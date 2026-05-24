import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseModule {
  static Future<Database> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = path.join(dir.path, 'soniox_transcriptor.db');
    final db = sqlite3.open(dbPath);

    db.execute('''
      CREATE TABLE IF NOT EXISTS transcriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        final_text TEXT NOT NULL,
        non_final_text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    return db;
  }
}
