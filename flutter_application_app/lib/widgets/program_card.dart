import 'package:flutter/material.dart';
import '../models/program.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/format.dart';
import '../utils/program_stats.dart';
import 'cartes.dart';
import 'tags.dart';

/// Carte « Objectif du programme » façon maquette : titre, statut,
/// « Semaine 6 sur 12 » et barre de progression.
class ProgramCard extends StatelessWidget {
  final Program program;
  final VoidCallback? onTap;

  /// Côté coach : signale visuellement un programme à renouveler.
  final bool showRenewal;
  final bool needsRenewalFlag;

  const ProgramCard({
    super.key,
    required this.program,
    this.onTap,
    this.showRenewal = false,
    this.needsRenewalFlag = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final p = program;
    final status = programStatus(p, now);
    final renew = showRenewal && needsRenewalFlag;
    final (String tag, TagStyle style) = switch (status) {
      _ when renew => ('À renouveler', TagStyle.today),
      ProgramStatus.active => ('En cours', TagStyle.active),
      ProgramStatus.upcoming => ('À venir', TagStyle.neutral),
      ProgramStatus.finished => ('Terminé', TagStyle.neutral),
    };
    final subtitle = switch (status) {
      ProgramStatus.active => 'Semaine ${currentWeek(p, now)} sur ${p.weeks}'
          '${daysLeft(p, now) <= renewalThresholdDays ? ' · fin dans ${daysLeft(p, now)} j' : ''}',
      ProgramStatus.upcoming => 'Commence le ${formatDayLong(p.startDate)} · ${p.weeks} semaines',
      ProgramStatus.finished => 'Terminé le ${formatDayLong(p.lastDay)}',
    };

    return AppCard(
      onTap: onTap,
      decoration: renew
          ? BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: AppText.itemTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TagChip(tag, style: style),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(value: programProgress(p, now)),
          const SizedBox(height: 6),
          Text('${formatDate(p.startDate)} → ${formatDate(p.lastDay)}', style: AppText.caption.copyWith(fontSize: 11)),
          if (p.notes != null) ...[
            const SizedBox(height: 6),
            Text(p.notes!, style: AppText.caption.copyWith(color: AppColors.text)),
          ],
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 8,
        color: AppColors.panel,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(decoration: const BoxDecoration(gradient: AppColors.progressGradient)),
        ),
      ),
    );
  }
}
