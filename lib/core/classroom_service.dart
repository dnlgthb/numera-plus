import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClassroomService {
  static final ClassroomService _instance = ClassroomService._();
  factory ClassroomService() => _instance;
  ClassroomService._();

  static const _baseUrl = '/api/aula';
  static const appId = 'numera';

  String? _studentId;
  String? _sessionCode;
  String? _studentName;
  String? lastError;

  /// Operaciones que el profesor pidió practicar en esta sesión (códigos
  /// `suma/resta/multi/div`). Vacío = uso libre (cualquier operación cuenta).
  final Set<String> _sessionOperations = {};

  String? get studentId => _studentId;
  String? get sessionCode => _sessionCode;
  String? get studentName => _studentName;
  bool get isInClassroom => _studentId != null;

  Set<String> get sessionOperations => Set.unmodifiable(_sessionOperations);
  bool get hasTargetOperations => _sessionOperations.isNotEmpty;

  /// Una operación "cuenta" para puntos si no hay objetivo fijado (uso libre)
  /// o si pertenece al conjunto objetivo de la sesión.
  bool isTargetOp(String opCode) =>
      _sessionOperations.isEmpty || _sessionOperations.contains(opCode);

  final List<Map<String, String>> _pendingEvents = [];

  /// Extrae el conjunto de operaciones objetivo desde el JSON de una sesión.
  /// Acepta `operationTypes` (lista, formato nuevo) y `operationType` (string
  /// único, retrocompatibilidad). Valores nulos/vacíos = uso libre.
  Set<String> _parseOperations(Map<String, dynamic>? session) {
    final ops = <String>{};
    if (session == null) return ops;
    final list = session['operationTypes'];
    if (list is List) {
      for (final e in list) {
        if (e is String && e.isNotEmpty) ops.add(e);
      }
    }
    final single = session['operationType'];
    if (single is String && single.isNotEmpty) ops.add(single);
    return ops;
  }

  void _setOperations(Set<String> ops) {
    _sessionOperations
      ..clear()
      ..addAll(ops);
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('classroom_studentId');
    final code = prefs.getString('classroom_sessionCode');
    final name = prefs.getString('classroom_studentName');
    if (id != null && code != null && name != null) {
      final session = await validateCode(code);
      if (session != null) {
        _studentId = id;
        _sessionCode = code;
        _studentName = name;
        // Refrescar el objetivo desde el servidor (el profesor pudo cambiarlo).
        _setOperations(_parseOperations(session));
        await _saveSession();
      } else {
        await _clearSaved();
      }
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('classroom_studentId', _studentId!);
    await prefs.setString('classroom_sessionCode', _sessionCode!);
    await prefs.setString('classroom_studentName', _studentName!);
    await prefs.setStringList(
        'classroom_operations', _sessionOperations.toList());
  }

  Future<void> _clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('classroom_studentId');
    await prefs.remove('classroom_sessionCode');
    await prefs.remove('classroom_studentName');
    await prefs.remove('classroom_operations');
  }

  Future<Map<String, dynamic>?> validateCode(String code) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/sessions/${code.toUpperCase()}'),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> joinSession(String code, String name) async {
    lastError = null;
    final res = await http.post(
      Uri.parse('$_baseUrl/sessions/${code.toUpperCase()}/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'studentName': name, 'app': appId}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _studentId = data['studentId'] as String;
      _sessionCode = code.toUpperCase();
      _studentName = name;
      _setOperations(_parseOperations(data));
      await _saveSession();
      return true;
    }
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      lastError = data['error'] as String?;
    } catch (_) {}
    return false;
  }

  void leaveSession() {
    _studentId = null;
    _sessionCode = null;
    _studentName = null;
    _sessionOperations.clear();
    _pendingEvents.clear();
    _clearSaved();
  }

  Future<void> sendEvent({
    required String eventType,
    required String operationType,
    String? problemText,
    String? studentAnswer,
    String? correctAnswer,
  }) async {
    if (!isInClassroom) return;

    _pendingEvents.add({
      'eventType': eventType,
      'operationType': operationType,
      if (problemText != null) 'problemText': problemText,
      if (studentAnswer != null) 'studentAnswer': studentAnswer,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
    });

    await flush();
  }

  Future<void> flush() async {
    if (!isInClassroom || _pendingEvents.isEmpty) return;

    final events = List<Map<String, String>>.from(_pendingEvents);
    _pendingEvents.clear();

    try {
      await http.post(
        Uri.parse('$_baseUrl/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': _studentId,
          'events': events,
        }),
      );
    } catch (_) {
      _pendingEvents.insertAll(0, events);
    }
  }
}
