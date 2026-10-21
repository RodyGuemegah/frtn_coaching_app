import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/measurement.dart';
import '../../models/program.dart';
import '../../models/session_model.dart';
import '../../services/measurement_service.dart';
import '../../services/program_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../utils/program_report.dart';
import '../../utils/program_stats.dart';
import '../../widgets/cartes.dart';
import '../../widgets/current_user_scope.dart';
import '../../widgets/tags.dart';
import '../../widgets/weight_chart.dart';
import 'program_editor.dart';

/// Bilan d'un programme (terminé ou en cours) : assiduité, semaines,
/// ressentis, évolution physique, objectifs — et renouvellement.
class ProgramReportScreen extends StatefulWidget {
  final AppUser student;
  final Program program;
  const ProgramReportScreen({super.key, required this.student, required this.program});

  @override
  State<ProgramReportScreen> createState() => _ProgramReportScreenState();
}

class _ProgramReportScreenState extends State<ProgramReportScreen> {
  late final Stream<List<SessionModel>> _sessions = SessionService().watchSessions(widget.student.uid);
  late final Stream<List<Measurement>> _measures = MeasurementService().watchMeasurements(widget.student.uid);
  late final Stream<List<Program>> _programs = ProgramService().watchPrograms(widget.student.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppText.upper('Bilan du programme'))),
      body: SafeArea(
        child: StreamBuilder<List<SessionModel>>(
          stream: _sessions,
          builder: (context, sessionSnap) => StreamBuilder<List<Measurement>>(
            stream: _measures,
            builder: (context, measureSnap) => StreamBuilder<List<Program>>(
              stream: _programs,
              builder: (context, programSnap) {
                final error = sessionSnap.error ?? measureSnap.error ?? programSnap.error;
                if (error != null) {
                  return Padding(padding: const EdgeInsets.all(18), child: ErrorCard(message: friendlyErrorMessage(error)));
                }
                if (!sessionSnap.hasData || !measureSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final now = DateTime.now();
                // Version à jour du programme (s'il a été modifié entre-temps).
                final programs = programSnap.data ?? const <Program>[];
                final program = programs.where((p) => p.id == widget.program.id).firstOrNull ?? widget.program;
                final report = programReport(
                  program: program,
                  sessions: sessionSnap.data!,
                  measurements: measureSnap.data!,
                  now: now,
                );
                final renew = needsRenewal(programs, now) && currentProgram(programs, now)?.id == program.id;
                return ProgramReportView(
                  report: report,
                  student: widget.student,
                  onRenew: renew && !widget.student.archived
                      ? () => showProgramEditor(
                            context,
                            student: widget.student,
                            coach: CurrentUserScope.of(context),
                            initial: renewalOf(program, now),
                          )
                      : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenu du bilan (public pour pouvoir être prévisualisé / testé sans Firestore).
class ProgramReportView extends StatelessWidget {
  final ProgramReport report;
  final AppUser student;
  final VoidCallback? onRenew;
  const ProgramReportView({super.key, required this.report, required this.student, this.onRenew});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final p = r.program;
    final now = DateTime.now();
    final (String tag, TagStyle style) = switch (r.status) {
      ProgramStatus.active => ('En cours', TagStyle.active),
      ProgramStatus.upcoming => ('À venir', TagStyle.neutral),
      ProgramStatus.finished => ('Terminé', TagStyle.neutral),
    };
    final dominant = r.dominantFeeling;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        // En-tête
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(AppText.upper(p.title), style: AppText.heroTitle)),
            const SizedBox(width: 8),
            TagChip(tag, style: style),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${student.nameOrEmail} · ${formatDate(p.startDate)} → ${formatDate(p.lastDay)} · ${p.weeks} semaines',
          style: AppText.caption,
        ),
        if (r.status == ProgramStatus.active) ...[
          const SizedBox(height: 12),
          NoticeCard(
            'Bilan intermédiaire — semaine ${currentWeek(p, now)} sur ${p.weeks}. '
            'Les séances à venir ne sont pas comptées.',
            icon: Icons.timelapse_rounded,
          ),
        ],
        const SizedBox(height: 16),

        // Chiffres clés
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            StatTile(value: r.attendancePct == null ? '—' : '${r.attendancePct}%', label: 'Assiduité'),
            StatTile(value: '${r.done}/${r.planned}', label: 'Séances faites'),
            StatTile(value: r.weight == null ? '—' : formatDeltaKg(r.weight!.delta), label: 'Évolution du poids'),
            StatTile(
              value: dominant == null ? '—' : dominant.emoji,
              label: dominant == null ? 'Ressenti dominant' : 'Surtout « ${dominant.label} »',
            ),
          ],
        ),

        // Semaines
        const SectionLabel('Semaine par semaine'),
        AppCard(
          child: r.planned == 0
              ? const Text('Aucune séance n\'a été assignée pendant ce programme.', style: AppText.caption)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WeekBars(weeks: r.weeks, now: now),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        const _Legend(color: AppColors.accent, label: 'Faites'),
                        _Legend(color: AppColors.muted.withValues(alpha: 0.55), label: 'Manquées (${r.missed})'),
                        if (r.upcoming > 0) _Legend(color: AppColors.card2, label: 'À venir (${r.upcoming})', outlined: true),
                      ],
                    ),
                  ],
                ),
        ),

        // Ressentis
        const SectionLabel('Ressentis'),
        AppCard(
          child: r.feelingsCount == 0
              ? const Text('Aucun ressenti laissé par l\'élève sur cette période.', style: AppText.caption)
              : _FeelingsBar(feelings: r.feelings, total: r.feelingsCount),
        ),

        // Évolution physique
        const SectionLabel('Évolution physique'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DeltaRow(label: 'Poids', delta: r.weight, unit: 'kg'),
              _DeltaRow(label: 'Tour de taille', delta: r.waist, unit: 'cm'),
              _DeltaRow(label: 'Masse grasse', delta: r.bodyFat, unit: '%'),
              if (r.measurements.length >= 2) ...[
                const SizedBox(height: 12),
                WeightChart(points: r.measurements, height: 140),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Ajoute au moins une pesée au début et une à la fin pour voir l\'évolution.', style: AppText.caption),
              ],
            ],
          ),
        ),

        // Objectifs
        if (p.notes != null) ...[
          const SectionLabel('Objectifs du programme'),
          AppCard(child: Text(p.notes!, style: AppText.bodyText)),
        ],

        if (onRenew != null) ...[
          const SizedBox(height: 20),
          PrimaryButton(label: '↻ Renouveler le programme', onPressed: onRenew),
        ],
      ],
    );
  }
}

/// Barres empilées par semaine : faites (rouge), manquées (gris), à venir (contour).
class _WeekBars extends StatelessWidget {
  final List<WeekReport> weeks;
  final DateTime now;
  const _WeekBars({required this.weeks, required this.now});

  @override
  Widget build(BuildContext context) {
    final maxPlanned = weeks.fold<int>(1, (m, w) => w.planned > m ? w.planned : m);
    const barArea = 110.0;
    return SizedBox(
      height: barArea + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final w in weeks)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: weeks.length > 10 ? 2 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _stack(w, barArea, maxPlanned),
                    const SizedBox(height: 6),
                    Text(
                      'S${w.week}',
                      style: AppText.caption.copyWith(
                        fontSize: weeks.length > 10 ? 9 : 10.5,
                        color: w.started(now) ? AppColors.muted : AppColors.muted.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stack(WeekReport w, double area, int maxPlanned) {
    final unit = area / maxPlanned;
    final pending = w.planned - w.done - w.missed;
    if (w.planned == 0) {
      return Container(height: 3, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Column(
        children: [
          if (pending > 0)
            Container(
              height: pending * unit,
              decoration: BoxDecoration(
                color: AppColors.card2,
                border: Border.all(color: AppColors.border),
              ),
            ),
          if (w.missed > 0) Container(height: w.missed * unit, color: AppColors.muted.withValues(alpha: 0.55)),
          if (w.done > 0)
            Container(
              height: w.done * unit,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.accentDark, AppColors.accent],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;
  const _Legend({required this.color, required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined ? Border.all(color: AppColors.border) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.caption.copyWith(fontSize: 11.5)),
      ],
    );
  }
}

/// Jauge horizontale de répartition des ressentis + légende chiffrée.
class _FeelingsBar extends StatelessWidget {
  final Map<Ressenti, int> feelings;
  final int total;
  const _FeelingsBar({required this.feelings, required this.total});

  static Color _color(Ressenti r) => switch (r) {
    Ressenti.facile => const Color(0xFF2FD07A),
    Ressenti.correct => const Color(0xFFF5B83D),
    Ressenti.difficile => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final r in Ressenti.values)
                  if ((feelings[r] ?? 0) > 0) Expanded(flex: feelings[r]!, child: Container(color: _color(r))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final r in Ressenti.values)
              Expanded(
                child: Column(
                  children: [
                    Text(r.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(
                      '${feelings[r] ?? 0} · ${((feelings[r] ?? 0) * 100 / total).round()}%',
                      style: AppText.itemTitle.copyWith(fontSize: 13),
                    ),
                    Text(r.label, style: AppText.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final String label;
  final MeasureDelta? delta;
  final String unit;
  const _DeltaRow({required this.label, required this.delta, required this.unit});

  @override
  Widget build(BuildContext context) {
    final d = delta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.bodyText)),
          if (d == null)
            const Text('—', style: AppText.caption)
          else ...[
            Text('${formatKg(d.start)} → ${formatKg(d.end)} $unit', style: AppText.caption),
            const SizedBox(width: 10),
            TagChip(
              '${d.delta > 0 ? '+' : (d.delta < 0 ? '−' : '=')}${formatKg(d.delta.abs())} $unit',
              style: TagStyle.neutral,
            ),
          ],
        ],
      ),
    );
  }
}
