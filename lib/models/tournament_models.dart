import 'dart:convert';

enum DraftGame {
  pokemon('Pokemon'),
  magic('Magic'),
  yugioh('Yu-Gi-Oh');

  const DraftGame(this.label);

  final String label;
}

enum TournamentFormat {
  bestOfOne('BO1', 1, false),
  bestOfThree('BO3', 3, false),
  bestOfThreeTopCut('BO3 + Top Cut', 3, true);

  const TournamentFormat(this.label, this.maxGames, this.hasTopCut);

  final String label;
  final int maxGames;
  final bool hasTopCut;
}

enum TournamentMode { offline, online }

enum TournamentStatus { setup, active, finalized, canceled }

enum MatchOutcome { playerA, playerB, draw, bye, unreported }

class TournamentPlayer {
  const TournamentPlayer({
    required this.id,
    required this.name,
    required this.seed,
    this.uid,
    this.username,
    this.dropped = false,
  });

  final String id;
  final String name;
  final int seed;
  final String? uid;
  final String? username;
  final bool dropped;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seed': seed,
        'uid': uid,
        'username': username,
        'dropped': dropped,
      };

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      seed: json['seed'] as int,
      uid: json['uid'] as String?,
      username: json['username'] as String?,
      dropped: json['dropped'] as bool? ?? false,
    );
  }
}

class MatchResult {
  const MatchResult({
    required this.outcome,
    this.playerAWins = 0,
    this.playerBWins = 0,
    this.draws = 0,
    this.reportedBy,
  });

  final MatchOutcome outcome;
  final int playerAWins;
  final int playerBWins;
  final int draws;
  final String? reportedBy;

  bool get isComplete => outcome != MatchOutcome.unreported;

  Map<String, dynamic> toJson() => {
        'outcome': outcome.name,
        'playerAWins': playerAWins,
        'playerBWins': playerBWins,
        'draws': draws,
        'reportedBy': reportedBy,
      };

  factory MatchResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MatchResult(outcome: MatchOutcome.unreported);
    }
    return MatchResult(
      outcome: MatchOutcome.values.byName(json['outcome'] as String),
      playerAWins: json['playerAWins'] as int? ?? 0,
      playerBWins: json['playerBWins'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      reportedBy: json['reportedBy'] as String?,
    );
  }
}

class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.roundNumber,
    required this.tableNumber,
    required this.playerAId,
    this.playerBId,
    this.result = const MatchResult(outcome: MatchOutcome.unreported),
    this.conflict = false,
    this.locked = false,
  });

  final String id;
  final int roundNumber;
  final int tableNumber;
  final String playerAId;
  final String? playerBId;
  final MatchResult result;
  final bool conflict;
  final bool locked;

  bool get isBye => playerBId == null;

  TournamentMatch copyWith({
    MatchResult? result,
    bool? conflict,
    bool? locked,
  }) {
    return TournamentMatch(
      id: id,
      roundNumber: roundNumber,
      tableNumber: tableNumber,
      playerAId: playerAId,
      playerBId: playerBId,
      result: result ?? this.result,
      conflict: conflict ?? this.conflict,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roundNumber': roundNumber,
        'tableNumber': tableNumber,
        'playerAId': playerAId,
        'playerBId': playerBId,
        'result': result.toJson(),
        'conflict': conflict,
        'locked': locked,
      };

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'] as String,
      roundNumber: json['roundNumber'] as int,
      tableNumber: json['tableNumber'] as int,
      playerAId: json['playerAId'] as String,
      playerBId: json['playerBId'] as String?,
      result: MatchResult.fromJson(json['result'] as Map<String, dynamic>?),
      conflict: json['conflict'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
    );
  }
}

class TournamentRound {
  const TournamentRound({
    required this.number,
    required this.matches,
    this.finalized = false,
  });

  final int number;
  final List<TournamentMatch> matches;
  final bool finalized;

  bool get isComplete => matches.every((match) => match.result.isComplete);

  TournamentRound copyWith({
    List<TournamentMatch>? matches,
    bool? finalized,
  }) {
    return TournamentRound(
      number: number,
      matches: matches ?? this.matches,
      finalized: finalized ?? this.finalized,
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'matches': matches.map((match) => match.toJson()).toList(),
        'finalized': finalized,
      };

  factory TournamentRound.fromJson(Map<String, dynamic> json) {
    return TournamentRound(
      number: json['number'] as int,
      matches: (json['matches'] as List<dynamic>? ?? [])
          .map((value) => TournamentMatch.fromJson(value as Map<String, dynamic>))
          .toList(),
      finalized: json['finalized'] as bool? ?? false,
    );
  }
}

class PayoutSplit {
  const PayoutSplit({required this.place, required this.percent});

  final int place;
  final int percent;

  Map<String, dynamic> toJson() => {
        'place': place,
        'percent': percent,
      };

  factory PayoutSplit.fromJson(Map<String, dynamic> json) {
    return PayoutSplit(
      place: json['place'] as int,
      percent: json['percent'] as int,
    );
  }
}

class TournamentConfig {
  const TournamentConfig({
    required this.title,
    required this.game,
    required this.format,
    required this.mode,
    this.ticketPkn = 0,
    this.payoutSplits = const [],
    this.topCutSize = 8,
  });

  final String title;
  final DraftGame game;
  final TournamentFormat format;
  final TournamentMode mode;
  final int ticketPkn;
  final List<PayoutSplit> payoutSplits;
  final int topCutSize;

  Map<String, dynamic> toJson() => {
        'title': title,
        'game': game.name,
        'format': format.name,
        'mode': mode.name,
        'ticketPkn': ticketPkn,
        'payoutSplits': payoutSplits.map((split) => split.toJson()).toList(),
        'topCutSize': topCutSize,
      };

  factory TournamentConfig.fromJson(Map<String, dynamic> json) {
    return TournamentConfig(
      title: json['title'] as String,
      game: DraftGame.values.byName(json['game'] as String),
      format: TournamentFormat.values.byName(json['format'] as String),
      mode: TournamentMode.values.byName(json['mode'] as String),
      ticketPkn: json['ticketPkn'] as int? ?? 0,
      payoutSplits: (json['payoutSplits'] as List<dynamic>? ?? [])
          .map((value) => PayoutSplit.fromJson(value as Map<String, dynamic>))
          .toList(),
      topCutSize: json['topCutSize'] as int? ?? 8,
    );
  }
}

class StandingRow {
  const StandingRow({
    required this.player,
    required this.rank,
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
  final int rank;
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
}

class EliminationMatch {
  const EliminationMatch({
    required this.id,
    required this.roundLabel,
    required this.tableNumber,
    required this.playerAId,
    required this.playerBId,
  });

  final String id;
  final String roundLabel;
  final int tableNumber;
  final String playerAId;
  final String playerBId;
}

class DraftTournament {
  const DraftTournament({
    required this.id,
    required this.config,
    required this.players,
    required this.rounds,
    this.status = TournamentStatus.setup,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final TournamentConfig config;
  final List<TournamentPlayer> players;
  final List<TournamentRound> rounds;
  final TournamentStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get currentRoundNumber => rounds.isEmpty ? 0 : rounds.last.number;

  DraftTournament copyWith({
    TournamentConfig? config,
    List<TournamentPlayer>? players,
    List<TournamentRound>? rounds,
    TournamentStatus? status,
    DateTime? updatedAt,
  }) {
    return DraftTournament(
      id: id,
      config: config ?? this.config,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'players': players.map((player) => player.toJson()).toList(),
        'rounds': rounds.map((round) => round.toJson()).toList(),
        'status': status.name,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  factory DraftTournament.fromJson(Map<String, dynamic> json) {
    return DraftTournament(
      id: json['id'] as String,
      config:
          TournamentConfig.fromJson(json['config'] as Map<String, dynamic>),
      players: (json['players'] as List<dynamic>? ?? [])
          .map((value) => TournamentPlayer.fromJson(value as Map<String, dynamic>))
          .toList(),
      rounds: (json['rounds'] as List<dynamic>? ?? [])
          .map((value) => TournamentRound.fromJson(value as Map<String, dynamic>))
          .toList(),
      status: TournamentStatus.values.byName(json['status'] as String),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  factory DraftTournament.decode(String raw) {
    return DraftTournament.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static DateTime? _readDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
