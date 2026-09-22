# Fork Changes

`thecodebrothers/flutter_map`, a fork of [`fleaflet/flutter_map`](https://github.com/fleaflet/flutter_map)
by way of [`JSosna/flutter_map`](https://github.com/JSosna/flutter_map).

| | |
|---|---|
| Upstream baseline | v8.4.0-dev.1 (`34457c1`) |
| Fork commits | 2, applied on top of upstream |
| Files modified | 4 + 1 new test file |

Both features are opt-in and default to upstream behaviour, so the fork is a drop-in
replacement for the matching upstream version.

Pin by git ref or SHA — `pubspec.yaml` carries upstream's version number unchanged.

---

## 1. `TileLayer.pruneOnZoomChange`

`lib/src/layer/tile_layer/tile_layer.dart`

By default tiles from the previous zoom level are kept until the new level has loaded, and
tiles within `panBuffer + keepBuffer` are retained, so the old level stays visible underneath
during the transition.

With `pruneOnZoomChange: true`, tiles are pruned with a buffer of 0 as soon as the native zoom
level changes — no stale tiles showing through, at the cost of a brief empty gap while the new
level loads. `_lastPrunedZoom` keeps the eager prune to once per zoom change.

Default `false`. No upstream equivalent.

## 2. Integer zoom

Restricts zooming to whole levels, for tile sets that only render correctly at native zoom.

**Scroll wheel and trackpad** — `lib/src/map/options/scroll_zoom.dart`,
`lib/src/gestures/scroll_zoom.dart`

A third `ScrollZoomOptions.integer()` variant next to upstream's `.smooth()` and `.snap()`,
configurable with `animationDuration` (200 ms) and `curve` (`Curves.fastOutSlowIn`). Each tick
eases to the next or previous whole level.

Ticks arriving mid-animation step out from the target the animation is already heading for,
rather than from the fractional zoom it has currently reached, so rapid scrolling accumulates
instead of fighting itself. The centre is anchored to that same target, so the point under the
cursor stays put as ticks chain.

> Upstream's smooth path recomputes the focal centre from the live camera every frame, so it
> still drifts under a chained scroll. That fix lives only in the integer path here.

`ScrollZoomHandler` now dispatches frames through a stored callback instead of binding the
ticker to one behaviour's frame logic on first use, so the two animated modes cannot inherit
each other's callback.

**Pinch** — `lib/src/map/options/interaction.dart`,
`lib/src/gestures/map_interactive_viewer.dart`

`InteractionOptions.enableIntegerZoom` makes a pinch gesture zoom by exactly one whole level —
in on a spreading pinch, out on a closing one — ignoring further scaling until the fingers lift.

Both default to off. Double-tap zoom is unaffected. No upstream equivalent.

### Usage

```dart
MapOptions(
  interactionOptions: const InteractionOptions(
    scrollZoomOptions: ScrollZoomOptions.integer(),
    enableIntegerZoom: true, // pinch gestures
  ),
)
```

---

## Tests

`test/gestures/integer_scroll_zoom_test.dart` covers the scroll-wheel path: whole-level
settling in both directions, that it animates rather than jumps, accumulation and reversal of
chained ticks, cursor anchoring at an off-centre position, and the `maxZoom` clamp. Kept in its
own file so upstream's `scroll_wheel_zoom_test.dart` stays untouched.

Pinch integer zoom has no automated coverage — there are no multi-pointer gesture helpers in
the test suite to build on.

---

## Dropped from the JSosna fork

- **Hand-rolled animated scroll-wheel zoom.** Superseded by upstream's
  [#2198](https://github.com/fleaflet/flutter_map/pull/2198) (`ScrollZoomHandler`,
  `ScrollZoomOptions`). The integer mode above is built on that machinery instead.
- **Disabled OSM tile-server blocking** (`_blockOpenStreetMapUrl` hardcoded to `false`).
  Upstream removed the whole flow in `097f79a`.

The pre-sync history is preserved on the `archive/jsosna-v8.1.1` branch.

## Keeping in sync

```bash
git remote add upstream https://github.com/fleaflet/flutter_map.git
git fetch upstream
git rebase upstream/master
```

Two commits to replay. `tile_layer.dart` and the pinch hunk are low-risk; the integer scroll
zoom sits inside `ScrollZoomHandler` and will need attention if upstream reworks that file.
