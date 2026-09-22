# Ça passe ! — Flutter + Flame, 2,5D

Un prototype jouable de livraison en 30 secondes : ramasser des colis, éviter les voitures et les cônes, franchir les ralentisseurs et livrer la plus grande pile possible.

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
- Espace ou Échap : pause / reprise ; espace démarre aussi une tournée.
- Bouton en haut à droite à l'accueil : activer/désactiver les vibrations (mobile).

Une collision avec un cône fait perdre jusqu'à deux colis. Une voiture fait perdre 40 % du chargement, au moins deux colis si disponibles. Les ralentisseurs font sauter le scooter et font tomber un colis lorsque la pile dépasse cinq colis. Une courte protection évite les doubles pénalités. Chaque vague laisse une voie de collecte libre.

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

Ce livrable est un prototype complet du cœur du jeu. Il ne comprend pas encore une boutique, des niveaux multiples, un classement en ligne, une bande-son ou une publication dans les stores.

