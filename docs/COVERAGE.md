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
| Covered | 20 |
| Partial | 6 |
| Missing | 5 |

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

## Partial

| Area | Has | Missing | Pri |
|---|---|---|---|
| Analytics | every figure is now server-computed — `advance-analytics/`, `advance-analytics-charts/`, `advance-analytics-stats/`, and `default-analytics/` for the overdue count. Five requests where the sweep took up to 45. A panel the server does not answer for is named as missing rather than drawn as a zero | the date-range and per-dimension filters Plane's own analytics page offers (assignee, label, cycle, estimate); `export-analytics/` | P3 |
| Intake | the triage queue has a screen: Open/Closed tabs, and the server's whole action set — accept, decline, snooze, un-snooze, mark duplicate. Reached from a badged app-bar action on the project screen, shown only where `intake_view` is on. Note the "Inbox" tab is the notification feed, not this queue | submitting *into* intake from the app (`POST intake-issues/`), deleting an entry, and the per-property filters Plane's own intake sidebar offers | P3 |
| Search | on Plane's own `workspaces/{slug}/search/` through the proxy, so `GlobalSearchEndpoint` filters every entity on project membership — *verified* | `entity-search/` and the per-project `search-issues/` are not used | P3 |
| Estimates | a work item's estimate point can be set | estimate *scales* cannot be created or managed | P3 |
| Projects | list, detail, settings, members; **cycles, modules, pages and views can be created**, gated on the caller's role | project **create** itself (deliberate — projects are made on the web), archive, join, leave | P3 |
| Draft work items | list, edit, promote to a work item, discard, and "Save draft" on the create screen. Reached from the work-item list's listing switcher | the draft editor carries the same fields the create screen does — title, description, state, priority — so assignees, labels, dates, cycle and module can be read off a web-made draft but not changed. Description is plain text, and the editor says so before it flattens a rich one. Workspace-level drafts with no project are not listed: the listing is project-scoped, and Plane refuses to promote a project-less draft anyway | P2 |

Two things about drafts that the route names do not tell you. They are
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

| Area | What it is | Pri |
|---|---|---|
| **Description history** | `issues/{}/versions/`, `work-items/{}/description-versions/`. The activity feed is covered; description history is not | P3 |
| **Exports** | `export-issues/`, `export-analytics/`, `user-activity/{}/export/` | P3 |
| **Home widgets** | stickies, quick links, the workspace home dashboard | P3 |
| **Webhooks & API tokens** | management UI. The app mints a token for its own auth and exposes nothing | P3 |
| **Bulk operations** | `bulk-archive-issues/`, `bulk-delete-issues/`, `bulk-create-labels/` | P3 |

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

The rest were audited rather than assumed clean. Every handler that resolves a
user from an API key now also proves membership before returning anything:
`issue-info` checks project membership, `workspaces` selects on the caller's
own membership row, `check-notifications` joins `project_members`, and device
registration only ever writes the caller's own record. `_is_project_member`
also pins the workspace when given a slug, so a caller cannot pair their own
slug with someone else's project id. A scan of every `/auth/mobile/` route for
"authenticates but does not authorise" now returns nothing.

The proxy is still the pattern to prefer for anything new: it cannot have this
class of bug at all, because the authorisation is not ours to get wrong.

## Known gaps in this document

Coverage here is *capability*, established by reading routes and by exercising
the app on a device. It is not a test suite. An area marked covered can still
be wrong in ways only a user will find — which is exactly how the process-killing
ButtonGroup crash and the dead work-item screen survived earlier rounds of
"verified on device".
