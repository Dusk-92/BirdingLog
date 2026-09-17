BirdingLog 1.3-FR1 - patch client français
==========================================

Patch non officiel préparé à partir de BirdingLog 1.3 de David Down.

Corrections principales :
- détection du client français via la commande /aide ;
- suivi des oiseaux indépendant du texte localisé "You have acquired" ;
- récupération des oiseaux par leur ID interne, commun à toutes les langues ;
- prise en charge des messages de progression contenant "ornith..." ;
- parseur de coordonnées plus tolérant (point/virgule, W/O) ;
- suppression du contrôle imposant le nom anglais exact "Birding Kit" ;
- quelques libellés principaux de la fenêtre traduits en français ;
- mémorisation temporaire du nom français d'un oiseau lorsqu'il est observé.

Installation :
1. Fermer ou décharger BirdingLog dans LOTRO.
2. Copier le dossier Dusk de cette archive dans Documents/The Lord of the Rings Online/Plugins/.
   Le chemin final doit commencer par Plugins/Dusk/.
3. Accepter le remplacement des fichiers BirdingLog existants.
4. Dans le gestionnaire de plugins LOTRO, actualiser puis charger BirdingLog.

Test conseillé :
- ouvrir BirdingLog ;
- cliquer sur "Détecter zone" ;
- vérifier qu'une zone est sélectionnée ;
- observer un oiseau ;
- le chat doit afficher "BL: Observation : ... total=1" (ou incrémenter le total existant).

Limitation :
La base de données fournie par l'auteur contient les noms anglais des oiseaux et des zones.
Les noms français des oiseaux observés sont récupérés en jeu, mais les oiseaux encore jamais vus
peuvent rester affichés en anglais dans certaines listes/menus.
