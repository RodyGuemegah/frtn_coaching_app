import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/session_model.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/cartes.dart';
import '../../widgets/current_user_scope.dart';
import 'coach_add_student.dart';

/// Version « page » (route poussée, avec AppBar) du formulaire de création.
class CoachCreateSessionScreen extends StatelessWidget {
  final List<AppUser> students;
  final String? preselectedStudentId;

  const CoachCreateSessionScreen({super.key, required this.students, this.preselectedStudentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.accent,
        title: const Text('Nouvelle séance', style: TextStyle(color: AppColors.text)),
      ),
      body: SafeArea(
        child: CoachCreateSessionForm(
          students: students,
          preselectedStudentId: preselectedStudentId,
          showTitle: false,
          onSubmitted: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// Formulaire de création d'une séance (utilisé en onglet et en page).
class CoachCreateSessionForm extends StatefulWidget {
  final List<AppUser> students;
  final String? preselectedStudentId;
  final bool showTitle;
  final VoidCallback? onSubmitted;

  const CoachCreateSessionForm({
    super.key,
    required this.students,
    this.preselectedStudentId,
    this.showTitle = true,
    this.onSubmitted,
  });

  @override
  State<CoachCreateSessionForm> createState() => _CoachCreateSessionFormState();
}

class _CoachCreateSessionFormState extends State<CoachCreateSessionForm> {
  String? _studentId;
  final _title = TextEditingController();
  final _duration = TextEditingController();
  final _note = TextEditingController();
  DateTime? _when;
  final List<Exercise> _exercises = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _studentId = widget.preselectedStudentId;
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final base = _when ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, base.hour, base.minute));
  }

  Future<void> _pickTime() async {
    final base = _when ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (time == null) return;
    setState(() => _when = DateTime(base.year, base.month, base.day, time.hour, time.minute));
  }

  Future<void> _addExercise() async {
    final ex = await showDialog<Exercise>(context: context, builder: (_) => const _ExerciseDialog());
    if (ex != null) setState(() => _exercises.add(ex));
  }

  Future<void> _submit() async {
    if (_saving) return;
    final me = CurrentUserScope.of(context);
    final studentId = _studentId;
    final title = _title.text.trim();
    final when = _when;

    String? error;
    if (studentId == null) {
      error = 'Choisis un élève.';
    } else if (title.isEmpty) {
      error = 'Donne un nom à la séance.';
    } else if (when == null) {
      error = 'Choisis une date et une heure.';
    } else if (_exercises.isEmpty) {
      error = 'Ajoute au moins un exercice.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final student = widget.students.where((s) => s.uid == studentId).toList();
    final studentName = student.isEmpty ? 'l\'élève' : student.first.nameOrEmail;
    final session = SessionModel(
      id: '',
      title: title,
      status: 'todo',
      date: when!,
      coachNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      exercises: List.unmodifiable(_exercises),
      studentId: studentId!,
      coachId: me.uid,
      coachName: me.nameOrEmail,
      durationMin: int.tryParse(_duration.text.trim()),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SessionService().createSession(studentUid: studentId, session: session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Séance « $title » assignée à $studentName')));
      _reset();
      widget.onSubmitted?.call();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _title.clear();
      _duration.clear();
      _note.clear();
      _when = null;
      _exercises.clear();
      _error = null;
      if (widget.preselectedStudentId == null) _studentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.students.map((s) => s.uid).toSet();
    final selected = ids.contains(_studentId) ? _studentId : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        if (widget.showTitle) ...[
          const Text('Nouvelle séance', style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Assigne une séance à un élève', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
        const _FieldLabel('Élève'),
        if (widget.students.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Aucun élève rattaché pour le moment.', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                GhostButton(
                  label: '+ Ajouter un élève',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoachAddStudentScreen())),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            // La clé force une reconstruction quand la sélection est réinitialisée.
            key: ValueKey('student-$selected'),
            initialValue: selected,
            dropdownColor: AppColors.panel,
            style: const TextStyle(color: AppColors.text),
            hint: const Text('Choisir un élève'),
            items: widget.students.map((s) => DropdownMenuItem(value: s.uid, child: Text(s.nameOrEmail))).toList(),
            onChanged: (v) => setState(() => _studentId = v),
          ),
        const _FieldLabel('Nom de la séance'),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(hintText: 'Ex : Haut du corps — Force'),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Date'),
                  _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: _when == null ? 'Choisir' : formatDayShort(_when!),
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Heure'),
                  _PickerTile(
                    icon: Icons.schedule_outlined,
                    label: _when == null ? '--h--' : formatTime(_when!),
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
          ],
        ),
        const _FieldLabel('Durée estimée (min, optionnel)'),
        TextField(
          controller: _duration,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(hintText: '55'),
        ),
        const SectionLabel('Exercices'),
        for (int i = 0; i < _exercises.length; i++)
          ExerciseRow(
            index: i + 1,
            name: _exercises[i].name,
            detail: _exercises[i].label,
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
              onPressed: () => setState(() => _exercises.removeAt(i)),
            ),
          ),
        GhostButton(label: '+ Ajouter un exercice', onPressed: _addExercise),
        const _FieldLabel("Consigne pour l'élève (optionnel)"),
        TextField(
          controller: _note,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(hintText: 'Concentre-toi sur la technique…'),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: '📤 Assigner la séance', loading: _saving, onPressed: _submit),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14))),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    );
  }
}

/// Saisie d'un exercice (nom, séries, reps, charge, repos).
class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog();

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sets = TextEditingController(text: '3');
  final _reps = TextEditingController(text: '10');
  final _load = TextEditingController();
  final _rest = TextEditingController(text: '90');

  @override
  void dispose() {
    for (final c in [_name, _sets, _reps, _load, _rest]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(Exercise(
      name: _name.text.trim(),
      sets: int.parse(_sets.text.trim()),
      reps: int.parse(_reps.text.trim()),
      load: num.tryParse(_load.text.trim().replaceAll(',', '.')) ?? 0,
      restSec: int.tryParse(_rest.text.trim()) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Nouvel exercice', style: TextStyle(color: AppColors.text)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: 'Nom *', hintText: 'Développé couché barre'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_sets, 'Séries *', required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_reps, 'Reps *', required: true)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_load, 'Kg', decimal: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_rest, 'Repos (s)')),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Charge vide = poids du corps', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        TextButton(onPressed: _save, child: const Text('Ajouter')),
      ],
    );
  }

  Widget _numField(TextEditingController c, String label, {bool required = false, bool decimal = false}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final s = (v ?? '').trim().replaceAll(',', '.');
        if (s.isEmpty) return required ? 'Requis' : null;
        final ok = decimal ? num.tryParse(s) != null : int.tryParse(s) != null;
        if (!ok) return 'Nombre';
        if (required && (num.tryParse(s) ?? 0) <= 0) return '> 0';
        return null;
      },
    );
  }
}
