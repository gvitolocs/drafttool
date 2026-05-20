# DraftTool

Standalone tournament pairings and event helper for Pokemon, Magic, and Yu-Gi-Oh drafts.

## Features

- Offline single-device Swiss tournaments with local persistence.
- BO1, BO3, and BO3 with top cut presets.
- Standings with match points, opponent match win percentage, game win percentage, and opponent game win percentage.
- Online mode foundation using the shared Pokoin Firebase project for auth, usernames, balances, invites, and reports.
- Trusted ticket API for PKN reservation, creator-defined payout splits, and refunds.

## Development

```bash
flutter pub get
flutter test
```

Run locally:

```bash
flutter run
```

## Web Deployment

DraftTool is standalone. Deploy it separately from CardVault/Pokoin, ideally on `makepair.pokoin.com`.

```bash
./deploy-drafttool-web.sh
```

The existing `pokoin.com/makepair` route should redirect to `https://makepair.pokoin.com` when the standalone deployment is ready.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
