import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/program.dart';
import '../../services/program_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/cartes.dart';
import '../../widgets/feedback.dart';

const _titleSuggestions = ['Prise de masse', 'Perte de poids', 'Remise en forme', 'Performance', 'Préparation physique'];
const _weekChoices = [4, 6, 8, 12, 16];

/// Feuille de création / modification / renouvellement d'un programme.
/// - [initial] avec un id : modification (suppression possible) ;
/// - [initial] sans id : pré-remplissage (renouvellement) ;
/// - rien : nouveau programme.
Future<void> showProgramEditor(
  BuildContext context, {
  required AppUser student,
  required AppUser coach,
  Program? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProgramEditor(student: student, coach: coach, initial: initial),
  );
}

class _ProgramEditor extends StatefulWidget {
  final AppUser student;
  final AppUser coach;
  final Program? initial;
  const _ProgramEditor({required this.student, required this.coach, this.initial});

  @override
  State<_ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends State<_ProgramEditor> {
  late final _title = TextEditingController(text: widget.initial?.title ?? widget.student.goal ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late DateTime _start = widget.initial?.startDate ?? DateTime.now();
  late int _weeks = widget.initial?.weeks ?? 12;
  bool _saving = false;
  String? _error;

  bool get _editing => (widget.initial?.id ?? '').isNotEmpty;
  bool get _renewing => widget.initial != null && !_editing;

  Program get _draft => Program(
        id: widget.initial?.id ?? '',
        title: _title.text.trim(),
        startDate: DateTime(_start.year, _start.month, _start.day),
        weeks: _weeks,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        studentId: widget.student.uid,
        coachId: widget.coach.uid,
      );

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return setState(() => _error = 'Donne un nom au programme.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProgramService().saveProgram(widget.student.uid, _draft);
      if (!mounted) return;
      showToast(
        context,
        _editing
            ? 'Programme modifié'
            : 'Programme « ${_title.text.trim()} » créé pour ${widget.student.shortName}',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final p = widget.initial!;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce programme ?',
      message: '« ${p.title} » sera retiré du suivi de ${widget.student.shortName}. '
          'Les séances déjà assignées ne sont pas supprimées.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) return;
    try {
      await ProgramService().deleteProgram(widget.student.uid, p.id);
      if (!mounted) return;
      showToast(context, 'Programme supprimé');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final heading = _editing ? 'Modifier le programme' : (_renewing ? 'Renouveler le programme' : 'Nouveau programme');
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppText.upper(heading), style: AppText.barTitle),
            const SizedBox(height: 4),
            Text('Pour ${widget.student.nameOrEmail}', style: AppText.caption),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _titleSuggestions)
                  ChoiceChip(
                    label: Text(t),
                    selected: _title.text.trim() == t,
                    onSelected: (_) => _title.text = t,
                    showCheckmark: false,
                    selectedColor: AppColors.accent.withValues(alpha: 0.25),
                    backgroundColor: AppColors.card,
                    side: BorderSide(color: _title.text.trim() == t ? AppColors.accent : AppColors.border),
                    labelStyle: AppText.bodyText.copyWith(fontSize: 12.5),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.bodyText,
              decoration: const InputDecoration(
                labelText: 'Nom du programme *',
                hintText: 'Prise de masse — Phase 2',
                counterText: '',
              ),
            ),
            const SectionLabel('Début'),
            AppCard(
              onTap: _pickStart,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(formatDayLong(_start), style: AppText.bodyText)),
                ],
              ),
            ),
            const SectionLabel('Durée'),
            Row(
              children: [
                for (final w in _weekChoices) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: SizedBox(width: double.infinity, child: Text('$w sem.', textAlign: TextAlign.center)),
                      selected: _weeks == w,
                      onSelected: (_) => setState(() => _weeks = w),
                      showCheckmark: false,
                      selectedColor: AppColors.accent.withValues(alpha: 0.25),
                      backgroundColor: AppColors.card,
                      side: BorderSide(color: _weeks == w ? AppColors.accent : AppColors.border),
                      labelStyle: AppText.bodyText.copyWith(fontSize: 12),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (w != _weekChoices.last) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _weeks > 1 ? () => setState(() => _weeks--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text('$_weeks semaine${_weeks > 1 ? 's' : ''}', textAlign: TextAlign.center, style: AppText.itemTitle),
                ),
                IconButton(
                  onPressed: _weeks < 52 ? () => setState(() => _weeks++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            NoticeCard(
              'Du ${formatDayLong(draft.startDate)} au ${formatDayLong(draft.lastDay)}',
              icon: Icons.date_range_outlined,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.bodyText,
              decoration: const InputDecoration(
                labelText: 'Objectifs / notes (optionnel)',
                hintText: '+2 kg de masse maigre, 4 séances par semaine…',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppText.caption.copyWith(color: Colors.redAccent)),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: _editing ? 'Enregistrer' : (_renewing ? '↻ Lancer la suite' : 'Créer le programme'),
              loading: _saving,
              onPressed: _save,
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _delete,
                child: const Text('Supprimer ce programme', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
