import 'package:flutter_test/flutter_test.dart';
import 'package:sumo_app/core/sum_generator.dart';

void main() {
  test('ronda 2 de combate división: 3 dígitos y resoluble mentalmente', () {
    for (int i = 0; i < 500; i++) {
      final p = SumGenerator.generateCombat(20,
          operation: OperationType.division);
      final dividend = p.a;
      final divisor = p.b;
      final quotient = p.answer;

      // División exacta
      expect(dividend % divisor, 0,
          reason: '$dividend ÷ $divisor no es exacta');
      // Dividendo siempre de 3 dígitos
      expect(dividend, inInclusiveRange(100, 999),
          reason: '$dividend ÷ $divisor no es de 3 dígitos');

      // Resoluble mentalmente: o es "tabla + cero" (cociente termina en 0 y
      // el factor está en las tablas), o cada cifra del dividendo se divide
      // exacta entre el divisor (sin acarreo)
      final tablaMasCero = quotient % 10 == 0 && quotient ~/ 10 <= 9;
      final sinAcarreo = dividend
          .toString()
          .split('')
          .every((d) => int.parse(d) % divisor == 0);
      expect(tablaMasCero || sinAcarreo, isTrue,
          reason: '$dividend ÷ $divisor = $quotient no es mental-friendly');
    }
  });

  test('ronda 1 de combate división: dividendos de 2 dígitos', () {
    for (int i = 0; i < 200; i++) {
      final p =
          SumGenerator.generateCombat(5, operation: OperationType.division);
      expect(p.a % p.b, 0);
      expect(p.a, lessThan(100), reason: '${p.a} ÷ ${p.b}');
    }
  });
}
