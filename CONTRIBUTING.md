# Contributing

## Before you open a pull request

Three things have to hold, and CI checks all three:

```sh
flutter analyze   # zero findings, not "zero new findings"
flutter test      # every test green
```

plus [MegaLinter](https://megalinter.io), which covers the rest of the tree —
YAML, Markdown, JSON, shell, GitHub Actions, spelling, and a secrets scan.

To run the linter locally the way CI runs it:

```sh
npx mega-linter-runner --flavor dotnetweb
```

## Commits

[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
The release notes and the version bump are generated from them by
[release-please](https://github.com/googleapis/release-please), so the type and
scope are not decoration:

- `feat:` a minor bump, `fix:` a patch bump
- `feat!:` or a `BREAKING CHANGE:` footer for a major bump
- `docs:`, `test:`, `refactor:`, `chore:`, `ci:`, `build:`, `perf:`, `style:`
  do not bump anything

Write the description in lowercase, imperative mood, no trailing period:

```text
fix(inbox): keep a dismissed row dismissed across a refetch
```

## The house style

The code in this repository explains **why**, not what. A comment that
restates the line above it is noise; a comment that records the constraint
that forced the line is the reason the next person does not undo it. Most
comments here name a specific fact about Plane's API, a defect that was found
on a device, or a decision that looks wrong until you know what it avoids.

Two consequences worth stating outright:

- **When you work around a server-side defect, say so where the workaround
  is,** and add a row to `docs/COVERAGE.md`. That table is the only record of
  why several odd-looking calls exist.
- **Do not add a hand-written SQL handler to the sidecar.** Everything the app
  reads goes through the proxy, where Plane's permission classes run. Every
  authorisation bug this project has had came from a handler that
  authenticated the caller and then trusted the ids in the URL.

## Tests

New behaviour needs a test. The seam is usually an injected `Dio` — services
expose a `debugClient` for exactly this — with a hand-written
`HttpClientAdapter` answering from a routing table. See
`test/services/inbox_service_test.dart` for the pattern.

`docs/COVERAGE.md` marks a feature *verified* only when something proves it.
"I ran it on my phone" has twice missed real defects, including a crash that
killed the process. Prefer a test.

## Integration tests

`integration_test/` talks to a real Plane instance and is not part of CI. Run
it against a throwaway workspace:

```sh
flutter test integration_test \
  --dart-define=PLANE_BASE_URL=https://plane.example.com \
  --dart-define=PLANE_API_KEY=plane_api_...
```

## Reporting a security issue

See [`SECURITY.md`](SECURITY.md). Do not open a public issue.
