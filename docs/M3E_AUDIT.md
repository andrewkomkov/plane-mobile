# M3 Expressive audit

Read-only audit of `lib/screens/`, `lib/widgets/`, `lib/config/theme.dart` and
`lib/config/m3e/`, against the brief in [`M3_EXPRESSIVE.md`](M3_EXPRESSIVE.md).
Audited at `d9d3f88`.

## Status

Audited at `d9d3f88`; this section records what has since been done, because an
audit that does not say what it retired becomes a list of things that look
broken and are not.

**Retired:** all of Part 1 (accessibility) — the thirteen double-announcing
`Semantics` wrappers, the three swipe-only destructive actions, the anonymous
notification feed, the `GestureDetector` around `IssueRow`, the missing search
back affordance and the colliding labels. Ranked items 3, 5, 6, 7, 8, 9, 10,
11, 12, 13, 14 and 15. Both of Part 5 — the four overlay surfaces now carry the
hairline the decision table promised, and the listing switcher is 48dp. All of
Part 6 — the four create flows are reachable, `FilterBar` is rendered and
`applyFilters` called, My issues honours its own Grouping option, and the
spreadsheet scrolls as one table.

**Consequence worth stating:** `flutter analyze` reports **nothing**, down from
30; the unit suite is **685 green**; and the seven integration tests pass on a
Galaxy S20 FE against the live instance. The fourteen warnings that survived
the first cleanup were all unreferenced declarations for the flows nobody could
reach — the analyzer was, for a while, the only thing in the repo reporting
that the app could not create a cycle.

**Two things the device found that no amount of reading would have.** Both
were on the way to verifying the work above, and both are worse than anything
in the audit below:

* **Every integration test failed on the device, all seven, at boot.**
  `projects_tab` reaches `_load` from `didUpdateWidget` — the home screen
  rebuilds the tab once it has resolved a workspace slug — and `_load` fired
  `favoritesProvider.notifier.load(...)` synchronously. Riverpod refuses a
  provider write inside a widget lifecycle and threw *"Tried to modify a
  provider while the widget tree was building"* on the first frame after
  sign-in. Deferred by one turn of the event loop; the suite went 0/7 → 7/7.
* **`ProjectSettingsScreen` had no call site anywhere in the app.** General,
  members, states, labels, integrations and the Features section — written,
  compiled, and unreachable from the running app. `flutter analyze` does not
  report an unused *public* class, which is exactly how the four create flows
  stayed dead through two earlier rounds. It is now a `settings_outlined`
  action on the project screen's app bar, and the Features section was
  photographed on the device reading the real flags.

**Not done, and deliberately:** `main.dart` still installs no `textScaler`
clamp. Screens that clipped at large text scales were fixed individually
instead. A global clamp overrides a user's accessibility setting, which is a
product decision rather than a refactor.

**Raised by the fixers, since done:** the four requests against the shared
widgets. `confirm_dialog` gained `confirmAction`, the non-destructive variant,
and the three hand-rolled restore dialogs now call it rather than paint
"Restore" in the error role or invent a third `AlertDialog` shape.
`EmptyStateWidget` and `ScrollableEmptyState` gained an action slot, which the
cycle, module, view and page lists were each wrapping in their own `Column` to
fake — all four now pass a button and use the scrollable widget they could not
use before. `SectionHeader` gained a trailing slot, and project settings' local
`_headerRow` is gone. `app_navbar` exports `appNavBarHeight` and
`appNavBarClearance`; `kProjectListBottomInset` and the five other literals
guessing that number are gone with it. The exported height reads the bar's
measured height where the Scaffold has one and falls back to the bar's own
geometry elsewhere, and a test asserts it against `getSize` of the bar under a
gesture inset and at 2x text.

**Raised by the fixers, also done:** `FilterBar`'s Clear now empties the four
filter sets and touches nothing else, and `issue_list_screen`'s guard against
the old behaviour — adopt the incoming ordering only if the selections did not
move — is gone with it. `Project` reads `cycle_view`, `module_view`,
`issue_views_view` and `page_view`, and the project settings Features section
is back, showing the real answers; a flag the payload does not carry reports
*on*, because a cached project claiming a user's cycles are switched off is the
worse failure.

**The sheet, dialog and row layer — §3.1, §3.2, the audit's largest finding.**
Done, and the counts are the check:

| | Audit | Now |
|---|---|---|
| Raw `showModalBottomSheet` | 45 | **7** — two are the shared widgets; five are bespoke sheets that cannot be a picker (the work-item picker, the command palette, display options, the emoji grid, the nav overflow) |
| Raw `AlertDialog` | 31 | **15** — every one a *form*; the fourteen confirmations are gone |
| Raw `ListTile` / `CheckboxListTile` / `SwitchListTile` | ~70 | **0** |
| `InkWell` | 10 | **0** |
| `CircularProgressIndicator` | 2 | **0** |
| `BottomSheetPicker` call sites | 0 | **33** |
| `confirmDestructive` / `confirmAction` call sites | 6 | **23** |

Three widgets carried it: `MultiSelectSheet` (the multi-choice sibling, with
`Clear`, a count, and a bottom action that can require a selection),
`SheetOptionRow` (exported so the bespoke sheets draw the same row), and
`BottomSheetPickerItem.enabled` for the rows the server would refuse — shown
dimmed with the reason rather than hidden, which is what the work-item, cycle,
module and page menus all needed.

Also retired along the way: 71 undifferentiated snackbars, now `say` and
`sayError` with the error container and an icon; two `_LabelPill`s and five
`_parseColor`s, now `LabelPill` and `parseHexColor`; the display sheet's
cycling rows, which advanced to the next value and never showed the range;
the auth-mode text links, now an `M3EButtonGroup` that marks the current mode;
the search destination, which was on screen while nothing in the nav bar was
selected; the last three spacer-and-`ListView` empty states; and the two
duplicated sign-in button styles.

---

## Verdict

**The token layer is genuinely excellent. The layer built on top of it has
drifted, and the drift is concentrated in three places.**

The mechanical checks come back almost perfectly clean, and that is worth
stating plainly because it is unusual:

| Check | Result |
|---|---|
| `BorderRadius.circular(<literal>)` anywhere in `lib/` | **0** |
| `Radius.circular(<literal>)` | **0** |
| `Color(0x…)` outside `theme.dart` | **0** |
| `Colors.<name>` outside two documented glass/scrim sites | **0** |
| Loose `fontSize:` | **2**, both justified (nav label metric, header collapse lerp) |
| Material `AppBar` | **0** |

So this is not an audit about hardcoded values. Almost every finding below is
about a *widget* that was built once, correctly, and then not used — or used on
some screens and not others.

The three concentrations, in order of user-visible cost:

1. **The sheet, dialog and picker layer is stock Material.** 45 raw
   `showModalBottomSheet`, 31 raw `AlertDialog`, ~70 raw `ListTile`. Meanwhile
   `BottomSheetPicker` has **zero call sites** and `confirmMemberAction` has
   six. Every screen in the app is springs, shape-morphing chips and press
   physics — and the moment you open a sheet you are in stock Material 3 with
   ink ripples. This is the single largest gap and it is on every screen.
2. **Accessibility has regressed in a specific, repeatable way.** Two
   independent patterns: bare `Semantics(label:)` wrappers that append rather
   than replace (~13 sites), and destructive actions that exist only as a
   swipe gesture (3 screens). The repo *documents the correct pattern* in
   `motion.dart:243-259` and applies it correctly in seven places — the other
   thirteen were written before the rule was understood.
3. **Navigation has no M3E at all.** No `PageTransitionsTheme` exists anywhere.
   All 47 route pushes are stock `MaterialPageRoute`. `M3EMotion.slowSpatial`,
   documented as "full-screen transitions", has **zero call sites**.

**Volume: 61 findings.** That is a real number, not padding — but note that a
large fraction collapse into about eight fixes, because they are the same
omission repeated across sibling screens. The ranked table below is ordered so
that the top ten fixes retire roughly half the list.

---

## How to read this

Every finding is tagged:

- **[M3E]** — violates the design language as this repo defines it.
- **[APP]** — does not violate M3E, but is inconsistent with how the rest of
  this app does the same thing. These are often *worse*: a user does not know
  what M3E is, but they do notice that the cycles list and the modules list
  have the same header and the views list does not.
- **[A11Y]** — accessibility regression. Highest priority regardless of tag.

Fix size is **S** (one call site), **M** (one widget, several call sites),
**L** (new shared widget + migration).

`lib/screens/issues/issue_detail_screen.dart`, `lib/widgets/property_chip.dart`
and `lib/widgets/reaction_bar.dart` are being reworked concurrently. Findings
touching those files are marked **⚠︎ possibly already fixed** and should be
re-checked before acting.

---

## Ranked: the fixes that buy the most

| # | Finding | Tag | Size |
|---|---|---|---|
| 1 | Swipe-only destructive actions on 3 screens — unreachable by screen reader *and* by `adb_drive.py` | A11Y | M |
| 2 | 13 bare `Semantics(label:)` wrappers append instead of replace → every filter chip and stat card announces twice | A11Y | M |
| 3 | `PropertyChip` renders a set value identically to an empty placeholder — 9 chips on the work-item screen | M3E | M |
| 4 | Notification rows are an unlabelled `M3EPressable` — the whole inbox is anonymous to automation | A11Y | S |
| 5 | No `PageTransitionsTheme`; `slowSpatial` unused; 47 stock Material transitions | M3E | M |
| 6 | `BottomSheetPicker` has zero call sites; 45 hand-rolled sheets disagree on header, item type, and whether selection is shown at all | APP | L |
| 7 | Status-bar icons are pinned to `Brightness.light` — white icons on the white light theme | M3E | S |
| 8 | Bare `FilledButton` resolves to the pale dark-scheme `primary`; `M3ELoadingIndicator` on it is invisible while saving | M3E | S |
| 9 | 5 of 31 destructive dialog buttons are styled identically to "Cancel" | APP | M |
| 10 | `M3EChip(dense:)` has no 48dp target — the archive toggle on 3 screens is ~24dp | M3E | S |
| 11 | Three byte-identical `_header()` methods; a fourth screen has none | APP | M |
| 12 | Empty state copy-pasted 10× with two different magic spacers | APP | M |
| 13 | Analytics draws its own cards, headers, empty states, progress radius | APP | L |
| 14 | `my_issues_tab` contains a 250-line divergent copy of `showDisplayOptions` | APP | M |
| 15 | `menu_tab` builds its own row, header, button and picker — none shared | APP | L |

---

# Part 1 — Accessibility

The most expensive category, and the one the brief flags. Two distinct bugs,
each repeated.

## 1.1 [A11Y] Bare `Semantics(label:)` appends the child's text instead of replacing it

`motion.dart:243-259` documents the rule precisely: *"An explicit label
REPLACES the subtree's, rather than being appended to it"* — but only because
`M3EPressable` sets `excludeSemantics: labelled`. A hand-written `Semantics`
wrapper without `excludeSemantics: true` does **not** replace; both names reach
the tree. `archive_toggle.dart:32-45` states this in its own comment and does
it correctly. Thirteen sites do not.

Consequence: a screen reader announces `"Filter by State, State"`, and
`tool/adb_drive.py tap "Filter by State"` — which matches on substring —
becomes ambiguous the moment two nodes carry overlapping text.

**Correct (7 sites, leave alone):** `archive_toggle.dart:44`,
`reaction_bar.dart:120, 191, 249`, `intake_screen.dart:294`,
`issue_detail_screen.dart:2455`, and `M3EPressable` itself.

**Missing `excludeSemantics: true` (13 sites):**

| File:line | Wraps | Colliding visible text |
|---|---|---|
| `widgets/filter_bar.dart:182` | `M3EChip` | "State" / "Priority" / "Assignee" / "Label" |
| `widgets/filter_bar.dart:206` | `M3EChip` | "Created" / "State" (the sort/group value) |
| `widgets/filter_bar.dart:153` | `M3EChip` | "Clear" |
| `screens/analytics/analytics_screen.dart:231` | error block | the message, verbatim |
| `screens/analytics/analytics_screen.dart:315` | chart bar | key + value, verbatim |
| `screens/analytics/analytics_screen.dart:416` | project row | name + count, verbatim |
| `screens/analytics/analytics_screen.dart:493` | stat card | label + value + source, verbatim |
| `screens/issues/issue_detail_screen.dart:1177, 1189, 1223, 1235, 1247` ⚠︎ | `PropertyChip` | "Label" / "Assignee" / "Estimate" / "Cycle" / "Module" |
| `screens/home/menu_tab.dart:163` | `GestureDetector` | "Plane" |
| `screens/search/search_screen.dart:196` | `TextButton` | "Clear" |

Note the analytics four also pass `container: true` without
`excludeSemantics: true`, which is the worst combination — it forces a node
*and* merges the children into it.

`filter_bar.dart` is the highest-impact of these: the filter bar is on every
project issue list.

**Fix:** add `container: true, excludeSemantics: true` to each, and re-declare
`onTap:` on the node where the child's gesture would otherwise be dropped —
exactly the shape of `motion.dart:243-261`. Then run
`tool/adb_drive.py check` on the affected screens. **Size M.**

## 1.2 [A11Y] Destructive actions that exist only as a swipe

Three screens make a destructive or state-changing action reachable *only* by
`Dismissible`. There is no button, no long-press menu, and no
`customSemanticsActions`. A screen-reader user cannot perform the action at
all, and `adb_drive.py check` will not even report it as a gap — there is no
node to be anonymous.

| File:line | Action |
|---|---|
| `screens/notifications/notification_screen.dart:289-299` | Archive notification |
| `screens/cycles/cycle_detail_screen.dart:510-546` | Remove issue from cycle |
| `screens/modules/module_detail_screen.dart:585-621` | Remove issue from module |

`inbox_tab.dart:297-311` has the same shape for swipe-to-dismiss.

**Fix:** put the action in `PlaneRow.trailing` as an
`M3EIconButton(tooltip: 'Archive <title>')` — that slot exists precisely
because it is the one place outside the row's own semantics node
(`plane_row.dart:96-99, 210-217`). Keep the swipe as an accelerator.
**Size M.**

## 1.3 [A11Y] The notification row is an unlabelled `M3EPressable`

`screens/notifications/notification_screen.dart:300-301`

```dart
child: M3EPressable(
  onTap: () => _onTap(notification),
```

No `semanticLabel`, no `selected`. `M3EPressable` short-circuits at
`motion.dart:238-240` and returns the bare `GestureDetector`, so the tappable
node is anonymous and the title/entity/timestamp sit in unrelated child nodes.
`PlaneRow` makes `semanticLabel` **required** for exactly this reason. The
whole notifications feed is currently invisible to `adb_drive.py tap`.

**Fix:** replace with `PlaneRow(emphasizeTitle: !isRead, highlighted: !isRead,
semanticLabel: …)`. This also fixes findings 3.4 and 4.6. **Size S.**

## 1.4 [A11Y] `GestureDetector` wrapped *around* `IssueRow`

`screens/home/inbox_tab.dart:312-313` puts `onLongPress` on an ancestor of
`IssueRow`. `PlaneRow` hands its label to `M3EPressable`, which excludes the
subtree and re-declares its own actions — so a long-press declared *above* it
lands on an anonymous node that is never associated with the row.
`IssueRow` has no `onLongPress` parameter (`issue_row.dart:67-90`); it needs
one, forwarded to `PlaneRow.onLongPress`. **Size S.**

## 1.5 [A11Y] Search screen has no back affordance

`screens/search/search_screen.dart:124-155` uses a raw `PreferredSize`
containing only an `M3ETextField`. The screen is pushed from
`project_screen.dart:186-192`, and there is no leading button, no close
action — only the system gesture returns. Every other pushed screen uses
`M3EAppBar`, which adds a labelled `M3EAppBarAction(tooltip: 'Back')`
automatically. **Size S.**

## 1.6 [A11Y] Generic and colliding labels

- `cycle_detail_screen.dart:385` and `module_detail_screen.dart:454` — the
  overflow trigger is tooltipped `'More'`. Two screens with a node literally
  named "More" makes `adb_drive.py tap "More"` ambiguous across a flow. Should
  name the target, as `favorite_toggle.dart:55-57` does. **Size S.**
- `project_settings_screen.dart:797-799` — `deleteButtonTooltipMessage:
  'Delete label'` is identical across N chips, and disagrees with the
  `semanticLabel: 'Delete label ${l.name}'` on the same icon. **Size S.**
- `webview_login_screen.dart:211` — `LinearProgressIndicator()` with no
  `semanticsLabel`; the busy state is silent. **Size S.**

---

# Part 2 — Violates M3E

## 2.1 State expression

M3E's thesis: state is carried by shape and physics, not only colour. These are
the places where a distinction is weaker than that.

### 2.1.1 [M3E] `PropertyChip` cannot tell set from unset ⚠︎ possibly already fixed

`widgets/property_chip.dart:30-56`, called nine times at
`issue_detail_screen.dart:1154-1256`.

The flagship case. `PropertyChip` has no notion of set vs unset at all — no
parameter, no branch. Every chip renders with the same `scheme.outline` at
0.8, the same `M3EShape.small` corner, the same `labelMedium` in the same
colour, the same padding:

| Chip | Set | Unset |
|---|---|---|
| State (1154) | "Done" | — always set |
| Priority (1161) | "Medium" | — always set |
| Labels (1181) | "+" | "Label" |
| Assignee (1193) | "3" | "Assignee" |
| Start date (1203) | "2026-03-01" | "Start" |
| Target date (1210) | "2026-04-15" | "Due" |
| Estimate (1227) | "5" | "Estimate" |
| Cycle (1239) | "Sprint 12" | "Cycle" |
| Module (1251) | "Auth" | "Module" |

Seven of the nine render a placeholder identically to real data. Worse, the
placeholder is not even distinguishable by icon colour: `iconColor: secondary`
is passed whether the field is set or not for Start, Due, Estimate, Cycle and
Module.

**What M3E says:** this is the exact case the shape channel exists for. The
app already has the answer implemented twice — `M3EChip` pulls its corner from
`largeIncreased` (20) to `small` (8) on selection *and* tints
(`chip.dart:60-88`); `M3EIconButton` morphs circle → `M3EShape.medium`
(`icon_button.dart:106-138`). `PropertyChip` opts out of both.

**Fix:** add `bool isSet` to `PropertyChip`. Unset takes a quiet outline
(`outlineVariant`), no fill, and `onSurfaceVariant` label; set takes a
`surfaceContainerHigh` fill, `onSurface` label, and the tighter corner. Drive
the change with the same `fastSpatial`/`defaultEffects` pair `M3EChip` uses so
it animates when a picker resolves. **Size M** (one widget, nine call sites
already passing enough information to derive `isSet`).

### 2.1.2 [M3E] Placeholder rendered as a real value

- `screens/issues/issue_create_screen.dart:407` — `_currentState?.name ??
  'Backlog'`, with a real-looking `PlaneTheme.backlog` swatch drawn at `:401`.
  A user cannot distinguish "no state chosen" from "state = Backlog". **S**
- `screens/home/projects_tab.dart:186` — `"0 active issues"` shown as fact
  while `_loadIssueCounts` (`:63-76`) is still filling `_issueCounts` row by
  row. Unknown and genuinely-zero render identically. **S**
- `screens/project/project_settings_screen.dart:850-853` — `_featureRow('Cycles',
  true, …)` ×4. The `enabled` argument is **hardcoded `true`**; `Project`
  carries no such field. A settings screen renders a green check and the word
  "Enabled" for four features regardless of the project's real configuration.
  The `false` branch is unreachable. **S** (read the flags, or drop the
  section).
- `screens/issues/spreadsheet_view.dart:159-179` — "Unassigned" vs a real
  assignee, and `'-'` vs a real due date, differ by text *colour* only
  (`secondary` vs `onSurface`) at the same size and weight. **S**

### 2.1.3 [M3E] Selection expressed by colour alone

- `screens/issues/calendar_view.dart:199-204` — the selected day changes fill
  colour and nothing else, instantly, with no corner change and no effects
  spring. 42 cells on screen. **S**
- `screens/workspace/workspace_members_screen.dart:130-133` and
  `screens/project/project_settings_screen.dart:681-691` — stock `ChoiceChip`.
  `chipTheme` (`theme.dart:316-322`) pins `StadiumBorder` for both states, so
  selection is a fill tint. Every other chip in the app is `M3EChip`, whose
  documented reason for existing is that selection also changes shape. **S**
- `screens/profile/profile_screen.dart:210-217` — theme mode selection is an
  18dp trailing check, untinted. No shape, no fill, no weight. It is also a
  *third* check-mark treatment: `bottom_sheet_picker.dart:52` uses 20dp
  untinted, `member_row.dart:193` uses tinted `primary`. **S**
- `screens/issues/spreadsheet_view.dart:192-241` — the state and priority
  pickers show **no** current selection at all: no check, no highlight. The
  sibling pickers at `issue_create_screen.dart:502, 536` do show a check. Same
  picker, two behaviours. **S**
- `screens/setup/setup_screen.dart:276-292` — the auth-mode switch renders
  inactive modes as text links separated by `"  |  "`. There is no selected
  state; the current mode is inferable only from which fields are on screen.
  `M3EButtonGroup` exists for this and `my_issues_tab.dart:586` uses it. **S**
- `screens/home/home_screen.dart:101` — `currentIndex: _currentTab < 4 ?
  _currentTab : -1`. When Search is showing, **no** destination is selected:
  the travelling indicator has no home, and `app_navbar.dart:96-104` passes no
  `selected:` to the search affordance's `M3EPressable`. Neither visually nor
  semantically is "you are on Search" expressed. **S**

### 2.1.4 [M3E] Disabled expressed weakly

- `screens/issues/issue_create_screen.dart:596-600` — the disabled state dims
  the *fill* to `alpha: 0.4` while the label keeps full-strength `foreground`.
  It does not read as disabled. `M3EIconButton` (`icon_button.dart:153-155`)
  dims the foreground to 0.38 — that is the house treatment. **S**
- `cycle_detail_screen.dart:128-151` / `module_detail_screen.dart:150-173` —
  "Add (N)" falls back to Material's default disabled alpha only. Minor, but
  it is the sheet's primary action. **S**

### 2.1.5 [M3E] Error and success are the same snackbar

110 `SnackBar` call sites, all inheriting `snackBarTheme`
(`theme.dart:408-416`): `surfaceContainerHighest`, no border, elevation 0.
`"View saved"` and `"Failed to restore cycle: DioException…"` render
identically — a failure is distinguished only by its words.

Two problems compound: on the light theme, `surfaceContainerHighest`
(`#E5E5E5`) against the `#FFFFFF` scaffold is 1.13:1, with no outline and no
elevation, so a *floating* snackbar is a barely-visible grey rectangle. The
brief's own rule is "flat everywhere, **hairline outlines**" — the snackbar,
dialog, sheet and card themes all omit the hairline, while `popupMenuTheme`
(`theme.dart:422`) has one.

**Fix:** add `side: BorderSide(color: scheme.outlineVariant, width: 0.5)` to
the snackbar/dialog/sheet shapes, and add an error variant (`errorContainer` /
`onErrorContainer`) reachable through a small helper. **Size S** for the
outline, **M** for the error variant.

## 2.2 Motion

### 2.2.1 [M3E] Hand-picked duration + curve where a spring is mandated

Only two sites in `lib/screens/`, but both animate visible state:

- `screens/issues/kanban_board_screen.dart:103-104` —
  `AnimatedContainer(duration: Duration(milliseconds: 200))` for the
  drop-target highlight. What changes is a **tint plus a border**, i.e. a pure
  effects change → `M3ESpringBuilder` + `M3EMotion.defaultEffects`
  (critically damped, must not overshoot). **S**
- `screens/analytics/analytics_screen.dart:335-337` —
  `AnimatedContainer(duration: 300ms)` animating a bar's **width**, i.e. a
  spatial property → `M3ESpringBuilder` + `M3EMotion.defaultSpatial` (may
  overshoot). It also runs on `AnimatedContainer`'s default `Curves.linear`.
  **S**

`M3EFabMenu`'s `Curves.easeOutBack` (`fab_menu.dart:251`) and its 420/260 ms
controller are **not** a finding — `fab_menu.dart:7-12` explains that a
stagger needs a shared timeline, which is correct.

### 2.2.2 [M3E] Missing press feedback

The app's signature touch response is `M3EPressable`'s spring squeeze. These
surfaces use Material ink or nothing:

**`InkWell` (10 sites):** `my_issues_tab.dart:329`,
`spreadsheet_view.dart:91`, `display_options.dart:55`,
`reaction_bar.dart:121, 192, 250` ⚠︎, `issue_detail_screen.dart:1503, 1736,
2456, 2579` ⚠︎.

**Bare `GestureDetector` (9 sites, excluding `M3EPressable`'s own):**
`inbox_tab.dart:312`, `menu_tab.dart:166, 382, 488`,
`project_settings_screen.dart:515`, `calendar_view.dart:193`,
`issue_create_screen.dart:371, 422`, `issue_detail_screen.dart:2102` ⚠︎.

**Stock `ListTile` (~70 sites)** — see §3.1; this is the systemic one.

Highest impact of these: `menu_tab.dart:488` (`_MenuRow`, eleven rows in the
app's most-visited settings surface), `calendar_view.dart:193` (42 day cells),
and `spreadsheet_view.dart:91` (the only way to open an issue from the table).

### 2.2.3 [M3E] Reduce motion is honoured, with one real gap

The claim at `motion.dart:139-141` — *"Every moving thing in this app is a
spring, so honouring it here covers the whole surface"* — is **overstated but
mostly rescued by the framework**, and I want the fixers to know why so they
do not over-correct.

`M3ESpringBuilder` uses `animateWith`, which Flutter does **not** scale, so its
explicit `maybeDisableAnimationsOf` check at `motion.dart:115, 142` is load
bearing and correct. Everything else in the app runs on
`AnimationController.forward()/reverse()`, which Flutter *does* scale to 5% of
its duration under `disableAnimations`
(`animation_controller.dart:651`) — so `M3EFabMenu`, both `AnimatedContainer`s
and every route transition are effectively instant already.

The one genuine gap: **`widgets/skeleton_loader.dart:15-16`** uses
`repeat(reverse: true)`, and `repeat` is *not* scaled. The shimmer pulses at
full speed for a user who has asked for no animation, on every list screen's
loading state. **Size S** — gate `initShimmer` on
`MediaQuery.maybeDisableAnimationsOf` and hold a static opacity.

Secondary: `main.dart:54-69` sets no `themeAnimationDuration`, so the
light/dark switch from `profile_screen.dart:158-181` crossfades on Flutter's
200 ms linear `kThemeAnimationDuration`. **Size S.**

## 2.3 Shape

Nothing to report on hardcoded radii — the sweep is clean. Two nits:

- `analytics_screen.dart:440` clips the stacked project bar at
  `M3EShape.extraSmall` (4) where `plane_row.dart:395` clips the identical
  element at `M3EShape.full`. Same element, two radii. `M3_EXPRESSIVE.md:167`
  grandfathers 2–4px progress caps, so this is [APP], not [M3E]. **S**
- `kanban_board_screen.dart:107-119` — the drop target's border only exists
  when `isTarget` (`decoration: null` otherwise), so accepting a card shifts
  the column's content by the border width as well as tinting it. Should draw
  a transparent border at rest. **S**

Selection/press *does* change corner radius where it should, in `M3EChip` and
`M3EIconButton`. The gap is that `PropertyChip` (§2.1.1) and the reaction chip
(§3.5) do not.

## 2.4 Typography and emphasis

The "one emphasized element per screen" rule is the one that has decayed most.

### 2.4.1 [M3E] Emphasis applied per-item rather than per-screen

- `screens/analytics/analytics_screen.dart:352-353` applies
  `M3EType.emphasized(titleSmall)` to **every bar's count** (up to 10 per chart
  × 2 charts) and `:434-435` to **every project's total**. With four
  `headlineMedium` stat numbers at `:507-509`, the screen carries 20+
  emphasized elements. **M**
- `screens/home/projects_tab.dart:199` — emphasized cut on the identifier
  badge of *every* row, competing with the flexible header's large title. **S**
- `screens/home/menu_tab.dart:175, 237, 422` — three emphasized elements
  ("Plane", display name, "Disconnect") plus a `headlineSmall` avatar initial
  at `:227`. **S**
- `screens/cycles/cycle_list_screen.dart:243, 264` — both date buttons take
  `M3EType.emphasized(labelMedium)`, side by side. **S**

### 2.4.2 [M3E] Emphasis spent on the wrong element

- `screens/home/my_issues_tab.dart:508` — the emphasized cut goes to **"Reset"**,
  the least important control on the display sheet, while the screen's title is
  plain. **S**
- `screens/profile/profile_screen.dart:102-103` — the avatar *initial* takes
  `headlineLarge` (28/w700), the largest type on the screen, for a decorative
  letter; the one real heading ("Appearance", `:156`) is `titleMedium` (15).
  Inverted. **S**
- `screens/search/search_screen.dart:190` — `M3EType.emphasized(titleSmall)`
  used as a plain section label, competing with the real `SectionHeader`
  overlines below it at `:238`. **S**

### 2.4.3 [M3E] Inline `TextStyle` that discards a role

- `cycle_detail_screen.dart:363` and `module_detail_screen.dart:407` —
  `Text('Delete', style: TextStyle(color: colorScheme.error))`. A bare
  `TextStyle` with only a colour discards `textButtonTheme`'s `labelLarge` +
  `w600` (`theme.dart:358-363`), so the destructive button renders at a
  *different weight* from the "Cancel" beside it. Should be
  `TextButton.styleFrom(foregroundColor: …)`, as `member_row.dart:227-231`
  already does. **S**
- `command_palette.dart:343-345` and `setup_screen.dart:281-282` — bare
  `TextStyle(color: …)` with no role; they inherit a size by accident. **S**

### 2.4.4 [APP] Icon sizes off the `PlaneTheme` ramp

`PlaneTheme.iconSmall/iconMedium/iconLarge` (14/16/20) exist and are used
correctly in many places. Loose literals: `cycle_detail_screen.dart:185, 566,
576, 586, 607`; `module_detail_screen.dart:207, 641, 651, 661, 680`;
`menu_tab.dart:114, 171, 495, 511`; `profile_screen.dart:212, 215`;
`command_palette.dart:136, 358`; `project_settings_screen.dart:753, 798, 816,
836, 883`; `browser_login_screen.dart:217`; `spreadsheet_view.dart:202, 227`;
`issue_create_screen.dart:354, 412, 445, 457, 503, 537`.

Worth noting the *symptom*: `member_row.dart:143` draws the same bottom-sheet
menu as `cycle_detail_screen.dart:566` with **no** size at all (Material's
default 24), so an identical menu renders at two icon sizes depending on which
screen opened it. **Size M.**

## 2.5 Colour roles

The palette itself is untouched, as documented. These are role misuses.

### 2.5.1 [M3E] Status-bar icons pinned to light — broken in the light theme

`lib/main.dart:14-17`

```dart
SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
));
```

Set once at startup, never re-applied. `Brightness.light` icons are **white**,
and `_bgLight` is `0xFFFFFFFF`. The clock, battery and signal indicators are
invisible for the entire light theme. This is the single most visible colour
bug in the app and no other `SystemUiOverlayStyle` or `AnnotatedRegion` exists
in `lib/`. **Size S.**

### 2.5.2 [M3E] Bare `FilledButton` paints the pale dark-scheme `primary`

`theme.dart:343-349` sets only shape, padding and text style on
`filledButtonTheme`, so the fill resolves to M3's default `colorScheme.primary`
— which in the dark scheme is `0xFFBDC2FF`, the *pale* tone meant to sit **on**
a dark surface. `setup_screen.dart:260-268` and `browser_login_screen.dart:175-183`
both document this hazard verbatim and work around it locally with
`primaryContainer`/`onPrimaryContainer`. Two screens did not get the memo:

- `screens/profile/profile_screen.dart:142-151`
- `screens/project/project_settings_screen.dart:697-702`

And it compounds: `M3ELoadingIndicator` defaults to `scheme.primary`
(`loading_indicator.dart:52`), so `profile_screen.dart:149` and
`project_settings_screen.dart:700` draw a pale indicator **on a pale button** —
invisible for the whole duration of the save.

**Fix:** move `backgroundColor: scheme.primaryContainer, foregroundColor:
scheme.onPrimaryContainer` into `theme.dart`'s `filledButtonTheme`, then delete
the two per-screen `_filledStyle` copies. **Size S**, fixes four sites.

### 2.5.3 [M3E] Dark-tuned constants used against the light surface

`theme.dart:76-106` documents at length that the raw priority/state constants
fail on the light surface and that `PlaneTheme.stateGroupColor(context, …)` is
the accessor. Two sites bypass it:

- `screens/project/project_settings_screen.dart:884` — `enabled ?
  PlaneTheme.completed : PlaneTheme.cancelled`. `completed` is `0xFF22C55E`,
  which the theme's own comment measures as failing on light. The same file
  does it correctly at `:751`. **S**
- `screens/issues/spreadsheet_view.dart:177` — `PlaneTheme.urgent` raw, where
  `issue_row.dart:167` spells the same thing
  `PlaneTheme.priorityColor(context, 'urgent')`. **S**

### 2.5.4 [M3E] Role paired with the wrong `on` role

- `screens/home/menu_tab.dart:382-428` — Disconnect draws `errorContainer` at
  20% as the fill and `colorScheme.error` as the text/icon. The paired role is
  `onErrorContainer`. **S**
- `cycle_detail_screen.dart:516` / `module_detail_screen.dart:591` — the swipe
  background hand-mixes `error.withValues(alpha: 0.1)` and draws a
  full-strength `error` icon on it. `errorContainer`/`onErrorContainer` exist
  in both schemes and are the roles for exactly this. **S**
- `screens/setup/browser_login_screen.dart:185-191` — the comment claims
  *"Same corner token and border weight as `M3ETextField`, so a field and a
  button stacked on this screen read as one control family."* The button uses
  `scheme.outlineVariant`; `M3ETextField` uses `scheme.outline`
  (`text_field.dart:111-112`). Two different roles, ~2 steps apart in both
  palettes. The claim is false and the two controls visibly disagree. **S**

### 2.5.5 [M3E] A tint below the perceptual threshold

`screens/notifications/notification_screen.dart:305-307` — the unread
background is `primary.withValues(alpha: 0.04)`. 4% does no work on either
`0xFF0A0A0A` or `0xFFFFFFFF`. The system's answer to "this row is lifted" is
`PlaneRow(highlighted: true)`, which *steps the surface*
(`plane_row.dart:165-167`). **S** — subsumed by finding 1.3.

### 2.5.6 [APP] Literal grey fallback

`screens/project/project_settings_screen.dart:622` —
`Color(int.tryParse(h, radix: 16) ?? 0xFF999999)`. Should be
`scheme.outline`. Note the hex *swatch list* at `:497-505` and the `'#6B7280'`
default at `:433, :481` are server-facing label data and are fine. **S**

### 2.5.7 [APP] Dead tokens in `PlaneTheme`

`theme.dart:9, 15, 16, 20, 27, 31, 32` define `surfaceDim`, `surfaceBright`,
`surfaceVariant`, `onBackground`, `inversePrimary`, `tertiaryColor` and
`tertiaryContainer`; none is referenced anywhere. Neither scheme overrides
`tertiary`, so if anything ever reaches for `scheme.tertiary` it will get M3's
baseline mauve, entirely off-palette. Delete the constants or wire `tertiary`
into both schemes. **S.**

## 2.6 Density and touch targets

`M3EIconButton` enforces 48dp regardless of visual size
(`icon_button.dart:117-119`) and `PropertyChip` pads out to 48 when tappable
(`property_chip.dart:70-75`) — the convention exists. These sites are below it.

| File:line | Control | Height | Note |
|---|---|---|---|
| `widgets/m3e/chip.dart:81-84` via `archive_toggle.dart:46` | Archive toggle | ~24dp | On `cycle_list:359`, `module_list:304`, `page_list:170`. `M3EChip` sets no minimum. **Fix once in `M3EChip`.** |
| `widgets/reaction_bar.dart:124-140` ⚠︎ | Reaction chip | ~24–30dp | The `_AddReactionButton` beside it *is* 48 (`:199-201`); the chips are not |
| `widgets/loading_state.dart:37` | Shared "Retry" | 36dp | Reached from 4+ screens |
| `screens/issues/issue_list_screen.dart:320-321` | Display options | **40dp** | `SizedBox(width: M3EIconButtonSize.small.container)` = 40, which *tightly constrains* the `M3EIconButton`'s own 48dp box and silently defeats its guarantee. Use 48 for the slot. |
| `screens/home/menu_tab.dart:166-185` | Workspace switcher | ~25dp | Bare `GestureDetector` around a `Row` |
| `screens/pages/page_detail_screen.dart:383-398` | "Save" pill | ~35dp | `M3EPressable` forwards `HitTestBehavior.opaque` on the child, so the hit area *is* the 35dp container |
| `screens/issues/issue_create_screen.dart:581-608` | `_BarAction` | ~38dp | |
| `screens/issues/issue_create_screen.dart:660-689` | Discard draft | ~42dp | |
| `screens/home/my_issues_tab.dart:539` | Row-property chips | ~31dp | Nine of them in a `Wrap` |
| `widgets/display_options.dart:209` | Row-property chips | ~31dp | Same, shared copy |
| `screens/setup/setup_screen.dart:283-289` | Mode switch | 36dp | The screen's primary navigation |
| `screens/setup/browser_login_screen.dart:157, 244` | Text actions | 36dp | |
| `screens/project/project_settings_screen.dart:681-691` | `ChoiceChip` | 32dp | |
| `screens/project/project_settings_screen.dart:797-800` | `Chip` delete | ~24dp | |
| `screens/issues/spreadsheet_view.dart:91-112` | Open issue | ~20dp | `InkWell` around the title `Text` only, inside a cell that reserves 48 |

**Two systemic fixes retire most of this:** a `minimumSize: Size(48, 48)` on
`theme.dart`'s `textButtonTheme` (`search_screen.dart:204-208` already does this
locally, with a comment explaining why), and a 48dp minimum inside `M3EChip`.
**Size S each.**

### [APP] `M3EButtonGroup` at three heights

`issues_tab_screen.dart:105` uses **48**, `my_issues_tab.dart:587` uses **40**,
`issue_listing_switcher.dart:49` uses **38** — for the same connected-button-group
component, on adjacent screens. The 48 is correct; the other two put segment
targets 8–10dp under the minimum. `issue_listing_switcher.dart:46-48` documents
its 38 as intentional ("shorter than the group's default so the header stays a
list header"), which is a legitimate density argument — but not one that
survives the touch-target floor. **Size S.**

---

# Part 3 — Inconsistent with the rest of this app

Not M3E violations. Often worse.

## 3.1 [APP] The entire sheet / picker / dialog layer is stock Material

**This is the largest finding in the audit.**

| | Count |
|---|---|
| Raw `showModalBottomSheet` | 45 |
| Raw `AlertDialog` | 31 |
| Raw `ListTile` / `CheckboxListTile` / `SwitchListTile` | ~70 |
| `BottomSheetPicker.show` call sites | **0** |
| `confirmMemberAction` call sites | 6 |

`widgets/bottom_sheet_picker.dart` implements exactly the pattern that is
hand-rolled 45 times — title, items, `selectedValue`, check trailing — and is
used **nowhere**. `confirmMemberAction` (`member_row.dart:205-238`) is the
correct destructive-confirm shape and is used by two files out of the fifteen
that need it.

The consequences are visible, not theoretical. The hand-rolled sheets disagree
on:

- **Header type role** — `titleMedium` (`intake_actions.dart:274`,
  `notification_screen.dart:161`, `project_settings_screen.dart:212`,
  `member_row.dart:139, 184`, `filter_bar._sheetHeader`), `titleLarge`
  (`setup_screen.dart:221`, `my_issues_tab.dart:240`), or **no header at all**
  (`inbox_tab.dart:167`, `my_issues_tab.dart:281`, `spreadsheet_view.dart:192,
  218`, `command_palette.dart:262`).
- **Item text role** — `bodyLarge` vs `bodyMedium`, split roughly evenly.
- **Whether the current value is marked** — `issue_create_screen.dart:502, 536`
  shows a check; `spreadsheet_view.dart:199, 225` (the same two pickers) shows
  nothing; `my_issues_tab.dart:247` (project picker) shows nothing.
- **Check treatment** — 20dp untinted (`bottom_sheet_picker.dart:52`), tinted
  `primary` (`member_row.dart:193`), 18dp untinted
  (`profile_screen.dart:215`), 18dp (`menu_tab.dart:114`).
- **Background** — `command_palette.dart:23` and `intake_actions.dart:250`
  both pass `backgroundColor: Colors.transparent` and hand-roll a surface, and
  land on *different* colours (`scaffoldBackgroundColor` vs
  `surfaceContainer`). Everything else takes the themed `surfaceContainer`.
- **Drag handle** — `theme.dart:393` sets `showDragHandle: true`, so the
  framework already draws one. `my_issues_tab.dart:364-371`,
  `display_options.dart:82-89`, `command_palette.dart:271-283` and
  `app_navbar.dart:148-155` each paint a **second** one. (The nav bar's is
  legitimate — it overrides the background to transparent — the other three are
  duplicates.)
- **Press physics** — every one of them is `ListTile` ink, not
  `M3EPressable` spring. This is the one interaction surface in the app that
  still expresses press with a ripple.

And the dialogs disagree on the one thing that matters most:

| Site | Destructive button |
|---|---|
| `member_row.dart:226-232` (the shared helper) | `TextButton.styleFrom(foregroundColor: error)` — **correct** |
| `intake_actions.dart:196-198` | tinted `error` |
| `cycle_detail_screen.dart:363` | raw `TextStyle(color: error)` — wrong weight |
| `module_detail_screen.dart:407` | raw `TextStyle(color: error)` — wrong weight |
| `page_detail_screen.dart:147-149` | **plain, no error colour** |
| `view_list_screen.dart:122-124` | **plain, no error colour** |
| `workspace_views_screen.dart:77-80` | **plain, no error colour** |
| `project_settings_screen.dart:456-458` ("Delete State") | **plain, no error colour** |
| `project_settings_screen.dart:583-585` ("Delete Label") | **plain, no error colour** |
| `menu_tab.dart:386-397` ("Disconnect") | **plain, no error colour** |
| `issue_create_screen.dart:261-278` ("Discard") | **plain, no error colour** |

Seven irreversible actions are visually indistinguishable from "Cancel".

Confirm-dialog bodies are triplicated verbatim except the noun:
restore (`cycle_list:518`, `module_list:137`, `page_list:104`), archive
(`cycle_detail:287`, `module_detail:332`, `page_detail:83`), delete
(`cycle_detail:334`, `module_detail:378`, `page_detail:137`, `view_list:113`,
`workspace_views:67`).

**Fix, in order:**
1. Extend `confirmMemberAction` into a general `confirmDestructive(context,
   title:, message:, confirmLabel:)` and migrate all 15 sites. **Size M.** This
   alone fixes the seven undifferentiated buttons.
2. Give `BottomSheetPicker` the M3E treatment (`M3EPressable` rows, one header
   role, one check treatment, shape-carried selection) and migrate the ~20
   single-choice sheets to it. **Size L.**
3. Add a `M3ESheetHeader` and use it for the multi-select sheets that cannot
   be a picker. **Size M.**

## 3.2 [APP] Rows that are not `PlaneRow`

`plane_row.dart:38-56` states the case: *"Before this existed, 'a thing in a
list' was drawn by three unrelated widgets plus half a dozen inline `Row`s."*
The brief asked for the next instance. Here it is.

| File:line | What it draws | Should be |
|---|---|---|
| `menu_tab.dart:471-517` (`_MenuRow`) | 11 settings rows: icon + title + subtitle + chevron | `PlaneRow(icon:, title:, subtitle:, trailing:)`. Icon 22 vs `iconLarge` 20, chevron 18, no gap between title and subtitle, **no press spring, no `Semantics(button:)`** |
| `analytics_screen.dart:400-460` (`_ProjectRow`) | title + total + progress bar | `PlaneRow(title:, subtitleTrailing:, progress:, progressColor:)`. Also not tappable, while every other project representation opens the project |
| `analytics_screen.dart:467-527` (`_StatCard`) | `Container` + `M3EShape.large` + `outlineVariant` 0.8 | `PlaneRow(density: card)`'s decoration, reimplemented inline minus its physics and semantics |
| `notification_screen.dart:302-363` | notification row | `PlaneRow` — see 1.3 |
| `command_palette.dart:357` | search result | `PlaneRow`. `search_screen.dart:324-337` renders the **same** `SearchService.searchAll` payload as `PlaneRow`. Two renderings of one result list |
| `command_palette.dart:135` | project picker row | `PlaneRow` or `BottomSheetPicker` |
| `project_settings_screen.dart:220, 747, 834` | member candidates, states, GitHub repos | `PlaneRow`. Note `:724-729` in the same file *does* use `MemberRow` |
| `profile_screen.dart:210` (`_ThemeOption`) | theme mode row | `PlaneRow` |
| `spreadsheet_view.dart:75-112` | table row | Legitimately bespoke (it is a table), but see 2.6 for the 20dp tap target |

## 3.3 [APP] Three byte-identical `_header()` methods, and a fourth screen with none

`cycle_list_screen.dart:349-367`, `module_list_screen.dart:294-312` and
`page_list_screen.dart:160-178` are **the same 18 lines three times** —
`Padding(fromLTRB(20,8,12,4))` → `Text('$count $noun', bodySmall)` → `Spacer`
→ `ArchiveToggle`. Only the noun differs.

- `view_list_screen.dart` has **no header at all** — no count, no chrome.
- The five workspace screens put the identical count in `M3EAppBar.subtitle`
  instead (`workspace_cycles:82`, `workspace_modules:80`, `workspace_views:110`,
  `workspace_issues:178`, `workspace_members:310`). So "N cycles" is a body
  header on one screen and an app-bar subtitle on another.

**Fix:** one `ListCountHeader(count:, noun:, trailing:)` widget. **Size M.**

## 3.4 [APP] Section headers — five renderings of one concept

`SectionHeader` (uppercase overline + colour bar + count pill) is the shared
one, used at `cycle_list:389`, `issue_list:389, 440, 506`, `projects_tab:151`,
`search_screen:238`, `notification_screen:272`, `project_grouped_list:82`,
`my_issues_tab:651`. Everything else invents its own:

| File:line | Rendering |
|---|---|
| `kanban_board_screen.dart:124-152` | icon + `titleSmall` + bare `labelSmall @ 0.6` count. The board's group headers look nothing like the list's group headers for the same states |
| `calendar_view.dart:265-271, 323-329` | `Padding` + `Text(titleSmall)` reading `2026-07-26 (3 issues)` — count inlined into the string, **raw ISO date** on screen |
| `analytics_screen.dart:190-192` | plain `Text(titleMedium)`, ×3 |
| `project_settings_screen.dart:872-874` | plain `Text(titleMedium)` |
| `command_palette.dart:304, 320, 329` | `labelMedium` + `onSurfaceVariant`, ×3 |
| `search_screen.dart:185-214` | `M3EType.emphasized(titleSmall)` in a `Row` — *on a screen that also uses `SectionHeader` 24 lines later* |
| `workspace_members_screen.dart:342-345` | `Padding` + `Text(titleMedium)` |
| `cycle_detail_screen.dart:485-491`, `module_detail_screen.dart:560-566` | `M3EType.emphasized(titleSmall)` + separate `bodySmall` count |

Two call-site nits on the shared one: `my_issues_tab.dart:651-654` omits
`count:` (every other call site shows the pill), and
`notification_screen.dart:272-280` passes `'UNREAD'`/`'READ'` pre-uppercased
when `section_header.dart:43` uppercases internally.

**Size M.**

## 3.5 [APP] Chips — nine implementations of one concept

`M3EChip` · `PropertyChip` · `_LabelPill` **in `issue_row.dart:209`** ·
`_LabelPill` **in `issue_detail_screen.dart:2571`** ⚠︎ · `_ReactionChip`
(`reaction_bar.dart:79`) ⚠︎ · `_TabChip` (`intake_screen.dart:274`) ·
`_RelationChip` (`issue_detail_screen.dart:2365`) ⚠︎ · `_AssigneeChip`
(`issue_detail_screen.dart:2616`) ⚠︎ · stock `ChoiceChip`/`Chip`
(`workspace_members:129`, `project_settings:681, 687, 787`).

The two `_LabelPill`s are the clearest evidence of drift: same concept, same
data, two files, and they have **already diverged in three dimensions** —
`vertical: 3` vs `4`, dot `6` vs `8`, `labelSmall` vs `labelMedium` — plus
`issue_detail`'s uses `InkWell` where `issue_row`'s has no press at all.

Relatedly, `_parseColor(String hex)` is implemented **five times**:
`issue_row.dart:215`, `filter_bar.dart:575`,
`issue_detail_screen.dart:2350` ⚠︎, `:2608` ⚠︎,
`project_settings_screen.dart:619`.

`_ReactionChip` also expresses its selected state by fill/outline only
(`reaction_bar.dart:135-139`) with no shape change — documented at `:131-134`
as a deliberate choice against the light ramp, which is fair, but it means the
one chip a user toggles most often is the one that does not morph.

**Fix:** one `LabelPill` widget and one `parseHexColor` utility. **Size M.**

## 3.6 [APP] Empty, error and loading states

### Empty states

`EmptyStateWidget` exists and is used 24 times. The *scaffolding around it* is
copy-pasted with two different magic numbers:

`ListView(children: [SizedBox(height: MediaQuery.height * X), Center(EmptyStateWidget(…))])`

- **X = 0.2** — `my_issues_tab:637`
- **X = 0.25** — `cycle_list:375, 418`, `module_list:321, 351`,
  `workspace_views:124`, `workspace_issues:193`, `project_grouped_list:68`,
  `intake_screen:204`
- **X = 0.3** — `page_list:189`, `view_list:159`, `view_detail:127`,
  `inbox_tab:240`, `notification_screen:246`

`EmptyStateWidget` is *already* a `Center`; the spacer exists only to work
around it being placed in a non-scrollable branch. Half the call sites pass a
guidance `subtitle` and half do not (`cycle_list:377` and `module_list:324` do
not; `page_list:198` and `view_list:161` do).

And five screens do not use it at all:

| File:line | What it draws instead |
|---|---|
| `cycle_detail_screen.dart:502-509`, `module_detail_screen.dart:577-584` | `Padding(24)` + `Center(Text(bodySmall))`, no icon |
| `calendar_view.dart:274-277, 331-335` | centred `Text(bodySmall)` |
| `analytics_screen.dart:365-377, 382-393` | `_NoData` **and** `_Unavailable` — two more, next to a correct `EmptyStateWidget` at `:101`. Three treatments on one screen |
| `command_palette.dart:338-347` | `Center(Text)` with a bare `TextStyle` |
| `search_screen.dart:161-169` | `Center(Text)` — on a screen that uses `EmptyStateWidget` at `:176` |
| `project_settings_screen.dart:809-826` | inline `Row(Icon + Text)` |
| `spreadsheet_view.dart` | **nothing** — an empty table renders a header row over blank space |
| `kanban_board_screen.dart` | **nothing** — an empty column renders a title over blank space |

**Fix:** a `SliverFillEmptyState` / `centeredEmpty()` helper that removes the
spacer entirely, then migrate. **Size M.**

### Error states

- `view_list_screen.dart:146` — `if (_error != null) return ErrorStateWidget(…)`
  replaces the whole screen unconditionally, losing the list **and** the
  `RefreshIndicator`. The three sibling screens (`cycle_list:370`,
  `module_list:315`, `page_list:181`) guard with `&& _list.isEmpty` and keep
  stale rows. Two policies for one situation. **S**
- `inbox_tab.dart:95-102` — a failed fetch clears `_loading` and falls through
  to `EmptyStateWidget('No notifications')`. **Offline is indistinguishable
  from "all caught up."** `my_issues_tab.dart:602` uses `ErrorStateWidget`
  correctly. **S**
- `projects_tab.dart:51-61` — `_load` has no `try`/`catch`; a throw leaves
  `_initialLoading` set and `ProjectListSkeleton` shimmers forever.
  `ErrorStateWidget` is not even imported. **S**
- `issues_tab_screen.dart:51-59` — no `catch`; a failure leaves all four view
  modes showing their empty states. This screen owns the data for all four. **S**
- In the three "keep stale rows" screens, a *refresh* failure with data already
  on screen is silently swallowed — no snackbar, no banner. **M**
- Error message vocabulary, three dialects: `describeApiError(…)`
  (`workspace_views:97`, `workspace_members:81, 164, 199, 218, 236, 253`);
  `'Failed to X: $e'` (`cycle_list:134, 303`, `module_list:130, 255`,
  `page_list:132`, `cycle_detail:146, 215, 275, 314, 329, 359`); and raw
  `'Error: $e'`, which dumps the exception at the user
  (`view_list:106, 136`, `page_detail:163, 359`, `issue_list:238`). **M**

### Loading states

Skeleton and spinner are split with no discernible rule:

- **Skeleton** — `cycle_list:325`, `module_list:272`, `page_list:142`,
  `projects_tab:157`, `issues_tab:93`, `my_issues_tab:600`, `inbox_tab:232`
- **Spinner** (`LoadingStateWidget`) — `view_list:145`, all five workspace
  screens, `intake_screen:196`, `intake_duplicate_picker:130`,
  `notification_screen:237`, `search_screen:157`,
  `project_settings_screen:631`, `analytics_screen:77`,
  `issue_list:363, 420` (drafts and archive, while the live list beside them
  gets a skeleton)

Two are outright wrong: `view_list_screen.dart:145` is a spinner where its
three sibling tabs are skeletons, and `notification_screen.dart:237` is a
spinner even though `InboxSkeleton` exists (`skeleton_loader.dart:402`) and
`inbox_tab.dart:232` uses it for the same feed.

And two stock spinners survive despite the doc's claim
(`M3_EXPRESSIVE.md:137-138`) that none remain:
`issue_detail_screen.dart:1663, 2915` ⚠︎ — raw `CircularProgressIndicator`.

**Size M.**

## 3.7 [APP] Duplicated screens and controls

- **`my_issues_tab.dart:319-568` is a 250-line divergent copy of
  `showDisplayOptions`** (`display_options.dart:45`). `issue_list_screen.dart:330`
  calls the shared one. They have already drifted: option value text is
  `bodyLarge`+secondary vs `bodySmall`; the shared version gained
  `BoxConstraints(minHeight: 48)` (`display_options.dart:59`) which the copy
  lacks (`:331`); "Reset" is emphasized `titleSmall` vs `labelMedium`; the chips
  carry an extra `Semantics` in one and not the other. It also duplicates
  `DisplayState`'s fields as locals (`:311-317`). **Size M** — delete the copy.
- **`intake_detail_screen.dart:263-317` (`_Decision`) vs
  `intake_actions.dart:330-384` (`_ActionTile`)** — identical labels, icons and
  detail strings for the same four decisions, rendered as a filled bordered
  card in one and an unfilled unbordered row in the other, at `pressedScale`
  0.96 vs 0.97. **Size S.**
- **`setup_screen.dart:257-274` and `browser_login_screen.dart:178-191`** define
  the same `filledStyle`/`outlinedStyle`/`controlShape` twice — and both exist
  only because `theme.dart` is missing the fix in §2.5.2. **Size S.**
- **`menu_tab.dart:157-198`** hand-rolls a screen header where the three
  sibling home tabs use `M3EFlexibleHeaderScaffold`
  (`inbox_tab:228`, `my_issues_tab:574`, `projects_tab:126`). Fourth rendering
  of the home-tab header. **Size M.**
- **`menu_tab.dart:382-428`** — Disconnect is a `GestureDetector` + `Container`
  where `filledButtonTheme`/`outlinedButtonTheme` exist. **Size S.**
- **`issue_create_screen.dart:371-419` and `:421-464`** — two hand-rolled picker
  fields, copy-pasted rather than one widget, each with a bespoke state dot
  where `PlaneTheme.stateIcon` / `PropertyChip` is the app's state rendering.
  **Size S.**
- **`menu_tab.dart:370-376`** — `showAboutDialog` drops stock Material chrome
  (Material's own dialog layout and licence page) into an app that themes every
  other dialog. **Size S.**

## 3.8 [APP] Detail-screen action surfaces disagree

- `cycle_detail_screen.dart:383-388`, `module_detail_screen.dart:452-457` —
  a single `more_horiz` opening a sheet with edit / archive / delete.
- `page_detail_screen.dart:175-208` — the same three actions as **three
  separate app-bar icons**, one `emphasized: true`.
- `view_detail_screen.dart:116` — `M3EAppBar(title:)` with **no actions at
  all**; a view can be deleted from its row (`view_list:193`) but not from its
  own screen, and cannot be renamed anywhere.

**Size M.**

## 3.9 [APP] Favourites are on the project lists and missing from the workspace lists

`FavoriteToggle` is in `PlaneRow.trailing` on `cycle_list:479`,
`module_list:415`, `view_list:186`, `page_list:250` — and is **absent** from
`workspace_cycles_screen.dart:113-143`, `workspace_modules_screen.dart:113-149`
and `workspace_views_screen.dart:172-177` (delete only). The same cycle can be
starred from one list and not from the other. The workspace lists also do not
call `favoritesFirst`, which all four project lists do.

Conversely `workspace_views_screen.dart:162-169` renders `PlaneRowMeta` for
private/locked/filter-count that `view_list_screen.dart:174-200` never shows.

**Size M.**

## 3.10 [APP] Scaffolding drift on lists

- **Pull-to-refresh is dead on short lists on 9 screens.**
  `workspace_members_screen.dart:330` is the only list that sets
  `physics: const AlwaysScrollableScrollPhysics()`, with a comment explaining
  why. Without it, a list that does not fill the viewport cannot trigger its
  `RefreshIndicator` at all: `cycle_list:383`, `module_list:334, 363`,
  `page_list:206`, `view_list:168`, `view_detail:138`, `workspace_views:135`,
  `workspace_issues:208`, `project_grouped_list:75`. (The empty-state branches
  escape this by padding with a `SizedBox` — which is very likely why the magic
  spacer in §3.6 exists in the first place.) **Size S**, nine one-line edits.
- **All 23 `RefreshIndicator`s are stock Material** — a raised, elevated puck
  with the M3 arrow, in an app whose theme sets `elevation: 0` on everything
  and whose loading language is `M3ELoadingIndicator`. There is no
  `refreshIndicatorTheme` in `theme.dart`. **Size S.**
- **Bottom padding under the floating nav bar, five values.**
  `project_screen.dart:156` sets `extendBody: true`, so list content runs under
  the glass bar. `cycle_list`, `module_list`, `page_list`, `view_list` have
  **none** — the last row sits under the bar. `cycle_detail:547`,
  `module_detail:622` use 80. `workspace_views:136`, `workspace_issues:210`,
  `project_grouped_list:76`, `view_detail:139` use 20.
  `workspace_members:349` uses 32. The home tabs use 100
  (`projects_tab:161`, `inbox_tab:254`). **Size S.**
- `inbox_tab.dart:300-310` — the swipe background is a square, full-bleed
  `error @ 0.20` block behind rows that are `M3EShape.large` cards with 16dp
  side margins (`plane_row.dart:163-168`). The red rectangle extends past the
  card it is revealed behind. **Size S.**
- `issue_list_screen.dart:295` — this view mode is a `Scaffold`, nested inside
  `IssuesTabScreen`'s `Column`, inside `ProjectScreen`'s `Scaffold`. The other
  three view modes return a plain `Column`/`ListView`. One of the four paints
  an extra scaffold background. **Size S.**
- `cycle_detail_screen.dart:474`, `module_detail_screen.dart:549`,
  `calendar_view.dart:137` — `Divider` re-states or overrides `dividerTheme`
  (`theme.dart:311-315`), including its `space: 0`. Should be a bare
  `Divider()`. **Size S.**

---

# Part 4 — Navigation and transitions

## 4.1 [M3E] There is no route transition treatment at all

`grep` over `lib/` finds **zero** `PageTransitionsTheme`, zero
`PageRouteBuilder`, zero custom `PageRoute`. All **47** navigations are raw
`MaterialPageRoute`, so every screen-to-screen move uses Android's stock
`ZoomPageTransitionsBuilder` — a fixed ~300 ms `FastOutSlowIn` curve.

Meanwhile `M3EMotion.slowSpatial` (`motion.dart:32-37`) is documented in the
token table as *"Large surfaces travelling a long distance — full-screen
transitions"* and has **zero call sites**. So does `slowEffects`, and so does
`standardSpatial`.

In an app whose stated thesis is "motion is springs, not curves", the single
most frequent motion a user sees is a Material curve.

**Fix:** one spring-driven `PageTransitionsBuilder` installed in
`PlaneTheme._build()`. Nothing at the 47 call sites changes. **Size M** — this
is the highest ratio of visible change to code touched in the whole audit.

## 4.2 [APP] Sheets and dialogs do not share a treatment

Covered in §3.1. The theme-level parts:

- `theme.dart:401-407` sets `dialogTheme.shape` to `M3EShape.extraLarge`, yet
  `member_row.dart:216-218` re-specifies the identical shape locally. Redundant.
- `dialogTheme`, `bottomSheetTheme` and `snackBarTheme` have no
  `side: BorderSide`, while `popupMenuTheme` (`theme.dart:422`) does. In a
  zero-elevation app the hairline *is* the boundary. See §2.1.5. **Size S.**

---

# Part 5 — Where I would argue with a documented decision

Kept separate, as the brief requires. These are **not** findings; they are two
places where following the written decision has produced a result I think the
authors would not want.

**1. "Flat everywhere, hairline outlines" is not actually applied to the
overlay surfaces.** The decision table says elevation is replaced by 0.5px
borders. `cardTheme`, `dialogTheme`, `bottomSheetTheme` and `snackBarTheme`
have *neither* — no elevation and no border. On the dark theme the surface
ramp carries them. On the light theme, `snackBarTheme`'s
`surfaceContainerHighest` (`#E5E5E5`) on `#FFFFFF` is 1.13:1 and it *floats*,
so a message can appear over a `#F7F7F7` card with no boundary between them at
all. I do not think this contradicts the decision — I think it is the decision
not having been carried through to four component themes. Adding the hairline
is faithful to the brief, not a departure from it.

**2. `issue_listing_switcher.dart:46-48` chooses 38dp deliberately** — *"shorter
than the group's default so the header stays a list header rather than a
toolbar"* — and that is a real density argument that I would normally defer to.
But it puts three segment targets 10dp under the accessibility minimum, and the
identical control on the adjacent screen is 48. Density is a legitimate axis to
trade on; the touch-target floor is not one of the axes. I would take the 48 and
find the density elsewhere (tighter horizontal padding, `dense` labels).

---

# Part 6 — Not design findings, but found while looking

Reported because they are user-visible and someone should own them, not because
they belong to this audit.

- **There is no way to create a cycle, module, page or view.** All four create
  flows are fully built and have **zero call sites** — verified by grep across
  the repo: `cycle_list_screen.dart:197 _showCreateCycleDialog`,
  `module_list_screen.dart:180 _showCreateModuleDialog`,
  `page_list_screen.dart:84 _createPage`, `view_list_screen.dart:66 _createView`.
  `project_screen.dart:136-155`'s only action is "New issue". Two empty states
  (`page_list:200`, `view_list:163`) tell the user to create one.
- **The "Grouping" display option in My issues does nothing.**
  `my_issues_tab.dart:635` calls `groupIssuesByStateGroup` unconditionally;
  `_grouped` (`:198`) and `_groupColor` (`:208`) are dead.
  `issue_list_screen.dart:505` honours the setting.
- **The spreadsheet is not a table.** `spreadsheet_view.dart:45` and `:74` give
  the header row and *every data row* its own `SingleChildScrollView`, so
  scrolling one row horizontally moves neither the header nor any other row.
- **`issue_list_screen.dart:57` `_filterState` is never assigned** — no
  `FilterBar` is rendered on that screen — so `hasActiveFilters` can never be
  true, the "No issues match filters" branch (`:487`) is unreachable, and
  `_saveAsView` (`:188-242`, with its own dialog) has no call site.
  `FilterBar` itself has **zero call sites** app-wide.
- `menu_tab.dart:347-350` — `SizedBox(width: 16, height: 16, child:
  M3ELoadingIndicator(size: 18))`; the indicator overflows its box.
  (`profile_screen.dart:145-150` already fixed the identical bug.)
- `analytics_screen.dart:320, 348` — fixed `SizedBox(width: 80)` / `width: 44`
  for a label and a count; both clip at a 1.3+ text scale. `main.dart` installs
  no `builder:` clamping `textScaler`.
- Dead code: `command_palette.dart:40-45` (`_CommandPaletteState` is a
  pass-through no route uses), `command_palette.dart:368` (`_CommandType` set
  and never read), `issues_tab_screen.dart:78-86` (`_fromCache`, `_refreshing`),
  `my_issues_tab.dart:124-131` (`_hasStateFilterForDone`),
  `M3EFloatingToolbar` and `M3ESplitButton` (documented as intentional).
- `workspace_members_screen.dart:124-135` — role `ChoiceChip`s in a bare `Row`
  inside an `AlertDialog`; three roles at a large font scale overflow rather
  than wrap. `module_detail_screen.dart:480-496` uses `Wrap` for the same job.

---

# Part 7 — What is already right

Do not churn these.

**The token layer is correct and complete.** Zero hardcoded radii, zero hex
outside `theme.dart`, two justified `fontSize:` literals in the whole app. The
`M3EShape` scale, `M3EType` scale and `M3EMotion` spring set are all coherent
and all actually used.

**Spatial vs effects springs are paired correctly wherever springs are used.**
`M3EChip` (`chip.dart:60-68`) and `M3EIconButton` (`icon_button.dart:125-131`)
each run *two* springs — `fastSpatial` for the corner morph, `defaultEffects`
for the tint — with a comment explaining why a single curve could express
neither. `flexible_app_bar.dart:130-132` uses `fastEffects` for the divider's
opacity. `chip.dart:53-59` documents removing an `AnimatedContainer` that was
low-pass-filtering the spring underneath it. This is the design language
working as intended.

**`M3ESpringBuilder` is the right primitive** and its reduce-motion handling
(`motion.dart:113-118, 142-147`) is correct — it uses `animateWith`, which the
framework does not scale, so the explicit check is load bearing.

**`M3EPressable`'s semantics contract is correctly reasoned and documented**
(`motion.dart:238-262`). So is `PlaneRow`'s `trailing`-slot split
(`plane_row.dart:96-99, 210-217`) — the gesture and semantics node cover the
content while the press scale covers the whole surface, which is exactly what
lets a real button live in a row.

**`M3EIconButton` is the model for the rest of the app to follow.** Required
`tooltip`, enforced 48dp target regardless of visual size, size ramp, corner
morph on selection, foreground dimmed on disabled.

**App-bar coverage is complete.** Every one of the 24 `Scaffold(appBar:)` sites
is `M3EAppBar`; the three main home tabs use `M3EFlexibleHeaderScaffold`. Only
`search_screen.dart:124` opts out (see 1.5).

**`M3ETextField`'s `MergeSemantics` reasoning** (`text_field.dart:74-82`) is
correct and subtle, and it is the fix for a real defect the doc records.

**Colour accessibility work is thorough and should not be undone.** The
light/dark twins for priority and state colours (`theme.dart:72-106`), the two
project-badge sets (`:127-148`), the switch thumb/track override (`:378-389`)
and the light surface-ramp stepping (`:206-222`) are all documented with
measured contrast ratios. `issue_row.dart:203-208` correctly refuses to trust a
server-supplied hex as a text colour.

**`PlaneRow` and `IssueRow` are the right architecture** — one row, one
mapping layer, `show*` flags that also adjust the semantic label so what the row
announces always matches what it draws (`issue_row.dart:19-22, 100-123`).

**`ArchiveToggle`, `FavoriteToggle` and `MemberRow`** are all correctly built
one-affordance-for-all-screens widgets with correct semantics. The problem with
them is only that the workspace screens forgot to use two of them (§3.9).

**The documented decisions are sound.** Linear's density over M3's stock sizes,
the untouched palette, the Compose bridge kept opt-in per call site, the
`ButtonGroup` weight fix — none of these should be revisited.

---

## Appendix: verification commands

```
# radii, colour and type literals — all should stay at zero
grep -rn "BorderRadius.circular([0-9]" lib/ | grep -v M3EShape
grep -rn "Color(0x" lib/ --include='*.dart' | grep -v config/theme.dart
grep -rn "fontSize:" lib/

# the two accessibility patterns
grep -rn "Semantics(" lib/ --include='*.dart'
grep -rn "excludeSemantics" lib/ --include='*.dart'

# the shared widgets that are not being used
grep -rn "BottomSheetPicker" lib/ --include='*.dart'
grep -rn "confirmMemberAction" lib/ --include='*.dart'
grep -rn "slowSpatial\|PageTransitionsTheme" lib/ --include='*.dart'

# stock Material leakage
grep -rn "showModalBottomSheet\|AlertDialog(\|ListTile(\|InkWell(" lib/ --include='*.dart'

# on device
tool/adb_drive.py check     # run per screen after the Part 1 fixes
```
