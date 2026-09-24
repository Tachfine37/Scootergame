import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/game_preferences.dart';
import 'delivery_model.dart';
import 'stages.dart';
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
  int startingStage = 0;

  void selectStage(int index) {
    startingStage = index.clamp(0, deliveryStages.length - 1);
    model.start(stage: startingStage);
    model.phase = RunPhase.ready;
    model.items.clear();
    model.flying.clear();
    model.crossings.clear();
    model.distance = 0;
    model.x = model.targetX = model.hop = model.velocity = model.lean = 0;
    model.stackSway = model.stackSwayVelocity = 0;
    model.balanceStress = model.balanceGrace = 0;
    model.braking = false;
    model.shield = false;
    model.magnetTime = model.shake = model.invulnerability = 0;
    steering = 0;
    hud.value++;
  }

  void startRun() {
    recordAtStart = preferences.endlessBest;
    model.start(stage: startingStage);
    steering = 0;
    _accumulator = 0;
    hud.value++;
  }

  void pauseRun() {
    model.pause();
    model.braking = false;
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

  void setBraking(bool value) {
    final next = model.running && value;
    if (model.braking == next) return;
    model.braking = next;
    hud.value++;
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
    if (model.running || model.phase == RunPhase.wrecked) {
      _accumulator += safeDt;
      const step = 1 / 120;
      while (_accumulator >= step) {
        if (steering != 0 && model.running) {
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
      preferences.saveEndlessBest(model.score).then((_) {
        if (!isRemoved) {
          hud.value++;
        }
      });
    }
    if (preferences.haptics && !kIsWeb) {
      final feedback = event == RunEvent.crash || event == RunEvent.spill
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick();
      feedback.catchError((Object _) {});
    }
    hud.value++;
  }

  int get displayedRecord => math.max(
    preferences.endlessBest,
    model.phase == RunPhase.finished ? model.score : 0,
  );
}
