# Publication Android : APK sur un store alternatif

Le Play Store n’est **pas** le canal. Le livrable est un **APK signé** (`flutter build apk --release`), déposé sur un store qui accepte les APK.

Le workflow GitHub sur **`main`** **n’est pas le store**. Il construit l’APK et le joint à une Release pour que tu puisses le télécharger et l’envoyer au store.

## Store visé : Uptodown

[Uptodown](https://www.uptodown.com/) prend un **APK**, y compris une app qui utilise Firebase / Google Sign-In. Compte développeur gratuit : [developers.uptodown.com](https://developers.uptodown.com/).

**Pas F-Droid** : Firebase Auth, Firestore, FCM et Gemini sont propriétaires, le dépôt officiel refuse.

Aptoide ou Amazon Appstore acceptent aussi un APK si tu préfères plus tard.

L’`applicationId` reste `com.example.flutter_pwd_container`. Uptodown l’accepte ; le Play Store, lui, bloque souvent `com.example.*`.

## Chaîne

```
push sur main
    → GitHub Actions : tests + APK signé
    → Release GitHub (fichier SafeVault-{version}.apk)
    → tu déposes cet APK sur Uptodown (nouvelle app, puis mises à jour)
```

Fichier CI : [`.github/workflows/publish-android.yml`](../.github/workflows/publish-android.yml).

Déclenché par un **push sur `main`**, ou **Actions → Publish Android APK → Run workflow**.

Tu es sur `staging` : rien n’est construit pour le store tant que `main` n’a pas ces commits.

## 1. Keystore (une fois, à garder)

Sans signature release, aucun store sérieux ne prendra l’app.

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Copie locale (non git) :

```bash
cp android/key.properties.example android/key.properties
# storePassword / keyPassword / keyAlias=upload
# storeFile=upload-keystore.jks  →  placer le .jks dans android/app/
```

`android/key.properties` et `*.jks` sont dans `.gitignore`.

Secrets GitHub (Settings → Secrets and variables → Actions) :

| Secret | Contenu |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w 0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du fichier |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

Sans ces secrets, le job **échoue** (pas d’APK debug publié comme « release »).

## 2. SHA-1 release dans Firebase

Google Sign-In sur l’APK du store exige l’empreinte **release** (pas seulement debug) :

```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
```

Console Firebase → `flutter-pwd-container` → app Android → **Ajouter une empreinte**.

## 3. Déposer l’APK sur Uptodown

1. Crée un compte sur [developers.uptodown.com](https://developers.uptodown.com/).
2. **Add application** / nouvelle application Android.
3. Télécharge `SafeVault-{version}.apk` depuis la [Release GitHub](https://github.com/VictorSulivan/flutter_pwd_container/releases).
4. Envoie cet APK. Uptodown lit le package `com.example.flutter_pwd_container` et la version dans le fichier.
5. Fiche store (à coller) :

| Champ | Valeur |
| --- | --- |
| Nom | SafeVault |
| Package | `com.example.flutter_pwd_container` |
| Catégorie | Productivité / Sécurité |
| Courte | Coffre de mots de passe chiffré sur le téléphone. |
| Longue | SafeVault garde tes identifiants en local (AES-256-GCM, mot de passe maître). La session Google ne sert qu’à l’identité. Aucun mot de passe n’est envoyé à Firebase ni à Gemini. |

Icône : `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (ou le webp équivalent du projet).

Les mises à jour suivantes : même compte, **même keystore**, nouvel APK avec `version` incrémentée dans `pubspec.yaml`.

## Sauvegarde Android

`allowBackup=false` : le coffre local ne part pas dans la sauvegarde Google.

## Build local (test, pas store)

Sans `android/key.properties`, `flutter build apk --release` signe encore en **debug**. Ne l’envoie pas à Uptodown.
