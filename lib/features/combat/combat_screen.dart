import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/sum_generator.dart';
import 'widgets/battle_widget.dart';

class CombatScreen extends StatelessWidget {
  final OperationType operation;
  const CombatScreen({super.key, this.operation = OperationType.sum});

  @override
  Widget build(BuildContext context) {
    final titleStr = 'Combate - ${switch (operation) {
      OperationType.sum => 'Suma',
      OperationType.subtraction => 'Resta',
      OperationType.multiplication => 'Multiplicación',
      OperationType.division => 'División',
    }}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _PlasmaText(text: titleStr),
        backgroundColor: const Color(0xFF9B59E8).withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: BattleWidget(operation: operation),
        ),
      ),
    );
  }
}

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
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
              ..shader = const LinearGradient(
                colors: [Color(0xFFFF4081), Color(0xFF9B59E8), Color(0xFFFF4081)],
              ).createShader(Rect.fromLTWH(0, 0, 300, 30)),
          ),
        ),
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
              ..shader = const LinearGradient(
                colors: [Color(0xFFE040FB), Color(0xFFCE93D8)],
              ).createShader(Rect.fromLTWH(0, 0, 300, 30)),
          ),
        ),
        Text(
          text,
          style: style.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
