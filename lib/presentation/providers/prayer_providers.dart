import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kosher_dart/kosher_dart.dart';
import 'package:siddur_am_israel_chai/core/calendar/hebrew_date.dart';
import 'package:siddur_am_israel_chai/core/data/cities.dart';
import 'package:siddur_am_israel_chai/data/datasources/local/gra_ssy_datasource.dart';
import 'package:siddur_am_israel_chai/data/datasources/local/kriah_datasource.dart';
import 'package:siddur_am_israel_chai/data/datasources/local/omer_mapping_datasource.dart';
import 'package:siddur_am_israel_chai/data/datasources/local/prayer_local_datasource.dart';
import 'package:siddur_am_israel_chai/data/datasources/local/settings_local_datasource.dart';
import 'package:siddur_am_israel_chai/data/datasources/local/sukkot_korbanot_datasource.dart';
import 'package:siddur_am_israel_chai/data/repositories/gra_ssy_repository_impl.dart';
import 'package:siddur_am_israel_chai/data/repositories/kriah_repository_impl.dart';
import 'package:siddur_am_israel_chai/data/repositories/omer_mapping_repository_impl.dart';
import 'package:siddur_am_israel_chai/data/repositories/prayer_repository_impl.dart';
import 'package:siddur_am_israel_chai/data/repositories/settings_repository_impl.dart';
import 'package:siddur_am_israel_chai/data/repositories/sukkot_korbanot_repository_impl.dart';
import 'package:siddur_am_israel_chai/domain/entities/assembled_segment.dart';
import 'package:siddur_am_israel_chai/domain/entities/day_flags.dart';
import 'package:siddur_am_israel_chai/domain/entities/omer_day.dart';
import 'package:siddur_am_israel_chai/domain/entities/prayer_zmanim.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_gra_ssy_repository.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_kriah_repository.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_omer_mapping_repository.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_prayer_repository.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_settings_repository.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_sukkot_korbanot_repository.dart';
import 'package:siddur_am_israel_chai/domain/services/halachic_calendar_service.dart';
import 'package:siddur_am_israel_chai/domain/services/i_calendar_flag_provider.dart';
import 'package:siddur_am_israel_chai/domain/services/i_prayer_assembler.dart';
import 'package:siddur_am_israel_chai/domain/services/prayer_assembler.dart';
import 'package:siddur_am_israel_chai/domain/services/prayer_zmanim_service.dart';
import 'package:siddur_am_israel_chai/domain/services/service_time_resolver.dart';
import 'package:siddur_am_israel_chai/presentation/providers/calendar_providers.dart';

// ── Dev date/time override (debug builds only) ───────────────────────────────

/// When non-null (debug builds only), overrides the "current time" used by
/// [hebrewDateProvider], [userContextProvider], and [currentServiceProvider].
/// Set via the dev panel in the Settings screen.
final devDateTimeOverrideProvider = StateProvider<DateTime?>(
  (ref) => null,
  // Wipe the override on every hot-restart so it never pollutes a new session.
);

// Convenience: resolves the effective "now" across all providers.
DateTime _effectiveNow(Ref ref) {
  if (kDebugMode) {
    return ref.watch(devDateTimeOverrideProvider) ?? DateTime.now();
  }
  return DateTime.now();
}

// Resolves the effective HEBREW-CALENDAR date. The halachic day rolls over at
// nightfall (צאת הכוכבים), not civil midnight: once the current time is past
// tzeit for the user's location, the calendar date — and therefore flags like
// Ya'aleh v'Yavo / Al HaNisim — already reflect the NEXT Hebrew day. Returns a
// noon-stamped DateTime so downstream date arithmetic is DST-safe.
DateTime _halachicNow(Ref ref) {
  final now = _effectiveNow(ref);
  final city = cityById(ref.watch(selectedCityIdProvider));
  final geo =
      GeoLocation.setLocation(city.name, city.latitude, city.longitude, now);
  final tzeit =
      ComplexZmanimCalendar.intGeoLocation(geo).getTzaisGeonim8Point5Degrees();
  final base = (tzeit != null && !now.isBefore(tzeit))
      ? now.add(const Duration(days: 1))
      : now;
  return DateTime(base.year, base.month, base.day, 12);
}

// ── Persistence ──────────────────────────────────────────────────────────────

/// Overridden in main() with the resolved instance, so widgets get it
/// synchronously without async hops.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  ),
);

final settingsLocalDatasourceProvider = Provider<SettingsLocalDatasource>(
  (ref) => SettingsLocalDatasource(ref.watch(sharedPreferencesProvider)),
);

final settingsRepositoryProvider = Provider<ISettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(settingsLocalDatasourceProvider)),
);

// ── Infrastructure ───────────────────────────────────────────────────────────

final prayerLocalDatasourceProvider = Provider<PrayerLocalDatasource>(
  (ref) => PrayerLocalDatasource(),
);

final prayerRepositoryProvider = Provider<IPrayerRepository>(
  (ref) => PrayerRepositoryImpl(ref.watch(prayerLocalDatasourceProvider)),
);

final omerMappingDatasourceProvider = Provider<OmerMappingDatasource>(
  (ref) => OmerMappingDatasource(),
);

final omerMappingRepositoryProvider = Provider<IOmerMappingRepository>(
  (ref) => OmerMappingRepositoryImpl(ref.watch(omerMappingDatasourceProvider)),
);

final sukkotKorbanotDatasourceProvider = Provider<SukkotKorbanotDatasource>(
  (ref) => SukkotKorbanotDatasource(),
);

final sukkotKorbanotRepositoryProvider = Provider<ISukkotKorbanotRepository>(
  (ref) =>
      SukkotKorbanotRepositoryImpl(ref.watch(sukkotKorbanotDatasourceProvider)),
);

final graSsyDatasourceProvider = Provider<GraSsyDatasource>(
  (ref) => GraSsyDatasource(),
);

final graSsyRepositoryProvider = Provider<IGraSsyRepository>(
  (ref) => GraSsyRepositoryImpl(ref.watch(graSsyDatasourceProvider)),
);

final kriahDatasourceProvider = Provider<KriahDatasource>(
  (ref) => KriahDatasource(),
);

final kriahRepositoryProvider = Provider<IKriahRepository>(
  (ref) => KriahRepositoryImpl(ref.watch(kriahDatasourceProvider)),
);

// ── Prayer-time zmanim (notes shown inside the siddur) ───────────────────────

final prayerZmanimServiceProvider =
    Provider<PrayerZmanimService>((ref) => const PrayerZmanimService());

/// The effective "now" (honours the dev override in debug builds).
final effectiveNowProvider = Provider<DateTime>((ref) => _effectiveNow(ref));

/// Zmanim for the morning service — computed for the current civil date at the
/// effective (GPS or selected) city. Used for the Sof-zman-Shema / Tefila notes.
final shacharitZmanimProvider = Provider<PrayerZmanim>((ref) {
  return ref.watch(prayerZmanimServiceProvider).compute(
        city: ref.watch(effectiveCityProvider),
        date: ref.watch(effectiveNowProvider),
      );
});

/// Zmanim for the Maariv night (sunset / tzeit / chatzot). Between midnight and
/// ~dawn the night still belongs to the previous civil day's sunset, so the
/// date is shifted back one day in the small hours.
final maarivZmanimProvider = Provider<PrayerZmanim>((ref) {
  final now = ref.watch(effectiveNowProvider);
  final date = now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
  return ref.watch(prayerZmanimServiceProvider).compute(
        city: ref.watch(effectiveCityProvider),
        date: date,
      );
});

final prayerAssemblerProvider = Provider<IPrayerAssembler>(
  (ref) => PrayerAssembler(
    ref.watch(prayerRepositoryProvider),
    omerRepository: ref.watch(omerMappingRepositoryProvider),
    sukkotRepository: ref.watch(sukkotKorbanotRepositoryProvider),
    graSsyRepository: ref.watch(graSsyRepositoryProvider),
    kriahRepository: ref.watch(kriahRepositoryProvider),
  ),
);

final calendarServiceProvider = Provider<ICalendarFlagProvider>(
  (ref) => HalachicCalendarService(),
);

final serviceTimeResolverProvider = Provider<ServiceTimeResolver>(
  (ref) => const ServiceTimeResolver(),
);

// ── User preferences (persistent state) ──────────────────────────────────────

/// Notifier base that loads the initial value from the settings repository
/// and persists each change. Avoids the verbose StateNotifier boilerplate for
/// these simple value holders.
class _PersistentNotifier<T> extends Notifier<T> {
  _PersistentNotifier({required this.read, required this.write});

  final T Function(ISettingsRepository) read;
  final Future<void> Function(ISettingsRepository, T) write;

  @override
  T build() => read(ref.read(settingsRepositoryProvider));

  void set(T value) {
    state = value;
    // Fire-and-forget; SharedPreferences writes are local & fast.
    write(ref.read(settingsRepositoryProvider), value);
  }
}

final nusachProvider = NotifierProvider<_PersistentNotifier<String>, String>(
  () => _PersistentNotifier<String>(
    read: (r) => r.getNusach(),
    write: (r, v) => r.setNusach(v),
  ),
);

/// Whether the user is in Eretz Yisrael — derived from the effective location
/// (GPS when enabled, otherwise the selected city), not a manual toggle.
/// Drives the Israel/chu"l liturgical differences (Yom Tov Sheni, etc.).
final isInIsraelProvider =
    Provider<bool>((ref) => ref.watch(effectiveCityProvider).inIsrael);

final userGenderProvider =
    NotifierProvider<_PersistentNotifier<Gender>, Gender>(
  () => _PersistentNotifier<Gender>(
    read: (r) => r.getGender(),
    write: (r, v) => r.setGender(v),
  ),
);

final withMinyanProvider = NotifierProvider<_PersistentNotifier<bool>, bool>(
  () => _PersistentNotifier<bool>(
    read: (r) => r.getWithMinyan(),
    write: (r, v) => r.setWithMinyan(v),
  ),
);

final purimDateProvider =
    NotifierProvider<_PersistentNotifier<PurimDate>, PurimDate>(
  () => _PersistentNotifier<PurimDate>(
    read: (r) => r.getPurimDate(),
    write: (r, v) => r.setPurimDate(v),
  ),
);

final fontSizeFactorProvider =
    NotifierProvider<_PersistentNotifier<double>, double>(
  () => _PersistentNotifier<double>(
    read: (r) => r.getFontSizeFactor(),
    write: (r, v) => r.setFontSizeFactor(v),
  ),
);

final hasSeenSettingsBannerProvider =
    NotifierProvider<_PersistentNotifier<bool>, bool>(
  () => _PersistentNotifier<bool>(
    read: (r) => r.getHasSeenSettingsBanner(),
    write: (r, v) => r.setHasSeenSettingsBanner(v),
  ),
);

final showSegmentLabelsProvider =
    NotifierProvider<_PersistentNotifier<bool>, bool>(
  () => _PersistentNotifier<bool>(
    read: (r) => r.getShowSegmentLabels(),
    write: (r, v) => r.setShowSegmentLabels(v),
  ),
);

/// Interface language code ('he' | 'en' | 'ru' | 'fr'). Affects only the
/// framework UI; the prayer texts are always Hebrew. Consumed by
/// `appLanguageEnumProvider` / `appStringsProvider` and `MaterialApp.locale`.
final appLanguageProvider =
    NotifierProvider<_PersistentNotifier<String>, String>(
  () => _PersistentNotifier<String>(
    read: (r) => r.getAppLanguage(),
    write: (r, v) => r.setAppLanguage(v),
  ),
);

/// Persists which optional segment IDs the user has chosen to keep expanded.
/// Tapping an accordion toggle saves/removes the ID from this set so the
/// choice survives app restarts — stored locally via SharedPreferences.
class _ExpandedSegmentsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref.read(settingsRepositoryProvider).getExpandedSegments();

  void toggle(String segmentId) {
    final next = {...state};
    if (next.contains(segmentId)) {
      next.remove(segmentId);
    } else {
      next.add(segmentId);
    }
    state = next;
    ref.read(settingsRepositoryProvider).setExpandedSegments(next);
  }
}

final expandedSegmentsProvider =
    NotifierProvider<_ExpandedSegmentsNotifier, Set<String>>(
  _ExpandedSegmentsNotifier.new,
);

/// Whether the user wears a tallit gadol (default true).
/// Used to inject [DayFlag.wearsTallitGadol] into the Shacharit context for
/// Ashkenaz/Sfard, gating the seder atifat tallit gadol accordion.
final isShaliachTzibburProvider =
    NotifierProvider<_PersistentNotifier<bool>, bool>(
  () => _PersistentNotifier<bool>(
    read: (r) => r.getIsShaliachTzibbur(),
    write: (r, v) => r.setIsShaliachTzibbur(v),
  ),
);

/// User toggle: "אין כהנים" (no kohanim present).
/// AutoDispose: resets to false when prayer screen unmounts.
final einKohanimProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Selected city id for the Hebrew calendar's zmanim (default Jerusalem).
final selectedCityIdProvider =
    NotifierProvider<_PersistentNotifier<String>, String>(
  () => _PersistentNotifier<String>(
    read: (r) => r.getLocationCityId(),
    write: (r, v) => r.setLocationCityId(v),
  ),
);

/// Location mode for the calendar's zmanim: 'city' (fixed) or 'gps'.
final locationModeProvider =
    NotifierProvider<_PersistentNotifier<String>, String>(
  () => _PersistentNotifier<String>(
    read: (r) => r.getLocationMode(),
    write: (r, v) => r.setLocationMode(v),
  ),
);

final wearsTallitGadolProvider =
    NotifierProvider<_PersistentNotifier<bool>, bool>(
  () => _PersistentNotifier<bool>(
    read: (r) => r.getWearsTallitGadol(),
    write: (r, v) => r.setWearsTallitGadol(v),
  ),
);

// ── Birkat HaMazon meal context (transient — NOT persisted) ──────────────────
// These reset to their defaults on every app launch by design: meal context
// changes per meal, so persisting it would be misleading.

class _TransientNotifier<T> extends Notifier<T> {
  _TransientNotifier(this.initial);
  final T initial;
  @override
  T build() => initial;
  void set(T value) => state = value;
}

final mealTypeProvider =
    NotifierProvider<_TransientNotifier<MealType>, MealType>(
  () => _TransientNotifier<MealType>(MealType.regular),
);

// ── Berachah Me'ein Shalosh (transient — per-occasion) ───────────────────────
// Which food type(s) are being blessed. Defaults to mezonot so the blessing
// is complete on open.
final meeinTypesProvider =
    NotifierProvider<_TransientNotifier<Set<MeeinType>>, Set<MeeinType>>(
  () => _TransientNotifier<Set<MeeinType>>({MeeinType.mezonot}),
);

// Eretz-Yisrael provenance for wine / fruit / grain. Default false = chutz
// la'aretz (per user spec). The grain (mezonot) toggle is only meaningful in
// Edot HaMizrach, but the provider exists for all nuscachim and is ignored
// elsewhere by the assembler.
final meeinGefenEyProvider = NotifierProvider<_TransientNotifier<bool>, bool>(
  () => _TransientNotifier<bool>(false),
);
final meeinPerotEyProvider = NotifierProvider<_TransientNotifier<bool>, bool>(
  () => _TransientNotifier<bool>(false),
);
final meeinMezonotEyProvider = NotifierProvider<_TransientNotifier<bool>, bool>(
  () => _TransientNotifier<bool>(false),
);

// ── Derived / computed ───────────────────────────────────────────────────────

final hebrewDateProvider = Provider<HebrewDate>(
  (ref) => HebrewDate.fromGregorian(_halachicNow(ref)),
);

final userContextProvider = Provider<UserContext>((ref) {
  final nusach = ref.watch(nusachProvider);
  final isInIsrael = ref.watch(isInIsraelProvider);
  final gender = ref.watch(userGenderProvider);
  final withMinyan = ref.watch(withMinyanProvider);
  final purimDate = ref.watch(purimDateProvider);
  final service = ref.watch(calendarServiceProvider);
  final baseCtx = UserContext(
    nusach: nusach,
    isInIsrael: isInIsrael,
    gender: gender,
    purimDate: purimDate,
    withMinyan: withMinyan,
  );
  final dayFlags = service.flagsFor(_halachicNow(ref), baseCtx);
  final flags = <String>{
    ...dayFlags.flags,
    if (withMinyan) DayFlag.withMinyan,
  }.toList();
  return UserContext(
    nusach: nusach,
    isInIsrael: isInIsrael,
    gender: gender,
    purimDate: purimDate,
    withMinyan: withMinyan,
    activeFlags: flags,
    omerDay: dayFlags.omerDay,
    sukkotDay: dayFlags.sukkotDay,
    pesachDay: dayFlags.pesachDay,
    chanukahDay: dayFlags.chanukahDay,
    chagYt1Weekday: dayFlags.chagYt1Weekday,
    upcomingParshah: dayFlags.upcomingParshah,
  );
});

/// Resolves the current day's [OmerDay] entry, or null when not in the omer
/// period.
final currentOmerDayProvider = FutureProvider<OmerDay?>((ref) async {
  final ctx = ref.watch(userContextProvider);
  if (ctx.omerDay == null) return null;
  final repo = ref.watch(omerMappingRepositoryProvider);
  return repo.loadDay(ctx.omerDay!);
});

/// Which prayer service is current right now (by halachic zmanim).
/// Initial tab in the AppShell reads this once on startup.
final currentServiceProvider = Provider<PrayerService>((ref) {
  final resolver = ref.watch(serviceTimeResolverProvider);
  return resolver.currentService(_effectiveNow(ref));
});

// ── Prayer content ───────────────────────────────────────────────────────────

UserContext _ctxWithExtraFlags(UserContext base, Iterable<String> extra) {
  final merged = <String>{...base.activeFlags, ...extra}.toList();
  return UserContext(
    nusach: base.nusach,
    isInIsrael: base.isInIsrael,
    gender: base.gender,
    purimDate: base.purimDate,
    withMinyan: base.withMinyan,
    activeFlags: merged,
    omerDay: base.omerDay,
    sukkotDay: base.sukkotDay,
    pesachDay: base.pesachDay,
    chanukahDay: base.chanukahDay,
    chagYt1Weekday: base.chagYt1Weekday,
    upcomingParshah: base.upcomingParshah,
  );
}

// ── Flow groups (continuous-paragraph merging) ───────────────────────────────
// Some blessings are authored as several small segments (for conditional
// variants), but read as one continuous flowing sentence. A flow group lists
// the segment IDs that, when they appear consecutively in the assembled
// output, are merged into a single segment whose text flows on one line.
class _FlowGroup {
  const _FlowGroup(this.members, [this.joiner = ' ']);
  final List<String> members;
  final String joiner; // inserted between merged members
}

const _flowGroups = <_FlowGroup>[
  // Birkat HaMazon (Ashkenaz/Sfard): הזן … (כאמור פותח) … ברוך … הזן את הכל
  _FlowGroup(['bhm_hazan_a', 'bhm_hazan_kaamur', 'bhm_hazan_chatima']),
  // Birkat HaMazon (A/S): רחם (נא) … body … בונה ברחמיו ירושלים
  _FlowGroup([
    'bhm_rachem_open_ashk',
    'bhm_rachem_open_sfard',
    'bhm_rachem_body',
    'bhm_rachem_chatima',
  ]),
  // Me'ein Shalosh: opening + ועל תנובת הארץ … בקדושה ובטהרה
  _FlowGroup(['ms_opening', 'ms_eretz']),
  // Me'ein Shalosh: near-closing + period + ברוך אתה ה' … chatima
  _FlowGroup(['ms_kiatah', 'ms_chatima'], '. '),
];

/// Merges each maximal run of consecutive segments that all belong to the same
/// [_FlowGroup] into a single segment whose text flows continuously (internal
/// line breaks within each member collapse to spaces).
List<AssembledSegment> _applyFlowGroups(List<AssembledSegment> segs) {
  final memberToGroup = <String, _FlowGroup>{};
  for (final g in _flowGroups) {
    for (final m in g.members) {
      memberToGroup[m] = g;
    }
  }

  final out = <AssembledSegment>[];
  var i = 0;
  while (i < segs.length) {
    final group = memberToGroup[segs[i].id];
    if (group == null) {
      out.add(segs[i]);
      i++;
      continue;
    }
    // Collect the consecutive run belonging to the same group.
    final run = <AssembledSegment>[];
    var j = i;
    while (j < segs.length && identical(memberToGroup[segs[j].id], group)) {
      run.add(segs[j]);
      j++;
    }
    if (run.length == 1) {
      out.add(run.first);
    } else {
      final text = run
          .map((s) => s.resolvedText.replaceAll('\n', ' ').trim())
          .where((t) => t.isNotEmpty)
          .join(group.joiner);
      out.add(run.first.copyWith(resolvedText: text));
    }
    i = j;
  }
  return out;
}

final shacharitProvider = FutureProvider<List<AssembledSegment>>((ref) {
  final assembler = ref.watch(prayerAssemblerProvider);
  final baseCtx = ref.watch(userContextProvider);
  final wearsTallitGadol = ref.watch(wearsTallitGadolProvider);
  final isShaliachTzibbur = ref.watch(isShaliachTzibburProvider);
  final einKohanim = ref.watch(einKohanimProvider);
  final isMale = baseCtx.gender == Gender.male;
  final extra = [
    DayFlag.serviceShacharit,
    // Tallit / shaliach tzibbur flags are male-only — women do not wear a
    // tallit gadol or serve as shaliach tzibbur in Orthodox Halacha.
    if (isMale &&
        wearsTallitGadol &&
        (baseCtx.nusach == 'ashkenaz' || baseCtx.nusach == 'sfard'))
      DayFlag.wearsTallitGadol,
    if (isMale && isShaliachTzibbur) DayFlag.isShaliachTzibbur,
    if (einKohanim) DayFlag.einKohanim,
  ];
  final ctx = _ctxWithExtraFlags(baseCtx, extra);
  return assembler.assemble(
    templateId: 'shacharit_${ctx.nusach}',
    userContext: ctx,
  );
});

final minchaProvider = FutureProvider<List<AssembledSegment>>((ref) {
  final assembler = ref.watch(prayerAssemblerProvider);
  final baseCtx = ref.watch(userContextProvider);
  // Inject Mincha-specific flags. tisha_beav is a whole-day flag, but Nachem
  // (and EM's Tisha B'Av chatima) only enter the bracha at Mincha.
  final ctx = _ctxWithExtraFlags(
    baseCtx,
    [
      DayFlag.serviceMincha,
      if (baseCtx.activeFlags.contains('tisha_beav')) 'tisha_beav_mincha',
    ],
  );
  return assembler.assemble(templateId: 'mincha', userContext: ctx);
});

/// Checks whether any of the Yom Tovim that block Vihi Noam for Ashkenaz/
/// Sfard fall within the next 6 days (Sun–Fri) or on the next Shabbat
/// (+7 days). Returns a record of (onWeekday, onShabbat).
({bool onWeekday, bool onShabbat}) _viHiNoamYomTovCheck(
    DateTime motzaei, bool inIsrael) {
  const blockedMonths = {
    JewishDate.TISHREI: [1, 2, 10, 15, 22], // RH, YK, Sukkot1, SA
    JewishDate.NISSAN: [15, 21], // Pesach1, Pesach7
  };

  for (var delta = 1; delta <= 7; delta++) {
    final d = motzaei.add(Duration(days: delta));
    final cal = JewishCalendar.fromDateTime(d);
    cal.inIsrael = inIsrael;
    final m = cal.getJewishMonth();
    final day = cal.getJewishDayOfMonth();
    final blocked = blockedMonths[m];
    if (blocked != null && blocked.contains(day)) {
      if (delta == 7)
        return (onWeekday: false, onShabbat: true); // next Shabbat
      return (onWeekday: true, onShabbat: false); // weekday
    }
  }
  return (onWeekday: false, onShabbat: false);
}

final maarivProvider = FutureProvider<List<AssembledSegment>>((ref) {
  final assembler = ref.watch(prayerAssemblerProvider);
  final baseCtx = ref.watch(userContextProvider);
  final isShabbat = baseCtx.activeFlags.contains(DayFlag.shabbat);
  final extra = <String>[];
  if (isShabbat) {
    extra.add(DayFlag.motzaeiShabbat);
    // For A/S: check if a blocking Yom Tov falls in the next week.
    if (baseCtx.nusach == 'ashkenaz' || baseCtx.nusach == 'sfard') {
      final now = kDebugMode
          ? (ref.read(devDateTimeOverrideProvider) ?? DateTime.now())
          : DateTime.now();
      final check = _viHiNoamYomTovCheck(now, baseCtx.isInIsrael);
      if (check.onWeekday) extra.add(DayFlag.yomTovNextWeek);
      if (check.onShabbat) extra.add('yom_tov_next_shabbat');
    }
  }
  final ctx = extra.isEmpty ? baseCtx : _ctxWithExtraFlags(baseCtx, extra);
  return assembler.assemble(
    templateId: 'maariv_${ctx.nusach}',
    userContext: ctx,
  );
});

final birkatHamazonProvider =
    FutureProvider<List<AssembledSegment>>((ref) async {
  final assembler = ref.watch(prayerAssemblerProvider);
  final baseCtx = ref.watch(userContextProvider);
  final mealType = ref.watch(mealTypeProvider);
  final flags = baseCtx.activeFlags.toSet();

  final extra = <String>[];

  // Pre-bentching psalm: on days with no tachanun (festive days, Rosh Chodesh,
  // etc.) and on Shabbat, only שיר המעלות is said — shown inline (no accordion).
  // On ordinary weekdays both psalms are offered as collapsible accordions.
  if (flags.contains(DayFlag.skipTachanun) || flags.contains(DayFlag.shabbat)) {
    extra.add(DayFlag.birkatFestivePsalm);
  }

  // Only the meal type is user-selectable now (שבע ברכות / ברית מילה). The
  // zimmun and dining-status variants are presented as full text with rubric
  // instructions / parentheses, so no zimmun/dining flags are injected.
  switch (mealType) {
    case MealType.regular:
    case MealType.seudatMitzvah:
      break;
    case MealType.shevaBrachot:
      extra.add(DayFlag.mealShevaBrachot);
    case MealType.britMilah:
      extra.add(DayFlag.mealBritMilah);
  }

  // מַגְדִּיל → מִגְדּוֹל in the closing Harachaman. The trigger differs by
  // nusach: A/S say מִגְדּוֹל on Rosh Chodesh / Chol HaMoed; EM say it on any
  // Musaf day, Motzaei Shabbat (proxied by the shabbat flag), Purim, or a
  // Brit Milah meal.
  final migdol = baseCtx.nusach == 'edot_mizrach'
      ? (flags.contains(DayFlag.musafDay) ||
          flags.contains(DayFlag.shabbat) ||
          flags.contains(DayFlag.purim) ||
          mealType == MealType.britMilah)
      : (flags.contains(DayFlag.roshChodesh) ||
          flags.contains(DayFlag.cholHamoedPesach) ||
          flags.contains(DayFlag.cholHamoedSukkot));
  if (migdol) extra.add(DayFlag.migdolWord);

  final ctx = _ctxWithExtraFlags(baseCtx, extra);
  final segs = await assembler.assemble(
    templateId: 'birkat_hamazon_${ctx.nusach}',
    userContext: ctx,
  );
  return _applyFlowGroups(segs);
});

final meeinShaloshProvider =
    FutureProvider<List<AssembledSegment>>((ref) async {
  final assembler = ref.watch(prayerAssemblerProvider);
  final baseCtx = ref.watch(userContextProvider);
  final types = ref.watch(meeinTypesProvider);
  final gefenEy = ref.watch(meeinGefenEyProvider);
  final perotEy = ref.watch(meeinPerotEyProvider);
  final mezonotEy = ref.watch(meeinMezonotEyProvider);

  // Calendar additions (Rosh Chodesh / Chol HaMoed) come from baseCtx.activeFlags
  // and are matched directly by the ms_date_* segments — no injection needed.
  final extra = <String>[];
  if (types.contains(MeeinType.mezonot)) {
    extra.add(DayFlag.meeinMezonot);
    // EY grain wording exists only in Edot HaMizrach.
    if (mezonotEy && baseCtx.nusach == 'edot_mizrach') {
      extra.add(DayFlag.meeinMezonotEy);
    }
  }
  if (types.contains(MeeinType.gefen)) {
    extra.add(DayFlag.meeinGefen);
    if (gefenEy) extra.add(DayFlag.meeinGefenEy);
  }
  if (types.contains(MeeinType.perot)) {
    extra.add(DayFlag.meeinPerot);
    if (perotEy) extra.add(DayFlag.meeinPerotEy);
  }

  final ctx = _ctxWithExtraFlags(baseCtx, extra);
  final segs = await assembler.assemble(
    templateId: 'meein_shalosh_${ctx.nusach}',
    userContext: ctx,
  );
  return _applyFlowGroups(segs);
});

/// Tefilat HaDerech (Traveler's Prayer): the main blessing plus an accordion
/// of additional verses. No conditional content beyond nusach selection.
final tefilatHaderechProvider = FutureProvider<List<AssembledSegment>>((ref) {
  final assembler = ref.watch(prayerAssemblerProvider);
  final ctx = ref.watch(userContextProvider);
  return assembler.assemble(
    templateId: 'tefilat_haderech_${ctx.nusach}',
    userContext: ctx,
  );
});
