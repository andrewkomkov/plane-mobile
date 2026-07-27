class Attachment {
  final String id;
  final String? filename;
  final int? size;
  final String? asset;
  final DateTime createdAt;

  Attachment({
    required this.id,
    this.filename,
    this.size,
    this.asset,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    return Attachment(
      id: json['id'] ?? '',
      filename: attributes['name'] as String? ?? json['attributes']?.toString(),
      size: attributes['size'] as int?,
      asset: json['asset'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get displaySize {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
