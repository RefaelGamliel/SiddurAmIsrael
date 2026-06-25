import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/core/utils/geo_bearing.dart';
import 'package:siddur_am_israel_chai/data/datasources/device/compass_datasource.dart';
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

/// Bearing (degrees from true north) toward Har HaBayit from the effective
/// location — GPS when enabled, otherwise the selected city.
final harHabayitBearingProvider = Provider<double>((ref) {
  final city = ref.watch(effectiveCityProvider);
  return bearingToHarHabayit(city.latitude, city.longitude);
});
