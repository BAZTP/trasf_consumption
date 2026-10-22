import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:transf_consumption/services/notification_service.dart';
import 'package:transf_consumption/database/database_helper.dart';
import 'package:transf_consumption/providers/transaction_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPermissionGranted = false;
  bool _isLoadingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationService.isPermissionGranted();
    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
        _isLoadingPermission = false;
      });
    }
  }

  Future<void> _exportToCSV() async {
    final transactions = await DatabaseHelper.instance.getTransactions();
    if (transactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay consumos para exportar.')),
        );
      }
      return;
    }

    final List<List<dynamic>> rows = [
      ['ID', 'Monto', 'Moneda', 'Comercio', 'Categoría', 'Fecha', 'Nota']
    ];

    for (final t in transactions) {
      rows.add([
        t.id,
        t.amount,
        'USD',
        t.merchant ?? '',
        t.category,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(t.date),
        t.note ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/consumos_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exportación de Consumos y Transferencias',
    );
  }

  Future<void> _confirmClearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todos los consumos?'),
        content: const Text(
          'Esta acción eliminará todas las transacciones guardadas. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar Todo'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.tableTransactions);
      if (mounted) {
        Provider.of<TransactionProvider>(context, listen: false)
            .loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historial eliminado exitosamente.')),
        );
      }
    }
  }

  void _showTestNotificationDialog() {
    final amountController = TextEditingController(text: '5.50');
    final merchantController = TextEditingController(text: 'Supermaxi');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simular Transferencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Prueba cómo reacciona la app cuando el banco te envía una notificación de transferencia o consumo.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto (\$) ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: merchantController,
              decoration: const InputDecoration(
                labelText: 'Comercio / Persona',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text) ?? 5.50;
              Navigator.pop(ctx);
              NotificationService.simulateTransaction(
                amount: amt,
                merchant: merchantController.text.trim().isEmpty
                    ? null
                    : merchantController.text.trim(),
                type: 'Transferencia enviada',
                rawText: 'Transferencia exitosa de \$$amt enviada a ${merchantController.text}',
              );
            },
            child: const Text('Disparar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          // Sección Servicio de Notificaciones
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'DETECCIÓN AUTOMÁTICA',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _isPermissionGranted
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: _isPermissionGranted ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Acceso a Notificaciones'),
                  subtitle: Text(
                    _isLoadingPermission
                        ? 'Verificando permiso...'
                        : (_isPermissionGranted
                            ? 'Activo - Detectando transferencias de tu banco'
                            : 'Inactivo - Requiere permiso para detectar consumos'),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      await NotificationService.openPermissionSettings();
                      Future.delayed(const Duration(seconds: 1), _checkPermission);
                    },
                    child: Text(_isPermissionGranted ? 'Ajustes' : 'Activar'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flash_on, color: Colors.blue),
                  title: const Text('Simular notificación bancaria'),
                  subtitle: const Text('Prueba el popup y registro con 1 clic'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showTestNotificationDialog,
                ),
              ],
            ),
          ),

          // Sección de Datos
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'GESTIÓN DE DATOS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download, color: Colors.teal),
                  title: const Text('Exportar a CSV / Excel'),
                  subtitle: const Text('Descarga o comparte tus gastos en formato tabla'),
                  onTap: _exportToCSV,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Borrar todo el historial',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Elimina todas las transacciones locales'),
                  onTap: _confirmClearData,
                ),
              ],
            ),
          ),

          // Sección Información
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'ACERCA DE LA APLICACIÓN',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.account_balance_wallet, color: Colors.indigo),
                  title: Text('TransfConsumption'),
                  subtitle: Text('Versión 1.0.0 • SQLite Offline'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.green),
                  title: const Text('Privacidad Total'),
                  subtitle: const Text(
                    'Tus datos y notificaciones nunca salen de este teléfono.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
