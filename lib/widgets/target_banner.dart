import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/classroom_service.dart';
import '../core/sum_generator.dart';
import '../core/theme.dart';

/// Recuerda al alumno qué operación pidió el profesor durante la clase.
///
/// Solo se muestra si está en una sesión de clase y el profesor fijó una o más
/// operaciones objetivo. Si [currentOp] se entrega y NO está en el objetivo,
/// el banner cambia a tono de aviso y aclara que esa práctica no suma puntos.
class ClassroomTargetBanner extends StatelessWidget {
  /// Código de la operación de la pantalla actual (`suma/resta/multi/div`).
  final String? currentOp;
  final EdgeInsetsGeometry margin;

  const ClassroomTargetBanner({
    super.key,
    this.currentOp,
    this.margin = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final classroom = ClassroomService();
    if (!classroom.isInClassroom || !classroom.hasTargetOperations) {
      return const SizedBox.shrink();
    }

    final labels =
        classroom.sessionOperations.map(operationLabelFromCode).join(', ');
    final offTarget = currentOp != null && !classroom.isTargetOp(currentOp!);
    final color = offTarget ? AppColors.warning : AppColors.correct;
    final text = offTarget
        ? 'Hoy cuenta: $labels · esta práctica no suma puntos'
        : 'Hoy cuenta: $labels';

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            offTarget ? Icons.info_outline_rounded : Icons.school_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
