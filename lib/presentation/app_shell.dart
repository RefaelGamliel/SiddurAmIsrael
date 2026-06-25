import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/domain/services/service_time_resolver.dart';
import 'package:siddur_am_israel_chai/presentation/i18n/app_strings.dart';
import 'package:siddur_am_israel_chai/presentation/pages/berachot/berachot_screen.dart';
import 'package:siddur_am_israel_chai/presentation/pages/calendar/calendar_screen.dart';
import 'package:siddur_am_israel_chai/presentation/pages/prayers/prayer_menu_screen.dart';
import 'package:siddur_am_israel_chai/presentation/pages/settings/settings_screen.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_colors.dart';

/// Top-level shell with 4 bottom tabs:
///   0 → Prayers   (Shacharit / Mincha / Maariv — opens on the current service)
///   1 → Berachot  (Birkat HaMazon, Me'ein Shalosh, …)
///   2 → Calendar  (לוח)
///   3 → Settings
///
/// The Prayers tab is a nested [Navigator] whose initial stack is
/// [menu, current-service], so the app opens directly onto the prayer that
/// matches the current time while a back-tap (or re-tapping the tab) reveals
/// the list. Tab state is preserved via [IndexedStack].
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  // Tab to return to when leaving Settings via its back arrow.
  int _previousIndex = 0;

  static const int _prayersIdx = 0;
  static const int _berachotIdx = 1;
  static const int _settingsIdx = 3;

  final _prayersNavKey = GlobalKey<NavigatorState>();
  final _berachotNavKey = GlobalKey<NavigatorState>();

  void _goTo(int i) {
    if (i == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = i;
    });
  }

  void _openSettings() => _goTo(_settingsIdx);

  void _onTapTab(int i) {
    // Re-tapping an active tab with a nested navigator returns to its root.
    if (i == _currentIndex) {
      if (i == _prayersIdx) {
        _prayersNavKey.currentState?.popUntil((r) => r.isFirst);
        return;
      }
      if (i == _berachotIdx) {
        _berachotNavKey.currentState?.popUntil((r) => r.isFirst);
        return;
      }
    }
    _goTo(i);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    final screens = <Widget>[
      _PrayersTab(navKey: _prayersNavKey, onOpenSettings: _openSettings),
      _BerachotTab(navKey: _berachotNavKey),
      const CalendarScreen(),
      SettingsScreen(onBack: () => _goTo(_previousIndex)),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Paint the status-bar inset with the header colour so the system
          // battery/clock icons stay visible on every tab (otherwise they
          // vanish against the light page background). Stripping the top
          // padding afterwards lets each tab's own AppBar sit flush below the
          // inset instead of adding a second gap.
          Container(
            color: AppColors.primary,
            height: MediaQuery.of(context).padding.top,
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(index: _currentIndex, children: screens),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTapTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: AppColors.background,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.auto_stories_outlined),
            activeIcon: const Icon(Icons.auto_stories),
            label: s.t('tab_prayers'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            activeIcon: const Icon(Icons.menu_book),
            label: s.t('tab_berachot'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today_outlined),
            activeIcon: const Icon(Icons.calendar_today),
            label: s.t('tab_calendar'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: s.t('tab_settings'),
          ),
        ],
      ),
    );
  }
}

/// The Prayers tab: a nested navigator whose root is the prayer menu, with the
/// current-time service pushed on top so the app opens straight into it.
class _PrayersTab extends ConsumerWidget {
  const _PrayersTab({required this.navKey, required this.onOpenSettings});

  final GlobalKey<NavigatorState> navKey;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(appStringsProvider);
    final current = ref.read(currentServiceProvider);
    final currentTitleKey = switch (current) {
      PrayerService.shacharit => 'shacharit',
      PrayerService.mincha => 'mincha',
      PrayerService.maariv => 'maariv',
    };

    // Force RTL so push/pop slide transitions match the (always-RTL) prayer
    // content — otherwise an LTR interface language makes pages slide in from
    // the wrong side during navigation.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Navigator(
        key: navKey,
        onGenerateInitialRoutes: (navigator, initialRoute) => [
          MaterialPageRoute<void>(
            builder: (_) => PrayerMenuScreen(onOpenSettings: onOpenSettings),
          ),
          MaterialPageRoute<void>(
            builder: (_) => buildPrayerReader(
              current,
              s.t(currentTitleKey),
              onOpenSettings: onOpenSettings,
            ),
          ),
        ],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => PrayerMenuScreen(onOpenSettings: onOpenSettings),
        ),
      ),
    );
  }
}

/// The Berachot tab: a nested navigator rooted at the blessings menu, so that
/// opening a blessing keeps the bottom navigation bar visible (the push stays
/// inside the tab rather than covering the whole shell).
class _BerachotTab extends StatelessWidget {
  const _BerachotTab({required this.navKey});

  final GlobalKey<NavigatorState> navKey;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Navigator(
        key: navKey,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => const BerachotScreen(),
        ),
      ),
    );
  }
}
