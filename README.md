# BirdingLog FR

Fork français de **Birding Log** pour *The Lord of the Rings Online (LOTRO)*.

- Addon original : **Birding Log** par David Down (Vinny)
- Adaptation / maintenance FR : **Dusk-92**
- Version du fork : **1.3-FR7.15**
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
- validation des anciennes sauvegardes, de la maîtrise et des raccourcis restaurés ;
- détection des Quickslots silencieusement rejetés par Turbine ;
- restauration silencieuse d'un kit accepté mais temporairement non résolu ;
- assainissement et bornage des options sensibles avant création de la fenêtre ;
- neutralisation des compteurs non numériques issus de sauvegardes anciennes/corrompues ;
- fenêtre restaurée maintenue dans les limites de la résolution actuelle ;
- sauvegarde immédiate de la valeur d'échelle lors d'un changement dans les options ;
- autosave périodique des observations et sauvegarde immédiate des changements importants ;
- retry explicite d'un autosave échoué dès la prochaine modification réelle des données ;
- vrai rafraîchissement manuel des noms appris dynamiquement avec `/bl fr`, piloté par un état runtime de localisation ;
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
/bl fr          Rafraîchir les noms FR appris dynamiquement
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

La signature n'est enregistrée qu'une fois les probes nécessaires réellement terminés. Si le plugin est fermé avant la fin, la signature n'est pas validée et la tentative reprendra au prochain chargement. Un ID que le client LOTRO ne sait pas résoudre n'est donc pas retenté à chaque connexion une fois une passe complète terminée.

Depuis **FR7.12**, `/bl fr` ne se contente plus de rechercher les noms absents : les noms provenant uniquement des caches dynamiques sont temporairement remis en file de probe. Les traductions officielles intégrées à `BL_FR.lua` ne sont jamais effacées. L'ancien nom appris reste utilisé comme repli si LOTRO ne renvoie rien de nouveau.

FR7.14 différerait déjà un `/bl fr` lancé pendant une passe oiseaux. Depuis **FR7.15**, cette décision ne repose plus directement sur `frProbeVersion` : BirdingLog maintient un état runtime de localisation qui suit la passe oiseaux et la queue des objets/récompenses `BL_GID`. Les demandes manuelles reçues pendant cette activité sont regroupées puis relancées dès la libération de cet état. Une sécurité de timeout reste présente afin qu'un contrôle Turbine bloqué ne verrouille pas définitivement le refresh.

`BL_IsLocalizationBusy()` expose cet état runtime aux futures couches du plugin sans transformer le marqueur persistant `frProbeVersion` en pseudo-indicateur d'activité.

FR7.11 à FR7.15 conservent la signature `BL710` car ces versions ne changent ni les ID d'oiseaux ni les ID de récompenses : aucune nouvelle passe automatique de localisation n'est déclenchée inutilement.

Les noms localisés des récompenses et objets d'ornithologie appris dynamiquement sont conservés séparément dans `BL_GNames`. Une récompense déjà connue par son ID est reconnue même lorsque `/bl track` est désactivé ; ce mode sert uniquement aux objets réellement inconnus.

Les caches appris `BL_Names` et `BL_GNames` sont appliqués/persistés comme caches français : ils ne doivent pas remplacer les noms natifs d'un lancement EN/DE.

## Sauvegardes

BirdingLog conserve notamment :

- les totaux du personnage et sa maîtrise d'ornithologie ;
- les observations par zone ;
- les options de fenêtre ;
- la position de l'icône ;
- les raccourcis du kit, de l'arme et du second emplacement ;
- les noms localisés d'oiseaux appris depuis LOTRO ;
- les noms localisés des récompenses/objets appris depuis LOTRO.

Les anciennes données restent compatibles avec le fork. Depuis FR7.11, les champs qui peuvent être consommés pendant la création de l'interface sont validés **avant** l'import complet de `BL_Main` : positions de fenêtre, échelle, maîtrise et structures de raccourci invalides sont neutralisées avant d'atteindre les contrôles Turbine.

FR7.12 a ajouté un test réel des données sauvegardées de `kit`, `wpn` et `shl` avec un `Shortcut(Item, data)` puis un `Quickslot:SetShortcut()` caché et protégé par `pcall()`.

Depuis **FR7.13**, cette validation contrôle aussi le résultat retourné par Turbine : le Quickslot doit rester de type `Item` et restituer exactement la donnée sauvegardée. Un rejet silencieux est donc détecté. Pour le kit d'ornithologie, un objet accepté mais dont `GetItemInfo()` n'est pas encore disponible est conservé ; il n'est rejeté que si LOTRO le résout et que sa catégorie est différente de `BL_BirdingKit`.

Depuis **FR7.14**, un kit accepté mais encore non résolu est volontairement tenu hors de `BL_Totals` pendant la construction de la fenêtre afin d'éviter la validation historique trop agressive. Il est ensuite restauré avec `ShortcutChanged` temporairement désactivé, puis revalidé une seconde fois. Cela évite le faux message « Objet introuvable » et empêche une mauvaise catégorie apparue entre les deux contrôles d'être réintroduite.

Les positions sauvegardées sont converties en coordonnées numériques valides puis bornées à l'écran actuel **avant** la création de la fenêtre. L'échelle est limitée à la plage utilisée par le panneau d'options (`0.5` à `2.0`). Une maîtrise non numérique est ignorée proprement. Depuis FR7.14, toute modification du curseur d'échelle est également sauvegardée immédiatement dans `PluginData` au lieu d'attendre l'unload du plugin.

Les compteurs d'oiseaux et de zones non numériques sont ramenés à une valeur sûre avant toute addition, et une entrée de zone corrompue est recréée sous forme de table vide.

Afin de limiter les pertes en cas de crash de LOTRO, FR7.12 sauvegarde automatiquement les données de runtime toutes les **10 observations reconnues**. Les changements de maîtrise, d'équipement, les ajouts manuels et les modifications manuelles de compteur déclenchent une sauvegarde immédiate. Une sauvegarde de consolidation est également faite après le chargement pour persister les anciennes données assainies.

Depuis **FR7.15**, un échec synchrone d'autosave active un indicateur de retry. La prochaine modification réelle d'une donnée sauvegardée — observation, maîtrise, nom dynamique, équipement, ajout ou compteur manuel — retente immédiatement la sauvegarde, même si le compteur périodique n'a pas encore atteint 10. Une sauvegarde réussie efface cet indicateur et remet le compteur périodique à zéro.

Sur les clients FR/DE, la bibliothèque historique `Dusk/Common` convertit les valeurs PluginData afin de contourner les problèmes de séparateur décimal. Depuis FR7.9, cette conversion n'utilise plus `loadstring()` : les nombres sont décodés avec `tonumber()` en acceptant point ou virgule, et les données invalides sont conservées sans faire planter le chargement.

## À propos de `Dusk/Common`

BirdingLog et FishingLog utilisent actuellement la même bibliothèque historique `Dusk/Common`. Les deux dépôts conservent désormais **exactement la même version durcie** de cette bibliothèque afin d'éviter qu'une installation de l'un remplace `Common` par une version différente de l'autre.

`Dusk/Common/Options.lua` est également maintenu identique dans les deux dépôts. FR7.14 y ajoute la sauvegarde immédiate de l'échelle afin qu'une fermeture brutale de LOTRO ne fasse pas revenir l'ancien réglage.

Elle reste volontairement partagée : la dupliquer naïvement ferait installer plusieurs wrappers globaux de `Turbine.PluginData.Load/Save` sur les clients FR/DE.

## Plugin Compendium

Le fichier `.plugincompendium` de l'addon original utilisait l'identifiant LOTROInterface **1241**, qui appartient à la publication originale. Il n'est pas utilisé comme identité de ce fork afin d'éviter qu'un gestionnaire de mises à jour confonde la version Dusk avec la version officielle.

## Historique

Les changements du fork sont résumés dans `CHANGELOG.md`. `Dusk/BirdingLog/Updates.txt` conserve également l'historique historique de Birding Log.

## Crédits

Birding Log a été créé par **David Down**. Ce dépôt conserve son travail d'origine et ajoute les adaptations françaises et correctifs de maintenance du fork Dusk-92.

Aucune licence différente de celle éventuellement applicable au projet original n'est revendiquée ici.
