// ╔══════════════════════════════════════════════════════════════════╗
// ║       CLOTHING MANAGEMENT SYSTEM — BACKEND (backend.dart)       ║
// ║       SQLite Local DB + HTTP Sync + Excel Import/Export          ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// pubspec.yaml mein ye dependencies add karo:
//
// dependencies:
//   flutter:
//     sdk: flutter
//   sqflite: ^2.3.3
//   path_provider: ^2.1.3
//   path: ^1.9.0
//   connectivity_plus: ^6.0.3
//   http: ^1.2.1
//   excel: ^4.0.2
//   shared_preferences: ^2.2.3
//   file_picker: ^8.0.0+1
//   permission_handler: ^11.3.1
//
// Android: android/app/src/main/AndroidManifest.xml mein add karo:
//   <uses-permission android:name="android.permission.INTERNET"/>
//   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
//   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
//
// API_BASE_URL apne server ka URL dalo neeche.
// Agar apna server nahi hai to Firebase use karo (instructions end mein hain).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// ══════════════════════════════════════════════════════════
//  CONFIG — Sirf ye ek jagah URL aur settings change karo
// ══════════════════════════════════════════════════════════
class AppConfig {
  static const String _nocodeUsername = 'chaywalaashu97';
  static const String _nocodeKey      = 'naGNnxBxebRHPoguD';
  static const String _usersTab       = 'users';
  static const String nocodeBaseUrl   =
      'https://v2.nocodeapi.com/$_nocodeUsername/google_sheets/$_nocodeKey';
  static String get usersUrl => '$nocodeBaseUrl?tabName=$_usersTab';
  static const String excelFileName = 'inventory.xlsx';
  static const int lowStockLimit = 5;
  static const String apiBaseUrl = 'https://v2.nocodeapi.com/$_nocodeUsername/google_sheets/$_nocodeKey';

  /// JWT token expire time (hours)
  static const int tokenExpiryHours = 24;

  /// Auto-sync interval jab internet aaye (minutes)
  static const int autoSyncIntervalMinutes = 5;

  /// Excel file name
  static const String excelFileName = 'inventory.xlsx';
}

// ══════════════════════════════════════════════════════════
//  MODELS — Saaf data classes
// ══════════════════════════════════════════════════════════

class UserSession {
  final String userId;
  final String name;
  final String role; // 'admin' ya 'worker'
  final String token;
  final String? workerKey;

  const UserSession({
    required this.userId,
    required this.name,
    required this.role,
    required this.token,
    this.workerKey,
  });

  bool get isAdmin => role == 'admin';
  bool get isWorker => role == 'worker';

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'role': role,
        'token': token,
        'workerKey': workerKey,
      };

  factory UserSession.fromMap(Map<String, dynamic> m) => UserSession(
        userId: m['userId'] as String,
        name: m['name'] as String,
        role: m['role'] as String,
        token: m['token'] as String,
        workerKey: m['workerKey'] as String?,
      );
}

class InventoryItem {
  final int? id;
  final String crn;        // Unique CRN number
  final String name;
  final String gender;     // Men / Women / Kids / Unisex
  final String size;
  final String unit;       // Piece / Set / Dozen
  final String brand;
  final double price;
  int quantity;
  final DateTime createdAt;
  DateTime updatedAt;

  InventoryItem({
    this.id,
    required this.crn,
    required this.name,
    required this.gender,
    required this.size,
    required this.unit,
    required this.brand,
    required this.price,
    required this.quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'crn': crn,
        'name': name,
        'gender': gender,
        'size': size,
        'unit': unit,
        'brand': brand,
        'price': price,
        'quantity': quantity,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InventoryItem.fromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'] as int?,
        crn: m['crn'] as String,
        name: m['name'] as String,
        gender: m['gender'] as String,
        size: m['size'] as String,
        unit: m['unit'] as String,
        brand: m['brand'] as String,
        price: (m['price'] as num).toDouble(),
        quantity: m['quantity'] as int,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  // Excel row se banao
  factory InventoryItem.fromExcelRow(List<dynamic> row) {
    return InventoryItem(
      crn: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      gender: row[2]?.toString() ?? 'Men',
      size: row[3]?.toString() ?? 'M',
      unit: row[4]?.toString() ?? 'Piece',
      brand: row[5]?.toString() ?? '',
      price: double.tryParse(row[6]?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(row[7]?.toString() ?? '0') ?? 0,
    );
  }

  // Excel row ke liye
  List<dynamic> toExcelRow() =>
      [crn, name, gender, size, unit, brand, price, quantity,
       createdAt.toIso8601String()];
}

class SaleRecord {
  final int? id;
  final String crn;
  final String itemName;
  final String itemGender;
  final String itemSize;
  final String brand;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double totalAmount;
  final String workerId;
  final String workerName;
  final DateTime soldAt;
  bool isSynced; // Server pe gaya ya nahi

  SaleRecord({
    this.id,
    required this.crn,
    required this.itemName,
    required this.itemGender,
    required this.itemSize,
    required this.brand,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.totalAmount,
    required this.workerId,
    required this.workerName,
    DateTime? soldAt,
    this.isSynced = false,
  }) : soldAt = soldAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'crn': crn,
        'item_name': itemName,
        'item_gender': itemGender,
        'item_size': itemSize,
        'brand': brand,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount,
        'total_amount': totalAmount,
        'worker_id': workerId,
        'worker_name': workerName,
        'sold_at': soldAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  factory SaleRecord.fromMap(Map<String, dynamic> m) => SaleRecord(
        id: m['id'] as int?,
        crn: m['crn'] as String,
        itemName: m['item_name'] as String,
        itemGender: m['item_gender'] as String,
        itemSize: m['item_size'] as String,
        brand: m['brand'] as String,
        quantity: m['quantity'] as int,
        unitPrice: (m['unit_price'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        totalAmount: (m['total_amount'] as num).toDouble(),
        workerId: m['worker_id'] as String,
        workerName: m['worker_name'] as String,
        soldAt: DateTime.parse(m['sold_at'] as String),
        isSynced: (m['is_synced'] as int) == 1,
      );

  Map<String, dynamic> toJson() => {
        'crn': crn,
        'item_name': itemName,
        'item_gender': itemGender,
        'item_size': itemSize,
        'brand': brand,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount,
        'total_amount': totalAmount,
        'worker_id': workerId,
        'worker_name': workerName,
        'sold_at': soldAt.toIso8601String(),
      };
}

class ReturnRecord {
  final int? id;
  final String crn;
  final String itemName;
  final int quantity;
  final String reason;
  final String workerId;
  final String workerName;
  final double refundAmount;
  final DateTime returnedAt;
  bool isSynced;

  ReturnRecord({
    this.id,
    required this.crn,
    required this.itemName,
    required this.quantity,
    required this.reason,
    required this.workerId,
    required this.workerName,
    required this.refundAmount,
    DateTime? returnedAt,
    this.isSynced = false,
  }) : returnedAt = returnedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'crn': crn,
        'item_name': itemName,
        'quantity': quantity,
        'reason': reason,
        'worker_id': workerId,
        'worker_name': workerName,
        'refund_amount': refundAmount,
        'returned_at': returnedAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  factory ReturnRecord.fromMap(Map<String, dynamic> m) => ReturnRecord(
        id: m['id'] as int?,
        crn: m['crn'] as String,
        itemName: m['item_name'] as String,
        quantity: m['quantity'] as int,
        reason: m['reason'] as String,
        workerId: m['worker_id'] as String,
        workerName: m['worker_name'] as String,
        refundAmount: (m['refund_amount'] as num).toDouble(),
        returnedAt: DateTime.parse(m['returned_at'] as String),
        isSynced: (m['is_synced'] as int) == 1,
      );

  Map<String, dynamic> toJson() => {
        'crn': crn,
        'item_name': itemName,
        'quantity': quantity,
        'reason': reason,
        'worker_id': workerId,
        'worker_name': workerName,
        'refund_amount': refundAmount,
        'returned_at': returnedAt.toIso8601String(),
      };
}

class WorkerKey {
  final int? id;
  final String key;
  final String name;
  final String phone;
  bool isActive;
  final DateTime createdAt;

  WorkerKey({
    this.id,
    required this.key,
    required this.name,
    required this.phone,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'key': key,
        'name': name,
        'phone': phone,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory WorkerKey.fromMap(Map<String, dynamic> m) => WorkerKey(
        id: m['id'] as int?,
        key: m['key'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String,
        isActive: (m['is_active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class InventoryUnit {
  final int? id;
  final String name;
  int totalQuantity;
  int usedQuantity;

  InventoryUnit({
    this.id,
    required this.name,
    required this.totalQuantity,
    this.usedQuantity = 0,
  });

  int get availableQuantity => totalQuantity - usedQuantity;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'total_quantity': totalQuantity,
        'used_quantity': usedQuantity,
      };

  factory InventoryUnit.fromMap(Map<String, dynamic> m) => InventoryUnit(
        id: m['id'] as int?,
        name: m['name'] as String,
        totalQuantity: m['total_quantity'] as int,
        usedQuantity: m['used_quantity'] as int,
      );
}

// Result wrapper — success ya error dono handle karta hai
class Result<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const Result.success(this.data) : error = null;
  const Result.failure(this.error) : data = null;
}

// ══════════════════════════════════════════════════════════
//  1. DATABASE SERVICE — SQLite setup aur saari tables
// ══════════════════════════════════════════════════════════
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'clothing_manager.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onConfigure: (db) async {
        // Foreign keys enable karo
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Inventory Units table (Piece, Set, Dozen etc.)
    await db.execute('''
      CREATE TABLE inventory_units (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL UNIQUE,
        total_quantity INTEGER NOT NULL DEFAULT 0,
        used_quantity  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Main Inventory table
    await db.execute('''
      CREATE TABLE inventory (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        crn         TEXT NOT NULL UNIQUE,
        name        TEXT NOT NULL,
        gender      TEXT NOT NULL,
        size        TEXT NOT NULL,
        unit        TEXT NOT NULL,
        brand       TEXT NOT NULL,
        price       REAL NOT NULL,
        quantity    INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        crn           TEXT NOT NULL,
        item_name     TEXT NOT NULL,
        item_gender   TEXT NOT NULL,
        item_size     TEXT NOT NULL,
        brand         TEXT NOT NULL,
        quantity      INTEGER NOT NULL,
        unit_price    REAL NOT NULL,
        discount      REAL NOT NULL DEFAULT 0,
        total_amount  REAL NOT NULL,
        worker_id     TEXT NOT NULL,
        worker_name   TEXT NOT NULL,
        sold_at       TEXT NOT NULL,
        is_synced     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Returns table
    await db.execute('''
      CREATE TABLE returns (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        crn           TEXT NOT NULL,
        item_name     TEXT NOT NULL,
        quantity      INTEGER NOT NULL,
        reason        TEXT NOT NULL,
        worker_id     TEXT NOT NULL,
        worker_name   TEXT NOT NULL,
        refund_amount REAL NOT NULL DEFAULT 0,
        returned_at   TEXT NOT NULL,
        is_synced     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Worker Keys table (admin ke paas hogi ye)
    await db.execute('''
      CREATE TABLE worker_keys (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        key         TEXT NOT NULL UNIQUE,
        name        TEXT NOT NULL,
        phone       TEXT NOT NULL DEFAULT '',
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT NOT NULL
      )
    ''');

    debugPrint('[DB] All tables created successfully');
  }

  // Raw query helper
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit);
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> executeRaw(String sql, [List<dynamic>? args]) async {
    final db = await database;
    await db.execute(sql, args);
  }

  /// Database close karo (app band hone pe)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  2. CONNECTIVITY SERVICE — Internet check
// ══════════════════════════════════════════════════════════
class ConnectivityService {
  static ConnectivityService? _instance;
  ConnectivityService._();
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  final _connectivity = Connectivity();

  /// Abhi internet hai ya nahi
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Internet aane-jaane ka stream
  Stream<bool> get onlineStatusStream => _connectivity.onConnectivityChanged
      .map((r) => r != ConnectivityResult.none);

  /// Actual internet hai ya sirf WiFi connect hai — real ping test
  Future<bool> get hasRealInternet async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  3. AUTH SERVICE — Login (online only), Session, Logout
// ══════════════════════════════════════════════════════════
class AuthService {
  static AuthService? _instance;
  AuthService._();
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  static const _sessionKey = 'user_session';
  static const _loginTimeKey = 'login_time';

  UserSession? _currentSession;
  UserSession? get currentSession => _currentSession;
  bool get isLoggedIn => _currentSession != null;

  /// App start hone pe saved session load karo
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionKey);
    if (sessionJson != null) {
      try {
        final map = jsonDecode(sessionJson) as Map<String, dynamic>;
        _currentSession = UserSession.fromMap(map);
        debugPrint('[Auth] Session loaded: ${_currentSession!.name}');
      } catch (e) {
        debugPrint('[Auth] Session load failed: $e');
        await _clearSession();
      }
    }
  }

  /// Google Sheet se saare users fetch karo
  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.usersUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>;
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('[Auth] Sheet fetch error: $e');
    }
    return [];
  }

  /// Admin login — Google Sheet se
  Future<Result<UserSession>> loginAdmin({
    required String username,
    required String password,
  }) async {
    final online = await ConnectivityService.instance.hasRealInternet;
    if (!online) {
      return const Result.failure(
          'Login ke liye internet zaroori hai.');
    }

    try {
      final users = await _fetchUsers();
      if (users.isEmpty) {
        return const Result.failure(
            'Sheet se data nahi aaya. Internet check karo.');
      }

      // Username + password + role match karo
      final matched = users.where((u) {
        final uName = (u['username'] ?? '').toString().trim().toLowerCase();
        final uPass = (u['password'] ?? '').toString().trim();
        final uRole = (u['role'] ?? '').toString().trim().toLowerCase();
        final uActive = (u['is_active'] ?? 'true').toString().trim().toLowerCase();
        return uName == username.trim().toLowerCase() &&
            uPass == password.trim() &&
            uRole == 'admin' &&
            uActive == 'true';
      }).toList();

      if (matched.isEmpty) {
        return const Result.failure('Username ya password galat hai.');
      }

      final user = matched.first;
      final session = UserSession(
        userId: 'admin_${user['row_id'] ?? '1'}',
        name: (user['name'] ?? 'Admin').toString(),
        role: 'admin',
        token: 'sheet_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _saveSession(session);
      debugPrint('[Auth] Admin login: ${session.name}');
      return Result.success(session);
    } catch (e) {
      return Result.failure('Login error: $e');
    }
  }

  /// Worker login — Google Sheet se key verify
  Future<Result<UserSession>> loginWorker({required String workerKey}) async {
    final online = await ConnectivityService.instance.hasRealInternet;
    if (!online) {
      return const Result.failure(
          'Login ke liye internet zaroori hai.');
    }

    try {
      final key = workerKey.trim().toUpperCase();
      final users = await _fetchUsers();

      final matched = users.where((u) {
        final uKey    = (u['worker_key'] ?? '').toString().trim().toUpperCase();
        final uRole   = (u['role'] ?? '').toString().trim().toLowerCase();
        final uActive = (u['is_active'] ?? 'true').toString().trim().toLowerCase();
        return uKey == key && uRole == 'worker' && uActive == 'true';
      }).toList();

      if (matched.isEmpty) {
        return const Result.failure(
            'Worker key invalid ya inactive hai.\nAdmin se contact karein.');
      }

      final user = matched.first;
      final session = UserSession(
        userId: 'worker_${user['row_id'] ?? '1'}',
        name: (user['name'] ?? 'Worker').toString(),
        role: 'worker',
        token: 'sheet_${DateTime.now().millisecondsSinceEpoch}',
        workerKey: key,
      );
      await _saveSession(session);
      debugPrint('[Auth] Worker login: ${session.name}');
      return Result.success(session);
    } catch (e) {
      return Result.failure('Login error: $e');
    }
  }

  /// Naya account banao — Google Sheet mein save hoga
  Future<Result<void>> createAccount({
    required String username,
    required String password,
    required String name,
    required String role,
    String workerKey = '',
  }) async {
    final online = await ConnectivityService.instance.hasRealInternet;
    if (!online) {
      return const Result.failure('Account banane ke liye internet zaroori hai.');
    }

    if (username.trim().isEmpty || password.trim().isEmpty || name.trim().isEmpty) {
      return const Result.failure('Saari fields bharo.');
    }

    try {
      // Duplicate check — kya username pehle se hai?
      final users = await _fetchUsers();
      final exists = users.any((u) =>
          (u['username'] ?? '').toString().trim().toLowerCase() ==
          username.trim().toLowerCase());

      if (exists) {
        return const Result.failure(
            'Ye username pehle se exist karta hai. Alag username lo.');
      }

      // Google Sheet mein new row add karo
      final res = await http
          .post(
            Uri.parse(AppConfig.usersUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode([
              [
                username.trim(),
                password.trim(),
                role.trim().toLowerCase(),
                name.trim(),
                workerKey.trim().toUpperCase(),
                'true',
              ]
            ]),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('[Auth] Account created: $username');
        return const Result.success(null);
      } else {
        return Result.failure('Sheet save error: ${res.statusCode}');
      }
    } catch (e) {
      return Result.failure('Account create error: $e');
    }
  }

  /// Logout — session clear karo
  Future<Result<void>> logout() async {
    await _clearSession();
    return const Result.success(null);
  }

  Future<void> _saveSession(UserSession session) async {
    _currentSession = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toMap()));
    await prefs.setString(
        _loginTimeKey, DateTime.now().toIso8601String());
    debugPrint('[Auth] Session saved for: ${session.name}');
  }

  Future<void> _clearSession() async {
    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_loginTimeKey);
    debugPrint('[Auth] Session cleared');
  }
}

// ══════════════════════════════════════════════════════════
//  4. INVENTORY SERVICE — CRUD + Units + Excel auto-update
// ══════════════════════════════════════════════════════════
class InventoryService {
  static InventoryService? _instance;
  InventoryService._();
  static InventoryService get instance {
    _instance ??= InventoryService._();
    return _instance!;
  }

  final _db = DatabaseService.instance;

  // ── Units ──────────────────────────────────────────────

  /// Nayi unit add karo (Piece, Set, Dozen etc.)
  Future<Result<InventoryUnit>> addUnit(InventoryUnit unit) async {
    try {
      final id = await _db.insert('inventory_units', unit.toMap());
      final saved = InventoryUnit(
        id: id,
        name: unit.name,
        totalQuantity: unit.totalQuantity,
        usedQuantity: unit.usedQuantity,
      );
      return Result.success(saved);
    } catch (e) {
      if (e.toString().contains('UNIQUE')) {
        return const Result.failure('Is naam ki unit pehle se exist karti hai.');
      }
      return Result.failure('Unit save error: $e');
    }
  }

  /// Saari units lo
  Future<List<InventoryUnit>> getAllUnits() async {
    final rows = await _db.query('inventory_units', orderBy: 'name ASC');
    return rows.map(InventoryUnit.fromMap).toList();
  }

  /// Unit update karo
  Future<Result<void>> updateUnit(InventoryUnit unit) async {
    try {
      await _db.update(
        'inventory_units',
        unit.toMap(),
        where: 'id = ?',
        whereArgs: [unit.id],
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Unit update error: $e');
    }
  }

  // ── Inventory Items ────────────────────────────────────

  /// Naya inventory item add karo
  /// Excel bhi automatically update hoti hai
  Future<Result<InventoryItem>> addItem(InventoryItem item) async {
    try {
      // CRN unique check
      final existing = await _db.query('inventory',
          where: 'crn = ?', whereArgs: [item.crn]);
      if (existing.isNotEmpty) {
        return const Result.failure(
            'Yeh CRN number pehle se exist karta hai. Alag CRN use karein.');
      }

      final now = DateTime.now();
      final newItem = InventoryItem(
        crn: item.crn,
        name: item.name,
        gender: item.gender,
        size: item.size,
        unit: item.unit,
        brand: item.brand,
        price: item.price,
        quantity: item.quantity,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _db.insert('inventory', newItem.toMap());
      final saved = InventoryItem.fromMap({...newItem.toMap(), 'id': id});

      // Excel file automatically update karo
      await ExcelService.instance.updateExcelFile();

      debugPrint('[Inventory] Item added: ${item.name} (${item.crn})');
      return Result.success(saved);
    } catch (e) {
      return Result.failure('Item add error: $e');
    }
  }

  /// Inventory item update karo
  Future<Result<void>> updateItem(InventoryItem item) async {
    try {
      item.updatedAt = DateTime.now();
      await _db.update(
        'inventory',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      await ExcelService.instance.updateExcelFile();
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Item update error: $e');
    }
  }

  /// Inventory item delete karo
  Future<Result<void>> deleteItem(int id) async {
    try {
      await _db.delete('inventory', where: 'id = ?', whereArgs: [id]);
      await ExcelService.instance.updateExcelFile();
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Item delete error: $e');
    }
  }

  /// CRN se item dhundho
  Future<InventoryItem?> getItemByCrn(String crn) async {
    final rows = await _db.query('inventory',
        where: 'crn = ?', whereArgs: [crn]);
    if (rows.isEmpty) return null;
    return InventoryItem.fromMap(rows.first);
  }

  /// Saare items lo (filter optional)
  Future<List<InventoryItem>> getAllItems({
    String? gender,
    String? searchQuery,
    String? unit,
  }) async {
    String? where;
    List<dynamic>? args;

    final conditions = <String>[];
    final argsList = <dynamic>[];

    if (gender != null && gender != 'All') {
      conditions.add('gender = ?');
      argsList.add(gender);
    }
    if (unit != null) {
      conditions.add('unit = ?');
      argsList.add(unit);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(name LIKE ? OR crn LIKE ? OR brand LIKE ?)');
      argsList.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      args = argsList;
    }

    final rows = await _db.query('inventory',
        where: where, whereArgs: args, orderBy: 'name ASC');
    return rows.map(InventoryItem.fromMap).toList();
  }

  /// Inventory server se download karo (worker login pe)
  Future<void> downloadInventoryFromServer(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/inventory'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final db = await DatabaseService.instance.database;

        // Transaction mein sab insert karo — fast hoga
        await db.transaction((txn) async {
          // Purani inventory clean karo
          await txn.delete('inventory');

          for (final itemMap in data) {
            final map = itemMap as Map<String, dynamic>;
            await txn.insert(
              'inventory',
              {
                'crn': map['crn'],
                'name': map['name'],
                'gender': map['gender'],
                'size': map['size'],
                'unit': map['unit'],
                'brand': map['brand'],
                'price': map['price'],
                'quantity': map['quantity'],
                'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        debugPrint('[Inventory] Downloaded ${data.length} items from server');
      }
    } catch (e) {
      debugPrint('[Inventory] Download failed: $e — using local data');
    }
  }
}

// ══════════════════════════════════════════════════════════
//  5. SALES SERVICE — Sell karo, inventory km karo
// ══════════════════════════════════════════════════════════
class SalesService {
  static SalesService? _instance;
  SalesService._();
  static SalesService get instance {
    _instance ??= SalesService._();
    return _instance!;
  }

  final _db = DatabaseService.instance;
  final _inv = InventoryService.instance;

  /// Item sell karo
  /// 1. Inventory se qty ghataao
  /// 2. Sale record save karo
  Future<Result<SaleRecord>> sellItem({
    required String crn,
    required int quantity,
    required double discount,
    required UserSession worker,
  }) async {
    // Inventory item dhundho
    final item = await _inv.getItemByCrn(crn);
    if (item == null) {
      return const Result.failure(
          'CRN number nahi mila. Item exist nahi karta.');
    }

    if (item.quantity < quantity) {
      return Result.failure(
          'Sirf ${item.quantity} items baaki hain. Itni quantity sell nahi ho sakti.');
    }

    final totalAmount = (item.price * quantity) - discount;
    if (totalAmount < 0) {
      return const Result.failure('Discount zyada hai. Total negative nahi ho sakta.');
    }

    try {
      // Transaction: inventory update + sale record ek saath
      final db = await DatabaseService.instance.database;
      late SaleRecord savedSale;

      await db.transaction((txn) async {
        // Inventory quantity ghataao
        await txn.update(
          'inventory',
          {
            'quantity': item.quantity - quantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'crn = ?',
          whereArgs: [crn],
        );

        // Sale record banao
        final sale = SaleRecord(
          crn: crn,
          itemName: item.name,
          itemGender: item.gender,
          itemSize: item.size,
          brand: item.brand,
          quantity: quantity,
          unitPrice: item.price,
          discount: discount,
          totalAmount: totalAmount,
          workerId: worker.userId,
          workerName: worker.name,
          isSynced: false,
        );

        final id = await txn.insert('sales', sale.toMap());
        savedSale = SaleRecord(
          id: id,
          crn: sale.crn,
          itemName: sale.itemName,
          itemGender: sale.itemGender,
          itemSize: sale.itemSize,
          brand: sale.brand,
          quantity: sale.quantity,
          unitPrice: sale.unitPrice,
          discount: sale.discount,
          totalAmount: sale.totalAmount,
          workerId: sale.workerId,
          workerName: sale.workerName,
          soldAt: sale.soldAt,
          isSynced: false,
        );
      });

      // Excel update karo
      await ExcelService.instance.updateExcelFile();

      // Background mein sync try karo
      _trySyncInBackground();

      debugPrint(
          '[Sales] Sold: ${item.name} x$quantity = ₹$totalAmount');
      return Result.success(savedSale);
    } catch (e) {
      return Result.failure('Sale error: $e');
    }
  }

  /// Aaj ki sales lo (worker specific ya sab)
  Future<List<SaleRecord>> getTodaySales({String? workerId}) async {
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final end =
        DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

    String where = 'sold_at BETWEEN ? AND ?';
    List<dynamic> args = [start, end];

    if (workerId != null) {
      where += ' AND worker_id = ?';
      args.add(workerId);
    }

    final rows = await _db.query('sales',
        where: where, whereArgs: args, orderBy: 'sold_at DESC');
    return rows.map(SaleRecord.fromMap).toList();
  }

  /// Date ke hisaab se sales lo
  Future<List<SaleRecord>> getSalesByDate(DateTime date,
      {String? workerId}) async {
    final start =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59)
        .toIso8601String();

    String where = 'sold_at BETWEEN ? AND ?';
    List<dynamic> args = [start, end];

    if (workerId != null) {
      where += ' AND worker_id = ?';
      args.add(workerId);
    }

    final rows = await _db.query('sales',
        where: where, whereArgs: args, orderBy: 'sold_at DESC');
    return rows.map(SaleRecord.fromMap).toList();
  }

  /// Aaj ka total revenue
  Future<double> getTodayRevenue({String? workerId}) async {
    final sales = await getTodaySales(workerId: workerId);
    return sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
  }

  /// Jo sync nahi hui sales
  Future<List<SaleRecord>> getUnsyncedSales(String workerId) async {
    final rows = await _db.query('sales',
        where: 'is_synced = 0 AND worker_id = ?',
        whereArgs: [workerId],
        orderBy: 'sold_at ASC');
    return rows.map(SaleRecord.fromMap).toList();
  }

  // Background sync try karo (error ignore karo)
  void _trySyncInBackground() {
    final session = AuthService.instance.currentSession;
    if (session == null) return;
    ConnectivityService.instance.isOnline.then((online) {
      if (online) {
        SyncService.instance.syncWorkerData(session).then((_) {
          debugPrint('[Sales] Background sync attempted');
        });
      }
    });
  }
}

// ══════════════════════════════════════════════════════════
//  6. RETURN SERVICE — Item return, inventory wapas badhao
// ══════════════════════════════════════════════════════════
class ReturnService {
  static ReturnService? _instance;
  ReturnService._();
  static ReturnService get instance {
    _instance ??= ReturnService._();
    return _instance!;
  }

  final _db = DatabaseService.instance;
  final _inv = InventoryService.instance;

  /// Item return karo
  /// 1. Inventory mein qty wapas add karo
  /// 2. Return record save karo
  Future<Result<ReturnRecord>> returnItem({
    required String crn,
    required int quantity,
    required String reason,
    required UserSession worker,
    double refundAmount = 0,
  }) async {
    final item = await _inv.getItemByCrn(crn);
    if (item == null) {
      return const Result.failure('CRN number nahi mila.');
    }

    try {
      final db = await DatabaseService.instance.database;
      late ReturnRecord savedReturn;

      await db.transaction((txn) async {
        // Inventory mein qty wapas add karo
        await txn.update(
          'inventory',
          {
            'quantity': item.quantity + quantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'crn = ?',
          whereArgs: [crn],
        );

        // Return record banao
        final ret = ReturnRecord(
          crn: crn,
          itemName: item.name,
          quantity: quantity,
          reason: reason,
          workerId: worker.userId,
          workerName: worker.name,
          refundAmount: refundAmount,
          isSynced: false,
        );

        final id = await txn.insert('returns', ret.toMap());
        savedReturn = ReturnRecord(
          id: id,
          crn: ret.crn,
          itemName: ret.itemName,
          quantity: ret.quantity,
          reason: ret.reason,
          workerId: ret.workerId,
          workerName: ret.workerName,
          refundAmount: ret.refundAmount,
          returnedAt: ret.returnedAt,
          isSynced: false,
        );
      });

      await ExcelService.instance.updateExcelFile();

      debugPrint('[Return] Returned: ${item.name} x$quantity');
      return Result.success(savedReturn);
    } catch (e) {
      return Result.failure('Return error: $e');
    }
  }

  /// Aaj ki returns
  Future<List<ReturnRecord>> getTodayReturns({String? workerId}) async {
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59)
        .toIso8601String();

    String where = 'returned_at BETWEEN ? AND ?';
    List<dynamic> args = [start, end];

    if (workerId != null) {
      where += ' AND worker_id = ?';
      args.add(workerId);
    }

    final rows = await _db.query('returns',
        where: where, whereArgs: args, orderBy: 'returned_at DESC');
    return rows.map(ReturnRecord.fromMap).toList();
  }

  /// Unsynced returns
  Future<List<ReturnRecord>> getUnsyncedReturns(String workerId) async {
    final rows = await _db.query('returns',
        where: 'is_synced = 0 AND worker_id = ?',
        whereArgs: [workerId],
        orderBy: 'returned_at ASC');
    return rows.map(ReturnRecord.fromMap).toList();
  }
}

// ══════════════════════════════════════════════════════════
//  7. WORKER KEY SERVICE — Keys manage karo
// ══════════════════════════════════════════════════════════
class WorkerKeyService {
  static WorkerKeyService? _instance;
  WorkerKeyService._();
  static WorkerKeyService get instance {
    _instance ??= WorkerKeyService._();
    return _instance!;
  }

  final _db = DatabaseService.instance;

  /// Naya worker key generate karo aur save karo
  Future<Result<WorkerKey>> createKey({
    required String name,
    required String phone,
  }) async {
    // Key generate karo — WRK-YEAR-NAMEXXX format
    final prefix = name.length >= 3
        ? name.substring(0, 3).toUpperCase()
        : name.toUpperCase().padRight(3, 'X');
    final year = DateTime.now().year;
    final rnd = (1000 + (DateTime.now().millisecond * 9) % 9000).toString();
    final key = 'WRK-$year-$prefix$rnd';

    final workerKey = WorkerKey(
      key: key,
      name: name,
      phone: phone,
    );

    try {
      // Server pe bhi create karo
      final session = AuthService.instance.currentSession;
      if (session != null) {
        final online = await ConnectivityService.instance.hasRealInternet;
        if (online) {
          await http.post(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/worker-keys'),
            headers: {
              'Authorization': 'Bearer ${session.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'key': key,
              'name': name,
              'phone': phone,
            }),
          ).timeout(const Duration(seconds: 10));
        }
      }

      // Local mein bhi save karo
      final id = await _db.insert('worker_keys', workerKey.toMap());
      final saved = WorkerKey(
        id: id,
        key: key,
        name: name,
        phone: phone,
      );

      debugPrint('[WorkerKey] Created: $key for $name');
      return Result.success(saved);
    } catch (e) {
      return Result.failure('Key create error: $e');
    }
  }

  /// Saari worker keys lo
  Future<List<WorkerKey>> getAllKeys() async {
    final rows =
        await _db.query('worker_keys', orderBy: 'created_at DESC');
    return rows.map(WorkerKey.fromMap).toList();
  }

  /// Key active/inactive toggle karo
  Future<Result<void>> toggleKey(int id, bool isActive) async {
    try {
      await _db.update(
        'worker_keys',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Key toggle error: $e');
    }
  }

  /// Key delete karo
  Future<Result<void>> deleteKey(int id) async {
    try {
      await _db.delete('worker_keys', where: 'id = ?', whereArgs: [id]);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Key delete error: $e');
    }
  }
}

// ══════════════════════════════════════════════════════════
//  8. EXCEL SERVICE — Inventory Excel import/export
// ══════════════════════════════════════════════════════════
class ExcelService {
  static ExcelService? _instance;
  ExcelService._();
  static ExcelService get instance {
    _instance ??= ExcelService._();
    return _instance!;
  }

  static const List<String> _headers = [
    'CRN Number',
    'Cloth Name',
    'Gender',
    'Size',
    'Unit',
    'Brand',
    'Price (₹)',
    'Quantity',
    'Added Date',
  ];

  /// Excel file ka path get karo
  Future<String> get _excelPath async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    return p.join(dir.path, AppConfig.excelFileName);
  }

  /// Jab bhi inventory change ho — Excel file update karo automatically
  Future<void> updateExcelFile() async {
    try {
      final items = await InventoryService.instance.getAllItems();
      await _writeExcel(items, await _excelPath);
      debugPrint('[Excel] File updated with ${items.length} items');
    } catch (e) {
      debugPrint('[Excel] Auto-update failed: $e');
    }
  }

  /// Excel file banao aur download folder mein save karo
  Future<Result<String>> exportInventory() async {
    try {
      // Permission check
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          return const Result.failure('Storage permission nahi mili.');
        }
      }

      final items = await InventoryService.instance.getAllItems();
      if (items.isEmpty) {
        return const Result.failure(
            'Inventory mein koi item nahi hai export ke liye.');
      }

      // Android downloads folder mein save karo
      String savePath;
      if (Platform.isAndroid) {
        savePath = '/storage/emulated/0/Download/${AppConfig.excelFileName}';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = p.join(dir.path, AppConfig.excelFileName);
      }

      await _writeExcel(items, savePath);

      debugPrint('[Excel] Exported to: $savePath');
      return Result.success(savePath);
    } catch (e) {
      return Result.failure('Export error: $e');
    }
  }

  Future<void> _writeExcel(List<InventoryItem> items, String path) async {
    final excel = Excel.createExcel();
    final sheet = excel['Inventory'];

    // Header row — bold style
    for (int i = 0; i < _headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(_headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D32F2F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Data rows
    for (int i = 0; i < items.length; i++) {
      final row = items[i].toExcelRow();
      for (int j = 0; j < row.length; j++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
        final val = row[j];
        if (val is double || val is int) {
          cell.value = DoubleCellValue(val.toDouble());
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
    }

    // Column width set karo
    sheet.setColumnWidth(0, 18);  // CRN
    sheet.setColumnWidth(1, 22);  // Name
    sheet.setColumnWidth(2, 12);  // Gender
    sheet.setColumnWidth(3, 8);   // Size
    sheet.setColumnWidth(4, 10);  // Unit
    sheet.setColumnWidth(5, 16);  // Brand
    sheet.setColumnWidth(6, 12);  // Price
    sheet.setColumnWidth(7, 12);  // Qty

    // File save karo
    final bytes = excel.save();
    if (bytes != null) {
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
  }

  /// Excel file import karo aur inventory mein add karo
  Future<Result<int>> importFromExcel() async {
    try {
      // File picker se file lo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) {
        return const Result.failure('Koi file select nahi ki.');
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return const Result.failure('File path nahi mila.');
      }

      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        return const Result.failure('Excel mein koi sheet nahi mili.');
      }

      int addedCount = 0;
      int skippedCount = 0;
      final errors = <String>[];

      // Row 1 se start karo (row 0 headers hai)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty || row[0] == null) continue;

        try {
          // Row se values nikalo
          final crn = row[0]?.value?.toString().trim() ?? '';
          final name = row[1]?.value?.toString().trim() ?? '';
          final gender = row[2]?.value?.toString().trim() ?? 'Men';
          final size = row[3]?.value?.toString().trim() ?? 'M';
          final unit = row[4]?.value?.toString().trim() ?? 'Piece';
          final brand = row[5]?.value?.toString().trim() ?? '';
          final priceStr = row[6]?.value?.toString().trim() ?? '0';
          final qtyStr = row[7]?.value?.toString().trim() ?? '0';

          if (crn.isEmpty || name.isEmpty) {
            skippedCount++;
            continue;
          }

          final item = InventoryItem(
            crn: crn,
            name: name,
            gender: gender,
            size: size,
            unit: unit,
            brand: brand,
            price: double.tryParse(priceStr) ?? 0,
            quantity: int.tryParse(qtyStr) ?? 0,
          );

          final addResult = await InventoryService.instance.addItem(item);
          if (addResult.isSuccess) {
            addedCount++;
          } else {
            skippedCount++;
          }
        } catch (e) {
          errors.add('Row ${i + 1}: $e');
        }
      }

      debugPrint(
          '[Excel] Import done: $addedCount added, $skippedCount skipped');

      if (addedCount == 0) {
        return Result.failure(
            'Koi item add nahi hua. File format check karein.\n'
            'Expected columns: CRN, Name, Gender, Size, Unit, Brand, Price, Qty');
      }

      return Result.success(addedCount);
    } catch (e) {
      return Result.failure('Import error: $e');
    }
  }
}

// ══════════════════════════════════════════════════════════
//  9. SYNC SERVICE — Worker data server pe push karo
// ══════════════════════════════════════════════════════════
class SyncService {
  static SyncService? _instance;
  SyncService._();
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  bool _isSyncing = false;

  /// Worker ka saara unsynced data server pe bhejo
  Future<Result<void>> syncWorkerData(UserSession session) async {
    if (_isSyncing) {
      return const Result.failure('Sync already chal rahi hai.');
    }

    if (!session.isWorker) return const Result.success(null);

    _isSyncing = true;
    debugPrint('[Sync] Starting sync for worker: ${session.name}');

    try {
      // Unsynced sales lo
      final unsyncedSales =
          await SalesService.instance.getUnsyncedSales(session.userId);

      // Unsynced returns lo
      final unsyncedReturns =
          await ReturnService.instance.getUnsyncedReturns(session.userId);

      if (unsyncedSales.isEmpty && unsyncedReturns.isEmpty) {
        debugPrint('[Sync] Kuch sync karna nahi hai.');
        _isSyncing = false;
        return const Result.success(null);
      }

      // Server pe batch send karo
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/worker/sync'),
            headers: {
              'Authorization': 'Bearer ${session.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'worker_id': session.userId,
              'worker_name': session.name,
              'sales': unsyncedSales.map((s) => s.toJson()).toList(),
              'returns': unsyncedReturns.map((r) => r.toJson()).toList(),
              'synced_at': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final db = await DatabaseService.instance.database;

        // Sales ko synced mark karo
        if (unsyncedSales.isNotEmpty) {
          final saleIds = unsyncedSales.map((s) => s.id).toList();
          await db.update(
            'sales',
            {'is_synced': 1},
            where:
                'id IN (${saleIds.map((_) => '?').join(',')})',
            whereArgs: saleIds,
          );
        }

        // Returns ko synced mark karo
        if (unsyncedReturns.isNotEmpty) {
          final retIds = unsyncedReturns.map((r) => r.id).toList();
          await db.update(
            'returns',
            {'is_synced': 1},
            where:
                'id IN (${retIds.map((_) => '?').join(',')})',
            whereArgs: retIds,
          );
        }

        debugPrint(
            '[Sync] Success: ${unsyncedSales.length} sales + ${unsyncedReturns.length} returns synced');
        _isSyncing = false;
        return const Result.success(null);
      } else {
        _isSyncing = false;
        return Result.failure(
            'Server sync failed: ${response.statusCode}');
      }
    } catch (e) {
      _isSyncing = false;
      return Result.failure('Sync error: $e');
    }
  }

  /// Logout ke baad worker ka synced local data delete karo
  Future<void> clearSyncedWorkerData(String workerId) async {
    final db = await DatabaseService.instance.database;

    // Sirf synced records delete karo
    await db.delete('sales',
        where: 'worker_id = ? AND is_synced = 1',
        whereArgs: [workerId]);

    await db.delete('returns',
        where: 'worker_id = ? AND is_synced = 1',
        whereArgs: [workerId]);

    debugPrint('[Sync] Local synced data cleared for worker: $workerId');
  }

  /// Internet aane pe auto-sync try karo
  void startAutoSync() {
    ConnectivityService.instance.onlineStatusStream.listen((isOnline) {
      if (isOnline) {
        final session = AuthService.instance.currentSession;
        if (session != null && session.isWorker) {
          debugPrint('[Sync] Internet aaya — auto sync try kar raha hai...');
          syncWorkerData(session);
        }
      }
    });
  }

  /// Pending sync count
  Future<int> getPendingSyncCount(String workerId) async {
    final sales =
        await SalesService.instance.getUnsyncedSales(workerId);
    final returns =
        await ReturnService.instance.getUnsyncedReturns(workerId);
    return sales.length + returns.length;
  }
}

// ══════════════════════════════════════════════════════════
//  10. APP INITIALIZER — App start hone pe ye call karo
// ══════════════════════════════════════════════════════════
class AppInitializer {
  /// main() mein runApp() se pehle ye call karo
  static Future<void> initialize() async {
    // Database initialize karo
    await DatabaseService.instance.database;
    debugPrint('[Init] Database ready');

    // Saved session load karo
    await AuthService.instance.loadSession();
    debugPrint('[Init] Session check done');

    // Auto sync listener start karo
    SyncService.instance.startAutoSync();
    debugPrint('[Init] Auto-sync listener started');

    debugPrint('[Init] App initialization complete ✓');
  }
}

// ══════════════════════════════════════════════════════════
//  main.dart mein ye changes karo:
// ══════════════════════════════════════════════════════════
//
//  import 'backend.dart';  // File ka name same rakho
//
//  void main() async {
//    WidgetsFlutterBinding.ensureInitialized();
//    await AppInitializer.initialize();  // <-- Ye add karo
//    SystemChrome.setSystemUIOverlayStyle(...);
//    runApp(const ClothingApp());
//  }
//
// ══════════════════════════════════════════════════════════
//  UI mein backend use karne ke examples:
// ══════════════════════════════════════════════════════════
//
//  // LOGIN SCREEN:
//  final result = await AuthService.instance.loginAdmin(
//    username: _userCtrl.text,
//    password: _passCtrl.text,
//  );
//  if (result.isSuccess) {
//    Navigator.pushReplacementNamed(context, '/admin-home');
//  } else {
//    showError(result.error!);
//  }
//
//  // WORKER LOGIN:
//  final result = await AuthService.instance.loginWorker(
//    workerKey: _keyCtrl.text,
//  );
//
//  // INVENTORY ADD:
//  final result = await InventoryService.instance.addItem(InventoryItem(
//    crn: 'CLT-2024-001',
//    name: 'Cotton Shirt',
//    gender: 'Men',
//    size: 'L',
//    unit: 'Piece',
//    brand: 'Arrow',
//    price: 850.0,
//    quantity: 50,
//  ));
//
//  // SELL ITEM:
//  final session = AuthService.instance.currentSession!;
//  final result = await SalesService.instance.sellItem(
//    crn: scannedCrn,
//    quantity: 2,
//    discount: 50.0,
//    worker: session,
//  );
//
//  // RETURN ITEM:
//  final result = await ReturnService.instance.returnItem(
//    crn: crnCtrl.text,
//    quantity: 1,
//    reason: 'Size issue',
//    worker: session,
//    refundAmount: 850.0,
//  );
//
//  // INVENTORY LIST:
//  final items = await InventoryService.instance.getAllItems(
//    gender: 'Men',          // optional filter
//    searchQuery: 'shirt',   // optional search
//  );
//
//  // TODAY'S SALES:
//  final sales = await SalesService.instance.getTodaySales(
//    workerId: session.userId,  // worker ke liye — admin ke liye null
//  );
//
//  // EXCEL EXPORT:
//  final result = await ExcelService.instance.exportInventory();
//
//  // EXCEL IMPORT:
//  final result = await ExcelService.instance.importFromExcel();
//  if (result.isSuccess) {
//    showMessage('${result.data} items imported!');
//  }
//
//  // LOGOUT:
//  final result = await AuthService.instance.logout();
//  if (result.isSuccess) {
//    Navigator.pushReplacementNamed(context, '/login');
//  } else {
//    showError(result.error!); // "Internet chahiye logout ke liye"
//  }
//
// ══════════════════════════════════════════════════════════
//  SERVER-SIDE API ENDPOINTS (Node.js / Python / PHP)
// ══════════════════════════════════════════════════════════
//
//  POST /api/admin/login       → { user_id, name, token }
//  POST /api/worker/login      → { worker_id, name, token }
//  POST /api/admin/worker-keys → Create worker key
//  GET  /api/inventory         → Full inventory list (worker ke liye)
//  POST /api/worker/sync       → { sales[], returns[] } receive karo
//
//  Agar apna server nahi hai to FIREBASE use karo:
//  - Authentication: Firebase Auth (admin/worker roles)
//  - Database: Firestore
//  - Worker keys: Firestore collection
//  - Sync: Firestore batch write
//  - http package ki jagah firebase_auth + cloud_firestore use karo
