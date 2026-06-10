import 'package:siddur_am_israel_chai/data/datasources/local/settings_local_datasource.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/domain/repositories/i_settings_repository.dart';

class SettingsRepositoryImpl implements ISettingsRepository {
  SettingsRepositoryImpl(this._ds);

  final SettingsLocalDatasource _ds;

  static const _defaultNusach = 'edot_mizrach';
  static const _defaultGender = Gender.male;
  static const _defaultIsInIsrael = true;
  static const _defaultWithMinyan = true;
  static const _defaultPurimDate = PurimDate.fourteenth;
  static const _defaultFontSize = 1.0;

  @override
  String getNusach() => _ds.readNusach() ?? _defaultNusach;

  @override
  Future<void> setNusach(String value) => _ds.writeNusach(value);

  @override
  Gender getGender() {
    final raw = _ds.readGender();
    return Gender.values.firstWhere(
      (g) => g.name == raw,
      orElse: () => _defaultGender,
    );
  }

  @override
  Future<void> setGender(Gender value) => _ds.writeGender(value.name);

  @override
  bool getIsInIsrael() => _ds.readIsInIsrael() ?? _defaultIsInIsrael;

  @override
  Future<void> setIsInIsrael(bool value) => _ds.writeIsInIsrael(value);

  @override
  bool getWithMinyan() => _ds.readWithMinyan() ?? _defaultWithMinyan;

  @override
  Future<void> setWithMinyan(bool value) => _ds.writeWithMinyan(value);

  @override
  PurimDate getPurimDate() {
    final raw = _ds.readPurimDate();
    return PurimDate.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => _defaultPurimDate,
    );
  }

  @override
  Future<void> setPurimDate(PurimDate value) => _ds.writePurimDate(value.name);

  @override
  double getFontSizeFactor() {
    final v = _ds.readFontSize() ?? _defaultFontSize;
    return v.clamp(0.6, 1.6);
  }

  @override
  Future<void> setFontSizeFactor(double value) =>
      _ds.writeFontSize(value.clamp(0.6, 1.6));

  @override
  bool getHasSeenSettingsBanner() => _ds.readSeenBanner() ?? false;

  @override
  Future<void> setHasSeenSettingsBanner(bool value) =>
      _ds.writeSeenBanner(value);

  @override
  bool getShowSegmentLabels() => _ds.readShowLabels() ?? true;

  @override
  Future<void> setShowSegmentLabels(bool value) => _ds.writeShowLabels(value);

  @override
  Set<String> getExpandedSegments() => _ds.readExpandedSegments();

  @override
  Future<void> setExpandedSegments(Set<String> ids) =>
      _ds.writeExpandedSegments(ids);

  @override
  bool getWearsTallitGadol() => _ds.readWearsTallitGadol();

  @override
  Future<void> setWearsTallitGadol(bool value) =>
      _ds.writeWearsTallitGadol(value);

  @override
  bool getIsShaliachTzibbur() => _ds.readIsShaliachTzibbur();

  @override
  Future<void> setIsShaliachTzibbur(bool value) =>
      _ds.writeIsShaliachTzibbur(value);

  @override
  bool getEinKohanim() => false;

  @override
  Future<void> setEinKohanim(bool value) => Future.value();

  static const _defaultLocationCity = 'jerusalem';

  @override
  String getLocationCityId() => _ds.readLocationCity() ?? _defaultLocationCity;

  @override
  Future<void> setLocationCityId(String value) => _ds.writeLocationCity(value);

  @override
  String getLocationMode() => _ds.readLocationMode() ?? 'city';

  @override
  Future<void> setLocationMode(String value) => _ds.writeLocationMode(value);

  static const _defaultAppLanguage = 'he';
  static const _supportedLanguages = {'he', 'en', 'ru', 'fr'};

  @override
  String getAppLanguage() {
    final raw = _ds.readAppLanguage();
    return (raw != null && _supportedLanguages.contains(raw))
        ? raw
        : _defaultAppLanguage;
  }

  @override
  Future<void> setAppLanguage(String value) => _ds.writeAppLanguage(
        _supportedLanguages.contains(value) ? value : _defaultAppLanguage,
      );
}
