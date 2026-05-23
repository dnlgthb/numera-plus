import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';

const double _cellSize = 44;
const double _cellGap = 3;

enum _DivPhase {
  enterQuotient,
  enterProduct,
  enterRemainder,
  bringDown,
  enterDecimalPoint,
  appendZero,
}

class ColumnDivisionWidget extends StatefulWidget {
  final SumProblem problem;
  final ValueChanged<bool> onCompleted;
  final VoidCallback? onError;
  final bool mentalMode;
  final bool decimalMode;
  final bool evalMode;

  const ColumnDivisionWidget({
    super.key,
    required this.problem,
    required this.onCompleted,
    this.onError,
    this.mentalMode = false,
    this.decimalMode = false,
    this.evalMode = false,
  });

  @override
  State<ColumnDivisionWidget> createState() => _ColumnDivisionWidgetState();
}

class _ColumnDivisionWidgetState extends State<ColumnDivisionWidget> {
  late List<int> _dividendDigits;
  late List<int> _quotientDigits;
  late List<_DivisionStep> _steps;
  late List<int?> _userQuotient;

  _DivPhase _phase = _DivPhase.enterQuotient;
  int _currentStepIdx = 0;

  List<int> _expectedProduct = [];
  List<int?> _userProduct = [];
  int _productPos = 0;

  List<int> _expectedRemainder = [];
  List<int?> _userRemainder = [];
  int _remainderPos = 0;

  bool _completed = false;
  bool _hadErrors = false;
  String? _shakeSlot;

  bool _evalDone = false;
  bool _evalSubmitted = false;
  bool? _evalCorrect;

  bool get _isEval => widget.evalMode;

  int _originalDividendLen = 0;
  int _integerStepCount = 0;
  bool _hasDecimalPart = false;
  bool _decimalPointPlaced = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final dividend = widget.problem.a;
    final divisor = widget.problem.b;

    _dividendDigits = dividend.toString().split('').map(int.parse).toList();
    _originalDividendLen = _dividendDigits.length;

    _steps = _computeSteps(dividend, divisor, decimal: widget.decimalMode);
    _integerStepCount = _steps.where((s) => !s.isDecimal).length;
    _hasDecimalPart = _steps.any((s) => s.isDecimal);

    if (_hasDecimalPart) {
      final decimalStepCount = _steps.length - _integerStepCount;
      for (int i = 0; i < decimalStepCount; i++) {
        _dividendDigits.add(0);
      }
    }

    _quotientDigits = _steps.map((s) => s.quotientDigit).toList();
    _userQuotient = List.filled(_quotientDigits.length, null);
    _phase = _DivPhase.enterQuotient;
    _currentStepIdx = 0;
    _expectedProduct = [];
    _userProduct = [];
    _productPos = 0;
    _expectedRemainder = [];
    _userRemainder = [];
    _remainderPos = 0;
    _completed = false;
    _hadErrors = false;
    _decimalPointPlaced = false;
    _evalDone = false;
    _evalSubmitted = false;
    _evalCorrect = null;
  }

  List<_DivisionStep> _computeSteps(int dividend, int divisor,
      {bool decimal = false}) {
    final steps = <_DivisionStep>[];
    final divDigits = dividend.toString().split('').map(int.parse).toList();
    int partial = 0;
    int quotientIdx = 0;
    bool started = false;

    for (int i = 0; i < divDigits.length; i++) {
      partial = partial * 10 + divDigits[i];

      if (partial >= divisor || started) {
        started = true;
        final q = partial ~/ divisor;
        final product = q * divisor;
        final remainder = partial - product;

        steps.add(_DivisionStep(
          partialDividend: partial,
          quotientDigit: q,
          product: product,
          remainder: remainder,
          digitIndex: quotientIdx,
          lastDividendIdx: i,
        ));

        partial = remainder;
        quotientIdx++;
      }
    }

    if (decimal && partial > 0) {
      int decimalPlaces = 0;
      while (partial > 0 && decimalPlaces < 3) {
        partial = partial * 10;
        final q = partial ~/ divisor;
        final product = q * divisor;
        final remainder = partial - product;

        steps.add(_DivisionStep(
          partialDividend: partial,
          quotientDigit: q,
          product: product,
          remainder: remainder,
          digitIndex: quotientIdx,
          lastDividendIdx: divDigits.length + decimalPlaces,
          isDecimal: true,
        ));

        partial = remainder;
        quotientIdx++;
        decimalPlaces++;
      }
    }

    return steps;
  }

  int get _quotientLen => _quotientDigits.length;
  int get _dividendLen => _dividendDigits.length;

  int get _processedUpTo {
    if (_steps.isEmpty) return -1;
    final idx = _currentStepIdx.clamp(0, _steps.length - 1);
    return _steps[idx].lastDividendIdx;
  }

  int _quotientSlotForStep(int stepIdx) {
    if (!_hasDecimalPart) return stepIdx;
    if (stepIdx < _integerStepCount) return stepIdx;
    return stepIdx + 1;
  }

  // --- Event handlers ---

  void _onDropOnQuotient(int slot, int data) {
    if (_completed || _evalSubmitted) return;

    if (_hasDecimalPart && slot == _integerStepCount) {
      if (_phase == _DivPhase.enterDecimalPoint && data == -1) {
        setState(() {
          _decimalPointPlaced = true;
          _phase = _DivPhase.appendZero;
          _shakeSlot = null;
        });
      } else if (!_isEval) {
        _triggerShake('q-comma');
        widget.onError?.call();
      }
      return;
    }

    if (data == -1) {
      if (!_isEval) {
        _triggerShake('q-$slot');
        widget.onError?.call();
      }
      return;
    }

    if (_phase != _DivPhase.enterQuotient) return;

    final expectedSlot = _quotientSlotForStep(_currentStepIdx);
    if (slot != expectedSlot) return;

    if (_isEval || data == _quotientDigits[_currentStepIdx]) {
      final step = _steps[_currentStepIdx];

      setState(() {
        _userQuotient[_currentStepIdx] = data;
        _shakeSlot = null;
      });

      if (step.product == 0) {
        _advanceAfterStep();
      } else if (widget.mentalMode) {
        final remDigits =
            step.remainder.toString().split('').map(int.parse).toList();
        setState(() {
          _phase = _DivPhase.enterRemainder;
          _expectedRemainder = remDigits;
          _userRemainder = List.filled(remDigits.length, null);
          _remainderPos = 0;
        });
      } else {
        final prodDigits =
            step.product.toString().split('').map(int.parse).toList();
        setState(() {
          _phase = _DivPhase.enterProduct;
          _expectedProduct = prodDigits;
          _userProduct = List.filled(prodDigits.length, null);
          _productPos = 0;
        });
      }
    } else {
      _triggerShake('q-$slot');
      widget.onError?.call();
    }
  }

  void _advanceAfterStep() {
    if (_currentStepIdx >= _steps.length - 1) {
      if (_isEval) {
        setState(() => _evalDone = true);
        return;
      }
      setState(() => _completed = true);
      widget.onCompleted(!_hadErrors);
    } else if (_hasDecimalPart &&
        !_decimalPointPlaced &&
        _steps[_currentStepIdx].lastDividendIdx >= _originalDividendLen - 1) {
      setState(() => _phase = _DivPhase.enterDecimalPoint);
    } else if (_decimalPointPlaced) {
      setState(() => _phase = _DivPhase.appendZero);
    } else {
      setState(() => _phase = _DivPhase.bringDown);
    }
  }

  void _onDropOnProduct(int pos, int digit) {
    if (_completed || _evalSubmitted) return;
    if (_phase != _DivPhase.enterProduct) return;
    if (pos != _productPos) return;
    if (digit == -1) {
      if (!_isEval) {
        _triggerShake('p-$pos');
        widget.onError?.call();
      }
      return;
    }

    if (_isEval || digit == _expectedProduct[pos]) {
      setState(() {
        _userProduct[pos] = digit;
        _shakeSlot = null;
        _productPos++;
      });

      if (_productPos >= _expectedProduct.length) {
        final step = _steps[_currentStepIdx];
        final remDigits =
            step.remainder.toString().split('').map(int.parse).toList();
        setState(() {
          _phase = _DivPhase.enterRemainder;
          _expectedRemainder = remDigits;
          _userRemainder = List.filled(remDigits.length, null);
          _remainderPos = 0;
        });
      }
    } else {
      _triggerShake('p-$pos');
      widget.onError?.call();
    }
  }

  void _onDropOnRemainder(int pos, int digit) {
    if (_completed || _evalSubmitted) return;
    if (_phase != _DivPhase.enterRemainder) return;
    if (pos != _remainderPos) return;
    if (digit == -1) {
      if (!_isEval) {
        _triggerShake('r-$pos');
        widget.onError?.call();
      }
      return;
    }

    if (_isEval || digit == _expectedRemainder[pos]) {
      setState(() {
        _userRemainder[pos] = digit;
        _shakeSlot = null;
        _remainderPos++;
      });

      if (_remainderPos >= _expectedRemainder.length) {
        _advanceAfterStep();
      }
    } else {
      _triggerShake('r-$pos');
      widget.onError?.call();
    }
  }

  void _onBringDown() {
    if (_phase != _DivPhase.bringDown) return;
    setState(() {
      _currentStepIdx++;
      _phase = _DivPhase.enterQuotient;
      _expectedProduct = [];
      _userProduct = [];
      _productPos = 0;
      _expectedRemainder = [];
      _userRemainder = [];
      _remainderPos = 0;
    });
  }

  void _onAppendZero(int digit) {
    if (_phase != _DivPhase.appendZero) return;
    if (digit == -1 || digit != 0) {
      if (!_isEval) {
        _triggerShake('az');
        widget.onError?.call();
      }
      return;
    }
    setState(() {
      _currentStepIdx++;
      _phase = _DivPhase.enterQuotient;
      _expectedProduct = [];
      _userProduct = [];
      _productPos = 0;
      _expectedRemainder = [];
      _userRemainder = [];
      _remainderPos = 0;
    });
  }

  void _onClearQuotient(int stepIdx) {
    if (_evalSubmitted || !_isEval) return;
    if (stepIdx != _currentStepIdx) return;
    if (_userQuotient[stepIdx] == null) return;
    setState(() {
      _userQuotient[stepIdx] = null;
      _phase = _DivPhase.enterQuotient;
      _expectedProduct = [];
      _userProduct = [];
      _productPos = 0;
      _expectedRemainder = [];
      _userRemainder = [];
      _remainderPos = 0;
    });
  }

  void _onReplaceQuotient(int stepIdx, int digit) {
    if (_evalSubmitted || !_isEval) return;
    if (stepIdx != _currentStepIdx) return;
    if (_userQuotient[stepIdx] == null) return;
    setState(() {
      _userQuotient[stepIdx] = digit;
      _phase = _DivPhase.enterQuotient;
      _expectedProduct = [];
      _userProduct = [];
      _productPos = 0;
      _expectedRemainder = [];
      _userRemainder = [];
      _remainderPos = 0;
      _evalDone = false;
    });
    // Re-trigger the quotient logic with the new digit
    final step = _steps[_currentStepIdx];
    if (step.product == 0) {
      _advanceAfterStep();
    } else if (widget.mentalMode) {
      final remDigits = step.remainder.toString().split('').map(int.parse).toList();
      setState(() {
        _phase = _DivPhase.enterRemainder;
        _expectedRemainder = remDigits;
        _userRemainder = List.filled(remDigits.length, null);
        _remainderPos = 0;
      });
    } else {
      final prodDigits = step.product.toString().split('').map(int.parse).toList();
      setState(() {
        _phase = _DivPhase.enterProduct;
        _expectedProduct = prodDigits;
        _userProduct = List.filled(prodDigits.length, null);
        _productPos = 0;
      });
    }
  }

  void _onSubmitEval() {
    if (_evalSubmitted) return;
    final userQ = _userQuotient.whereType<int>().toList();
    if (userQ.isEmpty) return;
    final correct =
        userQ.length == _quotientDigits.length &&
        List.generate(userQ.length, (i) => userQ[i] == _quotientDigits[i])
            .every((v) => v);
    setState(() {
      _evalSubmitted = true;
      _evalCorrect = correct;
      _completed = true;
    });
    widget.onCompleted(correct);
  }

  Widget _buildEvalFeedback() {
    final correct = _evalCorrect ?? false;
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

  void _triggerShake(String slot) {
    _hadErrors = true;
    setState(() => _shakeSlot = slot);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shakeSlot = null);
    });
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final bgColor = _isEval ? const Color(0xFF1E1E2C) : AppColors.surface;
    final shadowColor = _isEval
        ? Colors.black.withValues(alpha: 0.3)
        : AppColors.algorithm.withValues(alpha: 0.1);

    final scrollContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
          child: _buildDivisionLayout(),
        ),
        const SizedBox(height: 20),
        if (_isEval && _evalSubmitted) _buildEvalFeedback(),
        if (_isEval && !_evalSubmitted && _userQuotient.any((q) => q != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSubmitEval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('ENVIAR',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        if (_completed && !_isEval)
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

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: scrollContent,
          ),
        ),
        if (!_completed) ...[
          const SizedBox(height: 8),
          _buildDigitPalette(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDivisionLayout() {
    final divisorStr = widget.problem.b.toString();
    final cellW = _cellSize + _cellGap * 2;
    final dividendWidth = _dividendLen * cellW;

    final textColor =
        _isEval ? const Color(0xFFE0E0F0) : AppColors.textPrimary;
    final opColor =
        _isEval ? const Color(0xFF8888AA) : AppColors.textLight;
    final lineColor =
        _isEval ? const Color(0xFF555577) : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDividendRow(dividendWidth),
            const SizedBox(width: 4),
            SizedBox(
              height: _cellSize,
              child: Center(
                child: Text(
                  '÷',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: _cellSize,
                        child: Center(
                          child: Text(
                            divisorStr,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: _cellSize,
                        child: Center(
                          child: Text(
                            '=',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: opColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildQuotientRow(),
                    ],
                  ),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildWorkArea(),
      ],
    );
  }

  Widget _buildQuotientRow() {
    int totalSlots;
    if (_isEval) {
      final visibleSteps = _evalDone
          ? _quotientDigits.length
          : _currentStepIdx + 1;
      final showComma = _hasDecimalPart &&
          (_decimalPointPlaced ||
              _phase == _DivPhase.enterDecimalPoint ||
              _phase == _DivPhase.appendZero);
      totalSlots = showComma ? visibleSteps + 1 : visibleSteps;
    } else {
      totalSlots = _hasDecimalPart
          ? _quotientDigits.length + 1
          : _quotientDigits.length;
    }

    final color = _isEval ? const Color(0xFF6C5CE7) : AppColors.primary;
    final emptyBg =
        _isEval ? const Color(0xFF222236) : AppColors.background;
    final borderInactive = _isEval
        ? const Color(0xFF444466)
        : AppColors.textLight.withValues(alpha: 0.3);
    final filledTextColor =
        _isEval ? const Color(0xFFE0E0F0) : color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSlots, (slot) {
        if (_hasDecimalPart && slot == _integerStepCount) {
          return _buildCommaSlot(color);
        }

        final stepIdx =
            _hasDecimalPart && slot > _integerStepCount ? slot - 1 : slot;
        final isFilled = _userQuotient[stepIdx] != null;
        final isActive = stepIdx == _currentStepIdx &&
            _phase == _DivPhase.enterQuotient &&
            !_completed &&
            !_evalDone;
        final isShaking = _shakeSlot == 'q-$slot';

        Color? evalDigitColor;
        if (_isEval && _evalSubmitted && isFilled) {
          evalDigitColor =
              _userQuotient[stepIdx] == _quotientDigits[stepIdx]
                  ? AppColors.correct
                  : AppColors.incorrect;
        }

        final canReplace = _isEval && isFilled && !_evalSubmitted &&
            stepIdx == _currentStepIdx && !_evalDone;

        final slotWidget = GestureDetector(
          onDoubleTap: canReplace ? () => _onClearQuotient(stepIdx) : null,
          child: _AnimatedShake(
            shaking: isShaking,
            child: Container(
              width: _cellSize,
              height: _cellSize,
              margin: const EdgeInsets.symmetric(horizontal: _cellGap),
              decoration: BoxDecoration(
                color: _evalSubmitted && evalDigitColor != null
                    ? evalDigitColor.withValues(alpha: 0.15)
                    : isFilled
                        ? (_isEval
                            ? const Color(0xFF2A2A40)
                            : color.withValues(alpha: 0.12))
                        : isActive
                            ? color.withValues(alpha: 0.08)
                            : emptyBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _evalSubmitted && evalDigitColor != null
                      ? evalDigitColor
                      : isActive
                          ? color
                          : isFilled
                              ? (_isEval
                                  ? const Color(0xFF444466)
                                  : color.withValues(alpha: 0.4))
                              : borderInactive,
                  width: isActive ? 2.5 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isFilled
                  ? Text(
                      '${_userQuotient[stepIdx]}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _evalSubmitted && evalDigitColor != null
                            ? evalDigitColor
                            : filledTextColor,
                      ),
                    )
                  : isActive
                      ? Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                          color: color.withValues(alpha: 0.4),
                        )
                      : null,
            ),
          ),
        );

        if (canReplace) {
          return DragTarget<int>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              if (details.data == -1) return;
              _onReplaceQuotient(stepIdx, details.data);
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
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color, width: 2.5),
                    ),
                    alignment: Alignment.center,
                  ),
                );
              }
              return slotWidget;
            },
          );
        }

        if (!isActive || isFilled) return slotWidget;

        return DragTarget<int>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              _onDropOnQuotient(slot, details.data),
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color, width: 2.5),
                  ),
                  alignment: Alignment.center,
                ),
              );
            }
            return slotWidget;
          },
        );
      }),
    );
  }

  Widget _buildCommaSlot(Color color) {
    final isActive =
        _phase == _DivPhase.enterDecimalPoint && !_completed && !_evalDone;
    final isFilled = _decimalPointPlaced;
    final isShaking = _shakeSlot == 'q-comma';

    final hasDigitAfterComma = isFilled &&
        _integerStepCount < _userQuotient.length &&
        _userQuotient[_integerStepCount] != null;

    if (isFilled && hasDigitAfterComma) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 16,
        height: _cellSize,
        alignment: Alignment.center,
        child: Text(
          ',',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
    }

    if (isFilled) {
      return Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.symmetric(horizontal: _cellGap),
        alignment: Alignment.center,
        child: Text(
          ',',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
    }

    final emptyBg =
        _isEval ? const Color(0xFF222236) : AppColors.background;
    final borderInactive = _isEval
        ? const Color(0xFF444466)
        : AppColors.textLight.withValues(alpha: 0.3);

    final commaWidget = _AnimatedShake(
      shaking: isShaking,
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.symmetric(horizontal: _cellGap),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.08)
              : emptyBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : borderInactive,
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: isActive
            ? Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: color.withValues(alpha: 0.4),
              )
            : null,
      ),
    );

    if (!isActive) return commaWidget;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          _onDropOnQuotient(_integerStepCount, details.data),
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color, width: 2.5),
              ),
              alignment: Alignment.center,
            ),
          );
        }
        return commaWidget;
      },
    );
  }

  Widget _buildDividendRow(double width) {
    int? bringDownIdx;
    if (_phase == _DivPhase.bringDown && _currentStepIdx < _steps.length) {
      final nextIdx = _steps[_currentStepIdx].lastDividendIdx + 1;
      if (nextIdx < _dividendDigits.length) bringDownIdx = nextIdx;
    }

    final processed = _processedUpTo;
    final accentColor =
        _isEval ? const Color(0xFF6C5CE7) : AppColors.primary;
    final defaultColor =
        _isEval ? const Color(0xFFE0E0F0) : AppColors.textPrimary;
    final dimColor = _isEval
        ? const Color(0xFF555577)
        : AppColors.textLight.withValues(alpha: 0.4);

    return SizedBox(
      width: width,
      child: Row(
        children: List.generate(_dividendDigits.length, (i) {
          final isBringDown = bringDownIdx == i;
          final isProcessed = i <= processed && !isBringDown;
          final isVirtual = i >= _originalDividendLen;

          if (isVirtual) {
            return SizedBox(
              width: _cellSize + _cellGap * 2,
              height: _cellSize,
            );
          }

          final child = Container(
            width: _cellSize,
            height: _cellSize,
            margin: const EdgeInsets.symmetric(horizontal: _cellGap),
            decoration: isBringDown
                ? BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor,
                      width: 2.5,
                    ),
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              '${_dividendDigits[i]}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: isBringDown
                    ? accentColor
                    : isProcessed
                        ? accentColor
                        : isVirtual
                            ? dimColor
                            : defaultColor,
              ),
            ),
          );

          if (isBringDown) {
            return GestureDetector(
              onTap: _onBringDown,
              child: child,
            );
          }
          return child;
        }),
      ),
    );
  }

  Widget _buildRemainderWithZeroTarget(int remainder, int rightAlignCol) {
    final cellW = _cellSize + _cellGap * 2;
    final remStr = remainder.toString();
    final remDigits = remStr.split('').map(int.parse).toList();
    final zeroCol = rightAlignCol + 1;
    final startCol = rightAlignCol - remDigits.length + 1;
    final totalCols = (zeroCol + 1).clamp(0, _dividendLen + 1);
    final isShaking = _shakeSlot == 'az';
    final color = _isEval ? const Color(0xFF6C5CE7) : AppColors.primary;

    return SizedBox(
      width: totalCols * cellW,
      height: _cellSize,
      child: Row(
        children: List.generate(totalCols, (i) {
          final remIdx = i - startCol;
          if (remIdx >= 0 && remIdx < remDigits.length) {
            return Container(
              width: _cellSize,
              height: _cellSize,
              margin: const EdgeInsets.symmetric(horizontal: _cellGap),
              alignment: Alignment.center,
              child: Text(
                '${remDigits[remIdx]}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _isEval
                      ? const Color(0xFF9999BB)
                      : AppColors.textSecondary,
                ),
              ),
            );
          }

          if (i == zeroCol) {
            final slot = _AnimatedShake(
              shaking: isShaking,
              child: Container(
                width: _cellSize,
                height: _cellSize,
                margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: color.withValues(alpha: 0.4),
                ),
              ),
            );

            return DragTarget<int>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) => _onAppendZero(details.data),
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
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color, width: 2.5),
                      ),
                      alignment: Alignment.center,
                    ),
                  );
                }
                return slot;
              },
            );
          }

          return SizedBox(width: cellW);
        }),
      ),
    );
  }

  Widget _buildWorkArea() {
    final cellW = _cellSize + _cellGap * 2;
    final widgets = <Widget>[];
    final isMental = widget.mentalMode;

    for (int i = 0; i < _currentStepIdx; i++) {
      final step = _steps[i];
      final offset = _dividendLen - _quotientLen + step.digitIndex;
      final productStr = step.product.toString();

      if (step.product > 0 && !isMental) {
        widgets.add(_buildStepNumber(
            productStr, offset, _dividendLen, AppColors.incorrect));
        widgets.add(_buildSeparator(offset, productStr.length, cellW,
            showMinus: true));
      }
      if (isMental && step.product > 0) {
        final remStr = step.remainder.toString();
        widgets.add(_buildSeparator(offset, remStr.length, cellW));
      }

      final nextStep = _steps[i + 1];
      final nextOffset = _dividendLen - _quotientLen + nextStep.digitIndex;
      widgets.add(_buildStepNumber(nextStep.partialDividend.toString(),
          nextOffset, _dividendLen, AppColors.textSecondary));
    }

    if (_currentStepIdx < _steps.length) {
      final step = _steps[_currentStepIdx];
      final offset = _dividendLen - _quotientLen + step.digitIndex;
      final productStr = step.product.toString();

      if (_phase == _DivPhase.enterProduct) {
        final q = _userQuotient[_currentStepIdx] ?? 0;
        final d = widget.problem.b;
        final hintText = '$q×$d→';

        widgets.add(_buildDragTargets(
          expected: _expectedProduct,
          entered: _userProduct,
          activePos: _productPos,
          rightAlignCol: offset,
          shakePrefix: 'p',
          onDrop: _onDropOnProduct,
          hint: hintText,
        ));
      } else if (_phase == _DivPhase.enterRemainder) {
        if (!isMental) {
          widgets.add(_buildStepNumber(
              productStr, offset, _dividendLen, AppColors.incorrect));
          widgets.add(_buildSeparator(offset, productStr.length, cellW,
              showMinus: true));
        }
        widgets.add(_buildDragTargets(
          expected: _expectedRemainder,
          entered: _userRemainder,
          activePos: _remainderPos,
          rightAlignCol: offset,
          shakePrefix: 'r',
          onDrop: _onDropOnRemainder,
        ));
      } else if ((_phase == _DivPhase.bringDown ||
              _phase == _DivPhase.enterDecimalPoint) &&
          step.product > 0) {
        if (!isMental) {
          widgets.add(_buildStepNumber(
              productStr, offset, _dividendLen, AppColors.incorrect));
          widgets.add(_buildSeparator(offset, productStr.length, cellW,
              showMinus: true));
        }
        if (isMental) {
          final remStr = step.remainder.toString();
          widgets.add(_buildSeparator(offset, remStr.length, cellW));
        }
        widgets.add(_buildStepNumber(step.remainder.toString(), offset,
            _dividendLen, AppColors.textSecondary));
      } else if (_phase == _DivPhase.appendZero) {
        if (!isMental && step.product > 0) {
          widgets.add(_buildStepNumber(
              productStr, offset, _dividendLen, AppColors.incorrect));
          widgets.add(_buildSeparator(offset, productStr.length, cellW,
              showMinus: true));
        }
        if (isMental && step.product > 0) {
          final remStr = step.remainder.toString();
          widgets.add(_buildSeparator(offset, remStr.length, cellW));
        }
        widgets.add(_buildRemainderWithZeroTarget(step.remainder, offset));
      }

      if (_completed && step.product > 0) {
        if (_phase == _DivPhase.enterRemainder) {
          widgets.removeLast();
          widgets.add(_buildStepNumber(step.remainder.toString(), offset,
              _dividendLen, AppColors.correct));
        }
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSeparator(int offset, int productLen, double cellW,
      {bool showMinus = false}) {
    final lineColor = _isEval
        ? const Color(0xFF444466)
        : AppColors.textLight.withValues(alpha: 0.4);

    return Padding(
      padding: EdgeInsets.only(
        left: (offset - productLen + 1).clamp(0, _dividendLen) * cellW,
      ),
      child: SizedBox(
        width: (productLen + 1) * cellW,
        height: 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 9,
              child: Container(
                height: 2,
                color: lineColor,
              ),
            ),
            if (showMinus)
              Positioned(
                left: -16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    '−',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.incorrect,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragTargets({
    required List<int> expected,
    required List<int?> entered,
    required int activePos,
    required int rightAlignCol,
    required String shakePrefix,
    required void Function(int pos, int digit) onDrop,
    String? hint,
  }) {
    final cellW = _cellSize + _cellGap * 2;
    final startCol = rightAlignCol - expected.length + 1;
    final color = _isEval ? const Color(0xFF6C5CE7) : AppColors.primary;
    final emptyBg =
        _isEval ? const Color(0xFF222236) : AppColors.background;
    final borderInactive = _isEval
        ? const Color(0xFF444466)
        : AppColors.textLight.withValues(alpha: 0.3);
    final filledText =
        _isEval ? const Color(0xFFE0E0F0) : color;

    return SizedBox(
      width: _dividendLen * cellW,
      height: _cellSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: List.generate(_dividendLen, (i) {
              final dIdx = i - startCol;
              if (dIdx < 0 || dIdx >= expected.length) {
                return SizedBox(width: cellW);
              }

              final isFilled = entered[dIdx] != null;
              final isActive = dIdx == activePos && !_evalSubmitted;
              final isShaking = _shakeSlot == '$shakePrefix-$dIdx';

              final slot = _AnimatedShake(
                shaking: isShaking,
                child: Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? (_isEval
                            ? const Color(0xFF2A2A40)
                            : color.withValues(alpha: 0.12))
                        : isActive
                            ? color.withValues(alpha: 0.08)
                            : emptyBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? color
                          : isFilled
                              ? (_isEval
                                  ? const Color(0xFF444466)
                                  : color.withValues(alpha: 0.4))
                              : borderInactive,
                      width: isActive ? 2.5 : 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isFilled
                      ? Text(
                          '${entered[dIdx]}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: filledText,
                          ),
                        )
                      : isActive
                          ? Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                              color: color.withValues(alpha: 0.4),
                            )
                          : null,
                ),
              );

              if (!isActive || isFilled) return slot;

              return DragTarget<int>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) =>
                    onDrop(dIdx, details.data),
                builder: (context, candidateData, _) {
                  if (candidateData.isNotEmpty) {
                    return _AnimatedShake(
                      shaking: isShaking,
                      child: Container(
                        width: _cellSize,
                        height: _cellSize,
                        margin:
                            const EdgeInsets.symmetric(horizontal: _cellGap),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color, width: 2.5),
                        ),
                        alignment: Alignment.center,
                      ),
                    );
                  }
                  return slot;
                },
              );
            }),
          ),
          if (hint != null && !_isEval)
            Positioned(
              left: startCol.clamp(0, _dividendLen) * cellW - 8,
              top: 0,
              bottom: 0,
              child: FractionalTranslation(
                translation: const Offset(-1.0, 0),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepNumber(
      String numStr, int rightAlignCol, int totalLen, Color practiceColor) {
    final color = _isEval ? const Color(0xFF9999BB) : practiceColor;
    final digits = numStr.split('').map(int.parse).toList();
    final cellW = _cellSize + _cellGap * 2;
    final startCol = rightAlignCol - digits.length + 1;

    return SizedBox(
      width: totalLen * cellW,
      height: 36,
      child: Row(
        children: List.generate(totalLen, (i) {
          final dIdx = i - startCol;
          if (dIdx < 0 || dIdx >= digits.length) {
            return SizedBox(width: cellW);
          }
          return Container(
            width: _cellSize,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: _cellGap),
            alignment: Alignment.center,
            child: Text(
              '${digits[dIdx]}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
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
      children: [
        ...List.generate(10, (digit) {
          return Draggable<int>(
            data: digit,
            feedback: _DragDigitFeedback(digit: digit, dark: _isEval),
            childWhenDragging:
                _DigitChip(digit: digit, dimmed: true, dark: _isEval),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            child: _DigitChip(digit: digit, dark: _isEval),
          );
        }),
        if (widget.decimalMode)
          Draggable<int>(
            data: -1,
            feedback: _DragCommaFeedback(dark: _isEval),
            childWhenDragging: _CommaChip(dimmed: true, dark: _isEval),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            child: _CommaChip(dark: _isEval),
          ),
      ],
    );
  }
}

class _DivisionStep {
  final int partialDividend;
  final int quotientDigit;
  final int product;
  final int remainder;
  final int digitIndex;
  final int lastDividendIdx;
  final bool isDecimal;

  _DivisionStep({
    required this.partialDividend,
    required this.quotientDigit,
    required this.product,
    required this.remainder,
    required this.digitIndex,
    required this.lastDividendIdx,
    this.isDecimal = false,
  });
}

class _DigitChip extends StatelessWidget {
  final int digit;
  final bool dimmed;
  final bool dark;

  const _DigitChip({
    required this.digit,
    this.dimmed = false,
    this.dark = false,
  });

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
    final bgColor =
        dark ? const Color(0xFF6C5CE7) : AppColors.primary.withValues(alpha: 0.9);
    final shadowBase =
        dark ? const Color(0xFF6C5CE7) : AppColors.primary;

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

class _CommaChip extends StatelessWidget {
  final bool dimmed;
  final bool dark;

  const _CommaChip({this.dimmed = false, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final accent = dark ? const Color(0xFF6C5CE7) : AppColors.algorithm;

    return Container(
      width: 56,
      height: 52,
      decoration: BoxDecoration(
        color: dimmed
            ? (dark ? const Color(0xFF2A2A40) : AppColors.textLight.withValues(alpha: 0.15))
            : (dark ? accent.withValues(alpha: 0.15) : accent.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dimmed
              ? Colors.transparent
              : accent.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: dimmed
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.2 : 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        ',',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: dimmed
              ? (dark ? const Color(0xFF555577) : AppColors.textLight)
              : accent,
        ),
      ),
    );
  }
}

class _DragCommaFeedback extends StatelessWidget {
  final bool dark;

  const _DragCommaFeedback({this.dark = false});

  @override
  Widget build(BuildContext context) {
    final accent = dark ? const Color(0xFF6C5CE7) : AppColors.algorithm;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        height: 56,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: dark ? 0.4 : 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          ',',
          style: TextStyle(
            fontSize: 28,
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
 
