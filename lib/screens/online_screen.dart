import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/online_tournament_providers.dart';

class OnlineScreen extends ConsumerWidget {
  const OnlineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final balance = ref.watch(pknBalanceProvider).value ?? 0;
    final onlineTournaments = ref.watch(myOnlineTournamentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Online tournaments')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user == null ? 'Sign in with Pokoin' : 'Signed in',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user == null
                        ? 'Use your Pokoin account for invites, result reports, and ticketed events.'
                        : '${user.email ?? user.uid}\nAvailable PKN: $balance',
                  ),
                  const SizedBox(height: 16),
                  if (user == null)
                    FilledButton(
                      onPressed: () => _showSignInDialog(context),
                      child: const Text('Sign in'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Sign out'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Multiplayer tournament creation, player invites, report matching, conflict resolution, and PKN ticket escrow are wired through shared Firebase collections and trusted APIs.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'My online events',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          onlineTournaments.when(
            data: (items) {
              if (user == null) {
                return const Text('Sign in to see online tournaments.');
              }
              if (items.isEmpty) {
                return const Text('No online tournaments yet.');
              }
              return Column(
                children: [
                  for (final item in items)
                    Card(
                      child: ListTile(
                        title: Text('${item['title'] ?? 'Tournament'}'),
                        subtitle: Text(
                          '${item['game'] ?? 'game'} - ${item['format'] ?? 'format'} - ${item['status'] ?? 'status'}',
                        ),
                      ),
                    ),
                ],
              );
            },
            error: (error, _) => Text('Could not load online events: $error'),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  void _showSignInDialog(BuildContext context) {
    final email = TextEditingController();
    final password = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pokoin sign in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    ).whenComplete(() {
      email.dispose();
      password.dispose();
    });
  }
}
