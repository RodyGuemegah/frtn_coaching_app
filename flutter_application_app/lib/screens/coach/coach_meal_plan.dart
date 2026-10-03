import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/meal_model.dart';
import '../../services/meal_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../utils/session_stats.dart';
import '../../widgets/cartes.dart';
import '../../widgets/meal_widgets.dart';
import '../../widgets/tags.dart';
import '../../widgets/week_strip.dart';
import 'coach_meal_editor.dart';

/// Plan alimentaire d'un élève, géré par le coach : jour par jour,
/// ajout / modification / suppression de repas et duplication d'une journée.
class CoachMealPlanScreen extends StatefulWidget {
  final AppUser student;
  const CoachMealPlanScreen({super.key, required this.student});

  @override
  State<CoachMealPlanScreen> createState() => _CoachMealPlanScreenState();
}

class _CoachMealPlanScreenState extends State<CoachMealPlanScreen> {
  final _service = MealService();
  DateTime _day = startOfDay(DateTime.now());
  late DateTime _weekStart = startOfWeek(_day);
  late Stream<List<MealModel>> _weekStream = _watchWeek(_weekStart);

  Stream<List<MealModel>> _watchWeek(DateTime monday) =>
      _service.watchMealsBetween(widget.student.uid, monday, monday.add(const Duration(days: 7)));

  void _selectDay(DateTime d) {
    final day = startOfDay(d);
    final monday = startOfWeek(day);
    setState(() {
      _day = day;
      // On ne recrée l'écoute Firestore que si l'on change de semaine.
      if (monday != _weekStart) {
        _weekStart = monday;
        _weekStream = _watchWeek(monday);
      }
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) _snack(success);
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    }
  }

  Future<void> _add() async {
    final meal = await showMealEditor(context, day: _day);
    if (meal == null) return;
    await _run(() => _service.createMeal(widget.student.uid, meal), '${meal.title} ajouté');
  }

  Future<void> _edit(MealModel m) async {
    final meal = await showMealEditor(context, day: _day, initial: m);
    if (meal == null) return;
    await _run(() => _service.updateMeal(widget.student.uid, meal), 'Repas modifié');
  }

  Future<void> _delete(MealModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Supprimer ce repas ?', style: TextStyle(color: AppColors.text)),
        content: Text('${m.title} · ${m.time}', style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _service.deleteMeal(widget.student.uid, m.id), 'Repas supprimé');
  }

  Future<void> _duplicate(List<MealModel> meals) async {
    final choice = await showDialog<_DuplicateChoice>(
      context: context,
      builder: (_) => _DuplicateDialog(from: _day),
    );
    if (choice == null || choice.days.isEmpty) return;
    try {
      final n = await _service.copyMealsToDays(widget.student.uid, meals, choice.days, replace: choice.replace);
      if (mounted) _snack('$n repas copiés sur ${choice.days.length} jour${choice.days.length > 1 ? 's' : ''}');
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.accent,
        title: Text('Plan alimentaire · ${widget.student.shortName}', style: const TextStyle(color: AppColors.text)),
      ),
      body: StreamBuilder<List<MealModel>>(
        stream: _weekStream,
        builder: (context, snapshot) {
          final week = snapshot.data ?? const <MealModel>[];
          final meals = week.where((m) => isSameDay(m.date, _day)).toList();
          final totals = mealTotals(meals);
          final markedDays = week.map((m) => startOfDay(m.date)).toSet();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
            children: [
              WeekStrip(selected: _day, onSelect: _selectDay, marked: markedDays),
              const SizedBox(height: 16),
              if (snapshot.hasError) ...[
                ErrorCard(message: friendlyErrorMessage(snapshot.error!)),
                const SizedBox(height: 12),
              ],
              _TotalsCard(day: _day, totals: totals, count: meals.length),
              SectionLabel('Repas · ${formatDayLong(_day)}'),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
              else if (meals.isEmpty)
                const AppCard(child: Text('Aucun repas prévu ce jour-là.', style: TextStyle(color: AppColors.muted)))
              else
                for (final m in meals)
                  _CoachMealCard(meal: m, onEdit: () => _edit(m), onDelete: () => _delete(m)),
              const SizedBox(height: 8),
              PrimaryButton(label: '+ Ajouter un repas', onPressed: _add),
              if (meals.isNotEmpty) ...[
                const SizedBox(height: 10),
                GhostButton(label: '📋 Dupliquer cette journée', onPressed: () => _duplicate(meals)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final DateTime day;
  final ({int kcal, int protein, int carbs, int fat}) totals;
  final int count;
  const _TotalsCard({required this.day, required this.totals, required this.count});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isSameDay(day, DateTime.now()) ? "Total aujourd'hui" : 'Total du jour',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${totals.kcal} kcal',
                        style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              TagChip('$count repas', style: count == 0 ? TagStyle.neutral : TagStyle.active),
            ],
          ),
          const SizedBox(height: 10),
          MacroChips(kcal: totals.kcal, protein: totals.protein, carbs: totals.carbs, fat: totals.fat, showKcal: false),
        ],
      ),
    );
  }
}

class _CoachMealCard extends StatelessWidget {
  final MealModel meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CoachMealCard({required this.meal, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final m = meal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onEdit,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(mealEmoji(m.title), style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m.title} · ${m.time}',
                          style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                      if (m.description != null) ...[
                        const SizedBox(height: 2),
                        Text(m.description!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (m.eaten) const TagChip('✓ Mangé', style: TagStyle.active),
                PopupMenuButton<String>(
                  color: AppColors.panel,
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.only(right: 8), child: MacroChips.ofMeal(m)),
          ],
        ),
      ),
    );
  }
}

class _DuplicateChoice {
  final List<DateTime> days;
  final bool replace;
  const _DuplicateChoice(this.days, this.replace);
}

/// Choix des jours cibles : les 7 jours qui suivent la journée source.
class _DuplicateDialog extends StatefulWidget {
  final DateTime from;
  const _DuplicateDialog({required this.from});

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  late final List<DateTime> _candidates = [for (int i = 1; i <= 7; i++) widget.from.add(Duration(days: i))];
  final Set<int> _selected = {};
  bool _replace = true;

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == _candidates.length;
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Dupliquer la journée', style: TextStyle(color: AppColors.text)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Copier les repas du ${formatDayLong(widget.from)} vers :',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: allSelected,
                onChanged: (v) => setState(() {
                  _selected.clear();
                  if (v == true) _selected.addAll(List.generate(_candidates.length, (i) => i));
                }),
                title: const Text('Les 7 jours suivants', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                activeColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const Divider(color: AppColors.border, height: 1),
              for (int i = 0; i < _candidates.length; i++)
                CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: (v) => setState(() => v == true ? _selected.add(i) : _selected.remove(i)),
                  title: Text(formatDayLong(_candidates[i]), style: const TextStyle(color: AppColors.text, fontSize: 14)),
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                value: _replace,
                onChanged: (v) => setState(() => _replace = v),
                title: const Text('Remplacer les repas existants', style: TextStyle(color: AppColors.text, fontSize: 14)),
                subtitle: Text(
                  _replace ? 'Les repas déjà prévus ces jours-là seront supprimés' : 'Les repas seront ajoutés à ceux existants',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
                activeThumbColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _DuplicateChoice((_selected.toList()..sort()).map((i) => _candidates[i]).toList(), _replace),
                  ),
          child: Text(_selected.isEmpty ? 'Dupliquer' : 'Dupliquer (${_selected.length})'),
        ),
      ],
    );
  }
}
