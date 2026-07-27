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
server routes; exactly one has no internal route (`github-repositories/`).
What "covered" is worth, and what backs it, is set out at the end of this
document — read that before trusting a row. Behaviour marked *verified* was
exercised on a Galaxy S20 FE against the live instance, which is worth less
than a test and is labelled separately for that reason.

## Summary

| | Areas |
|---|---|
| Covered | 25 |
| Partial | 1 |
| Missing | 0 |

Everything that was structurally unreachable is now reachable, and the five
areas this document listed as missing are built. One area is still partial and
is named as such below.

The app no longer reaches Plane's data any way but through the proxy. The
three routes still served by `plane-mobile-api` are the ones that cannot be
proxied — two that mint the token and one that registers a device for push —
and none of them reads Plane's tables on the caller's behalf.

## Covered

| Area | Notes |
|---|---|
| Work items — core | list / detail / create / update / delete — *verified* |
| Work item views | List, Board, Table, Calendar — four of Plane's five |
| Work item properties | state, priority, assignees, labels, parent, dates, **estimate**, **cycle**, **module** |
| Reactions | on work items and on comments — *verified*, round-trips and removes |
| Subscription | subscribe/unsubscribe on a work item |
| Relations | read and write, all four kinds, plus sub-issue create and adopt |
| Comments | list, add, edit, delete, reactions — *verified* end to end on a device: posted, edited and deleted |
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
| Workspace rollups | cross-project work items (paginated), workspace saved views incl. delete, cycles, modules — from the More menu. `workspaces/{}/states/` and `.../labels/` resolve the ids, which the project-scoped calls cannot |
| Favorites | projects, cycles, modules, views and pages, starred from their list rows — *verified*, a star round-trips and unstars. On `user-favorites/`, not the per-entity routes; see below |
| Inbox | Plane's notification feed merged with the caller's own activity, both through the proxy. Read and archive on a notification are Plane's; the marks on an activity row are this device's, because the server has nowhere to keep them. See *Architectural risk* for why both feeds are needed |
| Intake | Open/Closed tabs, the server's whole action set — accept, decline, snooze, un-snooze, mark duplicate — plus submitting into the queue and deleting an entry |
| Search | workspace-wide on `workspaces/{slug}/search/`, and project-scoped work items on `search-issues/` for the parent, relation and duplicate pickers — *verified* |
| Draft work items | list, edit, promote, discard, and "Save draft" on the create screen, carrying every field a work item has |
| Estimates | a work item's point, and the scales those points come from — create and delete |
| Projects | list, detail, members, settings, archive and unarchive, leave; cycles, modules, pages and views can be created, gated on the caller's role — *verified* |
| Description history | `work-items/{id}/description-versions/`, with restore |
| Exports | `export-issues/` and `export-analytics/`, both queued server-side |
| Home widgets | stickies and quick links, both per-user |
| Webhooks & API tokens | list, create, revoke; webhook pause, secret roll and delete |
| Bulk operations | archive and delete a selection from the work-item list |
| Self-update | checks this repository's GitHub releases, verifies the download against its published SHA-256 and hands it to Android's package installer |

## Partial

| Area | Has | Missing | Pri |
|---|---|---|---|
| Analytics | every figure is server-computed — `advance-analytics/`, `advance-analytics-charts/`, `advance-analytics-stats/`, and `default-analytics/` for the overdue count. Five requests where the sweep took up to 45. A panel the server does not answer for is named as missing rather than drawn as a zero. **`export-analytics/` is wired** to an action on the screen | the date-range picker and the per-dimension filters Plane's own analytics page offers (assignee, label, cycle, estimate) | P3 |

That is the whole of what is partial. Everything else this table used to hold
is now in *Covered* above:

- **Intake** gained submitting into the queue and deleting an entry. Two
  things the routes do not advertise, both commented where they live:
  `IntakeIssueViewSet.create` reads the work item **nested under `issue`** and
  overwrites whatever state is sent with the project's triage state; and
  `destroy` deletes the **work item as well** for anything not yet accepted,
  so deleting a submission is not the same as declining it.
- **Search** gained the project-scoped `search-issues/`, which is a different
  endpoint from global search rather than a filtered call to it: it exists to
  feed the pickers that need work items and nothing else, and takes the flags
  that make parent and relation pickers correct. It answers with a bare list
  of `.values()` rows, so the keys are `project__identifier`-style rather than
  serialised.
- **Estimates** gained scale management. The app could put a point on a work
  item but not create the scale those points come from, so a project never set
  up on the web had no estimates and no way to gain them.
- **Projects** gained archive and unarchive. Archiving deletes every
  `UserFavorite` pointing at the project, and unarchiving does not bring them
  back — for anyone — so the confirmation says so. Leaving was already covered.
  Project *create* stays deliberately absent; projects are made on the web.
- **Draft work items** gained the rest of a work item's fields. The editor
  carried title, description, state and priority, which meant a draft written
  on the web showed its assignees and labels on the screen and lost them the
  moment it was saved. It now carries assignees, labels, both dates, the cycle
  and the modules, and sends all of them on every write — empty included,
  because an omitted key leaves the previous value standing.

A draft keeps its cycle and modules on the row and a work item does not:
`IssueCreateSerializer` has no cycle or module field at all, so those are
written afterwards against collections that need an id the create has to
return first. `cycle_id` on a draft has to be under that exact name — the view
lifts it out of `request.data` into the serializer context, and the usual
rename would be dropped in silence.

Two more things about drafts that the route names do not tell you. They are
**workspace-scoped and single-user**: `workspaces/{slug}/draft-issues/` has no
project segment, a draft's project is a nullable column, and the list filters
on `created_by=request.user` with no parameter that widens it — nobody can see
anyone else's drafts. And **`Issue.is_draft` is dead**. It is still in the
internal serialiser's field list and `IssueManager` still excludes it, but
migration 0077 moved every `is_draft=True` row into the separate `DraftIssue`
table and nothing writes the flag any more. A draft is a different model, not a
work item with a bit set, which is why it has no `sequence_id` and can never
render as `PLM-123`.

## Missing

Nothing. The five areas this section listed are built:

| Was missing | Where it is now |
|---|---|
| **Description history** | An action on the work-item menu, on `work-items/{id}/description-versions/`. Note the route says `work-items`, not `issues` — one of the few places Plane's newer naming reached the internal API. The sibling `issues/{id}/versions/` is a different thing. The listing omits the body and only the detail carries it, so opening a version is a second request. Restoring goes through the normal update path, so it becomes the newest version in turn |
| **Exports** | `export-issues/` from the workspace menu and `export-analytics/` from the analytics screen. Both queue a background job and answer immediately; nothing is downloaded and nothing arrives on the device, which is what the confirmation says |
| **Home widgets** | Stickies and quick links, on one screen. Both are per-user server-side — the views filter on the caller and set the owner themselves — so there is no request shape that reaches anyone else's, and the screen says so. The workspace home *dashboard* is still not drawn: `users/me/workspaces/{}/dashboard/` is a stats endpoint, and the app's analytics screen already answers what it would say |
| **Webhooks & API tokens** | One settings screen. This was the gap with the sharpest edge: the app mints a token for its own sign-in and had no way to show you that it had, let alone revoke it. A secret is shown once with a copy button, because Plane hashes an API token immediately and never sends it again. Webhooks are workspace-admin only, so a member is told that rather than shown an empty list |
| **Bulk operations** | Long-press a row in the work-item list to select; a bar offers archive and delete. Archiving filters the selection first — Plane refuses anything not completed or cancelled and answers 400 naming the first offender rather than archiving the rest. `bulk-create-labels/` has a service and no screen: it is not something a selection of work items can ask for |

Also absent, reasonably: **Gantt** (the fifth view type), **AI assistant**,
**Unsplash** covers, and GitHub integration beyond a read-only repo list —
`github-repositories/` is the one path the app calls that no internal route
serves, so it fails today.

## Not missing — not offered: trash and restore

Deleting a work item on mobile is unrecoverable, and it cannot be made
recoverable against this server. This was previously listed as a P2 gap. It is
not a gap; there is nothing to build.

`DELETE issues/{id}/` is a soft delete — `Issue` extends `SoftDeleteModel`, so
the row survives with `deleted_at` set and a background task soft-deletes its
children. The data is therefore still there. What is not there is any way back:

- **No restore route exists for work items.** The only `restore` handlers in
  the whole API are for file assets (`assets/v2/workspaces/{}/restore/{}/`).
  Nothing clears `deleted_at` on an issue, and no serialiser accepts it as a
  writable field, so there is no PATCH that would do it either.
- **`projects/{id}/deleted-issues/` is not a trash listing.** Despite the name
  it returns a bare JSON array of UUIDs — `values_list("id", flat=True)` over
  everything archived *or* deleted — with no names, states or timestamps. It
  exists so a client with a local database can prune rows it has cached. Plane's
  own web client has a `getDeletedIssues` method for it and calls it from
  nowhere.
- A listing built on it could show a column of UUIDs and offer no action on
  any of them. That is the "listing that can only look at things" this was
  explicitly not to become.

**The recoverable path is archiving, which the app already has.** Archive and
unarchive both round-trip, and archived work items are one of the three
listings on the work-item list. If the complaint is "delete is final on
mobile", the answer available today is to archive instead — the delete
confirmation on the work-item detail screen is where that would be said, and
that screen is not this change's to edit.

Restoring would need a server change: an endpoint that clears `deleted_at`, and
a listing endpoint that returns the deleted rows rather than their ids.

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
| `workspaces/{}/cycles/` and `.../modules/` never check project membership | they select on `workspace__slug` alone behind `WorkspaceViewerPermission`, so any workspace member reads the cycles and modules — names, dates, issue counts — of every project in the workspace, including ones they are not in. The sibling `workspaces/{}/issues/` does filter. The rollup screens drop any row whose project is not in the caller's own project list |
| `workspaces/{}/workspace-views/` is not a view list | `WorkspaceMemberUserViewsEndpoint` is POST-only and writes `view_props` onto the caller's workspace membership. A GET is a 405. The workspace saved views are at `workspaces/{}/views/` |
| `WorkspaceViewViewSet.retrieve` has no permission decorator and no 404 | every other action on it carries `@allow_permission`; this one does not, and it serialises whatever `.first()` returned. For a view that does not exist, or is private to someone else, `IssueViewSerializer(None).data` is DRF's initial-value dict, so the caller gets a 200 and an empty view rather than a 404 |
| `IssueView` has no `query_data` field | the model holds `filters` and the compiled `query`. `PlaneView` read `query_data`, so its filter set was empty for every view the server ever sent and a saved view listed the whole project. Fixed — it reads `filters` now. `view_list_screen` still posts the old key on create, which the serializer discards |
| `WorkspaceCyclesEndpoint`/`WorkspaceModulesEndpoint` read `order_by` from `self.kwargs` | that is the URL kwargs, which never contain it, so the `order_by` query parameter is silently ignored and the order is always `-created_at` |
| `CycleSerializer` omits `created_at` and `archived_at` | so a cycle from any endpoint using it — including the workspace rollup — has a fabricated `createdAt` and always reads as not archived. Harmless only because nothing sorts cycles by creation |
| Draft retrieve and update guard the wrong model | both are decorated `creator=True, model=Issue` while the pk is a `DraftIssue` id, so the "you made it" fallback can never match — `Issue.objects.filter(id=<draft id>)` is always empty. `retrieve` allows only `ROLE.ADMIN` besides, so a workspace member cannot fetch their own draft at all. The app never calls `retrieve`: the list serialiser already includes `description_html`, so the listing carries everything the detail would |
| `draft-to-issue/{id}/` does not copy the draft | it builds the work item out of `request.data` alone, takes only the project from the draft row, then deletes the row. Post an empty body and you get an empty work item and a destroyed draft. The app re-sends the whole draft, merged with any unsaved edits |
| Every per-entity favorites `list` action 500s | `CycleFavoriteViewSet` and friends are `BaseViewSet`s with `model = UserFavorite` and no `serializer_class`, so DRF's `get_serializer_class` assertion fires. There is no working read on that side of the feature at all, which is why the app uses the generic `user-favorites/` collection for everything |
| `projects/` drops the `is_favorite` annotation | `ProjectViewSet.get_queryset` annotates it and `ProjectViewSet.list` then builds its own `.values(...)` projection without it. Only `projects/details/` keeps it, so the project list cannot tell which projects are starred and the app reads that from `user-favorites/` like everything else |
| `views/` create takes `filters`, not `query_data` | there is no `query_data` field on `IssueView`; the serializer discards the unknown key without complaining, so a view created with it silently saves no filters |
| `notification_task` never notifies the actor | line 286 excludes `actor_id` from the subscriber set and line 309 subtracts it again. On a deployment where one person does the work, no `Notification` row is ever written and `users/notifications/` correctly returns nothing. Not a bug — but it is the reason the Inbox merges Plane's notifications with `user-activity/{me}/` rather than reading notifications alone |
| v1 `CycleSerializer.validate` reads `project_id` from the request body | its sibling `ModuleSerializer` reads the same value from the serializer context the view fills in from the URL. Post a cycle the way the route documents and Plane answers 400 "Project ID is required". `tool/seed_demo.py` repeats the id in the body |
| A cycle whose end date has passed refuses new work items | `CYCLE_COMPLETED`, with no way to add retrospectively. A finished sprint has to be populated first and closed afterwards, which is what the seeder does |
| `DraftIssueCreateSerializer.create` pops `module_ids` and then overwrites it | `validated_data.pop("module_ids")` on one line, `self.initial_data.get("module_ids")` two lines later. Harmless — the second wins and is the one that was wanted — but the first is dead |

## Architectural risk: closed

Two capabilities used to route through `plane-mobile-api`'s own SQL handlers
rather than the proxy — the Inbox notification feed and `issue-info` — and
this section used to say so as an open problem. It is closed.

Those handlers authenticated but did not authorise. That was demonstrated, not
suspected: the page handlers filtered by `project_id` with no membership
check, and `get_page` filtered on page id alone, so any valid token in the
instance could read or rewrite any page in any workspace. The notification
feed selected activity rows by workspace slug alone, with the same result.

The membership checks added afterwards were correct. They were also ours to
get wrong, which is the class of bug the proxy exists to make impossible. So
they are gone, along with the handlers:

| Handler | What replaced it |
|---|---|
| The derived notification feed and its five action routes | Plane's `workspaces/{slug}/users/notifications/` merged with `workspaces/{slug}/user-activity/{me}/`. The second carries `WorkspaceEntityPermission` and filters `project__project_projectmember__member=request.user` — the same scoping the hand-rolled join reached for, but Plane's to get wrong |
| One JSON file holding every user's read and dismissed ids, rewritten whole per request | Notification read and archive state is Plane's, where it already lived. Activity rows have no per-user state anywhere on the server, so those marks are this device's, in SQLite. That is a narrower blast radius than a shared file two concurrent writes could lose an update from |
| `issue-info` | `IssueViewSet` already annotates `cycle_id` and `module_ids`, and `IssueSerializer` already sends them |
| The workspace list | `users/me/workspaces/` |
| The pages handlers | Nothing — they had no call site and had not had one since pages moved to Plane. They were still live, and still reachable by any valid token |
| `check-notifications` | Nothing — no caller, and its FCM path was a second copy of the push loop's |

`plane-mobile-api` went from 1537 lines to 923. What is left cannot be reached
any other way: minting a token from a Google or a password sign-in, and
registering a device for push, which writes only the caller's own row.

**Why the Inbox needs two feeds.** Plane's notifications table is empty on this
instance, and that is correct behaviour rather than a fault:
`notification_task` drops the actor from the subscriber set twice over, so
Plane never notifies you about what you did. On a workspace where one person
does the work, no notification row is ever written. Reading only that endpoint
would leave the screen permanently blank, which is why the caller's own
activity is merged in — and why a notification and the activity row it was
raised for are deduplicated by the `issue_activity` id Plane puts in the
notification's `data`.

## What "covered" means here, and what it does not

Coverage in the tables above is **capability**: the route exists, the app calls
it, and the call is shaped the way the server's own serialiser and view
require. That was established by reading Plane's route table and source, not
its public documentation.

Two earlier versions of this document ended by disqualifying themselves —
coverage was established by reading routes and by exercising the app on a
device, which is not a test suite, and "verified on device" had twice missed a
real defect: the ButtonGroup crash that killed the process, and the dead
work-item screen. Both survived rounds of manual checking.

That is no longer the whole of the method:

- **732 unit and widget tests** run on every push and every pull request,
  alongside `flutter analyze --fatal-infos --fatal-warnings` and a formatting
  check. All three must be clean; there is no "zero new findings" allowance.
- **The seams are the services.** Each exposes a `debugClient`, and the tests
  answer it from a routing table, so what a test asserts is the thing that
  matters about a service: which path, which parameters, what it does with the
  answer. `test/services/inbox_service_test.dart` is the pattern.
- **Where a claim rests on a fact about Plane, the fact is cited** — file and
  line, in a comment next to the code that depends on it. Every row in the
  defect table above was read out of the source, and several were then
  reproduced against a live instance by `tool/seed_demo.py`.

What this still does not give you is a guarantee that a screen behaves. The
tests cover models, services and widgets; `integration_test/` drives the real
app against a real instance but needs credentials and does not run in CI. An
area marked covered can still be wrong in a way only a user will find. The
honest claim is narrower than "it works": **every capability listed as covered
is one the server will accept, and most of them are one a test will catch
breaking.**

Where a row above says *verified*, it means someone exercised it on a Galaxy
S20 FE against the live instance. That is worth less than a test and is
labelled separately for that reason.
