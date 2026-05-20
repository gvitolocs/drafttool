import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/tournament_models.dart';
import '../providers/tournament_providers.dart';

class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(localTournamentControllerProvider);
    final saved = ref.watch(localTournamentsProvider);
    final savedTournament =
        saved.value?.where((item) => item.id == tournamentId).firstOrNull;
    final tournament = selected?.id == tournamentId ? selected : savedTournament;

    if (selected?.id != tournamentId && savedTournament != null) {
      Future.microtask(
        () => ref
            .read(localTournamentControllerProvider.notifier)
            .select(savedTournament),
      );
    }

    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
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
    final currentRound =
        tournament.rounds.isEmpty ? null : tournament.rounds.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.config.title),
        actions: [
          if (tournament.status != TournamentStatus.finalized)
            TextButton(
              onPressed: currentRound != null && !currentRound.isComplete
                  ? null
                  : () => ref
                      .read(localTournamentControllerProvider.notifier)
                      .startNextRound(),
              child: Text(currentRound == null ? 'Pair round 1' : 'Next round'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Summary(tournament: tournament),
          const SizedBox(height: 20),
          if (currentRound != null)
            _RoundCard(round: currentRound, tournament: tournament)
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Pair round 1 to start the event.'),
              ),
            ),
          const SizedBox(height: 20),
          _StandingsCard(
            rows: standings,
            finalized: tournament.status == TournamentStatus.finalized,
          ),
          if (tournament.config.format.hasTopCut &&
              tournament.status == TournamentStatus.finalized) ...[
            const SizedBox(height: 20),
            _TopCutCard(matches: engine.buildTopCut(tournament)),
          ],
          const SizedBox(height: 20),
          if (currentRound != null &&
              currentRound.isComplete &&
              tournament.status != TournamentStatus.finalized)
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(localTournamentControllerProvider.notifier)
                  .finalize(),
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('Finalize and show ladder'),
            ),
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
    final playerA = tournament.players.firstWhere((p) => p.id == match.playerAId);
    final playerB = match.playerBId == null
        ? null
        : tournament.players.firstWhere((p) => p.id == match.playerBId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${match.tableNumber}')),
      title: Text(playerB == null ? '${playerA.name} has a bye' : '${playerA.name} vs ${playerB.name}'),
      subtitle: Text(_resultLabel(match, playerA, playerB)),
      trailing: playerB == null || match.result.isComplete
          ? null
          : PopupMenuButton<MatchOutcome>(
              onSelected: (outcome) {
                ref.read(localTournamentControllerProvider.notifier).recordResult(
                      matchId: match.id,
                      result: MatchResult(
                        outcome: outcome,
                        playerAWins: outcome == MatchOutcome.playerA ? 2 : 0,
                        playerBWins: outcome == MatchOutcome.playerB ? 2 : 0,
                        draws: outcome == MatchOutcome.draw ? 1 : 0,
                      ),
                    );
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: MatchOutcome.playerA,
                  child: Text('${playerA.name} won'),
                ),
                PopupMenuItem(
                  value: MatchOutcome.playerB,
                  child: Text('${playerB.name} won'),
                ),
                const PopupMenuItem(
                  value: MatchOutcome.draw,
                  child: Text('Draw'),
                ),
              ],
            ),
    );
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

class _TopCutCard extends StatelessWidget {
  const _TopCutCard({required this.matches});

  final List<EliminationMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top cut', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final match in matches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${match.roundLabel} table ${match.tableNumber}'),
                subtitle: Text('${match.playerAId} vs ${match.playerBId}'),
              ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
