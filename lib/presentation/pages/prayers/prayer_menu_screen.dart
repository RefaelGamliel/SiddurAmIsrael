import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/domain/entities/assembled_segment.dart';
import 'package:siddur_am_israel_chai/domain/services/service_time_resolver.dart';
import 'package:siddur_am_israel_chai/presentation/i18n/app_strings.dart';
import 'package:siddur_am_israel_chai/presentation/pages/prayers/prayer_screen.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_colors.dart';

/// One selectable prayer service in the menu.
class _PrayerEntry {
  const _PrayerEntry(this.service, this.titleKey, this.icon);
  final PrayerService service;
  final String titleKey;
  final IconData icon;
}

const _entries = <_PrayerEntry>[
  _PrayerEntry(PrayerService.shacharit, 'shacharit', Icons.wb_sunny_outlined),
  _PrayerEntry(PrayerService.mincha, 'mincha', Icons.brightness_6_outlined),
  _PrayerEntry(PrayerService.maariv, 'maariv', Icons.brightness_4_outlined),
];

FutureProvider<List<AssembledSegment>> _providerFor(PrayerService s) =>
    switch (s) {
      PrayerService.shacharit => shacharitProvider,
      PrayerService.mincha => minchaProvider,
      PrayerService.maariv => maarivProvider,
    };

/// Builds the reading screen for [service], wrapped RTL so the Hebrew prayer
/// text always renders right-to-left regardless of the interface language.
Widget buildPrayerReader(
  PrayerService service,
  String title, {
  VoidCallback? onOpenSettings,
}) =>
    Directionality(
      textDirection: TextDirection.rtl,
      child: PrayerScreen(
        title: title,
        contentProvider: _providerFor(service),
        onOpenSettings: onOpenSettings,
      ),
    );

/// Landing list for the "תפילות" tab. Shows Shacharit / Mincha / Maariv with
/// the service matching the current time highlighted; tapping one opens it.
class PrayerMenuScreen extends ConsumerWidget {
  const PrayerMenuScreen({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final current = ref.watch(currentServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.t('tab_prayers'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final e in _entries)
            _PrayerTile(
              title: s.t(e.titleKey),
              icon: e.icon,
              isCurrent: e.service == current,
              nowLabel: s.t('now_badge'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => buildPrayerReader(
                    e.service,
                    s.t(e.titleKey),
                    onOpenSettings: onOpenSettings,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({
    required this.title,
    required this.icon,
    required this.isCurrent,
    required this.nowLabel,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isCurrent;
  final String nowLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white,
      elevation: isCurrent ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? AppColors.primary : AppColors.borderLight,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        trailing: isCurrent
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(nowLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              )
            : const Icon(Icons.chevron_left, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
