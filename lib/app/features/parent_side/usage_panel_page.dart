import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/usage_aggregation_service.dart';
import 'package:times_up_flutter/theme/theme.dart';
import 'package:times_up_flutter/widgets/jh_display_text.dart';
import 'package:times_up_flutter/widgets/jh_empty_content.dart';

class UsagePanelPage extends StatefulWidget {
  const UsagePanelPage({
    required this.database,
    required this.childModel,
    Key? key,
  }) : super(key: key);

  final Database database;
  final ChildModel childModel;

  static Future<void> show(BuildContext context, ChildModel model) async {
    final database = Provider.of<Database>(context, listen: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UsagePanelPage(
          database: database,
          childModel: model,
        ),
      ),
    );
  }

  @override
  State<UsagePanelPage> createState() => _UsagePanelPageState();
}

class _UsagePanelPageState extends State<UsagePanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _displayNameForPackage(String package) {
    for (final app in widget.childModel.appsUsageModel) {
      if (app.packageName == package || app.packageName.contains(package)) {
        return app.appName;
      }
    }
    final parts = package.split('.');
    return parts.isNotEmpty ? parts.last : package;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childModel.name} — usage'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Day'),
            Tab(text: 'Week'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DayTab(
            database: widget.database,
            childId: widget.childModel.id,
            displayNameForPackage: _displayNameForPackage,
          ),
          _WeekTab(
            database: widget.database,
            childId: widget.childModel.id,
          ),
        ],
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.database,
    required this.childId,
    required this.displayNameForPackage,
  });

  final Database database;
  final String childId;
  final String Function(String package) displayNameForPackage;

  @override
  Widget build(BuildContext context) {
    final dateId = todayDateId();
    return FutureBuilder<Map<String, dynamic>?>(
      future: database.getAppUsageDaily(childId: childId, dateId: dateId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return JHEmptyContent(
            title: 'Error',
            message: snapshot.error.toString(),
          );
        }
        final doc = snapshot.data;
        final total = (doc?['totalMinutes'] as num?)?.toInt() ?? 0;
        final rawByApp = doc?['byApp'];
        final byApp = <String, int>{};
        if (rawByApp is Map) {
          for (final e in rawByApp.entries) {
            byApp[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
          }
        }
        final sorted = byApp.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (total == 0 && sorted.isEmpty) {
          return const JHEmptyContent(
            title: 'No usage today',
            message: 'Daily totals sync every ~10 min from the child device.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            JHDisplayText(
              text: '$total min',
              fontSize: 48,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: CustomColors.indigoPrimary,
              ),
            ),
            Text(
              dateId,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 24),
            ...sorted.map(
              (e) => ListTile(
                leading: const Icon(Icons.android),
                title: Text(displayNameForPackage(e.key)),
                trailing: Text('${e.value} min'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekTab extends StatelessWidget {
  const _WeekTab({
    required this.database,
    required this.childId,
  });

  final Database database;
  final String childId;

  @override
  Widget build(BuildContext context) {
    final dateIds = lastNDailyDateIds(days: 7);
    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: database.getAppUsageDailyRange(
        childId: childId,
        dateIds: dateIds,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return JHEmptyContent(
            title: 'Error',
            message: snapshot.error.toString(),
          );
        }
        final summary = aggregateDailyDocs(dateIds, snapshot.data ?? []);
        final maxY = summary.dailyTotals
            .map((d) => d.totalMinutes)
            .fold<int>(0, (a, b) => a > b ? a : b);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            JHDisplayText(
              text: '${summary.totalMinutes} min total',
              fontSize: 28,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: (maxY > 0 ? maxY : 1) * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= dateIds.length) {
                            return const SizedBox.shrink();
                          }
                          final d = DateTime.parse(dateIds[i]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('E').format(d),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barGroups: List.generate(summary.dailyTotals.length, (i) {
                    final mins = summary.dailyTotals[i].totalMinutes;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: mins.toDouble(),
                          color: CustomColors.greenPrimary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
