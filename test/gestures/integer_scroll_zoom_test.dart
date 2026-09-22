import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/gestures/scroll_zoom.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../test_utils/test_app.dart';
import '../test_utils/test_tile_provider.dart';

/// Sends a scroll event to the center of the FlutterMap widget.
Future<void> _scroll(WidgetTester tester, {required double dy}) =>
    _scrollAt(tester, tester.getCenter(find.byType(FlutterMap)), dy: dy);

/// Sends a scroll event to a global [position].
Future<void> _scrollAt(
  WidgetTester tester,
  Offset position, {
  required double dy,
}) async {
  await tester.sendEventToBinding(
    PointerScrollEvent(position: position, scrollDelta: Offset(0, dy)),
  );
}

/// Longer than [IntegerScrollZoomOptions.animationDuration], so that the
/// animation has certainly settled on its target.
const _settle = Duration(milliseconds: 400);

/// These tests inject `TestWidgetsFlutterBinding.instance.clock.now` into
/// [ScrollZoomHandler], which otherwise uses `DateTime.now()` and so would
/// advance in real time regardless of pumps.
void main() {
  group('Scroll zoom - integer mode', () {
    const options = InteractionOptions(
      scrollZoomOptions: ScrollZoomOptions.integer(),
    );

    testWidgets('settles on the next whole zoom level scrolling up',
        (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      await tester.pumpWidget(
        TestApp(controller: controller, interactionOptions: options),
      );

      // TestApp starts at the default initial zoom of 13.0.
      expect(controller.camera.zoom, equals(13));

      await _scroll(tester, dy: -100);
      await tester.pump(_settle);

      expect(controller.camera.zoom, equals(14));
    });

    testWidgets('settles on the previous whole zoom level scrolling down',
        (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      await tester.pumpWidget(
        TestApp(controller: controller, interactionOptions: options),
      );

      await _scroll(tester, dy: 100);
      await tester.pump(_settle);

      expect(controller.camera.zoom, equals(12));
    });

    testWidgets('animates rather than jumping immediately', (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      await tester.pumpWidget(
        TestApp(controller: controller, interactionOptions: options),
      );

      await _scroll(tester, dy: -100);

      // Part-way through the 200ms animation the camera should be between the
      // two whole levels, not already at the target.
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.camera.zoom, greaterThan(13));
      expect(controller.camera.zoom, lessThan(14));

      await tester.pump(_settle);
      expect(controller.camera.zoom, equals(14));
    });

    testWidgets('accumulates rapid ticks instead of restarting',
        (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      await tester.pumpWidget(
        TestApp(controller: controller, interactionOptions: options),
      );

      // Two ticks well within one animation duration of each other should
      // stack to two whole levels, rather than the second replacing the first.
      await _scroll(tester, dy: -100);
      await tester.pump(const Duration(milliseconds: 50));
      await _scroll(tester, dy: -100);
      await tester.pump(_settle);

      expect(controller.camera.zoom, equals(15));
    });

    testWidgets('reverses direction from the in-flight target', (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      await tester.pumpWidget(
        TestApp(controller: controller, interactionOptions: options),
      );

      await _scroll(tester, dy: -100);
      await tester.pump(const Duration(milliseconds: 50));
      await _scroll(tester, dy: 100);
      await tester.pump(_settle);

      // Heading for 14, stepping back one lands on 13 again.
      expect(controller.camera.zoom, equals(13));
    });

    testWidgets('keeps an off-centre cursor anchored across chained ticks',
        (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      await tester.pumpWidget(
        TestApp(controller: controller, interactionOptions: options),
      );

      // Deliberately off-centre: at the centre the focal offset is zero, so
      // anchoring to the animation's target and anchoring to its momentary
      // position are indistinguishable.
      const cursorLocal = Offset(160, 140);
      final cursorGlobal =
          tester.getTopLeft(find.byType(FlutterMap)) + cursorLocal;

      // The geographic point sitting under the cursor should not move.
      final anchorBefore = controller.camera.offsetToCrs(cursorLocal);

      await _scrollAt(tester, cursorGlobal, dy: -100);
      await tester.pump(const Duration(milliseconds: 50));
      // Second tick lands mid-animation: it must step out from the target the
      // first tick was heading for, not from wherever the camera has reached.
      await _scrollAt(tester, cursorGlobal, dy: -100);
      await tester.pump(_settle);

      expect(controller.camera.zoom, equals(15));

      final anchorAfter = controller.camera.offsetToCrs(cursorLocal);
      expect(anchorAfter.latitude, closeTo(anchorBefore.latitude, 1e-6));
      expect(anchorAfter.longitude, closeTo(anchorBefore.longitude, 1e-6));
    });

    testWidgets('does not exceed maxZoom', (tester) async {
      ScrollZoomHandler.currentTimestamp =
          TestWidgetsFlutterBinding.instance.clock.now;
      final controller = MapController();
      // Built inline rather than via TestApp, which exposes no maxZoom.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: FlutterMap(
                  mapController: controller,
                  options: const MapOptions(
                    initialCenter: LatLng(45.5231, -122.6765),
                    maxZoom: 14,
                    interactionOptions: options,
                  ),
                  children: [TileLayer(tileProvider: TestTileProvider())],
                ),
              ),
            ),
          ),
        ),
      );

      await _scroll(tester, dy: -100);
      await tester.pump(_settle);
      expect(controller.camera.zoom, equals(14));

      // A further tick at the limit should be a no-op.
      await _scroll(tester, dy: -100);
      await tester.pump(_settle);
      expect(controller.camera.zoom, equals(14));
    });
  });
}
