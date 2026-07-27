# Security

## Reporting a vulnerability

Use [GitHub's private advisory form][advisory] rather than a public issue.

[advisory]: https://github.com/andrewkomkov/plane-mobile/security/advisories/new

Please include what you were able to reach, and with what credentials — the
distinction between "a valid token" and "a token for a member of that project"
is the one that matters most here.

## What this project's threat model actually is

The app holds a Plane API token and nothing else. It never sees or stores a
session cookie. Everything it reads and writes goes through
[plane-mobile-api][sidecar], which exchanges the token for a real Plane session
server-side and proxies to Plane's internal API, so **Plane's own permission
classes decide what the app may see**.

That is deliberate, and it is the answer to the only class of bug this project
has repeatedly had: a hand-written handler that authenticated the caller and
then trusted the ids in the URL. Every one of those is gone. The routes that
remain outside the proxy are the ones that cannot be inside it:

| Route | Why it cannot be proxied |
| --- | --- |
| `google-auth/`, `password-auth/` | They mint the token. There is nothing to proxy with yet. |
| `register-device/` | Writes to the push service's own device table, and only ever the caller's own row. |

**Do not add a route that reads Plane's tables directly.** If something is
missing, it is missing from the proxy path, and that is where to add it.

[sidecar]: https://github.com/andrewkomkov/plane-mobile-api

## Things that are not vulnerabilities

- **`android/app/google-services.json` is absent from the repository.** If you
  supply your own, note that a Firebase client config is meant to be shipped
  inside an app; it is not a secret. Protect the project with Firebase security
  rules, not by hiding the file.
- **The app installs its own updates.** It downloads a release APK, checks it
  against the SHA-256 published beside it, and hands it to Android's package
  installer. Android refuses a package signed with a key other than the one
  that signed the installed app, and the user confirms every install. See
  `lib/services/update_service.dart`.

## Supported versions

The latest release. This is a client for a self-hosted service maintained by
one person; there is no backport branch.
