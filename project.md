Description Complète des Fonctionnalités du Projet
1. Authentification & Gestion de Session (Firebase Auth)

    Inscription et Connexion Multi-Provider :

        Connexion classique par e-mail / mot de passe.

        Connexion rapide via Google (Gmail) et autres identifiants tiers grâce à Firebase.

    Sécurisation de l'Accès :

        Déconnexion automatique après inactivité.

        Déverrouillage optionnel via biométrie (Empreinte digitale / Face ID).

2. Stockage Local Sécurisé (Chiffrement LocalStorage)

    Coffre-fort d'Identifiants :

        Gestion des fiches comptes (Nom du service, URL, Identifiant/E-mail, Mot de passe chiffré, Date de création/modification).

    Chiffrement Fort en Local :

        Les secrets sont chiffrés localement (AES-256) sur le téléphone avant écriture dans le stockage local (EncryptedStorage / AsyncStorage).

3. Générateur de Mots de Passe Indépendants

    Création Personnalisée :

        Réglage de la longueur et choix des caractères (majuscules, minuscules, chiffres, symboles).

    Copie Sécurisée :

        Copie en un clic avec nettoyage automatique du presse-papier après 30 secondes.

4. Système de Notifications & Alertes de Sécurité (Nouveau)

    Alertes en Temps Réel (In-App & Push) :

        Détection de Similitude / Doublons : Alerte automatique si deux fiches partagent une empreinte/hash identique de mot de passe (sans avoir besoin d'afficher ou de comparer les mots de passe en clair).

        Alerte d'Obsolescence : Notification programmable (ex: tous les 90 ou 180 jours) suggérant d'actualiser les mots de passe des comptes critiques (banque, e-mail principal).

        Alerte de Faiblesse : Notification si un compte nouvellement enregistré utilise une structure jugée trop fragile.

5. Assistant IA : Analyseur de Sécurité (Zero-Knowledge)

    Évaluation Contextuelle Sans Risque :

        L'IA analyse uniquement la métadonnée anonymisée transmise par l'application (ex: "Longueur: 10, Contient des chiffres: Oui, Ancienneté: 200 jours, Doublon détecté: Oui").

        Restitution en Langage Naturel : Génération d'un résumé clair synthétisant les alertes de notification sous forme de conseils bienveillants (ex: "3 de vos comptes principaux partagent la même structure de mot de passe et n'ont pas été modifiés cette année").