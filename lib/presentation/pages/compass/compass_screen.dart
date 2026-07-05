import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/core/utils/geo_bearing.dart';
import 'package:siddur_am_israel_chai/domain/entities/city.dart';
import 'package:siddur_am_israel_chai/presentation/i18n/app_strings.dart';
import 'package:siddur_am_israel_chai/presentation/providers/compass_providers.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_colors.dart';

/// A simple prayer-direction compass: a single arrow that always points toward
/// Har HaBayit as the user turns the device. There is deliberately no north
/// marker — only a faint fixed notch at the top showing the way the device
/// points, so the user just rotates until the arrow lines up with it.
class CompassScreen extends ConsumerWidget {
  const CompassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final locationAsync = ref.watch(compassLocationProvider);
    final headingAsync = ref.watch(headingProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(s.t('compass_title')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: locationAsync.when(
          loading: () => const _Spinner(),
          error: (_, __) => _NoSensor(s: s),
          data: (city) {
            final bearing = bearingToHarHabayit(city.latitude, city.longitude);
            return headingAsync.when(
              loading: () => const _Spinner(),
              error: (_, __) => _NoSensor(s: s),
              data: (heading) => heading == null
                  ? _NoSensor(s: s)
                  : _CompassView(
                      heading: heading,
                      bearing: bearing,
                      city: city,
                      s: s,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _CompassView extends StatelessWidget {
  const _CompassView({
    required this.heading,
    required this.bearing,
    required this.city,
    required this.s,
  });

  final double heading;
  final double bearing;
  final City city;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    // Angle of Har HaBayit relative to the device's forward ("up") direction.
    final relative = bearing - heading;
    final radians = relative * math.pi / 180.0;

    // Normalise to [-180, 180] to detect when the user is on target.
    var delta = relative % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final facing = delta.abs() <= 5;
    final accent = facing ? Colors.green.shade600 : AppColors.primary;

    final note = city.id == 'gps'
        ? s.t('compass_note_gps')
        : s.t('compass_note_city').replaceFirst('{city}', city.name);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          facing ? s.t('compass_facing') : s.t('compass_instruction'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: facing ? Colors.green.shade700 : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: accent, width: 3),
                ),
              ),
              // Faint fixed notch = the direction the device points.
              Positioned(
                top: 4,
                child: Icon(Icons.arrow_drop_up,
                    size: 30, color: Colors.grey.shade400),
              ),
              // The arrow that tracks Har HaBayit.
              Transform.rotate(
                angle: radians,
                child: Icon(Icons.navigation, size: 124, color: accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            note,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
}

class _NoSensor extends StatelessWidget {
  const _NoSensor({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              s.t('compass_no_sensor'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
