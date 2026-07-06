import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:times_up_flutter/theme/theme.dart';
import 'package:times_up_flutter/widgets/jh_display_text.dart';

/// Line chart fed by pre-built [spots] and X-axis [labels].
/// Data source is chosen by the caller (e.g. [appsUsageModel] on child details).
class JHLineChart extends StatelessWidget {
  const JHLineChart({
    required this.spots,
    required this.labels,
    this.emptyMessage,
    Key? key,
  }) : super(key: key);

  final List<FlSpot> spots;
  final List<String> labels;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return Center(
        child: JHDisplayText(
          text: emptyMessage ?? 'No hay datos disponibles',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final maxY = _maxYFromSpots(spots);
    final maxX = spots.length > 1 ? spots.length - 1.0 : 1.0;

    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: _titlesData(maxY),
        borderData: _borderData,
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: CustomColors.greenPrimary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: CustomColors.indigoDark.withOpacity(0.15),
            ),
            spots: spots,
          ),
        ],
        minX: 0,
        maxX: maxX,
        maxY: maxY * 1.2,
        minY: 0,
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  FlTitlesData _titlesData(double maxY) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= labels.length) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8,
              child: Text(
                labels[index],
                style: _axisStyle,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: maxY > 5 ? (maxY / 4).ceilToDouble() : 1,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value <= 0) return const SizedBox.shrink();
            return Text(
              '${value.toInt()}m',
              style: _axisStyle,
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  static double _maxYFromSpots(List<FlSpot> spots) {
    final max = spots.map((s) => s.y).fold<double>(0, (p, v) => v > p ? v : p);
    return max > 0 ? max : 1;
  }

  static const _axisStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);

  FlBorderData get _borderData => FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: CustomColors.indigoDark.withOpacity(0.2),
            width: 4,
          ),
          left: const BorderSide(color: Colors.transparent),
          right: const BorderSide(color: Colors.transparent),
          top: const BorderSide(color: Colors.transparent),
        ),
      );
}
