import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../models/tournament_models.dart';
import '../providers/auth_providers.dart';
import '../providers/online_tournament_providers.dart';
import '../wallet/wallet_bridge_stub.dart';
import '../widgets/pokoin_brand.dart';

class OnlineScreen extends ConsumerStatefulWidget {
  const OnlineScreen({super.key});

  @override
  ConsumerState<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends ConsumerState<OnlineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _wallet = createWalletBridge();
  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  bool _isWalletSubmitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final balance = ref.watch(pknBalanceProvider).value ?? 0;
    final onlineTournaments = ref.watch(myOnlineTournamentsProvider);

    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/online/new');
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const PokoinAppBarTitle(title: 'Online tournaments'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [Color(0x2238BDF8), Color(0x00050816)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (user != null) ...[
              _OnlineHero(
                balance: balance,
                label: user.email ?? user.displayName ?? user.uid,
                onSignOut: () => FirebaseAuth.instance.signOut(),
              ),
              const SizedBox(height: 16),
            ],
            if (user == null) ...[
              _InlineAuthSection(
                formKey: _formKey,
                email: _email,
                password: _password,
                confirmPassword: _confirmPassword,
                isLogin: _isLogin,
                isSubmitting: _isSubmitting,
                isGoogleSubmitting: _isGoogleSubmitting,
                isWalletSubmitting: _isWalletSubmitting,
                onToggleMode: () => setState(() => _isLogin = !_isLogin),
                onSubmit: _submitAuth,
                onGoogle: _signInWithGoogle,
                onWallet: _signInWithWallet,
              ),
            ] else ...[
              _Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: Color(0xFFFACC15),
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multiplayer event tools',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Invite Pokoin users, let players report wins from their own device, resolve conflicts, and finalize payout splits.',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (user != null) ...[
              const SizedBox(height: 16),
              Text(
                'My online events',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              onlineTournaments.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const _Panel(
                      child: Text(
                        'No online tournaments yet. Create one soon from this screen.',
                        style: TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.groups_2_outlined,
                              color: Color(0xFFFACC15),
                            ),
                            title: Text(
                              '${item['title'] ?? 'Tournament'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${item['game'] ?? 'game'} - ${item['format'] ?? 'format'} - ${item['status'] ?? 'status'}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
                error: (error, _) =>
                    Text('Could not load online events: $error'),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) {
        context.go('/online/new');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Signed in.' : 'Pokoin account created.'),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Pokoin sign in failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleSubmitting = true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters(<String, String>{'prompt': 'select_account'});
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        throw UnsupportedError('Google sign-in is currently available on web.');
      }
      if (mounted) {
        context.go('/online/new');
      }
    } on FirebaseAuthException catch (error) {
      _showAuthError(error.message ?? 'Google sign-in failed.');
    } catch (error) {
      _showAuthError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isGoogleSubmitting = false);
      }
    }
  }

  Future<void> _signInWithWallet() async {
    setState(() => _isWalletSubmitting = true);
    try {
      if (!_wallet.hasProvider) {
        if (_wallet.openMetaMaskDapp()) {
          return;
        }
        throw StateError('Install MetaMask or another EVM wallet first.');
      }
      await WalletSignInCoordinator.run(() async {
        final account = await _wallet.requestAccount();
        final address = account?.trim().toLowerCase();
        if (address == null || address.isEmpty) {
          throw StateError('No wallet account selected.');
        }
        final nonce = await _postJson('/api/wallet-auth/nonce', {
          'address': address,
        });
        final message = nonce['message'] as String? ?? '';
        if (message.isEmpty) {
          throw StateError('Wallet sign-in nonce was empty.');
        }
        final signature = await _wallet.signMessage(
          address: address,
          message: message,
        );
        final verified = await _postJson('/api/wallet-auth/verify', {
          'address': address,
          'signature': signature,
        });
        final customToken = verified['customToken'] as String? ?? '';
        if (customToken.isEmpty) {
          throw StateError('Wallet verification did not return a login token.');
        }
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
      });
      if (mounted) {
        context.go('/online/new');
      }
    } catch (error) {
      _showAuthError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isWalletSubmitting = false);
      }
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(payload['error'] as String? ?? 'Request failed.');
    }
    return payload;
  }

  void _showAuthError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _OnlineHero extends StatelessWidget {
  const _OnlineHero({
    required this.balance,
    required this.label,
    required this.onSignOut,
  });

  final int balance;
  final String label;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pokoin account',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 10),
          const PokoinMarkFrame(size: 58),
          const SizedBox(height: 8),
          Text(
            '$balance PKN',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Signed in as $label',
              style: const TextStyle(color: Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}

class _InlineAuthSection extends StatelessWidget {
  const _InlineAuthSection({
    required this.formKey,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.isLogin,
    required this.isSubmitting,
    required this.isGoogleSubmitting,
    required this.isWalletSubmitting,
    required this.onToggleMode,
    required this.onSubmit,
    required this.onGoogle,
    required this.onWallet,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final bool isLogin;
  final bool isSubmitting;
  final bool isGoogleSubmitting;
  final bool isWalletSubmitting;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onWallet;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 860;
    final children = [
      const _PokoinAuthStoryCard(),
      _PokoinAuthFormCard(
        formKey: formKey,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        isLogin: isLogin,
        isSubmitting: isSubmitting,
        isGoogleSubmitting: isGoogleSubmitting,
        isWalletSubmitting: isWalletSubmitting,
        onToggleMode: onToggleMode,
        onSubmit: onSubmit,
        onGoogle: onGoogle,
        onWallet: onWallet,
      ),
    ];
    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [children[0], const SizedBox(height: 16), children[1]],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 18),
              Expanded(child: children[1]),
            ],
          );
  }
}

class _PokoinAuthStoryCard extends StatelessWidget {
  const _PokoinAuthStoryCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PokoinMarkFrame(size: 58),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pokoin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Tournament profile + PKN wallet',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Use your Pokoin account for online tournaments.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Invite players, report results from multiple devices, protect PKN ticket escrow, and keep your tournament history connected to the same profile.',
            style: TextStyle(color: Color(0xFFCBD5E1), height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Color(0x22FACC15)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFFFACC15),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Login to unlock online tournaments, username invites, result reporting, and PKN ticket escrow.',
                    style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TrustPill(icon: Icons.groups_2_outlined, label: 'Invites'),
              _TrustPill(icon: Icons.shield_outlined, label: 'PKN escrow'),
              _TrustPill(icon: Icons.history_outlined, label: 'Event history'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PokoinAuthFormCard extends StatelessWidget {
  const _PokoinAuthFormCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.isLogin,
    required this.isSubmitting,
    required this.isGoogleSubmitting,
    required this.isWalletSubmitting,
    required this.onToggleMode,
    required this.onSubmit,
    required this.onGoogle,
    required this.onWallet,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final bool isLogin;
  final bool isSubmitting;
  final bool isGoogleSubmitting;
  final bool isWalletSubmitting;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onWallet;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isLogin ? 'Access your account' : 'Create your Pokoin account',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLogin
                  ? 'Continue with your Pokoin email and password.'
                  : 'Create an account to join online tournaments.',
              style: const TextStyle(color: Color(0xFF94A3B8), height: 1.45),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: isGoogleSubmitting ? null : onGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: Text(
                isGoogleSubmitting
                    ? 'Opening Google...'
                    : 'Continue with Google',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isWalletSubmitting ? null : onWallet,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(
                isWalletSubmitting
                    ? 'Opening MetaMask...'
                    : 'Continue with MetaMask',
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFF1E293B))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or use email',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFF1E293B))),
              ],
            ),
            const SizedBox(height: 18),
            _DarkTextField(
              controller: email,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _DarkTextField(
              controller: password,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            if (!isLogin) ...[
              const SizedBox(height: 14),
              _DarkTextField(
                controller: confirmPassword,
                label: 'Retype password',
                icon: Icons.lock_reset_outlined,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please retype your password';
                  }
                  if (value != password.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isLogin ? 'Sign in' : 'Create account'),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin
                      ? "Don't have an account?"
                      : 'Already have an account?',
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                TextButton(
                  onPressed: isSubmitting ? null : onToggleMode,
                  child: Text(isLogin ? 'Sign up' : 'Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFFACC15)),
      ),
      validator: validator,
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFACC15)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: padding, child: child),
    );
  }
}

class NewOnlineTournamentScreen extends ConsumerStatefulWidget {
  const NewOnlineTournamentScreen({super.key});

  @override
  ConsumerState<NewOnlineTournamentScreen> createState() =>
      _NewOnlineTournamentScreenState();
}

class _NewOnlineTournamentScreenState
    extends ConsumerState<NewOnlineTournamentScreen> {
  final _title = TextEditingController(text: 'Online tournament');
  final _invitees = TextEditingController();
  final _ticket = TextEditingController(text: '0');
  DraftGame _game = DraftGame.pokemon;
  TournamentFormat _format = TournamentFormat.bestOfOneTopCut;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _invitees.dispose();
    _ticket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/online');
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const PokoinAppBarTitle(title: 'Create online tournament'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [Color(0x2238BDF8), Color(0x00050816)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Panel(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Online event setup',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Invite Pokoin users, choose format, and optionally require a PKN ticket.',
                    style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Tournament name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OnlineChoiceSection<DraftGame>(
                    label: 'Game',
                    values: DraftGame.values,
                    selected: _game,
                    labelFor: (game) => game.label,
                    onSelected: (game) => setState(() => _game = game),
                  ),
                  const SizedBox(height: 16),
                  _OnlineChoiceSection<TournamentFormat>(
                    label: 'Format',
                    values: TournamentFormat.values,
                    selected: _format,
                    labelFor: (format) => format.label,
                    onSelected: (format) => setState(() => _format = format),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ticket,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ticket price in PKN',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _invitees,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Invite usernames, one per line',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _creating ? null : _create,
                    icon: const Icon(Icons.groups_2_outlined),
                    label: Text(
                      _creating ? 'Creating...' : 'Create online tournament',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final service = ref.read(onlineTournamentServiceProvider);
      final id = await service.createTournament(
        config: TournamentConfig(
          title: _title.text.trim().isEmpty
              ? 'Online tournament'
              : _title.text.trim(),
          game: _game,
          format: _format,
          mode: TournamentMode.online,
          ticketPkn: int.tryParse(_ticket.text.trim()) ?? 0,
        ),
        inviteUsernames: _invitees.text.split('\n'),
      );
      ref.invalidate(myOnlineTournamentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Online tournament created: $id')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }
}

class _OnlineChoiceSection<T> extends StatelessWidget {
  const _OnlineChoiceSection({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in values)
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
              ),
          ],
        ),
      ],
    );
  }
}
