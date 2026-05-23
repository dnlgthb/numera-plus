import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';

const double _cellSize = 52;
const double _cellGap = 4;

class ColumnSubtractionWidget extends StatefulWidget {
  final SumProblem problem;
  final ValueChanged<bool> onCompleted;
  final VoidCallback? onError;
  final bool evalMode;

  const ColumnSubtractionWidget({
    super.key,
    required this.problem,
    required this.onCompleted,
    this.onError,
    this.evalMode = false,
  });

  @override
  State<ColumnSubtractionWidget> createState() => _ColumnSubtractionWidgetState();
}

enum _ColPhase { waiting, needsPedir, waitingReduced, waitingAnswer }

class _ColumnSubtractionWidgetState extends State<ColumnSubtractionWidget> {
  late List<int> _digitsA;
  late List<int> _digitsB;
  late int _maxLen;

  // Precomputed borrow info per column
  late List<bool> _needsBorrow;
  late List<int> _borrowSource; // which col provides the borrow (-1 if none)
  late List<List<int>> _cascadeCols; // zero-cols that become 9 during cascade
  late List<int> _expectedReduced; // what the source digit becomes
  late List<int> _expectedAnswer; // correct answer digit per col

  // Runtime state
  late List<int> _effectiveA; // current effective top digits
  late List<bool> _crossedOut; // whether original digit is crossed out
  late List<int?> _newDigitAbove; // reduced/cascade digit shown above
  late List<bool> _receivedBorrow; // whether column shows +10 prefix
  late List<int?> _userAnswer;
  int _currentCol = 0;
  _ColPhase _phase = _ColPhase.waiting;
  bool _completed = false;
  bool _submitted = false;
  bool? _wasCorrect;
  bool _shakingPedir = false;
  String? _shakeSlot;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final a = widget.problem.a;
    final b = widget.problem.b;

    final aStr = a.toString();
    final bStr = b.toString();

    _maxLen = aStr.length;
    _digitsA = _padDigits(aStr, _maxLen);
    _digitsB = _padDigits(bStr, _maxLen);

    _effectiveA = List.from(_digitsA);
    _crossedOut = List.filled(_maxLen, false);
    _newDigitAbove = List.filled(_maxLen, null);
    _receivedBorrow = List.filled(_maxLen, false);
    _userAnswer = List.filled(_maxLen, null);

    _precomputeBorrows();

    _currentCol = _maxLen - 1;
    _phase = _needsBorrow[_currentCol] ? _ColPhase.needsPedir : _ColPhase.waitingAnswer;
    _completed = false;
  }

  void _precomputeBorrows() {
    _needsBorrow = List.filled(_maxLen, false);
    _borrowSource = List.filled(_maxLen, -1);
    _cascadeCols = List.generate(_maxLen, (_) => <int>[]);
    _expectedReduced = List.filled(_maxLen, 0);
    _expectedAnswer = List.filled(_maxLen, 0);

    final sim = List<int>.from(_digitsA);

    for (int col = _maxLen - 1; col >= 0; col--) {
      if (sim[col] < _digitsB[col]) {
        _needsBorrow[col] = true;

        // Find source: nearest col to the left with sim > 0
        int source = col - 1;
        final cascade = <int>[];
        while (source >= 0 && sim[source] == 0) {
          cascade.add(source);
          source--;
        }
        _borrowSource[col] = source;
        _cascadeCols[col] = cascade;
        _expectedReduced[col] = sim[source] - 1;

        // Apply borrow in simulation
        sim[source] -= 1;
        for (final c in cascade) {
          sim[c] = 9;
        }
        sim[col] += 10;
      }
      _expectedAnswer[col] = sim[col] - _digitsB[col];
    }
  }

  List<int> _padDigits(String numStr, int len) {
    final padded = numStr.padLeft(len, '0');
    return padded.split('').map((c) => int.parse(c)).toList();
  }

  void _onPedirPressed() {
    if (_completed) return;

    if (_phase != _ColPhase.needsPedir) {
      // Doesn't need borrow - shake the button
      setState(() => _shakingPedir = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakingPedir = false);
      });
      widget.onError?.call();
      return;
    }

    // Execute borrow
    final col = _currentCol;
    final source = _borrowSource[col];
    final cascade = _cascadeCols[col];

    setState(() {
      // Cross out source and cascade columns
      _crossedOut[source] = true;
      _effectiveA[source] -= 1;

      for (final c in cascade) {
        _crossedOut[c] = true;
        _effectiveA[c] = 9;
        _newDigitAbove[c] = 9; // auto-filled
      }

      // Current column receives +10
      _receivedBorrow[col] = true;
      _effectiveA[col] += 10;

      _phase = _ColPhase.waitingReduced;
    });
  }

  void _onDropOnReduced(int digit) {
    if (_phase != _ColPhase.waitingReduced || _completed) return;

    final source = _borrowSource[_currentCol];
    final expected = _expectedReduced[_currentCol];

    if (digit == expected) {
      setState(() {
        _newDigitAbove[source] = digit;
        _phase = _ColPhase.waitingAnswer;
        _shakeSlot = null;
      });
    } else {
      _triggerShake('reduced-$source');
      widget.onError?.call();
    }
  }

  void _onDropOnAnswer(int col, int digit) {
    if (_phase != _ColPhase.waitingAnswer || _completed) return;
    if (col != _currentCol) return;

    if (widget.evalMode) {
      // Eval mode: accept any digit, no validation yet
      setState(() {
        _userAnswer[col] = digit;
        _shakeSlot = null;
        _advanceToNextCol();
      });
    } else {
      if (digit == _expectedAnswer[col]) {
        setState(() {
          _userAnswer[col] = digit;
          _shakeSlot = null;
          _advanceToNextCol();
        });
      } else {
        _triggerShake('answer-$col');
        widget.onError?.call();
      }
    }
  }

  void _advanceToNextCol() {
    // Find next unfilled column to the left
    for (int col = _currentCol - 1; col >= 0; col--) {
      if (_userAnswer[col] == null) {
        _currentCol = col;
        _phase = _needsBorrow[col] ? _ColPhase.needsPedir : _ColPhase.waitingAnswer;
        return;
      }
    }
    // All answer slots filled
    if (widget.evalMode) {
      _completed = true;
    } else {
      _completed = true;
      widget.onCompleted(true);
    }
  }

  bool get _allAnswersFilled => _userAnswer.every((d) => d != null);

  void _onClearAnswer(int col) {
    if (_submitted || !widget.evalMode) return;
    if (_userAnswer[col] == null) return;
    setState(() {
      _userAnswer[col] = null;
      _completed = false;
      if (col >= _currentCol) {
        _currentCol = col;
        _phase = _needsBorrow[col] ? _ColPhase.needsPedir : _ColPhase.waitingAnswer;
      }
    });
  }

  void _onReplaceAnswer(int col, int digit) {
    if (_submitted || !widget.evalMode) return;
    if (_userAnswer[col] == null) return;
    setState(() {
      _userAnswer[col] = digit;
    });
  }

  void _onSubmit() {
    if (!_allAnswersFilled || _submitted) return;

    final correct = List.generate(_maxLen, (i) => _userAnswer[i] == _expectedAnswer[i])
        .every((v) => v);

    setState(() {
      _submitted = true;
      _wasCorrect = correct;
    });

    widget.onCompleted(correct);
  }

  void _triggerShake(String slot) {
    setState(() => _shakeSlot = slot);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shakeSlot = null);
    });
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

  bool get _isDark => widget.evalMode;

  @override
  Widget build(BuildContext context) {
    final gridWidth = _maxLen * (_cellSize + _cellGap * 2);
    final bgColor = _isDark ? const Color(0xFF1E1E2C) : AppColors.surface;
    final shadowColor = _isDark
        ? Colors.black.withValues(alpha: 0.3)
        : AppColors.algorithm.withValues(alpha: 0.1);
    final opColor = _isDark ? const Color(0xFF8888AA) : AppColors.textSecondary;
    final lineColor = _isDark ? const Color(0xFF555577) : AppColors.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 12, 24, 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildReducedRow(gridWidth),
              const SizedBox(height: 2),
              _buildTopNumberRow(gridWidth),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '−',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: opColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildBottomNumberRow(gridWidth),
                ],
              ),
              Container(
                width: gridWidth + 40,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildAnswerRow(gridWidth),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_submitted) _buildPedirButton(),
        if (widget.evalMode && !_submitted && _userAnswer.any((d) => d != null)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _allAnswersFilled ? _onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white54,
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
        ],
        const SizedBox(height: 12),
        if (!_submitted) _buildDigitPalette(),
        if (_submitted) _buildResultFeedback()
        else if (_completed && !widget.evalMode)
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

  Widget _buildReducedRow(double gridWidth) {
    final accentColor = _isDark ? const Color(0xFF6C5CE7) : AppColors.primary;

    return SizedBox(
      width: gridWidth,
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          final hasValue = _newDigitAbove[col] != null;
          final isWaiting = _phase == _ColPhase.waitingReduced &&
              _borrowSource[_currentCol] == col &&
              !hasValue;
          final isShaking = _shakeSlot == 'reduced-$col';

          if (!hasValue && !isWaiting) {
            return SizedBox(width: _cellSize + _cellGap * 2, height: 36);
          }

          final content = _AnimatedShake(
            shaking: isShaking,
            child: Container(
              width: 36,
              height: 36,
              margin: EdgeInsets.symmetric(
                horizontal: (_cellSize - 36) / 2 + _cellGap,
              ),
              decoration: BoxDecoration(
                color: hasValue
                    ? accentColor.withValues(alpha: 0.12)
                    : accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: isWaiting
                    ? Border.all(
                        color: accentColor.withValues(alpha: 0.7),
                        width: 2,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: hasValue
                  ? Text(
                      '${_newDigitAbove[col]}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    )
                  : Icon(
                      Icons.arrow_downward_rounded,
                      size: 14,
                      color: accentColor.withValues(alpha: 0.5),
                    ),
            ),
          );

          if (!isWaiting) return content;

          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => _onDropOnReduced(details.data),
            builder: (context, candidateData, _) {
              if (candidateData.isNotEmpty) {
                return _AnimatedShake(
                  shaking: isShaking,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: EdgeInsets.symmetric(
                      horizontal: (_cellSize - 36) / 2 + _cellGap,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor, width: 2.5),
                    ),
                    alignment: Alignment.center,
                  ),
                );
              }
              return content;
            },
          );
        }),
      ),
    );
  }

  Widget _buildTopNumberRow(double gridWidth) {
    final textColor = _isDark ? const Color(0xFFE0E0F0) : AppColors.textPrimary;
    final dimColor = _isDark
        ? const Color(0xFF555577)
        : AppColors.textLight.withValues(alpha: 0.4);

    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          final isLeadingZero = _digitsA[col] == 0 &&
              col < _maxLen - 1 &&
              _digitsA.sublist(0, col + 1).every((d) => d == 0);

          final isCrossed = _crossedOut[col];
          final hasBorrow = _receivedBorrow[col];

          return Container(
            width: _cellSize,
            height: _cellSize,
            margin: const EdgeInsets.symmetric(horizontal: _cellGap),
            alignment: Alignment.center,
            child: isLeadingZero
                ? null
                : Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        '${_digitsA[col]}',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: isCrossed ? dimColor : textColor,
                        ),
                      ),
                      if (isCrossed)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DiagonalLinePainter(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      if (hasBorrow)
                        Positioned(
                          left: -14,
                          top: -2,
                          child: Text(
                            '1',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF6B6B),
                            ),
                          ),
                        ),
                    ],
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNumberRow(double gridWidth) {
    final textColor = _isDark ? const Color(0xFFE0E0F0) : AppColors.textPrimary;

    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          final isLeadingZero = _digitsB[col] == 0 &&
              col < _maxLen - 1 &&
              _digitsB.sublist(0, col + 1).every((d) => d == 0);

          return Container(
            width: _cellSize,
            height: _cellSize,
            margin: const EdgeInsets.symmetric(horizontal: _cellGap),
            alignment: Alignment.center,
            child: Text(
              isLeadingZero ? '' : '${_digitsB[col]}',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAnswerRow(double gridWidth) {
    final emptyBg = _isDark ? const Color(0xFF222236) : AppColors.background;
    final borderInactive = _isDark
        ? const Color(0xFF444466)
        : AppColors.textLight.withValues(alpha: 0.3);

    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_maxLen, (col) {
          final isFilled = _userAnswer[col] != null;
          final isActive = col == _currentCol && _phase == _ColPhase.waitingAnswer;
          final isShaking = _shakeSlot == 'answer-$col';
          final color = _getColumnColor(col);

          Color? evalDigitColor;
          if (_submitted && isFilled && widget.evalMode) {
            evalDigitColor = _userAnswer[col] == _expectedAnswer[col]
                ? AppColors.correct
                : AppColors.incorrect;
          }

          final defaultWidget = GestureDetector(
            onDoubleTap: isFilled && widget.evalMode && !_submitted
                ? () => _onClearAnswer(col)
                : null,
            child: _AnimatedShake(
              shaking: isShaking,
              child: Container(
                width: _cellSize,
                height: _cellSize,
                margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                decoration: BoxDecoration(
                  color: _submitted && evalDigitColor != null
                      ? evalDigitColor.withValues(alpha: 0.15)
                      : isFilled
                          ? (_isDark
                              ? const Color(0xFF2A2A40)
                              : color.withValues(alpha: 0.12))
                          : isActive
                              ? color.withValues(alpha: 0.08)
                              : emptyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _submitted && evalDigitColor != null
                        ? evalDigitColor
                        : isActive
                            ? color
                            : isFilled
                                ? (_isDark
                                    ? const Color(0xFF444466)
                                    : color.withValues(alpha: 0.3))
                                : borderInactive,
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
                          color: _submitted && evalDigitColor != null
                              ? evalDigitColor
                              : _isDark
                                  ? const Color(0xFFE0E0F0)
                                  : color,
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
            ),
          );

          final canDrop = isActive || (isFilled && widget.evalMode && !_submitted);
          if (!canDrop) return defaultWidget;

          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              if (isFilled && widget.evalMode) {
                _onReplaceAnswer(col, details.data);
              } else {
                _onDropOnAnswer(col, details.data);
              }
            },
            builder: (context, candidateData, _) {
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
                    child: Icon(Icons.remove_rounded, color: color, size: 24),
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

  Widget _buildResultFeedback() {
    final correct = _wasCorrect ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
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

  Widget _buildPedirButton() {
    final btnColor = _isDark ? const Color(0xFF8888AA) : AppColors.textLight;

    return _AnimatedShake(
      shaking: _shakingPedir,
      child: GestureDetector(
        onTap: _onPedirPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: btnColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: btnColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: btnColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Pedir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: btnColor,
                ),
              ),
            ],
          ),
        ),
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
          feedback: _DragDigitFeedback(digit: digit, dark: _isDark),
          childWhenDragging: _DigitChip(digit: digit, dimmed: true, dark: _isDark),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          child: _DigitChip(digit: digit, dark: _isDark),
        );
      }),
    );
  }
}

class _DigitChip extends StatelessWidget {
  final int digit;
  final bool dimmed;
  final bool dark;

  const _DigitChip({required this.digit, this.dimmed = false, this.dark = false});

  @override
  Widget build(BuildContext context) {
    if (dark) {
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
          color: dimmed ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _DragDigitFeedback extends StatelessWidget {
  final int digit;
  final bool dark;

  const _DragDigitFeedback({required this.digit, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final bgColor = dark
        ? const Color(0xFF6C5CE7)
        : AppColors.primary.withValues(alpha: 0.9);
    final shadowBase = dark ? const Color(0xFF6C5CE7) : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: shadowBase.withValues(alpha: dark ? 0.4 : 0.3),
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

class _DiagonalLinePainter extends CustomPainter {
  final Color color;

  _DiagonalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
