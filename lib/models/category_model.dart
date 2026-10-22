import 'package:flutter/material.dart';

/// Modelo de categoría para clasificar transacciones.
///
/// Cada categoría tiene un nombre, icono, color y puede ser
/// una categoría predeterminada del sistema o personalizada por el usuario.
class CategoryModel {
  /// Identificador único de la categoría (nulo si aún no se ha guardado).
  final int? id;

  /// Nombre de la categoría (ej: "Comida", "Transporte").
  final String name;

  /// Código del icono almacenado como cadena hexadecimal del code point.
  final String icon;

  /// Color de la categoría en formato hexadecimal (ej: "#4CAF50").
  final String color;

  /// Indica si es una categoría predeterminada del sistema.
  final bool isDefault;

  /// Constructor principal con parámetros requeridos y opcionales.
  const CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  /// Convierte el modelo a un mapa para inserción en la base de datos.
  ///
  /// El campo [id] se omite si es nulo para permitir autoincremento en SQLite.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'icon': icon,
      'color': color,
      'is_default': isDefault ? 1 : 0,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Crea una instancia de [CategoryModel] a partir de un mapa de la base de datos.
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      isDefault: (map['is_default'] as int) == 1,
    );
  }

  /// Obtiene el [IconData] correspondiente al code point hexadecimal almacenado.
  ///
  /// Utiliza la fuente MaterialIcons para renderizar el icono.
  IconData getIconData() {
    switch (name.toLowerCase()) {
      case 'transporte':
        return Icons.directions_car;
      case 'comida':
        return Icons.restaurant;
      case 'compras':
        return Icons.shopping_cart;
      case 'hogar':
        return Icons.home;
      case 'salud':
        return Icons.local_hospital;
      case 'entretenimiento':
        return Icons.sports_esports;
      case 'educación':
      case 'educacion':
        return Icons.school;
      case 'servicios':
        return Icons.receipt_long;
      default:
        return Icons.more_horiz;
    }
  }

  /// Obtiene el [Color] correspondiente a la cadena hexadecimal almacenada.
  ///
  /// Convierte el formato "#RRGGBB" a un objeto [Color] con opacidad completa.
  Color getColor() {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Crea una copia del modelo con los campos especificados modificados.
  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Lista de categorías predeterminadas del sistema.
  ///
  /// Se utilizan para poblar la base de datos en la primera ejecución.
  static List<CategoryModel> get defaultCategories => [
        CategoryModel(
          name: 'Transporte',
          icon: Icons.directions_car.codePoint.toRadixString(16),
          color: '#4CAF50',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Comida',
          icon: Icons.restaurant.codePoint.toRadixString(16),
          color: '#FF9800',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Compras',
          icon: Icons.shopping_cart.codePoint.toRadixString(16),
          color: '#2196F3',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Hogar',
          icon: Icons.home.codePoint.toRadixString(16),
          color: '#9C27B0',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Salud',
          icon: Icons.local_hospital.codePoint.toRadixString(16),
          color: '#F44336',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Entretenimiento',
          icon: Icons.sports_esports.codePoint.toRadixString(16),
          color: '#E91E63',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Educación',
          icon: Icons.school.codePoint.toRadixString(16),
          color: '#00BCD4',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Servicios',
          icon: Icons.receipt_long.codePoint.toRadixString(16),
          color: '#795548',
          isDefault: true,
        ),
        CategoryModel(
          name: 'Otros',
          icon: Icons.more_horiz.codePoint.toRadixString(16),
          color: '#607D8B',
          isDefault: true,
        ),
      ];

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.color == color &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, icon, color, isDefault);
  }
}
