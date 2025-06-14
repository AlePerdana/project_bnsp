import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_bnsp/database.dart';
import 'package:project_bnsp/user_session.dart';
import 'package:project_bnsp/login.dart';

class AdminDasbor extends StatefulWidget {
  const AdminDasbor({super.key});

  @override
  State<AdminDasbor> createState() => _AdminDasborState();
}

class _AdminDasborState extends State<AdminDasbor> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> orders = [];
  Map<String, dynamic>? statistics;
  bool isLoading = true;
  Map<String, dynamic>? currentUser;
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
    setState(() {
      isLoading = true;
    });

    try {
      // Load orders
      final ordersResult = await DatabaseAPI().getOrders(
        role: 'admin',
      );

      if (ordersResult['success'] == true) {
        orders = List<Map<String, dynamic>>.from(ordersResult['orders'] ?? []);
      }

      // Load statistics
      final statsResult = await DatabaseAPI().getOrderStatistics();
      if (statsResult['success'] == true) {
        statistics = statsResult['statistics'];
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    final result = await DatabaseAPI().updateOrderStatus(
      orderId: orderId,
      status: status,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status pesanan berhasil diubah menjadi $status'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal mengubah status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchOrders() async {
    try {
      final result = await DatabaseAPI().searchOrders(
        query: _searchController.text,
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
        role: 'admin',
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
        title: const Text('Admin Dashboard'),
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
              icon: Icon(Icons.dashboard),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'Semua Pesanan',
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
              if (value == 'logout') {
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
                    Text(currentUser?['full_name'] ?? 'Admin'),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildOrdersTab(),
              ],
            ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, size: 40, color: Colors.orange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat datang, ${currentUser?['full_name'] ?? 'Admin'}!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Kelola pesanan dan pantau penjualan'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statistics cards
          if (statistics != null) ...[
            const Text(
              'Statistik Penjualan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Pesanan',
                  '${statistics!['total_orders']}',
                  Icons.receipt_long,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Pendapatan',
                  'Rp ${statistics!['total_revenue'].toStringAsFixed(0)}',
                  Icons.monetization_on,
                  Colors.green,
                ),
                _buildStatCard(
                  'Pesanan Hari Ini',
                  '${statistics!['today_orders']}',
                  Icons.today,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Status Pending',
                  '${_getStatusCount('pending')}',
                  Icons.pending,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Popular breads
            const Text(
              'Roti Terlaris',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (statistics!['popular_breads'] != null)
              ...List.generate(
                (statistics!['popular_breads'] as List).length,
                (index) {
                  final bread = (statistics!['popular_breads'] as List)[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.bakery_dining, color: Colors.orange),
                      title: Text(bread['bread_type']),
                      trailing: Text(
                        '${bread['total_quantity']} terjual',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Search and filter
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
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
        ),

        // Orders list
        Expanded(
          child: orders.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada pesanan',
                    style: TextStyle(fontSize: 18),
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
                                      '#${order['id']} - ${order['bread_type']}',
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
                              Text('Pelanggan: ${order['customer_name']}'),
                              Text('Phone: ${order['customer_phone']}'),
                              Text('Jumlah: ${order['quantity']} pcs'),
                              Text('Total: Rp ${order['total_price'].toStringAsFixed(0)}'),
                              
                              // Alamat section
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Alamat Pengiriman:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order['address'] ?? 'Alamat tidak tersedia',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // GPS Coordinates section
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.gps_fixed, size: 16, color: Colors.green[700]),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Koordinat GPS:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (order['latitude'] != null && order['longitude'] != null) ...[
                                      Text(
                                        'Latitude: ${order['latitude'].toStringAsFixed(6)}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      Text(
                                        'Longitude: ${order['longitude'].toStringAsFixed(6)}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${order['latitude'].toStringAsFixed(6)}, ${order['longitude'].toStringAsFixed(6)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _openInMaps(order['latitude'], order['longitude']),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green[700],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.map, size: 12, color: Colors.white),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Buka di Maps',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Text(
                                        'Koordinat tidak tersedia',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Waktu: ${_formatDate(order['order_date'])}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Action buttons
                              if (order['status'] == 'pending') ...[
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _updateOrderStatus(order['id'], 'confirmed'),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Konfirmasi'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _updateOrderStatus(order['id'], 'cancelled'),
                                      icon: const Icon(Icons.cancel, size: 16),
                                      label: const Text('Batalkan'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (order['status'] == 'confirmed') ...[
                                ElevatedButton.icon(
                                  onPressed: () => _updateOrderStatus(order['id'], 'delivered'),
                                  icon: const Icon(Icons.delivery_dining, size: 16),
                                  label: const Text('Tandai Terkirim'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
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
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _getStatusCount(String status) {
    if (statistics?['orders_by_status'] == null) return 0;
    
    final statusList = statistics!['orders_by_status'] as List;
    final statusData = statusList.firstWhere(
      (item) => item['status'] == status,
      orElse: () => {'count': 0},
    );
    return statusData['count'] ?? 0;
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

  void _openInMaps(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka Lokasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih aplikasi untuk membuka lokasi:'),
            const SizedBox(height: 16),
            Text(
              'Koordinat: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _copyToClipboard('$latitude, $longitude');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Salin Koordinat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Koordinat disalin: $text'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}