import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/game_preferences.dart';
import 'game/delivery_game.dart';
import 'game/delivery_model.dart';

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
    _left = _right = false;
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
              _left = _right = false;
              game.steering = 0;
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
                    'LIVRAISON EXPRESS',
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
            top: 179 * scale,
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
                IgnorePointer(
                  child: Column(
                    children: [
                      Text(
                        'GARDE LE CAP',
                        style: TextStyle(
                          color: cream,
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(height: 3 * scale),
                      Text(
                        'Glisse pour conduire',
                        style: TextStyle(
                          color: cream.withValues(alpha: .8),
                          fontSize: 11 * scale,
                        ),
                      ),
                    ],
                  ),
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
          _pill(Icons.wb_sunny_outlined, 'LA TOURNÉE DU SOLEIL', s),
          const Spacer(),
          _pill(Icons.emoji_events_outlined, '${game.displayedRecord}', s),
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
            decoration: BoxDecoration(
              color: cream.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '30 secondes · Un doigt · Le plus de colis possible',
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
            'Glisse sur la route ou utilise les flèches ← →',
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
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: game.model.progress,
          minHeight: 4 * s,
          backgroundColor: pine.withValues(alpha: .15),
          color: pine,
        ),
      ),
    ],
  );

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
    final stars = model.cargo >= 15
        ? 3
        : model.cargo >= 7
        ? 2
        : model.cargo > 0
        ? 1
        : 0;
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
                    : model.cargo >= 15
                    ? 'Le quartier peut compter sur toi.'
                    : model.cargo >= 7
                    ? 'Bien joué. Tu en prends un de plus ?'
                    : 'La prochaine tournée sera la bonne.',
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
                paused ? 'Reprendre' : 'Encore une tournée',
                paused ? Icons.play_arrow_rounded : Icons.replay_rounded,
                () {
                  if (paused) {
                    game.resumeRun();
                    _focus.requestFocus();
                  } else {
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

