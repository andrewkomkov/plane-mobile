# Plane Mobile -- UX Screen Reference

This document describes every screen in the Flutter app, including layout details,
component usage, font sizes, padding values, colors, interactions, and navigation.
It is a standalone reference for the designer -- no need to read code.

The overall visual direction is inspired by **Linear's mobile app**: minimal chrome,
restrained typography, monochromatic icons, frosted-glass bottom nav, tight spacing.

---

## Table of Contents

1. [Design System](#design-system)
2. [Navigation Flow](#navigation-flow)
3. [Shared Components Catalog](#shared-components-catalog)
4. [Home -- Inbox Tab](#1-home--inbox-tab)
5. [Home -- My Issues Tab](#2-home--my-issues-tab)
6. [Home -- Projects Tab](#3-home--projects-tab)
7. [Home -- Menu Tab](#4-home--menu-tab)
8. [Home -- Search Tab](#5-home--search-tab)
9. [Project Screen (container)](#6-project-screen)
10. [Project Settings Screen](#7-project-settings-screen)
11. [Issues Tab Screen (project)](#8-issues-tab-screen)
12. [Issue List Screen](#9-issue-list-screen)
13. [Issue Detail Screen](#10-issue-detail-screen)
14. [Issue Create Screen](#11-issue-create-screen)
15. [Kanban Board Screen](#12-kanban-board-screen)
16. [Calendar View](#13-calendar-view)
17. [Spreadsheet View](#14-spreadsheet-view)
18. [Cycle List Screen](#15-cycle-list-screen)
19. [Cycle Detail Screen](#16-cycle-detail-screen)
20. [Module List Screen](#17-module-list-screen)
21. [Module Detail Screen](#18-module-detail-screen)
22. [Page List Screen](#19-page-list-screen)
23. [Page Detail Screen](#20-page-detail-screen)
24. [Page Edit Screen](#21-page-edit-screen)
25. [View List Screen](#22-view-list-screen)
26. [View Detail Screen](#23-view-detail-screen)
27. [Notification Screen](#24-notification-screen)
28. [Analytics Screen](#25-analytics-screen)
29. [Profile Screen](#26-profile-screen)
30. [Setup Screen (Login)](#27-setup-screen)
31. [Command Palette](#28-command-palette)
32. [Issues & Inconsistencies Summary](#issues--inconsistencies-summary)

---

## Design System

The visual language is **Material 3 Expressive**, implemented natively in Dart
(Flutter has no M3E components, and the `material3:1.5.0-alpha24` artifact is
Compose-only). See [M3_EXPRESSIVE.md](M3_EXPRESSIVE.md) for the tokens,
components and the Linear-vs-Expressive trade-offs. This section covers what a
designer needs at the screen level.

### Font Family
**Inter** -- used across both themes via `fontFamily: 'Inter'`.

### Typography Scale

Roles come from M3E (`M3EType.textTheme`); sizes stay at Linear's compact
density. Any role can take its **emphasized** cut (one weight step up, slightly
tighter tracking) via `M3EType.emphasized()` -- used for the single element that
should dominate a screen.

| Role | Size | Weight | Usage |
|---|---|---|---|
| `headlineMedium` | 24 | w700 | Large screen titles ("My issues", "Inbox") |
| `headlineSmall` | 20 | w600 | AppBar titles (project name, "Settings") |
| `titleLarge` | 18 | w600 | Sheet headers |
| `titleMedium` | 15 | w500 | Issue names, list item titles |
| `titleSmall` | 13 | w500 | Compact labels |
| `bodyLarge` / `bodyMedium` | 15 / 14 | w400 | Descriptions, comments, markdown |
| `bodySmall` | 12 | w400 | Timestamps, IDs, subtitles |
| `labelLarge` | 14 | w500 | Buttons |
| `labelMedium` / `labelSmall` | 12 / 11 | w500 | Chips, badges, pills |
| `M3EType.overline` | 11 | w600 | Uppercase group headers ("IN PROGRESS") |

The legacy `PlaneTheme.font*` constants still exist and still resolve to the
same sizes, so older screens render identically.

### Icon Sizes

| Token | Size | Usage |
|---|---|---|
| `iconSmall` | 14 | Priority/state icons inside chips, inline indicators |
| `iconMedium` | 16 | Priority/state icons in issue rows, nav hint icons |
| `iconLarge` | 20 | Leading icons in PlaneRow, action icons |
| Nav bar icons | 22 | Bottom navigation bar items |

### Color Palette

#### Brand / Accent
- Accent: `#5E6AD2` (indigo, similar to Linear)

#### Dark Theme
| Role | Hex | Usage |
|---|---|---|
| Background | `#0A0A0A` | Scaffold background |
| Surface | `#141414` | Cards, input fills |
| Border | `#252525` | Dividers, card borders |
| Text primary | `#F1F1F1` | Titles, body text |
| Text secondary | `#8A8A8A` | Subtitles, captions |

#### Light Theme
| Role | Hex | Usage |
|---|---|---|
| Background | `#FFFFFF` | Scaffold background |
| Surface | `#F8F8F8` | Cards, input fills |
| Border | `#E8E8E8` | Dividers, card borders |
| Text primary | `#1A1A1A` | Titles, body text |
| Text secondary | `#6B6B6B` | Subtitles, captions |

#### Priority Colors
| Priority | Hex | Icon |
|---|---|---|
| Urgent | `#EF4444` | `Icons.error` (filled) |
| High | `#F97316` | `Icons.signal_cellular_alt` (3 bars) |
| Medium | `#EAB308` | `Icons.signal_cellular_alt_2_bar` |
| Low | `#3B82F6` | `Icons.signal_cellular_alt_1_bar` |
| None | `#6B7280` | `Icons.more_horiz` |

#### State Group Colors
| State | Hex | Icon |
|---|---|---|
| Backlog | `#6B7280` | `Icons.circle_outlined` |
| Unstarted | `#9CA3AF` | `Icons.circle_outlined` |
| Started | `#F59E0B` | `Icons.timelapse` |
| Completed | `#22C55E` | `Icons.check_circle` |
| Cancelled | `#EF4444` | `Icons.cancel` |

### Shape Scale

Corners follow the M3 Expressive scale (`M3EShape`). Shape is an *interactive*
property: selected chips pull their corners in, and pressed surfaces square off
slightly. Never hard-code a radius -- use the token.

| Token | Radius | Usage |
|---|---|---|
| `extraSmall` | 4 | Inline markers |
| `small` | 8 | Selected chip corners, button-group inner corners |
| `medium` | 12 | Pressed-state corner |
| `large` | 16 | Cards, issue tiles, inputs, list items, FAB |
| `largeIncreased` | 20 | -- |
| `extraLarge` | 28 | Dialogs |
| `extraLargeIncreased` | 32 | Bottom sheets |
| `full` | stadium | Chips, buttons, nav indicator, label pills, badges |

### Spacing Rules
- Screen title padding: `EdgeInsets.fromLTRB(20, 14, 20, 0)` (handled by `M3EFlexibleHeaderScaffold`)
- Section header padding: `EdgeInsets.fromLTRB(22, 22, 20, 8)`
- Issue tile: outer `symmetric(horizontal: 16, vertical: 2)`, inner `symmetric(horizontal: 16, vertical: 14)`
- Item tile: outer `symmetric(horizontal: 16, vertical: 2)`, inner `symmetric(horizontal: 16, vertical: 14)`
- Bottom padding on scrollable lists: 100 (to clear the navbar)
- Card inner padding (Kanban): `EdgeInsets.all(12)`
- Chip inner padding: `symmetric(horizontal: 14, vertical: 7)`, dense `(10, 5)`
- FAB placement over a list: `right: 20, bottom: 96`

### Borders and Elevation
- Everything is **flat** -- elevation 0 on every component theme. Separation
  comes from hairlines and surface steps, not shadows. The only shadow in the
  app is under the floating glass bars.
- **One border treatment app-wide:** 0.8px, `colorScheme.outlineVariant`.
  `colorScheme.outline` is not used for borders -- it is too heavy against the
  near-black surfaces and was the source of the app looking unevenly outlined.
- Divider: 0.5px, `colorScheme.outlineVariant`
- Focused input outline: 1.6px, `colorScheme.primary`

### Touch targets
Nothing interactive is smaller than 48dp. Where a control must *look* smaller
(a dense markdown toolbar, an inline chip action), `M3EIconButton` keeps the
48dp target and shrinks only the drawn circle.

### Motion

No component animates on a fixed duration + curve; everything runs on a spring.
Use `M3EPressable` for touch feedback and `M3ESpringBuilder` for anything that
tracks a changing target. Full token table in
[M3_EXPRESSIVE.md](M3_EXPRESSIVE.md).

---

## Navigation Flow

```
SetupScreen (login)
    |
    v
HomeScreen (IndexedStack)
    |--- [0] InboxTab
    |--- [1] MyIssuesTab ---> IssueDetailScreen
    |--- [2] ProjectsTab ---> ProjectScreen (IndexedStack)
    |         |                    |--- [0] IssuesTabScreen ---> IssueListScreen / KanbanBoard / Spreadsheet / Calendar
    |         |                    |--- [1] PageListScreen ---> PageDetailScreen / PageEditScreen
    |         |                    |--- [2] ModuleListScreen ---> ModuleDetailScreen
    |         |                    |--- [3] CycleListScreen ---> CycleDetailScreen
    |         |                    |--- [4] ViewListScreen ---> ViewDetailScreen
    |         |                    |--- (AppBar) IssueCreateScreen
    |         |                    |--- (AppBar) ProjectSettingsScreen
    |         |                    |--- (Search) SearchScreen
    |--- [3] MenuTab
    |         |--- NotificationScreen
    |         |--- AnalyticsScreen
    |         |--- WorkspaceMembersScreen
    |         |--- ProfileScreen
    |--- [4] SearchScreen (hidden 5th tab)
    |
    +--- (bottom nav) AppNavBar (glass pill, 4 tabs + search bubble)
    +--- (long-press search) CommandPalette (modal bottom sheet)
```

### Bottom Navigation Bars

**Home Screen NavBar:** 4 items + search
- Inbox (inbox icon)
- My Issues (circle icon)
- Projects (bolt icon)
- Menu (diamond icon)
- Search bubble (separate glass pill, 58x58)

**Project Screen NavBar:** 5 items + search
- Issues (list_alt icon)
- Pages (description icon)
- Modules (view_module icon)
- Cycles (loop icon)
- Views (view_list icon)
- Search bubble (opens SearchScreen as push route)

---

## Shared Components Catalog

### M3EIconButton
**Path:** `lib/widgets/m3e/icon_button.dart`
**Props:** `icon`, `tooltip` (required), `onPressed`, `size`, `style`, `color`, `selected`
**Sizes:** `extraSmall` 32/18, `small` 40/20, `medium` 48/22 (default), `large` 56/26 — container/icon in dp.
**Styles:** `standard` (no fill until pressed), `filled` (tonal, for the one primary action), `outlined`.
**Rules it enforces:** the touch target never drops below 48dp even when the visible circle is smaller, so dense toolbars stay thumb-usable; selected state morphs the corner from full-round toward `medium` as well as filling, so state does not depend on colour alone.
**Why `tooltip` is required:** that string is also the accessibility label. An icon-only control without one is invisible to screen readers and to `tool/adb_drive.py`. Making it required is what stops the app regressing into anonymous icons.
**Used by:** every icon-only control in the app. `M3EAppBarAction` is a thin naming wrapper over it.

### M3ETextField
**Path:** `lib/widgets/m3e/text_field.dart`
**Props:** `label` (required), `hint`, `controller`, `onChanged`, `prefixIcon`, `suffix`, `compact`, plus the usual `obscureText`/`keyboardType`/`maxLines`
**Layout:** filled on `surfaceContainerLow`, outline always visible at 0.8px `outlineVariant`, thickening to 1.6px `primary` on focus. `compact: true` single-line fields are stadium-shaped (search); everything else uses `M3EShape.large`.
**Why the label is required:** Android drops a hint from the accessible name as soon as the field has content, so a hint-only field goes anonymous exactly when it holds data. `label` is published as semantics regardless of what is typed.
**Used by:** every text input in the app.

### M3E component set
**Path:** `lib/widgets/m3e/`
`M3EButtonGroup`, `M3ESplitButton`, `M3EFabMenu`, `M3EFlexibleHeaderScaffold`,
`M3EAppBar`, `M3ELoadingIndicator`, `M3EChip`, `M3EFloatingToolbar`,
`M3EGlassContainer`.
Full behaviour reference in [M3_EXPRESSIVE.md](M3_EXPRESSIVE.md).

### M3EAppBar
**Path:** `lib/widgets/m3e/app_bar.dart`
**Props:** `title`, `subtitle`, `actions`, `leading`, `showDivider`, `bottom`, `backgroundColor`
**Layout:** 56px row, title in `headlineSmall` (20/w600) with optional `bodySmall` subtitle beneath, hairline divider below. Back button appears only when the route can pop. Actions are `M3EAppBarAction` (44x44 tap target, press-squeeze to 0.86); pass `emphasized: true` to give the single primary action a tonal circle.
**Used by:** every screen that is not a home tab -- issue detail/create, cycles, modules, pages, views, notifications, analytics, profile, project, project settings, sign-in.

### AppNavBar
**Path:** `lib/widgets/app_navbar.dart`
**Props:** `items` (List<NavItem>), `currentIndex`, `onTap`, `showSearch`, `onSearchTap`, `onSearchDoubleTap`, `onSearchLongPress`, `pendingWrites`
**Layout:** Frosted-glass pill (`M3EGlassContainer`, blur 30/30). Height 60px, fully rounded. The M3E active indicator is a 56x34 tinted pill that **springs between destinations** (`defaultSpatial`) rather than cross-fading; the active destination reveals its label beneath the icon. Search is a separate 56x60 glass pill.
**Padding:** `EdgeInsets.fromLTRB(16, 0, 16, 8)` -- sits at screen bottom via `extendBody: true`.
**Overflow:** If items > 5, extras go to a "More" bottom sheet.
**Gestures on search:** tap = open search tab, double-tap = open with auto-focus, long-press = open command palette.

### M3EFlexibleHeaderScaffold
**Path:** `lib/widgets/m3e/flexible_app_bar.dart`
**Props:** `title`, `overline`, `bottom` (persistent row), `actions`, `leading`, `body`, `collapseDistance`
**Layout:** Toolbar row (brand mark + actions) above a large 24/w700 title. As the body scrolls, the large title row collapses continuously and the toolbar cross-fades from the "Plane" brand to a 17/w600 inline title; the divider fades in only once content is underneath.
**Replaces** the former `ScreenHeader` (deleted).
**Used by:** InboxTab, MyIssuesTab, ProjectsTab.

### SectionHeader
**Path:** `lib/widgets/section_header.dart`
**Props:** `label`, `count` (optional int), `color` (optional)
**Layout:** Padding `(22, 22, 20, 8)`. Label uses `M3EType.overline` (11/w600, uppercase). When `color` is set, a 3x12 fully-rounded colour bar carries the state-group hue so the label itself stays legible. Count sits in a stadium badge on `surfaceContainerHigh`.
**Used by:** MyIssuesTab, ProjectsTab, IssueListScreen, CycleListScreen, NotificationScreen, SearchScreen.

### PlaneRow
**Path:** `lib/widgets/plane_row.dart`
**Replaces** the former `IssueTile`, `ItemTile` and the `IssueRow` wrapper (all deleted), plus the inline rows CycleListScreen, ModuleListScreen and ViewListScreen each built for themselves.
**Props:** `icon`/`iconColor`/`leading`, `identifier`, `badges`, `title`/`titleMaxLines`/`emphasizeTitle`, `subtitle`/`subtitleTrailing`, `chips`, `progress`/`progressColor`, `metadata`, `avatars`, `trailing`, `density`, `highlighted`, `selected`, `semanticLabel` (required), `onTap`, `onLongPress`
**Layout:** identifier line (identifier + badges), title, subtitle line (subtitle + a bulleted `subtitleTrailing`), chips wrap, progress bar. `metadata` and `avatars` form a right-hand cluster; `trailing` sits beyond it.
**Densities:** `standard` — rounded card (`M3EShape.large`) on `surfaceContainerLow`, outer `(16, 2)`, inner `(16, 14)`. `compact` — no fill, inner `(16, 10)`, text in the same place as standard, used by the calendar's day pane. `card` — the same slots stacked, outlined, for the 280dp board column.
**Press feedback:** the whole surface squeezes on touch-down and springs back with overshoot. The gesture and the semantics node cover the content region only, so an interactive `trailing` keeps its own accessibility label; the scale is lifted onto the surface so the card still moves as one piece.
**Semantics:** `semanticLabel` is required — `M3EPressable` replaces the subtree's semantics with it, and the app is driven from outside through those labels (`tool/adb_drive.py`).
**Used by:** every list in the app, through `IssueRow` for issues and directly for everything else.

### IssueRow
**Path:** `lib/widgets/issue_row.dart`
**Props:** `issue`, `state`, `identifier`, `subtitle`, `timeAgo`, `showId/showProject/showAssignee/showDueDate/showPriority/showState/showLabels/showSubIssues`, `unread`, `highlighted`, `maxTitleLines`, `density`, `semanticExtras`, `onTap`, `allLabels`, `allMembers`
The mapping from an `Issue` to a `PlaneRow`, and the only place that mapping is written down: state icon → leading, `PLM-123` → identifier, priority → badge, labels → chips, sub-issue count / due date / project → metadata, assignees → avatars. The `show*` flags follow the display-options sheet and drop a hidden property from the accessibility label too.
**Used by:** IssueListScreen, MyIssuesTab, InboxTab, ViewDetailScreen, CalendarView, KanbanBoardScreen, CycleDetailScreen, ModuleDetailScreen.

### PropertyChip
**Path:** `lib/widgets/property_chip.dart`
**Props:** `icon`, `iconColor`, `label`, `onTap`
**Layout:** `M3EShape.small` corners, 0.8px `outlineVariant` border, padding `(10, 6)`. Icon 14px keeps its **semantic** colour (priority red, state green) while the label stays neutral, so a row of these reads as data rather than as filters. `M3EPressable` (0.94) when tappable.
**Distinct from `M3EChip`,** which is the selectable filter chip -- selection there changes corner radius as well as tint.
**Used by:** IssueDetailScreen (status, priority, labels, assignee, dates), CycleDetailScreen, ModuleDetailScreen, ModuleListScreen.

### LoadingStateWidget
**Path:** `lib/widgets/loading_state.dart`
Centered `M3ELoadingIndicator` (44px) -- a filled shape rotating while morphing through seven lobed forms. Note for tests: it animates forever, so `pumpAndSettle` will time out; use `pump(duration)`.

### ErrorStateWidget
**Path:** `lib/widgets/loading_state.dart`
Centered error icon (40px) + message (`fontBody`) + optional Retry button.

### EmptyStateWidget
**Path:** `lib/widgets/loading_state.dart`
Centered icon (40px, 50% opacity) + message (`fontBody`) + optional subtitle (`fontSection`, 70% opacity).

### DisplayOptions (bottom sheet function)
**Path:** `lib/widgets/display_options.dart`
Shows a Linear-style bottom sheet with grouping/ordering/sort/completed-filter/sub-issues/max-title-lines/row-properties toggles. Row properties are toggle chips in a Wrap.
**Used by:** IssueListScreen. MyIssuesTab has its own copy (slightly different).

---

## Screen Details

---

### 1. Home -- Inbox Tab

**Path:** `lib/screens/home/inbox_tab.dart`
**Purpose:** Shows activity notifications on issues the user is involved with -- like Linear's Inbox.

**Layout:**
- Header: `M3EFlexibleHeaderScaffold(title: 'Inbox', overline: 'PENDING NOTIFICATIONS')` -- collapses into the toolbar on scroll.
- Body: `ListView.builder` of `IssueRow` with a subtitle (the activity text) and a `timeAgo`.
- Empty state: icon `Icons.inbox_outlined`, "No notifications", subtitle "Activity on your issues will appear here".
- Loading: `LoadingStateWidget`.
- Bottom padding: 100.

**Components used:** M3EFlexibleHeaderScaffold, IssueRow, LoadingStateWidget, EmptyStateWidget.

**Data shown:** Notification title (issue name), activity text (actor + action), priority icon, state icon, issue ID, read/unread status, time ago.

**Interactions:**
- Pull-to-refresh.
- Tap notification -> push to IssueDetailScreen.
- List separator: `Divider(indent: 60, endIndent: 20, height: 0.5)`.

**Navigation:** Reached from Home bottom nav tab 0. Tapping an item pushes IssueDetailScreen.

**Current issues:**
- No filter tabs (all/mentions/assigned) like Linear has.
- No swipe-to-archive or swipe-to-snooze.
- No read/unread toggle action.
- Separator indent is 60 but icon column is only ~32 wide -- misaligned.
- Uses custom API call (`Dio`) directly instead of a service. Inconsistent with other tabs that use the DataCache provider.
- Empty state icon is plain, no illustration.

**Reference:** Similar to Linear's Inbox tab.

---

### 2. Home -- My Issues Tab

**Path:** `lib/screens/home/my_issues_tab.dart`
**Purpose:** Shows all issues assigned to or created by the current user, across all projects.

**Layout:**
- Header: `M3EFlexibleHeaderScaffold` with title "My issues", a `more_horiz` action, and an `M3EButtonGroup` (Assigned / Created / All) pinned below the title. Pressing a scope widens it while its neighbour compresses.
- Create is an `M3EFabMenu` at `right: 20, bottom: 96` -- expands to "New issue" and "Display options" over a blurred scrim.
- Pill filters: rounded containers (radius 8), padding `(14, 6)`, `fontSection` (13), filled when selected.
- Body: grouped list with `SectionHeader` (grouped by state group: Backlog, Unstarted, etc.) + `IssueRow`.
- Empty state: "No issues", "All caught up".
- Loading: `LoadingStateWidget`.
- Error: `ErrorStateWidget` with retry.

**Components used:** M3EFlexibleHeaderScaffold, M3EButtonGroup, M3EFabMenu, M3EChip (display options), SectionHeader, IssueRow, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** Issue name, priority icon, state icon, issue ID with project identifier. Configurable via row properties (status, priority, id, labels, project, due date, assignee).

**Interactions:**
- Pull-to-refresh.
- Pill filter toggle (assigned/created/all).
- `...` menu -> "Display options" or "Refresh".
- Display options bottom sheet: grouping, ordering, sort direction, completed filter, sub-issues toggle, max title lines, row properties (toggle chips).
- Tap issue -> push to IssueDetailScreen, reload on return.

**Navigation:** Home tab 1. Navigates to IssueDetailScreen.

**Current issues:**
- Edit icon in header does nothing (`onPressed: () {}`).
- Display options are duplicated between this screen and `display_options.dart` widget -- should consolidate.
- No view mode switcher (list-only, no kanban/calendar for My Issues).
- groupBy logic in `_grouped` uses `groupIssuesBy` but the build method always calls `groupIssuesByStateGroup` -- the display options grouping selection only partially works.
- No count badge on the section headers in the build method.

**Reference:** Similar to Linear's "My Issues" screen with pill filters.

---

### 3. Home -- Projects Tab

**Path:** `lib/screens/home/projects_tab.dart`
**Purpose:** Lists all projects in the current workspace.

**Layout:**
- Header: `M3EFlexibleHeaderScaffold(title: 'Projects')` with a stadium search field pinned below the title (it filters the whole list, so it does not scroll away).
- Body: `ListView.builder` of rows this screen still builds inline (**not** `PlaneRow` — see Design Inconsistencies). Each project has a leading 40x40 rounded square with the project identifier text centered inside, tinted from the badge palette. Trailing: chevron_right icon.
- Bottom padding: 100.

**Components used:** M3EFlexibleHeaderScaffold, SectionHeader, LoadingStateWidget.

**Data shown:** Project name, project identifier (in leading square).

**Interactions:**
- Pull-to-refresh.
- Tap project -> push to ProjectScreen.

**Navigation:** Home tab 2. Navigates to ProjectScreen.

**Current issues:**
- No empty state -- just shows nothing if no projects.
- No project creation option.
- No project description or member count shown.
- No search/filter for projects.
- The 36x36 leading square with identifier looks functional but could be more polished (no emoji support, no project icon).

**Reference:** Similar to Linear's sidebar project list, but in a full-screen tab.

---

### 4. Home -- Menu Tab

**Path:** `lib/screens/home/menu_tab.dart`
**Purpose:** Workspace info, user profile, navigation to secondary screens, logout.

**Layout:**
- Top section: Workspace name + logo (tappable for workspace switcher), with `unfold_more` icon. Padding `(20, 16, 20, 0)`.
- User card: CircleAvatar (radius 22) + display name (15/w500) + email (12, secondary). Padding `(20, 16)`.
- Divider.
- Menu items, built inline rather than as `PlaneRow`: Notifications, Analytics, Workspace Members, Switch Workspace, Profile & Appearance, About.
- Divider.
- Disconnect (red icon, with confirmation dialog).

**Components used:** LoadingStateWidget, EmptyStateWidget, ErrorStateWidget (on workspace members sub-screen).

**Data shown:** Workspace name/logo, user name/email/avatar, menu items.

**Interactions:**
- Tap workspace name -> bottom sheet workspace picker (radio-style with check icon).
- Tap menu items -> push to respective screens.
- Disconnect -> confirmation dialog -> clear storage and logout.

**Navigation:** Home tab 3. Pushes to NotificationScreen, AnalyticsScreen, WorkspaceMembersScreen, ProfileScreen.

**Current issues:**
- No workspace logo fallback is elegant enough -- just a letter in a circle.
- The workspace switcher bottom sheet doesn't show a loading indicator if slow.
- Menu items are drawn by this screen instead of `PlaneRow`, and the icon style isn't consistent (some outlined, some not).
- About dialog uses Flutter's default `showAboutDialog` -- looks generic.

**Reference:** Similar to Linear's "Settings" sidebar section.

---

### 5. Home -- Search Tab

**Path:** `lib/screens/search/search_screen.dart`
**Purpose:** Global workspace search across issues, projects, pages, cycles, modules.

**Layout:**
- AppBar with embedded `TextField` (hint: "Search across workspace...", prefix search icon). Clear button when text present.
- When no query: shows "Recent searches" section with `PlaneRow` (history icon), or empty state ("Search issues, projects, pages and more").
- When querying: shows grouped results with `SectionHeader` per entity type + `_SearchResultTile` (a `PlaneRow` whose label spells out the kind of hit, since only the icon shows it).
- Loading: `LoadingStateWidget`.

**Components used:** SectionHeader, PlaneRow, LoadingStateWidget, EmptyStateWidget.

**Data shown:** Search result name, identifier (for issues), type-specific icon.

**Interactions:**
- Type to search (300ms debounce, minimum 2 chars).
- Tap recent search -> re-runs that query.
- Clear recent searches.
- Tap result -> currently does nothing (`onTap: () {}`).

**Navigation:** Hidden 5th tab in HomeScreen (accessible via search bubble in navbar). Also pushed from ProjectScreen's search bubble.

**Current issues:**
- Tapping search results does nothing -- navigation not implemented.
- No ability to filter by entity type.
- Recent searches stored in FlutterSecureStorage (overkill, should be simple prefs).
- The search input is inside AppBar, which means it has the AppBar title styling applied -- could look inconsistent.
- No result count shown per section.
- Double-tap on search bubble re-creates the tab (rebuildKey++) -- may lose scroll position.

**Reference:** Similar to Linear's Cmd+K / search overlay, but full-screen.

---

### 6. Project Screen

**Path:** `lib/screens/project/project_screen.dart`
**Purpose:** Container screen for a single project, with bottom nav switching between Issues/Pages/Modules/Cycles/Views.

**Layout:**
- Material AppBar with project name as title (20/w600). Actions: + (create issue), settings gear.
- Body: `IndexedStack` with 5 children (IssuesTabScreen, PageListScreen, ModuleListScreen, CycleListScreen, ViewListScreen).
- Bottom: `AppNavBar` with 5 items + search bubble.
- `extendBody: true`.

**Components used:** AppNavBar.

**Data shown:** Project name in AppBar.

**Interactions:**
- Tap + -> push IssueCreateScreen.
- Tap gear -> push ProjectSettingsScreen.
- Bottom nav switching.
- Search bubble -> push SearchScreen.

**Navigation:** Pushed from ProjectsTab. Contains 5 sub-screens. Can push IssueCreateScreen, ProjectSettingsScreen, SearchScreen.

**Current issues:**
- No create button for pages, modules, cycles -- only issues.
- Sub-screens use `M3EAppBar` (fixed 56px bar); home tabs use `M3EFlexibleHeaderScaffold` (collapsing). Both are M3E and share the type scale, so the weight now matches -- only the collapse behaviour differs, which is intentional: a detail screen has no large title to collapse.
- View mode toggle (list/kanban/spreadsheet/calendar) is defined in IssuesTabScreen but currently not exposed in the UI (the `_ViewToggle` widget exists but isn't rendered in the build method).

**Reference:** Similar to Linear's project view with sidebar navigation, adapted to mobile tabs.

---

### 7. Project Settings Screen

**Path:** `lib/screens/project/project_settings_screen.dart`
**Purpose:** Edit project name, description, network (secret/public), manage states, labels, members, integrations.

**Layout:**
- AppBar with title "Project Settings".
- Body: ListView with padding 16, sections:
  - General: name TextField, description TextField (3 lines), identifier (read-only box), network ChoiceChips (Secret/Public), Save button.
  - Members: list of ListTile with avatar, name, email, role badge.
  - States: list of ListTile with state icon + color + name + group + delete button. Add button in section header.
  - Labels: Wrap of Chip widgets with color dot + name + delete X. Add button in section header.
  - Integrations: GitHub repos if any, or info text "Set up integrations in the web app".
  - Features: rows with check/cancel icon showing Cycles/Modules/Views/Pages (all currently hardcoded as enabled).
- Loading: `LoadingStateWidget`.

**Components used:** LoadingStateWidget.

**Data shown:** Project name, description, identifier, network, members (with roles), states (with groups), labels (with colors), GitHub repos, features.

**Interactions:**
- Edit name/description/network -> Save Changes button.
- Add state -> dialog with name + group dropdown.
- Delete state -> confirmation dialog.
- Add label -> dialog with name + color palette (8 colors).
- Delete label -> confirmation dialog.

**Navigation:** Pushed from ProjectScreen AppBar gear icon.

**Current issues:**
- No inline editing -- always uses full dialog for add.
- Features section is read-only/hardcoded -- cannot toggle features.
- Color picker for labels only offers 8 colors.
- No state reordering.
- Section headers use local `_sectionHeader` method (16/w600) instead of the shared `SectionHeader` widget.
- Members section doesn't have add/remove functionality.
- No back-navigation after deleting a state causes orphaned issues.

---

### 8. Issues Tab Screen

**Path:** `lib/screens/issues/issues_tab_screen.dart`
**Purpose:** Container for project issue views (list, kanban, spreadsheet, calendar). Handles data loading and passes data down.

**Layout:**
- Loading: `LoadingStateWidget`.
- Body: delegates to the selected `_ViewMode` child.
- View mode toggle widget (`_ViewToggle`) exists but is NOT rendered in the build method.

**Components used:** LoadingStateWidget.

**Current issues:**
- View mode toggle is defined but commented out / not wired up. Users cannot switch between list/kanban/spreadsheet/calendar.
- This is a significant missing feature -- the kanban, spreadsheet, and calendar views exist but are unreachable.

---

### 9. Issue List Screen

**Path:** `lib/screens/issues/issue_list_screen.dart`
**Purpose:** The default issue view inside a project -- grouped list with display options.

**Layout:**
- Top bar: issue count text (12, secondary) + display options tune icon. Padding `(20, 8)`.
- Body: grouped `ListView.builder` with `SectionHeader` (with count) + `IssueRow`.
- Empty state: "No issues" or "No issues match filters".
- Pull-to-refresh.

**Components used:** SectionHeader, IssueRow, DisplayOptions (shared), EmptyStateWidget.

**Data shown:** Issue name, priority, state, ID, labels (as dots), sub-issue count, assignee avatars, due date indicator. All configurable via display options row properties.

**Interactions:**
- Pull-to-refresh.
- Tap tune icon -> `showDisplayOptions` bottom sheet.
- Tap issue -> push IssueDetailScreen, refresh on return.
- "Save as View" functionality exists in code but has no UI trigger.

**Navigation:** Embedded in IssuesTabScreen. Pushes IssueDetailScreen.

**Current issues:**
- No issue creation from this screen (must use ProjectScreen AppBar).
- Save-as-view is implemented but not accessible from UI.
- Filter bar (`FilterBar` widget) is imported but not rendered.
- No context menu on long-press (quick status change, etc.).

**Reference:** Similar to Linear's issue list view.

---

### 10. Issue Detail Screen

**Path:** `lib/screens/issues/issue_detail_screen.dart`
**Purpose:** Full detail view of a single issue with properties, description, sub-issues, relations, attachments, links, activity/comments.

**Layout:**
- AppBar: back arrow + share icon + more_horiz icon.
- Body: `SingleChildScrollView` with horizontal padding 20:
  - Identifier text (13, secondary): "PROJ-123"
  - Title (22/w600, height 1.3)
  - Chips row (`Wrap`, spacing 6): status PropertyChip, priority PropertyChip, label pills (colored dots + name), "+Label" chip, assignee chip, start date chip, due date chip.
  - Overdue text (12, red, w500) if applicable.
  - Module & Cycle row (if present): icon + name, secondary text.
  - Assignees section: label "Assignees" (12/w500) + wrapped avatar chips.
  - Description: rendered via `MarkdownBody` (flutter_markdown). Styles: p=14/1.6, h1=20/w600, h2=18/w600, h3=16/w500, code=13/primary, blockquote with 3px left border.
  - Sub-issues section: header with count + add button, list of rows this screen builds inline (**not** `IssueRow` — see Design Inconsistencies).
  - Relations section (if any).
  - Attachments section.
  - Links section.
  - Activity section: header "Activity" with count, interleaved comments and activities.
- Bottom: comment input bar (fixed, not scrollable with content).
  - TextField with hint "Add a comment...", send button.

**Components used:** PropertyChip, MarkdownBody, LoadingStateWidget, ErrorStateWidget.

**Data shown:** Everything about an issue: name, ID, state, priority, labels, assignees, start/target dates, description, sub-issues, relations, attachments, links, activity feed, comments.

**Interactions:**
- Tap status chip -> bottom sheet state picker.
- Tap priority chip -> bottom sheet priority picker.
- Tap label chip -> bottom sheet multi-select label picker.
- Tap assignee chip -> bottom sheet multi-select assignee picker.
- Tap date chips -> native date picker.
- Tap sub-issue -> push to another IssueDetailScreen.
- Add sub-issue -> push IssueCreateScreen with parentIssueId.
- Add comment -> POST and reload.
- Share -> `share_plus`.
- More menu -> Edit, Delete (with confirmation).
- Pull-to-refresh.
- Long-press comment to copy (not implemented).

**Navigation:** Pushed from InboxTab, MyIssuesTab, IssueListScreen, KanbanBoard, SpreadsheetView, CalendarView, CycleDetailScreen, ModuleDetailScreen, ViewDetailScreen, NotificationScreen. Can push IssueCreateScreen (sub-issue).

**Current issues:**
- Comment input is basic plain text -- no markdown support, no @mentions.
- Description is read-only (no edit button).
- Attachments and links sections exist but upload/add functionality is limited.
- Activity feed is text-only, no inline editing of properties.
- The title is not editable inline.
- No "copy link" button for the issue.
- Chips row can overflow on small screens without proper wrapping (Wrap handles it but can look crowded).
- Relations section uses raw Map data -- no typed models.

**Reference:** Similar to Linear's issue detail pane, adapted to full-screen mobile.

---

### 11. Issue Create Screen

**Path:** `lib/screens/issues/issue_create_screen.dart`
**Purpose:** Create a new issue or sub-issue with title, description, status, and priority.

**Layout:**
- AppBar: title "New Issue" or "New Sub-issue", Create button (TextButton) on right.
- Body: padding 16, Column:
  - Title TextField (autofocus, OutlineInputBorder, "Title" label).
  - Description TextField (4 lines, OutlineInputBorder, "Description" label).
  - Row of two dropdowns: Status (from project states), Priority (urgent/high/medium/low/none).
- Saving state: CircularProgressIndicator in place of Create button.

**Components used:** None (all inline).

**Data shown:** Available states, priority options.

**Interactions:**
- Type title + description.
- Select status from dropdown.
- Select priority from dropdown.
- Tap Create -> saves and pops.

**Navigation:** Pushed from ProjectScreen AppBar or IssueDetailScreen (add sub-issue).

**Current issues:**
- Very minimal form -- missing fields that Plane supports: assignees, labels, start/due dates, estimate.
- Description is plain text, converted to `<p>` tag -- no markdown.
- Uses Material `DropdownButtonFormField` which looks dated.
- No project selector (always uses current project).
- No "Create and add another" option.
- Form has no validation feedback beyond empty check.

**Reference:** Should be similar to Linear's Cmd+I new issue dialog.

---

### 12. Kanban Board Screen

**Path:** `lib/screens/issues/kanban_board_screen.dart`
**Purpose:** Horizontal scrolling Kanban board with columns per state.

**Layout:**
- Horizontal `ListView.builder`, padding `(8, 0)`.
- Each column: 280px wide, margin `(right: 8, top: 8, bottom: 8)`.
  - Column header: state icon (14) + state name (13/w500) + count (11, 60% opacity). Padding `(8, 8)`.
  - Cards: vertical ListView of `_DraggableKanbanCard` widgets.
- Card content: Container with 12px padding, 8px border-radius, 0.5px outline border.
  - Issue ID text (11, secondary).
  - Issue title (13/w400, maxLines 3, height 1.4).
  - Priority icon row.
- Drag feedback: elevation 8, 1.5px primary border, shadow `alpha 0.15, blur 12, offset (0,4)`.
- Drop target: 2px primary border at 50% opacity, 5% primary background.

**Components used:** None (custom card widgets).

**Data shown:** Issue ID, title (up to 3 lines), priority icon.

**Interactions:**
- Long-press card to start drag.
- Drag between columns to change state (calls `IssueService.updateIssue`).
- Tap card -> push to IssueDetailScreen, refresh on return.
- Drop target highlights with animated border.
- Dragging card fades to 30% opacity.

**Navigation:** Embedded in IssuesTabScreen (but currently unreachable). Pushes IssueDetailScreen.

**Current issues:**
- Currently unreachable -- view mode toggle not wired up.
- Cards show very minimal info (no assignee, no labels, no due date).
- No column collapse/expand.
- No "add issue" button per column.
- No horizontal scroll position indicator.
- Card design is functional but sparse compared to Linear's Kanban.
- Drag works but is long-press initiated (not very discoverable on mobile).

**Reference:** Similar to Linear's Board view.

---

### 13. Calendar View

**Path:** `lib/screens/issues/calendar_view.dart`
**Purpose:** Month calendar grid showing issues by due date.

**Layout:**
- Month navigation: `< Month Year >` row with chevron buttons. Title: 16/w600.
- Day-of-week headers: Mon-Sun, 11/w500, secondary color.
- Calendar grid: 7 columns, variable rows. Each cell 44px height, border-radius 6.
  - Day number: 12, normal weight. Today: white text on primary circle (24px).
  - Issue dot: 6px primary circle below the day number (if issues exist on that date).
  - Selected day: 15% primary background.
- Below grid: divider, then issue list.
  - If a day is selected: shows that day's issues via `IssueRow` widgets.
  - If no day selected: shows "No date" issues list.
  - Header text: "YYYY-MM-DD (N issues)" or "No date (N issues)", 13/w500, secondary.

**Components used:** IssueRow, with every row property enabled.

**Data shown:** Calendar grid, issue dots on dates, issue list for selected day or unscheduled issues.

**Interactions:**
- Tap left/right chevron -> navigate months.
- Tap day -> show that day's issues below.
- Tap issue -> push IssueDetailScreen.
- Pull-to-refresh: not implemented on this view.

**Navigation:** Embedded in IssuesTabScreen (currently unreachable).

**Current issues:**
- Currently unreachable -- view mode toggle not wired up.
- No drag-to-reschedule.
- No week view option.
- No swipe between months.
- Issue dots don't indicate count (just presence).
- Selected day state resets when navigating months.
- Date format in header is ISO (YYYY-MM-DD) -- not user-friendly.

**Reference:** Similar to Linear's Calendar view (simplified).

---

### 14. Spreadsheet View

**Path:** `lib/screens/issues/spreadsheet_view.dart`
**Purpose:** Table/spreadsheet view of issues with editable cells.

**Layout:**
- Header row: fixed horizontal scroll with column headers (ID: 80px, Title: 200px, State: 120px, Priority: 100px, Assignee: 120px, Due Date: 110px). Header text: 12/w600, secondary color. Bottom border 0.5px.
- Data rows: `ListView.builder`, each row has `SingleChildScrollView` horizontal with matching column widths. Each cell has 8px horizontal + 10px vertical padding.
  - ID: 12, secondary.
  - Title: 13, tappable -> IssueDetailScreen.
  - State: icon + name, 12. Tappable -> state picker bottom sheet.
  - Priority: icon + capitalized name, 12. Tappable -> priority picker bottom sheet.
  - Assignee: names joined by comma or "Unassigned", 12.
  - Due Date: date string or "-", 12. Red if overdue.

**Components used:** None (custom cells).

**Data shown:** Issue ID, title, state, priority, assignee names, due date.

**Interactions:**
- Tap title -> push IssueDetailScreen.
- Tap state cell -> bottom sheet state picker -> update immediately.
- Tap priority cell -> bottom sheet priority picker -> update immediately.
- No inline editing for other cells.

**Navigation:** Embedded in IssuesTabScreen (currently unreachable).

**Current issues:**
- Currently unreachable -- view mode toggle not wired up.
- Header and data rows scroll independently (not synced) -- each row has its own SingleChildScrollView.
- No column resizing or reordering.
- Assignee and due date are not editable.
- No row selection.
- No sorting by column header tap.
- Fixed column widths may not fit long names.

**Reference:** Similar to Linear's Spreadsheet/Table view.

---

### 15. Cycle List Screen

**Path:** `lib/screens/cycles/cycle_list_screen.dart`
**Purpose:** Lists all cycles in a project, grouped by status (Active, Upcoming, Completed, Draft).

**Layout:**
- Body: grouped `ListView.builder` with `SectionHeader` (status label + count + color) and `PlaneRow`.
- Row: loop icon in the status colour, cycle name, date range as the subtitle with "completed/total" at the end of it, and the 4px progress bar below.
- Empty: `EmptyStateWidget` with loop icon, "No cycles".
- Error: `ErrorStateWidget`.
- Pull-to-refresh.

**Components used:** SectionHeader, PlaneRow, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** Cycle name, completed/total issues, progress bar, date range, status group.

**Interactions:**
- Pull-to-refresh.
- Tap cycle -> push CycleDetailScreen, invalidate cache on return.
- Create cycle: FAB or dialog -- currently uses `_showCreateCycleDialog` but no FAB is rendered. The create dialog is in the code but has no trigger in the build method.

**Navigation:** Tab 3 in ProjectScreen. Pushes CycleDetailScreen.

**Current issues:**
- No UI trigger for cycle creation (dialog exists but no button).
- No cycle filtering by status.
- Progress bar colors match status but contrast can be low on light theme.
- Date range displayed as raw strings.

**Reference:** Similar to Linear's Cycles list.

---

### 16. Cycle Detail Screen

**Path:** `lib/screens/cycles/cycle_detail_screen.dart`
**Purpose:** Shows cycle info (status, description, dates, progress) and its issues.

**Layout:**
- AppBar: cycle name + more_horiz action.
- Body: ListView:
  - Info section (padding 20): status PropertyChip, description (15, secondary), date range row, progress bar (6px height) + "N/N" text.
  - Divider.
  - Issues header: "Issues" (13/w500) + count (12) + add icon (20).
  - Issue list: `Dismissible` wrappers around `IssueRow` (swipe to remove from cycle).
  - Bottom padding: 80.
- Loading/Error states.

**Components used:** PropertyChip, IssueRow, LoadingStateWidget, ErrorStateWidget.

**Data shown:** Cycle status, description, date range, progress, issues list.

**Interactions:**
- Pull-to-refresh.
- Tap + icon -> "Add issues" DraggableScrollableSheet with checkbox list of project issues not already in cycle.
- Swipe issue left -> remove from cycle.
- Tap issue -> push IssueDetailScreen.
- More menu -> Edit cycle (dialog), Delete cycle (confirmation).

**Navigation:** Pushed from CycleListScreen. Pushes IssueDetailScreen.

**Current issues:**
- Add issues sheet uses CheckboxListTile (Material default) -- not styled consistently.
- No search within add-issues sheet.
- Progress bar and issue list don't update until refresh after adding issues.

---

### 17. Module List Screen

**Path:** `lib/screens/modules/module_list_screen.dart`
**Purpose:** Lists all modules in a project as cards with status chips and progress bars.

**Layout:**
- Body: `ListView.builder` of `PlaneRow`.
- Row: module icon in the status colour, module name, the status `PropertyChip` on the right, date range as the subtitle with "completed/total" at the end of it, and the 4px progress bar below — the same shape as a cycle row.
- Empty: `EmptyStateWidget` with view_module icon, "No modules".
- Pull-to-refresh.

**Components used:** PlaneRow, PropertyChip, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** Module name, status (chip), progress bar, date range, issue count.

**Interactions:**
- Pull-to-refresh.
- Tap module -> push ModuleDetailScreen, invalidate cache on return.
- Create module: `_showCreateModuleDialog` exists but no button is rendered.

**Navigation:** Tab 2 in ProjectScreen. Pushes ModuleDetailScreen.

**Current issues:**
- No UI trigger for module creation.
- Nearly identical layout to CycleListScreen -- could share a common card widget.

**Reference:** Similar to Linear's Roadmap/Modules.

---

### 18. Module Detail Screen

**Path:** `lib/screens/modules/module_detail_screen.dart`
**Purpose:** Shows module info and its issues. Nearly identical layout to CycleDetailScreen.

**Layout:** Same as CycleDetailScreen but with module-specific status chip (circle icon, not loop).

**Current issues:** Same as CycleDetailScreen. Additionally, module status uses a filled circle icon which is small and hard to read.

---

### 19. Page List Screen

**Path:** `lib/screens/pages/page_list_screen.dart`
**Purpose:** Lists all pages in a project.

**Layout:**
- Body: `ListView.builder` of `PlaneRow`. Icon: `description_outlined` (or `lock` if locked). Title: page name or "Untitled". Subtitle: last updated date (dd.MM.yyyy format).
- Empty: "No pages", subtitle "Create a page to get started".
- Pull-to-refresh.

**Components used:** PlaneRow, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** Page name, lock status, last updated date.

**Interactions:**
- Pull-to-refresh.
- Tap page -> push PageDetailScreen, invalidate cache on return.
- Create page: `_createPage` method pushes PageEditScreen, but no FAB or button is rendered.

**Navigation:** Tab 1 in ProjectScreen. Pushes PageDetailScreen.

**Current issues:**
- No create button visible.
- Date format is European (dd.MM.yyyy) -- inconsistent with other date displays.
- No page preview snippet shown.

---

### 20. Page Detail Screen

**Path:** `lib/screens/pages/page_detail_screen.dart`
**Purpose:** Read-only view of a page's content rendered as Markdown.

**Layout:**
- AppBar: page name + edit icon (if not locked).
- Body: `MarkdownBody` in a `SingleChildScrollView` with padding 20. Typography: p=15/1.7, h1=22/w600, h2=19/w600, h3=17/w500, code=13/primary with 8% bg, code blocks with rounded container, blockquotes with 3px left border.
- Empty: centered "No content" text.
- Loading: `LoadingStateWidget`.

**Components used:** MarkdownBody (flutter_markdown), LoadingStateWidget.

**Data shown:** Page name, rendered HTML content (converted to Markdown first).

**Interactions:**
- Tap edit icon -> push PageEditScreen, reload on return.

**Navigation:** Pushed from PageListScreen.

**Current issues:**
- Content is HTML from API, converted to Markdown for display -- lossy conversion.
- No inline editing.
- No table of contents.
- No page deletion from this screen.

---

### 21. Page Edit Screen

**Path:** `lib/screens/pages/page_detail_screen.dart` (same file, `PageEditScreen` class)
**Purpose:** Create or edit a page with markdown editor and live preview.

**Layout:**
- AppBar: "New Page" or "Edit Page" + preview toggle icon + Save button.
- Body:
  - Page name TextField (20/w600, no border, hint "Page name").
  - Divider.
  - Toolbar (44px height, horizontal ListView): Bold, Italic, Heading, List, Code, Link, Quote buttons. Each: IconButton 20px, padding `(8, 0)`, min width 36.
  - Content area: TextField (15/1.6, no border, "Write in markdown...", expands to fill).
  - Preview mode: MarkdownBody in ScrollView.

**Data shown:** Page name, content as markdown.

**Interactions:**
- Toolbar buttons insert markdown formatting at cursor.
- Toggle between edit and preview.
- Save -> converts markdown to HTML -> creates or updates page.

**Current issues:**
- Very basic markdown editor -- no syntax highlighting.
- No undo/redo.
- No image insertion.
- Toolbar is minimal (7 buttons).
- Preview doesn't match the detail screen's styled MarkdownBody (uses defaults).

---

### 22. View List Screen

**Path:** `lib/screens/views/view_list_screen.dart`
**Purpose:** Lists saved views (filter presets) for a project.

**Layout:**
- Body: `ListView.builder` of `PlaneRow`.
  - Leading: `view_list_outlined` icon.
  - Title: view name.
  - Subtitle: description or time ago.
  - Trailing: delete icon button, named per view.
- Empty: "No saved views", "Create a view to save filter presets".
- Pull-to-refresh.

**Components used:** PlaneRow, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** View name, description or last updated time.

**Interactions:**
- Pull-to-refresh.
- Tap view -> push ViewDetailScreen.
- Tap delete -> confirmation dialog.
- Create view: `_createView` dialog (name input). No button rendered for it.

**Navigation:** Tab 4 in ProjectScreen. Pushes ViewDetailScreen.

**Current issues:**
- No create button visible in UI.
- Delete is always visible (no confirmation on accident).

---

### 23. View Detail Screen

**Path:** `lib/screens/views/view_detail_screen.dart`
**Purpose:** Shows issues matching a saved view's filter criteria.

**Layout:**
- AppBar: view name.
- Body: `ListView.separated` of `IssueRow` widgets (all properties shown).
- Separators: `Divider(indent: 16, endIndent: 16, height: 0.5)`.
- Empty: "No issues match this view".
- Loading/Error states.

**Components used:** IssueRow, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** Filtered issues with full properties (priority, state, ID, labels, assignees, due date, sub-issues).

**Interactions:**
- Pull-to-refresh.
- Tap issue -> push IssueDetailScreen.

**Current issues:**
- No way to edit view filters from mobile.
- Re-fetches all issues and applies filters client-side (inefficient for large projects).
- No display options or grouping.

---

### 24. Notification Screen

**Path:** `lib/screens/notifications/notification_screen.dart`
**Purpose:** Shows all notifications, grouped by read/unread status.

**Layout:**
- AppBar: "Notifications" + "Mark all read" text button (when unread exist) + settings gear icon.
- Body: ListView grouped into "UNREAD" and "READ" sections with `SectionHeader`.
- Notification tile: `Dismissible` (swipe right-to-left to archive). InkWell container:
  - Left: unread dot (8px primary circle) or 16px spacer.
  - Right column: title (15, normal or w500 if unread, maxLines 2), entity name (12, secondary), time ago (11, secondary).
  - Unread background: 4% primary tint.
  - Bottom border: 0.3px outline.
- Empty: "No notifications", "You're all caught up".
- Settings: bottom sheet with SwitchListTile toggles for Property changes, State changes, Comments, Mentions.

**Components used:** SectionHeader, LoadingStateWidget, EmptyStateWidget, ErrorStateWidget.

**Data shown:** Notification title, entity name, time ago, read/unread status.

**Interactions:**
- Pull-to-refresh.
- Swipe to archive.
- Tap -> mark as read + push IssueDetailScreen.
- Mark all read button.
- Settings icon -> notification preferences bottom sheet.

**Navigation:** Pushed from MenuTab.

**Current issues:**
- Separate from InboxTab -- confusing to have two notification-like screens.
- No snooze functionality.
- No filter tabs (all/mentions/assigned).
- Archive is permanent (no unarchive).
- Tile padding is `(20, 9)` -- tighter than a standard `PlaneRow`.

**Reference:** Similar to Linear's notification panel.

---

### 25. Analytics Screen

**Path:** `lib/screens/analytics/analytics_screen.dart`
**Purpose:** Basic analytics dashboard showing issue counts and distribution charts.

**Layout:**
- AppBar: "Analytics".
- Body: ListView with padding 20:
  - 2x2 grid of `_StatCard`: Total Issues, Completed, Pending, Overdue. Card: 1.6 aspect ratio, 16px padding, 12px border-radius, 0.5px outline border. Value: `fontTitle` (24/w700, colored). Label: `fontSection` (13, secondary).
  - "Issues by Priority" bar chart.
  - "Issues by State" bar chart.
  - "Recent Activity" list (10 items).
- Bar chart: horizontal bars. Label (80px, 13, secondary) + animated bar + count text (13/w500).
- Activity item: bordered container (8px radius), padding `(20, 9)`. Priority icon + issue name (13) + short date.

**Components used:** LoadingStateWidget, ErrorStateWidget.

**Data shown:** Issue totals, by-priority distribution, by-state distribution, 10 most recently updated issues.

**Interactions:**
- Pull-to-refresh.
- No tap actions on charts or activity items.

**Navigation:** Pushed from MenuTab.

**Current issues:**
- Fetches from up to 5 projects -- slow and not comprehensive.
- No date range selector.
- Activity items are not tappable.
- Bar charts are horizontal only (no pie charts, no line charts).
- Simple grid layout for stat cards -- could be more visually appealing.
- Date format on activity items is "d/M" -- inconsistent.

---

### 26. Profile Screen

**Path:** `lib/screens/profile/profile_screen.dart`
**Purpose:** Edit user display name and switch theme.

**Layout:**
- AppBar: "Profile".
- Body: ListView with padding 16:
  - Avatar: CircleAvatar (radius 40), primary-tinted background or network image. Letter fallback (28, primary, w600).
  - Email (read-only): label (12, secondary) + container with border.
  - Display name: label + TextField + Save button (FilledButton, full width).
  - Appearance section: header "Appearance" (16/w600). Three `_ThemeOption` tiles: Dark mode, Light mode, System. Each: ListTile with icon (20), label (14), check icon if selected.

**Components used:** LoadingStateWidget.

**Data shown:** Avatar, email, display name, current theme.

**Interactions:**
- Edit display name + Save.
- Tap theme option -> switch theme immediately (persisted via Riverpod).

**Navigation:** Pushed from MenuTab.

**Current issues:**
- No avatar upload.
- Email is read-only but doesn't clearly explain why.
- Theme section has no preview.
- Very minimal profile -- no timezone, no notification preferences.
- Save button covers full width which looks heavy for a single field.

---

### 27. Setup Screen

**Path:** `lib/screens/setup/setup_screen.dart`
**Purpose:** Login/connection screen. Supports Google Sign-In, email/password, and API key.

**Layout:**
- Body: SafeArea + SingleChildScrollView, padding 24:
  - App icon: `Icons.flight_takeoff` (64px, onSurface).
  - "Plane" title (28/bold).
  - "Connect to your self-hosted instance" subtitle (14, secondary).
  - Instance URL TextField (with link icon prefix, "https://plane.example.com" hint).
  - Mode-dependent form:
    - **Google:** OutlinedButton.icon "Sign in with Google" + divider "or" + links to Email/Password or API Key.
    - **Email/Password:** email TextField + password TextField + ElevatedButton "Sign In" + links to Google or API Key.
    - **API Key:** API key TextField (obscured) + workspace slug TextField + ElevatedButton "Connect" + links to Google or Email/Password.
  - Error text (red, 13) at bottom.
- After multi-workspace auth: workspace picker bottom sheet.

**Interactions:**
- Enter URL, then authenticate via one of three methods.
- Google: uses `GoogleSignIn` -> sends idToken to `/auth/mobile/google-auth/`.
- Email/Password: POST to `/auth/mobile/password-auth/`.
- API Key: tests connection, saves credentials.
- Multi-workspace: shows picker sheet.

**Navigation:** Shown as root when not authenticated. On success, calls `onConfigured` callback.

**Current issues:**
- App icon is `Icons.flight_takeoff` -- generic, should use Plane logo.
- Google Sign-In error handling is verbose in the UI.
- Mode switching uses text buttons that are easy to miss.
- No "remember me" or biometric auth.
- URL field doesn't validate format until submit.
- API key field should not be obscured if user needs to verify what they pasted.

---

### 28. Command Palette

**Path:** `lib/screens/command_palette/command_palette.dart`
**Purpose:** Quick action launcher and search overlay, triggered by long-pressing the search bubble.

**Layout:**
- Modal bottom sheet with `DraggableScrollableSheet` (initial 70%, max 90%, min 40%).
- Drag handle (36x4, rounded).
- Search TextField with border (radius 10), autofocus.
- When no query: "Quick actions" label (12/w500, secondary) + action items.
- Quick actions: "Create issue" (add icon), "Switch project" (swap icon).
- When searching: "Actions" section + "Results" section.
- Items: `ListTile` with icon (20), label (14), optional subtitle (12, secondary).

**Components used:** None (all inline).

**Data shown:** Quick actions, search results (issues, projects, pages, cycles, modules).

**Interactions:**
- Type to search (300ms debounce, min 2 chars).
- Tap "Create issue" -> pops palette, pushes IssueCreateScreen (default project).
- Tap "Switch project" -> pops palette, shows project picker sheet, pushes ProjectScreen.
- Tap search result -> pops palette (no navigation to result).

**Navigation:** Opened as modal from HomeScreen (long-press search). Can push IssueCreateScreen or ProjectScreen.

**Current issues:**
- Search results don't navigate anywhere (just close the palette).
- "Create issue" uses first project -- should let user pick or use last-used.
- No keyboard shortcuts (this is mobile, but the pattern is borrowed from desktop).
- No "recently viewed" items.
- Quick actions list is very short (only 2 items).

**Reference:** Similar to Linear's Cmd+K command palette.

---

## Issues & Inconsistencies Summary

### Critical (Functionality Missing)
1. **View mode toggle unreachable:** Kanban, Spreadsheet, and Calendar views exist but cannot be accessed -- the toggle UI was removed/commented out from IssuesTabScreen.
2. **Search results not navigable:** Tapping search results does nothing in both SearchScreen and CommandPalette.
3. **No create buttons for Pages, Cycles, Modules:** Create dialogs exist in code but no buttons are rendered.
4. **Edit icon on My Issues does nothing:** `onPressed: () {}`.

### Design Inconsistencies
5. **Two notification-like screens:** InboxTab (home) and NotificationScreen (menu) serve overlapping purposes.
6. **AppBar vs flexible header:** ~~resolved~~ -- home tabs use `M3EFlexibleHeaderScaffold`, sub-screens use `M3EAppBar`. Both draw from the M3E type scale and share the hairline divider; no Material `AppBar` remains in the app.
7. **Three widgets for one row:** ~~mostly resolved~~ -- `IssueTile`, `ItemTile` and the `IssueRow` wrapper are gone, as are the inline rows the cycle, module and view lists each built for themselves. Every issue and entity list now renders `PlaneRow`, issues through `IssueRow`. Still outside it: ProjectsTab's project cards, MenuTab's menu items, NotificationScreen's rows and IssueDetailScreen's sub-issue rows, which each still draw their own.
8. **Display options duplication:** MyIssuesTab has its own display options implementation; IssueListScreen uses the shared `showDisplayOptions`. Should consolidate.
9. **Date formats vary:** Calendar uses ISO (YYYY-MM-DD), Pages use European (dd.MM.yyyy), Analytics uses "d/M", notifications use `timeAgo`. No consistent formatting.
10. **Hardcoded colors:** ~~resolved~~ -- ViewListScreen went through `PlaneRow`, which takes every colour from the scheme.

### Polish Needed
11. **Empty states are text-only:** No illustrations, just icon + text. Could be more engaging.
12. **Loading is a bare spinner:** No skeleton loaders despite a `skeleton_loader.dart` file existing.
13. **No swipe gestures on issue rows:** Linear has swipe-to-change-status. Only CycleDetail and ModuleDetail use Dismissible.
14. **No haptic feedback** on any interaction.
15. **No transitions/animations** between screens (uses default `MaterialPageRoute` push).
16. **Comment input is plain text** -- no markdown, no @mentions, no rich text.
17. **Issue creation form is minimal** -- missing assignees, labels, dates, estimate fields.
18. **No offline mode indicators** beyond the cache system.

### Navigation Gaps
19. **No way to jump to a project from My Issues** -- tapping an issue goes to detail, but there's no "Open in project" action.
20. **No deep linking** -- cannot open a specific issue from a URL or notification payload directly.
21. **No breadcrumb or context** showing which project/cycle/module you're viewing issues from.
