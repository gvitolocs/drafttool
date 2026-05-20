import 'dart:math';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../models/tournament_models.dart';

class TournamentEngine {
  TournamentEngine({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  DraftTournament createOfflineTournament({
    required String title,
    required DraftGame game,
    required TournamentFormat format,
    required List<String> playerNames,
  }) {
    final cleanNames = playerNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (cleanNames.length < 2) {
      throw ArgumentError('Add at least two players.');
    }

    final now = DateTime.now();
    return DraftTournament(
      id: _uuid.v4(),
      config: TournamentConfig(
        title: title.trim().isEmpty ? 'Draft tournament' : title.trim(),
        game: game,
        format: format,
        mode: TournamentMode.offline,
      ),
      players: [
        for (var i = 0; i < cleanNames.length; i += 1)
          TournamentPlayer(
            id: 'player-${i + 1}',
            name: cleanNames[i],
            seed: i + 1,
          ),
      ],
      rounds: const [],
      status: TournamentStatus.setup,
      createdAt: now,
      updatedAt: now,
    );
  }

  DraftTournament startNextRound(DraftTournament tournament) {
    if (tournament.phase == TournamentPhase.topCut) {
      return startNextTopCutRound(tournament);
    }
    if (tournament.rounds.isNotEmpty && !tournament.rounds.last.isComplete) {
      throw StateError('Finish the current round before pairing the next one.');
    }

    final standings = calculateStandings(tournament);
    final orderedPlayers = tournament.rounds.isEmpty
        ? (List<TournamentPlayer>.from(tournament.players)
            ..sort((a, b) => a.seed.compareTo(b.seed)))
        : standings.map((row) => row.player).toList();
    final activePlayers = orderedPlayers
        .where((player) => !player.dropped)
        .toList();
    if (activePlayers.length < 2) {
      throw StateError('At least two active players are required.');
    }

    final roundNumber = tournament.rounds.length + 1;
    final pairings = _pairPlayers(
      activePlayers,
      previousPairings: _previousPairings(tournament.rounds),
      previousByes: _previousByes(tournament.rounds),
    );
    final matches = <TournamentMatch>[];
    for (var i = 0; i < pairings.length; i += 1) {
      final pairing = pairings[i];
      matches.add(
        TournamentMatch(
          id: 'r${roundNumber}m${i + 1}',
          roundNumber: roundNumber,
          tableNumber: i + 1,
          playerAId: pairing.$1.id,
          playerBId: pairing.$2?.id,
          result: pairing.$2 == null
              ? const MatchResult(outcome: MatchOutcome.bye, playerAWins: 1)
              : const MatchResult(outcome: MatchOutcome.unreported),
          locked: pairing.$2 == null,
        ),
      );
    }

    return tournament.copyWith(
      rounds: [
        ...tournament.rounds.map(
          (round) => round.number == roundNumber - 1
              ? round.copyWith(finalized: true)
              : round,
        ),
        TournamentRound(number: roundNumber, matches: matches),
      ],
      phase: TournamentPhase.swiss,
      status: TournamentStatus.active,
      updatedAt: DateTime.now(),
    );
  }

  DraftTournament recordResult({
    required DraftTournament tournament,
    required String matchId,
    required MatchResult result,
  }) {
    final rounds = tournament.rounds.map((round) {
      final matches = round.matches.map((match) {
        if (match.id != matchId) {
          return match;
        }
        return match.copyWith(result: result, locked: true, conflict: false);
      }).toList();
      return round.copyWith(matches: matches);
    }).toList();
    return tournament.copyWith(rounds: rounds, updatedAt: DateTime.now());
  }

  DraftTournament dropPlayer({
    required DraftTournament tournament,
    required String playerId,
  }) {
    if (tournament.phase != TournamentPhase.swiss) {
      throw StateError('Players can only drop during Swiss rounds.');
    }
    return tournament.copyWith(
      players: [
        for (final player in tournament.players)
          player.id == playerId ? player.copyWith(dropped: true) : player,
      ],
      updatedAt: DateTime.now(),
    );
  }

  DraftTournament finalizeTournament(DraftTournament tournament) {
    if (tournament.rounds.isEmpty) {
      throw StateError('Start at least one round before finalizing.');
    }
    if (tournament.config.format.hasTopCut) {
      if (tournament.phase != TournamentPhase.topCut) {
        return startTopCut(tournament);
      }
      if (tournament.topCutRounds.isEmpty ||
          !tournament.topCutRounds.last.isComplete) {
        throw StateError('Finish all top cut matches before finalizing.');
      }
    } else if (!tournament.rounds.last.isComplete) {
      throw StateError('Finish all matches before finalizing.');
    }
    return tournament.copyWith(
      status: TournamentStatus.finalized,
      updatedAt: DateTime.now(),
    );
  }

  List<StandingRow> calculateStandings(DraftTournament tournament) {
    final stats = {
      for (final player in tournament.players) player.id: _PlayerStats(player),
    };

    for (final round in tournament.rounds) {
      for (final match in round.matches) {
        final a = stats[match.playerAId];
        final b = match.playerBId == null ? null : stats[match.playerBId];
        if (a == null || !match.result.isComplete) {
          continue;
        }
        if (b == null || match.result.outcome == MatchOutcome.bye) {
          a.matchWins += 1;
          a.matchPoints += 3;
          a.gameWins += max(1, match.result.playerAWins);
          continue;
        }
        a.opponents.add(b.player.id);
        b.opponents.add(a.player.id);
        a.matchesPlayed += 1;
        b.matchesPlayed += 1;
        a.gameWins += match.result.playerAWins;
        a.gameLosses += match.result.playerBWins;
        a.gameDraws += match.result.draws;
        b.gameWins += match.result.playerBWins;
        b.gameLosses += match.result.playerAWins;
        b.gameDraws += match.result.draws;

        switch (match.result.outcome) {
          case MatchOutcome.playerA:
            a.matchWins += 1;
            a.matchPoints += 3;
            b.matchLosses += 1;
          case MatchOutcome.playerB:
            b.matchWins += 1;
            b.matchPoints += 3;
            a.matchLosses += 1;
          case MatchOutcome.draw:
            a.matchDraws += 1;
            b.matchDraws += 1;
            a.matchPoints += 1;
            b.matchPoints += 1;
          case MatchOutcome.bye:
            a.matchWins += 1;
            a.matchPoints += 3;
          case MatchOutcome.unreported:
            break;
        }
      }
    }

    final rows = stats.values.map((stat) {
      final opponentMatchWinPercentage = _average(
        stat.opponents.map((id) => stats[id]?.matchWinPercentage ?? 0),
      );
      final opponentGameWinPercentage = _average(
        stat.opponents.map((id) => stats[id]?.gameWinPercentage ?? 0),
      );
      return _UnrankedStanding(
        player: stat.player,
        matchPoints: stat.matchPoints,
        matchesPlayed: stat.matchesPlayed,
        matchWins: stat.matchWins,
        matchDraws: stat.matchDraws,
        matchLosses: stat.matchLosses,
        gameWins: stat.gameWins,
        gameDraws: stat.gameDraws,
        gameLosses: stat.gameLosses,
        opponentMatchWinPercentage: opponentMatchWinPercentage,
        gameWinPercentage: stat.gameWinPercentage,
        opponentGameWinPercentage: opponentGameWinPercentage,
      );
    }).toList()..sort(_compareStandings);

    return [for (var i = 0; i < rows.length; i += 1) rows[i].ranked(i + 1)];
  }

  int recommendedTopCutSize(int playerCount) {
    if (playerCount < 4) {
      return 2;
    }
    if (playerCount < 17) {
      return 4;
    }
    return 8;
  }

  DraftTournament startTopCut(DraftTournament tournament, {int? size}) {
    if (!tournament.config.format.hasTopCut) {
      throw StateError('This tournament format has no top cut.');
    }
    if (tournament.rounds.isEmpty || !tournament.rounds.last.isComplete) {
      throw StateError('Finish Swiss before starting top cut.');
    }
    if (tournament.topCutRounds.isNotEmpty) {
      return tournament.copyWith(phase: TournamentPhase.topCut);
    }
    final matches = buildTopCut(tournament, size: size);
    if (matches.isEmpty) {
      throw StateError('At least two players are required for top cut.');
    }
    return tournament.copyWith(
      phase: TournamentPhase.topCut,
      topCutRounds: [
        EliminationRound(
          number: 1,
          label: _topCutRoundLabel(matches.length * 2),
          matches: matches,
        ),
      ],
      status: TournamentStatus.active,
      autoAdvancePaused: true,
      updatedAt: DateTime.now(),
    );
  }

  DraftTournament startNextTopCutRound(DraftTournament tournament) {
    if (tournament.phase != TournamentPhase.topCut) {
      throw StateError('Top cut has not started.');
    }
    if (tournament.topCutRounds.isEmpty) {
      return startTopCut(tournament);
    }
    final currentRound = tournament.topCutRounds.last;
    if (!currentRound.isComplete) {
      throw StateError('Finish the current top cut round first.');
    }
    final winners = currentRound.matches
        .map((match) => match.winnerId)
        .whereType<String>()
        .toList();
    if (winners.length < 2) {
      return tournament.copyWith(
        status: TournamentStatus.finalized,
        updatedAt: DateTime.now(),
      );
    }
    final roundNumber = tournament.topCutRounds.length + 1;
    final matches = <EliminationMatch>[];
    for (var i = 0; i < winners.length; i += 2) {
      matches.add(
        EliminationMatch(
          id: 'topcut-r${roundNumber}m${matches.length + 1}',
          tableNumber: matches.length + 1,
          playerAId: winners[i],
          playerBId: winners[i + 1],
        ),
      );
    }
    return tournament.copyWith(
      topCutRounds: [
        ...tournament.topCutRounds,
        EliminationRound(
          number: roundNumber,
          label: _topCutRoundLabel(winners.length),
          matches: matches,
        ),
      ],
      autoAdvancePaused: true,
      updatedAt: DateTime.now(),
    );
  }

  DraftTournament recordTopCutResult({
    required DraftTournament tournament,
    required String matchId,
    required MatchResult result,
  }) {
    final rounds = tournament.topCutRounds.map((round) {
      final matches = round.matches.map((match) {
        if (match.id != matchId) {
          return match;
        }
        return match.copyWith(result: result, locked: true);
      }).toList();
      return round.copyWith(matches: matches);
    }).toList();
    var updated = tournament.copyWith(
      topCutRounds: rounds,
      updatedAt: DateTime.now(),
    );
    if (rounds.isNotEmpty && rounds.last.isComplete) {
      updated = startNextTopCutRound(updated);
    }
    return updated;
  }

  List<EliminationMatch> buildTopCut(DraftTournament tournament, {int? size}) {
    final standings = calculateStandings(tournament);
    final requestedSize =
        size ??
        min(
          tournament.config.topCutSize,
          recommendedTopCutSize(tournament.players.length),
        );
    final cutSize = min(requestedSize, standings.length);
    final normalizedSize = _largestPowerOfTwo(cutSize);
    if (normalizedSize < 2) {
      return const [];
    }
    final seeds = standings
        .take(normalizedSize)
        .map((row) => row.player)
        .toList();
    final matches = <EliminationMatch>[];
    for (var i = 0; i < normalizedSize ~/ 2; i += 1) {
      final highSeed = seeds[i];
      final lowSeed = seeds[normalizedSize - 1 - i];
      matches.add(
        EliminationMatch(
          id: 'topcut-r1m${i + 1}',
          tableNumber: i + 1,
          playerAId: highSeed.id,
          playerBId: lowSeed.id,
        ),
      );
    }
    return matches;
  }

  List<(TournamentPlayer, TournamentPlayer?)> _pairPlayers(
    List<TournamentPlayer> players, {
    required Set<String> previousPairings,
    required Set<String> previousByes,
  }) {
    final queue = [...players];
    final pairings = <(TournamentPlayer, TournamentPlayer?)>[];
    if (queue.length.isOdd) {
      final byePlayer = queue.reversed.firstWhere(
        (player) => !previousByes.contains(player.id),
        orElse: () => queue.last,
      );
      queue.remove(byePlayer);
      pairings.add((byePlayer, null));
    }

    while (queue.isNotEmpty) {
      final first = queue.removeAt(0);
      var opponentIndex = queue.indexWhere(
        (candidate) =>
            !previousPairings.contains(_pairingKey(first.id, candidate.id)),
      );
      if (opponentIndex < 0) {
        opponentIndex = 0;
      }
      final second = queue.removeAt(opponentIndex);
      pairings.insert(0, (first, second));
    }
    return pairings;
  }

  Set<String> _previousPairings(List<TournamentRound> rounds) {
    return {
      for (final round in rounds)
        for (final match in round.matches)
          if (match.playerBId != null)
            _pairingKey(match.playerAId, match.playerBId!),
    };
  }

  Set<String> _previousByes(List<TournamentRound> rounds) {
    return {
      for (final round in rounds)
        for (final match in round.matches)
          if (match.isBye) match.playerAId,
    };
  }

  static String _pairingKey(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join(':');
  }

  static double _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) {
      return 0;
    }
    return list.sum / list.length;
  }

  static int _compareStandings(_UnrankedStanding a, _UnrankedStanding b) {
    final comparisons = [
      b.matchPoints.compareTo(a.matchPoints),
      b.opponentMatchWinPercentage.compareTo(a.opponentMatchWinPercentage),
      b.gameWinPercentage.compareTo(a.gameWinPercentage),
      b.opponentGameWinPercentage.compareTo(a.opponentGameWinPercentage),
      a.player.seed.compareTo(b.player.seed),
      a.player.name.toLowerCase().compareTo(b.player.name.toLowerCase()),
    ];
    return comparisons.firstWhereOrNull((value) => value != 0) ?? 0;
  }

  static int _largestPowerOfTwo(int value) {
    var power = 1;
    while (power * 2 <= value) {
      power *= 2;
    }
    return power;
  }

  static String _topCutRoundLabel(int size) {
    return switch (size) {
      2 => 'Final',
      4 => 'Semifinal',
      8 => 'Quarterfinal',
      _ => 'Top $size',
    };
  }
}

class _PlayerStats {
  _PlayerStats(this.player);

  final TournamentPlayer player;
  final List<String> opponents = [];
  int matchPoints = 0;
  int matchesPlayed = 0;
  int matchWins = 0;
  int matchDraws = 0;
  int matchLosses = 0;
  int gameWins = 0;
  int gameDraws = 0;
  int gameLosses = 0;

  double get matchWinPercentage {
    if (matchesPlayed == 0) {
      return 0;
    }
    return (matchWins + matchDraws / 3) / matchesPlayed;
  }

  double get gameWinPercentage {
    final total = gameWins + gameDraws + gameLosses;
    if (total == 0) {
      return 0;
    }
    return (gameWins + gameDraws / 3) / total;
  }
}

class _UnrankedStanding {
  const _UnrankedStanding({
    required this.player,
    required this.matchPoints,
    required this.matchesPlayed,
    required this.matchWins,
    required this.matchDraws,
    required this.matchLosses,
    required this.gameWins,
    required this.gameDraws,
    required this.gameLosses,
    required this.opponentMatchWinPercentage,
    required this.gameWinPercentage,
    required this.opponentGameWinPercentage,
  });

  final TournamentPlayer player;
  final int matchPoints;
  final int matchesPlayed;
  final int matchWins;
  final int matchDraws;
  final int matchLosses;
  final int gameWins;
  final int gameDraws;
  final int gameLosses;
  final double opponentMatchWinPercentage;
  final double gameWinPercentage;
  final double opponentGameWinPercentage;

  StandingRow ranked(int rank) {
    return StandingRow(
      player: player,
      rank: rank,
      matchPoints: matchPoints,
      matchesPlayed: matchesPlayed,
      matchWins: matchWins,
      matchDraws: matchDraws,
      matchLosses: matchLosses,
      gameWins: gameWins,
      gameDraws: gameDraws,
      gameLosses: gameLosses,
      opponentMatchWinPercentage: opponentMatchWinPercentage,
      gameWinPercentage: gameWinPercentage,
      opponentGameWinPercentage: opponentGameWinPercentage,
    );
  }
}
