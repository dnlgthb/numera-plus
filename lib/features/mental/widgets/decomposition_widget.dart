import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/sum_generator.dart';

class DecompositionWidget extends StatefulWidget {
  final SumProblem problem;
  final bool showDecomposition;
  final VoidCallback onReady;
  final ValueChanged<int> onAnswer;

  const DecompositionWidget({
    super.key,
    required this.problem,
    required this.showDecomposition,
    required this.onReady,
    required this.onAnswer,
  });

  @override
  State<DecompositionWidget> createState() => _DecompositionWidgetState();
}

class _DecompositionWidgetState extends State<DecompositionWidget>
    with TickerProviderStateMixin {
  String _inputValue = '';
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<_DecomposedPart> _decompose(int number) {
    final parts = <_DecomposedPart>[];
    final str = number.toString();
    for (int i = 0; i < str.length; i++) {
      final digit = int.parse(str[i]);
      if (digit == 0) continue;
      final power = str.length - 1 - i;
      final value = digit * _pow10(power);
      final color = switch (power) {
        0 => AppColors.units,
        1 => AppColors.tens,
        2 => AppColors.hundreds,
        _ => AppColors.thousands,
      };
      final label = switch (power) {
        0 => 'U',
        1 => 'D',
        2 => 'C',
        _ => 'M',
      };
      parts.add(_DecomposedPart(value: value, color: color, label: label));
    }
    return parts;
  }

  int _pow10(int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }

  void _onDigit(String digit) {
    setState(() {
      _inputValue += digit;
    });
  }

  void _onDelete() {
    if (_inputValue.isEmpty) return;
    setState(() {
      _inputValue = _inputValue.substring(0, _inputValue.length - 1);
    });
  }

  void _onSubmit() {
    final parsed = int.tryParse(_inputValue);
    if (parsed != null) {
      widget.onAnswer(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showDecomposition) {
      return _buildDecomposition(context);
    }
    return _buildAnswerInput(context);
  }

  Widget _buildDecomposition(BuildContext context) {
    final partsA = _decompose(widget.problem.a);
    final partsB = _decompose(widget.problem.b);

    return FadeTransition(
      opacity: _fadeIn,
      child: Column(
        children: [
          // Problem display
          Text(
            '${widget.problem.a} + ${widget.problem.b}',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 32),
          // Decomposition A
          _buildDecompRow(widget.problem.a, partsA),
          const SizedBox(height: 12),
          // Plus sign
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Decomposition B
          _buildDecompRow(widget.problem.b, partsB),
          const Spacer(),
          // Ready button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onReady,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mental,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'YA LO TENGO',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDecompRow(int number, List<_DecomposedPart> parts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: parts[i].color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: parts[i].color.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  parts[i].label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: parts[i].color,
                  ),
                ),
                Text(
                  '${parts[i].value}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: parts[i].color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnswerInput(BuildContext context) {
    return Column(
      children: [
        Text(
          '${widget.problem.a} + ${widget.problem.b} = ?',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        // Input display
        Container(
          width: 200,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.mental, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            _inputValue.isEmpty ? '' : _inputValue,
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ),
        const Spacer(),
        // Numpad
        _buildNumpad(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['DEL', '0', 'OK'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((label) {
                final isAction = label == 'DEL' || label == 'OK';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 80,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: label == 'DEL'
                          ? _onDelete
                          : label == 'OK'
                              ? _onSubmit
                              : () => _onDigit(label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: label == 'OK'
                            ? AppColors.mental
                            : label == 'DEL'
                                ? AppColors.textLight.withValues(alpha: 0.3)
                                : AppColors.surface,
                        foregroundColor: label == 'OK'
                            ? Colors.white
                            : AppColors.textPrimary,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: isAction ? 14 : 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _DecomposedPart {
  final int value;
  final Color color;
  final String label;

  _DecomposedPart({
    required this.value,
    required this.color,
    required this.label,
  });
}
