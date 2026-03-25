import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Base shimmer mixin — provides a repeating opacity animation (0.3 → 0.7)
// ---------------------------------------------------------------------------
mixin _ShimmerMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  void initShimmer() {
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shimmerAnimation =
        Tween<double>(begin: 0.3, end: 0.7).animate(_shimmerController);
  }

  void disposeShimmer() {
    _shimmerController.dispose();
  }

  Animation<double> get shimmer => _shimmerAnimation;
}

// ---------------------------------------------------------------------------
// Primitive building blocks (private)
// ---------------------------------------------------------------------------
class _SkeletonCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _SkeletonCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final Color color;
  final double radius;
  const _SkeletonBox({
    this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Original skeleton list item (kept for backward compatibility)
// ---------------------------------------------------------------------------
class SkeletonListItem extends StatefulWidget {
  const SkeletonListItem({super.key});

  @override
  State<SkeletonListItem> createState() => _SkeletonListItemState();
}

class _SkeletonListItemState extends State<SkeletonListItem>
    with SingleTickerProviderStateMixin, _ShimmerMixin {
  @override
  void initState() {
    super.initState();
    initShimmer();
  }

  @override
  void dispose() {
    disposeShimmer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        final color = baseColor.withValues(alpha: shimmer.value);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _SkeletonCircle(size: 16, color: color),
              const SizedBox(width: 10),
              _SkeletonCircle(size: 16, color: color),
              const SizedBox(width: 10),
              _SkeletonBox(width: 50, height: 12, color: color),
              const SizedBox(width: 10),
              Expanded(child: _SkeletonBox(height: 14, color: color)),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;

  const SkeletonList({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => const SkeletonListItem(),
    );
  }
}

// ---------------------------------------------------------------------------
// IssueListSkeleton — mimics a list of issue tiles
// ---------------------------------------------------------------------------
class IssueListSkeleton extends StatefulWidget {
  final int itemCount;
  const IssueListSkeleton({super.key, this.itemCount = 6});

  @override
  State<IssueListSkeleton> createState() => _IssueListSkeletonState();
}

class _IssueListSkeletonState extends State<IssueListSkeleton>
    with SingleTickerProviderStateMixin, _ShimmerMixin {
  @override
  void initState() {
    super.initState();
    initShimmer();
  }

  @override
  void dispose() {
    disposeShimmer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final color = baseColor.withValues(alpha: shimmer.value);
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.itemCount,
          itemBuilder: (_, i) {
            // Vary the title width for a more natural look
            final titleFraction = [0.75, 0.60, 0.85, 0.50, 0.70, 0.65][i % 6];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: Row(
                children: [
                  // Priority icon placeholder
                  _SkeletonCircle(size: 16, color: color),
                  const SizedBox(width: 8),
                  // State icon placeholder
                  _SkeletonCircle(size: 16, color: color),
                  const SizedBox(width: 10),
                  // Issue ID placeholder
                  _SkeletonBox(width: 48, height: 12, color: color),
                  const SizedBox(width: 10),
                  // Title placeholder
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: titleFraction,
                      child: _SkeletonBox(height: 14, color: color),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ProjectListSkeleton — mimics project / cycle / module list tiles
// ---------------------------------------------------------------------------
class ProjectListSkeleton extends StatefulWidget {
  final int itemCount;
  const ProjectListSkeleton({super.key, this.itemCount = 5});

  @override
  State<ProjectListSkeleton> createState() => _ProjectListSkeletonState();
}

class _ProjectListSkeletonState extends State<ProjectListSkeleton>
    with SingleTickerProviderStateMixin, _ShimmerMixin {
  @override
  void initState() {
    super.initState();
    initShimmer();
  }

  @override
  void dispose() {
    disposeShimmer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final color = baseColor.withValues(alpha: shimmer.value);
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.itemCount,
          padding: const EdgeInsets.only(top: 4),
          itemBuilder: (_, i) {
            final nameFraction = [0.65, 0.80, 0.55, 0.70, 0.60][i % 5];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: shimmer.value * 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Identifier badge placeholder
                    _SkeletonBox(
                        width: 40, height: 40, color: color, radius: 10),
                    const SizedBox(width: 14),
                    // Name + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: nameFraction,
                            child: _SkeletonBox(height: 14, color: color),
                          ),
                          const SizedBox(height: 6),
                          _SkeletonBox(
                              width: 90, height: 10, color: color),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SkeletonBox(width: 16, height: 16, color: color),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// IssueDetailSkeleton — mimics issue detail layout
// ---------------------------------------------------------------------------
class IssueDetailSkeleton extends StatefulWidget {
  const IssueDetailSkeleton({super.key});

  @override
  State<IssueDetailSkeleton> createState() => _IssueDetailSkeletonState();
}

class _IssueDetailSkeletonState extends State<IssueDetailSkeleton>
    with SingleTickerProviderStateMixin, _ShimmerMixin {
  @override
  void initState() {
    super.initState();
    initShimmer();
  }

  @override
  void dispose() {
    disposeShimmer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final color = baseColor.withValues(alpha: shimmer.value);
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title bar
              _SkeletonBox(height: 22, color: color),
              const SizedBox(height: 8),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.6,
                child: _SkeletonBox(height: 22, color: color),
              ),
              const SizedBox(height: 20),
              // Chips row (status, priority, assignee)
              Row(
                children: [
                  _SkeletonBox(width: 80, height: 28, color: color),
                  const SizedBox(width: 8),
                  _SkeletonBox(width: 72, height: 28, color: color),
                  const SizedBox(width: 8),
                  _SkeletonBox(width: 96, height: 28, color: color),
                ],
              ),
              const SizedBox(height: 24),
              // Description block
              _SkeletonBox(height: 14, color: color),
              const SizedBox(height: 8),
              _SkeletonBox(height: 14, color: color),
              const SizedBox(height: 8),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.75,
                child: _SkeletonBox(height: 14, color: color),
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.45,
                child: _SkeletonBox(height: 14, color: color),
              ),
              const SizedBox(height: 32),
              // Activity items
              for (int i = 0; i < 3; i++) ...[
                Row(
                  children: [
                    _SkeletonCircle(size: 28, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: [0.55, 0.70, 0.45][i],
                            child: _SkeletonBox(height: 12, color: color),
                          ),
                          const SizedBox(height: 4),
                          _SkeletonBox(
                              width: 60, height: 10, color: color),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// InboxSkeleton — mimics inbox notification list
// ---------------------------------------------------------------------------
class InboxSkeleton extends StatefulWidget {
  final int itemCount;
  const InboxSkeleton({super.key, this.itemCount = 6});

  @override
  State<InboxSkeleton> createState() => _InboxSkeletonState();
}

class _InboxSkeletonState extends State<InboxSkeleton>
    with SingleTickerProviderStateMixin, _ShimmerMixin {
  @override
  void initState() {
    super.initState();
    initShimmer();
  }

  @override
  void dispose() {
    disposeShimmer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final color = baseColor.withValues(alpha: shimmer.value);
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.itemCount,
          separatorBuilder: (_, __) =>
              Divider(indent: 60, endIndent: 20, height: 0.5),
          itemBuilder: (_, i) {
            final titleFraction =
                [0.70, 0.55, 0.80, 0.60, 0.75, 0.50][i % 6];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: Row(
                children: [
                  // Priority icon
                  _SkeletonCircle(size: 16, color: color),
                  const SizedBox(width: 8),
                  // State icon
                  _SkeletonCircle(size: 16, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: titleFraction,
                          child: _SkeletonBox(height: 14, color: color),
                        ),
                        const SizedBox(height: 6),
                        // Activity subtitle
                        _SkeletonBox(
                            width: 140, height: 10, color: color),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time ago
                  _SkeletonBox(width: 28, height: 10, color: color),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
