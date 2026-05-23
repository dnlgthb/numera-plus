import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';

const double _cellSize = 48;
const double _cellGap = 3;
const double _carrySize = 28;

class ColumnMultiplicationWidget extends StatefulWidget {
  final SumProblem problem;
  final ValueChanged<bool> onCompleted;
  final VoidCallback? onError;
  final bool evalMode;

  const ColumnMultiplicationWidget({
    super.key,
    required this.problem,
    required this.onCompleted,
    this.onError,
    this.evalMode = false,
  });

  @override
  State<ColumnMultiplicationWidget> createState() =>
      _ColumnMultiplicationWidgetState();
}

enum _SlotType { answer, carry }

class _Slot {
  final _SlotType type;
  final int phase;
  final int colFromRight;
  final int expected;
  _Slot(this.type, this.phase, this.colFromRight, this.expected);
  String get key => '${type.name}-$phase-$colFromRight';
}

class _ColumnMultiplicationWidgetState
    extends State<ColumnMultiplicationWidget> {
  late List<int> _mDigits;
  late List<int> _multDigits;
  int _numPhases = 0;

  late List<List<int>> _ppDigitsLTR;
  late List<List<int>> _carryInto;
  late List<int> _finalDigits;
  int _gridCols = 0;

  int _sumPhaseIndex = 0;

  // Practice mode
  late List<_Slot> _slots;
  int _slotIdx = 0;
  String? _shakeKey;

  // Shared
  late List<Map<int, int>> _filledAnswers;
  late List<Map<int, int>> _filledCarries;
  bool _completed = false;

  bool get _needsSumPhase => _numPhases > 1;

  // Eval mode
  int _evalPhase = 0;
  bool _evalSubmitted = false;
  bool? _evalCorrect;
  late List<Map<int, int>> _expectedAnswers;
  late List<int> _answerCountPerPhase;

  bool get _isEval => widget.evalMode;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    int a = widget.problem.a;
    int b = widget.problem.b;
    if (b > a) {
      final t = a;
      a = b;
      b = t;
    }

    _mDigits = a.toString().split('').map(int.parse).toList();
    _multDigits = b.toString().split('').map(int.parse).toList();
    _numPhases = _multDigits.length;
    _sumPhaseIndex = _numPhases;

    _ppDigitsLTR = [];
    _carryInto = [];
    _slots = [];

    for (int p = 0; p < _numPhases; p++) {
      final d = _multDigits[_multDigits.length - 1 - p];
      final mLen = _mDigits.length;

      final carries = List.filled(mLen + 1, 0);
      final digits = <int>[];

      for (int i = 0; i < mLen; i++) {
        final mCol = mLen - 1 - i;
        final product = _mDigits[mCol] * d + carries[i];
        digits.add(product % 10);
        carries[i + 1] = product ~/ 10;
      }
      if (carries[mLen] > 0) digits.add(carries[mLen]);

      _ppDigitsLTR.add(digits.reversed.toList());
      _carryInto.add(carries);

      for (int cfr = 0; cfr < mLen; cfr++) {
        final mCol = mLen - 1 - cfr;
        final product = _mDigits[mCol] * d + carries[cfr];
        _slots.add(_Slot(_SlotType.answer, p, cfr, product % 10));
        if (carries[cfr + 1] > 0 && cfr < mLen - 1) {
          _slots.add(_Slot(_SlotType.carry, p, cfr + 1, carries[cfr + 1]));
        }
      }
      if (carries[mLen] > 0) {
        _slots.add(_Slot(_SlotType.answer, p, mLen, carries[mLen]));
      }
    }

    _finalDigits = (a * b).toString().split('').map(int.parse).toList();
    _gridCols = _finalDigits.length;

    if (_needsSumPhase) {
      final sumCarries = List.filled(_gridCols + 1, 0);
      for (int cfr = 0; cfr < _gridCols; cfr++) {
        int colSum = sumCarries[cfr];
        for (int p = 0; p < _numPhases; p++) {
          colSum += _ppDigitAt(p, cfr);
        }
        final digit = colSum % 10;
        sumCarries[cfr + 1] = colSum ~/ 10;
        _slots.add(_Slot(_SlotType.answer, _sumPhaseIndex, cfr, digit));
        if (sumCarries[cfr + 1] > 0 && cfr < _gridCols - 1) {
          _slots.add(_Slot(
              _SlotType.carry, _sumPhaseIndex, cfr + 1, sumCarries[cfr + 1]));
        }
      }
    }

    final totalPhases = _needsSumPhase ? _numPhases + 1 : _numPhases;
    _filledAnswers = List.generate(totalPhases, (_) => {});
    _filledCarries = List.generate(totalPhases, (_) => {});
    _slotIdx = 0;
    _completed = false;
    _shakeKey = null;

    // Eval: precompute expected answers and slot counts
    _expectedAnswers = List.generate(totalPhases, (_) => {});
    _answerCountPerPhase = [];
    for (int p = 0; p < _numPhases; p++) {
      final pp = _ppDigitsLTR[p];
      for (int cfr = 0; cfr < pp.length; cfr++) {
        _expectedAnswers[p][cfr] = pp[pp.length - 1 - cfr];
      }
      _answerCountPerPhase.add(pp.length);
    }
    if (_needsSumPhase) {
      for (int cfr = 0; cfr < _finalDigits.length; cfr++) {
        _expectedAnswers[_sumPhaseIndex][cfr] =
            _finalDigits[_finalDigits.length - 1 - cfr];
      }
      _answerCountPerPhase.add(_finalDigits.length);
    }
    _evalPhase = 0;
    _evalSubmitted = false;
    _evalCorrect = null;
  }

  int _ppDigitAt(int phase, int colFromRight) {
    final shift = phase;
    final ppCFR = colFromRight - shift;
    final pp = _ppDigitsLTR[phase];
    final ppIdx = pp.length - 1 - ppCFR;
    if (ppCFR < 0 || ppIdx < 0 || ppIdx >= pp.length) return 0;
    return pp[ppIdx];
  }

  // --- Practice mode helpers ---

  _Slot? get _current => _slotIdx < _slots.length ? _slots[_slotIdx] : null;

  int get _activePhase {
    if (_isEval) return _evalPhase;
    return _current?.phase ?? (_needsSumPhase ? _sumPhaseIndex : _numPhases - 1);
  }

  bool get _allMultDone {
    if (_isEval) return _evalPhase >= _numPhases;
    return _current == null || _current!.phase >= _numPhases;
  }

  void _onDrop(int digit) {
    final s = _current;
    if (s == null || _completed) return;

    if (digit == s.expected) {
      setState(() {
        if (s.type == _SlotType.answer) {
          _filledAnswers[s.phase][s.colFromRight] = digit;
        } else {
          _filledCarries[s.phase][s.colFromRight] = digit;
        }
        _slotIdx++;
        _shakeKey = null;
        if (_slotIdx >= _slots.length) {
          _completed = true;
          widget.onCompleted(true);
        }
      });
    } else {
      setState(() => _shakeKey = s.key);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _shakeKey = null);
      });
      widget.onError?.call();
    }
  }

  // --- Eval mode helpers ---

  int? get _evalNextAnswerCol {
    if (_evalPhase >= _answerCountPerPhase.length) return null;
    final count = _answerCountPerPhase[_evalPhase];
    for (int cfr = 0; cfr < count; cfr++) {
      if (!_filledAnswers[_evalPhase].containsKey(cfr)) return cfr;
    }
    return null;
  }

  bool get _allEvalDone {
    for (int p = 0; p < _answerCountPerPhase.length; p++) {
      for (int cfr = 0; cfr < _answerCountPerPhase[p]; cfr++) {
        if (!_filledAnswers[p].containsKey(cfr)) return false;
      }
    }
    return true;
  }

  void _onDropEvalAnswer(int phase, int cfr, int digit) {
    if (_evalSubmitted || phase != _evalPhase) return;
    setState(() {
      _filledAnswers[phase][cfr] = digit;
      if (_evalNextAnswerCol == null &&
          _evalPhase < _answerCountPerPhase.length - 1) {
        _evalPhase++;
      }
    });
  }

  void _onDropEvalCarry(int phase, int cfr, int digit) {
    if (_evalSubmitted) return;
    setState(() {
      _filledCarries[phase][cfr] = digit;
    });
  }

  void _onClearEvalAnswer(int phase, int cfr) {
    if (_evalSubmitted) return;
    setState(() {
      _filledAnswers[phase].remove(cfr);
      if (phase < _evalPhase) _evalPhase = phase;
    });
  }

  void _onClearEvalCarry(int phase, int cfr) {
    if (_evalSubmitted) return;
    setState(() {
      _filledCarries[phase].remove(cfr);
    });
  }

  void _onSubmitEval() {
    if (!_allEvalDone || _evalSubmitted) return;
    bool allCorrect = true;
    for (int p = 0; p < _answerCountPerPhase.length; p++) {
      for (int cfr = 0; cfr < _answerCountPerPhase[p]; cfr++) {
        if (_filledAnswers[p][cfr] != _expectedAnswers[p][cfr]) {
          allCorrect = false;
        }
      }
    }
    setState(() {
      _evalSubmitted = true;
      _evalCorrect = allCorrect;
      _completed = true;
    });
    widget.onCompleted(allCorrect);
  }

  // --- Shared ---

  Color _colColor(int colFromRight) {
    return switch (colFromRight) {
      0 => AppColors.units,
      1 => AppColors.tens,
      2 => AppColors.hundreds,
      _ => AppColors.thousands,
    };
  }

  @override
  Widget build(BuildContext context) {
    final gridWidth = _gridCols * (_cellSize + _cellGap * 2);
    final extraRight = (_multDigits.length * 16.0) + 48;
    final bgColor =
        _isEval ? const Color(0xFF1E1E2C) : AppColors.surface;
    final shadowColor = _isEval
        ? Colors.black.withValues(alpha: 0.3)
        : AppColors.algorithm.withValues(alpha: 0.1);
    final lineColor =
        _isEval ? const Color(0xFF555577) : AppColors.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24 + extraRight, 16),
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
              _buildProblemRow(gridWidth),
              if (!_allMultDone) ...[
                _buildCarryRow(gridWidth, _activePhase),
                const SizedBox(height: 4),
              ],
              _buildLine(gridWidth, lineColor),
              if (_needsSumPhase && _allMultDone) ...[
                _buildCarryRow(gridWidth, _sumPhaseIndex),
                const SizedBox(height: 4),
              ],
              ...List.generate(_numPhases, (p) => _buildPPRow(p)),
              if (_needsSumPhase && _allMultDone) ...[
                _buildLine(gridWidth, lineColor),
                _buildSumRow(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isEval && _evalSubmitted) _buildEvalFeedback(),
        if (_isEval && !_evalSubmitted && _allEvalDone)
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
        if (!_completed) _buildPalette(),
        if (_completed && !_isEval)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.correct, size: 48),
          ),
      ],
    );
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

  Widget _buildProblemRow(double gridWidth) {
    final textColor =
        _isEval ? const Color(0xFFE0E0F0) : AppColors.textPrimary;
    final opColor =
        _isEval ? const Color(0xFF8888AA) : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: gridWidth,
        height: _cellSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(_gridCols, (gridCol) {
                final idx = gridCol - (_gridCols - _mDigits.length);
                final show = idx >= 0 && idx < _mDigits.length;
                return Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellGap),
                  alignment: Alignment.center,
                  child: show
                      ? Text('${_mDigits[idx]}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: textColor))
                      : null,
                );
              }),
            ),
            Positioned(
              right: -((_multDigits.length * 16.0) + 40),
              top: 0,
              bottom: 0,
              child: Center(
                child: Text('× ${_multDigits.join()}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: opColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(double width, Color color) {
    return Container(
      width: width + 40,
      height: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCarryRow(double gridWidth, int phase) {
    return SizedBox(
      width: gridWidth,
      height: _carrySize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_gridCols, (gridCol) {
          final cfr = _gridCols - 1 - gridCol;

          if (phase < _numPhases) {
            if (cfr <= 0 || cfr >= _mDigits.length) {
              return SizedBox(
                  width: _cellSize + _cellGap * 2, height: _carrySize);
            }
          } else {
            if (cfr <= 0) {
              return SizedBox(
                  width: _cellSize + _cellGap * 2, height: _carrySize);
            }
          }

          if (_isEval) return _buildEvalCarryCell(phase, cfr);
          return _buildPracticeCarryCell(phase, cfr);
        }),
      ),
    );
  }

  Widget _buildPracticeCarryCell(int phase, int cfr) {
    final filled = _filledCarries[phase].containsKey(cfr);
    final isActive = _current?.type == _SlotType.carry &&
        _current?.phase == phase &&
        _current?.colFromRight == cfr;
    final isShaking = _shakeKey == 'carry-$phase-$cfr';

    final child = _ShakeWrap(
      shaking: isShaking,
      child: Container(
        width: _carrySize,
        height: _carrySize,
        margin: EdgeInsets.symmetric(
            horizontal: (_cellSize - _carrySize) / 2 + _cellGap),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.accent.withValues(alpha: 0.15)
              : isActive
                  ? _colColor(cfr).withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive && !filled
              ? Border.all(
                  color: AppColors.accent.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: filled
            ? Text('${_filledCarries[phase][cfr]}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent))
            : isActive
                ? Icon(Icons.arrow_downward_rounded,
                    size: 12,
                    color: AppColors.accent.withValues(alpha: 0.5))
                : null,
      ),
    );

    if (!isActive || filled) return child;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onDrop(d.data),
      builder: (_, candidates, __) {
        if (candidates.isNotEmpty) {
          return Container(
            width: _carrySize,
            height: _carrySize,
            margin: EdgeInsets.symmetric(
                horizontal: (_cellSize - _carrySize) / 2 + _cellGap),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
          );
        }
        return child;
      },
    );
  }

  Widget _buildEvalCarryCell(int phase, int cfr) {
    final filled = _filledCarries[phase].containsKey(cfr);

    final child = GestureDetector(
      onDoubleTap: filled ? () => _onClearEvalCarry(phase, cfr) : null,
      child: Container(
        width: _carrySize,
        height: _carrySize,
        margin: EdgeInsets.symmetric(
            horizontal: (_cellSize - _carrySize) / 2 + _cellGap),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF3A3A5C) : const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(8),
          border: !filled && !_evalSubmitted
              ? Border.all(color: const Color(0xFF444466), width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: filled
            ? Text('${_filledCarries[phase][cfr]}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9999BB)))
            : null,
      ),
    );

    if (filled || _evalSubmitted) return child;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onDropEvalCarry(phase, cfr, d.data),
      builder: (_, candidates, __) {
        if (candidates.isNotEmpty) {
          return Container(
            width: _carrySize,
            height: _carrySize,
            margin: EdgeInsets.symmetric(
                horizontal: (_cellSize - _carrySize) / 2 + _cellGap),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A5C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6C5CE7), width: 2),
            ),
          );
        }
        return child;
      },
    );
  }

  Widget _buildPPRow(int phase) {
    final pp = _ppDigitsLTR[phase];
    final shift = phase;
    final ppLen = pp.length;

    if (_isEval) {
      if (phase > _evalPhase) return const SizedBox.shrink();
    } else {
      if (phase > _activePhase && !_allMultDone) return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: _gridCols * (_cellSize + _cellGap * 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(_gridCols, (gridCol) {
            final gridCFR = _gridCols - 1 - gridCol;
            if (gridCFR < shift) {
              return SizedBox(width: _cellSize + _cellGap * 2);
            }
            final ppCFR = gridCFR - shift;
            final ppIdx = ppLen - 1 - ppCFR;
            if (ppIdx < 0 || ppIdx >= ppLen) {
              return SizedBox(width: _cellSize + _cellGap * 2);
            }

            if (_isEval) {
              return _buildEvalAnswerCell(phase, ppCFR, gridCFR);
            }
            return _buildPracticeAnswerCell(phase, ppCFR, gridCFR);
          }),
        ),
      ),
    );
  }

  Widget _buildPracticeAnswerCell(int phase, int cfr, int gridCFR) {
    final filled = _filledAnswers[phase].containsKey(cfr);
    final isActive = _current?.type == _SlotType.answer &&
        _current?.phase == phase &&
        _current?.colFromRight == cfr;
    final isShaking = _shakeKey == 'answer-$phase-$cfr';
    final color = _colColor(gridCFR);

    final child = _ShakeWrap(
      shaking: isShaking,
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.symmetric(horizontal: _cellGap),
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: 0.12)
              : isActive
                  ? color.withValues(alpha: 0.08)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color
                : filled
                    ? color.withValues(alpha: 0.3)
                    : AppColors.textLight.withValues(alpha: 0.3),
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: filled
            ? Text('${_filledAnswers[phase][cfr]}',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: color))
            : isActive
                ? Icon(Icons.arrow_downward_rounded,
                    size: 20, color: color.withValues(alpha: 0.4))
                : null,
      ),
    );

    if (!isActive || filled) return child;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onDrop(d.data),
      builder: (_, candidates, __) {
        if (candidates.isNotEmpty) {
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
        return child;
      },
    );
  }

  Widget _buildEvalAnswerCell(int phase, int cfr, int gridCFR) {
    final filled = _filledAnswers[phase].containsKey(cfr);
    final isCurrentPhase = phase == _evalPhase;
    final isActive = isCurrentPhase && !filled && cfr == _evalNextAnswerCol;
    final canDrop = isCurrentPhase && !_evalSubmitted;
    final color = _colColor(gridCFR);

    Color? digitColor;
    if (_evalSubmitted && filled) {
      digitColor = _filledAnswers[phase][cfr] == _expectedAnswers[phase][cfr]
          ? AppColors.correct
          : AppColors.incorrect;
    }

    final child = GestureDetector(
      onDoubleTap:
          filled && !_evalSubmitted ? () => _onClearEvalAnswer(phase, cfr) : null,
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.symmetric(horizontal: _cellGap),
        decoration: BoxDecoration(
          color: _evalSubmitted && filled
              ? (digitColor == AppColors.correct
                  ? AppColors.correct.withValues(alpha: 0.15)
                  : AppColors.incorrect.withValues(alpha: 0.15))
              : filled
                  ? const Color(0xFF2A2A40)
                  : isActive
                      ? color.withValues(alpha: 0.1)
                      : const Color(0xFF222236),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _evalSubmitted && filled
                ? digitColor!
                : isActive
                    ? color
                    : const Color(0xFF444466),
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: filled
            ? Text('${_filledAnswers[phase][cfr]}',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _evalSubmitted
                        ? digitColor!
                        : const Color(0xFFE0E0F0)))
            : isActive
                ? Icon(Icons.arrow_downward_rounded,
                    size: 20, color: color.withValues(alpha: 0.5))
                : null,
      ),
    );

    if (!canDrop || _evalSubmitted) return child;
    if (!isActive && !filled) return child;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onDropEvalAnswer(phase, cfr, d.data),
      builder: (_, candidates, __) {
        if (candidates.isNotEmpty) {
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
        return child;
      },
    );
  }

  Widget _buildSumRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: _gridCols * (_cellSize + _cellGap * 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(_gridCols, (gridCol) {
            final cfr = _gridCols - 1 - gridCol;
            if (_isEval) {
              return _buildEvalAnswerCell(_sumPhaseIndex, cfr, cfr);
            }
            return _buildPracticeSumCell(cfr);
          }),
        ),
      ),
    );
  }

  Widget _buildPracticeSumCell(int cfr) {
    final filled = _filledAnswers[_sumPhaseIndex].containsKey(cfr);
    final isActive = _current?.type == _SlotType.answer &&
        _current?.phase == _sumPhaseIndex &&
        _current?.colFromRight == cfr;
    final isShaking = _shakeKey == 'answer-$_sumPhaseIndex-$cfr';
    final color = _colColor(cfr);

    final child = _ShakeWrap(
      shaking: isShaking,
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.symmetric(horizontal: _cellGap),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.correct.withValues(alpha: 0.12)
              : isActive
                  ? color.withValues(alpha: 0.08)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color
                : filled
                    ? AppColors.correct.withValues(alpha: 0.4)
                    : AppColors.textLight.withValues(alpha: 0.3),
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: filled
            ? Text('${_filledAnswers[_sumPhaseIndex][cfr]}',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.correct))
            : isActive
                ? Icon(Icons.arrow_downward_rounded,
                    size: 20, color: color.withValues(alpha: 0.4))
                : null,
      ),
    );

    if (!isActive || filled) return child;

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onDrop(d.data),
      builder: (_, candidates, __) {
        if (candidates.isNotEmpty) {
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
        return child;
      },
    );
  }

  Widget _buildPalette() {
    final isDark = _isEval;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(10, (digit) {
        return Draggable<int>(
          data: digit,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: 60,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF6C5CE7)
                    : AppColors.primary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF6C5CE7).withValues(alpha: 0.4)
                        : AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text('$digit',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          childWhenDragging: Container(
            width: 56,
            height: 52,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A40)
                  : AppColors.textLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text('$digit',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF555577)
                        : AppColors.textLight)),
          ),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          child: Container(
            width: 56,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E2E48) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF444466)
                    : AppColors.textLight.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text('$digit',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFCCCCEE)
                        : AppColors.textPrimary)),
          ),
        );
      }),
    );
  }
}

class _ShakeWrap extends StatefulWidget {
  final bool shaking;
  final Widget child;
  const _ShakeWrap({required this.shaking, required this.child});

  @override
  State<_ShakeWrap> createState() => _ShakeWrapState();
}

class _ShakeWrapState extends State<_ShakeWrap>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _anim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(covariant _ShakeWrap old) {
    super.didUpdateWidget(old);
    if (widget.shaking && !old.shaking) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) =>
          Transform.translate(offset: Offset(_anim.value, 0), child: child),
      child: widget.child,
    );
  }
}
