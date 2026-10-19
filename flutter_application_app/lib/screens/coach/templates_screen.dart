import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../models/session_template.dart';
import '../../services/template_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/errors.dart';
import '../../widgets/cartes.dart';
import '../../widgets/current_user_scope.dart';
import '../../widgets/feedback.dart';
import 'coach_create_session.dart';
import 'template_picker.dart' show TemplateRow;

/// « Mes modèles » : bibliothèque des séances types du coach.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  Stream<List<SessionTemplate>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= TemplateService().watchTemplates(CurrentUserScope.of(context).uid);
  }

  void _open([SessionTemplate? t]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateEditorScreen(initial: t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppText.upper('Mes modèles'))),
      body: SafeArea(
        child: StreamBuilder<List<SessionTemplate>>(
          stream: _stream,
          builder: (context, snap) {
            final templates = snap.data ?? const <SessionTemplate>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Text(
                  'Tes séances types, réutilisables avec « Partir d\'un modèle » lors de la création d\'une séance.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: '+ Nouveau modèle', onPressed: () => _open()),
                const SizedBox(height: 16),
                if (snap.hasError)
                  ErrorCard(message: friendlyErrorMessage(snap.error!))
                else if (!snap.hasData)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                else if (templates.isEmpty)
                  const NoticeCard(
                    'Aucun modèle. Crée-en un ici, ou depuis une séance existante : ⋮ → « Enregistrer comme modèle ».',
                    icon: Icons.bookmark_border_rounded,
                  )
                else
                  for (final t in templates) TemplateRow(template: t, onTap: () => _open(t)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Création / modification d'un modèle : nom, durée, consigne et exercices.
class TemplateEditorScreen extends StatefulWidget {
  /// Modèle à modifier ; `null` = nouveau modèle.
  final SessionTemplate? initial;
  const TemplateEditorScreen({super.key, this.initial});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _duration = TextEditingController(text: widget.initial?.durationMin?.toString() ?? '');
  late final _note = TextEditingController(text: widget.initial?.coachNote ?? '');
  late final List<Exercise> _exercises = List.of(widget.initial?.exercises ?? const <Exercise>[]);
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final ex = await showExerciseDialog(context);
    if (ex != null) setState(() => _exercises.add(ex));
  }

  Future<void> _editExercise(int i) async {
    final ex = await showExerciseDialog(context, initial: _exercises[i]);
    if (ex != null) setState(() => _exercises[i] = ex);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Donne un nom au modèle.');
    if (_exercises.isEmpty) return setState(() => _error = 'Ajoute au moins un exercice.');
    final coach = CurrentUserScope.of(context);
    final template = SessionTemplate(
      id: widget.initial?.id ?? '',
      title: title,
      durationMin: int.tryParse(_duration.text.trim()),
      coachNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      exercises: List.of(_exercises),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = TemplateService();
      if (_editing) {
        await service.updateTemplate(coach.uid, template);
      } else {
        await service.createTemplate(coach.uid, template);
      }
      if (!mounted) return;
      showToast(context, _editing ? 'Modèle « $title » modifié' : 'Modèle « $title » créé');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final t = widget.initial!;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer ce modèle ?',
      message: '« ${t.title} » disparaîtra de ta bibliothèque. Les séances déjà créées avec ce modèle ne changent pas.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !mounted) return;
    try {
      await TemplateService().deleteTemplate(CurrentUserScope.of(context).uid, t.id);
      if (!mounted) return;
      showToast(context, 'Modèle supprimé');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppText.upper(_editing ? 'Modifier le modèle' : 'Nouveau modèle')),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            TextField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.bodyText,
              decoration: const InputDecoration(labelText: 'Nom du modèle *', hintText: 'Haut du corps — Force', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              style: AppText.bodyText,
              decoration: const InputDecoration(labelText: 'Durée estimée (min, optionnel)', hintText: '55'),
            ),
            const SectionLabel('Exercices'),
            if (_exercises.isEmpty)
              const NoticeCard('Aucun exercice pour l\'instant.', icon: Icons.fitness_center_outlined)
            else
              for (int i = 0; i < _exercises.length; i++)
                ExerciseRow(
                  index: i + 1,
                  name: _exercises[i].name,
                  detail: _exercises[i].label,
                  onTap: () => _editExercise(i),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    onPressed: () => setState(() => _exercises.removeAt(i)),
                  ),
                ),
            const SizedBox(height: 6),
            GhostButton(label: '+ Ajouter un exercice', onPressed: _addExercise),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.bodyText,
              decoration: const InputDecoration(labelText: "Consigne pour l'élève (optionnel)"),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.caption.copyWith(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(label: _editing ? 'Enregistrer' : 'Créer le modèle', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
