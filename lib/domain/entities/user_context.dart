import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_context.freezed.dart';

enum Gender { male, female }

/// Which Purim date(s) the user observes.
/// Fourteenth = regular cities (everywhere except walled cities).
/// Fifteenth  = walled cities (Jerusalem, etc.).
/// Both       = celebrates both days (e.g. living near a walled city).
enum PurimDate { fourteenth, fifteenth, both }

/// Type of meal for Birkat HaMazon. Transient (per-meal) — NOT persisted.
/// regular        = everyday meal
/// seudatMitzvah  = (retained for enum stability; no longer user-selectable)
/// shevaBrachot   = wedding / sheva brachot meal (adds zimmun + kos blessings)
/// britMilah      = circumcision meal (adds zimmun intro + Harachaman block)
///
/// The zimmun (3/10) and dining-status variants are no longer user toggles —
/// the full text is shown with rubric instructions / parentheses instead.
enum MealType { regular, seudatMitzvah, shevaBrachot, britMilah }

/// Food type(s) for Berachah Me'ein Shalosh. A user may bless on any
/// combination; recitation order is always mezonot → gefen → perot.
/// Transient (per-occasion) — NOT persisted.
/// mezonot = five grains (על המחיה)
/// gefen   = wine (על הגפן)
/// perot   = fruit of the seven species (על העץ)
enum MeeinType { mezonot, gefen, perot }

@freezed
class UserContext with _$UserContext {
  const factory UserContext({
    required String nusach,
    @Default(true) bool isInIsrael,
    @Default(Gender.male) Gender gender,
    @Default(PurimDate.fourteenth) PurimDate purimDate,
    // Populated by HalachicCalendarService each day.
    // Examples: 'shabbat', 'rosh_chodesh', 'skip_tachanun',
    // 'aseret_yemei_teshuva', 'skip_lamenatzeach', 'yaaleh_veyavo', etc.
    @Default([]) List<String> activeFlags,
    // 1..49 during the 49 days of Sefirat HaOmer (16 Nisan through 5 Sivan).
    // Null on every other day. The PrayerAssembler uses this to fetch the
    // matching row from `_omer_mapping.json` (text per nusach, sefira, and
    // the words/letter to bold in Ana BeKoach / Lamenatzeach / Yismechu).
    int? omerDay,
    // 1..7 during Sukkot (15–21 Tishrei). 1 = first day (Yom Tov),
    // 2..6 = Chol HaMoed, 7 = Hoshana Raba. Used to resolve the daily korban
    // in Musaf and other day-specific content. Null outside Sukkot.
    int? sukkotDay,
    // 1..7 (EY) / 1..8 (chu"l) during Pesach (15 Nisan onward).
    // 1 = YT1, 7 = YT7 (last YT in EY), 8 = Acharon Pesach (chu"l only).
    // Used by Gr"a Shir Shel Yom mapping. Null outside Pesach.
    int? pesachDay,
    // 1..8 during Chanukah. Used by KriahPostProcessor for the RC Tevet
    // composite reading. Null outside Chanukah.
    int? chanukahDay,
    // Day-of-week (Mon=1 … Sun=7) of YT1 of the current chag (Pesach or
    // Sukkot). Used together with pesachDay/sukkotDay by the Gr"a SSY
    // post-processor to look up the day's Tehillim chapter. Null outside
    // those chagim.
    int? chagYt1Weekday,
    // Slug of the upcoming Shabbat's parashah (combined → first single).
    // Used by the Mon/Thu Torah-reading post-processor.
    String? upcomingParshah,
    // User is davening with a minyan. Drives the [DayFlag.withMinyan] flag,
    // which gates Kaddish / Chazarat HaShatz / Kriat HaTorah / Barchu /
    // Yud-Gimel Middot. Default true.
    @Default(true) bool withMinyan,
  }) = _UserContext;
}
