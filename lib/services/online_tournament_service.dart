import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/tournament_models.dart';

class OnlineTournamentService {
  OnlineTournamentService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection('drafttool_tournaments');

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('drafttool_invites');

  Stream<List<Map<String, dynamic>>> myTournaments() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }
    return _tournaments
        .where('participantUids', arrayContains: user.uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<String> createTournament({
    required TournamentConfig config,
    required List<String> inviteUsernames,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before creating an online tournament.');
    }
    final now = FieldValue.serverTimestamp();
    final doc = await _tournaments.add({
      'creatorUid': user.uid,
      'title': config.title,
      'game': config.game.name,
      'format': config.format.name,
      'status': TournamentStatus.setup.name,
      'ticketPkn': config.ticketPkn,
      'payoutSplits': config.payoutSplits
          .map((split) => split.toJson())
          .toList(),
      'participantUids': [user.uid],
      'inviteUsernames': inviteUsernames
          .map((username) => username.trim().toLowerCase())
          .where((username) => username.isNotEmpty)
          .toList(),
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  Future<void> createInvite({
    required String tournamentId,
    required String inviteeUid,
    required String inviteeUsername,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before inviting players.');
    }
    await _invites.add({
      'tournamentId': tournamentId,
      'inviterUid': user.uid,
      'inviteeUid': inviteeUid,
      'inviteeUsername': inviteeUsername.trim().toLowerCase(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportMatch({
    required String tournamentId,
    required int roundNumber,
    required String matchId,
    required MatchResult result,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before reporting a match.');
    }
    await _tournaments
        .doc(tournamentId)
        .collection('rounds')
        .doc('$roundNumber')
        .collection('matches')
        .doc(matchId)
        .collection('reports')
        .doc(user.uid)
        .set({
          ...result.toJson(),
          'reportedBy': user.uid,
          'reportedAt': FieldValue.serverTimestamp(),
        });
  }
}
