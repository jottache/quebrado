import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';

void main() {
  group('Multi-Book Accounting Profile Management Tests', () {
    late AppState appState;

    setUp(() async {
      appState = AppState();
      await appState.loadData();

      // Reset to default active book
      if (appState.activeDbName != 'quebrado.db') {
        await appState.switchProfile('quebrado.db');
      }

      // Delete any test books created in previous test runs
      final profilesToDelete = appState.profiles
          .where((p) => p['id'] != 'quebrado.db')
          .toList();
      for (var p in profilesToDelete) {
        await appState.deleteProfile(p['id']!);
      }
    });

    test('Loads default Personal book on startup', () async {
      expect(appState.profiles.length, 1);
      expect(appState.profiles.first['id'], 'quebrado.db');
      expect(appState.profiles.first['name'], 'Personal');
      expect(appState.activeDbName, 'quebrado.db');
    });

    test('Creates new book and switches to it', () async {
      // 1. Create and switch to new book 'Business'
      await appState.createProfile('Business', '#1F6F5F');

      expect(appState.profiles.length, 2);
      expect(appState.activeProfileName, 'Business');
      expect(appState.activeDbName.startsWith('quebrado_'), true);

      // 2. Switch back to Personal book
      await appState.switchProfile('quebrado.db');
      expect(appState.activeProfileName, 'Personal');
    });

    test('Can rename a custom book', () async {
      await appState.createProfile('Travel', '#1F6F5F');
      final newBookId = appState.activeDbName;

      await appState.updateProfile(newBookId, 'Business Trip', '#2FA084');
      expect(appState.activeProfileName, 'Business Trip');

      await appState.switchProfile('quebrado.db');
      expect(appState.profiles.any((p) => p['name'] == 'Business Trip'), true);
    });

    test('Deleting custom book falls back to Personal', () async {
      await appState.createProfile('Temp Book', '#1F6F5F');
      final tempId = appState.activeDbName;

      expect(appState.activeDbName, tempId);

      // Delete active custom book
      await appState.deleteProfile(tempId);

      expect(appState.activeDbName, 'quebrado.db');
      expect(appState.activeProfileName, 'Personal');
      expect(appState.profiles.any((p) => p['id'] == tempId), false);
    });
  });
}
