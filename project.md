# SafeVault — cahier des charges

Coffre de mots de passe Flutter / Android. Ce qui est listé ici correspond à **ce qui tourne dans l’app**, sauf la section hors scope.

## 1. Authentification

- Connexion Google via Firebase Auth.
- Pas de formulaire e-mail / mot de passe, pas d’avatar.
- Auth = identité. Ça n’ouvre pas le coffre.

## 2. Coffre local

- Fiches : nom du service, URL, identifiant, mot de passe, dates.
- AES-256-GCM. Le maître dérive une KEK (PBKDF2-HMAC-SHA256, 210 000 itérations) qui enveloppe la DEK.
- Fichier `vault_<uid>.enc` sur le téléphone. Utilisable hors ligne une fois déverrouillé.

## 3. Générateur

- Longueur et jeux de caractères (minuscules, majuscules, chiffres, symboles).
- Copie presse-papier, effacement après 30 secondes.

## 4. Santé et alertes

- Score (longueur, mélange, mots trop simples, doublons SHA-256, âge 90 jours, fuites).
- Have I Been Pwned : k-anonymity, pas le secret en entier.
- Bandeau in-app + notification système. Texte = compteurs, jamais le mot de passe.

## 5. Assistant

- Gemini (Firebase AI) rédige un briefing et répond aux questions.
- Prompt = JSON de compteurs. Pas de mot de passe, login, URL ni nom de site.
- Plan d’action et bilan d’une fiche en Dart (les IDs restent sur le téléphone).
- Sans réseau : repli local.

## 6. Copie cloud

- Firestore : `users/{uid}/enveloppe` + `users/{uid}/fiches/{id}`, ciphertext seulement.
- Last-write-wins.

## Hors scope

- Biométrie (empreinte / Face ID).
- Compte Firebase e-mail + mot de passe.
- API HIBP payante (fuites par e-mail).
- Push calculé côté serveur (le jeton FCM est enregistré, l’analyse reste locale).
