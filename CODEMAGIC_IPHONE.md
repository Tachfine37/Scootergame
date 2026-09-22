# Installer « Ça passe ! » sur ton iPhone

Dépôt privé : https://github.com/Tachfine37/Scootergame

## 1. Vérification sans signature

Dans l'application **Scootergame** de Codemagic, sélectionner la configuration **codemagic.yaml**, la branche `main`, puis le workflow **iOS — vérifications et compilation sans signature** (`ios-check`).

Le workflow génère les dossiers natifs manquants avec Flutter 3.47.5, vérifie le code, exécute les tests et compile iOS ainsi que la version web. Il s'arrête si une vérification échoue.

`ios-unsigned.zip` n'est **pas installable sur un iPhone physique**. Il sert à vérifier la compilation avant de configurer la signature. `web-preview.zip` contient le build web à servir avec un serveur HTTP.

## 2. Configurer Apple une seule fois

L'abonnement Apple Developer actif est requis pour ce parcours Codemagic/TestFlight.

1. Dans Apple Developer, enregistrer un identifiant d'application explicite **com.tachfine37.scootergame**. Si un autre identifiant existe déjà, remplacer les trois occurrences dans `codemagic.yaml` et la valeur par défaut dans `tool/configure_ios.py`.
2. Dans App Store Connect, créer la fiche de l'application avec cet identifiant, la plateforme iOS et le nom souhaité. Un nom provisoire distinct peut être nécessaire si « Ça passe ! » est déjà pris.
3. Dans App Store Connect > Utilisateurs et accès > Intégrations > API App Store Connect, créer ou sélectionner une clé d'équipe adaptée à Codemagic. La documentation Codemagic recommande le rôle **App Manager**. Conserver l'Issuer ID, le Key ID et le fichier `.p8`.
4. Dans Codemagic > Team settings > Integrations > Developer Portal, ajouter cette clé sous le nom exact **ca-passe-apple**. Le fichier `.p8` doit être ajouté directement dans Codemagic : ne pas le mettre dans GitHub ni dans le chat.
5. Dans Codemagic > Code signing identities, importer un certificat **Apple Distribution** avec sa clé privée (`.p12`), ou utiliser la génération proposée par Codemagic. Importer ou récupérer un profil **App Store** correspondant à `com.tachfine37.scootergame`. Ne pas révoquer un certificat existant utilisé par une autre application.

Le workflow utilise les identités de signature ainsi configurées. Il n'invente pas de Team ID, ne crée pas la fiche App Store Connect et ne contient aucune clé Apple.

## 3. Construire pour TestFlight

Dans Codemagic, lancer manuellement **iPhone — TestFlight** (`ios-testflight`) sur `main`.

Le workflow applique les profils, produit l'IPA signé et le transfère dans App Store Connect. Le numéro de build augmente avec `PROJECT_BUILD_NUMBER + 1`. Si cette application a déjà reçu des builds avec un numéro supérieur, ajuster le compteur Codemagic avant le premier envoi.

La configuration d'envoi n'effectue aucune soumission à l'App Store public ni aucune demande de revue bêta externe. Pour tester sur ton propre iPhone, utiliser un groupe de testeurs internes :

1. Attendre la fin du traitement Apple dans App Store Connect > application > TestFlight.
2. Créer un groupe **interne**, s'ajouter comme testeur avec le compte ayant accès à l'application, puis ajouter le build au groupe. L'activation de la distribution automatique au groupe est facultative.
3. Installer **TestFlight** depuis l'App Store sur l'iPhone.
4. Accepter l'invitation et toucher **Installer**.

La validation « export compliance » est renseignée pour ce prototype sans chiffrement propre (`ITSAppUsesNonExemptEncryption = false`). Réévaluer cette déclaration si des fonctions de chiffrement sont ajoutées.

## Sources officielles

- Codemagic — Flutter : https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/
- Codemagic — signature iOS : https://docs.codemagic.io/yaml-code-signing/signing-ios/
- Apple — testeurs internes : https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers

