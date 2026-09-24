# Journal des modifications (Changelog) - Zen Browser iOS

Toutes les modifications notables apportées à ce projet sont documentées dans ce fichier.

---

## [Non publié] - 2026-09-24

### Modifié
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
