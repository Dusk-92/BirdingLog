# 🐦 BirdingLog

Carnet d’ornithologie pour **The Lord of the Rings Online**, avec suivi des observations, progression par zone et fenêtre dédiée aux prouesses.

**🌍 Langues / Languages / Sprachen :** 🇫🇷 Français · 🇬🇧 English · 🇩🇪 Deutsch

Version actuelle : **1.3-FR7.27**

---

## 🇫🇷 Français

### 📖 Présentation

**BirdingLog** est une adaptation et une maintenance communautaire du plugin **Birding Log** de David Down / Vinny. Le fork modernise le fonctionnement du plugin tout en conservant son carnet d’observations et ses données historiques.

### ✨ Fonctionnalités

- Suivi des oiseaux observés à partir de leurs identifiants LOTRO.
- Fonctionnement indépendant de la langue affichée pour les noms d’objets.
- Progression par zone.
- Fenêtre **Prouesses** avec oiseaux obtenus et manquants.
- Niveau d’ornithologie et meilleur rang affichés dans la fenêtre principale.
- Détection de zone à partir des coordonnées LOTRO.
- Apprentissage contrôlé des sous-zones extérieures non reconnues.
- Gestion des coordonnées françaises avec virgule décimale et `O` pour Ouest.
- Raccourcis d’équipement et kit d’ornithologie.
- Sauvegardes renforcées et compatibilité avec les anciennes données.
- Interface compatible FR / EN / DE.

### 📦 Installation

Copie le dossier **Dusk** dans :

```text
Documents\The Lord of the Rings Online\Plugins\
```

Puis en jeu :

```text
/plugins refresh
/plugins load BirdingLog
```

### 🎮 Utilisation

Ouvre BirdingLog pour consulter ta maîtrise, tes observations et la progression des zones. Le bouton **Détecter zone** utilise la commande de localisation LOTRO afin de rapprocher tes coordonnées des régions connues.

Si une sous-zone extérieure ne peut pas être reconnue immédiatement, BirdingLog peut apprendre son association à partir de nouvelles observations ou d’une sélection manuelle.

### ⌨️ Commandes

- `/bl` — afficher la maîtrise d’ornithologie.
- `/bl sight` — afficher les observations personnelles.
- `/bl zones` — afficher la progression par zone.
- `/bl deeds` — ouvrir la fenêtre des prouesses.
- `/bl deed <zone>` — afficher le détail d’une zone.
- `/bl area forget` — oublier la dernière association de sous-zone apprise.
- `/bl fr` — rafraîchir les noms français appris dynamiquement.
- `/bl track` — activer/désactiver le suivi des objets inconnus.
- `/blw` — ouvrir la fenêtre BirdingLog.
- `/bll zone` — lister les oiseaux de la zone sélectionnée.
- `/bll list` — lister les observations de la zone sélectionnée.
- `/blg` — afficher la récompense de la zone sélectionnée.

### ⚙️ Sauvegardes & réglages

BirdingLog utilise son propre espace Lua et conserve les observations, associations de zones et réglages du plugin. Les anciennes sauvegardes compatibles sont migrées et protégées contre les lectures incomplètes.

### 🌍 Langues

Le plugin prend en charge les clients **français, anglais et allemands**. Les noms français officiels sont reliés aux identifiants internes LOTRO afin d’éviter de dépendre uniquement du texte affiché.

### ⚠️ Limites / notes

L’API LOTRO ne fournit pas directement une région d’ornithologie fiable dans toutes les sous-zones. La détection repose donc sur les coordonnées connues et, lorsque nécessaire, sur un apprentissage contrôlé. Une zone inconnue n’est pas associée arbitrairement.

### 🐛 Bugs & suggestions

Utilise les [Issues GitHub](https://github.com/Dusk-92/BirdingLog/issues).

### 🙏 Crédits

Plugin original : **David Down / Vinny**.  
Adaptation et maintenance : **Dusk-92**.

---

## 🇬🇧 English

### 📖 Overview

**BirdingLog** is a community-maintained adaptation of **Birding Log** by David Down / Vinny. The fork modernizes the plugin while preserving its observation log and historical data.

### ✨ Features

- Bird observation tracking using LOTRO internal IDs.
- Tracking independent from localized item-name text.
- Progress by region.
- Dedicated **Deeds** window with collected and missing birds.
- Birding skill level and best rank in the main window.
- Region detection from LOTRO coordinates.
- Controlled learning for outdoor sub-areas that cannot be recognized directly.
- Support for localized coordinate formats.
- Equipment shortcuts and current birding kits.
- Hardened saved data with legacy compatibility.
- FR / EN / DE client support.

### 📦 Installation

Copy the **Dusk** folder into:

```text
Documents\The Lord of the Rings Online\Plugins\
```

Then in game:

```text
/plugins refresh
/plugins load BirdingLog
```

### 🎮 Usage

Open BirdingLog to review your skill level, observations and regional progress. The **Detect area** function uses LOTRO location coordinates to match your position with known birding regions.

When an outdoor sub-area cannot be recognized immediately, BirdingLog can learn the association from new observations or a manual selection.

### ⌨️ Commands

- `/bl` — show birding skill information.
- `/bl sight` — show personal sightings.
- `/bl zones` — show progress by region.
- `/bl deeds` — open the Deeds window.
- `/bl deed <zone>` — show details for one region.
- `/bl area forget` — forget the latest learned sub-area association.
- `/bl fr` — refresh dynamically learned French names.
- `/bl track` — toggle unknown-item tracking.
- `/blw` — open the BirdingLog window.
- `/bll zone` — list birds for the selected region.
- `/bll list` — list sightings for the selected region.
- `/blg` — show the reward for the selected region.

### ⚙️ Saved data & settings

BirdingLog uses its own Lua data apartment and stores observations, learned area associations and plugin settings. Compatible legacy data is migrated with additional safeguards against incomplete reads.

### 🌍 Languages

The plugin supports **French, English and German** clients. French canonical names are tied to LOTRO internal IDs so tracking does not depend only on displayed text.

### ⚠️ Limitations / notes

The LOTRO API does not expose a reliable birding region for every sub-area. Detection therefore relies on known coordinates and, when needed, controlled learning. Unknown locations are not mapped arbitrarily.

### 🐛 Bugs & suggestions

Use [GitHub Issues](https://github.com/Dusk-92/BirdingLog/issues).

### 🙏 Credits

Original plugin: **David Down / Vinny**.  
Adaptation and maintenance: **Dusk-92**.

---

## 🇩🇪 Deutsch

### 📖 Übersicht

**BirdingLog** ist eine gemeinschaftlich gepflegte Anpassung von **Birding Log** von David Down / Vinny. Der Fork modernisiert das Plugin und bewahrt gleichzeitig Beobachtungsprotokoll und historische Daten.

### ✨ Funktionen

- Vogelbeobachtungen anhand interner LOTRO-IDs.
- Erfassung unabhängig vom lokalisierten Gegenstandsnamen.
- Fortschritt nach Region.
- Eigenes **Taten**-Fenster mit gefundenen und fehlenden Vögeln.
- Anzeige von Ornithologie-Stufe und bestem Rang.
- Gebietserkennung über LOTRO-Koordinaten.
- Kontrolliertes Lernen unbekannter Außen-Untergebiete.
- Unterstützung lokalisierter Koordinatenformate.
- Ausrüstungs-Schnellplätze und aktuelle Ornithologie-Sets.
- Robuste Speicherdaten mit Legacy-Kompatibilität.
- Unterstützung für FR / EN / DE.

### 📦 Installation

Den Ordner **Dusk** nach folgendem Pfad kopieren:

```text
Documents\The Lord of the Rings Online\Plugins\
```

Danach im Spiel:

```text
/plugins refresh
/plugins load BirdingLog
```

### 🎮 Verwendung

BirdingLog öffnen, um Fertigkeitsstufe, Beobachtungen und regionalen Fortschritt zu sehen. Die Gebietserkennung nutzt LOTRO-Koordinaten und gleicht sie mit bekannten Ornithologie-Regionen ab.

Kann ein Außen-Untergebiet nicht direkt erkannt werden, kann BirdingLog die Zuordnung anhand neuer Beobachtungen oder einer manuellen Auswahl lernen.

### ⌨️ Befehle

- `/bl` — Ornithologie-Informationen anzeigen.
- `/bl sight` — eigene Beobachtungen anzeigen.
- `/bl zones` — Fortschritt nach Region anzeigen.
- `/bl deeds` — Taten-Fenster öffnen.
- `/bl deed <zone>` — Details einer Region anzeigen.
- `/bl area forget` — zuletzt gelernte Gebietszuordnung vergessen.
- `/bl fr` — dynamisch gelernte französische Namen aktualisieren.
- `/bl track` — Erfassung unbekannter Gegenstände umschalten.
- `/blw` — BirdingLog-Fenster öffnen.
- `/bll zone` — Vögel der ausgewählten Region auflisten.
- `/bll list` — Beobachtungen der ausgewählten Region auflisten.
- `/blg` — Belohnung der ausgewählten Region anzeigen.

### ⚙️ Gespeicherte Daten & Einstellungen

BirdingLog verwendet einen eigenen Lua-Datenbereich und speichert Beobachtungen, gelernte Gebietszuordnungen und Einstellungen. Kompatible ältere Daten werden mit zusätzlichen Schutzmechanismen übernommen.

### 🌍 Sprachen

Das Plugin unterstützt **Deutsch, Englisch und Französisch**. Französische kanonische Namen werden mit internen LOTRO-IDs verknüpft, damit die Erfassung nicht nur vom sichtbaren Text abhängt.

### ⚠️ Einschränkungen / Hinweise

Die LOTRO-API liefert nicht für jedes Untergebiet zuverlässig die passende Ornithologie-Region. Deshalb nutzt die Erkennung bekannte Koordinaten und bei Bedarf ein kontrolliertes Lernverfahren. Unbekannte Orte werden nicht willkürlich zugeordnet.

### 🐛 Fehler & Vorschläge

Bitte die [GitHub Issues](https://github.com/Dusk-92/BirdingLog/issues) verwenden.

### 🙏 Credits

Ursprüngliches Plugin: **David Down / Vinny**.  
Anpassung und Wartung: **Dusk-92**.
