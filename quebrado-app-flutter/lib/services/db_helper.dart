import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../models/saving_pocket.dart';
import '../models/transaction_category.dart';
import '../models/transaction.dart';
import '../models/exchange_rate_record.dart';
import '../models/recurring_payment.dart';
import '../models/recurring_payment_partial.dart';
import '../models/account.dart';
import '../models/mobile_payment_recipient.dart';
import '../models/currency_type.dart';
import '../models/market_store.dart';
import '../models/market_item.dart';
import '../models/market_product.dart';
import '../models/market_trip.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbName = await getActiveProfile();
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<String> _getDbPath() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return '.';
    }
    return await getDatabasesPath();
  }

  Future<String> getDbPath() async {
    return await _getDbPath();
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await _getDbPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 24,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<Database> initProfileDb(String profileId) async {
    return await _initDB(profileId);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE pockets ADD COLUMN description TEXT');
        await db.execute('ALTER TABLE pockets ADD COLUMN image_url TEXT');
      } catch (e) {
        // Handle migration gracefully if columns already exist
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            currency TEXT NOT NULL,
            balance REAL NOT NULL,
            color_hex TEXT NOT NULL,
            icon TEXT NOT NULL
          )
        ''');
        await db.execute('ALTER TABLE transactions ADD COLUMN account_id TEXT');

        final List<Map<String, dynamic>> settingsMaps = await db.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['totalBalanceUSD'],
        );

        double existingBalanceUSD = 0.0;
        if (settingsMaps.isNotEmpty) {
          existingBalanceUSD = double.tryParse(settingsMaps.first['value'] as String? ?? '0.0') ?? 0.0;
        }

        const defaultUsdId = 'default_usd';
        const defaultVesId = 'default_ves';

        await db.insert('accounts', {
          'id': defaultUsdId,
          'name': 'Efectivo \$',
          'currency': 'usd',
          'balance': existingBalanceUSD,
          'color_hex': '#2FA084',
          'icon': 'creditcard',
        });

        await db.insert('accounts', {
          'id': defaultVesId,
          'name': 'Banco Bs.',
          'currency': 'bsBCV',
          'balance': 0.0,
          'color_hex': '#3B6B7B',
          'icon': 'creditcard',
        });

        await db.update('transactions', {'account_id': defaultUsdId});
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE recurring_payments (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            frequency TEXT NOT NULL,
            start_date TEXT NOT NULL,
            notification_option TEXT NOT NULL,
            icon TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            type TEXT NOT NULL,
            account_id TEXT,
            pocket_id TEXT,
            total_installments INTEGER,
            FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
            FOREIGN KEY (pocket_id) REFERENCES pockets (id) ON DELETE SET NULL
          )
        ''');

        final List<Map<String, dynamic>> subMaps = await db.query('subscriptions');
        for (var map in subMaps) {
          await db.insert('recurring_payments', {
            'id': map['id'],
            'name': map['name'],
            'amount': map['amount'],
            'currency': map['currency'],
            'frequency': map['frequency'],
            'start_date': map['start_date'],
            'notification_option': map['notification_option'],
            'icon': map['icon'],
            'color_hex': map['color_hex'],
            'type': 'expense',
            'account_id': 'default_usd',
            'pocket_id': null,
            'total_installments': null,
          });
        }

        await db.execute('DROP TABLE IF EXISTS subscriptions');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE pockets ADD COLUMN target_date TEXT');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE recurring_payments ADD COLUMN custom_days INTEGER');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE recurring_payments ADD COLUMN is_variable INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE recurring_payments ADD COLUMN max_amount REAL');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE recurring_payment_confirmations (
            id TEXT PRIMARY KEY,
            recurring_payment_id TEXT NOT NULL,
            date TEXT NOT NULL,
            FOREIGN KEY (recurring_payment_id) REFERENCES recurring_payments (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE pockets ADD COLUMN priority INTEGER DEFAULT 1');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN position INTEGER DEFAULT 0');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('''
          CREATE TABLE recurring_payment_partials (
            id TEXT PRIMARY KEY,
            recurring_payment_id TEXT NOT NULL,
            occurrence_date TEXT NOT NULL,
            amount REAL NOT NULL,
            transaction_id TEXT NOT NULL,
            FOREIGN KEY (recurring_payment_id) REFERENCES recurring_payments (id) ON DELETE CASCADE,
            FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 12) {
      try {
        await db.execute('''
          CREATE TABLE mobile_payment_recipients (
            id TEXT PRIMARY KEY,
            alias TEXT NOT NULL,
            bank_code TEXT NOT NULL,
            bank_name TEXT NOT NULL,
            identity_card TEXT NOT NULL,
            phone_number TEXT NOT NULL
          )
        ''');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE pockets ADD COLUMN funding_rule_type TEXT DEFAULT "none"');
        await db.execute('ALTER TABLE pockets ADD COLUMN funding_rule_value REAL');
        await db.execute('ALTER TABLE pockets ADD COLUMN funding_rule_threshold REAL');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 14) {
      try {
        await db.execute('''
          CREATE TABLE market_stores (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            color_hex TEXT,
            icon TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE market_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price_usd REAL NOT NULL,
            price_ves REAL NOT NULL,
            exchange_rate_used REAL NOT NULL,
            store_id TEXT NOT NULL,
            date TEXT NOT NULL,
            FOREIGN KEY (store_id) REFERENCES market_stores (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute('''
          CREATE TABLE market_trips (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
        await db.execute('ALTER TABLE market_items ADD COLUMN trip_id TEXT');
        
        final List<Map<String, dynamic>> items = await db.query('market_items');
        if (items.isNotEmpty) {
           final legacyTripId = const Uuid().v4();
           await db.insert('market_trips', {
             'id': legacyTripId,
             'title': 'Compras Anteriores',
             'date': DateTime.now().toIso8601String(),
           });
           await db.update('market_items', {'trip_id': legacyTripId});
        }
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE market_trips ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 17) {
      try {
        await db.execute('''
          CREATE TABLE market_products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            storeIds TEXT NOT NULL,
            referencePriceUSD REAL
          )
        ''');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 18) {
      try {
        await db.execute('''
          CREATE TABLE market_shopping_lists (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE market_shopping_list_items (
            id TEXT PRIMARY KEY,
            list_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            is_checked INTEGER DEFAULT 0,
            FOREIGN KEY (list_id) REFERENCES market_shopping_lists (id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES market_products (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE market_trips ADD COLUMN transaction_id TEXT');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 20) {
      try {
        await db.execute('ALTER TABLE market_items ADD COLUMN product_id TEXT');
        // Migrate existing items by matching product name
        final List<Map<String, dynamic>> items = await db.query('market_items');
        final List<Map<String, dynamic>> products = await db.query('market_products');
        for (var item in items) {
          final String itemName = item['name'] as String;
          // Find matching product
          final matchingProduct = products.firstWhere(
            (p) => (p['name'] as String).toLowerCase() == itemName.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (matchingProduct.isNotEmpty) {
            await db.update(
              'market_items',
              {'product_id': matchingProduct['id']},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          }
        }
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN parent_id TEXT');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 22) {
      try {
        await db.execute('ALTER TABLE market_items ADD COLUMN quantity REAL DEFAULT 1.0');
        await db.execute("ALTER TABLE market_items ADD COLUMN unit TEXT DEFAULT 'un'");
        await db.execute('ALTER TABLE market_items ADD COLUMN is_pending INTEGER DEFAULT 0');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE market_products ADD COLUMN unit TEXT DEFAULT "un"');
        await db.execute('ALTER TABLE market_shopping_list_items ADD COLUMN quantity REAL DEFAULT 1.0');
      } catch (e) {
        // Handle migration gracefully
      }
    }
    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE market_products ADD COLUMN default_quantity REAL DEFAULT 1.0');
      } catch (e) {
        // Handle migration gracefully
      }
    }
  }

  Future _onConfigure(Database db) async {
    // Enable SQLite foreign key constraints natively for ON DELETE SET NULL cascading
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const doubleType = 'REAL NOT NULL';

    // 1. Settings Table (For variables like rates, total wealth, currency config)
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 2. Pockets Table
    await db.execute('''
      CREATE TABLE pockets (
        id TEXT PRIMARY KEY,
        name $textType,
        current_amount_usd $doubleType,
        target_amount_usd $doubleType,
        icon $textType,
        color_hex $textType,
        description TEXT,
        image_url TEXT,
        target_date TEXT,
        priority INTEGER DEFAULT 1,
        funding_rule_type TEXT DEFAULT 'none',
        funding_rule_value REAL,
        funding_rule_threshold REAL
      )
    ''');

    // 3. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name $textType,
        icon $textType,
        color_hex $textType,
        type $textType,
        position INTEGER DEFAULT 0,
        parent_id $textNullable
      )
    ''');

    // 4. Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name $textType,
        currency $textType,
        balance $doubleType,
        color_hex $textType,
        icon $textType
      )
    ''');

    // 5. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        date $textType,
        amount $doubleType,
        currency $textType,
        destination_pocket_id $textNullable,
        category_id $textNullable,
        account_id $textNullable,
        note $textType,
        type $textType,
        exchange_rate $doubleType,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (destination_pocket_id) REFERENCES pockets (id) ON DELETE SET NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // 6. Rate History Table
    await db.execute('''
      CREATE TABLE rate_history (
        id TEXT PRIMARY KEY,
        date $textType,
        rate $doubleType,
        type $textType
      )
    ''');

    // 7. Recurring Payments Table
    await db.execute('''
      CREATE TABLE recurring_payments (
        id TEXT PRIMARY KEY,
        name $textType,
        amount $doubleType,
        currency $textType,
        frequency $textType,
        start_date $textType,
        notification_option $textType,
        icon $textType,
        color_hex $textType,
        type $textType,
        account_id $textNullable,
        pocket_id $textNullable,
        total_installments INTEGER,
        custom_days INTEGER,
        is_variable INTEGER DEFAULT 0,
        max_amount REAL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (pocket_id) REFERENCES pockets (id) ON DELETE SET NULL
      )
    ''');

    // 8. Recurring Payment Confirmations Table
    await db.execute('''
      CREATE TABLE recurring_payment_confirmations (
        id TEXT PRIMARY KEY,
        recurring_payment_id TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (recurring_payment_id) REFERENCES recurring_payments (id) ON DELETE CASCADE
      )
    ''');

    // 9. Recurring Payment Partials Table
    await db.execute('''
      CREATE TABLE recurring_payment_partials (
        id TEXT PRIMARY KEY,
        recurring_payment_id TEXT NOT NULL,
        occurrence_date TEXT NOT NULL,
        amount REAL NOT NULL,
        transaction_id TEXT NOT NULL,
        FOREIGN KEY (recurring_payment_id) REFERENCES recurring_payments (id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // 10. Mobile Payment Recipients Table
    await db.execute('''
      CREATE TABLE mobile_payment_recipients (
        id TEXT PRIMARY KEY,
        alias $textType,
        bank_code $textType,
        bank_name $textType,
        identity_card $textType,
        phone_number $textType
      )
    ''');

    // Seed default categories
    await _seedDefaultCategories(db);

    // Seed default accounts
    await db.insert('accounts', {
      'id': 'default_usd',
      'name': 'Efectivo \$',
      'currency': 'usd',
      'balance': 0.0,
      'color_hex': '#2FA084',
      'icon': 'creditcard',
    });

    await db.insert('accounts', {
      'id': 'default_ves',
      'name': 'Banco Bs.',
      'currency': 'bsBCV',
      'balance': 0.0,
      'color_hex': '#3B6B7B',
      'icon': 'creditcard',
    });

    // 11. Market Stores Table
    await db.execute('''
      CREATE TABLE market_stores (
        id TEXT PRIMARY KEY,
        name $textType,
        description TEXT,
        color_hex TEXT,
        icon TEXT
      )
    ''');

    // 12. Market Products Table
    await db.execute('''
      CREATE TABLE market_products (
        id TEXT PRIMARY KEY,
        name $textType,
        category $textType,
        storeIds $textType,
        referencePriceUSD REAL,
        unit TEXT DEFAULT "un",
        default_quantity REAL DEFAULT 1.0
      )
    ''');

    // 13. Market Trips Table
    await db.execute('''
      CREATE TABLE market_trips (
        id TEXT PRIMARY KEY,
        title $textType,
        date $textType,
        is_active INTEGER DEFAULT 1,
        transaction_id TEXT
      )
    ''');

    // 14. Market Items Table
    await db.execute('''
      CREATE TABLE market_items (
        id TEXT PRIMARY KEY,
        name $textType,
        category $textType,
        price_usd $doubleType,
        price_ves $doubleType,
        exchange_rate_used $doubleType,
        store_id TEXT NOT NULL,
        trip_id TEXT NOT NULL,
        product_id TEXT,
        date $textType,
        quantity REAL DEFAULT 1.0,
        unit TEXT DEFAULT 'un',
        is_pending INTEGER DEFAULT 0,
        FOREIGN KEY (store_id) REFERENCES market_stores (id) ON DELETE CASCADE,
        FOREIGN KEY (trip_id) REFERENCES market_trips (id) ON DELETE CASCADE
      )
    ''');

    // 15. Market Shopping Lists Table
    await db.execute('''
      CREATE TABLE market_shopping_lists (
        id TEXT PRIMARY KEY,
        title $textType,
        date $textType,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // 16. Market Shopping List Items Table
    await db.execute('''
      CREATE TABLE market_shopping_list_items (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        is_checked INTEGER DEFAULT 0,
        quantity REAL DEFAULT 1.0,
        FOREIGN KEY (list_id) REFERENCES market_shopping_lists (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES market_products (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _seedDefaultCategories(Database db) async {
    final defaults = [
      // Income Categories
      {'id': const Uuid().v4(), 'name': 'Sueldo', 'icon': 'briefcase', 'color_hex': '#1F6F5F', 'type': 'income'},
      {'id': const Uuid().v4(), 'name': 'Freelance', 'icon': 'laptopcomputer', 'color_hex': '#2FA084', 'type': 'income'},
      {'id': const Uuid().v4(), 'name': 'Regalos', 'icon': 'gift', 'color_hex': '#6FCF97', 'type': 'income'},
      {'id': const Uuid().v4(), 'name': 'Inversiones', 'icon': 'chart_line_uptrend', 'color_hex': '#D4A373', 'type': 'income'},
      {'id': const Uuid().v4(), 'name': 'Otros', 'icon': 'ellipsis', 'color_hex': '#3B6B7B', 'type': 'income'},
      
      // Expense Categories
      {'id': const Uuid().v4(), 'name': 'Comida', 'icon': 'restaurant', 'color_hex': '#C84E4E', 'type': 'expense'},
      {'id': const Uuid().v4(), 'name': 'Transporte', 'icon': 'directions_car', 'color_hex': '#3B6B7B', 'type': 'expense'},
      {'id': const Uuid().v4(), 'name': 'Alquiler', 'icon': 'home', 'color_hex': '#7C8B64', 'type': 'expense'},
      {'id': const Uuid().v4(), 'name': 'Servicios', 'icon': 'flash_on', 'color_hex': '#D4A373', 'type': 'expense'},
      {'id': const Uuid().v4(), 'name': 'Entretenimiento', 'icon': 'sports_esports', 'color_hex': '#2FA084', 'type': 'expense'},
      {'id': const Uuid().v4(), 'name': 'Otros', 'icon': 'ellipsis', 'color_hex': '#5F8575', 'type': 'expense'},
    ];

    for (var cat in defaults) {
      await db.insert('categories', cat);
    }
  }

  // MARK: - Settings CRUD
  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // MARK: - Accounts CRUD
  Future<List<Account>> getAccounts() async {
    final db = await instance.database;
    final result = await db.query('accounts');
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future insertAccount(Account account) async {
    final db = await instance.database;
    await db.insert('accounts', account.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future updateAccount(Account account) async {
    final db = await instance.database;
    await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future deleteAccount(String id) async {
    final db = await instance.database;
    await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Pockets CRUD
  Future<List<SavingPocket>> getPockets() async {
    final db = await instance.database;
    final result = await db.query('pockets');
    return result.map((json) => SavingPocket.fromMap(json)).toList();
  }

  Future insertPocket(SavingPocket pocket) async {
    final db = await instance.database;
    await db.insert('pockets', pocket.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future updatePocket(SavingPocket pocket) async {
    final db = await instance.database;
    await db.update(
      'pockets',
      pocket.toMap(),
      where: 'id = ?',
      whereArgs: [pocket.id],
    );
  }

  Future deletePocket(String id) async {
    final db = await instance.database;
    await db.delete(
      'pockets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Categories CRUD
  Future<List<TransactionCategory>> getCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'position ASC, name ASC');
    return result.map((json) => TransactionCategory.fromMap(json)).toList();
  }

  Future insertCategory(TransactionCategory category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future updateCategory(TransactionCategory category) async {
    final db = await instance.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future deleteCategory(String id) async {
    final db = await instance.database;
    await db.delete(
      'categories',
      where: 'parent_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Transactions CRUD
  Future<List<Transaction>> getTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => Transaction.fromMap(json)).toList();
  }

  Future insertTransaction(Transaction transaction) async {
    final db = await instance.database;
    await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future updateTransactionCategory(String transactionId, String? categoryId) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future updateTransaction(Transaction transaction) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future deleteTransaction(String id) async {
    final db = await instance.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Rate History CRUD
  Future<List<ExchangeRateRecord>> getRateHistory(String type) async {
    final db = await instance.database;
    final result = await db.query(
      'rate_history',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'date DESC',
    );
    return result.map((json) => ExchangeRateRecord.fromMap(json)).toList();
  }

  Future insertRateRecord(ExchangeRateRecord record, String type) async {
    final db = await instance.database;
    final map = record.toMap();
    map['type'] = type;
    await db.insert('rate_history', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future insertRateRecords(List<ExchangeRateRecord> records, String type) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var rec in records) {
      final map = rec.toMap();
      map['type'] = type;
      batch.insert('rate_history', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future clearRateHistory(String type) async {
    final db = await instance.database;
    await db.delete(
      'rate_history',
      where: 'type = ?',
      whereArgs: [type],
    );
  }

  // MARK: - Recurring Payments CRUD
  Future<List<RecurringPayment>> getRecurringPayments() async {
    final db = await instance.database;
    final result = await db.query('recurring_payments');
    return result.map((json) => RecurringPayment.fromMap(json)).toList();
  }

  Future insertRecurringPayment(RecurringPayment payment) async {
    final db = await instance.database;
    await db.insert('recurring_payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future updateRecurringPayment(RecurringPayment payment) async {
    final db = await instance.database;
    await db.update(
      'recurring_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future deleteRecurringPayment(String id) async {
    final db = await instance.database;
    await db.delete(
      'recurring_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Global Reset
  Future clearAllData() async {
    final db = await instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.delete('settings');
      await db.delete('pockets');
      await db.delete('transactions');
      await db.delete('rate_history');
      await db.delete('recurring_payments');
      await db.delete('recurring_payment_confirmations');
      await db.delete('categories');
      await db.delete('accounts');
      await db.delete('mobile_payment_recipients');
      await _seedDefaultCategories(db);
      await db.insert('accounts', {
        'id': 'default_usd',
        'name': 'Efectivo \$',
        'currency': 'usd',
        'balance': 0.0,
        'color_hex': '#2FA084',
        'icon': 'creditcard',
      });
      await db.insert('accounts', {
        'id': 'default_ves',
        'name': 'Banco Bs.',
        'currency': 'bsBCV',
        'balance': 0.0,
        'color_hex': '#3B6B7B',
        'icon': 'creditcard',
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // MARK: - Partial Reset (keep pockets, categories, accounts - set balances to 0)
  Future clearPartialData() async {
    final db = await instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.delete('transactions');
      await db.delete('recurring_payments');
      await db.delete('recurring_payment_confirmations');
      await db.update('pockets', {'current_amount_usd': 0.0});
      await db.update('accounts', {'balance': 0.0});
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // MARK: - Recurring Payment Confirmations CRUD
  Future<List<Map<String, dynamic>>> getAllConfirmations() async {
    final db = await instance.database;
    return await db.query('recurring_payment_confirmations');
  }

  Future<List<String>> getConfirmationsForDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'recurring_payment_confirmations',
      columns: ['recurring_payment_id'],
      where: 'date = ?',
      whereArgs: [date],
    );
    return result.map((row) => row['recurring_payment_id'] as String).toList();
  }

  Future insertConfirmation(String recurringPaymentId, String date) async {
    final db = await instance.database;
    await db.insert('recurring_payment_confirmations', {
      'id': '${recurringPaymentId}_$date',
      'recurring_payment_id': recurringPaymentId,
      'date': date,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future deleteConfirmation(String recurringPaymentId, String date) async {
    final db = await instance.database;
    await db.delete(
      'recurring_payment_confirmations',
      where: 'recurring_payment_id = ? AND date = ?',
      whereArgs: [recurringPaymentId, date],
    );
  }

  // MARK: - Recurring Payment Partials CRUD
  Future<List<Map<String, dynamic>>> getAllPartials() async {
    final db = await instance.database;
    return await db.query('recurring_payment_partials');
  }

  Future insertPartial(Map<String, dynamic> partialMap) async {
    final db = await instance.database;
    await db.insert('recurring_payment_partials', partialMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future deletePartial(String id) async {
    final db = await instance.database;
    await db.delete(
      'recurring_payment_partials',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Mobile Payment Recipients CRUD
  Future<List<MobilePaymentRecipient>> getRecipients() async {
    final db = await instance.database;
    final result = await db.query('mobile_payment_recipients', orderBy: 'alias ASC');
    return result.map((json) => MobilePaymentRecipient.fromMap(json)).toList();
  }

  Future insertRecipient(MobilePaymentRecipient recipient) async {
    final db = await instance.database;
    await db.insert('mobile_payment_recipients', recipient.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future updateRecipient(MobilePaymentRecipient recipient) async {
    final db = await instance.database;
    await db.update(
      'mobile_payment_recipients',
      recipient.toMap(),
      where: 'id = ?',
      whereArgs: [recipient.id],
    );
  }

  Future deleteRecipient(String id) async {
    final db = await instance.database;
    await db.delete(
      'mobile_payment_recipients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MARK: - Profiles / Libros Config
  Future<List<Map<String, String>>> loadProfiles() async {
    final dbPath = await _getDbPath();
    final file = File(join(dbPath, 'quebrado_profiles.json'));
    if (!await file.exists()) {
      final defaultList = [
        {'id': 'quebrado.db', 'name': 'Personal'}
      ];
      final initialData = {
        'active_profile': 'quebrado.db',
        'profiles': defaultList
      };
      await file.writeAsString(jsonEncode(initialData));
      return defaultList;
    }
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final list = (data['profiles'] as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      return list;
    } catch (e) {
      return [{'id': 'quebrado.db', 'name': 'Personal'}];
    }
  }

  Future<String> getActiveProfile() async {
    final dbPath = await _getDbPath();
    final file = File(join(dbPath, 'quebrado_profiles.json'));
    if (!await file.exists()) {
      return 'quebrado.db';
    }
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['active_profile'] as String? ?? 'quebrado.db';
    } catch (e) {
      return 'quebrado.db';
    }
  }

  Future<void> saveProfiles(String activeProfile, List<Map<String, String>> profiles) async {
    final dbPath = await _getDbPath();
    final file = File(join(dbPath, 'quebrado_profiles.json'));
    final data = {
      'active_profile': activeProfile,
      'profiles': profiles
    };
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> switchProfile(String dbName) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<List<Account>> getAccountsForProfile(String profileId) async {
    // Abrir la base de datos de destino temporalmente con la estructura completa
    final targetDb = await _initDB(profileId);
    final result = await targetDb.query('accounts');
    await targetDb.close();
    
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getPendingDataForProfile(String profileId) async {
    // Abrir la base temporalmente asegurando que su esquema está creado
    final targetDb = await _initDB(profileId);
    
    final recList = await targetDb.query('recurring_payments');
    final confList = await targetDb.query('recurring_payment_confirmations');
    final partList = await targetDb.query('recurring_payment_partials');
    
    await targetDb.close();
    
    return {
      'recurring': recList.map((j) => RecurringPayment.fromMap(j)).toList(),
      'confirmations': confList,
      'partials': partList.map((j) => RecurringPaymentPartial.fromMap(j)).toList(),
    };
  }

  Future<void> insertCrossProfileTransaction(String targetProfileId, Transaction tx, Account targetAccount) async {
    // Abrir la base de datos de destino temporalmente con esquema completo
    final targetDb = await _initDB(targetProfileId);
    
    // Insertar la transacción (Ingreso)
    await targetDb.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Actualizar el balance de la cuenta destino
    double amountInAccCurrency = tx.amount;
    if (tx.currency == CurrencyType.usd && targetAccount.currency == CurrencyType.bsBCV) {
      amountInAccCurrency = tx.amount * (tx.exchangeRate > 0 ? tx.exchangeRate : 1.0);
    } else if (tx.currency == CurrencyType.bsBCV && targetAccount.currency == CurrencyType.usd) {
      amountInAccCurrency = tx.exchangeRate > 0 ? tx.amount / tx.exchangeRate : 0.0;
    }
    
    if (tx.type == TransactionType.income) {
      targetAccount.balance += amountInAccCurrency;
    } else {
      targetAccount.balance -= amountInAccCurrency;
    }
    
    await targetDb.update(
      'accounts',
      targetAccount.toMap(),
      where: 'id = ?',
      whereArgs: [targetAccount.id],
    );
    
    await targetDb.close();
  }

  Future<void> deleteDatabaseFile(String dbName) async {
    if (dbName == 'quebrado.db') return;
    final dbPath = await _getDbPath();
    final file = File(join(dbPath, dbName));
    if (await file.exists()) {
      await file.delete();
    }
    final journalFile = File(join(dbPath, '$dbName-journal'));
    if (await journalFile.exists()) {
      await journalFile.delete();
    }
  }

  // MARK: - Backup Management System

  Future<String> getBackupMetadataPath() async {
    final dbPath = await _getDbPath();
    return join(dbPath, 'quebrado_backup_metadata.json');
  }

  Future<Map<String, dynamic>> loadBackupMetadata() async {
    final path = await getBackupMetadataPath();
    final file = File(path);
    if (!await file.exists()) {
      final initial = {
        'security_pin': '',
        'last_auto_backup_date': '',
        'restore_history': <dynamic>[]
      };
      await file.writeAsString(jsonEncode(initial));
      return initial;
    }
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {
        'security_pin': '',
        'last_auto_backup_date': '',
        'restore_history': <dynamic>[]
      };
    }
  }

  Future<void> saveBackupMetadata(Map<String, dynamic> metadata) async {
    final path = await getBackupMetadataPath();
    final file = File(path);
    await file.writeAsString(jsonEncode(metadata));
  }

  Future<void> checkAndPerformAutoBackup() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final metadata = await loadBackupMetadata();
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final lastDate = metadata['last_auto_backup_date'] as String? ?? '';
      
      if (lastDate != dateStr) {
        await performBackupInternal('auto_backup_$dateStr');
        metadata['last_auto_backup_date'] = dateStr;
        await saveBackupMetadata(metadata);
      }
    } catch (e) {
      print("Error performing auto backup: $e");
    }
  }

  Future<void> performBackupInternal(String folderName) async {
    final dbPath = await _getDbPath();
    final backupsDir = Directory(join(dbPath, 'backups', folderName));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    // 1. Copy profiles config
    final profilesFile = File(join(dbPath, 'quebrado_profiles.json'));
    if (await profilesFile.exists()) {
      await profilesFile.copy(join(backupsDir.path, 'quebrado_profiles.json'));
    }

    // 2. Load profiles list to copy all databases
    final profilesList = await loadProfiles();
    for (var prof in profilesList) {
      final dbName = prof['id'];
      if (dbName != null) {
        final dbFile = File(join(dbPath, dbName));
        if (await dbFile.exists()) {
          await dbFile.copy(join(backupsDir.path, dbName));
        }
      }
    }
  }

  Future<String> performManualBackup() async {
    final now = DateTime.now();
    final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final folderName = 'manual_backup_$timestamp';
    await performBackupInternal(folderName);
    return folderName;
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final dbPath = await _getDbPath();
    final backupsParent = Directory(join(dbPath, 'backups'));
    if (!await backupsParent.exists()) {
      return [];
    }

    final List<Map<String, dynamic>> results = [];
    final entities = await backupsParent.list().toList();
    for (var entity in entities) {
      if (entity is Directory) {
        final folderName = basename(entity.path);
        double sizeBytes = 0.0;
        try {
          final files = await entity.list().toList();
          for (var file in files) {
            if (file is File) {
              sizeBytes += await file.length();
            }
          }
        } catch (_) {}

        final stat = await entity.stat();
        final isAuto = folderName.startsWith('auto_backup_');
        
        DateTime createdAt;
        try {
          if (isAuto) {
            final dateStr = folderName.replaceFirst('auto_backup_', '');
            final parts = dateStr.split('-');
            createdAt = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            final tsStr = folderName.replaceFirst('manual_backup_', '');
            final parts = tsStr.split('_');
            final datePart = parts[0];
            final timePart = parts[1];
            createdAt = DateTime(
              int.parse(datePart.substring(0, 4)),
              int.parse(datePart.substring(4, 6)),
              int.parse(datePart.substring(6, 8)),
              int.parse(timePart.substring(0, 2)),
              int.parse(timePart.substring(2, 4)),
              int.parse(timePart.substring(4, 6)),
            );
          }
        } catch (_) {
          createdAt = stat.changed;
        }

        results.add({
          'name': folderName,
          'path': entity.path,
          'created_at': createdAt,
          'is_auto': isAuto,
          'size_bytes': sizeBytes,
        });
      }
    }

    results.sort((a, b) => (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));
    return results;
  }

  Future<void> deleteBackup(String folderName) async {
    final dbPath = await _getDbPath();
    final dir = Directory(join(dbPath, 'backups', folderName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<bool> restoreBackup(String folderName) async {
    final dbPath = await _getDbPath();
    final backupDir = Directory(join(dbPath, 'backups', folderName));
    if (!await backupDir.exists()) {
      return false;
    }

    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final files = await backupDir.list().toList();
      for (var f in files) {
        if (f is File) {
          final name = basename(f.path);
          await f.copy(join(dbPath, name));
        }
      }

      final metadata = await loadBackupMetadata();
      final restoreHistory = List<Map<String, dynamic>>.from(
        metadata['restore_history'] as List? ?? []
      );
      restoreHistory.add({
        'backup_name': folderName,
        'restored_at': DateTime.now().toIso8601String(),
        'success': true,
      });
      metadata['restore_history'] = restoreHistory;
      await saveBackupMetadata(metadata);

      return true;
    } catch (e) {
      print("Error restoring backup: $e");
      final metadata = await loadBackupMetadata();
      final restoreHistory = List<Map<String, dynamic>>.from(
        metadata['restore_history'] as List? ?? []
      );
      restoreHistory.add({
        'backup_name': folderName,
        'restored_at': DateTime.now().toIso8601String(),
        'success': false,
        'error': e.toString(),
      });
      metadata['restore_history'] = restoreHistory;
      await saveBackupMetadata(metadata);
      return false;
    }
  }

  Future<Map<String, dynamic>> getBackupPreview(String folderPath) async {
    final Map<String, dynamic> preview = {
      'profiles': [],
      'total_transactions': 0,
      'total_pockets': 0,
      'total_market_items': 0,
    };

    try {
      final profilesFile = File(join(folderPath, 'quebrado_profiles.json'));
      if (await profilesFile.exists()) {
        final content = await profilesFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final profilesList = data['profiles'] as List? ?? [];
        
        int transCount = 0;
        int pocketsCount = 0;
        int itemsCount = 0;
        
        final List<Map<String, dynamic>> profilesPreview = [];
        
        for (var p in profilesList) {
          final dbName = p['id'] as String;
          final name = p['name'] as String;
          final dbFile = File(join(folderPath, dbName));
          
          if (await dbFile.exists()) {
            final tempDb = await openDatabase(dbFile.path, readOnly: true);
            
            List<Map<String, dynamic>> accountsList = [];
            try {
              accountsList = await tempDb.query('accounts');
            } catch (_) {}
            
            try {
              final txRes = Sqflite.firstIntValue(await tempDb.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
              transCount += txRes;
            } catch (_) {}
            
            try {
              final pkRes = Sqflite.firstIntValue(await tempDb.rawQuery('SELECT COUNT(*) FROM pockets')) ?? 0;
              pocketsCount += pkRes;
            } catch (_) {}
            
            try {
              final mkRes = Sqflite.firstIntValue(await tempDb.rawQuery('SELECT COUNT(*) FROM market_items')) ?? 0;
              itemsCount += mkRes;
            } catch (_) {}
            
            await tempDb.close();
            
            profilesPreview.add({
              'name': name,
              'accounts': accountsList.map((a) => {
                'name': a['name'],
                'balance': a['balance'],
                'currency': a['currency'],
              }).toList(),
            });
          }
        }
        
        preview['profiles'] = profilesPreview;
        preview['total_transactions'] = transCount;
        preview['total_pockets'] = pocketsCount;
        preview['total_market_items'] = itemsCount;
      }
    } catch (e) {
      print("Error loading backup preview: $e");
    }
    
    return preview;
  }

  // MARK: - Market Stores CRUD
  Future<List<MarketStore>> getMarketStores() async {
    final db = await instance.database;
    final result = await db.query('market_stores', orderBy: 'name ASC');
    return result.map((json) => MarketStore.fromMap(json)).toList();
  }

  Future<void> insertMarketStore(MarketStore store) async {
    final db = await instance.database;
    await db.insert('market_stores', store.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMarketStore(MarketStore store) async {
    final db = await instance.database;
    await db.update(
      'market_stores',
      store.toMap(),
      where: 'id = ?',
      whereArgs: [store.id],
    );
  }

  Future<void> deleteMarketStore(String id) async {
    final db = await instance.database;
    await db.delete('market_stores', where: 'id = ?', whereArgs: [id]);
  }

  // MARK: - Market Items CRUD
  Future<List<MarketItem>> getMarketItems() async {
    final db = await instance.database;
    final result = await db.query('market_items', orderBy: 'date DESC');
    return result.map((json) => MarketItem.fromMap(json)).toList();
  }

  Future<void> insertMarketItem(MarketItem item) async {
    final db = await instance.database;
    await db.insert('market_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMarketItem(String id) async {
    final db = await instance.database;
    await db.delete('market_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMarketItem(MarketItem item) async {
    final db = await instance.database;
    await db.update(
      'market_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // MARK: - Market Products CRUD
  Future<List<MarketProduct>> getMarketProducts() async {
    final db = await instance.database;
    final result = await db.query('market_products', orderBy: 'name ASC');
    return result.map((json) => MarketProduct.fromMap(json)).toList();
  }

  Future<void> insertMarketProduct(MarketProduct product) async {
    final db = await instance.database;
    await db.insert('market_products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMarketProduct(MarketProduct product) async {
    final db = await instance.database;
    await db.update(
      'market_products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteMarketProduct(String id) async {
    final db = await instance.database;
    await db.delete('market_products', where: 'id = ?', whereArgs: [id]);
  }

  // MARK: - Market Trips CRUD
  Future<List<MarketTrip>> getMarketTrips() async {
    final db = await instance.database;
    final result = await db.query('market_trips', orderBy: 'date DESC');
    return result.map((json) => MarketTrip.fromMap(json)).toList();
  }

  Future<void> insertMarketTrip(MarketTrip trip) async {
    final db = await instance.database;
    await db.insert('market_trips', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMarketTrip(String id) async {
    final db = await instance.database;
    await db.delete('market_trips', where: 'id = ?', whereArgs: [id]);
  }

  // MARK: - Market Shopping Lists CRUD
  Future<List<MarketShoppingList>> getMarketShoppingLists() async {
    final db = await instance.database;
    final result = await db.query('market_shopping_lists', orderBy: 'date DESC');
    return result.map((json) => MarketShoppingList.fromMap(json)).toList();
  }

  Future<void> insertMarketShoppingList(MarketShoppingList list) async {
    final db = await instance.database;
    await db.insert('market_shopping_lists', list.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMarketShoppingList(MarketShoppingList list) async {
    final db = await instance.database;
    await db.update(
      'market_shopping_lists',
      list.toMap(),
      where: 'id = ?',
      whereArgs: [list.id],
    );
  }

  Future<void> deleteMarketShoppingList(String id) async {
    final db = await instance.database;
    await db.delete('market_shopping_lists', where: 'id = ?', whereArgs: [id]);
  }

  // MARK: - Market Shopping List Items CRUD
  Future<List<MarketShoppingListItem>> getMarketShoppingListItems() async {
    final db = await instance.database;
    final result = await db.query('market_shopping_list_items');
    return result.map((json) => MarketShoppingListItem.fromMap(json)).toList();
  }

  Future<void> insertMarketShoppingListItem(MarketShoppingListItem item) async {
    final db = await instance.database;
    await db.insert('market_shopping_list_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMarketShoppingListItem(MarketShoppingListItem item) async {
    final db = await instance.database;
    await db.update(
      'market_shopping_list_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteMarketShoppingListItem(String id) async {
    final db = await instance.database;
    await db.delete('market_shopping_list_items', where: 'id = ?', whereArgs: [id]);
  }
}
