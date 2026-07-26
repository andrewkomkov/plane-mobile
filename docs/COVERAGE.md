# Feature coverage against Plane self-hosted

What the mobile app does and does not implement, measured against the Plane
server this deployment actually runs.

**Reference:** `~/PycharmProjects/Plane.so`, Plane **v1.2.0** — a fork, not
stock (it carries local commits adding workspace-level Pages and a v1 pages
API). The feature list below is derived from that server's own route table
(`apps/api/plane/app/urls/*.py`, ~250 routes across 20 modules), not from
Plane's public documentation, so it reflects what this instance can do.

**Method:** static. Every path literal in `lib/` was extracted and matched
against the server routes — 55 client paths against ~250 server routes. This
finds absent capability. It does not find broken capability: a feature listed
as covered here is *wired*, not *verified working*. Anything marked ⚠ is a
correctness risk found by reading, not by running.

**Not counted as gaps.** Much of the server surface is not user-facing
feature: `user-properties`, `home-preferences`, `sidebar-preferences`,
`recent-visits`, `tour-completed`, `onboard`, `project-deploy-boards`,
`instance-admin`. Missing those is not a coverage hole, and they are left out
of the table rather than padding it.

## Summary

| | Areas |
|---|---|
| Covered | 9 |
| Partial | 11 |
| Missing | 13 |

The shape of the gap: the app is a solid **work-item client** — issues,
cycles, modules, views, labels, states, comments, attachments and
notifications are all real. What it does not have is (a) the **collaboration
layer** on top of work items — reactions, subscribers, relations, comment
editing; (b) **anything archived, deleted or drafted**; and (c) the
**workspace-administration** surface — members, invitations, estimates,
webhooks, exports.

## Covered

| Area | Notes |
|---|---|
| Work items — core CRUD | list / detail / create / update / delete, `issue_service.dart` |
| Work item views | List, Board (kanban), Table (spreadsheet), Calendar — four of Plane's five |
| Cycles | CRUD plus add/remove issues, `cycle_service.dart` |
| Modules | CRUD plus add/remove issues, `module_service.dart` |
| States | full CRUD including per-project state management |
| Labels | full CRUD |
| Attachments | list / upload / delete |
| Project views | saved views CRUD at project level |
| Notifications | list, read/unread, archive, mark-all-read, preferences |

## Partial

| Area | Has | Missing | Pri |
|---|---|---|---|
| Work item fields | state, priority, assignees, labels, parent, start/target date | **estimate point**, cycle and module assignment from the item itself | P1 |
| Comments | list, add | **edit, delete**, reactions | P1 |
| Sub-issues | read; can set `parent` on an item | creating/linking a sub-issue from the parent | P2 |
| Issue relations | read (`getIssueRelations`) | **add/remove** — blocks/blocked-by/duplicate/relates-to are read-only | P2 |
| Issue links | list, add | **edit, delete** | P3 |
| Pages | list, get, create, update | **delete**, versions, lock, archive, duplicate, access control | P2 |
| Projects | list, detail, update settings | **create** (deliberate — see M3_EXPRESSIVE.md), archive, join, leave | P2 |
| Members | read workspace + project members | **invite, remove, change role** | P2 |
| Workspaces | list, switch, update | invitations, themes, slug check | P3 |
| Intake / Inbox | list and triage via `inboxes/{}/inbox-issues/` | ⚠ uses the **legacy** route; this server also serves `intakes/` and `intake-issues/`, and Plane renamed the feature. Working today, deprecation risk | P2 |
| Analytics | a screen that computes counts client-side from fetched issues | the server's own `analytics/`, `advance-analytics*`, `project-stats`, `export-analytics` — so numbers are limited to what the app already paged in, and will disagree with web on large projects | P1 |

## Missing

| Area | What it is | Pri |
|---|---|---|
| **Reactions** | emoji reactions on work items and comments (`issues/{}/reactions/`, `comments/{}/reactions/`). No trace in `lib/` | P1 |
| **Subscribers** | subscribe/unsubscribe to a work item (`issue-subscribers/`, `subscribe/`). Drives who gets notified — the app has push notifications but no way to control subscription | P1 |
| **Archive** | archiving and archived listings for work items, cycles, modules, pages (`archived-issues/`, `archived-cycles/`, `archived-modules/`, `{}/archive/`). Archived content is invisible and uncreatable on mobile | P1 |
| **Trash / restore** | `deleted-issues/`, asset restore. Deleting on mobile is unrecoverable there | P2 |
| **Draft work items** | `workspaces/{}/draft-issues/`, `draft-to-issue/{}/`. Drafts made on web are invisible on mobile | P2 |
| **Estimates** | estimate definitions and points (`estimates/`, `estimate-points/`). `display_options.dart` references estimates for display only; they cannot be set or managed | P2 |
| **Workspace-level views & issues** | `workspaces/{}/views/`, `workspaces/{}/issues/`, `workspaces/{}/cycles/`, `workspaces/{}/modules/` — cross-project rollups. Mobile is project-scoped only | P2 |
| **Favorites** | `user-favorites/`, per-entity favorite endpoints for projects, cycles, modules, views, pages. Nothing in `lib/` | P2 |
| **Exports** | `export-issues/`, `export-analytics/`, `user-activity/{}/export/` | P3 |
| **Home widgets** | stickies (`stickies/`), quick links (`quick-links/`), the workspace home dashboard | P3 |
| **Webhooks & API tokens** | `webhooks/`, `webhook-logs/`, `service-api-tokens/`. The app creates a token for its own auth but exposes no management UI | P3 |
| **Work item history versions** | `issues/{}/versions/`, `work-items/{}/description-versions/`. Activity feed is covered; description history is not | P3 |
| **Bulk operations** | `bulk-archive-issues/`, `bulk-delete-issues/`, `bulk-create-labels/` | P3 |

Also absent, deliberately or reasonably: **Gantt** (the fifth view type — the
other four exist), **AI assistant** (`ai-assistant/`), **Unsplash** covers,
**Slack/GitHub integrations** beyond read-only GitHub repo listing.

## Architectural risk worth flagging

The app does not talk only to Plane. Four capabilities route through the
separate `plane-mobile-api` FastAPI service, which reaches into Plane's
**PostgreSQL directly** rather than through Plane's API:

| Path | Feature |
|---|---|
| `/auth/mobile/{slug}/search/` | global search |
| `/auth/mobile/{slug}/projects/{id}/pages/` | pages list/get/create/update |
| `/auth/mobile/{slug}/notifications/` | notification list, read, dismiss |
| `/auth/mobile/register-device/`, `workspaces/`, `issue-info/` | auth, push, workspace list |

Two consequences. First, those features bypass Plane's permission checks and
serialisers, so they can drift from what the web app enforces. Second, a Plane
schema change breaks them silently — the service's own history shows this
(`fix pages SQL: use project_pages join table instead of project_id column`).
Pages in particular exist on **both** paths: `page_service.dart` calls the
shim, while `/workspaces/{}/projects/{}/pages/` also appears in `lib/`. Worth
settling on one.

## What to do about it

Filed as tasks, highest value first:

1. Reactions + subscribers — the two most-used collaboration features, both
   entirely absent, both small (one service each).
2. Archive support — currently a whole class of content is unreachable.
3. Comment edit/delete — users can create comments they cannot fix.
4. Estimate point on the work item, plus cycle/module assignment from the item.
5. Analytics against the server's endpoints instead of client-side counting.
6. Intake: migrate to the `intakes/` routes before the legacy ones go.
7. Issue relations write path.
8. Members: invite / remove / role.
9. Settle pages on one backend.

P3 items above are recorded here but not filed — they are real gaps, not
planned work.
