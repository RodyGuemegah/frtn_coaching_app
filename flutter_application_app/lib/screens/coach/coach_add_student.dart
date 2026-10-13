import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/errors.dart';
import '../../utils/validators.dart';
import '../../widgets/cartes.dart';
import '../../widgets/feedback.dart';
import '../../widgets/current_user_scope.dart';

const _goals = ['Prise de masse', 'Perte de poids', 'Remise en forme', 'Performance', 'Autre'];

/// Création d'un compte élève par le coach — ou, avec [initial],
/// modification de la fiche d'un élève existant.
class CoachAddStudentScreen extends StatefulWidget {
  /// Élève à modifier ; `null` = création d'un nouveau compte.
  final AppUser? initial;
  const CoachAddStudentScreen({super.key, this.initial});

  @override
  State<CoachAddStudentScreen> createState() => _CoachAddStudentScreenState();
}

class _CoachAddStudentScreenState extends State<CoachAddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _customGoal = TextEditingController();
  String? _goal;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    if (s == null) return;
    _firstName.text = s.firstName;
    _lastName.text = s.lastName;
    // Anciens profils sans prénom/nom séparés : on découpe le nom affiché.
    if (s.firstName.isEmpty && s.lastName.isEmpty && s.displayName.trim().isNotEmpty) {
      final parts = s.displayName.trim().split(RegExp(r'\s+'));
      _firstName.text = parts.first;
      _lastName.text = parts.skip(1).join(' ');
    }
    _email.text = s.email;
    _age.text = s.age?.toString() ?? '';
    _height.text = s.heightCm?.toString() ?? '';
    _weight.text = s.weightKg == null ? '' : s.weightKg.toString().replaceAll('.', ',');
    if (s.goal != null) {
      // Objectif hors liste → « Autre » + champ libre pré-rempli.
      if (_goals.contains(s.goal) && s.goal != 'Autre') {
        _goal = s.goal;
      } else {
        _goal = 'Autre';
        _customGoal.text = s.goal!;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _age, _height, _weight, _customGoal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_editing) return _saveChanges();
    final coach = CurrentUserScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final goal = _goal == 'Autre' ? _customGoal.text.trim() : _goal;
      final result = await UserService().createStudent(
        coach: coach,
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        age: int.tryParse(_age.text.trim()),
        heightCm: int.tryParse(_height.text.trim()),
        weightKg: parseUserNumber(_weight.text),
        goal: goal == null || goal.isEmpty ? null : goal,
      );
      if (!mounted) return;
      await _showSuccess(result);
      if (mounted) Navigator.of(context).pop(result.student);
    } on StudentCreationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Création impossible, réessaie.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Mode édition : met à jour la fiche (sans toucher à l'email ni au compte).
  Future<void> _saveChanges() async {
    final student = widget.initial!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final goal = _goal == 'Autre' ? _customGoal.text.trim() : _goal;
      await UserService().updateStudentProfile(
        student.uid,
        firstName: _firstName.text,
        lastName: _lastName.text,
        age: int.tryParse(_age.text.trim()),
        heightCm: int.tryParse(_height.text.trim()),
        weightKg: parseUserNumber(_weight.text),
        goal: goal,
      );
      if (!mounted) return;
      showToast(context, 'Fiche de ${_firstName.text.trim()} mise à jour');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSuccess(StudentCreationResult result) {
    final AppUser s = result.student;
    return showSuccessSheet(
      context,
      title: 'Compte créé',
      message: result.resetEmailSent
          ? '${s.nameOrEmail} rejoint ton équipe ! Un email vient de partir à ${s.email} pour choisir son mot de passe.'
          : "Le compte de ${s.nameOrEmail} est créé, mais l'email n'a pas pu être envoyé. "
              "L'élève pourra utiliser « Mot de passe oublié ? » avec ${s.email}.",
      emoji: result.resetEmailSent ? '🎉' : '✓',
      buttonLabel: 'Super',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.accent,
        title: Text(AppText.upper(_editing ? "Modifier l'élève" : 'Nouvel élève')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Text(
              _editing
                  ? "Les modifications sont visibles tout de suite dans le profil de l'élève."
                  : "L'élève recevra un email pour choisir son mot de passe.",
              style: AppText.caption,
            ),
            Row(
              children: [
                Expanded(child: _field('Prénom *', _firstName, validator: _required, capitalization: TextCapitalization.words)),
                const SizedBox(width: 12),
                Expanded(child: _field('Nom *', _lastName, validator: _required, capitalization: TextCapitalization.words)),
              ],
            ),
            _field(
              _editing ? 'Email (adresse de connexion, non modifiable ici)' : 'Email *',
              _email,
              keyboard: TextInputType.emailAddress,
              validator: _emailValidator,
              readOnly: _editing,
            ),
            const SectionLabel('Informations (optionnel)'),
            Row(
              children: [
                Expanded(
                  child: _field('Âge', _age,
                      keyboard: TextInputType.number,
                      validator: ageValidator,
                      formatters: intInput(),
                      hint: '${ProfileLimits.minAge}–${ProfileLimits.maxAge}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Taille (cm)', _height,
                      keyboard: TextInputType.number,
                      validator: heightValidator,
                      formatters: intInput(),
                      hint: '${ProfileLimits.minHeightCm}–${ProfileLimits.maxHeightCm}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Poids (kg)', _weight,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                      validator: weightValidator,
                      formatters: decimalInput(),
                      hint: '${ProfileLimits.minWeightKg}–${ProfileLimits.maxWeightKg}'),
                ),
              ],
            ),
            const _FieldLabel('Objectif du programme'),
            DropdownButtonFormField<String>(
              initialValue: _goal,
              dropdownColor: AppColors.panel,
              style: const TextStyle(color: AppColors.text),
              hint: const Text('Choisir un objectif'),
              items: [
                // En édition, on peut retirer l'objectif.
                if (_editing) const DropdownMenuItem<String>(value: null, child: Text('Aucun objectif')),
                ..._goals.map((g) => DropdownMenuItem(value: g, child: Text(g))),
              ],
              onChanged: (v) => setState(() => _goal = v),
            ),
            if (_goal == 'Autre') _field('Précise l\'objectif', _customGoal),
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
            PrimaryButton(label: _editing ? 'Enregistrer' : 'Créer le compte', loading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? hint,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          textCapitalization: capitalization,
          validator: validator,
          inputFormatters: formatters,
          readOnly: readOnly,
          enabled: !readOnly,
          // Retour immédiat dès que la valeur sort des bornes.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(color: readOnly ? AppColors.muted : AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            errorMaxLines: 2,
            suffixIcon: readOnly ? const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.muted) : null,
          ),
        ),
      ],
    );
  }

  static String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Requis' : null;

  static String? _emailValidator(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Requis';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s);
    return ok ? null : 'Email invalide';
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
