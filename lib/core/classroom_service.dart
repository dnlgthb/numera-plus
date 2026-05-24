import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClassroomService {
  static final ClassroomService _instance = ClassroomService._();
  factory ClassroomService() => _instance;
  ClassroomService._();

  static const _baseUrl = '/api/aula';

  String? _studentId;
  String? _sessionCode;
  String? _studentName;

  String? get studentId => _studentId;
  String? get sessionCode => _sessionCode;
  String? get studentName => _studentName;
  bool get isInClassroom => _studentId != null;

  final List<Map<String, String>> _pendingEvents = [];

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
  }

  Future<void> _clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('classroom_studentId');
    await prefs.remove('classroom_sessionCode');
    await prefs.remove('classroom_studentName');
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
    final res = await http.post(
      Uri.parse('$_baseUrl/sessions/${code.toUpperCase()}/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'studentName': name}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _studentId = data['studentId'] as String;
      _sessionCode = code.toUpperCase();
      _studentName = name;
      await _saveSession();
      return true;
    }
    return false;
  }

  void leaveSession() {
    _studentId = null;
    _sessionCode = null;
    _studentName = null;
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
