# סידור עם ישראל

An **offline-first Orthodox Halachic siddur** built with Flutter. Prayer texts are bundled as versioned JSON assets; no network connection is required at runtime. The app automatically selects the correct prayer, text variants, and halachic additions for the current date, time of day, and user profile.

---

## Table of Contents

1. [Features](#features)
2. [Architecture Overview](#architecture-overview)
3. [Core State Pipeline](#core-state-pipeline)
4. [JSON Data Model](#json-data-model)
5. [Project Structure](#project-structure)
6. [Getting Started](#getting-started)
7. [Code Generation](#code-generation)
8. [Running Tests](#running-tests)
9. [Halachic Standard](#halachic-standard)
10. [App Store Deployment](#app-store-deployment)
11. [Adding New Content](#adding-new-prayers--content)
12. [Project Status & Tooling](#project-status--tooling)

---

## Features

### Prayers (תפילות)
- **Three nusachim**: Ashkenaz, Sfard, Edot HaMizrach
- **Three daily services**: Shacharit, Mincha, Maariv — auto-selected by halachic zmanim; the app opens directly to the current service; tapping the tab or back-arrow reveals the service list
- **Full halachic calendar**: Shabbat, Yom Tov, Chol HaMoed, Rosh Chodesh, Chanukah, Purim (Shacharit + Maariv with Megillat Esther), fast days, Sefirat HaOmer, Sukkot (hoshanot, daily korban), Kriat HaTorah (Mon/Thu, RC, CHM, Chanukah, Purim, fast days)
- **In-prayer navigation panel**: jump-to-section within each service
- **Adjustable font size** with one-tap FAB controls
- **Inline prayer toggles**: tallit, tefillin, shaliach tzibbur, kohanim, and more — shown contextually within the prayer, not buried in settings

### Berachot (ברכות)
- **Birkat HaMazon** — all three nusachim, with transient meal-context selectors: meal type (regular / seudat mitzvah / sheva brachot / brit milah), zimmun (individual / 3 / 10), and dining status. Al HaNisim, Ya'aleh VeYavo, Harachaman blocks, and al hakos / sheva brachot adapt automatically
- **Berachah Me'ein Shalosh** — all three nusachim; multi-select food types (mezonot / gefen / perot) with correct vav-prefix and closing colon; Eretz-Yisrael provenance toggles; Rosh Chodesh / Chol HaMoed insertions
- **Tefilat HaDerech** — all three nusachim; main blessing plus an optional accordion of post-blessing verses (A/S 16-part set; Edot HaMizrach 5-verse set with te'amim), each verse repeated its stated number of times with the first occurrence bolded

### Settings & Personalisation
- **User settings** (persisted across sessions): nusach, gender, Israel/diaspora, minyan/individual, Purim date, font size, segment labels
- **Interface language**: Hebrew, English, Russian, or French — affects the framework chrome only (tabs, titles, settings labels); prayer texts are always Hebrew
- **Support contact** button in settings

---

## Architecture Overview

The codebase follows **Clean Architecture** with strict three-layer separation. No layer may import from a higher layer.

```
┌─────────────────────────────────────────────┐
│              Presentation Layer              │
│  Flutter widgets · Riverpod providers        │
│  lib/presentation/                           │
│  • No business logic                         │
│  • Reads assembled segments via providers    │
├─────────────────────────────────────────────┤
│               Domain Layer                   │
│  Entities · Repository interfaces            │
│  Services · Post-processors                  │
│  lib/domain/                                 │
│  • Pure Dart — no Flutter, no JSON parsing   │
│  • All halachic logic lives here             │
├─────────────────────────────────────────────┤
│                Data Layer                    │
│  Datasources · Repository implementations   │
│  lib/data/                                   │
│  • JSON parsing, SharedPreferences I/O       │
│  • Asset bundle access only                  │
└─────────────────────────────────────────────┘
               ↑ assets/prayers/ ↑
     700+ JSON files, fully bundled offline
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| Offline-first JSON assets | Guarantees correct text in shuls worldwide without connectivity |
| Riverpod for state | Compile-safe, composable, testable without `BuildContext` |
| `freezed` + `json_serializable` | Immutable domain entities; eliminates mutation bugs |
| `kosher_dart` for zmanim | Battle-tested Hebrew calendar and zmanim engine |
| Per-nusach manifest lookup | A single segment ID resolves to the correct file for the active nusach |
| Transient providers for Berachot | Meal-context toggles (meal type, zimmun, food types) are session-only — no SharedPreferences — so they reset with each bentching |

---

## Core State Pipeline

This is the central data flow that drives every prayer screen:

```
DateTime.now()  +  UserSettings (nusach, gender, Israel, …)
        │
        ▼
┌────────────────────────────┐
│  HalachicCalendarService   │  lib/domain/services/halachic_calendar_service.dart
│  .flagsFor(date, context)  │
└───────────┬────────────────┘
            │  DayFlags
            │  (Set<String> flag tokens + int? omerDay / sukkotDay / chanukahDay / …)
            ▼
┌────────────────────────────┐
│       UserContext          │  lib/domain/entities/user_context.dart
│  (nusach + activeFlags     │  Assembled in prayer_providers.dart → userContextProvider
│   + day-specific ints)     │
└───────────┬────────────────┘
            │
            ▼
┌────────────────────────────┐
│      PrayerAssembler       │  lib/domain/services/prayer_assembler.dart
│  .assemble(templateId,     │
│            userContext)    │
└───────────┬────────────────┘
            │  List<AssembledSegment>
            │  (resolved Hebrew text · optional · groupId)
            ▼
┌────────────────────────────┐
│     PrayerScreen widget    │  lib/presentation/pages/prayers/prayer_screen.dart
│  (renders segments,        │
│   accordion groups,        │
│   navigation panel)        │
└────────────────────────────┘
```

### Flag System

`HalachicCalendarService` emits string flag tokens (e.g. `"skip_tachanun"`, `"rosh_chodesh"`, `"omer_period"`) into `DayFlags.flags`. These merge into `UserContext.activeFlags` and serve as a **condition/exclude gate** in two places:

- **Template entries** — `condition_flags` / `exclude_flags` determine which segments appear
- **Segment sections** — the same fields control which text variant renders within a segment

Every flag constant lives in `DayFlag` (`lib/domain/entities/day_flags.dart`) — the single source of truth referenced by both Dart code and JSON assets.

Berachot providers inject additional transient flags (meal type, zimmun mode, dining status, food types) into the `UserContext.activeFlags` for each assembly, without persisting them.

### Post-Processors

After assembly, specialized post-processors inject dynamic content:

| Post-Processor | Trigger | What it injects |
|---|---|---|
| `OmerPostProcessor` | `omerDay != null` | Fills `{{omer_day_count}}` and `{{omer_sefira}}`; bolds the day's word in Lamenatzeach and Ana BeKoach |
| `SukkotKorbanotPostProcessor` | `sukkotDay != null` | Fills `{{daily_korban}}` with the correct Numbers 29 pasuk |
| Kriah resolver | `upcomingParshah != null` | Loads Mon/Thu Torah reading text |
| RC Tevet composite | `rc_tevet` flag | Merges RC olim 1–3 + Chanukah day-N as oleh 4 |
| GraSsy resolver | `chagYt1Weekday != null` | Loads the Gr"a Shir Shel Yom chapter for CHM Pesach/Sukkot |

---

## JSON Data Model

### Asset Manifest — `assets/prayers/_manifest.json`

Three top-level keys: `common` (nusach-agnostic segments), `nusach` (per-nusach overrides), and `templates`.

```json
{
  "common": {
    "hallel": "assets/prayers/shacharit/acharei_amidah/common/hallel.json"
  },
  "nusach": {
    "ashkenaz":     { "kedushah": "…/ashkenaz/kedushah.json" },
    "sfard":        { "kedushah": "…/sfard/kedushah.json"    },
    "edot_mizrach": { "kedushah": "…/edot_mizrach/kedushah.json" }
  }
}
```

Lookup order: nusach-specific entry → `common` fallback.

### Prayer Template

```json
{
  "id": "shacharit_ashkenaz",
  "name": "shacharit_ashkenaz",
  "segments": [
    {
      "segment_id": "baruch_sheamar",
      "condition_flags": [],
      "exclude_flags": [],
      "optional": false,
      "allowed_nusach": []
    },
    {
      "sub_template_id": "tachanun_ashkenaz",
      "condition_flags": [],
      "exclude_flags": ["skip_tachanun"]
    }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `segment_id` | string | Leaf segment — load from manifest and render |
| `sub_template_id` | string | Expand a nested template recursively |
| `condition_flags` | string[] | ALL must be in `activeFlags` for this entry to appear |
| `exclude_flags` | string[] | ANY match causes the entry to be skipped |
| `allowed_nusach` | string[] | If non-empty, restricts to listed nusachim |
| `optional` | bool | Renders as a collapsed accordion the user can expand |

### Prayer Segment

```json
{
  "id": "amidah_avot",
  "sections": [
    {
      "text": [
        "בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵינוּ",
        "וֵאלֹהֵי אֲבוֹתֵינוּ"
      ],
      "condition_flags": [],
      "exclude_flags": ["hamelech_hakadosh"]
    },
    {
      "text": "הַמֶּלֶךְ הַקָּדוֹשׁ",
      "condition_flags": ["hamelech_hakadosh"],
      "exclude_flags": []
    }
  ]
}
```

- **`text`**: `String` or `List<String>`. Arrays are joined with `" "` at runtime. **Texts longer than ~80 characters must use the array form**, split at natural phrase or cantillation-pause boundaries.
- **Sections** are filtered by `condition_flags`/`exclude_flags` and concatenated with `\n`.
- **Bold syntax**: `<b>word</b>` — used by post-processors; rendered by `RichPrayerText`.

---

## Project Structure

```
smart_siddur/
├── assets/prayers/               # 700+ JSON prayer asset files
│   ├── _manifest.json            # Central segment-ID → path registry
│   ├── templates/                # Prayer templates (one per service-section per nusach)
│   ├── shared_global/            # Amidah blessings, Kaddish, shared segments
│   ├── shacharit/                # Shacharit-specific segments by section
│   ├── mincha/
│   ├── maariv/
│   ├── musaf/
│   ├── birkat_hamazon/           # Birkat HaMazon segments (common + per nusach)
│   ├── meein_shalosh/            # Me'ein Shalosh segments (common + per nusach)
│   ├── tefilat_haderech/         # Tefilat HaDerech segments (common + per nusach)
│   └── purim/                    # Purim segments (Megillat Esther + blessings)
│
├── lib/
│   ├── core/
│   │   ├── calendar/             # HebrewDate value object
│   │   └── utils/                # HebrewFormatter (display strings)
│   ├── data/
│   │   ├── datasources/local/    # Asset bundle + SharedPreferences datasources
│   │   └── repositories/         # Concrete repository implementations
│   ├── domain/
│   │   ├── entities/             # Freezed immutable models (+ generated .freezed.dart/.g.dart)
│   │   ├── repositories/         # Abstract interfaces (I*.dart)
│   │   └── services/             # HalachicCalendarService · PrayerAssembler · post-processors
│   └── presentation/
│       ├── constants/            # segment_labels.dart — Hebrew UI labels per segment ID
│       ├── i18n/                 # app_locale.dart · app_strings.dart — interface language
│       ├── pages/
│       │   ├── berachot/         # BerachotScreen (Birkat HaMazon, Me'ein Shalosh, …)
│       │   ├── prayers/          # PrayerScreen (shared) · PrayerMenuScreen
│       │   └── settings/         # SettingsScreen
│       ├── providers/            # prayer_providers.dart — all Riverpod providers
│       ├── theme/                # AppColors · AppDimens — design token constants
│       └── widgets/              # PrayerTextWidget · HalachicHeader · FontSizeFab · …
│
├── test/
│   ├── domain/                   # HalachicCalendarService · assembler · Me'ein Shalosh · post-processors
│   └── presentation/             # Provider reactivity · widget rendering
│
├── pubspec.yaml
└── README.md                     # This file
```

---

## Getting Started

### Prerequisites

| Tool | Required Version |
|---|---|
| Flutter | 3.41.9 (stable) |
| Dart | 3.11.5 |
| Xcode | 16+ (for iOS builds) |
| Android SDK | API 21+ (minSdkVersion) |

### Install

```bash
git clone <repo-url>
cd smart-siddur
flutter pub get
```

### Run (development)

```bash
flutter run
```

A debug overlay (🛠 button) is available in debug builds with presets for every testable halachic scenario: Chanukah, Sukkot, Purim, Rosh Chodesh, fast days, Sefirat HaOmer, etc.

---

## Code Generation

The project uses `freezed` (immutable models) and `json_serializable` (JSON deserialization). **Run this command whenever you modify any entity in `lib/domain/entities/`:**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Watch mode for active development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

Generated files (`*.freezed.dart`, `*.g.dart`) are committed to source control and must always be in sync with their source files before submitting a PR.

---

## Running Tests

```bash
# Full suite — 218 tests across 12 files
flutter test

# Verbose output showing each test name
flutter test --reporter=expanded

# Single file
flutter test test/domain/halachic_calendar_service_test.dart

# Static analysis — target: 0 errors, 0 warnings
flutter analyze
```

### Test matrix

| File | Coverage |
|---|---|
| `halachic_calendar_service_test.dart` | Flag emission for every halachic scenario (RC, YT, CHM, Chanukah, Purim, fasts, Omer, BaHaB, seasons) |
| `prayer_assembler_test.dart` | Template assembly, condition/exclude gates, sub-template recursion |
| `prayer_assembler_mincha_test.dart` | Mincha-specific flow (Tisha B'Av, Nachem) |
| `prayer_assembler_meein_test.dart` | Me'ein Shalosh assembly: vav-prefix, closing colon, EY toggles, nusach differences, Tefilat HaDerech |
| `omer_post_processor_test.dart` | `{{omer_day_count}}` substitution, Lamenatzeach/Ana BeKoach bold highlighting |
| `sukkot_korbanot_post_processor_test.dart` | `{{daily_korban}}` injection per day |
| `service_time_resolver_test.dart` | Zmanim-based service auto-selection |
| `prayer_providers_test.dart` | Riverpod provider reactivity, persistence round-trips |
| `settings_repository_test.dart` | SharedPreferences read/write |
| `rich_prayer_text_test.dart` | `<b>…</b>` span parsing |
| `hebrew_formatter_test.dart` | Hebrew date/nusach display strings |
| `prayer_local_datasource_test.dart` | Asset bundle JSON loading and text normalization |

---

## Halachic Standard

This application is a **strictly Orthodox Halachic siddur**. Key points for all contributors:

- Only mainstream Orthodox Halachic practice is represented. Reform, Conservative, Egalitarian, or Liberal variants are forbidden in any part of the codebase (source, JSON, comments, tests, docs).
- Every flag constant in `DayFlag` (`lib/domain/entities/day_flags.dart`) is documented with its Halachic basis.
- Gender-specific variants require a cited posek from mainstream Orthodox halacha before implementation.
- The only supported prayer services are Shacharit, Mincha, and Maariv. Kabbalat Shabbat and Musaf Yom Tov/Shabbat are out of scope for the current version.

---

## App Store Deployment

### Pre-submission checklist

```bash
# 1. Regenerate all code-gen artifacts from source
dart run build_runner build --delete-conflicting-outputs

# 2. Full test suite must pass with zero failures
flutter test

# 3. Analyzer must report zero errors and zero warnings
flutter analyze

# 4. Bump version in pubspec.yaml (format: major.minor.patch+buildNumber)
#    Example: version: 1.0.1+2
```

### iOS — Apple App Store

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode → Product → Archive → Distribute App → App Store Connect.

**Notes for submission:**
- The app requires **no special entitlements**: no push notifications, no background modes, no camera, no microphone, no location.
- The app does **not** collect or transmit any user data.
- Hebrew RTL is configured via `flutter_localizations`. Interface language selection (he/en/ru/fr) does not affect the prayer texts.

### Android — Google Play

```bash
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to the Play Console.

---

## Adding New Prayers / Content

1. **Create segment JSON** in the appropriate `assets/prayers/…/nusach/<nusach>/` folder.
2. **Register the segment** in `assets/prayers/_manifest.json` under the correct nusach key.
3. **Add to a template** (`assets/prayers/templates/…`) with appropriate `condition_flags` / `exclude_flags`.
4. **Declare the asset directory** in `pubspec.yaml` under `flutter.assets` if it is a new folder.
5. **Add a label** in `lib/presentation/constants/segment_labels.dart` (empty string = no visible section header).
6. Run `flutter test` to verify no regressions.

**JSON text formatting rule**: any `text` field longer than ~80 characters must use the array form (`List<String>`), split at natural phrase or cantillation-pause boundaries. The parser joins array elements with a single space at runtime.

---

## Project Status & Tooling

### Developer Tools

**Date / Time Override Panel (debug builds only)**

A floating 🛠 button appears in the bottom-right corner of every screen **only when the app is run in debug mode** (`flutter run` or IDE launch). It is completely absent from release/profile builds.

**How to use (debug builds):**

1. Tap 🛠 to open the preset panel.
2. Use the date/time pickers or tap a quick-preset button to jump to any halachic scenario:
   - Chanukah (each day 1–8)
   - Rosh Chodesh + RC Tevet (Chanukah composite)
   - Chol HaMoed Pesach / Sukkot (each day)
   - Purim / Shushan Purim
   - Fast days (Tzom Gedaliah, 10 Tevet, Taanit Esther, 17 Tammuz, Tisha B'Av)
   - Sefirat HaOmer (any of the 49 days)
   - Aseret Yemei Teshuva, Yom Kippur, Hoshana Raba, etc.
3. Tap **Reset** to return to the real current date/time.

The override affects `HalachicCalendarService`, `ServiceTimeResolver`, and all prayer + berachot providers simultaneously.

---

### Known Limitations (v1)

| Area | Status | Notes |
|---|---|---|
| **Shabbat prayer services** | 🚫 Out of scope | Kabbalat Shabbat, Shacharit/Musaf Shabbat, Maariv Motzei Shabbat |
| **Yom Tov full services** | 🚫 Out of scope | Yom Tov Musaf Amidah, full Hallel Shacharit |
| **Tisha B'Av full service** | ⚠️ Partial | Nachem at Mincha is implemented; Shacharit Kinot and abbreviated Psukei DeZimra are not |
| **Kiddush Levana** | 📋 Planned | Placeholder in the Berachot tab; content not yet implemented |
| **GPS Eretz-Yisrael detection** | ⚠️ Approximate | When location mode is GPS, "in Eretz Yisrael" (which drives Yom Tov Sheni and similar din) is decided by a coarse lat/lng bounding box (`lat 29.4–33.4`, `lng 34.2–35.95`). It covers all of Israel — including Judea & Samaria — with no false negatives, but the rectangle also catches slivers of neighbouring countries (e.g. Amman & the western Jordan Valley, southern Lebanon around Tyre, north-east Sinai), so a user physically inside one of those border areas would be treated as in Israel. Selecting a fixed city instead is always exact. A precise border polygon is a future refinement. |

---

## Credits

The application's code infrastructure was developed by **Refael Gamliel** (רפאל גמליאל).

- LinkedIn: [www.linkedin.com/in/refael-gamliel](https://www.linkedin.com/in/refael-gamliel)
- Email: [refaelgamliel@gmail.com](mailto:refaelgamliel@gmail.com)
