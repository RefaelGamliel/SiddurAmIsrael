/// Zmanim relevant to the prayer-time notes shown inside the siddur.
///
/// All fields are local `DateTime`s (or null when the sun event does not occur,
/// e.g. polar latitudes). [tzeit] is a fixed 18 minutes after sunset and
/// [chatzotNight] is halachic midday + 12 hours, matching the calendar screen.
class PrayerZmanim {
  const PrayerZmanim({
    required this.sofZmanShmaGra,
    required this.sofZmanTfilaGra,
    required this.sunset,
    required this.tzeit,
    required this.chatzotNight,
  });

  /// Latest time for Kriat Shema — Vilna Gaon (GRA).
  final DateTime? sofZmanShmaGra;

  /// Latest time for the morning Amidah — Vilna Gaon (GRA).
  final DateTime? sofZmanTfilaGra;

  final DateTime? sunset;

  /// Nightfall: a fixed 18 minutes after sunset.
  final DateTime? tzeit;

  /// Halachic midnight (midday + 12h).
  final DateTime? chatzotNight;
}
