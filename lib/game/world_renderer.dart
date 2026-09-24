import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'delivery_model.dart';

/// Hand-painted geometry projected onto a road plane. No 3D runtime or assets.
class WorldRenderer {
  static const width = 430.0;
  static const height = 800.0;
  static const horizon = 260.0;
  static const ink = Color(0xff233f42);
  final Paint _paint = Paint()..isAntiAlias = true;
  late Canvas _canvas;
  double _distance = 0;
  double _clock = 0;
  int _stage = 0;

  double scaleAt(double z) => 28 / (z + 28);
  Offset project(double x, double z, [double elevation = 0]) {
    final scale = scaleAt(z);
    return Offset(
      width / 2 + x * 238 * scale,
      horizon + 570 * scale - elevation * scale,
    );
  }

  void render(
    Canvas canvas,
    Size size,
    DeliveryModel model, {
    required double clock,
    bool reduceMotion = false,
  }) {
    _canvas = canvas;
    _distance = model.distance;
    _clock = clock;
    _stage = model.stageIndex;
    canvas.save();
    canvas.scale(size.width / width, size.height / height);
    canvas.clipRect(const Rect.fromLTWH(0, 0, width, height));
    _sky();
    if (!reduceMotion && model.shake > 0) {
      canvas.translate(
        math.sin(clock * 75) * model.shake * 4,
        math.cos(clock * 63) * model.shake * 2,
      );
    }
    _road(model);
    // Roadside scenery and traffic share a back-to-front draw list.
    final draws = <({double z, void Function() draw})>[];
    for (var i = 0; i < 10; i++) {
      final z = i * 19.0 - (_distance % 19);
      if (z < -5) {
        continue;
      }
      final n = i + (_distance / 19).floor();
      for (final side in [-1.0, 1.0]) {
        if (_stage == 2) {
          draws.add((z: z, draw: () => _tree(side * 1.75, z)));
        } else if (_stage != 1 || side < 0) {
          draws.add((
            z: z,
            draw: () => _building(side, z, n + (side > 0 ? 2 : 0)),
          ));
        }
        if (n.isEven) {
          draws.add((z: z - 5, draw: () => _tree(side * 1.34, z - 5)));
        }
        if (n % 3 == 0) {
          draws.add((z: z - 8, draw: () => _lamp(side * 1.17, z - 8)));
        }
      }
    }
    for (final item in model.items) {
      if (item.z < 0 || item.z > 140) {
        continue;
      }
      draws.add((z: item.z, draw: () => _item(item)));
    }
    for (final crossing in model.crossings) {
      if (crossing.z < -5 || crossing.z > 160) continue;
      draws.add((z: crossing.z, draw: () => _trafficLight(crossing)));
      for (final car in crossing.cars) {
        draws.add((z: crossing.z, draw: () => _crossingCar(car, crossing.z)));
      }
    }
    draws.add((
      z: DeliveryModel.playerZ,
      draw: () => _scooter(model, reduceMotion),
    ));
    draws.sort((a, b) => b.z.compareTo(a.z));
    for (final entry in draws) {
      entry.draw();
    }
    for (final piece in model.flying) {
      final ground = project(0, DeliveryModel.playerZ);
      canvas.save();
      canvas.translate(ground.dx + piece.x, ground.dy - piece.height);
      canvas.rotate(piece.rotation);
      _parcel(0, 0, .75, piece.variant, alpha: piece.life.clamp(0, 1));
      canvas.restore();
    }
    if (model.phase == RunPhase.finished &&
        model.goalReached &&
        !reduceMotion) {
      for (var i = 0; i < 35; i++) {
        final px = (i * 73.0) % width;
        final py = (i * 47 + clock * (35 + i % 4 * 12)) % height;
        _round(
          px,
          py,
          5,
          10,
          2,
          [
            const Color(0xfff7c65f),
            const Color(0xffe78676),
            const Color(0xff73cbb0),
          ][i % 3],
        );
      }
    }
    // A subtle warm foreground vignette anchors the scooter in the scene.
    _paint.shader = ui.Gradient.linear(
      const Offset(0, 720),
      const Offset(0, 800),
      [const Color(0x00233f42), const Color(0x20233f42)],
    );
    canvas.drawRect(const Rect.fromLTWH(0, 720, width, 80), _paint);
    _paint.shader = null;
    canvas.restore();
  }

  void _sky() {
    _paint.shader = ui.Gradient.linear(Offset.zero, const Offset(0, 350), [
      [
        const Color(0xfface0df),
        const Color(0xff98dce9),
        const Color(0xffc1e1c8),
        const Color(0xffd5b2d5),
      ][_stage],
      [
        const Color(0xfff5ead0),
        const Color(0xfff8e9be),
        const Color(0xfff0edc5),
        const Color(0xffffc998),
      ][_stage],
    ]);
    _canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), _paint);
    _paint.shader = null;
    _oval(340, 175, 36, 36, const Color(0x28fff9db));
    _oval(
      340,
      _stage == 3 ? 222 : 175,
      _stage == 3 ? 34 : 25,
      _stage == 3 ? 34 : 25,
      const Color(0xffffefbc),
    );
    _cloud(77, 180, 1);
    _cloud(257, 142, .7);
    _path([
      const Offset(0, 247),
      const Offset(60, 215),
      const Offset(117, 243),
      const Offset(202, 216),
      const Offset(295, 239),
      const Offset(365, 208),
      const Offset(430, 239),
      const Offset(430, 300),
      const Offset(0, 300),
    ], const Color(0xff9fc5b2));
    for (var i = 0; i < (_stage == 2 ? 0 : 16); i++) {
      final bx = i * 30.0 - 20;
      final bh = 16.0 + (i * 17 % 31);
      _round(
        bx,
        265 - bh,
        24,
        bh,
        2,
        i.isEven ? const Color(0xffb0c9bb) : const Color(0xffc6d0b8),
      );
    }
  }

  void _cloud(double x, double y, double s) {
    const cloud = Color(0xaafffff0);
    _oval(x, y, 30 * s, 8 * s, cloud);
    _oval(x - 10 * s, y - 5 * s, 14 * s, 12 * s, cloud);
    _oval(x + 10 * s, y - 9 * s, 17 * s, 15 * s, cloud);
  }

  void _road(DeliveryModel model) {
    _rect(
      0,
      horizon,
      width,
      height - horizon,
      [
        const Color(0xffddceb0),
        const Color(0xffebd7a0),
        const Color(0xff9cbd7e),
        const Color(0xffc4a8aa),
      ][_stage],
    );
    if (_stage == 1) {
      _rect(250, horizon, 180, height - horizon, const Color(0xff65bbc4));
      for (var i = 0; i < 18; i++) {
        final y = horizon + 14 + i * 30.0;
        final dx = math.sin(_clock + i) * 9;
        _stroke(
          Offset(290 + dx, y),
          Offset(420 + dx, y),
          const Color(0x88e2f7ea),
          2,
        );
      }
      _path([
        const Offset(375, 291),
        const Offset(397, 291),
        const Offset(383, 300),
      ], ink);
      _path([
        const Offset(385, 289),
        const Offset(385, 265),
        const Offset(400, 289),
      ], const Color(0xffffefca));
    }
    _path([
      project(-1.22, 5000),
      project(1.22, 5000),
      project(1.22, -2),
      project(-1.22, -2),
    ], const Color(0xffefe1c4));
    _path([
      project(-1, 5000),
      project(1, 5000),
      project(1, -2),
      project(-1, -2),
    ], _stage == 3 ? const Color(0xff77778c) : const Color(0xff778a8c));
    for (var i = 0; i < 32; i++) {
      final z = i * 5.0 - (_distance % 5);
      if (z < 0) {
        continue;
      }
      final stripe = (i + (_distance / 5).floor()).isEven;
      for (final side in [-1.0, 1.0]) {
        _path([
          project(side, z),
          project(side * 1.065, z),
          project(side * 1.065, z + 5),
          project(side, z + 5),
        ], stripe ? const Color(0xfff4e7cb) : const Color(0xffb5bca9));
      }
      if (stripe) {
        for (final lane in [-.335, .335]) {
          _path([
            project(lane - .009, z),
            project(lane + .009, z),
            project(lane + .009, z + 2.4),
            project(lane - .009, z + 2.4),
          ], const Color(0xffd6d8c0));
        }
      }
    }
    // Periodic pedestrian crossings make motion and distance legible.
    final crossingZ = 125 - (_distance % 170);
    if (crossingZ > 0) {
      for (var i = 0; i < 9; i++) {
        final x = -.85 + i * .2;
        _path([
          project(x, crossingZ),
          project(x + .11, crossingZ),
          project(x + .11, crossingZ + 3),
          project(x, crossingZ + 3),
        ], const Color(0xffe8dfc5));
      }
    }
    for (final crossing in model.crossings) {
      if (crossing.z > -8 && crossing.z < 160) {
        _intersection(crossing.z);
      }
    }
    if (model.remaining < 4.5 && model.phase != RunPhase.ready) {
      final z = DeliveryModel.playerZ + model.remaining * model.speed;
      for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 12; col++) {
          final lx = -1 + col / 6;
          _path([
            project(lx, z + row * 1.7),
            project(lx + 1 / 6, z + row * 1.7),
            project(lx + 1 / 6, z + (row + 1) * 1.7),
            project(lx, z + (row + 1) * 1.7),
          ], (row + col).isEven ? const Color(0xfff9edcf) : ink);
        }
      }
    }
  }

  void _intersection(double z) {
    final asphalt = _stage == 3
        ? const Color(0xff686b80)
        : const Color(0xff657f80);
    _path([
      project(-3.8, z - 6),
      project(3.8, z - 6),
      project(3.8, z + 6),
      project(-3.8, z + 6),
    ], asphalt);
    for (final offset in [-2.6, 2.6]) {
      _path([
        project(-3.8, z + offset),
        project(3.8, z + offset),
        project(3.8, z + offset + .22),
        project(-3.8, z + offset + .22),
      ], const Color(0xffd7d6bd));
    }
    _path([
      project(-1, z - 9),
      project(1, z - 9),
      project(1, z - 8.2),
      project(-1, z - 8.2),
    ], const Color(0xfffff0cf));
  }

  void _trafficLight(RoadCrossing crossing) {
    final p = project(1.3, crossing.z);
    final s = scaleAt(crossing.z);
    _canvas.save();
    _canvas.translate(p.dx, p.dy);
    _canvas.scale(s);
    _stroke(const Offset(0, 0), const Offset(0, -162), ink, 8);
    _round(-22, -213, 44, 74, 9, ink);
    final red = crossing.phase == TrafficPhase.red;
    final amber = crossing.phase == TrafficPhase.amber;
    _oval(
      0,
      -194,
      12,
      12,
      red ? const Color(0xffff6657) : const Color(0xff785a51),
    );
    _oval(
      0,
      -176,
      10,
      10,
      amber ? const Color(0xffffce62) : const Color(0xff756c4d),
    );
    _oval(
      0,
      -156,
      12,
      12,
      crossing.phase == TrafficPhase.green
          ? const Color(0xff87d7a6)
          : const Color(0xff4b6b5a),
    );
    _canvas.restore();
  }

  void _crossingCar(CrossTrafficCar car, double z) {
    final p = project(car.x, z);
    final s = scaleAt(z);
    final color = [
      const Color(0xffe88c63),
      const Color(0xff739ec1),
      const Color(0xffd4b35f),
    ][car.variant % 3];
    _canvas.save();
    _canvas.translate(p.dx, p.dy);
    _canvas.scale(s);
    if (car.direction < 0) _canvas.scale(-1, 1);
    _oval(0, 2, 52, 12, const Color(0x55334444));
    _round(-42, -31, 84, 29, 8, color);
    _path([
      const Offset(-20, -31),
      const Offset(-9, -56),
      const Offset(22, -56),
      const Offset(35, -31),
    ], Color.lerp(color, const Color(0xffffedc9), .2)!);
    _path([
      const Offset(-13, -49),
      const Offset(17, -49),
      const Offset(28, -32),
      const Offset(-18, -32),
    ], const Color(0xff3c6970));
    _oval(-27, -2, 10, 10, ink);
    _oval(28, -2, 10, 10, ink);
    _round(33, -23, 9, 7, 2, const Color(0xffffe1aa));
    _canvas.restore();
  }

  void _building(double side, double z, int variant) {
    if (z < 0) {
      return;
    }
    final base = project(side * 1.62, z);
    final s = scaleAt(z);
    final w = (85 + (variant % 3) * 20) * s;
    final h = (135 + (variant % 4) * 23) * s;
    final d = 22 * s;
    final left = side < 0 ? base.dx - w : base.dx;
    final palette = [
      const Color(0xffe9b89b),
      const Color(0xffe9ce97),
      const Color(0xffadc4b0),
      const Color(0xffded5bd),
    ];
    final color = _stage == 3
        ? Color.lerp(palette[variant % 4], const Color(0xffab80a3), .35)!
        : palette[variant % 4];
    _path([
      Offset(left, base.dy),
      Offset(left + w, base.dy),
      Offset(left + w + 25 * s, base.dy + 9 * s),
      Offset(left + 25 * s, base.dy + 9 * s),
    ], const Color(0x18394e49));
    _rect(left, base.dy - h, w, h, color);
    _path([
      Offset(left + w, base.dy - h),
      Offset(left + w + d, base.dy - h - d * .7),
      Offset(left + w + d, base.dy - d * .7),
      Offset(left + w, base.dy),
    ], Color.lerp(color, ink, .15)!);
    _path([
      Offset(left, base.dy - h),
      Offset(left + d, base.dy - h - d * .7),
      Offset(left + w + d, base.dy - h - d * .7),
      Offset(left + w, base.dy - h),
    ], Color.lerp(color, const Color(0xfffff1d0), .35)!);
    _rect(left - 3 * s, base.dy - h, w + 6 * s, 6 * s, const Color(0xfff7e6c6));
    final rows = h / s > 170 ? 3 : 2;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < 2; col++) {
        final wx = left + (16 + col * 43) * s;
        final wy = base.dy - h + (18 + row * 35) * s;
        _round(
          wx,
          wy,
          21 * s,
          25 * s,
          3 * s,
          _stage == 3 ? const Color(0xffffd887) : const Color(0xff547978),
        );
        _rect(wx + 3 * s, wy + 3 * s, 7 * s, 18 * s, const Color(0xff83a6a1));
        _rect(wx - 2 * s, wy + 25 * s, 25 * s, 3 * s, const Color(0xfff6e2be));
      }
    }
    _round(
      left + 15 * s,
      base.dy - 45 * s,
      48 * s,
      45 * s,
      3 * s,
      const Color(0xff42685f),
    );
    _rect(
      left + 20 * s,
      base.dy - 39 * s,
      18 * s,
      27 * s,
      const Color(0xff9fc4b7),
    );
    final awning = variant.isEven
        ? const Color(0xffd97959)
        : const Color(0xff417b6b);
    _path([
      Offset(left + 8 * s, base.dy - 48 * s),
      Offset(left + 69 * s, base.dy - 48 * s),
      Offset(left + 75 * s, base.dy - 36 * s),
      Offset(left + 4 * s, base.dy - 36 * s),
    ], awning);
    for (var i = 0; i < 5; i++) {
      _rect(
        left + (6 + i * 14) * s,
        base.dy - 36 * s,
        7 * s,
        6 * s,
        const Color(0xfffae8c5),
      );
    }
    if (s > .3) {
      _label(
        variant.isEven ? 'CAFE' : 'FLOWERS',
        left + 39 * s,
        base.dy - 57 * s,
        9 * s,
        ink,
      );
    }
  }

  void _tree(double x, double z) {
    if (z < 0) {
      return;
    }
    final p = project(x, z);
    final s = scaleAt(z);
    if (_stage == 1) {
      _stroke(
        p,
        Offset(p.dx + 7 * s, p.dy - 108 * s),
        const Color(0xffa78656),
        7 * s,
      );
      for (var i = 0; i < 5; i++) {
        final angle = math.pi + i * math.pi / 4;
        final tip = Offset(
          p.dx + 7 * s + math.cos(angle) * 43 * s,
          p.dy - 100 * s + math.sin(angle) * 24 * s,
        );
        _path([
          Offset(p.dx + 7 * s, p.dy - 106 * s),
          tip,
          Offset(tip.dx, tip.dy + 13 * s),
        ], const Color(0xff3e8a71));
      }
      return;
    }
    _oval(p.dx + 12 * s, p.dy + 2 * s, 25 * s, 8 * s, const Color(0x23304f40));
    _round(
      p.dx - 4 * s,
      p.dy - 76 * s,
      8 * s,
      76 * s,
      2 * s,
      const Color(0xff907852),
    );
    _oval(p.dx, p.dy - 87 * s, 25 * s, 33 * s, const Color(0xff4e8164));
    _oval(p.dx - 8 * s, p.dy - 98 * s, 17 * s, 23 * s, const Color(0xff75a171));
    _oval(
      p.dx + 10 * s,
      p.dy - 82 * s,
      15 * s,
      23 * s,
      const Color(0xff3d735d),
    );
    _round(
      p.dx - 14 * s,
      p.dy - 8 * s,
      28 * s,
      12 * s,
      3 * s,
      const Color(0xffca9b73),
    );
  }

  void _lamp(double x, double z) {
    if (z < 0) {
      return;
    }
    final p = project(x, z);
    final s = scaleAt(z);
    if (_stage == 3) {
      _oval(
        p.dx - 15 * s,
        p.dy - 138 * s,
        27 * s,
        27 * s,
        const Color(0x44ffe6a1),
      );
    }
    _stroke(
      Offset(p.dx, p.dy),
      Offset(p.dx, p.dy - 135 * s),
      const Color(0xff527672),
      4 * s,
    );
    _stroke(
      Offset(p.dx, p.dy - 135 * s),
      Offset(p.dx - 16 * s, p.dy - 140 * s),
      const Color(0xff527672),
      4 * s,
    );
    _round(
      p.dx - 27 * s,
      p.dy - 143 * s,
      22 * s,
      7 * s,
      3 * s,
      const Color(0xff3b615c),
    );
    _round(
      p.dx - 24 * s,
      p.dy - 136 * s,
      16 * s,
      3 * s,
      1 * s,
      const Color(0xffffe5aa),
    );
  }

  void _item(RoadItem item) {
    final p = project(item.x, item.z);
    final s = scaleAt(item.z);
    _canvas.save();
    _canvas.translate(p.dx, p.dy);
    _canvas.scale(s);
    switch (item.kind) {
      case ItemKind.shield:
      case ItemKind.magnet:
        final color = item.kind == ItemKind.shield
            ? const Color(0xff4bafd0)
            : const Color(0xffc675b2);
        _oval(0, -25, 32, 32, color.withValues(alpha: .22));
        _oval(0, -25, 24, 24, color);
        _label(
          item.kind == ItemKind.shield ? 'S' : 'M',
          0,
          -26,
          25,
          const Color(0xfffff5dd),
        );
        _label(
          item.kind == ItemKind.shield ? 'SHIELD' : 'MAGNET',
          0,
          10,
          10,
          ink,
        );
      case ItemKind.parcel:
        _oval(3, 1, 26, 9, const Color(0x35364f42));
        final bob = math.sin(_clock * 4 + item.z * .1) * 3;
        _parcel(0, -7 + bob, 1, item.variant);
        if (item.z < 60) {
          _stroke(
            const Offset(-29, -34),
            const Offset(-23, -34),
            const Color(0xffffeab0),
            2,
          );
          _stroke(
            const Offset(28, -51),
            const Offset(28, -43),
            const Color(0xffffeab0),
            2,
          );
        }
      case ItemKind.cone:
        _oval(5, 2, 26, 10, const Color(0x30364f42));
        _path([
          const Offset(-26, -1),
          const Offset(-12, -9),
          const Offset(27, -3),
          const Offset(16, 7),
        ], const Color(0xffaa6649));
        _path([
          const Offset(0, -52),
          const Offset(-17, -3),
          const Offset(18, -3),
        ], const Color(0xffed9961));
        _path([
          const Offset(0, -52),
          const Offset(0, -3),
          const Offset(18, -3),
        ], const Color(0xffd77a4b));
        _path([
          const Offset(-8, -30),
          const Offset(8, -30),
          const Offset(12, -18),
          const Offset(-12, -18),
        ], const Color(0xffffedcc));
      case ItemKind.car:
        _car(item.variant);
      case ItemKind.bump:
        _oval(0, 2, 39, 9, const Color(0x30364f42));
        _round(-39, -9, 78, 15, 6, const Color(0xffe8b951));
        for (var i = 0; i < 4; i++) {
          _path([
            Offset(-32 + i * 19, -9),
            Offset(-25 + i * 19, -9),
            Offset(-17 + i * 19, 6),
            Offset(-24 + i * 19, 6),
          ], ink);
        }
    }
    _canvas.restore();
  }

  void _car(int variant) {
    final color = [
      const Color(0xffd9775d),
      const Color(0xff739ec1),
      const Color(0xffd9b568),
    ][variant % 3];
    _oval(6, 5, 46, 16, const Color(0x45344a45));
    _round(-38, -20, 13, 28, 5, ink);
    _round(25, -20, 13, 28, 5, ink);
    _path([
      const Offset(-34, -35),
      const Offset(-25, -91),
      const Offset(22, -91),
      const Offset(36, -35),
    ], Color.lerp(color, const Color(0xffffffff), .2)!);
    _round(-28, -80, 55, 47, 10, Color.lerp(color, ink, .1)!);
    _path([
      const Offset(-22, -72),
      const Offset(19, -72),
      const Offset(25, -47),
      const Offset(-27, -47),
    ], const Color(0xff385d64));
    _path([
      const Offset(-19, -69),
      const Offset(4, -69),
      const Offset(-7, -51),
      const Offset(-22, -51),
    ], const Color(0xff6c9798));
    _round(-37, -43, 74, 45, 10, color);
    _round(
      -29,
      -31,
      58,
      13,
      4,
      Color.lerp(color, const Color(0xfffce6c0), .13)!,
    );
    _round(-32, -17, 15, 8, 3, const Color(0xfff8c99b));
    _round(17, -17, 15, 8, 3, const Color(0xfff8c99b));
    _round(-12, -10, 24, 7, 2, const Color(0xfff2e8d0));
    _round(-31, -2, 62, 5, 2, const Color(0xff546a65));
    _round(-43, -49, 10, 7, 3, color);
    _round(33, -49, 10, 7, 3, color);
  }

  void _scooter(DeliveryModel model, bool reduceMotion) {
    final p = project(model.x, DeliveryModel.playerZ);
    final idle = model.phase == RunPhase.ready;
    final count = idle ? 3 : model.cargo;
    if (model.shield || model.magnetTime > 0) {
      _oval(
        p.dx,
        p.dy - 55,
        57,
        95,
        (model.shield ? const Color(0xff70dcf5) : const Color(0xffedb1e0))
            .withValues(alpha: .32),
      );
      _oval(p.dx, p.dy + 7, 51, 16, const Color(0x99e1fffb));
    }
    _oval(p.dx + 5, p.dy + 7, 35 + count * .4, 12, const Color(0x45354c44));
    _canvas.save();
    final bob = reduceMotion
        ? 0.0
        : math.sin(_clock * 20) * (model.running ? 1.1 : .3);
    _canvas.translate(p.dx, p.dy - model.hop + bob);
    _canvas.rotate((model.velocity * .035).clamp(-.13, .13));
    final flash = model.invulnerability > 0 && (_clock * 14).floor().isEven;
    if (flash) {
      _canvas.saveLayer(
        const Rect.fromLTWH(-90, -450, 180, 500),
        Paint()..color = const Color(0xafffffff),
      );
    }
    _round(-10, -32, 20, 44, 8, ink);
    _round(-6, -14, 12, 23, 4, const Color(0xff52615c));
    _stroke(const Offset(-30, -77), const Offset(-42, -110), ink, 3);
    _stroke(const Offset(30, -77), const Offset(42, -110), ink, 3);
    _oval(-43, -112, 9, 5, const Color(0xffc2e3d7));
    _oval(43, -112, 9, 5, const Color(0xffc2e3d7));
    _round(-32, -68, 64, 62, 24, const Color(0xfff0bf4e));
    _path([
      const Offset(-31, -38),
      const Offset(-20, -64),
      const Offset(20, -64),
      const Offset(31, -38),
    ], const Color(0xffffd96d));
    _round(-27, -47, 54, 44, 17, const Color(0xffe6a640));
    _round(-21, -27, 42, 23, 10, const Color(0xfff6c65d));
    _round(-15, -22, 30, 9, 4, const Color(0xffbc6552));
    _round(-11, -9, 22, 8, 2, const Color(0xffffedc7));
    _round(-31, -44, 9, 12, 3, const Color(0xfffaeac5));
    _round(22, -44, 9, 12, 3, const Color(0xfffaeac5));
    // Rider: jacket, sleeves and helmet, viewed from behind.
    _stroke(
      const Offset(-17, -97),
      const Offset(-33, -72),
      const Color(0xff386b62),
      12,
    );
    _stroke(
      const Offset(17, -97),
      const Offset(33, -72),
      const Color(0xff386b62),
      12,
    );
    _round(-21, -109, 42, 47, 13, const Color(0xff427e6e));
    _round(-4, -104, 8, 33, 3, const Color(0xff7eac86));
    _oval(0, -120, 20, 22, const Color(0xffffe9bd));
    _oval(-3, -124, 17, 17, const Color(0xffe78657));
    _path([
      const Offset(-5, -142),
      const Offset(2, -142),
      const Offset(5, -109),
      const Offset(-3, -109),
    ], const Color(0xffffd282));
    _round(-17, -112, 34, 6, 3, const Color(0xff314f4b));
    // A visible luggage rack ties the stack to the scooter.
    _round(-29, -63, 58, 7, 3, const Color(0xff2f5b54));
    // Keep the pile on screen while still adding a visible box past 15.
    final visible = math.min(count, 24);
    final spacing = visible <= 15 ? 15.0 : 210 / (visible - 1);
    for (var i = 0; i < visible; i++) {
      final sway = reduceMotion ? 0.0 : model.stackSway;
      _canvas.save();
      _canvas.translate(sway * (i + 1) * 7.5, -62 - i * spacing);
      _canvas.rotate(sway * (i + 1) * .012);
      _parcel(0, 0, .86 + (i % 3) * .035, i % 3);
      _canvas.restore();
    }
    if (count > visible) {
      _label(
        '×$count',
        0,
        -62 - (visible - 1) * spacing - 45,
        16,
        const Color(0xff264d41),
      );
    }
    if (flash) {
      _canvas.restore();
    }
    _canvas.restore();
  }

  void _parcel(double x, double y, double s, int variant, {double alpha = 1}) {
    final front = [
      const Color(0xffd8a165),
      const Color(0xffefc16f),
      const Color(0xffc68a68),
    ][variant % 3];
    final top = Color.lerp(front, const Color(0xffffedbc), .43)!;
    final side = Color.lerp(front, const Color(0xff764f3f), .25)!;
    Color a(Color c) => c.withValues(alpha: alpha);
    _canvas.save();
    _canvas.translate(x, y);
    _canvas.scale(s);
    _path([
      const Offset(-23, -30),
      const Offset(16, -30),
      const Offset(16, 0),
      const Offset(-23, 0),
    ], a(front));
    _path([
      const Offset(16, -30),
      const Offset(27, -40),
      const Offset(27, -10),
      const Offset(16, 0),
    ], a(side));
    _path([
      const Offset(-23, -30),
      const Offset(-12, -40),
      const Offset(27, -40),
      const Offset(16, -30),
    ], a(top));
    _rect(-7, -30, 8, 30, a(const Color(0xfff8dfa6)));
    _path([
      const Offset(-7, -30),
      const Offset(4, -40),
      const Offset(12, -40),
      const Offset(1, -30),
    ], a(const Color(0xffffedc1)));
    _round(5, -23, 8, 11, 1, a(const Color(0xfff6e7c8)));
    _stroke(
      const Offset(7, -19),
      const Offset(11, -19),
      a(const Color(0xffb89366)),
      1,
    );
    _stroke(
      const Offset(-18, -7),
      const Offset(-13, -7),
      a(const Color(0xffa57449)),
      1.5,
    );
    _canvas.restore();
  }

  void _label(String text, double x, double y, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      _canvas,
      Offset(x - painter.width / 2, y - painter.height / 2),
    );
  }

  void _rect(double x, double y, double w, double h, Color c) {
    _paint.color = c;
    _canvas.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _round(double x, double y, double w, double h, double radius, Color c) {
    _paint.color = c;
    _canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      _paint,
    );
  }

  void _oval(double x, double y, double rx, double ry, Color c) {
    _paint.color = c;
    _canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
      _paint,
    );
  }

  void _path(List<Offset> points, Color c) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    _paint.color = c;
    _canvas.drawPath(path, _paint);
  }

  void _stroke(Offset a, Offset b, Color c, double w) {
    _paint
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    _canvas.drawLine(a, b, _paint);
  }
}
