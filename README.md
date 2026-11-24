# archymouv

Application Flutter (Android) qui mesure les mouvements de l'arc avec le
gyroscope et l'accéléromètre d'un smartphone fixé sur la poignée, pour
analyser le tir de l'archer.

## Lancer

```powershell
flutter test                       # 18 tests : capteurs, analyse, Excel, écrans
flutter run                        # téléphone Android branché (débogage USB)
flutter build apk --release        # APK : build\app\outputs\flutter-apk\app-release.apk
flutter run -d chrome              # démo navigateur (capteurs simulés)
```

Sur un PC ou dans le navigateur il n'y a pas de capteurs : l'appli passe en
**mode démo** et rejoue un tir simulé à chaque mesure. Sur le téléphone, le
mode démo se désactive dans Paramètres › Divers.

## Unités (question « rad/s ou °/s ? »)

Le paquet `sensors_plus` donne :

- gyroscope en **rad/s** (1 rad/s = 57,3 °/s) ;
- accéléromètre en **m/s²**, gravité incluse (≈ 9,81 au repos).

L'appli stocke les valeurs brutes (rad/s) et affiche / exporte le gyroscope
en °/s.

## Repères

Repère **arc** utilisé partout : X = axe de tir (+ vers la cible),
Y = vertical (+ vers le haut), Z = latéral (+ à droite face à la cible).

Positions du téléphone (Paramètres › 4) : vertical (défaut), vertical
inversé, horizontal haut vers la cible, horizontal haut vers l'archer.
Gaucher = même montage tourné de 180° autour de la verticale (X et Z
changent de signe). L'écran « Test des capteurs » détecte la position par
la gravité et montre un viseur en direct pour vérifier les sens.

## Séquence d'une flèche

1. « Mesure de départ » : nombre de flèches de la volée (6 par défaut).
2. Écran noir « Flèche k / n » : un toucher n'importe où arme la mesure
   (bip, heure enregistrée).
3. Déclenchement automatique : l'arc est baissé (≥ 5°) puis remonté (≥ 5°) ;
   t = 0 est fixé **200 ms après le point bas** (les mesures sont gardées en
   mémoire tampon, le départ est donc exact). Un 2e toucher force le départ.
4. Enregistrement de 15 s, ré-échantillonné toutes les 20 ms
   (751 lignes : t, gyro x/y/z, accéléro x/y/z), bip de fin.
5. Graphique de la flèche, puis écran noir de la flèche suivante.

Les données sont sauvegardées après chaque flèche (un fichier JSON par
entraînement). À l'ouverture, les entraînements de plus de 2 semaines
déclenchent la question « Avez-vous bien envoyé l'Excel ? » puis la
suppression.

## Analyse d'un tir (`lib/core/analysis.dart`)

- **Accélérations** : min / max signés par axe, et | |a| − g | max.
- **Lâcher** : début du choc d'accélération (sinon pic de rotation).
  La fin de la phase C est l'échantillon juste avant : c'est l'origine
  (z = 0, y = 0) du graphique, supposée au centre du jaune.
- **Phases** : C = 3 s avant le lâcher, B = 3 s avant C (durées nominales),
  A = début de l'enregistrement, D = du lâcher jusqu'à ce que la rotation
  retombe (arc rattrapé).
- **Viseur sur le blason** (première approche, à valider) : intégration du
  gyroscope depuis la référence, puis
  `latéral = −D·tan(angle Y)` et `vertical = D·tan(angle Z)`, D = distance.
  Ne tient pas encore compte de la dérive du gyroscope ni de l'inclinaison.
- **Verticalité** : inclinaison autour de X par la gravité
  (`atan2(−az, ay)`), + = haut de l'arc penché à droite.

## Export Excel

Bouton « envoyer » de l'entraînement : un fichier
`archymouv_AAAA-MM-JJ_HHhMM.xlsx`, objet du mail
« archymouv entraînement du JJ/MM/AAAA HHhMM », destinataire = email des
paramètres.

- Feuille **Entraînement** : paramètres + une ligne de résumé par flèche.
- Une feuille **par volée** : Flèche, Heure départ, t (ms), Gyro X/Y/Z (°/s),
  Acc X/Y/Z (m/s²), visée latérale/verticale (cm), inclinaison (°), phase.
  Les flèches sont séparées par une ligne de « xxx ».

## Points ouverts

- Calcul exact de la position du viseur sur le blason (xb, yb) : la formule
  actuelle est une approximation au premier ordre.
- Seuils de détection (lâcher, phases, déclenchement) à régler sur de vraies
  mesures : toutes les valeurs sont dans `analysis.dart` et dans les
  paramètres.
- À 20 ms, le choc du lâcher (10–30 ms) peut être en partie manqué ; essayer
  10 ms si le téléphone le permet (l'écran Test des capteurs affiche la
  fréquence réelle).
- « Autres analyses » de l'entraînement : à définir.

## Organisation du code

```
lib/core/       modèles, repères, capteurs, simulation, enregistreur, analyse
lib/services/   stockage, export Excel, envoi email, bips
lib/screens/    accueil, paramètres, test capteurs, entraînement,
                acquisition (écran noir), résultat flèche, analyse
lib/widgets/    graphiques (blason, courbes), composants communs
test/           tests unitaires et tests d'écrans
```
