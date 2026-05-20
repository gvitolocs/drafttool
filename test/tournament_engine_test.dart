import 'package:flutter_test/flutter_test.dart';

import 'package:drafttool/models/tournament_models.dart';
import 'package:drafttool/services/tournament_engine.dart';

void main() {
  group('TournamentEngine', () {
    test('creates Swiss pairings and avoids repeated opponents', () {
      final engine = TournamentEngine();
      var tournament = engine.createOfflineTournament(
        title: 'Test event',
        game: DraftGame.pokemon,
        format: TournamentFormat.bestOfThree,
        playerNames: ['Alice', 'Bob', 'Charlie', 'Dana'],
      );

      tournament = engine.startNextRound(tournament);
      expect(tournament.rounds.single.matches, hasLength(2));
      final firstRoundPairs = tournament.rounds.single.matches
          .map((match) => {match.playerAId, match.playerBId})
          .toList();

      for (final match in tournament.rounds.single.matches) {
        tournament = engine.recordResult(
          tournament: tournament,
          matchId: match.id,
          result: const MatchResult(
            outcome: MatchOutcome.playerA,
            playerAWins: 2,
          ),
        );
      }
      tournament = engine.startNextRound(tournament);
      final secondRoundPairs = tournament.rounds.last.matches
          .map((match) => {match.playerAId, match.playerBId})
          .toList();

      for (final pair in secondRoundPairs) {
        expect(firstRoundPairs, isNot(contains(pair)));
      }
    });

    test('assigns only one bye per odd-player round', () {
      final engine = TournamentEngine();
      final tournament = engine.startNextRound(
        engine.createOfflineTournament(
          title: 'Odd event',
          game: DraftGame.magic,
          format: TournamentFormat.bestOfOne,
          playerNames: ['A', 'B', 'C', 'D', 'E'],
        ),
      );

      expect(
        tournament.rounds.single.matches.where((m) => m.isBye),
        hasLength(1),
      );
      expect(
        tournament.rounds.single.matches
            .singleWhere((m) => m.isBye)
            .result
            .outcome,
        MatchOutcome.bye,
      );
    });

    test('sorts standings by match points and game record', () {
      final engine = TournamentEngine();
      var tournament = engine.startNextRound(
        engine.createOfflineTournament(
          title: 'Standings event',
          game: DraftGame.yugioh,
          format: TournamentFormat.bestOfThree,
          playerNames: ['A', 'B', 'C', 'D'],
        ),
      );

      final matches = tournament.rounds.single.matches;
      tournament = engine.recordResult(
        tournament: tournament,
        matchId: matches[0].id,
        result: const MatchResult(
          outcome: MatchOutcome.playerA,
          playerAWins: 2,
        ),
      );
      tournament = engine.recordResult(
        tournament: tournament,
        matchId: matches[1].id,
        result: const MatchResult(
          outcome: MatchOutcome.draw,
          playerAWins: 1,
          playerBWins: 1,
          draws: 1,
        ),
      );

      final standings = engine.calculateStandings(tournament);
      expect(standings.first.matchPoints, 3);
      expect(standings[1].matchPoints, 1);
      expect(standings.last.matchPoints, 0);
    });

    test('serializes and restores tournaments', () {
      final engine = TournamentEngine();
      final tournament = engine.createOfflineTournament(
        title: 'Serialize',
        game: DraftGame.pokemon,
        format: TournamentFormat.bestOfThreeTopCut,
        playerNames: ['A', 'B'],
      );

      final restored = DraftTournament.decode(tournament.encode());
      expect(restored.id, tournament.id);
      expect(restored.config.format, TournamentFormat.bestOfThreeTopCut);
      expect(restored.players.map((p) => p.name), ['A', 'B']);
    });

    test('builds top cut from final standings', () {
      final engine = TournamentEngine();
      final tournament = engine.createOfflineTournament(
        title: 'Top cut',
        game: DraftGame.pokemon,
        format: TournamentFormat.bestOfOneTopCut,
        playerNames: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
      );

      final topCut = engine.buildTopCut(tournament, size: 8);
      expect(topCut, hasLength(4));
      expect(topCut.first.playerAId, 'player-1');
      expect(topCut.first.playerBId, 'player-8');
    });

    test(
      'top cut formats move from Swiss into playable elimination rounds',
      () {
        final engine = TournamentEngine();
        var tournament = engine.startNextRound(
          engine.createOfflineTournament(
            title: 'Playable cut',
            game: DraftGame.pokemon,
            format: TournamentFormat.bestOfOneTopCut,
            playerNames: ['A', 'B', 'C', 'D'],
          ),
        );

        for (final match in tournament.rounds.single.matches) {
          tournament = engine.recordResult(
            tournament: tournament,
            matchId: match.id,
            result: const MatchResult(
              outcome: MatchOutcome.playerA,
              playerAWins: 1,
            ),
          );
        }

        tournament = engine.finalizeTournament(tournament);
        expect(tournament.status, TournamentStatus.active);
        expect(tournament.phase, TournamentPhase.topCut);
        expect(tournament.topCutRounds.single.matches, hasLength(2));

        for (final match in tournament.topCutRounds.single.matches) {
          tournament = engine.recordTopCutResult(
            tournament: tournament,
            matchId: match.id,
            result: const MatchResult(
              outcome: MatchOutcome.playerA,
              playerAWins: 1,
            ),
          );
        }

        expect(tournament.status, TournamentStatus.active);
        expect(tournament.topCutRounds, hasLength(2));
        expect(tournament.topCutRounds.last.label, 'Final');

        final finalMatch = tournament.topCutRounds.last.matches.single;
        tournament = engine.recordTopCutResult(
          tournament: tournament,
          matchId: finalMatch.id,
          result: const MatchResult(
            outcome: MatchOutcome.playerA,
            playerAWins: 1,
          ),
        );

        expect(tournament.status, TournamentStatus.finalized);
      },
    );

    test('dropped players are not paired in future Swiss rounds', () {
      final engine = TournamentEngine();
      var tournament = engine.startNextRound(
        engine.createOfflineTournament(
          title: 'Drop event',
          game: DraftGame.pokemon,
          format: TournamentFormat.bestOfOneTopCut,
          playerNames: ['A', 'B', 'C', 'D'],
        ),
      );
      final droppedId = tournament.rounds.single.matches.first.playerAId;
      tournament = engine.dropPlayer(
        tournament: tournament,
        playerId: droppedId,
      );

      for (final match in tournament.rounds.single.matches) {
        tournament = engine.recordResult(
          tournament: tournament,
          matchId: match.id,
          result: const MatchResult(
            outcome: MatchOutcome.playerA,
            playerAWins: 1,
          ),
        );
      }

      tournament = engine.startNextRound(tournament);
      expect(
        tournament.rounds.last.matches.expand(
          (match) => [
            match.playerAId,
            if (match.playerBId != null) match.playerBId!,
          ],
        ),
        isNot(contains(droppedId)),
      );
    });

    test('can remove the latest round and reopen the previous one', () {
      final engine = TournamentEngine();
      var tournament = engine.startNextRound(
        engine.createOfflineTournament(
          title: 'Undo event',
          game: DraftGame.pokemon,
          format: TournamentFormat.bestOfThree,
          playerNames: ['A', 'B', 'C', 'D'],
        ),
      );

      for (final match in tournament.rounds.single.matches) {
        tournament = engine.recordResult(
          tournament: tournament,
          matchId: match.id,
          result: const MatchResult(outcome: MatchOutcome.playerA),
        );
      }
      tournament = engine.startNextRound(tournament);

      final previousRounds = tournament.rounds
          .take(tournament.rounds.length - 1)
          .toList();
      final targetRound = previousRounds.last;
      previousRounds[previousRounds.length - 1] = targetRound.copyWith(
        finalized: false,
        matches: [
          for (final match in targetRound.matches)
            match.copyWith(
              result: const MatchResult(outcome: MatchOutcome.unreported),
              locked: false,
            ),
        ],
      );
      final reopened = tournament.copyWith(rounds: previousRounds);

      expect(reopened.rounds, hasLength(1));
      expect(reopened.rounds.single.isComplete, isFalse);
      expect(reopened.rounds.single.matches.every((m) => !m.locked), isTrue);
    });

    test('BO3 match result stores per-game wins for tiebreakers', () {
      final result = const MatchResult(outcome: MatchOutcome.unreported)
          .withGameOutcome(
            gameIndex: 0,
            gameOutcome: MatchOutcome.playerA,
            winsRequired: 2,
            maxGames: 3,
          )
          .withGameOutcome(
            gameIndex: 1,
            gameOutcome: MatchOutcome.playerB,
            winsRequired: 2,
            maxGames: 3,
          )
          .withGameOutcome(
            gameIndex: 2,
            gameOutcome: MatchOutcome.playerA,
            winsRequired: 2,
            maxGames: 3,
          );

      expect(result.outcome, MatchOutcome.playerA);
      expect(result.playerAWins, 2);
      expect(result.playerBWins, 1);
      expect(result.gameOutcomes, [
        MatchOutcome.playerA,
        MatchOutcome.playerB,
        MatchOutcome.playerA,
      ]);
    });
  });
}
