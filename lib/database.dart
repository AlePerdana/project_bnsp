import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseAPI {
  static final DatabaseAPI _instance = DatabaseAPI._internal();
  static Database? _database;

  DatabaseAPI._internal();

  factory DatabaseAPI() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'roti_shop.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel users untuk autentikasi
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT,
        role TEXT DEFAULT 'customer',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Tabel orders untuk menyimpan pesanan
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        bread_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        status TEXT DEFAULT 'pending',
        order_date TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Insert admin default
    String adminPassword = _hashPassword('admin123');
    await db.insert('users', {
      'username': 'admin',
      'email': 'admin@rotishop.com',
      'password_hash': adminPassword,
      'full_name': 'Administrator',
      'phone': '081234567890',
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Hash password menggunakan SHA256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Helper method untuk konversi data
  Map<String, dynamic> _convertToMap(Map<String, Object?> row) {
    return Map<String, dynamic>.from(row);
  }

  List<Map<String, dynamic>> _convertToListMap(List<Map<String, Object?>> rows) {
    return rows.map((row) => _convertToMap(row)).toList();
  }

  // API Endpoints

  // AUTH APIs
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final db = await database;
      
      // Check if username or email already exists
      final existingUser = await db.query(
        'users',
        where: 'username = ? OR email = ?',
        whereArgs: [username, email],
      );

      if (existingUser.isNotEmpty) {
        return {
          'success': false,
          'message': 'Username atau email sudah terdaftar'
        };
      }

      // Hash password
      String hashedPassword = _hashPassword(password);

      // Insert user
      int userId = await db.insert('users', {
        'username': username,
        'email': email,
        'password_hash': hashedPassword,
        'full_name': fullName,
        'phone': phone,
        'role': 'customer',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Registrasi berhasil',
        'user_id': userId
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final db = await database;
      
      String hashedPassword = _hashPassword(password);
      
      final result = await db.query(
        'users',
        where: 'username = ? AND password_hash = ?',
        whereArgs: [username, hashedPassword],
        limit: 1,
      );

      if (result.isEmpty) {
        // Try with email
        final emailResult = await db.query(
          'users',
          where: 'email = ? AND password_hash = ?',
          whereArgs: [username, hashedPassword],
          limit: 1,
        );

        if (emailResult.isEmpty) {
          return {
            'success': false,
            'message': 'Username/email atau password salah'
          };
        }

        Map<String, dynamic> user = _convertToMap(emailResult.first);
        user.remove('password_hash');
        
        return {
          'success': true,
          'message': 'Login berhasil',
          'user': user
        };
      }

      Map<String, dynamic> user = _convertToMap(result.first);
      user.remove('password_hash');
      
      return {
        'success': true,
        'message': 'Login berhasil',
        'user': user
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // USER APIs
  Future<Map<String, dynamic>> getUserById(int userId) async {
    try {
      final db = await database;
      
      final result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isEmpty) {
        return {
          'success': false,
          'message': 'User tidak ditemukan'
        };
      }

      Map<String, dynamic> user = _convertToMap(result.first);
      user.remove('password_hash');
      
      return {
        'success': true,
        'user': user
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String fullName,
    required String phone,
    String? email,
  }) async {
    try {
      final db = await database;
      
      Map<String, dynamic> updateData = {
        'full_name': fullName,
        'phone': phone,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (email != null) {
        updateData['email'] = email;
      }

      await db.update(
        'users',
        updateData,
        where: 'id = ?',
        whereArgs: [userId],
      );

      return {
        'success': true,
        'message': 'Profile berhasil diupdate'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ORDER APIs
  Future<Map<String, dynamic>> createOrder({
    required int userId,
    required String customerName,
    required String customerPhone,
    required String breadType,
    required int quantity,
    required double unitPrice,
    required double totalPrice,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final db = await database;
      
      int orderId = await db.insert('orders', {
        'user_id': userId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'bread_type': breadType,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'status': 'pending',
        'order_date': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Pesanan berhasil dibuat',
        'order_id': orderId
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> getOrders({
    required String role,
    int? userId,
  }) async {
    try {
      final db = await database;
      
      List<Map<String, Object?>> result;
      
      if (role == 'admin') {
        // Admin dapat melihat semua pesanan
        result = await db.query(
          'orders',
          orderBy: 'order_date DESC',
        );
      } else {
        // Customer hanya dapat melihat pesanannya sendiri
        result = await db.query(
          'orders',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'order_date DESC',
        );
      }

      return {
        'success': true,
        'orders': _convertToListMap(result)
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'orders': <Map<String, dynamic>>[]
      };
    }
  }

  Future<Map<String, dynamic>> getOrderById(int orderId) async {
    try {
      final db = await database;
      
      final result = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );

      if (result.isEmpty) {
        return {
          'success': false,
          'message': 'Pesanan tidak ditemukan'
        };
      }

      return {
        'success': true,
        'order': _convertToMap(result.first)
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    try {
      final db = await database;
      
      await db.update(
        'orders',
        {'status': status},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      return {
        'success': true,
        'message': 'Status pesanan berhasil diupdate'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    try {
      final db = await database;
      
      await db.update(
        'orders',
        {'status': 'cancelled'},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      return {
        'success': true,
        'message': 'Pesanan berhasil dibatalkan'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // BREAD MENU APIs
  List<Map<String, dynamic>> getBreadMenu() {
    return [
      {
        'id': 1,
        'name': 'Roti Tawar',
        'price': 15000.0,
        'description': 'Roti tawar lembut',
        'image': 'assets/bread1.png'
      },
      {
        'id': 2,
        'name': 'Roti Manis',
        'price': 12000.0,
        'description': 'Roti manis dengan gula',
        'image': 'assets/bread2.jpg'
      },
      {
        'id': 3,
        'name': 'Roti Coklat',
        'price': 18000.0,
        'description': 'Roti manis dengan coklat',
        'image': 'assets/bread3.jpg'
      },
      {
        'id': 4,
        'name': 'Roti Keju',
        'price': 20000.0,
        'description': 'Roti manis dengan keju',
        'image': 'assets/bread4.jpg'
      },
      {
        'id': 5,
        'name': 'Roti Kismis',
        'price': 16000.0,
        'description': 'Roti manisdengan kismis',
        'image': 'assets/bread5.jpg'
      },
      {
        'id': 6,
        'name': 'Roti Gandum',
        'price': 17000.0,
        'description': 'Roti gandum sehat dan bergizi',
        'image': 'assets/bread6.jpg'
      },
    ];
  }

  // STATISTICS APIs (untuk admin)
  Future<Map<String, dynamic>> getOrderStatistics() async {
    try {
      final db = await database;
      
      // Total pesanan
      final totalOrdersResult = await db.rawQuery('SELECT COUNT(*) as count FROM orders');
      int totalOrders = (totalOrdersResult.first['count'] as int?) ?? 0;
      
      // Total pendapatan
      final totalRevenueResult = await db.rawQuery('SELECT SUM(total_price) as total FROM orders WHERE status != "cancelled"');
      double totalRevenue = ((totalRevenueResult.first['total'] as num?) ?? 0).toDouble();
      
      // Pesanan hari ini
      String today = DateTime.now().toIso8601String().split('T')[0];
      final todayOrdersResult = await db.rawQuery('SELECT COUNT(*) as count FROM orders WHERE DATE(order_date) = ?', [today]);
      int todayOrders = (todayOrdersResult.first['count'] as int?) ?? 0;
      
      // Pesanan berdasarkan status
      final statusResult = await db.rawQuery('''
        SELECT status, COUNT(*) as count 
        FROM orders 
        GROUP BY status
      ''');
      
      // Roti terlaris
      final popularBreadResult = await db.rawQuery('''
        SELECT bread_type, SUM(quantity) as total_quantity
        FROM orders 
        WHERE status != "cancelled"
        GROUP BY bread_type 
        ORDER BY total_quantity DESC 
        LIMIT 5
      ''');

      return {
        'success': true,
        'statistics': {
          'total_orders': totalOrders,
          'total_revenue': totalRevenue,
          'today_orders': todayOrders,
          'orders_by_status': _convertToListMap(statusResult),
          'popular_breads': _convertToListMap(popularBreadResult),
        }
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // UTILITY APIs
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('orders');
    await db.delete('users');
    
    // Re-insert admin
    String adminPassword = _hashPassword('admin123');
    await db.insert('users', {
      'username': 'admin',
      'email': 'admin@rotishop.com',
      'password_hash': adminPassword,
      'full_name': 'Administrator',
      'phone': '081234567890',
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  // SEARCH APIs
  Future<Map<String, dynamic>> searchOrders({
    required String query,
    String? status,
    int? userId,
    String? role,
  }) async {
    try {
      final db = await database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (role != 'admin' && userId != null) {
        whereClause = 'user_id = ?';
        whereArgs.add(userId);
      }
      
      if (query.isNotEmpty) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += '(customer_name LIKE ? OR bread_type LIKE ? OR address LIKE ?)';
        whereArgs.addAll(['%$query%', '%$query%', '%$query%']);
      }
      
      if (status != null && status.isNotEmpty) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'status = ?';
        whereArgs.add(status);
      }

      final result = await db.query(
        'orders',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'order_date DESC',
      );

      return {
        'success': true,
        'orders': _convertToListMap(result)
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'orders': <Map<String, dynamic>>[]
      };
    }
  }

  // DELETE DATABASE (untuk testing)
  Future<void> deleteDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'roti_shop.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}