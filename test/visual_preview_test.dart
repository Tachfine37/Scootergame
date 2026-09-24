import 'dart:io';
import 'dart:ui' as ui;

import 'package:ca_passe/data/game_preferences.dart';
import 'package:ca_passe/game/delivery_game.dart';
import 'package:ca_passe/game/delivery_model.dart';
import 'package:ca_passe/main.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Optional artifact export; normal test runs do not write screenshots.
// CA_PASSE_RENDER_DIR points to the desired output folder.
void main() {
  final output = Platform.environment['CA_PASSE_RENDER_DIR'];
  testWidgets('export actual Flutter welcome and gameplay frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontPath = Platform.environment['CA_PASSE_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('sans-serif');
      loader.addFont(
        Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
      );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: DeliveryApp(preferences: GamePreferences(null)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output!).create(recursive: true);
        await File(
          '$output/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('accueil-flutter');
    await tester.tap(find.text("Let's go!"));
    await tester.pump(const Duration(milliseconds: 100));
    final widget = tester.widget<GameWidget<DeliveryGame>>(
      find.byType(GameWidget<DeliveryGame>),
    );
    final game = widget.game!;
    game.model.cargo = 9;
    game.model.collected = 9;
    game.model.elapsed = 12;
    game.model.distance = 310;
    game.model.items
      ..clear()
      ..addAll([
        RoadItem(ItemKind.parcel, 0, 24),
        RoadItem(ItemKind.parcel, -.67, 58, variant: 1),
        RoadItem(ItemKind.car, -.67, 24),
        RoadItem(ItemKind.cone, .67, 16),
        RoadItem(ItemKind.bump, .67, 48),
      ]);
    game.hud.value++;
    await tester.pump(const Duration(milliseconds: 20));
    await capture('jeu-flutter');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: output == null);
}
