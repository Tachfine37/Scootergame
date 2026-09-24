import 'package:ca_passe/data/game_preferences.dart';
import 'package:ca_passe/main.dart';
import 'package:ca_passe/game/delivery_game.dart';
import 'package:ca_passe/game/delivery_model.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('stage selection, results and next stage fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = GamePreferences(null);
    await tester.pumpWidget(DeliveryApp(preferences: prefs));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(find.text('Seaside'), findsOneWidget);
    await tester.tap(find.text("Let's go!"));
    await tester.pump(const Duration(milliseconds: 100));
    final game = tester
        .widget<GameWidget<DeliveryGame>>(find.byType(GameWidget<DeliveryGame>))
        .game!;
    expect(game.model.stageIndex, 1);
    game.model.cargo = 20;
    game.model.elapsed = game.model.stage.seconds - .01;
    game.model.update(.05);
    await tester.pump();
    expect(game.model.phase, RunPhase.finished);
    expect(find.text('Next route'), findsOneWidget);
    expect(prefs.stageStars(1), 3);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next route'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.model.stageIndex, 2);
    expect(game.model.cargo, 0);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('Choose a route'));
    await tester.pump();
    expect(find.text('Garden District'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('welcome, start, pause and resume work at narrow mobile size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = GamePreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(DeliveryApp(preferences: prefs));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('One more\nparcel?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("Let's go!"));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ON BOARD'), findsOneWidget);
    final game = tester
        .widget<GameWidget<DeliveryGame>>(find.byType(GameWidget<DeliveryGame>))
        .game!;
    final brake = await tester.startGesture(
      tester.getCenter(find.text('BRAKE')),
    );
    await tester.pump();
    expect(game.model.braking, true);
    await brake.up();
    await tester.pump();
    expect(game.model.braking, false);
    game.model.crossings.add(RoadCrossing(50, 0, 2)..age = 1);
    game.hud.value++;
    await tester.pump();
    expect(find.text('RED LIGHT · HOLD BRAKE'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Catch your breath?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
    await tester.pump();
    expect(find.text('Catch your breath?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('record survives loading a new preferences instance', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final prefs = GamePreferences(storage);
    await prefs.saveRecord(18);
    await prefs.saveRecord(4);
    expect(GamePreferences(storage).record, 18);
    await prefs.setHaptics(false);
    expect(GamePreferences(storage).haptics, false);
    await prefs.saveStage(1, 20);
    await prefs.saveStage(1, 4);
    await prefs.saveStage(2, 9);
    final reloaded = GamePreferences(storage);
    expect(reloaded.stageBest(1), 20);
    expect(reloaded.stageStars(1), 3);
    expect(reloaded.totalStars, 4);
  });
}
