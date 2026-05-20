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
    final engine = ref.read(tournamentEngineProvider);
    final tournament = engine.startNextRound(
      engine.createOfflineTournament(
        title: title,
        game: game,
        format: format,
        playerNames: playerNames,
      ),
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
    final updated = ref
        .read(tournamentEngineProvider)
        .startNextRound(current.copyWith(autoAdvancePaused: false));
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
    var updated = ref
        .read(tournamentEngineProvider)
        .recordResult(tournament: current, matchId: matchId, result: result);
    if (!updated.autoAdvancePaused &&
        !updated.config.format.hasTopCut &&
        updated.rounds.isNotEmpty &&
        updated.rounds.last.isComplete) {
      updated = ref.read(tournamentEngineProvider).startNextRound(updated);
    }
    await _save(updated);
  }

  Future<void> goBackRound() async {
    final current = state;
    if (current == null ||
        current.phase != TournamentPhase.swiss ||
        current.rounds.length <= 1) {
      return;
    }
    final previousRounds = current.rounds
        .take(current.rounds.length - 1)
        .toList();
    final targetRound = previousRounds.last;
    previousRounds[previousRounds.length - 1] = targetRound.copyWith(
      finalized: false,
    );
    final updated = current.copyWith(
      rounds: previousRounds,
      status: TournamentStatus.active,
      autoAdvancePaused: true,
      updatedAt: DateTime.now(),
    );
    await _save(updated);
  }

  Future<void> dropPlayer(String playerId) async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = ref
        .read(tournamentEngineProvider)
        .dropPlayer(tournament: current, playerId: playerId);
    await _save(updated);
  }

  Future<void> recordTopCutResult({
    required String matchId,
    required MatchResult result,
  }) async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = ref
        .read(tournamentEngineProvider)
        .recordTopCutResult(
          tournament: current,
          matchId: matchId,
          result: result,
        );
    await _save(updated);
  }

  Future<void> finalize() async {
    var current = state;
    if (current == null) {
      return;
    }
    if (current.rounds.length > 1 &&
        current.rounds.last.matches.every(
          (match) => match.isBye || !match.result.isComplete,
        )) {
      current = current.copyWith(
        rounds: current.rounds.take(current.rounds.length - 1).toList(),
        autoAdvancePaused: true,
        updatedAt: DateTime.now(),
      );
    }
    final updated = ref
        .read(tournamentEngineProvider)
        .finalizeTournament(current);
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
