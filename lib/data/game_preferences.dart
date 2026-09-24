import 'package:shared_preferences/shared_preferences.dart';
import '../game/stages.dart';

class GamePreferences {
  GamePreferences(this._prefs) {
    _memoryRecord = _prefs?.getInt('delivery_record_v1') ?? 0;
    _memoryHaptics = _prefs?.getBool('haptics_v1') ?? true;
    _music = _prefs?.getBool('music_v1') ?? true;
    _effects = _prefs?.getBool('effects_v1') ?? true;
    _musicVolume = (_prefs?.getDouble('music_volume_v1') ?? .55).clamp(
      0.0,
      1.0,
    );
    _effectsVolume = (_prefs?.getDouble('effects_volume_v1') ?? .7).clamp(
      0.0,
      1.0,
    );
    _endlessBest = _prefs?.getInt('endless_best_v1') ?? 0;
    for (var i = 0; i < deliveryStages.length; i++) {
      _stageBests[i] = _prefs?.getInt('stage_best_v2_$i') ?? 0;
    }
  }
  final SharedPreferences? _prefs;
  int _memoryRecord = 0;
  bool _memoryHaptics = true;
  bool _music = true;
  bool _effects = true;
  double _musicVolume = .55;
  double _effectsVolume = .7;
  int _endlessBest = 0;
  int get endlessBest => _endlessBest;
  int get record => _memoryRecord;
  bool get haptics => _memoryHaptics;
  bool get music => _music;
  bool get effects => _effects;
  double get musicVolume => _musicVolume;
  double get effectsVolume => _effectsVolume;
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

  Future<void> setMusic(bool enabled) async {
    _music = enabled;
    try {
      await _prefs?.setBool('music_v1', enabled);
    } catch (_) {}
  }

  Future<void> saveEndlessBest(int score) async {
    if (score <= _endlessBest) return;
    _endlessBest = score;
    try {
      await _prefs?.setInt('endless_best_v1', score);
    } catch (_) {}
  }

  Future<void> setEffects(bool enabled) async {
    _effects = enabled;
    try {
      await _prefs?.setBool('effects_v1', enabled);
    } catch (_) {}
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    try {
      await _prefs?.setDouble('music_volume_v1', _musicVolume);
    } catch (_) {}
  }

  Future<void> setEffectsVolume(double value) async {
    _effectsVolume = value.clamp(0.0, 1.0);
    try {
      await _prefs?.setDouble('effects_volume_v1', _effectsVolume);
    } catch (_) {}
  }
}
