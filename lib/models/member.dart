class Member {
  final String id;
  final String memberId;
  final String displayName;
  final String email;
  final String? avatar;
  final int role;

  Member({
    required this.id,
    required this.memberId,
    required this.displayName,
    required this.email,
    this.avatar,
    required this.role,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    final memberDetail = json['member'] as Map<String, dynamic>?;
    return Member(
      id: json['id'] ?? '',
      memberId: memberDetail?['id'] ?? json['member']?.toString() ?? '',
      displayName: memberDetail?['display_name'] ?? json['display_name'] ?? '',
      email: memberDetail?['email'] ?? json['email'] ?? '',
      avatar: memberDetail?['avatar'] ?? json['avatar'],
      role: json['role'] ?? 10,
    );
  }
}
