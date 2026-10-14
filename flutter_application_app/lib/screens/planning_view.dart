import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/meal_model.dart';
import '../models/schedule_slot.dart';
import '../models/session_model.dart';
import '../services/meal_service.dart';
import '../services/schedule_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/planning.dart';
import '../utils/session_stats.dart';
import '../widgets/cartes.dart';
import '../widgets/slot_editor.dart';
import '../widgets/week_strip.dart';
import 'session_detail.dart';

/// Emploi du temps d'un élève : bandeau de semaine + frise de la journée
/// (séances, repas et créneaux récurrents). Partagé élève / coach.
class PlanningView extends StatefulWidget {
  final AppUser student;

  /// Côté coach : les séances s'ouvrent en mode gestion (modifier / supprimer).
  final bool coachMode;

  /// Contenu affiché au-dessus du bandeau (ex : titre d'écran).
  final Widget? header;

  const PlanningView({super.key, required this.student, this.coachMode = false, this.header});

  @override
  State<PlanningView> createState() => _PlanningViewState();
}

class _PlanningViewState extends State<PlanningView> {
  DateTime _day = startOfDay(DateTime.now());
  late DateTime _weekStart = startOfWeek(_day);

  late final Stream<List<SessionModel>> _sessions = SessionService().watchSessions(widget.student.uid);
  late final Stream<List<ScheduleSlot>> _slots = ScheduleService().watchSlots(widget.student.uid);
  late Stream<List<MealModel>> _meals = _watchMeals(_weekStart);

  Stream<List<MealModel>> _watchMeals(DateTime monday) =>
      MealService().watchMealsBetween(widget.student.uid, monday, monday.add(const Duration(days: 7)));

  void _selectDay(DateTime d) {
    final day = startOfDay(d);
    final monday = startOfWeek(day);
    setState(() {
      _day = day;
      // Les repas sont chargés par semaine : nouvelle requête seulement si on change de semaine.
      if (monday != _weekStart) {
        _weekStart = monday;
        _meals = _watchMeals(monday);
      }
    });
  }

  void _onTap(PlanningItem item) {
    switch (item.kind) {
      case PlanningKind.session:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SessionDetailScreen(
            uid: widget.student.uid,
            session: item.source as SessionModel,
            readOnly: widget.coachMode,
            student: widget.coachMode ? widget.student : null,
          ),
        ));
      case PlanningKind.slot:
        showSlotEditor(context, uid: widget.student.uid, initial: item.source as ScheduleSlot);
      case PlanningKind.meal:
        break; // Les repas se gèrent depuis le plan alimentaire / l'onglet Nutrition.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionModel>>(
      stream: _sessions,
      builder: (context, sessionSnap) => StreamBuilder<List<MealModel>>(
        stream: _meals,
        builder: (context, mealSnap) => StreamBuilder<List<ScheduleSlot>>(
          stream: _slots,
          builder: (context, slotSnap) {
            final sessions = sessionSnap.data ?? const <SessionModel>[];
            final meals = mealSnap.data ?? const <MealModel>[];
            final slots = slotSnap.data ?? const <ScheduleSlot>[];
            final error = sessionSnap.error ?? mealSnap.error ?? slotSnap.error;
            final loading = !sessionSnap.hasData && !sessionSnap.hasError;
            final items = buildDayItems(day: _day, sessions: sessions, meals: meals, slots: slots);
            // Point sous les jours de la semaine qui ont une séance.
            final sessionDays = sessions.map((s) => startOfDay(s.date)).toSet();

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                if (widget.header != null) ...[widget.header!, const SizedBox(height: 12)],
                WeekStrip(selected: _day, onSelect: _selectDay, marked: sessionDays),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  ErrorCard(message: friendlyErrorMessage(error)),
                ],
                SectionLabel(formatDayLong(_day)),
                if (loading)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                else if (items.isEmpty)
                  const NoticeCard('Rien de prévu ce jour-là.', icon: Icons.event_available_outlined)
                else
                  PlanningTimeline(items: items, onTap: _onTap),
                const SizedBox(height: 12),
                GhostButton(
                  label: '+ Ajouter un créneau régulier',
                  onPressed: () => showSlotEditor(context, uid: widget.student.uid),
                ),
                if (slots.isNotEmpty) ...[
                  const SectionLabel('Créneaux réguliers'),
                  for (final s in slots) _SlotRow(slot: s, onTap: () => showSlotEditor(context, uid: widget.student.uid, initial: s)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Couleur du point / de la bordure selon la nature de l'élément.
Color _kindColor(PlanningKind k) => switch (k) {
  PlanningKind.session => AppColors.accent,
  PlanningKind.meal => AppColors.accent2,
  PlanningKind.slot => AppColors.muted,
};

/// Frise verticale (ligne + points) façon maquette.
class PlanningTimeline extends StatelessWidget {
  final List<PlanningItem> items;
  final ValueChanged<PlanningItem> onTap;
  const PlanningTimeline({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Segment de ligne (coupé au-dessus du 1er et sous le dernier point).
                      Positioned(
                        top: i == 0 ? 22 : 0,
                        bottom: i == items.length - 1 ? null : 0,
                        height: i == items.length - 1 ? 22 : null,
                        child: Container(width: 2, color: AppColors.border),
                      ),
                      Positioned(
                        top: 17,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kindColor(items[i].kind),
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemCard(item: items[i], onTap: () => onTap(items[i])),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final PlanningItem item;
  final VoidCallback onTap;
  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSession = item.kind == PlanningKind.session;
    return AppCard(
      onTap: item.kind == PlanningKind.meal ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSession ? AppColors.accent : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppText.itemTitle.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  [item.timeLabel, if (item.subtitle.isNotEmpty) item.subtitle].join(' · '),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.emoji, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final ScheduleSlot slot;
  final VoidCallback onTap;
  const _SlotRow({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hours = slot.endMinutes == null
        ? formatMinutes(slot.startMinutes)
        : '${formatMinutes(slot.startMinutes)} – ${formatMinutes(slot.endMinutes!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(slot.kind.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.title, style: AppText.itemTitle.copyWith(fontSize: 14)),
                  Text('${formatWeekdays(slot.weekdays)} · $hours', style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
