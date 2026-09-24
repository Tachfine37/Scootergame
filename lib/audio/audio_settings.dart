import 'package:flutter/material.dart';
import '../data/game_preferences.dart';
import 'game_music.dart';

class AudioSettings extends StatefulWidget {
  const AudioSettings({
    super.key,
    required this.preferences,
    required this.audio,
  });
  final GamePreferences preferences;
  final GameMusic audio;
  @override
  State<AudioSettings> createState() => _AudioSettingsState();
}

class _AudioSettingsState extends State<AudioSettings> {
  Future<void> _change(Future<void> save) async {
    setState(() {});
    final p = widget.preferences;
    await widget.audio.configure(
      music: p.music,
      effects: p.effects,
      musicVolume: p.musicVolume,
      effectsVolume: p.effectsVolume,
    );
    await save;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preferences;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sound settings',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Music'),
              subtitle: const Text('Urban funk · adaptive tempo'),
              value: p.music,
              onChanged: (v) => _change(p.setMusic(v)),
            ),
            Slider(
              value: p.musicVolume,
              divisions: 20,
              label: '${(p.musicVolume * 100).round()}%',
              semanticFormatterCallback: (v) =>
                  'Music volume ${(v * 100).round()} percent',
              onChanged: p.music ? (v) => _change(p.setMusicVolume(v)) : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound effects'),
              subtitle: const Text('Traffic, parcels, upgrades and police'),
              value: p.effects,
              onChanged: (v) => _change(p.setEffects(v)),
            ),
            Slider(
              value: p.effectsVolume,
              divisions: 20,
              label: '${(p.effectsVolume * 100).round()}%',
              semanticFormatterCallback: (v) =>
                  'Effects volume ${(v * 100).round()} percent',
              onChanged: p.effects
                  ? (v) => _change(p.setEffectsVolume(v))
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibrations'),
              value: p.haptics,
              onChanged: (v) => _change(p.setHaptics(v)),
            ),
            if (widget.audio.problem != null)
              Text(widget.audio.problem!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: p.effects && p.effectsVolume > 0
                      ? () async {
                          await widget.audio.effect(
                            GameSound.upgrade,
                            preview: true,
                          );
                          if (mounted) setState(() {});
                        }
                      : null,
                  child: const Text('Test sound'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Audio starts after you tap. Your settings are saved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
