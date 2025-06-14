import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:project_bnsp/database.dart';
import 'package:project_bnsp/user_session.dart';
import 'package:project_bnsp/login.dart';

class PelangganDasbor extends StatefulWidget {
  const PelangganDasbor({super.key});

  @override
  State<PelangganDasbor> createState() => _PelangganDasborState();
}

class _PelangganDasborState extends State<PelangganDasbor> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> breadMenu = [];
  bool isLoading = false;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    currentUser = await UserSession.getUser();
    setState(() {});
  }

  Future<void> _loadData() async {
    try {
      final userId = await UserSession.getUserId();
      
      // Load orders
      final ordersResult = await DatabaseAPI().getOrders(
        role: 'customer',
        userId: userId,
      );
      
      if (ordersResult['success']) {
        orders = List<Map<String, dynamic>>.from(ordersResult['orders']);
      }

      // Load bread menu
      breadMenu = DatabaseAPI().getBreadMenu();
      
      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak aktif. Silakan aktifkan GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak. Mohon berikan izin akses lokasi.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen. Mohon aktifkan di pengaturan aplikasi.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<void> _showOrderDialog(Map<String, dynamic> bread) async {
    int quantity = 1;
    String manualAddress = '';
    Position? currentPosition;
    bool isLoadingLocation = false;
    final TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            'Pesan ${bread['name']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bread info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bread['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bread['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Harga: Rp ${bread['price'].toStringAsFixed(0)}/pcs',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity selector
                Row(
                  children: [
                    const Text(
                      'Jumlah: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: quantity > 1 ? () {
                              setStateDialog(() {
                                quantity--;
                              });
                            } : null,
                            icon: const Icon(Icons.remove),
                            iconSize: 20,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setStateDialog(() {
                                quantity++;
                              });
                            },
                            icon: const Icon(Icons.add),
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Address input section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Alamat Pengiriman',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Manual address input
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Lengkap *',
                          hintText: 'Masukkan alamat pengiriman lengkap',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit_location),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          manualAddress = value;
                        },
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      
                      // GPS coordinate section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.gps_fixed, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                const Text(
                                  'Koordinat GPS:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            
                            if (isLoadingLocation) ...[
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Mengambil koordinat...', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ] else if (currentPosition == null) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Koordinat belum diambil',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        setStateDialog(() {
                                          isLoadingLocation = true;
                                        });
                                        
                                        try {
                                          currentPosition = await _getCurrentPosition();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                        
                                        setStateDialog(() {
                                          isLoadingLocation = false;
                                        });
                                      },
                                      icon: const Icon(Icons.my_location, size: 16),
                                      label: const Text('Ambil Koordinat GPS', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lat: ${currentPosition!.latitude.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Lng: ${currentPosition!.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Koordinat berhasil diambil',
                                        style: TextStyle(fontSize: 11, color: Colors.green),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () async {
                                          setStateDialog(() {
                                            isLoadingLocation = true;
                                          });
                                          
                                          try {
                                            currentPosition = await _getCurrentPosition();
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                          
                                          setStateDialog(() {
                                            isLoadingLocation = false;
                                          });
                                        },
                                        child: const Text('Perbarui', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Total price
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Harga:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rp ${(bread['price'] * quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: (manualAddress.trim().isEmpty || currentPosition == null || isLoadingLocation) ? null : () async {
                Navigator.pop(context);
                await _createOrder(bread, quantity, manualAddress.trim(), currentPosition!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pesan Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrder(Map<String, dynamic> bread, int quantity, String address, Position position) async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = await UserSession.getUserId();

      final result = await DatabaseAPI().createOrder(
        userId: userId!,
        customerName: currentUser!['full_name'],
        customerPhone: currentUser!['phone'] ?? '',
        breadType: bread['name'],
        quantity: quantity,
        unitPrice: bread['price'],
        totalPrice: bread['price'] * quantity,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Pesanan berhasil dibuat!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadData(); // Refresh data
        _tabController.animateTo(1); // Switch to orders tab
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal membuat pesanan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _searchOrders() async {
    try {
      final userId = await UserSession.getUserId();
      final result = await DatabaseAPI().searchOrders(
        query: _searchController.text,
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
        userId: userId,
        role: 'customer',
      );

      if (result['success']) {
        setState(() {
          orders = List<Map<String, dynamic>>.from(result['orders']);
        });
      }
    } catch (e) {
      print('Error searching orders: $e');
    }
  }

  Future<void> _cancelOrder(int orderId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final result = await DatabaseAPI().cancelOrder(orderId);
              
              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan berhasil dibatalkan'),
                    backgroundColor: Colors.orange,
                  ),
                );
                await _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Gagal membatalkan pesanan'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await UserSession.clearUser();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roti Shop'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.bakery_dining),
              text: 'Menu Roti',
            ),
            Tab(
              icon: Icon(Icons.receipt_long),
              text: 'Pesanan Saya',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'profile') {
                // TODO: Implement profile page
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(currentUser?['full_name'] ?? 'Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Menu Roti
          Column(
            children: [
              // Welcome banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[100]!, Colors.orange[50]!],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang, ${currentUser?['full_name'] ?? 'Pelanggan'}!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih roti segar favorit Anda',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Menu grid
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: breadMenu.length,
                    itemBuilder: (context, index) {
                      final bread = breadMenu[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image placeholder
                            Expanded(
                              flex: 3,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.bakery_dining,
                                  size: 40,
                                  color: Colors.orange[600],
                                ),
                              ),
                            ),
                            
                            // Content
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bread['name'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bread['description'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Rp ${bread['price'].toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 24,
                                          child: ElevatedButton(
                                            onPressed: isLoading ? null : () => _showOrderDialog(bread),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              minimumSize: Size.zero,
                                            ),
                                            child: const Text(
                                              'Pesan',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          
          // Tab Pesanan Saya
          Column(
            children: [
              // Search and filter
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[50],
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari pesanan...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (value) => _searchOrders(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.filter_list,
                            color: _selectedStatus.isEmpty ? Colors.grey : Colors.orange,
                          ),
                          onSelected: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                            _searchOrders();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: '', child: Text('Semua Status')),
                            const PopupMenuItem(value: 'pending', child: Text('Pending')),
                            const PopupMenuItem(value: 'confirmed', child: Text('Dikonfirmasi')),
                            const PopupMenuItem(value: 'delivered', child: Text('Terkirim')),
                            const PopupMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Orders list
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada pesanan',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pesan roti favorit Anda sekarang!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${order['bread_type']} - ${order['quantity']} pcs',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order['status']),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getStatusText(order['status']),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.monetization_on, size: 16, color: Colors.green[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Total: Rp ${order['total_price'].toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            order['address'] ?? 'Alamat tidak tersedia',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(order['order_date']),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Show coordinates for admin reference
                                    if (order['latitude'] != null && order['longitude'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.gps_fixed, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'GPS: ${order['latitude'].toStringAsFixed(6)}, ${order['longitude'].toStringAsFixed(6)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    
                                    // Action button for cancellation
                                    if (order['status'] == 'pending') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _cancelOrder(order['id']),
                                            icon: const Icon(Icons.cancel, size: 16),
                                            label: const Text('Batalkan'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: isLoading
          ? const FloatingActionButton(
              onPressed: null,
              backgroundColor: Colors.grey,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : null,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'MENUNGGU';
      case 'confirmed':
        return 'DIKONFIRMASI';
      case 'delivered':
        return 'TERKIRIM';
      case 'cancelled':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Tanggal tidak tersedia';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}