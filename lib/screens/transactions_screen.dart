import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:transf_consumption/models/transaction_model.dart';
import 'package:transf_consumption/models/category_model.dart';
import 'package:transf_consumption/providers/transaction_provider.dart';

enum DateFilter { todas, hoy, semana, mes }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();

  DateFilter _dateFilter = DateFilter.todas;
  String? _selectedCategory;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> list) {
    final now = DateTime.now();

    return list.where((t) {
      // Filtro de fecha
      if (_dateFilter == DateFilter.hoy) {
        if (t.date.year != now.year ||
            t.date.month != now.month ||
            t.date.day != now.day) {
          return false;
        }
      } else if (_dateFilter == DateFilter.semana) {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startZero = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        if (t.date.isBefore(startZero)) return false;
      } else if (_dateFilter == DateFilter.mes) {
        if (t.date.year != now.year || t.date.month != now.month) {
          return false;
        }
      }

      // Filtro de categoría
      if (_selectedCategory != null && t.category != _selectedCategory) {
        return false;
      }

      // Filtro de búsqueda
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final m = (t.merchant ?? '').toLowerCase();
        final c = t.category.toLowerCase();
        final n = (t.note ?? '').toLowerCase();
        if (!m.contains(query) && !c.contains(query) && !n.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar por comercio o nota...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text(
                'Historial de Consumos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredList = _filterTransactions(provider.transactions);
          final totalAmount = filteredList.fold(0.0, (acc, t) => acc + t.amount);

          return Column(
            children: [
              // Barra de filtros rápidos
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _dateFilter == DateFilter.todas,
                      onSelected: (val) {
                        if (val) setState(() => _dateFilter = DateFilter.todas);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Hoy'),
                      selected: _dateFilter == DateFilter.hoy,
                      onSelected: (val) {
                        if (val) setState(() => _dateFilter = DateFilter.hoy);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Esta Semana'),
                      selected: _dateFilter == DateFilter.semana,
                      onSelected: (val) {
                        if (val) setState(() => _dateFilter = DateFilter.semana);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Este Mes'),
                      selected: _dateFilter == DateFilter.mes,
                      onSelected: (val) {
                        if (val) setState(() => _dateFilter = DateFilter.mes);
                      },
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String?>(
                      initialValue: _selectedCategory,
                      onSelected: (cat) {
                        setState(() => _selectedCategory = cat);
                      },
                      itemBuilder: (context) {
                        return [
                          const PopupMenuItem(
                            value: null,
                            child: Text('Todas las categorías'),
                          ),
                          ...CategoryModel.defaultCategories.map(
                            (c) => PopupMenuItem(
                              value: c.name,
                              child: Row(
                                children: [
                                  Icon(c.getIconData(), color: c.getColor(), size: 18),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ),
                          ),
                        ];
                      },
                      child: Chip(
                        avatar: _selectedCategory == null
                            ? const Icon(Icons.filter_list, size: 16)
                            : const Icon(Icons.check, size: 16),
                        label: Text(_selectedCategory ?? 'Categoría'),
                        deleteIcon: _selectedCategory != null
                            ? const Icon(Icons.close, size: 16)
                            : null,
                        onDeleted: _selectedCategory != null
                            ? () => setState(() => _selectedCategory = null)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Total en resumen de la vista actual
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filteredList.length} registro(s)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      'Total: ${_currencyFormat.format(totalAmount)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Lista de consumos
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron consumos',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredList.length,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final cat = CategoryModel.defaultCategories.firstWhere(
                            (c) => c.name == item.category,
                            orElse: () => CategoryModel.defaultCategories.last,
                          );

                          return Dismissible(
                            key: ValueKey(item.id ?? index),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('¿Eliminar consumo?'),
                                  content: Text(
                                      'Se eliminará el registro de \$${item.amount.toStringAsFixed(2)}.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) {
                              if (item.id != null) {
                                provider.deleteTransaction(item.id!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Consumo eliminado'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cat.getColor().withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(cat.getIconData(),
                                      color: cat.getColor(), size: 22),
                                ),
                                title: Text(
                                  item.merchant ?? item.category,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.category} • ${DateFormat('dd MMM yyyy, hh:mm a').format(item.date)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (item.note != null && item.note!.isNotEmpty)
                                      Text(
                                        'Nota: ${item.note}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  _currencyFormat.format(item.amount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                onTap: () => _showEditDialog(context, item),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, TransactionModel t) {
    final noteController = TextEditingController(text: t.note);
    final merchantController = TextEditingController(text: t.merchant);
    String selectedCat = t.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Detalles del Consumo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${t.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: merchantController,
                    decoration: const InputDecoration(
                      labelText: 'Comercio / Destinatario',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: CategoryModel.defaultCategories
                        .map((c) => DropdownMenuItem(
                              value: c.name,
                              child: Row(
                                children: [
                                  Icon(c.getIconData(), color: c.getColor(), size: 18),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCat = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (t.rawNotification != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Notificación original:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.rawNotification!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                onPressed: () async {
                  final updated = t.copyWith(
                    merchant: merchantController.text.trim().isEmpty
                        ? null
                        : merchantController.text.trim(),
                    category: selectedCat,
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                  );
                  await Provider.of<TransactionProvider>(context, listen: false)
                      .updateTransaction(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Actualizar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
