import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences]. All keys are versioned
/// (`v1.*`) so future schema changes can migrate without trampling.
class SettingsLocalDatasource {
  SettingsLocalDatasource(this._prefs);

  final SharedPreferences _prefs;

  static const _kNusach = 'v1.settings.nusach';
  static const _kGender = 'v1.settings.gender';
  static const _kIsInIsrael = 'v1.settings.is_in_israel';
  static const _kWithMinyan = 'v1.settings.with_minyan';
  static const _kPurimDate = 'v1.settings.purim_date';
  static const _kFontSize = 'v1.settings.font_size_factor';
  static const _kSeenBanner = 'v1.settings.seen_banner';
  static const _kShowLabels = 'v1.settings.show_labels';
  static const _kExpandedSegments = 'v1.settings.expanded_segments';
  static const _kWearsTallitGadol = 'v1.settings.wears_tallit_gadol';

  String? readNusach() => _prefs.getString(_kNusach);
  Future<void> writeNusach(String v) => _prefs.setString(_kNusach, v);

  String? readGender() => _prefs.getString(_kGender);
  Future<void> writeGender(String v) => _prefs.setString(_kGender, v);

  bool? readIsInIsrael() => _prefs.getBool(_kIsInIsrael);
  Future<void> writeIsInIsrael(bool v) => _prefs.setBool(_kIsInIsrael, v);

  bool? readWithMinyan() => _prefs.getBool(_kWithMinyan);
  Future<void> writeWithMinyan(bool v) => _prefs.setBool(_kWithMinyan, v);

  String? readPurimDate() => _prefs.getString(_kPurimDate);
  Future<void> writePurimDate(String v) => _prefs.setString(_kPurimDate, v);

  double? readFontSize() => _prefs.getDouble(_kFontSize);
  Future<void> writeFontSize(double v) => _prefs.setDouble(_kFontSize, v);

  bool? readSeenBanner() => _prefs.getBool(_kSeenBanner);
  Future<void> writeSeenBanner(bool v) => _prefs.setBool(_kSeenBanner, v);

  bool? readShowLabels() => _prefs.getBool(_kShowLabels);
  Future<void> writeShowLabels(bool v) => _prefs.setBool(_kShowLabels, v);

  /// Returns the set of optional segment IDs the user has chosen to keep open.
  Set<String> readExpandedSegments() {
    final raw = _prefs.getString(_kExpandedSegments) ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> writeExpandedSegments(Set<String> ids) =>
      _prefs.setString(_kExpandedSegments, ids.join(','));

  bool readWearsTallitGadol() => _prefs.getBool(_kWearsTallitGadol) ?? true;
  Future<void> writeWearsTallitGadol(bool v) =>
      _prefs.setBool(_kWearsTallitGadol, v);

  static const _kIsShaliachTzibbur = 'v1.settings.is_shaliach_tzibbur';
  bool readIsShaliachTzibbur() => _prefs.getBool(_kIsShaliachTzibbur) ?? false;
  Future<void> writeIsShaliachTzibbur(bool v) =>
      _prefs.setBool(_kIsShaliachTzibbur, v);

  // Selected city id for zmanim (see lib/core/data/cities.dart). Default handled
  // in the repository.
  static const _kLocationCity = 'v1.settings.location_city';
  String? readLocationCity() => _prefs.getString(_kLocationCity);
  Future<void> writeLocationCity(String v) =>
      _prefs.setString(_kLocationCity, v);

  // Location mode: 'city' (fixed) or 'gps'. Default handled in the repository.
  static const _kLocationMode = 'v1.settings.location_mode';
  String? readLocationMode() => _prefs.getString(_kLocationMode);
  Future<void> writeLocationMode(String v) =>
      _prefs.setString(_kLocationMode, v);

  /// Interface language code (e.g. 'he', 'en', 'ru', 'fr'). Affects only the
  /// app's framework UI (tabs, titles, settings) — never the prayer texts.
  static const _kAppLanguage = 'v1.settings.app_language';
  String? readAppLanguage() => _prefs.getString(_kAppLanguage);
  Future<void> writeAppLanguage(String v) =>
      _prefs.setString(_kAppLanguage, v);
}
