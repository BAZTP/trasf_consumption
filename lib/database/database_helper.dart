import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:transf_consumption/models/transaction_model.dart';
import 'package:transf_consumption/models/category_model.dart';

/// Helper para gestionar la base de datos SQLite de la aplicación.
///
/// Implementa el patrón Singleton para garantizar una única instancia
/// de conexión a la base de datos durante toda la vida de la aplicación.
class DatabaseHelper {
  /// Nombre del archivo de base de datos.
  static const String _databaseName = 'transf_consumption.db';

  /// Versión actual del esquema de la base de datos.
  static const int _databaseVersion = 1;

  /// Nombres de las tablas.
  static const String tableTransactions = 'transactions';
  static const String tableCategories = 'categories';

  /// Instancia única del helper (Singleton).
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  /// Instancia de la base de datos (inicializada de forma perezosa).
  static Database? _database;

  /// Constructor privado para el patrón Singleton.
  DatabaseHelper._internal();

  /// Acceso a la instancia única del helper.
  static DatabaseHelper get instance => _instance;

  factory DatabaseHelper() => _instance;

  /// Obtiene la instancia de la base de datos, inicializándola si es necesario.
  Future<Database> get database async {
    _database ??= await initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos y crea las tablas necesarias.
  ///
  /// Retorna la instancia de [Database] lista para usar.
  Future<Database> initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );

    // Sembrar categorías predeterminadas si es la primera ejecución
    await seedDefaultCategories();

    return _database!;
  }

  /// Crea las tablas del esquema en la primera ejecución.
  Future<void> _onCreate(Database db, int version) async {
    // Tabla de categorías
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabla de transacciones
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        merchant TEXT,
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        raw_notification TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Índices para mejorar el rendimiento de consultas frecuentes
    await db.execute('''
      CREATE INDEX idx_transactions_date ON $tableTransactions (date)
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_category ON $tableTransactions (category)
    ''');
  }

  // ---------------------------------------------------------------------------
  // Operaciones CRUD de Transacciones
  // ---------------------------------------------------------------------------

  /// Inserta una nueva transacción en la base de datos.
  ///
  /// Retorna el [id] asignado por SQLite a la transacción insertada.
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert(
      tableTransactions,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene una lista de transacciones con filtros opcionales.
  ///
  /// - [startDate]: fecha inicial del rango (inclusiva).
  /// - [endDate]: fecha final del rango (inclusiva).
  /// - [category]: filtra por nombre de categoría.
  ///
  /// Los resultados se ordenan por fecha descendente (más recientes primero).
  Future<List<TransactionModel>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    final db = await database;

    final where = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      where.add('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.add('date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }

    final result = await db.query(
      tableTransactions,
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC',
    );

    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Actualiza una transacción existente en la base de datos.
  ///
  /// Retorna el número de filas afectadas (debería ser 1).
  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Elimina una transacción por su [id].
  ///
  /// Retorna el número de filas eliminadas (debería ser 1).
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Operaciones CRUD de Categorías
  // ---------------------------------------------------------------------------

  /// Inserta una nueva categoría en la base de datos.
  ///
  /// Retorna el [id] asignado por SQLite a la categoría insertada.
  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert(
      tableCategories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene todas las categorías ordenadas por nombre.
  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final result = await db.query(
      tableCategories,
      orderBy: 'name ASC',
    );
    return result.map((map) => CategoryModel.fromMap(map)).toList();
  }

  /// Elimina una categoría por su [id].
  ///
  /// Retorna el número de filas eliminadas (debería ser 1).
  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Inserta las categorías predeterminadas si la tabla está vacía.
  ///
  /// Se llama durante la inicialización de la aplicación para garantizar
  /// que siempre existan categorías disponibles para el usuario.
  Future<void> seedDefaultCategories() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableCategories'),
    );

    if (count == 0) {
      final batch = db.batch();
      for (final category in CategoryModel.defaultCategories) {
        batch.insert(tableCategories, category.toMap());
      }
      await batch.commit(noResult: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Consultas de Reportes y Estadísticas
  // ---------------------------------------------------------------------------

  /// Calcula el total gastado por categoría en un rango de fechas.
  ///
  /// Retorna un [Map] donde la clave es el nombre de la categoría
  /// y el valor es la suma total de sus transacciones.
  Future<Map<String, double>> getTotalByCategory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total
      FROM $tableTransactions
      WHERE date >= ? AND date <= ?
      GROUP BY category
      ORDER BY total DESC
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final totals = <String, double>{};
    for (final row in result) {
      totals[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return totals;
  }

  /// Calcula el total gastado por día en un rango de fechas.
  ///
  /// Retorna un [Map] donde la clave es la fecha en formato "YYYY-MM-DD"
  /// y el valor es la suma total de transacciones de ese día.
  Future<Map<String, double>> getTotalByDay(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT SUBSTR(date, 1, 10) as day, SUM(amount) as total
      FROM $tableTransactions
      WHERE date >= ? AND date <= ?
      GROUP BY day
      ORDER BY day ASC
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final totals = <String, double>{};
    for (final row in result) {
      totals[row['day'] as String] = (row['total'] as num).toDouble();
    }
    return totals;
  }

  /// Calcula el total gastado en un mes y año específicos.
  ///
  /// Retorna el monto total como [double], o 0.0 si no hay transacciones.
  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await database;

    // Construir rango del mes: desde el primer día hasta el último
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM $tableTransactions
      WHERE date >= ? AND date <= ?
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  /// Obtiene los comercios con mayor gasto en un rango de fechas.
  ///
  /// - [limit]: cantidad máxima de comercios a retornar.
  /// - [startDate]: fecha inicial del rango (inclusiva).
  /// - [endDate]: fecha final del rango (inclusiva).
  ///
  /// Retorna una lista de mapas con las claves 'merchant', 'total' y 'count'.
  Future<List<Map<String, dynamic>>> getTopMerchants(
    int limit,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT merchant, SUM(amount) as total, COUNT(*) as count
      FROM $tableTransactions
      WHERE date >= ? AND date <= ? AND merchant IS NOT NULL AND merchant != ''
      GROUP BY merchant
      ORDER BY total DESC
      LIMIT ?
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String(), limit],
    );

    return result
        .map((row) => {
              'merchant': row['merchant'] as String,
              'total': (row['total'] as num).toDouble(),
              'count': row['count'] as int,
            })
        .toList();
  }

  /// Cierra la conexión a la base de datos.
  ///
  /// Útil para pruebas o cuando la aplicación se cierra de forma controlada.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
