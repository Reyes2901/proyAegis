import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/widgets/jh_display_text.dart';
import 'package:times_up_flutter/widgets/jh_line_chart.dart';

void main() {
  testWidgets('JHLineChart shows empty message when spots is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JHLineChart(
            spots: [],
            labels: [],
            emptyMessage: 'No hay datos disponibles',
          ),
        ),
      ),
    );

    expect(find.text('No hay datos disponibles'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('JHLineChart renders chart when spots has data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: JHLineChart(
              spots: [FlSpot(0, 5), FlSpot(1, 10)],
              labels: ['App1', 'App2'],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(JHDisplayText), findsNothing);
  });
}
