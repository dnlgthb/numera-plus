import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/sum_generator.dart';
import 'widgets/decomposition_widget.dart';

class MentalScreen extends StatefulWidget {
  const MentalScreen({super.key});

  @override
  State<MentalScreen> createState() => _MentalScreenState();
}

class _MentalScreenState extends State<MentalScreen> {
  Difficulty _difficulty = Difficulty.medium;
  late SumProblem _problem;
  int _score = 0;
  int _total = 0;
  bool _showingDecomposition = true;

  @override
  void initState() {
    super.initState();
    _problem = SumGenerator.generate(_difficulty);
  }

  void _newProblem() {
    setState(() {
      _problem = SumGenerator.generate(_difficulty);
      _showingDecomposition = true;
    });
  }

  void _onAnswer(int answer) {
    final correct = answer == _problem.answer;
    setState(() {
      _total++;
      if (correct) _score++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          correct ? 'Correcto!' : 'La respuesta es ${_problem.answer}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: correct ? AppColors.correct : AppColors.incorrect,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(milliseconds: 900), _newProblem);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculo Mental'),
        backgroundColor: AppColors.mental.withValues(alpha: 0.08),
        foregroundColor: AppColors.mental,
        elevation: 0,
        actions: [
          if (_total > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$_score / $_total',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.mental,
                      ),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _DifficultySelector(
              selected: _difficulty,
              color: AppColors.mental,
              onChanged: (d) {
                setState(() {
                  _difficulty = d;
                });
                _newProblem();
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: DecompositionWidget(
                key: ValueKey('${_problem.a}-${_problem.b}'),
                problem: _problem,
                showDecomposition: _showingDecomposition,
                onReady: () {
                  setState(() {
                    _showingDecomposition = false;
                  });
                },
                onAnswer: _onAnswer,
              ),
            ),
          ],
        ),
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
