BirdingLog 1.3-FR7.6 — re-audit

- BL_Loader sécurise BL_Options avant le chargement du module principal.
- Hook chat protégé par génération : les anciens handlers BirdingLog enfouis sous FishingLog deviennent inactifs au lieu de compter deux fois.
- Le nom de zone/secteur fourni directement par ;loc est utilisé en priorité lorsqu’il correspond à une zone Birding connue.
- Le calcul déterministe par rectangles reste en secours pour les sous-zones.
- Toutes les corrections FR7.5 sont conservées.

Après la mise à jour, redémarrer complètement LOTRO une fois pour éliminer d’éventuels anciens wrappers déjà présents en mémoire.
