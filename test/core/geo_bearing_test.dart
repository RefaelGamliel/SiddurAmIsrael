import 'package:flutter_test/flutter_test.dart';
import 'package:siddur_am_israel_chai/core/utils/geo_bearing.dart';

void main() {
  group('initialBearing — cardinal directions', () {
    test('due east is 90°', () {
      expect(initialBearing(0, 0, 0, 10), closeTo(90, 0.001));
    });
    test('due west is 270°', () {
      expect(initialBearing(0, 10, 0, 0), closeTo(270, 0.001));
    });
    test('due north is 0°', () {
      expect(initialBearing(0, 0, 10, 0), closeTo(0, 0.001));
    });
    test('due south is 180°', () {
      expect(initialBearing(10, 0, 0, 0), closeTo(180, 0.001));
    });
  });

  group('bearingToHarHabayit', () {
    test('always returns a value in [0, 360)', () {
      final b = bearingToHarHabayit(32.0853, 34.7818);
      expect(b, greaterThanOrEqualTo(0));
      expect(b, lessThan(360));
    });

    test('from Tel Aviv points south-east toward Jerusalem (~115–140°)', () {
      expect(bearingToHarHabayit(32.0853, 34.7818), inInclusiveRange(115, 140));
    });

    test('from New York the initial great-circle bearing is north-east', () {
      // Flights NYC→Israel leave heading north-east (~50–60°).
      expect(bearingToHarHabayit(40.7128, -74.0060), inInclusiveRange(40, 70));
    });

    test('from due west on the same latitude points roughly east', () {
      expect(
        bearingToHarHabayit(kHarHabayitLat, kHarHabayitLng - 5),
        inInclusiveRange(85, 95),
      );
    });
  });
}
