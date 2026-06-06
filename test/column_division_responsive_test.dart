import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumo_app/core/sum_generator.dart';
import 'package:sumo_app/features/algorithm/widgets/column_division_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SafeArea(child: child),
    ),
  );
}

void main() {
  testWidgets('división experto cabe en pantalla de 360px sin overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Caso ancho: dividendo de 5 dígitos, cociente de 4 dígitos.
    await tester.pumpWidget(_wrap(ColumnDivisionWidget(
      problem: SumProblem(72000, 18, operation: OperationType.division),
      onCompleted: (_) {},
    )));
    await tester.pumpAndSettle();

    // Sin excepciones de overflow al renderizar.
    expect(tester.takeException(), isNull);
  });

  testWidgets('división con decimales cabe en 360px sin overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 9001 ÷ 8 = 1125,125 → 4 dígitos enteros + coma + 3 decimales.
    await tester.pumpWidget(_wrap(ColumnDivisionWidget(
      problem: SumProblem(9001, 8, operation: OperationType.division),
      onCompleted: (_) {},
      decimalMode: true,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('en pantalla ancha mantiene tamaño máximo de celda',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ColumnDivisionWidget(
      problem: SumProblem(72, 8, operation: OperationType.division),
      onCompleted: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
