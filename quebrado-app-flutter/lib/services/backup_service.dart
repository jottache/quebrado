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
  static const List<String> _tables = [
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
    final db = await DatabaseHelper.instance.database;
    final Map<String, List<Map<String, dynamic>>> backupData = {};

    for (var tableName in _tables) {
      final rows = await db.query(tableName);
      backupData[tableName] = rows;
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

    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("El archivo seleccionado no tiene un formato válido.");
    }

    // Validate that tables exist or at least it is a valid backup map structure
    for (var tableName in _tables) {
      if (!decoded.containsKey(tableName)) {
        // Allow backwards compatibility with older backups that do not contain partials or recipients
        if (tableName == 'recurring_payment_partials' || tableName == 'mobile_payment_recipients') {
          continue;
        }
        throw Exception("El archivo seleccionado no es válido. Falta la tabla: '$tableName'.");
      }
    }

    final db = await DatabaseHelper.instance.database;
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
        file = File(tempDir.path.replaceAll('/tmp', '/Library/Caches') + "/datos_prueba_quebrado.json");
      } else if (tempDir.path.endsWith('/Library/Caches')) {
        file = File(tempDir.path.replaceAll('/Library/Caches', '/tmp') + "/datos_prueba_quebrado.json");
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
    
    // Find active profile DB name
    String dbName = 'quebrado.db';
    final profilesFile = File(join(dbPath, 'quebrado_profiles.json'));
    if (await profilesFile.exists()) {
      try {
        final content = await profilesFile.readAsString();
        final Map<String, dynamic> profilesData = jsonDecode(content);
        dbName = profilesData['active_profile'] as String? ?? 'quebrado.db';
      } catch (_) {}
    }
    
    final dbFile = File(join(dbPath, dbName));
    if (!await dbFile.exists()) {
      throw Exception("No se encontró el archivo de base de datos para esta copia.");
    }
    
    final db = await openDatabase(dbFile.path);
    final Map<String, List<Map<String, dynamic>>> backupData = {};
    
    try {
      for (var tableName in _tables) {
        try {
          final rows = await db.query(tableName);
          backupData[tableName] = rows;
        } catch (_) {
          // If a table doesn't exist in the backed up database, we skip it
        }
      }
    } finally {
      await db.close();
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
}
