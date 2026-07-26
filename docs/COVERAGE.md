# Feature coverage against Plane self-hosted

What the mobile app does and does not implement, measured against the Plane
server this deployment actually runs.

**Reference:** `~/PycharmProjects/Plane.so`, Plane **v1.2.0** — a fork, not
stock. The feature list is derived from that server's own route table, not from
Plane's public documentation.

**The reference is `apps/api/plane/app/urls/` — the internal API.** That is what
the app talks to. It did not always: the app authenticates with an API token,
which only reaches Plane's external v1 API, and it was calling the internal
API's route names against it. `plane-mobile-api` now exchanges the token for a
real Plane session and proxies through, so the internal surface — and Plane's
own permission classes — apply. See `lib/config/api_client.dart`.

**Method:** every path literal in `lib/` extracted and matched against the
server routes. 50 client paths; exactly one has no internal route
(`github-repositories/`). Behaviour marked *verified* was exercised on a
Galaxy S20 FE against the live instance; *wired* means the code exists and
compiles but no one has watched it work.

## Summary

| | Areas |
|---|---|
| Covered | 18 |
| Partial | 5 |
| Missing | 9 |

Everything that was structurally unreachable is now reachable. What remains
missing is missing because nobody has built it, not because the transport
forbids it — which was not true of this document's first two versions.

## Covered

| Area | Notes |
|---|---|
| Work items — core | list / detail / create / update / delete — *verified* |
| Work item views | List, Board, Table, Calendar — four of Plane's five |
| Work item properties | state, priority, assignees, labels, parent, dates, **estimate**, **cycle**, **module** |
| Reactions | on work items and on comments — *verified*, round-trips and removes |
| Subscription | subscribe/unsubscribe on a work item |
| Relations | read and write, all four kinds, plus sub-issue create and adopt |
| Comments | list, add, edit, delete, reactions |
| Attachments | list / upload / delete |
| Activity feed | *verified* — requires `activity_type`, see below |
| Archive | work items, cycles, modules, pages; archived listings — *verified* |
| Cycles | CRUD, issues, archive |
| Modules | CRUD, issues, archive |
| Pages | CRUD including delete, archive |
| States | full CRUD |
| Labels | full CRUD |
| Saved views | project-level CRUD — *verified* (this was the screen that failed outright) |
| Members | roles, invite, change role, remove, leave, pending invitations — *verified* |
| Notifications | list, read/unread, archive, mark-all-read, preferences |

## Partial

| Area | Has | Missing | Pri |
|---|---|---|---|
| Analytics | every figure is now server-computed — `advance-analytics/`, `advance-analytics-charts/`, `advance-analytics-stats/`, and `default-analytics/` for the overdue count. Five requests where the sweep took up to 45. A panel the server does not answer for is named as missing rather than drawn as a zero | the date-range and per-dimension filters Plane's own analytics page offers (assignee, label, cycle, estimate); `export-analytics/` | P3 |
| Intake | `intake_service.dart` is correct and current | **no UI reaches it.** The "Inbox" tab is the notification feed, not this queue | P2 |
| Search | on Plane's own `workspaces/{slug}/search/` through the proxy, so `GlobalSearchEndpoint` filters every entity on project membership — *verified* | `entity-search/` and the per-project `search-issues/` are not used | P3 |
| Estimates | a work item's estimate point can be set | estimate *scales* cannot be created or managed | P3 |
| Projects | list, detail, settings, members | **create** (deliberate), archive, join, leave | P3 |

## Missing

| Area | What it is | Pri |
|---|---|---|
| **Workspace-level rollups** | `workspaces/{}/issues/`, `views/`, `cycles/`, `modules/` — cross-project views. Mobile is project-scoped | P2 |
| **Favorites** | `user-favorites/` and the per-entity favorite routes | P2 |
| **Draft work items** | `draft-issues/`, `draft-to-issue/{}/`. Drafts made on web are invisible here | P2 |
| **Trash / restore** | `deleted-issues/`, asset restore. Deleting on mobile is unrecoverable there | P2 |
| **Description history** | `issues/{}/versions/`, `work-items/{}/description-versions/`. The activity feed is covered; description history is not | P3 |
| **Exports** | `export-issues/`, `export-analytics/`, `user-activity/{}/export/` | P3 |
| **Home widgets** | stickies, quick links, the workspace home dashboard | P3 |
| **Webhooks & API tokens** | management UI. The app mints a token for its own auth and exposes nothing | P3 |
| **Bulk operations** | `bulk-archive-issues/`, `bulk-delete-issues/`, `bulk-create-labels/` | P3 |

Also absent, reasonably: **Gantt** (the fifth view type), **AI assistant**,
**Unsplash** covers, and GitHub integration beyond a read-only repo list —
`github-repositories/` is the one path the app calls that no internal route
serves, so it fails today.

## Server defects found while building this

These are bugs in Plane, not in the app. Each is worked around, and the
workaround is commented where it lives.

| Defect | Consequence |
|---|---|
| `issues/{id}/history/` 500s without `activity_type` | the view sorts unserialised model instances as dicts. The app always passes it |
| Cycle archive with no end date 500s | `end_date` is nullable and compared unguarded. `Cycle.canArchive` stops the app sending one |
| `archived-cycles/{id}/`, `archived-modules/{id}/` look writable | their `post`/`delete` take an argument the URL never supplies. Both directions go to `.../{id}/archive/` |
| `pages/` never filters `archived_at` | archived pages have always been mixed into the mobile page list |
| `DELETE pages/{id}/` requires prior archiving | the delete action added earlier failed on every live page |
| `fields=` is discarded in `DynamicBaseSerializer` | `projects/{id}/members/` returns `member` as a bare id, so every Member had an empty name and assignee lookups matched nothing. Fixed by joining the workspace list, as Plane's web client does |
| Project invitation endpoint 500s twice | reads `.role` off a queryset, calls `.delay` on a list. Invite-by-email is offered only at workspace level |
| Comment PATCH/DELETE guarded by `ProjectLitePermission` alone | any project member may rewrite anyone's comment. The app gates on authorship instead |
| `ProjectMemberViewSet.partial_update` admits guests | a project guest can demote a project admin. The app gates on admin |

## Architectural risk

Two capabilities still route through `plane-mobile-api`'s own SQL handlers
rather than the proxy: the **Inbox notification feed** and `issue-info`, plus
auth and device registration.

Those handlers authenticated but did not authorise. This was demonstrated, not
suspected: the page handlers filtered by `project_id` with no membership check,
and `get_page` filtered on page id alone, so any valid token in the instance
could read or rewrite any page in any workspace. The notification feed selected
activity rows by workspace slug alone, with the same result.

Pages and search were moved onto Plane's own API and their handlers deleted.
The notification feed could not follow — Plane's own notifications table is
empty on this instance while the derived feed has entries, so pointing the
Inbox at it would empty a feed in use. It is authorised properly instead: the
caller must be a workspace member, and the query joins `project_members` so it
only returns activity from projects that caller belongs to. Worth revisiting
once it is known why Plane is not populating its own table.

The proxy is the pattern to prefer for anything new: it cannot have this class
of bug, because the authorisation is not ours to get wrong.

## Known gaps in this document

Coverage here is *capability*, established by reading routes and by exercising
the app on a device. It is not a test suite. An area marked covered can still
be wrong in ways only a user will find — which is exactly how the process-killing
ButtonGroup crash and the dead work-item screen survived earlier rounds of
"verified on device".
