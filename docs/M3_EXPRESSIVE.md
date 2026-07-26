# Material 3 Expressive layer

## Two implementations, on purpose

The app uses Material 3 Expressive through **both** available routes.

### 1. The real artifact, via Compose platform views

`androidx.compose.material3:material3:1.5.0-alpha24` is declared in
`android/app/build.gradle` and its composables are rendered for real — not
reimplemented. Flutter cannot link a Compose artifact directly, so each one runs
inside a `ComposeView` exposed to Dart as an Android platform view:

- Kotlin host: `android/app/src/main/kotlin/.../M3ExpressiveViews.kt`
- Dart bridge: `lib/widgets/m3e/native.dart`
- Live call site: the List/Board/Table/Calendar switch in `issues_tab_screen.dart`

Currently bridged: `ButtonGroup` (with the library's own `animateWidth` press
expansion, every item weighted — see "Known gaps") and `LoadingIndicator`, both wrapped in `MaterialExpressiveTheme`
with `MotionScheme.expressive()` — that theme call is what puts the library into
the expressive token set rather than the standard one. The Compose `ColorScheme`
is built from roles passed over from the Dart theme so the two never diverge.

Verify it is genuinely in the build:

```
cd android && ./gradlew :app:dependencies --configuration debugRuntimeClasspath \
  | grep material3
# +--- androidx.compose.material3:material3:1.5.0-alpha24

unzip -p build/app/outputs/flutter-apk/app-debug.apk classes.dex \
  | strings | grep -c MaterialExpressiveTheme
```

**What this route costs**, which is why it is opt-in per call site rather than
the default:

- **Android only.** iOS and web get nothing from it.
- **A separate render surface** composited into the Flutter scene per view —
  materially more expensive than a Flutter widget, and not something to put in a
  list row.
- **A heavy toolchain bump.** Compose 1.12 (pulled in transitively by
  alpha24) forced AGP 8.9.3 → 9.1.0, Gradle 8.11.1 → 9.3.1, compileSdk 36 → 37,
  Kotlin 2.1.0 → 2.1.20, plus `MainActivity` moving to `FlutterFragmentActivity`
  because `ComposeView` needs a lifecycle owner.
- **It is an alpha.** Every composable used is behind
  `@ExperimentalMaterial3ExpressiveApi`.

### 2. Dart implementations of the same spec

`lib/widgets/m3e/` implements the same language natively in Dart, on the one M3E
primitive Flutter does have: physics-based animation
(`SpringDescription.withDampingRatio`, `SpringSimulation`).

This is not redundant work. It is what renders on iOS, in widget tests, and at
every call site where a platform view would be too expensive — which is most of
them: list rows, chips, app bars, press feedback. The native widgets in
`native.dart` fall back to these automatically, and that fallback is tested.

## What the language is, here

M3 Expressive's thesis is that state should be carried by *shape* and *physics*,
not only by colour. Three rules follow, and they are applied consistently:

1. **Motion is springs, not curves.** Anything that moves runs on a spatial
   spring and is allowed to overshoot. Anything that fades or tints runs on a
   critically damped effects spring and never overshoots.
2. **Shape is interactive.** Selection and press change corner radius. A
   selected chip pulls its corners in; a pressed surface squeezes.
3. **Emphasis is typographic.** One element per screen may take the emphasized
   weight; the rest stay quiet.

## Keeping it Linear

Expressive and Linear pull in opposite directions — M3E wants big radii, tonal
fills and visible chrome; Linear wants hairlines, near-black surfaces and
nothing decorative. Where they conflict, these choices were made:

| Decision | Chosen | Why |
|---|---|---|
| Type scale | Linear's compact sizes, M3E's roles + emphasis | M3's stock sizes run ~2 steps larger; inflating them would lose the product's density |
| Elevation | Flat everywhere, hairline outlines | M3E's tonal elevation reads as "Google app"; Linear separates with 0.5px borders |
| Corner radius | M3E scale adopted (8→16→28) | This is the most visible expressive cue and costs nothing in density |
| Bottom bar | Linear's frosted glass, M3E's travelling indicator | The blur is the app's signature; the indicator is pure M3E and sits inside it |
| Colour | Existing palette untouched | Expressiveness is delivered through shape and motion instead |

## Files

### Tokens — `lib/config/m3e/`

| File | Contents |
|---|---|
| `motion.dart` | Spring specs (`fastSpatial`, `defaultSpatial`, `slowSpatial`, and the effects trio), `M3ESpringBuilder`, `M3EPressable` |
| `shapes.dart` | Corner scale, `M3ECookieShape` (morphable lobed shapes) |
| `typography.dart` | Type scale with `emphasized()` and `overline()` |

Spring values match the Compose `MotionScheme.expressive()` tokens:

| Token | Stiffness | Damping ratio | Used for |
|---|---|---|---|
| `fastSpatial` | 800 | 0.6 | Press states, chip selection, button-group squeeze |
| `defaultSpatial` | 380 | 0.8 | Nav indicator, FAB menu, sheets |
| `slowSpatial` | 200 | 0.8 | Full-screen transitions |
| `fastEffects` | 3800 | 1.0 | Immediate colour changes |
| `defaultEffects` | 1600 | 1.0 | Standard fades |
| `slowEffects` | 800 | 1.0 | Slow tints |

`M3ESpringBuilder` is the workhorse. Unlike Flutter's implicit animation
widgets, retargeting mid-flight inherits the current velocity, so rapid taps
blend instead of restarting.

### Components — `lib/widgets/m3e/`

| Component | Behaviour |
|---|---|
| `M3EButtonGroup` | Connected selection row. Pressing a button widens it while its immediate neighbours compress — one spring per item, resolved in a single layout pass |
| `M3ESplitButton` | Primary action + trailing menu toggle whose chevron flips and inner corner rounds while open |
| `M3EFabMenu` | FAB expanding to labelled actions with a bottom-up stagger over a blurred scrim; rendered in an `OverlayEntry` so it is never clipped |
| `M3EFlexibleHeaderScaffold` | Large title collapsing continuously into the toolbar as the body scrolls; drops into the existing `Column(header, Expanded(list))` shape |
| `M3ELoadingIndicator` | Filled shape rotating while morphing through seven lobed forms |
| `M3EChip` | Filter chip where selection changes corner radius as well as tint |
| `M3EAppBar` / `M3EAppBarAction` | Small top bar for the sub-screens, which are `Scaffold(appBar:, body:)`. Implements `PreferredSizeWidget`, so migrating a screen is a one-line swap |
| `M3EFloatingToolbar` / `M3EGlassContainer` | Detached frosted pill; the toolbar springs out of the way on scroll-down |

### Compose bridge — `lib/widgets/m3e/native.dart`

| Widget | Backed by |
|---|---|
| `M3ENativeButtonGroup` | `androidx.compose.material3.ButtonGroup` (falls back to `M3EButtonGroup`) |
| `M3ENativeLoadingIndicator` | `androidx.compose.material3.LoadingIndicator` (falls back to `M3ELoadingIndicator`) |

`M3ENative.isAvailable` gates both — false on web, on iOS, and under
`flutter test`.

## Where it is wired in

Coverage is complete — no Material `AppBar` and no `CircularProgressIndicator`
remain anywhere in `lib/`.

- `lib/config/theme.dart` — one `_build()` for both themes; M3E shapes on every
  component theme, M3E type scale, zero elevation throughout
- `lib/widgets/app_navbar.dart` — M3E nav indicator inside the glass bar
- `lib/screens/home/{inbox,my_issues,projects}_tab.dart` — flexible header;
  My issues also uses `M3EButtonGroup` for scope and `M3EFabMenu` for create
- `lib/screens/issues/issues_tab_screen.dart` — the List/Board/Table/Calendar
  switch is `M3ENativeButtonGroup`, i.e. the genuine Compose `ButtonGroup` from
  material3 1.5.0-alpha24 on Android
- All 15 sub-screens (issue detail/create, cycles, modules, pages, views,
  notifications, analytics, profile, project + settings, search, login) —
  `M3EAppBar`
- `lib/widgets/filter_bar.dart` — all filter/action chips are `M3EChip`
- `lib/widgets/{issue_tile,item_tile,property_chip,section_header}.dart` —
  press physics and the expressive corner scale
- Cycle, module and notification list rows — `M3EPressable`

### Two title changes worth flagging

- **Issue detail** used to title its bar "Plane". It now shows the issue's own
  identifier (`PLM-123`), which is the thing a user actually needs there.
- **Projects** lost its "create project" button — it only ever showed a snackbar
  saying projects must be made on the web. It is now a `help_outline` action,
  which does not promise an action it cannot perform.

## Known gaps

- **Not every hard-coded radius is tokenized.** 29 card- and button-shaped sites
  were converted to `M3EShape`; a handful of 2–4px sites (progress-bar caps,
  skeleton shimmer blocks) were deliberately left alone — they are not shape
  decisions.
- **`M3EFloatingToolbar` and `M3ESplitButton` have no call site yet.** Both are
  built and tested, but no current screen has the contextual-action row or the
  primary-plus-variants action that would justify them. They are there for the
  next screen that needs one rather than being retrofitted somewhere awkward.
- **Compose's `ButtonGroup` cannot be allowed to overflow.** Its overflow path
  in 1.5.0-alpha24 measures the width left for the items as
  `remaining + overflowIndicatorWidth`; with an indicator that draws nothing
  that value goes negative, `Constraints.copy` throws, and because this is an
  uncaught exception on Android's main thread inside `View.measure`, it takes
  the whole process down — no Dart error, no crash screen, the app is just
  gone. Every item therefore passes an explicit `weight`, which keeps the group
  inside whatever width it is given and never reaches that branch. Do not
  restore the default `weight` (NaN, "size to content") without giving the
  overflow indicator real width.

## Tests

`test/widgets/m3e_components_test.dart` (21 tests) covers the behaviour that is
easy to regress silently — the button-group squeeze (asserts the pressed item's
width grows while its neighbour's shrinks), the FAB menu expand/select/dismiss
cycle, the header collapse cross-fade, that `M3ESpringBuilder` converges, and
that the Compose-backed widgets fall back correctly when no platform view is
available. One regression test pins `M3EAppBar.preferredSize` including its
divider — leaving the divider out made Scaffold under-allocate and the bar
overflowed.

The Compose side is not covered by Dart tests; it needs an instrumented test on
a device, which this repo has no harness for. It was instead verified by hand on
a Pixel 8 (Android 17 / API 37) — see below.

## Verified on device

Pixel 8, Android 17, debug build, driven with `tool/adb_drive.py`:

- The Compose `ButtonGroup` renders and round-trips: tapping "Board" over adb
  updates Compose's own state, crosses the MethodChannel, and switches the
  Flutter view. No crash in logcat on any screen.
- `check` passes on every screen walked: the four home tabs, all four project
  view modes, issue detail, Pages / Modules / Views / Cycles, the More menu,
  Notifications, Analytics, Profile.

A Pixel 8 turned out to be a misleading thing to verify a `ButtonGroup` on: at
411dp it is a few dp wider than the point where the four view labels stop
fitting, so it was the one common device that did not crash. The group is now
re-checked on a Galaxy S20 FE across window widths 308–432dp (via
`adb shell wm density`) and font scales 1.0–1.8. Before the weight fix
everything below 411dp died, as did 411dp itself at font scale 1.3; after it,
all of them pass.

Three real defects were found this way and fixed:

1. **The Projects search field was anonymous.** It relied on `hintText`, which
   Android drops from the accessible name as soon as the field has content — so
   the control lost its name exactly when it held a query. It now carries an
   explicit `Semantics(label:, textField: true)`.
2. **The Dart and Compose ButtonGroups rendered different colours for the same
   selected state.** Compose's `ButtonGroup` is built on `ToggleButton`, whose
   checked state fills with `primary`; the Dart port used `primaryContainer`.
   The Dart side now follows the library.
3. **Opening any project killed the app on a normal-width phone.** The Compose
   `ButtonGroup` was left at its default sizing, which overflows below ~411dp
   and throws out of the measure pass. See "Known gaps"; items now carry
   weights, as `M3EButtonGroup` already did on the Dart side.

## Driving the app from adb

The whole app is driveable from a shell with no instrumentation build and no
Dart-side test hooks. Flutter enables its semantics tree as soon as an
accessibility client attaches, and `adb shell uiautomator dump` is one — so
every labelled widget shows up as a node with `content-desc` and a tap target.

```
tool/adb_drive.py tree              # labelled nodes + tap coordinates
tool/adb_drive.py check             # tappable nodes with NO label — the gaps
tool/adb_drive.py tap "New issue"   # tap by label
tool/adb_drive.py flow smoke        # walk the main destinations, shot + check each
```

This only holds if controls carry labels. An icon-only button renders as an
anonymous node that automation cannot find, which is why `M3EPressable` takes
`semanticLabel:` and `selected:`, and why `M3EAppBarAction` wraps itself in a
`Tooltip`. `check` is the regression guard: run it on a screen and it lists
every tappable node that is still anonymous.

Two things worth knowing:

- **The Compose platform views label themselves.** The native `ButtonGroup`
  reports `List / Board / Table / Calendar` through Compose's own semantics, so
  the same `tap` command works across the Flutter/Compose boundary.
- **A locked or dark screen screenshots as solid black.** The tool wakes the
  display and refuses outright on a keyguard rather than trying to get past it.
