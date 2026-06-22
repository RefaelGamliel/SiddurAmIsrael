import 'package:freezed_annotation/freezed_annotation.dart';

part 'assembled_segment.freezed.dart';

@freezed
class AssembledSegment with _$AssembledSegment {
  const factory AssembledSegment({
    required String id,
    required String resolvedText,
    @Default(false) bool optional,
    // Non-empty when this segment belongs to a collapsible group (e.g.
    // 'chazarat_hashatz'). Consecutive segments with the same groupId are
    // rendered as a single accordion by the presentation layer.
    @Default('') String groupId,
    // Non-empty when this segment belongs to a nested sub-accordion INSIDE its
    // group (e.g. 'vidui' inside the 'tachanun' group). Consecutive segments
    // with the same subGroupId render as one nested accordion.
    @Default('') String subGroupId,
  }) = _AssembledSegment;
}
