import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/sum_generator.dart';
import '../../core/classroom_service.dart';
import '../../core/audio_service.dart';
import '../../widgets/target_banner.dart';
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
  final _audio = AudioService.instance;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    await _classroom.restoreSession();
    if (!mounted) return;
    setState(() {});
    // Deep-link del aula: una URL con ?code=XXXXXX (QR del profe) abre el
    // diálogo con el código ya cargado, listo para elegir nombre. Solo si el
    // alumno no está ya en una clase restaurada.
    if (!_classroom.isInClassroom) {
      final code = Uri.base.queryParameters['code']?.trim();
      if (code != null && code.isNotEmpty) {
        _showJoinDialog(initialCode: code.toUpperCase());
      }
    }
  }

  void _toggleExpanded(int index) {
    _audio.playSelect();
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  // Permite al alumno salir de la clase (p.ej. si el profe lo liberó por haber
  // entrado mal, o para reingresar con otro nombre).
  void _confirmLeaveClass() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1528),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Salir de la clase',
            style: GoogleFonts.orbitron(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        content: const Text(
          '¿Seguro que quieres salir de la clase? Podrás volver a unirte con el código.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              _classroom.leaveSession();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Salir', style: TextStyle(color: Color(0xFFFF4081))),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog({String? initialCode}) {
    final codeController = TextEditingController(text: initialCode ?? '');
    final nameController = TextEditingController();
    String? errorText;
    // Info de la sesión, cargada al teclear el código completo. En modo
    // "roster" el alumno elige su nombre de la lista del profe en vez de
    // escribirlo.
    Map<String, dynamic>? sessionInfo;
    String? selectedRosterName;
    String? lastCheckedCode;
    bool checkingCode = false;
    bool autoFetchScheduled = false;

    // Consulta la info de la sesión para un código y refresca el diálogo.
    // Reutilizada por el onChanged del campo y por el deep-link (initialCode).
    Future<void> checkCode(String raw, StateSetter setDialogState) async {
      final c = raw.trim().toUpperCase();
      if (c.length < 6) {
        if (sessionInfo != null || checkingCode || lastCheckedCode != null) {
          setDialogState(() {
            sessionInfo = null;
            selectedRosterName = null;
            checkingCode = false;
            lastCheckedCode = null;
          });
        }
        return;
      }
      if (c == lastCheckedCode) return;
      lastCheckedCode = c;
      setDialogState(() => checkingCode = true);
      final session = await _classroom.validateCode(c);
      // Ignorar respuestas viejas si el código siguió cambiando.
      if (c != codeController.text.trim().toUpperCase()) return;
      setDialogState(() {
        checkingCode = false;
        sessionInfo = session;
        selectedRosterName = null;
        nameController.clear();
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Con código por deep-link, cargar la sesión una sola vez al abrir.
          if (initialCode != null && !autoFetchScheduled) {
            autoFetchScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => checkCode(initialCode, setDialogState));
          }
          return AlertDialog(
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
                onChanged: (_) =>
                    checkCode(codeController.text, setDialogState),
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
              if (checkingCode)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54),
                  ),
                )
              else if (sessionInfo?['nameMode'] == 'roster')
                Builder(builder: (_) {
                  final names = (sessionInfo?['availableNames'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      const <String>[];
                  if (names.isEmpty) {
                    return const Text(
                      'No quedan nombres disponibles en esta clase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFFC107), fontSize: 13),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    // Remonta el campo cuando cambia la lista (otro código),
                    // evitando que quede seleccionado un nombre ya no presente.
                    key: ValueKey(names.join('|')),
                    initialValue: selectedRosterName,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1528),
                    iconEnabledColor: Colors.white54,
                    hint: const Text('Elige tu nombre',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 16)),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                    items: names
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedRosterName = v),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  );
                })
              else
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
                final isRoster = sessionInfo?['nameMode'] == 'roster';
                final name = isRoster
                    ? (selectedRosterName ?? '')
                    : nameController.text.trim();
                if (code.isEmpty || name.length < 2) {
                  setDialogState(() => errorText = isRoster
                      ? 'Ingresa el código y elige tu nombre'
                      : 'Ingresa el código y tu nombre');
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

                  final sessionApp = session['app'] as String?;
                  if (sessionApp != null &&
                      sessionApp != ClassroomService.appId) {
                    setDialogState(() => errorText =
                        'Este código es para ${session['appLabel'] ?? 'otra app'}');
                    return;
                  }

                  final ok = await _classroom.joinSession(code, name);
                  if (ok) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  } else {
                    setDialogState(() =>
                        errorText = _classroom.lastError ?? 'Error al unirse');
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
          );
        },
      ),
    );
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
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () {
                    _audio.toggleMute();
                    setState(() {});
                  },
                  icon: Icon(
                    _audio.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
              ),
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
              // Operación buscada por el profesor (solo en clase con objetivo)
              const ClassroomTargetBanner(),
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
                            const AlgorithmScreen(operation: OperationType.sum),
                            OperationType.sum.code),
                        _NavOption('Resta', Icons.remove_rounded,
                            const AlgorithmScreen(operation: OperationType.subtraction),
                            OperationType.subtraction.code),
                        _NavOption('Multi', Icons.close_rounded,
                            const AlgorithmScreen(operation: OperationType.multiplication),
                            OperationType.multiplication.code),
                        _NavOption('Div', Icons.safety_divider_rounded,
                            const AlgorithmScreen(operation: OperationType.division),
                            OperationType.division.code),
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
                            const CombatScreen(operation: OperationType.sum),
                            OperationType.sum.code),
                        _NavOption('Resta', Icons.remove_rounded,
                            const CombatScreen(operation: OperationType.subtraction),
                            OperationType.subtraction.code),
                        _NavOption('Multi', Icons.close_rounded,
                            const CombatScreen(operation: OperationType.multiplication),
                            OperationType.multiplication.code),
                        _NavOption('Div', Icons.safety_divider_rounded,
                            const CombatScreen(operation: OperationType.division),
                            OperationType.division.code),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Classroom indicator with exit button
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
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _confirmLeaveClass,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.logout_rounded,
                              color: Color(0xFF00E676), size: 18),
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
  final String opCode;
  const _NavOption(this.label, this.icon, this.screen, this.opCode);
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
                    final classroom = ClassroomService();
                    // En clase con objetivo, las operaciones no buscadas siguen
                    // accesibles pero se atenúan y avisan que no suman puntos.
                    final offTarget = classroom.isInClassroom &&
                        classroom.hasTargetOperations &&
                        !classroom.isTargetOp(opt.opCode);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Opacity(
                        opacity: offTarget ? 0.45 : 1.0,
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
                                if (offTarget) ...[
                                  const SizedBox(width: 8),
                                  Text('no cuenta hoy',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white70,
                                      )),
                                ],
                              ],
                            ),
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
