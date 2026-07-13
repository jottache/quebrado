import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class BackupService {
  static final List<String> _tables = [
    'settings',
    'categories',
    'accounts',
    'pockets',
    'transactions',
    'rate_history',
    'recurring_payments',
    'recurring_payment_confirmations',
    'recurring_payment_partials',
    'mobile_payment_recipients'
  ];

  static Future<void> exportBackup({Rect? sharePositionOrigin}) async {
    final dbHelper = DatabaseHelper.instance;
    final dbPath = await dbHelper.getDbPath();
    final activeProfile = await dbHelper.getActiveProfile();
    final profiles = await dbHelper.loadProfiles();

    final Map<String, dynamic> backupData = {
      '__multi_profile_backup__': true,
      'profiles_config': {
        'active_profile': activeProfile,
        'profiles': profiles,
      },
      'databases': {},
    };

    // Dump each profile's database
    for (var prof in profiles) {
      final dbName = prof['id'];
      if (dbName != null) {
        final targetPath = join(dbPath, dbName);
        if (await File(targetPath).exists()) {
          final dbData = await _dumpDatabase(targetPath);
          backupData['databases'][dbName] = dbData;
        }
      }
    }

    // Convert to JSON String
    final jsonString = jsonEncode(backupData);

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final fileName = "copia_seguridad_quebrado_${DateTime.now().millisecondsSinceEpoch}.json";
    final file = File("${tempDir.path}/$fileName");
    await file.writeAsString(jsonString);

    // Share the file
    final xFile = XFile(file.path, mimeType: "application/json");
    await Share.shareXFiles(
      [xFile],
      subject: "Copia de Seguridad Quebrado",
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Picks a JSON backup file and imports its content into database tables
  static Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return false; // User cancelled picking
    }

    final fileBytes = result.files.first.bytes;
    String? jsonContent;

    if (fileBytes != null) {
      jsonContent = utf8.decode(fileBytes);
    } else if (result.files.first.path != null) {
      final file = File(result.files.first.path!);
      jsonContent = await file.readAsString();
    }

    if (jsonContent == null) {
      throw Exception("No se pudieron leer los datos del archivo seleccionado.");
    }

    return await importFromJsonString(jsonContent);
  }

  static Future<bool> importFromJsonString(String jsonContent) async {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("El archivo seleccionado no tiene un formato válido.");
    }

    final dbHelper = DatabaseHelper.instance;

    // Check if it's a multi-profile backup
    if (decoded.containsKey('__multi_profile_backup__') && decoded['__multi_profile_backup__'] == true) {
      final profilesConfig = decoded['profiles_config'];
      final databases = decoded['databases'];
      if (profilesConfig is Map<String, dynamic> && databases is Map<String, dynamic>) {
        final dbPath = await dbHelper.getDbPath();
        
        final activeDbName = profilesConfig['active_profile'] as String? ?? 'quebrado.db';
        final profilesListRaw = profilesConfig['profiles'];
        final List<Map<String, String>> profilesList = [];
        if (profilesListRaw is List) {
          for (var p in profilesListRaw) {
            if (p is Map) {
              profilesList.add({
                'id': p['id']?.toString() ?? '',
                'name': p['name']?.toString() ?? '',
              });
            }
          }
        }
        await dbHelper.saveProfiles(activeDbName, profilesList);

        // Ensure we switch to the target active profile to make its DB connection open
        await dbHelper.switchProfile(activeDbName);

        for (var entry in databases.entries) {
          final dbName = entry.key;
          final dbData = entry.value;
          if (dbData is Map<String, dynamic>) {
            final targetPath = join(dbPath, dbName);
            if (dbName == activeDbName) {
              final db = await dbHelper.database;
              await db.execute('PRAGMA foreign_keys = OFF');
              try {
                await db.transaction((txn) async {
                  for (var tableName in _tables) {
                    try { await txn.delete(tableName); } catch (_) {}
                  }
                  for (var tableName in _tables) {
                    final rowsToInsert = dbData[tableName];
                    if (rowsToInsert is List) {
                      for (var row in rowsToInsert) {
                        if (row is Map<String, dynamic>) {
                          try { await txn.insert(tableName, row); } catch (_) {}
                        }
                      }
                    }
                  }
                });
              } finally {
                await db.execute('PRAGMA foreign_keys = ON');
              }
            } else {
              await _restoreDatabase(targetPath, dbData);
            }
          }
        }
        return true;
      }
    }

    // Validate that tables exist or at least it is a valid backup map structure (Legacy Fallback)
    for (var tableName in _tables) {
      if (!decoded.containsKey(tableName)) {
        // Allow backwards compatibility with older backups that do not contain partials or recipients
        if (tableName == 'recurring_payment_partials' || tableName == 'mobile_payment_recipients') {
          continue;
        }
        throw Exception("El archivo seleccionado no es válido. Falta la tabla: '$tableName'.");
      }
    }

    final db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        // Clear all existing data
        for (var tableName in _tables) {
          await txn.delete(tableName);
        }

        // Insert new data
        for (var tableName in _tables) {
          final rowsToInsert = decoded[tableName];
          if (rowsToInsert is List) {
            for (var row in rowsToInsert) {
              if (row is Map<String, dynamic>) {
                await txn.insert(tableName, row);
              }
            }
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    return true;
  }

  static Future<bool> importMockTestData() async {
    final tempDir = await getTemporaryDirectory();
    File file = File("${tempDir.path}/datos_prueba_quebrado.json");

    if (!await file.exists()) {
      if (tempDir.path.endsWith('/tmp')) {
        file = File("${tempDir.path.replaceAll('/tmp', '/Library/Caches')}/datos_prueba_quebrado.json");
      } else if (tempDir.path.endsWith('/Library/Caches')) {
        file = File("${tempDir.path.replaceAll('/Library/Caches', '/tmp')}/datos_prueba_quebrado.json");
      }
    }

    if (!await file.exists()) {
      throw Exception(
        "No se encontró el archivo 'datos_prueba_quebrado.json' en el dispositivo. "
        "Asegúrate de que esté en el directorio temporal o de caché del simulador."
      );
    }

    final jsonContent = await file.readAsString();
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("El archivo de prueba no tiene un formato válido.");
    }

    final db = await DatabaseHelper.instance.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        for (var tableName in _tables) {
          await txn.delete(tableName);
        }

        for (var tableName in _tables) {
          final rowsToInsert = decoded[tableName];
          if (rowsToInsert is List) {
            for (var row in rowsToInsert) {
              if (row is Map<String, dynamic>) {
                await txn.insert(tableName, row);
              }
            }
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    return true;
  }

  static Future<void> exportBackupFolder(String folderName, {Rect? sharePositionOrigin}) async {
    final dbHelper = DatabaseHelper.instance;
    final metadataPath = await dbHelper.getBackupMetadataPath();
    final dbPath = join(dirname(metadataPath), 'backups', folderName);
    
    // Find profiles config from the backup folder
    List<Map<String, String>> profiles = [{'id': 'quebrado.db', 'name': 'Personal'}];
    String activeProfile = 'quebrado.db';
    
    final profilesFile = File(join(dbPath, 'quebrado_profiles.json'));
    if (await profilesFile.exists()) {
      try {
        final content = await profilesFile.readAsString();
        final Map<String, dynamic> profilesData = jsonDecode(content);
        activeProfile = profilesData['active_profile'] as String? ?? 'quebrado.db';
        final profilesListRaw = profilesData['profiles'];
        if (profilesListRaw is List) {
          profiles = [];
          for (var p in profilesListRaw) {
            if (p is Map) {
              profiles.add({
                'id': p['id']?.toString() ?? '',
                'name': p['name']?.toString() ?? '',
              });
            }
          }
        }
      } catch (_) {}
    }
    
    final Map<String, dynamic> backupData = {
      '__multi_profile_backup__': true,
      'profiles_config': {
        'active_profile': activeProfile,
        'profiles': profiles,
      },
      'databases': {},
    };
    
    // Dump each profile's database from the backup folder
    for (var prof in profiles) {
      final dbName = prof['id'];
      if (dbName != null) {
        final targetPath = join(dbPath, dbName);
        if (await File(targetPath).exists()) {
          final dbData = await _dumpDatabase(targetPath);
          backupData['databases'][dbName] = dbData;
        }
      }
    }
    
    final jsonString = jsonEncode(backupData);
    
    final tempDir = await getTemporaryDirectory();
    final fileName = "copia_seguridad_quebrado_${folderName}_${DateTime.now().millisecondsSinceEpoch}.json";
    final file = File("${tempDir.path}/$fileName");
    await file.writeAsString(jsonString);
    
    final xFile = XFile(file.path, mimeType: "application/json");
    await Share.shareXFiles(
      [xFile],
      subject: "Copia de Seguridad Quebrado ($folderName)",
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _dumpDatabase(String path) async {
    final db = await openDatabase(path);
    final Map<String, List<Map<String, dynamic>>> backupData = {};
    try {
      for (var tableName in _tables) {
        try {
          final rows = await db.query(tableName);
          backupData[tableName] = rows;
        } catch (_) {}
      }
    } finally {
      await db.close();
    }
    return backupData;
  }

  static Future<void> _restoreDatabase(String path, Map<String, dynamic> decoded) async {
    final db = await openDatabase(path);
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        for (var tableName in _tables) {
          try {
            await txn.delete(tableName);
          } catch (_) {}
        }
        for (var tableName in _tables) {
          final rowsToInsert = decoded[tableName];
          if (rowsToInsert is List) {
            for (var row in rowsToInsert) {
              if (row is Map<String, dynamic>) {
                try {
                  await txn.insert(tableName, row);
                } catch (_) {}
              }
            }
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
      await db.close();
    }
  }
}

