import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'game_music.dart';

class AdaptiveGameMusic extends GameMusic {
  AdaptiveGameMusic() {
    for (var i = 0; i < 2; i++) {
      _subscriptions.add(
        _tracks[i].onPositionChanged.listen((position) {
          if (i != _current) return;
          _position = position;
          final bar = (position.inMilliseconds / (240000 / _bpm)).floor();
          if (bar != _bar &&
              _active &&
              _music &&
              !_changing &&
              (_bpm != _wantedBpm || _chase != _wantedChase)) {
            _changing = true;
            unawaited(
              _enqueue(_transition).whenComplete(() => _changing = false),
            );
          }
          _bar = bar;
        }),
      );
    }
  }
  final _tracks = [AudioPlayer(), AudioPlayer()];
  final _fx = [AudioPlayer(), AudioPlayer()];
  final _engine = AudioPlayer(), _ambient = AudioPlayer();
  final List<StreamSubscription<Duration>> _subscriptions = [];
  final Map<GameSound, DateTime> _lastSound = {};
  final _fxPending = [Future<void>.value(), Future<void>.value()];
  Future<void> _pending = Future<void>.value();
  bool _disposed = false, _active = false, _loaded = false, _changing = false;
  bool _music = true, _effects = true, _chase = false, _wantedChase = false;
  double _musicVolume = .55, _effectsVolume = .7;
  int _current = 0, _bpm = 100, _wantedBpm = 100, _bar = -1, _epoch = 0;
  int _vehicle = 0, _district = 0, _loadedVehicle = -1, _loadedDistrict = -1;
  bool _layersQueued = false, _wasBraking = false;
  Duration _position = Duration.zero;
  DateTime _duckUntil = DateTime(2000);
  Timer? _duckTimer;
  String? _problem;
  @override
  String? get problem => _problem;
  Iterable<AudioPlayer> get _all => [..._tracks, ..._fx, _engine, _ambient];
  double get _gain => _music
      ? _musicVolume * (DateTime.now().isBefore(_duckUntil) ? .35 : 1)
      : 0;
  AssetSource _asset(String name) => AssetSource('audio/funk/$name.wav');
  void _report(Object error) {
    _problem = 'Sound could not start. Try Test sound or restart this run.';
    debugPrint('Game audio: $error');
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (_disposed) return Future<void>.value();
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (error) {
        _report(error);
      }
    });
    return _pending;
  }

  @override
  Future<void> configure({
    required bool music,
    required bool effects,
    required double musicVolume,
    required double effectsVolume,
  }) {
    _music = music;
    _effects = effects;
    _musicVolume = musicVolume.clamp(0.0, 1.0);
    _effectsVolume = effectsVolume.clamp(0.0, 1.0);
    return _enqueue(() async {
      if (!_music) {
        for (final p in _tracks) {
          await p.pause();
        }
      } else if (_active) {
        if (!_loaded) {
          await _startTrack();
        } else {
          await _tracks[_current].resume();
        }
      }
      await _tracks[_current].setVolume(_gain);
      if (!_effects) {
        for (final p in [..._fx, _engine, _ambient]) {
          await p.stop();
        }
        _loadedVehicle = _loadedDistrict = -1;
      } else if (_active) {
        await _layers();
      }
      await _engine.setVolume(_effectsVolume * .055);
      await _ambient.setVolume(_effectsVolume * .035);
      for (final p in _fx) {
        await p.setVolume(_effects ? _effectsVolume : 0);
      }
    });
  }

  Future<void> _startTrack() async {
    if (!_active || !_music) return;
    _bpm = _wantedBpm;
    _chase = _wantedChase;
    await _tracks[_current].play(
      _asset('${_chase ? 'chase' : 'ride'}_$_bpm'),
      volume: _gain,
    );
    await _tracks[_current].setReleaseMode(ReleaseMode.loop);
    _loaded = true;
    _problem = null;
    if (!_active) await _tracks[_current].pause();
  }

  Future<void> _transition() async {
    if (!_active || !_music || !_loaded) return;
    final epoch = _epoch;
    final bpm = _wantedBpm, chase = _wantedChase;
    final old = _tracks[_current], next = _tracks[1 - _current];
    await next.setSource(_asset('${chase ? 'chase' : 'ride'}_$bpm'));
    if (!_active || epoch != _epoch) return;
    // Rendered tempos retain pitch; seek to the corresponding musical position.
    final position = await old.getCurrentPosition() ?? _position;
    final target = Duration(
      microseconds: (position.inMicroseconds * _bpm / bpm).round(),
    );
    await next.setVolume(0);
    await next.seek(target);
    await next.setReleaseMode(ReleaseMode.loop);
    await next.resume();
    for (var step = 1; step <= 6; step++) {
      if (!_active || epoch != _epoch) {
        await next.pause();
        return;
      }
      await next.setVolume(_gain * step / 6);
      await old.setVolume(_gain * (1 - step / 6));
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    await old.stop();
    _current = 1 - _current;
    _bpm = bpm;
    _chase = chase;
    _position = target;
  }

  Future<void> _layers() async {
    if (!_active || !_effects) return;
    if (_vehicle != _loadedVehicle) {
      await _engine.play(
        _asset('engine_$_vehicle'),
        volume: _effectsVolume * .055,
      );
      await _engine.setReleaseMode(ReleaseMode.loop);
      _loadedVehicle = _vehicle;
    } else {
      await _engine.resume();
    }
    if (_district != _loadedDistrict) {
      await _ambient.play(
        _asset('ambient_$_district'),
        volume: _effectsVolume * .035,
      );
      await _ambient.setReleaseMode(ReleaseMode.loop);
      _loadedDistrict = _district;
    } else {
      await _ambient.resume();
    }
    if (!_active) {
      await _engine.pause();
      await _ambient.pause();
    }
  }

  @override
  Future<void> start() {
    _active = true;
    _epoch++;
    _lastSound.clear();
    _duckUntil = DateTime(2000);
    _duckTimer?.cancel();
    return _enqueue(() async {
      for (final p in _all) {
        await p.stop();
      }
      _loaded = false;
      _loadedVehicle = _loadedDistrict = -1;
      _bar = -1;
      await _startTrack();
      await _layers();
    });
  }

  @override
  Future<void> pause() {
    _active = false;
    _epoch++;
    return _enqueue(() async {
      for (final p in _all) {
        await p.pause();
      }
    });
  }

  @override
  Future<void> resume() {
    _active = true;
    return _enqueue(() async {
      if (_music) {
        if (_loaded) {
          // A pause may interrupt a crossfade before its volume reaches 100%.
          await _tracks[_current].setVolume(_gain);
          await _tracks[_current].resume();
        } else {
          await _startTrack();
        }
      }
      await _layers();
    });
  }

  @override
  Future<void> stop() {
    _active = false;
    _epoch++;
    _lastSound.clear();
    _duckTimer?.cancel();
    return _enqueue(() async {
      for (final p in _all) {
        await p.stop();
      }
      _loaded = false;
      _loadedVehicle = _loadedDistrict = -1;
    });
  }

  @override
  void update({
    required int speedLevel,
    required bool police,
    required double escapeRemaining,
    required int vehicle,
    required int district,
    required double stress,
    required int integrity,
    required bool braking,
  }) {
    _wantedBpm = speedLevel >= 4
        ? 120
        : speedLevel >= 2
        ? 110
        : 100;
    _wantedChase = police;
    _vehicle = vehicle.clamp(0, 3);
    _district = district.clamp(0, 3);
    if (!_active) {
      _wasBraking = braking;
      return;
    }
    if (!_layersQueued &&
        _effects &&
        (_vehicle != _loadedVehicle || _district != _loadedDistrict)) {
      _layersQueued = true;
      unawaited(_enqueue(_layers).whenComplete(() => _layersQueued = false));
    }
    if (stress > .45) unawaited(effect(GameSound.rattle));
    if (integrity == 1) unawaited(effect(GameSound.damage));
    if (braking && !_wasBraking) unawaited(effect(GameSound.brake));
    _wasBraking = braking;
    // Escape progress exists in the model; physical police distance does not.
    if (police) {
      final seconds = escapeRemaining > 200 ? 5 : 9;
      final last = _lastSound[GameSound.police];
      if (last == null ||
          DateTime.now().difference(last).inSeconds >= seconds) {
        unawaited(effect(GameSound.police));
      }
    }
  }

  @override
  Future<void> effect(GameSound sound, {bool preview = false}) {
    if (_disposed || !_effects || (!_active && !preview)) {
      return Future<void>.value();
    }
    final now = DateTime.now();
    final cooldown = switch (sound) {
      GameSound.rattle => 1600,
      GameSound.damage => 5000,
      GameSound.police => 3500,
      GameSound.pickup => 180,
      _ => 450,
    };
    final last = _lastSound[sound];
    if (last != null && now.difference(last).inMilliseconds < cooldown) {
      return Future<void>.value();
    }
    _lastSound[sound] = now;
    final important = [
      GameSound.crash,
      GameSound.upgrade,
      GameSound.police,
      GameSound.escape,
      GameSound.broken,
      GameSound.delivery,
      GameSound.combo,
    ].contains(sound);
    final channel = important ? 0 : 1, epoch = _epoch;
    final name = sound == GameSound.nearMiss ? 'near_miss' : sound.name;
    if (sound == GameSound.crash || sound == GameSound.broken) {
      _duckUntil = now.add(const Duration(milliseconds: 750));
      unawaited(_enqueue(() => _tracks[_current].setVolume(_gain)));
      _duckTimer?.cancel();
      _duckTimer = Timer(const Duration(milliseconds: 800), () {
        if (!_disposed) {
          unawaited(_enqueue(() => _tracks[_current].setVolume(_gain)));
        }
      });
    }
    _fxPending[channel] = _fxPending[channel].then((_) async {
      if (_disposed || !_effects || epoch != _epoch || (!_active && !preview)) {
        return;
      }
      try {
        await _fx[channel].play(
          _asset(name),
          volume:
              _effectsVolume *
              (sound == GameSound.pickup
                  ? .35
                  : sound == GameSound.police
                  ? .5
                  : .8),
        );
        _problem = null;
        if (_disposed || !_effects || epoch != _epoch) {
          await _fx[channel].stop();
        }
      } catch (error) {
        _report(error);
      }
    });
    return _fxPending[channel];
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _active = false;
    _epoch++;
    _duckTimer?.cancel();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _pending;
    await Future.wait(_fxPending);
    for (final p in _all) {
      try {
        await p.dispose();
      } catch (error) {
        debugPrint('$error');
      }
    }
  }
}
