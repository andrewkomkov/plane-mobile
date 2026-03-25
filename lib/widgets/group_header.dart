import 'package:flutter/material.dart';
import 'section_header.dart';

/// Backward-compatible wrapper around [SectionHeader].
/// All new code should use [SectionHeader] directly.
class GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const GroupHeader({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      label: label,
      count: count,
      color: color,
    );
  }
}
