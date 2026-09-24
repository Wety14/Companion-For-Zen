import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case fr = "fr"
    case en = "en"
    case es = "es"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        case .es: return "Español"
        }
    }
    
    public var flag: String {
        switch self {
        case .fr: return "🇫🇷"
        case .en: return "🇬🇧"
        case .es: return "🇪🇸"
        }
    }
}

public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            let preferred = Locale.current.language.languageCode?.identifier ?? "fr"
            if preferred.hasPrefix("en") {
                self.currentLanguage = .en
            } else if preferred.hasPrefix("es") {
                self.currentLanguage = .es
            } else {
                self.currentLanguage = .fr
            }
        }
    }
    
    public func string(for key: String) -> String {
        guard let dict = translations[key] else { return key }
        return dict[currentLanguage] ?? dict[.fr] ?? key
    }
    
    private let translations: [String: [AppLanguage: String]] = [
        // Omnibar & Navigation
        "search_or_enter_address": [
            .fr: "Rechercher ou entrer une adresse...",
            .en: "Search or enter address...",
            .es: "Buscar o ingresar dirección..."
        ],
        "new_tab": [
            .fr: "Nouvel onglet",
            .en: "New Tab",
            .es: "Nueva pestaña"
        ],
        "spaces": [
            .fr: "Espaces",
            .en: "Spaces",
            .es: "Espacios"
        ],
        "pinned_tabs": [
            .fr: "Onglets épinglés",
            .en: "Pinned Tabs",
            .es: "Pestañas fijadas"
        ],
        "today_tabs": [
            .fr: "Onglets récents",
            .en: "Today's Tabs",
            .es: "Pestañas recientes"
        ],
        "archived_tabs": [
            .fr: "Onglets archivés",
            .en: "Archived Tabs",
            .es: "Pestañas archivadas"
        ],
        "archive_now": [
            .fr: "Archiver les onglets inactifs",
            .en: "Archive inactive tabs",
            .es: "Archivar pestañas inactivas"
        ],
        "restore_tab": [
            .fr: "Restaurer",
            .en: "Restore",
            .es: "Restaurar"
        ],
        "delete_tab": [
            .fr: "Supprimer",
            .en: "Delete",
            .es: "Eliminar"
        ],
        "clear_all": [
            .fr: "Tout effacer",
            .en: "Clear All",
            .es: "Borrar todo"
        ],
        
        // Web Tools
        "reader_mode": [
            .fr: "Mode Lecture",
            .en: "Reader Mode",
            .es: "Modo Lectura"
        ],
        "translate_page": [
            .fr: "Traduire la page",
            .en: "Translate Page",
            .es: "Traducir página"
        ],
        "show_original": [
            .fr: "Afficher l'original",
            .en: "Show Original",
            .es: "Mostrar original"
        ],
        "translation_dialog_title": [
            .fr: "Traduction système",
            .en: "System Translation",
            .es: "Traducción del sistema"
        ],
        "translation_dialog_message": [
            .fr: "La traduction s'effectue localement sur votre appareil avec la traduction système Apple. Aucune donnée n'est transmise à des serveurs tiers.",
            .en: "Translation is performed locally on your device with Apple's system translation. No data is sent to third-party servers.",
            .es: "La traducción se realiza localmente en tu dispositivo con la traducción del sistema de Apple. No se envían datos a servidores externos."
        ],
        "translation_always_allow": [
            .fr: "Toujours autoriser",
            .en: "Always Allow",
            .es: "Permitir siempre"
        ],
        "translation_allow_once": [
            .fr: "Autoriser",
            .en: "Allow",
            .es: "Permitir"
        ],
        "translation_deny": [
            .fr: "Refuser",
            .en: "Don't Allow",
            .es: "Rechazar"
        ],
        "translation_settings_section": [
            .fr: "Traduction",
            .en: "Translation",
            .es: "Traducción"
        ],
        "translation_settings_toggle": [
            .fr: "Toujours autoriser la traduction locale",
            .en: "Always allow local translation",
            .es: "Permitir siempre la traducción local"
        ],
        "translation_settings_footer": [
            .fr: "La traduction s'effectue localement sur votre appareil à l'aide des modèles neuronaux d'Apple, garantissant le respect absolu de votre vie privée.",
            .en: "Translation is performed locally on your device using Apple's neural models, fully ensuring your privacy.",
            .es: "La traducción se realiza localmente en tu dispositivo mediante los modelos neuronales de Apple, garantizando el respeto absoluto de tu privacidad."
        ],
        "page_zoom": [
            .fr: "Zoom de page",
            .en: "Page Zoom",
            .es: "Zoom de página"
        ],
        "desktop_mode": [
            .fr: "Version ordinateur",
            .en: "Desktop Site",
            .es: "Versión de escritorio"
        ],
        "mobile_mode": [
            .fr: "Version mobile",
            .en: "Mobile Site",
            .es: "Versión móvil"
        ],
        "shield_active": [
            .fr: "Protection Zen active",
            .en: "Zen Shield Active",
            .es: "Protección Zen Activa"
        ],
        "ads_trackers_blocked": [
            .fr: "pubs, traqueurs & cookies bloqués",
            .en: "ads, trackers & cookies blocked",
            .es: "anuncios, rastreadores y cookies bloqueados"
        ],
        
        // Downloads, History, Bookmarks
        "downloads": [
            .fr: "Téléchargements",
            .en: "Downloads",
            .es: "Descargas"
        ],
        "history": [
            .fr: "Historique",
            .en: "History",
            .es: "Historial"
        ],
        "bookmarks": [
            .fr: "Favoris",
            .en: "Bookmarks",
            .es: "Marcadores"
        ],
        "add_bookmark": [
            .fr: "Ajouter aux favoris",
            .en: "Add to Bookmarks",
            .es: "Añadir a marcadores"
        ],
        "no_downloads": [
            .fr: "Aucun téléchargement récent",
            .en: "No recent downloads",
            .es: "No hay descargas recientes"
        ],
        "no_history": [
            .fr: "Aucun historique de navigation",
            .en: "No browsing history",
            .es: "Sin historial de navegación"
        ],
        "clear_history": [
            .fr: "Effacer l'historique",
            .en: "Clear History",
            .es: "Borrar historial"
        ],
        
        // Firefox Sync
        "firefox_sync": [
            .fr: "Synchronisation Firefox",
            .en: "Firefox Sync",
            .es: "Sincronización Firefox"
        ],
        "connected_as": [
            .fr: "Connecté en tant que",
            .en: "Connected as",
            .es: "Conectado como"
        ],
        "sync_now": [
            .fr: "Synchroniser maintenant",
            .en: "Sync Now",
            .es: "Sincronizar ahora"
        ],
        "sync_tabs": [
            .fr: "Onglets ouverts & Espaces",
            .en: "Open Tabs & Spaces",
            .es: "Pestañas abiertas y Espacios"
        ],
        "sync_bookmarks": [
            .fr: "Marque-pages",
            .en: "Bookmarks",
            .es: "Marcadores"
        ],
        "sync_history": [
            .fr: "Historique de navigation",
            .en: "Browsing History",
            .es: "Historial de navegación"
        ],
        "sign_in_mozilla": [
            .fr: "Se connecter avec un compte Firefox",
            .en: "Sign in with Firefox Account",
            .es: "Iniciar sesión con cuenta Firefox"
        ],
        "sign_out": [
            .fr: "Se déconnecter",
            .en: "Sign Out",
            .es: "Cerrar sesión"
        ],
        "last_synced": [
            .fr: "Dernière synchro :",
            .en: "Last synced:",
            .es: "Última sincronización:"
        ],
        
        // Settings
        "settings": [
            .fr: "Paramètres",
            .en: "Settings",
            .es: "Ajustes"
        ],
        "search_engine": [
            .fr: "Moteur de recherche",
            .en: "Search Engine",
            .es: "Motor de búsqueda"
        ],
        "appearance": [
            .fr: "Apparence & Thème",
            .en: "Appearance & Theme",
            .es: "Apariencia y Tema"
        ],
        "theme_mode": [
            .fr: "Mode d'affichage",
            .en: "Display Mode",
            .es: "Modo de visualización"
        ],
        "theme_automatic": [
            .fr: "Automatique",
            .en: "Automatic",
            .es: "Automático"
        ],
        "theme_light": [
            .fr: "Clair",
            .en: "Light",
            .es: "Claro"
        ],
        "theme_dark": [
            .fr: "Sombre",
            .en: "Dark",
            .es: "Oscuro"
        ],
        "app_icon": [
            .fr: "Icône de l'application",
            .en: "App Icon",
            .es: "Icono de la aplicación"
        ],
        "auto_archive_delay": [
            .fr: "Délai d'auto-archivage",
            .en: "Auto-archive Duration",
            .es: "Plazo de autoarchivado"
        ],
        "content_blocking": [
            .fr: "Blocage de contenu",
            .en: "Content Blocking",
            .es: "Bloqueo de contenido"
        ],
        "block_ads": [
            .fr: "Bloquer les publicités",
            .en: "Block Advertisements",
            .es: "Bloquear publicidad"
        ],
        "block_trackers": [
            .fr: "Bloquer les traqueurs",
            .en: "Block Trackers",
            .es: "Bloquear rastreadores"
        ],
        "block_cookie_banners": [
            .fr: "Masquer les bannières cookies",
            .en: "Dismiss Cookie Banners",
            .es: "Ocultar avisos de cookies"
        ],
        "language": [
            .fr: "Langue",
            .en: "Language",
            .es: "Idioma"
        ],
        "handoff_title": [
            .fr: "Apple Handoff (Continuité)",
            .en: "Apple Handoff (Continuity)",
            .es: "Apple Handoff (Continuidad)"
        ],
        "handoff_desc": [
            .fr: "Transmet l'onglet actif à votre Mac avec Zen Browser",
            .en: "Transfers the active tab to your Mac with Zen Browser",
            .es: "Transfiere la pestaña activa a tu Mac con Zen Browser"
        ],
        "handoff_banner_title": [
            .fr: "Depuis votre Mac",
            .en: "From your Mac",
            .es: "Desde tu Mac"
        ],
        "handoff_open": [
            .fr: "Ouvrir",
            .en: "Open",
            .es: "Abrir"
        ],
        "about_zen": [
            .fr: "À propos de Zen Browser",
            .en: "About Zen Browser",
            .es: "Acerca de Zen Browser"
        ],
        "default_browser": [
            .fr: "Navigateur par défaut",
            .en: "Default Browser",
            .es: "Navegador predeterminado"
        ],
        "set_default_browser": [
            .fr: "Rendre Zen navigateur par défaut",
            .en: "Set Zen as Default Browser",
            .es: "Hacer de Zen el navegador predeterminado"
        ],
        "default_browser_subtitle": [
            .fr: "Ouvrir les liens web automatiquement dans Zen",
            .en: "Open web links automatically in Zen",
            .es: "Abrir enlaces web automáticamente en Zen"
        ],
        "default_browser_footer": [
            .fr: "Dans les Réglages iOS, sélectionnez « App du navigateur par défaut » puis choisissez Zen.",
            .en: "In iOS Settings, select 'Default Browser App' and choose Zen.",
            .es: "En Ajustes de iOS, seleccione 'App del navegador por omisión' y elija Zen."
        ],
        "desktop_sidebar_twin": [
            .fr: "Sidebar Zen Desktop (Mac)",
            .en: "Zen Desktop Sidebar (Mac)",
            .es: "Barra lateral Zen Desktop (Mac)"
        ],
        "mirror_sidebar_now": [
            .fr: "Jumeler la sidebar Desktop avec Zen iOS",
            .en: "Mirror Desktop Sidebar to Zen iOS",
            .es: "Duplicar barra lateral Desktop en Zen iOS"
        ],
        "desktop_sidebar_desc": [
            .fr: "Reproduit fidèlement vos espaces, couleurs exactes et onglets épinglés de Zen Desktop.",
            .en: "Faithfully mirrors your Zen Desktop workspaces, exact colors, and pinned tabs.",
            .es: "Reproduce fielmente sus espacios, colores exactos y pestañas fijadas de Zen Desktop."
        ]
    ]
}

/// Convenience global translation function
public func tr(_ key: String) -> String {
    LocalizationManager.shared.string(for: key)
}
