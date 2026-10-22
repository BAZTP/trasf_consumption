/// Modelo de transacción para registrar consumos y gastos.
///
/// Representa una transacción individual con información sobre
/// el monto, comercio, categoría, nota y fecha.
class TransactionModel {
  /// Identificador único de la transacción (nulo si aún no se ha guardado).
  final int? id;

  /// Monto de la transacción.
  final double amount;

  /// Nombre del comercio o establecimiento (opcional).
  final String? merchant;

  /// Categoría de la transacción (ej: "Comida", "Transporte").
  final String category;

  /// Nota adicional o descripción (opcional).
  final String? note;

  /// Fecha en que ocurrió la transacción.
  final DateTime date;

  /// Texto original de la notificación que generó esta transacción (opcional).
  final String? rawNotification;

  /// Fecha y hora en que se creó el registro.
  final DateTime createdAt;

  /// Constructor principal con parámetros requeridos y opcionales.
  const TransactionModel({
    this.id,
    required this.amount,
    this.merchant,
    required this.category,
    this.note,
    required this.date,
    this.rawNotification,
    required this.createdAt,
  });

  /// Convierte el modelo a un mapa para inserción en la base de datos.
  ///
  /// El campo [id] se omite si es nulo para permitir autoincremento en SQLite.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'raw_notification': rawNotification,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Crea una instancia de [TransactionModel] a partir de un mapa de la base de datos.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String?,
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      rawNotification: map['raw_notification'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Crea una copia del modelo con los campos especificados modificados.
  TransactionModel copyWith({
    int? id,
    double? amount,
    String? merchant,
    String? category,
    String? note,
    DateTime? date,
    String? rawNotification,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      rawNotification: rawNotification ?? this.rawNotification,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, amount: $amount, merchant: $merchant, '
        'category: $category, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel &&
        other.id == id &&
        other.amount == amount &&
        other.merchant == merchant &&
        other.category == category &&
        other.note == note &&
        other.date == date &&
        other.rawNotification == rawNotification &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      amount,
      merchant,
      category,
      note,
      date,
      rawNotification,
      createdAt,
    );
  }
}
