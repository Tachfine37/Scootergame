import 'package:ca_passe/game/delivery_model.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(DeliveryModel model, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    model.update(1 / 120);
  }
}

void main() {
  test('a run ends after 30 seconds and restart clears all state', () {
    final model = DeliveryModel()..start();
    advance(model, 30.1);
    expect(model.phase, RunPhase.finished);
    expect(model.remaining, 0);
    expect(model.collected - model.lost, model.cargo);
    model.start();
    expect(model.phase, RunPhase.running);
    expect(model.cargo, 0);
    expect(model.collisions, 0);
    expect(model.remaining, 30);
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

  test('each spawned traffic wave leaves a parcel lane open', () {
    final model = DeliveryModel(seed: 17)..start();
    for (var tick = 0; tick < 120 * 20; tick++) {
      model.update(1 / 120);
      final fresh = model.items.where((item) => item.z > 111).toList();
      final obstacles = fresh.where((item) => item.kind != ItemKind.parcel);
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

