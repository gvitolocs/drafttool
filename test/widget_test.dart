import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drafttool/main.dart';
import 'package:drafttool/models/tournament_models.dart';
import 'package:drafttool/providers/tournament_providers.dart';
import 'package:drafttool/services/local_tournament_store.dart';

void main() {
  testWidgets('DraftTool app renders home screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localTournamentStoreProvider.overrideWithValue(_MemoryStore()),
        ],
        child: const DraftToolApp(),
      ),
    );

    await tester.pump();
    expect(find.text('DraftTool'), findsWidgets);
    expect(find.text('New offline tournament'), findsOneWidget);
  });
}

class _MemoryStore extends LocalTournamentStore {
  @override
  Future<List<DraftTournament>> loadAll() async => const [];

  @override
  Future<void> save(DraftTournament tournament) async {}
}
