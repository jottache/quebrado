import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../models/currency_type.dart';
import '../models/exchange_rate_record.dart';
import '../models/saving_pocket.dart';
import '../models/recurring_payment.dart';
import '../models/timeline_event.dart';
import '../models/transaction.dart';
import '../models/transaction_category.dart';
import '../models/account.dart';
import '../models/recurring_payment_partial.dart';
import '../models/mobile_payment_recipient.dart';
import '../models/market_store.dart';
import '../models/market_item.dart';
import '../models/market_product.dart';
import '../models/market_trip.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../services/db_helper.dart';
import '../services/rate_service.dart';
import '../services/notification_manager.dart';
import '../widgets/helpers.dart';
import '../services/backup_service.dart';

class AppState extends ChangeNotifier {
  // Global Key for the central Floating Action Button showcased in tutorials
  final GlobalKey fabKey = GlobalKey();

  // MARK: - Persistent State Fields
  double _bcvRate = 42.15;
  double _parallelRate = 45.00;
  double _euroRate = 45.00;
  CurrencyType _selectedCurrency = CurrencyType.usd;
  int _currentTabIndex = 0;
  int _historyFilterIndex = 0;
  bool _useBiometrics = false;
  bool _useSlideToConfirm = false;

  List<SavingPocket> pockets = [];
  List<TransactionCategory> categories = [];
  List<Transaction> transactions = [];
  List<ExchangeRateRecord> rateHistory = [];
  List<ExchangeRateRecord> euroRateHistory = [];
  List<RecurringPayment> recurringPayments = [];
  List<Account> accounts = [];
  List<RecurringPaymentPartial> partialPayments = [];
  List<MobilePaymentRecipient> recipients = [];
  List<MarketStore> marketStores = [];
  List<MarketItem> marketItems = [];
  List<MarketProduct> marketProducts = [];
  List<MarketTrip> marketTrips = [];
  List<MarketShoppingList> shoppingLists = [];
  List<MarketShoppingListItem> shoppingListItems = [];
  List<PendingOccurrence> _pendingPaymentsToday = [];
  List<PendingOccurrence> get pendingPaymentsToday => _pendingPaymentsToday;
  final Set<String> _confirmedKeys = {};
  final Set<String> _manualSavingsConfirmed = {};

  List<Map<String, String>> _profiles = [];
  List<Map<String, String>> get profiles => _profiles;

  String _activeDbName = 'quebrado.db';
  String get activeDbName => _activeDbName;

  String get activeProfileName {
    final active = _profiles.firstWhere(
      (p) => p['id'] == _activeDbName,
      orElse: () => {'id': 'quebrado.db', 'name': 'Personal'},
    );
    return active['name'] ?? 'Personal';
  }

  // MARK: - Getters
  double get bcvRate => _bcvRate;
  double get parallelRate => _parallelRate;
  double get euroRate => _euroRate;
  CurrencyType get selectedCurrency => _selectedCurrency;
  bool get useBiometrics => _useBiometrics;
  bool get useSlideToConfirm => _useSlideToConfirm;

  double get totalBalanceUSD {
    double total = 0.0;
    for (var acc in accounts) {
      if (acc.currency == CurrencyType.usd) {
        total += acc.balance;
      } else {
        total += bcvRate > 0 ? acc.balance / bcvRate : 0.0;
      }
    }
    return total;
  }

  // MARK: - UI Configuration States
  bool showingCalculator = false;
  bool isFetchingRates = false;
  bool isFetchingHistory = false;
  String? rateFetchError;
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  final RateService _rateService = RateService();

  AppState() {
    loadData();
  }

  /// Loads all settings and database tables asynchronously from SQLite.
  Future<void> loadData() async {
    // Clear data from previous profile to avoid cross-profile caching if an error occurs
    _pendingPaymentsToday = [];
    recurringPayments = [];
    pockets = [];
    categories = [];
    transactions = [];
    accounts = [];
    _confirmedKeys.clear();
    partialPayments = [];
    
    try {
      _profiles = await DatabaseHelper.instance.loadProfiles();
      _activeDbName = await DatabaseHelper.instance.getActiveProfile();
      
      // Update theme color based on active profile
      final activeProfile = _profiles.firstWhere(
        (p) => p['id'] == _activeDbName,
        orElse: () => _profiles.first,
      );
      if (activeProfile.containsKey('color') && activeProfile['color'] != null) {
        final colorHex = activeProfile['color']!;
        AppColors.updateThemeColor(Color(int.parse(colorHex.replaceFirst('#', '0xFF'))));
      } else {
        AppColors.updateThemeColor(Color(0xFF1F6F5F)); // Default color
      }
      
      await DatabaseHelper.instance.checkAndPerformAutoBackup();

      final bcvVal = await DatabaseHelper.instance.getSetting('bcvRate');
      if (bcvVal != null) _bcvRate = double.parse(bcvVal);

      final paraleloVal = await DatabaseHelper.instance.getSetting(
        'parallelRate',
      );
      if (paraleloVal != null) _parallelRate = double.parse(paraleloVal);

      final euroVal = await DatabaseHelper.instance.getSetting('euroRate');
      if (euroVal != null) _euroRate = double.parse(euroVal);

      final currencyVal = await DatabaseHelper.instance.getSetting(
        'selectedCurrency',
      );
      if (currencyVal != null) {
        _selectedCurrency = CurrencyType.fromString(currencyVal);
      }

      final biometricsVal = await DatabaseHelper.instance.getSetting('useBiometrics');
      if (biometricsVal != null) _useBiometrics = biometricsVal == 'true';

      final slideVal = await DatabaseHelper.instance.getSetting('useSlideToConfirm');
      if (slideVal != null) _useSlideToConfirm = slideVal == 'true';

      pockets = await DatabaseHelper.instance.getPockets();
      categories = await DatabaseHelper.instance.getCategories();
      transactions = await DatabaseHelper.instance.getTransactions();
      rateHistory = await DatabaseHelper.instance.getRateHistory('bcv');
      euroRateHistory = await DatabaseHelper.instance.getRateHistory('euro');
      recurringPayments = await DatabaseHelper.instance.getRecurringPayments();
      accounts = await DatabaseHelper.instance.getAccounts();
      recipients = await DatabaseHelper.instance.getRecipients();
      marketStores = await DatabaseHelper.instance.getMarketStores();
      marketItems = await DatabaseHelper.instance.getMarketItems();
      marketProducts = await DatabaseHelper.instance.getMarketProducts();
      marketTrips = await DatabaseHelper.instance.getMarketTrips();
      shoppingLists = await DatabaseHelper.instance.getMarketShoppingLists();
      shoppingListItems = await DatabaseHelper.instance.getMarketShoppingListItems();

      _confirmedKeys.clear();
      final allConfirmations = await DatabaseHelper.instance
          .getAllConfirmations();
      for (var c in allConfirmations) {
        final pId = c['recurring_payment_id'] as String;
        final dateStr = c['date'] as String;
        _confirmedKeys.add("${pId}_$dateStr");
      }

      final allPartials = await DatabaseHelper.instance.getAllPartials();
      partialPayments = allPartials.map((e) => RecurringPaymentPartial.fromMap(e)).toList();

      _manualSavingsConfirmed.clear();
      final confirmedStr = await DatabaseHelper.instance.getSetting("manual_savings_confirmed");
      if (confirmedStr != null && confirmedStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(confirmedStr) as List;
          for (var item in decoded) {
            if (item is String) {
              _manualSavingsConfirmed.add(item);
            }
          }
        } catch (e) {
          if (kDebugMode) print("Error decoding manual_savings_confirmed: $e");
        }
      }

      await updatePendingPaymentsToday();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Error loading database settings: $e");
    }
  }

  // MARK: - Setter Toggles

  void setShowingCalculator(bool visible) {
    showingCalculator = visible;
    notifyListeners();
  }

  Future<void> toggleSelectedCurrency() async {
    _selectedCurrency = _selectedCurrency == CurrencyType.usd
        ? CurrencyType.bsBCV
        : CurrencyType.usd;
    await DatabaseHelper.instance.setSetting(
      'selectedCurrency',
      _selectedCurrency.name,
    );
    notifyListeners();
  }

  Future<void> setUseBiometrics(bool value) async {
    _useBiometrics = value;
    await DatabaseHelper.instance.setSetting('useBiometrics', _useBiometrics.toString());
    notifyListeners();
  }

  Future<void> setUseSlideToConfirm(bool value) async {
    _useSlideToConfirm = value;
    await DatabaseHelper.instance.setSetting('useSlideToConfirm', _useSlideToConfirm.toString());
    notifyListeners();
  }

  // MARK: - Exchange Rate Fetch Updates

  Future<void> refreshRates() async {
    isFetchingRates = true;
    rateFetchError = null;
    notifyListeners();

    try {
      final lookup = await InternetAddress.lookup('example.com').timeout(Duration(seconds: 2));
      _hasInternet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      _hasInternet = false;
    }

    if (!_hasInternet) {
      isFetchingRates = false;
      rateFetchError = "Error de conexión: No hay acceso a Internet.";
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _rateService.fetchOfficialRate(),
        _rateService.fetchParallelRate(),
        _rateService.fetchEuroRate(),
      ]);

      final officialRate = results[0];
      final paralelo = results[1];
      final euro = results[2];

      final now = DateTime.now();
      final isWeekend =
          (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday);
      final hasValidRates =
          rateHistory.isNotEmpty && euroRateHistory.isNotEmpty;

      if (isWeekend && hasValidRates) {
        isFetchingRates = false;
        notifyListeners();
        return;
      }

      // Log BCV history if changed
      final latestBcvRecorded = rateHistory.isNotEmpty
          ? rateHistory.first.rate
          : null;
      if (latestBcvRecorded == null || latestBcvRecorded != officialRate) {
        final newRecord = ExchangeRateRecord(
          id: "bcv_${DateTime.now().millisecondsSinceEpoch}",
          date: DateTime.now(),
          rate: officialRate,
        );
        await DatabaseHelper.instance.insertRateRecord(newRecord, 'bcv');
        rateHistory = await DatabaseHelper.instance.getRateHistory('bcv');
      }

      // Log Euro history if changed
      final latestEuroRecorded = euroRateHistory.isNotEmpty
          ? euroRateHistory.first.rate
          : null;
      if (latestEuroRecorded == null || latestEuroRecorded != euro) {
        final newRecord = ExchangeRateRecord(
          id: "euro_${DateTime.now().millisecondsSinceEpoch}",
          date: DateTime.now(),
          rate: euro,
        );
        await DatabaseHelper.instance.insertRateRecord(newRecord, 'euro');
        euroRateHistory = await DatabaseHelper.instance.getRateHistory('euro');
      }

      _bcvRate = officialRate;
      _parallelRate = paralelo;
      _euroRate = euro;

      await DatabaseHelper.instance.setSetting('bcvRate', _bcvRate.toString());
      await DatabaseHelper.instance.setSetting(
        'parallelRate',
        _parallelRate.toString(),
      );
      await DatabaseHelper.instance.setSetting(
        'euroRate',
        _euroRate.toString(),
      );

      // Reschedule recurring payments due dates
      for (var sub in recurringPayments) {
        NotificationManager.shared.scheduleNotification(sub, _bcvRate);
      }
    } catch (e) {
      rateFetchError = e.toString();
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Failed host lookup") ||
          e.toString().contains("connection")) {
        _hasInternet = false;
      }
    }

    isFetchingRates = false;
    notifyListeners();
  }

  Future<void> fetchFullRateHistory() async {
    isFetchingHistory = true;
    rateFetchError = null;
    notifyListeners();

    try {
      final lookup = await InternetAddress.lookup('example.com').timeout(Duration(seconds: 2));
      _hasInternet = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      _hasInternet = false;
    }

    if (!_hasInternet) {
      isFetchingHistory = false;
      rateFetchError = "Error de conexión: No hay acceso a Internet.";
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _rateService.fetchHistoricRates(),
        _rateService.fetchEuroHistoricRates(),
      ]);

      final bcvRecords = results[0];
      final euroRecords = results[1];

      await DatabaseHelper.instance.clearRateHistory('bcv');
      await DatabaseHelper.instance.clearRateHistory('euro');

      await DatabaseHelper.instance.insertRateRecords(bcvRecords, 'bcv');
      await DatabaseHelper.instance.insertRateRecords(euroRecords, 'euro');

      rateHistory = await DatabaseHelper.instance.getRateHistory('bcv');
      euroRateHistory = await DatabaseHelper.instance.getRateHistory('euro');

      if (rateHistory.isNotEmpty) {
        _bcvRate = rateHistory.first.rate;
        await DatabaseHelper.instance.setSetting(
          'bcvRate',
          _bcvRate.toString(),
        );
      }
      if (euroRateHistory.isNotEmpty) {
        _euroRate = euroRateHistory.first.rate;
        await DatabaseHelper.instance.setSetting(
          'euroRate',
          _euroRate.toString(),
        );
      }
    } catch (e) {
      rateFetchError = e.toString();
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Failed host lookup") ||
          e.toString().contains("connection")) {
        _hasInternet = false;
      }
    }

    isFetchingHistory = false;
    notifyListeners();
  }

  // MARK: - Conversions

  double convert({required double amountUSD, required CurrencyType to}) {
    switch (to) {
      case CurrencyType.usd:
        return amountUSD;
      case CurrencyType.bsBCV:
        return amountUSD * _bcvRate;
      case CurrencyType.eur:
        return _euroRate > 0 ? (amountUSD * _bcvRate) / _euroRate : 0.0;
    }
  }

  double convertToUSD({required double amount, required CurrencyType from}) {
    switch (from) {
      case CurrencyType.usd:
        return amount;
      case CurrencyType.bsBCV:
        return _bcvRate > 0 ? amount / _bcvRate : 0.0;
      case CurrencyType.eur:
        return _bcvRate > 0 ? (amount * _euroRate) / _bcvRate : 0.0;
    }
  }

  // MARK: - Financial Sub-systems (Pockets)

  double get totalPocketsUSD {
    return pockets.fold(0.0, (sum, pocket) => sum + pocket.currentAmountUSD);
  }

  double get liquidBalanceUSD {
    double usdTotal = accounts
        .where((acc) => acc.currency == CurrencyType.usd)
        .fold(0.0, (sum, acc) => sum + acc.balance);
    final balance = usdTotal - totalPocketsUSD;
    return balance > 0 ? balance : 0.0;
  }

  Future<void> addPocket({
    required String name,
    required double targetAmountUSD,
    required String icon,
    required String colorHex,
    String? description,
    String? imageUrl,
    DateTime? targetDate,
    int priority = 1,
    String fundingRuleType = 'none',
    double? fundingRuleValue,
    double? fundingRuleThreshold,
  }) async {
    final pocket = SavingPocket(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      currentAmountUSD: 0.0,
      targetAmountUSD: targetAmountUSD,
      icon: icon,
      colorHex: colorHex,
      description: description,
      imageUrl: imageUrl,
      targetDate: targetDate,
      priority: priority,
      fundingRuleType: fundingRuleType,
      fundingRuleValue: fundingRuleValue,
      fundingRuleThreshold: fundingRuleThreshold,
    );

    await DatabaseHelper.instance.insertPocket(pocket);
    pockets = await DatabaseHelper.instance.getPockets();
    notifyListeners();
  }

  Future<void> updatePocket(SavingPocket pocket) async {
    await DatabaseHelper.instance.updatePocket(pocket);
    pockets = await DatabaseHelper.instance.getPockets();
    notifyListeners();
  }

  // MARK: - Market Trips
  Future<void> updateMarketStore(MarketStore store) async {
    final index = marketStores.indexWhere((s) => s.id == store.id);
    if (index >= 0) {
      marketStores[index] = store;
      marketStores.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      await DatabaseHelper.instance.updateMarketStore(store);
    }
  }

  Future<void> addMarketTrip(MarketTrip trip) async {
    marketTrips.insert(0, trip);
    notifyListeners();
    await DatabaseHelper.instance.insertMarketTrip(trip);
  }

  Future<void> updateMarketTrip(MarketTrip trip) async {
    final index = marketTrips.indexWhere((t) => t.id == trip.id);
    if (index != -1) {
      marketTrips[index] = trip;
      notifyListeners();
      await DatabaseHelper.instance.insertMarketTrip(trip);
    }
  }

  Future<void> deleteMarketTrip(String id) async {
    marketTrips.removeWhere((t) => t.id == id);
    // Delete all items associated with this trip
    marketItems.removeWhere((i) => i.tripId == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteMarketTrip(id);
  }

  // MARK: - Market Methods
  Future<void> addMarketStore(MarketStore store) async {
    final index = marketStores.indexWhere((s) => s.id == store.id);
    if (index >= 0) {
      marketStores[index] = store;
    } else {
      marketStores.add(store);
    }
    marketStores.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    
    await DatabaseHelper.instance.insertMarketStore(store);
  }

  Future<void> deleteMarketStore(String id) async {
    await DatabaseHelper.instance.deleteMarketStore(id);
    marketStores.removeWhere((s) => s.id == id);
    marketItems.removeWhere((i) => i.storeId == id);
    notifyListeners();
  }

  Future<void> addMarketItem(MarketItem item) async {
    final index = marketItems.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      marketItems[index] = item;
    } else {
      marketItems.add(item);
    }
    marketItems.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    
    await DatabaseHelper.instance.insertMarketItem(item);
  }

  Future<void> deleteMarketItem(String id) async {
    await DatabaseHelper.instance.deleteMarketItem(id);
    marketItems.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<void> updateMarketItem(MarketItem item) async {
    final index = marketItems.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      marketItems[index] = item;
      await DatabaseHelper.instance.updateMarketItem(item);
      notifyListeners();
    }
  }

  // MARK: - Market Products
  Future<void> addMarketProduct(MarketProduct product) async {
    final index = marketProducts.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      marketProducts[index] = product;
    } else {
      marketProducts.add(product);
    }
    marketProducts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    
    await DatabaseHelper.instance.insertMarketProduct(product);
  }

  Future<void> updateMarketProduct(MarketProduct product) async {
    final index = marketProducts.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      marketProducts[index] = product;
      marketProducts.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      await DatabaseHelper.instance.updateMarketProduct(product);
    }
  }

  // MARK: - Market Shopping Lists Methods
  Future<void> addMarketShoppingList(MarketShoppingList list) async {
    if (list.isActive) {
      for (var i = 0; i < shoppingLists.length; i++) {
        if (shoppingLists[i].isActive) {
          final deactivated = MarketShoppingList(
            id: shoppingLists[i].id,
            title: shoppingLists[i].title,
            date: shoppingLists[i].date,
            isActive: false,
          );
          shoppingLists[i] = deactivated;
          await DatabaseHelper.instance.updateMarketShoppingList(deactivated);
        }
      }
    }
    shoppingLists.insert(0, list);
    notifyListeners();
    await DatabaseHelper.instance.insertMarketShoppingList(list);
  }

  Future<void> updateMarketShoppingList(MarketShoppingList list) async {
    if (list.isActive) {
      for (var i = 0; i < shoppingLists.length; i++) {
        if (shoppingLists[i].id != list.id && shoppingLists[i].isActive) {
          final deactivated = MarketShoppingList(
            id: shoppingLists[i].id,
            title: shoppingLists[i].title,
            date: shoppingLists[i].date,
            isActive: false,
          );
          shoppingLists[i] = deactivated;
          await DatabaseHelper.instance.updateMarketShoppingList(deactivated);
        }
      }
    }
    final index = shoppingLists.indexWhere((l) => l.id == list.id);
    if (index != -1) {
      shoppingLists[index] = list;
      notifyListeners();
      await DatabaseHelper.instance.updateMarketShoppingList(list);
    }
  }

  Future<void> deleteMarketShoppingList(String id) async {
    shoppingLists.removeWhere((l) => l.id == id);
    shoppingListItems.removeWhere((item) => item.listId == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteMarketShoppingList(id);
  }

  Future<void> addMarketShoppingListItem(MarketShoppingListItem item) async {
    shoppingListItems.add(item);
    notifyListeners();
    await DatabaseHelper.instance.insertMarketShoppingListItem(item);
  }

  Future<void> updateMarketShoppingListItem(MarketShoppingListItem item) async {
    final index = shoppingListItems.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      shoppingListItems[index] = item;
      notifyListeners();
      await DatabaseHelper.instance.updateMarketShoppingListItem(item);
    }
  }

  Future<void> deleteMarketShoppingListItem(String id) async {
    shoppingListItems.removeWhere((i) => i.id == id);
    notifyListeners();
    await DatabaseHelper.instance.deleteMarketShoppingListItem(id);
  }

  Future<void> deleteMarketProduct(String id) async {
    await DatabaseHelper.instance.deleteMarketProduct(id);
    marketProducts.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  double get totalMarketSpentThisMonthUSD {
    final now = DateTime.now();
    double total = 0.0;
    for (var item in marketItems) {
      if (item.date.year == now.year && item.date.month == now.month) {
        total += item.priceUSD;
      }
    }
    return total;
  }

  Future<void> deletePocket(String id) async {
    await DatabaseHelper.instance.deletePocket(id);
    pockets = await DatabaseHelper.instance.getPockets();
    notifyListeners();
  }

  Future<void> confirmManualSaving({
    required List<String> transactionIds,
    required String pocketId,
    required double amountUSD,
  }) async {
    for (var txId in transactionIds) {
      final key = "${txId}_$pocketId";
      _manualSavingsConfirmed.add(key);
    }
    
    // Save to settings
    final list = _manualSavingsConfirmed.toList();
    await DatabaseHelper.instance.setSetting("manual_savings_confirmed", jsonEncode(list));

    // Deposit to pocket
    await depositToPocket(id: pocketId, amountUSD: amountUSD);
  }

  Future<void> depositToPocket({
    required String id,
    required double amountUSD,
  }) async {
    final index = pockets.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final deposit = amountUSD < liquidBalanceUSD ? amountUSD : liquidBalanceUSD;
    if (deposit <= 0) return;

    pockets[index].currentAmountUSD += deposit;
    await DatabaseHelper.instance.updatePocket(pockets[index]);
    pockets = await DatabaseHelper.instance.getPockets();
    notifyListeners();
  }

  Future<void> withdrawFromPocket({
    required String id,
    required double amountUSD,
  }) async {
    final index = pockets.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final withdraw = amountUSD < pockets[index].currentAmountUSD
        ? amountUSD
        : pockets[index].currentAmountUSD;
    if (withdraw <= 0) return;

    pockets[index].currentAmountUSD -= withdraw;
    await DatabaseHelper.instance.updatePocket(pockets[index]);
    pockets = await DatabaseHelper.instance.getPockets();
    notifyListeners();
  }

  // MARK: - Transactions Ledger

  double _getTransactionAmountInAccountCurrency(Transaction tx, Account acc) {
    if (tx.currency == acc.currency) {
      return tx.amount;
    }
    if (tx.currency == CurrencyType.usd && acc.currency == CurrencyType.bsBCV) {
      return tx.amount * tx.exchangeRate;
    }
    if (tx.currency == CurrencyType.bsBCV && acc.currency == CurrencyType.usd) {
      return tx.exchangeRate > 0 ? tx.amount / tx.exchangeRate : 0.0;
    }
    if (tx.currency == CurrencyType.eur && acc.currency == CurrencyType.bsBCV) {
      return tx.amount * tx.exchangeRate;
    }
    if (tx.currency == CurrencyType.eur && acc.currency == CurrencyType.usd) {
      double amountBs = tx.amount * tx.exchangeRate;
      return _bcvRate > 0 ? amountBs / _bcvRate : 0.0;
    }
    if (tx.currency == CurrencyType.bsBCV && acc.currency == CurrencyType.eur) {
      return tx.exchangeRate > 0 ? tx.amount / tx.exchangeRate : 0.0;
    }
    if (tx.currency == CurrencyType.usd && acc.currency == CurrencyType.eur) {
      double amountBs = tx.amount * _bcvRate;
      return tx.exchangeRate > 0 ? amountBs / tx.exchangeRate : 0.0;
    }
    return tx.amount;
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      await DatabaseHelper.instance.insertTransaction(transaction);
    } catch (e) {
      if (kDebugMode) {
        print("Error inserting transaction in DB: $e");
      }
    }

    if (transaction.accountId != null) {
      final index = accounts.indexWhere(
        (acc) => acc.id == transaction.accountId,
      );
      if (index != -1) {
        final acc = accounts[index];
        final amountInAccCurrency = _getTransactionAmountInAccountCurrency(transaction, acc);
        if (transaction.type == TransactionType.income) {
          acc.balance += amountInAccCurrency;
        } else {
          acc.balance -= amountInAccCurrency;
        }
        try {
          await DatabaseHelper.instance.updateAccount(acc);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating account in DB: $e");
          }
        }
      }
    }

    if (transaction.destinationPocketId != null) {
      final index = pockets.indexWhere(
        (p) => p.id == transaction.destinationPocketId,
      );
      if (index != -1) {
        double amountUSD = transaction.currency == CurrencyType.usd
            ? transaction.amount
            : transaction.amount /
                  (transaction.exchangeRate > 0
                      ? transaction.exchangeRate
                      : 1.0);

        if (transaction.type == TransactionType.income) {
          pockets[index].currentAmountUSD += amountUSD;
        } else {
          pockets[index].currentAmountUSD =
              pockets[index].currentAmountUSD - amountUSD > 0
              ? pockets[index].currentAmountUSD - amountUSD
              : 0.0;
        }
        try {
          await DatabaseHelper.instance.updatePocket(pockets[index]);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating pocket in DB: $e");
          }
        }
      }
    }

    try {
      transactions = await DatabaseHelper.instance.getTransactions();
      pockets = await DatabaseHelper.instance.getPockets();
      accounts = await DatabaseHelper.instance.getAccounts();
    } catch (e) {
      if (kDebugMode) {
        print("Error reloading lists from DB: $e");
      }
    }
    notifyListeners();
  }

  Future<void> performCrossProfileTransfer({
    required String targetProfileId,
    required String targetProfileName,
    required String sourceAccountId,
    required Account targetAccount,
    required double amount,
    required CurrencyType currency,
  }) async {
    // 1. Crear Gasto en el perfil actual
    final sourceTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      amount: amount,
      currency: currency,
      type: TransactionType.expense,
      accountId: sourceAccountId,
      note: 'Transferencia hacia libro: $targetProfileName',
      exchangeRate: bcvRate,
    );
    await addTransaction(sourceTx); // Esto también actualiza el balance local

    // 2. Determinar el nombre del perfil actual para la nota destino
    String currentProfileName = activeProfileName;

    // 3. Crear Ingreso en el perfil destino
    final targetTx = Transaction(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      date: DateTime.now(),
      amount: amount,
      currency: currency,
      type: TransactionType.income,
      accountId: targetAccount.id,
      note: 'Transferencia desde libro: $currentProfileName',
      exchangeRate: bcvRate,
    );

    // Guardar en el perfil destino
    try {
      await DatabaseHelper.instance.insertCrossProfileTransaction(
        targetProfileId,
        targetTx,
        targetAccount,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error inserting cross profile transaction: $e");
      }
    }
  }

  Future<void> updateTransaction(Transaction oldTx, Transaction newTx) async {
    // 1. Revert old transaction's impact on account balance
    if (oldTx.accountId != null) {
      final oldAccIndex = accounts.indexWhere((acc) => acc.id == oldTx.accountId);
      if (oldAccIndex != -1) {
        final acc = accounts[oldAccIndex];
        final amountInAccCurrency = _getTransactionAmountInAccountCurrency(oldTx, acc);
        if (oldTx.type == TransactionType.income) {
          acc.balance -= amountInAccCurrency;
        } else {
          acc.balance += amountInAccCurrency;
        }
        try {
          await DatabaseHelper.instance.updateAccount(acc);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating account in DB: $e");
          }
        }
      }
    }

    // 2. Revert old transaction's impact on pocket balance (if any)
    if (oldTx.destinationPocketId != null) {
      final oldPocketIndex = pockets.indexWhere((p) => p.id == oldTx.destinationPocketId);
      if (oldPocketIndex != -1) {
        final pocket = pockets[oldPocketIndex];
        final double amountUSD = oldTx.currency == CurrencyType.usd
            ? oldTx.amount
            : oldTx.amount / (oldTx.exchangeRate > 0 ? oldTx.exchangeRate : 1.0);
        
        if (oldTx.type == TransactionType.income) {
          pocket.currentAmountUSD = pocket.currentAmountUSD - amountUSD > 0 ? pocket.currentAmountUSD - amountUSD : 0.0;
        } else {
          pocket.currentAmountUSD += amountUSD;
        }
        try {
          await DatabaseHelper.instance.updatePocket(pocket);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating pocket in DB: $e");
          }
        }
      }
    }

    // 3. Apply new transaction's impact on account balance
    if (newTx.accountId != null) {
      final newAccIndex = accounts.indexWhere((acc) => acc.id == newTx.accountId);
      if (newAccIndex != -1) {
        final acc = accounts[newAccIndex];
        final amountInAccCurrency = _getTransactionAmountInAccountCurrency(newTx, acc);
        if (newTx.type == TransactionType.income) {
          acc.balance += amountInAccCurrency;
        } else {
          acc.balance -= amountInAccCurrency;
        }
        try {
          await DatabaseHelper.instance.updateAccount(acc);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating account in DB: $e");
          }
        }
      }
    }

    // 4. Apply new transaction's impact on pocket balance (if any)
    if (newTx.destinationPocketId != null) {
      final newPocketIndex = pockets.indexWhere((p) => p.id == newTx.destinationPocketId);
      if (newPocketIndex != -1) {
        final pocket = pockets[newPocketIndex];
        final double amountUSD = newTx.currency == CurrencyType.usd
            ? newTx.amount
            : newTx.amount / (newTx.exchangeRate > 0 ? newTx.exchangeRate : 1.0);
        
        if (newTx.type == TransactionType.income) {
          pocket.currentAmountUSD += amountUSD;
        } else {
          pocket.currentAmountUSD = pocket.currentAmountUSD - amountUSD > 0 ? pocket.currentAmountUSD - amountUSD : 0.0;
        }
        try {
          await DatabaseHelper.instance.updatePocket(pocket);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating pocket in DB: $e");
          }
        }
      }
    }

    // 5. Update transaction in SQLite
    try {
      await DatabaseHelper.instance.updateTransaction(newTx);
    } catch (e) {
      if (kDebugMode) {
        print("Error updating transaction in DB: $e");
      }
    }

    // 6. Reload lists from database to ensure everything is in sync
    try {
      transactions = await DatabaseHelper.instance.getTransactions();
      pockets = await DatabaseHelper.instance.getPockets();
      accounts = await DatabaseHelper.instance.getAccounts();
    } catch (e) {
      if (kDebugMode) {
        print("Error reloading lists from DB: $e");
      }
    }
    
    notifyListeners();
  }

  Future<void> _revertTransactionImpact(Transaction t) async {
    if (t.accountId != null) {
      final index = accounts.indexWhere((acc) => acc.id == t.accountId);
      if (index != -1) {
        final acc = accounts[index];
        final amountInAccCurrency = _getTransactionAmountInAccountCurrency(t, acc);
        if (t.type == TransactionType.income) {
          acc.balance -= amountInAccCurrency;
        } else {
          acc.balance += amountInAccCurrency;
        }
        try {
          await DatabaseHelper.instance.updateAccount(acc);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating account in DB: $e");
          }
        }
      }
    }

    if (t.destinationPocketId != null) {
      final index = pockets.indexWhere((p) => p.id == t.destinationPocketId);
      if (index != -1) {
        final pocket = pockets[index];
        final double amountUSD = t.currency == CurrencyType.usd
            ? t.amount
            : t.amount / (t.exchangeRate > 0 ? t.exchangeRate : 1.0);

        if (t.type == TransactionType.income) {
          pocket.currentAmountUSD = pocket.currentAmountUSD - amountUSD > 0
              ? pocket.currentAmountUSD - amountUSD
              : 0.0;
        } else {
          pocket.currentAmountUSD += amountUSD;
        }
        try {
          await DatabaseHelper.instance.updatePocket(pocket);
        } catch (e) {
          if (kDebugMode) {
            print("Error updating pocket in DB: $e");
          }
        }
      }
    }
  }

  Future<void> deleteTransaction(Transaction tx) async {
    // 1. Revert main transaction impact
    await _revertTransactionImpact(tx);

    // 2. Check and revert counterpart if it's an exchange
    Transaction? counterpart;
    final parts = tx.id.split('_');
    if (parts.length >= 2 && (tx.id.contains('_usd_') || tx.id.contains('_ves_'))) {
      final prefix = parts[0];
      for (var t in transactions) {
        if (t.id != tx.id && t.id.startsWith('${prefix}_')) {
          counterpart = t;
          break;
        }
      }
    }

    if (counterpart != null) {
      await _revertTransactionImpact(counterpart);
      try {
        await DatabaseHelper.instance.deleteTransaction(counterpart.id);
      } catch (e) {
        if (kDebugMode) {
          print("Error deleting counterpart transaction in DB: $e");
        }
      }
    }

    // 3. Delete main transaction from database
    try {
      await DatabaseHelper.instance.deleteTransaction(tx.id);
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting transaction in DB: $e");
      }
    }

    // 4. Update in-memory lists (fallback if reload fails under testing/mocking)
    transactions.removeWhere((t) => t.id == tx.id);
    if (counterpart != null) {
      transactions.removeWhere((t) => t.id == counterpart!.id);
    }

    try {
      transactions = await DatabaseHelper.instance.getTransactions();
      pockets = await DatabaseHelper.instance.getPockets();
      accounts = await DatabaseHelper.instance.getAccounts();
      final allPartials = await DatabaseHelper.instance.getAllPartials();
      partialPayments = allPartials.map((e) => RecurringPaymentPartial.fromMap(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Error reloading lists from DB: $e");
      }
    }

    await updatePendingPaymentsToday();
    notifyListeners();
  }


  // MARK: - Categories Manager

  Future<void> addCategory({
    required String name,
    required String icon,
    required String colorHex,
    required TransactionCategoryType type,
    String? parentId,
  }) async {
    final cat = TransactionCategory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      icon: icon,
      colorHex: colorHex,
      type: type,
      parentId: parentId,
    );

    await DatabaseHelper.instance.insertCategory(cat);
    categories = await DatabaseHelper.instance.getCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    categories = await DatabaseHelper.instance.getCategories();
    transactions = await DatabaseHelper.instance.getTransactions();
    notifyListeners();
  }

  Future<void> updateCategory(TransactionCategory category) async {
    await DatabaseHelper.instance.updateCategory(category);
    categories = await DatabaseHelper.instance.getCategories();
    transactions = await DatabaseHelper.instance.getTransactions();
    notifyListeners();
  }

  Future<void> reorderCategories(List<TransactionCategory> reorderedList) async {
    for (int i = 0; i < reorderedList.length; i++) {
      reorderedList[i].position = i;
      await DatabaseHelper.instance.updateCategory(reorderedList[i]);
    }
    categories = await DatabaseHelper.instance.getCategories();
    notifyListeners();
  }

  List<TransactionCategory> getParentCategories(TransactionCategoryType type) {
    return categories.where((c) => c.type == type && c.parentId == null).toList();
  }

  List<TransactionCategory> getSubcategories(String parentId) {
    return categories.where((c) => c.parentId == parentId).toList();
  }

  List<TransactionCategory> getGroupedCategories(TransactionCategoryType type) {
    final parents = getParentCategories(type);
    parents.sort((a, b) => a.position.compareTo(b.position));
    
    List<TransactionCategory> grouped = [];
    for (var parent in parents) {
      grouped.add(parent);
      final children = getSubcategories(parent.id);
      children.sort((a, b) => a.position.compareTo(b.position));
      grouped.addAll(children);
    }
    return grouped;
  }

  Future<void> updateTransactionCategory(
    String transactionId,
    String? categoryId,
  ) async {
    await DatabaseHelper.instance.updateTransactionCategory(
      transactionId,
      categoryId,
    );
    transactions = await DatabaseHelper.instance.getTransactions();
    notifyListeners();
  }

  // MARK: - Recurring Payments Manager

  Future<void> addRecurringPayment({
    required String name,
    required double amount,
    required CurrencyType currency,
    required SubscriptionFrequency frequency,
    required DateTime startDate,
    required NotificationOption notificationOption,
    required String icon,
    required String colorHex,
    required TransactionType type,
    String? accountId,
    String? pocketId,
    int? totalInstallments,
    int? customDays,
    bool isVariable = false,
    double? maxAmount,
  }) async {
    final payment = RecurringPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      currency: currency,
      frequency: frequency,
      startDate: startDate,
      notificationOption: notificationOption,
      icon: icon,
      colorHex: colorHex,
      type: type,
      accountId: accountId,
      pocketId: pocketId,
      totalInstallments: totalInstallments,
      customDays: customDays,
      isVariable: isVariable,
      maxAmount: maxAmount,
    );

    await DatabaseHelper.instance.insertRecurringPayment(payment);
    recurringPayments = await DatabaseHelper.instance.getRecurringPayments();
    NotificationManager.shared.scheduleNotification(payment, _bcvRate);
    await updatePendingPaymentsToday();
    notifyListeners();
  }

  Future<void> deleteRecurringPayment(String id) async {
    final payment = recurringPayments.firstWhere((s) => s.id == id);
    await NotificationManager.shared.cancelNotification(payment);

    await DatabaseHelper.instance.deleteRecurringPayment(id);
    recurringPayments = await DatabaseHelper.instance.getRecurringPayments();
    await updatePendingPaymentsToday();
    notifyListeners();
  }

  Future<void> updateRecurringPayment(RecurringPayment payment) async {
    await DatabaseHelper.instance.updateRecurringPayment(payment);
    recurringPayments = await DatabaseHelper.instance.getRecurringPayments();
    NotificationManager.shared.scheduleNotification(payment, _bcvRate);
    await updatePendingPaymentsToday();
    notifyListeners();
  }

  // MARK: - Projections & Timeline Calculations
  
  List<TimelineEvent>? _cachedTimelineEvents;
  int? _cachedTimelineDays;

  @override
  void notifyListeners() {
    _cachedTimelineEvents = null;
    super.notifyListeners();
  }

  List<TimelineEvent> getTimelineEvents(int daysToProject, {List<SavingPocket> virtualPockets = const [], List<RecurringPayment> virtualPayments = const []}) {
    if (virtualPockets.isEmpty && virtualPayments.isEmpty) {
      if (_cachedTimelineEvents != null && _cachedTimelineDays == daysToProject) {
        return _cachedTimelineEvents!;
      }
    }

    final allPockets = [...pockets, ...virtualPockets];
    final rangeStart = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    // Always simulate a full year (365 days) internally for consistent calculations, deficits, and suggestions
    final rangeEnd = rangeStart.add(Duration(days: 365));
    final filterEnd = rangeStart.add(Duration(days: daysToProject));

    List<_OccurrenceRaw> occurrences = [];

    final allPayments = [...recurringPayments, ...virtualPayments];

    for (var payment in allPayments) {
      DateTime current = payment.startDate.copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      int count = 0;

      while (current.isBefore(rangeEnd) || current.isAtSameMomentAs(rangeEnd)) {
        count++;
        if (payment.totalInstallments != null &&
            count > payment.totalInstallments!) {
          break;
        }

        final dateStr =
            "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
        final isConfirmed = _confirmedKeys.contains("${payment.id}_$dateStr");

        // Calculate partial amount paid
        double partialPaid = 0.0;
        for (var p in partialPayments) {
          if (p.recurringPaymentId == payment.id && p.occurrenceDate == dateStr) {
            partialPaid += p.amount;
          }
        }

        final remainingAmount = payment.amount - partialPaid;
        if (remainingAmount > 0.01) {
          if (current.isAfter(rangeStart) ||
              current.isAtSameMomentAs(rangeStart)) {
            if (!isConfirmed) {
              occurrences.add(_OccurrenceRaw(payment, current, count, partialAmountPaid: partialPaid));
            }
          } else {
            if (!isConfirmed) {
              occurrences.add(
                _OccurrenceRaw(payment, current, count, isOverdue: true, partialAmountPaid: partialPaid),
              );
            }
          }
        }

        // Advance
        switch (payment.frequency) {
          case SubscriptionFrequency.weekly:
            current = current.add(Duration(days: 7));
            break;
          case SubscriptionFrequency.biweekly:
            current = current.add(Duration(days: 14));
            break;
          case SubscriptionFrequency.fifteenDays:
            if (current.day == 15) {
              current = DateTime(
                current.year,
                current.month + 1,
                0,
                current.hour,
                current.minute,
                current.second,
              );
            } else if (current.day > 15) {
              current = DateTime(
                current.year,
                current.month + 1,
                15,
                current.hour,
                current.minute,
                current.second,
              );
            } else {
              current = DateTime(
                current.year,
                current.month,
                15,
                current.hour,
                current.minute,
                current.second,
              );
            }
            break;
          case SubscriptionFrequency.monthly:
            current = DateTime(current.year, current.month + 1, current.day);
            break;
          case SubscriptionFrequency.threeMonths:
            current = DateTime(current.year, current.month + 3, current.day);
            break;
          case SubscriptionFrequency.yearly:
            current = DateTime(current.year + 1, current.month, current.day);
            break;
          case SubscriptionFrequency.custom:
            final days = payment.customDays ?? 30;
            current = current.add(Duration(days: days > 0 ? days : 30));
            break;
          case SubscriptionFrequency.once:
            current = rangeEnd.add(Duration(days: 1)); // stop loop
            break;
        }
      }
    }

    // Sort occurrences chronologically
    occurrences.sort((a, b) => a.date.compareTo(b.date));

    // First Pass: Find pocket deficits and generate virtual deposits
    Map<String, double> tempPocketBalances = {
      for (var p in allPockets) p.id: p.currentAmountUSD,
    };
    Map<String, _VirtualDeposit> consolidatedDeposits = {};

    for (int i = 0; i < occurrences.length; i++) {
      var occ = occurrences[i];
      final payment = occ.payment;
      if (payment.pocketId != null) {
        final pId = payment.pocketId!;
        final accId =
            payment.accountId ??
            (payment.currency == CurrencyType.usd
                ? 'default_usd'
                : 'default_ves');
        final targetAccount = accounts.firstWhere(
          (a) => a.id == accId,
          orElse: () => accounts.first,
        );
        final bool isVesTarget = targetAccount.currency == CurrencyType.bsBCV;

        double amountUSD = occ.remainingAmount;
        if (isVesTarget) {
          double amountBs = occ.remainingAmount;
          if (payment.currency == CurrencyType.usd) {
            amountBs = occ.remainingAmount * bcvRate;
          } else if (payment.currency == CurrencyType.eur) {
            amountBs = occ.remainingAmount * euroRate;
          }
          amountUSD = bcvRate > 0 ? amountBs / bcvRate : 0.0;
        } else {
          if (payment.currency == CurrencyType.bsBCV) {
            amountUSD = bcvRate > 0 ? occ.remainingAmount / bcvRate : 0.0;
          } else if (payment.currency == CurrencyType.eur) {
            amountUSD = bcvRate > 0 ? (occ.remainingAmount * euroRate) / bcvRate : 0.0;
          }
        }

        if (payment.type == TransactionType.income) {
          tempPocketBalances[pId] =
              (tempPocketBalances[pId] ?? 0.0) + amountUSD;
        } else {
          final curPocketBal = tempPocketBalances[pId] ?? 0.0;
          if (curPocketBal < amountUSD) {
            final deficit = amountUSD - curPocketBal;

            // Deficit found. We need a virtual deposit before or on `occ.date`.
            // Find most recent income event before `occ.date`, or today if none.
            DateTime depositDate = rangeStart;
            // Optimization: search backwards from current index to find the most recent income
            for (int j = i - 1; j >= 0; j--) {
              var other = occurrences[j];
              if (other.payment.type == TransactionType.income &&
                  other.payment.currency == CurrencyType.usd &&
                  other.date.isBefore(occ.date)) {
                depositDate = other.date;
                break;
              }
            }

            final dateKey =
                "${depositDate.year}-${depositDate.month.toString().padLeft(2, '0')}-${depositDate.day.toString().padLeft(2, '0')}_$pId";

            if (consolidatedDeposits.containsKey(dateKey)) {
              final existing = consolidatedDeposits[dateKey]!;
              if (existing.reasons.containsKey(payment.name)) {
                existing.reasons[payment.name]!.count++;
              } else {
                existing.reasons[payment.name] = _VirtualDepositReason(
                  name: payment.name,
                  amount: payment.amount,
                  frequency: payment.frequency.value,
                  currency: payment.currency,
                );
              }

              double displayAmountChange = deficit;
              if (payment.currency == CurrencyType.bsBCV) {
                displayAmountChange = deficit * bcvRate;
              }

              consolidatedDeposits[dateKey] = _VirtualDeposit(
                pocketId: pId,
                amountUSD: existing.amountUSD + deficit,
                amount: existing.amount + displayAmountChange,
                currency: payment.currency,
                date: depositDate,
                reasons: existing.reasons,
              );
            } else {
              double displayAmount = deficit;
              if (payment.currency == CurrencyType.bsBCV) {
                displayAmount = deficit * bcvRate;
              }

              consolidatedDeposits[dateKey] = _VirtualDeposit(
                pocketId: pId,
                amountUSD: deficit,
                amount: displayAmount,
                currency: payment.currency,
                date: depositDate,
                reasons: {
                  payment.name: _VirtualDepositReason(
                    name: payment.name,
                    amount: payment.amount,
                    frequency: payment.frequency.value,
                    currency: payment.currency,
                  )
                },
              );
            }

            tempPocketBalances[pId] = curPocketBal + deficit;
          }
          // Deduct from pocket
          tempPocketBalances[pId] = tempPocketBalances[pId]! - amountUSD;
          if (tempPocketBalances[pId]! < 0) tempPocketBalances[pId] = 0.0;
        }
      }
    }

    // Second Pass: Add savings target goals to consolidatedDeposits
    for (var pocket in allPockets) {
      final hasRule = pocket.fundingRuleType != 'none';
      if (pocket.targetAmountUSD <= 0 && !hasRule) continue;
      double remaining = pocket.targetAmountUSD > 0
          ? pocket.targetAmountUSD - pocket.currentAmountUSD
          : double.infinity;
      if (remaining <= 0 && !hasRule) continue;

      DateTime? targetD = pocket.targetDate;
      if (targetD != null) {
        if (!isPocketTargetDateFeasible(pocket, virtualPockets: virtualPockets)) {
          targetD = getViableTargetDate(pocket, virtualPockets: virtualPockets);
        }

        if (targetD == null) continue;

        // Find sequential start date after higher priority pockets complete
        DateTime startD = rangeStart;
        for (var h in allPockets) {
          if (h.id != pocket.id && h.priority < pocket.priority) {
            if (h.targetDate != null && h.targetDate!.isAfter(startD)) {
              startD = h.targetDate!;
            }
          }
        }

        // If targetD is before startD, skip scheduling
        if (targetD.isBefore(startD)) continue;

        // Find income paydays between startD and targetD (inclusive) regardless of simulation horizon
        List<DateTime> pocketPaydays = [];
        for (var payment in recurringPayments) {
          if (payment.type == TransactionType.income && payment.currency == CurrencyType.usd) {
            DateTime current = payment.startDate.copyWith(
              hour: 0,
              minute: 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );
            int count = 0;
            while (current.isBefore(targetD) ||
                current.isAtSameMomentAs(targetD)) {
              count++;
              if (payment.totalInstallments != null &&
                  count > payment.totalInstallments!) {
                break;
              }
              if (current.isAfter(startD) ||
                  current.isAtSameMomentAs(startD)) {
                if (!pocketPaydays.contains(current)) {
                  pocketPaydays.add(current);
                }
              }
              // Advance
              switch (payment.frequency) {
                case SubscriptionFrequency.weekly:
                  current = current.add(Duration(days: 7));
                  break;
                case SubscriptionFrequency.biweekly:
                  current = current.add(Duration(days: 14));
                  break;
                case SubscriptionFrequency.fifteenDays:
                  if (current.day == 15) {
                    current = DateTime(
                      current.year,
                      current.month + 1,
                      0,
                      current.hour,
                      current.minute,
                      current.second,
                    );
                  } else if (current.day > 15) {
                    current = DateTime(
                      current.year,
                      current.month + 1,
                      15,
                      current.hour,
                      current.minute,
                      current.second,
                    );
                  } else {
                    current = DateTime(
                      current.year,
                      current.month,
                      15,
                      current.hour,
                      current.minute,
                      current.second,
                    );
                  }
                  break;
                case SubscriptionFrequency.monthly:
                  current = DateTime(
                    current.year,
                    current.month + 1,
                    current.day,
                  );
                  break;
                case SubscriptionFrequency.threeMonths:
                  current = DateTime(
                    current.year,
                    current.month + 3,
                    current.day,
                  );
                  break;
                case SubscriptionFrequency.yearly:
                  current = DateTime(
                    current.year + 1,
                    current.month,
                    current.day,
                  );
                  break;
                case SubscriptionFrequency.custom:
                  final days = payment.customDays ?? 30;
                  current = current.add(Duration(days: days > 0 ? days : 30));
                  break;
                case SubscriptionFrequency.once:
                  current = targetD.add(Duration(days: 1)); // stop loop
                  break;
              }
            }
          }
        }

        if (pocketPaydays.isNotEmpty) {
          double amountPerPayday = remaining / pocketPaydays.length;
          for (var payday in pocketPaydays) {
            final isLastPayday = payday == pocketPaydays.last;
            final dateKey =
                "${payday.year}-${payday.month.toString().padLeft(2, '0')}-${payday.day.toString().padLeft(2, '0')}_${pocket.id}";
            if (consolidatedDeposits.containsKey(dateKey)) {
              final existing = consolidatedDeposits[dateKey]!;
              if (!existing.reasons.containsKey("Meta de Ahorro")) {
                existing.reasons["Meta de Ahorro"] = _VirtualDepositReason(name: "Meta de Ahorro");
              }
              consolidatedDeposits[dateKey] = _VirtualDeposit(
                pocketId: pocket.id,
                amountUSD: existing.amountUSD + amountPerPayday,
                amount: existing.amount + amountPerPayday,
                currency: CurrencyType.usd,
                date: payday,
                reasons: existing.reasons,
                isLast: existing.isLast || isLastPayday,
              );
            } else {
              consolidatedDeposits[dateKey] = _VirtualDeposit(
                pocketId: pocket.id,
                amountUSD: amountPerPayday,
                amount: amountPerPayday,
                currency: CurrencyType.usd,
                date: payday,
                reasons: {
                  "Meta de Ahorro": _VirtualDepositReason(name: "Meta de Ahorro")
                },
                isLast: isLastPayday,
              );
            }
          }
        } else {
          // Fallback: single deposit today (rangeStart)
          final dateKey =
              "${rangeStart.year}-${rangeStart.month.toString().padLeft(2, '0')}-${rangeStart.day.toString().padLeft(2, '0')}_${pocket.id}";
          if (consolidatedDeposits.containsKey(dateKey)) {
            final existing = consolidatedDeposits[dateKey]!;
            if (!existing.reasons.containsKey("Meta de Ahorro")) {
              existing.reasons["Meta de Ahorro"] = _VirtualDepositReason(name: "Meta de Ahorro");
            }
            consolidatedDeposits[dateKey] = _VirtualDeposit(
              pocketId: pocket.id,
              amountUSD: existing.amountUSD + remaining,
              amount: existing.amount + remaining,
              currency: CurrencyType.usd,
              date: rangeStart,
              reasons: existing.reasons,
              isLast: true,
            );
          } else {
            consolidatedDeposits[dateKey] = _VirtualDeposit(
              pocketId: pocket.id,
              amountUSD: remaining,
              amount: remaining,
              currency: CurrencyType.usd,
              date: rangeStart,
              reasons: {
                "Meta de Ahorro": _VirtualDepositReason(name: "Meta de Ahorro")
              },
              isLast: true,
            );
          }
        }
      } else {
        // pocket.targetDate is null: check for rules
        if (pocket.fundingRuleType != 'none') {
          double simulatedBalance = pocket.currentAmountUSD;
          for (var occ in occurrences) {
            if (occ.payment.type != TransactionType.income) continue;
            if (occ.payment.currency != CurrencyType.usd) continue;
            final accId = occ.payment.accountId ?? 'default_usd';
            final targetAccount = accounts.firstWhere(
              (a) => a.id == accId,
              orElse: () => accounts.firstWhere(
                (a) => a.currency == CurrencyType.usd,
                orElse: () => Account(id: 'default_usd', name: 'Efectivo \$', currency: CurrencyType.usd, balance: 0.0, colorHex: '', icon: ''),
              ),
            );
            if (targetAccount.currency != CurrencyType.usd) continue;

            double remainingToMeta = pocket.targetAmountUSD > 0
                ? pocket.targetAmountUSD - simulatedBalance
                : double.infinity;
            if (pocket.targetAmountUSD > 0 && remainingToMeta <= 0) break;
            double occAmountUSD = occ.remainingAmount;
            if (occ.payment.currency == CurrencyType.bsBCV) {
              occAmountUSD = bcvRate > 0 ? occ.remainingAmount / bcvRate : 0.0;
            }
            double proposedSaving = 0.0;
            String ruleReason = '';
            if (pocket.fundingRuleType == 'percentage') {
              final pct = pocket.fundingRuleValue ?? 0.0;
              proposedSaving = occAmountUSD * (pct / 100.0);
              ruleReason = "${pct.toStringAsFixed(0)}% de ingreso";
            } else if (pocket.fundingRuleType == 'fixedThreshold') {
              final threshold = pocket.fundingRuleThreshold ?? 0.0;
              final fixedVal = pocket.fundingRuleValue ?? 0.0;
              if (occAmountUSD >= threshold) {
                proposedSaving = fixedVal;
                ruleReason = "Ahorro fijo por ingreso (>= \$${threshold.toStringAsFixed(0)})";
              }
            }
            if (pocket.targetAmountUSD > 0 && proposedSaving > remainingToMeta) {
              proposedSaving = remainingToMeta;
            }
            if (proposedSaving > 0) {
              final dateKey =
                  "${occ.date.year}-${occ.date.month.toString().padLeft(2, '0')}-${occ.date.day.toString().padLeft(2, '0')}_${pocket.id}";
              if (consolidatedDeposits.containsKey(dateKey)) {
                final existing = consolidatedDeposits[dateKey]!;
                if (!existing.reasons.containsKey(ruleReason)) {
                  existing.reasons[ruleReason] = _VirtualDepositReason(name: ruleReason);
                }
                consolidatedDeposits[dateKey] = _VirtualDeposit(
                  pocketId: pocket.id,
                  amountUSD: existing.amountUSD + proposedSaving,
                  amount: existing.amount + proposedSaving,
                  currency: CurrencyType.usd,
                  date: occ.date,
                  reasons: existing.reasons,
                );
              } else {
                consolidatedDeposits[dateKey] = _VirtualDeposit(
                  pocketId: pocket.id,
                  amountUSD: proposedSaving,
                  amount: proposedSaving,
                  currency: CurrencyType.usd,
                  date: occ.date,
                  reasons: {
                    ruleReason: _VirtualDepositReason(name: ruleReason)
                  },
                );
              }
              simulatedBalance += proposedSaving;
            }
          }
        }
      }
    }

    // --- Evaluate manual USD incomes from today/past ---
    // Keep track of how much pocket balance is available to cover unconfirmed suggestions.
    Map<String, double> pocketCoveredAmounts = {
      for (var p in allPockets) p.id: p.currentAmountUSD,
    };

    // Filter and sort manual incomes chronologically (oldest first)
    // Auto-save suggestions for manual incomes are disabled. Auto-save only applies to recurring incomes.
    final manualIncomes = <Transaction>[];

    for (var t in manualIncomes) {
      final tDateMidnight = t.date.copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );

      if (tDateMidnight.isAfter(rangeStart) || tDateMidnight.isAtSameMomentAs(rangeStart)) {
        if (tDateMidnight.isBefore(rangeEnd) || tDateMidnight.isAtSameMomentAs(rangeEnd)) {
          for (var pocket in allPockets) {
            if (pocket.targetDate != null) continue;
            if (pocket.fundingRuleType == 'none') continue;

            double remainingToMeta = pocket.targetAmountUSD > 0
                ? pocket.targetAmountUSD - pocket.currentAmountUSD
                : double.infinity;
            if (pocket.targetAmountUSD > 0 && remainingToMeta <= 0) continue;

            double proposedSaving = 0.0;
            String ruleReason = '';
            if (pocket.fundingRuleType == 'percentage') {
              final pct = pocket.fundingRuleValue ?? 0.0;
              proposedSaving = t.amount * (pct / 100.0);
              ruleReason = "${pct.toStringAsFixed(0)}% de ingreso manual";
            } else if (pocket.fundingRuleType == 'fixedThreshold') {
              final threshold = pocket.fundingRuleThreshold ?? 0.0;
              final fixedVal = pocket.fundingRuleValue ?? 0.0;
              if (t.amount >= threshold) {
                proposedSaving = fixedVal;
                ruleReason = "Ahorro fijo (ingreso ≥ \$${threshold.toStringAsFixed(0)})";
              }
            }

            if (pocket.targetAmountUSD > 0 && proposedSaving > remainingToMeta) {
              proposedSaving = remainingToMeta;
            }

            if (proposedSaving > 0) {
              final confirmKey = "${t.id}_${pocket.id}";
              
              if (_manualSavingsConfirmed.contains(confirmKey)) {
                // Already confirmed, consume the amount from our tracking map
                pocketCoveredAmounts[pocket.id] = (pocketCoveredAmounts[pocket.id] ?? 0.0) - proposedSaving;
                continue;
              }

              // Check if we can cover this suggestion with direct manual deposits
              final availableCover = pocketCoveredAmounts[pocket.id] ?? 0.0;
              if (availableCover >= proposedSaving) {
                // Fully covered! Subtract from available and do not show suggestion.
                pocketCoveredAmounts[pocket.id] = availableCover - proposedSaving;
                continue;
              } else if (availableCover > 0) {
                // Partially covered! Reduce the suggestion and consume all cover.
                proposedSaving -= availableCover;
                pocketCoveredAmounts[pocket.id] = 0.0;
              }

              final dateKey = "${tDateMidnight.year}-${tDateMidnight.month.toString().padLeft(2, '0')}-${tDateMidnight.day.toString().padLeft(2, '0')}_${pocket.id}";
              if (consolidatedDeposits.containsKey(dateKey)) {
                final existing = consolidatedDeposits[dateKey]!;
                if (!existing.reasons.containsKey(ruleReason)) {
                  existing.reasons[ruleReason] = _VirtualDepositReason(name: ruleReason);
                }
                
                List<String> associatedTxs = existing.associatedTransactionIds?.toList() ?? [];
                if (!associatedTxs.contains(t.id)) {
                  associatedTxs.add(t.id);
                }

                consolidatedDeposits[dateKey] = _VirtualDeposit(
                  pocketId: pocket.id,
                  amountUSD: existing.amountUSD + proposedSaving,
                  amount: existing.amount + proposedSaving,
                  currency: CurrencyType.usd,
                  date: tDateMidnight,
                  reasons: existing.reasons,
                  associatedTransactionIds: associatedTxs,
                );
              } else {
                consolidatedDeposits[dateKey] = _VirtualDeposit(
                  pocketId: pocket.id,
                  amountUSD: proposedSaving,
                  amount: proposedSaving,
                  currency: CurrencyType.usd,
                  date: tDateMidnight,
                  reasons: {
                    ruleReason: _VirtualDepositReason(name: ruleReason)
                  },
                  associatedTransactionIds: [t.id],
                );
              }
            }
          }
        }
      }
    }

    final virtualDeposits = consolidatedDeposits.values.toList();

    // Merge occurrences, virtual deposits, and registered partial payment abonos
    List<_SimEvent> simEvents = [];
    for (var occ in occurrences) {
      simEvents.add(_SimEvent(date: occ.date, occurrence: occ));
    }
    for (var dep in virtualDeposits) {
      simEvents.add(_SimEvent(date: dep.date, deposit: dep));
    }
    for (var partial in partialPayments) {
      RecurringPayment? payment;
      for (var p in allPayments) {
        if (p.id == partial.recurringPaymentId) {
          payment = p;
          break;
        }
      }
      if (payment == null) continue;

      // Find the transaction to get its actual date
      Transaction? tx;
      for (var t in transactions) {
        if (t.id == partial.transactionId) {
          tx = t;
          break;
        }
      }
      final DateTime txDate = tx?.date ?? DateTime.now();
      final txDateMidnight = txDate.copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );

      // Only add to timeline if it is within our projection range
      if (txDateMidnight.isAfter(rangeStart) || txDateMidnight.isAtSameMomentAs(rangeStart)) {
        if (txDateMidnight.isBefore(rangeEnd) || txDateMidnight.isAtSameMomentAs(rangeEnd)) {
          simEvents.add(_SimEvent(date: txDateMidnight, partial: partial));
        }
      }
    }

    // Sort chronologically. If same date: Incomes first, then pocket virtual deposits, then expenses.
    simEvents.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;

      int getWeight(_SimEvent e) {
        if (e.occurrence != null) {
          return e.occurrence!.payment.type == TransactionType.income ? 1 : 3;
        }
        if (e.deposit != null) {
          return 2;
        }
        if (e.partial != null) {
          return 0; // Process real abonos first on the same day
        }
        return 0;
      }

      return getWeight(a).compareTo(getWeight(b));
    });

    // Reset simulation balances
    Map<String, double> projectedBalances = {
      for (var acc in accounts) acc.id: acc.balance,
    };
    Map<String, double> projectedPocketBalances = {
      for (var p in allPockets) p.id: p.currentAmountUSD,
    };

    List<TimelineEvent> events = [];

    for (var sim in simEvents) {
      if (sim.deposit != null) {
        final dep = sim.deposit!;
        final pIndex = allPockets.indexWhere((p) => p.id == dep.pocketId);
        String? pocketName;
        if (pIndex != -1) {
          pocketName = allPockets[pIndex].name;
          projectedPocketBalances[dep.pocketId] =
              (projectedPocketBalances[dep.pocketId] ?? 0.0) + dep.amountUSD;
        }

        // Calculate consolidated metrics
        double totalUSD = 0.0;
        for (var acc in accounts) {
          final bal = projectedBalances[acc.id] ?? 0.0;
          if (acc.currency == CurrencyType.usd) {
            totalUSD += bal;
          } else {
            totalUSD += bcvRate > 0 ? bal / bcvRate : 0.0;
          }
        }

        double totalPockets = projectedPocketBalances.values.fold(
          0.0,
          (sum, val) => sum + val,
        );
        double projectedLiquid = totalUSD - totalPockets;

        events.add(
          TimelineEvent(
            date: dep.date,
            title: "Apartar para Bolsillo: $pocketName",
            amount: dep.amount,
            currency: dep.currency,
            type: TransactionType.expense, // Reserved from liquid cash
            pocketName: pocketName,
            pocketId: dep.pocketId,
            accountName: dep.targetExpenseTitle, // Save target reasons here
            suggestionReasons: dep.suggestionReasonsList,
            projectedBalanceUSD: totalUSD,
            projectedLiquidBalanceUSD: projectedLiquid,
            isSuggestion: true,
            isLastProvisioning: dep.isLast,
            associatedTransactionIds: dep.associatedTransactionIds,
          ),
        );
      } else if (sim.partial != null) {
        final partial = sim.partial!;
        final payment = allPayments.firstWhere((p) => p.id == partial.recurringPaymentId);
        Transaction? tx;
        for (var t in transactions) {
          if (t.id == partial.transactionId) {
            tx = t;
            break;
          }
        }

        final accId = tx?.accountId ?? payment.accountId ??
            (payment.currency == CurrencyType.usd ? 'default_usd' : 'default_ves');
        final accIndex = accounts.indexWhere((acc) => acc.id == accId);
        String? accountName;
        if (accIndex != -1) {
          accountName = accounts[accIndex].name;
        }

        // Calculate running metrics
        double totalUSD = 0.0;
        for (var acc in accounts) {
          final bal = projectedBalances[acc.id] ?? 0.0;
          if (acc.currency == CurrencyType.usd) {
            totalUSD += bal;
          } else {
            totalUSD += bcvRate > 0 ? bal / bcvRate : 0.0;
          }
        }

        double totalPockets = projectedPocketBalances.values.fold(
          0.0,
          (sum, val) => sum + val,
        );
        double projectedLiquid = totalUSD - totalPockets;

        events.add(
          TimelineEvent(
            date: sim.date,
            title: "${payment.name} (Abono Parcial)",
            amount: partial.amount,
            currency: payment.currency,
            type: payment.type,
            accountName: accountName,
            pocketName: () {
              if (payment.pocketId == null) return null;
              for (var p in allPockets) {
                if (p.id == payment.pocketId) return p.name;
              }
              return null;
            }(),
            pocketId: payment.pocketId,
            projectedBalanceUSD: totalUSD,
            projectedLiquidBalanceUSD: projectedLiquid,
            isSuggestion: false,
            recurringPaymentId: payment.id,
            isVariable: false,
            maxAmount: null,
            isOverdue: false,
            partialAmountPaid: partial.amount,
            isCompletedAbono: true,
          ),
        );
      } else {
        final occ = sim.occurrence!;
        final payment = occ.payment;
        final remainingVal = occ.remainingAmount;
        final accId =
            payment.accountId ??
            (payment.currency == CurrencyType.usd
                ? 'default_usd'
                : 'default_ves');
        final accIndex = accounts.indexWhere((acc) => acc.id == accId);
        String? accountName;
        String? pocketName;

        double amountInAccountCurrency = remainingVal;
        double amountUSD = remainingVal;

        if (accIndex != -1) {
          final acc = accounts[accIndex];
          accountName = acc.name;

          if (acc.currency == CurrencyType.usd) {
            // Account is USD
            if (payment.currency == CurrencyType.usd) {
              amountInAccountCurrency = remainingVal;
            } else if (payment.currency == CurrencyType.eur) {
              amountInAccountCurrency = bcvRate > 0 ? (remainingVal * euroRate) / bcvRate : 0.0;
            } else {
              // VES
              amountInAccountCurrency = bcvRate > 0 ? remainingVal / bcvRate : 0.0;
            }
            amountUSD = amountInAccountCurrency;
          } else {
            // Account is VES (bsBCV)
            if (payment.currency == CurrencyType.usd) {
              amountInAccountCurrency = remainingVal * bcvRate;
            } else if (payment.currency == CurrencyType.eur) {
              amountInAccountCurrency = remainingVal * euroRate;
            } else {
              // VES
              amountInAccountCurrency = remainingVal;
            }
            amountUSD = bcvRate > 0 ? amountInAccountCurrency / bcvRate : 0.0;
          }
        } else {
          // No account associated
          if (payment.currency == CurrencyType.bsBCV) {
            amountUSD = bcvRate > 0 ? remainingVal / bcvRate : 0.0;
          } else if (payment.currency == CurrencyType.eur) {
            amountUSD = bcvRate > 0 ? (remainingVal * euroRate) / bcvRate : 0.0;
          }
        }

        // Apply to projected balances
        if (payment.type == TransactionType.income) {
          if (projectedBalances.containsKey(accId)) {
            projectedBalances[accId] =
                projectedBalances[accId]! + amountInAccountCurrency;
          }
          if (payment.pocketId != null) {
            final pIndex = allPockets.indexWhere((p) => p.id == payment.pocketId);
            if (pIndex != -1) {
              pocketName = allPockets[pIndex].name;
              projectedPocketBalances[payment.pocketId!] =
                  (projectedPocketBalances[payment.pocketId!] ?? 0.0) +
                  amountUSD;
            }
          }
        } else {
          if (projectedBalances.containsKey(accId)) {
            final curBal = projectedBalances[accId]!;
            projectedBalances[accId] = curBal - amountInAccountCurrency;
          }
          if (payment.pocketId != null) {
            final pIndex = allPockets.indexWhere((p) => p.id == payment.pocketId);
            if (pIndex != -1) {
              pocketName = allPockets[pIndex].name;
              final curPocketBal =
                  projectedPocketBalances[payment.pocketId!] ?? 0.0;
              projectedPocketBalances[payment.pocketId!] =
                  curPocketBal - amountUSD > 0 ? curPocketBal - amountUSD : 0.0;
            }
          }
        }

        // Calculate consolidated metrics
        double totalUSD = 0.0;
        for (var acc in accounts) {
          final bal = projectedBalances[acc.id] ?? 0.0;
          if (acc.currency == CurrencyType.usd) {
            totalUSD += bal;
          } else {
            totalUSD += bcvRate > 0 ? bal / bcvRate : 0.0;
          }
        }

        double totalPockets = projectedPocketBalances.values.fold(
          0.0,
          (sum, val) => sum + val,
        );
        double projectedLiquid = totalUSD - totalPockets;

        events.add(
          TimelineEvent(
            date: occ.date,
            title: payment.name,
            amount: remainingVal,
            currency: payment.currency,
            type: payment.type,
            accountName: accountName,
            pocketName: pocketName,
            pocketId: payment.pocketId,
            projectedBalanceUSD: totalUSD,
            projectedLiquidBalanceUSD: projectedLiquid,
            installmentNumber: payment.totalInstallments != null
                ? occ.installmentNumber
                : null,
            totalInstallments: payment.totalInstallments,
            isSuggestion: virtualPayments.any((v) => v.id == payment.id),
            isVariable: payment.isVariable,
            maxAmount: payment.maxAmount,
            recurringPaymentId: payment.id,
            isOverdue: occ.isOverdue,
            partialAmountPaid: occ.partialAmountPaid,
          ),
        );
      }
    }

    // Filter events to only include those within the requested projection window
    return events
        .where(
          (event) =>
              event.date.isBefore(filterEnd) ||
              event.date.isAtSameMomentAs(filterEnd),
        )
        .toList();
  }

  Map<String, dynamic> get safeToSaveExplanation {
    final events = getTimelineEvents(365);
    double minLiquid = liquidBalanceUSD;
    DateTime? minDate;
    String? minReason;

    for (var event in events) {
      if (event.projectedLiquidBalanceUSD < minLiquid) {
        minLiquid = event.projectedLiquidBalanceUSD;
        minDate = event.date;
        minReason = event.title;
      }
    }

    final isLowestToday = minLiquid == liquidBalanceUSD;

    return {
      'amount': minLiquid,
      'date': isLowestToday ? null : minDate,
      'reason': isLowestToday ? null : minReason,
    };
  }

  double get safeToSaveAmountUSD {
    return safeToSaveExplanation['amount'] as double;
  }

  double getDailySavingPotential() {
    double dailyIncome = 0.0;
    double dailyExpense = 0.0;

    for (var payment in recurringPayments) {
      final accId =
          payment.accountId ??
          (payment.currency == CurrencyType.usd
              ? 'default_usd'
              : 'default_ves');
      final targetAccount = accounts.firstWhere(
        (a) => a.id == accId,
        orElse: () => accounts.first,
      );

      double amountUSD = payment.amount;
      if (targetAccount.currency == CurrencyType.bsBCV) {
        double amountBs = payment.amount;
        if (payment.currency == CurrencyType.usd) {
          amountBs = payment.amount * bcvRate;
        } else if (payment.currency == CurrencyType.eur) {
          amountBs = payment.amount * euroRate;
        }
        amountUSD = bcvRate > 0 ? amountBs / bcvRate : 0.0;
      } else {
        if (payment.currency == CurrencyType.bsBCV) {
          amountUSD = bcvRate > 0 ? payment.amount / bcvRate : 0.0;
        } else if (payment.currency == CurrencyType.eur) {
          amountUSD = bcvRate > 0 ? (payment.amount * euroRate) / bcvRate : 0.0;
        }
      }

      double dailyEquivalent = 0.0;
      switch (payment.frequency) {
        case SubscriptionFrequency.weekly:
          dailyEquivalent = amountUSD / 7.0;
          break;
        case SubscriptionFrequency.biweekly:
          dailyEquivalent = amountUSD / 14.0;
          break;
        case SubscriptionFrequency.fifteenDays:
          dailyEquivalent = (amountUSD * 24.0) / 365.0;
          break;
        case SubscriptionFrequency.monthly:
          dailyEquivalent = amountUSD / 30.4375;
          break;
        case SubscriptionFrequency.threeMonths:
          dailyEquivalent = amountUSD / 91.3125;
          break;
        case SubscriptionFrequency.yearly:
          dailyEquivalent = amountUSD / 365.25;
          break;
        case SubscriptionFrequency.custom:
          final days = payment.customDays ?? 30;
          dailyEquivalent = days > 0 ? amountUSD / days : amountUSD / 30.0;
          break;
        case SubscriptionFrequency.once:
          dailyEquivalent = 0.0;
          break;
      }

      if (payment.type == TransactionType.income) {
        dailyIncome += dailyEquivalent;
      } else {
        dailyExpense += dailyEquivalent;
      }
    }

    return dailyIncome - dailyExpense;
  }

  double get totalDailyMinimumIncomeUSD {
    double total = 0.0;
    for (var payment in recurringPayments) {
      if (payment.type == TransactionType.income) {
        final accId =
            payment.accountId ??
            (payment.currency == CurrencyType.usd
                ? 'default_usd'
                : 'default_ves');
        final targetAccount = accounts.firstWhere(
          (a) => a.id == accId,
          orElse: () => accounts.first,
        );

        double amountUSD = payment.amount;
        if (targetAccount.currency == CurrencyType.bsBCV) {
          double amountBs = payment.amount;
          if (payment.currency == CurrencyType.usd) {
            amountBs = payment.amount * bcvRate;
          } else if (payment.currency == CurrencyType.eur) {
            amountBs = payment.amount * euroRate;
          }
          amountUSD = bcvRate > 0 ? amountBs / bcvRate : 0.0;
        } else {
          if (payment.currency == CurrencyType.bsBCV) {
            amountUSD = bcvRate > 0 ? payment.amount / bcvRate : 0.0;
          } else if (payment.currency == CurrencyType.eur) {
            amountUSD = bcvRate > 0 ? (payment.amount * euroRate) / bcvRate : 0.0;
          }
        }

        double dailyEquivalent = 0.0;
        switch (payment.frequency) {
          case SubscriptionFrequency.weekly:
            dailyEquivalent = amountUSD / 7.0;
            break;
          case SubscriptionFrequency.biweekly:
            dailyEquivalent = amountUSD / 14.0;
            break;
          case SubscriptionFrequency.fifteenDays:
            dailyEquivalent = (amountUSD * 24.0) / 365.0;
            break;
          case SubscriptionFrequency.monthly:
            dailyEquivalent = amountUSD / 30.4375;
            break;
          case SubscriptionFrequency.threeMonths:
            dailyEquivalent = amountUSD / 91.3125;
            break;
          case SubscriptionFrequency.yearly:
            dailyEquivalent = amountUSD / 365.25;
            break;
          case SubscriptionFrequency.custom:
            final days = payment.customDays ?? 30;
            dailyEquivalent = days > 0 ? amountUSD / days : amountUSD / 30.0;
            break;
          case SubscriptionFrequency.once:
            dailyEquivalent = 0.0;
            break;
        }
        total += dailyEquivalent;
      }
    }
    return total;
  }

  Map<String, double> calculatePocketAllocations({List<SavingPocket> virtualPockets = const []}) {
    final allPockets = [...pockets, ...virtualPockets];
    final dsp = getDailySavingPotential();
    Map<String, double> allocations = {};
    if (dsp <= 0) {
      for (var p in allPockets) {
        allocations[p.id] = 0.0;
      }
      return allocations;
    }

    // Filter pockets that have a remaining target amount
    final activePockets = allPockets.where((p) {
      return p.targetAmountUSD > p.currentAmountUSD;
    }).toList();

    // Group active pockets by priority
    Map<int, List<SavingPocket>> groupedByPriority = {};
    for (var p in activePockets) {
      groupedByPriority.putIfAbsent(p.priority, () => []).add(p);
    }
    final sortedPriorities = groupedByPriority.keys.toList()..sort();

    double remainingDsp = dsp;

    for (var priority in sortedPriorities) {
      final list = groupedByPriority[priority]!;

      Map<String, double> requiredRates = {};
      double totalRequiredForLevel = 0.0;

      for (var p in list) {
        final remaining = p.targetAmountUSD - p.currentAmountUSD;
        // Default target date of 365 days if none specified to estimate a required rate
        final targetD =
            p.targetDate ?? DateTime.now().add(Duration(days: 365));
        final today = DateTime.now().copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
        final cleanTarget = targetD.copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
        final days = cleanTarget.difference(today).inDays;
        final activeDays = days > 0 ? days : 1;

        final rate = remaining / activeDays;
        requiredRates[p.id] = rate;
        totalRequiredForLevel += rate;
      }

      if (totalRequiredForLevel <= 0) continue;

      if (remainingDsp >= totalRequiredForLevel) {
        for (var p in list) {
          allocations[p.id] = requiredRates[p.id]!;
        }
        remainingDsp -= totalRequiredForLevel;
      } else {
        // Split proportionally if remaining dsp is insufficient for this priority level
        for (var p in list) {
          final rate = requiredRates[p.id]!;
          allocations[p.id] = remainingDsp * (rate / totalRequiredForLevel);
        }
        remainingDsp = 0.0;
        break; // No more DSP available for lower priority levels
      }
    }

    // Default any pocket that was not allocated to 0.0
    for (var p in allPockets) {
      allocations.putIfAbsent(p.id, () => 0.0);
    }

    return allocations;
  }

  bool isPocketTargetDateFeasible(SavingPocket pocket, {List<SavingPocket> virtualPockets = const []}) {
    final allPockets = [...pockets, ...virtualPockets];
    if (pocket.targetAmountUSD <= 0 || pocket.targetDate == null) return true;
    double remaining = pocket.targetAmountUSD - pocket.currentAmountUSD;
    if (remaining <= 0) return true;

    final today = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final targetDate = pocket.targetDate!.copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    if (targetDate.isBefore(today)) return false;

    DateTime startD = today;
    for (var h in allPockets) {
      if (h.id != pocket.id && h.priority < pocket.priority) {
        if (h.targetDate != null && h.targetDate!.isAfter(startD)) {
          startD = h.targetDate!;
        }
      }
    }

    if (targetDate.isBefore(startD)) return false;

    final daysToTarget = targetDate.difference(startD).inDays;

    double safeAmt = liquidBalanceUSD;
    double netRemaining = remaining - safeAmt;
    if (netRemaining <= 0) return true;

    final allocations = calculatePocketAllocations(virtualPockets: virtualPockets);
    final pocketDsp = allocations[pocket.id] ?? 0.0;
    if (pocketDsp <= 0) {
      return false;
    }

    final daysNeeded = netRemaining / pocketDsp;
    return daysToTarget >= daysNeeded;
  }

  DateTime? getViableTargetDate(SavingPocket pocket, {List<SavingPocket> virtualPockets = const []}) {
    final allPockets = [...pockets, ...virtualPockets];
    if (pocket.targetAmountUSD <= 0 || pocket.targetDate == null) return null;
    double remaining = pocket.targetAmountUSD - pocket.currentAmountUSD;
    if (remaining <= 0) return null;

    final today = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    DateTime startD = today;
    for (var h in allPockets) {
      if (h.id != pocket.id && h.priority < pocket.priority) {
        if (h.targetDate != null && h.targetDate!.isAfter(startD)) {
          startD = h.targetDate!;
        }
      }
    }

    double safeAmt = liquidBalanceUSD;
    double netRemaining = remaining - safeAmt;
    if (netRemaining <= 0) {
      return startD;
    }

    final allocations = calculatePocketAllocations(virtualPockets: virtualPockets);
    final pocketDsp = allocations[pocket.id] ?? 0.0;
    if (pocketDsp <= 0) {
      return null;
    }

    final daysNeeded = netRemaining / pocketDsp;
    final daysInt = daysNeeded.ceil();

    return startD.add(Duration(days: daysInt));
  }

  // MARK: - Recurring Payment Confirmations & Pending List
  Future<void> updatePendingPaymentsToday() async {
    final today = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    List<PendingOccurrence> pending = [];
    for (var payment in recurringPayments) {
      DateTime current = payment.startDate.copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      int count = 0;

      while (current.isBefore(today) || current.isAtSameMomentAs(today)) {
        count++;
        if (payment.totalInstallments != null &&
            count > payment.totalInstallments!) {
          break;
        }

        final dateStr =
            "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
        final key = "${payment.id}_$dateStr";

        if (!_confirmedKeys.contains(key)) {
          // Calculate partial amount paid
          double partialPaid = 0.0;
          for (var p in partialPayments) {
            if (p.recurringPaymentId == payment.id && p.occurrenceDate == dateStr) {
              partialPaid += p.amount;
            }
          }

          pending.add(
            PendingOccurrence(
              payment: payment,
              occurrenceDate: current,
              partialAmountPaid: partialPaid,
            ),
          );
        }

        // Advance current by frequency
        switch (payment.frequency) {
          case SubscriptionFrequency.weekly:
            current = current.add(Duration(days: 7));
            break;
          case SubscriptionFrequency.biweekly:
            current = current.add(Duration(days: 14));
            break;
          case SubscriptionFrequency.fifteenDays:
            if (current.day == 15) {
              current = DateTime(
                current.year,
                current.month + 1,
                0,
                current.hour,
                current.minute,
                current.second,
              );
            } else if (current.day > 15) {
              current = DateTime(
                current.year,
                current.month + 1,
                15,
                current.hour,
                current.minute,
                current.second,
              );
            } else {
              current = DateTime(
                current.year,
                current.month,
                15,
                current.hour,
                current.minute,
                current.second,
              );
            }
            break;
          case SubscriptionFrequency.monthly:
            current = DateTime(current.year, current.month + 1, current.day);
            break;
          case SubscriptionFrequency.threeMonths:
            current = DateTime(current.year, current.month + 3, current.day);
            break;
          case SubscriptionFrequency.yearly:
            current = DateTime(current.year + 1, current.month, current.day);
            break;
          case SubscriptionFrequency.custom:
            final days = payment.customDays ?? 30;
            current = current.add(Duration(days: days > 0 ? days : 30));
            break;
          case SubscriptionFrequency.once:
            current = today.add(Duration(days: 1)); // stop loop
            break;
        }
      }
    }

    pending.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    pending.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    _pendingPaymentsToday = pending;
  }

  Future<List<PendingOccurrence>> fetchPendingPaymentsForProfile(String profileId) async {
    if (profileId == _activeDbName) {
      return _pendingPaymentsToday;
    }
    
    final data = await DatabaseHelper.instance.getPendingDataForProfile(profileId);
    final List<RecurringPayment> recurring = data['recurring'];
    final List<Map<String, dynamic>> confs = data['confirmations'];
    final List<RecurringPaymentPartial> partials = data['partials'];
    
    final Set<String> confirmedKeys = {};
    for (var c in confs) {
      final pId = c['recurring_payment_id'] as String;
      final dateStr = c['date'] as String;
      confirmedKeys.add("${pId}_$dateStr");
    }
    
    final today = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    List<PendingOccurrence> pending = [];
    for (var payment in recurring) {
      DateTime current = payment.startDate.copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0,
      );
      int count = 0;

      while (current.isBefore(today) || current.isAtSameMomentAs(today)) {
        count++;
        if (payment.totalInstallments != null && count > payment.totalInstallments!) break;

        final dateStr = "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
        final key = "${payment.id}_$dateStr";

        if (!confirmedKeys.contains(key)) {
          double partialPaid = 0.0;
          for (var p in partials) {
            if (p.recurringPaymentId == payment.id && p.occurrenceDate == dateStr) {
              partialPaid += p.amount;
            }
          }
          pending.add(PendingOccurrence(
            payment: payment,
            occurrenceDate: current,
            partialAmountPaid: partialPaid,
          ));
        }

        switch (payment.frequency) {
          case SubscriptionFrequency.weekly: current = current.add(const Duration(days: 7)); break;
          case SubscriptionFrequency.biweekly: current = current.add(const Duration(days: 14)); break;
          case SubscriptionFrequency.fifteenDays:
            if (current.day == 15) {
              current = DateTime(current.year, current.month + 1, 0, current.hour, current.minute, current.second);
            } else if (current.day > 15) {
              current = DateTime(current.year, current.month + 1, 15, current.hour, current.minute, current.second);
            } else {
              current = DateTime(current.year, current.month, 15, current.hour, current.minute, current.second);
            }
            break;
          case SubscriptionFrequency.monthly: current = DateTime(current.year, current.month + 1, current.day); break;
          case SubscriptionFrequency.threeMonths: current = DateTime(current.year, current.month + 3, current.day); break;
          case SubscriptionFrequency.yearly: current = DateTime(current.year + 1, current.month, current.day); break;
          case SubscriptionFrequency.custom: 
            final days = payment.customDays ?? 30;
            current = current.add(Duration(days: days > 0 ? days : 30));
            break;
          case SubscriptionFrequency.once: current = today.add(const Duration(days: 1)); break;
        }
      }
    }

    pending.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    return pending;
  }

  int getConfirmedCountForPayment(String paymentId) {
    return _confirmedKeys.where((k) => k.startsWith("${paymentId}_")).length;
  }

  Future<bool> confirmRecurringPayment({
    required RecurringPayment payment,
    required double actualAmount,
    DateTime? occurrenceDate,
    CurrencyType? overrideCurrency,
    double? customExchangeRate,
    String? customNote,
    String? overrideAccountId,
  }) async {
    final dateToConfirm = occurrenceDate ?? DateTime.now();
    final today = dateToConfirm.copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Find category
    final categoryId = payment.type == TransactionType.income
        ? categories
              .firstWhere(
                (cat) => cat.type == TransactionCategoryType.income && cat.name != "Cambio de Divisa",
                orElse: () => categories.firstWhere((cat) => cat.type == TransactionCategoryType.income, orElse: () => categories.first),
              )
              .id
        : categories
              .firstWhere(
                (cat) => cat.type == TransactionCategoryType.expense && cat.name != "Cambio de Divisa",
                orElse: () => categories.firstWhere((cat) => cat.type == TransactionCategoryType.expense, orElse: () => categories.first),
              )
              .id;

    final targetCurrency = overrideCurrency ?? payment.currency;
    final rateToUse = customExchangeRate ?? 
        (targetCurrency == CurrencyType.eur ? _euroRate : _bcvRate);
    final noteToUse = customNote ?? "Confirmado: ${payment.name}";

    // Create real transaction if amount > 0
    if (actualAmount > 0.0) {
      final newTx = Transaction(
        id: "${DateTime.now().millisecondsSinceEpoch}_rec",
        date: DateTime.now(),
        amount: actualAmount,
        currency: targetCurrency,
        destinationPocketId: payment.pocketId,
        categoryId: categoryId,
        accountId:
            overrideAccountId ??
            payment.accountId ??
            (payment.currency == CurrencyType.usd
                ? 'default_usd'
                : 'default_ves'),
        note: noteToUse,
        type: payment.type,
        exchangeRate: rateToUse,
      );

      await addTransaction(newTx);
    }

    // Insert confirmation record
    await DatabaseHelper.instance.insertConfirmation(payment.id, todayStr);
    _confirmedKeys.add("${payment.id}_$todayStr");

    // Update pending list
    await updatePendingPaymentsToday();
    notifyListeners();

    if (payment.totalInstallments != null && payment.totalInstallments! > 0) {
      int confirmedCount = getConfirmedCountForPayment(payment.id);
      if (confirmedCount >= payment.totalInstallments!) {
        return true;
      }
    }
    return false;
  }

  Future<void> registerPartialPayment({
    required RecurringPayment payment,
    required double partialAmount,
    required DateTime occurrenceDate,
    CurrencyType? overrideCurrency,
    double? customExchangeRate,
    String? customNote,
    String? overrideAccountId,
  }) async {
    final today = occurrenceDate.copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final dateStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Find category
    final categoryId = payment.type == TransactionType.income
        ? categories
              .firstWhere(
                (cat) => cat.type == TransactionCategoryType.income && cat.name != "Cambio de Divisa",
                orElse: () => categories.firstWhere((cat) => cat.type == TransactionCategoryType.income, orElse: () => categories.first),
              )
              .id
        : categories
              .firstWhere(
                (cat) => cat.type == TransactionCategoryType.expense && cat.name != "Cambio de Divisa",
                orElse: () => categories.firstWhere((cat) => cat.type == TransactionCategoryType.expense, orElse: () => categories.first),
              )
              .id;

    final accountIdToUse = overrideAccountId ??
        payment.accountId ??
        (payment.currency == CurrencyType.usd
            ? 'default_usd'
            : 'default_ves');

    final targetAccount = accounts.firstWhere(
      (a) => a.id == accountIdToUse,
      orElse: () => accounts.first,
    );
    final targetCurrency = overrideCurrency ?? targetAccount.currency;
    final rateToUse = customExchangeRate ?? _bcvRate;
    final noteToUse = customNote ?? "Pago Parcial: ${payment.name}";

    // Calculate transaction amount in target account's currency
    double txAmount = partialAmount;
    if (payment.currency != targetCurrency) {
      if (payment.currency == CurrencyType.usd && targetCurrency == CurrencyType.bsBCV) {
        txAmount = partialAmount * rateToUse;
      } else if (payment.currency == CurrencyType.bsBCV && targetCurrency == CurrencyType.usd) {
        txAmount = rateToUse > 0 ? partialAmount / rateToUse : 0.0;
      }
    }

    // Create real transaction
    final txId = "${DateTime.now().millisecondsSinceEpoch}_partial";
    final newTx = Transaction(
      id: txId,
      date: DateTime.now(),
      amount: txAmount,
      currency: targetCurrency,
      destinationPocketId: payment.pocketId,
      categoryId: categoryId,
      accountId: accountIdToUse,
      note: noteToUse,
      type: payment.type,
      exchangeRate: rateToUse,
    );

    await addTransaction(newTx);

    // Record partial payment (Always store in recurring payment's original currency)
    final partialObj = RecurringPaymentPartial(
      id: Uuid().v4(),
      recurringPaymentId: payment.id,
      occurrenceDate: dateStr,
      amount: partialAmount, 
      transactionId: txId,
    );

    await DatabaseHelper.instance.insertPartial(partialObj.toMap());
    partialPayments.add(partialObj);

    // Update pending list
    await updatePendingPaymentsToday();
    notifyListeners();
  }

  Future<void> dismissRecurringPaymentToday(
    RecurringPayment payment, {
    DateTime? occurrenceDate,
  }) async {
    final dateToConfirm = occurrenceDate ?? DateTime.now();
    final today = dateToConfirm.copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    await DatabaseHelper.instance.insertConfirmation(payment.id, todayStr);
    _confirmedKeys.add("${payment.id}_$todayStr");
    await updatePendingPaymentsToday();
    notifyListeners();
  }

  // MARK: - Wipes All Data

  Future<void> clearAllData() async {
    for (var sub in recurringPayments) {
      await NotificationManager.shared.cancelNotification(sub);
    }

    await DatabaseHelper.instance.clearAllData();
    _bcvRate = 42.15;
    _parallelRate = 45.00;
    _euroRate = 45.00;
    _selectedCurrency = CurrencyType.usd;

    await loadData();
  }

  Future<void> clearPartialData() async {
    for (var sub in recurringPayments) {
      await NotificationManager.shared.cancelNotification(sub);
    }

    await DatabaseHelper.instance.clearPartialData();
    await loadData();
  }

  // MARK: - Accounts Manager

  Future<void> addAccount({
    required String name,
    required CurrencyType currency,
    required double initialBalance,
    required String colorHex,
    required String icon,
  }) async {
    final acc = Account(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      currency: currency,
      balance: initialBalance,
      colorHex: colorHex,
      icon: icon,
    );

    await DatabaseHelper.instance.insertAccount(acc);
    accounts = await DatabaseHelper.instance.getAccounts();
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    await DatabaseHelper.instance.updateAccount(account);
    accounts = await DatabaseHelper.instance.getAccounts();
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    if (id == 'default_usd' || id == 'default_ves') {
      return; // Prevent deleting default accounts
    }
    if (accounts.length <= 1) {
      return; // Prevent deleting the last remaining account
    }
    await DatabaseHelper.instance.deleteAccount(id);
    accounts = await DatabaseHelper.instance.getAccounts();
    notifyListeners();
  }

  // MARK: - Exchange Manager

  Future<String> _getOrCreateExchangeCategory(
    TransactionCategoryType type,
  ) async {
    const catName = "Cambio de Divisa";
    final matchIndex = categories.indexWhere(
      (cat) => cat.name == catName && cat.type == type,
    );
    if (matchIndex != -1) {
      return categories[matchIndex].id;
    }

    final newId =
        DateTime.now().millisecondsSinceEpoch.toString() +
        (type == TransactionCategoryType.income ? "_inc" : "_exp");
    final newCat = TransactionCategory(
      id: newId,
      name: catName,
      icon: "ellipsis",
      colorHex: "#FF9500",
      type: type,
    );
    await DatabaseHelper.instance.insertCategory(newCat);
    categories = await DatabaseHelper.instance.getCategories();
    return newId;
  }

  Future<void> exchangeCurrency({
    required String usdAccountId,
    required String vesAccountId,
    required double amountUSD,
    required double exchangeRate,
    required bool isVenta, // true: Venta USD -> VES, false: Compra VES -> USD
    required String note,
  }) async {
    final amountVES = amountUSD * exchangeRate;

    final incomeCatId = await _getOrCreateExchangeCategory(
      TransactionCategoryType.income,
    );
    final expenseCatId = await _getOrCreateExchangeCategory(
      TransactionCategoryType.expense,
    );

    final usdIndex = accounts.indexWhere((acc) => acc.id == usdAccountId);
    final vesIndex = accounts.indexWhere((acc) => acc.id == vesAccountId);

    if (usdIndex == -1 || vesIndex == -1) return;

    final usdAcc = accounts[usdIndex];
    final vesAcc = accounts[vesIndex];

    final now = DateTime.now();

    if (isVenta) {
      // Venta: USD -> VES
      // 1. USD Account Egress (Expense)
      usdAcc.balance = usdAcc.balance - amountUSD > 0
          ? usdAcc.balance - amountUSD
          : 0.0;
      final usdTx = Transaction(
        id: "${now.millisecondsSinceEpoch}_usd_exp",
        date: now,
        amount: amountUSD,
        currency: CurrencyType.usd,
        categoryId: expenseCatId,
        accountId: usdAccountId,
        note: note.isEmpty ? "Venta de Divisa" : note,
        type: TransactionType.expense,
        exchangeRate: exchangeRate,
      );

      // 2. VES Account Ingress (Income)
      vesAcc.balance += amountVES;
      final vesTx = Transaction(
        id: "${now.millisecondsSinceEpoch}_ves_inc",
        date: now,
        amount: amountVES,
        currency: CurrencyType.bsBCV,
        categoryId: incomeCatId,
        accountId: vesAccountId,
        note: note.isEmpty ? "Venta de Divisa" : note,
        type: TransactionType.income,
        exchangeRate: exchangeRate,
      );

      await DatabaseHelper.instance.updateAccount(usdAcc);
      await DatabaseHelper.instance.updateAccount(vesAcc);
      await DatabaseHelper.instance.insertTransaction(usdTx);
      await DatabaseHelper.instance.insertTransaction(vesTx);
    } else {
      // Compra: VES -> USD
      // 1. VES Account Egress (Expense)
      vesAcc.balance = vesAcc.balance - amountVES > 0
          ? vesAcc.balance - amountVES
          : 0.0;
      final vesTx = Transaction(
        id: "${now.millisecondsSinceEpoch}_ves_exp",
        date: now,
        amount: amountVES,
        currency: CurrencyType.bsBCV,
        categoryId: expenseCatId,
        accountId: vesAccountId,
        note: note.isEmpty ? "Compra de Divisa" : note,
        type: TransactionType.expense,
        exchangeRate: exchangeRate,
      );

      // 2. USD Account Ingress (Income)
      usdAcc.balance += amountUSD;
      final usdTx = Transaction(
        id: "${now.millisecondsSinceEpoch}_usd_inc",
        date: now,
        amount: amountUSD,
        currency: CurrencyType.usd,
        categoryId: incomeCatId,
        accountId: usdAccountId,
        note: note.isEmpty ? "Compra de Divisa" : note,
        type: TransactionType.income,
        exchangeRate: exchangeRate,
      );

      await DatabaseHelper.instance.updateAccount(usdAcc);
      await DatabaseHelper.instance.updateAccount(vesAcc);
      await DatabaseHelper.instance.insertTransaction(usdTx);
      await DatabaseHelper.instance.insertTransaction(vesTx);
    }

    transactions = await DatabaseHelper.instance.getTransactions();
    accounts = await DatabaseHelper.instance.getAccounts();
    notifyListeners();
  }

  // MARK: - Guided Tutorial/Showcases States

  bool shouldShowDashboardTutorial = false;
  bool shouldShowPocketsTutorial = false;
  bool shouldShowTimelineTutorial = false;
  bool shouldShowRecurrentsTutorial = false;

  int initialPocketsSubTab = 0; // 0 = Bolsillos, 1 = Recurrentes, 2 = Proyección

  void triggerDashboardTutorial() {
    shouldShowDashboardTutorial = true;
    _currentTabIndex = 0;
    notifyListeners();
  }

  void triggerPocketsTutorial() {
    shouldShowPocketsTutorial = true;
    _currentTabIndex = 1;
    initialPocketsSubTab = 0; // Reset sub-tab to first one
    notifyListeners();
  }

  void triggerRecurrentsTutorial() {
    shouldShowRecurrentsTutorial = true;
    _currentTabIndex = 1;
    initialPocketsSubTab = 1; // Go to Recurrentes sub-tab
    notifyListeners();
  }

  void triggerTimelineTutorial() {
    shouldShowTimelineTutorial = true;
    _currentTabIndex = 1;
    initialPocketsSubTab = 2; // Go straight to Timeline sub-tab
    notifyListeners();
  }

  Future<void> resetAllTutorials() async {
    try {
      await DatabaseHelper.instance.setSetting('tutorial_dashboard_seen', 'false');
      await DatabaseHelper.instance.setSetting('tutorial_pockets_seen', 'false');
      await DatabaseHelper.instance.setSetting('tutorial_timeline_seen', 'false');
      await DatabaseHelper.instance.setSetting('tutorial_recurrents_seen', 'false');
    } catch (e) {
      debugPrint("Error resetting tutorial settings database records: $e");
    }
    shouldShowDashboardTutorial = false;
    shouldShowPocketsTutorial = false;
    shouldShowTimelineTutorial = false;
    shouldShowRecurrentsTutorial = false;
    notifyListeners();
  }

  // MARK: - Navigation Manager

  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  int get historyFilterIndex => _historyFilterIndex;

  void setHistoryFilterIndex(int index) {
    _historyFilterIndex = index;
    notifyListeners();
  }

  // MARK: - Mobile Payment Recipients Manager
  Future<void> addRecipient({
    required String alias,
    required String bankCode,
    required String bankName,
    required String identityCard,
    required String phoneNumber,
  }) async {
    final recipient = MobilePaymentRecipient(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      alias: alias,
      bankCode: bankCode,
      bankName: bankName,
      identityCard: identityCard,
      phoneNumber: phoneNumber,
    );
    try {
      await DatabaseHelper.instance.insertRecipient(recipient);
    } catch (e) {
      if (kDebugMode) {
        print("Error inserting recipient in DB: $e");
      }
    }
    recipients.add(recipient);
    try {
      recipients = await DatabaseHelper.instance.getRecipients();
    } catch (e) {
      if (kDebugMode) {
        print("Error reloading recipients from DB: $e");
      }
    }
    notifyListeners();
  }

  Future<void> updateRecipient(MobilePaymentRecipient recipient) async {
    try {
      await DatabaseHelper.instance.updateRecipient(recipient);
    } catch (e) {
      if (kDebugMode) {
        print("Error updating recipient in DB: $e");
      }
    }
    final index = recipients.indexWhere((r) => r.id == recipient.id);
    if (index != -1) {
      recipients[index] = recipient;
    }
    try {
      recipients = await DatabaseHelper.instance.getRecipients();
    } catch (e) {
      if (kDebugMode) {
        print("Error reloading recipients from DB: $e");
      }
    }
    notifyListeners();
  }

  Future<void> deleteRecipient(String id) async {
    try {
      await DatabaseHelper.instance.deleteRecipient(id);
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting recipient in DB: $e");
      }
    }
    recipients.removeWhere((r) => r.id == id);
    try {
      recipients = await DatabaseHelper.instance.getRecipients();
    } catch (e) {
      if (kDebugMode) {
        print("Error reloading recipients from DB: $e");
      }
    }
    notifyListeners();
  }

  // MARK: - Profiles / Libros Operations
  Future<void> switchProfile(String dbName) async {
    await DatabaseHelper.instance.switchProfile(dbName);
    _activeDbName = dbName;
    
    final activeProfile = _profiles.firstWhere(
      (p) => p['id'] == _activeDbName,
      orElse: () => _profiles.first,
    );
    if (activeProfile.containsKey('color') && activeProfile['color'] != null) {
      final colorHex = activeProfile['color']!;
      AppColors.updateThemeColor(Color(int.parse(colorHex.replaceFirst('#', '0xFF'))));
    } else {
      AppColors.updateThemeColor(Color(0xFF1F6F5F)); // Default color
    }
    
    await DatabaseHelper.instance.saveProfiles(dbName, _profiles);
    await loadData();
    notifyListeners();
  }

  Future<void> createProfile(String name, String color) async {
    final id = "quebrado_${DateTime.now().millisecondsSinceEpoch}.db";
    _profiles.add({'id': id, 'name': name, 'color': color});
    await switchProfile(id);
  }

  Future<void> updateProfile(String id, String newName, String newColor) async {
    final index = _profiles.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      _profiles[index]['name'] = newName;
      _profiles[index]['color'] = newColor;
      
      if (_activeDbName == id) {
        AppColors.updateThemeColor(Color(int.parse(newColor.replaceFirst('#', '0xFF'))));
      }
      
      await DatabaseHelper.instance.saveProfiles(_activeDbName, _profiles);
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    if (id == 'quebrado.db') return;
    
    _profiles.removeWhere((p) => p['id'] == id);
    
    if (_activeDbName == id) {
      await switchProfile('quebrado.db');
    } else {
      await DatabaseHelper.instance.saveProfiles(_activeDbName, _profiles);
    }
    
    await DatabaseHelper.instance.deleteDatabaseFile(id);
    notifyListeners();
  }

  // MARK: - Backup Management System Methods

  Future<Map<String, dynamic>> loadBackupMetadata() async {
    return await DatabaseHelper.instance.loadBackupMetadata();
  }

  Future<void> updateSecurityPin(String newPin) async {
    final metadata = await loadBackupMetadata();
    metadata['security_pin'] = newPin;
    await DatabaseHelper.instance.saveBackupMetadata(metadata);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getBackupsList() async {
    return await DatabaseHelper.instance.listBackups();
  }

  Future<void> createManualBackup() async {
    await DatabaseHelper.instance.performManualBackup();
    notifyListeners();
  }

  Future<void> deleteBackup(String folderName) async {
    await DatabaseHelper.instance.deleteBackup(folderName);
    notifyListeners();
  }

  Future<bool> restoreBackup(String folderName) async {
    final ok = await DatabaseHelper.instance.restoreBackup(folderName);
    if (ok) {
      await loadData();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> importBackupFromFile() async {
    try {
      final ok = await BackupService.importBackup();
      if (ok) {
        final metadata = await DatabaseHelper.instance.loadBackupMetadata();
        final restoreHistory = List<Map<String, dynamic>>.from(
          metadata['restore_history'] as List? ?? []
        );
        restoreHistory.add({
          'backup_name': 'Archivo importado (.json)',
          'restored_at': DateTime.now().toIso8601String(),
          'success': true,
        });
        metadata['restore_history'] = restoreHistory;
        await DatabaseHelper.instance.saveBackupMetadata(metadata);

        await loadData();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      final metadata = await DatabaseHelper.instance.loadBackupMetadata();
      final restoreHistory = List<Map<String, dynamic>>.from(
        metadata['restore_history'] as List? ?? []
      );
      restoreHistory.add({
        'backup_name': 'Archivo importado (.json)',
        'restored_at': DateTime.now().toIso8601String(),
        'success': false,
        'error': e.toString(),
      });
      metadata['restore_history'] = restoreHistory;
      await DatabaseHelper.instance.saveBackupMetadata(metadata);
      rethrow;
    }
  }

  Future<void> exportBackupFolder(String folderName, {Rect? sharePositionOrigin}) async {
    await BackupService.exportBackupFolder(folderName, sharePositionOrigin: sharePositionOrigin);
  }

  Future<Map<String, dynamic>> getBackupPreview(String folderPath) async {
    return await DatabaseHelper.instance.getBackupPreview(folderPath);
  }

  // MARK: - Market Product History
  List<Map<String, dynamic>> getHistoricalPricesForProduct(String productId, String storeId) {
    final List<Map<String, dynamic>> history = [];
    final items = marketItems.where((i) => i.productId == productId && i.storeId == storeId).toList();
    // Sort items by date descending
    items.sort((a, b) => b.date.compareTo(a.date));

    for (var item in items) {
      final trip = marketTrips.firstWhere(
        (t) => t.id == item.tripId, 
        orElse: () => MarketTrip(id: '', title: 'Sesión Desconocida', date: item.date)
      );
      
      history.add({
        'date': item.date,
        'tripTitle': trip.title,
        'priceUSD': item.priceUSD,
        'priceVES': item.priceVES,
        'exchangeRateUsed': item.exchangeRateUsed,
      });
    }
    
    return history;
  }
}

class _OccurrenceRaw {
  final RecurringPayment payment;
  final DateTime date;
  final int installmentNumber;
  final bool isOverdue;
  final double partialAmountPaid;
  _OccurrenceRaw(
    this.payment,
    this.date,
    this.installmentNumber, {
    this.isOverdue = false,
    this.partialAmountPaid = 0.0,
  });

  double get remainingAmount => payment.amount - partialAmountPaid;
}

class _VirtualDepositReason {
  final String name;
  final double? amount;
  final String? frequency;
  final CurrencyType? currency;
  int count;

  _VirtualDepositReason({
    required this.name,
    this.amount,
    this.frequency,
    this.currency,
    this.count = 1,
  });
}

class _VirtualDeposit {
  final String pocketId;
  final double amountUSD;
  final double amount;
  final CurrencyType currency;
  final DateTime date;
  final Map<String, _VirtualDepositReason> reasons;
  final bool isLast;
  final List<String>? associatedTransactionIds;
  _VirtualDeposit({
    required this.pocketId,
    required this.amountUSD,
    required this.amount,
    required this.currency,
    required this.date,
    required this.reasons,
    this.isLast = false,
    this.associatedTransactionIds,
  });

  String get targetExpenseTitle {
    if (reasons.isEmpty) return "";
    List<String> lines = [];
    for (var reason in reasons.values) {
      if (reason.amount != null && reason.frequency != null && reason.currency != null) {
        String currSymbol = reason.currency == CurrencyType.usd ? "\$" : (reason.currency == CurrencyType.eur ? "€" : "Bs.");
        if (reason.count > 1) {
          double total = reason.amount! * reason.count;
          String formattedAmount = reason.amount! % 1 == 0 ? reason.amount!.toStringAsFixed(0) : reason.amount!.toStringAsFixed(2);
          String formattedTotal = total % 1 == 0 ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
          lines.add("• ${reason.name} $currSymbol$formattedAmount x${reason.count} = $currSymbol$formattedTotal (${reason.frequency!.toLowerCase()})");
        } else {
          String formattedAmount = reason.amount! % 1 == 0 ? reason.amount!.toStringAsFixed(0) : reason.amount!.toStringAsFixed(2);
          lines.add("• ${reason.name} $currSymbol$formattedAmount (${reason.frequency!.toLowerCase()})");
        }
      } else {
        lines.add("• ${reason.name}");
      }
    }
    return lines.join("\n");
  }

  List<SuggestionReason> get suggestionReasonsList {
    if (reasons.isEmpty) return [];
    List<SuggestionReason> list = [];
    for (var reason in reasons.values) {
      if (reason.amount != null && reason.frequency != null && reason.currency != null) {
        String currSymbol = reason.currency == CurrencyType.usd ? "\$" : (reason.currency == CurrencyType.eur ? "€" : "Bs.");
        if (reason.count > 1) {
          double total = reason.amount! * reason.count;
          String formattedAmount = reason.amount! % 1 == 0 ? reason.amount!.toStringAsFixed(0) : reason.amount!.toStringAsFixed(2);
          String formattedTotal = total % 1 == 0 ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
          list.add(SuggestionReason("• ${reason.name}", "$currSymbol$formattedAmount x${reason.count} = $currSymbol$formattedTotal (${reason.frequency!.toLowerCase()})"));
        } else {
          String formattedAmount = reason.amount! % 1 == 0 ? reason.amount!.toStringAsFixed(0) : reason.amount!.toStringAsFixed(2);
          list.add(SuggestionReason("• ${reason.name}", "$currSymbol$formattedAmount (${reason.frequency!.toLowerCase()})"));
        }
      } else {
        list.add(SuggestionReason("• ${reason.name}", ""));
      }
    }
    return list;
  }
}

class _SimEvent {
  final DateTime date;
  final _OccurrenceRaw? occurrence;
  final _VirtualDeposit? deposit;
  final RecurringPaymentPartial? partial;
  _SimEvent({required this.date, this.occurrence, this.deposit, this.partial});
}
