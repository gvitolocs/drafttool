import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseReadyProvider = Provider<bool>((ref) {
  return Firebase.apps.isNotEmpty;
});

final authStateProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(null);
  }
  return FirebaseAuth.instance.authStateChanges();
});

final pknBalanceProvider = StreamProvider<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || Firebase.apps.isEmpty) {
    return Stream.value(0);
  }
  return FirebaseFirestore.instance
      .collection('balances')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => (snapshot.data()?['availablePkn'] as num?)?.toInt() ?? 0);
});
