import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';
import '../../../core/character_type.dart';
import '../../../core/classroom_service.dart';
import '../../../core/audio_service.dart';
enum BattlePhase { selecting, fighting, transition, victory, defeat }

class BattleWidget extends StatefulWidget {
  final OperationType operation;
  const BattleWidget({super.key, this.operation = OperationType.sum});

  @override
  State<BattleWidget> createState() => _BattleWidgetState();
}

class _BattleWidgetState extends State<BattleWidget>
    with TickerProviderStateMixin {
  final _classroom = ClassroomService();
  final _audio = AudioService.instance;

  BattlePhase _phase = BattlePhase.selecting;
  CharacterType _playerCharacter = CharacterType.mage;
  List<CharacterType> _opponents = [];
  int _currentRound = 0;

  late SumProblem _problem;
  int _completed = 0;

  String _playerAnswer = '';
  int _playerHP = 7;

  int _machineHP = 7;

  late AnimationController _spellController;
  late AnimationController _machineSpellController;
  late AnimationController _shakeController;
  late AnimationController _impactController;
  bool _playerCasting = false;
  bool _machineCasting = false;
  bool _playerImpact = false;
  bool _machineImpact = false;
  bool? _lastResult;
  bool _machineThinking = false;

  double _machineProgress = 0;
  bool _roundActive = true;

  CharacterType get _currentOpponent => _opponents[_currentRound];

  void _selectCharacter(CharacterType character) {
    _audio.playSelect();
    setState(() {
      _playerCharacter = character;
      _opponents = CharacterType.values.where((c) => c != character).toList();
      _currentRound = 0;
      _phase = BattlePhase.fighting;
    });
    _startFight();
  }

  void _startFight() {
    setState(() {
      _playerHP = 7;
      _machineHP = 7;
      _completed = _currentRound == 0 ? 0 : 18;
      _playerAnswer = '';
      _lastResult = null;
      _roundActive = true;
      _machineProgress = 0;
      _playerCasting = false;
      _machineCasting = false;
      _playerImpact = false;
      _machineImpact = false;
    });
    _problem = SumGenerator.generateCombat(_completed, operation: widget.operation);
    _startMachineTimer();
  }

  @override
  void initState() {
    super.initState();
    _problem = SumGenerator.generateCombat(0, operation: widget.operation);
    _spellController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _machineSpellController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _shakeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _impactController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _roundActive = false;
    _machineThinking = false;
    _classroom.flush();
    _spellController.dispose();
    _machineSpellController.dispose();
    _shakeController.dispose();
    _impactController.dispose();
    super.dispose();
  }

  void _newProblem() {
    if (!mounted) return;
    setState(() {
      _completed++;
      _problem = SumGenerator.generateCombat(_completed, operation: widget.operation);
      _playerAnswer = '';
      _lastResult = null;
      _roundActive = true;
      _machineProgress = 0;
    });
    _startMachineTimer();
  }

  void _startMachineTimer() {
    final digits = _problem.answer.toString().length;
    final baseTime = 3000 + (digits * 1500);
    final variance = Random().nextInt(2000);
    final thinkTime = baseTime + variance;
    _machineThinking = true;
    _machineProgress = 0;
    _updateMachineProgress(thinkTime);
  }

  void _updateMachineProgress(int totalMs) {
    const step = 100;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_roundActive || !_machineThinking) return;
      setState(() => _machineProgress += step / totalMs);
      if (_machineProgress >= 1.0) {
        _machineAnswers();
      } else {
        _updateMachineProgress(totalMs);
      }
    });
  }

  void _machineAnswers() {
    if (!_roundActive || !mounted) return;
    _roundActive = false;
    _audio.playSpellCast();
    setState(() {
      _machineThinking = false;
      _machineCasting = true;
    });

    _machineSpellController.forward().then((_) {
      if (!mounted) return;
      _audio.playImpact();
      setState(() {
        _machineCasting = false;
        _playerImpact = true;
        _playerHP = (_playerHP - 1).clamp(0, 7);
      });
      _machineSpellController.reset();
      _impactController.forward().then((_) {
        if (!mounted) return;
        setState(() => _playerImpact = false);
        _impactController.reset();
      });
      _shakeController.forward().then((_) {
        if (!mounted) return;
        _shakeController.reset();
      });
      _checkGameOver();
      if (_playerHP > 0) {
        Future.delayed(const Duration(milliseconds: 600), _newProblem);
      }
    });
  }

  bool get _isDivision => widget.operation == OperationType.division;

  void _onDigitTap(int digit) {
    if (!_roundActive || _lastResult != null) return;
    _audio.playTap();
    if (_isDivision) {
      final answerLen = _problem.answer.toString().length;
      if (_playerAnswer.length >= answerLen) return;
      setState(() => _playerAnswer += digit.toString());
      return;
    }
    final answerLen = _problem.answer.toString().length;
    if (_playerAnswer.length >= answerLen) return;
    setState(() => _playerAnswer += digit.toString());
  }

  void _onBackspace() {
    if (!_roundActive || _playerAnswer.isEmpty || _lastResult != null) return;
    setState(() =>
        _playerAnswer = _playerAnswer.substring(0, _playerAnswer.length - 1));
  }

  String get _opName => switch (widget.operation) {
    OperationType.sum => 'suma',
    OperationType.subtraction => 'resta',
    OperationType.multiplication => 'multi',
    OperationType.division => 'div',
  };

  void _onSubmit() {
    if (_playerAnswer.isEmpty || !_roundActive || _lastResult != null) return;
    final bool correct;
    if (_isDivision) {
      final parsed = int.tryParse(_playerAnswer);
      correct = parsed != null && parsed == _problem.answer;
    } else {
      final reversed = _playerAnswer.split('').reversed.join('');
      correct = int.tryParse(reversed) == _problem.answer;
    }

    _classroom.sendEvent(
      eventType: correct ? 'correct' : 'error',
      operationType: _opName,
      problemText: '${_problem.a} ${_isDivision ? '÷' : switch (widget.operation) {
        OperationType.sum => '+',
        OperationType.subtraction => '-',
        OperationType.multiplication => '×',
        _ => '',
      }} ${_problem.b}',
      studentAnswer: _playerAnswer,
      correctAnswer: '${_problem.answer}',
    );

    if (correct) {
      _roundActive = false;
      _machineThinking = false;
      _audio.playSpellCast();
      setState(() {
        _lastResult = true;
        _playerCasting = true;
      });
      _spellController.forward().then((_) {
        if (!mounted) return;
        _audio.playImpact();
        setState(() {
          _machineImpact = true;
          _machineHP = (_machineHP - 1).clamp(0, 7);
          _playerCasting = false;
        });
        _spellController.reset();
        _impactController.forward().then((_) {
          if (!mounted) return;
          setState(() => _machineImpact = false);
          _impactController.reset();
        });
        _checkGameOver();
        if (_machineHP > 0) {
          Future.delayed(const Duration(milliseconds: 600), _newProblem);
        }
      });
    } else {
      _audio.playWrong();
      setState(() => _lastResult = false);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _playerAnswer = '';
          _lastResult = null;
        });
        _shakeController.forward().then((_) {
          if (!mounted) return;
          _shakeController.reset();
        });
      });
    }
  }

  void _checkGameOver() {
    if (_playerHP <= 0 || _machineHP <= 0) {
      _roundActive = false;
      _machineThinking = false;
      if (_machineHP <= 0) {
        if (_currentRound == 0) {
          _audio.playCorrect();
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (!mounted) return;
            setState(() => _phase = BattlePhase.transition);
          });
        } else {
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (!mounted) return;
            _audio.playVictory();
            setState(() => _phase = BattlePhase.victory);
          });
        }
      } else {
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (!mounted) return;
          _audio.playDefeat();
          setState(() => _phase = BattlePhase.defeat);
        });
      }
    }
  }

  void _startRound2() {
    setState(() {
      _currentRound = 1;
      _phase = BattlePhase.fighting;
    });
    _spellController.reset();
    _machineSpellController.reset();
    _shakeController.reset();
    _impactController.reset();
    _startFight();
  }

  void _goToSelection() {
    _spellController.reset();
    _machineSpellController.reset();
    _shakeController.reset();
    _impactController.reset();
    setState(() {
      _phase = BattlePhase.selecting;
      _currentRound = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == BattlePhase.selecting) return _buildSelectionScreen();
    if (_phase == BattlePhase.fighting) return _buildFightScreen();

    // For transition/victory/defeat, show arena behind with overlay on top
    return Stack(
      children: [
        _buildFightScreen(),
        Container(color: Colors.black.withValues(alpha: 0.6)),
        if (_phase == BattlePhase.transition) _buildTransitionScreen(),
        if (_phase == BattlePhase.victory) _buildEndScreen(won: true),
        if (_phase == BattlePhase.defeat) _buildEndScreen(won: false),
      ],
    );
  }

  Widget _buildSelectionScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Elige tu luchador',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.sumoGame)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: CharacterType.values.map((c) {
                return GestureDetector(
                  onTap: () => _selectCharacter(c),
                  child: Container(
                    width: 105,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A3E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.sumoGame.withValues(alpha: 0.4), width: 2),
                      boxShadow: [BoxShadow(
                        color: AppColors.sumoGame.withValues(alpha: 0.15),
                        blurRadius: 12, spreadRadius: 2)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..setEntry(0, 0, -1.0),
                          child: Image.asset(
                            c.spritePath('idle'),
                            width: 80, height: 100,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(c.displayName, style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFightScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ronda ${_currentRound + 1}/2',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sumoGame)),
              const SizedBox(width: 12),
              Text('vs ${_currentOpponent.displayName}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
        Expanded(
          child: _BattleArena(
            playerHP: _playerHP,
            machineHP: _machineHP,
            playerCasting: _playerCasting, machineCasting: _machineCasting,
            playerImpact: _playerImpact, machineImpact: _machineImpact,
            spellAnimation: _spellController,
            machineSpellAnimation: _machineSpellController,
            shakeAnimation: _shakeController,
            impactAnimation: _impactController,
            machineProgress: _machineProgress,
            playerCharacter: _playerCharacter,
            machineCharacter: _currentOpponent,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BattleProblem(problem: _problem, userAnswer: _playerAnswer, result: _lastResult),
            const SizedBox(width: 10),
            Expanded(
              child: _Keypad(
                onDigit: _onDigitTap, onBackspace: _onBackspace,
                onSubmit: _onSubmit,
                canSubmit: _playerAnswer.isNotEmpty && _roundActive,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransitionScreen() {
    final next = _opponents[1];
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A3E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.sumoGame.withValues(alpha: 0.4), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF00B894)),
            const SizedBox(height: 12),
            Text('${_opponents[0].displayName} ${_opponents[0].isFeminine ? 'derrotada' : 'derrotado'}!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF00B894))),
            const SizedBox(height: 24),
            const Text('Siguiente rival:',
                style: TextStyle(fontSize: 14, color: Colors.white54)),
            const SizedBox(height: 12),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..setEntry(0, 0, -1.0),
              child: Image.asset(
                next.spritePath('idle'),
                width: 100, height: 130,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 8),
            Text(next.displayName, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Dificultad aumentada',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.8))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startRound2,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('CONTINUAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sumoGame, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndScreen({required bool won}) {
    final defeatedBy = won ? null : _currentOpponent;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A3E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (won ? const Color(0xFFFFD93D) : AppColors.incorrect).withValues(alpha: 0.4),
            width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
              size: 56,
              color: won ? const Color(0xFFFFD93D) : AppColors.incorrect),
            const SizedBox(height: 12),
            Text(won ? 'Victoria Total!' : 'Derrota',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: won ? const Color(0xFFFFD93D) : AppColors.incorrect)),
            const SizedBox(height: 8),
            Text(
              won
                  ? 'Has derrotado a todos los rivales!'
                  : '${defeatedBy!.displayName} te ha derrotado.\nSigue practicando!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goToSelection,
              icon: Icon(won ? Icons.replay_rounded : Icons.refresh_rounded),
              label: Text(won ? 'JUGAR DE NUEVO' : 'INTENTAR DE NUEVO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sumoGame, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// (Character selector and battle type selector removed — selection is now a phase)

// ==========================================================
// BATTLE ARENA
// ==========================================================

class _BattleArena extends StatelessWidget {
  final int playerHP, machineHP;
  final bool playerCasting, machineCasting, playerImpact, machineImpact;
  final AnimationController spellAnimation, machineSpellAnimation;
  final AnimationController shakeAnimation, impactAnimation;
  final double machineProgress;
  final CharacterType playerCharacter, machineCharacter;

  const _BattleArena({
    required this.playerHP,
    required this.machineHP,
    required this.playerCasting, required this.machineCasting,
    required this.playerImpact, required this.machineImpact,
    required this.spellAnimation, required this.machineSpellAnimation,
    required this.shakeAnimation, required this.impactAnimation,
    required this.machineProgress,
    required this.playerCharacter, required this.machineCharacter,
  });

  @override
  Widget build(BuildContext context) {
    const mageWidth = 90.0;
    const mageMargin = 16.0;

    return LayoutBuilder(builder: (context, constraints) {
      final arenaWidth = constraints.maxWidth;
      final arenaHeight = constraints.maxHeight;
      final playerX = mageMargin;
      final spellStartX = playerX + mageWidth;
      final spellEndX = arenaWidth - mageMargin - mageWidth - 8;
      final spellTravel = spellEndX - spellStartX;

      return Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D2B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF533483).withValues(alpha: 0.4), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: _ArenaBgPainter(),
            child: Stack(children: [
              // Ground platform with perspective
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: CustomPaint(
                  size: Size(arenaWidth, 55),
                  painter: _GroundPainter(),
                ),
              ),

              // Player mage shadow
              Positioned(
                left: playerX + 10, bottom: 8,
                child: Container(
                  width: 70, height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12, spreadRadius: 2)],
                  ),
                ),
              ),
              // Machine mage shadow
              Positioned(
                right: mageMargin + 10, bottom: 8,
                child: Container(
                  width: 70, height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12, spreadRadius: 2)],
                  ),
                ),
              ),

              // Player mage
              Positioned(
                left: playerX, bottom: 42,
                child: AnimatedBuilder(
                  animation: shakeAnimation,
                  builder: (_, child) {
                    final shake = shakeAnimation.isAnimating
                        ? sin(shakeAnimation.value * pi * 6) * 6 : 0.0;
                    return Transform.translate(offset: Offset(shake, 0), child: child);
                  },
                  child: _ChibiMage(
                    color: const Color(0xFF6C5CE7), facingRight: true,
                    casting: playerCasting, hp: playerHP, maxHP: 7,
                    shield: 0, label: playerCharacter.displayName,
                    hit: playerImpact,
                    victory: machineHP <= 0,
                    character: playerCharacter),
                ),
              ),

              // Machine mage
              Positioned(
                right: mageMargin, bottom: 42,
                child: _ChibiMage(
                  color: const Color(0xFFFF6B6B), facingRight: false,
                  casting: machineCasting, hp: machineHP, maxHP: 7,
                  shield: 0, label: machineCharacter.displayName,
                  hit: machineImpact,
                  victory: playerHP <= 0,
                  character: machineCharacter),
              ),

              Positioned.fill(
                child: _buildSpell(spellAnimation, spellStartX, spellTravel,
                    const Color(0xFF6C5CE7), false, arenaHeight),
              ),
              Positioned.fill(
                child: _buildSpell(machineSpellAnimation, spellStartX, spellTravel,
                    const Color(0xFFFF6B6B), true, arenaHeight),
              ),

              Positioned.fill(
                child: _buildImpact(impactAnimation, spellEndX, const Color(0xFF6C5CE7), arenaHeight, machineImpact),
              ),
              Positioned.fill(
                child: _buildImpact(impactAnimation, spellStartX, const Color(0xFFFF6B6B), arenaHeight, playerImpact),
              ),

              Positioned(
                right: 20, top: 10,
                child: Opacity(
                  opacity: (machineProgress > 0 && machineProgress < 1) ? 1.0 : 0.0,
                  child: SizedBox(width: 80, child: Column(children: [
                    Text('${machineCharacter.displayName} piensa...',
                        style: const TextStyle(fontSize: 9, color: Colors.white54)),
                    const SizedBox(height: 2),
                    LinearProgressIndicator(
                      value: machineProgress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B6B)),
                      borderRadius: BorderRadius.circular(4)),
                  ])),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildSpell(AnimationController anim, double startX, double travel,
      Color color, bool reverse, double arenaHeight) {
    final spellY = arenaHeight / 2;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final p = anim.value;
        if (p == 0) return const SizedBox.shrink();
        final mainX = reverse ? startX + travel - (p * travel) : startX + (p * travel);
        final yOff = sin(p * pi * 3) * 6;

        return Stack(children: [
          ...List.generate(8, (i) {
            final delay = (i + 1) * 0.05;
            final tp = (p - delay).clamp(0.0, 1.0);
            if (tp <= 0) return const SizedBox.shrink();
            final tx = reverse ? startX + travel - (tp * travel) : startX + (tp * travel);
            final size = 14.0 - i * 1.4;
            final alpha = 0.5 - i * 0.05;
            return Positioned(
              left: tx - size / 2,
              top: spellY + sin(tp * pi * 3 + i * 0.5) * 5,
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: alpha * 0.6), blurRadius: 10)],
                  gradient: RadialGradient(colors: [
                    color.withValues(alpha: alpha),
                    color.withValues(alpha: alpha * 0.3),
                    Colors.transparent,
                  ]),
                ),
              ),
            );
          }),
          Positioned(
            left: mainX - 12, top: spellY - 12 + yOff,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white,
                  Color.lerp(Colors.white, color, 0.4)!,
                  color,
                  color.withValues(alpha: 0.2),
                ], stops: const [0.0, 0.25, 0.55, 1.0]),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.9), blurRadius: 24, spreadRadius: 8),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2),
                ],
              ),
            ),
          ),
          ...List.generate(4, (i) {
            final angle = (p * pi * 6) + (i * pi / 2);
            final dist = 16.0;
            final sx = mainX + cos(angle) * dist;
            final sy = spellY + yOff + sin(angle) * dist * 0.6;
            return Positioned(
              left: sx - 3, top: sy - 3,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.8),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
            );
          }),
        ]);
      },
    );
  }

  Widget _buildImpact(AnimationController anim, double x, Color color, double arenaHeight, bool active) {
    final spellY = arenaHeight / 2;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final p = anim.value;
        if (p == 0 || !active) return const SizedBox.shrink();
        final fade = (1.0 - p).clamp(0.0, 1.0);
        final ringSize = 20 + p * 60;

        return Stack(children: [
          Positioned(
            left: x - ringSize / 2, top: spellY - ringSize / 2,
            child: Container(
              width: ringSize, height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: fade * 0.8),
                  width: 3 * (1.0 - p)),
                boxShadow: [BoxShadow(
                  color: color.withValues(alpha: fade * 0.4),
                  blurRadius: 20, spreadRadius: 4)],
              ),
            ),
          ),
          Positioned(
            left: x - 18, top: spellY - 18,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: fade * 0.9),
                  color.withValues(alpha: fade * 0.5),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Burst debris
          ...List.generate(10, (i) {
            final angle = (i / 10) * pi * 2 + 0.3;
            final dist = p * 50;
            final px = x + cos(angle) * dist;
            final py = 96 + sin(angle) * dist;
            final size = 5.0 * (1.0 - p * 0.7);
            return Positioned(
              left: px - size / 2, bottom: py - size / 2,
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: i % 3 == 0 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: i % 3 == 0 ? BorderRadius.circular(1) : null,
                  color: (i % 2 == 0 ? Colors.white : color).withValues(alpha: fade * 0.9),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: fade * 0.4), blurRadius: 4)],
                ),
              ),
            );
          }),
        ]);
      },
    );
  }
}

// --- Arena background painter ---

class _ArenaBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0), Offset(0, size.height),
        [const Color(0xFF0D0D2B), const Color(0xFF1A1040), const Color(0xFF2D1B69)],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, skyPaint);

    // Stars
    final rng = Random(42);
    final starPaint = Paint();
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.7;
      final r = 0.5 + rng.nextDouble() * 1.5;
      final alpha = (0.3 + rng.nextDouble() * 0.7).clamp(0.0, 1.0);
      starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Nebula glow
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.25),
      60,
      Paint()
        ..color = const Color(0xFF6C5CE7).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.35),
      50,
      Paint()
        ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Ground painter ---

class _GroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 15)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, 15)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0), Offset(0, size.height),
        [const Color(0xFF2D1B69), const Color(0xFF1A1040), const Color(0xFF0D0D2B)],
        [0.0, 0.5, 1.0],
      ));

    // Stone line
    canvas.drawPath(
      Path()
        ..moveTo(0, 16)
        ..quadraticBezierTo(size.width * 0.5, 1, size.width, 16),
      Paint()
        ..color = const Color(0xFF533483).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================================
// PUPPET MAGE — 2D layered articulated character (unisex witch/wizard)
// ==========================================================

enum _MagePose { idle, casting, hit, defeated, victory }

class _ChibiMage extends StatefulWidget {
  final Color color;
  final bool facingRight, casting;
  final int hp, maxHP, shield;
  final String label;
  final bool hit;
  final bool victory;
  final CharacterType character;

  const _ChibiMage({
    required this.color, required this.facingRight, required this.casting,
    required this.hp, required this.maxHP, required this.shield,
    required this.label, this.hit = false, this.victory = false,
    required this.character,
  });

  @override
  State<_ChibiMage> createState() => _ChibiMageState();
}

class _ChibiMageState extends State<_ChibiMage>
    with SingleTickerProviderStateMixin {
  late AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  _MagePose get _currentPose {
    if (widget.hp <= 0) return _MagePose.defeated;
    if (widget.victory) return _MagePose.victory;
    if (widget.hit) return _MagePose.hit;
    if (widget.casting) return _MagePose.casting;
    return _MagePose.idle;
  }

  String get _spriteAsset {
    final pose = switch (_currentPose) {
      _MagePose.idle => 'idle',
      _MagePose.casting => 'casting',
      _MagePose.hit => 'hit',
      _MagePose.defeated => 'defeated',
      _MagePose.victory => 'victory',
    };
    return widget.character.spritePath(pose);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: List.generate(widget.maxHP, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i < widget.hp ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 14,
            color: i < widget.hp ? const Color(0xFFFF6B6B) : Colors.white24),
        );
      })),
      if (widget.shield > 0)
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.shield_rounded, size: 12, color: Color(0xFF00B894))),
      const SizedBox(height: 2),
      AnimatedBuilder(
        animation: _idle,
        builder: (_, __) {
          final bounce = sin(_idle.value * pi) * 3.0;
          return Transform(
            alignment: Alignment.center,
            transform: widget.facingRight
                ? (Matrix4.identity()..setEntry(0, 0, -1.0))
                : Matrix4.identity(),
            child: Transform.translate(
              offset: Offset(0, -bounce),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Image.asset(
                  _spriteAsset,
                  key: ValueKey(_spriteAsset),
                  width: 110,
                  height: 140,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 2),
      Text(widget.label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
    ]);
  }
}


// --- Battle problem display ---

class _BattleProblem extends StatelessWidget {
  final SumProblem problem;
  final String userAnswer;
  final bool? result;

  const _BattleProblem({required this.problem, required this.userAnswer, required this.result});

  static const double _cell = 40;
  static const double _gap = 3;

  Color _colColor(int col, int maxLen) {
    final pos = maxLen - 1 - col;
    return switch (pos) {
      0 => AppColors.units,
      1 => AppColors.tens,
      2 => AppColors.hundreds,
      _ => AppColors.thousands,
    };
  }

  bool get _isMultiplication => problem.operation == OperationType.multiplication;
  bool get _isDivision => problem.operation == OperationType.division;

  @override
  Widget build(BuildContext context) {
    final maxLen = problem.answer.toString().length;
    final gridWidth = maxLen * (_cell + _gap * 2);
    final extraRight = _isMultiplication ? (problem.b.toString().length * 16.0) + 40 : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 16 + (_isDivision ? 0 : extraRight), 10),
      decoration: BoxDecoration(
        color: result == null
            ? AppColors.sumoGame.withValues(alpha: 0.08)
            : (result! ? AppColors.correct.withValues(alpha: 0.1) : AppColors.incorrect.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result == null
              ? AppColors.sumoGame.withValues(alpha: 0.2)
              : (result! ? AppColors.correct.withValues(alpha: 0.3) : AppColors.incorrect.withValues(alpha: 0.3))),
      ),
      child: _isDivision
          ? _buildDivisionLayout()
          : _isMultiplication
              ? _buildMultiplicationLayout(maxLen, gridWidth)
              : _buildSumLayout(maxLen, gridWidth),
    );
  }

  Widget _buildDivisionLayout() {
    final answerColor = result != null
        ? (result! ? AppColors.correct : AppColors.incorrect)
        : AppColors.sumoGame;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '${problem.a}  ÷  ${problem.b}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '=',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 60),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: userAnswer.isNotEmpty
                ? answerColor.withValues(alpha: 0.12)
                : AppColors.sumoGame.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: userAnswer.isNotEmpty
                  ? answerColor.withValues(alpha: 0.3)
                  : AppColors.sumoGame.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Text(
            userAnswer.isEmpty ? ' ' : userAnswer,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: answerColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplicationLayout(int maxLen, double gridWidth) {
    final aDigits = problem.a.toString().split('').map(int.parse).toList();
    final bDigitLen = problem.b.toString().length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: gridWidth,
            height: _cell,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(maxLen, (gridCol) {
                    final idx = gridCol - (maxLen - aDigits.length);
                    final show = idx >= 0 && idx < aDigits.length;
                    return Container(
                      width: _cell, height: _cell,
                      margin: const EdgeInsets.symmetric(horizontal: _gap),
                      alignment: Alignment.center,
                      child: show
                          ? Text('${aDigits[idx]}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary))
                          : null,
                    );
                  }),
                ),
                Positioned(
                  right: -((bDigitLen * 16.0) + 40),
                  top: 0, bottom: 0,
                  child: Center(
                    child: Text('× ${problem.b}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: gridWidth + 32,
          height: 2.5,
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _buildAnswerRow(maxLen, gridWidth),
      ],
    );
  }

  Widget _buildSumLayout(int maxLen, double gridWidth) {
    final aDigits = problem.a.toString().padLeft(maxLen, '0').split('').map(int.parse).toList();
    final bDigits = problem.b.toString().padLeft(maxLen, '0').split('').map(int.parse).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildNumberRow(aDigits, maxLen, gridWidth),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(problem.operatorSymbol,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            _buildNumberRow(bDigits, maxLen, gridWidth),
          ],
        ),
        Container(
          width: gridWidth + 32,
          height: 2.5,
          margin: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _buildAnswerRow(maxLen, gridWidth),
      ],
    );
  }

  Widget _buildNumberRow(List<int> digits, int maxLen, double gridWidth) {
    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(maxLen, (i) {
          final isLeadingZero = digits[i] == 0 &&
              i < maxLen - 1 &&
              digits.sublist(0, i + 1).every((d) => d == 0);
          return Container(
            width: _cell, height: _cell,
            margin: const EdgeInsets.symmetric(horizontal: _gap),
            alignment: Alignment.center,
            child: Text(
              isLeadingZero ? '' : '${digits[i]}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAnswerRow(int maxLen, double gridWidth) {
    final typed = userAnswer.length;
    final activeCol = typed < maxLen ? maxLen - 1 - typed : null;

    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(maxLen, (col) {
          final color = _colColor(col, maxLen);
          final ansIdx = maxLen - 1 - col;
          final isFilled = ansIdx < typed;
          final digit = isFilled ? userAnswer[ansIdx] : null;
          final isActive = col == activeCol && result == null;

          return Container(
            width: _cell, height: _cell,
            margin: const EdgeInsets.symmetric(horizontal: _gap),
            decoration: BoxDecoration(
              color: isFilled
                  ? color.withValues(alpha: 0.12)
                  : isActive
                      ? color.withValues(alpha: 0.08)
                      : AppColors.background,
              borderRadius: BorderRadius.circular(10),
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
                ? Text(digit!,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                      color: result != null ? (result! ? AppColors.correct : AppColors.incorrect) : color))
                : isActive
                    ? Icon(Icons.arrow_downward_rounded, size: 16, color: color.withValues(alpha: 0.4))
                    : null,
          );
        }),
      ),
    );
  }
}

// --- Keypad ---

class _Keypad extends StatelessWidget {
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace, onSubmit;
  final bool canSubmit;

  const _Keypad({
    required this.onDigit, required this.onBackspace,
    required this.onSubmit, required this.canSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [_key(1), _key(2), _key(3)]),
      const SizedBox(height: 4),
      Row(children: [_key(4), _key(5), _key(6)]),
      const SizedBox(height: 4),
      Row(children: [_key(7), _key(8), _key(9)]),
      const SizedBox(height: 4),
      Row(children: [
        _actionKey(Icons.backspace_rounded, onBackspace, AppColors.textSecondary),
        _key(0),
        _actionKey(Icons.bolt_rounded, canSubmit ? onSubmit : () {},
            canSubmit ? const Color(0xFFFFD93D) : AppColors.textLight),
      ]),
    ]);
  }

  Widget _key(int digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onDigit(digit),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
              child: Text('$digit',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionKey(IconData icon, VoidCallback onTap, Color c) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withValues(alpha: 0.3))),
              child: Icon(icon, color: c, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
