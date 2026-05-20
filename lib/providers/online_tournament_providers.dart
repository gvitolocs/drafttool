import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/online_tournament_service.dart';

final onlineTournamentServiceProvider = Provider<OnlineTournamentService>((ref) {
  return OnlineTournamentService();
});

final myOnlineTournamentsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(onlineTournamentServiceProvider).myTournaments();
});
