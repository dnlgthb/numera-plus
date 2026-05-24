import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/sum_generator.dart';
import '../../core/classroom_service.dart';
import '../algorithm/algorithm_screen.dart';
import '../combat/combat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _expandedIndex;
  final _classroom = ClassroomService();

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    await _classroom.restoreSession();
    if (mounted) setState(() {});
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  void _showJoinDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1528),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Unirse a Clase',
              style: GoogleFonts.orbitron(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.orbitron(
                    fontSize: 20, color: Colors.white, letterSpacing: 4),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'CÓDIGO',
                  hintStyle: GoogleFonts.orbitron(
                      fontSize: 16, color: Colors.white38, letterSpacing: 4),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tu nombre',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!,
                    style: const TextStyle(color: Color(0xFFFF4081), fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59E8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final code = codeController.text.trim();
                final name = nameController.text.trim();
                if (code.isEmpty || name.length < 2) {
                  setDialogState(() =>
                      errorText = 'Ingresa el código y tu nombre');
                  return;
                }
                setDialogState(() => errorText = null);

                try {
                  final session = await _classroom.validateCode(code);
                  if (session == null) {
                    setDialogState(
                        () => errorText = 'Código no encontrado o expirado');
                    return;
                  }

                  final ok = await _classroom.joinSession(code, name);
                  if (ok) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  } else {
                    setDialogState(() => errorText = 'Error al unirse');
                  }
                } catch (e) {
                  debugPrint('ClassroomService error: $e');
                  setDialogState(() => errorText = 'Error de conexión: $e');
                }
              },
              child: const Text('Unirse',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _leaveClassroom() {
    _classroom.leaveSession();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/fondo_bg.png',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
            children: [
              // Logo
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Image.asset(
                      'assets/numera+.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Two buttons side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ExpandableButton(
                      label: 'Practica',
                      icon: Icons.view_column_rounded,
                      expanded: _expandedIndex == 0,
                      onTap: () => _toggleExpanded(0),
                      options: [
                        _NavOption('Suma', Icons.add_rounded,
                            const AlgorithmScreen(operation: OperationType.sum)),
                        _NavOption('Resta', Icons.remove_rounded,
                            const AlgorithmScreen(operation: OperationType.subtraction)),
                        _NavOption('Multi', Icons.close_rounded,
                            const AlgorithmScreen(operation: OperationType.multiplication)),
                        _NavOption('Div', Icons.safety_divider_rounded,
                            const AlgorithmScreen(operation: OperationType.division)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ExpandableButton(
                      label: 'Combate',
                      icon: Icons.bolt_rounded,
                      expanded: _expandedIndex == 1,
                      onTap: () => _toggleExpanded(1),
                      options: [
                        _NavOption('Suma', Icons.add_rounded,
                            const CombatScreen(operation: OperationType.sum)),
                        _NavOption('Resta', Icons.remove_rounded,
                            const CombatScreen(operation: OperationType.subtraction)),
                        _NavOption('Multi', Icons.close_rounded,
                            const CombatScreen(operation: OperationType.multiplication)),
                        _NavOption('Div', Icons.safety_divider_rounded,
                            const CombatScreen(operation: OperationType.division)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Classroom indicator (no exit button)
              if (_classroom.isInClassroom)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_rounded,
                          color: Color(0xFF00E676), size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'En clase: ${_classroom.studentName}',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00E676),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _showJoinDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text('Unirse a Clase',
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            )),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}

class _NavOption {
  final String label;
  final IconData icon;
  final Widget screen;
  const _NavOption(this.label, this.icon, this.screen);
}

class _ExpandableButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;
  final List<_NavOption> options;

  static const _purple = Color(0xFF9B59E8);
  static const _purpleDark = Color(0xFF6C3ABA);

  const _ExpandableButton({
    required this.label,
    required this.icon,
    required this.expanded,
    required this.onTap,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: expanded
              ? [_purpleDark.withValues(alpha: 0.7), _purple.withValues(alpha: 0.5)]
              : [_purpleDark.withValues(alpha: 0.5), _purple.withValues(alpha: 0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _purple.withValues(alpha: expanded ? 0.8 : 0.4),
          width: 1.5,
        ),
        boxShadow: expanded
            ? [BoxShadow(color: _purple.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: -2)]
            : null,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                children: [
                  Icon(icon, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(label, style: GoogleFonts.orbitron(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Column(
                  children: options.map((opt) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => opt.screen),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _purple.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(opt.icon, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text(opt.label, style: GoogleFonts.orbitron(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          ],
        ),
      ),
    );
  }
}
