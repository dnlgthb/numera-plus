import 'dart:math';

enum Difficulty {
  easy,    // 1 digit (1-9)
  medium,  // 2 digits (10-99)
  hard,    // 3 digits (100-999)
  expert,  // 4 digits (1000-9999)
}

enum OperationType { sum, subtraction, multiplication, division }

class SumProblem {
  final int a;
  final int b;
  final OperationType operation;

  int get answer => switch (operation) {
    OperationType.sum => a + b,
    OperationType.subtraction => a - b,
    OperationType.multiplication => a * b,
    OperationType.division => a ~/ b,
  };
  String get operatorSymbol => switch (operation) {
    OperationType.sum => '+',
    OperationType.subtraction => '−',
    OperationType.multiplication => '×',
    OperationType.division => '÷',
  };

  SumProblem(this.a, this.b, {this.operation = OperationType.sum});
}

class SumGenerator {
  static final _random = Random();

  static SumProblem generate(Difficulty difficulty, {OperationType operation = OperationType.sum}) {
    if (operation == OperationType.multiplication) {
      return _generateMultiplication(difficulty);
    }
    if (operation == OperationType.subtraction) {
      return _generateSubtraction(difficulty);
    }
    if (operation == OperationType.division) {
      return _generateDivision(difficulty);
    }

    final range = switch (difficulty) {
      Difficulty.easy => (min: 1, max: 9),
      Difficulty.medium => (min: 10, max: 99),
      Difficulty.hard => (min: 100, max: 999),
      Difficulty.expert => (min: 1000, max: 9999),
    };

    final a = _random.nextInt(range.max - range.min + 1) + range.min;
    final b = _random.nextInt(range.max - range.min + 1) + range.min;
    return SumProblem(a, b, operation: operation);
  }

  static SumProblem _generateSubtraction(Difficulty difficulty) {
    final range = switch (difficulty) {
      Difficulty.easy => (min: 1, max: 9),
      Difficulty.medium => (min: 10, max: 99),
      Difficulty.hard => (min: 100, max: 999),
      Difficulty.expert => (min: 1000, max: 9999),
    };

    var a = _random.nextInt(range.max - range.min + 1) + range.min;
    var b = _random.nextInt(range.max - range.min + 1) + range.min;
    if (a < b) {
      final temp = a;
      a = b;
      b = temp;
    }
    if (a == b) a += 1;
    return SumProblem(a, b, operation: OperationType.subtraction);
  }

  static SumProblem _generateDivision(Difficulty difficulty) {
    int divisor, quotient;
    switch (difficulty) {
      case Difficulty.easy:
        divisor = _random.nextInt(8) + 2;
        quotient = _random.nextInt(9) + 2;
      case Difficulty.medium:
        divisor = _random.nextInt(8) + 2;
        quotient = _random.nextInt(89) + 11;
      case Difficulty.hard:
        divisor = _random.nextDouble() < 0.8
            ? _random.nextInt(8) + 2
            : _random.nextInt(18) + 12;
        quotient = _random.nextDouble() < 0.4
            ? _random.nextInt(90) + 10
            : _random.nextInt(900) + 100;
      case Difficulty.expert:
        divisor = _random.nextDouble() < 0.7
            ? _random.nextInt(8) + 2
            : _random.nextInt(18) + 12;
        quotient = _random.nextDouble() < 0.3
            ? _random.nextInt(900) + 100
            : _random.nextInt(9000) + 1000;
    }
    if (difficulty != Difficulty.easy && _random.nextDouble() < 0.30) {
      quotient = _forceZeroInQuotient(quotient);
    }
    final dividend = divisor * quotient;
    return SumProblem(dividend, divisor, operation: OperationType.division);
  }

  static SumProblem _generateCombatDivision(int completed) {
    final isRound2 = completed >= 18;
    int divisor, quotient;

    if (!isRound2) {
      // Round 1: dividendos de 2 dígitos
      divisor = _random.nextInt(8) + 2; // 2-9
      quotient = _random.nextInt(9) + 2; // 2-10
    } else {
      // Round 2: dividendos de 3 dígitos, 4 solo si terminan en 0
      divisor = _random.nextInt(8) + 2; // 2-9
      final roll = _random.nextDouble();
      if (roll < 0.7) {
        // 3 dígitos en el dividendo
        final minQ = (100 / divisor).ceil();
        final maxQ = (999 / divisor).floor();
        quotient = _random.nextInt(maxQ - minQ + 1) + minQ;
      } else {
        // 4 dígitos en el dividendo, pero termina en 0
        final minQ = (1000 / divisor).ceil();
        final maxQ = (9999 / divisor).floor();
        quotient = _random.nextInt(maxQ - minQ + 1) + minQ;
        final dividend = divisor * quotient;
        if (dividend % 10 != 0) {
          // Forzar que termine en 0: buscar un cociente cercano cuyo producto termine en 0
          for (int q = quotient; q <= maxQ; q++) {
            if ((divisor * q) % 10 == 0) {
              quotient = q;
              break;
            }
          }
        }
      }
    }

    final dividend = divisor * quotient;
    return SumProblem(dividend, divisor, operation: OperationType.division);
  }

  static int _forceZeroInQuotient(int q) {
    final digits = q.toString().split('').map(int.parse).toList();
    if (digits.length < 2) return q;
    final pos = _random.nextInt(digits.length - 1) + 1;
    digits[pos] = 0;
    return int.parse(digits.join());
  }

  static SumProblem _generateMultiplication(Difficulty difficulty) {
    int a, b;
    switch (difficulty) {
      case Difficulty.easy:
        // 1d × 1d
        a = _random.nextInt(9) + 2;
        b = _random.nextInt(9) + 2;
      case Difficulty.medium:
        // 2d × 1d
        a = _random.nextInt(90) + 10;
        b = _random.nextInt(9) + 2;
      case Difficulty.hard:
        // 2d × 2d
        a = _random.nextInt(90) + 10;
        b = _random.nextInt(90) + 10;
      case Difficulty.expert:
        // 3d × 2d or 3d × 3d
        a = _random.nextInt(900) + 100;
        b = _random.nextDouble() < 0.6
            ? _random.nextInt(90) + 10
            : _random.nextInt(900) + 100;
    }
    return SumProblem(a, b, operation: OperationType.multiplication);
  }

  static SumProblem _generateDecimalDivision(Difficulty difficulty) {
    const easyDivisors = [2, 4, 5];
    const allDivisors = [2, 4, 5, 8];

    int divisor, intQuotient, remainder;

    switch (difficulty) {
      case Difficulty.easy:
        divisor = easyDivisors[_random.nextInt(easyDivisors.length)];
        intQuotient = _random.nextInt(8) + 2;
        remainder = _random.nextInt(divisor - 1) + 1;
      case Difficulty.medium:
        divisor = easyDivisors[_random.nextInt(easyDivisors.length)];
        intQuotient = _random.nextInt(89) + 11;
        remainder = _random.nextInt(divisor - 1) + 1;
      case Difficulty.hard:
        divisor = allDivisors[_random.nextInt(allDivisors.length)];
        intQuotient = _random.nextDouble() < 0.6
            ? _random.nextInt(90) + 10
            : _random.nextInt(900) + 100;
        remainder = _random.nextInt(divisor - 1) + 1;
      case Difficulty.expert:
        divisor = allDivisors[_random.nextInt(allDivisors.length)];
        intQuotient = _random.nextDouble() < 0.3
            ? _random.nextInt(900) + 100
            : _random.nextInt(9000) + 1000;
        remainder = _random.nextInt(divisor - 1) + 1;
    }

    final dividend = divisor * intQuotient + remainder;
    return SumProblem(dividend, divisor, operation: OperationType.division);
  }

  static SumProblem generateProgressive(int completed, {OperationType operation = OperationType.sum, bool decimal = false}) {
    final roll = _random.nextDouble();

    Difficulty difficulty;
    if (operation == OperationType.division) {
      if (completed < 2) {
        difficulty = Difficulty.easy;
      } else if (completed < 4) {
        difficulty = roll < 0.2 ? Difficulty.easy : Difficulty.medium;
      } else if (completed < 8) {
        if (roll < 0.05) {
          difficulty = Difficulty.easy;
        } else if (roll < 0.25) {
          difficulty = Difficulty.medium;
        } else {
          difficulty = Difficulty.hard;
        }
      } else {
        if (roll < 0.05) {
          difficulty = Difficulty.medium;
        } else if (roll < 0.45) {
          difficulty = Difficulty.hard;
        } else {
          difficulty = Difficulty.expert;
        }
      }
    } else if (operation == OperationType.multiplication) {
      // Multiplication: ramp up fast to 2d×2d, then 3d×2d/3d×3d
      if (completed < 2) {
        difficulty = Difficulty.easy;
      } else if (completed < 3) {
        difficulty = roll < 0.3 ? Difficulty.easy : Difficulty.medium;
      } else if (completed < 6) {
        if (roll < 0.10) {
          difficulty = Difficulty.easy;
        } else if (roll < 0.30) {
          difficulty = Difficulty.medium;
        } else {
          difficulty = Difficulty.hard;
        }
      } else if (completed < 12) {
        if (roll < 0.05) {
          difficulty = Difficulty.easy;
        } else if (roll < 0.15) {
          difficulty = Difficulty.medium;
        } else if (roll < 0.55) {
          difficulty = Difficulty.hard;
        } else {
          difficulty = Difficulty.expert;
        }
      } else {
        if (roll < 0.05) {
          difficulty = Difficulty.medium;
        } else if (roll < 0.35) {
          difficulty = Difficulty.hard;
        } else {
          difficulty = Difficulty.expert;
        }
      }
    } else if (completed < 2) {
      difficulty = Difficulty.easy;
    } else if (completed < 5) {
      difficulty = roll < 0.3 ? Difficulty.easy : Difficulty.medium;
    } else if (completed < 10) {
      if (roll < 0.10) {
        difficulty = Difficulty.easy;
      } else if (roll < 0.55) {
        difficulty = Difficulty.medium;
      } else {
        difficulty = Difficulty.hard;
      }
    } else if (completed < 18) {
      if (roll < 0.05) {
        difficulty = Difficulty.easy;
      } else if (roll < 0.30) {
        difficulty = Difficulty.medium;
      } else if (roll < 0.75) {
        difficulty = Difficulty.hard;
      } else {
        difficulty = Difficulty.expert;
      }
    } else {
      if (roll < 0.05) {
        difficulty = Difficulty.easy;
      } else if (roll < 0.20) {
        difficulty = Difficulty.medium;
      } else if (roll < 0.60) {
        difficulty = Difficulty.hard;
      } else {
        difficulty = Difficulty.expert;
      }
    }

    if (decimal && operation == OperationType.division) {
      return _generateDecimalDivision(difficulty);
    }
    return generate(difficulty, operation: operation);
  }

  static SumProblem generateCombat(int completed, {OperationType operation = OperationType.sum}) {
    if (operation == OperationType.division) {
      return _generateCombatDivision(completed);
    }
    if (operation == OperationType.sum || operation == OperationType.subtraction) {
      return generateProgressive(completed, operation: operation);
    }
    final roll = _random.nextDouble();
    int a;
    final b = _random.nextInt(8) + 2;

    if (completed < 3) {
      a = _random.nextInt(9) + 2;
    } else if (completed < 7) {
      a = roll < 0.3 ? _random.nextInt(9) + 2 : _random.nextInt(90) + 10;
    } else if (completed < 14) {
      if (roll < 0.15) {
        a = _random.nextInt(9) + 2;
      } else if (roll < 0.6) {
        a = _random.nextInt(90) + 10;
      } else {
        a = _random.nextInt(900) + 100;
      }
    } else {
      if (roll < 0.3) {
        a = _random.nextInt(90) + 10;
      } else {
        a = _random.nextInt(900) + 100;
      }
    }
    return SumProblem(a, b, operation: OperationType.multiplication);
  }

  static String difficultyLabel(Difficulty d) {
    return switch (d) {
      Difficulty.easy => '1 digito',
      Difficulty.medium => '2 digitos',
      Difficulty.hard => '3 digitos',
      Difficulty.expert => '4 digitos',
    };
  }
}
