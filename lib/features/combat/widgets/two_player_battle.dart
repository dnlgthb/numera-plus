import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';
import '../../../core/audio_service.dart';

class TwoPlayerBattleScreen extends StatefulWidget {
  const TwoPlayerBattleScreen({super.key});

  @override
  State<TwoPlayerBattleScreen> createState() => _TwoPlayerBattleScreenState();
}

class _TwoPlayerBattleScreenState extends State<TwoPlayerBattleScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService.instance;
  late SumProblem _problem;
  int _completed = 0;

  int _p1HP = 3, _p1Shield = 1;
  String _p1Answer = '';
  bool? _p1Result;

  int _p2HP = 3, _p2Shield = 1;
  String _p2Answer = '';
  bool? _p2Result;

  bool _roundActive = true;

  late AnimationController _spellController;
  late AnimationController _shakeP1Controller;
  late AnimationController _shakeP2Controller;
  int _spellDirection = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _problem = SumGenerator.generateProgressive(0);
    _spellController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeP1Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeP2Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _roundActive = false;
    _spellController.dispose();
    _shakeP1Controller.dispose();
    _shakeP2Controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _newRound() {
    if (!mounted) return;
    setState(() {
      _completed++;
      _problem = SumGenerator.generateProgressive(_completed);
      _p1Answer = '';
      _p2Answer = '';
      _p1Result = null;
      _p2Result = null;
      _roundActive = true;
      _spellDirection = 0;
    });
  }

  void _submit(int player) {
    final answer = player == 1 ? _p1Answer : _p2Answer;
    if (answer.isEmpty || !_roundActive) return;
    if (player == 1 && _p1Result != null) return;
    if (player == 2 && _p2Result != null) return;

    final correct = int.tryParse(answer) == _problem.answer;
    setState(() {
      if (player == 1) _p1Result = correct;
      if (player == 2) _p2Result = correct;
    });

    if (correct) {
      _roundActive = false;
      _audio.playSpellCast();
      setState(() => _spellDirection = player);
      _spellController.forward().then((_) {
        _spellController.reset();
        if (!mounted) return;
        _audio.playImpact();
        setState(() {
          final target = player == 1 ? 2 : 1;
          if (target == 1) {
            if (_p1Shield > 0) {
              _p1Shield = 0;
            } else {
              _p1HP = (_p1HP - 1).clamp(0, 3);
            }
          } else {
            if (_p2Shield > 0) {
              _p2Shield = 0;
            } else {
              _p2HP = (_p2HP - 1).clamp(0, 3);
            }
          }
          _spellDirection = 0;
        });
        final shaker = player == 1 ? _shakeP2Controller : _shakeP1Controller;
        shaker.forward().then((_) {
          if (mounted) shaker.reset();
        });
        final targetHP = player == 1 ? _p2HP : _p1HP;
        if (targetHP <= 0) {
          _endGame(player);
        } else {
          Future.delayed(const Duration(milliseconds: 800), _newRound);
        }
      });
    } else {
      _audio.playWrong();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          if (player == 1) {
            _p1Answer = '';
            _p1Result = null;
          } else {
            _p2Answer = '';
            _p2Result = null;
          }
        });
      });
      final shaker = player == 1 ? _shakeP1Controller : _shakeP2Controller;
      shaker.forward().then((_) {
        if (mounted) shaker.reset();
      });
    }
  }

  void _endGame(int winner) {
    _audio.playVictory();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFFFD93D), size: 32),
            const SizedBox(width: 10),
            Text('Jugador $winner gana!'),
          ]),
          content: Text(
              'El Mago ${winner == 1 ? "Purpura" : "Rojo"} es el vencedor!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetGame();
              },
              child: const Text('Revancha'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Salir'),
            ),
          ],
        ),
      );
    });
  }

  void _resetGame() {
    if (!mounted) return;
    setState(() {
      _p1HP = 3;
      _p1Shield = 1;
      _p2HP = 3;
      _p2Shield = 1;
      _completed = 0;
    });
    _newRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // Player 2 (top, rotated 180° with RotatedBox for proper hit testing)
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: _PlayerSide(
                  playerNum: 2,
                  color: const Color(0xFFFF6B6B),
                  hp: _p2HP,
                  shield: _p2Shield,
                  answer: _p2Answer,
                  result: _p2Result,
                  problem: _problem,
                  roundActive: _roundActive,
                  shakeController: _shakeP2Controller,
                  onDigit: (d) {
                    if (!_roundActive || _p2Result != null) return;
                    setState(() => _p2Answer += d.toString());
                  },
                  onBackspace: () {
                    if (!_roundActive ||
                        _p2Answer.isEmpty ||
                        _p2Result != null) {
                      return;
                    }
                    setState(() => _p2Answer =
                        _p2Answer.substring(0, _p2Answer.length - 1));
                  },
                  onSubmit: () => _submit(2),
                ),
              ),
            ),

            // Center divider
            _CenterDivider(
              spellDirection: _spellDirection,
              spellAnimation: _spellController,
            ),

            // Player 1 (bottom, normal)
            Expanded(
              child: _PlayerSide(
                playerNum: 1,
                color: const Color(0xFF6C5CE7),
                hp: _p1HP,
                shield: _p1Shield,
                answer: _p1Answer,
                result: _p1Result,
                problem: _problem,
                roundActive: _roundActive,
                shakeController: _shakeP1Controller,
                onDigit: (d) {
                  if (!_roundActive || _p1Result != null) return;
                  setState(() => _p1Answer += d.toString());
                },
                onBackspace: () {
                  if (!_roundActive ||
                      _p1Answer.isEmpty ||
                      _p1Result != null) {
                    return;
                  }
                  setState(() => _p1Answer =
                      _p1Answer.substring(0, _p1Answer.length - 1));
                },
                onSubmit: () => _submit(1),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => Navigator.pop(context),
        backgroundColor: Colors.white12,
        child: const Icon(Icons.close, color: Colors.white70, size: 20),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}

// --- Player side ---

class _PlayerSide extends StatelessWidget {
  final int playerNum;
  final Color color;
  final int hp, shield;
  final String answer;
  final bool? result;
  final SumProblem problem;
  final bool roundActive;
  final AnimationController shakeController;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  const _PlayerSide({
    required this.playerNum,
    required this.color,
    required this.hp,
    required this.shield,
    required this.answer,
    required this.result,
    required this.problem,
    required this.roundActive,
    required this.shakeController,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeController,
      builder: (context, child) {
        final dx = shakeController.isAnimating
            ? (shakeController.value * 12.566).remainder(6.283) < 3.14
                ? 4.0
                : -4.0
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            // Header: label + HP
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('J$playerNum',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 8),
              ...List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          i < hp
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color:
                              i < hp ? const Color(0xFFFF6B6B) : Colors.white24,
                        ),
                      )),
              if (shield > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.shield_rounded,
                      size: 14, color: Color(0xFF00B894)),
                ),
            ]),
            const SizedBox(height: 6),

            // Problem + answer
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: result == null
                      ? color.withValues(alpha: 0.3)
                      : (result!
                          ? AppColors.correct
                          : AppColors.incorrect),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${problem.a} + ${problem.b} = ',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Container(
                    constraints: const BoxConstraints(minWidth: 50),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      answer.isEmpty ? '?' : answer,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: answer.isEmpty
                            ? Colors.white30
                            : (result == null
                                ? Colors.white
                                : (result!
                                    ? AppColors.correct
                                    : AppColors.incorrect)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Keypad
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(children: [
                      for (int d = 1; d <= 5; d++) _key(d, onDigit),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Row(children: [
                      for (int d = 6; d <= 9; d++) _key(d, onDigit),
                      _key(0, onDigit),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Row(children: [
                      _actionBtn(Icons.backspace_rounded, onBackspace,
                          Colors.white38, 2),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 3,
                        child: Material(
                          color: answer.isNotEmpty && roundActive && result == null
                              ? color.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: answer.isNotEmpty &&
                                    roundActive &&
                                    result == null
                                ? onSubmit
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: answer.isNotEmpty &&
                                            roundActive &&
                                            result == null
                                        ? color.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Icon(Icons.bolt_rounded,
                                  color: answer.isNotEmpty &&
                                          roundActive &&
                                          result == null
                                      ? color
                                      : Colors.white24,
                                  size: 24),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _key(int digit, ValueChanged<int> onDigit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onDigit(digit),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              child: Text('$digit',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, VoidCallback onTap, Color iconColor, int flex) {
    return Expanded(
      flex: flex,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

// --- Center divider with VS and spell ---

class _CenterDivider extends StatelessWidget {
  final int spellDirection;
  final AnimationController spellAnimation;

  const _CenterDivider({
    required this.spellDirection,
    required this.spellAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            const Color(0xFF1A1A2E),
            const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          ],
        ),
        border: const Border(
          top: BorderSide(color: Color(0xFF333366), width: 1),
          bottom: BorderSide(color: Color(0xFF333366), width: 1),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text('VS',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white24,
                  letterSpacing: 4)),
          if (spellDirection != 0)
            AnimatedBuilder(
              animation: spellAnimation,
              builder: (context, _) {
                final w = MediaQuery.of(context).size.width;
                final startX = spellDirection == 1 ? 40.0 : w - 40.0;
                final endX = spellDirection == 1 ? w - 40.0 : 40.0;
                final x = startX + (endX - startX) * spellAnimation.value;
                final c = spellDirection == 1
                    ? const Color(0xFF6C5CE7)
                    : const Color(0xFFFF6B6B);
                return Positioned(
                  left: x - 6,
                  top: 19,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: c.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 3)
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
