import 'package:hive_flutter/hive_flutter.dart';

import '../models/tournament_models.dart';

class LocalTournamentStore {
  static const _boxName = 'drafttool_local_tournaments';

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  Future<List<DraftTournament>> loadAll() async {
    final box = await _box();
    final tournaments = box.values
        .map(DraftTournament.decode)
        .toList()
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
    return tournaments;
  }

  Future<DraftTournament?> load(String id) async {
    final box = await _box();
    final raw = box.get(id);
    return raw == null ? null : DraftTournament.decode(raw);
  }

  Future<void> save(DraftTournament tournament) async {
    final box = await _box();
    await box.put(tournament.id, tournament.encode());
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }
}
