# plane-mobile

[![CI](https://github.com/andrewkomkov/plane-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/andrewkomkov/plane-mobile/actions/workflows/ci.yml)
[![MegaLinter](https://github.com/andrewkomkov/plane-mobile/actions/workflows/megalinter.yml/badge.svg)](https://github.com/andrewkomkov/plane-mobile/actions/workflows/megalinter.yml)
[![Licence: AGPL v3](https://img.shields.io/badge/licence-AGPL--3.0-blue.svg)](LICENSE)

A Flutter client for a self-hosted [Plane](https://plane.so) instance.

Built against a real deployment rather than against Plane's public docs: the
feature list in [`docs/COVERAGE.md`](docs/COVERAGE.md) is derived from that
server's own route table, and every claim in it is either backed by a test or
marked as unverified.

> **Status:** works, used daily against one instance. Android is the platform
> that gets exercised; iOS compiles in CI but nobody runs it. The other four
> Flutter targets are unmodified scaffolding.

## What it does

Work items in all four of Plane's mobile-viable layouts — list, board, table,
calendar — with the full property set including estimates, cycles and modules;
comments, reactions, attachments, relations and sub-issues; cycles, modules,
pages, states, labels and saved views; the intake triage queue; workspace-wide
rollups; server-computed analytics; drafts; archives; and offline reads behind
a write queue that drains when the network returns.

What it deliberately does not do, and why, is in
[`docs/COVERAGE.md`](docs/COVERAGE.md).

## Architecture

```text
+-------------+   X-Api-Key    +------------------+   session cookie   +-------+
| Flutter app | -------------> | plane-mobile-api | -----------------> | Plane |
|             |                |   (the proxy)    |                    |  API  |
+-------------+                +------------------+                    +-------+
```

Plane has two APIs. The internal one (`/api/...`) carries the whole feature set
but authenticates by session cookie only. The external one (`/api/v1/...`)
accepts an API token but is a much smaller surface — no views, no reactions, no
relations, no analytics.

The app holds a token. [plane-mobile-api][sidecar] exchanges it for a real
Plane session and proxies through to the internal API, so **Plane's own
permission classes decide what the app may see**. The session lives entirely on
the proxy; the app never sees it and never stores one.

That indirection is the security model, and it is deliberate. A proxy cannot
have an "authenticates but does not authorise" bug, because the authorisation
is not ours to write — and every such bug this project has had came from a
hand-written handler that read Plane's tables directly. The sidecar's remaining
non-proxy routes are the ones that cannot be proxied: minting the token from a
Google or password sign-in, and registering a device for push.

[sidecar]: https://github.com/andrewkomkov/plane-mobile-api

## Requirements

- Flutter 3.44+ (Dart 3.12+)
- A self-hosted Plane instance you can administer
- [plane-mobile-api][sidecar] deployed alongside it

## Getting started

```sh
git clone https://github.com/andrewkomkov/plane-mobile
cd plane-mobile
flutter pub get
flutter run
```

The app asks for your instance URL and signs you in on first launch; there is
nothing to configure at build time.

### Releases and updates

Merging to `main` opens a release pull request via
[release-please](https://github.com/googleapis/release-please); merging that
tags the release and CI attaches a signed APK with its SHA-256. The app checks
those releases itself and can install one in place — see
`lib/services/update_service.dart` for the trust chain.

### Push notifications (optional)

Push needs a Firebase project. `android/app/google-services.json` is not in the
repository because it names a specific one — copy
[`google-services.json.example`](android/app/google-services.json.example) and
fill it in from your Firebase console. Without it the app builds and runs
normally and push is simply inert: the Gradle plugin is applied only when the
file is present, and `PushNotificationService.initialize` returns quietly when
Firebase is unavailable.

### Google sign-in (optional)

Signing in with Google needs an OAuth client of type **Android** in the same
Google Cloud project as the web client ID in `_googleServerClientId`
(`lib/screens/setup/setup_screen.dart`), which is the one the Plane instance is
configured with as `GOOGLE_CLIENT_ID`. Play services matches the client on the
package name together with the SHA-1 of the certificate the APK is signed with,
so every signing key needs its own fingerprint registered — the debug keystore
to run from source, the release keystore for anything CI builds:

```sh
keytool -list -v -keystore ~/.android/debug.keystore -storepass android \
  -alias androiddebugkey | grep SHA1
keytool -list -v -keystore android/upload-keystore.jks -alias <alias> | grep SHA1
```

Add each fingerprint to the Android app in the Firebase console under Project
settings, then confirm under APIs & Services → Credentials that an Android
OAuth client actually exists for it. Registering the fingerprint does not
reliably create the client — when it does not, create it there by hand with the
package name and the same SHA-1. Either way the change takes from five minutes
to a few hours to reach devices.

Miss this and sign-in fails as `canceled - [16] Account reauth failed`, which
names neither the certificate nor the client. The reason it stands for,
`UNREGISTERED_ON_API_CONSOLE`, is only ever visible in
`adb logcat -s Auth.Api.Credentials`. Email/password and API key sign-in do not
depend on any of this.

## Development

```sh
flutter analyze --fatal-infos --fatal-warnings   # must be clean
dart format --output=none --set-exit-if-changed .
flutter test                                     # 743 tests
flutter test --coverage                          # with lcov output
```

All three run on every push and every pull request, alongside
[MegaLinter](https://megalinter.io), an Android build and an iOS build. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).

`test/e2e/` boots real screens against a fake Plane instance
(`test/e2e/fake_plane.dart`) and asserts both what they draw and what they
send. Those run in CI; the `integration_test/` suite below does not.

### A workspace to look at

`tool/seed_demo.py` fills a workspace with a project that exercises every
screen — five states, every priority, six labels, three modules, a finished
sprint and a running one, sub-issues, comments, and a few work items
deliberately overdue so the analytics screen has something to count. It talks
to Plane's external API with a plain token, so it needs neither the proxy nor
a session:

```sh
PLANE_BASE_URL=https://plane.example.com \
PLANE_API_KEY=plane_api_... \
PLANE_WORKSPACE_SLUG=my-workspace \
  python3 tool/seed_demo.py
```

`--reset` removes only a project whose identifier is `AUR`; `--dry-run`
answers its own reads, so it prints what it would do without credentials.

### Integration tests

`integration_test/` drives the real app against a real instance, so it needs
credentials and does not run in CI:

```sh
flutter test integration_test \
  --dart-define=PLANE_BASE_URL=https://plane.example.com \
  --dart-define=PLANE_API_KEY=plane_api_...
```

## Documentation

| Document | What is in it |
| --- | --- |
| [`docs/COVERAGE.md`](docs/COVERAGE.md) | Feature coverage against the server's route table, and every server-side defect the app works around |
| [`docs/UX_SCREENS.md`](docs/UX_SCREENS.md) | Every screen, what it shows, and what it can do |
| [`docs/M3_EXPRESSIVE.md`](docs/M3_EXPRESSIVE.md) | The design system the app is built to |
| [`docs/M3E_AUDIT.md`](docs/M3E_AUDIT.md) | Audit of the app against that brief |

## Licence

[AGPL-3.0-only](LICENSE), matching Plane itself.

Not affiliated with or endorsed by Plane Software, Inc.
