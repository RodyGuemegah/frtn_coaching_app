import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/measurement.dart';
import '../services/measurement_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/progress_stats.dart';
import '../utils/validators.dart';
import '../widgets/cartes.dart';
import '../widgets/feedback.dart';
import '../widgets/tags.dart';
import '../widgets/weight_chart.dart';

/// « Mesures & progrès » d'un élève (même écran pour l'élève et son coach).
class MeasurementsScreen extends StatefulWidget {
  final AppUser student;
  final bool coachMode;
  const MeasurementsScreen({super.key, required this.student, this.coachMode = false});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  late final Stream<List<Measurement>> _stream = MeasurementService().watchMeasurements(widget.student.uid);
  ChartRange _range = ChartRange.quarter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppText.upper(widget.coachMode ? 'Progrès · ${widget.student.shortName}' : 'Mes progrès')),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Measurement>>(
          stream: _stream,
          builder: (context, snap) {
            final all = snap.data ?? const <Measurement>[];
            final now = DateTime.now();
            final summary = progressSummary(all, now);
            final deltas = deltasWithPrevious(all);
            final history = sortedByDate(all).reversed.toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                if (snap.hasError) ...[
                  ErrorCard(message: friendlyErrorMessage(snap.error!)),
                  const SizedBox(height: 12),
                ],
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
                else if (summary.isEmpty)
                  _EmptyState(coachMode: widget.coachMode, name: widget.student.shortName)
                else ...[
                  _SummaryTiles(summary: summary),
                  const SectionLabel('Évolution du poids'),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(10, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final r in ChartRange.values) ...[
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text(r.label),
                                selected: _range == r,
                                onSelected: (_) => setState(() => _range = r),
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                selectedColor: AppColors.accent.withValues(alpha: 0.25),
                                backgroundColor: AppColors.panel,
                                side: BorderSide(color: _range == r ? AppColors.accent : AppColors.border),
                                labelStyle: AppText.caption.copyWith(color: AppColors.text, fontSize: 11.5),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        WeightChart(points: measurementsInRange(all, _range, now)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                PrimaryButton(
                  label: '+ Ajouter une mesure',
                  onPressed: () => showMeasurementEditor(context, uid: widget.student.uid, all: all),
                ),
                if (history.isNotEmpty) ...[
                  const SectionLabel('Historique'),
                  for (final m in history)
                    _MeasurementRow(
                      measurement: m,
                      delta: deltas[m.id],
                      onTap: () => showMeasurementEditor(context, uid: widget.student.uid, all: all, initial: m),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  final ProgressSummary summary;
  const _SummaryTiles({required this.summary});

  @override
  Widget build(BuildContext context) {
    final latest = summary.latest!;
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            StatTile(value: '${formatKg(latest.weightKg)} kg', label: 'Poids actuel'),
            StatTile(
              value: summary.totalDeltaKg == null ? '—' : formatDeltaKg(summary.totalDeltaKg!),
              label: 'Depuis le ${formatDate(summary.first!.date)}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(child: Text('Dernière mesure : ${formatDayLong(latest.date)}', style: AppText.caption)),
              if (summary.last30DaysDeltaKg != null)
                TagChip('${formatDeltaKg(summary.last30DaysDeltaKg!)} / 30 j', style: TagStyle.neutral),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final Measurement measurement;
  final num? delta;
  final VoidCallback onTap;
  const _MeasurementRow({required this.measurement, required this.delta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final extras = [
      if (m.waistCm != null) 'Taille ${formatKg(m.waistCm!)} cm',
      if (m.bodyFatPct != null) 'MG ${formatKg(m.bodyFatPct!)} %',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${formatKg(m.weightKg)} kg', style: AppText.itemTitle),
                  const SizedBox(height: 2),
                  Text(
                    [formatDayLong(m.date), ...extras].join(' · '),
                    style: AppText.caption,
                  ),
                  if (m.note != null) ...[
                    const SizedBox(height: 4),
                    Text('« ${m.note} »', style: AppText.caption.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            if (delta != null) TagChip(formatDeltaKg(delta!), style: TagStyle.neutral),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool coachMode;
  final String name;
  const _EmptyState({required this.coachMode, required this.name});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Text('📈', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(AppText.upper('Aucune mesure'), style: AppText.barTitle),
          const SizedBox(height: 6),
          Text(
            coachMode
                ? 'Ajoute la première pesée de $name pour suivre son évolution.'
                : 'Ajoute ta première pesée : tu suivras ton évolution semaine après semaine.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Carte « Suivi du poids » réutilisable (Profil élève, fiche coach) :
/// mini-courbe + dernier poids + évolution, ouvre l'écran complet au toucher.
class WeightSummaryCard extends StatefulWidget {
  final AppUser student;
  final bool coachMode;
  const WeightSummaryCard({super.key, required this.student, this.coachMode = false});

  @override
  State<WeightSummaryCard> createState() => _WeightSummaryCardState();
}

class _WeightSummaryCardState extends State<WeightSummaryCard> {
  late final Stream<List<Measurement>> _stream = MeasurementService().watchMeasurements(widget.student.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Measurement>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Measurement>[];
        final summary = progressSummary(all, DateTime.now());
        return AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MeasurementsScreen(student: widget.student, coachMode: widget.coachMode),
          )),
          child: summary.isEmpty
              ? Row(
                  children: [
                    const Text('📈', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        snap.hasError ? friendlyErrorMessage(snap.error!) : 'Aucune pesée pour l\'instant — ajoute la première.',
                        style: AppText.caption,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('${formatKg(summary.latest!.weightKg)} kg', style: AppText.number.copyWith(fontSize: 24)),
                        const SizedBox(width: 10),
                        if (summary.totalDeltaKg != null)
                          TagChip(formatDeltaKg(summary.totalDeltaKg!), style: TagStyle.active),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 8),
                    WeightChart(points: sortedByDate(all), height: 70, compact: true),
                    const SizedBox(height: 6),
                    Text(
                      summary.first!.id == summary.latest!.id
                          ? 'Pesée du ${formatDate(summary.latest!.date)}'
                          : '${formatDate(summary.first!.date)} → ${formatDate(summary.latest!.date)} : '
                              '${formatKg(summary.first!.weightKg)} kg → ${formatKg(summary.latest!.weightKg)} kg',
                      style: AppText.caption,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Feuille d'ajout / modification d'une mesure. [all] = mesures existantes
/// (pour savoir si la nouvelle est la plus récente → synchro du poids du profil).
Future<void> showMeasurementEditor(
  BuildContext context, {
  required String uid,
  required List<Measurement> all,
  Measurement? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MeasurementEditor(uid: uid, all: all, initial: initial),
  );
}

class _MeasurementEditor extends StatefulWidget {
  final String uid;
  final List<Measurement> all;
  final Measurement? initial;
  const _MeasurementEditor({required this.uid, required this.all, this.initial});

  @override
  State<_MeasurementEditor> createState() => _MeasurementEditorState();
}

class _MeasurementEditorState extends State<_MeasurementEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late final _weight = TextEditingController(text: widget.initial == null ? '' : formatKg(widget.initial!.weightKg));
  late final _waist = TextEditingController(text: widget.initial?.waistCm == null ? '' : formatKg(widget.initial!.waistCm!));
  late final _fat = TextEditingController(text: widget.initial?.bodyFatPct == null ? '' : formatKg(widget.initial!.bodyFatPct!));
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  bool _saving = false;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    for (final c in [_weight, _waist, _fat, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now, // pas de mesure dans le futur
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final m = Measurement(
      id: widget.initial?.id ?? '',
      date: _date,
      weightKg: parseUserNumber(_weight.text)!,
      waistCm: parseUserNumber(_waist.text),
      bodyFatPct: parseUserNumber(_fat.text),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    setState(() => _saving = true);
    try {
      await MeasurementService().saveMeasurement(widget.uid, m, syncProfileWeight: isLatest(m, widget.all));
      if (!mounted) return;
      showToast(context, _editing ? 'Mesure modifiée' : 'Pesée enregistrée : ${formatKg(m.weightKg)} kg');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final m = widget.initial!;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cette mesure ?',
      message: '${formatKg(m.weightKg)} kg du ${formatDayLong(m.date)} disparaîtra de l\'historique et du graphique.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) return;
    try {
      await MeasurementService().deleteMeasurement(widget.uid, m.id);
      if (!mounted) return;
      showToast(context, 'Mesure supprimée');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppText.upper(_editing ? 'Modifier la mesure' : 'Nouvelle mesure'), style: AppText.barTitle),
              const SizedBox(height: 14),
              AppCard(
                onTap: _pickDate,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSameDay(_date, DateTime.now()) ? "Aujourd'hui" : formatDayLong(_date),
                        style: AppText.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weight,
                autofocus: !_editing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInput(),
                validator: requiredWeightValidator,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: AppText.bodyText,
                decoration: const InputDecoration(labelText: 'Poids (kg) *', hintText: '71,2', errorMaxLines: 2),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _waist,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalInput(),
                      validator: waistValidator,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: AppText.bodyText,
                      decoration: const InputDecoration(labelText: 'Tour de taille (cm)', errorMaxLines: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalInput(maxIntDigits: 2),
                      validator: bodyFatValidator,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: AppText.bodyText,
                      decoration: const InputDecoration(labelText: 'Masse grasse (%)', errorMaxLines: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.bodyText,
                decoration: const InputDecoration(labelText: 'Note (optionnel)', hintText: 'À jeun, après la séance…', counterText: ''),
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: _editing ? 'Enregistrer' : 'Ajouter la mesure', loading: _saving, onPressed: _save),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _delete,
                  child: const Text('Supprimer cette mesure', style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
