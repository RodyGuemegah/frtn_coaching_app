// Formatage de dates/heures en français, sans dépendance externe.

const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _joursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "mardi 14 juillet"
String formatDayLong(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

/// "Jeu. 16 juillet"
String formatDayShort(DateTime d) => '${_joursCourts[d.weekday - 1]}. ${d.day} ${_mois[d.month - 1]}';

/// "16/07"
String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// "18h00"
String formatTime(DateTime d) => '${_two(d.hour)}h${_two(d.minute)}';

String todayLabel([DateTime? now]) => formatDayLong(now ?? DateTime.now());

/// Ajoute [days] JOURS DU CALENDRIER (et non des tranches de 24 h) en gardant l'heure.
/// Indispensable autour des changements d'heure : le 25 octobre dure 25 h en France,
/// donc `date.add(Duration(days: 1))` peut tomber la veille à 23h00.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute, d.second, d.millisecond);

/// Nombre de jours du calendrier de [from] à [to] (insensible aux changements d'heure).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Aujourd'hui · 18h00", "Demain · 18h00" ou "16/07 · 18h00"
String sessionDateTag(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  if (isSameDay(d, n)) return "Aujourd'hui · ${formatTime(d)}";
  if (isSameDay(d, addDays(n, 1))) return 'Demain · ${formatTime(d)}';
  return '${formatDate(d)} · ${formatTime(d)}';
}
