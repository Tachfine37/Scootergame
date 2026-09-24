# One More Parcel? — Endless Ride, Flutter + Flame

Un jeu de livraison infini en quatre quartiers, avec interface anglaise : ramasser des colis, garder l'équilibre et préserver son scooter aussi longtemps que possible.

Jouer : https://tachfine37.github.io/Scootergame/

## Les quartiers

Choisissez votre quartier de départ. Downtown, Seaside, Garden District et Golden Hour s'enchaînent sans interrompre la course, tous les 400 mètres. Le chronomètre ne met plus fin à la partie.

- Le scooter dispose de 3 points de santé. Une collision avec une voiture ou un cône retire un point. Une protection de 1,6 seconde empêche les dégâts en chaîne.
- Les bosses et les pertes d'équilibre font tomber des colis sans endommager le scooter. Rayures, feu arrière cassé et fumée rendent les dégâts visibles ; à zéro santé, le scooter bascule puis le bilan apparaît.
- Chaque passage de livraison, tous les 400 m, dépose automatiquement la pile : 2 pièces et 25 points par colis livré. Chaque mètre parcouru rapporte aussi un point ; les colis encore à bord à la panne ne rapportent pas de points de livraison.
- Les garages apparaissent après la première livraison, puis environ tous les 400 m. Entrez dans leur voie pour réparer un point contre 6 pièces. Aucun paiement si le scooter est intact ou si le solde est insuffisant.
- Le meilleur score infini est sauvegardé séparément des anciens records de stages. La vitesse monte de 22 à 40 et la fréquence des obstacles augmente progressivement sur 2 000 m, puis reste plafonnée. Le compteur de vitesse, les niveaux tous les 500 m et les traits sur les côtés rendent cette progression visible.

## Police, piétons et véhicules (0.6.0)

- Un premier feu rouge déclenche la police. Une nouvelle infraction ou une collision non protégée pendant la poursuite entraîne l'arrestation. Parcourir 350 m sans nouvelle faute permet de la semer ; patienter à l'arrêt ou en pause ne fait pas progresser cette distance. Le bouclier protège des chocs, pas des infractions. Passer au rouge sans toucher une voiture ne retire plus artificiellement de santé.
- Après 400 m, certains carrefours deviennent des passages piétons. Les personnages attendent sur le trottoir puis traversent au rouge ; le feu reste rouge jusqu'au dégagement. Une rencontre déclenche un freinage d'urgence et une perte de colis, sans dégâts aux piétons ni à la santé du véhicule.
- Après les seuils ci-dessous, un portail violet propose gratuitement le véhicule suivant, face à la voie de réparation habituelle. Entrer dans sa voie accepte l'amélioration ; passer ailleurs conserve le véhicule. Les portails reviennent si on les ignore.

| Véhicule | Seuil d'accès | Colis protégés | Colis par ramassage |
| --- | --- | --- | --- |
| City Scooter | Départ | 0 | 1 |
| Box Scooter | 800 m | 6 | 2 |
| Touring Bike | 1 600 m | 12 | 3 |
| Cargo Trike | 2 400 m | 20 | 4 |

Les portails apparaissent au prochain garage disponible après le seuil. Coffre, sacoches et caisse de tricycle sont visibles. Les nouveaux véhicules sont plus larges et moins agiles. Le chargement n'a pas de plafond : les colis au-delà du rangement protégé restent empilés et peuvent tomber. Tout revient au véhicule de départ lors d'une nouvelle partie.

Chaque vague garde une voie libre et les abords des garages restent dégagés. Aux carrefours, les voitures traversent au rouge : maintenez **BRAKE** pour attendre. Le bonus bleu **SHIELD** absorbe un choc ; le bonus rose **MAGNET** attire les colis des trois voies pendant six secondes. La pause fige aussi les bonus. Freiner ne rapporte ni distance ni points.

Le rendu utilise une projection en perspective, des volumes dessinés sur Canvas, un tri par profondeur, des ombres au sol et des animations de pile. Il ne dépend pas d'un moteur 3D, d'images distantes ou d'assets payants. Le gameplay est piloté par Flame ; les menus et commandes sont des widgets Flutter.

## Lancer

Flutter **3.41 ou plus récent** et Dart **3.11 ou plus récent** sont requis.

```sh
python3 tool/bootstrap_platforms.py
flutter pub get
flutter run -d chrome
```

Les dossiers natifs sont générés par Flutter au premier lancement. Le script utilise les modèles officiels sans modifier `lib/`, `test/`, `pubspec.yaml` ni les dossiers natifs déjà présents. Codemagic effectue cette étape automatiquement.

Sous Windows, `./lancer.ps1` utilise Flutter installé dans le PATH ou le SDK local préparé à côté de ce projet sur cette machine.

Pour un téléphone Android connecté avec le débogage USB activé :

```sh
flutter devices
flutter run -d IDENTIFIANT_APPAREIL
```

## Commandes

- Glisser sur la route : diriger le scooter.
- Flèches gauche/droite ou A/D : conduire au clavier.
- Boutons à l'écran : appui court pour changer de position, appui long pour tourner.
- Maintenir **FREIN** ou la flèche bas / **S** : s'arrêter au feu rouge ; relâcher pour repartir.
- Espace ou Échap : pause / reprise ; espace démarre aussi une tournée.
- Bouton en haut à droite à l'accueil : activer/désactiver les vibrations (mobile).

Une collision avec un cône fait perdre jusqu'à deux colis. Une voiture fait perdre 40 % du chargement, au moins deux colis si disponibles. Les ralentisseurs font sauter le scooter et font tomber un colis lorsque la pile dépasse cinq colis. Une courte protection évite les doubles pénalités. Chaque vague laisse une voie de collecte libre. Plus la pile est haute, plus le scooter met du temps à changer de direction et plus la pile se balance. Le nouvel indicateur d'équilibre monte pendant les virages brusques : à pleine charge, les colis peuvent tomber sans obstacle. Tourner progressivement ou freiner permet de le faire redescendre. Le score n'est pas limité à 15 colis.

Le record et la préférence de vibration sont sauvegardés localement. Pas de compte, de publicité, de paiement ou de serveur de jeu. Le record est distinct de celui de la première démo dans la conversation.

## Vérifier et compiler

```sh
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
flutter build apk --release
```

La compilation Android nécessite le SDK Android et Java configurés. La compilation iOS nécessite macOS, Xcode et une signature Apple pour un appareil physique. Codemagic génère et compile le projet iOS sur son Mac distant.

Le nom technique est `ca_passe`. L'identifiant iOS prévu est `com.tachfine37.scootergame` ; il faut enregistrer cet identifiant dans le compte Apple ou remplacer ses occurrences dans `codemagic.yaml` et `tool/configure_ios.py` par celui déjà enregistré. Avant publication publique, choisir une icône finale et configurer la signature de distribution. La configuration Android générée pour ce prototype ne constitue pas une configuration de publication sur le Play Store.

## Tester sur iPhone avec Codemagic

Voir [CODEMAGIC_IPHONE.md](CODEMAGIC_IPHONE.md). Le workflow `ios-check` vérifie le projet sans compte Apple. Le workflow `ios-testflight` construit un IPA signé et l'envoie dans App Store Connect ; il faut ensuite l'ajouter à un groupe interne TestFlight. Aucun workflow ne soumet le jeu au public dans l'App Store.

## Structure

- `lib/main.dart` : interface adaptative, menus, clavier, tactile, cycle de vie.
- `lib/game/delivery_model.dart` : simulation Dart indépendante, collisions et progression.
- `lib/game/delivery_game.dart` : boucle Flame à pas fixe, notifications et vibrations.
- `lib/game/world_renderer.dart` : route en perspective, ville, scooter et colis.
- `lib/data/game_preferences.dart` : sauvegarde du record et des préférences.
- `test/` : tests du gameplay, de l'interface et de la sauvegarde.

Le jeu comprend une course sans fin, quatre quartiers, une progression des véhicules et une bande-son funk adaptative. Il ne comprend pas encore de boutique, de classement en ligne ou de publication dans les stores.

## Audio (0.8.0)

Le bouton **Settings** ouvre les réglages **Music**, **Sound effects** et leurs volumes, mémorisés localement. Les effets restent disponibles quand la musique est coupée. Le jeu se met en pause à l'ouverture des réglages ou quand l'application passe en arrière-plan.

La musique originale est rendue à 100, 110 et 120 BPM, avec une variante de poursuite. Les changements de morceau conservent la position musicale et utilisent un fondu. La vitesse dépend du niveau atteint, pas du freinage. Les sons comprennent les accidents, upgrades, livraisons, police, colis instables et moteurs par véhicule.

Les WAV sont générés sans dépendance ni téléchargement par `python tool/build_game_audio.py`. `tool/bootstrap_platforms.py` lance automatiquement cette étape sur GitHub Actions et Codemagic, avant Flutter. Pour un lancement manuel depuis un clone neuf, exécuter le générateur avant `flutter test` ou `flutter build`. Les fichiers générés sont exclus de Git; les deux scripts de synthèse sont leur source.
