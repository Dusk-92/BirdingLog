# BirdingLog FR

Fork français de **Birding Log** pour *The Lord of the Rings Online (LOTRO)*.

- Addon original : **Birding Log** par David Down (Vinny)
- Adaptation / maintenance FR : **Dusk-92**
- Version du fork : **1.3-FR7.10**
- Addon original : https://www.lotrointerface.com/downloads/info1241

## Objectif du fork

Cette version conserve le fonctionnement original de Birding Log tout en améliorant son utilisation sur le client français de LOTRO :

- interface et messages principaux en français ;
- noms français officiels des oiseaux préchargés par ID interne ;
- suivi des observations indépendant de la langue du nom d'objet ;
- détection des messages d'observation sur client FR ;
- coordonnées françaises avec virgule décimale et `O` pour Ouest ;
- récupération progressive des futurs noms localisés directement depuis le client LOTRO ;
- cache séparé des noms localisés des récompenses/objets d'ornithologie ;
- protections contre les doubles handlers de chat après reload ;
- validation des anciennes sauvegardes et du kit restauré ;
- neutralisation des compteurs non numériques issus de sauvegardes anciennes/corrompues ;
- gestion plus sûre des noms localisés identiques ;
- détection de zone déterministe lorsque plusieurs rectangles se chevauchent ;
- décodage PluginData durci sans exécuter le contenu des sauvegardes comme du code Lua.

## Installation

Copier le dossier `Dusk` dans :

```text
Documents\The Lord of the Rings Online\Plugins\
```

Le fichier principal doit ensuite se trouver ici :

```text
Documents\The Lord of the Rings Online\Plugins\Dusk\BirdingLog.plugin
```

Dans LOTRO, charger l'addon depuis le gestionnaire de plugins.

## Commandes principales

```text
/bl             Afficher la maîtrise d'ornithologie
/bl sight       Afficher les observations personnelles
/bl zones       Afficher la progression par zone
/bl fr          Forcer une nouvelle récupération des noms FR
/bl track       Activer/désactiver le suivi des objets réellement inconnus
/blw            Ouvrir la fenêtre BirdingLog
/bll zone       Lister les oiseaux de la zone sélectionnée
/bll list       Lister les observations de la zone sélectionnée
/blg            Afficher la récompense de la zone sélectionnée
```

Le bouton **Détecter zone** utilise la commande LOTRO `;loc` et les coordonnées connues par BirdingLog. Les frontières réelles de certaines zones ne sont pas rectangulaires : le menu manuel reste donc le moyen de corriger une détection de frontière exceptionnelle.

## Données françaises

La base française est associée aux **ID internes LOTRO**, et non aux noms anglais. Les noms officiels connus sont préchargés dans `BL_FR.lua`.

Depuis **FR7.10**, BirdingLog calcule une signature déterministe à partir des ID d'oiseaux (`BL_ID`) et des objets/récompenses (`BL_GID`). Si une future mise à jour ajoute ou retire des ID, une nouvelle tentative automatique de localisation est autorisée pour cette nouvelle base.

La signature n'est enregistrée qu'une fois les probes nécessaires réellement terminés. Si le plugin est fermé avant la fin, la signature n'est pas validée et la tentative reprendra au prochain chargement. Un ID que le client LOTRO ne sait pas résoudre n'est donc pas retenté à chaque connexion une fois une passe complète terminée. La commande `/bl fr` reste disponible pour forcer une nouvelle tentative manuelle à tout moment.

Les noms localisés des récompenses et objets d'ornithologie appris dynamiquement sont conservés séparément dans `BL_GNames`. Une récompense déjà connue par son ID est reconnue même lorsque `/bl track` est désactivé ; ce mode sert uniquement aux objets réellement inconnus.

Les caches appris `BL_Names` et `BL_GNames` sont appliqués/persistés comme caches français : ils ne doivent pas remplacer les noms natifs d'un lancement EN/DE.

## Sauvegardes

BirdingLog conserve notamment :

- les totaux du personnage ;
- les observations par zone ;
- les options de fenêtre ;
- la position de l'icône ;
- les noms localisés d'oiseaux appris depuis LOTRO ;
- les noms localisés des récompenses/objets appris depuis LOTRO.

Les anciennes données restent compatibles avec le fork. Lors du chargement, les compteurs d'oiseaux et de zones non numériques sont ramenés à une valeur sûre avant toute addition, et une entrée de zone corrompue est recréée sous forme de table vide.

Sur les clients FR/DE, la bibliothèque historique `Dusk/Common` convertit les valeurs PluginData afin de contourner les problèmes de séparateur décimal. Depuis FR7.9, cette conversion n'utilise plus `loadstring()` : les nombres sont décodés avec `tonumber()` en acceptant point ou virgule, et les données invalides sont conservées sans faire planter le chargement.

## À propos de `Dusk/Common`

BirdingLog et FishingLog utilisent actuellement la même bibliothèque historique `Dusk/Common`. Les deux dépôts conservent désormais **exactement la même version durcie** de cette bibliothèque afin d'éviter qu'une installation de l'un remplace `Common` par une version différente de l'autre.

Elle reste volontairement partagée : la dupliquer naïvement ferait installer plusieurs wrappers globaux de `Turbine.PluginData.Load/Save` sur les clients FR/DE.

## Plugin Compendium

Le fichier `.plugincompendium` de l'addon original utilisait l'identifiant LOTROInterface **1241**, qui appartient à la publication originale. Il n'est pas utilisé comme identité de ce fork afin d'éviter qu'un gestionnaire de mises à jour confonde la version Dusk avec la version officielle.

## Historique

Les changements du fork sont résumés dans `CHANGELOG.md`. `Dusk/BirdingLog/Updates.txt` conserve également l'historique historique de Birding Log.

## Crédits

Birding Log a été créé par **David Down**. Ce dépôt conserve son travail d'origine et ajoute les adaptations françaises et correctifs de maintenance du fork Dusk-92.

Aucune licence différente de celle éventuellement applicable au projet original n'est revendiquée ici.
