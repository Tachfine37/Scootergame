import 'package:ca_passe/game/delivery_model.dart';
import 'package:ca_passe/game/vehicles.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(DeliveryModel model, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    model.update(1 / 120);
  }
}

void runRed(DeliveryModel model) {
  model.crossings
    ..clear()
    ..add(RoadCrossing(10.1, 0, 5)..age = 1);
  model.update(.05);
}

void main() {
  test(
    'all three upgrade gates are reachable in the generated endless world',
    () {
      final model = DeliveryModel(seed: 19)..start();
      for (var tick = 0; tick < 180 * 120 && model.vehicleTier < 3; tick++) {
        model.invulnerability = 2;
        final crossing = model.upcomingCrossing;
        model.braking =
            crossing != null &&
            crossing.z < 25 &&
            crossing.phase != TrafficPhase.green;
        final upgrade = model.upcomingUpgrade;
        if (upgrade != null) model.steer(upgrade.x);
        model.update(1 / 120);
      }
      expect(model.running, true);
      expect(model.vehicleTier, 3);
      expect(model.distance, greaterThanOrEqualTo(2400));
      expect(model.vehicle.storage, 20);
    },
  );

  test('shield and crash immunity do not cancel police offences', () {
    final model = DeliveryModel()..start();
    model.shield = true;
    model.invulnerability = 5;
    runRed(model);
    expect(model.policeActive, true);
    expect(model.integrity, 3);
    expect(model.shield, true);
    runRed(model);
    expect(model.phase, RunPhase.wrecked);
    expect(model.endReason, RunEnd.caught);
    expect(model.redLightsRun, 2);
    advance(model, 1.3);
    expect(model.phase, RunPhase.finished);
  });

  test(
    'police escape requires forward travel; pause and braking cannot farm it',
    () {
      final model = DeliveryModel()..start();
      runRed(model);
      model.braking = true;
      advance(model, 20);
      expect(model.chaseDistance, 0);
      model.pause();
      advance(model, 20);
      expect(model.chaseDistance, 0);
      model.resume();
      model.braking = false;
      while (model.policeActive) {
        model.items.clear();
        model.crossings.clear();
        model.update(.05);
        expect(model.elapsed, lessThan(60));
      }
      expect(model.escapes, 1);
      expect(model.phase, RunPhase.running);
      expect(model.chaseDistance, greaterThanOrEqualTo(350));
    },
  );

  test('an unprotected accident in a chase ends the run', () {
    final model = DeliveryModel()..start();
    runRed(model);
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.car, 0, 10.1));
    model.update(.05);
    expect(model.endReason, RunEnd.caught);
    expect(model.phase, RunPhase.wrecked);
  });

  test('a shield absorbs a crash in a chase and bumps do not cause arrest', () {
    final model = DeliveryModel()..start();
    runRed(model);
    model.shield = true;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.car, 0, 10.1));
    model.update(.05);
    expect(model.running, true);
    expect(model.policeActive, true);
    expect(model.shield, false);
    model.invulnerability = 0;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.bump, 0, 10.1));
    model.update(.05);
    expect(model.running, true);
  });

  test(
    'pedestrians wait for red, cross without cars, and clear before green',
    () {
      final model = DeliveryModel()..start();
      final crossing = RoadCrossing(50, 1, 5.2, pedestrianOnly: true);
      model.crossings.add(crossing);
      model.braking = true;
      final startX = crossing.pedestrians.first.x;
      advance(model, 1.5);
      expect(crossing.pedestrians.first.x, startX);
      expect(crossing.pedestriansReleased, false);
      advance(model, 2);
      expect(crossing.pedestriansReleased, true);
      expect(crossing.phase, TrafficPhase.red);
      expect(crossing.pedestrians.any((person) => person.x.abs() < 1.3), true);
      expect(crossing.cars, isEmpty);
      advance(model, 5);
      expect(crossing.phase, TrafficPhase.green);
      expect(crossing.pedestrians, isEmpty);
      expect(model.redLightsRun, 0);
    },
  );

  test(
    'a pedestrian near miss causes an emergency stop without health damage',
    () {
      final model = DeliveryModel()..start();
      model.cargo = 8;
      final crossing = RoadCrossing(10.1, 0, 5.2, pedestrianOnly: true)
        ..age = 1;
      crossing.pedestrians.first.x = 0;
      model.crossings.add(crossing);
      model.update(.05);
      expect(model.pedestrianStops, 1);
      expect(model.cargo, 6);
      expect(model.integrity, 3);
      expect(model.emergencyStop, 1.2);
      expect(model.policeActive, true);
      final distance = model.distance;
      advance(model, .5);
      expect(model.distance, distance);
      expect(
        crossing.pedestrians.every((person) => person.x.abs() > .23),
        true,
      );
    },
  );

  test(
    'upgrades require their milestone and correct lane; no forced upgrade',
    () {
      final model = DeliveryModel()..start();
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.upgrade, 0, 10.1, variant: 1));
      model.update(.05);
      expect(model.vehicleTier, 0);
      model.distance = 900;
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.upgrade, .67, 10.1, variant: 1));
      model.update(.05);
      expect(model.vehicleTier, 0);
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.upgrade, 0, 10.1, variant: 1));
      model.update(.05);
      expect(model.vehicleTier, 1);
      expect(model.vehicle.storage, 6);
      expect(model.integrity, 3);
      expect(model.coins, 0);
    },
  );

  test(
    'larger vehicles collect bundles and protect storage without a cargo cap',
    () {
      for (var tier = 0; tier < deliveryVehicles.length; tier++) {
        final model = DeliveryModel()..start();
        model.vehicleTier = tier;
        for (var pickup = 0; pickup < 30; pickup++) {
          model.items
            ..clear()
            ..add(RoadItem(ItemKind.parcel, 0, 10.1));
          model.update(.05);
        }
        expect(model.cargo, 30 * (tier + 1));
        model.cargo = model.vehicle.storage + 1;
        model.items
          ..clear()
          ..add(RoadItem(ItemKind.car, 0, 10.1));
        model.update(.05);
        expect(model.cargo, model.vehicle.storage);
        expect(model.integrity, 2);
        if (tier > 0) expect(model.steeringResponse, lessThan(11));
      }
    },
  );

  test('speed climbs, stays capped and restart resets pursuit and vehicle', () {
    final model = DeliveryModel()..start();
    var previous = model.speed;
    for (final distance in [500.0, 1000.0, 2000.0, 10000.0]) {
      model.distance = distance;
      expect(model.speed, greaterThanOrEqualTo(previous));
      expect(model.speed, lessThanOrEqualTo(40));
      previous = model.speed;
    }
    model.vehicleTier = 3;
    model.policeActive = true;
    model.chaseDistance = 200;
    model.emergencyStop = 1;
    model.start();
    expect(model.vehicleTier, 0);
    expect(model.policeActive, false);
    expect(model.chaseDistance, 0);
    expect(model.emergencyStop, 0);
    expect(model.speedLevel, 1);
  });
}
