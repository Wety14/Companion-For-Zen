# Companion for Zen (Twilight for iOS)

> Le navigateur mobile open-source inspiré de l'ergonomie d'**Arc**, doté de l'ADN visuel et de la synchronisation de **Zen Browser**, **100% sans IA intrusive**.

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Platform: iOS 17+](https://img.shields.io/badge/Platform-iOS%2017%2B-black.svg?logo=apple)]()
[![Swift: 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)]()

---

## 🌟 Vision du Projet

**Companion for Zen** a été conçu pour combler le manque d'application mobile officielle pour les utilisateurs de [Zen Browser](https://zen-browser.app).

Il reprend les meilleures avancées ergonomiques mobiles d'**Arc** (barre flottante inférieure, Espaces étanches, navigation par gestes au pouce, et **auto-archivage intelligent des onglets**), tout en bannissant catégoriquement les gadgets d'IA générative (*Browse for Me*, résumés LLM) qui alourdissent la navigation et consomment batterie et bande passante.

---

## ✨ Fonctionnalités Clés

### 🛡️ Zen Shield (Bloqueur de Contenu Natif)
* **Publicités & Trackers** : Compilation native `WKContentRuleList` (EasyList, uBlock triggers) avec zéro impact CPU.
* **Auto-Dismiss des Bannières Cookies** : Masquage et auto-clic des bandeaux de consentement (OneTrust, Didomi, Cookiebot, etc.) et déblocage automatique du scroll.
* **Compteur en direct** dans l'Omnibar.

### 🗂️ Gestion des Onglets & Auto-Archivage (Arc-style)
* **Espaces (Workspaces)** : Espaces personnalisés (Personnel, Travail, Détente...) avec couleurs d'accent Zen et icônes.
* **Onglets Épinglés (Pinned)** : Persistants par espace.
* **Auto-Archivage sans IA** : Les onglets inactifs sont automatiquement déplacés vers l'Archive après un délai configurable (12h, 24h, 3 jours, 7 jours, ou jamais).
* **Vue Archives** : Recherche instantanée et restauration en un tap.

### 🦊 Synchronisation Firefox (Zen Desktop)
* Compatible avec l'infrastructure **Mozilla Sync 1.5 & Firefox Accounts (FxA)** utilisée par Zen Browser Desktop.
* Synchronisation bidirectionnelle de l'historique, des favoris et des onglets ouverts.
* Détection des appareils connectés (*Zen MacBook*, etc.) et envoi d'onglets à distance (*Send to Device*).

### 🍏 Compatibilité Apple Handoff (Continuité macOS <-> iOS)
* **Diffusion continue (`NSUserActivityTypeBrowsingWeb`)** : La page consultée sur iPhone apparaît instantanément dans le Dock de votre Mac avec l'icône de Zen Browser.
* **Réception fluide** : Reprenez instantanément sur votre iPhone la lecture d'un onglet ouvert sur votre Mac grâce à la bannière de continuité dédiée.
* **Activité personnalisée Zen** : Prise en charge des métadonnées d'Espaces Zen (`app.zenbrowser.companion.browsing`).
* Activable / désactivable en un tap dans les Paramètres.

### 🔍 Outils Web Essentiels
* **Mode Traduction** : Traduction in-page avec bannière interactive (Français, Anglais, Espagnol, Allemand, Italien).
* **Mode Lecture (Zen Reader)** : Extraction épurée du contenu, typographie personnalisable (Serif, Sans, Mono) et 4 thèmes (Sépia, Sombre, OLED Noir, Crème).
* **Zoom de Page** : Contrôle continu de 50% à 200%.
* **Version Ordinateur** : Bascule immédiate vers le User-Agent Desktop.
* **Moteurs de recherche** : DuckDuckGo, Brave Search, Google, Ecosia, Kagi, Qwant, SearXNG ou moteur personnalisé avec modèle `%@`.

### 🎨 Esthétique Zen & "Liquid Glass" iOS 27
* Matériaux ultra-fins translucides avec reflets irisés sur les bordures.
* Palettes de couleurs officielles Zen : *Twilight Blue*, *Zen Coral*, *Zen Forest*, *Zen Berry*, *Zen Lavender*, *Dark Accent*, *OLED Black*.
* **Icônes d'application interchangeables** : Twilight, Coral, Dark, Frost, Retrowave.

### 🌐 Multilingue & Téléchargements
* Prise en charge native du **Français (FR)**, de l'**Anglais (EN)** et de l'**Espagnol (ES)** avec bascule instantanée en cours d'utilisation.
* Gestionnaire complet des téléchargements avec prévisualisation QuickLook et partage iOS.

---

## 🤖 Conçu pour le Portage Android

Le projet a été architecturé selon les principes de la **Clean Architecture** (modèles découplés de l'UI, services sous forme de contrats / protocoles, gestion d'état réactive).

Consultez le guide complet : **[`ANDROID_PORTING_GUIDE.md`](./ANDROID_PORTING_GUIDE.md)** pour voir la correspondance 1:1 avec **Kotlin Multiplatform & Jetpack Compose**.

---

## 🚀 Comment Ouvrir et Lancer le Projet

1. Double-cliquez sur `CompanionForZen.xcodeproj` pour ouvrir le projet dans **Xcode**.
2. Sélectionnez un simulateur iOS (iPhone 15/16/Pro).
3. Appuyez sur **Cmd + R** pour compiler et lancer l'application !
