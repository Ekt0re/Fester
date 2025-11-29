import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class EventStatisticsScreen extends StatefulWidget {
  final String eventId;

  const EventStatisticsScreen({super.key, required this.eventId});

  @override
  State<EventStatisticsScreen> createState() => _EventStatisticsScreenState();
}

class _EventStatisticsScreenState extends State<EventStatisticsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Statistics data
  int _totalAttendance = 0;
  int _maxCapacity = 0;
  int _activeStaff = 0;
  int _totalStaff = 0;
  double _totalRevenue = 0;
  Map<String, int> _statusCounts = {};
  List<Map<String, dynamic>> _topProducts = [];
  int _totalItemsSold = 0;
  double _avgSpend = 0;
  double _checkInRate = 0;
  double _staffGuestRatio = 0;
  int _totalInvited = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get event settings for max capacity
      final eventSettings =
          await _supabase
              .from('event_settings')
              .select('max_participants')
              .eq('event_id', widget.eventId)
              .maybeSingle();

      _maxCapacity = eventSettings?['max_participants'] ?? 0;

      // 2. Count participations (total attendance)
      final participations = await _supabase
          .from('participation')
          .select('id, status_id, participation_status(name, is_inside)')
          .eq('event_id', widget.eventId);

      int totalAttendance = 0;
      Map<String, int> statusCounts = {};

      for (var p in participations) {
        final statusData = p['participation_status'];
        final statusName = statusData?['name'] ?? 'Unknown';
        final isInside = statusData?['is_inside'] ?? false;

        statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;
        if (isInside) totalAttendance++;
      }

      // 3. Count staff
      final staff = await _supabase
          .from('event_staff')
          .select('id, staff:staff_user_id(is_active)')
          .eq('event_id', widget.eventId);

      _totalStaff = (staff as List).length;
      _activeStaff =
          (staff as List).where((s) {
            final staffUser = s['staff'];
            return staffUser != null && staffUser['is_active'] == true;
          }).length;

      // 4. Calculate total revenue and get transactions
      final transactions = await _supabase
          .from('transaction')
          .select(
            'amount, quantity, menu_item_id, menu_item(name), participation!inner(event_id)',
          )
          .eq('participation.event_id', widget.eventId);

      double totalRevenue = 0;
      int totalItemsSold = 0;
      Map<String, int> productCounts = {};

      for (var t in transactions) {
        final amount = (t['amount'] as num?)?.toDouble() ?? 0;
        final quantity = (t['quantity'] as num?)?.toInt() ?? 1;
        totalRevenue += amount * quantity;
        totalItemsSold += quantity;

        // Count products
        if (t['menu_item_id'] != null) {
          final itemName = t['menu_item']?['name'] ?? 'Unknown';
          productCounts[itemName] = (productCounts[itemName] ?? 0) + quantity;
        }
      }

      final topProducts =
          productCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      _totalInvited = participations.length;
      if (_totalAttendance > 0) {
        _avgSpend = totalRevenue / _totalAttendance;
        _staffGuestRatio = _activeStaff / _totalAttendance;
      }
      if (_totalInvited > 0) {
        _checkInRate = (_totalAttendance / _totalInvited) * 100;
      }

      setState(() {
        _totalAttendance = totalAttendance;
        _totalRevenue = totalRevenue;
        _statusCounts = statusCounts;
        _activeStaff = _activeStaff;
        _topProducts =
            topProducts
                .take(5)
                .map((e) => {'name': e.key, 'count': e.value})
                .toList();
        _totalItemsSold = totalItemsSold;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'statistics.load_error'.tr()}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text('statistics.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('statistics.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Metrics Grid
              if (isDesktop)
                GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  childAspectRatio: 1.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSmallMetricCard(
                      theme: theme,
                      title: 'statistics.live_attendance'.tr(),
                      value: '$_totalAttendance',
                      subtitle: _maxCapacity > 0 ? '/ $_maxCapacity' : '',
                      icon: Icons.people,
                      color: AppTheme.primaryLight,
                    ),
                    _buildSmallMetricCard(
                      theme: theme,
                      title: 'statistics.total_sales'.tr(),
                      value: '€${_totalRevenue.toStringAsFixed(0)}',
                      subtitle: '',
                      icon: Icons.monetization_on,
                      color: Colors.green,
                    ),
                    _buildSmallMetricCard(
                      theme: theme,
                      title: 'statistics.avg_spend'.tr(),
                      value: '€${_avgSpend.toStringAsFixed(1)}',
                      subtitle: 'statistics.per_person'.tr(),
                      icon: Icons.attach_money,
                      color: Colors.blue,
                    ),
                    _buildSmallMetricCard(
                      theme: theme,
                      title: 'statistics.check_in_rate'.tr(),
                      value: '${_checkInRate.toStringAsFixed(1)}%',
                      subtitle: 'statistics.of_invited'.tr(),
                      icon: Icons.check_circle_outline,
                      color: Colors.purple,
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallMetricCard(
                            theme: theme,
                            title: 'statistics.live_attendance'.tr(),
                            value: '$_totalAttendance',
                            subtitle: _maxCapacity > 0 ? '/ $_maxCapacity' : '',
                            icon: Icons.people,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSmallMetricCard(
                            theme: theme,
                            title: 'statistics.total_sales'.tr(),
                            value: '€${_totalRevenue.toStringAsFixed(0)}',
                            subtitle: '',
                            icon: Icons.monetization_on,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallMetricCard(
                            theme: theme,
                            title: 'statistics.avg_spend'.tr(),
                            value: '€${_avgSpend.toStringAsFixed(1)}',
                            subtitle: 'statistics.per_person'.tr(),
                            icon: Icons.attach_money,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSmallMetricCard(
                            theme: theme,
                            title: 'statistics.check_in_rate'.tr(),
                            value: '${_checkInRate.toStringAsFixed(1)}%',
                            subtitle: 'statistics.of_invited'.tr(),
                            icon: Icons.check_circle_outline,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // Staff Stats
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallMetricCard(
                        theme: theme,
                        title: 'statistics.active_staff'.tr(),
                        value: '$_activeStaff',
                        subtitle: _totalStaff > 0 ? '/ $_totalStaff' : '',
                        icon: Icons.badge,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSmallMetricCard(
                        theme: theme,
                        title: 'statistics.staff_guest_ratio'.tr(),
                        value: '1:${_staffGuestRatio.toStringAsFixed(0)}',
                        subtitle: 'statistics.staff_per_guests'.tr(),
                        icon: Icons.group_work,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                )
              else
                _buildSmallMetricCard(
                  theme: theme,
                  title: 'statistics.active_staff'.tr(),
                  value: '$_activeStaff',
                  subtitle: _totalStaff > 0 ? '/ $_totalStaff' : '',
                  icon: Icons.badge,
                  color: Colors.orange,
                ),

              const SizedBox(height: 24),

              // Charts
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStatusChart(theme)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTopProductsChart(theme)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildStatusChart(theme),
                    const SizedBox(height: 16),
                    _buildTopProductsChart(theme),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChart(ThemeData theme) {
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'statistics.participation_by_status'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child:
                  _statusCounts.isEmpty
                      ? Center(
                        child: Text(
                          'statistics.no_data'.tr(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                      : PieChart(
                        PieChartData(
                          sections:
                              _statusCounts.entries.map((entry) {
                                final index = _statusCounts.keys
                                    .toList()
                                    .indexOf(entry.key);
                                return PieChartSectionData(
                                  value: entry.value.toDouble(),
                                  title: '${entry.value}',
                                  color: _getColorForIndex(index),
                                  radius: 70,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                        ),
                      ),
            ),
            const SizedBox(height: 20),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children:
                  _statusCounts.entries.map((entry) {
                    final index = _statusCounts.keys.toList().indexOf(
                      entry.key,
                    );
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _getColorForIndex(index),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.key} (${entry.value})',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsChart(ThemeData theme) {
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'statistics.top_consumed_items'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (_topProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${'statistics.most_popular'.tr()}${_topProducts.first['name']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections:
                          _topProducts.asMap().entries.map((entry) {
                            final index = entry.key;
                            final product = entry.value;
                            final percentage =
                                (_totalItemsSold > 0
                                    ? (product['count'] / _totalItemsSold * 100)
                                    : 0);
                            return PieChartSectionData(
                              value: product['count'].toDouble(),
                              title: '${percentage.toStringAsFixed(0)}%',
                              color: _getProductColor(index),
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                      sectionsSpace: 3,
                      centerSpaceRadius: 60,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'statistics.total_items'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        _totalItemsSold.toString(),
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Product Legend
            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final percentage =
                  (_totalItemsSold > 0
                      ? (product['count'] / _totalItemsSold * 100)
                      : 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getProductColor(index),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product['name'],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
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

  Widget _buildSmallMetricCard({
    required ThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Icon(icon, size: 20, color: color.withOpacity(0.7)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      AppTheme.primaryLight,
      AppTheme.secondaryLight,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  Color _getProductColor(int index) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
    ];
    return colors[index % colors.length];
  }
}
