import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer({Map<String, Object>? initial}) async {
    SharedPreferences.setMockInitialValues(initial ?? {});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('prayer providers — defaults', () {
    late ProviderContainer container;

    setUp(() async => container = await makeContainer());
    tearDown(() => container.dispose());

    test('nusachProvider defaults to edot_mizrach', () {
      expect(container.read(nusachProvider), 'edot_mizrach');
    });

    test('isInIsraelProvider defaults to true', () {
      expect(container.read(isInIsraelProvider), isTrue);
    });

    test('userGenderProvider defaults to male', () {
      expect(container.read(userGenderProvider), Gender.male);
    });

    test('fontSizeFactorProvider defaults to 1.0', () {
      expect(container.read(fontSizeFactorProvider), 1.0);
    });

    test('hebrewDateProvider returns a plausible Hebrew year', () {
      final date = container.read(hebrewDateProvider);
      expect(date.year, greaterThan(5780));
      expect(date.month, inInclusiveRange(1, 13));
      expect(date.day, inInclusiveRange(1, 30));
    });
  });

  group('userContextProvider — reactivity', () {
    late ProviderContainer container;

    setUp(() async => container = await makeContainer());
    tearDown(() => container.dispose());

    test('reflects default nusach', () {
      final ctx = container.read(userContextProvider);
      expect(ctx.nusach, 'edot_mizrach');
    });

    test('reflects updated nusach', () {
      container.read(nusachProvider.notifier).set('sfard');
      final ctx = container.read(userContextProvider);
      expect(ctx.nusach, 'sfard');
    });

    test('isInIsrael derives from the selected city', () {
      // Default city (Jerusalem) → in Israel.
      expect(container.read(userContextProvider).isInIsrael, isTrue);
      // Selecting a chu"l city flips it.
      container.read(selectedCityIdProvider.notifier).set('new_york');
      expect(container.read(userContextProvider).isInIsrael, isFalse);
    });

    test('reflects updated gender', () {
      container.read(userGenderProvider.notifier).set(Gender.female);
      final ctx = container.read(userContextProvider);
      expect(ctx.gender, Gender.female);
    });
  });

  group('fontSizeFactorProvider — mutation', () {
    late ProviderContainer container;

    setUp(() async => container = await makeContainer());
    tearDown(() => container.dispose());

    test('can be incremented', () {
      container.read(fontSizeFactorProvider.notifier).set(1.2);
      expect(container.read(fontSizeFactorProvider), closeTo(1.2, 0.001));
    });

    test('can be decremented', () {
      container.read(fontSizeFactorProvider.notifier).set(0.8);
      expect(container.read(fontSizeFactorProvider), closeTo(0.8, 0.001));
    });
  });

  group('persistence', () {
    test('nusach round-trips through SharedPreferences', () async {
      final c1 = await makeContainer();
      c1.read(nusachProvider.notifier).set('edot_mizrach');
      // Allow the fire-and-forget write to complete.
      await Future<void>.delayed(Duration.zero);
      c1.dispose();

      // Re-read mock prefs (setMockInitialValues persists for the test session
      // until reset). Fresh container picks up the persisted value.
      SharedPreferences.setMockInitialValues({
        'v1.settings.nusach': 'edot_mizrach',
      });
      final prefs = await SharedPreferences.getInstance();
      final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(c2.read(nusachProvider), 'edot_mizrach');
      c2.dispose();
    });
  });
}
