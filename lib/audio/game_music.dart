import 'package:audioplayers/audioplayers.dart';

/// Small interface so the UI can be tested without a native audio device.
abstract class GameMusic {
  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AssetGameMusic implements GameMusic {
  final AudioPlayer _player = AudioPlayer();
  Future<void> _pending = Future<void>.value();
  bool _started = false;
  bool _disposed = false;

  Future<void> _enqueue(Future<void> Function() action) {
    if (_disposed) return Future<void>.value();
    final next = _pending.then((_) async {
      try {
        await action();
      } catch (_) {
        // A blocked browser audio context must never interrupt gameplay.
      }
    });
    _pending = next;
    return next;
  }

  @override
  Future<void> start() => _enqueue(() async {
    // Load/play only after a tap or key press: browsers disallow autoplay.
    await _player.play(AssetSource('audio/ride_loop.wav'), volume: 0.32);
    _started = true;
    await _player.setReleaseMode(ReleaseMode.loop);
  });

  @override
  Future<void> pause() => _enqueue(() async {
    if (_started) await _player.pause();
  });

  @override
  Future<void> resume() => _enqueue(() async {
    if (_started) {
      await _player.resume();
    } else {
      await _player.play(AssetSource('audio/ride_loop.wav'), volume: 0.32);
      _started = true;
      await _player.setReleaseMode(ReleaseMode.loop);
    }
  });

  @override
  Future<void> stop() => _enqueue(() async {
    if (_started) await _player.stop();
    _started = false;
  });

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _pending;
    await _player.dispose();
  }
}
