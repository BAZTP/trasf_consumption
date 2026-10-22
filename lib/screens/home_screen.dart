import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:transf_consumption/database/database_helper.dart';
import 'package:transf_consumption/models/transaction_model.dart';
import 'package:transf_consumption/models/category_model.dart';
import 'package:transf_consumption/providers/transaction_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  Map<String, double> _categoryTotals = {};
  double _monthTotal = 0;
  double _todayTotal = 0;
  int _transactionCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final db = DatabaseHelper.instance;

    final categoryTotals = await db.getTotalByCategory(startOfMonth, endOfMonth);
    final monthTotal = await db.getMonthlyTotal(now.year, now.month);
    final todayTransactions = await db.getTransactions(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    double todaySum = 0;
    for (final t in todayTransactions) {
      todaySum += t.amount;
    }

    final allMonthTransactions = await db.getTransactions(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    if (mounted) {
      setState(() {
        _categoryTotals = categoryTotals;
        _monthTotal = monthTotal;
        _todayTotal = todaySum;
        _transactionCount = allMonthTransactions.length;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TransfConsumption',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboardData();
              Provider.of<TransactionProvider>(context, listen: false)
                  .loadTransactions();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final provider = context.read<TransactionProvider>();
                await _loadDashboardData();
                await provider.loadTransactions();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Resumen del mes
                  _buildMonthSummaryCard(theme),
                  const SizedBox(height: 16),

                  // Tarjetas rápidas
                  Row(
                    children: [
                      Expanded(child: _buildQuickCard(
                        theme,
                        'Hoy',
                        _currencyFormat.format(_todayTotal),
                        Icons.today,
                        Colors.orange,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickCard(
                        theme,
                        'Transacciones',
                        '$_transactionCount',
                        Icons.receipt_long,
                        Colors.blue,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickCard(
                        theme,
                        'Promedio',
                        _currencyFormat.format(
                          _transactionCount > 0
                              ? _monthTotal / DateTime.now().day
                              : 0,
                        ),
                        Icons.trending_up,
                        Colors.purple,
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Distribución por categoría
                  _buildCategoryBreakdown(theme),
                  const SizedBox(height: 24),

                  // Últimas transacciones
                  _buildRecentTransactions(theme),
                ],
              ),
            ),
      // FAB para agregar transacción manual
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  Widget _buildMonthSummaryCard(ThemeData theme) {
    final monthName = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total del mes',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              monthName.substring(0, 1).toUpperCase() + monthName.substring(1),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currencyFormat.format(_monthTotal),
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme) {
    if (_categoryTotals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin consumos este mes',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los consumos detectados aparecerán aquí',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final defaultCategories = CategoryModel.defaultCategories;
    final sortedEntries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por Categoría',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedEntries.map((entry) {
              final cat = defaultCategories.firstWhere(
                (c) => c.name == entry.key,
                orElse: () => defaultCategories.last,
              );
              final percentage = _monthTotal > 0
                  ? (entry.value / _monthTotal * 100)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cat.getColor().withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        cat.getIconData(),
                        color: cat.getColor(),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _currencyFormat.format(entry.value),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: cat.getColor().withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(cat.getColor()),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(ThemeData theme) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final transactions = provider.transactions.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Últimos Consumos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to transactions tab
                  },
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No hay consumos registrados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              )
            else
              ...transactions.map((t) => _buildTransactionTile(theme, t)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionTile(ThemeData theme, TransactionModel t) {
    final defaultCategories = CategoryModel.defaultCategories;
    final cat = defaultCategories.firstWhere(
      (c) => c.name == t.category,
      orElse: () => defaultCategories.last,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cat.getColor().withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(cat.getIconData(), color: cat.getColor(), size: 22),
        ),
        title: Text(
          t.merchant ?? t.category,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${t.category} • ${DateFormat('dd MMM, hh:mm a').format(t.date)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          _currencyFormat.format(t.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final amountController = TextEditingController();
    final merchantController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Agregar Consumo Manual',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Monto
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Comercio
                  TextField(
                    controller: merchantController,
                    decoration: InputDecoration(
                      labelText: 'Comercio (opcional)',
                      prefixIcon: const Icon(Icons.store),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nota
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Nota (opcional)',
                      prefixIcon: const Icon(Icons.note),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categorías
                  Text(
                    'Categoría',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryModel.defaultCategories.map((cat) {
                      final isSelected = selectedCategory == cat.name;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() => selectedCategory = cat.name);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cat.getColor().withValues(alpha: 0.2)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? cat.getColor()
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.getIconData(),
                                size: 18,
                                color: cat.getColor(),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? cat.getColor()
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Guardar
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedCategory == null
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountController.text);
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ingresa un monto válido'),
                                  ),
                                );
                                return;
                              }

                              final transaction = TransactionModel(
                                amount: amount,
                                merchant: merchantController.text.isEmpty
                                    ? null
                                    : merchantController.text,
                                category: selectedCategory!,
                                note: noteController.text.isEmpty
                                    ? null
                                    : noteController.text,
                                date: DateTime.now(),
                                createdAt: DateTime.now(),
                              );

                              await DatabaseHelper.instance
                                  .insertTransaction(transaction);

                              if (ctx.mounted) {
                                Provider.of<TransactionProvider>(
                                  ctx,
                                  listen: false,
                                ).loadTransactions();

                                Navigator.pop(ctx);
                                _loadDashboardData();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Consumo de ${_currencyFormat.format(amount)} registrado',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Consumo'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
