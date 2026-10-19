#!/usr/bin/env bash
# Renouvelle les profils de développement Apple (iPhone + Mac) de FRTN Coaching.
#
# Avec un compte Apple gratuit, les profils ne durent que 7 jours ; `flutter run`
# ne sait pas les renouveler. Ce script les recrée pour 7 nouveaux jours.
#
# Usage (depuis la racine du projet) :
#   ./scripts/renouveler_profils.sh          # iPhone (s'il est branché) + Mac
#   ./scripts/renouveler_profils.sh mac      # Mac seulement
#   ./scripts/renouveler_profils.sh ios      # iPhone seulement
set -euo pipefail

cible="${1:-tout}"
racine="$(cd "$(dirname "$0")/.." && pwd)"
profils="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
sauvegarde="$(mktemp -d)/profils-sauvegarde"
journal="$(mktemp -d)"

afficher_profils() {
  for f in "$profils"/*; do
    [ -f "$f" ] || continue
    security cms -D -i "$f" 2>/dev/null > "$journal/p.plist" || continue
    echo "  • $(plutil -extract Name raw "$journal/p.plist") → expire le $(plutil -extract ExpirationDate raw "$journal/p.plist")"
  done
}

# Supprime les profils de l'app pour la plateforme donnée (après sauvegarde),
# afin que Xcode en génère un neuf (7 jours à partir de maintenant).
retirer_profils() {
  local motif="$1"
  mkdir -p "$sauvegarde"
  for f in "$profils"/*; do
    [ -f "$f" ] || continue
    security cms -D -i "$f" 2>/dev/null > "$journal/p.plist" || continue
    if plutil -extract Name raw "$journal/p.plist" | grep -q "$motif.*com.rody.frtncoachingapp"; then
      cp "$f" "$sauvegarde/" && rm -f "$f"
    fi
  done
}

echo "Profils actuels :"; afficher_profils

if [[ "$cible" == "tout" || "$cible" == "mac" ]]; then
  echo "→ Mac…"
  retirer_profils "Mac Team"
  (cd "$racine/macos" && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
     -allowProvisioningUpdates -destination 'platform=macOS' build > "$journal/mac.log" 2>&1) \
     && echo "  ✓ profil Mac renouvelé" || { echo "  ✗ échec (journal : $journal/mac.log)"; exit 1; }
fi

if [[ "$cible" == "tout" || "$cible" == "ios" ]]; then
  iphone="$(xcrun xctrace list devices 2>/dev/null | sed -n '/== Devices ==/,/== Devices Offline ==/p' \
            | grep -i 'iphone' | sed -E 's/.*\(([0-9A-F-]{20,})\)$/\1/' | head -1 || true)"
  if [[ -z "$iphone" ]]; then
    echo "→ iPhone : aucun iPhone branché, étape ignorée (branche-le puis relance avec « ios »)."
  else
    echo "→ iPhone ($iphone)…"
    retirer_profils "iOS Team"
    (cd "$racine" && flutter build ios --config-only --debug > "$journal/ios-config.log" 2>&1)
    (cd "$racine/ios" && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
       -allowProvisioningUpdates -allowProvisioningDeviceRegistration -destination "id=$iphone" build \
       > "$journal/ios.log" 2>&1) \
       && echo "  ✓ profil iPhone renouvelé" || { echo "  ✗ échec (journal : $journal/ios.log)"; exit 1; }
  fi
fi

echo "Profils après renouvellement :"; afficher_profils
echo "Anciens profils sauvegardés dans : $sauvegarde"
