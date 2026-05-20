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

      expect(tournament.rounds.single.matches.where((m) => m.isBye), hasLength(1));
      expect(
        tournament.rounds.single.matches.singleWhere((m) => m.isBye).result.outcome,
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
        format: TournamentFormat.bestOfThreeTopCut,
        playerNames: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
      );

      final topCut = engine.buildTopCut(tournament, size: 8);
      expect(topCut, hasLength(4));
      expect(topCut.first.playerAId, 'player-1');
      expect(topCut.first.playerBId, 'player-8');
    });
  });
}
