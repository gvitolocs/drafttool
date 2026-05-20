import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tournament_models.dart';
import '../services/local_tournament_store.dart';
import '../services/tournament_engine.dart';

final tournamentEngineProvider = Provider<TournamentEngine>((ref) {
  return TournamentEngine();
});

final localTournamentStoreProvider = Provider<LocalTournamentStore>((ref) {
  return LocalTournamentStore();
});

final localTournamentsProvider = FutureProvider<List<DraftTournament>>((ref) {
  return ref.watch(localTournamentStoreProvider).loadAll();
});

class LocalTournamentController extends Notifier<DraftTournament?> {
  @override
  DraftTournament? build() => null;

  Future<DraftTournament> create({
    required String title,
    required DraftGame game,
    required TournamentFormat format,
    required List<String> playerNames,
  }) async {
    final tournament = ref.read(tournamentEngineProvider).createOfflineTournament(
          title: title,
          game: game,
          format: format,
          playerNames: playerNames,
        );
    await ref.read(localTournamentStoreProvider).save(tournament);
    ref.invalidate(localTournamentsProvider);
    state = tournament;
    return tournament;
  }

  Future<void> select(DraftTournament tournament) async {
    state = tournament;
  }

  Future<void> startNextRound() async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = ref.read(tournamentEngineProvider).startNextRound(current);
    await _save(updated);
  }

  Future<void> recordResult({
    required String matchId,
    required MatchResult result,
  }) async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = ref.read(tournamentEngineProvider).recordResult(
          tournament: current,
          matchId: matchId,
          result: result,
        );
    await _save(updated);
  }

  Future<void> finalize() async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = ref.read(tournamentEngineProvider).finalizeTournament(current);
    await _save(updated);
  }

  Future<void> _save(DraftTournament tournament) async {
    await ref.read(localTournamentStoreProvider).save(tournament);
    ref.invalidate(localTournamentsProvider);
    state = tournament;
  }
}

final localTournamentControllerProvider =
    NotifierProvider<LocalTournamentController, DraftTournament?>(
  LocalTournamentController.new,
);
