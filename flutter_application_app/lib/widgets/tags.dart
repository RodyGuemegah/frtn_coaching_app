import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TagStyle { today, active, neutral }

/// Petite pastille arrondie (ex: "Aujourd'hui · 18h00", "En cours", "À venir").
class TagChip extends StatelessWidget {
  final String label;
  final TagStyle style;

  const TagChip(this.label, {super.key, this.style = TagStyle.neutral});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (style) {
      case TagStyle.today:
        bg = AppColors.accent;
        fg = Colors.white;
        break;
      case TagStyle.active:
        bg = AppColors.accent.withValues(alpha: 0.14);
        fg = AppColors.accent2;
        break;
      case TagStyle.neutral:
        bg = Colors.white.withValues(alpha: 0.08);
        fg = const Color(0xFFC9C9D0);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
