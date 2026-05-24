import 'package:shared_preferences/shared_preferences.dart';

class LocalProgressService {
  static final LocalProgressService _instance = LocalProgressService._();
  factory LocalProgressService() => _instance;
  LocalProgressService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _key(String operation, String stat) => 'progress_${operation}_$stat';

  Future<void> saveProgress({
    required String operation,
    required int completed,
    required int errors,
    required int maxStreak,
    required int coins,
  }) async {
    await init();
    await _prefs!.setInt(_key(operation, 'completed'), completed);
    await _prefs!.setInt(_key(operation, 'errors'), errors);
    await _prefs!.setInt(_key(operation, 'maxStreak'), maxStreak);
    await _prefs!.setInt(_key(operation, 'coins'), coins);
  }

  Future<Map<String, int>> loadProgress(String operation) async {
    await init();
    return {
      'completed': _prefs!.getInt(_key(operation, 'completed')) ?? 0,
      'errors': _prefs!.getInt(_key(operation, 'errors')) ?? 0,
      'maxStreak': _prefs!.getInt(_key(operation, 'maxStreak')) ?? 0,
      'coins': _prefs!.getInt(_key(operation, 'coins')) ?? 0,
    };
  }
}
