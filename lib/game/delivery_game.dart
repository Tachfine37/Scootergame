import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/game_preferences.dart';
import 'delivery_model.dart';
import 'world_renderer.dart';

class DeliveryGame extends FlameGame {
  DeliveryGame(this.preferences, {int seed = 42})
    : model = DeliveryModel(seed: seed) {
    model.onEvent = _onEvent;
  }
  final GamePreferences preferences;
  final DeliveryModel model;
  final WorldRenderer renderer = WorldRenderer();
  final ValueNotifier<int> hud = ValueNotifier(0);
  bool reduceMotion = false;
  int steering = 0;
  double _clock = 0;
  double _accumulator = 0;
  double _hudTimer = 0;
  int recordAtStart = 0;

  void startRun() {
    recordAtStart = preferences.record;
    model.start();
    steering = 0;
    _accumulator = 0;
    hud.value++;
  }

  void pauseRun() {
    model.pause();
    steering = 0;
    hud.value++;
  }

  void resumeRun() {
    model.resume();
    _accumulator = 0;
    hud.value++;
  }

  void steerAt(double screenX) {
    if (!model.running || size.x <= 0) {
      return;
    }
    final virtualX = screenX / size.x * WorldRenderer.width;
    final groundScale = renderer.scaleAt(DeliveryModel.playerZ);
    model.steer((virtualX - WorldRenderer.width / 2) / (238 * groundScale));
  }

  void nudge(int direction) {
    if (model.running) {
      model.steer(model.targetX + direction * .67);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!dt.isFinite) {
      return;
    }
    final safeDt = dt.clamp(0.0, .1);
    if (model.phase != RunPhase.paused) {
      _clock += safeDt;
    }
    if (model.running) {
      _accumulator += safeDt;
      const step = 1 / 120;
      while (_accumulator >= step) {
        if (steering != 0) {
          model.steer(model.targetX + steering * step * 2.5);
        }
        model.update(step);
        _accumulator -= step;
      }
      _hudTimer += safeDt;
      if (_hudTimer >= .08) {
        _hudTimer = 0;
        hud.value++;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    renderer.render(
      canvas,
      Size(size.x, size.y),
      model,
      clock: _clock,
      reduceMotion: reduceMotion,
    );
  }

  void _onEvent(RunEvent event) {
    if (event == RunEvent.finish) {
      preferences.saveRecord(model.cargo).then((_) {
        if (!isRemoved) {
          hud.value++;
        }
      });
    }
    if (preferences.haptics && !kIsWeb) {
      final feedback = event == RunEvent.crash
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick();
      feedback.catchError((Object _) {});
    }
    hud.value++;
  }

  int get displayedRecord => math.max(
    preferences.record,
    model.phase == RunPhase.finished ? model.cargo : 0,
  );
}

