import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:transf_consumption/database/database_helper.dart';
import 'package:transf_consumption/models/transaction_model.dart';
import 'package:transf_consumption/models/category_model.dart';
import 'package:transf_consumption/providers/transaction_provider.dart';
import 'package:transf_consumption/services/notification_service.dart';

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
  bool _isPermissionGranted = false;

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

    final permission = await NotificationService.isPermissionGranted();

    if (mounted) {
      setState(() {
        _categoryTotals = categoryTotals;
        _monthTotal = monthTotal;
        _todayTotal = todaySum;
        _transactionCount = allMonthTransactions.length;
        _isPermissionGranted = permission;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDemoData() async {
    final now = DateTime.now();
    final demos = [
      TransactionModel(
        amount: 5.50,
        merchant: 'Uber / Transporte',
        category: 'Transporte',
        note: 'Viaje al trabajo',
        date: now.subtract(const Duration(hours: 3)),
        createdAt: now,
      ),
      TransactionModel(
        amount: 14.25,
        merchant: 'Almuerzo Ejecutivo',
        category: 'Comida',
        note: 'Restaurante El Jardín',
        date: now.subtract(const Duration(hours: 6)),
        createdAt: now,
      ),
      TransactionModel(
        amount: 38.90,
        merchant: 'Supermaxi',
        category: 'Compras',
        note: 'Viveres de la semana',
        date: now.subtract(const Duration(days: 1)),
        createdAt: now,
      ),
      TransactionModel(
        amount: 12.00,
        merchant: 'Farmacias Fybeca',
        category: 'Salud',
        note: 'Medicinas',
        date: now.subtract(const Duration(days: 2)),
        createdAt: now,
      ),
    ];

    for (final t in demos) {
      await DatabaseHelper.instance.insertTransaction(t);
    }

    if (mounted) {
      context.read<TransactionProvider>().loadTransactions();
    }
    await _loadDashboardData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Se cargaron 4 consumos de ejemplo para probar la app.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'TransfConsumption',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboardData();
              context.read<TransactionProvider>().loadTransactions();
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
                  // 1. Estado del servicio de notificaciones
                  _buildServiceStatusBanner(theme),
                  const SizedBox(height: 16),

                  // 2. Tarjeta Resumen del mes
                  _buildMonthSummaryCard(theme),
                  const SizedBox(height: 16),

                  // 3. Métricas rápidas (Hoy, Transacciones, Promedio)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickCard(
                          theme,
                          'Hoy',
                          _currencyFormat.format(_todayTotal),
                          Icons.today,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickCard(
                          theme,
                          'Registros',
                          '$_transactionCount',
                          Icons.receipt_long,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickCard(
                          theme,
                          'Promedio',
                          _currencyFormat.format(
                            _transactionCount > 0
                                ? _monthTotal / DateTime.now().day
                                : 0,
                          ),
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Registro Rápido de Categorías
                  _buildQuickExpenseBar(theme),
                  const SizedBox(height: 24),

                  // 5. Si está vacío, mostrar Guía / Tutorial y botón de simulación
                  if (_transactionCount == 0) ...[
                    _buildEmptyStateGuide(theme),
                    const SizedBox(height: 24),
                  ] else ...[
                    // Distribución por categoría
                    _buildCategoryBreakdown(theme),
                    const SizedBox(height: 24),

                    // Últimas transacciones
                    _buildRecentTransactions(theme),
                  ],
                ],
              ),
            ),
      // FAB para agregar transacción manual
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Gasto'),
      ),
    );
  }

  /// Banner que indica si el permiso de notificaciones está activo o si requiere configuración
  Widget _buildServiceStatusBanner(ThemeData theme) {
    if (_isPermissionGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detección Automática Activa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Listo para capturar transferencias y consumos bancarios',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.orange, size: 20),
              tooltip: 'Simular transferencia',
              onPressed: () {
                NotificationService.simulateTransaction(
                  amount: 5.50,
                  merchant: 'Supermaxi',
                  type: 'Transferencia enviada',
                  rawText: 'Transferencia exitosa de \$5.50 enviada a Supermaxi',
                );
              },
            ),
          ],
        ),
      );
    } else {
      return Card(
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.amber.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.amber.shade900, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permiso de Notificaciones Pendiente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Actívalo para que la app detecte transferencias automáticamente.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await NotificationService.openPermissionSettings();
                  Future.delayed(const Duration(seconds: 1), _loadDashboardData);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Activar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Barra de acceso rápido para registrar gastos habituales
  Widget _buildQuickExpenseBar(ThemeData theme) {
    final quickItems = [
      {'name': 'Comida', 'icon': Icons.restaurant, 'color': const Color(0xFFFF9800)},
      {'name': 'Transporte', 'icon': Icons.directions_car, 'color': const Color(0xFF4CAF50)},
      {'name': 'Compras', 'icon': Icons.shopping_cart, 'color': const Color(0xFF2196F3)},
      {'name': 'Servicios', 'icon': Icons.receipt_long, 'color': const Color(0xFF795548)},
      {'name': 'Salud', 'icon': Icons.local_hospital, 'color': const Color(0xFFF44336)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Gasto Rápido',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Toca para registrar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: quickItems.map((item) {
              final color = item['color'] as Color;
              final icon = item['icon'] as IconData;
              final name = item['name'] as String;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => _showAddTransactionDialog(context, initialCategory: name),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Guía visual y acciones rápidas cuando la app no tiene consumos aún
  Widget _buildEmptyStateGuide(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '¿Cómo funciona TransfConsumption?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cada vez que hagas un consumo o transferencia en tu app bancaria (Banco Pichincha, Deuna, etc.), la app lo detectará automáticamente.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            _buildStepRow(
              '1',
              'Transfieres o compras',
              'El banco envía una notificación de transferencia exitosa.',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              '2',
              'Salta el popup "¿De qué fue?"',
              'Eliges la categoría (Comida, Transporte, etc.) en 1 toque.',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              '3',
              'Estadísticas al instante',
              'Tus gráficos de gastos y presupuestos se actualizan solos.',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadDemoData,
                    icon: const Icon(Icons.dataset, size: 18),
                    label: const Text('Cargar ejemplos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      NotificationService.simulateTransaction(
                        amount: 5.50,
                        merchant: 'Supermaxi',
                        type: 'Transferencia enviada',
                        rawText: 'Transferencia exitosa de \$5.50 enviada a Supermaxi',
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Probar simulación'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(String stepNumber, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
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
              theme.colorScheme.primary.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total del mes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    monthName.substring(0, 1).toUpperCase() + monthName.substring(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currencyFormat.format(_monthTotal),
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _transactionCount > 0
                  ? '$_transactionCount consumo(s) registrados este mes'
                  : 'Aún no registras consumos en este mes',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
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
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme) {
    final defaultCategories = CategoryModel.defaultCategories;
    final sortedEntries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gastos por Categoría',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_categoryTotals.length} categorías',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
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
                              backgroundColor:
                                  cat.getColor().withValues(alpha: 0.1),
                              valueColor:
                                  AlwaysStoppedAnimation(cat.getColor()),
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
                Text(
                  '${provider.transactions.length} total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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

  void _showAddTransactionDialog(BuildContext context, {String? initialCategory}) {
    final amountController = TextEditingController();
    final merchantController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedCategory = initialCategory;

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
                    'Registrar Consumo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Monto
                  TextField(
                    controller: amountController,
                    autofocus: true,
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
                      labelText: 'Comercio / Persona (opcional)',
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
                                context
                                    .read<TransactionProvider>()
                                    .loadTransactions();

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
