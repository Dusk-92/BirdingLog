# Changelog — BirdingLog FR

Ce fichier regroupe les évolutions du fork français maintenu par **Dusk-92**.
L'historique original de Birding Log reste disponible dans `Dusk/BirdingLog/Updates.txt` et dans l'historique Git.

## 1.3-FR7.9 — 17 septembre 2026

- Remplacement du déclenchement FR basé uniquement sur `frProbeVersion` par une **signature déterministe de la base d'ID**.
- Une modification de `BL_ID` ou `BL_GID` autorise automatiquement une nouvelle passe de localisation.
- Un ID impossible à résoudre n'est plus retenté automatiquement à chaque connexion.
- `/bl fr` conserve la possibilité de forcer une nouvelle tentative manuelle.
- Ajout d'un cache persistant `BL_GNames` pour les noms localisés des récompenses et objets d'ornithologie.
- Le suivi chat peut mémoriser un nom localisé de récompense rencontré en jeu.
- Durcissement partagé de `Dusk/Common` dans BirdingLog et FishingLog.
- Suppression de `loadstring()` pour la conversion des nombres PluginData.
- Conversion sûre avec `tonumber()` en acceptant point ou virgule selon la locale.
- Les données numériques invalides sont conservées sous forme de texte au lieu de provoquer une erreur au chargement.
- Correction de la date historique de la version 1.1.4 dans `Updates.txt`.
- Consolidation de la documentation de versions dans ce changelog.

## 1.3-FR7.8 — 17 septembre 2026

- Le probe FR n'est plus définitivement bloqué par l'ancien marqueur `frProbeVersion=3` lorsqu'une future base contient des oiseaux sans nom FR.
- Métadonnées du fork nettoyées et site redirigé vers le dépôt GitHub Dusk-92.
- Suppression du `.plugincompendium` utilisant l'identifiant LOTROInterface 1241 de la publication originale.
- Ajout d'un `README.md` complet.

## 1.3-FR7.7 — 17 septembre 2026

- Anti-doublon du handler de chat renforcé par génération.
- Listes protégées contre les anciens ID invalides/corrompus.
- `/bl zones` ne compte plus les totaux à zéro comme observés.
- Validation du kit restauré depuis une ancienne sauvegarde.
- Détection de zone rendue déterministe en cas de rectangles superposés.

## FR7.x précédentes

- Traduction et adaptation du fonctionnement au client français.
- Base officielle de noms français liée aux ID internes LOTRO.
- Gestion des noms localisés identiques.
- Icône flottante et sauvegarde de sa position.
- Amélioration de la détection de zone et des coordonnées FR.
- Compatibilité renforcée avec les anciennes sauvegardes.

Pour les détails fins des étapes FR3 à FR7.6, consulter l'historique Git du dépôt.
