import 'package:shared_preferences/shared_preferences.dart';
import '../game/stages.dart';

class GamePreferences {
  GamePreferences(this._prefs) {
    _memoryRecord = _prefs?.getInt('delivery_record_v1') ?? 0;
    _memoryHaptics = _prefs?.getBool('haptics_v1') ?? true;
    _endlessBest = _prefs?.getInt('endless_best_v1') ?? 0;
    for (var i = 0; i < deliveryStages.length; i++) {
      _stageBests[i] = _prefs?.getInt('stage_best_v2_$i') ?? 0;
    }
  }
  final SharedPreferences? _prefs;
  int _memoryRecord = 0;
  bool _memoryHaptics = true;
  int _endlessBest = 0;
  int get endlessBest => _endlessBest;
  int get record => _memoryRecord;
  bool get haptics => _memoryHaptics;
  final Map<int, int> _stageBests = {};
  int stageBest(int stage) => _stageBests[stage] ?? 0;
  int stageStars(int stage) => deliveryStages[stage].starsFor(stageBest(stage));
  int get totalStars => List.generate(
    deliveryStages.length,
    stageStars,
  ).fold(0, (sum, value) => sum + value);

  Future<void> saveStage(int stage, int cargo) async {
    if (cargo <= stageBest(stage)) return;
    _stageBests[stage] = cargo;
    try {
      await _prefs?.setInt('stage_best_v2_$stage', cargo);
    } catch (_) {}
  }

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

  Future<void> saveEndlessBest(int score) async {
    if (score <= _endlessBest) return;
    _endlessBest = score;
    try {
      await _prefs?.setInt('endless_best_v1', score);
    } catch (_) {}
  }
}
