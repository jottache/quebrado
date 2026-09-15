import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/quebrado/services/backup_service.dart';
import 'package:quebrado_app_flutter/quebrado/services/db_helper.dart';
import 'package:quebrado_app_flutter/quebrado/viewmodels/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Backup Import & Reload Verification', () {
    test('Import user backup JSON and verify BackupImportResult metrics and AppState in-memory reload', () async {
      final db = await DatabaseHelper.instance.database;
      // Wipe all transactions and insert 1 dummy
      await db.delete('transactions');
      await db.insert('transactions', {
        'id': 'dummy-1',
        'note': 'Test dummy',
        'amount': 10.0,
        'currency': 'usd',
        'exchange_rate': 1.0,
        'date': DateTime.now().toIso8601String(),
        'type': 'expense',
      });

      final appState = AppState();
      await appState.loadData(forceReload: true);
      expect(appState.transactions.length, equals(1));

      // Read real user backup file
      final file = File('/Users/jottache/Downloads/copia_seguridad_quebrado_manual_backup_20260914_224438_1789440281854.json');
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();

      // Test importFromJsonString returning rich BackupImportResult
      final result = await BackupService.importFromJsonString(
        content,
        fileName: 'copia_seguridad_quebrado_manual_backup_20260914_224438_1789440281854.json',
      );

      expect(result.success, isTrue);
      expect(result.activeProfileName, equals('Personal'));
      expect(result.profilesCount, equals(4));
      expect(result.transactionsCount, equals(172));
      expect(result.accountsCount, equals(3));
      expect(result.pocketsCount, equals(4));
      expect(result.categoriesCount, equals(13));

      // Reload appState with forceReload (as implemented in importBackupFromFile and restoreBackup)
      await appState.loadData(forceReload: true);

      // Verify in-memory state has updated to the imported backup data
      expect(appState.transactions.length, equals(172));
      expect(appState.accounts.length, equals(3));
      expect(appState.pockets.length, equals(4));
      expect(appState.categories.length, equals(13));
    });

    test('Import corrupted JSON string returns informative failure', () async {
      final result = await BackupService.importFromJsonString('{"invalid_json": true');
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('no contiene un formato JSON válido'));
    });

    test('Import non-map JSON string returns informative failure', () async {
      final result = await BackupService.importFromJsonString('[1, 2, 3]');
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('no contiene una estructura de datos válida'));
    });
  });
}
