import 'package:ca_passe/game/delivery_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a red light with no impact emits police, not a crash sound', () {
    final model = DeliveryModel()..start();
    final events = <RunEvent>[];
    model.onEvent = events.add;
    final crossing = RoadCrossing(10.1, 0, 5)..age = 1;
    crossing.carTimer = 99;
    model.crossings.add(crossing);
    model.update(.05);
    expect(model.policeActive, true);
    expect(events, contains(RunEvent.police));
    expect(events, isNot(contains(RunEvent.crash)));
  });

  test('an upgrade has its own cue and cannot repeat after collection', () {
    final model = DeliveryModel()..start();
    final events = <RunEvent>[];
    model.onEvent = events.add;
    model.distance = 800;
    model.items.add(RoadItem(ItemKind.upgrade, 0, 10.1, variant: 1));
    model.update(.05);
    model.update(.05);
    expect(model.vehicleTier, 1);
    expect(events.where((e) => e == RunEvent.upgrade).length, 1);
  });
}
