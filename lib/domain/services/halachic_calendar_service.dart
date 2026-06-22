import 'package:kosher_dart/kosher_dart.dart';

import 'package:siddur_am_israel_chai/domain/entities/day_flags.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/domain/services/i_calendar_flag_provider.dart';

/// Computes the full set of Halachic flags for a given Gregorian date
/// and user context. All Hebrew calendar arithmetic is handled by the
/// kosher_dart library (JewishCalendar).
class HalachicCalendarService implements ICalendarFlagProvider {
  const HalachicCalendarService();

  @override
  DayFlags flagsFor(DateTime date, UserContext context) {
    final cal = JewishCalendar.fromDateTime(date);
    cal.inIsrael = context.isInIsrael;

    final flags = <String>{};

    _addDayIdentification(cal, date, context, flags);
    _addSeasonFlags(cal, date, context, flags);
    _addTachanunFlags(cal, flags);
    _addLamenatzeachFlag(context, flags);
    _addAsaretYemeiTeshuva(cal, flags);
    _addAvinoMalkeinu(flags);
    _addYaalehVeyavo(flags);
    _addAlHaNisim(flags);
    _addMizmorLetodahFlag(context, flags);
    _addTefillinFlag(context, flags);
    _addShemaHotzaahFlag(flags);
    _addKriatHatorahFlag(flags);
    _addMusafDayFlag(flags);
    _addHallelFlags(cal, flags);
    _addLulavDayFlag(flags);
    _addGenderAndIsrael(context, flags);
    _addLeapKeferatPashay(cal, flags);

    // Sefirat HaOmer day: kosher_dart returns 1..49 during the count
    // (16 Nisan through 5 Sivan), or -1 outside that window.
    final int rawOmer = cal.getDayOfOmer();
    final int? omerDay = (rawOmer >= 1 && rawOmer <= 49) ? rawOmer : null;
    if (omerDay != null) flags.add(DayFlag.omerPeriod);

    // Sukkot day (1..7): set only during 15–21 Tishrei.
    final int? sukkotDay = _computeSukkotDay(cal);
    // Pesach day (1..7 EY): set only during 15-21 Nisan.
    final int? pesachDay = _computePesachDay(cal);
    // Chanukah day (1..8): kosher_dart returns -1 outside Chanukah.
    final int rawChan = cal.getDayOfChanukah();
    final int? chanukahDay = (rawChan >= 1 && rawChan <= 8) ? rawChan : null;
    // YT1 weekday for the current chag (Pesach or Sukkot). Null outside.
    int? chagYt1Weekday;
    if (sukkotDay != null) {
      chagYt1Weekday = _yt1Weekday(date, sukkotDay);
    } else if (pesachDay != null) {
      chagYt1Weekday = _yt1Weekday(date, pesachDay);
    }

    // Emit pesach_day_<N> boolean flags.
    if (pesachDay != null) {
      const pesachDayFlags = [
        DayFlag.pesachDay1, DayFlag.pesachDay2, DayFlag.pesachDay3,
        DayFlag.pesachDay4, DayFlag.pesachDay5, DayFlag.pesachDay6,
        DayFlag.pesachDay7,
      ];
      flags.add(pesachDayFlags[pesachDay - 1]);
      // CHM Pesach reading shift when YT1 falls on Thursday (Dart=4):
      // Shabbat lands at pesachDay 3, so readings 3-5 shift down by one
      // (Psal Lecha goes to Shabbat, OOS for us).
      if (chagYt1Weekday == DateTime.thursday) {
        flags.add(DayFlag.pesachYt1Thursday);
      }
    }

    // Emit sukkot_day_<N> boolean flags + hoshanot_day flag.
    if (sukkotDay != null) {
      const sukkotDayFlags = [
        DayFlag.sukkotDay1, DayFlag.sukkotDay2, DayFlag.sukkotDay3,
        DayFlag.sukkotDay4, DayFlag.sukkotDay5, DayFlag.sukkotDay6,
        DayFlag.sukkotDay7,
      ];
      flags.add(sukkotDayFlags[sukkotDay - 1]);
      // hoshanot_day: days 2..7, not Shabbat.
      if (sukkotDay >= 2 &&
          sukkotDay <= 7 &&
          !flags.contains(DayFlag.shabbat)) {
        flags.add(DayFlag.hoshanotDay);
      }
    }

    // Upcoming parashah slug (for Mon/Thu Torah reading lookup). Mapped
    // combined-parshiot → first single per the standard Mon/Thu rule.
    final upcomingParshah = _computeUpcomingParshah(cal);

    // kriat_hatorah_mon_thu: gate the regular weekly reading. Set only
    // when there's no overriding special reading. The user said in
    // future batches we'll add specific flags for RC/CHM/Chanukah/Purim
    // etc.; for now the override list mirrors them.
    if (flags.contains(DayFlag.mondayThursday) &&
        upcomingParshah != null &&
        !flags.contains(DayFlag.roshChodesh) &&
        !flags.contains(DayFlag.chanukah) &&
        !flags.contains(DayFlag.purim) &&
        !flags.contains(DayFlag.shushanPurim) &&
        !flags.contains(DayFlag.cholHamoedPesach) &&
        !flags.contains(DayFlag.cholHamoedSukkot) &&
        !flags.contains(DayFlag.fastDay)) {
      flags.add(DayFlag.kriatHatorahMonThu);
    }
    // Standalone RC reading: RC NOT during Chanukah (RC Tevet → composite
    // reading handled separately in E.8e, NOT here).
    if (flags.contains(DayFlag.roshChodesh) &&
        !flags.contains(DayFlag.chanukah)) {
      flags.add(DayFlag.kriatHatorahRc);
    }
    // RC Tevet — always falls during Chanukah. Composite reading: olim
    // 1-3 from RC, oleh 4 from Chanukah day-N. Handled by KriahPostProcessor.
    if (flags.contains(DayFlag.roshChodesh) &&
        flags.contains(DayFlag.chanukah)) {
      flags.add(DayFlag.rcTevet);
    }
    // Chanukah standalone — NOT on RC Tevet (composite there).
    if (flags.contains(DayFlag.chanukah) &&
        !flags.contains(DayFlag.roshChodesh)) {
      flags.add(DayFlag.kriatHatorahChanukah);
    }
    // Purim Torah reading. Already gated by purim flag (which respects
    // UserContext.purimDate); shushanPurim also gets a reading in walled
    // cities. We fire on either to match standard practice.
    if (flags.contains(DayFlag.purim) ||
        flags.contains(DayFlag.shushanPurim)) {
      flags.add(DayFlag.kriatHatorahPurim);
    }

    // Derived: gra_ssy_day on CHM Pesach + CHM Sukkot (incl. Hoshana Raba).
    // The first/last days of the chag are YT and have their own SSY (92 on
    // Shabbat, 76 on weekdays of Sukkot, 114 of Pesach) — Gr"a only swaps
    // SSY on the intermediate CHM days, which is what we gate here.
    if ((pesachDay != null && pesachDay >= 2 && pesachDay <= 6) ||
        (sukkotDay != null && sukkotDay >= 2 && sukkotDay <= 7)) {
      flags.add(DayFlag.graSsyDay);
    }

    // chanukah_day_<N> boolean flags.
    if (chanukahDay != null) {
      const chanukahDayFlags = [
        DayFlag.chanukahDay1, DayFlag.chanukahDay2, DayFlag.chanukahDay3,
        DayFlag.chanukahDay4, DayFlag.chanukahDay5, DayFlag.chanukahDay6,
        DayFlag.chanukahDay7, DayFlag.chanukahDay8,
      ];
      flags.add(chanukahDayFlags[chanukahDay - 1]);
    }

    return DayFlags(
      flags: flags.toList(),
      omerDay: omerDay,
      sukkotDay: sukkotDay,
      pesachDay: pesachDay,
      chanukahDay: chanukahDay,
      chagYt1Weekday: chagYt1Weekday,
      upcomingParshah: upcomingParshah,
    );
  }

  // ── Upcoming parashah (Mon/Thu Torah reading lookup) ───────────────────
  // kosher_dart's getParshah() returns the parashah for the upcoming
  // Shabbat (or NONE for special Shabbatot when YT/RC override). For
  // combined parshiot we collapse to the FIRST single (Tazria-Metzora →
  // tazria) per the standard Mon/Thu rule.
  String? _computeUpcomingParshah(JewishCalendar cal) {
    // getParshah() returns a parsha only ON Shabbat (NONE on weekdays). On a
    // weekday we advance to the upcoming Shabbat to find the sidra that is
    // read this coming Monday/Thursday. inIsrael must be preserved because the
    // parsha scheme differs between Israel and chu"l.
    JewishCalendar shabbatCal = cal;
    final dow = cal.getDayOfWeek(); // 1 = Sunday … 7 = Saturday
    if (dow != 7) {
      final shabbatDate =
          cal.getGregorianCalendar().add(Duration(days: 7 - dow));
      shabbatCal = JewishCalendar.fromDateTime(shabbatDate)
        ..inIsrael = cal.inIsrael;
    }
    final p = shabbatCal.getParshah();
    if (p == Parsha.NONE) return null;
    // Combined → first single.
    const collapsed = <Parsha, Parsha>{
      Parsha.VAYAKHEL_PEKUDEI: Parsha.VAYAKHEL,
      Parsha.TAZRIA_METZORA: Parsha.TAZRIA,
      Parsha.ACHREI_MOS_KEDOSHIM: Parsha.ACHREI_MOS,
      Parsha.BEHAR_BECHUKOSAI: Parsha.BEHAR,
      Parsha.CHUKAS_BALAK: Parsha.CHUKAS,
      Parsha.MATOS_MASEI: Parsha.MATOS,
      Parsha.NITZAVIM_VAYEILECH: Parsha.NITZAVIM,
    };
    final single = collapsed[p] ?? p;
    return single.name.toLowerCase();
  }

  // ── Hallel ────────────────────────────────────────────────────────────────

  void _addHallelFlags(JewishCalendar cal, Set<String> f) {
    final tr = TefilaRules();
    if (!tr.isHallelRecited(cal)) return;
    if (tr.isHallelShalemRecited(cal)) {
      f.add(DayFlag.fullHallel);
    } else {
      f.add(DayFlag.halfHallel);
    }
    // Derived: hallel_with_musaf — Hallel said on a Musaf day.
    if (f.contains(DayFlag.musafDay)) f.add(DayFlag.hallelWithMusaf);
  }

  // ── BaHaB ────────────────────────────────────────────────────────────────
  // BaHaB (בה"ב) is a 3-day Mon/Thu/Mon penitential observance held in
  // some communities in Cheshvan (after Sukkot) and Iyar (after Pesach).
  // The standard rule: starts on the SECOND Monday of the Jewish month.
  // Subsequent days: Thursday +3, next Monday +7.
  //
  // On days where Tachanun is skipped (RC, Pesach Sheni, etc.), the
  // selichot are also skipped — the segment-level `exclude_flags:
  // ['skip_tachanun']` handles that override.
  void _addBahabFlags(JewishCalendar cal, DateTime date, Set<String> f) {
    final m = cal.getJewishMonth();
    if (m != JewishDate.CHESHVAN && m != JewishDate.IYAR) return;
    final today = cal.getJewishDayOfMonth();
    // Gregorian date of Jewish day 1 of this month.
    final day1Greg = date.subtract(Duration(days: today - 1));
    // weekday in Dart: Mon=1 ... Sun=7.
    final daysUntilFirstMon = (1 - day1Greg.weekday + 7) % 7;
    final firstMondayJDay = 1 + daysUntilFirstMon;
    final secondMondayJDay = firstMondayJDay + 7;
    final thursdayJDay = secondMondayJDay + 3;
    final thirdMondayJDay = secondMondayJDay + 7;
    if (today == secondMondayJDay) {
      f.add(DayFlag.bahabSheniKama);
      f.add(DayFlag.bahabDay);
    } else if (today == thursdayJDay) {
      f.add(DayFlag.bahabChamishi);
      f.add(DayFlag.bahabDay);
    } else if (today == thirdMondayJDay) {
      f.add(DayFlag.bahabSheniBatra);
      f.add(DayFlag.bahabDay);
    }
  }

  // ── Lulav day ────────────────────────────────────────────────────────────
  // Set when lulav is taken: any Sukkot day (incl. CHM + Hoshana Raba),
  // unless overridden by Shabbat. SA + Simchat Torah have no `sukkot` flag
  // so they are already excluded.
  void _addLulavDayFlag(Set<String> f) {
    if (!f.contains(DayFlag.sukkot)) return;
    if (f.contains(DayFlag.shabbat)) return;
    f.add(DayFlag.lulavDay);
  }

  // ── Sukkot day (1..7) ────────────────────────────────────────────────────
  // Returns the day-of-Sukkot (1 = 15 Tishrei, ..., 7 = 21 Tishrei / Hoshana
  // Raba), or null if today is outside Sukkot.
  int? _computeSukkotDay(JewishCalendar cal) {
    if (cal.getJewishMonth() != JewishDate.TISHREI) return null;
    final d = cal.getJewishDayOfMonth();
    if (d < 15 || d > 21) return null;
    return d - 14;
  }

  // Pesach day-in-chag (1..7 EY, 1..8 chu"l). Null outside 15-22 Nisan.
  int? _computePesachDay(JewishCalendar cal) {
    if (cal.getJewishMonth() != JewishDate.NISSAN) return null;
    final d = cal.getJewishDayOfMonth();
    if (d < 15 || d > 22) return null;
    return d - 14;
  }

  // Day-of-week (Dart's Mon=1..Sun=7) of YT1 of the current chag, derived
  // from today's date and how many days into the chag we are.
  int _yt1Weekday(DateTime today, int dayInChag) {
    final yt1 = today.subtract(Duration(days: dayInChag - 1));
    return yt1.weekday;
  }

  // ── 1. Day identification ─────────────────────────────────────────────────

  void _addDayIdentification(
    JewishCalendar cal,
    DateTime date,
    UserContext ctx,
    Set<String> f,
  ) {
    final yomTov = cal.getYomTovIndex();
    final m = cal.getJewishMonth();
    final d = cal.getJewishDayOfMonth();
    final dow = date.weekday; // Dart: 1=Mon…6=Sat…7=Sun

    if (dow == DateTime.saturday) f.add(DayFlag.shabbat);
    if (dow == DateTime.monday || dow == DateTime.thursday) {
      f.add(DayFlag.mondayThursday);
    }

    // Day-of-week flags — used for shir_shel_yom and other day-specific content
    switch (dow) {
      case DateTime.sunday:    f.add(DayFlag.daySunday);    break;
      case DateTime.monday:    f.add(DayFlag.dayMonday);    break;
      case DateTime.tuesday:   f.add(DayFlag.dayTuesday);   break;
      case DateTime.wednesday: f.add(DayFlag.dayWednesday); break;
      case DateTime.thursday:  f.add(DayFlag.dayThursday);  break;
      case DateTime.friday:    f.add(DayFlag.dayFriday);    break;
      case DateTime.saturday:  f.add(DayFlag.dayShabbat);   break;
    }

    // Rosh Chodesh (days 1 and 30 of applicable months)
    if (cal.isRoshChodesh()) f.add(DayFlag.roshChodesh);

    // Aseret Yemei Teshuva (1–10 Tishri)
    if (cal.isAseresYemeiTeshuva()) f.add(DayFlag.asaretYemeiTeshuva);

    // Tishri — specific days
    if (yomTov == JewishCalendar.ROSH_HASHANA) f.add(DayFlag.roshHashanah);
    if (yomTov == JewishCalendar.EREV_YOM_KIPPUR) f.add(DayFlag.erevYomKippur);
    if (yomTov == JewishCalendar.YOM_KIPPUR) f.add(DayFlag.yomKippur);
    // 11 Tishrei — the day immediately after Yom Kippur.
    if (cal.getJewishMonth() == JewishDate.TISHREI &&
        cal.getJewishDayOfMonth() == 11) {
      f.add(DayFlag.dayAfterYomKippur);
    }

    // Sukkot season
    if (yomTov == JewishCalendar.SUCCOS) {
      f.add(DayFlag.sukkot);
    }
    if (yomTov == JewishCalendar.CHOL_HAMOED_SUCCOS) {
      f.add(DayFlag.sukkot);
      f.add(DayFlag.cholHamoedSukkot);
    }
    if (yomTov == JewishCalendar.HOSHANA_RABBA) {
      f.add(DayFlag.sukkot);
      f.add(DayFlag.hoshanahRaba);
      f.add(DayFlag.cholHamoedSukkot);
    }
    if (yomTov == JewishCalendar.SHEMINI_ATZERES) {
      f.add(DayFlag.sheminiAtzeret);
      // In Israel, Shemini Atzeret and Simchat Torah are the same day
      if (ctx.isInIsrael) f.add(DayFlag.simchatTorah);
    }
    if (yomTov == JewishCalendar.SIMCHAS_TORAH) {
      f.add(DayFlag.simchatTorah);
    }

    // 11–14 Tishri — between YK and Sukkot (no explicit flag needed here;
    // handled in tachanun logic via manual month/day check)

    // Erev Rosh Hashanah (29 Elul)
    if (yomTov == JewishCalendar.EREV_ROSH_HASHANA) f.add(DayFlag.erevRoshHashanah);

    // Chanukah
    if (cal.isChanukah()) f.add(DayFlag.chanukah);

    // Tu BiShvat
    if (yomTov == JewishCalendar.TU_BESHVAT) f.add(DayFlag.tuBishvat);

    // Purim / Adar
    _addPurimFlags(cal, ctx, f, yomTov, m);

    // Pesach season
    if (yomTov == JewishCalendar.EREV_PESACH) {
      f.add(DayFlag.pesach);
      f.add(DayFlag.erevPesach);
    }
    if (yomTov == JewishCalendar.PESACH) f.add(DayFlag.pesach);
    if (cal.isCholHamoedPesach()) f.add(DayFlag.cholHamoedPesach);

    // Iyar
    if (yomTov == JewishCalendar.PESACH_SHENI) f.add(DayFlag.pesachSheni);
    if (m == JewishDate.IYAR && d == 13) f.add(DayFlag.erevPesachSheni);
    if (yomTov == JewishCalendar.LAG_BAOMER) f.add(DayFlag.lagBaomer);

    // Sivan — Shavuot
    if (yomTov == JewishCalendar.EREV_SHAVUOS) f.add(DayFlag.erevShavuot);
    if (yomTov == JewishCalendar.SHAVUOS) f.add(DayFlag.shavuot);

    // Av
    if (yomTov == JewishCalendar.TU_BEAV) f.add(DayFlag.tuBav);

    // Isru Chag (day after last Yom Tov of Pesach / Shavuot / Sukkot)
    if (_isIsruChag(cal)) f.add(DayFlag.isruChag);

    // Fast days (covers 10 Tevet, Tzom Gedaliah, Taanit Esther, 17 Tammuz, 9 Av, YK)
    if (cal.isTaanis()) f.add(DayFlag.fastDay);

    // Individual minor fasts — used to gate day-specific selichot.
    if (yomTov == JewishCalendar.TENTH_OF_TEVES) f.add(DayFlag.fast10Tevet);
    if (yomTov == JewishCalendar.FAST_OF_GEDALYAH) f.add(DayFlag.fastGedalia);
    if (yomTov == JewishCalendar.FAST_OF_ESTHER) f.add(DayFlag.fastEsther);
    if (yomTov == JewishCalendar.SEVENTEEN_OF_TAMMUZ) f.add(DayFlag.fast17Tammuz);

    // BaHaB — Mon/Thu/Mon series in Cheshvan and Iyar.
    _addBahabFlags(cal, date, f);

    // Elul flag: Elul month, excluding Erev Rosh Hashana (29 Elul)
    if (m == JewishDate.ELUL && !f.contains(DayFlag.erevRoshHashanah)) {
      f.add(DayFlag.elul);
    }

    // ladavid_season: Elul (all days) + 1–10 Tishri
    if (m == JewishDate.ELUL) f.add(DayFlag.ladavid_season);
    if (m == JewishDate.TISHREI && d <= 10) f.add(DayFlag.ladavid_season);

    // erev_shabbat: Friday
    if (date.weekday == DateTime.friday) f.add(DayFlag.erevShabbat);
  }

  void _addPurimFlags(
    JewishCalendar cal,
    UserContext ctx,
    Set<String> f,
    int yomTov,
    int m,
  ) {
    // Purim Katan / Shushan Purim Katan (leap year Adar I)
    if (yomTov == JewishCalendar.PURIM_KATAN) f.add(DayFlag.purimKatan);
    if (yomTov == JewishCalendar.SHUSHAN_PURIM_KATAN) {
      f.add(DayFlag.shushanPurimKatan);
    }

    // Erev Purim (13 Adar / 13 Adar II) = Taanit Esther day
    if (yomTov == JewishCalendar.FAST_OF_ESTHER) f.add(DayFlag.erevPurim);

    // Purim proper (14 Adar) — respects PurimDate setting
    if (yomTov == JewishCalendar.PURIM) {
      if (ctx.purimDate == PurimDate.fourteenth ||
          ctx.purimDate == PurimDate.both) {
        f.add(DayFlag.purim);
      }
    }

    // Shushan Purim (15 Adar)
    if (yomTov == JewishCalendar.SHUSHAN_PURIM) {
      f.add(DayFlag.shushanPurim);
      if (ctx.purimDate == PurimDate.fifteenth ||
          ctx.purimDate == PurimDate.both) {
        f.add(DayFlag.purim);
      }
      // On the 15th when celebrating both days, 14th was the primary reading:
      // megillah is read again without blessings (A/S), Al HaNisim omitted (EM).
      if (ctx.purimDate == PurimDate.both) {
        f.add(DayFlag.purimSecondDay);
      }
    }
  }

  bool _isIsruChag(JewishCalendar cal) {
    final m = cal.getJewishMonth();
    final d = cal.getJewishDayOfMonth();
    final inIsrael = cal.inIsrael;
    if (m == JewishDate.TISHREI && d == (inIsrael ? 23 : 24)) return true;
    if (m == JewishDate.NISSAN && d == (inIsrael ? 22 : 23)) return true;
    if (m == JewishDate.SIVAN && d == (inIsrael ? 7 : 8)) return true;
    return false;
  }

  // ── 2. Season / precipitation flags ──────────────────────────────────────

  void _addSeasonFlags(
    JewishCalendar cal,
    DateTime date,
    UserContext ctx,
    Set<String> f,
  ) {
    final m = cal.getJewishMonth();
    final d = cal.getJewishDayOfMonth();

    // mashiv_haruach: 22 Tishrei (Shemini Atzeret) through 14 Nisan (Erev Pesach)
    if (_isMashivHaruachPeriod(m, d)) f.add(DayFlag.mashivHaruach);

    // tal_umatar: Israel from 7 Cheshvan; Diaspora from Dec 4/5; both through 14 Nisan
    if (_isTalUmatarPeriod(m, d, date, ctx.isInIsrael)) f.add(DayFlag.talUmatar);

    // tisha_beav
    if (cal.getYomTovIndex() == JewishCalendar.TISHA_BEAV) f.add(DayFlag.tishaBaav);
  }

  bool _isMashivHaruachPeriod(int m, int d) {
    if (m == JewishDate.TISHREI && d >= 22) return true;
    if (m >= JewishDate.CHESHVAN) return true;
    if (m == JewishDate.NISSAN && d <= 14) return true;
    return false;
  }

  bool _isTalUmatarPeriod(int m, int d, DateTime date, bool inIsrael) {
    // Summer months: no tal u'matar
    if (m >= JewishDate.IYAR && m < JewishDate.TISHREI) return false;
    if (m == JewishDate.TISHREI && d < 22) return false;
    // Ends before 15 Nisan
    if (m == JewishDate.NISSAN && d >= 15) return false;

    if (inIsrael) {
      if (m == JewishDate.CHESHVAN && d < 7) return false;
      return true;
    }

    // Diaspora: starts December 4 or 5
    if (date.month == 12) return date.day >= _diasporaTalUmatarStartDay(date.year);
    if (date.month <= 5) return true; // Jan–May: past December start
    return false; // Oct–Nov: before December start
  }

  int _diasporaTalUmatarStartDay(int year) {
    final nextYear = year + 1;
    final nextIsLeap =
        (nextYear % 4 == 0 && nextYear % 100 != 0) || nextYear % 400 == 0;
    return nextIsLeap ? 5 : 4;
  }

  // ── 3. Tachanun ───────────────────────────────────────────────────────────

  void _addTachanunFlags(JewishCalendar cal, Set<String> f) {
    final m = cal.getJewishMonth();
    final d = cal.getJewishDayOfMonth();

    bool skipAll = false;
    bool skipMinchaOnly = false;

    // Whole Nisan (1–30)
    if (m == JewishDate.NISSAN) skipAll = true;

    // Standard skip-tachanun days — all identified via their flags
    if (f.contains(DayFlag.chanukah)) skipAll = true;
    if (f.contains(DayFlag.roshChodesh)) skipAll = true;
    if (f.contains(DayFlag.purim) ||
        f.contains(DayFlag.shushanPurim) ||
        f.contains(DayFlag.erevPurim) ||
        f.contains(DayFlag.purimKatan) ||
        f.contains(DayFlag.shushanPurimKatan)) {
      skipAll = true;
    }
    if (f.contains(DayFlag.pesachSheni)) skipAll = true;
    if (f.contains(DayFlag.tuBishvat) ||
        f.contains(DayFlag.lagBaomer) ||
        f.contains(DayFlag.tuBav)) {
      skipAll = true;
    }
    if (f.contains(DayFlag.roshHashanah) ||
        f.contains(DayFlag.yomKippur) ||
        f.contains(DayFlag.erevYomKippur) ||
        f.contains(DayFlag.sukkot) ||
        f.contains(DayFlag.cholHamoedSukkot) ||
        f.contains(DayFlag.hoshanahRaba) ||
        f.contains(DayFlag.sheminiAtzeret) ||
        f.contains(DayFlag.simchatTorah) ||
        f.contains(DayFlag.pesach) ||
        f.contains(DayFlag.cholHamoedPesach) ||
        f.contains(DayFlag.shavuot) ||
        f.contains(DayFlag.isruChag)) {
      skipAll = true;
    }

    // 11–14 Tishri (between Yom Kippur and Sukkot)
    if (m == JewishDate.TISHREI && d >= 11 && d <= 14) skipAll = true;

    // 1–12 Sivan: no tachanun (preparation for Shavuot through 12 Sivan,
    // the tashlumin period; Shulchan Aruch O.C. 131:7, Rema).
    // RC Sivan (1 Sivan), Erev Shavuot (5 Sivan), Shavuot (6 Sivan) and
    // Isru Chag (7 Sivan) are already caught above — this catches 2–4
    // and 8–12 Sivan.
    if (m == JewishDate.SIVAN && d >= 1 && d <= 12) skipAll = true;

    // Erev Shavuot (5 Sivan) — Mincha only (subsumed by the Sivan rule
    // above, kept for clarity in case the Sivan window is ever narrowed).
    if (f.contains(DayFlag.erevShavuot)) skipMinchaOnly = true;

    // EXPLICIT EXCEPTIONS — no skip flag set:
    //   29 Elul (Erev Rosh Hashanah) — Mincha HAS tachanun
    //   13 Iyar (Erev Pesach Sheni)  — Mincha HAS tachanun
    // (simply do not set skipMinchaOnly for these)

    if (skipAll) f.add(DayFlag.skipTachanun);
    if (!skipAll && skipMinchaOnly) f.add(DayFlag.skipTachanunMincha);
  }

  // ── 3. Lamenatzeach ───────────────────────────────────────────────────────

  void _addLamenatzeachFlag(UserContext ctx, Set<String> f) {
    // All nusachim: skip Lamenatzeach on any day that skips Tachanun.
    // (Edot HaMizrach explicitly mirrors Tachanun; Ashkenaz/Sfard effectively the same.)
    if (f.contains(DayFlag.skipTachanun)) f.add(DayFlag.skipLamenatzeach);
  }

  // ── 4. Aseret Yemei Teshuva text additions ────────────────────────────────

  void _addAsaretYemeiTeshuva(JewishCalendar cal, Set<String> f) {
    if (!f.contains(DayFlag.asaretYemeiTeshuva)) return;
    f.add(DayFlag.hamelech_hakadosh);
    f.add(DayFlag.hamelech_hamishpat);
    f.add(DayFlag.zochrenu);
    f.add(DayFlag.miChamochaAyt);
    f.add(DayFlag.uchtov);
    f.add(DayFlag.bseferChaim);
  }

  // ── 5. Avinu Malkeinu ─────────────────────────────────────────────────────

  void _addAvinoMalkeinu(Set<String> f) {
    final isAyt = f.contains(DayFlag.asaretYemeiTeshuva);
    final isFast = f.contains(DayFlag.fastDay);
    final isShabbat = f.contains(DayFlag.shabbat);
    final isYomKippur = f.contains(DayFlag.yomKippur);
    final isTishaBaav = f.contains(DayFlag.tishaBaav);

    // Tisha B'Av: NOT said, even though it's a fast day (Halachic exception).
    if ((isAyt || isFast) && !isShabbat && !isTishaBaav) {
      f.add(DayFlag.avinoMalkeinu);
    }
    // Yom Kippur: always said, even on Shabbat
    if (isYomKippur) f.add(DayFlag.avinoMalkeinu);
  }

  // ── 6. Ya'aleh Ve'yavo ────────────────────────────────────────────────────

  void _addYaalehVeyavo(Set<String> f) {
    const yyvDays = {
      DayFlag.roshChodesh,
      DayFlag.roshHashanah,
      DayFlag.pesach,
      DayFlag.cholHamoedPesach,
      DayFlag.shavuot,
      DayFlag.sukkot,
      DayFlag.cholHamoedSukkot,
      DayFlag.hoshanahRaba,
      DayFlag.sheminiAtzeret,
      DayFlag.simchatTorah,
    };
    if (f.any(yyvDays.contains)) f.add(DayFlag.yaalehVeyavo);
  }

  // ── 7. Al HaNisim ─────────────────────────────────────────────────────────

  void _addAlHaNisim(Set<String> f) {
    if (f.contains(DayFlag.chanukah) || f.contains(DayFlag.purim)) {
      // EM does not say Al HaNisim on the second day of Purim (15 Adar,
      // when the user celebrates both days — 14th was the primary day).
      if (f.contains(DayFlag.purimSecondDay) &&
          f.contains(DayFlag.nusachEdotMizrach)) return;
      f.add(DayFlag.alHaNisim);
    }
  }

  // ── 8. Mizmor LeTodah ─────────────────────────────────────────────────────

  void _addMizmorLetodahFlag(UserContext ctx, Set<String> f) {
    if (ctx.nusach == 'edot_mizrach') return;
    if (f.contains(DayFlag.erevPesach) ||
        f.contains(DayFlag.cholHamoedPesach) ||
        f.contains(DayFlag.erevYomKippur)) {
      f.add(DayFlag.skipMizmorLetodah);
    }
  }

  // ── 9. Tefillin on Chol HaMoed ────────────────────────────────────────────

  void _addTefillinFlag(UserContext ctx, Set<String> f) {
    final isCholHaMoed = f.contains(DayFlag.cholHamoedPesach) ||
        f.contains(DayFlag.cholHamoedSukkot);
    if (!isCholHaMoed) return;
    if (ctx.isInIsrael) {
      f.add(DayFlag.skipTefillin);
    } else {
      f.add(DayFlag.tefillinOptionalAccordion);
    }
  }

  // ── 10. Shema at Hotzaat HaTorah ─────────────────────────────────────────

  void _addShemaHotzaahFlag(Set<String> f) {
    // Shema + proclamations are said during hotzaat sefer Torah only on
    // Shabbat, Yom Tov (all days), and Hoshana Raba — not on weekdays,
    // Rosh Chodesh, or Chol HaMoed.
    final isYomTovLevel =
        f.contains(DayFlag.shabbat) ||
        f.contains(DayFlag.roshHashanah) ||
        f.contains(DayFlag.yomKippur) ||
        f.contains(DayFlag.hoshanahRaba) ||
        f.contains(DayFlag.sheminiAtzeret) ||
        f.contains(DayFlag.simchatTorah) ||
        f.contains(DayFlag.shavuot) ||
        (f.contains(DayFlag.pesach) &&
            !f.contains(DayFlag.cholHamoedPesach) &&
            !f.contains(DayFlag.erevPesach)) ||
        (f.contains(DayFlag.sukkot) && !f.contains(DayFlag.cholHamoedSukkot));
    if (isYomTovLevel) f.add(DayFlag.shemaHotzaah);
  }

  // ── 10b. Kriat HaTorah ────────────────────────────────────────────────────

  void _addKriatHatorahFlag(Set<String> f) {
    // Torah is read on: Monday/Thursday, Rosh Chodesh, public fast days
    // (Tisha B'Av at Mincha too, but that's the fast_day flag), Chanukah,
    // Purim, Chol HaMoed Pesach/Sukkot, Yom Tov, Shabbat.
    final hasKriah = f.contains(DayFlag.mondayThursday) ||
        f.contains(DayFlag.roshChodesh) ||
        f.contains(DayFlag.fastDay) ||
        f.contains(DayFlag.chanukah) ||
        f.contains(DayFlag.purim) ||
        f.contains(DayFlag.shushanPurim) ||
        f.contains(DayFlag.cholHamoedPesach) ||
        f.contains(DayFlag.cholHamoedSukkot) ||
        f.contains(DayFlag.shabbat) ||
        f.contains(DayFlag.roshHashanah) ||
        f.contains(DayFlag.yomKippur) ||
        f.contains(DayFlag.pesach) ||
        f.contains(DayFlag.shavuot) ||
        f.contains(DayFlag.sukkot) ||
        f.contains(DayFlag.sheminiAtzeret) ||
        f.contains(DayFlag.simchatTorah) ||
        f.contains(DayFlag.hoshanahRaba);
    if (hasKriah) f.add(DayFlag.kriatHatorah);
  }

  // ── 10c. Musaf day ────────────────────────────────────────────────────────

  void _addMusafDayFlag(Set<String> f) {
    // Musaf is recited on: Rosh Chodesh, Chol HaMoed Pesach/Sukkot, Yom Tov,
    // Shabbat. (Hoshana Raba is Chol HaMoed Sukkot — already covered.)
    final hasMusaf = f.contains(DayFlag.roshChodesh) ||
        f.contains(DayFlag.cholHamoedPesach) ||
        f.contains(DayFlag.cholHamoedSukkot) ||
        f.contains(DayFlag.shabbat) ||
        f.contains(DayFlag.roshHashanah) ||
        f.contains(DayFlag.yomKippur) ||
        f.contains(DayFlag.pesach) ||
        f.contains(DayFlag.shavuot) ||
        f.contains(DayFlag.sukkot) ||
        f.contains(DayFlag.sheminiAtzeret) ||
        f.contains(DayFlag.simchatTorah);
    if (hasMusaf) f.add(DayFlag.musafDay);
    // Musaf days for which the app currently has content (RC + CHM). Yom Tov
    // and Shabbat are deliberately excluded for now.
    final hasMusafContent = f.contains(DayFlag.roshChodesh) ||
        f.contains(DayFlag.cholHamoedPesach) ||
        f.contains(DayFlag.cholHamoedSukkot);
    if (hasMusafContent) f.add(DayFlag.musafContent);
  }

  // ── 11a. Leap-year ולכפרת פשע (Rosh Chodesh Musaf) ──────────────────────────

  void _addLeapKeferatPashay(JewishCalendar cal, Set<String> f) {
    if (!cal.isJewishLeapYear()) return;
    // Months in which ולכפרת פשע is said in a leap year:
    // Cheshvan (8) through Nisan (1): months 8,9,10,11,12,13 + 1.
    final m = cal.getJewishMonth();
    final leapMonths = {
      JewishDate.CHESHVAN, JewishDate.KISLEV, JewishDate.TEVES,
      JewishDate.SHEVAT, JewishDate.ADAR, JewishDate.ADAR_II,
      JewishDate.NISSAN,
    };
    if (leapMonths.contains(m)) f.add(DayFlag.leapKeferatPashay);
  }

  // ── 11. Gender + Israel flags ─────────────────────────────────────────────

  void _addGenderAndIsrael(UserContext ctx, Set<String> f) {
    f.add(ctx.gender == Gender.male ? DayFlag.genderMale : DayFlag.genderFemale);
    f.add(ctx.isInIsrael ? DayFlag.inIsrael : DayFlag.notInIsrael);
  }
}
