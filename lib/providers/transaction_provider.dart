import 'package:flutter/material.dart';
import 'package:transf_consumption/database/database_helper.dart';
import 'package:transf_consumption/models/transaction_model.dart';

/// Provider para manejar el estado global de transacciones
class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  /// Carga todas las transacciones desde la base de datos
  Future<void> loadTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await DatabaseHelper.instance.getTransactions(
        startDate: startDate,
        endDate: endDate,
        category: category,
      );
    } catch (e) {
      debugPrint('Error al cargar transacciones: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Agrega una transacción y refresca la lista
  Future<void> addTransaction(TransactionModel transaction) async {
    await DatabaseHelper.instance.insertTransaction(transaction);
    await loadTransactions();
  }

  /// Actualiza una transacción existente
  Future<void> updateTransaction(TransactionModel transaction) async {
    await DatabaseHelper.instance.updateTransaction(transaction);
    await loadTransactions();
  }

  /// Elimina una transacción por ID
  Future<void> deleteTransaction(int id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await loadTransactions();
  }

  /// Obtiene el total del mes actual
  Future<double> getCurrentMonthTotal() async {
    final now = DateTime.now();
    return await DatabaseHelper.instance.getMonthlyTotal(now.year, now.month);
  }

  /// Obtiene totales por categoría del mes actual
  Future<Map<String, double>> getCurrentMonthCategoryTotals() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return await DatabaseHelper.instance.getTotalByCategory(start, end);
  }
}
