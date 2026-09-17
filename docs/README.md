# Documentation SafeVault

Ce dossier garde une trace des **choix techniques** déjà en place : à quoi sert chaque brique, et pourquoi elle est faite comme ça.

Le cahier des charges produit est dans [`../project.md`](../project.md). Ici on documente **ce qui est vraiment dans le code**, pas la vision complète.

| Document | Contenu |
| --- | --- |
| [architecture.md](architecture.md) | Vue d’ensemble, arborescence, flux de démarrage |
| [auth.md](auth.md) | Firebase, Google Sign-In, session, redirections |
| [riverpod.md](riverpod.md) | Providers : rôle de chacun, ce que Riverpod n’est pas |
| [vault.md](vault.md) | Coffre AES-256-GCM, PBKDF2, isolation par uid |
| [firebase-sync.md](firebase-sync.md) | Config console Firestore (règles, document prévu) |
| [decisions.md](decisions.md) | Décisions figées (pourquoi X plutôt que Y) |
| [roadmap.md](roadmap.md) | Fait / pas encore fait, ordre des prochaines étapes |
