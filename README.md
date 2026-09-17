# BirdingLog FR

Fork français de **Birding Log** pour *The Lord of the Rings Online (LOTRO)*.

- Addon original : **Birding Log** par David Down (Vinny)
- Adaptation / maintenance FR : **Dusk-92**
- Version du fork : **1.3-FR7.16**
- Addon original : https://www.lotrointerface.com/downloads/info1241

## Objectif du fork

Cette version conserve l'interface et les données historiques de Birding Log tout en renforçant son fonctionnement sur les clients français, anglais et allemands :

- interface et messages principaux en français sur le client FR ;
- noms français officiels des oiseaux liés aux ID internes LOTRO ;
- suivi des observations indépendant de la langue du nom d'objet ;
- coordonnées FR avec virgule décimale et `O` pour Ouest ;
- détection de zone déterministe lorsque plusieurs rectangles se chevauchent ;
- caches séparés pour les noms d'oiseaux et d'objets appris dynamiquement ;
- Quickslots sauvegardés vérifiés contre les rejets silencieux de Turbine ;
- récupération automatique d'un raccourci temporairement indisponible ;
- conservation explicite du bypass **Maj** utilisé historiquement pour un kit ;
- assainissement des anciennes sauvegardes avant création de l'interface ;
- autosave périodique et sauvegardes immédiates des changements importants ;
- sauvegardes runtime vérifiées avec le callback réel de `PluginData.Save` ;
- nettoyage renforcé des handlers, commandes et contrôles asynchrones à l'unload ;
- audit GitHub Actions avec compilation Lua 5.1 et contrôles d'invariants.

## Installation

Copier le dossier `Dusk` dans :

```text
Documents\The Lord of the Rings Online\Plugins\
```

Le fichier principal doit ensuite se trouver ici :

```text
Documents\The Lord of the Rings Online\Plugins\Dusk\BirdingLog.plugin
```

Dans LOTRO, actualiser le gestionnaire de plugins puis charger **BirdingLog**.

## Commandes principales

```text
/bl             Afficher la maîtrise d'ornithologie
/bl sight       Afficher les observations personnelles
/bl zones       Afficher la progression par zone
/bl fr          Rafraîchir les noms FR appris dynamiquement
/bl track       Activer/désactiver le suivi des objets réellement inconnus
/blw            Ouvrir la fenêtre BirdingLog
/bll zone       Lister les oiseaux de la zone sélectionnée
/bll list       Lister les observations de la zone sélectionnée
/blg            Afficher la récompense de la zone sélectionnée
```

Le bouton **Détecter zone** utilise la commande LOTRO `;loc` (ou son équivalent localisé) et les coordonnées connues par BirdingLog. Les frontières réelles de certaines zones ne sont pas parfaitement rectangulaires : le menu manuel reste disponible pour corriger un cas de frontière exceptionnel.

## Architecture FR7.16

Depuis **FR7.16**, le point d'entrée est :

```text
Dusk.BirdingLog.BL_Loader716
```

`BL_Loader716.lua` effectue uniquement le **préflight** des sauvegardes sensibles, charge une seule fois le cœur historique `BL_Main`, puis passe la main à `BL_Runtime716.lua`.

Les anciens `BL_Loader.lua` et `BL_Loader712.lua` restent dans le dépôt pour l'historique mais **ne sont plus dans le chemin d'exécution actif**. Cela supprime l'empilement de wrappers qui rendait les versions FR7.11 à FR7.15 difficiles à auditer globalement.

Le runtime FR7.16 possède un seul propriétaire pour :

- le handler de chat BirdingLog ;
- les sauvegardes runtime ;
- la localisation dynamique FR ;
- les validations de Quickslots après chargement ;
- les commandes BirdingLog ;
- le nettoyage à l'unload.

## Données françaises et localisation dynamique

La base officielle française est liée aux **ID internes LOTRO**, et non aux noms anglais. Les traductions connues sont chargées depuis `BL_FR.lua`.

FR7.16 reconstruit à chaque chargement la liste des IDs disposant d'un nom FR officiel **avant** de réappliquer les caches dynamiques. Un ancien nom appris ne peut donc pas écraser une traduction intégrée au plugin.

Les noms appris dynamiquement sont conservés séparément :

- `BL_Names` pour les oiseaux ;
- `BL_GNames` pour les récompenses et objets liés au hobby.

`/bl fr` ne détruit pas les traductions officielles. Il re-sonde uniquement les IDs non officiels qui en ont besoin, ou tous les IDs dynamiques lors d'un refresh manuel. L'ancien nom appris reste disponible si LOTRO ne renvoie rien de nouveau.

FR7.16 utilise **un seul runner de localisation réel** pour oiseaux et objets. Il n'y a plus de second probe GID ni d'estimation de son activité par nombre de frames. Une demande `/bl fr` reçue pendant une passe ou une sauvegarde est mise en attente puis rejouée proprement.

La signature de base passe au préfixe **`BL716`**. Elle n'est validée qu'après :

1. la fin réelle du probe ;
2. la sauvegarde réussie de `BL_Names` ;
3. la sauvegarde réussie de `BL_GNames` ;
4. la sauvegarde réussie de `BL_Options` contenant la nouvelle signature.

Si une de ces écritures échoue, la signature précédente est conservée afin qu'une session ultérieure puisse réessayer.

Le **Chapeau d'ornithologue** (`6B900`) est également reconnu comme objet connu du hobby sans être traité comme une récompense de zone.

## Quickslots et anciennes sauvegardes

Les champs sauvegardés `kit`, `wpn` et `shl` sont testés avant que `BL_Window` ne crée ses contrôles :

- construction d'un `ShortcutType.Item` ;
- application dans un Quickslot de test caché ;
- vérification du type retourné ;
- vérification exacte de `GetData()`.

Un raccourci momentanément rejeté par LOTRO n'est plus détruit. FR7.16 le place dans `BL_PendingShortcuts` et met une valeur `false` explicite dans le champ actif. Cette distinction est importante :

- `false` = raccourci en attente, à retenter au prochain chargement ;
- `nil` = emplacement réellement vidé par le joueur, à ne jamais ressusciter.

Si le joueur modifie ou vide ensuite l'emplacement, l'entrée pending est supprimée.

Pour le kit d'ornithologie, la catégorie est vérifiée dès que `GetItemInfo()` est réellement disponible. Un kit accepté mais pas encore résolu est conservé et revalidé plus tard. Le bypass historique obtenu avec **Maj** est désormais enregistré avec le raccourci et reste donc cohérent après un reload.

Une seconde validation est effectuée sur les vrais Quickslots après construction de la fenêtre afin de couvrir le cas où le probe de préflight accepte un raccourci mais où le contrôle réel le rejette quelques instructions plus tard.

## Sauvegardes et crash-loss protection

BirdingLog sauvegarde notamment :

- les totaux du personnage et sa maîtrise ;
- les observations par zone ;
- les options de fenêtre ;
- les raccourcis d'équipement ;
- les raccourcis temporairement indisponibles ;
- les caches de noms dynamiques.

Les observations déclenchent un autosave toutes les **10 observations reconnues**. Les changements importants — maîtrise, équipement, nouveau nom appris, ajout manuel et compteur manuel — déclenchent une sauvegarde immédiate.

FR7.16 sérialise ces écritures pour éviter que plusieurs sauvegardes des mêmes tables se chevauchent. Si une modification arrive pendant une sauvegarde, une nouvelle passe est regroupée et exécutée juste après.

Contrairement aux anciennes couches qui considéraient qu'un `pcall()` réussi signifiait que la sauvegarde avait réussi, FR7.16 utilise le **callback `PluginData.Save(success, message)`**. Un échec réel laisse le retry actif et la modification suivante provoque une nouvelle tentative.

`Dusk/Common/Options.lua` route également les sauvegardes de `BL_Options` vers cet ordonnanceur lorsque FR7.16 est chargé. Les mouvements rapides du curseur d'échelle sont donc coalescés au lieu de lancer des écritures concurrentes. La fenêtre est immédiatement re-bornée à l'écran après un changement d'échelle.

## Compatibilité des données

Le préflight neutralise les valeurs non numériques, positions invalides et structures de raccourci dangereuses avant qu'elles n'atteignent les contrôles Turbine.

Les anciennes données de lieux sont migrées vers les zones modernes **sans écraser les zones déjà présentes dans une sauvegarde mixte**. Les IDs de compteurs inconnus sont conservés plutôt que supprimés, afin qu'un retour vers une base de données plus récente ne perde pas leur historique.

Sur le client allemand, FR7.16 applique aussi les corrections de géométrie de zones déjà présentes dans la base EN/FR et corrige les deux différences de casse qui empêchaient certaines récompenses de correspondre à leur zone.

Sur les clients FR/DE, `Dusk/Common` conserve le contournement du bug de séparateur décimal de `PluginData`. Le décodage n'utilise pas `loadstring()` : les données sauvegardées ne sont jamais exécutées comme du code Lua.

## Audit automatique

Le dépôt contient désormais `.github/workflows/audit.yml` et `tools/audit_repo.py`.

À chaque push ou pull request, GitHub Actions :

- compile **tous les fichiers Lua avec Lua 5.1** ;
- vérifie la cohérence version / README / changelog / `Updates.txt` ;
- vérifie que le point d'entrée déclaré existe ;
- empêche FR7.16 de revenir vers l'ancien empilement de loaders ;
- compare les ensembles d'IDs oiseaux EN et DE ;
- vérifie toutes les références oiseaux → zones ;
- exige une traduction FR intégrée pour chaque oiseau actuel ;
- vérifie les protections essentielles du runtime FR7.16 ;
- bloque le retour de `loadstring()`.

Cela ne remplace pas un test dans le moteur Turbine de LOTRO, mais attrape automatiquement une grande partie des régressions structurelles avant publication.

## À propos de `Dusk/Common`

BirdingLog et FishingLog utilisent la même bibliothèque historique `Dusk/Common`. Les fichiers partagés maintenus par le fork, notamment `Options.lua`, sont gardés identiques entre les deux dépôts afin qu'installer l'un n'écrase pas l'autre avec une variante incompatible.

## Plugin Compendium

Le fichier `.plugincompendium` de l'addon original utilisait l'identifiant LOTROInterface **1241**, qui appartient à la publication originale. Il n'est pas repris comme identité de ce fork afin d'éviter qu'un gestionnaire de mises à jour confonde la version Dusk avec la version officielle.

## Crédits

Birding Log a été créé par **David Down**. Ce dépôt conserve son travail d'origine et ajoute les adaptations françaises et correctifs de maintenance du fork Dusk-92.

Aucune licence différente de celle éventuellement applicable au projet original n'est revendiquée ici.
