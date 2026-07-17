// ╔══════════════════════════════════════════════════════════════════╗
// ║       KIRANA STORE MANAGEMENT SYSTEM — BACKEND (backend.dart)       ║
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
  final String crn;        // Optional ab — barcode na ho to blank ho sakta hai
  final String name;       // Optional ab — blank ho to displayName auto-derive hoga
  final String category;     // Grocery / Dairy / Snacks / Beverages / Household / etc.
  final String packSize;
  final String unit;
  final int? subUnitId;    // Kis block (Unit+Pack Size) ka hissa hai — stock yahi se judi hai
  final String brand;
  final double price;
  int quantity;            // is batch/tag mein kitne piece abhi bache hain
  final DateTime createdAt;
  DateTime updatedAt;

  InventoryItem({
    this.id,
    this.crn = '',
    this.name = '',
    required this.category,
    required this.packSize,
    required this.unit,
    this.subUnitId,
    this.brand = '-',
    this.price = 0,
    required this.quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Naam nahi diya to Unit+Pack Size se ek readable naam ban jata hai
  String get displayName => name.trim().isEmpty ? '$unit $packSize' : name;
  // Barcode nahi diya to ye dikhega
  String get displayCrn => crn.trim().isEmpty ? 'No Barcode' : crn;
  bool get hasBarcode => crn.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'crn': crn,
        'name': name,
        'category': category,
        'packSize': packSize,
        'unit': unit,
        'sub_unit_id': subUnitId,
        'brand': brand,
        'price': price,
        'quantity': quantity,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InventoryItem.fromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'] as int?,
        crn: (m['crn'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        category: m['category'] as String,
        packSize: m['packSize'] as String,
        unit: m['unit'] as String,
        subUnitId: m['sub_unit_id'] as int?,
        brand: (m['brand'] ?? '-') as String,
        price: (m['price'] as num).toDouble(),
        quantity: m['quantity'] as int,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  // Excel row se banao — order: Unit, Sub Unit(Pack Size), Item, CRN, Category, Brand, Price, Qty
  factory InventoryItem.fromExcelRow(List<dynamic> row) {
    return InventoryItem(
      unit: row[0]?.toString() ?? 'Piece',
      packSize: row[1]?.toString() ?? 'Loose',
      name: row[2]?.toString() ?? '',
      crn: row[3]?.toString() ?? '',
      category: row[4]?.toString() ?? 'Grocery',
      brand: row[5]?.toString() ?? '',
      price: double.tryParse(row[6]?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(row[7]?.toString() ?? '0') ?? 0,
    );
  }

  // Excel row ke liye — Unit, Sub Unit, Item ka structure taaki
  // import karte waqt Unit + Sub Unit wapas bane
  List<dynamic> toExcelRow() =>
      [unit, packSize, name, crn, category, brand, price, quantity,
       createdAt.toIso8601String()];
}

// Ek "Complete Sell" ka poora checkout — isme 1 ya zyada items ho sakte hain.
// Pehle har item apni alag row ban kar dikhta tha jo confusing tha;
// ab poora checkout ek hi Session hai, jiske andar SaleRecord lines hain.
class SaleSession {
  final int? id;
  final String workerId;
  final String workerName;
  final double totalAmount;
  final int itemCount;
  final String paymentMethod;
  final bool isCredit;
  final String? creditCustomer;
  final DateTime soldAt;
  bool isSynced;

  SaleSession({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.totalAmount,
    required this.itemCount,
    this.paymentMethod = 'cod',
    this.isCredit = false,
    this.creditCustomer,
    DateTime? soldAt,
    this.isSynced = false,
  }) : soldAt = soldAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'worker_id': workerId,
        'worker_name': workerName,
        'total_amount': totalAmount,
        'item_count': itemCount,
        'payment_method': paymentMethod,
        'is_credit': isCredit ? 1 : 0,
        'credit_customer': creditCustomer,
        'sold_at': soldAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  factory SaleSession.fromMap(Map<String, dynamic> m) => SaleSession(
        id: m['id'] as int?,
        workerId: m['worker_id'] as String,
        workerName: m['worker_name'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        itemCount: m['item_count'] as int,
        paymentMethod: (m['payment_method'] ?? 'cod') as String,
        isCredit: ((m['is_credit'] ?? 0) as int) == 1,
        creditCustomer: m['credit_customer'] as String?,
        soldAt: DateTime.parse(m['sold_at'] as String),
        isSynced: (m['is_synced'] as int) == 1,
      );
}

class SaleRecord {
  final int? id;
  final int? sessionId;   // Kis Sale Session (checkout) ka hissa hai
  final String crn;
  final String itemName;
  final String itemCategory;
  final String itemPackSize;
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
    this.sessionId,
    required this.crn,
    required this.itemName,
    required this.itemCategory,
    required this.itemPackSize,
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
        'session_id': sessionId,
        'crn': crn,
        'item_name': itemName,
        'item_category': itemCategory,
        'item_pack_size': itemPackSize,
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
        sessionId: m['session_id'] as int?,
        crn: m['crn'] as String,
        itemName: m['item_name'] as String,
        itemCategory: m['item_category'] as String,
        itemPackSize: m['item_pack_size'] as String,
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
        'item_category': itemCategory,
        'item_pack_size': itemPackSize,
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

// Unit — parent category (jaise "Namak", "Biscuit"). Har unit ke andar
// multiple SUB-UNITS ho sakti hain (packSize ke hisaab se: S, M, L, 30, 32 etc).
// Pehle unit ke andar hi "sizes" comma-string mein store hoti thi jiski wajah se
// same naam ki unit dobara banane par purani REPLACE ho jaati thi. Ab Unit sirf
// naam+category hai, aur har packSize apni alag InventorySubUnit row hai.
class InventoryUnit {
  final int? id;
  final String name;
  final String category; // Grocery, Dairy, Snacks, Beverages, Household, etc.
  final DateTime createdAt;

  InventoryUnit({
    this.id,
    required this.name,
    this.category = 'Grocery',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        // sizes/total_quantity/used_quantity columns purane version ke liye DB
        // mein defaults ke saath maujood hain, ab ye class unhe use nahi karti.
      };

  factory InventoryUnit.fromMap(Map<String, dynamic> m) => InventoryUnit(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: (m['category'] ?? 'Grocery') as String,
      );
}

// Sub-Unit — ek Unit ke andar ek specific packSize/variant.
// Example: Unit "Namak" (Grocery) → Sub-units: "500g", "1kg"
class InventorySubUnit {
  final int? id;
  final int unitId;
  final String packSize;
  int totalQuantity; // ASLI stock count is packSize (block) ke liye
  int lowStockThreshold; // is se kam/barabar ho to "low stock" alert
  final DateTime createdAt;

  InventorySubUnit({
    this.id,
    required this.unitId,
    required this.packSize,
    this.totalQuantity = 0,
    this.lowStockThreshold = 5,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOutOfStock => totalQuantity <= 0;
  bool get isLowStock => totalQuantity > 0 && totalQuantity <= lowStockThreshold;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'unit_id': unitId,
        'packSize': packSize,
        'total_quantity': totalQuantity,
        'low_stock_threshold': lowStockThreshold,
        'created_at': createdAt.toIso8601String(),
      };

  factory InventorySubUnit.fromMap(Map<String, dynamic> m) => InventorySubUnit(
        id: m['id'] as int?,
        unitId: m['unit_id'] as int,
        packSize: m['packSize'] as String,
        totalQuantity: (m['total_quantity'] ?? 0) as int,
        lowStockThreshold: (m['low_stock_threshold'] ?? 5) as int,
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
    final path = p.join(dir, 'kirana_manager.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createTables,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // category aur sizes columns add karo
          try { await db.execute('ALTER TABLE inventory_units ADD COLUMN category TEXT DEFAULT "Grocery"'); } catch (_) {}
          try { await db.execute('ALTER TABLE inventory_units ADD COLUMN sizes TEXT DEFAULT "S,M,L,XL"'); } catch (_) {}
          debugPrint('[DB] Migrated to version 2');
        }
        if (oldV < 3) {
          // Sub-units table — har unit ke andar packSize-wise entries
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventory_sub_units (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              unit_id        INTEGER NOT NULL,
              packSize           TEXT NOT NULL,
              total_quantity INTEGER NOT NULL DEFAULT 0,
              created_at     TEXT NOT NULL,
              UNIQUE(unit_id, packSize),
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
              final packSizeList = sizesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
              for (final s in packSizeList) {
                await db.insert('inventory_sub_units', {
                  'unit_id': unitId,
                  'packSize': s,
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
        if (oldV < 4) {
          await db.execute('PRAGMA foreign_keys = OFF');

          // ── 1. Units: naam+category dono se UNIQUE (pehle sirf naam se tha,
          //    isliye "Namak" Grocery aur "Namak" Masale ek hi unit ban jaate the) ──
          await db.execute('''
            CREATE TABLE inventory_units_new (
              id     INTEGER PRIMARY KEY AUTOINCREMENT,
              name   TEXT NOT NULL,
              category TEXT NOT NULL DEFAULT 'Grocery',
              UNIQUE(name, category)
            )
          ''');
          await db.execute('''
            INSERT OR IGNORE INTO inventory_units_new (id, name, category)
            SELECT id, name, COALESCE(category, 'Grocery') FROM inventory_units
          ''');
          await db.execute('DROP TABLE inventory_units');
          await db.execute('ALTER TABLE inventory_units_new RENAME TO inventory_units');
          // Safety: sqlite_sequence ko explicitly sahi max-id pe set karo,
          // taaki naye inserts purani migrated id se kabhi collide na karein.
          try {
            await db.execute('''
              INSERT OR REPLACE INTO sqlite_sequence (name, seq)
              VALUES ('inventory_units', (SELECT COALESCE(MAX(id), 0) FROM inventory_units))
            ''');
          } catch (_) {}

          // ── 2. Sub-units: per-block low-stock threshold add karo ──
          try { await db.execute('ALTER TABLE inventory_sub_units ADD COLUMN low_stock_threshold INTEGER NOT NULL DEFAULT 5'); } catch (_) {}

          // ── 3. Inventory items: CRN/naam ab OPTIONAL hain (barcode na ho to
          //    bhi stock feed ho sake), aur har item ab seedha apni Sub-Unit
          //    (block) se juda hai — yahi ab stock count ka asli source hai ──
          await db.execute('''
            CREATE TABLE inventory_new (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              crn         TEXT NOT NULL DEFAULT '',
              name        TEXT NOT NULL DEFAULT '',
              category      TEXT NOT NULL,
              packSize        TEXT NOT NULL,
              unit        TEXT NOT NULL,
              sub_unit_id INTEGER,
              brand       TEXT NOT NULL DEFAULT '-',
              price       REAL NOT NULL DEFAULT 0,
              quantity    INTEGER NOT NULL DEFAULT 0,
              created_at  TEXT NOT NULL,
              updated_at  TEXT NOT NULL
            )
          ''');
          await db.execute('''
            INSERT INTO inventory_new
              (id, crn, name, category, packSize, unit, sub_unit_id, brand, price, quantity, created_at, updated_at)
            SELECT
              i.id, i.crn, i.name, i.category, i.packSize, i.unit,
              (SELECT su.id FROM inventory_sub_units su
                 JOIN inventory_units iu ON iu.id = su.unit_id
                 WHERE LOWER(iu.name) = LOWER(i.unit) AND LOWER(iu.category) = LOWER(i.category)
                   AND LOWER(su.packSize) = LOWER(i.packSize)
                 LIMIT 1),
              i.brand, i.price, i.quantity, i.created_at, i.updated_at
            FROM inventory i
          ''');
          await db.execute('DROP TABLE inventory');
          await db.execute('ALTER TABLE inventory_new RENAME TO inventory');
          try {
            await db.execute('''
              INSERT OR REPLACE INTO sqlite_sequence (name, seq)
              VALUES ('inventory', (SELECT COALESCE(MAX(id), 0) FROM inventory))
            ''');
          } catch (_) {}

          // Purane data mein sub-unit ka total_quantity kabhi sahi track nahi
          // hua tha (item add hone par update hi nahi hota tha) — ab items
          // se hi dobara sahi total nikaal lo. Ye ab stock ka asli source hai.
          await db.execute('''
            UPDATE inventory_sub_units
            SET total_quantity = (
              SELECT COALESCE(SUM(quantity), 0) FROM inventory WHERE inventory.sub_unit_id = inventory_sub_units.id
            )
          ''');

          // ── 4. Sale Sessions: ek "Complete Sell" ke saare items ab ek
          //    single session ke andar group hote hain (pehle har item ki
          //    apni alag row dikhti thi, jo confusing tha) ──
          await db.execute('''
            CREATE TABLE sale_sessions (
              id              INTEGER PRIMARY KEY AUTOINCREMENT,
              worker_id       TEXT NOT NULL,
              worker_name     TEXT NOT NULL,
              total_amount    REAL NOT NULL,
              item_count      INTEGER NOT NULL,
              payment_method  TEXT NOT NULL DEFAULT 'cod',
              is_credit       INTEGER NOT NULL DEFAULT 0,
              credit_customer TEXT,
              sold_at         TEXT NOT NULL,
              is_synced       INTEGER NOT NULL DEFAULT 0
            )
          ''');
          try { await db.execute('ALTER TABLE sales ADD COLUMN session_id INTEGER'); } catch (_) {}

          // Purani sales rows ke liye — har ek ko apna alag session de do
          // (purana data isolate hi rahega, lekin corrupt/lost nahi hoga)
          try {
            final oldSales = await db.query('sales', where: 'session_id IS NULL');
            for (final s in oldSales) {
              final sid = await db.insert('sale_sessions', {
                'worker_id': s['worker_id'],
                'worker_name': s['worker_name'],
                'total_amount': s['total_amount'],
                'item_count': 1,
                'payment_method': s['payment_method'] ?? 'cod',
                'is_credit': s['is_credit'] ?? 0,
                'credit_customer': s['credit_customer'],
                'sold_at': s['sold_at'],
                'is_synced': s['is_synced'] ?? 0,
              });
              await db.update('sales', {'session_id': sid}, where: 'id = ?', whereArgs: [s['id']]);
            }
          } catch (e) {
            debugPrint('[DB] Old sales session migration skipped: $e');
          }

          await db.execute('PRAGMA foreign_keys = ON');
          debugPrint('[DB] Migrated to version 4 (block-based stock + sale sessions + unit category fix)');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Inventory Units table — naam+category dono se unique (Namak-Grocery aur
    // Namak-Masale alag alag units hain)
    await db.execute('''
      CREATE TABLE inventory_units (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        name   TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Grocery',
        UNIQUE(name, category)
      )
    ''');

    // Inventory Sub-Units table — har unit ke andar packSize-wise entries.
    // total_quantity yahi stock ka ASLI SOURCE hai (block-level tracking).
    await db.execute('''
      CREATE TABLE inventory_sub_units (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id              INTEGER NOT NULL,
        packSize                 TEXT NOT NULL,
        total_quantity       INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold  INTEGER NOT NULL DEFAULT 5,
        created_at           TEXT NOT NULL,
        UNIQUE(unit_id, packSize),
        FOREIGN KEY(unit_id) REFERENCES inventory_units(id) ON DELETE CASCADE
      )
    ''');

    // Main Inventory table — CRN aur naam ab OPTIONAL hain (barcode na ho
    // to bhi item ek batch/tag ke roop mein add ho sakta hai). sub_unit_id
    // se pata chalta hai ye item kis block (packSize) ka hissa hai.
    await db.execute('''
      CREATE TABLE inventory (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        crn         TEXT NOT NULL DEFAULT '',
        name        TEXT NOT NULL DEFAULT '',
        category      TEXT NOT NULL,
        packSize        TEXT NOT NULL,
        unit        TEXT NOT NULL,
        sub_unit_id INTEGER,
        brand       TEXT NOT NULL DEFAULT '-',
        price       REAL NOT NULL DEFAULT 0,
        quantity    INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    // Sale Sessions — ek "Complete Sell" mein jitne bhi items bike,
    // sab isi ek session ke andar group hote hain
    await db.execute('''
      CREATE TABLE sale_sessions (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id       TEXT NOT NULL,
        worker_name     TEXT NOT NULL,
        total_amount    REAL NOT NULL,
        item_count      INTEGER NOT NULL,
        payment_method  TEXT NOT NULL DEFAULT 'cod',
        is_credit       INTEGER NOT NULL DEFAULT 0,
        credit_customer TEXT,
        sold_at         TEXT NOT NULL,
        is_synced       INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Sales table — ek line-item, jo kisi session se juda hai
    await db.execute('''
      CREATE TABLE sales (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id    INTEGER,
        crn           TEXT NOT NULL,
        item_name     TEXT NOT NULL,
        item_category   TEXT NOT NULL,
        item_pack_size     TEXT NOT NULL,
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
      'https://script.google.com/macros/s/AKfycbxNKBurECKeIvwAq1wddUPxfnF6jsOBXoZGE36giFLk11ZYcTMvwfyjy0GEVvUbkMny/exec';

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

  /// Unit banao (ya agar naam+category se already exist karti hai to wahi use
  /// karo), aur diye gaye packSize(s) ko us unit ke SUB-UNIT ke roop mein add
  /// karo. Isse same naam ki unit dobara banane par purani REPLACE nahi hoti
  /// — naya packSize sirf ek nayi sub-unit ban kar existing unit ke andar jud
  /// jaata hai. Naam+Category dono match karne par hi existing unit maani
  /// jaati hai — isliye "Namak" Grocery aur "Namak" Masale alag-alag units hain.
  ///
  /// [packSizesInput] comma se alag multiple sizes bhi ho sakti hain: "S,M,L"
  /// NOTE: Ye method sirf UNIT/SUB-UNIT ka DHAANCHA (structure) banata hai.
  /// Stock quantity yahan se update NAHI hoti — wo sirf addItem() se hoti
  /// hai, taaki double-count na ho.
  Future<Result<InventoryUnit>> addOrUpdateUnit({
    required String name,
    required String category,
    required String packSizesInput,
    int quantityPerSize = 0,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return const Result.failure('Unit naam daalo!');

    final packSizeList = packSizesInput
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (packSizeList.isEmpty) return const Result.failure('Kam se kam ek pack size daalo!');

    try {
      final db = await _db.database;
      int unitId;

      // Existing unit dhundho — NAAM aur CATEGORY dono match hone chahiye
      final existing = await db.query('inventory_units',
          where: 'LOWER(name) = ? AND LOWER(category) = ?',
          whereArgs: [cleanName.toLowerCase(), category.toLowerCase()]);

      if (existing.isNotEmpty) {
        unitId = existing.first['id'] as int;
      } else {
        unitId = await db.insert('inventory_units', {'name': cleanName, 'category': category});
      }

      // Har packSize ke liye sub-unit upsert karo
      for (final packSize in packSizeList) {
        final subExisting = await db.query('inventory_sub_units',
            where: 'unit_id = ? AND LOWER(packSize) = ?',
            whereArgs: [unitId, packSize.toLowerCase()]);

        if (subExisting.isEmpty) {
          await db.insert('inventory_sub_units', {
            'unit_id': unitId,
            'packSize': packSize,
            'total_quantity': quantityPerSize,
            'low_stock_threshold': 5,
            'created_at': DateTime.now().toIso8601String(),
          });
        } else if (quantityPerSize > 0) {
          final subId = subExisting.first['id'] as int;
          final currentQty = subExisting.first['total_quantity'] as int;
          await db.update('inventory_sub_units',
              {'total_quantity': currentQty + quantityPerSize},
              where: 'id = ?', whereArgs: [subId]);
        }
      }

      final savedRow = (await db.query('inventory_units', where: 'id = ?', whereArgs: [unitId])).first;
      debugPrint('[Inventory] Unit "$cleanName" ($category) ready with sizes: ${packSizeList.join(", ")}');
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
        where: 'unit_id = ?', whereArgs: [unitId], orderBy: 'packSize ASC');
    return rows.map(InventorySubUnit.fromMap).toList();
  }

  /// Saari units + unki sub-units ek saath lo (list screens ke liye efficient)
  Future<Map<int, List<InventorySubUnit>>> getSubUnitsGroupedByUnit() async {
    final rows = await _db.query('inventory_sub_units', orderBy: 'packSize ASC');
    final map = <int, List<InventorySubUnit>>{};
    for (final r in rows) {
      final su = InventorySubUnit.fromMap(r);
      map.putIfAbsent(su.unitId, () => []).add(su);
    }
    return map;
  }

  /// Ek block (sub-unit) ka low-stock threshold badlo
  Future<Result<void>> updateSubUnitThreshold(int subUnitId, int threshold) async {
    try {
      await _db.update('inventory_sub_units', {'low_stock_threshold': threshold},
          where: 'id = ?', whereArgs: [subUnitId]);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Threshold update error: $e');
    }
  }

  // ── Inventory Items ────────────────────────────────────

  /// Naye stock ka entry — CRN/naam dono OPTIONAL hain. Barcode diya ho ya
  /// na diya ho, quantity hamesha us Unit+Pack Size ke SUB-UNIT (block) ke total
  /// mein add hoti hai — yahi ab "kitna stock bacha hai" ka asli source hai.
  ///
  /// - CRN diya aur wahi CRN isi block mein pehle se hai → quantity add ho
  ///   jaati hai usi row mein (upsert), duplicate row nahi banta.
  /// - CRN nahi diya → naya "batch" row banta hai (bina barcode tracking ke).
  ///
  /// Excel bhi automatically update hoti hai (silent=true karne par bulk
  /// import ke waqt har row par Excel rewrite nahi hoti — sirf end mein ek baar)
  Future<Result<InventoryItem>> addItem(InventoryItem item, {bool silent = false}) async {
    try {
      final db = await _db.database;
      final addQty = item.quantity <= 0 ? 1 : item.quantity;

      // Is Unit+Category+Pack Size ka block (sub-unit) dhundo
      final subRows = await db.rawQuery('''
        SELECT su.* FROM inventory_sub_units su
        JOIN inventory_units iu ON iu.id = su.unit_id
        WHERE LOWER(iu.name) = ? AND LOWER(iu.category) = ? AND LOWER(su.packSize) = ?
        LIMIT 1
      ''', [item.unit.trim().toLowerCase(), item.category.trim().toLowerCase(), item.packSize.trim().toLowerCase()]);

      if (subRows.isEmpty) {
        return const Result.failure(
            'Ye pack size is unit mein nahi mili. Pehle "Unit Banao" tab se ye pack size add karo.');
      }
      final subUnit = InventorySubUnit.fromMap(subRows.first);
      final now = DateTime.now();
      final crn = item.crn.trim();
      int itemId;

      if (crn.isNotEmpty) {
        // Same barcode isi block mein pehle se hai? to quantity add karo
        final dup = await db.query('inventory',
            where: 'crn = ? AND sub_unit_id = ?', whereArgs: [crn, subUnit.id]);
        if (dup.isNotEmpty) {
          itemId = dup.first['id'] as int;
          final exQty = dup.first['quantity'] as int;
          await db.update('inventory',
              {'quantity': exQty + addQty, 'updated_at': now.toIso8601String()},
              where: 'id = ?', whereArgs: [itemId]);
        } else {
          itemId = await db.insert('inventory', InventoryItem(
            crn: crn, name: item.name.trim(), category: item.category, packSize: item.packSize,
            unit: item.unit, subUnitId: subUnit.id, brand: item.brand,
            price: item.price, quantity: addQty, createdAt: now, updatedAt: now,
          ).toMap());
        }
      } else {
        // Barcode nahi diya — naya batch entry
        itemId = await db.insert('inventory', InventoryItem(
          crn: '', name: item.name.trim(), category: item.category, packSize: item.packSize,
          unit: item.unit, subUnitId: subUnit.id, brand: item.brand,
          price: item.price, quantity: addQty, createdAt: now, updatedAt: now,
        ).toMap());
      }

      // Block ka total badhao — YAHI stock ka asli source hai
      await db.update('inventory_sub_units',
          {'total_quantity': subUnit.totalQuantity + addQty},
          where: 'id = ?', whereArgs: [subUnit.id]);

      final savedRow = (await db.query('inventory', where: 'id = ?', whereArgs: [itemId])).first;
      final saved = InventoryItem.fromMap(savedRow);

      if (!silent) await ExcelService.instance.updateExcelFile();

      debugPrint('[Inventory] Stock added: ${item.unit}/${item.packSize} +$addQty (${saved.displayCrn})');
      return Result.success(saved);
    } catch (e) {
      return Result.failure('Item add error: $e');
    }
  }

  /// Inventory item update karo (quantity badlegi to block ka total bhi
  /// automatically sync hoga)
  Future<Result<void>> updateItem(InventoryItem item) async {
    try {
      final db = await _db.database;
      final oldRow = await db.query('inventory', where: 'id = ?', whereArgs: [item.id]);
      final oldQty = oldRow.isNotEmpty ? oldRow.first['quantity'] as int : item.quantity;
      final delta = item.quantity - oldQty;

      item.updatedAt = DateTime.now();
      await db.update('inventory', item.toMap(), where: 'id = ?', whereArgs: [item.id]);

      if (delta != 0 && item.subUnitId != null) {
        await db.rawUpdate(
            'UPDATE inventory_sub_units SET total_quantity = total_quantity + ? WHERE id = ?',
            [delta, item.subUnitId]);
      }
      await ExcelService.instance.updateExcelFile();
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Item update error: $e');
    }
  }

  /// Inventory item delete karo (block ka total bhi ghat jayega)
  Future<Result<void>> deleteItem(int id) async {
    try {
      final db = await _db.database;
      final row = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
      if (row.isNotEmpty) {
        final qty = row.first['quantity'] as int;
        final subUnitId = row.first['sub_unit_id'] as int?;
        if (subUnitId != null && qty > 0) {
          await db.rawUpdate(
              'UPDATE inventory_sub_units SET total_quantity = MAX(0, total_quantity - ?) WHERE id = ?',
              [qty, subUnitId]);
        }
      }
      await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
      await ExcelService.instance.updateExcelFile();
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Item delete error: $e');
    }
  }

  /// CRN se item dhundho — available (quantity > 0) wala priority mein
  Future<InventoryItem?> getItemByCrn(String crn) async {
    final rows = await _db.query('inventory',
        where: 'crn = ?', whereArgs: [crn], orderBy: 'quantity DESC');
    if (rows.isEmpty) return null;
    return InventoryItem.fromMap(rows.first);
  }

  /// ID se item dhundho — Manual Search / cart jaise flows ke liye jahan
  /// CRN blank ho sakta hai (bulk stock, barcode nahi hai)
  Future<InventoryItem?> getItemById(int id) async {
    final rows = await _db.query('inventory', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InventoryItem.fromMap(rows.first);
  }

  /// Saare items lo (filter optional)
  Future<List<InventoryItem>> getAllItems({
    String? category,
    String? searchQuery,
    String? unit,
    int? subUnitId,
  }) async {
    String? where;
    List<dynamic>? args;

    final conditions = <String>[];
    final argsList = <dynamic>[];

    if (category != null && category != 'All') {
      conditions.add('category = ?');
      argsList.add(category);
    }
    if (unit != null) {
      conditions.add('unit = ?');
      argsList.add(unit);
    }
    if (subUnitId != null) {
      conditions.add('sub_unit_id = ?');
      argsList.add(subUnitId);
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

  /// Ek Unit ke items, uski sub-units (sizes) ke hisaab se grouped —
  /// UnitItemsScreen mein "Pack Size: M — Total: 12" jaisi listing ke liye
  Future<Map<InventorySubUnit, List<InventoryItem>>> getItemsGroupedBySubUnit(int unitId) async {
    final subUnits = await getSubUnitsForUnit(unitId);
    final result = <InventorySubUnit, List<InventoryItem>>{};
    for (final su in subUnits) {
      final items = await getAllItems(subUnitId: su.id);
      result[su] = items;
    }
    return result;
  }

  /// Low-stock / out-of-stock blocks (Sub-Units) — ab har SIZE ka apna
  /// alag threshold hota hai, aur check Unit+Pack Size ke TOTAL par hota hai,
  /// na ki har item ki apni alag quantity par (jo pehle galat tha).
  Future<List<Map<String, dynamic>>> getLowStockSubUnits() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT su.*, iu.name AS unit_name, iu.category AS unit_category
      FROM inventory_sub_units su
      JOIN inventory_units iu ON iu.id = su.unit_id
      WHERE su.total_quantity <= su.low_stock_threshold
      ORDER BY su.total_quantity ASC
    ''');
    return rows;
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
                'category': map['category'],
                'packSize': map['packSize'],
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
class SaleLineInput {
  final int itemId;
  final double discount;
  SaleLineInput({required this.itemId, this.discount = 0});
}

class SalesService {
  static SalesService? _instance;
  SalesService._();
  static SalesService get instance {
    _instance ??= SalesService._();
    return _instance!;
  }

  final _db = DatabaseService.instance;
  final _inv = InventoryService.instance;

  /// Ek poora checkout complete karo — cart mein 1 ya zyada items ho sakte
  /// hain, sab MILKAR ek hi Sale Session banate hain (pehle har item ki
  /// alag row dikhti thi, ab poora checkout ek grouped entry hai).
  ///
  /// Har item ke liye: uski apni quantity -1 hoti hai, AUR uske block
  /// (Sub-Unit) ka total bhi -1 hota hai — yahi stock ka asli source hai.
  Future<Result<SaleSession>> completeSale({
    required List<SaleLineInput> lines,
    required UserSession worker,
    String paymentMethod = 'cod',
    bool isCredit = false,
    String? creditCustomer,
  }) async {
    if (lines.isEmpty) return const Result.failure('Cart khali hai.');
    if (isCredit && (creditCustomer == null || creditCustomer.trim().isEmpty)) {
      return const Result.failure('Udhari ke liye customer ka naam daalo.');
    }

    // Pehle saare items fetch + validate karo
    final resolvedItems = <InventoryItem>[];
    for (final line in lines) {
      final item = await _inv.getItemById(line.itemId);
      if (item == null) {
        return const Result.failure('Item nahi mila.');
      }
      if (item.quantity < 1) {
        return Result.failure('${item.displayName} stock mein nahi hai.');
      }
      resolvedItems.add(item);
    }

    double sessionTotal = 0;
    final lineTotals = <double>[];
    for (int i = 0; i < resolvedItems.length; i++) {
      final total = resolvedItems[i].price - lines[i].discount;
      if (total < 0) return const Result.failure('Discount zyada hai. Total negative nahi ho sakta.');
      lineTotals.add(total);
      sessionTotal += total;
    }

    try {
      final db = await DatabaseService.instance.database;
      late SaleSession savedSession;
      final savedLines = <SaleRecord>[];

      await db.transaction((txn) async {
        final sessionObj = SaleSession(
          workerId: worker.userId,
          workerName: worker.name,
          totalAmount: sessionTotal,
          itemCount: resolvedItems.length,
          paymentMethod: paymentMethod,
          isCredit: isCredit,
          creditCustomer: isCredit ? creditCustomer!.trim() : null,
        );
        final sessionId = await txn.insert('sale_sessions', sessionObj.toMap());

        for (int i = 0; i < resolvedItems.length; i++) {
          final item = resolvedItems[i];

          // Item ki apni quantity ghataao
          await txn.update('inventory',
              {'quantity': item.quantity - 1, 'updated_at': DateTime.now().toIso8601String()},
              where: 'id = ?', whereArgs: [item.id]);

          // Block (Sub-Unit) ka total bhi ghataao — asli stock source
          if (item.subUnitId != null) {
            await txn.rawUpdate(
                'UPDATE inventory_sub_units SET total_quantity = MAX(0, total_quantity - 1) WHERE id = ?',
                [item.subUnitId]);
          }

          final sale = SaleRecord(
            sessionId: sessionId,
            crn: item.crn,
            itemName: item.displayName,
            itemCategory: item.category,
            itemPackSize: item.packSize,
            brand: item.brand,
            quantity: 1,
            unitPrice: item.price,
            discount: lines[i].discount,
            totalAmount: lineTotals[i],
            workerId: worker.userId,
            workerName: worker.name,
            isSynced: false,
            paymentMethod: paymentMethod,
            isCredit: isCredit,
            creditCustomer: isCredit ? creditCustomer!.trim() : null,
          );
          final saleId = await txn.insert('sales', sale.toMap());
          savedLines.add(SaleRecord(
            id: saleId, sessionId: sessionId, crn: sale.crn, itemName: sale.itemName,
            itemCategory: sale.itemCategory, itemPackSize: sale.itemPackSize, brand: sale.brand,
            quantity: sale.quantity, unitPrice: sale.unitPrice, discount: sale.discount,
            totalAmount: sale.totalAmount, workerId: sale.workerId, workerName: sale.workerName,
            soldAt: sale.soldAt, isSynced: false, paymentMethod: sale.paymentMethod,
            isCredit: sale.isCredit, creditCustomer: sale.creditCustomer,
          ));
        }

        savedSession = SaleSession(
          id: sessionId, workerId: sessionObj.workerId, workerName: sessionObj.workerName,
          totalAmount: sessionObj.totalAmount, itemCount: sessionObj.itemCount,
          paymentMethod: sessionObj.paymentMethod, isCredit: sessionObj.isCredit,
          creditCustomer: sessionObj.creditCustomer, soldAt: sessionObj.soldAt, isSynced: false,
        );
      });

      // Udhari hai to POORE session ke total ka EK hi debit entry banega
      // (pehle har item ka alag debit banta tha, jo confusing tha)
      if (isCredit) {
        await CreditService.instance.addDebit(
          customerName: creditCustomer!.trim(),
          amount: sessionTotal,
          note: '${resolvedItems.length} item(s) sold',
          worker: worker,
        );
      }

      await ExcelService.instance.updateExcelFile();
      _trySyncInBackground();

      debugPrint('[Sales] Session complete: ${resolvedItems.length} items = ₹$sessionTotal');
      return Result.success(savedSession);
    } catch (e) {
      return Result.failure('Sale error: $e');
    }
  }

  /// Aaj ke sale sessions (grouped checkouts)
  Future<List<SaleSession>> getTodaySessions({String? workerId}) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
    return getSessionsBetween(start, end, workerId: workerId);
  }

  /// Date ke hisaab se sale sessions
  Future<List<SaleSession>> getSessionsByDate(DateTime date, {String? workerId}) async {
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    return getSessionsBetween(start, end, workerId: workerId);
  }

  Future<List<SaleSession>> getSessionsBetween(String start, String end, {String? workerId}) async {
    String where = 'sold_at BETWEEN ? AND ?';
    List<dynamic> args = [start, end];
    if (workerId != null) {
      where += ' AND worker_id = ?';
      args.add(workerId);
    }
    final rows = await _db.query('sale_sessions', where: where, whereArgs: args, orderBy: 'sold_at DESC');
    return rows.map(SaleSession.fromMap).toList();
  }

  /// Sab sale sessions (Total Sell screen ke liye)
  Future<List<SaleSession>> getAllSessions({String? workerId}) async {
    String? where;
    List<dynamic>? args;
    if (workerId != null) {
      where = 'worker_id = ?';
      args = [workerId];
    }
    final rows = await _db.query('sale_sessions', where: where, whereArgs: args, orderBy: 'sold_at DESC');
    return rows.map(SaleSession.fromMap).toList();
  }

  /// Ek session ke andar ke saare line-items (tap karke expand karne ke liye)
  Future<List<SaleRecord>> getLinesForSession(int sessionId) async {
    final rows = await _db.query('sales', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'id ASC');
    return rows.map(SaleRecord.fromMap).toList();
  }

  /// Aaj ka total revenue
  Future<double> getTodayRevenue({String? workerId}) async {
    final sessions = await getTodaySessions(workerId: workerId);
    return sessions.fold<double>(0, (sum, s) => sum + s.totalAmount);
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
        // Inventory mein qty wapas add karo — item.id se (crn se nahi,
        // kyunki same barcode multiple batches mein ho sakta hai)
        await txn.update(
          'inventory',
          {
            'quantity': item.quantity + quantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );

        // Block (Sub-Unit) ka total bhi wapas badhao
        if (item.subUnitId != null) {
          await txn.rawUpdate(
              'UPDATE inventory_sub_units SET total_quantity = total_quantity + ? WHERE id = ?',
              [quantity, item.subUnitId]);
        }

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
    'Sub Unit (Pack Size)',
    'Item Name',
    'CRN Number',
    'Category',
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
    sheet.setColumnWidth(1, 14);  // Sub Unit (Pack Size)
    sheet.setColumnWidth(2, 22);  // Item Name
    sheet.setColumnWidth(3, 18);  // CRN
    sheet.setColumnWidth(4, 12);  // Category
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
      // Isse purani ("CRN, Name, Category, Pack Size, Unit...") aur nayi
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
        else if (h.contains('item') || h == 'name' || h.contains('name')) { col['name'] = c; }
        else if (h.contains('category')) { col['category'] = c; }
        else if (h.contains('brand')) { col['brand'] = c; }
        else if (h.contains('price')) { col['price'] = c; }
        else if (h.contains('qty') || h.contains('quantity')) { col['quantity'] = c; }
        else if (h == 'unit' || (h.contains('unit') && !col.containsKey('unit'))) { col['unit'] = c; }
        else if (h.contains('pack') || h.contains('size')) { col['unit_sub'] = c; }
      }

      // Fallback: agar headers pehchan mein nahi aaye to naye standard order pe
      // gir jaao — Unit, Sub Unit, Item, CRN, Category, Brand, Price, Qty
      col.putIfAbsent('unit', () => 0);
      col.putIfAbsent('unit_sub', () => 1);
      col.putIfAbsent('name', () => 2);
      col.putIfAbsent('crn', () => 3);
      col.putIfAbsent('category', () => 4);
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

        final unitName = safeVal(col['unit'], '').trim();
        final subUnit  = safeVal(col['unit_sub'], '').trim();

        // Sirf Unit + Pack Size zaroori hain — CRN/naam na ho tab bhi stock
        // feed honi chahiye (bina barcode ke bhi 1 item count hona chahiye)
        if (unitName.isEmpty || subUnit.isEmpty) {
          skippedCount++;
          continue;
        }

        final crn      = safeVal(col['crn'], '');
        final name     = safeVal(col['name'], '');
        final category   = safeVal(col['category'], 'Grocery');
        final quantity = int.tryParse(safeVal(col['quantity'], '1')) ?? 1;
        final effectiveQty = quantity <= 0 ? 1 : quantity;

        try {
          final item = InventoryItem(
            crn:      crn.toUpperCase(),
            name:     name,
            category:   category,
            packSize:     subUnit,
            unit:     unitName,
            brand:    safeVal(col['brand'], '-'),
            price:    double.tryParse(safeVal(col['price'], '0')) ?? 0,
            quantity: effectiveQty,
          );

          // Pehle Unit + Sub Unit ka DHAANCHA ready karo (quantity yahan
          // add NAHI karte — warna addItem() ke saath double-count ho
          // jayegi. Stock sirf addItem() se badhti hai.)
          await InventoryService.instance.addOrUpdateUnit(
            name: unitName,
            category: category,
            packSizesInput: subUnit,
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
            '• Columns: Unit, Sub Unit (Pack Size), Item Name, CRN, Category, Brand, Price, Qty\n'
            '• Unit aur Sub Unit column khaali to nahi hai?');
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
//    runApp(const KiranaApp());
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
//    crn: 'KRN-2024-001',
//    name: 'Tata Salt',
//    category: 'Grocery',
//    packSize: 'L',
//    unit: 'Piece',
//    brand: 'Tata',
//    price: 850.0,
//    quantity: 50,
//  ));
//
//  // SELL ITEM(S) — ek ya zyada items ek session mein:
//  final session = AuthService.instance.currentSession!;
//  final result = await SalesService.instance.completeSale(
//    lines: [SaleLineInput(itemId: itemId, discount: 50.0)],
//    worker: session,
//  );
//
//  // RETURN ITEM:
//  final result = await ReturnService.instance.returnItem(
//    crn: crnCtrl.text,
//    quantity: 1,
//    reason: 'Damaged packet',
//    worker: session,
//    refundAmount: 850.0,
//  );
//
//  // INVENTORY LIST:
//  final items = await InventoryService.instance.getAllItems(
//    category: 'Grocery',          // optional filter
//    searchQuery: 'salt',   // optional search
//  );
//
//  // TODAY'S SALE SESSIONS:
//  final sessions = await SalesService.instance.getTodaySessions(
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
