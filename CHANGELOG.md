# Journal des modifications (Changelog) - Zen Browser iOS

Toutes les modifications notables apportées à ce projet sont documentées dans ce fichier.

---

## [Non publié] - 2026-09-24

### Corrigé
- **Bascule immédiate du thème clair / sombre (`ZenTheme.swift`, `BrowserContainerView.swift`, `WebToolsOverlayView.swift`)** :
  - **Correction du blocage de thème par la couleur de page web** : Dans `BrowserContainerView`, la directive `.preferredColorScheme` écrasait le thème utilisateur en forçant `.light` dès qu'une page web chargée avait un fond clair (`isPageColorLight == true`). Cela bloquait l'application en mode clair jusqu'au redémarrage de l'app.
  - **Application instantanée au niveau UIWindow** : Implémentation de `applyTheme()` dans `ZenThemeManager`, appliquant immédiatement `window.overrideUserInterfaceStyle` (`.dark`, `.light` ou `.unspecified`) à l'ensemble des fenêtres et scènes actives d'iOS.
  - **Propagation aux feuilles modales (Sheets)** : Ajout de `.preferredColorScheme(themeManager.colorScheme)` sur la hiérarchie modale `WebToolsOverlayView`, garantissant un basculement visuel synchrone sans latence dans les réglages et l'ensemble de l'interface.

### Modifié
- **Couleur d'accentuation globale (`ZenTheme.swift` & `AccentColor.colorset`)** :
  - Remplacement de l'ancienne teinte bleue par la couleur corail `#F76F53` avec adaptation intelligente de luminosité selon le thème :
    - **Thème sombre** : Teinte `#F76F53` éclatante et chaleureuse, parfaitement dosée pour un excellent confort visuel sur les arrière-plans sombres.
    - **Thème clair** : Teinte ajustée subtilement plus soutenue (`#E85B3D`), garantissant un contraste optimal (respect des normes d'accessibilité sans éblouissement sur fond blanc/clair).
  - Mise à jour de `AccentColor.colorset` avec la gestion native des apparences Any / Dark d'iOS.
- **Réglages (`SettingsView.swift`)** :
  - Suppression de la mention descriptive « Compagnon mobile... » dans la section « À propos de Zen » pour un rendu plus épuré et sobre axé directement sur l'identité de marque Zen Browser.
  - Ajout du sélecteur à 3 modes pour l'apparence : **Automatique (par défaut)**, **Clair**, **Sombre**.
- **Gestionnaire de Thème (`ZenTheme.swift`)** :
  - Introduction de l'enum `AppThemeMode` (.automatic, .light, .dark).
  - Support de la bascule dynamique automatique basée sur le thème système iOS (`ColorScheme? = nil`).
  - Arrière-plans dynamiques via `UIColor { trait in ... }` et adaptation automatique de l'apparence du clavier système.
- **Support Navigateur par Défaut (`Info.plist` & Entitlements)** :
  - Configuration de `CFBundleURLTypes` pour `http` / `https` avec `CFBundleTypeRole: Viewer`.
  - Ajout de la catégorie `LSApplicationCategoryType: public.app-category.productivity`.
  - Préparation du fichier `CompanionForZen.entitlements` avec `com.apple.developer.web-browser`.
- **Traduction Système (`TranslationService.swift`)** :
  - Intégration du framework natif Apple Neural Translation (iOS 18+).
  - Ajout de la boîte de dialogue explicative d'autorisation locale avec les options : *Autoriser*, *Toujours autoriser* (mise en avant), *Refuser*.
  - Ajout du réglage « Toujours autoriser la traduction locale » dans les paramètres de l'application.

### Ajouté
- **Nouveau sélecteur d'icônes officielles Zen (`IconPickerView.swift`)** :
  - Intégration des 4 nouvelles icônes officielles créées à partir des paquets `.icon` de `Assets/ZenLogos` :
    - **Zen Twilight** (`TwilightIcon.icon`) : Bleu classique officiel (icône primaire par défaut).
    - **Zen Coral** (`CoralIcon.icon`) : Teinte corail dégradée éclatante.
    - **Zen Dark** (`DarkIcon.icon`) : Noir profond épuré.
    - **Zen Retro** (`RetroIcon.icon`) : Ambiance rétro violet néon & or vintage.
  - Nouvelle interface graphique en grille (2x2) avec prévisualisation en direct de l'icône sur l'écran d'accueil iOS (carte springboard avec effet de halo et ombre portée).
  - Rendu haute fidélité natif des icônes dans les cartes avec indicateur de sélection animé et retour haptique instantané.
  - Génération des ensembles d'icônes 1024x1024 (`AppIcon.appiconset`, `AppIcon-Twilight`, `AppIcon-Coral`, `AppIcon-Dark`, `AppIcon-Retro`) et des prévisualisations in-app (`Preview-Twilight`, `Preview-Coral`, `Preview-Dark`, `Preview-Retro`).
  - Déclaration des 4 icônes alternatives dans `Info.plist` (`CFBundleAlternateIcons`).
  - Suppression de l'ancien système (anciens doublons, icône Frost et Retrowave obsolètes).

---

## [1.0.0] - Version Initiale
- Navigateur web moderne pour iOS inspiré de Zen Browser et Arc.
- Gestion des espaces (Spaces), onglets verticaux et archivage automatique.
- Synchronisation Firefox Sync (chiffrement de bout en bout).
- Bloqueur de contenus et publicités natif (AdBlockService).
- Mode lecture (Reader Mode).
- Handoff avec Zen Browser pour macOS.
