import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';

const double _cellSize = 52;
const double _cellGap = 4;
const double _carrySize = 32;

class ColumnSumWidget extends StatefulWidget {
  final SumProblem problem;
  final ValueChanged<bool> onCompleted;
  final VoidCallback? onError;

  const ColumnSumWidget({
    super.key,
    required this.problem,
    required this.onCompleted,
    this.onError,
  });

  @override
  State<ColumnSumWidget> createState() => _ColumnSumWidgetState();
}

class _ColumnSumWidgetState extends State<ColumnSumWidget> {
  late List<int> _digitsA;
  late List<int> _digitsB;
  late List<int> _digitsAnswer;
  late List<int> _carries; // carry INTO column i (from column i+1)
  late List<int?> _userAnswer;
  late List<int?> _userCarries;
  int _maxLen = 0;
  int _answerLen = 0;
  bool _completed = false;

  // Tracks which slot is shaking on wrong drop
  String? _shakeSlot; // "answer-0", "carry-0", etc.

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final a = widget.problem.a;
    final b = widget.problem.b;
    final answer = widget.problem.answer;

    final aStr = a.toString();
    final bStr = b.toString();
    final ansStr = answer.toString();

    _answerLen = ansStr.length;
    // maxLen is the answer length (could be 1 more than operands)
    _maxLen = _answerLen;

    _digitsA = _padDigits(aStr, _maxLen);
    _digitsB = _padDigits(bStr, _maxLen);
    _digitsAnswer = _padDigits(ansStr, _maxLen);

    // Calculate carries: _carries[i] = carry produced by column i going into column i-1
    // We store it as: carry that arrives at column i (from column i+1)
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
    _completed = false;
  }

  List<int> _padDigits(String numStr, int len) {
    final padded = numStr.padLeft(len, '0');
    return padded.split('').map((c) => int.parse(c)).toList();
  }

  /// Check if a carry slot at column [col] needs to be filled
  bool _carryNeeded(int col) => _carries[col] > 0;

  /// Check if a carry slot at column [col] has been filled
  bool _carryFilled(int col) => _userCarries[col] != null;

  /// Check if answer slot at column [col] has been filled
  bool _answerFilled(int col) => _userAnswer[col] != null;

  /// Determine the next slot that needs filling (right to left, answer then carry)
  /// Returns null if all filled
  _SlotInfo? get _nextSlot {
    for (int col = _maxLen - 1; col >= 0; col--) {
      if (!_answerFilled(col)) {
        return _SlotInfo(type: _SlotType.answer, col: col);
      }
      // Require intermediate carries, but the leftmost carry is optional
      if (col > 1 && _carryNeeded(col - 1) && !_carryFilled(col - 1)) {
        return _SlotInfo(type: _SlotType.carry, col: col - 1);
      }
    }
    return null;
  }

  bool _isActiveSlot(_SlotType type, int col) {
    final next = _nextSlot;
    if (next != null && next.type == type && next.col == col) return true;
    // The leftmost carry is optional: active alongside the last answer digit
    if (type == _SlotType.carry && col == 0 && _carryNeeded(0) && !_carryFilled(0)) {
      if (next == null || (next.type == _SlotType.answer && next.col == 0)) {
        return true;
      }
    }
    return false;
  }

  void _onDropOnAnswer(int col, int digit) {
    if (_completed || _answerFilled(col)) return;
    if (!_isActiveSlot(_SlotType.answer, col)) return;

    if (digit == _digitsAnswer[col]) {
      setState(() {
        _userAnswer[col] = digit;
        _shakeSlot = null;
      });
      _checkCompleted();
    } else {
      _triggerShake('answer-$col');
      widget.onError?.call();
    }
  }

  void _onDropOnCarry(int col, int digit) {
    if (_completed || _carryFilled(col)) return;
    if (!_isActiveSlot(_SlotType.carry, col)) return;

    if (digit == _carries[col]) {
      setState(() {
        _userCarries[col] = digit;
        _shakeSlot = null;
      });
      _checkCompleted();
    } else {
      _triggerShake('carry-$col');
      widget.onError?.call();
    }
  }

  void _triggerShake(String slot) {
    setState(() => _shakeSlot = slot);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shakeSlot = null);
    });
  }

  void _checkCompleted() {
    if (_nextSlot == null) {
      setState(() => _completed = true);
      widget.onCompleted(true);
    }
  }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Paper-like sum container
        Container(
          padding: const EdgeInsets.fromLTRB(32, 12, 24, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.algorithm.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Carry row
              _buildCarryRow(gridWidth),
              const SizedBox(height: 4),
              // Number A - right aligned
              _buildNumberRow(_digitsA, gridWidth),
              const SizedBox(height: 2),
              // Number B with + sign
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.problem.operatorSymbol,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildNumberRow(_digitsB, gridWidth),
                ],
              ),
              // Divider line
              Container(
                width: gridWidth + 40,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Answer row (drop targets)
              _buildAnswerRow(gridWidth),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Draggable digit palette
        if (!_completed) _buildDigitPalette(),
        if (_completed)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.correct,
              size: 48,
            ),
          ),
      ],
    );
  }

  /// Row showing the given number's digits, right-aligned
  Widget _buildNumberRow(List<int> digits, double gridWidth) {
    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (i) {
          // Hide leading zeros
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
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Row of carry drop targets
  Widget _buildCarryRow(double gridWidth) {
    return SizedBox(
      width: gridWidth,
      height: _carrySize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          if (!_carryNeeded(col)) {
            return SizedBox(
              width: _cellSize + _cellGap * 2,
              height: _carrySize,
            );
          }

          final isFilled = _carryFilled(col);
          final isActive = _isActiveSlot(_SlotType.carry, col);
          final isShaking = _shakeSlot == 'carry-$col';
          final color = _getColumnColor(col);

          final defaultWidget = _AnimatedShake(
            shaking: isShaking,
            child: Container(
              width: _carrySize,
              height: _carrySize,
              margin: const EdgeInsets.symmetric(
                horizontal: (_cellSize - _carrySize) / 2 + _cellGap,
              ),
              decoration: BoxDecoration(
                color: isFilled
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : isActive
                        ? color.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isActive && !isFilled
                    ? Border.all(
                        color: AppColors.accent.withValues(alpha: 0.6),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: isFilled
                  ? Text(
                      '${_userCarries[col]}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    )
                  : isActive
                      ? Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: AppColors.accent.withValues(alpha: 0.5),
                        )
                      : null,
            ),
          );

          if (!isActive || isFilled) return defaultWidget;

          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) =>
                _onDropOnCarry(col, details.data),
            builder: (context, candidateData, rejectedData) {
              if (candidateData.isNotEmpty) {
                return _AnimatedShake(
                  shaking: isShaking,
                  child: Container(
                    width: _carrySize,
                    height: _carrySize,
                    margin: EdgeInsets.symmetric(
                      horizontal: (_cellSize - _carrySize) / 2 + _cellGap,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                  ),
                );
              }
              return defaultWidget;
            },
          );
        }),
      ),
    );
  }

  /// Row of answer drop targets
  Widget _buildAnswerRow(double gridWidth) {
    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          final isFilled = _answerFilled(col);
          final isActive = _isActiveSlot(_SlotType.answer, col);
          final isShaking = _shakeSlot == 'answer-$col';
          final color = _getColumnColor(col);

          final defaultWidget = _AnimatedShake(
            shaking: isShaking,
            child: Container(
              width: _cellSize,
              height: _cellSize,
              margin: const EdgeInsets.symmetric(horizontal: _cellGap),
              decoration: BoxDecoration(
                color: isFilled
                    ? color.withValues(alpha: 0.12)
                    : isActive
                        ? color.withValues(alpha: 0.08)
                        : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? color
                      : isFilled
                          ? color.withValues(alpha: 0.3)
                          : AppColors.textLight.withValues(alpha: 0.3),
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
                        color: color,
                      ),
                    )
                  : isActive
                      ? Icon(
                          Icons.arrow_downward_rounded,
                          size: 20,
                          color: color.withValues(alpha: 0.4),
                        )
                      : null,
            ),
          );

          if (!isActive || isFilled) return defaultWidget;

          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) =>
                _onDropOnAnswer(col, details.data),
            builder: (context, candidateData, rejectedData) {
              if (candidateData.isNotEmpty) {
                return _AnimatedShake(
                  shaking: isShaking,
                  child: Container(
                    width: _cellSize,
                    height: _cellSize,
                    margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                  );
                }
                return defaultWidget;
              },
            );
        }),
      ),
    );
  }

  /// Draggable digit palette at the bottom
  Widget _buildDigitPalette() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(10, (digit) {
        return Draggable<int>(
          data: digit,
          feedback: _DragDigitFeedback(digit: digit),
          childWhenDragging: _DigitChip(
            digit: digit,
            dimmed: true,
          ),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          child: _DigitChip(digit: digit),
        );
      }),
    );
  }
}

// --- Helper widgets ---

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
        color: dimmed
            ? AppColors.textLight.withValues(alpha: 0.15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dimmed
              ? Colors.transparent
              : AppColors.textLight.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: dimmed
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
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
          color: dimmed
              ? AppColors.textLight
              : AppColors.textPrimary,
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
          color: AppColors.primary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
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

/// Simple shake animation for wrong drops
class _AnimatedShake extends StatefulWidget {
  final bool shaking;
  final Widget child;

  const _AnimatedShake({required this.shaking, required this.child});

  @override
  State<_AnimatedShake> createState() => _AnimatedShakeState();
}

class _AnimatedShakeState extends State<_AnimatedShake>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _offsetAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shaking && !oldWidget.shaking) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnim.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// --- Data types ---

enum _SlotType { answer, carry }

class _SlotInfo {
  final _SlotType type;
  final int col;
  _SlotInfo({required this.type, required this.col});
}
