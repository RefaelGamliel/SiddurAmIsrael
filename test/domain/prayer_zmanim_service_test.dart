import 'package:flutter_test/flutter_test.dart';
import 'package:siddur_am_israel_chai/domain/entities/city.dart';
import 'package:siddur_am_israel_chai/domain/services/prayer_zmanim_service.dart';

void main() {
  const service = PrayerZmanimService();
  const jerusalem = City(
    id: 'jerusalem',
    name: 'ירושלים',
    latitude: 31.7683,
    longitude: 35.2137,
    elevation: 754,
    candleLightingMinutes: 40,
    inIsrael: true,
  );

  // Assertions are timezone-independent (relative ordering only), so the suite
  // passes regardless of the machine's local zone.
  final z = service.compute(city: jerusalem, date: DateTime(2025, 6, 21));

  test('all zmanim resolve for a mid-latitude city', () {
    expect(z.sofZmanShmaGra, isNotNull);
    expect(z.sofZmanTfilaGra, isNotNull);
    expect(z.sunset, isNotNull);
    expect(z.tzeit, isNotNull);
    expect(z.chatzotNight, isNotNull);
  });

  test('Sof zman Shema (GRA) is before Sof zman Tefila (GRA)', () {
    expect(z.sofZmanShmaGra!.isBefore(z.sofZmanTfilaGra!), isTrue);
  });

  test('tzeit is exactly 18 minutes after sunset', () {
    expect(z.tzeit!.difference(z.sunset!), const Duration(minutes: 18));
  });

  test('sunset is after the morning zmanim', () {
    expect(z.sunset!.isAfter(z.sofZmanTfilaGra!), isTrue);
  });

  test('chatzot halayla is after sunset', () {
    expect(z.chatzotNight!.isAfter(z.sunset!), isTrue);
  });
}
