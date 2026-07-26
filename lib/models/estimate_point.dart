/// One selectable estimate value on a project.
///
/// Plane models estimates in two layers: a project has at most one `Estimate`
/// (a named scale, e.g. "Points" or "T-shirt"), and that scale owns an ordered
/// set of `EstimatePoint`s, which are the values a work item can actually
/// hold. A work item's `estimate_point` is a foreign key to one of these, not
/// a number — so the id is what gets written and [value] is only ever a label.
class EstimatePoint {
  final String id;

  /// Sort position within the scale. The server does not guarantee the list
  /// arrives ordered, so this is what the picker sorts on.
  final int key;

  /// What to show. Free text, capped at 20 characters server-side, so it can
  /// be "8" on a points scale or "M" on a t-shirt one.
  final String value;

  final String? description;

  const EstimatePoint({
    required this.id,
    required this.key,
    required this.value,
    this.description,
  });

  factory EstimatePoint.fromJson(Map<String, dynamic> json) => EstimatePoint(
        id: json['id']?.toString() ?? '',
        key: json['key'] is int
            ? json['key'] as int
            : int.tryParse(json['key']?.toString() ?? '') ?? 0,
        value: json['value']?.toString() ?? '',
        description: json['description']?.toString(),
      );
}
