import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';

const double _cellSize = 52;
const double _cellGap = 4;
const double _carrySize = 32;

/// Evaluation mode widget: carries are optional, only the final answer is
/// validated when the user presses "Enviar". No immediate feedback per digit.
class EvalSumWidget extends StatefulWidget {
  final SumProblem problem;

  /// Called with true/false when the user submits their answer.
  final ValueChanged<bool> onSubmitted;

  /// Called when the user drops a digit on an error (not used here, but kept
  /// for interface parity – errors are only counted on submit).
  final VoidCallback? onError;

  const EvalSumWidget({
    super.key,
    required this.problem,
    required this.onSubmitted,
    this.onError,
  });

  @override
  State<EvalSumWidget> createState() => _EvalSumWidgetState();
}

class _EvalSumWidgetState extends State<EvalSumWidget> {
  late List<int> _digitsA;
  late List<int> _digitsB;
  late List<int> _digitsAnswer;
  late List<int> _carries;
  late List<int?> _userAnswer;
  late List<int?> _userCarries;
  int _maxLen = 0;
  bool _submitted = false;
  bool? _wasCorrect;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final a = widget.problem.a;
    final b = widget.problem.b;
    final answer = widget.problem.answer;

    final ansStr = answer.toString();

    _maxLen = ansStr.length;

    if (widget.problem.operation == OperationType.division) {
      _digitsA = a.toString().split('').map((c) => int.parse(c)).toList();
      _digitsB = b.toString().split('').map((c) => int.parse(c)).toList();
    } else {
      _digitsA = _padDigits(a.toString(), _maxLen);
      _digitsB = _padDigits(b.toString(), _maxLen);
    }
    _digitsAnswer = _padDigits(ansStr, _maxLen);

    _carries = List.filled(_maxLen, 0);
    int carry = 0;
    if (widget.problem.operation == OperationType.sum) {
      for (int i = _maxLen - 1; i >= 0; i--) {
        final colSum = _digitsA[i] + _digitsB[i] + carry;
        final newCarry = colSum ~/ 10;
        if (i > 0) _carries[i - 1] = newCarry;
        carry = newCarry;
      }
    }

    _userAnswer = List.filled(_maxLen, null);
    _userCarries = List.filled(_maxLen, null);
    _submitted = false;
    _wasCorrect = null;
  }

  List<int> _padDigits(String numStr, int len) {
    final padded = numStr.padLeft(len, '0');
    return padded.split('').map((c) => int.parse(c)).toList();
  }

  // In eval mode, the next empty answer slot (right to left) is active.
  // Carries are always droppable (optional) but answer slots take priority.
  int? get _nextAnswerCol {
    for (int col = _maxLen - 1; col >= 0; col--) {
      if (_userAnswer[col] == null) return col;
    }
    return null;
  }

  bool get _allAnswersFilled => _nextAnswerCol == null;

  void _onDropOnAnswer(int col, int digit) {
    if (_submitted) return;
    // Allow dropping on current active slot OR replacing any filled slot
    if (_userAnswer[col] == null && col != _nextAnswerCol) return;

    setState(() {
      _userAnswer[col] = digit;
    });
  }

  void _onDropOnCarry(int col, int digit) {
    if (_submitted) return;
    // Always allow replacing carries
    setState(() {
      _userCarries[col] = digit;
    });
  }

  void _onClearAnswer(int col) {
    if (_submitted) return;
    if (_userAnswer[col] != null) {
      setState(() {
        _userAnswer[col] = null;
      });
    }
  }

  void _onClearCarry(int col) {
    if (_submitted) return;
    setState(() {
      _userCarries[col] = null;
    });
  }

  void _onSubmit() {
    if (!_allAnswersFilled || _submitted) return;

    final correct = List.generate(_maxLen, (i) => _userAnswer[i])
        .every((d) => d != null) &&
        List.generate(_maxLen, (i) => _userAnswer[i] == _digitsAnswer[i])
            .every((v) => v);

    setState(() {
      _submitted = true;
      _wasCorrect = correct;
    });

    widget.onSubmitted(correct);
  }

  bool get _isMultiplication =>
      widget.problem.operation == OperationType.multiplication;

  bool get _isDivision =>
      widget.problem.operation == OperationType.division;

  Color _getColumnColor(int col) {
    final pos = _maxLen - 1 - col;
    return switch (pos) {
      0 => AppColors.units,
      1 => AppColors.tens,
      2 => AppColors.hundreds,
      _ => AppColors.thousands,
    };
  }

  @override
  Widget build(BuildContext context) {
    final gridWidth = _maxLen * (_cellSize + _cellGap * 2);
    final mulExtra = _isMultiplication
        ? (widget.problem.b.toString().length.clamp(1, 9) * 16.0) + 48
        : _isDivision
            ? (widget.problem.b.toString().length.clamp(1, 9) * 16.0) + 48
            : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sum container – dark themed
        Container(
          padding: EdgeInsets.fromLTRB(32, 12, 24 + mulExtra, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isMultiplication) ...[
                _buildMultiplicationProblemRow(gridWidth),
              ] else if (_isDivision) ...[
                _buildDivisionProblemRow(gridWidth),
              ] else ...[
                _buildCarryRow(gridWidth),
                const SizedBox(height: 4),
                _buildNumberRow(_digitsA, gridWidth),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.problem.operatorSymbol,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8888AA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildNumberRow(_digitsB, gridWidth),
                  ],
                ),
              ],
              Container(
                width: gridWidth + 40,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF555577),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildAnswerRow(gridWidth),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Result feedback after submit
        if (_submitted) _buildResultFeedback(),

        // Submit button or digit palette
        if (!_submitted) ...[
          if (_allAnswersFilled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'ENVIAR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          _buildDigitPalette(),
        ],
      ],
    );
  }

  Widget _buildResultFeedback() {
    final correct = _wasCorrect ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: correct ? AppColors.correct : AppColors.incorrect,
            size: 48,
          ),
          if (!correct) ...[
            const SizedBox(height: 8),
            Text(
              'Respuesta correcta: ${widget.problem.answer}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.incorrect,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiplicationProblemRow(double gridWidth) {
    final a = widget.problem.a > widget.problem.b
        ? widget.problem.a
        : widget.problem.b;
    final b = widget.problem.a > widget.problem.b
        ? widget.problem.b
        : widget.problem.a;
    final aDigits = a.toString().split('').map(int.parse).toList();
    final bStr = b.toString();
    final extraRight = (bStr.length * 16.0) + 48;

    return Padding(
      padding: EdgeInsets.only(right: extraRight),
      child: SizedBox(
        width: gridWidth,
        height: _cellSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(_maxLen, (gridCol) {
                final idx = gridCol - (_maxLen - aDigits.length);
                final show = idx >= 0 && idx < aDigits.length;
                return Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                  alignment: Alignment.center,
                  child: show
                      ? Text(
                          '${aDigits[idx]}',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE0E0F0),
                          ),
                        )
                      : null,
                );
              }),
            ),
            Positioned(
              right: -extraRight + 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  '× $bStr',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8888AA),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivisionProblemRow(double gridWidth) {
    final dividendStr = widget.problem.a.toString();
    final divisorStr = widget.problem.b.toString();
    final extraRight = (divisorStr.length * 16.0) + 48;

    return Padding(
      padding: EdgeInsets.only(right: extraRight),
      child: SizedBox(
        width: gridWidth,
        height: _cellSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(_maxLen, (gridCol) {
                final idx = gridCol - (_maxLen - dividendStr.length);
                final show = idx >= 0 && idx < dividendStr.length;
                return Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                  alignment: Alignment.center,
                  child: show
                      ? Text(
                          dividendStr[idx],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE0E0F0),
                          ),
                        )
                      : null,
                );
              }),
            ),
            Positioned(
              right: -extraRight + 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  '÷ $divisorStr',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8888AA),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<int> digits, double gridWidth) {
    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (i) {
          final isLeadingZero = digits[i] == 0 &&
              i < _maxLen - 1 &&
              digits.sublist(0, i + 1).every((d) => d == 0);

          return Container(
            width: _cellSize,
            height: _cellSize,
            margin: const EdgeInsets.symmetric(horizontal: _cellGap),
            alignment: Alignment.center,
            child: Text(
              isLeadingZero ? '' : '${digits[i]}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE0E0F0),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCarryRow(double gridWidth) {
    return SizedBox(
      width: gridWidth,
      height: _carrySize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          // Rightmost column (units) never needs a carry into it
          if (col == _maxLen - 1) {
            return SizedBox(
              width: _cellSize + _cellGap * 2,
              height: _carrySize,
            );
          }

          final isFilled = _userCarries[col] != null;

          final defaultCarry = GestureDetector(
            onDoubleTap: isFilled ? () => _onClearCarry(col) : null,
            child: Container(
              width: _carrySize,
              height: _carrySize,
              margin: const EdgeInsets.symmetric(
                horizontal: (_cellSize - _carrySize) / 2 + _cellGap,
              ),
              decoration: BoxDecoration(
                color: isFilled
                    ? const Color(0xFF3A3A5C)
                    : const Color(0xFF2A2A40),
                borderRadius: BorderRadius.circular(8),
                border: !isFilled && !_submitted
                    ? Border.all(
                        color: const Color(0xFF444466),
                        width: 1,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: isFilled
                  ? Text(
                      '${_userCarries[col]}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9999BB),
                      ),
                    )
                  : null,
            ),
          );

          if (isFilled || _submitted) return defaultCarry;

          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) =>
                _onDropOnCarry(col, details.data),
            builder: (context, candidateData, _) {
              if (candidateData.isNotEmpty) {
                return Container(
                  width: _carrySize,
                  height: _carrySize,
                  margin: const EdgeInsets.symmetric(
                    horizontal: (_cellSize - _carrySize) / 2 + _cellGap,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A5C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6C5CE7),
                      width: 2,
                    ),
                  ),
                );
              }
              return defaultCarry;
            },
          );
        }),
      ),
    );
  }

  Widget _buildAnswerRow(double gridWidth) {
    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          final isFilled = _userAnswer[col] != null;
          final isActive = col == _nextAnswerCol && !_submitted;
          final color = _getColumnColor(col);

          // After submit, show correct/incorrect per digit
          Color? digitColor;
          if (_submitted && isFilled) {
            digitColor = _userAnswer[col] == _digitsAnswer[col]
                ? AppColors.correct
                : AppColors.incorrect;
          }

          final defaultAnswer = GestureDetector(
            onDoubleTap: isFilled && !_submitted
                ? () => _onClearAnswer(col)
                : null,
            child: Container(
              width: _cellSize,
              height: _cellSize,
              margin: const EdgeInsets.symmetric(horizontal: _cellGap),
              decoration: BoxDecoration(
                color: isFilled
                    ? (_submitted
                        ? (digitColor == AppColors.correct
                            ? AppColors.correct.withValues(alpha: 0.15)
                            : AppColors.incorrect.withValues(alpha: 0.15))
                        : const Color(0xFF2A2A40))
                    : isActive
                        ? color.withValues(alpha: 0.1)
                        : const Color(0xFF222236),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _submitted && isFilled
                      ? digitColor!
                      : isActive
                          ? color
                          : const Color(0xFF444466),
                  width: isActive ? 2.5 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isFilled
                  ? Text(
                      '${_userAnswer[col]}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: _submitted
                            ? digitColor!
                            : const Color(0xFFE0E0F0),
                      ),
                    )
                  : isActive
                      ? Icon(
                          Icons.arrow_downward_rounded,
                          size: 20,
                          color: color.withValues(alpha: 0.5),
                        )
                      : null,
            ),
          );

          // Allow drop on active slot OR any filled slot (to replace)
          if (_submitted || (!isActive && !isFilled)) return defaultAnswer;

          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) =>
                _onDropOnAnswer(col, details.data),
            builder: (context, candidateData, _) {
              if (candidateData.isNotEmpty) {
                return Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, color: color, size: 24),
                );
              }
              return defaultAnswer;
            },
          );
        }),
      ),
    );
  }

  Widget _buildDigitPalette() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(10, (digit) {
        return Draggable<int>(
          data: digit,
          feedback: _DragDigitFeedback(digit: digit),
          childWhenDragging: _DigitChip(digit: digit, dimmed: true),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          child: _DigitChip(digit: digit),
        );
      }),
    );
  }
}

// --- Dark-themed helper widgets ---

class _DigitChip extends StatelessWidget {
  final int digit;
  final bool dimmed;

  const _DigitChip({required this.digit, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 52,
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFF2A2A40) : const Color(0xFF2E2E48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dimmed ? Colors.transparent : const Color(0xFF444466),
          width: 1.5,
        ),
        boxShadow: dimmed
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$digit',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: dimmed ? const Color(0xFF555577) : const Color(0xFFCCCCEE),
        ),
      ),
    );
  }
}

class _DragDigitFeedback extends StatelessWidget {
  final int digit;

  const _DragDigitFeedback({required this.digit});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$digit',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
