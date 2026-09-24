import 'dart:math' as math;
import 'stages.dart';
import 'vehicles.dart';

String parcelWord(int count) => count == 1 ? 'parcel' : 'parcels';

enum RunPhase { ready, running, paused, wrecked, finished }

enum ItemKind { parcel, cone, car, bump, shield, magnet, garage, upgrade }

enum RunEnd { broken, caught }

enum RunEvent {
  pickup,
  crash,
  bump,
  spill,
  finish,
  bonus,
  upgrade,
  delivery,
  police,
  escape,
  nearMiss,
}

enum TrafficPhase { green, amber, red }

class CrossingPedestrian {
  CrossingPedestrian(this.direction, this.variant)
    : x = direction > 0 ? -1.55 - variant * .12 : 1.55 + variant * .12;
  final int direction;
  final int variant;
  double x;
}

class CrossTrafficCar {
  CrossTrafficCar(this.direction, this.variant)
    : x = direction > 0 ? -1.55 : 1.55;
  final int direction;
  final int variant;
  double x;
}

class RoadCrossing {
  RoadCrossing(
    this.z,
    this.flipAfter,
    this.redDuration, {
    this.pedestrianOnly = false,
  }) {
    if (pedestrianOnly) {
      pedestrians.addAll([
        CrossingPedestrian(1, 0),
        CrossingPedestrian(-1, 1),
        CrossingPedestrian(1, 2),
      ]);
    }
  }
  static const amberDuration = .7;
  double z;
  final double flipAfter;
  final double redDuration;
  final bool pedestrianOnly;
  bool pedestriansReleased = false;
  final pedestrians = <CrossingPedestrian>[];
  double age = 0;
  double carTimer = 0;
  int carsSent = 0;
  bool resolved = false;
  final cars = <CrossTrafficCar>[];

  TrafficPhase get phase {
    if (age < flipAfter) return TrafficPhase.green;
    if (age < flipAfter + amberDuration) return TrafficPhase.amber;
    if (age < flipAfter + amberDuration + redDuration ||
        cars.any((car) => car.x.abs() < 1.3) ||
        pedestrians.any((person) => person.x.abs() < 1.35)) {
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
  static const deliveryInterval = 400.0;
  static const repairCost = 6;
  static const maxIntegrity = 3;
  static const policeEscapeDistance = 350.0;
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
  int integrity = maxIntegrity;
  int delivered = 0;
  int coins = 0;
  int repairs = 0;
  int deliveries = 0;
  int vehicleTier = 0;
  RunEnd endReason = RunEnd.broken;
  bool policeActive = false;
  double chaseDistance = 0;
  int escapes = 0;
  int redLightsRun = 0;
  int pedestrianStops = 0;
  double emergencyStop = 0;
  int _speedLevel = 1;
  double wreckTime = 0;
  double _nextDelivery = deliveryInterval;
  double _nextGarage = 600;
  int _garagesSpawned = 0;
  String message = '';
  int stageIndex = 0;
  bool shield = false;
  double magnetTime = 0;
  DeliveryStage get stage => deliveryStages[stageIndex];
  int get score => distance.floor() + delivered * 25;
  double get distanceToDelivery => math.max(0, _nextDelivery - distance);
  double get progress => 1 - distanceToDelivery / deliveryInterval;
  double get difficulty => (distance / 2000).clamp(0.0, 1.0);
  double get speed => 22 + difficulty * 18;
  int get speedLevel => 1 + (distance / 500).floor().clamp(0, 4);
  double get spawnInterval => 1.15 - difficulty * .3;
  double get travelSpeed => braking || emergencyStop > 0 ? 0 : speed;
  DeliveryVehicle get vehicle => deliveryVehicles[vehicleTier];
  DeliveryVehicle? get nextVehicle => vehicleTier < deliveryVehicles.length - 1
      ? deliveryVehicles[vehicleTier + 1]
      : null;
  int get storedCargo => math.min(cargo, vehicle.storage);
  int get pickupSize => vehicleTier + 1;
  int get exposedCargo => cargo - storedCargo;
  double get loadFactor => (exposedCargo / vehicle.loadRating).clamp(0.0, 1.0);
  double get steeringResponse => (11 - 7 * loadFactor) * vehicle.handling;
  double get escapeRemaining =>
      math.max(0, policeEscapeDistance - chaseDistance);
  RoadCrossing? get upcomingCrossing {
    for (final crossing in crossings) {
      if (crossing.z >= playerZ && !crossing.resolved) return crossing;
    }
    return null;
  }

  bool get running => phase == RunPhase.running;
  RoadItem? get upcomingGarage {
    for (final item in items) {
      if ((item.kind == ItemKind.garage || item.kind == ItemKind.upgrade) &&
          !item.resolved) {
        return item;
      }
    }
    return null;
  }

  RoadItem? get upcomingUpgrade {
    for (final item in items) {
      if (item.kind == ItemKind.upgrade && !item.resolved) return item;
    }
    return null;
  }

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
    integrity = maxIntegrity;
    delivered = coins = repairs = deliveries = 0;
    vehicleTier = escapes = redLightsRun = pedestrianStops = 0;
    policeActive = false;
    chaseDistance = emergencyStop = 0;
    endReason = RunEnd.broken;
    _speedLevel = 1;
    wreckTime = 0;
    _nextDelivery = deliveryInterval;
    _nextGarage = 600;
    _garagesSpawned = 0;
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
    if (dt <= 0 || !dt.isFinite) {
      return;
    }
    dt = math.min(dt, .05);
    if (phase == RunPhase.wrecked) {
      wreckTime += dt;
      shake = math.max(0, shake - dt * 2);
      if (wreckTime >= 1.2) {
        phase = RunPhase.finished;
        onEvent?.call(RunEvent.finish);
      }
      return;
    }
    if (!running) return;
    elapsed += dt;
    final travelled = travelSpeed * dt;
    distance += travelled;
    emergencyStop = math.max(0, emergencyStop - dt);
    eventTime = math.max(0, eventTime - dt);
    invulnerability = math.max(0, invulnerability - dt);
    magnetTime = math.max(0, magnetTime - dt);
    shake = math.max(0, shake - dt * 3);
    balanceGrace = math.max(0, balanceGrace - dt);
    if (policeActive) {
      chaseDistance += travelled;
      if (chaseDistance >= policeEscapeDistance) {
        policeActive = false;
        escapes++;
        message = 'Police escaped! Keep riding clean';
        eventTime = 2;
        onEvent?.call(RunEvent.escape);
      }
    }
    if (speedLevel > _speedLevel) {
      _speedLevel = speedLevel;
      if (eventTime == 0) {
        message = 'Speed up! Level $speedLevel';
        eventTime = 1.8;
      }
    }
    final previousVelocity = velocity;
    final oldX = x;
    final desiredX = (targetX + stackSway * loadFactor * .12).clamp(-.91, .91);
    if (!braking && emergencyStop == 0) {
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
    if (!braking && emergencyStop == 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnWave();
        _spawnTimer += spawnInterval;
      }
      _crossingTimer -= dt;
      if (_crossingTimer <= 0 && upcomingGarage == null) {
        final flipDistance = 53 + _random.nextDouble() * 28;
        final flipAfter = _crossingsSpawned == 0
            ? (145 - flipDistance) / speed
            : _random.nextDouble() < .8
            ? (145 - flipDistance) / speed
            : double.infinity;
        final pedestrians = distance >= 400 && _crossingsSpawned % 3 == 2;
        crossings.add(
          RoadCrossing(
            145,
            flipAfter,
            pedestrians ? 5.2 : 2.3 + stageIndex * .2,
            pedestrianOnly: pedestrians,
          ),
        );
        _crossingsSpawned++;
        _crossingTimer += 11 - difficulty * 2;
      }
      _spawnGarage();
    }

    _updateCrossings(dt, travelled);
    if (!running) return;

    for (final item in items) {
      final oldZ = item.z;
      item.z -= travelled;
      // Swept forward collision prevents tunneling, independent of render FPS.
      if (!item.resolved && oldZ >= playerZ && item.z <= playerZ) {
        item.resolved = true;
        final width =
            item.kind == ItemKind.car ||
                item.kind == ItemKind.garage ||
                item.kind == ItemKind.upgrade
            ? .32
            : .24;
        final extraWidth =
            [ItemKind.car, ItemKind.cone, ItemKind.bump].contains(item.kind)
            ? vehicle.hitPadding
            : 0;
        if ((item.x - x).abs() < width + extraWidth ||
            (item.kind == ItemKind.parcel && magnetTime > 0)) {
          item.collected =
              item.kind == ItemKind.parcel ||
              item.kind == ItemKind.shield ||
              item.kind == ItemKind.magnet ||
              item.kind == ItemKind.garage ||
              item.kind == ItemKind.upgrade;
          _hit(item.kind, upgradeTier: item.variant);
          if (!running) break;
        } else if (item.kind == ItemKind.car &&
            (item.x - x).abs() < width + extraWidth + .16) {
          onEvent?.call(RunEvent.nearMiss);
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
    if (running && distance >= _nextDelivery) {
      final shipment = cargo;
      delivered += shipment;
      coins += shipment * 2;
      cargo = 0;
      balanceStress = stackSway = stackSwayVelocity = 0;
      deliveries++;
      _nextDelivery += deliveryInterval;
      stageIndex = (stageIndex + 1) % deliveryStages.length;
      message = shipment > 0
          ? 'Delivered $shipment! +${shipment * 2} coins'
          : 'Next district: ${stage.name}';
      eventTime = 2.4;
      onEvent?.call(RunEvent.delivery);
    }
  }

  void _spawnGarage() {
    if (distance + 102 < _nextGarage) return;
    final z = _nextGarage - distance + playerZ;
    if (crossings.any((crossing) => (crossing.z - z).abs() < 40)) {
      _nextGarage += 60;
      return;
    }
    // A clear approach gives the rider time to enter the repair lane.
    items.removeWhere(
      (item) =>
          (item.z - z).abs() < 28 &&
          [ItemKind.car, ItemKind.cone, ItemKind.bump].contains(item.kind),
    );
    items.add(
      RoadItem(ItemKind.garage, _garagesSpawned.isEven ? .67 : -.67, z),
    );
    if (nextVehicle != null && _nextGarage >= nextVehicle!.unlockDistance) {
      items.add(
        RoadItem(
          ItemKind.upgrade,
          _garagesSpawned.isEven ? -.67 : .67,
          z,
          variant: vehicleTier + 1,
        ),
      );
    }
    _garagesSpawned++;
    _nextGarage += deliveryInterval;
  }

  void _repair() {
    if (integrity == maxIntegrity) {
      message = 'Garage: scooter already healthy';
    } else if (coins < repairCost) {
      message = 'Garage: need $repairCost coins';
    } else {
      coins -= repairCost;
      integrity++;
      repairs++;
      invulnerability = 1.6;
      message = 'Repaired! +1 health, -$repairCost coins';
    }
    eventTime = 2;
    onEvent?.call(RunEvent.bonus);
  }

  void _updateBalance(double dt) {
    if (exposedCargo < 6) {
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
    final count = _drop(exposedCargo >= 18 ? 2 : 1);
    balanceStress = .18;
    balanceGrace = .85;
    streak = 0;
    shake = .35;
    message = 'Turned too sharply! −$count ${parcelWord(count)}';
    eventTime = 1.5;
    onEvent?.call(RunEvent.spill);
  }

  void _updateCrossings(double dt, double travelled) {
    for (final crossing in crossings) {
      final oldZ = crossing.z;
      crossing.z -= travelled;
      crossing.age += dt;
      final redStarts = crossing.flipAfter + RoadCrossing.amberDuration;
      final redEnds = redStarts + crossing.redDuration;
      if (crossing.pedestrianOnly && crossing.phase == TrafficPhase.red) {
        crossing.pedestriansReleased = true;
      }
      if (crossing.pedestriansReleased) {
        for (final person in crossing.pedestrians) {
          person.x += person.direction * .75 * dt;
        }
        crossing.pedestrians.removeWhere(
          (person) => person.direction > 0 ? person.x > 1.8 : person.x < -1.8,
        );
      }
      if (!crossing.pedestrianOnly &&
          crossing.phase == TrafficPhase.red &&
          crossing.age < redEnds - .35) {
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
        if (crossing.phase == TrafficPhase.red) {
          // Traffic offences are independent of shield or crash immunity.
          final alreadyChased = policeActive;
          redLightsRun++;
          if (alreadyChased) {
            _endRun(RunEnd.caught);
            return;
          }
          final carHit = crossing.cars.any(
            (car) => (car.x - x).abs() < .38 + vehicle.hitPadding,
          );
          if (carHit) _hit(ItemKind.car);
          if (crossing.pedestrians.any(
            (person) => (person.x - x).abs() < .23 + vehicle.hitPadding,
          )) {
            emergencyStop = 1.2;
            pedestrianStops++;
            _drop(2);
            streak = 0;
            invulnerability = math.max(invulnerability, 1.6);
            for (final person in crossing.pedestrians) {
              if ((person.x - x).abs() < .23 + vehicle.hitPadding) {
                person.x = person.direction > 0 ? 1.6 : -1.6;
              }
            }
          }
          if (!running) return;
          policeActive = true;
          chaseDistance = 0;
          message = emergencyStop > 0
              ? 'Emergency stop! Police alerted'
              : 'Red light! Police chasing · 350 m to escape';
          eventTime = 2.5;
          onEvent?.call(RunEvent.police);
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
    final nearGarage = items.any(
      (item) =>
          (item.kind == ItemKind.garage || item.kind == ItemKind.upgrade) &&
          (item.z - 112).abs() < 32,
    );
    if (_wave >= 2 && !nearCrossing && !nearGarage) {
      final blocked = (lane + 1 + _random.nextInt(2)) % 3;
      final kind = (_wave % 7 == 5 || (stageIndex == 2 && _wave % 3 == 0))
          ? ItemKind.bump
          : (_wave % 4 == 3 ? ItemKind.car : ItemKind.cone);
      items.add(RoadItem(kind, lanes[blocked], 112, variant: _wave % 3));
      // The parcel lane always remains clear, even during the rush hour.
      if (difficulty > .2 && _wave % 4 == 0) {
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

  void _hit(ItemKind kind, {int upgradeTier = 0}) {
    if (kind == ItemKind.upgrade) {
      if (upgradeTier == vehicleTier + 1 &&
          nextVehicle != null &&
          distance >= nextVehicle!.unlockDistance) {
        vehicleTier = upgradeTier;
        balanceStress = stackSway = stackSwayVelocity = 0;
        message = '${vehicle.name}! ${vehicle.storage} protected slots';
        eventTime = 2.5;
        onEvent?.call(RunEvent.upgrade);
      }
      return;
    }
    if (kind == ItemKind.garage) {
      _repair();
      return;
    }
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
      cargo += pickupSize;
      collected += pickupSize;
      streak++;
      bestStreak = math.max(bestStreak, streak);
      peakCargo = math.max(peakCargo, cargo);
      message = streak > 1 && streak % 5 == 0
          ? '$streak in a row!'
          : '+$pickupSize ${parcelWord(pickupSize)}';
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
      invulnerability = 1.6;
      message = 'Shield used · stack saved!';
      eventTime = 1.4;
      onEvent?.call(RunEvent.bonus);
      return;
    }
    if (kind == ItemKind.bump) {
      hopVelocity = 110;
      leanVelocity += 1.2;
      final count = exposedCargo > 5 ? _drop(1) : 0;
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
    if (policeActive) {
      _endRun(RunEnd.caught);
      return;
    }
    integrity--;
    streak = 0;
    final count = _drop(
      kind == ItemKind.car ? math.max(2, (cargo * .4).ceil()) : 2,
    );
    invulnerability = 1.6;
    shake = 1;
    leanVelocity += 2;
    message = integrity == 1
        ? 'Critical damage! Find a garage'
        : 'Crash! $integrity/3 health · -$count ${parcelWord(count)}';
    eventTime = 1.5;
    if (integrity == 0) {
      _endRun(RunEnd.broken);
      return;
    }
    onEvent?.call(RunEvent.crash);
  }

  void _endRun(RunEnd reason) {
    endReason = reason;
    phase = RunPhase.wrecked;
    braking = false;
    velocity = 0;
    wreckTime = 0;
    message = reason == RunEnd.caught
        ? 'Caught by the police!'
        : 'Scooter broken!';
    onEvent?.call(RunEvent.crash);
  }

  int _drop(int requested) {
    final count = math.min(requested, exposedCargo);
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
