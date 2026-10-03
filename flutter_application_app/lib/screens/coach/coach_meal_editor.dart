import 'package:flutter/material.dart';
import '../../models/meal_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/cartes.dart';

/// Bottom sheet de création / édition d'un repas pour la journée [day].
/// Retourne le repas saisi (id vide en création) ou `null` si annulé.
Future<MealModel?> showMealEditor(BuildContext context, {required DateTime day, MealModel? initial}) {
  return showModalBottomSheet<MealModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _MealEditor(day: day, initial: initial),
  );
}

class _MealEditor extends StatefulWidget {
  final DateTime day;
  final MealModel? initial;
  const _MealEditor({required this.day, this.initial});

  @override
  State<_MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<_MealEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late final _protein = TextEditingController(text: _initNum(widget.initial?.protein));
  late final _carbs = TextEditingController(text: _initNum(widget.initial?.carbs));
  late final _fat = TextEditingController(text: _initNum(widget.initial?.fat));
  late final _kcal = TextEditingController(text: _initNum(widget.initial?.kcal));
  late TimeOfDay _time = widget.initial != null
      ? TimeOfDay(hour: widget.initial!.date.hour, minute: widget.initial!.date.minute)
      : const TimeOfDay(hour: 12, minute: 30);

  static String _initNum(int? v) => v == null || v == 0 ? '' : '$v';

  @override
  void initState() {
    super.initState();
    for (final c in [_protein, _carbs, _fat]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _protein, _carbs, _fat, _kcal]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  int get _estimatedKcal => kcalFromMacros(_int(_protein), _int(_carbs), _int(_fat));

  void _pickSuggestion(String title) {
    setState(() {
      _title.text = title;
      if (widget.initial == null) _time = _defaultTimeFor(title) ?? _time;
    });
  }

  static TimeOfDay? _defaultTimeFor(String title) => switch (title) {
    'Petit-déjeuner' => const TimeOfDay(hour: 7, minute: 30),
    'Déjeuner' => const TimeOfDay(hour: 12, minute: 30),
    'Collation' => const TimeOfDay(hour: 16, minute: 30),
    'Dîner' => const TimeOfDay(hour: 20, minute: 0),
    _ => null,
  };

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final date = DateTime(widget.day.year, widget.day.month, widget.day.day, _time.hour, _time.minute);
    final kcal = _kcal.text.trim().isEmpty ? _estimatedKcal : _int(_kcal);
    final desc = _description.text.trim();
    Navigator.of(context).pop(MealModel(
      id: widget.initial?.id ?? '',
      title: _title.text.trim(),
      time: formatTime(date),
      date: date,
      description: desc.isEmpty ? null : desc,
      kcal: kcal,
      protein: _int(_protein),
      carbs: _int(_carbs),
      fat: _int(_fat),
      eaten: widget.initial?.eaten ?? false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 20, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? 'Modifier le repas' : 'Nouveau repas',
                  style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(formatDayLong(widget.day), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in mealTitleSuggestions)
                    ChoiceChip(
                      label: Text(s),
                      selected: _title.text == s,
                      onSelected: (_) => _pickSuggestion(s),
                      selectedColor: AppColors.accent.withValues(alpha: 0.25),
                      backgroundColor: AppColors.card,
                      side: BorderSide(color: _title.text == s ? AppColors.accent : AppColors.border),
                      labelStyle: const TextStyle(color: AppColors.text, fontSize: 12),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(labelText: 'Repas *'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppCard(
                      onTap: _pickTime,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_outlined, size: 18, color: AppColors.muted),
                          const SizedBox(width: 8),
                          Text('${_time.hour.toString().padLeft(2, '0')}h${_time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: AppColors.text, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Contenu (optionnel)',
                  hintText: 'Poulet 180 g, riz complet 100 g, brocolis',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_protein, 'Prot. (g)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_carbs, 'Gluc. (g)')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_fat, 'Lip. (g)')),
                ],
              ),
              const SizedBox(height: 10),
              _numField(
                _kcal,
                'Calories (kcal)',
                hint: _estimatedKcal > 0 ? '$_estimatedKcal (calculé depuis les macros)' : 'Calculées depuis les macros si vide',
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: editing ? 'Enregistrer' : 'Ajouter le repas', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, {String? hint}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return null;
        final n = int.tryParse(s);
        if (n == null || n < 0) return 'Nombre';
        return null;
      },
    );
  }
}
