class Member {
  final String id;
  final String displayName;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatar;

  Member({
    required this.id,
    required this.displayName,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] ?? '',
        displayName: json['display_name'] ?? '',
        email: json['email'] ?? '',
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        avatar: json['avatar'],
      );
}
