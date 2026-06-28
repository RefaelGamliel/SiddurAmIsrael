import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/domain/entities/assembled_segment.dart';
import 'package:siddur_am_israel_chai/domain/services/service_time_resolver.dart';
import 'package:siddur_am_israel_chai/presentation/i18n/app_strings.dart';
import 'package:siddur_am_israel_chai/presentation/pages/compass/compass_screen.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_colors.dart';
import 'package:siddur_am_israel_chai/presentation/widgets/font_size_fab.dart';
import 'package:siddur_am_israel_chai/presentation/widgets/halachic_header.dart';
import 'package:siddur_am_israel_chai/presentation/widgets/prayer_text_widget.dart';
import 'package:siddur_am_israel_chai/presentation/widgets/settings_reminder_banner.dart';

// ── Group accordion config ────────────────────────────────────────────────────

const _groupTitles = <String, String>{
  'chazarat_hashatz': 'חזרת הש״ץ',
  'ketoret_group': 'פרשת הקטורת',
  'pitum_group': 'פטום הקטורת',
  'eizehu_group': 'איזהו מקומן',
  'tachanun': 'תחנון',
  'zimmun': 'זימון',
};

// Group accordions that open by default (the user can still collapse them).
const _defaultOpenGroups = <String>{'tachanun'};

// Titles for nested sub-accordions rendered INSIDE a group accordion.
const _subGroupTitles = <String, String>{
  'vidui': 'וידוי וי״ג מידות',
};

// Sub-accordions that open by default. Those absent here start collapsed.
const _subGroupDefaultOpen = <String>{};

// ── Nav anchors ───────────────────────────────────────────────────────────────
// Defines WHICH segments appear as nav list items and with what label.
// Only entries matching (segmentId + occurrence index) produce a nav item.
// Segments appear in the nav list in the order they occur in the assembled
// prayer — this list only determines which ones are included and their labels.

class _NavSpec {
  const _NavSpec(this.segmentId, this.label,
      {this.occurrence = 0, this.group = ''});
  final String segmentId;
  final String label;
  final int occurrence; // 0 = first occurrence, 1 = second, …
  // When non-empty, only the FIRST matching spec in this group creates a nav
  // entry. Use to handle mutually-exclusive anchors (e.g. psalm_030 vs hodu
  // both map to "פסוקי דזמרה" but only whichever appears first fires).
  final String group;
}

const _navSpecs = <_NavSpec>[
  // ── Lifnei HaTfila ──────────────────────────────────────────────────────
  _NavSpec('modeh_ani', 'השכמת הבוקר'),
  _NavSpec('birkat_tzitzit_gadol', 'סדר לבישת ציצית'),
  _NavSpec('seder_tefillin', 'סדר הנחת תפילין'),
  _NavSpec('birkot_hashachar_header', 'ברכות השחר'),
  _NavSpec('akeidah', 'פרשת העקידה'),
  _NavSpec('korbanot_eizehu_header', 'איזהו מקומן'),
  _NavSpec('korbanot_conclusion', 'רבי ישמעאל'),
  _NavSpec('kaddish_derabanan_header', 'קדיש דרבנן'),
  // ── Pesukei DeZimra ─────────────────────────────────────────────────────
  // Ashkenaz starts with psalm_030; Sfard/EM starts with hodu.
  // group:'pezimra_start' ensures only the first one found fires.
  _NavSpec('psalm_030', 'פסוקי דזמרה', group: 'pezimra_start'),
  _NavSpec('hodu', 'פסוקי דזמרה', group: 'pezimra_start'),
  _NavSpec('baruch_sheamar', 'ברוך שאמר'),
  _NavSpec('ashrei', 'אשרי יושבי ביתך'), // 1st = pesukei dezimra
  _NavSpec('yishtabach', 'ישתבח'),
  // ── Birkot Kriat Shema ──────────────────────────────────────────────────
  _NavSpec('yotzer_or', 'יוצר אור'),
  _NavSpec('shema', 'קריאת שמע'),
  // ── Amidah (one entry for entire amidah) ────────────────────────────────
  _NavSpec('amidah_intro', 'עמידה'),
  // ── Chazarat HaShatz (inside accordion) ─────────────────────────────────
  _NavSpec('kedushah', 'קדושה'),
  _NavSpec('modim_derabanan', 'מודים דרבנן'),
  _NavSpec('birkat_kohanim', 'ברכת כהנים'),
  // ── Post-amidah ─────────────────────────────────────────────────────────
  _NavSpec('tachanun_header', 'תחנון'),
  _NavSpec('kriat_hatorah_hotzaah', 'קריאת התורה'),
  _NavSpec('ashrei', 'אשרי', occurrence: 1), // 2nd = after musaf
  // שיר של יום — exactly one day-variant fires per service.
  _NavSpec('shir_shel_yom_sunday', 'שיר של יום'),
  _NavSpec('shir_shel_yom_monday', 'שיר של יום'),
  _NavSpec('shir_shel_yom_tuesday', 'שיר של יום'),
  _NavSpec('shir_shel_yom_wednesday', 'שיר של יום'),
  _NavSpec('shir_shel_yom_thursday', 'שיר של יום'),
  _NavSpec('shir_shel_yom_friday', 'שיר של יום'),
  _NavSpec('shir_shel_yom_shabbat', 'שיר של יום'),
  // ── Sof HaTfila ─────────────────────────────────────────────────────────
  _NavSpec('musaf_header', 'מוסף'),
  _NavSpec('ein_keloheinu', 'אין כאלקינו'),
  _NavSpec('aleinu', 'עלינו לשבח'),
  _NavSpec('ladavid', 'לדוד ה׳'),
];

/// Finds the matching nav spec for [id] at [occurrence], respecting group
/// exclusivity via [satisfiedGroups] (mutates it when a group fires).
_NavSpec? _findNavSpec(String id, int occurrence, Set<String> satisfiedGroups) {
  for (final spec in _navSpecs) {
    if (spec.segmentId != id || spec.occurrence != occurrence) continue;
    if (spec.group.isNotEmpty && satisfiedGroups.contains(spec.group)) {
      return null; // another spec in this group already fired
    }
    if (spec.group.isNotEmpty) satisfiedGroups.add(spec.group);
    return spec;
  }
  return null;
}

// ── PrayerScreen ─────────────────────────────────────────────────────────────

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({
    super.key,
    required this.title,
    required this.service,
    required this.contentProvider,
    this.onOpenSettings,
  });

  final String title;
  final PrayerService service;
  final FutureProvider<List<AssembledSegment>> contentProvider;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  final ScrollController _scrollController = ScrollController();

  List<_ListItem>? _cachedItems;
  List<_NavEntry>? _cachedNavEntries;
  List<AssembledSegment>? _lastSegments;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateCache(List<AssembledSegment> segments) {
    if (identical(segments, _lastSegments)) return;
    // Save scroll offset before the list rebuilds (e.g. after inline toggle).
    final savedOffset = _scrollController.hasClients &&
            _scrollController.position.hasContentDimensions
        ? _scrollController.offset
        : 0.0;
    _lastSegments = segments;
    _cachedItems = _buildListItems(segments, widget.service);
    _cachedNavEntries = _buildNavEntries(_cachedItems!);
    // Restore scroll position after layout so inline toggles don't jump.
    if (savedOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  void _showNavSheet() {
    final entries = _cachedNavEntries;
    if (entries == null || entries.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NavSheet(
        title: ref.read(appStringsProvider).t('jump_to_section'),
        entries: entries,
        scrollController: _scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayerAsync = ref.watch(widget.contentProvider);
    final bannerSeen = ref.watch(hasSeenSettingsBannerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      // The AppShell paints the status-bar inset and strips the top padding,
      // so this screen only needs to avoid the bottom inset.
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                SettingsReminderBanner(onOpenSettings: widget.onOpenSettings),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 140,
                        pinned: true,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        title: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        centerTitle: true,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.explore),
                            tooltip: ref
                                .read(appStringsProvider)
                                .t('compass_tooltip'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CompassScreen(),
                              ),
                            ),
                          ),
                        ],
                        flexibleSpace: const FlexibleSpaceBar(
                          background: HalachicHeader(),
                          collapseMode: CollapseMode.pin,
                        ),
                      ),
                      prayerAsync.when(
                        // Inline toggles change a watched provider → the prayer
                        // FutureProvider RELOADS (dependency change), not just
                        // refreshes. skipLoadingOnReload keeps the previous
                        // content visible so the SliverList is never replaced by
                        // the loading spinner — which is what reset scroll to top.
                        skipLoadingOnReload: true,
                        skipLoadingOnRefresh: true,
                        loading: () => const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        ),
                        error: (err, _) => SliverFillRemaining(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'שגיאה בטעינת התפילה\n$err',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                        data: (segments) {
                          _updateCache(segments);
                          final items = _cachedItems!;
                          // Truly eager: a Column inside SliverToBoxAdapter keeps
                          // EVERY child (and its nav GlobalKey) in the element
                          // tree at all times — unlike SliverList, which is lazy
                          // and only builds children near the viewport. This is
                          // required so Scrollable.ensureVisible can always reach
                          // any nav target accurately, regardless of distance.
                          return SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final item in items) item.build(context),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            FontSizeFab(scrollController: _scrollController),
            if (prayerAsync.hasValue &&
                (_cachedNavEntries?.isNotEmpty ?? false))
              Positioned(
                // Below the collapsed toolbar + clear of the title text.
                // Add extra offset when the settings banner is still visible
                // (~44 dp) so the button doesn't land on the banner row.
                top: bannerSeen ? kToolbarHeight + 4 : kToolbarHeight + 48,
                right: 12,
                child: _NavFab(onTap: _showNavSheet),
              ),
          ],
        ),
      ),
    );
  }
}

// ── List item helpers ─────────────────────────────────────────────────────────

/// Walks the assembled segments and builds the list of UI items:
/// - Consecutive segments with the same non-empty groupId → one [_GroupItem].
/// - Everything else → individual [_SegmentItem].
///
/// [occurrenceCounts] is shared across all items so grouped children count
/// toward the global occurrence index.
List<_ListItem> _buildListItems(
    List<AssembledSegment> segments, PrayerService service) {
  final items = <_ListItem>[];
  final counts = <String, int>{};
  final satisfiedGroups = <String>{};

  // Maariv: the tzeit / chatzot note sits at the very top, before the service.
  if (service == PrayerService.maariv) {
    items.add(const _ZmanNoteItem(_ZmanNoteKind.maariv));
  }
  // Shacharit: insert the Sof-zman notes right before their anchor segments.
  var shemaNoteDone = false;
  var tefilaNoteDone = false;

  int i = 0;
  while (i < segments.length) {
    final seg = segments[i];
    final gid = seg.groupId;

    if (gid.isNotEmpty) {
      final grouped = <AssembledSegment>[];
      final groupStartIdx = items.length;
      while (i < segments.length && segments[i].groupId == gid) {
        grouped.add(segments[i]);
        i++;
      }
      final title = _groupTitles[gid] ?? gid;
      items.add(_GroupItem(
        groupId: gid,
        title: title,
        segments: grouped,
        counts: counts,
        satisfiedGroups: satisfiedGroups,
        itemIndex: groupStartIdx,
        // totalItems placeholder — filled after full list is built
      ));
    } else {
      if (service == PrayerService.shacharit) {
        if (!shemaNoteDone && seg.id == 'shema') {
          items.add(const _ZmanNoteItem(_ZmanNoteKind.shema));
          shemaNoteDone = true;
        } else if (!tefilaNoteDone && seg.id == 'amidah_intro') {
          items.add(const _ZmanNoteItem(_ZmanNoteKind.tefila));
          tefilaNoteDone = true;
        }
      }
      final occ = counts[seg.id] ?? 0;
      counts[seg.id] = occ + 1;
      final spec = _findNavSpec(seg.id, occ, satisfiedGroups);
      final key = spec != null ? GlobalKey() : null;
      items.add(_SegmentItem(
        segment: seg,
        navKey: key,
        navLabel: spec?.label,
        itemIndex: items.length,
      ));
      i++;
    }
  }

  // Back-fill totalItems now that we know the full count.
  final total = items.length;
  for (final item in items) {
    if (item is _SegmentItem) item._totalItems = total;
    if (item is _GroupItem) item._totalItems = total;
  }
  return items;
}

List<_NavEntry> _buildNavEntries(List<_ListItem> items) {
  final entries = <_NavEntry>[];
  for (final item in items) {
    if (item is _SegmentItem) {
      final e = item.navEntry;
      if (e != null) entries.add(e);
    } else if (item is _GroupItem) {
      // Group item itself is NOT a nav entry; only its nav-anchor children are.
      entries.addAll(item.childNavEntries);
    }
  }
  return entries;
}

// ── Abstract list item ────────────────────────────────────────────────────────

abstract class _ListItem {
  const _ListItem();
  Widget build(BuildContext context);
}

// ── Segment item ──────────────────────────────────────────────────────────────

class _SegmentItem extends _ListItem {
  _SegmentItem({
    required this.segment,
    required this.navKey,
    required this.navLabel,
    required this.itemIndex,
  });

  final AssembledSegment segment;
  final GlobalKey? navKey;
  final String? navLabel;
  final int itemIndex;
  // Set after the full list is built.
  int _totalItems = 1;

  _NavEntry? get navEntry {
    final k = navKey;
    final l = navLabel;
    if (k == null || l == null) return null;
    return _NavEntry(
      label: l,
      key: k,
      itemIndex: itemIndex,
      totalItems: _totalItems,
    );
  }

  @override
  Widget build(BuildContext context) =>
      PrayerTextWidget(key: navKey, segment: segment);
}

// ── Prayer-time note item ─────────────────────────────────────────────────────

enum _ZmanNoteKind { shema, tefila, maariv }

class _ZmanNoteItem extends _ListItem {
  const _ZmanNoteItem(this.kind);
  final _ZmanNoteKind kind;

  @override
  Widget build(BuildContext context) => _ZmanNote(kind: kind);
}

/// A small, location-aware time note shown above a prayer section. Appears only
/// inside its display window (Shacharit: from 1h before the זמן; Maariv tzeit:
/// from 30 min before sunset; Maariv chatzot: from 1h before chatzot).
class _ZmanNote extends ConsumerWidget {
  const _ZmanNote({required this.kind});
  final _ZmanNoteKind kind;

  static String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(effectiveNowProvider);
    final lines = <_ZmanLine>[];

    switch (kind) {
      case _ZmanNoteKind.shema:
        final z = ref.watch(shacharitZmanimProvider).sofZmanShmaGra;
        if (z != null && !now.isBefore(z.subtract(const Duration(hours: 1)))) {
          lines.add(_ZmanLine('סוף זמן קריאת שמע בשעה ${_hm(z)}', 'לפי הגר״א'));
        }
      case _ZmanNoteKind.tefila:
        final z = ref.watch(shacharitZmanimProvider).sofZmanTfilaGra;
        if (z != null && !now.isBefore(z.subtract(const Duration(hours: 1)))) {
          lines.add(_ZmanLine('סוף זמן תפילה בשעה ${_hm(z)}', 'לפי הגר״א'));
        }
      case _ZmanNoteKind.maariv:
        final zm = ref.watch(maarivZmanimProvider);
        final sunset = zm.sunset;
        final tzeit = zm.tzeit;
        final chatzot = zm.chatzotNight;
        if (sunset != null &&
            tzeit != null &&
            !now.isBefore(sunset.subtract(const Duration(minutes: 30)))) {
          lines.add(_ZmanLine(
              'צאת הכוכבים בשעה ${_hm(tzeit)}', '18 דק׳ אחרי השקיעה'));
        }
        if (chatzot != null &&
            !now.isBefore(chatzot.subtract(const Duration(hours: 1)))) {
          lines.add(_ZmanLine('חצות הלילה בשעה ${_hm(chatzot)}', null));
        }
    }

    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final l in lines) l.build()],
      ),
    );
  }
}

class _ZmanLine {
  const _ZmanLine(this.main, this.qualifier);
  final String main;
  final String? qualifier;

  Widget build() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: main,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              if (qualifier != null)
                TextSpan(
                  text: '  ($qualifier)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
      );
}

// ── Group item (accordion) ────────────────────────────────────────────────────

class _GroupItem extends _ListItem {
  _GroupItem({
    required this.groupId,
    required this.title,
    required this.segments,
    required Map<String, int> counts,
    required Set<String> satisfiedGroups,
    required this.itemIndex,
  })  : _key = GlobalKey(),
        _controller = ExpansibleController() {
    // Scan children for nav anchors; update the shared occurrence counter.
    final childKeys = <int, GlobalKey>{};
    final entries = <_NavEntry>[];

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final occ = counts[seg.id] ?? 0;
      counts[seg.id] = occ + 1;

      final spec = _findNavSpec(seg.id, occ, satisfiedGroups);
      if (spec != null) {
        final key = GlobalKey();
        childKeys[i] = key;
        entries.add(_NavEntry(
          label: spec.label,
          key: key,
          onBeforeScroll: _controller.expand,
          itemIndex: itemIndex, // group's position in the full list
          totalItems: _totalItems,
        ));
      }
    }

    _childKeys = childKeys;
    _childNavEntries = entries;
  }

  final String groupId;
  final String title;
  final List<AssembledSegment> segments;
  final int itemIndex;
  final GlobalKey _key;
  final ExpansibleController _controller;
  late final Map<int, GlobalKey> _childKeys;
  late final List<_NavEntry> _childNavEntries;
  // Set after the full list is built.
  int _totalItems = 1;

  List<_NavEntry> get childNavEntries => _childNavEntries;

  @override
  Widget build(BuildContext context) => _GroupAccordion(
        key: _key,
        groupId: groupId,
        title: title,
        segments: segments,
        controller: _controller,
        childKeys: _childKeys,
      );
}

// ── Group accordion widget ────────────────────────────────────────────────────

class _GroupAccordion extends ConsumerStatefulWidget {
  const _GroupAccordion({
    super.key,
    required this.groupId,
    required this.title,
    required this.segments,
    required this.controller,
    required this.childKeys,
  });

  final String groupId;
  final String title;
  final List<AssembledSegment> segments;
  final ExpansibleController controller;
  final Map<int, GlobalKey> childKeys;

  @override
  ConsumerState<_GroupAccordion> createState() => _GroupAccordionState();
}

class _GroupAccordionState extends ConsumerState<_GroupAccordion> {
  late bool _expanded;

  // Persist key for the group's open/closed state (distinct from segment IDs).
  String get _persistKey => 'group:${widget.groupId}';

  @override
  void initState() {
    super.initState();
    // Default-open groups start expanded; the user can still collapse them.
    final defaultOpen = _defaultOpenGroups.contains(widget.groupId);
    _expanded =
        defaultOpen || ref.read(expandedSegmentsProvider).contains(_persistKey);
  }

  @override
  Widget build(BuildContext context) {
    // Group titles scale with the prayer-text font factor, like segment labels.
    final factor = ref.watch(fontSizeFactorProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            controller: widget.controller,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: _expanded,
            shape: const Border(),
            collapsedShape: const Border(),
            onExpansionChanged: (v) {
              setState(() => _expanded = v);
              final saved =
                  ref.read(expandedSegmentsProvider).contains(_persistKey);
              if (v != saved) {
                ref.read(expandedSegmentsProvider.notifier).toggle(_persistKey);
              }
            },
            title: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 20 * factor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14 * factor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  // No hint text — the arrow icon already signals tappability.
                ],
              ),
            ),
            children: _buildChildren(),
          ),
        ),
      ),
    );
  }

  /// Builds the group's children, coalescing consecutive segments that share a
  /// non-empty subGroupId into a single nested accordion (e.g. vidui inside
  /// tachanun). Plain segments render as individual [PrayerTextWidget]s.
  List<Widget> _buildChildren() {
    final segs = widget.segments;
    final out = <Widget>[];
    var i = 0;
    while (i < segs.length) {
      final sub = segs[i].subGroupId;
      if (sub.isNotEmpty) {
        final run = <AssembledSegment>[];
        while (i < segs.length && segs[i].subGroupId == sub) {
          run.add(segs[i]);
          i++;
        }
        out.add(_SubGroupAccordion(subGroupId: sub, segments: run));
      } else {
        out.add(PrayerTextWidget(
          key: widget.childKeys[i],
          segment: segs[i],
        ));
        i++;
      }
    }
    return out;
  }
}

// ── Nested sub-group accordion ────────────────────────────────────────────────
// A second-level accordion rendered INSIDE a group accordion (e.g. the
// "וידוי וי״ג מידות" block inside the open "תחנון" group). Title from
// [_subGroupTitles]; default open/closed from [_subGroupDefaultOpen]; open
// state persisted under a 'subgroup:<id>' key.

class _SubGroupAccordion extends ConsumerStatefulWidget {
  const _SubGroupAccordion({
    required this.subGroupId,
    required this.segments,
  });

  final String subGroupId;
  final List<AssembledSegment> segments;

  @override
  ConsumerState<_SubGroupAccordion> createState() => _SubGroupAccordionState();
}

class _SubGroupAccordionState extends ConsumerState<_SubGroupAccordion> {
  late bool _expanded;

  String get _persistKey => 'subgroup:${widget.subGroupId}';

  @override
  void initState() {
    super.initState();
    final defaultOpen = _subGroupDefaultOpen.contains(widget.subGroupId);
    _expanded =
        defaultOpen || ref.read(expandedSegmentsProvider).contains(_persistKey);
  }

  @override
  Widget build(BuildContext context) {
    final factor = ref.watch(fontSizeFactorProvider);
    final title = _subGroupTitles[widget.subGroupId] ?? widget.subGroupId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: _expanded,
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (v) {
            setState(() => _expanded = v);
            final saved =
                ref.read(expandedSegmentsProvider).contains(_persistKey);
            if (v != saved) {
              ref.read(expandedSegmentsProvider.notifier).toggle(_persistKey);
            }
          },
          title: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                  size: 18 * factor,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13 * factor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final seg in widget.segments) PrayerTextWidget(segment: seg),
          ],
        ),
      ),
    );
  }
}

// ── Nav FAB ───────────────────────────────────────────────────────────────────

class _NavFab extends StatelessWidget {
  const _NavFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.primary,
          size: 26,
        ),
      ),
    );
  }
}

// ── Navigation entry ──────────────────────────────────────────────────────────

class _NavEntry {
  const _NavEntry({
    required this.label,
    required this.key,
    this.onBeforeScroll,
    this.itemIndex = 0,
    this.totalItems = 1,
  });

  final String label;
  final GlobalKey key;

  /// Called before scrolling (e.g., to expand an accordion). The nav sheet
  /// waits 350 ms after the call to allow the animation to complete.
  final VoidCallback? onBeforeScroll;

  /// Position of this item in the full assembled list — used for fallback
  /// scroll estimation when the widget is off-screen.
  final int itemIndex;
  final int totalItems;
}

// ── Navigation sheet ──────────────────────────────────────────────────────────

class _NavSheet extends StatelessWidget {
  const _NavSheet({
    required this.title,
    required this.entries,
    required this.scrollController,
  });

  final String title;
  final List<_NavEntry> entries;
  final ScrollController scrollController;

  Future<void> _jumpTo(BuildContext context, _NavEntry entry) async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));

    final beforeScroll = entry.onBeforeScroll;
    if (beforeScroll != null) {
      beforeScroll();
      await Future.delayed(const Duration(milliseconds: 350));
    }

    final ctx = entry.key.currentContext;
    if (ctx == null || !ctx.mounted) return;

    // Compute the exact scroll offset that brings the target to the top of the
    // viewport, then subtract the pinned app bar's collapsed height so the
    // section lands just BELOW the app bar instead of behind it.
    // Because the list is rendered eagerly (Column in SliverToBoxAdapter),
    // every nav target's render object is always available — no estimation.
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return;
    final viewport = RenderAbstractViewport.of(box);
    final revealOffset = viewport.getOffsetToReveal(box, 0.0).offset;
    const pinnedAppBarHeight = kToolbarHeight;
    final target = (revealOffset - pinnedAppBarHeight)
        .clamp(0.0, scrollController.position.maxScrollExtent);

    await scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sheetScroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.format_list_bulleted,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.black54,
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: ListView.separated(
                controller: sheetScroll,
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, i) {
                  final entry = entries[i];
                  return InkWell(
                    onTap: () => _jumpTo(context, entry),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.chevron_left,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.label,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
