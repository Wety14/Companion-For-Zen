# Journal des modifications (Changelog)

## [Unreleased] - 2026-09-25

### Contraste et Typographie Adaptative selon la Luminosité des Dégradés
- **Typographie adaptative (Luminance ITU-R BT.601)** : Sur les dégradés sombres (ou schémas sombres), les textes des onglets non sélectionnés ainsi que le nom de l'espace actif s'affichent automatiquement en blanc pur (`.white`) avec des contrastes et séparateurs adaptés.
- **Dégradés clairs** : Sur les dégradés clairs, les textes des onglets non sélectionnés et le nom de l'espace basculent en noir profond (`#16161A`).
- **Préservation stricte de l'onglet actif** : L'onglet actif conserve son esthétique Zen signature : conteneur blanc pur légèrement arrondi avec typographie noire (`#18181C`), quel que soit le dégradé de fond.
- **Édition des Espaces a posteriori** : Intégration de `SpaceEditorSheet` accessible depuis l'option "Modifier l'espace" du menu contextuel des espaces.
- **Drag & Drop natif ultra-smooth 120fps** : Maintien ouvrant le menu contextuel, puis fermeture automatique du menu dès le mouvement du doigt pour libérer l'élément en glisser-déposer sans accroc.

### Esthétique Zen épurée et Gestes Interactifs Fluides (Tab Manager)
- **Rendu sans délimitation des onglets** : Les onglets inactifs apparaissent directement sous forme d'icône et de texte sur le dégradé de fond sans conteneurs ou bordures rectangulaires, reproduisant fidèlement l'esthétique Zen desktop.
- **Sélection de l'onglet actif** : Seul l'onglet actif dispose d'un conteneur blanc pur légèrement arrondi avec ombre subtile et texte sombre.
- **Transition d'espace progressive au doigt** : Le balayage horizontal suit désormais en direct le mouvement du doigt : le dégradé de couleur se fond progressivement entre l'espace source et l'espace cible, et les listes d'onglets glissent de façon synchronisée.
- **Glisser-déposer tactile des onglets** : Maintien (long press) puis glissement direct d'un onglet entre les 3 zones (Favoris, Épinglés, Onglets ouverts) ou vers une icône d'espace du dock, avec aperçu flottant et retour haptique.
- **Réorganisation des espaces par glissement** : Les icônes d'espaces du dock inférieur sont réorganisables directement en maintenant et glissant horizontalement.

### Affinements du Gestionnaire d'Onglets
- **Affichage réel des favicons** : Création du composant `TabFaviconView` avec support `AsyncImage`, détection native des sites Zen Browser (`ZenLogoView`) et fallback élégant.
- **Séparateurs épurés** : Remplacement des conteneurs/sections encadrés par de simples traits horizontaux épurés entre Favoris, Épinglés et Onglets ouverts.
- **Bouton Nouvel Onglet Intégré** : L'action d'ajout d'onglet est désormais présentée exactement comme un onglet ouvert en tête de liste de la catégorie des onglets ouverts.

### Redesign complet du Gestionnaire d'Onglets (Tab Manager / Drawer)
- **Arrière-plan dynamique** : Dégradé fluide et texturé issu du thème de l'espace actif couvrant toute la fenêtre.
- **En-tête stylisé** : Nom de l'espace actif affiché en haut à gauche avec badge de profil associé et compteur d'onglets.
- **Section Favoris (Haut)** : Tuiles compactes ramassées sur elles-mêmes affichant uniquement l'icône du site, partagées et synchronisées entre les espaces d'un même profil Zen.
- **Section Épinglés (Milieu)** : Lignes épurées et plates avec petite icône à gauche et titre ; support exclusif des dossiers regroupables et dépliables avec création dynamique.
- **Section Onglets Ouverts (Bas)** : Liste des onglets actifs sujets à l'archivage automatique avec bouton de fermeture rapide.
- **Dock Centré Inférieur** : Navigation d'espaces représentée uniquement par des icônes monochromes neutres sans texte.
- **Navigation Circulaire Infinie** : Balayage horizontal avec bouclage automatique entre le premier et le dernier espace (ex: A -> B -> C -> A et inversement).
- **Glisser-Déposer Transversal (Drag & Drop)** : Déplacement fluide d'onglets entre Favoris, Épinglés, Onglets ouverts et vers les icônes d'autres espaces.
- **Navigation Privée Hors-Espaces** : Onglets privés isolés du système d'espaces accessibles via le mode Privé dédié.
- **Ouverture Intelligente lors du Changement d'Espace** : Réactivation automatique du dernier onglet consulté ; si aucun onglet n'est ouvert, déclenchement immédiat de la recherche/nouvel onglet.

### Air Traffic Control (Routage des liens externes)
- **Service & Paramètres ATC** : Configuration de règles de routage pour ouvrir automatiquement les liens externes dans l'espace approprié (par domaine, sous-chaîne, préfixe ou URL exacte).
- **Règle générale de secours** : Choix entre redirection vers le dernier espace accédé ou vers un espace spécifique fixé par l'utilisateur.

### Extension de Partage (Share Extension)
- **Menu déroulant à multiples volets** : Choix précis de l'espace de destination et du type d'enregistrement (Favori, Épinglé avec sélection/création de dossier, ou Onglet ouvert standard).
- **Support des profils d'espace** : Attribution automatique du profil pour les favoris créés depuis la Share Extension.
 - Zen Browser iOS

Toutes les modifications notables apportées à ce projet sont documentées dans ce fichier.

---

## [Non publié] - 2026-09-24 / 2026-09-25

### Ajouté
- **Onglet d'accueil Zen Browser par défaut au premier lancement (`TabManager.swift`)** :
  - **Ouverture par défaut du site Zen** : Au premier lancement de l'application ou si aucun onglet n'existe, un onglet vers le site officiel de Zen Browser (`https://zen-browser.app`) est ouvert et activé par défaut.
  - **Persistance immédiate** : Enregistrement direct sur disque (`save()`) dès la création de l'onglet par défaut pour éviter sa disparition lors d'un rechargement ou de la réouverture de l'application.
  - **Garantie d'affichage d'onglet actif** : Sécurisation du getter `activeTab` avec repli automatique sur le premier onglet disponible de l'espace actif, éliminant tout affichage de l'écran vide « Aucun onglet actif ».
- **Générateur de dégradés et sélecteur de thème Zen pour les Espaces (`SpaceThemePicker.swift`, `SpaceSelectorView.swift`, `Space.swift`)** :
  - **Portage complet de l'interface Zen Browser desktop** : Remplacement du sélecteur de couleur simple par le panneau complet de génération de dégradés issu de `ZenGradientGenerator.mjs` de Zen Desktop.
  - **Roue chromatique circulaire interactive (`gradientCanvas`)** : Disque sombre avec aperçu des gradients radiaux, jusqu'à 3 points déplaçables au doigt avec calculs HSL/RGB, ajout au toucher et suppression.
  - **Boutons d'actions & harmonies colorimétriques** : Commutateur de schéma d'apparence (*Auto*, *Clair*, *Sombre*), boutons d'ajout/retrait de points et cycleur d'harmonies (analogue, complémentaire, etc.).
  - **Palettes de présélections paginées (`presetPager`)** : Deux pages de 8 nuances Zen Desktop (*Pastels* et *Sombres*) sélectionnables en un toucher avec chevrons de navigation.
  - **Curseur d'opacité avec indicateur en onde sinusoïdale (`WaveShape`)** : Onde fluide animée réagissant dynamiquement au curseur d'opacité.
  - **Cadran rotatif de texture/grain & Couleurs personnalisées** : Sélecteur de grain à 16 crans rotatif et sélecteur de couleur avec réglage fin de l'opacité.
  - **Rendu dynamique des dégradés** : Intégration en temps réel dans l'aperçu du badge de l'Espace et dans les pastilles de sélection d'Espace du tiroir d'onglets.
### Ajouté
- **Sélecteur d'icônes SVG Zen & Emojis pour les Espaces (`Space.swift`, `SpaceSelectorView.swift`, `Assets.xcassets`)** :
  - **Catalogue complet des 87 icônes vectorielles Zen Desktop** : Importation et compilation des 87 icônes SVG issues de `Zen Space Icons` dans `Assets.xcassets/SpaceIcons` avec préservation vectorielle (`preserves-vector-representation`) et rendu template dynamique teinté avec la couleur d'accentuation de l'espace.
  - **Composant universel `SpaceIconView`** : Rendu automatique selon la nature de l'icône (Emoji, icône vectorielle Zen SVG ou repli SF Symbol).
  - **Modale de création d'Espace repensée** :
    - Sélecteur segmented entre **Icônes Zen** (avec champ de recherche instantané et grille de sélection de 87 icônes) et **Emoji** (déploiement direct et immédiat du clavier émoji natif iOS via `EmojiKeyboardTextField` / `textInputMode = "emoji"`, sans grille intermédiaire).
    - Aperçu en direct du badge d'espace (icône/emoji + nom + couleur) réactif aux modifications.
- **Architecture de localisation officielle String Catalog (`Localizable.xcstrings`, `AppLanguage.swift`)** :
  - **Suppression définitive du crash au lancement** (`Thread 1: Fatal error: Dictionary literal contains duplicate keys`) : suppression de la clé `shield_active` dupliquée et abandon des dictionnaires littéraux statiques en Swift au profit d'un chargement dynamique et sécurisé via `CatalogEntry` et `dict[key] = ...`.
  - **Fichier de catalogue standard Xcode** : Création et enregistrement de `Localizable.xcstrings` (124 chaînes de traduction complètes pour le Français, l'Anglais et l'Espagnol) dans les ressources du projet (`CompanionForZen.xcodeproj`).
  - **Résolution Cocoa native** : Prise en charge des bundles `.lproj` avec repli élégant sur le String Catalog. Les modifications de chaînes peuvent désormais se faire directement depuis l'éditeur de catalogues de chaînes d'Xcode.
- **Synchronisation Firefox & Espaces Zen Desktop (`FirefoxSyncService.swift`, `FirefoxSyncView.swift`, `WebViewContainer.swift`)** :
  - **Authentification complète Mozilla FxA** : Remplacement de l'ancien formulaire factice par une saisie sécurisée **Email ET Mot de passe** (champ `SecureField` avec bascule d'affichage du mot de passe et indicateur de chiffrement de bout en bout Mozilla FxA).
  - **Résolution du crash / erreur `didFailProvisionalLoadForFrame: code=-999`** :
    - Élimination de la double navigation simultanée lors de la sélection d'un onglet synchronisé (`handleTabSelection` n'invoque plus à la fois `openNewTab` et `loadURLTrigger`).
    - Gestion gracieuse de `NSURLErrorCancelled` (-999) dans `WebViewContainer.swift` pour ne plus bloquer ni consigner d'erreurs en cas de requête supplantée.
  - **Import & Export des Espaces Zen Desktop (Workspaces)** :
    - Suite à l'étude du code source de Zen Desktop (`zen-browser/desktop`), prise en compte du fait que Mozilla Sync ne gère nativement que les onglets, favoris et historiques Firefox, tandis que les Espaces Zen exclusifs sont enregistrés localement dans `zen-sessions.jsonlz4`.
    - Ajout d'une fonctionnalité complète d'importation (`importWorkspacesFromJSON`) et d'exportation (`exportWorkspacesAsJSON`) pour intégrer fidèlement la configuration de ses espaces de travail Zen Desktop (noms, icônes, couleurs d'accent, onglets épinglés et onglets ouverts) ou les exporter depuis l'application iOS.
- **Système de traduction réactif et instantané (`AppLanguage.swift`, `CompanionForZenApp.swift`, l'ensemble des vues)** :
  - **Maintien des feuilles ouvertes lors du changement de langue** : Suppression du modificateur destructif `.id(locManager.currentLanguage)` sur `BrowserContainerView`. Ce modificateur détruisait et recréait toute la hiérarchie de la vue racine, provoquant la fermeture brutale des feuilles ouvertes (Zen Tools, Réglages).
  - **Mise à jour dynamique en place** : La réactivité est désormais gérée de manière non destructive via `@ObservedObject var locManager = LocalizationManager.shared` et `.environment(\.locale, ...)`, permettant à l ensemble des textes des Réglages et de Zen Tools de se traduire instantanément à l écran sans fermer la modale.
- **Correction des conteneurs de boutons dans Zen Tools (`WebToolsOverlayView.swift`)** :
  - Suppression de l'effet d'emboîtement / double conteneur rond provoqué par l'imbrication du conteneur de barre d'outils iOS et des modificateurs de boutons personnalisés.
  - Intégration de boutons circulaires unifiés de 32x32 au style `.buttonStyle(.plain)` natif avec remplissage circulaire intégré dans l'étiquette.
- **Persistance globale du moteur de recherche (`SearchEngine.swift`, `SettingsView.swift`, `BrowserContainerView.swift`, `TabManager.swift`)** :
  - Création de `SearchEngineManager.shared` avec persistance `UserDefaults` (`zen_search_engine_config`).
- **Recherche et navigation privée / Incognito Mode (`SearchOverlayView.swift`, `Tab.swift`, `TabManager.swift`, `WebViewContainer.swift`, `TabCardView.swift`)** :
  - Bouton interactif dédié tout à droite de la barre de recherche utilisant les symboles SF `eyeglasses` et `eyeglasses.slash`.

### Modifié
### Modifié
- **Remplacement absolu de l'ancien système de coloration par le nouveau générateur de dégradés Zen** :
  - **Écrasement des thèmes existants (`Space.swift`, `TabManager.swift`)** : Les espaces déjà créés sur disque (dans `UserDefaults` App Group / local) sont automatiquement détectés, écrasés et convertis vers le nouveau système de dégradés Zen tri-chromatiques split-complementary (+150° / +210°).
  - **Sauvegarde et écrasement immédiat sur le stockage** : Les thèmes migrés sont immédiatement persistés pour éliminer toute trace résiduelle de l'ancien système monochrome sur l'appareil.
  - **Harmonisation UI globale** : Rendu des dégradés dynamiques (`gradientBackground`) sur la pastille d'espace actif de la barre d'adresse (`BottomOmnibarView.swift`), dans le sélecteur d'espaces (`SpaceSelectorView.swift`) et dans l'extension de partage (`ShareExtensionView.swift`).
### Modifié
- **Épuration de la roue de grain (`SpaceThemePicker.swift`)** :
  - **Pas discret à 16 crans** : Rétablissement du pas discret à 16 positions avec retour haptique net à chaque cran.
  - **Maintien de l'échelle progressive** : Conservation des crans de longueurs variables (de 4 pt à 16 pt) pour visualiser l'intensité sans encombrer l'affichage.
  - **Suppression du pourcentage et du motif central** : Élimination du texte de pourcentage et de la pastille centrale au profit d'un centre totalement épuré.
### Modifié
- **Améliorations du sélecteur de dégradé Zen (`SpaceThemePicker.swift`)** :
  - **Suppression des couleurs personnalisées** : Élimination de la section Superflue pour épurer l'interface.
  - **Cadran de grain à crans de longueurs progressives & affichage d'intensité** : Remplacement des 16 points fixes par une jauge en arc de cercle de 28 crans dont la longueur grandit progressivement avec l'intensité (de 4 pt à 18 pt), avec surbrillance dynamique des crans actifs et affichage du pourcentage exact (`0%` à `100%`) au cœur du cadran et en badge d'en-tête.
  - **Verrouillage du seuil minimal à 1 point de couleur** : Le bouton `-` est désactivé dès qu'il ne reste qu'un point, garantissant un spectre jamais vide.
  - **Résolution de la présélection blanc/crème pastel** : La première nuance par défaut `(244, 239, 223)` applique désormais fidèlement sa valeur RVB claire et pastel d'origine avec ses compléments split-harmoniques sans subir de saturation parasite.
### Modifié
- **Contraintes géométriques harmoniques sur le spectre de couleurs (`SpaceThemePicker.swift`)** :
  - **1 point** : Mouvement libre sur l'ensemble du spectre chromatique.
  - **2 points** : Symétrie centrale absolue par rapport au centre du disque ($180^\circ$) avec ligne d'axe en pointillés ; le déplacement d'un point répercute instantanément la symétrie centrale sur le second.
  - **3 points (Split-Complementary)** : Contrainte géométrique rigide où le point majeur a pour opposé deux points secondaires situés à $150^\circ$ ($180^\circ - 30^\circ$) et $210^\circ$ ($180^\circ + 30^\circ$) par rapport au primaire. Les secondaires sont parfaitement symétriques par rapport à l'axe reliant le primaire à son complémentaire exact, avec affichage des lignes de visée harmoniques.
  - **Interaction fluide** : La manipulation de n'importe quel point secondaire ou primaire recalcule la rotation et le rayon de l'ensemble de la figure géométrique.
### Modifié
- **Navigation par vues dédiées pour la création d'Espace (`SpaceSelectorView.swift`, `SpaceThemePicker.swift`)** :
  - **Formulaire principal épuré** : Présentation claire avec l'aperçu du badge en direct, le nom de l'espace et les lignes de navigation vers les deux écrans dédiés.
  - **Vue entière dédiée pour l'Icône (`SpaceIconSelectionView`)** : Écran dédié offrant tout l'espace nécessaire pour parcourir et rechercher parmi les 87 icônes vectorielles Zen, ou utiliser directement le clavier émoji natif.
  - **Vue entière dédiée pour le Dégradé & Thème (`SpaceThemePickerDetailView`)** : Écran dédié permettant une manipulation confortable de la roue chromatique, des palettes de nuances, du curseur d'onde d'opacité et du cadran rotatif de texture.
- **Verrouillage temporaire de Firefox Sync (`WebToolsOverlayView.swift`, `FirefoxSyncView.swift`)** :
  - **Accès verrouillé en surface** : Dans le panneau Zen Tools, la ligne Firefox Sync affiche désormais un badge « Bientôt disponible », une icône de cadenas et une opacité atténuée, désactivant la navigation directe.
  - **Préservation intégrale du code** : L ensemble du code sous-jacent (`FirefoxSyncService.swift`, modèles d objets synchronisés, gestionnaire de sessions, import/export JSON des Espaces Zen) reste 100% conservé et intact dans le projet pour une réactivation ultérieure.
- **Thème automatique et respect de l'apparence système ()** :
  - **Correction du blocage en thème clair** : Résolution du comportement où le mode Automatique forçait le thème clair.  renvoie désormais  en mode automatique pour permettre à SwiftUI d'adopter dynamiquement l'apparence du système (Dark/Light).
  - **Déréférencement UIKit** :  applique désormais  sur les fenêtres en mode automatique au lieu de forcer , permettant à UIKit et à SwiftUI d'adapter simultanément l'application, les barres d'outils et le clavier () au mode sombre/clair défini dans iOS.
- **Bouton Navigateur par défaut (`SettingsView.swift`)** :
  - Retrait du sous-label « Ouvrir les liens web avec Zen » pour une présentation plus concise et directe.
- **Mode lecture (`WebToolsOverlayView.swift`)** :
  - Retrait temporaire du mode lecture actif : la tuile dans Zen Tools devient un placeholder élégant avec le sous-titre « Bientôt disponible ».
- **Bouton Protection Zen (`WebToolsOverlayView.swift`)** :
  - Suppression du nom de domaine actuel dans le sous-titre de la carte de protection pour allouer toute la largeur au label d'action.
- **Gestes sur la barre principale (`BrowserContainerView.swift`)** :
  - Suppression du geste de balayage vers le haut (swipe up) qui affichait le tiroir d'onglets depuis l'omnibar.
