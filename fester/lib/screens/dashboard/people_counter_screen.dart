import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase/models/event_area.dart';
import '../../services/supabase/people_counter_service.dart';
import '../../theme/app_theme.dart';

class PeopleCounterScreen extends StatefulWidget {
  final String eventId;

  const PeopleCounterScreen({super.key, required this.eventId});

  @override
  State<PeopleCounterScreen> createState() => _PeopleCounterScreenState();
}

class _PeopleCounterScreenState extends State<PeopleCounterScreen> {
  final PeopleCounterService _service = PeopleCounterService();
  late Stream<List<EventArea>> _areasStream;

  @override
  void initState() {
    super.initState();
    _refreshStream();
  }

  void _refreshStream() {
    setState(() {
      _areasStream = _service.getAreasStream(widget.eventId);
    });
  }

  @override
  void didUpdateWidget(covariant PeopleCounterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _refreshStream();
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Conta Persone",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAreaDialog,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<EventArea>>(
        stream: _areasStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final areas = snapshot.data ?? [];

          if (areas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.layers_clear,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Nessuna area creata",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Desktop View (Side-by-Side)
              if (constraints.maxWidth > 900) {
                return Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: theme.dividerColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                "Contatori",
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            Expanded(child: _buildCountersList(areas, theme)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: PeopleCounterStatistics(
                        areas: areas,
                        service: _service,
                      ),
                    ),
                  ],
                );
              }

              // Mobile/Tablet View (Tabs)
              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurface
                          .withOpacity(0.6),
                      indicatorColor: theme.colorScheme.primary,
                      labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: const [
                        Tab(text: "Contatori"),
                        Tab(text: "Statistiche"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCountersList(areas, theme),
                          PeopleCounterStatistics(
                            areas: areas,
                            service: _service,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCountersList(List<EventArea> areas, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      itemCount: areas.length,
      itemBuilder: (context, index) {
        final area = areas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
          ),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      area.name,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _showDeleteConfirmDialog(area),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildControlButton(
                      icon: Icons.remove,
                      color: theme.colorScheme.error,
                      onTap: () => _updateCount(area.id, -1),
                    ),
                    Expanded(
                      child: Text(
                        '${area.currentCount}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    _buildControlButton(
                      icon: Icons.add,
                      color: theme.colorScheme.secondary,
                      onTap: () => _updateCount(area.id, 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }

  Future<void> _updateCount(String areaId, int delta) async {
    try {
      await _service.updateCount(areaId, delta);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Errore: $e")));
      }
    }
  }

  void _showAddAreaDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              "Nuova Area",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Nome Area (es. Piano Terra)",
                hintText: "Inserisci nome",
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annulla"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(dialogContext);
                    try {
                      await _service.createArea(
                        widget.eventId,
                        controller.text.trim(),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Errore creazione: $e")),
                        );
                      }
                    }
                  }
                },
                child: const Text("Crea"),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmDialog(EventArea area) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              "Elimina ${area.name}?",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Questa azione non può essere annullata. Tutti i dati relativi a questa area verranno persi.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annulla"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await _service.deleteArea(area.id);
                    if (mounted) {
                      _refreshStream(); // Force refresh to update UI immediately
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Errore eliminazione: $e")),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorLight,
                ),
                child: const Text("Elimina"),
              ),
            ],
          ),
    );
  }
}

class PeopleCounterStatistics extends StatefulWidget {
  final List<EventArea> areas;
  final PeopleCounterService service;

  const PeopleCounterStatistics({
    super.key,
    required this.areas,
    required this.service,
  });

  @override
  State<PeopleCounterStatistics> createState() =>
      _PeopleCounterStatisticsState();
}

class _PeopleCounterStatisticsState extends State<PeopleCounterStatistics> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void didUpdateWidget(covariant PeopleCounterStatistics oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh logs if areas have changed or if the total counts have changed
    // This allows the graph to update in real-time when counts change
    bool shouldRefresh = oldWidget.areas.length != widget.areas.length;
    if (!shouldRefresh) {
      // Check if counts changed
      for (final area in widget.areas) {
        final oldArea = oldWidget.areas.firstWhere(
          (element) => element.id == area.id,
          orElse: () => area,
        );
        if (oldArea.currentCount != area.currentCount) {
          shouldRefresh = true;
          break;
        }
      }
    }

    if (shouldRefresh) {
      _fetchLogs(silent: true);
    }
  }

  Future<void> _fetchLogs({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final logs = await widget.service.getAreaLogs(
        widget.areas.map((e) => e.id).toList(),
      );
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.areas.isEmpty) return const SizedBox();

    final theme = Theme.of(context);
    final total = widget.areas.fold(0, (sum, item) => sum + item.currentCount);
    final activeAreas = widget.areas.where((a) => a.currentCount > 0).toList();

    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Total Count Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Totale Partecipanti",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$total",
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Current Distribution Chart
          Text(
            "Distribuzione Attuale",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (total > 0)
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections:
                      activeAreas.map((area) {
                        final areaIndex = widget.areas.indexOf(
                          area,
                        ); // Use consistent index for color
                        final color = colors[areaIndex % colors.length];
                        final percent = (area.currentCount / total * 100)
                            .toStringAsFixed(1);
                        return PieChartSectionData(
                          color: color,
                          value: area.currentCount.toDouble(),
                          title: '${area.currentCount}\n($percent%)',
                          radius: 80,
                          titleStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  "Nessun dato attuale",
                  style: GoogleFonts.outfit(color: theme.hintColor),
                ),
              ),
            ),

          // Legend
          if (activeAreas.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children:
                  widget.areas.where((a) => a.currentCount > 0).map((area) {
                    final index = widget.areas.indexOf(area);
                    final color = colors[index % colors.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          area.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],

          const SizedBox(height: 48),

          // History Line Chart
          Text(
            "Andamento nel Tempo",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading && _logs.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(
              "Errore: $_error",
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_logs.isEmpty)
            Text(
              "Nessuno storico disponibile",
              style: GoogleFonts.outfit(color: theme.hintColor),
            )
          else
            _buildHistoryChart(theme, colors),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHistoryChart(ThemeData theme, List<Color> colors) {
    if (_logs.isEmpty) return const SizedBox();

    // Determine start time from the oldest log
    final DateTime startTime =
        DateTime.parse(_logs.first['created_at'].toString()).toLocal();
    final DateTime now = DateTime.now();

    // Map to store list of spots for each area
    final Map<String, List<FlSpot>> areaSpots = {};
    // Initialize current counts from the actual known state (Source of Truth)
    final Map<String, int> runningCounts = {};

    for (var area in widget.areas) {
      areaSpots[area.id] = [];
      runningCounts[area.id] = area.currentCount;
    }

    // Process logs in REVERSE order (Newest -> Oldest)
    // This allows us to work backwards from the known current count
    for (var i = _logs.length - 1; i >= 0; i--) {
      final log = _logs[i];
      final delta = (log['delta'] as num?)?.toInt() ?? 0;
      final createdAtStr = log['created_at'];
      final areaId = log['area_id'] as String?;

      if (createdAtStr == null ||
          areaId == null ||
          !runningCounts.containsKey(areaId)) {
        continue;
      }

      final createdAt = DateTime.parse(createdAtStr.toString()).toLocal();

      // Calculate X based on difference from startTime
      // Use seconds for higher precision
      double diff = createdAt.difference(startTime).inSeconds.toDouble() / 60.0;
      if (diff < 0) diff = 0;

      // The count AT this timestamp (after the event) is the current value in runningCounts
      areaSpots[areaId]!.add(FlSpot(diff, runningCounts[areaId]!.toDouble()));

      // "Undo" the change to find the count BEFORE this event
      // If event added 1, previous was current - 1
      runningCounts[areaId] = runningCounts[areaId]! - delta;
    }

    // Now proceed to finalize the spots lists
    // 1. We added spots in reverse order (Newest first), so reverse them back
    // 2. Add the "initial" state at X=0 (the count before the first log)
    // 3. Add the "current" state at X=now (to extend line to the right)

    final double maxTime =
        now.difference(startTime).inSeconds.toDouble() / 60.0;

    for (var area in widget.areas) {
      if (areaSpots[area.id] == null) continue;

      final spots = areaSpots[area.id]!;

      // Reverse to get chronological order
      // spots now: [ (t_oldest, val_after_first_log), ... (t_newest, current_val) ]
      // Wait, we added backwards.
      // We added (t_newest, current), then ..., then (t_oldest, val_after_oldest).
      // So reversing gives: (t_oldest, val_after_oldest) ... (t_newest, current).
      final reversedSpots = spots.reversed.toList();
      spots.clear();
      spots.addAll(reversedSpots);

      // Add initial point (count before the oldest log)
      final initialCount = runningCounts[area.id] ?? 0;
      if (spots.isEmpty || spots.first.x > 0) {
        spots.insert(0, FlSpot(0, initialCount.toDouble()));
      }

      // Add final point (extend to now)
      if (spots.last.x < maxTime) {
        spots.add(FlSpot(maxTime, area.currentCount.toDouble()));
      }

      // Update the map reference just in case
      areaSpots[area.id] = spots;
    }

    // Build LineBars
    final List<LineChartBarData> lines = [];
    for (var i = 0; i < widget.areas.length; i++) {
      final area = widget.areas[i];
      final spots = areaSpots[area.id]!;

      if (spots.isEmpty) continue;

      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: colors[i % colors.length],
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (lines.isEmpty) return const SizedBox();

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine:
                (value) => FlLine(
                  color: theme.dividerColor.withOpacity(0.2),
                  strokeWidth: 1,
                ),
            getDrawingVerticalLine:
                (value) => FlLine(
                  color: theme.dividerColor.withOpacity(0.2),
                  strokeWidth: 1,
                ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxTime > 60 ? 30 : (maxTime > 10 ? 5 : 1),
                getTitlesWidget: (value, meta) {
                  // startTime is guaranteed non-null here
                  final date = startTime.add(Duration(minutes: value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
          ),
          lineBarsData: lines,
        ),
      ),
    );
  }
}
