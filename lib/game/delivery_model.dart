import 'dart:math' as math;
import 'stages.dart';

String parcelWord(int count) => count == 1 ? 'parcel' : 'parcels';

enum RunPhase { ready, running, paused, finished }

enum ItemKind { parcel, cone, car, bump, shield, magnet }

enum RunEvent { pickup, crash, bump, spill, finish, bonus }

enum TrafficPhase { green, amber, red }

class CrossTrafficCar {
  CrossTrafficCar(this.direction, this.variant)
    : x = direction > 0 ? -1.55 : 1.55;
  final int direction;
  final int variant;
  double x;
}

class RoadCrossing {
  RoadCrossing(this.z, this.flipAfter, this.redDuration);
  double z;
  final double flipAfter;
  final double redDuration;
  double age = 0;
  double carTimer = 0;
  int carsSent = 0;
  bool resolved = false;
  final cars = <CrossTrafficCar>[];

  TrafficPhase get phase {
    if (age < flipAfter) return TrafficPhase.green;
    if (age < flipAfter + .4) return TrafficPhase.amber;
    if (age < flipAfter + .4 + redDuration ||
        cars.any((car) => car.x.abs() < 1.3)) {
      return TrafficPhase.red;
    }
    return TrafficPhase.green;
  }
}

class RoadItem {
  RoadItem(this.kind, this.x, this.z, {this.variant = 0});
  final ItemKind kind;
  final double x;
  double z;
  final int variant;
  bool resolved = false;
  bool collected = false;
}

class FlyingParcel {
  FlyingParcel({
    required this.x,
    required this.height,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.variant,
  });
  double x;
  double height;
  double vx;
  double vy;
  double rotation;
  final int variant;
  double life = 1;
}

/// Pure Dart simulation. Rendering and platform services stay outside this class.
class DeliveryModel {
  DeliveryModel({int seed = 42}) : _random = math.Random(seed);
  static const duration = 30.0;
  static const playerZ = 10.0;
  static const lanes = [-.67, 0.0, .67];
  final math.Random _random;
  void Function(RunEvent)? onEvent;
  RunPhase phase = RunPhase.ready;
  final items = <RoadItem>[];
  final flying = <FlyingParcel>[];
  final crossings = <RoadCrossing>[];
  double elapsed = 0;
  double distance = 0;
  double x = 0;
  double targetX = 0;
  double velocity = 0;
  double lean = 0;
  double leanVelocity = 0;
  double stackSway = 0;
  double stackSwayVelocity = 0;
  double balanceStress = 0;
  double balanceGrace = 0;
  bool braking = false;
  double invulnerability = 0;
  double shake = 0;
  double hop = 0;
  double hopVelocity = 0;
  double eventTime = 0;
  double _spawnTimer = 0;
  double _crossingTimer = 0;
  int _crossingsSpawned = 0;
  int _wave = 0;
  int cargo = 0;
  int collected = 0;
  int lost = 0;
  int collisions = 0;
  int streak = 0;
  int bestStreak = 0;
  int peakCargo = 0;
  String message = '';
  int stageIndex = 0;
  bool shield = false;
  double magnetTime = 0;
  DeliveryStage get stage => deliveryStages[stageIndex];
  int get stars => stage.starsFor(cargo);
  bool get goalReached => cargo >= stage.goal;

  double get remaining => math.max(0, stage.seconds - elapsed);
  double get progress => (elapsed / stage.seconds).clamp(0.0, 1.0);
  double get speed => stage.baseSpeed + progress * 6;
  double get travelSpeed => braking ? 0 : speed;
  double get loadFactor => (cargo / 24).clamp(0.0, 1.0);
  double get steeringResponse => 11 - 7 * loadFactor;
  RoadCrossing? get upcomingCrossing {
    for (final crossing in crossings) {
      if (crossing.z >= playerZ && !crossing.resolved) return crossing;
    }
    return null;
  }

  bool get running => phase == RunPhase.running;

  void start({int? stage}) {
    if (stage != null) {
      stageIndex = stage.clamp(0, deliveryStages.length - 1);
    }
    phase = RunPhase.running;
    elapsed = distance = x = targetX = velocity = lean = leanVelocity = 0;
    stackSway = stackSwayVelocity = 0;
    balanceStress = balanceGrace = 0;
    braking = false;
    invulnerability = shake = hop = hopVelocity = eventTime = 0;
    cargo = collected = lost = collisions = streak = bestStreak = peakCargo = 0;
    message = '';
    shield = false;
    magnetTime = 0;
    _wave = 0;
    _spawnTimer = .25;
    _crossingTimer = 4.2;
    _crossingsSpawned = 0;
    items.clear();
    flying.clear();
    crossings.clear();
    // A gentle opening: three visible parcels before the first obstacle.
    items.addAll([
      RoadItem(ItemKind.parcel, 0, 37),
      RoadItem(ItemKind.parcel, -.67, 57, variant: 1),
      RoadItem(ItemKind.parcel, .67, 80, variant: 2),
    ]);
  }

  void steer(double value) => targetX = value.clamp(-.91, .91);
  void pause() {
    if (running) {
      phase = RunPhase.paused;
    }
  }

  void resume() {
    if (phase == RunPhase.paused) {
      phase = RunPhase.running;
    }
  }

  void update(double dt) {
    if (!running || dt <= 0 || !dt.isFinite) {
      return;
    }
    dt = math.min(dt, .05);
    elapsed = math.min(stage.seconds, elapsed + dt);
    distance += travelSpeed * dt;
    eventTime = math.max(0, eventTime - dt);
    invulnerability = math.max(0, invulnerability - dt);
    magnetTime = math.max(0, magnetTime - dt);
    shake = math.max(0, shake - dt * 3);
    balanceGrace = math.max(0, balanceGrace - dt);
    final previousVelocity = velocity;
    final oldX = x;
    final desiredX = (targetX + stackSway * loadFactor * .12).clamp(-.91, .91);
    if (!braking) {
      x += (desiredX - x) * (1 - math.exp(-steeringResponse * dt));
    }
    velocity = (x - oldX) / dt;
    leanVelocity += -(velocity - previousVelocity) * .36 - lean * 30 * dt;
    leanVelocity *= math.exp(-5 * dt);
    lean = (lean + leanVelocity * dt).clamp(-.7, .7);
    final swayTarget =
        (-velocity * (.025 + loadFactor * .12) +
                math.sin(elapsed * 3.5) * loadFactor * .035)
            .clamp(-.42, .42);
    stackSwayVelocity += (swayTarget - stackSway) * (14 - loadFactor * 5) * dt;
    stackSwayVelocity *= math.exp(-(6 - loadFactor * 2) * dt);
    stackSway = (stackSway + stackSwayVelocity * dt).clamp(-.42, .42);
    _updateBalance(dt);
    if (hop > 0 || hopVelocity > 0) {
      hopVelocity -= 380 * dt;
      hop = math.max(0, hop + hopVelocity * dt);
      if (hop == 0) {
        hopVelocity = 0;
      }
    }
    if (!braking) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0 && remaining > 5) {
        _spawnWave();
        _spawnTimer += stage.interval;
      }
      _crossingTimer -= dt;
      if (_crossingTimer <= 0 && remaining > 8) {
        final flipDistance = 53 + _random.nextDouble() * 28;
        final flipAfter = _crossingsSpawned == 0
            ? (145 - flipDistance) / speed
            : _random.nextDouble() < .8
            ? (145 - flipDistance) / speed
            : double.infinity;
        crossings.add(RoadCrossing(145, flipAfter, 2.3 + stageIndex * .2));
        _crossingsSpawned++;
        _crossingTimer += 10.5 - stageIndex * .45;
      }
    }

    _updateCrossings(dt);

    for (final item in items) {
      final oldZ = item.z;
      item.z -= travelSpeed * dt;
      // Swept forward collision prevents tunneling, independent of render FPS.
      if (!item.resolved && oldZ >= playerZ && item.z <= playerZ) {
        item.resolved = true;
        final width = item.kind == ItemKind.car ? .32 : .24;
        if ((item.x - x).abs() < width ||
            (item.kind == ItemKind.parcel && magnetTime > 0)) {
          item.collected =
              item.kind == ItemKind.parcel ||
              item.kind == ItemKind.shield ||
              item.kind == ItemKind.magnet;
          _hit(item.kind);
        }
      }
    }
    items.removeWhere((item) => item.z < -8 || item.collected);
    for (final piece in flying) {
      piece.x += piece.vx * dt;
      piece.height += piece.vy * dt;
      piece.vy -= 220 * dt;
      piece.rotation += piece.vx * dt * .05;
      piece.life -= dt;
    }
    flying.removeWhere((piece) => piece.life <= 0);
    if (elapsed >= stage.seconds) {
      phase = RunPhase.finished;
      onEvent?.call(RunEvent.finish);
    }
  }

  void _updateBalance(double dt) {
    if (cargo < 6) {
      balanceStress = 0;
      return;
    }
    final excess = math.max(0, velocity.abs() - (2.5 - 1.4 * loadFactor));
    if (balanceGrace == 0 && !braking) {
      balanceStress =
          (balanceStress +
                  excess * dt * (1.2 + 1.8 * loadFactor) -
                  (excess == 0 ? .36 * dt : 0))
              .clamp(0.0, 1.2);
    } else {
      balanceStress = math.max(0, balanceStress - dt * .8);
    }
    if (balanceStress < .85) return;
    final count = _drop(cargo >= 18 ? 2 : 1);
    balanceStress = .18;
    balanceGrace = .85;
    streak = 0;
    shake = .35;
    message = 'Turned too sharply! −$count ${parcelWord(count)}';
    eventTime = 1.5;
    onEvent?.call(RunEvent.spill);
  }

  void _updateCrossings(double dt) {
    for (final crossing in crossings) {
      final oldZ = crossing.z;
      crossing.z -= travelSpeed * dt;
      crossing.age += dt;
      final redStarts = crossing.flipAfter + .4;
      final redEnds = redStarts + crossing.redDuration;
      if (crossing.phase == TrafficPhase.red && crossing.age < redEnds - .35) {
        crossing.carTimer -= dt;
        if (crossing.carTimer <= 0) {
          crossing.cars.add(
            CrossTrafficCar(
              crossing.carsSent.isEven ? 1 : -1,
              crossing.carsSent % 3,
            ),
          );
          crossing.carsSent++;
          crossing.carTimer += .68 - stageIndex * .04;
        }
      }
      for (final car in crossing.cars) {
        car.x += car.direction * (1.85 + stageIndex * .12) * dt;
      }
      crossing.cars.removeWhere((car) => car.x.abs() > 1.65);
      if (!crossing.resolved && oldZ >= playerZ && crossing.z <= playerZ) {
        crossing.resolved = true;
        if (crossing.phase == TrafficPhase.red && invulnerability == 0) {
          final carHit = crossing.cars.any((car) => (car.x - x).abs() < .38);
          final protected = shield;
          final before = cargo;
          _hit(ItemKind.car);
          if (!protected) {
            final fallen = before - cargo;
            message = fallen == 0
                ? (carHit ? 'Car at the crossing!' : 'Ran a red light!')
                : carHit
                ? 'Car at the crossing! −$fallen ${parcelWord(fallen)}'
                : 'Ran a red light! −$fallen ${parcelWord(fallen)}';
          }
        }
      }
    }
    crossings.removeWhere((crossing) => crossing.z < -18);
  }

  void _spawnWave() {
    final lane = _wave < 2 ? _wave : _random.nextInt(3);
    items.add(RoadItem(ItemKind.parcel, lanes[lane], 112, variant: _wave % 3));
    if (_wave.isEven) {
      items.add(
        RoadItem(ItemKind.parcel, lanes[lane], 94, variant: (_wave + 1) % 3),
      );
    }
    final nearCrossing = crossings.any(
      (crossing) => (crossing.z - 112).abs() < 20,
    );
    if (_wave >= 2 && !nearCrossing) {
      final blocked = (lane + 1 + _random.nextInt(2)) % 3;
      final kind = (_wave % 7 == 5 || (stageIndex == 2 && _wave % 3 == 0))
          ? ItemKind.bump
          : (_wave % 4 == 3 ? ItemKind.car : ItemKind.cone);
      items.add(RoadItem(kind, lanes[blocked], 112, variant: _wave % 3));
      // The parcel lane always remains clear, even during the rush hour.
      if (stageIndex >= 2 && _wave % 4 == 0) {
        final other = 3 - lane - blocked;
        items.add(RoadItem(ItemKind.cone, lanes[other], 112));
      }
    }
    // Bonuses follow the parcel in its safe lane; they never reduce the score
    // that a careful player can earn on a route.
    if (_wave % 8 == 3) {
      items.add(
        RoadItem(
          _wave % 16 == 3 ? ItemKind.shield : ItemKind.magnet,
          lanes[lane],
          126,
        ),
      );
    }
    _wave++;
  }

  void _hit(ItemKind kind) {
    if (kind == ItemKind.shield || kind == ItemKind.magnet) {
      if (kind == ItemKind.shield) {
        shield = true;
        message = 'Shield! Your next hit is blocked';
      } else {
        magnetTime = 6;
        message = 'Magnet! Collect every lane for 6 s';
      }
      eventTime = 1.6;
      onEvent?.call(RunEvent.bonus);
      return;
    }
    if (kind == ItemKind.parcel) {
      cargo++;
      collected++;
      streak++;
      bestStreak = math.max(bestStreak, streak);
      peakCargo = math.max(peakCargo, cargo);
      message = streak > 1 && streak % 5 == 0
          ? '$streak in a row!'
          : '+1 parcel';
      eventTime = .9;
      hopVelocity = math.max(30, hopVelocity);
      onEvent?.call(RunEvent.pickup);
      return;
    }
    if (invulnerability > 0) {
      return;
    }
    if (shield) {
      shield = false;
      invulnerability = .85;
      message = 'Shield used · stack saved!';
      eventTime = 1.4;
      onEvent?.call(RunEvent.bonus);
      return;
    }
    if (kind == ItemKind.bump) {
      hopVelocity = 110;
      leanVelocity += 1.2;
      final count = cargo > 5 ? _drop(1) : 0;
      message = count > 0 ? 'Bumpy ride! −1 parcel' : 'Nice hop!';
      eventTime = 1.3;
      invulnerability = .4;
      if (count > 0) {
        streak = 0;
      }
      onEvent?.call(RunEvent.bump);
      return;
    }
    collisions++;
    streak = 0;
    final count = _drop(
      kind == ItemKind.car ? math.max(2, (cargo * .4).ceil()) : 2,
    );
    invulnerability = .85;
    shake = 1;
    leanVelocity += 2;
    message = count == 0
        ? 'Oops! Watch the road'
        : 'Oops! −$count ${parcelWord(count)}';
    eventTime = 1.5;
    onEvent?.call(RunEvent.crash);
  }

  int _drop(int requested) {
    final count = math.min(requested, cargo);
    for (var i = 0; i < count; i++) {
      flying.add(
        FlyingParcel(
          x: x * 160,
          height: 74 + (cargo - i) * 12,
          vx: (i.isEven ? -1 : 1) * (75 + _random.nextDouble() * 75),
          vy: 60 + _random.nextDouble() * 60,
          rotation: _random.nextDouble(),
          variant: i % 3,
        ),
      );
    }
    cargo -= count;
    lost += count;
    return count;
  }
}
