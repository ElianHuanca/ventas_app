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
        precxcompra REAL NOT NULL DEFAULT 0,
        idusuarios INTEGER NOT NULL DEFAULT 1
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
          precxcompra REAL NOT NULL DEFAULT 0,
          idusuarios INTEGER NOT NULL DEFAULT 1
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
