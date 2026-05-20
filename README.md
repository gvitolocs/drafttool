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
flutter analyze
flutter test
npm run check
```

Create a local env file before running the app:

```bash
cp .env.example .env.local
# Fill FIREBASE_* client config values in .env.local.
```

Run locally:

```bash
flutter run -d chrome $(./tool/flutter_env.sh)
```

## Web Deployment

DraftTool is standalone. Deploy it separately from CardVault/Pokoin, ideally on `makepair.pokoin.com`.

```bash
./deploy-drafttool-web.sh
```

The existing `pokoin.com/makepair` route should redirect to `https://makepair.pokoin.com` when the standalone deployment is ready.

## Workflows

Operational notes live in [`workflows/README.md`](workflows/README.md).

CI checks live in [`.github/workflows/checks.yml`](.github/workflows/checks.yml).

## Notes

DraftTool is not part of the CardVault/Pokoin Flutter app. Keep web deployment,
mobile packaging, and tournament APIs independent.
