import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/tournament_models.dart';
import '../providers/tournament_providers.dart';
import '../widgets/pokoin_brand.dart';

class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(localTournamentControllerProvider);
    final saved = ref.watch(localTournamentsProvider);
    final savedTournament = saved.value
        ?.where((item) => item.id == tournamentId)
        .firstOrNull;
    final tournament = selected?.id == tournamentId
        ? selected
        : savedTournament;

    if (selected?.id != tournamentId && savedTournament != null) {
      Future.microtask(
        () => ref
            .read(localTournamentControllerProvider.notifier)
            .select(savedTournament),
      );
    }

    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(title: const PokoinAppBarTitle(title: 'Tournament')),
        body: Center(
          child: saved.isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tournament not found.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Back home'),
                    ),
                  ],
                ),
        ),
      );
    }

    final engine = ref.watch(tournamentEngineProvider);
    final standings = engine.calculateStandings(tournament);
    final currentRound = tournament.rounds.isEmpty
        ? null
        : tournament.rounds.last;
    final inTopCut = tournament.phase == TournamentPhase.topCut;
    final canStartTopCut =
        tournament.config.format.hasTopCut &&
        !inTopCut &&
        tournament.status != TournamentStatus.finalized &&
        currentRound != null &&
        currentRound.isComplete;
    final canEndTournament =
        !tournament.config.format.hasTopCut &&
        tournament.status != TournamentStatus.finalized &&
        tournament.rounds.any((round) => round.isComplete);
    final standingsCard = _BlurredStandingsCard(
      rows: standings,
      finalized: tournament.status == TournamentStatus.finalized,
    );
    final roundCard = currentRound != null
        ? _RoundCard(round: currentRound, tournament: tournament)
        : const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No round paired yet.'),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: PokoinAppBarTitle(
          title: tournament.config.title,
          homeOnTap: tournament.status == TournamentStatus.finalized,
        ),
        actions: [
          if (!inTopCut &&
              tournament.rounds.length > 1 &&
              tournament.status != TournamentStatus.finalized)
            TextButton.icon(
              onPressed: () => ref
                  .read(localTournamentControllerProvider.notifier)
                  .goBackRound(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back round'),
            ),
          if (canStartTopCut || canEndTournament)
            TextButton.icon(
              onPressed: () => ref
                  .read(localTournamentControllerProvider.notifier)
                  .finalize(),
              icon: const Icon(Icons.emoji_events_outlined),
              label: Text(canStartTopCut ? 'Start top cut' : 'Show winners'),
            ),
          if (!inTopCut && tournament.status != TournamentStatus.finalized)
            TextButton(
              onPressed: currentRound != null && !currentRound.isComplete
                  ? null
                  : () => ref
                        .read(localTournamentControllerProvider.notifier)
                        .startNextRound(),
              child: Text(currentRound == null ? 'Pair round' : 'Next round'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Summary(tournament: tournament),
          const SizedBox(height: 20),
          if (inTopCut) ...[
            _TopCutCard(tournament: tournament),
            const SizedBox(height: 20),
            standingsCard,
          ] else if (tournament.status == TournamentStatus.finalized) ...[
            standingsCard,
            const SizedBox(height: 20),
            roundCard,
          ] else ...[
            roundCard,
            const SizedBox(height: 20),
            standingsCard,
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.tournament});

  final DraftTournament tournament;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _Chip(label: tournament.config.game.label),
            _Chip(label: tournament.config.format.label),
            _Chip(label: '${tournament.players.length} players'),
            _Chip(
              label: tournament.phase == TournamentPhase.topCut
                  ? 'top cut'
                  : 'swiss',
            ),
            _Chip(label: tournament.status.name),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _RoundCard extends ConsumerWidget {
  const _RoundCard({required this.round, required this.tournament});

  final TournamentRound round;
  final DraftTournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round ${round.number}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final match in round.matches)
              _MatchTile(match: match, tournament: tournament),
          ],
        ),
      ),
    );
  }
}

class _MatchTile extends ConsumerWidget {
  const _MatchTile({required this.match, required this.tournament});

  final TournamentMatch match;
  final DraftTournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerA = tournament.players.firstWhere(
      (p) => p.id == match.playerAId,
    );
    final playerB = match.playerBId == null
        ? null
        : tournament.players.firstWhere((p) => p.id == match.playerBId);
    final maxGames = tournament.config.format.maxGames;
    final winsRequired = maxGames == 1 ? 1 : 2;
    final hideThirdGame =
        maxGames == 3 && _firstTwoGamesAlreadyDecideMatch(match.result);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Text('${match.tableNumber}')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerB == null
                      ? '${playerA.name} has a bye'
                      : '${playerA.name} vs ${playerB.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(_resultLabel(match, playerA, playerB)),
                if (playerB != null) ...[
                  const SizedBox(height: 10),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var gameIndex = 0;
                          gameIndex < maxGames;
                          gameIndex += 1
                        )
                          if (gameIndex < 2 || !hideThirdGame)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: Padding(
                                key: ValueKey(
                                  '${match.id}-game-$gameIndex-$hideThirdGame',
                                ),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _GameResultRow(
                                  label: 'Match #${gameIndex + 1}',
                                  selected:
                                      gameIndex <
                                          match.result.gameOutcomes.length
                                      ? match.result.gameOutcomes[gameIndex]
                                      : MatchOutcome.unreported,
                                  disabled: false,
                                  playerA: playerA,
                                  playerB: playerB,
                                  onDropA: playerA.dropped
                                      ? null
                                      : () => _dropPlayer(ref, playerA),
                                  onDropB: playerB.dropped
                                      ? null
                                      : () => _dropPlayer(ref, playerB),
                                  onSelected: (outcome) => _recordGame(
                                    ref,
                                    gameIndex: gameIndex,
                                    outcome: outcome,
                                    winsRequired: winsRequired,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _firstTwoGamesAlreadyDecideMatch(MatchResult result) {
    if (result.gameOutcomes.length < 2) {
      return false;
    }
    final firstTwo = result.gameOutcomes.take(2).toList();
    return firstTwo.every((outcome) => outcome == MatchOutcome.playerA) ||
        firstTwo.every((outcome) => outcome == MatchOutcome.playerB);
  }

  void _recordGame(
    WidgetRef ref, {
    required int gameIndex,
    required MatchOutcome outcome,
    required int winsRequired,
  }) {
    ref
        .read(localTournamentControllerProvider.notifier)
        .recordResult(
          matchId: match.id,
          result: match.result.withGameOutcome(
            gameIndex: gameIndex,
            gameOutcome: outcome,
            winsRequired: winsRequired,
            maxGames: tournament.config.format.maxGames,
          ),
        );
  }

  void _dropPlayer(WidgetRef ref, TournamentPlayer player) {
    ref.read(localTournamentControllerProvider.notifier).dropPlayer(player.id);
  }

  String _resultLabel(
    TournamentMatch match,
    TournamentPlayer playerA,
    TournamentPlayer? playerB,
  ) {
    return switch (match.result.outcome) {
      MatchOutcome.playerA => '${playerA.name} won',
      MatchOutcome.playerB => '${playerB?.name ?? 'Opponent'} won',
      MatchOutcome.draw => 'Draw',
      MatchOutcome.bye => 'Bye win',
      MatchOutcome.unreported => 'Awaiting result',
    };
  }
}

class _GameResultRow extends StatelessWidget {
  const _GameResultRow({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.playerA,
    required this.playerB,
    this.onDropA,
    this.onDropB,
    required this.onSelected,
  });

  final String label;
  final MatchOutcome selected;
  final bool disabled;
  final TournamentPlayer playerA;
  final TournamentPlayer playerB;
  final VoidCallback? onDropA;
  final VoidCallback? onDropB;
  final ValueChanged<MatchOutcome> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
        ),
        _PlayerResultActions(
          player: playerA,
          selected: selected == MatchOutcome.playerA,
          disabled: disabled,
          onWin: () => onSelected(MatchOutcome.playerA),
          onDrop: onDropA,
        ),
        _PlayerResultActions(
          player: playerB,
          selected: selected == MatchOutcome.playerB,
          disabled: disabled,
          onWin: () => onSelected(MatchOutcome.playerB),
          onDrop: onDropB,
        ),
        _ResultButton(
          label: 'Draw',
          selected: selected == MatchOutcome.draw,
          disabled: disabled,
          onPressed: () => onSelected(MatchOutcome.draw),
        ),
      ],
    );
  }
}

class _PlayerResultActions extends StatelessWidget {
  const _PlayerResultActions({
    required this.player,
    required this.selected,
    required this.disabled,
    required this.onWin,
    this.onDrop,
  });

  final TournamentPlayer player;
  final bool selected;
  final bool disabled;
  final VoidCallback onWin;
  final VoidCallback? onDrop;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ResultButton(
          label: player.dropped ? '${player.name} (dropped)' : player.name,
          selected: selected,
          disabled: disabled,
          onPressed: onWin,
        ),
        if (onDrop != null)
          IconButton(
            tooltip: 'Drop ${player.name} after this round',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDrop,
          ),
      ],
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(
            onPressed: disabled ? null : onPressed,
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: disabled ? null : onPressed,
            child: Text(label),
          );
  }
}

class _BlurredStandingsCard extends StatelessWidget {
  const _BlurredStandingsCard({required this.rows, required this.finalized});

  final List<StandingRow> rows;
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    if (finalized) {
      return _StandingsCard(rows: rows, finalized: true);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: IgnorePointer(
            child: _StandingsCard(rows: rows, finalized: false),
          ),
        ),
        Card(
          color: const Color(0xEE050816),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              'Ladder unlocks after Show winners',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFACC15),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.rows, required this.finalized});

  final List<StandingRow> rows;
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              finalized ? 'Final ladder' : 'Standings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('#${row.rank}'),
                title: Text(row.player.name),
                subtitle: Text(
                  '${row.matchWins}-${row.matchLosses}-${row.matchDraws} matches, ${row.gameWins}-${row.gameLosses}-${row.gameDraws} games',
                ),
                trailing: Text('${row.matchPoints} pts'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopCutCard extends ConsumerWidget {
  const _TopCutCard({required this.tournament});

  final DraftTournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tournament.topCutRounds.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxGames = tournament.config.format.maxGames;
    final winsRequired = maxGames == 1 ? 1 : 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top cut', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final round in tournament.topCutRounds) ...[
              Text(round.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final match in round.matches)
                _TopCutMatchTile(
                  match: match,
                  tournament: tournament,
                  maxGames: maxGames,
                  winsRequired: winsRequired,
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopCutMatchTile extends ConsumerWidget {
  const _TopCutMatchTile({
    required this.match,
    required this.tournament,
    required this.maxGames,
    required this.winsRequired,
  });

  final EliminationMatch match;
  final DraftTournament tournament;
  final int maxGames;
  final int winsRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerA = tournament.players.firstWhere(
      (p) => p.id == match.playerAId,
    );
    final playerB = tournament.players.firstWhere(
      (p) => p.id == match.playerBId,
    );
    final hideThirdGame =
        maxGames == 3 && _firstTwoGamesAlreadyDecideMatch(match.result);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Table ${match.tableNumber}: ${playerA.name} vs ${playerB.name}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(_resultLabel(match, playerA, playerB)),
          const SizedBox(height: 10),
          for (var gameIndex = 0; gameIndex < maxGames; gameIndex += 1)
            if (gameIndex < 2 || !hideThirdGame)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GameResultRow(
                  label: 'Match #${gameIndex + 1}',
                  selected: gameIndex < match.result.gameOutcomes.length
                      ? match.result.gameOutcomes[gameIndex]
                      : MatchOutcome.unreported,
                  disabled: false,
                  playerA: playerA,
                  playerB: playerB,
                  onSelected: (outcome) {
                    ref
                        .read(localTournamentControllerProvider.notifier)
                        .recordTopCutResult(
                          matchId: match.id,
                          result: match.result.withGameOutcome(
                            gameIndex: gameIndex,
                            gameOutcome: outcome,
                            winsRequired: winsRequired,
                            maxGames: maxGames,
                          ),
                        );
                  },
                ),
              ),
        ],
      ),
    );
  }

  bool _firstTwoGamesAlreadyDecideMatch(MatchResult result) {
    if (result.gameOutcomes.length < 2) {
      return false;
    }
    final firstTwo = result.gameOutcomes.take(2).toList();
    return firstTwo.every((outcome) => outcome == MatchOutcome.playerA) ||
        firstTwo.every((outcome) => outcome == MatchOutcome.playerB);
  }

  String _resultLabel(
    EliminationMatch match,
    TournamentPlayer playerA,
    TournamentPlayer playerB,
  ) {
    return switch (match.result.outcome) {
      MatchOutcome.playerA => '${playerA.name} advances',
      MatchOutcome.playerB => '${playerB.name} advances',
      MatchOutcome.draw => 'Draw',
      MatchOutcome.bye => 'Bye win',
      MatchOutcome.unreported => 'Awaiting result',
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
