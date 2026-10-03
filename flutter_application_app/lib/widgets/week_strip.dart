import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/session_stats.dart';

const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Bandeau de 7 jours (lundi → dimanche) façon maquette, avec navigation semaine.
class WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Jours à marquer d'un point (ex : jours qui ont déjà des repas).
  final Set<DateTime> marked;

  const WeekStrip({super.key, required this.selected, required this.onSelect, this.marked = const {}});

  @override
  Widget build(BuildContext context) {
    final monday = startOfWeek(selected);
    final sunday = monday.add(const Duration(days: 6));
    final now = DateTime.now();
    final label = monday.month == sunday.month
        ? '${monday.day} – ${sunday.day} ${_months[sunday.month - 1]}'
        : '${monday.day} ${_months[monday.month - 1]} – ${sunday.day} ${_months[sunday.month - 1]}';

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.muted),
              onPressed: () => onSelect(selected.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.muted),
              onPressed: () => onSelect(selected.add(const Duration(days: 7))),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (int i = 0; i < 7; i++) ...[
              Expanded(child: _DayCell(
                day: monday.add(Duration(days: i)),
                letter: _letters[i],
                selected: isSameDay(monday.add(Duration(days: i)), selected),
                today: isSameDay(monday.add(Duration(days: i)), now),
                marked: marked.any((d) => isSameDay(d, monday.add(Duration(days: i)))),
                onTap: () => onSelect(monday.add(Duration(days: i))),
              )),
              if (i < 6) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final String letter;
  final bool selected, today, marked;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.letter,
    required this.selected,
    required this.today,
    required this.marked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? AppColors.accent : (today ? AppColors.accent.withValues(alpha: 0.6) : AppColors.border)),
          ),
          child: Column(
            children: [
              Text(letter, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${day.day}',
                  style: TextStyle(color: selected ? const Color(0xFFFFC9CD) : AppColors.muted, fontSize: 10.5)),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: marked ? (selected ? Colors.white : AppColors.accent) : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
