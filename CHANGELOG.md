# Changelog — BirdingLog FR

Ce fichier regroupe les évolutions du fork français maintenu par **Dusk-92**.
L'historique original de Birding Log reste disponible dans `Dusk/BirdingLog/Updates.txt` et dans l'historique Git.

## 1.3-FR7.11 — 17 septembre 2026

- `BL_Options` est désormais assaini **avant** que `BL_Main` crée la fenêtre et le panneau d'options.
- Les positions `pos1`, `pos2` et `iconPos` invalides sont ignorées au lieu d'être transmises aux contrôles Turbine.
- `scale` est converti en nombre et borné entre `0.5` et `2.0` avant toute multiplication ou appel à `SetScale()`.
- `BL_Totals.fp` est validé comme nombre positif ou nul ; une valeur corrompue ne peut plus faire échouer `/bl`.
- Les raccourcis sauvegardés `kit`, `wpn` et `shl` sont ignorés s'ils ne sont pas des chaînes exploitables.
- Les compteurs d'oiseaux et de zones conservent la seconde validation post-chargement introduite en FR7.10.
- La fenêtre principale restaurée est re-bornée à la résolution actuelle afin qu'elle ne puisse pas rester hors écran après un changement de moniteur ou de résolution.
- La signature de localisation reste `BL710` : FR7.11 ne modifie ni `BL_ID` ni `BL_GID`, donc aucune nouvelle passe FR inutile n'est déclenchée.

## 1.3-FR7.10 — 17 septembre 2026

- Les récompenses connues de `BL_GID` sont désormais reconnues et leur nom FR peut être appris même lorsque `/bl track` est désactivé.
- Les compteurs d'oiseaux et de zones issus d'anciennes sauvegardes sont normalisés avant toute opération arithmétique ; une valeur non numérique ne peut plus provoquer une erreur lors d'un `+1`.
- Les entrées de zone corrompues qui ne sont plus des tables sont recréées proprement.
- La signature de localisation FR n'est plus enregistrée au lancement des probes : elle n'est validée qu'après la fin effective du probe oiseaux et du probe récompenses.
- Si le plugin est fermé ou si un probe n'aboutit pas avant validation, la signature reste ancienne et la passe sera retentée au chargement suivant.
- Le préfixe de signature passe à `BL710`, ce qui invalide proprement l'ancienne signature FR7.9.
- Le cache appris `BL_Names` n'est plus appliqué aux clients EN/DE ; il reste réservé au client FR afin d'éviter une contamination de langue.
- Les nouveaux noms appris depuis le chat ne sont persistés dans `BL_Names` / `BL_GNames` que sur client FR.

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