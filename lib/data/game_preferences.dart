import 'package:shared_preferences/shared_preferences.dart';

class GamePreferences {
  GamePreferences(this._prefs) {
    _memoryRecord = _prefs?.getInt('delivery_record_v1') ?? 0;
    _memoryHaptics = _prefs?.getBool('haptics_v1') ?? true;
  }
  final SharedPreferences? _prefs;
  int _memoryRecord = 0;
  bool _memoryHaptics = true;
  int get record => _memoryRecord;
  bool get haptics => _memoryHaptics;

  Future<void> saveRecord(int value) async {
    if (value <= record) {
      return;
    }
    _memoryRecord = value;
    try {
      await _prefs?.setInt('delivery_record_v1', value);
    } catch (_) {
      // Storage can be unavailable in private browser sessions.
    }
  }

  Future<void> setHaptics(bool enabled) async {
    _memoryHaptics = enabled;
    try {
      await _prefs?.setBool('haptics_v1', enabled);
    } catch (_) {}
  }
}

