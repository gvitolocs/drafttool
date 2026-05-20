import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/online_screen.dart';
import 'screens/tournament_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await _initializeFirebase();
  runApp(const ProviderScope(child: DraftToolApp()));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Offline mode must remain usable even if Firebase is unavailable.
  }
}

class DraftToolApp extends StatelessWidget {
  const DraftToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DraftTool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) => const NewTournamentScreen(),
    ),
    GoRoute(
      path: '/online',
      builder: (context, state) => const OnlineScreen(),
    ),
    GoRoute(
      path: '/tournament/:id',
      builder: (context, state) {
        return TournamentScreen(tournamentId: state.pathParameters['id']!);
      },
    ),
  ],
);
