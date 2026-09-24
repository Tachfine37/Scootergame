import 'package:ca_passe/game/delivery_model.dart';
import 'package:ca_passe/game/stages.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(DeliveryModel model, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    model.update(1 / 120);
  }
}

void main() {
  test(
    'three separate accidents break the scooter and finish exactly once',
    () {
      final model = DeliveryModel()..start();
      var finishes = 0;
      model.onEvent = (event) {
        if (event == RunEvent.finish) finishes++;
      };
      for (var hit = 1; hit <= 3; hit++) {
        model.invulnerability = 0;
        model.items
          ..clear()
          ..add(RoadItem(ItemKind.car, 0, 10.1));
        model.update(.05);
        expect(model.integrity, 3 - hit);
        expect(model.phase, hit == 3 ? RunPhase.wrecked : RunPhase.running);
      }
      final distance = model.distance;
      advance(model, 1.3);
      expect(model.phase, RunPhase.finished);
      expect(finishes, 1);
      advance(model, 10);
      expect(finishes, 1);
      expect(model.distance, distance);
    },
  );

  test(
    'crash grace blocks repeat damage; bumps and spills do not damage health',
    () {
      final model = DeliveryModel()..start();
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.car, 0, 10.1));
      model.update(.05);
      advance(model, 1);
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.car, 0, 10.1));
      model.update(.05);
      expect(model.integrity, 2);
      model.invulnerability = 0;
      model.cargo = 20;
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.bump, 0, 10.1));
      model.update(.05);
      model.steer(.9);
      advance(model, .5);
      expect(model.lost, greaterThan(0));
      expect(model.integrity, 2);
    },
  );

  test('delivery banks parcels once and changes district without stopping', () {
    final model = DeliveryModel()..start(stage: 3);
    model.distance = 399.9;
    model.cargo = model.collected = 8;
    model.items.clear();
    model.update(.05);
    expect(model.phase, RunPhase.running);
    expect(model.stageIndex, 0);
    expect(model.deliveries, 1);
    expect(model.delivered, 8);
    expect(model.cargo, 0);
    expect(model.coins, 16);
    expect(model.score, model.distance.floor() + 200);
    model.update(.05);
    expect(model.coins, 16);
    expect(model.deliveries, 1);
    expect(model.distanceToDelivery, greaterThan(390));
  });

  test('garage needs the correct lane, damage and sufficient earned coins', () {
    final model = DeliveryModel()..start();
    model.integrity = 1;
    model.coins = 12;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.garage, .67, 10.1));
    model.update(.05);
    expect(model.integrity, 1);
    expect(model.coins, 12);
    for (var pass = 0; pass < 3; pass++) {
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.garage, 0, 10.1));
      model.update(.05);
    }
    expect(model.integrity, 3);
    expect(model.coins, 0);
    expect(model.repairs, 2);
    model.integrity = 2;
    model.coins = 5;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.garage, 0, 10.1));
    model.update(.05);
    expect(model.integrity, 2);
    expect(model.coins, 5);
    expect(model.message, 'Garage: need 6 coins');
  });

  test(
    'garage spawns visibly with a clear approach after the first delivery',
    () {
      final model = DeliveryModel()..start();
      model.distance = 499;
      model.update(.05);
      final garage = model.upcomingGarage!;
      expect(garage.z, greaterThan(100));
      for (var tick = 0; tick < 120 * 3; tick++) {
        model.invulnerability = 2;
        model.update(1 / 120);
        expect(
          model.items.any(
            (item) =>
                [
                  ItemKind.car,
                  ItemKind.cone,
                  ItemKind.bump,
                ].contains(item.kind) &&
                (item.z - garage.z).abs() < 25,
          ),
          false,
        );
      }
    },
  );

  test('shield absorbs exactly one collision and restart clears bonuses', () {
    final model = DeliveryModel()..start(stage: 3);
    model.cargo = 10;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.shield, 0, 10.1));
    model.update(.05);
    expect(model.shield, true);
    model.items.add(RoadItem(ItemKind.car, 0, 10.1));
    model.update(.05);
    expect(model.cargo, 10);
    expect(model.shield, false);
    expect(model.collisions, 0);
    advance(model, 1.7);
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.car, 0, 10.1));
    model.update(.05);
    expect(model.cargo, 6);
    model.magnetTime = 4;
    model.start();
    expect(model.stageIndex, 3);
    expect(model.integrity, 3);
    expect(model.magnetTime, 0);
  });

  test('magnet collects all lanes once, expires, and freezes during pause', () {
    final model = DeliveryModel()..start();
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.magnet, 0, 10.1));
    model.update(.05);
    model.pause();
    advance(model, 10);
    expect(model.magnetTime, 6);
    model.resume();
    model.items.addAll([
      RoadItem(ItemKind.parcel, -.67, 10.1),
      RoadItem(ItemKind.parcel, .67, 10.1),
    ]);
    model.update(.05);
    expect(model.cargo, 2);
    expect(model.items.where((item) => item.kind == ItemKind.parcel), isEmpty);
    advance(model, 6.1);
    expect(model.magnetTime, 0);
    final cargo = model.cargo;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.parcel, .67, 10.1));
    model.update(.05);
    expect(model.cargo, cargo);
  });

  test(
    'all starting districts run indefinitely and keep reward lanes safe',
    () {
      for (var stage = 0; stage < deliveryStages.length; stage++) {
        final model = DeliveryModel(seed: 19)..start(stage: stage);
        for (var tick = 0; tick < 120 * 150; tick++) {
          model.invulnerability = 2;
          model.update(1 / 120);
          final fresh = model.items.where((item) => item.z > 111).toList();
          final obstacles = fresh.where(
            (item) => [
              ItemKind.car,
              ItemKind.cone,
              ItemKind.bump,
            ].contains(item.kind),
          );
          final rewards = fresh.where(
            (item) => [
              ItemKind.parcel,
              ItemKind.shield,
              ItemKind.magnet,
            ].contains(item.kind),
          );
          for (final reward in rewards) {
            expect(obstacles.any((item) => item.x == reward.x), false);
          }
        }
        expect(model.phase, RunPhase.running);
        expect(model.deliveries, greaterThan(4));
        expect(model.cargo + model.delivered, model.collected - model.lost);
        expect(model.stageIndex, (stage + model.deliveries) % 4);
        expect(model.speed, lessThanOrEqualTo(36));
        expect(model.items.length, lessThan(50));
        expect(model.crossings.length, lessThan(4));
      }
    },
  );

  test('waiting never ends a run and restart clears endless state', () {
    final model = DeliveryModel()..start();
    model.braking = true;
    advance(model, 30.1);
    expect(model.phase, RunPhase.running);
    expect(model.distance, 0);
    expect(model.score, 0);
    model.integrity = 1;
    model.delivered = 12;
    model.coins = 18;
    model.repairs = 2;
    model.start();
    expect(model.phase, RunPhase.running);
    expect(model.cargo, 0);
    expect(model.collisions, 0);
    expect(model.integrity, 3);
    expect(model.delivered, 0);
    expect(model.coins, 0);
    expect(model.repairs, 0);
    expect(model.braking, false);
    expect(model.distanceToDelivery, 400);
  });

  test('pause freezes world, timer and steering', () {
    final model = DeliveryModel()..start();
    advance(model, 1);
    final distance = model.distance;
    final elapsed = model.elapsed;
    model.pause();
    model.steer(.8);
    advance(model, 3);
    expect(model.distance, distance);
    expect(model.elapsed, elapsed);
    model.resume();
    advance(model, 1);
    expect(model.distance, greaterThan(distance));
  });

  test('swept collision collects a parcel only once', () {
    final model = DeliveryModel()..start();
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.parcel, 0, 10.1));
    model.update(.05);
    expect(model.cargo, 1);
    model.update(.05);
    expect(model.cargo, 1);
  });

  test('cargo and peak keep growing beyond fifteen parcels', () {
    final model = DeliveryModel()..start();
    for (var i = 0; i < 21; i++) {
      model.items
        ..clear()
        ..add(RoadItem(ItemKind.parcel, 0, 10.1));
      model.update(.05);
    }
    expect(model.cargo, 21);
    expect(model.collected, 21);
    expect(model.peakCargo, 21);
  });

  test('the route offers more than fifteen parcels', () {
    final model = DeliveryModel(seed: 19)..start();
    model.magnetTime = 100;
    for (var tick = 0; tick < 30 * 120; tick++) {
      model.invulnerability = 1;
      model.update(1 / 120);
    }
    expect(model.collected, greaterThan(20));
    expect(model.collected, model.cargo + model.delivered);
  });

  test('lateral miss does not collect a parcel', () {
    final model = DeliveryModel()..start();
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.parcel, .67, 10.1));
    model.update(.05);
    expect(model.cargo, 0);
  });

  test('car drops 40 percent; invulnerability prevents a double hit', () {
    final model = DeliveryModel()..start();
    model.cargo = 10;
    model.items
      ..clear()
      ..addAll([
        RoadItem(ItemKind.car, 0, 10.1),
        RoadItem(ItemKind.cone, 0, 10.2),
      ]);
    model.update(.05);
    expect(model.cargo, 6);
    expect(model.lost, 4);
    expect(model.collisions, 1);
    expect(model.flying.length, 4);
  });

  test('crashing with an empty load cannot produce negative cargo', () {
    final model = DeliveryModel()..start();
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.car, 0, 10.1));
    model.update(.05);
    expect(model.cargo, 0);
    expect(model.lost, 0);
  });

  test('bump launches scooter and only drops cargo from a tall stack', () {
    final model = DeliveryModel()..start();
    model.cargo = 8;
    model.items
      ..clear()
      ..add(RoadItem(ItemKind.bump, 0, 10.1));
    model.update(.05);
    expect(model.cargo, 7);
    advance(model, .1);
    expect(model.hop, greaterThan(0));
  });

  test('steering is bounded and converges without leaving the road', () {
    final model = DeliveryModel()..start();
    model.steer(100);
    advance(model, 2);
    expect(model.x, inInclusiveRange(.89, .91));
    model.steer(-100);
    advance(model, 2);
    expect(model.x, inInclusiveRange(-.91, -.89));
  });

  test('a tall pile steers slower and sways more than an empty scooter', () {
    final empty = DeliveryModel()..start();
    final loaded = DeliveryModel()..start();
    loaded.cargo = 24;
    empty.steer(.9);
    loaded.steer(.9);
    advance(empty, .25);
    advance(loaded, .25);
    expect(loaded.steeringResponse, lessThan(empty.steeringResponse));
    expect(loaded.x, lessThan(empty.x));
    expect(loaded.stackSway.abs(), greaterThan(empty.stackSway.abs()));
    loaded.start();
    expect(loaded.stackSway, 0);
    expect(loaded.steeringResponse, empty.steeringResponse);
  });

  test('a hard turn spills a tall pile, but not an empty scooter', () {
    final empty = DeliveryModel()..start();
    final loaded = DeliveryModel()..start();
    loaded.cargo = 20;
    empty.steer(.9);
    loaded.steer(.9);
    advance(empty, .4);
    advance(loaded, .4);
    expect(empty.lost, 0);
    expect(loaded.lost, 2);
    expect(loaded.cargo, 18);
    expect(loaded.message, contains('Turned too sharply'));
    expect(loaded.balanceGrace, greaterThan(0));
  });

  test(
    'quick reversing spills a medium pile while gentle steering is safe',
    () {
      final sharp = DeliveryModel()..start();
      final gentle = DeliveryModel()..start();
      sharp.cargo = gentle.cargo = 10;
      sharp.steer(.9);
      advance(sharp, .4);
      sharp.steer(-.9);
      advance(sharp, .5);
      for (var step = 1; step <= 9; step++) {
        gentle.steer(step * .1);
        advance(gentle, .1);
      }
      expect(sharp.lost, 1);
      expect(gentle.lost, 0);
    },
  );

  test('a red crossing car hits a rider who does not brake', () {
    final model = DeliveryModel()..start();
    model.cargo = 10;
    final crossing = RoadCrossing(10.1, 0, 5)..age = 1;
    crossing.cars.add(CrossTrafficCar(1, 0)..x = 0);
    model.crossings.add(crossing);
    model.update(.05);
    expect(crossing.resolved, true);
    expect(model.collisions, 1);
    expect(model.cargo, 6);
    expect(model.message, 'Car at the crossing! −4 parcels');
  });

  test('running a red light is costly even between crossing cars', () {
    final model = DeliveryModel()..start();
    model.cargo = 10;
    model.crossings.add(RoadCrossing(10.1, 0, 5)..age = 1);
    model.update(.05);
    expect(model.collisions, 1);
    expect(model.cargo, 6);
    expect(model.message, 'Ran a red light! −4 parcels');
  });

  test('the light changes from green through amber to red', () {
    final crossing = RoadCrossing(60, 1, 2);
    expect(crossing.phase, TrafficPhase.green);
    crossing.age = 1.2;
    expect(crossing.phase, TrafficPhase.amber);
    crossing.age = 1.5;
    expect(crossing.phase, TrafficPhase.red);
    crossing.age = 3.5;
    expect(crossing.phase, TrafficPhase.green);
  });

  test('braking waits out a red light while cross traffic keeps moving', () {
    final model = DeliveryModel()..start();
    final crossing = RoadCrossing(14, 0, 1)..age = .5;
    model.crossings.add(crossing);
    model.braking = true;
    final distance = model.distance;
    advance(model, 2.5);
    expect(model.distance, distance);
    expect(crossing.z, 14);
    expect(crossing.phase, TrafficPhase.green);
    expect(crossing.cars, isEmpty);
    expect(model.elapsed, greaterThan(2));
    model.braking = false;
    advance(model, .3);
    expect(crossing.resolved, true);
    expect(model.collisions, 0);
  });

  test('each spawned traffic wave leaves a parcel lane open', () {
    final model = DeliveryModel(seed: 17)..start();
    for (var tick = 0; tick < 120 * 20; tick++) {
      model.update(1 / 120);
      final fresh = model.items.where((item) => item.z > 111).toList();
      final obstacles = fresh.where(
        (item) =>
            [ItemKind.car, ItemKind.cone, ItemKind.bump].contains(item.kind),
      );
      for (final parcel in fresh.where(
        (item) => item.kind == ItemKind.parcel,
      )) {
        expect(
          obstacles.any((obstacle) => (obstacle.x - parcel.x).abs() < .1),
          false,
        );
      }
    }
  });
}
