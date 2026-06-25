// The nusach/purim selectors keep RadioListTile bound directly to the
// persistent providers. Flutter's RadioListTile group API (groupValue/
// onChanged) is deprecated in favor of a RadioGroup ancestor, but introducing
// that ancestor would restructure the provider-bound tiles for no behavioral
// gain, so the deprecation is suppressed locally here instead.
// ignore_for_file: deprecated_member_use
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:siddur_am_israel_chai/core/data/cities.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/presentation/constants/app_config.dart';
import 'package:siddur_am_israel_chai/presentation/i18n/app_locale.dart';
import 'package:siddur_am_israel_chai/presentation/i18n/app_strings.dart';
import 'package:siddur_am_israel_chai/presentation/providers/calendar_providers.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_colors.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_dimens.dart';

/// Bottom sheet to choose the city used for the calendar's zmanim.
Future<void> _pickCity(
    BuildContext context, WidgetRef ref, String currentId) async {
  final s = ref.read(appStringsProvider);
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(s.t('choose_city'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary)),
            ),
            for (final c in kCities)
              ListTile(
                title: Text(c.name),
                trailing: c.id == currentId
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    ),
  );
  if (id != null) ref.read(selectedCityIdProvider.notifier).set(id);
}

/// User preferences screen. Every change writes through to
/// SharedPreferences immediately via the persistent providers.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.onBack});

  /// When provided, a back arrow is shown that returns to the screen the user
  /// came from (e.g. the prayer they were reading) without re-selecting a tab.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nusach = ref.watch(nusachProvider);
    final gender = ref.watch(userGenderProvider);
    final withMinyan = ref.watch(withMinyanProvider);
    final purimDate = ref.watch(purimDateProvider);
    final fontFactor = ref.watch(fontSizeFactorProvider);
    final showLabels = ref.watch(showSegmentLabelsProvider);
    final city = ref.watch(selectedCityProvider);
    final locationMode = ref.watch(locationModeProvider);
    final language = ref.watch(appLanguageProvider);
    final lang = ref.watch(appLanguageEnumProvider);
    final s = ref.watch(appStringsProvider);
    // Tallit / shaliach tzibbur / kohanim toggles are now inline in the prayer screen.

    return Directionality(
      textDirection: lang.direction,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: onBack == null
              ? null
              : IconButton(
                  icon: const BackButtonIcon(),
                  onPressed: onBack,
                ),
          title: Text(s.t('tab_settings'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: ListView(
          children: [
            _SectionHeader(title: s.t('section_nusach')),
            RadioListTile<String>(
              value: 'edot_mizrach',
              groupValue: nusach,
              title: Text(s.t('nusach_edot_mizrach')),
              onChanged: (v) =>
                  ref.read(nusachProvider.notifier).set(v ?? 'edot_mizrach'),
            ),
            RadioListTile<String>(
              value: 'sfard',
              groupValue: nusach,
              title: Text(s.t('nusach_sfard')),
              onChanged: (v) =>
                  ref.read(nusachProvider.notifier).set(v ?? 'sfard'),
            ),
            RadioListTile<String>(
              value: 'ashkenaz',
              groupValue: nusach,
              title: Text(s.t('nusach_ashkenaz')),
              onChanged: (v) =>
                  ref.read(nusachProvider.notifier).set(v ?? 'ashkenaz'),
            ),
            _SectionHeader(title: s.t('section_davener')),
            SwitchListTile(
              title: Text(s.t('i_am_woman')),
              value: gender == Gender.female,
              activeColor: AppColors.primary,
              onChanged: (isFemale) => ref
                  .read(userGenderProvider.notifier)
                  .set(isFemale ? Gender.female : Gender.male),
            ),
            _SectionHeader(title: s.t('section_zmanim_location')),
            SwitchListTile(
              title: Text(s.t('use_gps')),
              subtitle: Text(s.t('use_gps_sub')),
              value: locationMode == 'gps',
              activeColor: AppColors.primary,
              onChanged: (v) {
                ref.read(locationModeProvider.notifier).set(v ? 'gps' : 'city');
                if (v) ref.invalidate(currentLocationProvider);
              },
            ),
            if (locationMode != 'gps')
              ListTile(
                leading: const Icon(Icons.location_city_outlined,
                    color: AppColors.primary),
                title: Text(s.t('city_for_times')),
                subtitle: Text(city.name),
                trailing:
                    const Icon(Icons.chevron_left, color: AppColors.primary),
                onTap: () => _pickCity(context, ref, city.id),
              ),
            _SectionHeader(title: s.t('section_prayer')),
            SwitchListTile(
              title: Text(s.t('with_minyan')),
              value: withMinyan,
              onChanged: (v) => ref.read(withMinyanProvider.notifier).set(v),
            ),
            _SectionHeader(title: s.t('section_purim')),
            RadioListTile<PurimDate>(
              value: PurimDate.fourteenth,
              groupValue: purimDate,
              title: Text(s.t('purim_14')),
              onChanged: (v) => ref
                  .read(purimDateProvider.notifier)
                  .set(v ?? PurimDate.fourteenth),
            ),
            RadioListTile<PurimDate>(
              value: PurimDate.fifteenth,
              groupValue: purimDate,
              title: Text(s.t('purim_15')),
              onChanged: (v) => ref
                  .read(purimDateProvider.notifier)
                  .set(v ?? PurimDate.fifteenth),
            ),
            RadioListTile<PurimDate>(
              value: PurimDate.both,
              groupValue: purimDate,
              title: Text(s.t('purim_both')),
              onChanged: (v) =>
                  ref.read(purimDateProvider.notifier).set(v ?? PurimDate.both),
            ),
            _SectionHeader(title: s.t('section_display')),
            SwitchListTile(
              title: Text(s.t('show_labels')),
              value: showLabels,
              onChanged: (v) =>
                  ref.read(showSegmentLabelsProvider.notifier).set(v),
            ),
            _SectionHeader(title: s.t('section_font')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('א', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: fontFactor,
                      min: AppDimens.fontFactorMin,
                      max: AppDimens.fontFactorMax,
                      divisions: AppDimens.fontFactorDivisions,
                      label: '${(fontFactor * 100).round()}%',
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          ref.read(fontSizeFactorProvider.notifier).set(v),
                    ),
                  ),
                  const Text('א', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Text(
                  'מוֹדֶה אֲנִי לְפָנֶיךָ מֶלֶךְ חַי וְקַיָּם שֶׁהֶחֱזַרְתָּ בִּי נִשְׁמָתִי בְּחֶמְלָה רַבָּה אֱמוּנָתֶךָ:',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 22 * fontFactor),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SectionHeader(title: s.t('section_language')),
            for (final l in AppLanguage.values)
              RadioListTile<String>(
                value: l.code,
                groupValue: language,
                title: Text(l.nativeName, textDirection: l.direction),
                onChanged: (v) => ref
                    .read(appLanguageProvider.notifier)
                    .set(v ?? AppLanguage.hebrew.code),
              ),
            const SizedBox(height: 8),
            _SectionHeader(title: s.t('section_contact')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(s.t('support')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  alignment: AlignmentDirectional.centerEnd,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () async {
                  final uri = Uri.parse(AppConfig.supportUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            if (kDebugMode) _DevDateTimePanel(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DevDateTimePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(devDateTimeOverrideProvider);
    final displayDt = override ?? DateTime.now();

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: displayDt,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        locale: const Locale('he'),
      );
      if (picked == null) return;
      ref.read(devDateTimeOverrideProvider.notifier).state = DateTime(
        picked.year,
        picked.month,
        picked.day,
        displayDt.hour,
        displayDt.minute,
      );
    }

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: displayDt.hour, minute: displayDt.minute),
      );
      if (picked == null) return;
      ref.read(devDateTimeOverrideProvider.notifier).state = DateTime(
        displayDt.year,
        displayDt.month,
        displayDt.day,
        picked.hour,
        picked.minute,
      );
    }

    final dateStr = '${displayDt.day.toString().padLeft(2, '0')}/'
        '${displayDt.month.toString().padLeft(2, '0')}/'
        '${displayDt.year}';
    final timeStr = '${displayDt.hour.toString().padLeft(2, '0')}:'
        '${displayDt.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppColors.borderLight),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: const [
              Icon(Icons.bug_report, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'כלי פיתוח — תאריך ושעה',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            override == null ? 'זמן אמיתי (ללא דריסה)' : 'דריסה פעילה',
            style: TextStyle(
              fontSize: 12,
              color: override == null ? Colors.grey : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dateStr),
                onPressed: pickDate,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 16),
                label: Text(timeStr),
                onPressed: pickTime,
              ),
              if (override != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('איפוס'),
                  onPressed: () => ref
                      .read(devDateTimeOverrideProvider.notifier)
                      .state = null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
