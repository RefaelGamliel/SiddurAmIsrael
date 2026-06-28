import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/data/datasources/device/compass_datasource.dart';
import 'package:siddur_am_israel_chai/domain/entities/city.dart';
import 'package:siddur_am_israel_chai/presentation/providers/calendar_providers.dart';

final compassDatasourceProvider =
    Provider<CompassDatasource>((ref) => const CompassDatasource());

/// Live device heading (degrees clockwise from north).
///
/// A data value of `null` means the device has no usable compass sensor — the
/// stream emits a single `null` in that case so the UI can show a fallback
/// instead of spinning forever on a loading state.
final headingProvider = StreamProvider.autoDispose<double?>((ref) {
  final stream = ref.watch(compassDatasourceProvider).headingStream();
  return stream ?? Stream<double?>.value(null);
});

/// Location used for the compass.
///
/// Unlike the zmanim location (which follows the user's city/GPS *setting*),
/// direction depends on exactly where you are standing — so this ALWAYS tries
/// the device's precise GPS position first, and only falls back to the selected
/// city when GPS is unavailable or denied. The returned city has id `'gps'`
/// when it came from the device, which the UI uses to label the source.
final compassLocationProvider = FutureProvider.autoDispose<City>((ref) async {
  final gps = await ref.watch(locationDatasourceProvider).currentCity();
  return gps ?? ref.watch(selectedCityProvider);
});
