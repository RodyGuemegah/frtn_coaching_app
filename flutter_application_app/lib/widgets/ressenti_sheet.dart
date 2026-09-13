import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../theme/app_colors.dart';
import 'cartes.dart';

/// Bottom sheet « Comment s'est passée la séance ? » — retourne le ressenti
/// choisi (avec commentaire optionnel) ou `null` si annulé.
Future<SessionFeedback?> showRessentiSheet(BuildContext context) {
  return showModalBottomSheet<SessionFeedback>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _RessentiSheet(),
  );
}

class _RessentiSheet extends StatefulWidget {
  const _RessentiSheet();

  @override
  State<_RessentiSheet> createState() => _RessentiSheetState();
}

class _RessentiSheetState extends State<_RessentiSheet> {
  Ressenti? _selected;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 20, 18, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Comment s'est passée la séance ?",
            style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final r in Ressenti.values) ...[
                Expanded(child: _RessentiOption(r, selected: _selected == r, onTap: () => setState(() => _selected = r))),
                if (r != Ressenti.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Un commentaire pour ton coach ? (optionnel)',
              counterStyle: TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Valider',
            onPressed: _selected == null
                ? null
                : () {
                    final comment = _comment.text.trim();
                    Navigator.of(context).pop(SessionFeedback(
                      ressenti: _selected!,
                      comment: comment.isEmpty ? null : comment,
                      createdAt: DateTime.now(),
                    ));
                  },
          ),
        ],
      ),
    );
  }
}

class _RessentiOption extends StatelessWidget {
  final Ressenti ressenti;
  final bool selected;
  final VoidCallback onTap;

  const _RessentiOption(this.ressenti, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withValues(alpha: 0.14) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Text(ressenti.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            ressenti.label,
            style: TextStyle(
              color: selected ? AppColors.text : AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
