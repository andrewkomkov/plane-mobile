class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final String? avatar;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        displayName: json['display_name'] ?? '',
        avatar: json['avatar'],
      );
}
