import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';
import '../widgets/feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final error = await _auth.signIn(_email.text.trim(), _password.text);
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Saisis ton email pour recevoir un lien de réinitialisation');
      return;
    }
    final error = await _auth.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) {
      showToast(context, 'Si un compte existe pour cet email, un lien vient d\'être envoyé.', type: ToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Halos décoratifs en fond
          Positioned(
            top: -80,
            right: -60,
            child: _glow(AppColors.accent.withValues(alpha: 0.35), 220),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _glow(AppColors.accentDark.withValues(alpha: 0.25), 260),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _buildLogo(),
                      const SizedBox(height: 10),
                      Text(
                        'Connecte-toi pour retrouver ton programme',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
                      ),
                      const SizedBox(height: 36),
                      _buildForm(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Accès élève fourni par ton coach',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );

  /// Logo officiel FRTN Coaching (bouclier, monogramme « FR », éclair).
  /// Le fondu vers le fond de l'écran (#0A0A0C) est intégré à l'image.
  Widget _buildLogo() {
    return Center(
      child: Semantics(
        label: 'FRTN Coaching',
        image: true,
        child: Image.asset(
          'assets/images/logo_frtn.jpg',
          height: 290,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Se connecter', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
