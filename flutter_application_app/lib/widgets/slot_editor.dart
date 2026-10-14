import 'package:flutter/material.dart';
import '../models/schedule_slot.dart';
import '../services/schedule_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/errors.dart';
import 'cartes.dart';
import 'feedback.dart';

/// Feuille d'ajout / modification d'un créneau récurrent pour l'élève [uid].
/// Enregistre (ou supprime) directement via [ScheduleService].
Future<void> showSlotEditor(BuildContext context, {required String uid, ScheduleSlot? initial}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SlotEditor(uid: uid, initial: initial),
  );
}

class _SlotEditor extends StatefulWidget {
  final String uid;
  final ScheduleSlot? initial;
  const _SlotEditor({required this.uid, this.initial});

  @override
  State<_SlotEditor> createState() => _SlotEditorState();
}

class _SlotEditorState extends State<_SlotEditor> {
  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late SlotKind _kind = widget.initial?.kind ?? SlotKind.cours;
  // Création : type « Cours » par défaut → du lundi au vendredi.
  late final Set<int> _days = widget.initial?.weekdays.toSet() ?? {1, 2, 3, 4, 5};
  late int _start = widget.initial?.startMinutes ?? 8 * 60 + 30;
  late int? _end = widget.initial == null ? 12 * 60 : widget.initial!.endMinutes;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Valeurs par défaut pratiques selon le type choisi (en création uniquement).
  void _pickKind(SlotKind k) {
    setState(() {
      _kind = k;
      if (_editing) return;
      switch (k) {
        case SlotKind.cours:
          _start = 8 * 60 + 30;
          _end = 12 * 60;
          _days
            ..clear()
            ..addAll({1, 2, 3, 4, 5});
        case SlotKind.travail:
          _start = 9 * 60;
          _end = 17 * 60;
          _days
            ..clear()
            ..addAll({1, 2, 3, 4, 5});
        case SlotKind.sommeil:
          _start = 23 * 60;
          _end = null;
          _days
            ..clear()
            ..addAll({1, 2, 3, 4, 5, 6, 7});
        case SlotKind.activite:
        case SlotKind.autre:
          break;
      }
    });
  }

  Future<int?> _pickTime(int initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _save() async {
    if (_days.isEmpty) return setState(() => _error = 'Choisis au moins un jour.');
    if (_end != null && _end! <= _start) {
      return setState(() => _error = "L'heure de fin doit être après l'heure de début.");
    }
    final slot = ScheduleSlot(
      id: widget.initial?.id ?? '',
      title: _title.text.trim().isEmpty ? _kind.label : _title.text.trim(),
      kind: _kind,
      weekdays: _days.toList()..sort(),
      startMinutes: _start,
      endMinutes: _end,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ScheduleService();
      if (_editing) {
        await service.updateSlot(widget.uid, slot);
      } else {
        await service.createSlot(widget.uid, slot);
      }
      if (!mounted) return;
      showToast(context, _editing ? 'Créneau modifié' : 'Créneau ajouté · ${formatWeekdays(slot.weekdays)}');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final s = widget.initial!;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce créneau ?',
      message: '« ${s.title} » (${formatWeekdays(s.weekdays)}, ${formatMinutes(s.startMinutes)}) '
          'disparaîtra de toutes les semaines.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) return;
    try {
      await ScheduleService().deleteSlot(widget.uid, s.id);
      if (!mounted) return;
      showToast(context, 'Créneau supprimé');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppText.upper(_editing ? 'Modifier le créneau' : 'Nouveau créneau'), style: AppText.barTitle),
            const SizedBox(height: 4),
            const Text('Il se répète chaque semaine, les jours choisis.', style: AppText.caption),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in SlotKind.values)
                  ChoiceChip(
                    label: Text('${k.emoji} ${k.label}'),
                    selected: _kind == k,
                    onSelected: (_) => _pickKind(k),
                    showCheckmark: false,
                    selectedColor: AppColors.accent.withValues(alpha: 0.25),
                    backgroundColor: AppColors.card,
                    side: BorderSide(color: _kind == k ? AppColors.accent : AppColors.border),
                    labelStyle: AppText.bodyText.copyWith(fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80, // même limite que les règles Firestore
              style: AppText.bodyText,
              decoration: InputDecoration(labelText: 'Intitulé (optionnel)', hintText: _kind.label, counterText: ''),
            ),
            const SectionLabel('Jours'),
            Row(
              children: [
                for (int d = 1; d <= 7; d++) ...[
                  Expanded(
                    child: _DayToggle(
                      letter: _letters[d - 1],
                      selected: _days.contains(d),
                      onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                    ),
                  ),
                  if (d < 7) const SizedBox(width: 6),
                ],
              ],
            ),
            const SectionLabel('Horaires'),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Début',
                    value: formatMinutes(_start),
                    onTap: () async {
                      final v = await _pickTime(_start);
                      if (v != null) setState(() => _start = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: 'Fin (optionnel)',
                    value: _end == null ? '—' : formatMinutes(_end!),
                    onTap: () async {
                      final v = await _pickTime(_end ?? (_start + 60).clamp(0, 24 * 60 - 1));
                      if (v != null) setState(() => _end = v);
                    },
                    onClear: _end == null ? null : () => setState(() => _end = null),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.caption.copyWith(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(label: _editing ? 'Enregistrer' : 'Ajouter le créneau', loading: _saving, onPressed: _save),
            if (_editing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _delete,
                child: const Text('Supprimer ce créneau', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String letter;
  final bool selected;
  final VoidCallback onTap;
  const _DayToggle({required this.letter, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Text(letter, style: AppText.itemTitle.copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _TimeTile({required this.label, required this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: AppText.itemTitle),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}
