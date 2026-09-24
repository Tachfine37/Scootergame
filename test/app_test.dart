import 'package:ca_passe/audio/game_music.dart';
import 'package:ca_passe/data/game_preferences.dart';
import 'package:ca_passe/main.dart';
import 'package:ca_passe/game/delivery_game.dart';
import 'package:ca_passe/game/delivery_model.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGameMusic extends GameMusic {
  final sounds = <GameSound>[];
  bool musicEnabled = true;
  bool effectsEnabled = true;
  @override
  Future<void> effect(GameSound sound, {bool preview = false}) async {
    sounds.add(sound);
  }

  @override
  Future<void> configure({
    required bool music,
    required bool effects,
    required double musicVolume,
    required double effectsVolume,
  }) async {
    musicEnabled = music;
    effectsEnabled = effects;
  }

  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('endless game over, saved score and restart fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = GamePreferences(null);
    await tester.pumpWidget(
      DeliveryApp(preferences: prefs, music: FakeGameMusic()),
    );
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
    game.model.distance = 123;
    game.model.delivered = 8;
    for (var hit = 0; hit < 3; hit++) {
      game.model.invulnerability = 0;
      game.model.items
        ..clear()
        ..add(RoadItem(ItemKind.car, 0, 10.1));
      game.model.update(.05);
    }
    expect(game.model.phase, RunPhase.wrecked);
    for (var tick = 0; tick < 150; tick++) {
      game.model.update(1 / 120);
    }
    await tester.pump();
    expect(game.model.phase, RunPhase.finished);
    expect(find.text('Ride again'), findsOneWidget);
    expect(prefs.endlessBest, game.model.score);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ride again'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.model.stageIndex, 1);
    expect(game.model.cargo, 0);
    expect(game.model.integrity, 3);
    expect(find.text('HEALTH 3/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('Choose a district'));
    await tester.pump();
    expect(find.text('Seaside'), findsOneWidget);
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
    await tester.pumpWidget(
      DeliveryApp(preferences: prefs, music: FakeGameMusic()),
    );
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
    game.model.cargo = 12;
    game.model.integrity = 1;
    game.model.items.add(RoadItem(ItemKind.garage, .67, 65));
    game.hud.value++;
    await tester.pump();
    expect(find.text('RED LIGHT · HOLD BRAKE'), findsOneWidget);
    expect(find.text('HEALTH 1/3'), findsOneWidget);
    expect(find.textContaining('GARAGE RIGHT'), findsNothing);
    game.model.crossings.clear();
    game.hud.value++;
    await tester.pump();
    expect(find.textContaining('GARAGE RIGHT'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Catch your breath?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
    await tester.pump();
    expect(find.text('Catch your breath?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'upgrades, pedestrians and police fit the smallest supported phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        DeliveryApp(preferences: GamePreferences(null), music: FakeGameMusic()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text("Let's go!"));
      await tester.pump(const Duration(milliseconds: 100));
      final game = tester
          .widget<GameWidget<DeliveryGame>>(
            find.byType(GameWidget<DeliveryGame>),
          )
          .game!;
      game.model.policeActive = true;
      game.model.cargo = 35;
      for (var tier = 0; tier < 4; tier++) {
        game.model.vehicleTier = tier;
        game.hud.value++;
        await tester.pump();
        expect(find.textContaining('TO ESCAPE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      game.model.vehicleTier = 2;
      game.model.items
        ..clear()
        ..addAll([
          RoadItem(ItemKind.garage, .67, 65),
          RoadItem(ItemKind.upgrade, -.67, 65, variant: 3),
        ]);
      game.hud.value++;
      await tester.pump();
      expect(find.textContaining('UPGRADE LEFT: Cargo Trike'), findsOneWidget);
      expect(tester.takeException(), isNull);
      game.model.crossings.add(
        RoadCrossing(40, 0, 5.2, pedestrianOnly: true)..age = 1,
      );
      game.hud.value++;
      await tester.pump();
      expect(find.text('PEDESTRIANS · HOLD BRAKE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      game.model.crossings
        ..clear()
        ..add(RoadCrossing(10.1, 0, 5)..age = 1);
      game.model.update(.05);
      for (var tick = 0; tick < 150; tick++) {
        game.model.update(1 / 120);
      }
      await tester.pump();
      expect(find.text('CAUGHT BY POLICE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('record survives loading a new preferences instance', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final prefs = GamePreferences(storage);
    await prefs.saveRecord(18);
    await prefs.saveRecord(4);
    expect(GamePreferences(storage).record, 18);
    await prefs.setHaptics(false);
    expect(GamePreferences(storage).haptics, false);
    await prefs.setMusic(false);
    expect(GamePreferences(storage).music, false);
    await prefs.setEffects(false);
    await prefs.setMusicVolume(.25);
    await prefs.setEffectsVolume(.8);
    expect(GamePreferences(storage).effects, false);
    expect(GamePreferences(storage).musicVolume, .25);
    expect(GamePreferences(storage).effectsVolume, .8);
    await prefs.saveStage(1, 20);
    await prefs.saveStage(1, 4);
    await prefs.saveStage(2, 9);
    final reloaded = GamePreferences(storage);
    expect(reloaded.stageBest(1), 20);
    expect(reloaded.stageStars(1), 3);
    expect(reloaded.totalStars, 4);
    await prefs.saveEndlessBest(1234);
    await prefs.saveEndlessBest(100);
    expect(GamePreferences(storage).endlessBest, 1234);
    expect(GamePreferences(storage).record, 18);
  });

  testWidgets('soundtrack follows play, pause, mute and district selection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final music = FakeGameMusic();
    await tester.pumpWidget(
      DeliveryApp(preferences: GamePreferences(null), music: music),
    );
    await tester.pump();
    expect(music.starts, 0);
    await tester.tap(find.text("Let's go!"));
    await tester.pump();
    expect(music.starts, 1);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(music.pauses, 1);
    await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
    await tester.pump();
    expect(music.resumes, 1);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(music.pauses, 2);
    expect(find.text('Music'), findsOneWidget);
    await tester.tap(find.text('Music'));
    await tester.pump();
    expect(music.musicEnabled, false);
    expect(music.effectsEnabled, true);
    await tester.tap(find.text('Test sound'));
    await tester.pump();
    expect(music.sounds, contains(GameSound.upgrade));
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
    await tester.pump();
    expect(music.resumes, 2);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('Choose a district'));
    await tester.pump();
    expect(music.stops, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
