class Label {
  final String id;
  final String name;
  final String color;

  Label({required this.id, required this.name, required this.color});

  factory Label.fromJson(Map<String, dynamic> json) => Label(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        color: json['color'] ?? '#999',
      );
}
