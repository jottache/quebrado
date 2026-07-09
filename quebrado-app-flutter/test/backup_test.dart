import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quebrado_app_flutter/services/db_helper.dart';

void main() {
  group('DatabaseHelper Backup Management System Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      // Clean up any existing test files before running
      final meta = File('quebrado_backup_metadata.json');
      if (await meta.exists()) await meta.delete();
      final profiles = File('quebrado_profiles.json');
      if (await profiles.exists()) await profiles.delete();
      final backupsDir = Directory('backups');
      if (await backupsDir.exists()) await backupsDir.delete(recursive: true);
    });

    tearDown(() async {
      // Clean up files after test run
      final meta = File('quebrado_backup_metadata.json');
      if (await meta.exists()) await meta.delete();
      final profiles = File('quebrado_profiles.json');
      if (await profiles.exists()) await profiles.delete();
      final backupsDir = Directory('backups');
      if (await backupsDir.exists()) await backupsDir.delete(recursive: true);
    });

    test('loadBackupMetadata initializes default PIN and values if missing', () async {
      final metadata = await dbHelper.loadBackupMetadata();
      expect(metadata['security_pin'], equals(''));
      expect(metadata['last_auto_backup_date'], equals(''));
      expect(metadata['restore_history'], isEmpty);

      final file = File('quebrado_backup_metadata.json');
      expect(await file.exists(), isTrue);
    });

    test('saveBackupMetadata and loadBackupMetadata correctly preserves new values', () async {
      final metadata = await dbHelper.loadBackupMetadata();
      metadata['security_pin'] = '4321';
      metadata['last_auto_backup_date'] = '2026-07-02';
      await dbHelper.saveBackupMetadata(metadata);

      final updated = await dbHelper.loadBackupMetadata();
      expect(updated['security_pin'], equals('4321'));
      expect(updated['last_auto_backup_date'], equals('2026-07-02'));
    });

    test('performManualBackup and listBackups works correctly', () async {
      // Create a dummy quebrado_profiles.json to simulate backup
      final profilesFile = File('quebrado_profiles.json');
      await profilesFile.writeAsString('{"active_profile": "quebrado.db", "profiles": []}');

      final backupFolder = await dbHelper.performManualBackup();
      expect(backupFolder, startsWith('manual_backup_'));

      // Verify directory exists
      final backupDir = Directory(p.join('backups', backupFolder));
      expect(await backupDir.exists(), isTrue);
      
      // Verify files inside
      final copiedProfiles = File(p.join(backupDir.path, 'quebrado_profiles.json'));
      expect(await copiedProfiles.exists(), isTrue);

      // List backups
      final list = await dbHelper.listBackups();
      expect(list, isNotEmpty);
      expect(list.first['name'], equals(backupFolder));
      expect(list.first['is_auto'], isFalse);
    });

    test('deleteBackup removes the physical backup directory', () async {
      final profilesFile = File('quebrado_profiles.json');
      await profilesFile.writeAsString('{"active_profile": "quebrado.db", "profiles": []}');

      final backupFolder = await dbHelper.performManualBackup();
      final backupDir = Directory(p.join('backups', backupFolder));
      expect(await backupDir.exists(), isTrue);

      await dbHelper.deleteBackup(backupFolder);
      expect(await backupDir.exists(), isFalse);

      final list = await dbHelper.listBackups();
      expect(list, isEmpty);
    });

    test('restoreBackup overwrites existing databases and logs success in metadata history', () async {
      // 1. Create a dummy metadata and profile file
      final profilesFile = File('quebrado_profiles.json');
      await profilesFile.writeAsString('{"active_profile": "quebrado.db", "profiles": []}');

      // 2. Perform backup
      final backupFolder = await dbHelper.performManualBackup();

      // 3. Mutate main profiles file
      await profilesFile.writeAsString('{"active_profile": "restored.db", "profiles": []}');

      // 4. Perform restore
      final success = await dbHelper.restoreBackup(backupFolder);
      expect(success, isTrue);

      // 5. Verify profiles file contents have been restored to original backup state
      final content = await profilesFile.readAsString();
      expect(content, contains('quebrado.db'));
      expect(content, isNot(contains('restored.db')));

      // 6. Verify traceability log in metadata
      final metadata = await dbHelper.loadBackupMetadata();
      final history = metadata['restore_history'] as List;
      expect(history, isNotEmpty);
      expect(history.first['backup_name'], equals(backupFolder));
      expect(history.first['success'], isTrue);
    });
  });
}
