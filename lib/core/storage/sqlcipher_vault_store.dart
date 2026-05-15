import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../security/secure_key_store.dart';
import 'vault_data.dart';
import 'vault_paths.dart';
import 'vault_store.dart';

class SqlCipherVaultStore implements VaultStore {
  SqlCipherVaultStore({
    VaultPaths? paths,
    SecureKeyStore? keyStore,
  })  : _paths = paths ?? const VaultPaths(),
        _keyStore = keyStore ?? SecureKeyStore();

  static const _vaultRowId = 'main';

  final VaultPaths _paths;
  final SecureKeyStore _keyStore;
  Database? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final appDirectory = await _paths.appDirectory();
    final key = base64Url.encode(await _keyStore.readOrCreateVaultKey());
    final database = await openDatabase(
      p.join(appDirectory.path, 'notes.db'),
      password: key,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vault (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL
          )
        ''');
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<VaultData> read() async {
    final database = await _open();
    final rows = await database.query(
      'vault',
      columns: const ['payload'],
      where: 'id = ?',
      whereArgs: const [_vaultRowId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const VaultData();
    }

    return VaultData.fromJson(
      Map<String, Object?>.from(
        jsonDecode(rows.single['payload'] as String) as Map,
      ),
    );
  }

  @override
  Future<void> write(VaultData data) async {
    final database = await _open();
    await database.insert(
      'vault',
      {
        'id': _vaultRowId,
        'payload': jsonEncode(data.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
