import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/game_preferences.dart';
import 'game/delivery_game.dart';
import 'game/delivery_model.dart';
import 'game/stages.dart';

const pine = Color(0xff234e43);
const cream = Color(0xfffff5dd);
const coral = Color(0xffde7b55);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SharedPreferences? storage;
  try {
    storage = await SharedPreferences.getInstance();
  } catch (_) {}
  runApp(DeliveryApp(preferences: GamePreferences(storage)));
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key, required this.preferences});
  final GamePreferences preferences;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ça passe !',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: pine),
      scaffoldBackgroundColor: const Color(0xff193e37),
      fontFamily: 'sans-serif',
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: pine,
        displayColor: pine,
      ),
    ),
    home: DeliveryScreen(preferences: preferences),
  );
}

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, required this.preferences});
  final GamePreferences preferences;
  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with WidgetsBindingObserver {
  late final DeliveryGame game;
  final _focus = FocusNode(debugLabel: 'delivery-controls');
  bool _left = false;
  bool _right = false;
  bool _brake = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = DeliveryGame(widget.preferences);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && game.model.running) {
      game.pauseRun();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is! KeyUpEvent;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      _left = down;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      _right = down;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyS) {
      _brake = down;
      game.setBraking(_brake);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (game.model.running) {
          game.pauseRun();
        } else if (game.model.phase == RunPhase.paused) {
          game.resumeRun();
        } else {
          _start();
        }
      }
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    game.steering = (_right ? 1 : 0) - (_left ? 1 : 0);
    return KeyEventResult.handled;
  }

  void _start() {
    _left = _right = _brake = false;
    game.startRun();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    game.reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          onFocusChange: (focused) {
            if (!focused) {
              _left = _right = _brake = false;
              game.steering = 0;
              game.setBraking(false);
            }
          },
          child: LayoutBuilder(
            builder: (context, viewport) {
              final width = math.min(
                viewport.maxWidth,
                viewport.maxHeight * 430 / 800,
              );
              final height = width * 800 / 430;
              return Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      viewport.maxWidth > 600 ? 28 : 0,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final uiScale = (constraints.maxWidth / 430).clamp(
                          .65,
                          1.5,
                        );
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Listener(
                                onPointerDown: (event) {
                                  _focus.requestFocus();
                                  game.steerAt(event.localPosition.dx);
                                },
                                onPointerMove: (event) =>
                                    game.steerAt(event.localPosition.dx),
                                child: Semantics(
                                  label:
                                      'Route en perspective. Glissez à gauche ou à droite pour diriger le scooter.',
                                  child: GameWidget(game: game),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: ListenableBuilder(
                                listenable: game.hud,
                                builder: (context, _) => _interface(uiScale),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _interface(double scale) {
    final model = game.model;
    final ready = model.phase == RunPhase.ready;
    return Stack(
      children: [
        Positioned(
          top: 22 * scale,
          left: 22 * scale,
          right: 22 * scale,
          child: Row(
            children: [
              Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(
                  color: pine,
                  borderRadius: BorderRadius.circular(13 * scale),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: cream,
                  size: 23 * scale,
                ),
              ),
              SizedBox(width: 10 * scale),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ÇA PASSE !',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20 * scale,
                      letterSpacing: -.8,
                    ),
                  ),
                  Text(
                    '${model.stageIndex + 1} / 4 · ${model.stage.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 9 * scale,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w700,
                      color: pine.withValues(alpha: .65),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!ready && model.phase != RunPhase.finished)
                _iconButton(
                  model.phase == RunPhase.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  model.phase == RunPhase.paused ? 'Reprendre' : 'Pause',
                  () {
                    if (model.phase == RunPhase.paused) {
                      game.resumeRun();
                    } else {
                      game.pauseRun();
                    }
                  },
                  scale,
                )
              else
                _iconButton(
                  widget.preferences.haptics
                      ? Icons.vibration_rounded
                      : Icons.phone_android_rounded,
                  widget.preferences.haptics
                      ? 'Désactiver les vibrations'
                      : 'Activer les vibrations',
                  () async {
                    await widget.preferences.setHaptics(
                      !widget.preferences.haptics,
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  scale,
                ),
            ],
          ),
        ),
        if (ready) ..._welcome(scale),
        if (!ready)
          Positioned(
            top: 83 * scale,
            left: 20 * scale,
            right: 20 * scale,
            child: _hud(scale),
          ),
        if (model.running) ...[
          Positioned(
            top: 272 * scale,
            left: 20 * scale,
            right: 20 * scale,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: model.eventTime > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16 * scale,
                      vertical: 9 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      model.message,
                      style: TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w800,
                        color: pine,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 21 * scale,
            left: 20 * scale,
            right: 20 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _steerButton(-1, scale),
                Column(
                  children: [
                    Text(
                      model.cargo >= 6
                          ? model.balanceStress > .5
                                ? 'PILE INSTABLE'
                                : 'VIRAGES DOUX'
                          : 'GARDE LE CAP',
                      style: TextStyle(
                        color: cream,
                        fontSize: 9 * scale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    _brakeButton(scale),
                  ],
                ),
                _steerButton(1, scale),
              ],
            ),
          ),
        ],
        if (model.phase == RunPhase.paused) _modal(scale, paused: true),
        if (model.phase == RunPhase.finished) _modal(scale, paused: false),
      ],
    );
  }

  List<Widget> _welcome(double s) => [
    Positioned(
      top: 99 * s,
      left: 22 * s,
      right: 22 * s,
      child: Row(
        children: [
          _pill(Icons.map_outlined, game.model.stage.subtitle.toUpperCase(), s),
          const Spacer(),
          _pill(Icons.star_rounded, '${widget.preferences.totalStars}/12', s),
        ],
      ),
    ),
    Positioned(
      top: 159 * s,
      left: 26 * s,
      right: 26 * s,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encore\nun colis ?',
              style: TextStyle(
                fontSize: 58 * s,
                height: .96,
                letterSpacing: -3 * s,
                fontWeight: FontWeight.w900,
                color: pine,
              ),
            ),
            SizedBox(height: 17 * s),
            Text(
              'Une pile trop haute.\nUne livraison à assurer.',
              style: TextStyle(
                fontSize: 15 * s,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: pine.withValues(alpha: .8),
              ),
            ),
          ],
        ),
      ),
    ),
    Positioned(
      bottom: 23 * s,
      left: 25 * s,
      right: 25 * s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stagePicker(s),
          SizedBox(height: 12 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
            decoration: BoxDecoration(
              color: cream.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${game.model.stage.seconds.toInt()} s · Objectif : ${game.model.stage.goal} colis livrés',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11 * s,
                fontWeight: FontWeight.w700,
                color: pine,
              ),
            ),
          ),
          SizedBox(height: 12 * s),
          _primaryButton('C’est parti', Icons.arrow_forward_rounded, _start, s),
          SizedBox(height: 10 * s),
          Text(
            'Flèches ← → pour conduire · FREIN au feu rouge',
            style: TextStyle(
              color: cream,
              fontSize: 11 * s,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  ];

  Widget _stagePicker(double s) => Container(
    padding: EdgeInsets.all(12 * s),
    decoration: BoxDecoration(
      color: cream.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(20 * s),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CHOISIS TON QUARTIER',
          style: TextStyle(
            fontSize: 10 * s,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: pine,
          ),
        ),
        SizedBox(height: 8 * s),
        Row(
          children: List.generate(deliveryStages.length, (i) {
            final selected = game.model.stageIndex == i;
            const icons = [
              Icons.storefront_rounded,
              Icons.waves_rounded,
              Icons.park_rounded,
              Icons.wb_twilight_rounded,
            ];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  selected: selected,
                  child: TextButton(
                    onPressed: () => game.selectStage(i),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10 * s),
                      minimumSize: const Size(44, 44),
                      backgroundColor: selected
                          ? pine
                          : pine.withValues(alpha: .06),
                      foregroundColor: selected ? cream : pine,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[i], size: 23 * s),
                        SizedBox(height: 5 * s),
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14 * s,
                          ),
                        ),
                        Text(
                          '${widget.preferences.stageStars(i)} ★',
                          style: TextStyle(fontSize: 11 * s),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 6 * s),
        Text(
          game.model.stage.name,
          style: TextStyle(
            fontSize: 16 * s,
            fontWeight: FontWeight.w900,
            color: pine,
          ),
        ),
        Text(
          '1 ★ ${game.model.stage.goal}  ·  2 ★ ${game.model.stage.twoStars}  ·  3 ★ ${game.model.stage.threeStars} colis',
          style: TextStyle(fontSize: 11 * s, color: pine),
        ),
      ],
    ),
  );

  Widget _hud(double s) => Column(
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 13 * s),
        decoration: BoxDecoration(
          color: cream.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(20 * s),
          boxShadow: [
            BoxShadow(
              color: pine.withValues(alpha: .07),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _metric(
              'À BORD',
              '${game.model.cargo}',
              Icons.inventory_2_outlined,
              s,
            ),
            _metric(
              'ARRIVÉE',
              '${game.model.remaining.ceil()} s',
              Icons.timer_outlined,
              s,
            ),
            _metric(
              'RECORD',
              '${game.displayedRecord}',
              Icons.emoji_events_outlined,
              s,
            ),
          ],
        ),
      ),
      SizedBox(height: 10 * s),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 5 * s),
        decoration: BoxDecoration(
          color: cream.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              game.model.goalReached
                  ? Icons.check_circle_rounded
                  : Icons.flag_rounded,
              size: 16 * s,
              color: pine,
            ),
            SizedBox(width: 6 * s),
            Expanded(
              child: Text(
                'Objectif ${game.model.cargo}/${game.model.stage.goal} colis',
                style: TextStyle(
                  fontSize: 12 * s,
                  color: pine,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${game.model.streak} à la suite',
              style: TextStyle(fontSize: 11 * s, color: pine),
            ),
          ],
        ),
      ),
      SizedBox(height: 6 * s),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: game.model.progress,
          minHeight: 4 * s,
          backgroundColor: pine.withValues(alpha: .15),
          color: pine,
        ),
      ),
      if (game.model.cargo >= 6) ...[
        SizedBox(height: 5 * s),
        Row(
          children: [
            Text(
              'ÉQUILIBRE',
              style: TextStyle(
                fontSize: 9 * s,
                fontWeight: FontWeight.w800,
                color: cream,
              ),
            ),
            SizedBox(width: 8 * s),
            Expanded(
              child: LinearProgressIndicator(
                value: (game.model.balanceStress / .85).clamp(0.0, 1.0),
                minHeight: 5 * s,
                backgroundColor: cream.withValues(alpha: .4),
                color: coral,
              ),
            ),
          ],
        ),
      ],
      if (game.model.upcomingCrossing != null &&
          game.model.upcomingCrossing!.z < 100)
        _trafficStatus(game.model.upcomingCrossing!, s),
    ],
  );

  Widget _trafficStatus(RoadCrossing crossing, double s) {
    final phase = crossing.phase;
    final lightColor = phase == TrafficPhase.red
        ? const Color(0xffee6856)
        : phase == TrafficPhase.amber
        ? const Color(0xffffc45a)
        : const Color(0xff7ad29a);
    final text = phase == TrafficPhase.red
        ? 'FEU ROUGE · MAINTIENS FREIN'
        : phase == TrafficPhase.amber
        ? 'FEU ORANGE · FREINE !'
        : 'FEU VERT · RESTE VIGILANT';
    return Container(
      margin: EdgeInsets.only(top: 8 * s),
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
      decoration: BoxDecoration(
        color: pine.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(12 * s),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.traffic_rounded, color: lightColor, size: 17 * s),
          SizedBox(width: 7 * s),
          Text(
            text,
            style: TextStyle(
              color: cream,
              fontSize: 10 * s,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon, double s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 9 * s,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: pine.withValues(alpha: .6),
        ),
      ),
      SizedBox(height: 4 * s),
      Row(
        children: [
          Icon(icon, size: 17 * s, color: coral),
          SizedBox(width: 6 * s),
          Text(
            value,
            style: TextStyle(
              fontSize: 25 * s,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: pine,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _modal(double s, {required bool paused}) {
    final model = game.model;
    final newRecord = model.cargo > game.recordAtStart;
    final stars = model.stars;
    final nextStage =
        !paused &&
        model.goalReached &&
        model.stageIndex < deliveryStages.length - 1;
    return Positioned.fill(
      child: Container(
        color: pine.withValues(alpha: .35),
        alignment: Alignment.center,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 26 * s),
          padding: EdgeInsets.all(25 * s),
          decoration: BoxDecoration(
            color: cream,
            borderRadius: BorderRadius.circular(28 * s),
            boxShadow: [
              BoxShadow(
                color: pine.withValues(alpha: .2),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                paused ? Icons.local_cafe_rounded : Icons.task_alt_rounded,
                size: 40 * s,
                color: coral,
              ),
              SizedBox(height: 14 * s),
              Text(
                paused
                    ? 'PETITE PAUSE'
                    : newRecord
                    ? 'NOUVEAU RECORD'
                    : 'TOURNÉE TERMINÉE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10 * s,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w800,
                  color: pine.withValues(alpha: .6),
                ),
              ),
              SizedBox(height: 9 * s),
              Text(
                paused ? 'On souffle ?' : '${model.cargo} colis\nlivrés !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 39 * s,
                  height: 1.02,
                  letterSpacing: -1.5,
                  fontWeight: FontWeight.w900,
                  color: pine,
                ),
              ),
              SizedBox(height: 13 * s),
              if (!paused)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        index < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: index < stars
                            ? const Color(0xffdd9b37)
                            : const Color(0xffc4c6aa),
                        size: 31 * s,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 10 * s),
              Text(
                paused
                    ? 'Ta pile est en sécurité.'
                    : model.goalReached
                    ? '${model.stage.name} : mission réussie !'
                    : 'Encore ${model.stage.goal - model.cargo} colis pour la première étoile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13 * s,
                  height: 1.45,
                  color: pine.withValues(alpha: .75),
                ),
              ),
              if (!paused) ...[
                SizedBox(height: 21 * s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _resultStat('Ramassés', model.collected, s),
                    _resultStat('Perdus', model.lost, s),
                    _resultStat('Record', game.displayedRecord, s),
                  ],
                ),
              ],
              SizedBox(height: 24 * s),
              _primaryButton(
                paused
                    ? 'Reprendre'
                    : nextStage
                    ? 'Quartier suivant'
                    : 'Encore une tournée',
                paused
                    ? Icons.play_arrow_rounded
                    : nextStage
                    ? Icons.arrow_forward_rounded
                    : Icons.replay_rounded,
                () {
                  if (paused) {
                    game.resumeRun();
                    _focus.requestFocus();
                  } else {
                    if (nextStage) game.selectStage(model.stageIndex + 1);
                    _start();
                  }
                },
                s,
              ),
              if (paused)
                Padding(
                  padding: EdgeInsets.only(top: 6 * s),
                  child: TextButton(
                    onPressed: _start,
                    child: const Text('Recommencer la tournée'),
                  ),
                ),
              if (!paused && nextStage)
                TextButton(
                  onPressed: _start,
                  child: const Text('Rejouer pour 3 étoiles'),
                ),
              TextButton(
                onPressed: () {
                  _left = _right = false;
                  game.selectStage(model.stageIndex);
                },
                child: const Text('Choisir un quartier'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultStat(String label, int value, double s) => Column(
    children: [
      Text(
        '$value',
        style: TextStyle(
          fontSize: 23 * s,
          fontWeight: FontWeight.w900,
          color: pine,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 11 * s, color: pine.withValues(alpha: .65)),
      ),
    ],
  );

  Widget _primaryButton(
    String label,
    IconData icon,
    VoidCallback action,
    double s,
  ) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: action,
      style: FilledButton.styleFrom(
        backgroundColor: pine,
        foregroundColor: cream,
        padding: EdgeInsets.symmetric(vertical: 18 * s, horizontal: 17 * s),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18 * s),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w800),
          ),
          SizedBox(width: 12 * s),
          Icon(icon, size: 21 * s),
        ],
      ),
    ),
  );

  Widget _iconButton(
    IconData icon,
    String tooltip,
    VoidCallback action,
    double s,
  ) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: action,
    style: IconButton.styleFrom(
      backgroundColor: cream.withValues(alpha: .85),
      foregroundColor: pine,
      minimumSize: const Size(44, 44),
    ),
    icon: Icon(icon, size: 21 * s),
  );

  Widget _pill(IconData icon, String text, double s) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
    decoration: BoxDecoration(
      color: cream.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: pine, size: 14 * s),
        SizedBox(width: 6 * s),
        Text(
          text,
          style: TextStyle(
            color: pine,
            fontSize: 9 * s,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ],
    ),
  );

  Widget _brakeButton(double s) => Listener(
    onPointerDown: (_) => game.setBraking(true),
    onPointerUp: (_) => game.setBraking(false),
    onPointerCancel: (_) => game.setBraking(false),
    child: Semantics(
      button: true,
      label: 'Maintenir pour freiner',
      onTap: () => game.setBraking(!game.model.braking),
      child: Container(
        width: math.max(78, 110 * s),
        height: math.max(44, 49 * s),
        decoration: BoxDecoration(
          color: game.model.braking ? coral : cream.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(16 * s),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.stop_rounded,
              color: game.model.braking ? cream : pine,
              size: 21 * s,
            ),
            SizedBox(width: 3 * s),
            Text(
              'FREIN',
              style: TextStyle(
                color: game.model.braking ? cream : pine,
                fontSize: 12 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _steerButton(int direction, double s) => Listener(
    onPointerDown: (_) {
      game.steering = direction;
    },
    onPointerUp: (_) {
      game.steering = 0;
    },
    onPointerCancel: (_) {
      game.steering = 0;
    },
    child: Semantics(
      label: direction < 0 ? 'Conduire à gauche' : 'Conduire à droite',
      button: true,
      child: IconButton.filled(
        onPressed: () => game.nudge(direction),
        style: IconButton.styleFrom(
          backgroundColor: cream.withValues(alpha: .92),
          foregroundColor: pine,
          fixedSize: Size(math.max(48, 58 * s), math.max(44, 49 * s)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * s),
          ),
        ),
        icon: Icon(
          direction < 0
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          size: 25 * s,
        ),
      ),
    ),
  );
}
