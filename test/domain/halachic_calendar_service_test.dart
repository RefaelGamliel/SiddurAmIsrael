import 'package:flutter_test/flutter_test.dart';
import 'package:siddur_am_israel_chai/core/calendar/hebrew_date.dart';
import 'package:siddur_am_israel_chai/domain/entities/day_flags.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/domain/services/halachic_calendar_service.dart';

// ── Verified Gregorian↔Hebrew date anchors (year 5785) ────────────────────
// Oct  2 2024 (Wed) = 29 Elul  5784  — Erev Rosh Hashanah
// Oct  3 2024 (Thu) =  1 Tishri 5785 — Rosh Hashanah
// Oct  5 2024 (Sat) =  3 Tishri 5785 — AYT weekday on Shabbat
// Oct 12 2024 (Sat) = 10 Tishri 5785 — Yom Kippur (Shabbat)
// Dec 25 2024 (Wed) = 24 Kislev 5785 — Day before Chanukah
// Dec 26 2024 (Thu) = 25 Kislev 5785 — Chanukah day 1
// Dec 31 2024 (Tue) =  1 Tevet  5785 — Rosh Chodesh + Chanukah day 7
// Jan 29 2025 (Wed) = 29 Tevet  5785 — Day before Rosh Chodesh Shvat
// Jan 30 2025 (Thu) =  1 Shvat  5785 — Rosh Chodesh (standalone)
// Feb 13 2025 (Thu) = 15 Shvat  5785 — Tu BiShvat
// Mar  5 2025 (Wed) =  6 Adar   5785 — Regular weekday (mid-Adar)
// Mar 13 2025 (Thu) = 13 Adar   5785 — Erev Purim / Taanit Esther
// Mar 14 2025 (Fri) = 14 Adar   5785 — Purim
// Mar 15 2025 (Sat) = 15 Adar   5785 — Shushan Purim
// Apr 12 2025 (Sat) = 14 Nisan  5785 — Erev Pesach (Shabbat)
// Apr 13 2025 (Sun) = 15 Nisan  5785 — Pesach day 1
// Apr 14 2025 (Mon) = 16 Nisan  5785 — Chol HaMoed Pesach (Israel) / Yom Tov day 2 (Diaspora)
// Apr 15 2025 (Tue) = 17 Nisan  5785 — Chol HaMoed Pesach (Diaspora)
// May 10 2025 (Sat) = 12 Iyar   5785 — Shabbat before Erev Pesach Sheni
// May 11 2025 (Sun) = 13 Iyar   5785 — Erev Pesach Sheni
// May 12 2025 (Mon) = 14 Iyar   5785 — Pesach Sheni
// Jun  1 2025 (Sun) =  5 Sivan  5785 — Erev Shavuot
// Jul 13 2025 (Sun) = 18 Tammuz 5785 — 17 Tammuz fast (pushed from Shabbat)

void main() {
  // ── HebrewDate unit tests ─────────────────────────────────────────────────
  group('HebrewDate', () {
    group('Gregorian → Hebrew conversions', () {
      test('25 Kislev 5785 (Chanukah, Thursday)', () {
        final hd = HebrewDate.fromGregorian(DateTime(2024, 12, 26));
        expect(hd.year, 5785);
        expect(hd.month, HebrewDate.kislev);
        expect(hd.day, 25);
        expect(hd.dayOfWeek, DateTime.thursday);
      });

      test('1 Tishri 5785 (Rosh Hashanah, Thursday)', () {
        final hd = HebrewDate.fromGregorian(DateTime(2024, 10, 3));
        expect(hd.year, 5785);
        expect(hd.month, HebrewDate.tishri);
        expect(hd.day, 1);
        expect(hd.dayOfWeek, DateTime.thursday);
      });

      test('10 Tishri 5785 (Yom Kippur, Saturday)', () {
        final hd = HebrewDate.fromGregorian(DateTime(2024, 10, 12));
        expect(hd.year, 5785);
        expect(hd.month, HebrewDate.tishri);
        expect(hd.day, 10);
        expect(hd.dayOfWeek, DateTime.saturday);
      });

      test('29 Elul 5784 (Erev Rosh Hashanah, Wednesday)', () {
        final hd = HebrewDate.fromGregorian(DateTime(2024, 10, 2));
        expect(hd.year, 5784);
        expect(hd.month, HebrewDate.elul);
        expect(hd.day, 29);
        expect(hd.dayOfWeek, DateTime.wednesday);
      });
    });

    group('isShabbat', () {
      test('Saturday returns true', () {
        final hd = HebrewDate.fromGregorian(DateTime(2024, 10, 12));
        expect(hd.isShabbat, isTrue);
      });

      test('Thursday returns false', () {
        final hd = HebrewDate.fromGregorian(DateTime(2024, 10, 3));
        expect(hd.isShabbat, isFalse);
      });
    });

    group('isLeapYear', () {
      test('5784 is a leap year', () => expect(HebrewDate.isLeapYear(5784), isTrue));
      test('5785 is not a leap year', () => expect(HebrewDate.isLeapYear(5785), isFalse));
      test('5782 is a leap year', () => expect(HebrewDate.isLeapYear(5782), isTrue));
      test('5783 is not a leap year', () => expect(HebrewDate.isLeapYear(5783), isFalse));
    });

    group('daysInMonth', () {
      test('Nisan always has 30 days', () {
        expect(HebrewDate.daysInMonth(HebrewDate.nisan, 5785), 30);
      });
      test('Iyar always has 29 days', () {
        expect(HebrewDate.daysInMonth(HebrewDate.iyar, 5785), 29);
      });
      test('Adar in non-leap year has 29 days', () {
        expect(HebrewDate.daysInMonth(HebrewDate.adar, 5785), 29);
      });
      test('Adar I in leap year has 30 days', () {
        expect(HebrewDate.daysInMonth(HebrewDate.adarI, 5784), 30);
      });
      test('Adar II always has 29 days', () {
        expect(HebrewDate.daysInMonth(HebrewDate.adarII, 5784), 29);
      });
    });
  });

  // ── HalachicCalendarService ────────────────────────────────────────────────
  group('HalachicCalendarService', () {
    const service = HalachicCalendarService();
    const ctx = UserContext(nusach: 'sfard', isInIsrael: true);
    const edotCtx = UserContext(nusach: 'edot_mizrach', isInIsrael: true);
    const femaleCtx = UserContext(
      nusach: 'sfard',
      isInIsrael: false,
      gender: Gender.female,
    );

    // ── Kriat HaTorah (Mon/Thu upcoming parashah) ────────────────────────────
    group('kriat hatorah mon/thu', () {
      test('regular Monday emits kriat_hatorah_mon_thu + upcoming parashah', () {
        // Mon 4 Nov 2024 (~3 Cheshvan 5785) — a plain weekday. The reading is
        // the start of the upcoming Shabbat's sidra (Lech Lecha, 9 Nov).
        final f = service.flagsFor(DateTime(2024, 11, 4), ctx);
        expect(f.flags, contains(DayFlag.kriatHatorahMonThu));
        expect(f.upcomingParshah, isNotNull);
        expect(f.upcomingParshah, 'lech_lecha');
      });

      test('regular Sunday has no Mon/Thu reading', () {
        final f = service.flagsFor(DateTime(2024, 11, 3), ctx);
        expect(f.flags, isNot(contains(DayFlag.kriatHatorahMonThu)));
      });
    });

    // ── Day identification ───────────────────────────────────────────────────
    group('day identification', () {
      test('1 Tishri → rosh_hashanah', () {
        final f = service.flagsFor(DateTime(2024, 10, 3), ctx);
        expect(f.flags, contains(DayFlag.roshHashanah));
      });

      test('25 Kislev → chanukah', () {
        final f = service.flagsFor(DateTime(2024, 12, 26), ctx);
        expect(f.flags, contains(DayFlag.chanukah));
      });

      test('1 Tevet (Rosh Chodesh) during Chanukah → both flags', () {
        final f = service.flagsFor(DateTime(2024, 12, 31), ctx);
        expect(f.flags, contains(DayFlag.roshChodesh));
        expect(f.flags, contains(DayFlag.chanukah));
      });

      test('1 Shvat → rosh_chodesh', () {
        final f = service.flagsFor(DateTime(2025, 1, 30), ctx);
        expect(f.flags, contains(DayFlag.roshChodesh));
      });

      test('29 Elul → erev_rosh_hashanah', () {
        final f = service.flagsFor(DateTime(2024, 10, 2), ctx);
        expect(f.flags, contains(DayFlag.erevRoshHashanah));
      });

      test('13 Iyar → erev_pesach_sheni', () {
        final f = service.flagsFor(DateTime(2025, 5, 11), ctx);
        expect(f.flags, contains(DayFlag.erevPesachSheni));
      });

      test('14 Iyar → pesach_sheni', () {
        final f = service.flagsFor(DateTime(2025, 5, 12), ctx);
        expect(f.flags, contains(DayFlag.pesachSheni));
      });

      test('Thursday → monday_thursday', () {
        final f = service.flagsFor(DateTime(2024, 10, 3), ctx);
        expect(f.flags, contains(DayFlag.mondayThursday));
      });

      test('Wednesday (24 Kislev) → no monday_thursday', () {
        final f = service.flagsFor(DateTime(2024, 12, 25), ctx);
        expect(f.flags, isNot(contains(DayFlag.mondayThursday)));
      });

      test('15 Tammuz fast pushed to 18 Tammuz (Sunday) when 17 is Shabbat', () {
        // 17 Tammuz 5785 = July 12 (Sat) → fast pushed to July 13 (Sun, 18 Tammuz)
        final sat17 = service.flagsFor(DateTime(2025, 7, 12), ctx);
        final sun18 = service.flagsFor(DateTime(2025, 7, 13), ctx);
        expect(sat17.flags, isNot(contains(DayFlag.fastDay)));
        expect(sun18.flags, contains(DayFlag.fastDay));
      });
    });

    // ── Tachanun ─────────────────────────────────────────────────────────────
    group('tachanun', () {
      test('Rosh Hashanah → skip_tachanun', () {
        final f = service.flagsFor(DateTime(2024, 10, 3), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('Yom Kippur → skip_tachanun', () {
        final f = service.flagsFor(DateTime(2024, 10, 12), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('11–14 Tishri (between YK and Sukkot) → skip_tachanun', () {
        // Oct 14, 2024 = 12 Tishri 5785
        final f = service.flagsFor(DateTime(2024, 10, 14), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('Chanukah → skip_tachanun', () {
        final f = service.flagsFor(DateTime(2024, 12, 26), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('Rosh Chodesh → skip_tachanun', () {
        final f = service.flagsFor(DateTime(2025, 1, 30), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('Tu BiShvat → skip_tachanun', () {
        final f = service.flagsFor(DateTime(2025, 2, 13), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('Pesach Sheni (14 Iyar) → skip_tachanun', () {
        final f = service.flagsFor(DateTime(2025, 5, 12), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('Erev Shavuot (5 Sivan) → skip_tachanun (subsumed by 1–12 Sivan rule)', () {
        // Jun 1, 2025 = 5 Sivan 5785. Inside the 1–12 Sivan no-tachanun
        // window per Shulchan Aruch O.C. 131:7 — full skip, not Mincha-only.
        final f = service.flagsFor(DateTime(2025, 6, 1), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('2–4 Sivan → skip_tachanun (1–12 Sivan rule)', () {
        // May 29, 2025 = 2 Sivan 5785.
        final f = service.flagsFor(DateTime(2025, 5, 29), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('8–12 Sivan (tashlumin days after Shavuot) → skip_tachanun', () {
        // May 26, 2026 = 9 Sivan 5786. Inside the 8–12 Sivan tashlumin
        // window (after Shavuot) — no tachanun.
        final f = service.flagsFor(DateTime(2026, 5, 26), ctx);
        expect(f.skipTachanun, isTrue);
      });

      test('13 Sivan → tachanun resumes (outside the 1–12 window)', () {
        // Jun 9, 2025 = 13 Sivan 5785. Tachanun should NOT be skipped.
        final f = service.flagsFor(DateTime(2025, 6, 9), ctx);
        expect(f.skipTachanun, isFalse);
        expect(f.skipTachanunMincha, isFalse);
      });

      test('29 Elul → NO skip flags (Mincha HAS tachanun, explicit exception)', () {
        final f = service.flagsFor(DateTime(2024, 10, 2), ctx);
        expect(f.skipTachanun, isFalse);
        expect(f.skipTachanunMincha, isFalse);
      });

      test('13 Iyar → NO skip flags (Mincha HAS tachanun, explicit exception)', () {
        final f = service.flagsFor(DateTime(2025, 5, 11), ctx);
        expect(f.skipTachanun, isFalse);
        expect(f.skipTachanunMincha, isFalse);
      });

      test('Regular weekday → no skip flags', () {
        // Mar 5, 2025 = 6 Adar 5785 (Wednesday, mid-Adar)
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.skipTachanun, isFalse);
        expect(f.skipTachanunMincha, isFalse);
      });

      test('Fast day (17 Tammuz pushed) → tachanun IS said (no skip)', () {
        final f = service.flagsFor(DateTime(2025, 7, 13), ctx);
        expect(f.skipTachanun, isFalse);
        expect(f.skipTachanunMincha, isFalse);
      });
    });

    // ── Lamenatzeach ─────────────────────────────────────────────────────────
    group('lamenatzeach', () {
      test('Edot HaMizrach: Chanukah → skip_lamenatzeach', () {
        final f = service.flagsFor(DateTime(2024, 12, 26), edotCtx);
        expect(f.skipLamenatzeach, isTrue);
      });

      test('Edot HaMizrach: regular weekday → no skip_lamenatzeach', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), edotCtx);
        expect(f.skipLamenatzeach, isFalse);
      });

      test('Sfard: Chanukah → skip_lamenatzeach (same as tachanun)', () {
        final f = service.flagsFor(DateTime(2024, 12, 26), ctx);
        expect(f.skipLamenatzeach, isTrue);
      });

      test('Regular weekday: no skip_lamenatzeach', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.skipLamenatzeach, isFalse);
      });
    });

    // ── Aseret Yemei Teshuva ─────────────────────────────────────────────────
    group('aseret yemei teshuva', () {
      test('Rosh Hashanah → asaret_yemei_teshuva + all text-change flags', () {
        final f = service.flagsFor(DateTime(2024, 10, 3), ctx);
        expect(f.isAsaretYemeiTeshuva, isTrue);
        expect(f.flags, contains(DayFlag.hamelech_hakadosh));
        expect(f.flags, contains(DayFlag.hamelech_hamishpat));
        expect(f.flags, contains(DayFlag.zochrenu));
        expect(f.flags, contains(DayFlag.miChamochaAyt));
        expect(f.flags, contains(DayFlag.uchtov));
        expect(f.flags, contains(DayFlag.bseferChaim));
      });

      test('3 Tishri (AYT weekday) → asaret_yemei_teshuva', () {
        final f = service.flagsFor(DateTime(2024, 10, 5), ctx);
        expect(f.isAsaretYemeiTeshuva, isTrue);
      });

      test('Regular day → no AYT flags', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.isAsaretYemeiTeshuva, isFalse);
        expect(f.flags, isNot(contains(DayFlag.hamelech_hakadosh)));
      });
    });

    // ── Avinu Malkeinu ───────────────────────────────────────────────────────
    group('avinu malkeinu', () {
      test('AYT on weekday (Rosh Hashanah) → avinu_malkeinu', () {
        final f = service.flagsFor(DateTime(2024, 10, 3), ctx);
        expect(f.sayAvinu, isTrue);
      });

      test('AYT on Shabbat (3 Tishri) → NO avinu_malkeinu', () {
        final f = service.flagsFor(DateTime(2024, 10, 5), ctx);
        expect(f.sayAvinu, isFalse);
      });

      test('Yom Kippur on Shabbat → avinu_malkeinu (YK always said)', () {
        // Oct 12, 2024 = 10 Tishri 5785 (Saturday)
        final f = service.flagsFor(DateTime(2024, 10, 12), ctx);
        expect(f.sayAvinu, isTrue);
      });

      test('Fast day on weekday → avinu_malkeinu', () {
        // Jul 13, 2025 = 18 Tammuz 5785 (Sunday, pushed fast day)
        final f = service.flagsFor(DateTime(2025, 7, 13), ctx);
        expect(f.sayAvinu, isTrue);
      });

      test('Regular weekday → no avinu_malkeinu', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.sayAvinu, isFalse);
      });
    });

    // ── Ya'aleh Ve'yavo ──────────────────────────────────────────────────────
    group("ya'aleh veyavo", () {
      test('Rosh Hashanah → yaaleh_veyavo', () {
        final f = service.flagsFor(DateTime(2024, 10, 3), ctx);
        expect(f.sayYaalehVeyavo, isTrue);
      });

      test('Rosh Chodesh + Chanukah → yaaleh_veyavo', () {
        final f = service.flagsFor(DateTime(2024, 12, 31), ctx);
        expect(f.sayYaalehVeyavo, isTrue);
      });

      test('Standalone Rosh Chodesh → yaaleh_veyavo', () {
        final f = service.flagsFor(DateTime(2025, 1, 30), ctx);
        expect(f.sayYaalehVeyavo, isTrue);
      });

      test('Pesach → yaaleh_veyavo', () {
        final f = service.flagsFor(DateTime(2025, 4, 12), ctx);
        expect(f.sayYaalehVeyavo, isTrue);
      });

      test('Regular weekday → no yaaleh_veyavo', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.sayYaalehVeyavo, isFalse);
      });
    });

    // ── Al HaNisim ───────────────────────────────────────────────────────────
    group('al hanisim', () {
      test('Chanukah → al_hanisim', () {
        final f = service.flagsFor(DateTime(2024, 12, 26), ctx);
        expect(f.sayAlHaNisim, isTrue);
      });

      test('Purim (14 Adar, fourteenth observer) → al_hanisim', () {
        final f = service.flagsFor(DateTime(2025, 3, 14), ctx);
        expect(f.sayAlHaNisim, isTrue);
      });

      test('Regular weekday → no al_hanisim', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.sayAlHaNisim, isFalse);
      });

      test('Fast day → no al_hanisim', () {
        final f = service.flagsFor(DateTime(2025, 7, 13), ctx);
        expect(f.sayAlHaNisim, isFalse);
      });
    });

    // ── Purim date settings ──────────────────────────────────────────────────
    group('purim date', () {
      test('fourteenth observer: purim on 14 Adar, not 15', () {
        const ctx14 = UserContext(
          nusach: 'sfard',
          isInIsrael: true,
          purimDate: PurimDate.fourteenth,
        );
        expect(
          service.flagsFor(DateTime(2025, 3, 14), ctx14).flags,
          contains(DayFlag.purim),
        );
        expect(
          service.flagsFor(DateTime(2025, 3, 15), ctx14).flags,
          isNot(contains(DayFlag.purim)),
        );
      });

      test('fifteenth observer: no purim on 14 Adar, shushan_purim on 15', () {
        const ctx15 = UserContext(
          nusach: 'sfard',
          isInIsrael: true,
          purimDate: PurimDate.fifteenth,
        );
        expect(
          service.flagsFor(DateTime(2025, 3, 14), ctx15).flags,
          isNot(contains(DayFlag.purim)),
        );
        final flags15 = service.flagsFor(DateTime(2025, 3, 15), ctx15);
        expect(flags15.flags, contains(DayFlag.shushanPurim));
        expect(flags15.flags, contains(DayFlag.purim));
      });

      test('both observer: purim on 14 AND shushan_purim on 15', () {
        const ctxBoth = UserContext(
          nusach: 'sfard',
          isInIsrael: true,
          purimDate: PurimDate.both,
        );
        expect(
          service.flagsFor(DateTime(2025, 3, 14), ctxBoth).flags,
          contains(DayFlag.purim),
        );
        expect(
          service.flagsFor(DateTime(2025, 3, 15), ctxBoth).flags,
          contains(DayFlag.shushanPurim),
        );
      });

      test('Erev Purim (13 Adar) → erev_purim + fast_day + skip_tachanun', () {
        // Taanit Esther is the 13th, but erev_purim triggers skip_tachanun
        final f = service.flagsFor(DateTime(2025, 3, 13), ctx);
        expect(f.flags, contains(DayFlag.erevPurim));
        expect(f.flags, contains(DayFlag.fastDay));
        expect(f.skipTachanun, isTrue);
      });
    });

    // ── Gender + Israel flags ────────────────────────────────────────────────
    group('gender and israel', () {
      test('male + Israel → gender_male and in_israel', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.flags, contains(DayFlag.genderMale));
        expect(f.flags, contains(DayFlag.inIsrael));
        expect(f.flags, isNot(contains(DayFlag.genderFemale)));
        expect(f.flags, isNot(contains(DayFlag.notInIsrael)));
      });

      test('female + diaspora → gender_female and not_in_israel', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), femaleCtx);
        expect(f.flags, contains(DayFlag.genderFemale));
        expect(f.flags, contains(DayFlag.notInIsrael));
        expect(f.flags, isNot(contains(DayFlag.genderMale)));
        expect(f.flags, isNot(contains(DayFlag.inIsrael)));
      });
    });

    // ── Mizmor LeTodah ───────────────────────────────────────────────────────
    group('mizmor letodah', () {
      test('Erev Pesach, Sfard → skip_mizmor_letodah', () {
        // Apr 12, 2025 = 14 Nisan 5785 (Erev Pesach, Shabbat)
        final f = service.flagsFor(DateTime(2025, 4, 12), ctx);
        expect(f.flags, contains(DayFlag.erevPesach));
        expect(f.flags, contains(DayFlag.skipMizmorLetodah));
      });

      test('Erev Pesach, Edot Mizrach → NO skip_mizmor_letodah', () {
        // Apr 12, 2025 = 14 Nisan 5785 (Erev Pesach, Shabbat)
        final f = service.flagsFor(DateTime(2025, 4, 12), edotCtx);
        expect(f.flags, contains(DayFlag.erevPesach));
        expect(f.flags, isNot(contains(DayFlag.skipMizmorLetodah)));
      });

      test('Erev Yom Kippur, Sfard → skip_mizmor_letodah', () {
        // Oct 11, 2024 = 9 Tishri 5785 (Erev Yom Kippur, Friday)
        final f = service.flagsFor(DateTime(2024, 10, 11), ctx);
        expect(f.flags, contains(DayFlag.erevYomKippur));
        expect(f.flags, contains(DayFlag.skipMizmorLetodah));
      });

      test('Chol HaMoed Pesach, Sfard → skip_mizmor_letodah', () {
        // Apr 14, 2025 = 17 Nisan 5785 (Chol HaMoed Pesach, Monday)
        final f = service.flagsFor(DateTime(2025, 4, 14), ctx);
        expect(f.flags, contains(DayFlag.cholHamoedPesach));
        expect(f.flags, contains(DayFlag.skipMizmorLetodah));
      });
    });

    // ── Tefillin on Chol HaMoed ──────────────────────────────────────────────
    group('tefillin chol hamoed', () {
      test('Chol HaMoed Pesach in Israel → skip_tefillin', () {
        final f = service.flagsFor(DateTime(2025, 4, 14), ctx);
        expect(f.flags, contains(DayFlag.skipTefillin));
        expect(f.flags, isNot(contains(DayFlag.tefillinOptionalAccordion)));
      });

      test('Chol HaMoed Pesach in Diaspora → tefillin_optional_accordion', () {
        // Apr 15, 2025 = 17 Nisan (Chol HaMoed day 1 in Diaspora)
        final f = service.flagsFor(DateTime(2025, 4, 15), femaleCtx);
        expect(f.flags, contains(DayFlag.tefillinOptionalAccordion));
        expect(f.flags, isNot(contains(DayFlag.skipTefillin)));
      });

      test('Regular weekday → no tefillin flags', () {
        final f = service.flagsFor(DateTime(2025, 3, 5), ctx);
        expect(f.flags, isNot(contains(DayFlag.skipTefillin)));
        expect(f.flags, isNot(contains(DayFlag.tefillinOptionalAccordion)));
      });
    });

    // ── DayFlags operator+ ───────────────────────────────────────────────────
    group('DayFlags merge operator', () {
      test('merges two flag sets without duplicates', () {
        const a = DayFlags(flags: ['shabbat', 'rosh_chodesh']);
        const b = DayFlags(flags: ['rosh_chodesh', 'chanukah']);
        final merged = a + b;
        expect(merged.flags.length, 3);
        expect(merged.flags, containsAll(['shabbat', 'rosh_chodesh', 'chanukah']));
      });
    });
  });
}
