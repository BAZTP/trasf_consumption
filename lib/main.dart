import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transf_consumption/models/transaction_model.dart';
import 'package:transf_consumption/providers/transaction_provider.dart';
import 'package:transf_consumption/screens/home_screen.dart';
import 'package:transf_consumption/screens/transactions_screen.dart';
import 'package:transf_consumption/screens/statistics_screen.dart';
import 'package:transf_consumption/screens/settings_screen.dart';
import 'package:transf_consumption/database/database_helper.dart';
import 'package:transf_consumption/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar base de datos
  await DatabaseHelper.instance.initDatabase();

  // Inicializar servicio de notificaciones
  await NotificationService.initialize();

  runApp(const TransfConsumptionApp());
}

class TransfConsumptionApp extends StatelessWidget {
  const TransfConsumptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionProvider()..loadTransactions(),
      child: MaterialApp(
        title: 'TransfConsumption',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const MainNavigation(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TransactionsScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForTransactions();
  }

  void _listenForTransactions() {
    NotificationService.onTransactionDetected.listen((data) {
      if (!mounted) return;
      _showCategoryDialog(data);
    });
  }

  void _showCategoryDialog(TransactionData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryPickerSheet(transactionData: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Consumos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet para seleccionar categoría cuando se detecta una transacción
class CategoryPickerSheet extends StatefulWidget {
  final TransactionData transactionData;

  const CategoryPickerSheet({super.key, required this.transactionData});

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final TextEditingController _noteController = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Icono de éxito y monto
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '¡${widget.transactionData.type}!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${widget.transactionData.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.transactionData.merchant != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.transactionData.merchant!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pregunta
            Text(
              '¿De qué fue?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Grid de categorías
            FutureBuilder(
              future: DatabaseHelper.instance.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = snapshot.data!;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat.name;
                    final catColor = cat.getColor();
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat.name);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor.withValues(alpha: 0.2)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? catColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.getIconData(), size: 20, color: catColor),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                color: isSelected
                                    ? catColor
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
                );
              },
            ),
            const SizedBox(height: 16),

            // Nota opcional
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Agregar nota (opcional)',
                prefixIcon: const Icon(Icons.note_add_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedCategory == null
                    ? null
                    : () => _saveTransaction(context),
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction(BuildContext context) async {
    final transaction = TransactionModel(
      amount: widget.transactionData.amount,
      merchant: widget.transactionData.merchant,
      category: _selectedCategory!,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      date: DateTime.now(),
      rawNotification: widget.transactionData.rawText,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertTransaction(transaction);

    if (context.mounted) {
      // Refrescar la lista de transacciones
      Provider.of<TransactionProvider>(context, listen: false)
          .loadTransactions();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gasto de \$${widget.transactionData.amount.toStringAsFixed(2)} registrado en $_selectedCategory',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
