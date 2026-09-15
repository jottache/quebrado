import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';
import 'supabase_service.dart';
import 'supabase_config.dart';
/// Result object returned by backup import operations
class BackupImportResult {
  final bool success;
  final bool isCancelled;
  final String? errorMessage;
  final String activeProfileName;
  final String activeProfileId;
  final int profilesCount;
  final int transactionsCount;
  final int accountsCount;
  final int pocketsCount;
  final int categoriesCount;
  final int recurringCount;
  final int recipientsCount;
  final String? fileName;

  const BackupImportResult({
    required this.success,
    this.isCancelled = false,
    this.errorMessage,
    this.activeProfileName = 'Personal',
    this.activeProfileId = 'quebrado.db',
    this.profilesCount = 0,
    this.transactionsCount = 0,
    this.accountsCount = 0,
    this.pocketsCount = 0,
    this.categoriesCount = 0,
    this.recurringCount = 0,
    this.recipientsCount = 0,
    this.fileName,
  });

  factory BackupImportResult.cancelled() => const BackupImportResult(
        success: false,
        isCancelled: true,
      );

  factory BackupImportResult.failure(String error) => BackupImportResult(
        success: false,
        isCancelled: false,
        errorMessage: error,
      );
}

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
    'mobile_payment_recipients',
    'market_stores',
    'market_products',
    'market_trips',
    'market_items',
    'market_shopping_lists',
    'market_shopping_list_items'
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
  static Future<BackupImportResult> importBackup({VoidCallback? onUploadStart}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return BackupImportResult.cancelled();
    }

    onUploadStart?.call();

    final fileBytes = result.files.first.bytes;
    final fileName = result.files.first.name;
    String? jsonContent;

    if (fileBytes != null) {
      jsonContent = utf8.decode(fileBytes);
    } else if (result.files.first.path != null) {
      final file = File(result.files.first.path!);
      jsonContent = await file.readAsString();
    }

    if (jsonContent == null) {
      return BackupImportResult.failure("No se pudieron leer los datos del archivo seleccionado.");
    }

    return await importFromJsonString(jsonContent, fileName: fileName);
  }

  static Future<BackupImportResult> importFromJsonString(String jsonContent, {String? fileName}) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (e) {
      return BackupImportResult.failure("El archivo seleccionado no contiene un formato JSON válido: $e");
    }

    if (decoded is! Map) {
      return BackupImportResult.failure("El archivo seleccionado no contiene una estructura de datos válida.");
    }
    final backupMap = Map<String, dynamic>.from(decoded);

    final bool isMultiProfile = backupMap.containsKey('__multi_profile_backup__') &&
        backupMap['__multi_profile_backup__'] == true;

    if (isMultiProfile) {
      final profilesConfig = backupMap['profiles_config'];
      final databasesRaw = backupMap['databases'];
      if (profilesConfig is! Map || databasesRaw is! Map) {
        return BackupImportResult.failure(
          "El archivo de copia multi-perfil está corrupto o incompleto (faltan 'profiles_config' o 'databases')."
        );
      }

      final activeDbName = profilesConfig['active_profile']?.toString() ?? 'quebrado.db';
      final profilesListRaw = profilesConfig['profiles'];
      final List<Map<String, String>> profilesList = [];
      String activeProfileDisplayName = 'Personal';

      if (profilesListRaw is List) {
        for (var p in profilesListRaw) {
          if (p is Map) {
            final id = p['id']?.toString() ?? '';
            final name = p['name']?.toString() ?? 'Personal';
            if (id == activeDbName) {
              activeProfileDisplayName = name;
            }
            final map = <String, String>{
              'id': id,
              'name': name,
            };
            if (p['color'] != null) {
              map['color'] = p['color'].toString();
            }
            profilesList.add(map);
          }
        }
      }

      if (profilesList.isEmpty) {
        profilesList.add({'id': activeDbName, 'name': 'Personal'});
      }

      final Map<String, dynamic> databases = {};
      for (var k in databasesRaw.keys) {
        if (databasesRaw[k] is Map) {
          databases[k.toString()] = Map<String, dynamic>.from(databasesRaw[k] as Map);
        }
      }

      // 1. Sincronizar con Supabase si está disponible
      if (SupabaseConfig.isConfigured && SupabaseService.instance.isReady) {
        try {
          await SupabaseService.instance.importBackupData(backupMap, fileName: fileName);
        } catch (spErr) {
          debugPrint("Aviso: Error al sincronizar copia con Supabase: $spErr");
          if (kIsWeb) {
            return BackupImportResult.failure("Error al sincronizar con Supabase: $spErr");
          }
        }
      }

      // 2. Restaurar bases de datos SQLite en plataformas nativas
      if (!kIsWeb) {
        final dbHelper = DatabaseHelper.instance;

        // Guardar la configuración de perfiles y cambiar al perfil activo
        await dbHelper.saveProfiles(activeDbName, profilesList);
        await dbHelper.switchProfile(activeDbName);

        for (var entry in databases.entries) {
          final dbName = entry.key;
          final dbData = entry.value as Map<String, dynamic>;

          if (dbName == activeDbName) {
            final db = await dbHelper.database;
            await db.execute('PRAGMA foreign_keys = OFF');
            try {
              await db.transaction((txn) async {
                for (var tableName in _tables) {
                  try {
                    await txn.delete(tableName);
                  } catch (_) {}
                }
                for (var tableName in _tables) {
                  final rowsToInsert = dbData[tableName];
                  if (rowsToInsert is List) {
                    for (var row in rowsToInsert) {
                      if (row is Map) {
                        try {
                          await txn.insert(tableName, Map<String, dynamic>.from(row));
                        } catch (e) {
                          debugPrint("Error insertando en $tableName ($dbName): $e");
                        }
                      }
                    }
                  }
                }
              });
            } finally {
              await db.execute('PRAGMA foreign_keys = ON');
            }
          } else {
            await _restoreDatabase(dbName, dbData);
          }
        }

        // Resetear la conexión activa para que la próxima consulta abra el perfil activo restaurado
        await dbHelper.switchProfile(activeDbName);
      }

      final activeDbData = databases[activeDbName] ??
          (databases.isNotEmpty ? databases.values.first as Map<String, dynamic> : <String, dynamic>{});
      final int txCount = (activeDbData['transactions'] as List?)?.length ?? 0;
      final int accCount = (activeDbData['accounts'] as List?)?.length ?? 0;
      final int pocketCount = (activeDbData['pockets'] as List?)?.length ?? 0;
      final int catCount = (activeDbData['categories'] as List?)?.length ?? 0;
      final int recCount = (activeDbData['recurring_payments'] as List?)?.length ?? 0;
      final int recipCount = (activeDbData['mobile_payment_recipients'] as List?)?.length ?? 0;

      return BackupImportResult(
        success: true,
        fileName: fileName,
        activeProfileName: activeProfileDisplayName,
        activeProfileId: activeDbName,
        profilesCount: profilesList.length,
        transactionsCount: txCount,
        accountsCount: accCount,
        pocketsCount: pocketCount,
        categoriesCount: catCount,
        recurringCount: recCount,
        recipientsCount: recipCount,
      );
    }

    // Copia simple (single-profile legacy)
    final dbHelper = DatabaseHelper.instance;
    final activeDbName = await dbHelper.getActiveProfile();
    final profiles = await dbHelper.loadProfiles();
    final activeProf = profiles.firstWhere(
      (p) => p['id'] == activeDbName,
      orElse: () => {'id': activeDbName, 'name': 'Personal'},
    );
    final activeProfileDisplayName = activeProf['name'] ?? 'Personal';

    if (SupabaseConfig.isConfigured && SupabaseService.instance.isReady) {
      try {
        await SupabaseService.instance.importBackupData(backupMap, fileName: fileName);
      } catch (spErr) {
        debugPrint("Aviso: Error al sincronizar copia con Supabase: $spErr");
        if (kIsWeb) {
          return BackupImportResult.failure("Error al sincronizar con Supabase: $spErr");
        }
      }
    }

    if (!kIsWeb) {
      await dbHelper.switchProfile(activeDbName);
      final db = await dbHelper.database;
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction((txn) async {
          for (var tableName in _tables) {
            try {
              await txn.delete(tableName);
            } catch (_) {}
          }
          for (var tableName in _tables) {
            final rowsToInsert = backupMap[tableName];
            if (rowsToInsert is List) {
              for (var row in rowsToInsert) {
                if (row is Map) {
                  try {
                    await txn.insert(tableName, Map<String, dynamic>.from(row));
                  } catch (e) {
                    debugPrint("Error insertando en $tableName: $e");
                  }
                }
              }
            }
          }
        });
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }
      await dbHelper.switchProfile(activeDbName);
    }

    final int txCount = (backupMap['transactions'] as List?)?.length ?? 0;
    final int accCount = (backupMap['accounts'] as List?)?.length ?? 0;
    final int pocketCount = (backupMap['pockets'] as List?)?.length ?? 0;
    final int catCount = (backupMap['categories'] as List?)?.length ?? 0;
    final int recCount = (backupMap['recurring_payments'] as List?)?.length ?? 0;
    final int recipCount = (backupMap['mobile_payment_recipients'] as List?)?.length ?? 0;

    return BackupImportResult(
      success: true,
      fileName: fileName,
      activeProfileName: activeProfileDisplayName,
      activeProfileId: activeDbName,
      profilesCount: 1,
      transactionsCount: txCount,
      accountsCount: accCount,
      pocketsCount: pocketCount,
      categoriesCount: catCount,
      recurringCount: recCount,
      recipientsCount: recipCount,
    );
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

  static Future<void> _restoreDatabase(String profileId, Map<String, dynamic> decoded) async {
    final db = await DatabaseHelper.instance.initProfileDb(profileId);
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

