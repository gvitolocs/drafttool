import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/tournament_models.dart';
import '../providers/auth_providers.dart';
import '../providers/tournament_providers.dart';
import '../services/draft_form_store.dart';
import '../services/pokemon_name_service.dart';
import '../widgets/pokoin_brand.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(localTournamentsProvider);
    final user = ref.watch(authStateProvider).value;
    final accountLabel = user == null
        ? 'Log in'
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : user.email ?? 'Account');
    return Scaffold(
      appBar: AppBar(
        title: const PokoinAppBarTitle(
          title: 'DraftTool',
          subtitle: 'Tournament helper for TCG events',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/online'),
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            label: Text(accountLabel),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.2,
            colors: [Color(0x2238BDF8), Color(0x00050816)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ModeGrid(signedIn: user != null),
            const SizedBox(height: 28),
            Text(
              'Last tournaments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            tournaments.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _Panel(
                    child: Text(
                      'No recent tournaments yet. Create an offline event or log in for online tournaments.',
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final tournament in items)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.history_outlined,
                            color: Color(0xFFFACC15),
                          ),
                          title: Text(
                            tournament.config.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${tournament.config.game.label} - ${tournament.config.format.label} - ${tournament.players.length} players\n${_lastTournamentLabel(tournament)}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            ref
                                .read(
                                  localTournamentControllerProvider.notifier,
                                )
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
      ),
    );
  }
}

String _lastTournamentLabel(DraftTournament tournament) {
  final date = tournament.updatedAt ?? tournament.createdAt;
  final status = tournament.status.name;
  if (date == null) {
    return status;
  }
  final now = DateTime.now();
  final difference = now.difference(date);
  final relative = switch (difference) {
    Duration(inMinutes: < 1) => 'just now',
    Duration(inHours: < 1) => '${difference.inMinutes}m ago',
    Duration(inDays: < 1) => '${difference.inHours}h ago',
    Duration(inDays: 1) => 'yesterday',
    Duration(inDays: < 7) => '${difference.inDays}d ago',
    _ => '${date.day}/${date.month}/${date.year}',
  };
  return '$status - $relative';
}

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModeCard(
          icon: Icons.wifi_off_outlined,
          title: 'Offline tournament',
          value: 'Single device',
          detail:
              'Create players, pair rounds, select winners, and finish the ladder without internet.',
          onPressed: () => context.go('/new'),
        ),
        _ModeCard(
          icon: Icons.groups_2_outlined,
          title: 'Online tournament',
          value: signedIn ? 'Ready' : 'Login required',
          detail: signedIn
              ? 'Invite users, let players report results, and use PKN tickets.'
              : 'Sign in with Pokoin to create multiplayer events, invite users, and manage tickets.',
          onPressed: () => context.go('/online'),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFFFACC15), size: 30),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                detail,
                style: const TextStyle(color: Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.collapsible = false,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final orderedValues = [
      selected,
      for (final value in values)
        if (value != selected) value,
    ];
    final visibleValues = collapsible && !expanded
        ? orderedValues.take(3)
        : orderedValues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in visibleValues)
              ChoiceChip(
                label: Text(labelFor(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
                selectedColor: const Color(0xFFFACC15),
                backgroundColor: const Color(0xFF111827),
                labelStyle: TextStyle(
                  color: value == selected
                      ? const Color(0xFF111827)
                      : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: Color(0x33FACC15)),
                ),
              ),
            if (collapsible && values.length > 3)
              IconButton.outlined(
                onPressed: onToggleExpanded,
                icon: Icon(expanded ? Icons.remove : Icons.add),
                tooltip: expanded ? 'Show fewer games' : 'Show more games',
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFFFACC15),
                  side: const BorderSide(color: Color(0x66FACC15)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlayerFields extends StatelessWidget {
  const _PlayerFields({
    required this.players,
    required this.focusNodes,
    required this.validatingNames,
    required this.onlineValidNames,
    required this.invalidNames,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TextEditingController> players;
  final List<FocusNode> focusNodes;
  final Set<String> validatingNames;
  final Set<String> onlineValidNames;
  final Set<String> invalidNames;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Players', style: TextStyle(color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: players.length > 4 ? onRemove : null,
              icon: const Icon(Icons.remove),
              tooltip: 'Remove player',
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFFACC15),
                disabledForegroundColor: const Color(0x5594A3B8),
                side: const BorderSide(color: Color(0x66FACC15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < players.length; i += 1)
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: players[i],
                        focusNode: focusNodes[i],
                        onChanged: (_) => onChanged(),
                        decoration: InputDecoration(
                          labelText: 'Player ${i + 1}',
                          helperText: _helperText(players[i].text),
                          helperStyle: TextStyle(
                            color: _helperColor(players[i].text),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Add player',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _helperText(String value) {
    final normalized = PokemonNameService.normalizeName(value);
    if (normalized.isEmpty) {
      return null;
    }
    if (onlineValidNames.contains(normalized)) {
      return 'Validated with PokeAPI';
    }
    if (validatingNames.contains(normalized)) {
      return 'Checking Pokemon API...';
    }
    if (invalidNames.contains(normalized)) {
      return 'Not found in local list or PokeAPI';
    }
    return null;
  }

  Color? _helperColor(String value) {
    final normalized = PokemonNameService.normalizeName(value);
    if (invalidNames.contains(normalized)) {
      return const Color(0xFFFCA5A5);
    }
    if (onlineValidNames.contains(normalized)) {
      return const Color(0xFF86EFAC);
    }
    return null;
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
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
  final _formStore = DraftFormStore();
  final _pokemonNames = PokemonNameService();
  final _title = TextEditingController(text: DraftFormStore.defaultTitle());
  final List<TextEditingController> _players = [];
  final List<FocusNode> _playerFocusNodes = [];
  final List<bool> _touchedPlayers = [];
  List<String> _pokemonNamePool = const [];
  Set<String> _localPokemonNames = const {};
  final Set<String> _validatingNames = {};
  final Set<String> _onlineValidNames = {};
  final Set<String> _invalidNames = {};
  final Random _random = Random();
  DraftGame _game = DraftGame.pokemon;
  TournamentFormat _format = TournamentFormat.bestOfOneTopCut;
  bool _showAllGames = false;
  bool _loadedDraft = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final snapshot = await _formStore.load();
    final names = await _pokemonNames.loadLocalNames();
    if (!mounted) {
      return;
    }
    setState(() {
      _pokemonNamePool = names;
      _localPokemonNames = names.map(PokemonNameService.normalizeName).toSet();
      _title.text = snapshot.title;
      _game = snapshot.game;
      _format = snapshot.format;
      _setPlayers(snapshot.players, snapshot.touchedPlayers);
      _loadedDraft = true;
    });
  }

  void _setPlayers(List<String> players, List<bool> touched) {
    for (final controller in _players) {
      controller.dispose();
    }
    for (final focusNode in _playerFocusNodes) {
      focusNode.dispose();
    }
    _players
      ..clear()
      ..addAll(players.map((name) => TextEditingController(text: name)));
    _playerFocusNodes
      ..clear()
      ..addAll(List.generate(players.length, _createPlayerFocusNode));
    _touchedPlayers
      ..clear()
      ..addAll([
        for (var i = 0; i < players.length; i += 1)
          i < touched.length ? touched[i] : false,
      ]);
  }

  FocusNode _createPlayerFocusNode(int index) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus ||
          index >= _players.length ||
          _touchedPlayers[index]) {
        return;
      }
      setState(() {
        _players[index].clear();
        _touchedPlayers[index] = true;
      });
      _saveDraft();
    });
    return node;
  }

  @override
  void dispose() {
    _title.dispose();
    for (final controller in _players) {
      controller.dispose();
    }
    for (final focusNode in _playerFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const PokoinAppBarTitle(title: 'New offline tournament'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_loadedDraft)
            const Center(child: CircularProgressIndicator())
          else
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    onChanged: (_) => _saveDraft(),
                    decoration: const InputDecoration(
                      labelText: 'Tournament name',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ChoiceSection<DraftGame>(
                    label: 'Game',
                    values: DraftGame.values,
                    selected: _game,
                    labelFor: (game) => game.label,
                    collapsible: true,
                    expanded: _showAllGames,
                    onToggleExpanded: () =>
                        setState(() => _showAllGames = !_showAllGames),
                    onSelected: (game) {
                      setState(() => _game = game);
                      _saveDraft();
                    },
                  ),
                  const SizedBox(height: 18),
                  _ChoiceSection<TournamentFormat>(
                    label: 'Format',
                    values: TournamentFormat.values,
                    selected: _format,
                    labelFor: (format) => format.label,
                    onSelected: (format) {
                      setState(() => _format = format);
                      _saveDraft();
                    },
                  ),
                  const SizedBox(height: 20),
                  _PlayerFields(
                    players: _players,
                    focusNodes: _playerFocusNodes,
                    validatingNames: _validatingNames,
                    onlineValidNames: _onlineValidNames,
                    invalidNames: _invalidNames,
                    onChanged: _saveDraft,
                    onAdd: _addPlayer,
                    onRemove: _removePlayer,
                  ),
                ],
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
      final missingNames = await _validatePlayerNames();
      if (missingNames.isNotEmpty) {
        setState(() {
          _error =
              'Check these Pokemon names: ${missingNames.join(', ')}. They were not found locally or in PokeAPI.';
        });
        return;
      }
      final tournament = await ref
          .read(localTournamentControllerProvider.notifier)
          .create(
            title: _title.text,
            game: _game,
            format: _format,
            playerNames: _players.map((controller) => controller.text).toList(),
          );
      if (mounted) {
        context.go('/tournament/${tournament.id}');
      }
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<List<String>> _validatePlayerNames() async {
    if (_game != DraftGame.pokemon) {
      return const [];
    }
    final enteredNames = _players
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final namesToCheck = enteredNames.where((name) {
      final normalized = PokemonNameService.normalizeName(name);
      return !_localPokemonNames.contains(normalized) &&
          !_onlineValidNames.contains(normalized);
    }).toList();
    if (namesToCheck.isEmpty) {
      return const [];
    }
    setState(() {
      _error = null;
      _validatingNames
        ..clear()
        ..addAll(namesToCheck.map(PokemonNameService.normalizeName));
      _invalidNames.removeAll(_validatingNames);
    });
    final missing = <String>[];
    for (final name in namesToCheck) {
      final normalized = PokemonNameService.normalizeName(name);
      try {
        if (await _pokemonNames.existsOnline(name)) {
          _onlineValidNames.add(normalized);
        } else {
          _invalidNames.add(normalized);
          missing.add(name);
        }
      } catch (_) {
        _invalidNames.add(normalized);
        missing.add(name);
      }
      _validatingNames.remove(normalized);
      if (mounted) {
        setState(() {});
      }
    }
    return missing;
  }

  void _addPlayer() {
    setState(() {
      _players.add(TextEditingController(text: _randomPokemonName()));
      _playerFocusNodes.add(_createPlayerFocusNode(_players.length - 1));
      _touchedPlayers.add(false);
    });
    _saveDraft();
  }

  void _removePlayer() {
    if (_players.length <= 4) {
      return;
    }
    setState(() {
      _players.removeLast().dispose();
      _playerFocusNodes.removeLast().dispose();
      _touchedPlayers.removeLast();
    });
    _saveDraft();
  }

  String _randomPokemonName() {
    final usedNames = _players
        .map((controller) => PokemonNameService.normalizeName(controller.text))
        .where((name) => name.isNotEmpty)
        .toSet();
    final availableNames = _pokemonNamePool
        .where(
          (name) => !usedNames.contains(PokemonNameService.normalizeName(name)),
        )
        .toList();
    if (availableNames.isEmpty) {
      return '';
    }
    return availableNames[_random.nextInt(availableNames.length)];
  }

  Future<void> _saveDraft() {
    return _formStore.save(
      DraftFormSnapshot(
        title: _title.text,
        game: _game,
        format: _format,
        players: _players.map((controller) => controller.text).toList(),
        touchedPlayers: _touchedPlayers,
      ),
    );
  }
}
