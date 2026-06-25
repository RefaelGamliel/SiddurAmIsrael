import 'dart:math' as math;

/// Even HaShetiya (the Foundation Stone) on the Temple Mount — the focal point
/// of tefillah direction (mizrach) for the prayer-direction compass.
const double kHarHabayitLat = 31.778;
const double kHarHabayitLng = 35.2354;

/// Initial great-circle bearing, in degrees clockwise from **true north**
/// (0 = north, 90 = east, 180 = south, 270 = west), from the point
/// ([fromLat], [fromLng]) toward ([toLat], [toLng]).
///
/// All arguments are decimal degrees. The result is normalised to `[0, 360)`.
double initialBearing(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final phi1 = _deg2rad(fromLat);
  final phi2 = _deg2rad(toLat);
  final dLambda = _deg2rad(toLng - fromLng);

  final y = math.sin(dLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);

  final theta = math.atan2(y, x);
  return (_rad2deg(theta) + 360) % 360;
}

/// Bearing (degrees from true north) from ([lat], [lng]) to Har HaBayit.
double bearingToHarHabayit(double lat, double lng) =>
    initialBearing(lat, lng, kHarHabayitLat, kHarHabayitLng);

double _deg2rad(double d) => d * math.pi / 180.0;
double _rad2deg(double r) => r * 180.0 / math.pi;
