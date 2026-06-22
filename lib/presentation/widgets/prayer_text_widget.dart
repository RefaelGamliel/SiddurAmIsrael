import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:siddur_am_israel_chai/domain/entities/assembled_segment.dart';
import 'package:siddur_am_israel_chai/domain/entities/omer_day.dart';
import 'package:siddur_am_israel_chai/domain/entities/user_context.dart';
import 'package:siddur_am_israel_chai/presentation/constants/segment_labels.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';
import 'package:siddur_am_israel_chai/presentation/theme/app_colors.dart';
import 'package:siddur_am_israel_chai/presentation/widgets/rich_prayer_text.dart';

// Optional segments that should start EXPANDED (open accordion by default).
const _initiallyExpanded = <String>{
  'birkat_kohanim_bracha',
  // Mon/Thu "יהי רצון" before the 2nd Ashrei (Ashkenaz + Sfard).
  'yehi_ratzon_mon_thu',
  // "למנצח" in Edot Mizrach Shacharit (optional only on the EM template).
  'lamenatzeach',
  // End-of-selichot block ("א-ל רחום שמך…") on fast days (Ashkenaz/Sfard).
  'selichot_shared_7',
};

// Segments that are part of a tight block: no trailing spacer so consecutive
// segments flow without visual gaps. (Continuous in-line flow of a single
// blessing is handled upstream by the flow-group merge in the providers; these
// sets only tune the vertical spacing between the resulting blocks.)
const _noTrailingSpace = <String>{
  'chatzi_kaddish_header',
  'kaddish_derabanan_header',
  'kaddish_yatom_header',
  'kaddish_titkabal_header',
  'kaddish_body',
  'kaddish_closing',
  'kaddish_derabanan_paragraph',
  'kaddish_titkabal_paragraph',
  // אין כאלהינו flows directly into אתה הוא שהקטירו
  'ein_keloheinu',
  // Me'ein Shalosh — chips attach tightly to the opening text; the opening,
  // date insertion and closing stack with just a line break between them.
  'inline_toggle_meein',
  'ms_opening',
};

// Segments that get extra bottom padding (typically the last segment of a flow).
const _extraBottomPadding = <String>{
  // Extra whitespace after the al hakos optional block at the end of BHM.
  'bhm_kos_bpg',
  // Extra whitespace after the sheva brachot block (before BPG).
  'bhm_sheva_kos',
  'bhm_em_sheva_kos',
};

// Segments whose top padding is suppressed (they follow a tight predecessor).
const _noTopPadding = <String>{
  // Me'ein Shalosh: opening below the chips; date / closing follow with just
  // a line break (no larger gap).
  'ms_opening',
  'ms_date_rc',
  'ms_date_chm_pesach',
  'ms_date_chm_sukkot',
  'ms_kiatah',
};

/// Compact inline toggle row rendered inside the prayer scroll view.
class _PrayerInlineToggle extends ConsumerWidget {
  const _PrayerInlineToggle({required this.segmentId});
  final String segmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tallit toggle: segmented control (not a simple on/off switch)
    if (segmentId == 'inline_toggle_tallit_gadol') {
      return _buildTallitSegmented(ref);
    }
    // Kohanim toggle: section title + switch with "יש כהנים" label
    if (segmentId == 'inline_toggle_kohanim') {
      return _buildKohanumToggle(ref);
    }
    // Birkat HaMazon meal-type selector (שבע ברכות / ברית מילה).
    // "רגילה" is not shown — it is the implicit default when nothing is
    // selected. Tapping the active chip deselects it (resets to regular).
    if (segmentId == 'inline_toggle_meal_type') {
      final value = ref.watch(mealTypeProvider);
      const options = [
        (MealType.shevaBrachot, 'שבע ברכות'),
        (MealType.britMilah, 'ברית מילה'),
      ];
      return _buildSegmentedChoice<MealType>(
        current: value,
        options: options,
        onSelect: (v) {
          // Tap selected chip → deselect (regular). Tap other → select.
          final next = v == value ? MealType.regular : v;
          ref.read(mealTypeProvider.notifier).set(next);
        },
      );
    }
    // Me'ein Shalosh: multi-select food types + small Eretz-Yisrael toggles.
    if (segmentId == 'inline_toggle_meein') {
      return _buildMeeinToggle(ref);
    }
    final (label, value, onChanged) = _resolve(ref);
    return _InlineCheckRow(
      label: label,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildKohanumToggle(WidgetRef ref) {
    final einKohanim = ref.watch(einKohanimProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Text(
                'ברכת כהנים',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryDarker,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _InlineCheckRow(
                label: 'אין כהנים',
                value: einKohanim,
                onChanged: (v) {
                  ref.read(einKohanimProvider.notifier).state = v;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTallitSegmented(WidgetRef ref) {
    final isGadol = ref.watch(wearsTallitGadolProvider);
    final activeStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryDarker,
    );
    final inactiveStyle = TextStyle(
      fontSize: 13,
      color: AppColors.primaryDarker.withValues(alpha: 0.45),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            // Right label (RTL first = visual right): עטיפת טלית
            GestureDetector(
              onTap: () =>
                  ref.read(wearsTallitGadolProvider.notifier).set(true),
              child: Text('עטיפת טלית',
                  style: isGadol ? activeStyle : inactiveStyle),
            ),
            const SizedBox(width: 8),
            Switch(
              value: !isGadol, // RTL flips knob direction → invert value
              onChanged: (v) =>
                  ref.read(wearsTallitGadolProvider.notifier).set(!v),
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 8),
            // Left label: ברכת ציצית
            GestureDetector(
              onTap: () =>
                  ref.read(wearsTallitGadolProvider.notifier).set(false),
              child: Text('ברכת ציצית',
                  style: !isGadol ? activeStyle : inactiveStyle),
            ),
          ],
        ),
      ),
    );
  }

  /// Generic multi-option chip row for transient meal-context choices.
  /// Renders each option as a tappable pill; the selected one is filled.
  Widget _buildSegmentedChoice<T>({
    required T current,
    required List<(T, String)> options,
    required void Function(T) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        textDirection: TextDirection.rtl,
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () => onSelect(value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: value == current
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: value == current
                        ? AppColors.primary
                        : AppColors.borderLight,
                  ),
                ),
                child: Text(
                  label,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        value == current ? FontWeight.w700 : FontWeight.w500,
                    color: value == current
                        ? Colors.white
                        : AppColors.primaryDarker,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Me'ein Shalosh selector: a multi-select row of food types (mezonot /
  /// gefen / perot) plus, beneath it, small unobtrusive Eretz-Yisrael
  /// provenance toggles that appear only for the selected types (the grain
  /// toggle only in Edot HaMizrach).
  Widget _buildMeeinToggle(WidgetRef ref) {
    final types = ref.watch(meeinTypesProvider);
    final nusach = ref.watch(nusachProvider);
    final gefenEy = ref.watch(meeinGefenEyProvider);
    final perotEy = ref.watch(meeinPerotEyProvider);
    final mezonotEy = ref.watch(meeinMezonotEyProvider);

    void toggleType(MeeinType t) {
      final next = {...types};
      next.contains(t) ? next.remove(t) : next.add(t);
      if (next.isEmpty) return; // always keep at least one type selected
      ref.read(meeinTypesProvider.notifier).set(next);
    }

    Widget typeChip(MeeinType t, String label) {
      final selected = types.contains(t);
      return GestureDetector(
        onTap: () => toggleType(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight,
            ),
          ),
          child: Text(
            label,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.primaryDarker,
            ),
          ),
        ),
      );
    }

    // Small, low-emphasis provenance toggle (filled = Eretz Yisrael).
    Widget eyChip(String label, bool value, void Function(bool) onChanged) {
      return GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: value
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? AppColors.primary : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                value ? Icons.check_circle : Icons.circle_outlined,
                size: 13,
                color: value ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 12,
                  color: value ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final eyToggles = <Widget>[
      if (types.contains(MeeinType.mezonot) && nusach == 'edot_mizrach')
        eyChip('מזונות מארץ ישראל', mezonotEy,
            (v) => ref.read(meeinMezonotEyProvider.notifier).set(v)),
      if (types.contains(MeeinType.gefen))
        eyChip('יין מארץ ישראל', gefenEy,
            (v) => ref.read(meeinGefenEyProvider.notifier).set(v)),
      if (types.contains(MeeinType.perot))
        eyChip('פירות מארץ ישראל', perotEy,
            (v) => ref.read(meeinPerotEyProvider.notifier).set(v)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            textDirection: TextDirection.rtl,
            children: [
              typeChip(MeeinType.mezonot, 'מזונות'),
              typeChip(MeeinType.gefen, 'גפן'),
              typeChip(MeeinType.perot, 'פירות'),
            ],
          ),
          if (eyToggles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              textDirection: TextDirection.rtl,
              children: eyToggles,
            ),
          ],
        ],
      ),
    );
  }

  (String, bool, void Function(bool)) _resolve(WidgetRef ref) {
    switch (segmentId) {
      case 'inline_toggle_tallit_gadol':
        // Rendered as segmented control (see _buildInlineToggle override below)
        return ('', false, (_) {});
      case 'inline_toggle_shaliach_tzibbur':
        return (
          'אני שליח ציבור',
          ref.watch(isShaliachTzibburProvider),
          (v) => ref.read(isShaliachTzibburProvider.notifier).set(v),
        );
      case 'inline_toggle_kohanim':
        return (
          'אין כהנים',
          ref.watch(einKohanimProvider),
          (v) => ref.read(einKohanimProvider.notifier).state = v,
        );
      default:
        return ('', false, (_) {});
    }
  }
}

const _inlineToggleIds = {
  'inline_toggle_tallit_gadol',
  'inline_toggle_shaliach_tzibbur',
  'inline_toggle_kohanim',
  'inline_toggle_meal_type',
  'inline_toggle_meein',
};

/// Compact checkbox row used for in-prayer boolean choices (e.g. "אין כהנים",
/// "אני שליח ציבור", "אין תחנון"). Label is on the right (RTL), checkbox on the
/// left. The entire row is tappable.
class _InlineCheckRow extends StatelessWidget {
  const _InlineCheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            Text(
              label,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 14,
                color: value
                    ? AppColors.primaryDarker
                    : AppColors.primaryDarker.withValues(alpha: 0.55),
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class PrayerTextWidget extends ConsumerWidget {
  const PrayerTextWidget({super.key, required this.segment});

  final AssembledSegment segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inline toggle markers render as compact toggle rows, not prayer text.
    if (_inlineToggleIds.contains(segment.id)) {
      return _PrayerInlineToggle(segmentId: segment.id);
    }

    final factor = ref.watch(fontSizeFactorProvider);
    final showLabels = ref.watch(showSegmentLabelsProvider);
    final label = segmentLabel(segment.id);
    final bodyStyle = GoogleFonts.notoSerifHebrew(
      fontSize: 22 * factor,
      height: 1.5,
      color: Colors.black87,
    );

    if (segment.optional) {
      final tile = _OptionalSegmentTile(
        label: label,
        factor: factor,
        bodyStyle: bodyStyle,
        segment: segment,
        initiallyExpanded: _initiallyExpanded.contains(segment.id),
      );
      if (_extraBottomPadding.contains(segment.id)) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: tile,
        );
      }
      return tile;
    }

    // Pure nav-anchor segments (empty body + no visible label, e.g.
    // `tachanun_header`) occupy no vertical space. They still attach their
    // GlobalKey so the section-nav jump can scroll to them.
    if (segment.resolvedText.isEmpty && label.isEmpty) {
      return const SizedBox.shrink();
    }

    final noTrailing = _noTrailingSpace.contains(segment.id);
    final noTop = _noTopPadding.contains(segment.id);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, noTop ? 0 : 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLabels && label.isNotEmpty) ...[
            Text(
              label,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 14 * factor,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (segment.resolvedText.isNotEmpty)
            RichPrayerText(text: segment.resolvedText, style: bodyStyle),
          if (segment.id == 'sefirat_haomer_day_count') _OmerSummary(factor: factor),
          SizedBox(height: noTrailing ? 2
              : _extraBottomPadding.contains(segment.id) ? 36
              : 16),
        ],
      ),
    );
  }
}

/// Renders an [AssembledSegment] whose `optional` flag is true as a
/// collapsed accordion. The user sees a stylized header (label + chevron
/// + hint) and taps to expand. Use for community-specific or alternate
/// minhag content (e.g. Gr"a Shir Shel Yom variants, alternate L'shem
/// Yichud forms) that shouldn't be in the main reading flow by default.
class _OptionalSegmentTile extends ConsumerStatefulWidget {
  const _OptionalSegmentTile({
    required this.label,
    required this.factor,
    required this.bodyStyle,
    required this.segment,
    this.initiallyExpanded = false,
  });

  final String label;
  final double factor;
  final TextStyle bodyStyle;
  final AssembledSegment segment;
  final bool initiallyExpanded;

  @override
  ConsumerState<_OptionalSegmentTile> createState() =>
      _OptionalSegmentTileState();
}

class _OptionalSegmentTileState extends ConsumerState<_OptionalSegmentTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Start expanded if the hardcoded default OR the user previously opened it.
    final saved = ref.read(expandedSegmentsProvider);
    _expanded = widget.initiallyExpanded || saved.contains(widget.segment.id);
  }

  /// Returns the text to display in the accordion header.
  /// If the label is non-empty, use it. Otherwise, take the first two words
  /// of the segment's resolved text as a preview.
  String get _headerText {
    if (widget.label.isNotEmpty) return widget.label;
    final raw = widget.segment.resolvedText
        .replaceAll(RegExp(r'<[^>]+>'), '') // strip tags
        .trim();
    final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 14 * widget.factor,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
      letterSpacing: 0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4, bottom: 12),
          initiallyExpanded: widget.initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (v) {
            setState(() => _expanded = v);
            ref.read(expandedSegmentsProvider.notifier).toggle(widget.segment.id);
          },
          title: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20 * widget.factor,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _headerText,
                    style: headerStyle,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
          children: [
            RichPrayerText(
              text: widget.segment.resolvedText,
              style: widget.bodyStyle,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderLight),
          ],
        ),
      ),
    );
  }
}

class _OmerSummary extends ConsumerWidget {
  const _OmerSummary({required this.factor});

  final double factor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentOmerDayProvider);
    return async.when(
      data: (day) => day == null ? const SizedBox.shrink() : _summary(day),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _summary(OmerDay day) {
    final labelStyle = TextStyle(
      fontSize: 13 * factor,
      color: AppColors.textSecondary,
    );
    final valueStyle = TextStyle(
      fontSize: 15 * factor,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    Widget pair(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, textDirection: TextDirection.rtl, style: labelStyle),
            const SizedBox(height: 2),
            Text(value, textDirection: TextDirection.rtl, style: valueStyle),
          ],
        );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 24,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              pair('ספירה', day.sefira),
              pair('אנא בכח', day.anaWord),
              pair('למנצח', day.lamenatzeachWord),
              pair('ישמחו', day.yismechuLetter),
            ],
          ),
        ),
      ),
    );
  }
}
