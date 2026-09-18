# BirdingLog FR

Fork français de **Birding Log** pour *The Lord of the Rings Online (LOTRO)*.

- Addon original : **Birding Log** par David Down (Vinny)
- Adaptation / maintenance FR : **Dusk-92**
- Version du fork : **1.3-FR7.24**
- Addon original : https://www.lotrointerface.com/downloads/info1241

## Objectif du fork

Cette version conserve l'interface et les données historiques de Birding Log tout en renforçant son fonctionnement sur les clients français, anglais et allemands :

- interface et messages principaux en français sur le client FR ;
- noms français officiels des oiseaux liés aux ID internes LOTRO ;
- suivi des observations indépendant de la langue du nom d'objet ;
- coordonnées FR avec virgule décimale et `O` pour Ouest ;
- détection de zone déterministe lorsque plusieurs rectangles se chevauchent ;
- mémorisation des sous-zones extérieures que les coordonnées historiques ne reconnaissent pas ;
- caches séparés pour les noms d'oiseaux et d'objets appris dynamiquement ;
- Quickslots sauvegardés vérifiés contre les rejets silencieux de Turbine ;
- récupération automatique d'un raccourci temporairement indisponible ;
- slot Kit compatible avec les kits LOTRO actuels sans dépendre de l'ancienne catégorie `104` ;
- icône flottante sur la couche UI normale afin que la carte et les panneaux natifs LOTRO puissent passer devant ;
- niveau d'ornithologie et meilleur rang atteint affichés directement dans la fenêtre principale ;
- fenêtre principale légèrement agrandie et redistribuée pour laisser plus d'espace entre les blocs ;
- fenêtre **Prouesses** dédiée : progression par zone, détail des 16 oiseaux requis et récompense connue ;
- assainissement des anciennes sauvegardes avant création de l'interface ;
- autosave périodique et sauvegardes immédiates des changements importants ;
- sauvegardes runtime vérifiées avec le callback réel de `PluginData.Save` ;
- lecture compatible avec les anciennes sauvegardes Dusk simple/double-encodées et changement de langue FR/DE/EN ;
- appartement Lua dédié `BirdingLog`, isolé de FishingLog et TravelRef ;
- nettoyage renforcé des handlers, commandes et contrôles asynchrones à l'unload ;
- état `BL_Totals` + `BL_PendingShortcuts` protégé comme un groupe atomique en cas d'échec de lecture ;
- runtime unique : `BL_Main` construit les données/UI, `BL_Runtime716` possède seul chat, commandes, sauvegardes et unload ;
- compteurs normalisés en entiers positifs et données DE alignées directement dans la base source ;
- tests de régression du codec PluginData (normal, ancien encodage simple/double, changement de langue, erreur de lecture) ;
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
/bl deeds       Ouvrir la fenêtre des prouesses
/bl deed <zone> Ouvrir le détail d’une zone
/bl fr          Rafraîchir les noms FR appris dynamiquement
/bl track       Activer/désactiver le suivi des objets réellement inconnus
/blw            Ouvrir la fenêtre BirdingLog
/bll zone       Lister les oiseaux de la zone sélectionnée
/bll list       Lister les observations de la zone sélectionnée
/blg            Afficher la récompense de la zone sélectionnée
```

Le bouton **Détecter zone** utilise la commande LOTRO `;loc` (ou son équivalent localisé) et les coordonnées connues par BirdingLog.

Depuis **FR7.24**, lorsqu’un lieu utilise une autre carte ou un autre repère de coordonnées et ne peut pas être rattaché immédiatement à l’une des 33 zones d’ornithologie, BirdingLog conserve le nom du lieu et peut apprendre son rattachement de deux façons :

- automatiquement, lorsqu’une ou plusieurs observations d’oiseaux permettent d’identifier sans ambiguïté la zone d’ornithologie ;
- manuellement, en sélectionnant une seule fois la bonne zone dans le menu après l’échec de détection.

L’association est ensuite sauvegardée côté serveur dans `BL_AreaAliases` et réutilisée lors des prochains passages. Les lieux inconnus ne sont donc pas arbitrairement rattachés à une zone : un donjon/raid où le loisir ne produit aucune observation ne sera pas appris automatiquement.

## Architecture FR7.16+

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

**FR7.17** a supprimé la dépendance fonctionnelle à la catégorie historique `104` pour le slot **Kit**. Depuis **FR7.21**, cette compatibilité est intégrée directement à `BL_Runtime716.lua` : `BL_Runtime717.lua` n’est plus nécessaire.

**FR7.18** aligne l'icône flottante sur TravelRef et LOTRO Events : `BL_IconWindow` utilise désormais `SetZOrder(0)`. La carte et les autres panneaux natifs LOTRO peuvent donc la recouvrir normalement.

**FR7.19** ajoute dans la fenêtre principale une ligne de maîtrise du type `Ornithologie : niveau 28 — Bird-brained`. Le meilleur rang atteint est calculé depuis les paliers `BL_Title`. Tant que la fenêtre est visible, l'affichage est rafraîchi automatiquement si la maîtrise change ; si elle était fermée au moment du gain, la nouvelle valeur apparaît dès sa prochaine ouverture.

**FR7.20** agrandit légèrement la fenêtre principale de `340x275` à `360x295` et redistribue les contrôles pour laisser davantage d'espace autour de la maîtrise et des deux rangées d'équipement, sans modifier leur fonctionnement.

### FR7.24 — sous-zones extérieures apprises

FR7.24 complète la détection par rectangles avec un résolveur de sous-zones. Lorsqu’un paysage extérieur utilise des coordonnées différentes de celles de la région historique — par exemple une carte alternative — BirdingLog peut désormais mémoriser le couple `région globale + lieu` et le rattacher à la bonne zone d’ornithologie.

Si la zone est inconnue, BirdingLog n’affiche plus une erreur sèche. Il attend soit une observation suffisamment distinctive pour déduire automatiquement la zone à partir de la base des oiseaux, soit une sélection manuelle unique dans le menu. Une fois apprise, la sous-zone est restaurée automatiquement aux sessions suivantes.

Cette logique ne force pas les donjons et raids dans une région d’ornithologie : sans observation compatible ou validation manuelle, ils restent non associés.

### FR7.23 — suivi des prouesses

FR7.23 ajoute une fenêtre **Prouesses d'ornithologie** accessible depuis le bouton **Prouesses** de la fenêtre principale ou avec `/bl deeds`.

La vue générale affiche les 33 zones connues et leur progression `X/16`. Un clic sur une zone ouvre le détail des oiseaux trouvés/manquants, ainsi que la récompense associée lorsque BirdingLog la connaît. La commande `/bl deed <zone>` ouvre directement une zone par son nom.

La progression est calculée uniquement depuis les observations déjà suivies par BirdingLog (`BL_Totals`) : elle ne prétend pas lire directement le journal natif des prouesses de LOTRO. La fenêtre se rafraîchit immédiatement lorsqu'une nouvelle observation ou un ajout manuel est enregistré.

### FR7.22 — release consolidée

FR7.22 transforme FR7.21 en release candidate plus simple à maintenir : `BL_Main.lua` ne possède plus de handler chat, de commande active, d'unload ou de Quickslot historique. Ces responsabilités appartiennent uniquement à `BL_Runtime716.lua`.

Les deux fichiers personnage `BL_Totals` et `BL_PendingShortcuts` sont traités comme un même groupe de récupération : si l'un échoue à la lecture, aucun des deux n'est réécrit pendant la session. Une racine de sauvegarde d'un type inattendu est également mise en quarantaine plutôt que remplacée sur disque.

Les titres FR affichés dans la fenêtre utilisent les récompenses actuelles : **Amateur d'oiseaux**, **Oiseleur**, **Fauvette acharnée**, **Connaisseur d’ailes**, **Dompteur d’oiseaux**.

### FR7.21 — isolation et migration des sauvegardes

FR7.21 supprime le monkeypatch global de `Turbine.PluginData.Load/Save`. Les helpers de `Dusk/Common` savent relire les anciennes sauvegardes marquées `# BirdingLog FR

Fork français de **Birding Log** pour *The Lord of the Rings Online (LOTRO)*.

- Addon original : **Birding Log** par David Down (Vinny)
- Adaptation / maintenance FR : **Dusk-92**
- Version du fork : **1.3-FR7.21**
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
- slot Kit compatible avec les kits LOTRO actuels sans dépendre de l'ancienne catégorie `104` ;
- icône flottante sur la couche UI normale afin que la carte et les panneaux natifs LOTRO puissent passer devant ;
- niveau d'ornithologie et meilleur rang atteint affichés directement dans la fenêtre principale ;
- fenêtre principale légèrement agrandie et redistribuée pour laisser plus d'espace entre les blocs ;
- assainissement des anciennes sauvegardes avant création de l'interface ;
- autosave périodique et sauvegardes immédiates des changements importants ;
- sauvegardes runtime vérifiées avec le callback réel de `PluginData.Save` ;
- lecture compatible avec les anciennes sauvegardes Dusk simple/double-encodées et changement de langue FR/DE/EN ;
- appartement Lua dédié `BirdingLog`, isolé de FishingLog et TravelRef ;
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

## Architecture FR7.16+

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

**FR7.17** a supprimé la dépendance fonctionnelle à la catégorie historique `104` pour le slot **Kit**. Depuis **FR7.21**, cette compatibilité est intégrée directement à `BL_Runtime716.lua` : `BL_Runtime717.lua` n’est plus nécessaire.

**FR7.18** aligne l'icône flottante sur TravelRef et LOTRO Events : `BL_IconWindow` utilise désormais `SetZOrder(0)`. La carte et les autres panneaux natifs LOTRO peuvent donc la recouvrir normalement.

**FR7.19** ajoute dans la fenêtre principale une ligne de maîtrise du type `Ornithologie : niveau 28 — Bird-brained`. Le meilleur rang atteint est calculé depuis les paliers `BL_Title`. Tant que la fenêtre est visible, l'affichage est rafraîchi automatiquement si la maîtrise change ; si elle était fermée au moment du gain, la nouvelle valeur apparaît dès sa prochaine ouverture.

**FR7.20** agrandit légèrement la fenêtre principale de `340x275` à `360x295` et redistribue les contrôles pour laisser davantage d'espace autour de la maîtrise et des deux rangées d'équipement, sans modifier leur fonctionnement.

 / `#`, y compris une double couche laissée par d’anciens ordres de chargement. Une lecture en erreur désactive l’écriture de la clé concernée pour la session afin d’éviter d’écraser une sauvegarde valide.

Le niveau d’ornithologie rafraîchit désormais directement la fenêtre lors du message de progression, sans polling à chaque frame. Le rang FR utilise `BL_TitleFR`, et l’ajout manuel appelle directement l’autosave.

## Données françaises et localisation dynamique

La base officielle française est liée aux **ID internes LOTRO**, et non aux noms anglais. Les traductions connues sont chargées depuis `BL_FR.lua`.

FR7.16 reconstruit à chaque chargement la liste des IDs disposant d'un nom FR officiel **avant** de réappliquer les caches dynamiques. Un ancien nom appris ne peut donc pas écraser une traduction intégrée au plugin.

Les noms appris dynamiquement sont conservés séparément :

- `BL_Names` pour les oiseaux ;
- `BL_GNames` pour les récompenses et objets liés au hobby.

`/bl fr` ne détruit pas les traductions officielles. Il re-sonde uniquement les IDs non officiels qui en ont besoin, ou tous les IDs dynamiques lors d'un refresh manuel. L'ancien nom appris reste disponible si LOTRO ne renvoie rien de nouveau.

FR7.16 utilise **un seul runner de localisation réel** pour oiseaux et objets. Il n'y a plus de second probe GID ni d'estimation de son activité par nombre de frames. Une demande `/bl fr` reçue pendant une passe ou une sauvegarde est mise en attente puis rejouée proprement.

La signature de base utilise le préfixe **`BL716`**. Elle n'est validée qu'après :

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

Depuis **FR7.17**, le slot **Kit d'ornithologie** n'utilise plus `GetItemInfo():GetCategory()` ni la constante historique `BL_BirdingKit=104`. Le test runtime dans LOTRO a montré que cette valeur pouvait rejeter le véritable **Kit d'ornithologie de base**. Le slot Kit accepte donc désormais tout raccourci de type `Item` dont les données sont valides, comme les emplacements Arme et 2e slot. Cette règle s'applique aussi aux futurs kits que LOTRO pourrait exposer avec une autre catégorie interne.

En **FR7.21**, la validation du Kit est directement intégrée au runtime principal : aucun contrôle par catégorie `104` n’est exécuté et aucune surcouche séparée n’est nécessaire. Les raccourcis pending et la sauvegarde immédiate restent pris en charge.

Une seconde validation est toujours effectuée sur les vrais Quickslots après construction de la fenêtre afin de couvrir le cas où le probe de préflight accepte un raccourci mais où le contrôle réel le rejette quelques instructions plus tard.

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

`Dusk/Common/Options.lua` route également les sauvegardes de `BL_Options` vers cet ordonnanceur lorsque le runtime consolidé est chargé. Les mouvements rapides du curseur d'échelle sont donc coalescés au lieu de lancer des écritures concurrentes. La fenêtre est immédiatement re-bornée à l'écran après un changement d'échelle.

## Compatibilité des données

Le préflight neutralise les valeurs non numériques, positions invalides et structures de raccourci dangereuses avant qu'elles n'atteignent les contrôles Turbine.

Les anciennes données de lieux sont migrées vers les zones modernes **sans écraser les zones déjà présentes dans une sauvegarde mixte**. Les IDs de compteurs inconnus sont conservés plutôt que supprimés, afin qu'un retour vers une base de données plus récente ne perde pas leur historique.

Sur le client allemand, FR7.16 applique aussi les corrections de géométrie de zones déjà présentes dans la base EN/FR et corrige les deux différences de casse qui empêchaient certaines récompenses de correspondre à leur zone.

Sur les clients FR/DE, `Dusk/Common` conserve le contournement du bug de séparateur décimal de `PluginData`. Le décodage n'utilise pas `loadstring()` : les données sauvegardées ne sont jamais exécutées comme du code Lua.

## Audit automatique

Le dépôt contient `.github/workflows/audit.yml` et `tools/audit_repo.py`.

À chaque push ou pull request, GitHub Actions :

- compile **tous les fichiers Lua avec Lua 5.1** ;
- vérifie la cohérence version / README / changelog / `Updates.txt` ;
- vérifie que le point d'entrée déclaré existe ;
- empêche le retour vers l'ancien empilement de loaders ;
- compare les ensembles d'IDs oiseaux et objets EN/DE ;
- vérifie toutes les références oiseaux → zones ;
- exige une traduction FR intégrée pour chaque oiseau et objet actuel ;
- vérifie les protections essentielles du runtime consolidé ;
- vérifie que le handler Kit consolidé n’utilise plus la catégorie historique `104` ;
- vérifie que l'icône reste sur `SetZOrder(0)` depuis FR7.18 ;
- vérifie la présence de l'affichage dynamique de maîtrise depuis FR7.19 ;
- bloque le retour de `loadstring()`.

Cela ne remplace pas un test dans le moteur Turbine de LOTRO, mais attrape automatiquement une grande partie des régressions structurelles avant publication.

## À propos de `Dusk/Common`

BirdingLog et FishingLog embarquent toujours la même bibliothèque historique `Dusk/Common`, gardée strictement identique dans les deux dépôts. Depuis FR7.21/FR8.5, chaque plugin utilise toutefois son **propre appartement Lua** et les helpers PluginData sont locaux : installer ou charger l’un ne modifie plus le runtime de l’autre ni celui de TravelRef.

## Plugin Compendium

Le fichier `.plugincompendium` de l'addon original utilisait l'identifiant LOTROInterface **1241**, qui appartient à la publication originale. Il n'est pas repris comme identité de ce fork afin d'éviter qu'un gestionnaire de mises à jour confonde la version Dusk avec la version officielle.

## Crédits

Birding Log a été créé par **David Down**. Ce dépôt conserve son travail d'origine et ajoute les adaptations françaises et correctifs de maintenance du fork Dusk-92.

Aucune licence différente de celle éventuellement applicable au projet original n'est revendiquée ici.
