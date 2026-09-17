BirdingLog 1.3-FR7.5 — audit correctif

- Détection de zone déterministe dans les rectangles qui se chevauchent.
- Le choix privilégie la zone où le joueur est le plus profondément à l’intérieur, avec départage stable.
- Hook Turbine.Chat.Received protégé contre les empilements directs et restauré à l’unload quand possible.
- Position de la fenêtre principale sauvegardée à l’unload.
- Position de l’icône sauvegardée dans BL_IconState, avec migration depuis iconPos.
- Validation de catégorie du Kit d’ornithologie (Shift permet un bypass manuel).
- Nettoyage de deux imports/variables UI inutilisés.
- Toutes les données FR7.4 et le bouton Détecter zone fonctionnel sont conservés.
