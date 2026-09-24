# Journal des modifications (Changelog) - Zen Browser iOS

Toutes les modifications notables apportées à ce projet sont documentées dans ce fichier.

---

## [Non publié] - 2026-09-24

### Ajouté
- **Gestionnaire d'icônes `AppIconManager` (`AppIconManager.swift`)** :
  - Création du gestionnaire dédié `@MainActor final class AppIconManager: ObservableObject` conforme au modèle fourni.
  - Définition de l'enum `AppIcon` mappée directement sur les icônes des Assets :
    - `.primary = "AppIcon"` (Zen Coral officiel, icône par défaut passant `nil` à `setAlternateIconName`)
    - `.dark = "DarkIcon"` (Zen Dark)
    - `.retro = "RetroIcon"` (Zen Retro)
    - `.twilight = "TwilightIcon"` (Zen Twilight)
  - Prise en charge native de `UIApplication.shared.supportsAlternateIcons` et mise à jour dynamique de `currentIcon`.
  - Intégration dans `IconPickerView` avec synchronisation en direct du choix d'icône.
  - Configuration de `CFBundleAlternateIcons` dans `Info.plist` pour `DarkIcon`, `RetroIcon` et `TwilightIcon`.
  - Respect strict des dossiers d'icônes existants dans `Assets.xcassets` (aucun fichier d'icône modifié ou écrasé).

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

---

## [1.0.0] - Version Initiale
- Navigateur web moderne pour iOS inspiré de Zen Browser et Arc.
- Gestion des espaces (Spaces), onglets verticaux et archivage automatique.
- Synchronisation Firefox Sync (chiffrement de bout en bout).
- Bloqueur de contenus et publicités natif (AdBlockService).
- Mode lecture (Reader Mode).
- Handoff avec Zen Browser pour macOS.
