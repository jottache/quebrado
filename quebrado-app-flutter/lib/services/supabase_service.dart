import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../quebrado/models/account.dart';
import '../quebrado/models/saving_pocket.dart';
import '../quebrado/models/transaction_category.dart';
import '../quebrado/models/transaction.dart';
import '../quebrado/models/recurring_payment.dart';
import '../quebrado/models/recurring_payment_partial.dart';
import '../quebrado/models/mobile_payment_recipient.dart';
import '../quebrado/models/market_store.dart';
import '../quebrado/models/market_product.dart';
import '../quebrado/models/market_item.dart';
import '../quebrado/models/market_trip.dart';
import '../quebrado/models/market_shopping_list.dart';
import '../quebrado/models/market_shopping_list_item.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => client != null;

  // MARK: - Settings
  Future<Map<String, String>> loadSettings() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('settings').select();
      final Map<String, String> settings = {};
      for (var row in response) {
        if (row['key'] != null && row['value'] != null) {
          settings[row['key'] as String] = row['value'] as String;
        }
      }
      return settings;
    } catch (e) {
      debugPrint('Error loading settings from Supabase: $e');
      return {};
    }
  }

  Future<void> saveSetting(String key, String value) async {
    if (!isReady) return;
    try {
      await client!.from('settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving setting to Supabase: $e');
    }
  }

  // MARK: - Profiles (Libros Contables)
  Future<List<Map<String, String>>> loadProfiles() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('profiles').select();
      return response.map<Map<String, String>>((row) {
        return {
          'id': row['id'] as String? ?? 'quebrado.db',
          'name': row['name'] as String? ?? 'Personal',
          'is_active': (row['is_active'] == true).toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading profiles from Supabase: $e');
      return [];
    }
  }

  Future<void> saveProfiles(String activeProfile, List<Map<String, String>> profiles) async {
    if (!isReady) return;
    try {
      for (var p in profiles) {
        await client!.from('profiles').upsert({
          'id': p['id'],
          'name': p['name'],
          'is_active': p['id'] == activeProfile,
        });
      }
    } catch (e) {
      debugPrint('Error saving profiles to Supabase: $e');
    }
  }

  // MARK: - Accounts
  Future<List<Account>> getAccounts({String? profileId = 'quebrado.db'}) async {
    if (!isReady) return [];
    try {
      var query = client!.from('accounts').select();
      if (profileId != null) {
        query = query.eq('profile_id', profileId);
      }
      final List response = await query;
      return response.map((row) => Account.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading accounts from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, List<Account>>> getAllAccountsByProfile() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('accounts').select();
      final Map<String, List<Account>> map = {};
      for (var row in response) {
        final profileId = row['profile_id'] as String? ?? 'quebrado.db';
        map.putIfAbsent(profileId, () => []).add(Account.fromMap(Map<String, dynamic>.from(row)));
      }
      return map;
    } catch (e) {
      debugPrint('Error loading all accounts by profile: $e');
      return {};
    }
  }

  Future<void> insertAccount(Account account, {String profileId = 'quebrado.db'}) async {
    if (!isReady) return;
    try {
      final map = account.toMap();
      map['profile_id'] = profileId;
      await client!.from('accounts').insert(map);
    } catch (e) {
      debugPrint('Error inserting account to Supabase: $e');
    }
  }

  Future<void> updateAccount(Account account) async {
    if (!isReady) return;
    try {
      await client!.from('accounts').update(account.toMap()).eq('id', account.id);
    } catch (e) {
      debugPrint('Error updating account in Supabase: $e');
    }
  }

  Future<void> deleteAccount(String id) async {
    if (!isReady) return;
    try {
      await client!.from('accounts').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting account from Supabase: $e');
    }
  }

  // MARK: - Pockets
  Future<List<SavingPocket>> getPockets({String? profileId = 'quebrado.db'}) async {
    if (!isReady) return [];
    try {
      var query = client!.from('pockets').select();
      if (profileId != null) {
        query = query.eq('profile_id', profileId);
      }
      final List response = await query;
      return response.map((row) => SavingPocket.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading pockets from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, List<SavingPocket>>> getAllPocketsByProfile() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('pockets').select();
      final Map<String, List<SavingPocket>> map = {};
      for (var row in response) {
        final profileId = row['profile_id'] as String? ?? 'quebrado.db';
        map.putIfAbsent(profileId, () => []).add(SavingPocket.fromMap(Map<String, dynamic>.from(row)));
      }
      return map;
    } catch (e) {
      debugPrint('Error loading all pockets by profile: $e');
      return {};
    }
  }

  Future<void> insertPocket(SavingPocket pocket, {String profileId = 'quebrado.db'}) async {
    if (!isReady) return;
    try {
      final map = pocket.toMap();
      map['profile_id'] = profileId;
      await client!.from('pockets').insert(map);
    } catch (e) {
      debugPrint('Error inserting pocket to Supabase: $e');
    }
  }

  Future<void> updatePocket(SavingPocket pocket) async {
    if (!isReady) return;
    try {
      await client!.from('pockets').update(pocket.toMap()).eq('id', pocket.id);
    } catch (e) {
      debugPrint('Error updating pocket in Supabase: $e');
    }
  }

  Future<void> deletePocket(String id) async {
    if (!isReady) return;
    try {
      await client!.from('pockets').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting pocket from Supabase: $e');
    }
  }

  // MARK: - Categories
  Future<List<TransactionCategory>> getCategories({String? profileId = 'quebrado.db'}) async {
    if (!isReady) return [];
    try {
      var query = client!.from('categories').select();
      if (profileId != null) {
        query = query.eq('profile_id', profileId);
      }
      final List response = await query.order('position', ascending: true);
      return response.map((row) => TransactionCategory.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading categories from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, List<TransactionCategory>>> getAllCategoriesByProfile() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('categories').select().order('position', ascending: true);
      final Map<String, List<TransactionCategory>> map = {};
      for (var row in response) {
        final profileId = row['profile_id'] as String? ?? 'quebrado.db';
        map.putIfAbsent(profileId, () => []).add(TransactionCategory.fromMap(Map<String, dynamic>.from(row)));
      }
      return map;
    } catch (e) {
      debugPrint('Error loading all categories by profile: $e');
      return {};
    }
  }

  Future<void> insertCategory(TransactionCategory category, {String profileId = 'quebrado.db'}) async {
    if (!isReady) return;
    try {
      final map = category.toMap();
      map['profile_id'] = profileId;
      await client!.from('categories').insert(map);
    } catch (e) {
      debugPrint('Error inserting category to Supabase: $e');
    }
  }

  Future<void> updateCategory(TransactionCategory category) async {
    if (!isReady) return;
    try {
      await client!.from('categories').update(category.toMap()).eq('id', category.id);
    } catch (e) {
      debugPrint('Error updating category in Supabase: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    if (!isReady) return;
    try {
      await client!.from('categories').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting category from Supabase: $e');
    }
  }

  // MARK: - Transactions
  Future<List<Transaction>> getTransactions({String? profileId = 'quebrado.db'}) async {
    if (!isReady) return [];
    try {
      var query = client!.from('transactions').select();
      if (profileId != null) {
        query = query.eq('profile_id', profileId);
      }
      final List response = await query.order('date', ascending: false);
      return response.map((row) => Transaction.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading transactions from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, List<Transaction>>> getAllTransactionsByProfile() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('transactions').select().order('date', ascending: false);
      final Map<String, List<Transaction>> map = {};
      for (var row in response) {
        final profileId = row['profile_id'] as String? ?? 'quebrado.db';
        map.putIfAbsent(profileId, () => []).add(Transaction.fromMap(Map<String, dynamic>.from(row)));
      }
      return map;
    } catch (e) {
      debugPrint('Error loading all transactions by profile: $e');
      return {};
    }
  }

  Future<void> insertTransaction(Transaction transaction, {String profileId = 'quebrado.db'}) async {
    if (!isReady) return;
    try {
      final map = transaction.toMap();
      map['profile_id'] = profileId;
      await client!.from('transactions').insert(map);
    } catch (e) {
      debugPrint('Error inserting transaction to Supabase: $e');
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    if (!isReady) return;
    try {
      await client!.from('transactions').update(transaction.toMap()).eq('id', transaction.id);
    } catch (e) {
      debugPrint('Error updating transaction in Supabase: $e');
    }
  }

  Future<void> deleteTransaction(String id) async {
    if (!isReady) return;
    try {
      await client!.from('transactions').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting transaction from Supabase: $e');
    }
  }

  // MARK: - Recurring Payments
  Future<List<RecurringPayment>> getRecurringPayments({String? profileId = 'quebrado.db'}) async {
    if (!isReady) return [];
    try {
      var query = client!.from('recurring_payments').select();
      if (profileId != null) {
        query = query.eq('profile_id', profileId);
      }
      final List response = await query;
      return response.map((row) => RecurringPayment.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading recurring payments from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, List<RecurringPayment>>> getAllRecurringPaymentsByProfile() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('recurring_payments').select();
      final Map<String, List<RecurringPayment>> map = {};
      for (var row in response) {
        final profileId = row['profile_id'] as String? ?? 'quebrado.db';
        map.putIfAbsent(profileId, () => []).add(RecurringPayment.fromMap(Map<String, dynamic>.from(row)));
      }
      return map;
    } catch (e) {
      debugPrint('Error loading all recurring payments by profile: $e');
      return {};
    }
  }

  Future<void> insertRecurringPayment(RecurringPayment payment, {String profileId = 'quebrado.db'}) async {
    if (!isReady) return;
    try {
      final map = payment.toMap();
      map['profile_id'] = profileId;
      await client!.from('recurring_payments').insert(map);
    } catch (e) {
      debugPrint('Error inserting recurring payment to Supabase: $e');
    }
  }

  Future<void> updateRecurringPayment(RecurringPayment payment) async {
    if (!isReady) return;
    try {
      await client!.from('recurring_payments').update(payment.toMap()).eq('id', payment.id);
    } catch (e) {
      debugPrint('Error updating recurring payment in Supabase: $e');
    }
  }

  Future<void> deleteRecurringPayment(String id) async {
    if (!isReady) return;
    try {
      await client!.from('recurring_payments').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting recurring payment from Supabase: $e');
    }
  }

  // MARK: - Confirmations
  Future<Set<String>> getConfirmedPaymentKeys() async {
    if (!isReady) return {};
    try {
      final List response = await client!.from('recurring_payment_confirmations').select('id');
      return response.map<String>((row) => row['id'] as String).toSet();
    } catch (e) {
      debugPrint('Error loading confirmations from Supabase: $e');
      return {};
    }
  }

  Future<void> insertConfirmation(String id, String recurringPaymentId, String dateStr) async {
    if (!isReady) return;
    try {
      await client!.from('recurring_payment_confirmations').insert({
        'id': id,
        'recurring_payment_id': recurringPaymentId,
        'date': dateStr,
      });
    } catch (e) {
      debugPrint('Error inserting confirmation to Supabase: $e');
    }
  }

  Future<void> deleteConfirmation(String recurringPaymentId, String dateStr) async {
    if (!isReady) return;
    try {
      await client!
          .from('recurring_payment_confirmations')
          .delete()
          .eq('recurring_payment_id', recurringPaymentId)
          .eq('date', dateStr);
    } catch (e) {
      debugPrint('Error deleting confirmation from Supabase: $e');
    }
  }

  // MARK: - Partials
  Future<List<RecurringPaymentPartial>> getPartials() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('recurring_payment_partials').select();
      return response.map((row) => RecurringPaymentPartial.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading partials from Supabase: $e');
      return [];
    }
  }

  Future<void> insertPartial(RecurringPaymentPartial partial) async {
    if (!isReady) return;
    try {
      await client!.from('recurring_payment_partials').insert(partial.toMap());
    } catch (e) {
      debugPrint('Error inserting partial to Supabase: $e');
    }
  }

  Future<void> deletePartial(String id) async {
    if (!isReady) return;
    try {
      await client!.from('recurring_payment_partials').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting partial from Supabase: $e');
    }
  }

  // MARK: - Mobile Payment Recipients
  Future<List<MobilePaymentRecipient>> getRecipients() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('mobile_payment_recipients').select();
      return response.map((row) => MobilePaymentRecipient.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading recipients from Supabase: $e');
      return [];
    }
  }

  Future<void> insertRecipient(MobilePaymentRecipient recipient) async {
    if (!isReady) return;
    try {
      await client!.from('mobile_payment_recipients').insert(recipient.toMap());
    } catch (e) {
      debugPrint('Error inserting recipient to Supabase: $e');
    }
  }

  Future<void> updateRecipient(MobilePaymentRecipient recipient) async {
    if (!isReady) return;
    try {
      await client!.from('mobile_payment_recipients').update(recipient.toMap()).eq('id', recipient.id);
    } catch (e) {
      debugPrint('Error updating recipient in Supabase: $e');
    }
  }

  Future<void> deleteRecipient(String id) async {
    if (!isReady) return;
    try {
      await client!.from('mobile_payment_recipients').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting recipient from Supabase: $e');
    }
  }

  // MARK: - Market Module
  Future<List<MarketStore>> getMarketStores() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('market_stores').select();
      return response.map((row) => MarketStore.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading market stores from Supabase: $e');
      return [];
    }
  }

  Future<void> insertMarketStore(MarketStore store) async {
    if (!isReady) return;
    try {
      await client!.from('market_stores').insert(store.toMap());
    } catch (e) {
      debugPrint('Error inserting market store to Supabase: $e');
    }
  }

  Future<void> deleteMarketStore(String id) async {
    if (!isReady) return;
    try {
      await client!.from('market_stores').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting market store from Supabase: $e');
    }
  }

  Future<List<MarketProduct>> getMarketProducts() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('market_products').select();
      return response.map((row) => MarketProduct.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading market products from Supabase: $e');
      return [];
    }
  }

  Future<void> insertMarketProduct(MarketProduct product) async {
    if (!isReady) return;
    try {
      await client!.from('market_products').insert(product.toMap());
    } catch (e) {
      debugPrint('Error inserting market product to Supabase: $e');
    }
  }

  Future<void> deleteMarketProduct(String id) async {
    if (!isReady) return;
    try {
      await client!.from('market_products').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting market product from Supabase: $e');
    }
  }

  Future<List<MarketTrip>> getMarketTrips() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('market_trips').select();
      return response.map((row) => MarketTrip.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading market trips from Supabase: $e');
      return [];
    }
  }

  Future<void> insertMarketTrip(MarketTrip trip) async {
    if (!isReady) return;
    try {
      await client!.from('market_trips').insert(trip.toMap());
    } catch (e) {
      debugPrint('Error inserting market trip to Supabase: $e');
    }
  }

  Future<void> updateMarketTrip(MarketTrip trip) async {
    if (!isReady) return;
    try {
      await client!.from('market_trips').update(trip.toMap()).eq('id', trip.id);
    } catch (e) {
      debugPrint('Error updating market trip in Supabase: $e');
    }
  }

  Future<void> deleteMarketTrip(String id) async {
    if (!isReady) return;
    try {
      await client!.from('market_trips').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting market trip from Supabase: $e');
    }
  }

  Future<List<MarketItem>> getMarketItems() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('market_items').select();
      return response.map((row) => MarketItem.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading market items from Supabase: $e');
      return [];
    }
  }

  Future<void> insertMarketItem(MarketItem item) async {
    if (!isReady) return;
    try {
      await client!.from('market_items').insert(item.toMap());
    } catch (e) {
      debugPrint('Error inserting market item to Supabase: $e');
    }
  }

  Future<void> deleteMarketItem(String id) async {
    if (!isReady) return;
    try {
      await client!.from('market_items').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting market item from Supabase: $e');
    }
  }

  Future<List<MarketShoppingList>> getMarketShoppingLists() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('market_shopping_lists').select();
      return response.map((row) => MarketShoppingList.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading shopping lists from Supabase: $e');
      return [];
    }
  }

  Future<void> insertMarketShoppingList(MarketShoppingList list) async {
    if (!isReady) return;
    try {
      await client!.from('market_shopping_lists').insert(list.toMap());
    } catch (e) {
      debugPrint('Error inserting shopping list to Supabase: $e');
    }
  }

  Future<void> deleteMarketShoppingList(String id) async {
    if (!isReady) return;
    try {
      await client!.from('market_shopping_lists').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting shopping list from Supabase: $e');
    }
  }

  Future<List<MarketShoppingListItem>> getMarketShoppingListItems() async {
    if (!isReady) return [];
    try {
      final List response = await client!.from('market_shopping_list_items').select();
      return response.map((row) => MarketShoppingListItem.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('Error loading shopping list items from Supabase: $e');
      return [];
    }
  }

  Future<void> insertMarketShoppingListItem(MarketShoppingListItem item) async {
    if (!isReady) return;
    try {
      await client!.from('market_shopping_list_items').insert(item.toMap());
    } catch (e) {
      debugPrint('Error inserting shopping list item to Supabase: $e');
    }
  }

  Future<void> updateMarketShoppingListItem(MarketShoppingListItem item) async {
    if (!isReady) return;
    try {
      await client!.from('market_shopping_list_items').update(item.toMap()).eq('id', item.id);
    } catch (e) {
      debugPrint('Error updating shopping list item in Supabase: $e');
    }
  }

  Future<void> deleteMarketShoppingListItem(String id) async {
    if (!isReady) return;
    try {
      await client!.from('market_shopping_list_items').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting shopping list item from Supabase: $e');
    }
  }

  // MARK: - Backup & Restore Sync to Supabase Cloud
  Future<void> importBackupData(Map<String, dynamic> backupData, {String? fileName}) async {
    if (!isReady) throw Exception("Supabase no está configurado o inicializado.");

    try {
      // 1. Intentar importación atómica ultra rápida mediante RPC en Supabase
      bool rpcSuccess = false;
      try {
        final rpcRes = await client!.rpc('import_quebrado_backup', params: {
          'backup_data': backupData,
        });
        debugPrint("Supabase RPC import successful: $rpcRes");
        rpcSuccess = true;
      } catch (rpcErr) {
        debugPrint("RPC import_quebrado_backup no disponible ($rpcErr). Usando importación por lotes.");
      }

      if (!rpcSuccess) {
        final bool isMultiProfile = backupData['__multi_profile_backup__'] == true;
        Map<String, dynamic> databases = {};
        List<Map<String, dynamic>> profilesToSave = [];
        String activeProfile = 'quebrado.db';

      if (isMultiProfile) {
        final profilesConfig = backupData['profiles_config'];
        if (profilesConfig is Map) {
          activeProfile = profilesConfig['active_profile']?.toString() ?? 'quebrado.db';
          final pList = profilesConfig['profiles'];
          if (pList is List) {
            for (var p in pList) {
              if (p is Map) {
                profilesToSave.add({
                  'id': p['id']?.toString() ?? 'quebrado.db',
                  'name': p['name']?.toString() ?? 'Personal',
                  'is_active': (p['id']?.toString() ?? '') == activeProfile,
                });
              }
            }
          }
        }
        final dbs = backupData['databases'];
        if (dbs is Map<String, dynamic>) {
          databases = dbs;
        }
      } else {
        // Single profile legacy backup
        profilesToSave.add({
          'id': 'quebrado.db',
          'name': 'Personal',
          'is_active': true,
        });
        databases['quebrado.db'] = backupData;
      }

      if (profilesToSave.isEmpty) {
        profilesToSave.add({
          'id': 'quebrado.db',
          'name': 'Personal',
          'is_active': true,
        });
      }

      // 1. Upsert profiles
      for (var prof in profilesToSave) {
        await client!.from('profiles').upsert(prof);
      }

      // 2. Iterate each database (profile)
      for (var entry in databases.entries) {
        final profileId = entry.key;
        final dbData = entry.value;
        if (dbData is! Map) continue;

        // A. Settings (Skip system backup state so imported files do not overwrite cloud snapshots or metadata)
        final settingsRows = dbData['settings'];
        if (settingsRows is List && settingsRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in settingsRows) {
            if (r is Map && r['key'] != null && r['value'] != null) {
              final k = r['key']?.toString();
              if (k == 'backup_snapshots' || k == 'backup_metadata') continue;
              list.add({
                'key': k,
                'value': r['value']?.toString(),
              });
            }
          }
          if (list.isNotEmpty) {
            await _batchUpsert('settings', list);
          }
        }

        // B. Categories (Two passes: root categories first, then subcategories with parent_id)
        final categoryRows = dbData['categories'];
        if (categoryRows is List && categoryRows.isNotEmpty) {
          final List<Map<String, dynamic>> rootCats = [];
          final List<Map<String, dynamic>> subCats = [];

          for (var r in categoryRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              map['profile_id'] = profileId;
              final parentId = map['parent_id']?.toString().trim();
              if (parentId == null || parentId.isEmpty) {
                map['parent_id'] = null;
                rootCats.add(map);
              } else {
                map['parent_id'] = parentId;
                subCats.add(map);
              }
            }
          }

          await _batchUpsert('categories', rootCats);
          await _batchUpsert('categories', subCats);
        }

        // C. Accounts
        final accountRows = dbData['accounts'];
        if (accountRows is List && accountRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in accountRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              map['profile_id'] = profileId;
              list.add(map);
            }
          }
          await _batchUpsert('accounts', list);
        }

        // D. Pockets
        final pocketRows = dbData['pockets'];
        if (pocketRows is List && pocketRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in pocketRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              map['profile_id'] = profileId;
              if (map['is_archived'] is int) {
                map['is_archived'] = map['is_archived'] == 1;
              }
              list.add(map);
            }
          }
          await _batchUpsert('pockets', list);
        }

        // E. Transactions
        final transactionRows = dbData['transactions'];
        if (transactionRows is List && transactionRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in transactionRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              map['profile_id'] = profileId;
              if (map['destination_pocket_id'] == '') map['destination_pocket_id'] = null;
              if (map['category_id'] == '') map['category_id'] = null;
              if (map['account_id'] == '') map['account_id'] = null;
              list.add(map);
            }
          }
          await _batchUpsert('transactions', list);
        }

        // F. Rate history
        final rateRows = dbData['rate_history'];
        if (rateRows is List && rateRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in rateRows) {
            if (r is Map) {
              list.add(Map<String, dynamic>.from(r));
            }
          }
          await _batchUpsert('rate_history', list);
        }

        // G. Recurring payments
        final recurringRows = dbData['recurring_payments'];
        if (recurringRows is List && recurringRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in recurringRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              map['profile_id'] = profileId;
              if (map['pocket_id'] == '') map['pocket_id'] = null;
              if (map['account_id'] == '') map['account_id'] = null;
              if (map['is_variable'] is int) {
                map['is_variable'] = map['is_variable'] == 1;
              }
              list.add(map);
            }
          }
          await _batchUpsert('recurring_payments', list);
        }

        // H. Recurring payment confirmations
        final confirmationRows = dbData['recurring_payment_confirmations'];
        if (confirmationRows is List && confirmationRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in confirmationRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              if (!map.containsKey('id') || map['id'] == null) {
                map['id'] = "${map['recurring_payment_id']}_${map['date']}";
              }
              list.add(map);
            }
          }
          await _batchUpsert('recurring_payment_confirmations', list);
        }

        // I. Recurring payment partials
        final partialRows = dbData['recurring_payment_partials'];
        if (partialRows is List && partialRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in partialRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              if (map['transaction_id'] == '') map['transaction_id'] = null;
              list.add(map);
            }
          }
          await _batchUpsert('recurring_payment_partials', list);
        }

        // J. Mobile payment recipients
        final recipientRows = dbData['mobile_payment_recipients'];
        if (recipientRows is List && recipientRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in recipientRows) {
            if (r is Map) {
              list.add(Map<String, dynamic>.from(r));
            }
          }
          await _batchUpsert('mobile_payment_recipients', list);
        }

        // K. Market stores
        final storeRows = dbData['market_stores'];
        if (storeRows is List && storeRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in storeRows) {
            if (r is Map) {
              list.add(Map<String, dynamic>.from(r));
            }
          }
          await _batchUpsert('market_stores', list);
        }

        // L. Market products
        final productRows = dbData['market_products'];
        if (productRows is List && productRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in productRows) {
            if (r is Map) {
              list.add(Map<String, dynamic>.from(r));
            }
          }
          await _batchUpsert('market_products', list);
        }

        // M. Market trips
        final tripRows = dbData['market_trips'];
        if (tripRows is List && tripRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in tripRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              if (map['is_active'] is int) {
                map['is_active'] = map['is_active'] == 1;
              }
              if (map['store_id'] == '') map['store_id'] = null;
              if (map['transaction_id'] == '') map['transaction_id'] = null;
              list.add(map);
            }
          }
          await _batchUpsert('market_trips', list);
        }

        // N. Market items
        final itemRows = dbData['market_items'];
        if (itemRows is List && itemRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in itemRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              if (map['is_pending'] is int) {
                map['is_pending'] = map['is_pending'] == 1;
              }
              if (map['product_id'] == '') map['product_id'] = null;
              if (map['store_id'] == '') map['store_id'] = null;
              if (map['trip_id'] == '') map['trip_id'] = null;
              list.add(map);
            }
          }
          await _batchUpsert('market_items', list);
        }

        // O. Market shopping lists
        final listRows = dbData['market_shopping_lists'];
        if (listRows is List && listRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in listRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              if (map['is_active'] is int) {
                map['is_active'] = map['is_active'] == 1;
              }
              if (map['is_completed'] is int) {
                map['is_completed'] = map['is_completed'] == 1;
              }
              list.add(map);
            }
          }
          await _batchUpsert('market_shopping_lists', list);
        }

        // P. Market shopping list items
        final listItemRows = dbData['market_shopping_list_items'];
        if (listItemRows is List && listItemRows.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var r in listItemRows) {
            if (r is Map) {
              final map = Map<String, dynamic>.from(r);
              if (map['is_checked'] is int) {
                map['is_checked'] = map['is_checked'] == 1;
              }
              if (map['list_id'] == '') map['list_id'] = null;
              if (map['product_id'] == '') map['product_id'] = null;
              list.add(map);
            }
          }
          await _batchUpsert('market_shopping_list_items', list);
        }
      }
    }

      // 3. Register this imported backup in backup_snapshots so it appears in "Copias Disponibles"
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      final cleanName = (fileName != null && fileName.isNotEmpty)
          ? fileName.replaceAll('.json', '')
          : 'copia_importada_$dateStr';

      final snapshots = await listBackupSnapshots();
      snapshots.removeWhere((s) => s['name'] == cleanName);
      snapshots.insert(0, {
        'name': cleanName,
        'path': cleanName,
        'created_at': now,
        'is_auto': false,
        'size_bytes': (backupData['databases'] is Map) ? 45000.0 : 25000.0,
        'data': backupData,
      });

      final manualBackups = snapshots.where((s) => s['is_auto'] != true).toList();
      if (manualBackups.length > 10) {
        final toRemove = manualBackups.sublist(10);
        snapshots.removeWhere((s) => toRemove.contains(s));
      }
      await saveBackupSnapshots(snapshots);

      // 4. Record restore history so it appears in "Historial"
      await recordRestoreHistory(
        backupName: (fileName != null && fileName.isNotEmpty) ? fileName : 'Archivo importado (.json)',
        success: true,
      );
    } catch (e) {
      debugPrint("Error importando backup a Supabase: $e");
      rethrow;
    }
  }

  /// Batch upsert helper to prevent hundreds of single HTTP requests
  Future<void> _batchUpsert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty || !isReady) return;
    const chunkSize = 50;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final end = (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
      final chunk = rows.sublist(i, end);
      await client!.from(table).upsert(chunk);
    }
  }

  // MARK: - Backup Metadata & Restoration History
  Future<Map<String, dynamic>> loadBackupMetadata() async {
    final settings = await loadSettings();
    if (settings.containsKey('backup_metadata')) {
      try {
        final decoded = jsonDecode(settings['backup_metadata']!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {
      'restore_history': [],
      'security_pin': '1234',
      'last_auto_backup_date': '',
    };
  }

  Future<void> saveBackupMetadata(Map<String, dynamic> metadata) async {
    await saveSetting('backup_metadata', jsonEncode(metadata));
  }

  Future<void> recordRestoreHistory({
    required String backupName,
    required bool success,
    String? error,
  }) async {
    final metadata = await loadBackupMetadata();
    final restoreHistory = List<Map<String, dynamic>>.from(
      metadata['restore_history'] as List? ?? [],
    );
    final Map<String, dynamic> record = {
      'backup_name': backupName,
      'restored_at': DateTime.now().toIso8601String(),
      'success': success,
    };
    if (error != null) {
      record['error'] = error;
    }
    restoreHistory.add(record);
    metadata['restore_history'] = restoreHistory;
    await saveBackupMetadata(metadata);
  }

  // MARK: - Backup Snapshots (Available Backups list)
  Future<List<Map<String, dynamic>>> listBackupSnapshots() async {
    final settings = await loadSettings();
    if (settings.containsKey('backup_snapshots')) {
      try {
        final list = jsonDecode(settings['backup_snapshots']!) as List;
        return list.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          if (m['created_at'] is String) {
            m['created_at'] = DateTime.tryParse(m['created_at']) ?? DateTime.now();
          }
          m['size_bytes'] = (m['size_bytes'] as num?)?.toDouble() ?? 0.0;
          m['is_auto'] = m['is_auto'] == true;
          m['name'] = m['name']?.toString() ?? 'Copia de seguridad';
          m['path'] = m['path']?.toString() ?? m['name'];
          return m;
        }).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> saveBackupSnapshots(List<Map<String, dynamic>> snapshots) async {
    final toSave = snapshots.map((s) {
      final m = Map<String, dynamic>.from(s);
      if (m['created_at'] is DateTime) {
        m['created_at'] = (m['created_at'] as DateTime).toIso8601String();
      }
      return m;
    }).toList();
    await saveSetting('backup_snapshots', jsonEncode(toSave));
  }

  /// Export current Supabase database to a JSON backup structure
  Future<Map<String, dynamic>> exportCurrentDatabaseToJson() async {
    final profiles = await loadProfiles();
    final activeProfile = profiles.isNotEmpty ? profiles.first['id'] ?? 'quebrado.db' : 'quebrado.db';

    final Map<String, dynamic> backupData = {
      '__multi_profile_backup__': true,
      'profiles_config': {
        'active_profile': activeProfile,
        'profiles': profiles,
      },
      'databases': {},
    };

    Future<List<Map<String, dynamic>>> fetchTable(String tableName, {String? profileId}) async {
      try {
        var query = client!.from(tableName).select();
        if (profileId != null) {
          query = query.eq('profile_id', profileId);
        }
        final List res = await query;
        return res.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      } catch (e) {
        debugPrint('Error fetching table $tableName for export: $e');
        return [];
      }
    }

    final effectiveProfiles = profiles.isNotEmpty ? profiles : [{'id': 'quebrado.db', 'name': 'Personal'}];

    for (var prof in effectiveProfiles) {
      final profId = prof['id']!;
      final allSettings = await fetchTable('settings');
      final cleanSettings = allSettings
          .where((s) => s['key'] != 'backup_snapshots' && s['key'] != 'backup_metadata')
          .toList();

      backupData['databases'][profId] = {
        'settings': cleanSettings,
        'categories': await fetchTable('categories', profileId: profId),
        'accounts': await fetchTable('accounts', profileId: profId),
        'pockets': await fetchTable('pockets', profileId: profId),
        'transactions': await fetchTable('transactions', profileId: profId),
        'rate_history': await fetchTable('rate_history'),
        'recurring_payments': await fetchTable('recurring_payments', profileId: profId),
        'recurring_payment_confirmations': await fetchTable('recurring_payment_confirmations'),
        'recurring_payment_partials': await fetchTable('recurring_payment_partials'),
        'mobile_payment_recipients': await fetchTable('mobile_payment_recipients'),
        'market_stores': await fetchTable('market_stores'),
        'market_products': await fetchTable('market_products'),
        'market_trips': await fetchTable('market_trips'),
        'market_items': await fetchTable('market_items'),
        'market_shopping_lists': await fetchTable('market_shopping_lists'),
        'market_shopping_list_items': await fetchTable('market_shopping_list_items'),
      };
    }

    return backupData;
  }

  /// Automatically checks and creates daily auto-backup in Supabase
  Future<void> checkAndPerformAutoBackup() async {
    if (!isReady) return;
    try {
      final metadata = await loadBackupMetadata();
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final lastDate = metadata['last_auto_backup_date'] as String? ?? '';

      final snapshots = await listBackupSnapshots();
      final alreadyHasToday = snapshots.any((s) => s['is_auto'] == true && s['name'] == 'auto_backup_$dateStr');

      if (lastDate != dateStr || !alreadyHasToday) {
        final backupData = await exportCurrentDatabaseToJson();
        final jsonStr = jsonEncode(backupData);
        final sizeBytes = utf8.encode(jsonStr).length.toDouble();

        snapshots.removeWhere((s) => s['is_auto'] == true && s['name'] == 'auto_backup_$dateStr');

        snapshots.insert(0, {
          'name': 'auto_backup_$dateStr',
          'path': 'auto_backup_$dateStr',
          'created_at': now,
          'is_auto': true,
          'size_bytes': sizeBytes,
          'data': backupData,
        });

        // Retain max 7 auto-backups
        final autoBackups = snapshots.where((s) => s['is_auto'] == true).toList();
        if (autoBackups.length > 7) {
          final toRemove = autoBackups.sublist(7);
          snapshots.removeWhere((s) => toRemove.contains(s));
        }

        await saveBackupSnapshots(snapshots);
        metadata['last_auto_backup_date'] = dateStr;
        await saveBackupMetadata(metadata);
      }
    } catch (e) {
      debugPrint("Error performing Supabase auto backup: $e");
    }
  }

  /// Creates a manual backup snapshot and downloads/shares the JSON file
  Future<String> performManualBackup() async {
    final now = DateTime.now();
    final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final folderName = 'manual_backup_$timestamp';

    final backupData = await exportCurrentDatabaseToJson();
    final jsonStr = jsonEncode(backupData);
    final sizeBytes = utf8.encode(jsonStr).length.toDouble();

    final snapshots = await listBackupSnapshots();
    snapshots.insert(0, {
      'name': folderName,
      'path': folderName,
      'created_at': now,
      'is_auto': false,
      'size_bytes': sizeBytes,
      'data': backupData,
    });
    await saveBackupSnapshots(snapshots);

    // Prompt user download / share
    final fileName = "copia_seguridad_quebrado_$timestamp.json";
    final xFile = XFile.fromData(
      utf8.encode(jsonStr),
      mimeType: "application/json",
      name: fileName,
    );
    await Share.shareXFiles([xFile], subject: "Copia de Seguridad Quebrado");

    return folderName;
  }

  /// Summary preview of an available backup snapshot
  Future<Map<String, dynamic>> getBackupPreview(String folderName) async {
    final snapshots = await listBackupSnapshots();
    final found = snapshots.firstWhere((s) => s['name'] == folderName, orElse: () => {});
    if (found.isNotEmpty && found['data'] != null) {
      final dbData = found['data'];
      final Map<String, dynamic> preview = {
        'profiles': [],
        'total_transactions': 0,
        'total_pockets': 0,
        'total_market_items': 0,
      };
      if (dbData['databases'] is Map) {
        final dbs = dbData['databases'] as Map;
        preview['profiles'] = dbs.keys.toList();
        for (var v in dbs.values) {
          if (v is Map) {
            preview['total_transactions'] = (preview['total_transactions'] as int) + ((v['transactions'] as List?)?.length ?? 0);
            preview['total_pockets'] = (preview['total_pockets'] as int) + ((v['pockets'] as List?)?.length ?? 0);
            preview['total_market_items'] = (preview['total_market_items'] as int) + ((v['market_items'] as List?)?.length ?? 0);
          }
        }
      }
      return preview;
    }
    return {};
  }

  /// Restores data from an existing backup snapshot
  Future<bool> restoreBackupSnapshot(String folderName) async {
    final snapshots = await listBackupSnapshots();
    final found = snapshots.firstWhere((s) => s['name'] == folderName, orElse: () => {});
    if (found.isNotEmpty && found['data'] != null) {
      try {
        await importBackupData(found['data']);
        await recordRestoreHistory(backupName: folderName, success: true);
        return true;
      } catch (e) {
        await recordRestoreHistory(backupName: folderName, success: false, error: e.toString());
        rethrow;
      }
    }
    return false;
  }

  /// Deletes a backup snapshot
  Future<void> deleteBackupSnapshot(String folderName) async {
    final snapshots = await listBackupSnapshots();
    snapshots.removeWhere((s) => s['name'] == folderName);
    await saveBackupSnapshots(snapshots);
  }
}
