import 'package:flutter/material.dart';
import '../../models/session_template.dart';
import '../../services/template_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/errors.dart';
import '../../widgets/cartes.dart';

/// Feuille du bas listant les modèles du coach.
/// Retourne le modèle choisi, ou `null` si le coach ferme la feuille.
Future<SessionTemplate?> showTemplatePicker(BuildContext context, {required String coachUid}) {
  return showModalBottomSheet<SessionTemplate>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TemplatePicker(coachUid: coachUid),
  );
}

class _TemplatePicker extends StatefulWidget {
  final String coachUid;
  const _TemplatePicker({required this.coachUid});

  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  // Créé une seule fois (et non dans build) pour ne pas relancer la requête à chaque rebuild.
  late final Stream<List<SessionTemplate>> _stream = TemplateService().watchTemplates(widget.coachUid);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // La feuille ne dépasse pas 75 % de l'écran ; au-delà, la liste défile.
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: StreamBuilder<List<SessionTemplate>>(
        stream: _stream,
        builder: (context, snapshot) {
          final templates = snapshot.data ?? const <SessionTemplate>[];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text(AppText.upper('Partir d\'un modèle'), style: AppText.barTitle),
              const SizedBox(height: 4),
              const Text('Le contenu sera copié dans le formulaire. Tu choisis ensuite l\'élève et la date.',
                  style: AppText.caption),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                ErrorCard(message: friendlyErrorMessage(snapshot.error!))
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (templates.isEmpty)
                const NoticeCard(
                  'Aucun modèle pour l\'instant. Ouvre une séance existante, puis ⋮ → « Enregistrer comme modèle ».',
                  icon: Icons.bookmark_border_rounded,
                )
              else
                for (final t in templates) _TemplateRow(template: t, onTap: () => Navigator.of(context).pop(t)),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final SessionTemplate template;
  final VoidCallback onTap;
  const _TemplateRow({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = template.exercises.length;
    final details = [
      '$n exercice${n > 1 ? 's' : ''}',
      if (template.durationMin != null) '~${template.durationMin} min',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.bookmark_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.title, style: AppText.itemTitle),
                  const SizedBox(height: 2),
                  Text(details, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
