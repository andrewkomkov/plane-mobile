class IssueState {
  final String id;
  final String name;
  final String color;
  final String group;
  final int sequence;

  IssueState({
    required this.id,
    required this.name,
    required this.color,
    required this.group,
    required this.sequence,
  });

  factory IssueState.fromJson(Map<String, dynamic> json) => IssueState(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        color: json['color'] ?? '#999',
        group: json['group'] ?? 'backlog',
        sequence: (json['sequence'] ?? 0).toInt(),
      );
}
