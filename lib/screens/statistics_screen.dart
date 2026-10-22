import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:transf_consumption/database/database_helper.dart';
import 'package:transf_consumption/models/category_model.dart';

/// Pantalla de estadísticas con gráficos interactivos y resúmenes de gastos.
///
/// Muestra distribución por categoría (gráfico de dona), barras de gasto
/// por período y tarjetas de resumen con los datos más relevantes.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

/// Períodos disponibles para filtrar las estadísticas.
enum _StatPeriod { semana, mes, anio }

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Período actualmente seleccionado.
  _StatPeriod _selectedPeriod = _StatPeriod.semana;

  /// Totales agrupados por categoría para el período actual.
  Map<String, double> _categoryTotals = {};

  /// Totales agrupados por día/semana/mes para el gráfico de barras.
  Map<String, double> _barData = {};

  /// Lista de los comercios con mayor gasto en el período.
  List<Map<String, dynamic>> _topMerchants = [];

  /// Categorías disponibles para obtener colores e iconos.
  List<CategoryModel> _categories = [];

  /// Indica si los datos se están cargando.
  bool _isLoading = true;

  /// Índice de la sección tocada en el gráfico de dona (-1 = ninguna).
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // Cálculo de rango de fechas según el período seleccionado
  // ---------------------------------------------------------------------------

  /// Retorna las fechas de inicio y fin para el período seleccionado.
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case _StatPeriod.semana:
        // Lunes a domingo de la semana actual
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
      case _StatPeriod.mes:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
      case _StatPeriod.anio:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
    }
  }

  // ---------------------------------------------------------------------------
  // Carga de datos desde la base de datos
  // ---------------------------------------------------------------------------

  /// Carga todas las estadísticas necesarias para el período seleccionado.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final (startDate, endDate) = _getDateRange();

    final results = await Future.wait([
      _db.getTotalByCategory(startDate, endDate),
      _db.getTotalByDay(startDate, endDate),
      _db.getTopMerchants(5, startDate, endDate),
      _db.getCategories(),
    ]);

    setState(() {
      _categoryTotals = results[0] as Map<String, double>;
      _barData = results[1] as Map<String, double>;
      _topMerchants = results[2] as List<Map<String, dynamic>>;
      _categories = results[3] as List<CategoryModel>;
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers de formato y colores
  // ---------------------------------------------------------------------------

  /// Formatea un monto como moneda USD.
  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_US', symbol: '\$').format(amount);
  }

  /// Obtiene el color de una categoría por nombre; retorna gris si no se encuentra.
  Color _getCategoryColor(String categoryName) {
    final match = _categories.where((c) => c.name == categoryName);
    if (match.isNotEmpty) {
      return match.first.getColor();
    }
    return Colors.grey;
  }

  /// Obtiene el icono de una categoría por nombre.
  IconData _getCategoryIcon(String categoryName) {
    final match = _categories.where((c) => c.name == categoryName);
    if (match.isNotEmpty) {
      return match.first.getIconData();
    }
    return Icons.category;
  }

  /// Total general del período.
  double get _totalSpent =>
      _categoryTotals.values.fold(0.0, (sum, v) => sum + v);

  /// Número de días transcurridos en el período actual.
  int get _daysInPeriod {
    final (start, end) = _getDateRange();
    return end.difference(start).inDays + 1;
  }

  /// Nombre de la categoría con mayor gasto.
  String get _topCategory {
    if (_categoryTotals.isEmpty) return '—';
    return _categoryTotals.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  // ---------------------------------------------------------------------------
  // Construcción de la interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Selector de período
                  _buildPeriodSelector(theme),
                  const SizedBox(height: 24),

                  // Gráfico de dona por categoría
                  _buildSectionTitle('Distribución por categoría', theme),
                  const SizedBox(height: 12),
                  _categoryTotals.isEmpty
                      ? _buildEmptyState('Sin datos para este período')
                      : _buildPieChart(),
                  const SizedBox(height: 12),
                  if (_categoryTotals.isNotEmpty) _buildLegend(),
                  const SizedBox(height: 24),

                  // Gráfico de barras
                  _buildSectionTitle('Gasto por período', theme),
                  const SizedBox(height: 12),
                  _barData.isEmpty
                      ? _buildEmptyState('Sin datos para este período')
                      : _buildBarChart(theme),
                  const SizedBox(height: 24),

                  // Tarjetas de resumen
                  _buildSectionTitle('Resumen', theme),
                  const SizedBox(height: 12),
                  _buildSummaryCards(theme),
                  const SizedBox(height: 24),

                  // Top comercios
                  _buildSectionTitle('Top comercios', theme),
                  const SizedBox(height: 12),
                  _topMerchants.isEmpty
                      ? _buildEmptyState('Sin comercios registrados')
                      : _buildTopMerchants(theme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Selector de período (Semana / Mes / Año)
  // ---------------------------------------------------------------------------

  Widget _buildPeriodSelector(ThemeData theme) {
    return Center(
      child: SegmentedButton<_StatPeriod>(
        segments: const [
          ButtonSegment(value: _StatPeriod.semana, label: Text('Semana')),
          ButtonSegment(value: _StatPeriod.mes, label: Text('Mes')),
          ButtonSegment(value: _StatPeriod.anio, label: Text('Año')),
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (selected) {
          setState(() => _selectedPeriod = selected.first);
          _loadData();
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: theme.colorScheme.primaryContainer,
          selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gráfico de dona (Pie Chart)
  // ---------------------------------------------------------------------------

  Widget _buildPieChart() {
    final total = _totalSpent;
    final entries = _categoryTotals.entries.toList();

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedPieIndex = -1;
                  return;
                }
                _touchedPieIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: List.generate(entries.length, (i) {
            final isTouched = i == _touchedPieIndex;
            final fontSize = isTouched ? 16.0 : 12.0;
            final radius = isTouched ? 60.0 : 50.0;
            final percentage = total > 0 ? (entries[i].value / total) * 100 : 0;

            return PieChartSectionData(
              color: _getCategoryColor(entries[i].key),
              value: entries[i].value,
              title: '${percentage.toStringAsFixed(1)}%',
              radius: radius,
              titleStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 2),
                ],
              ),
              titlePositionPercentageOffset: 0.55,
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Leyenda del gráfico de dona
  // ---------------------------------------------------------------------------

  Widget _buildLegend() {
    final total = _totalSpent;
    final entries = _categoryTotals.entries.toList();

    return Column(
      children: entries.map((entry) {
        final percentage = total > 0 ? (entry.value / total) * 100 : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Icono de la categoría
              Icon(
                _getCategoryIcon(entry.key),
                size: 16,
                color: _getCategoryColor(entry.key),
              ),
              const SizedBox(width: 8),
              // Nombre de la categoría
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              // Monto
              Text(
                _formatCurrency(entry.value),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Porcentaje
              SizedBox(
                width: 50,
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Gráfico de barras
  // ---------------------------------------------------------------------------

  Widget _buildBarChart(ThemeData theme) {
    final entries = _barData.entries.toList();
    final maxValue =
        entries.fold<double>(0, (max, e) => e.value > max ? e.value : max);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue > 0 ? maxValue * 1.2 : 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = _getBarLabel(entries[group.x.toInt()].key);
                return BarTooltipItem(
                  '$label\n${_formatCurrency(rod.toY)}',
                  TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            // Eje inferior: etiquetas de fecha
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _getBarLabel(entries[index].key),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            // Eje izquierdo: valores monetarios
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    _formatCompact(value),
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue > 0 ? maxValue / 4 : 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: theme.colorScheme.primary,
                  width: entries.length > 12 ? 8 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue > 0 ? maxValue * 1.2 : 100,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Formatea la etiqueta de cada barra según el período.
  ///
  /// Para "Semana" muestra el día de la semana abreviado;
  /// para "Mes" muestra el número de día; para "Año" muestra el mes abreviado.
  String _getBarLabel(String key) {
    try {
      final date = DateTime.parse(key);
      switch (_selectedPeriod) {
        case _StatPeriod.semana:
          const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
          return days[date.weekday - 1];
        case _StatPeriod.mes:
          return '${date.day}';
        case _StatPeriod.anio:
          const months = [
            'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
            'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
          ];
          return months[date.month - 1];
      }
    } catch (_) {
      return key.length > 5 ? key.substring(5) : key;
    }
  }

  /// Formatea valores grandes de forma compacta (ej: 1.2K, 3.5M).
  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  // ---------------------------------------------------------------------------
  // Tarjetas de resumen
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(ThemeData theme) {
    final dailyAvg = _daysInPeriod > 0 ? _totalSpent / _daysInPeriod : 0.0;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total gastado',
            value: _formatCurrency(_totalSpent),
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.today_outlined,
            label: 'Promedio diario',
            value: _formatCurrency(dailyAvg),
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.emoji_events_outlined,
            label: 'Categoría top',
            value: _topCategory,
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top comercios
  // ---------------------------------------------------------------------------

  Widget _buildTopMerchants(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(_topMerchants.length, (i) {
            final merchant = _topMerchants[i];
            final name = merchant['merchant'] as String;
            final total = merchant['total'] as double;
            final count = merchant['count'] as int;

            return Padding(
              padding: EdgeInsets.only(
                bottom: i < _topMerchants.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  // Número de posición
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nombre del comercio y conteo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$count transaccion${count == 1 ? '' : 'es'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Monto total
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Utilidades visuales
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget auxiliar: Tarjeta de resumen
// =============================================================================

/// Tarjeta compacta para mostrar una métrica de resumen con icono.
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
