import 'package:kosher_dart/kosher_dart.dart';

import 'package:siddur_am_israel_chai/domain/entities/city.dart';
import 'package:siddur_am_israel_chai/domain/entities/prayer_zmanim.dart';

/// Computes the prayer-time zmanim shown inside the siddur for a given location
/// and civil [date]. Sof zman Shema/Tefila use the GRA (Vilna Gaon) opinion,
/// which kosher_dart provides directly.
class PrayerZmanimService {
  const PrayerZmanimService();

  PrayerZmanim compute({required City city, required DateTime date}) {
    final geo = GeoLocation.setLocation(
      city.name,
      city.latitude,
      city.longitude,
      date,
    );
    final zc = ComplexZmanimCalendar.intGeoLocation(geo);

    final sunset = zc.getSunset();
    final chatzos = zc.getChatzos();

    return PrayerZmanim(
      sofZmanShmaGra: zc.getSofZmanShmaGRA(),
      sofZmanTfilaGra: zc.getSofZmanTfilaGRA(),
      sunset: sunset,
      tzeit: sunset?.add(const Duration(minutes: 18)),
      chatzotNight: chatzos?.add(const Duration(hours: 12)),
    );
  }
}
