import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/sum_generator.dart';
import '../../core/audio_service.dart';
import 'widgets/dohyo_widget.dart';

class SumoScreen extends StatefulWidget {
  const SumoScreen({super.key});

  @override
  State<SumoScreen> createState() => _SumoScreenState();
}

class _SumoScreenState extends State<SumoScreen> {
  final _audio = AudioService.instance;
  Difficulty _difficulty = Difficulty.easy;
  bool _gameActive = false;
  bool _gameOver = false;
  bool _playerWon = false;

  // Positions: 0.0 = center, -1.0 = player pushed out, 1.0 = rival pushed out
  double _position = 0.0;
  static const double _pushAmount = 0.15;
  static const double _winThreshold = 1.0;

  late SumProblem _currentProblem;
  String _inputValue = '';
  Timer? _rivalTimer;
  int _playerScore = 0;
  int _rivalScore = 0;

  double get _rivalSpeed {
    return switch (_difficulty) {
      Difficulty.easy => 6.0,
      Difficulty.medium => 4.5,
      Difficulty.hard => 3.0,
      Difficulty.expert => 2.0,
    };
  }

  void _startGame() {
    setState(() {
      _gameActive = true;
      _gameOver = false;
      _position = 0.0;
      _playerScore = 0;
      _rivalScore = 0;
    });
    _nextProblem();
    _startRivalTimer();
  }

  void _nextProblem() {
    setState(() {
      _currentProblem = SumGenerator.generate(_difficulty);
      _inputValue = '';
    });
  }

  void _startRivalTimer() {
    _rivalTimer?.cancel();
    _rivalTimer = Timer.periodic(
      Duration(milliseconds: (_rivalSpeed * 1000).toInt()),
      (_) {
        if (!_gameActive) return;
        _rivalPushes();
      },
    );
  }

  void _rivalPushes() {
    _audio.playImpact();
    setState(() {
      _position -= _pushAmount;
      _rivalScore++;
    });
    _checkWin();
  }

  void _playerPushes() {
    _audio.playCorrect();
    setState(() {
      _position += _pushAmount;
      _playerScore++;
    });
    _checkWin();
    _nextProblem();
  }

  void _playerFails() {
    _audio.playWrong();
    setState(() {
      _position -= _pushAmount * 0.5;
    });
    _checkWin();
    _nextProblem();
  }

  void _checkWin() {
    if (_position >= _winThreshold) {
      _endGame(playerWon: true);
    } else if (_position <= -_winThreshold) {
      _endGame(playerWon: false);
    }
  }

  void _endGame({required bool playerWon}) {
    _rivalTimer?.cancel();
    if (playerWon) {
      _audio.playVictory();
    } else {
      _audio.playDefeat();
    }
    setState(() {
      _gameActive = false;
      _gameOver = true;
      _playerWon = playerWon;
    });
  }

  void _onDigit(String digit) {
    if (!_gameActive) return;
    _audio.playTap();
    setState(() {
      _inputValue += digit;
    });

    final parsed = int.tryParse(_inputValue);
    if (parsed == null) return;

    if (parsed == _currentProblem.answer) {
      _playerPushes();
    } else if (_inputValue.length >= _currentProblem.answer.toString().length) {
      _playerFails();
    }
  }

  void _onDelete() {
    if (!_gameActive || _inputValue.isEmpty) return;
    setState(() {
      _inputValue = _inputValue.substring(0, _inputValue.length - 1);
    });
  }

  @override
  void dispose() {
    _rivalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combate Sumo'),
        backgroundColor: AppColors.sumoGame.withValues(alpha: 0.08),
        foregroundColor: AppColors.sumoGame,
        elevation: 0,
      ),
      body: _gameActive || _gameOver
          ? _buildGame(context)
          : _buildSetup(context),
    );
  }

  Widget _buildSetup(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_mma_rounded,
            size: 80,
            color: AppColors.sumoGame.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Combate Sumo',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Responde sumas correctamente para empujar a tu rival fuera del dohyo. El rival empuja automaticamente cada cierto tiempo.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _DifficultySelector(
            selected: _difficulty,
            color: AppColors.sumoGame,
            onChanged: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sumoGame,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'LUCHAR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGame(BuildContext context) {
    return Column(
      children: [
        // Dohyo visualization
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Score row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tu: $_playerScore',
                      style: TextStyle(
                        color: AppColors.algorithm,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Rival: $_rivalScore',
                      style: TextStyle(
                        color: AppColors.sumoGame,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Dohyo
                Expanded(
                  child: DohyoWidget(
                    position: _position,
                    gameOver: _gameOver,
                    playerWon: _playerWon,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_gameOver)
          // Game over message
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _playerWon ? 'GANASTE!' : 'PERDISTE',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: _playerWon
                            ? AppColors.correct
                            : AppColors.incorrect,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sumoGame,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('REVANCHA'),
                ),
              ],
            ),
          )
        else ...[
          // Problem display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: AppColors.surface,
            child: Column(
              children: [
                Text(
                  '${_currentProblem.a} + ${_currentProblem.b}',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 160,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.textLight,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _inputValue.isEmpty ? '' : _inputValue,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
              ],
            ),
          ),
          // Numpad
          _buildNumpad(),
        ],
      ],
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: AppColors.background,
      child: Column(
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['DEL', '0', ''],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: row.map((label) {
                  if (label.isEmpty) return const Expanded(child: SizedBox());
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: label == 'DEL'
                              ? _onDelete
                              : () => _onDigit(label),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: label == 'DEL'
                                ? AppColors.textLight.withValues(alpha: 0.3)
                                : AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: label == 'DEL' ? 14 : 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  final Difficulty selected;
  final Color color;
  final ValueChanged<Difficulty> onChanged;

  const _DifficultySelector({
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Difficulty.values.map((d) {
        final isSelected = d == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  SumGenerator.difficultyLabel(d),
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
