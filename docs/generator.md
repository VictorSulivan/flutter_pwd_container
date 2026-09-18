# Générateur

Aucun appel Firebase, aucun stockage. `Random.secure()`. Accessible seulement après déverrouillage du coffre (mot de passe maître).

Options : longueur 8–64, majuscules, minuscules, chiffres, symboles. Au moins un caractère de chaque type coché.

Accès (coffre ouvert) :

- un seul bouton **Générer** dans l’en-tête de la liste
- bouton **Générer** dans le formulaire de fiche (remplit le champ)

Copie : presse-papier vidé après 30 s (comme les fiches).

La force affichée après génération réutilise [`password_health.dart`](../lib/src/services/password_health.dart).
