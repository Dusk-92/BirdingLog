# BirdingLog FR

Fork français de **Birding Log** pour *The Lord of the Rings Online (LOTRO)*.

- Addon original : **Birding Log** par David Down (Vinny)
- Adaptation / maintenance FR : **Dusk-92**
- Version du fork : **1.3-FR7.8**
- Addon original : https://www.lotrointerface.com/downloads/info1241

## Objectif du fork

Cette version conserve le fonctionnement original de Birding Log tout en améliorant son utilisation sur le client français de LOTRO :

- interface et messages principaux en français ;
- noms français officiels des oiseaux préchargés par ID interne ;
- suivi des observations indépendant de la langue du nom d'objet ;
- détection des messages d'observation sur client FR ;
- coordonnées françaises avec virgule décimale et `O` pour Ouest ;
- récupération progressive des futurs noms localisés directement depuis le client LOTRO ;
- protections contre les doubles handlers de chat après reload ;
- validation des anciennes sauvegardes et du kit restauré ;
- gestion plus sûre des noms localisés identiques ;
- détection de zone déterministe lorsque plusieurs rectangles se chevauchent.

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
/bl fr          Relancer manuellement la récupération des noms FR
/bl track       Activer/désactiver le suivi des oiseaux inconnus
/blw            Ouvrir la fenêtre BirdingLog
/bll zone       Lister les oiseaux de la zone sélectionnée
/bll list       Lister les observations de la zone sélectionnée
/blg            Afficher la récompense de la zone sélectionnée
```

Le bouton **Détecter zone** utilise la commande LOTRO `;loc` et les coordonnées connues par BirdingLog. Les frontières réelles de certaines zones ne sont pas rectangulaires : le menu manuel reste donc le moyen de corriger une détection de frontière exceptionnelle.

## Données françaises

La base française est associée aux **ID internes LOTRO**, et non aux noms anglais. Les noms officiels connus sont préchargés dans `BL_FR.lua`.

À partir de FR7.8, si une future mise à jour de `BL_Data.lua` introduit un oiseau sans nom français préchargé, BirdingLog autorise automatiquement une nouvelle tentative de récupération du nom depuis le client LOTRO. `/bl fr` reste disponible pour forcer cette opération.

## Sauvegardes

BirdingLog conserve notamment :

- les totaux du personnage ;
- les observations par zone ;
- les options de fenêtre ;
- la position de l'icône ;
- les noms localisés appris depuis LOTRO.

Les anciennes données restent compatibles avec le fork.

## À propos de `Dusk/Common`

BirdingLog et FishingLog utilisent actuellement la même bibliothèque historique `Dusk/Common`. Elle est volontairement conservée partagée dans cette version : la dupliquer naïvement ferait installer plusieurs wrappers globaux de `Turbine.PluginData.Load/Save` sur les clients FR/DE. Une éventuelle séparation devra donc être effectuée simultanément dans les addons concernés.

## Plugin Compendium

Le fichier `.plugincompendium` de l'addon original utilisait l'identifiant LOTROInterface **1241**, qui appartient à la publication originale. Il n'est pas utilisé comme identité de ce fork afin d'éviter qu'un gestionnaire de mises à jour confonde la version Dusk avec la version officielle.

## Crédits

Birding Log a été créé par **David Down**. Ce dépôt conserve son travail d'origine et ajoute les adaptations françaises et correctifs de maintenance du fork Dusk-92.

Aucune licence différente de celle éventuellement applicable au projet original n'est revendiquée ici.
