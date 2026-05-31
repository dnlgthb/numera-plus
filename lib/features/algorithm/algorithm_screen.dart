import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/sum_generator.dart';
import '../../core/classroom_service.dart';
import '../../core/local_progress_service.dart';
import '../../core/audio_service.dart';
import 'widgets/column_sum_widget.dart';
import 'widgets/column_subtraction_widget.dart';
import 'widgets/column_multiplication_widget.dart';
import 'widgets/column_division_widget.dart';
import 'widgets/eval_sum_widget.dart';

class AlgorithmScreen extends StatefulWidget {
  final OperationType operation;
  const AlgorithmScreen({super.key, this.operation = OperationType.sum});

  @override
  State<AlgorithmScreen> createState() => _AlgorithmScreenState();
}

class _AlgorithmScreenState extends State<AlgorithmScreen> {
  late SumProblem _problem;
  bool _isEvalMode = false;

  // Division modes
  bool _mentalMode = false;
  bool _decimalMode = false;

  final _classroom = ClassroomService();
  final _localProgress = LocalProgressService();
  final _audio = AudioService.instance;

  // Shared stats
  int _completed = 0;
  int _errors = 0;

  // Eval-specific stats
  int _streak = 0;
  int _maxStreak = 0;
  int _coins = 0;
  int _starsInCurrentCoinCycle = 0; // tracks stars toward next coin

  @override
  void initState() {
    super.initState();
    _problem = SumGenerator.generateProgressive(0, operation: widget.operation, decimal: _decimalMode);
    if (!_classroom.isInClassroom) _loadProgress();
  }

  Future<void> _loadProgress() async {
    final data = await _localProgress.loadProgress(_opName);
    if (!mounted) return;
    setState(() {
      _completed = data['completed']!;
      _errors = data['errors']!;
      _maxStreak = data['maxStreak']!;
      _coins = data['coins']!;
    });
    _problem = SumGenerator.generateProgressive(
      _completed, operation: widget.operation, decimal: _decimalMode);
  }

  void _saveProgress() {
    if (_classroom.isInClassroom) return;
    _localProgress.saveProgress(
      operation: _opName,
      completed: _completed,
      errors: _errors,
      maxStreak: _maxStreak,
      coins: _coins,
    );
  }

  @override
  void dispose() {
    _classroom.flush();
    super.dispose();
  }

  void _newProblem() {
    setState(() {
      _problem = SumGenerator.generateProgressive(
        _completed,
        operation: widget.operation,
        decimal: _decimalMode,
      );
    });
  }

  void _resetStats() {
    setState(() {
      _completed = 0;
      _errors = 0;
      _streak = 0;
      _maxStreak = 0;
      _coins = 0;
      _starsInCurrentCoinCycle = 0;
    });
  }

  String get _opName => switch (widget.operation) {
    OperationType.sum => 'suma',
    OperationType.subtraction => 'resta',
    OperationType.multiplication => 'multi',
    OperationType.division => 'div',
  };

  String get _problemStr => '${_problem.a} ${switch (widget.operation) {
    OperationType.sum => '+',
    OperationType.subtraction => '-',
    OperationType.multiplication => '×',
    OperationType.division => '÷',
  }} ${_problem.b}';

  void _reportEvent(bool correct, {String? answer}) {
    _classroom.sendEvent(
      eventType: correct ? 'correct' : 'error',
      operationType: _opName,
      problemText: _problemStr,
      studentAnswer: answer,
      correctAnswer: '${_problem.answer}',
    );
  }

  // --- Practicar callbacks ---
  void _onPracticeCompleted(bool correct) {
    if (correct) {
      _audio.playCorrect();
    } else {
      _audio.playWrong();
    }
    setState(() {
      _completed++;
      if (!correct) _errors++;
    });
    _reportEvent(correct);
    _saveProgress();
    Future.delayed(const Duration(milliseconds: 800), _newProblem);
  }

  void _onPracticeError() {
    _audio.playWrong();
    setState(() {
      _errors++;
    });
    _reportEvent(false);
    _saveProgress();
  }

  // --- Desafio callbacks ---
  void _onEvalSubmitted(bool correct) {
    if (correct) {
      _audio.playCorrect();
    } else {
      _audio.playWrong();
    }
    setState(() {
      _completed++;
      if (correct) {
        _streak++;
        _starsInCurrentCoinCycle++;
        if (_streak > _maxStreak) _maxStreak = _streak;
        if (_starsInCurrentCoinCycle >= 10) {
          _coins++;
          _starsInCurrentCoinCycle = 0;
          _audio.playCoin();
        }
        if (_streak > 0 && _streak % 5 == 0) {
          _audio.playStreak();
        }
      } else {
        _errors++;
        _streak = 0;
        _starsInCurrentCoinCycle = 0;
      }
    });
    _reportEvent(correct);
    _saveProgress();
    Future.delayed(const Duration(milliseconds: 1500), _newProblem);
  }

  Widget _buildOperationWidget() {
    switch (widget.operation) {
      case OperationType.multiplication:
        return ColumnMultiplicationWidget(
          key: ValueKey('mul-${_isEvalMode ? 'e' : 'p'}-${_problem.a}-${_problem.b}'),
          problem: _problem,
          onCompleted: _isEvalMode ? _onEvalSubmitted : _onPracticeCompleted,
          onError: _isEvalMode ? null : _onPracticeError,
          evalMode: _isEvalMode,
        );
      case OperationType.division:
        return ColumnDivisionWidget(
          key: ValueKey('div-${_isEvalMode ? 'e' : 'p'}-${_mentalMode ? 'm' : 'p'}-${_decimalMode ? 'd' : 'i'}-${_problem.a}-${_problem.b}'),
          problem: _problem,
          onCompleted: _isEvalMode ? _onEvalSubmitted : _onPracticeCompleted,
          onError: _isEvalMode ? null : _onPracticeError,
          mentalMode: _isEvalMode ? true : _mentalMode,
          decimalMode: _decimalMode,
          evalMode: _isEvalMode,
        );
      case OperationType.subtraction:
        return ColumnSubtractionWidget(
          key: ValueKey('sub-${_isEvalMode ? 'e' : 'p'}-${_problem.a}-${_problem.b}'),
          problem: _problem,
          onCompleted: _isEvalMode ? _onEvalSubmitted : _onPracticeCompleted,
          onError: _isEvalMode ? null : _onPracticeError,
          evalMode: _isEvalMode,
        );
      case OperationType.sum:
        return _isEvalMode
            ? EvalSumWidget(
                key: ValueKey('eval-${_problem.a}-${_problem.b}'),
                problem: _problem,
                onSubmitted: _onEvalSubmitted,
              )
            : ColumnSumWidget(
                key: ValueKey('${_problem.a}-${_problem.b}'),
                problem: _problem,
                onCompleted: _onPracticeCompleted,
                onError: _onPracticeError,
              );
    }
  }

  /// Color based on error ratio with grace period
  Color get _progressColor {
    if (_completed == 0) return const Color(0xFF00B894);

    final gracedErrors = _completed < 8
        ? (_errors - 3).clamp(0, _errors)
        : _errors;

    final total = _completed + _errors;
    final errorRate = gracedErrors / total;

    if (errorRate < 0.05) return const Color(0xFF00B894);
    if (errorRate < 0.10) return const Color(0xFF2ECC71);
    if (errorRate < 0.15) return const Color(0xFF6FCF6A);
    if (errorRate < 0.20) return const Color(0xFFA3D977);
    if (errorRate < 0.25) return const Color(0xFFD4E157);
    if (errorRate < 0.30) return const Color(0xFFFFD93D);
    if (errorRate < 0.40) return const Color(0xFFFFC048);
    return AppColors.algorithm;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isEvalMode
        ? const Color(0xFF16162A)
        : AppColors.background;
    final fgColor = _isEvalMode
        ? const Color(0xFFCCCCEE)
        : Colors.white;

    final titleStr = '${_isEvalMode ? 'Desafio' : 'Practicar'} - ${switch (widget.operation) {
      OperationType.sum => 'Suma',
      OperationType.subtraction => 'Resta',
      OperationType.multiplication => 'Multiplicación',
      OperationType.division => 'División',
    }}';

    final titleWidget = _isEvalMode
        ? Text(titleStr)
        : _PlasmaText(text: titleStr);

    return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: titleWidget,
          backgroundColor: _isEvalMode
              ? const Color(0xFF1E1E34)
              : const Color(0xFF9B59E8).withValues(alpha: 0.08),
          foregroundColor: fgColor,
          elevation: 0,
          titleTextStyle: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: fgColor,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                // Mode switch
                _ModeSwitch(
                  isEvalMode: _isEvalMode,
                  onChanged: (val) {
                    setState(() => _isEvalMode = val);
                    _resetStats();
                    _newProblem();
                  },
                ),
                if (widget.operation == OperationType.division) ...[
                  const SizedBox(height: 6),
                  _DivisionModeChips(
                    mentalMode: _isEvalMode ? true : _mentalMode,
                    decimalMode: _decimalMode,
                    showMentalToggle: !_isEvalMode,
                    onMentalChanged: (val) {
                      setState(() => _mentalMode = val);
                      _resetStats();
                      _newProblem();
                    },
                    onDecimalChanged: (val) {
                      setState(() => _decimalMode = val);
                      _resetStats();
                      _newProblem();
                    },
                  ),
                ],
                const SizedBox(height: 8),
                // Progress bar + counter
                _ProgressIndicator(
                  completed: _completed,
                  color: _progressColor,
                  darkMode: _isEvalMode,
                ),
                if (_isEvalMode) ...[
                  const SizedBox(height: 6),
                  _StreakDisplay(
                    streak: _streak,
                    maxStreak: _maxStreak,
                    starsTowardCoin: _starsInCurrentCoinCycle,
                    coins: _coins,
                  ),
                ],
                const SizedBox(height: 10),
                // Sum widget
                Expanded(
                  child: widget.operation == OperationType.division
                      ? _buildOperationWidget()
                      : SingleChildScrollView(
                          child: _buildOperationWidget(),
                        ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

// --- Mode Switch ---

class _ModeSwitch extends StatelessWidget {
  final bool isEvalMode;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({
    required this.isEvalMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEvalMode
            ? const Color(0xFF222240)
            : AppColors.algorithm.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _modeTab('Practicar', !isEvalMode, () => onChanged(false)),
          _modeTab('Desafio', isEvalMode, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    final isDesafio = label == 'Desafio';
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? (isDesafio
                    ? const Color(0xFF6C5CE7)
                    : AppColors.algorithm)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : (isDesafio && !active
                      ? const Color(0xFF8888AA)
                      : AppColors.algorithm.withValues(alpha: 0.6)),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Streak display for desafio mode ---

class _StreakDisplay extends StatelessWidget {
  final int streak;
  final int maxStreak;
  final int starsTowardCoin;
  final int coins;

  const _StreakDisplay({
    required this.streak,
    required this.maxStreak,
    required this.starsTowardCoin,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Current streak
        Icon(
          Icons.local_fire_department_rounded,
          color: streak > 0
              ? const Color(0xFFFF6B6B)
              : const Color(0xFF444466),
          size: 20,
        ),
        const SizedBox(width: 2),
        Text(
          '$streak',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: streak > 0
                ? const Color(0xFFFF6B6B)
                : const Color(0xFF666688),
          ),
        ),
        const SizedBox(width: 12),
        // Best streak
        const Icon(
          Icons.emoji_events_rounded,
          color: Color(0xFF666688),
          size: 16,
        ),
        const SizedBox(width: 2),
        Text(
          '$maxStreak',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666688),
          ),
        ),
        const SizedBox(width: 16),
        // Stars toward next coin (10 dots)
        ...List.generate(10, (i) {
          final filled = i < starsTowardCoin;
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              Icons.star_rounded,
              size: 14,
              color: filled
                  ? const Color(0xFFFFD93D)
                  : const Color(0xFF333355),
            ),
          );
        }),
        const Spacer(),
        // Coins
        if (coins > 0) ...[
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFD93D),
            size: 22,
          ),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFD93D),
            ),
          ),
        ],
      ],
    );
  }
}

// --- Progress Indicator ---

class _ProgressIndicator extends StatelessWidget {
  final int completed;
  final Color color;
  final bool darkMode;

  static const int _milestone = 20;

  const _ProgressIndicator({
    required this.completed,
    required this.color,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (completed % _milestone) / _milestone;
    final milestonesDone = completed ~/ _milestone;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: darkMode
                      ? color.withValues(alpha: 0.15)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  widthFactor: completed == 0
                      ? 0
                      : progress == 0
                          ? 1.0
                          : progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (milestonesDone > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: List.generate(
                      milestonesDone.clamp(0, 10),
                      (_) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: darkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '$completed',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Plasma Text ---

class _PlasmaText extends StatelessWidget {
  final String text;
  const _PlasmaText({required this.text});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.orbitron(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    return Stack(
      children: [
        // Outer glow layer
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
              ..shader = const LinearGradient(
                colors: [Color(0xFFFF4081), Color(0xFF9B59E8), Color(0xFFFF4081)],
              ).createShader(const Rect.fromLTWH(0, 0, 300, 30)),
          ),
        ),
        // Inner glow layer
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
              ..shader = const LinearGradient(
                colors: [Color(0xFFE040FB), Color(0xFFCE93D8)],
              ).createShader(const Rect.fromLTWH(0, 0, 300, 30)),
          ),
        ),
        // White core
        Text(
          text,
          style: style.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

// --- Division Mode Chips ---

class _DivisionModeChips extends StatelessWidget {
  final bool mentalMode;
  final bool decimalMode;
  final bool showMentalToggle;
  final ValueChanged<bool> onMentalChanged;
  final ValueChanged<bool> onDecimalChanged;

  const _DivisionModeChips({
    required this.mentalMode,
    required this.decimalMode,
    this.showMentalToggle = true,
    required this.onMentalChanged,
    required this.onDecimalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showMentalToggle) ...[
          _check('Resta Mental', mentalMode, () => onMentalChanged(!mentalMode)),
          const SizedBox(width: 16),
        ],
        _check('Decimales', decimalMode, () => onDecimalChanged(!decimalMode)),
      ],
    );
  }

  Widget _check(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: active,
              onChanged: (_) => onTap(),
              activeColor: AppColors.algorithm,
              side: BorderSide(
                color: AppColors.textLight.withValues(alpha: 0.5),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.algorithm : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
