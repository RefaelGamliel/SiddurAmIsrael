import 'package:flutter_compass/flutter_compass.dart';

/// Streams the device heading from the magnetometer.
///
/// Each event is the direction the **top of the device** points, in degrees
/// clockwise from north. The heading is null when the device cannot currently
/// determine it, and [headingStream] itself returns null when the platform has
/// no compass sensor at all — callers must handle both cases.
///
/// On iOS the heading is referenced to true north (Core Location applies the
/// local magnetic declination); on Android it is magnetic north. For pointing
/// toward Har HaBayit the few degrees of declination are immaterial.
class CompassDatasource {
  const CompassDatasource();

  Stream<double?>? headingStream() =>
      FlutterCompass.events?.map((event) => event.heading);
}
