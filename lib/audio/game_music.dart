enum GameSound {
  pickup,
  crash,
  spill,
  upgrade,
  delivery,
  combo,
  police,
  escape,
  rattle,
  brake,
  nearMiss,
  damage,
  broken,
  bonus,
  district,
}

/// Injectable facade: gameplay tests do not require a native audio device.
abstract class GameMusic {
  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
  String? get problem => null;
  Future<void> configure({
    required bool music,
    required bool effects,
    required double musicVolume,
    required double effectsVolume,
  }) async {}
  void update({
    required int speedLevel,
    required bool police,
    required double escapeRemaining,
    required int vehicle,
    required int district,
    required double stress,
    required int integrity,
    required bool braking,
  }) {}
  Future<void> effect(GameSound sound, {bool preview = false}) async {}
}
