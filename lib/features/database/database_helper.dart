import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = await getDatabasesPath();
    const dbName = 'textiles_app.db';
    final dbPath = join(path, dbName);

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sucursales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE telas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        precxmen REAL NOT NULL DEFAULT 0,
        precxmay REAL NOT NULL DEFAULT 0,
        precxrollo REAL NOT NULL DEFAULT 0,
        precxcompra REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ventas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        ganancias REAL NOT NULL DEFAULT 0,
        descuento REAL NOT NULL DEFAULT 0,
        idsucursales INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE detalle_ventas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        precio REAL NOT NULL,
        cantidad REAL NOT NULL,
        total REAL,
        ganancias REAL,
        idtelas INTEGER NOT NULL,
        idventa INTEGER NOT NULL,
        FOREIGN KEY (idventa) REFERENCES ventas(id)
      )
    ''');

    await _seedTelasIfEmpty(db);
  }

  /// Inserta los productos iniciales (telas) solo si la tabla está vacía.
  Future<void> _seedTelasIfEmpty(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM telas');
    final count = (result.isNotEmpty ? result.first['c'] as int? : null) ?? 0;
    if (count > 0) return;

    const inserts = [
      ['Razo Suizo Licra', 30.0, 25.0, 23.0, 20.0],
      ['Razo Suizo Rigido', 25.0, 20.0, 18.0, 15.0],
      ['Lipiur 3D', 160.0, 130.0, 110.0, 100.0],
      ['Mostazilla', 180.0, 150.0, 140.0, 110.0],
      ['Lipiur', 130.0, 100.0, 85.0, 70.0],
      ['Razo Doble Ancho', 20.0, 15.0, 14.0, 11.0],
      ['Razo', 10.0, 8.0, 6.0, 5.5],
      ['Tull Ramas', 65.0, 55.0, 50.0, 40.0],
      ['Blonda 15', 15.0, 12.0, 10.0, 8.0],
      ['Blonda 20', 20.0, 15.0, 12.0, 10.0],
      ['Blonda 50', 50.0, 45.0, 43.0, 35.0],
      ['Tull Ilusion', 10.0, 8.0, 6.0, 5.5],
      ['Tull Licra', 20.0, 16.0, 15.0, 8.0],
      ['Tull Frances', 25.0, 20.0, 18.0, 16.0],
      ['Can Can', 20.0, 17.0, 14.0, 12.0],
      ['Tull Maripozas LPZ', 65.0, 50.0, 45.0, 40.0],
      ['Tull Americano', 20.0, 17.0, 15.0, 11.5],
      ['lipiur AG', 130.0, 100.0, 85.0, 62.0],
      ['Tull Perlado', 100.0, 80.0, 70.0, 46.0],
      ['Bonye', 10.0, 8.0, 6.0, 5.5],
      ['Tull Brilloso', 23.0, 18.0, 15.0, 12.0],
      ['Lipiur IH', 130.0, 100.0, 85.0, 57.0],
      ['Lipiur Blonda', 60.0, 50.0, 45.0, 40.0],
      ['gasa', 15.0, 12.0, 10.0, 9.0],
      ['Tull Ramas Ramada', 65.0, 55.0, 50.0, 40.0],
    ];

    await db.transaction((txn) async {
      for (final row in inserts) {
        await txn.insert('telas', {
          'nombre': row[0],
          'precxmen': row[1],
          'precxmay': row[2],
          'precxrollo': row[3],
          'precxcompra': row[4],
        });
      }
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS telas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          precxmen REAL NOT NULL DEFAULT 0,
          precxmay REAL NOT NULL DEFAULT 0,
          precxrollo REAL NOT NULL DEFAULT 0,
          precxcompra REAL NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ventas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha TEXT NOT NULL,
          total REAL NOT NULL DEFAULT 0,
          ganancias REAL NOT NULL DEFAULT 0,
          descuento REAL NOT NULL DEFAULT 0,
          idsucursales INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS detalle_ventas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT,
          precio REAL NOT NULL,
          cantidad REAL NOT NULL,
          total REAL,
          ganancias REAL,
          idtelas INTEGER NOT NULL,
          idventa INTEGER NOT NULL
        )
      ''');
    }
  }
}
