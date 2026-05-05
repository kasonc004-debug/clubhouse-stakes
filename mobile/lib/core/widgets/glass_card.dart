import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Translucent surface card matching the Apple-dark-glass spec —
/// 4% white fill, 8% white hairline border, 22px radius by default.
///
/// Pass [accent] to swap the border for a gold ring (used to highlight
/// the active item or a primary CTA target).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool accent;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.accent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = accent
        ? AppColors.gold.withValues(alpha: 0.45)
        : AppColors.glassBorder();
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.glassFill(),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: accent ? 1.4 : 1),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Section eyebrow: ALL-CAPS, 11pt, letter-spaced. Pairs with a numeric
/// stat or large headline below.
class GlassEyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const GlassEyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color ?? AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      );
}
