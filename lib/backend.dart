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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
//  CONFIG
// ══════════════════════════════════════════════════════════
class AppConfig {
  // ═══════════════════════════════════════════════════════
  // ADMIN LOGIN — APK banate waqt yahan change karo
  // ═══════════════════════════════════════════════════════
  static const String adminUsername = 'admin';
  static const String adminPassword = 'admin123';
  static const String adminName     = 'Admin';

  static const String apiBaseUrl             = '';
  static const String excelFileName          = 'inventory.xlsx';
  static const int    lowStockLimit          = 5;
  static const int    tokenExpiryHours       = 24;
  static const int    autoSyncIntervalMinutes = 5;
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

  // Excel row se banao — order: Unit, Sub Unit(Size), Item, CRN, Gender, Brand, Price, Qty
  factory InventoryItem.fromExcelRow(List<dynamic> row) {
    return InventoryItem(
      unit: row[0]?.toString() ?? 'Piece',
      size: row[1]?.toString() ?? 'Free Size',
      name: row[2]?.toString() ?? '',
      crn: row[3]?.toString() ?? '',
      gender: row[4]?.toString() ?? 'Men',
      brand: row[5]?.toString() ?? '',
      price: double.tryParse(row[6]?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(row[7]?.toString() ?? '0') ?? 0,
    );
  }

  // Excel row ke liye — Unit, Sub Unit, Item ka structure taaki
  // import karte waqt Unit + Sub Unit wapas bane
  List<dynamic> toExcelRow() =>
      [unit, size, name, crn, gender, brand, price, quantity,
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
  final String paymentMethod;   // 'cod' ya 'online'
  final bool isCredit;          // true = udhari (customer ne abhi paisa nahi diya)
  final String? creditCustomer; // udhari hai to customer ka naam

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
    this.paymentMethod = 'cod',
    this.isCredit = false,
    this.creditCustomer,
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
        'payment_method': paymentMethod,
        'is_credit': isCredit ? 1 : 0,
        'credit_customer': creditCustomer,
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
        paymentMethod: (m['payment_method'] ?? 'cod') as String,
        isCredit: ((m['is_credit'] ?? 0) as int) == 1,
        creditCustomer: m['credit_customer'] as String?,
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
        'payment_method': paymentMethod,
        'is_credit': isCredit,
        'credit_customer': creditCustomer,
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

// ══════════════════════════════════════════════════════════
//  UDHARI (CREDIT) MODELS
// ══════════════════════════════════════════════════════════

// Ek customer ka udhari account
class CreditAccount {
  final int? id;
  final String customerName;
  final String phone;
  final DateTime createdAt;

  CreditAccount({
    this.id,
    required this.customerName,
    this.phone = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'customer_name': customerName,
        'phone': phone,
        'created_at': createdAt.toIso8601String(),
      };

  factory CreditAccount.fromMap(Map<String, dynamic> m) => CreditAccount(
        id: m['id'] as int?,
        customerName: m['customer_name'] as String,
        phone: (m['phone'] ?? '') as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// Udhari ledger ki ek entry — 'debit' = udhar diya (customer par charhi),
// 'credit' = payment mila (customer ne wapas kiya)
class CreditTransaction {
  final int? id;
  final int accountId;
  final String type; // 'debit' ya 'credit'
  final double amount;
  final String note;
  final String workerId;
  final String workerName;
  final DateTime txnDate;

  CreditTransaction({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.note = '',
    this.workerId = '',
    this.workerName = '',
    DateTime? txnDate,
  }) : txnDate = txnDate ?? DateTime.now();

  bool get isDebit => type == 'debit';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'account_id': accountId,
        'type': type,
        'amount': amount,
        'note': note,
        'worker_id': workerId,
        'worker_name': workerName,
        'txn_date': txnDate.toIso8601String(),
      };

  factory CreditTransaction.fromMap(Map<String, dynamic> m) => CreditTransaction(
        id: m['id'] as int?,
        accountId: m['account_id'] as int,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: (m['note'] ?? '') as String,
        workerId: (m['worker_id'] ?? '') as String,
        workerName: (m['worker_name'] ?? '') as String,
        txnDate: DateTime.parse(m['txn_date'] as String),
      );
}

// Ek customer ka summary — account + total udhari (balance)
class CreditSummary {
  final CreditAccount account;
  final double totalDebit;
  final double totalCredit;
  final DateTime? lastTxnDate;
  CreditSummary({required this.account, required this.totalDebit, required this.totalCredit, this.lastTxnDate});
  double get balance => totalDebit - totalCredit;
}

// Unit — parent category (jaise "Jeans", "T-Shirt"). Har unit ke andar
// multiple SUB-UNITS ho sakti hain (size ke hisaab se: S, M, L, 30, 32 etc).
// Pehle unit ke andar hi "sizes" comma-string mein store hoti thi jiski wajah se
// same naam ki unit dobara banane par purani REPLACE ho jaati thi. Ab Unit sirf
// naam+gender hai, aur har size apni alag InventorySubUnit row hai.
class InventoryUnit {
  final int? id;
  final String name;
  final String gender; // Men, Women, Kids, Unisex
  final DateTime createdAt;

  InventoryUnit({
    this.id,
    required this.name,
    this.gender = 'Men',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'gender': gender,
        // sizes/total_quantity/used_quantity columns purane version ke liye DB
        // mein defaults ke saath maujood hain, ab ye class unhe use nahi karti.
      };

  factory InventoryUnit.fromMap(Map<String, dynamic> m) => InventoryUnit(
        id: m['id'] as int?,
        name: m['name'] as String,
        gender: (m['gender'] ?? 'Men') as String,
      );
}

// Sub-Unit — ek Unit ke andar ek specific size/variant.
// Example: Unit "Jeans" (Men) → Sub-units: "30", "32", "34"
class InventorySubUnit {
  final int? id;
  final int unitId;
  final String size;
  int totalQuantity; // bulk stock counter is size ke liye (display purpose)
  final DateTime createdAt;

  InventorySubUnit({
    this.id,
    required this.unitId,
    required this.size,
    this.totalQuantity = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'unit_id': unitId,
        'size': size,
        'total_quantity': totalQuantity,
        'created_at': createdAt.toIso8601String(),
      };

  factory InventorySubUnit.fromMap(Map<String, dynamic> m) => InventorySubUnit(
        id: m['id'] as int?,
        unitId: m['unit_id'] as int,
        size: m['size'] as String,
        totalQuantity: (m['total_quantity'] ?? 0) as int,
        createdAt: DateTime.parse(m['created_at'] as String),
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
      version: 3,
      onCreate: _createTables,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // gender aur sizes columns add karo
          try { await db.execute('ALTER TABLE inventory_units ADD COLUMN gender TEXT DEFAULT "Men"'); } catch (_) {}
          try { await db.execute('ALTER TABLE inventory_units ADD COLUMN sizes TEXT DEFAULT "S,M,L,XL"'); } catch (_) {}
          debugPrint('[DB] Migrated to version 2');
        }
        if (oldV < 3) {
          // Sub-units table — har unit ke andar size-wise entries
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventory_sub_units (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              unit_id        INTEGER NOT NULL,
              size           TEXT NOT NULL,
              total_quantity INTEGER NOT NULL DEFAULT 0,
              created_at     TEXT NOT NULL,
              UNIQUE(unit_id, size),
              FOREIGN KEY(unit_id) REFERENCES inventory_units(id) ON DELETE CASCADE
            )
          ''');

          // Purani units ki comma-separated "sizes" ko sub-unit rows mein todo,
          // taaki purana data bhi naye system mein sahi se dikhe.
          try {
            final oldUnits = await db.query('inventory_units');
            for (final u in oldUnits) {
              final unitId = u['id'] as int;
              final sizesStr = (u['sizes'] ?? '') as String;
              final sizeList = sizesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
              for (final s in sizeList) {
                await db.insert('inventory_sub_units', {
                  'unit_id': unitId,
                  'size': s,
                  'total_quantity': 0,
                  'created_at': DateTime.now().toIso8601String(),
                }, conflictAlgorithm: ConflictAlgorithm.ignore);
              }
            }
          } catch (e) {
            debugPrint('[DB] Old sizes migration skipped: $e');
          }

          // Sales table mein payment method + udhari columns
          try { await db.execute("ALTER TABLE sales ADD COLUMN payment_method TEXT DEFAULT 'cod'"); } catch (_) {}
          try { await db.execute('ALTER TABLE sales ADD COLUMN is_credit INTEGER DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE sales ADD COLUMN credit_customer TEXT'); } catch (_) {}

          // Udhari (credit) ledger tables
          await db.execute('''
            CREATE TABLE IF NOT EXISTS credit_accounts (
              id            INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_name TEXT NOT NULL,
              phone         TEXT NOT NULL DEFAULT '',
              created_at    TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS credit_transactions (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              account_id   INTEGER NOT NULL,
              type         TEXT NOT NULL,
              amount       REAL NOT NULL,
              note         TEXT NOT NULL DEFAULT '',
              worker_id    TEXT NOT NULL DEFAULT '',
              worker_name  TEXT NOT NULL DEFAULT '',
              txn_date     TEXT NOT NULL,
              FOREIGN KEY(account_id) REFERENCES credit_accounts(id) ON DELETE CASCADE
            )
          ''');
          debugPrint('[DB] Migrated to version 3 (sub-units + udhari ledger)');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Inventory Units table
    await db.execute('''
      CREATE TABLE inventory_units (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL UNIQUE,
        gender        TEXT NOT NULL DEFAULT 'Men',
        sizes         TEXT NOT NULL DEFAULT 'S,M,L,XL',
        total_quantity INTEGER NOT NULL DEFAULT 0,
        used_quantity  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Inventory Sub-Units table — har unit ke andar size-wise entries
    await db.execute('''
      CREATE TABLE inventory_sub_units (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id        INTEGER NOT NULL,
        size           TEXT NOT NULL,
        total_quantity INTEGER NOT NULL DEFAULT 0,
        created_at     TEXT NOT NULL,
        UNIQUE(unit_id, size),
        FOREIGN KEY(unit_id) REFERENCES inventory_units(id) ON DELETE CASCADE
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
        is_synced     INTEGER NOT NULL DEFAULT 0,
        payment_method  TEXT NOT NULL DEFAULT 'cod',
        is_credit       INTEGER NOT NULL DEFAULT 0,
        credit_customer TEXT
      )
    ''');

    // Udhari (credit) ledger tables
    await db.execute('''
      CREATE TABLE credit_accounts (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        phone         TEXT NOT NULL DEFAULT '',
        created_at    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE credit_transactions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id   INTEGER NOT NULL,
        type         TEXT NOT NULL,
        amount       REAL NOT NULL,
        note         TEXT NOT NULL DEFAULT '',
        worker_id    TEXT NOT NULL DEFAULT '',
        worker_name  TEXT NOT NULL DEFAULT '',
        txn_date     TEXT NOT NULL,
        FOREIGN KEY(account_id) REFERENCES credit_accounts(id) ON DELETE CASCADE
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
//  3. AUTH SERVICE — Google Sheet se Login
// ══════════════════════════════════════════════════════════
class AuthService {
  static AuthService? _instance;
  AuthService._();
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  static const _sessionKey   = 'user_session';
  static const _loginTimeKey = 'login_time';

  // Google Apps Script URL
  static const _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwHepJisSRih3z1cowr2QGlQ6iBCVfk1Y0UFhER2qX0rjWHbKtQ7hqt0hivWD8r0fleyA/exec';

  UserSession? _currentSession;
  UserSession? get currentSession => _currentSession;
  bool get isLoggedIn => _currentSession != null;

  /// App start hote hi saved session check karo — agar login ko
  /// AppConfig.tokenExpiryHours se zyada time ho gaya hai to session
  /// expire kar do taaki dubara login mangna pade (pehle ye check nahi
  /// hota tha isliye app kitne bhi din band rehne ke baad bhi seedha khul jaata tha).
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString(_sessionKey);
    final loginTimeStr = prefs.getString(_loginTimeKey);

    if (json == null) return;

    try {
      if (loginTimeStr == null) {
        // Purana data jisme login time save hi nahi hua — safe side pe
        // session clear karo, dubara login mangega.
        await _clearSession();
        return;
      }

      final loginTime = DateTime.parse(loginTimeStr);
      final expiresAt = loginTime.add(Duration(hours: AppConfig.tokenExpiryHours));

      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('[Auth] Session expired (login tha: $loginTime) — dubara login mangega.');
        await _clearSession();
        return;
      }

      _currentSession = UserSession.fromMap(
          jsonDecode(json) as Map<String, dynamic>);
      debugPrint('[Auth] Session loaded: ${_currentSession!.name}');
    } catch (_) {
      await _clearSession();
    }
  }

  /// Sheet se users fetch karo
  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    try {
      // http.get redirects automatically follow karta hai
      final res = await http
          .get(Uri.parse(_scriptUrl))
          .timeout(const Duration(seconds: 20));

      debugPrint('[Auth] Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        // Response clean karo — kabhi kabhi HTML wrapper aata hai
        String body = res.body.trim();

        // Agar JSON nahi hai to skip
        if (!body.startsWith('{') && !body.startsWith('[')) {
          debugPrint('[Auth] Non-JSON response: ${body.substring(0, body.length.clamp(0, 100))}');
          return [];
        }

        final parsed = jsonDecode(body);
        if (parsed is Map && parsed.containsKey('data')) {
          return (parsed['data'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        } else if (parsed is List) {
          return parsed.map((e) => e as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {
      debugPrint('[Auth] Fetch error: $e');
    }
    return [];
  }

  /// Admin login
  Future<Result<UserSession>> loginAdmin({
    required String username,
    required String password,
  }) async {
    try {
      final users = await _fetchUsers();
      if (users.isEmpty) {
        return const Result.failure(
            'Sheet se data nahi aaya.\nInternet check karo.');
      }

      final match = users.where((u) {
        return (u['username'] ?? '').toString().trim().toLowerCase()
                == username.trim().toLowerCase() &&
            (u['password'] ?? '').toString().trim() == password.trim() &&
            (u['role']     ?? '').toString().trim().toLowerCase() == 'admin' &&
            (u['is_active']?? 'true').toString().trim().toLowerCase() == 'true';
      }).toList();

      if (match.isEmpty) {
        return const Result.failure('Username ya password galat hai.');
      }

      final session = UserSession(
        userId: 'admin_${match.first['row_id'] ?? 1}',
        name: (match.first['name'] ?? 'Admin').toString(),
        role: 'admin',
        token: 'token_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _saveSession(session);
      return Result.success(session);
    } catch (e) {
      return Result.failure('Login error: $e');
    }
  }

  /// Worker login — SQLite worker_keys table se check karo
  Future<Result<UserSession>> loginWorker({required String workerKey}) async {
    try {
      final key = workerKey.trim().toUpperCase();

      // SQLite mein worker_keys check karo
      final rows = await DatabaseService.instance.query(
        'worker_keys',
        where: 'key = ? AND is_active = 1',
        whereArgs: [key],
      );

      if (rows.isEmpty) {
        return const Result.failure(
            'Worker key galat hai ya inactive hai.\nAdmin se contact karein.');
      }

      final w = WorkerKey.fromMap(rows.first);
      final session = UserSession(
        userId: 'worker_${w.id}',
        name: w.name,
        role: 'worker',
        token: 'local_${DateTime.now().millisecondsSinceEpoch}',
        workerKey: key,
      );
      await _saveSession(session);
      debugPrint('[Auth] Worker login: ${w.name}');
      return Result.success(session);
    } catch (e) {
      return Result.failure('Login error: $e');
    }
  }

  /// Naya account — Google Sheet mein save karo
  Future<Result<void>> createAccount({
    required String username,
    required String password,
    required String name,
    required String role,
    String workerKey = '',
  }) async {
    if (username.trim().isEmpty || name.trim().isEmpty) {
      return const Result.failure('Saari fields bharo.');
    }
    try {
      // Duplicate check
      final users = await _fetchUsers();
      final exists = users.any((u) =>
          (u['username'] ?? '').toString().trim().toLowerCase() ==
          username.trim().toLowerCase());
      if (exists) {
        return const Result.failure('Ye username pehle se exist karta hai.');
      }

      // Sheet mein POST karo
      final res = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode({
          'row': [
            username.trim(),
            password.trim(),
            role.trim().toLowerCase(),
            name.trim(),
            workerKey.trim().toUpperCase(),
            'true',
          ]
        }),
      ).timeout(const Duration(seconds: 20));

      debugPrint('[Auth] Create account response: ${res.statusCode} ${res.body}');

      // 2xx ya 3xx = success (Google Script 302 redirect karta hai)
      if (res.statusCode >= 200 && res.statusCode < 400) {
        return const Result.success(null);
      }
      return Result.failure('Save error: ${res.statusCode}');
    } catch (e) {
      return Result.failure('Account error: $e');
    }
  }

  Future<Result<void>> logout() async {
    await _clearSession();
    return const Result.success(null);
  }

  Future<void> _saveSession(UserSession s) async {
    _currentSession = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(s.toMap()));
    await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());
  }

  Future<void> _clearSession() async {
    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_loginTimeKey);
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

  // ── Units + Sub-Units ──────────────────────────────────

  /// Unit banao (ya agar naam se already exist karti hai to wahi use karo),
  /// aur diye gaye size(s) ko us unit ke SUB-UNIT ke roop mein add karo.
  /// Isse same naam ki unit dobara banane par purani REPLACE nahi hoti —
  /// naya size sirf ek nayi sub-unit ban kar existing unit ke andar jud jaata hai.
  ///
  /// [sizesInput] comma se alag multiple sizes bhi ho sakti hain: "S,M,L"
  Future<Result<InventoryUnit>> addOrUpdateUnit({
    required String name,
    required String gender,
    required String sizesInput,
    int quantityPerSize = 0,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return const Result.failure('Unit naam daalo!');

    final sizeList = sizesInput
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sizeList.isEmpty) return const Result.failure('Kam se kam ek size daalo!');

    try {
      final db = await _db.database;
      int unitId;

      // Existing unit dhundho (naam case-insensitive match)
      final existing = await db.query('inventory_units',
          where: 'LOWER(name) = ?', whereArgs: [cleanName.toLowerCase()]);

      if (existing.isNotEmpty) {
        unitId = existing.first['id'] as int;
        // Gender latest wale se update kar do (display ke liye)
        await db.update('inventory_units', {'gender': gender},
            where: 'id = ?', whereArgs: [unitId]);
      } else {
        unitId = await db.insert('inventory_units', {'name': cleanName, 'gender': gender});
      }

      // Har size ke liye sub-unit upsert karo
      for (final size in sizeList) {
        final subExisting = await db.query('inventory_sub_units',
            where: 'unit_id = ? AND LOWER(size) = ?',
            whereArgs: [unitId, size.toLowerCase()]);

        if (subExisting.isNotEmpty) {
          // Sub-unit pehle se hai — quantity add kar do, replace nahi
          final subId = subExisting.first['id'] as int;
          final currentQty = subExisting.first['total_quantity'] as int;
          await db.update('inventory_sub_units',
              {'total_quantity': currentQty + quantityPerSize},
              where: 'id = ?', whereArgs: [subId]);
        } else {
          await db.insert('inventory_sub_units', {
            'unit_id': unitId,
            'size': size,
            'total_quantity': quantityPerSize,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      final savedRow = (await db.query('inventory_units', where: 'id = ?', whereArgs: [unitId])).first;
      debugPrint('[Inventory] Unit "$cleanName" ready with sizes: ${sizeList.join(", ")}');
      return Result.success(InventoryUnit.fromMap(savedRow));
    } catch (e) {
      return Result.failure('Unit save error: $e');
    }
  }

  /// Saari units lo
  Future<List<InventoryUnit>> getAllUnits() async {
    final rows = await _db.query('inventory_units', orderBy: 'name ASC');
    return rows.map(InventoryUnit.fromMap).toList();
  }

  /// Ek unit ki saari sub-units (sizes) lo
  Future<List<InventorySubUnit>> getSubUnitsForUnit(int unitId) async {
    final rows = await _db.query('inventory_sub_units',
        where: 'unit_id = ?', whereArgs: [unitId], orderBy: 'size ASC');
    return rows.map(InventorySubUnit.fromMap).toList();
  }

  /// Saari units + unki sub-units ek saath lo (list screens ke liye efficient)
  Future<Map<int, List<InventorySubUnit>>> getSubUnitsGroupedByUnit() async {
    final rows = await _db.query('inventory_sub_units', orderBy: 'size ASC');
    final map = <int, List<InventorySubUnit>>{};
    for (final r in rows) {
      final su = InventorySubUnit.fromMap(r);
      map.putIfAbsent(su.unitId, () => []).add(su);
    }
    return map;
  }

  // ── Inventory Items ────────────────────────────────────

  /// Naya inventory item add karo
  /// Excel bhi automatically update hoti hai (silent=true karne par bulk
  /// import ke waqt har row par Excel rewrite nahi hoti — sirf end mein ek baar)
  Future<Result<InventoryItem>> addItem(InventoryItem item, {bool silent = false}) async {
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

      // Excel file automatically update karo (bulk import ke waqt skip karo)
      if (!silent) await ExcelService.instance.updateExcelFile();

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
    String paymentMethod = 'cod',
    bool isCredit = false,
    String? creditCustomer,
  }) async {
    if (isCredit && (creditCustomer == null || creditCustomer.trim().isEmpty)) {
      return const Result.failure('Udhari ke liye customer ka naam daalo.');
    }
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
          paymentMethod: paymentMethod,
          isCredit: isCredit,
          creditCustomer: isCredit ? creditCustomer!.trim() : null,
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
          paymentMethod: sale.paymentMethod,
          isCredit: sale.isCredit,
          creditCustomer: sale.creditCustomer,
        );
      });

      // Udhari hai to customer ke credit account mein debit chadhao
      if (isCredit) {
        await CreditService.instance.addDebit(
          customerName: creditCustomer!.trim(),
          amount: totalAmount,
          note: '${item.name} x$quantity (CRN: $crn)',
          worker: worker,
        );
      }

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
//  6B. CREDIT SERVICE — Udhari ledger (customer ka udhar)
// ══════════════════════════════════════════════════════════
class CreditService {
  static CreditService? _instance;
  CreditService._();
  static CreditService get instance {
    _instance ??= CreditService._();
    return _instance!;
  }

  final _db = DatabaseService.instance;

  /// Customer naam se account dhundho, nahi hai to naya banao
  Future<int> _getOrCreateAccountId(String customerName, {String phone = ''}) async {
    final db = await _db.database;
    final name = customerName.trim();
    final existing = await db.query('credit_accounts',
        where: 'LOWER(customer_name) = ?', whereArgs: [name.toLowerCase()]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return db.insert('credit_accounts', {
      'customer_name': name,
      'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Udhar sale hui — customer ke account mein DEBIT (udhari badhao)
  Future<Result<void>> addDebit({
    required String customerName,
    required double amount,
    String note = '',
    UserSession? worker,
  }) async {
    if (customerName.trim().isEmpty) return const Result.failure('Customer naam daalo.');
    if (amount <= 0) return const Result.failure('Amount 0 se zyada hona chahiye.');
    try {
      final accountId = await _getOrCreateAccountId(customerName);
      await _db.insert('credit_transactions', CreditTransaction(
        accountId: accountId,
        type: 'debit',
        amount: amount,
        note: note,
        workerId: worker?.userId ?? '',
        workerName: worker?.name ?? '',
      ).toMap());
      debugPrint('[Credit] Udhar diya: $customerName ₹$amount');
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Udhari save error: $e');
    }
  }

  /// Customer se payment mila — CREDIT (udhari kam karo)
  Future<Result<void>> receivePayment({
    required int accountId,
    required double amount,
    String note = '',
    UserSession? worker,
  }) async {
    if (amount <= 0) return const Result.failure('Amount 0 se zyada hona chahiye.');
    try {
      await _db.insert('credit_transactions', CreditTransaction(
        accountId: accountId,
        type: 'credit',
        amount: amount,
        note: note.trim().isEmpty ? 'Payment received' : note,
        workerId: worker?.userId ?? '',
        workerName: worker?.name ?? '',
      ).toMap());
      debugPrint('[Credit] Payment mila: account #$accountId ₹$amount');
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Payment save error: $e');
    }
  }

  /// Saare customers unke total udhari balance ke saath
  Future<List<CreditSummary>> getAllSummaries() async {
    final db = await _db.database;
    final accounts = await db.query('credit_accounts', orderBy: 'customer_name ASC');
    final summaries = <CreditSummary>[];
    for (final a in accounts) {
      final accountId = a['id'] as int;
      final txns = await db.query('credit_transactions',
          where: 'account_id = ?', whereArgs: [accountId], orderBy: 'txn_date DESC');
      double debit = 0, credit = 0;
      DateTime? last;
      for (final t in txns) {
        final amt = (t['amount'] as num).toDouble();
        if (t['type'] == 'debit') { debit += amt; } else { credit += amt; }
        final d = DateTime.parse(t['txn_date'] as String);
        if (last == null || d.isAfter(last)) last = d;
      }
      summaries.add(CreditSummary(
        account: CreditAccount.fromMap(a),
        totalDebit: debit,
        totalCredit: credit,
        lastTxnDate: last,
      ));
    }
    // Sabse zyada udhari wale upar
    summaries.sort((a, b) => b.balance.compareTo(a.balance));
    return summaries;
  }

  /// Ek account ki saari date-wise transactions
  Future<List<CreditTransaction>> getTransactions(int accountId) async {
    final rows = await _db.query('credit_transactions',
        where: 'account_id = ?', whereArgs: [accountId], orderBy: 'txn_date DESC');
    return rows.map(CreditTransaction.fromMap).toList();
  }

  /// Sab customers ka total pending udhari (dashboard summary ke liye)
  Future<double> getTotalOutstanding() async {
    final summaries = await getAllSummaries();
    return summaries.fold<double>(0, (s, c) => s + c.balance);
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
    String? customKey,
  }) async {
    final key = customKey ??
        () {
          final prefix = name.length >= 3
              ? name.substring(0, 3).toUpperCase()
              : name.toUpperCase().padRight(3, 'X');
          final year = DateTime.now().year;
          final rnd = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
          return 'WRK-$year-$prefix$rnd';
        }();

    final workerKey = WorkerKey(key: key, name: name, phone: phone);

    try {
      final id = await _db.insert('worker_keys', workerKey.toMap());
      final saved = WorkerKey(id: id, key: key, name: name, phone: phone);
      debugPrint('[WorkerKey] Created: $key for $name');
      return Result.success(saved);
    } catch (e) {
      if (e.toString().contains('UNIQUE')) {
        return const Result.failure('Ye key pehle se exist karti hai.');
      }
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
    'Unit',
    'Sub Unit (Size)',
    'Item Name',
    'CRN Number',
    'Gender',
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
    sheet.setColumnWidth(0, 14);  // Unit
    sheet.setColumnWidth(1, 14);  // Sub Unit (Size)
    sheet.setColumnWidth(2, 22);  // Item Name
    sheet.setColumnWidth(3, 18);  // CRN
    sheet.setColumnWidth(4, 12);  // Gender
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // bytes directly lo — path issue avoid karo
      );

      if (result == null || result.files.isEmpty) {
        return const Result.failure('Koi file select nahi ki.');
      }

      // Bytes directly lo (path null ho sakta hai on some devices)
      Uint8List? bytes;
      if (result.files.first.bytes != null) {
        bytes = result.files.first.bytes!;
      } else if (result.files.first.path != null) {
        bytes = await File(result.files.first.path!).readAsBytes();
      } else {
        return const Result.failure('File read nahi ho saki.');
      }

      final excel = Excel.decodeBytes(bytes);

      // "inventory" sheet dhundho, nahi mila to pehli sheet lo
      Sheet? sheet;
      if (excel.tables.containsKey('inventory')) {
        sheet = excel.tables['inventory'];
      } else {
        // Pehli valid sheet lo
        for (final key in excel.tables.keys) {
          if ((excel.tables[key]?.rows.length ?? 0) > 1) {
            sheet = excel.tables[key];
            break;
          }
        }
      }

      if (sheet == null || sheet.rows.isEmpty) {
        return const Result.failure(
            'Excel mein "inventory" sheet nahi mili.\n'
            'Sheet ka naam "inventory" rakho.');
      }

      debugPrint('[Excel] Sheet rows: ${sheet.rows.length}');

      // ── Header row padhkar columns ko naam se map karo ──
      // Isse purani ("CRN, Name, Gender, Size, Unit...") aur nayi
      // ("Unit, Sub Unit, Item...") dono tarah ki files sahi se import hoti hain.
      final headerRow = sheet.rows.first;
      String headerAt(int c) {
        if (c >= headerRow.length) return '';
        return (headerRow[c]?.value?.toString() ?? '').trim().toLowerCase();
      }

      final Map<String, int> col = {};
      for (int c = 0; c < headerRow.length; c++) {
        final h = headerAt(c);
        if (h.isEmpty) continue;
        if (h.contains('unit') && h.contains('sub')) { col['unit_sub'] = c; }
        else if (h.contains('crn') || h.contains('barcode')) { col['crn'] = c; }
        else if (h.contains('item') || h.contains('cloth') || h == 'name' || h.contains('name')) { col['name'] = c; }
        else if (h.contains('gender')) { col['gender'] = c; }
        else if (h.contains('brand')) { col['brand'] = c; }
        else if (h.contains('price')) { col['price'] = c; }
        else if (h.contains('qty') || h.contains('quantity')) { col['quantity'] = c; }
        else if (h == 'unit' || (h.contains('unit') && !col.containsKey('unit'))) { col['unit'] = c; }
        else if (h.contains('size')) { col['unit_sub'] = c; }
      }

      // Fallback: agar headers pehchan mein nahi aaye to naye standard order pe
      // gir jaao — Unit, Sub Unit, Item, CRN, Gender, Brand, Price, Qty
      col.putIfAbsent('unit', () => 0);
      col.putIfAbsent('unit_sub', () => 1);
      col.putIfAbsent('name', () => 2);
      col.putIfAbsent('crn', () => 3);
      col.putIfAbsent('gender', () => 4);
      col.putIfAbsent('brand', () => 5);
      col.putIfAbsent('price', () => 6);
      col.putIfAbsent('quantity', () => 7);

      int addedCount = 0;
      int skippedCount = 0;

      // Row 1 se start (row 0 = headers)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        // Safe value nikalo
        String safeVal(int? c, String fallback) {
          if (c == null) return fallback;
          try {
            if (c >= row.length) return fallback;
            final cell = row[c];
            if (cell == null) return fallback;
            final val = cell.value;
            if (val == null) return fallback;
            return val.toString().trim();
          } catch (_) {
            return fallback;
          }
        }

        final crn  = safeVal(col['crn'], '');
        final name = safeVal(col['name'], '');

        if (crn.isEmpty || name.isEmpty) {
          skippedCount++;
          continue;
        }

        final unitName = safeVal(col['unit'], 'Piece');
        final subUnit  = safeVal(col['unit_sub'], 'Free Size');
        final gender   = safeVal(col['gender'], 'Men');
        final quantity = int.tryParse(safeVal(col['quantity'], '0')) ?? 0;

        try {
          final item = InventoryItem(
            crn:      crn.toUpperCase(),
            name:     name,
            gender:   gender,
            size:     subUnit,
            unit:     unitName,
            brand:    safeVal(col['brand'], '-'),
            price:    double.tryParse(safeVal(col['price'], '0')) ?? 0,
            quantity: quantity,
          );

          // Pehle Unit + Sub Unit ready karo — isi se app mein Inventory Detail
          // aur Worker Manual Search mein ye item dikhna shuru hota hai.
          await InventoryService.instance.addOrUpdateUnit(
            name: unitName,
            gender: gender,
            sizesInput: subUnit,
            quantityPerSize: quantity,
          );

          final r = await InventoryService.instance.addItem(item, silent: true);
          if (r.isSuccess) { addedCount++; }
          else { skippedCount++; }
        } catch (e) {
          debugPrint('[Excel] Row $i error: $e');
          skippedCount++;
        }
      }

      // Ek hi baar mein Excel file refresh karo (har row par nahi)
      await updateExcelFile();

      debugPrint('[Excel] Import: $addedCount added, $skippedCount skipped');

      if (addedCount == 0) {
        return Result.failure(
            'Koi item add nahi hua.\n'
            'Check karo:\n'
            '• Sheet naam "inventory" hai?\n'
            '• Columns: Unit, Sub Unit, Item Name, CRN, Gender, Brand, Price, Qty');
      }

      return Result.success(addedCount);
    } catch (e) {
      debugPrint('[Excel] Import error: $e');
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
