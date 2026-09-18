# Changelog — BirdingLog FR

Ce fichier regroupe les évolutions du fork français maintenu par **Dusk-92**.
L'historique original de Birding Log reste disponible dans `Dusk/BirdingLog/Updates.txt` et dans l'historique Git.

## 1.3-FR7.22 — 18 septembre 2026

- `BL_Main.lua` est réduit à la construction des données, de l’UI, de l’aide et des options ; le runtime consolidé possède seul chat, commandes, sauvegardes et unload.
- `BL_Totals` et `BL_PendingShortcuts` sont protégés comme un groupe atomique : l’échec de lecture de l’un interdit la réécriture des deux pendant la session.
- Les racines PluginData d’un type invalide sont mises en quarantaine au lieu d’être remplacées silencieusement par une table vide sur disque.
- Les compteurs d’observations et la maîtrise sont normalisés en entiers positifs.
- Les anciens champs `kitBypass` et la logique de validation de catégorie du runtime actif sont supprimés.
- Le slot Kit, Arme et 2e emplacement n’ont plus qu’un seul propriétaire de `ShortcutChanged` : `BL_Runtime716.lua`.
- La langue du client est détectée avec `Turbine.Engine.GetLanguage()`.
- Les titres FR 10/30/50/70/100 sont alignés sur les récompenses actuelles du jeu.
- Les événements clavier de la fenêtre ne restent actifs que lorsque la fenêtre est visible.
- L’état de l’icône passe par les helpers PluginData protégés ; une lecture défectueuse de `BL_IconState` n’est jamais écrasée.
- Les corrections de géométrie et de noms de récompenses allemandes sont intégrées directement dans `BL_Data_DE.lua`.
- Ajout d’un test de régression Lua pour les sauvegardes normales, encodées une fois/deux fois, changement de langue et erreur de lecture.
- Le CI vérifie désormais aussi l’unicité des propriétaires runtime, la parité géométrique EN/DE, les titres FR et le XML du plugin.

## 1.3-FR7.21 — 18 septembre 2026

- BirdingLog utilise désormais l’appartement Lua dédié `BirdingLog` au lieu de l’appartement partagé `Dusk`.
- `Dusk/Common` ne remplace plus globalement `Turbine.PluginData.Load/Save`; ses helpers sont locaux au plugin.
- Les anciennes sauvegardes marquées `$` / `#` sont relues sur tous les clients, avec récupération d’une éventuelle double couche d’encodage.
- Une clé dont la lecture échoue n’est plus réécrite pendant la session, afin d’éviter une perte de données.
- La compatibilité Kit est intégrée dans `BL_Runtime716.lua`; `BL_Runtime717.lua` est supprimé.
- Le rang affiché dans la fenêtre utilise désormais `BL_TitleFR` sur le client français.
- Le niveau est rafraîchi directement lors du gain de maîtrise ; le polling `Update` permanent est supprimé.
- L’ajout manuel d’un oiseau déclenche directement la sauvegarde, sans dépendre du texte imprimé.
- Le préflight utilise désormais la vraie taille de fenêtre `360x295` et nettoie les effets de `BL_Main` si le runtime moderne échoue à charger.

## 1.3-FR7.20 — 17 septembre 2026

- La fenêtre principale passe de `340x275` à `360x295` pour mieux respirer autour de la ligne de maîtrise ajoutée en FR7.19.
- Les blocs **Kit / Observer** et **Arme / 2e slot** sont légèrement descendus et davantage espacés horizontalement.
- Les boutons de zone, listes et totaux sont redistribués sur la largeur supplémentaire, avec des boutons de `135 px` de large.
- La ligne **Ajouter** est descendue et son menu est élargi à `220 px`.
- La logique de maîtrise, les Quickslots, commandes, données et sauvegardes restent inchangés.

## 1.3-FR7.19 — 17 septembre 2026

- La fenêtre principale affiche désormais la maîtrise d’ornithologie directement sous son titre.
- Le format FR est `Ornithologie : niveau X — Rang`, avec le meilleur rang atteint à partir de `BL_Title`.
- Avant le premier niveau connu, la fenêtre affiche `Ornithologie : niveau inconnu`.
- L’affichage est rafraîchi automatiquement tant que la fenêtre est visible ; un niveau gagné pendant qu’elle est fermée apparaît dès sa prochaine ouverture.
- Aucun bouton ni Quickslot n’a été déplacé et la fenêtre conserve sa taille `340x275`.
- Le CI vérifie désormais les protections cumulatives FR7.16+ au lieu de les limiter à une version exacte, ainsi que la présence de l’affichage de maîtrise FR7.19.

## 1.3-FR7.18 — 17 septembre 2026

- L'icône flottante BirdingLog n'utilise plus `SetZOrder(1000)`.
- Elle passe sur `SetZOrder(0)`, comme TravelRef et LOTRO Events.
- Les panneaux natifs LOTRO — notamment la carte — peuvent désormais passer devant l'icône.
- Le déplacement, la sauvegarde de position et le clic d'ouverture de BirdingLog restent inchangés.

## 1.3-FR7.17 — 17 septembre 2026

- Le slot **Kit d’ornithologie** n'utilise plus `BL_BirdingKit=104` ni `GetCategory()` pour décider si un objet est valide.
- Le test en jeu avec le **Kit d’ornithologie de base** a confirmé que la catégorie historique `104` ne correspond plus au comportement actuel de LOTRO et provoquait un faux rejet.
- FR7.17 accepte désormais tout raccourci `ShortcutType.Item` possédant des données valides dans le slot Kit, exactement comme les emplacements Arme et 2e slot.
- Les kits déjà sauvegardés sont marqués avant le chargement de `BL_Runtime716` afin que l'ancienne revalidation par catégorie ne puisse pas les supprimer au reload.
- Le handler du slot Kit est remplacé après le runtime consolidé par `BL_Runtime717.lua`; il conserve l'autosave immédiat et le nettoyage des raccourcis pending.
- L'audit automatique vérifie désormais que `BL_Runtime717.lua` ne contient ni `GetCategory()` ni `BL_BirdingKit`, afin d'empêcher le retour de cette régression.
- Aucun changement n'est apporté aux oiseaux, zones, traductions FR, armes ou second emplacement.

## 1.3-FR7.16 — 17 septembre 2026

- Nouveau point d'entrée actif `BL_Loader716.lua` : les anciens `BL_Loader.lua` et `BL_Loader712.lua` ne sont plus empilés dans le chemin d'exécution.
- Le loader FR7.16 effectue uniquement le préflight des sauvegardes, charge `BL_Main` une fois, puis passe la main à `BL_Runtime716.lua`.
- `BL_Runtime716.lua` devient l'unique propriétaire moderne du chat, des sauvegardes, de la localisation FR, des commandes, des Quickslots et de l'unload.
- Les sauvegardes runtime utilisent désormais le callback réel `PluginData.Save(success, message)` au lieu de considérer un `pcall()` réussi comme preuve d'une écriture disque réussie.
- Les écritures runtime sont sérialisées et coalescées : une modification reçue pendant une sauvegarde déclenche une nouvelle passe après la précédente au lieu de lancer une écriture concurrente.
- `BL_Options` est également routé vers cet ordonnanceur depuis `Dusk/Common/Options.lua` quand BirdingLog FR7.16 est actif.
- La localisation dynamique FR utilise un seul runner pour les oiseaux et objets `BL_GID`; il n'existe plus de second probe GID ni d'estimation de son activité en nombre de frames.
- La signature de localisation passe à `BL716` et n'est validée qu'après la sauvegarde réussie de `BL_Names`, `BL_GNames` et `BL_Options`.
- Les noms officiels intégrés à `BL_FR.lua` sont identifiés avant de réappliquer les caches dynamiques, empêchant un ancien cache d'écraser une traduction officielle.
- Le probe de localisation vide son Quickslot de test et vérifie le type ainsi que `GetData()` à chaque ID, ce qui empêche un raccourci rejeté de réutiliser accidentellement l'objet précédent.
- Les Quickslots temporairement indisponibles sont stockés dans `BL_PendingShortcuts` et représentés par `false` dans `BL_Totals`, tandis que `nil` signifie désormais explicitement que le joueur a réellement vidé l'emplacement.
- Une seconde validation est faite sur les vrais Quickslots après création de la fenêtre afin de couvrir un rejet qui surviendrait entre le préflight et le contrôle réel.
- Un kit dont `GetItem()` ou `GetItemInfo()` n'est pas encore résolu est conservé et validé ultérieurement au lieu d'être supprimé à tort.
- Le bypass historique avec **Maj** est persisté via `kitBypass` et reste cohérent après reload.
- Les anciennes sauvegardes de lieux mixtes (ancien format + zones modernes) sont fusionnées sans supprimer les zones modernes déjà présentes.
- Les IDs de compteurs inconnus sont conservés afin d'éviter une perte de données lors d'un downgrade ou d'un décalage de base.
- Le `BL_Bname` est reconstruit depuis zéro après localisation afin qu'un ancien alias appris ne reste pas attaché indéfiniment.
- Le Chapeau d'ornithologue (`6B900`) est reconnu comme objet connu du hobby sans être traité comme récompense de zone.
- Les anciennes différences de géométrie DE et deux différences de casse sur les noms de zones de récompenses sont corrigées au runtime.
- Les commandes `sight` et `zones` sont maintenant strictement limitées à `/bl`; elles ne peuvent plus intercepter accidentellement `/bll` ou `/blg`.
- L'unload arrête le runner de localisation, invalide le handler chat, masque les fenêtres et retire la commande shell BirdingLog.
- Ajout de `.github/workflows/audit.yml` et `tools/audit_repo.py` : compilation de tous les Lua en 5.1 et contrôles automatiques des versions, IDs, zones, couverture FR, point d'entrée et protections essentielles.
- `Dusk/Common/Options.lua` reste strictement synchronisé entre BirdingLog et FishingLog.

## 1.3-FR7.15 — 17 septembre 2026

- `/bl fr` ne déduit plus qu'une localisation est active uniquement depuis `frProbeVersion` : FR7.15 maintient un état runtime de localisation.
- Les demandes manuelles de refresh sont regroupées lorsqu'une passe est déjà en cours.
- `BL715_SaveRetryPending` force une nouvelle tentative de sauvegarde lors de la prochaine modification après un échec.

## 1.3-FR7.14 — 17 septembre 2026

- Restauration silencieuse d'un kit temporairement non résolu afin d'éviter le faux message « Objet introuvable ».
- Différé de `/bl fr` lorsqu'une passe oiseaux est déjà active.
- Signalement des échecs synchrones d'autosave.
- Sauvegarde immédiate du changement d'échelle et synchronisation de `Dusk/Common/Options.lua` avec FishingLog.

## 1.3-FR7.13 — 17 septembre 2026

- Le validateur de raccourcis contrôle le `ShortcutType.Item` et la donnée réellement restituée par Turbine.
- Détection des Quickslots silencieusement rejetés.
- Conservation d'un kit accepté mais temporairement non résolu.

## 1.3-FR7.12 — 17 septembre 2026

- Ajout du loader de durcissement précoce des Quickslots et de la position de fenêtre.
- Autosave toutes les 10 observations reconnues et sauvegardes immédiates des changements importants.
- `/bl fr` devient un vrai refresh des caches de noms dynamiques.

## 1.3-FR7.11 — 17 septembre 2026

- Assainissement des options et totaux avant création de l'interface.
- Bornage de l'échelle entre `0.5` et `2.0`.
- Fenêtre restaurée maintenue dans les limites de la résolution actuelle.

## 1.3-FR7.10 — 17 septembre 2026

- Reconnaissance des récompenses connues indépendamment de `/bl track`.
- Normalisation des compteurs issus de sauvegardes anciennes/corrompues.
- Signature de localisation enregistrée seulement après la fin des probes nécessaires.
- Isolation du cache FR sur les clients EN/DE.

## 1.3-FR7.9 — 17 septembre 2026

- Signature déterministe basée sur les IDs oiseaux/objets.
- Cache `BL_GNames` séparé pour les objets d'ornithologie.
- Suppression de `loadstring()` dans la conversion `PluginData` partagée.

## 1.3-FR7.8 — 17 septembre 2026

- Future-proofing du probe FR, nettoyage des métadonnées du fork et ajout du README principal.

## 1.3-FR7.7 — 17 septembre 2026

- Anti-doublon du handler chat, listes sûres, validation du kit restauré et détection de zone déterministe.

## FR7.x précédentes

- Traduction et adaptation au client français.
- Base officielle de noms français liée aux IDs internes LOTRO.
- Gestion des noms localisés identiques.
- Icône flottante et sauvegarde de position.
- Compatibilité renforcée avec les anciennes sauvegardes.

Pour les détails fins des étapes FR3 à FR7.6 et de l'historique original, consulter l'historique Git et `Dusk/BirdingLog/Updates.txt`.
