import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/tournament_models.dart';
import '../providers/tournament_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(localTournamentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DraftTool'),
        actions: [
          TextButton(
            onPressed: () => context.go('/online'),
            child: const Text('Online'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _HeroCard(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.go('/new'),
            icon: const Icon(Icons.add),
            label: const Text('New offline tournament'),
          ),
          const SizedBox(height: 24),
          Text(
            'Saved tournaments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          tournaments.when(
            data: (items) {
              if (items.isEmpty) {
                return const Text('No saved tournaments yet.');
              }
              return Column(
                children: [
                  for (final tournament in items)
                    Card(
                      child: ListTile(
                        title: Text(tournament.config.title),
                        subtitle: Text(
                          '${tournament.config.game.label} - ${tournament.config.format.label} - ${tournament.players.length} players',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ref
                              .read(localTournamentControllerProvider.notifier)
                              .select(tournament);
                          context.go('/tournament/${tournament.id}');
                        },
                      ),
                    ),
                ],
              );
            },
            error: (error, _) => Text('Could not load tournaments: $error'),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF111827), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tournament pairings for drafts with friends',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Run Pokemon, Magic, and Yu-Gi-Oh Swiss events offline, or use online mode for invites, reports, and PKN tickets.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class NewTournamentScreen extends ConsumerStatefulWidget {
  const NewTournamentScreen({super.key});

  @override
  ConsumerState<NewTournamentScreen> createState() =>
      _NewTournamentScreenState();
}

class _NewTournamentScreenState extends ConsumerState<NewTournamentScreen> {
  final _title = TextEditingController(text: 'Friday draft');
  final _players = TextEditingController(text: 'Alice\nBob\nCharlie\nDana');
  DraftGame _game = DraftGame.pokemon;
  TournamentFormat _format = TournamentFormat.bestOfThree;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _players.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New offline tournament')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tournament name'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DraftGame>(
            initialValue: _game,
            decoration: const InputDecoration(labelText: 'Game'),
            items: [
              for (final game in DraftGame.values)
                DropdownMenuItem(value: game, child: Text(game.label)),
            ],
            onChanged: (value) => setState(() => _game = value ?? _game),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TournamentFormat>(
            initialValue: _format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: [
              for (final format in TournamentFormat.values)
                DropdownMenuItem(value: format, child: Text(format.label)),
            ],
            onChanged: (value) => setState(() => _format = value ?? _format),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _players,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Players, one per line',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _create,
            child: const Text('Create tournament'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    try {
      final tournament =
          await ref.read(localTournamentControllerProvider.notifier).create(
                title: _title.text,
                game: _game,
                format: _format,
                playerNames: _players.text.split('\n'),
              );
      if (mounted) {
        context.go('/tournament/${tournament.id}');
      }
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }
}
