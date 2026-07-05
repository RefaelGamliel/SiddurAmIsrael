import 'package:freezed_annotation/freezed_annotation.dart';

part 'prayer_template.freezed.dart';
part 'prayer_template.g.dart';

@freezed
class PrayerTemplate with _$PrayerTemplate {
  const factory PrayerTemplate({
    required String id,
    required String name,
    required List<TemplateEntry> segments,
  }) = _PrayerTemplate;

  factory PrayerTemplate.fromJson(Map<String, dynamic> json) =>
      _$PrayerTemplateFromJson(json);
}

@freezed
class TemplateEntry with _$TemplateEntry {
  const factory TemplateEntry({
    @Default('') @JsonKey(name: 'segment_id') String segmentId,
    @Default('') @JsonKey(name: 'sub_template_id') String subTemplateId,
    @Default([]) @JsonKey(name: 'condition_flags') List<String> conditionFlags,
    @Default([]) @JsonKey(name: 'exclude_flags') List<String> excludeFlags,
    @Default(false) bool optional,
    // Empty list means the segment is valid for ALL nusachim.
    // Non-empty: the segment is skipped unless userContext.nusach is listed here.
    @Default([]) @JsonKey(name: 'allowed_nusach') List<String> allowedNusach,
    // Non-empty: all segments produced by this entry (and any sub-template
    // expansion) will carry this groupId, causing them to be grouped into a
    // single collapsible accordion in the presentation layer.
    @Default('') @JsonKey(name: 'group_id') String groupId,
    // Non-empty: segments produced by this entry carry this subGroupId, and the
    // presentation layer renders consecutive same-subGroupId segments INSIDE a
    // group accordion as one nested accordion (e.g. vidui inside tachanun).
    @Default('') @JsonKey(name: 'sub_group_id') String subGroupId,
  }) = _TemplateEntry;

  factory TemplateEntry.fromJson(Map<String, dynamic> json) =>
      _$TemplateEntryFromJson(json);
}
