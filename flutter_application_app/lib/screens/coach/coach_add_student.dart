import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cartes.dart';
import '../../widgets/current_user_scope.dart';

const _goals = ['Prise de masse', 'Perte de poids', 'Remise en forme', 'Performance', 'Autre'];

/// Création d'un compte élève par le coach.
class CoachAddStudentScreen extends StatefulWidget {
  const CoachAddStudentScreen({super.key});

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
        weightKg: num.tryParse(_weight.text.trim().replaceAll(',', '.')),
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

  Future<void> _showSuccess(StudentCreationResult result) {
    final AppUser s = result.student;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Compte créé ✅', style: TextStyle(color: AppColors.text)),
        content: Text(
          result.resetEmailSent
              ? '${s.nameOrEmail} recevra un email à ${s.email} pour choisir son mot de passe.'
              : "Le compte de ${s.nameOrEmail} est créé, mais l'email n'a pas pu être envoyé. "
                  "L'élève pourra utiliser « Mot de passe oublié ? » sur l'écran de connexion avec ${s.email}.",
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.accent,
        title: const Text('Nouvel élève', style: TextStyle(color: AppColors.text)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const Text(
              "L'élève recevra un email pour choisir son mot de passe.",
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            Row(
              children: [
                Expanded(child: _field('Prénom *', _firstName, validator: _required, capitalization: TextCapitalization.words)),
                const SizedBox(width: 12),
                Expanded(child: _field('Nom *', _lastName, validator: _required, capitalization: TextCapitalization.words)),
              ],
            ),
            _field('Email *', _email, keyboard: TextInputType.emailAddress, validator: _emailValidator),
            const SectionLabel('Informations (optionnel)'),
            Row(
              children: [
                Expanded(child: _field('Âge', _age, keyboard: TextInputType.number, validator: _optionalInt)),
                const SizedBox(width: 12),
                Expanded(child: _field('Taille (cm)', _height, keyboard: TextInputType.number, validator: _optionalInt)),
                const SizedBox(width: 12),
                Expanded(child: _field('Poids (kg)', _weight, keyboard: const TextInputType.numberWithOptions(decimal: true), validator: _optionalNum)),
              ],
            ),
            const _FieldLabel('Objectif du programme'),
            DropdownButtonFormField<String>(
              initialValue: _goal,
              dropdownColor: AppColors.panel,
              style: const TextStyle(color: AppColors.text),
              hint: const Text('Choisir un objectif'),
              items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
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
            PrimaryButton(label: 'Créer le compte', loading: _saving, onPressed: _submit),
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
          style: const TextStyle(color: AppColors.text),
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

  static String? _optionalInt(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return int.tryParse(s) == null ? 'Nombre entier' : null;
  }

  static String? _optionalNum(String? v) {
    final s = v?.trim().replaceAll(',', '.') ?? '';
    if (s.isEmpty) return null;
    return num.tryParse(s) == null ? 'Nombre' : null;
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
