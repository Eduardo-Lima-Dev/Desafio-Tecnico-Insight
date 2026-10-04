import 'package:flutter/material.dart';

class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class RoomListSkeleton extends StatelessWidget {
  const RoomListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando conversas',
      child: ExcludeSemantics(
        child: SkeletonPulse(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 7,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const SkeletonBox(width: 48, height: 48, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 90.0 + (index % 3) * 30, height: 14),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: double.infinity, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({super.key});

  static const List<({bool own, double width})> _rows = [
    (own: false, width: 220.0),
    (own: false, width: 300.0),
    (own: true, width: 180.0),
    (own: false, width: 260.0),
    (own: true, width: 240.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando mensagens',
      child: ExcludeSemantics(
        child: SkeletonPulse(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              for (final row in _rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: row.own
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: SkeletonBox(
                      width: row.width,
                      height: 44,
                      radius: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
