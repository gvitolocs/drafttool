import 'package:shared_preferences/shared_preferences.dart';

import '../models/tournament_models.dart';

class DraftFormSnapshot {
  const DraftFormSnapshot({
    required this.title,
    required this.game,
    required this.format,
    required this.players,
    required this.touchedPlayers,
  });

  final String title;
  final DraftGame game;
  final TournamentFormat format;
  final List<String> players;
  final List<bool> touchedPlayers;
}

class DraftFormStore {
  static const _titleKey = 'drafttool_form_title';
  static const _gameKey = 'drafttool_form_game';
  static const _formatKey = 'drafttool_form_format';
  static const _playersKey = 'drafttool_form_players';
  static const _touchedKey = 'drafttool_form_touched_players';

  Future<DraftFormSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final players =
        prefs.getStringList(_playersKey) ??
        const ['Pikachu', 'Squirtle', 'Bulbasaur', 'Charmander'];
    final touched =
        prefs
            .getStringList(_touchedKey)
            ?.map((value) => value == '1')
            .toList() ??
        List<bool>.filled(players.length, false);
    return DraftFormSnapshot(
      title: prefs.getString(_titleKey) ?? defaultTitle(),
      game: DraftGame.values.byName(
        prefs.getString(_gameKey) ?? DraftGame.pokemon.name,
      ),
      format: TournamentFormat.values.byName(
        prefs.getString(_formatKey) ?? TournamentFormat.bestOfOneTopCut.name,
      ),
      players: players,
      touchedPlayers: [
        for (var i = 0; i < players.length; i += 1)
          i < touched.length ? touched[i] : false,
      ],
    );
  }

  Future<void> save(DraftFormSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleKey, snapshot.title);
    await prefs.setString(_gameKey, snapshot.game.name);
    await prefs.setString(_formatKey, snapshot.format.name);
    await prefs.setStringList(_playersKey, snapshot.players);
    await prefs.setStringList(
      _touchedKey,
      snapshot.touchedPlayers.map((value) => value ? '1' : '0').toList(),
    );
  }

  static String defaultTitle() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return "${weekdays[now.weekday - 1]}'s draft";
  }
}
