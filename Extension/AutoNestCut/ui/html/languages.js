// Internationalization support for AutoNestCut
const translations = {
    'en': {
        // Main UI
        'app_title': 'AutoNestCut',
        'developer_credit': 'Developed by: Int. Arch. M.Shkeir',
        'configuration': 'Configuration',
        'report': 'Report',
        
        // Buttons
        'generate_cut_list': 'Generate Cut List',
        'refresh_selection': 'Refresh Selection',
        'cancel': 'Cancel',
        'add': 'Add',
        'defaults': 'Defaults',
        'import': 'Import',
        'export': 'Export',
        'refresh': 'Refresh',
        'pdf': 'PDF',
        'csv': 'CSV',
        'html': 'HTML',
        
        // Settings
        'general_settings': 'General Settings',
        'kerf_width': 'Kerf Width (mm):',
        'allow_rotation': 'Allow part rotation',
        'stock_materials_pricing': 'Stock Materials & Pricing',
        'default_currency': 'Default Currency:',
        
        // Materials
        'material_name': 'Material Name',
        'width_mm': 'Width (mm)',
        'height_mm': 'Height (mm)',
        'price': 'Price',
        'currency': 'Currency',
        'actions': 'Actions',
        'status': 'Status',
        'used': 'Used',
        'not_used': 'Not Used',
        'show_used_only': 'Used Only',
        'show_all_materials': 'Show All Materials',
        'clear': 'Clear',
        
        // Parts
        'parts_preview': 'Parts Preview',
        'parts_found': 'Parts Found',
        'name': 'Name',
        'thick_mm': 'Thick (mm)',
        'qty': 'Qty',
        'total': 'Total:',
        
        // Report sections
        'diagrams': 'Diagrams',
        'report_details': 'Report Details',
        'project_name': 'Project Name:',
        'address': 'Address:',
        'date': 'Date:',
        'materials_used': 'Materials Used',
        'overall_summary': 'Overall Summary',
        'unique_part_types': 'Unique Part Types',
        'unique_board_types': 'Unique Board Types',
        'boards_summary': 'Boards Summary',
        'parts_placed_detailed': 'Parts Placed (Detailed)',
        'show_tree_structure': 'Show Tree Structure',
        'hide_tree_structure': 'Hide Tree Structure',
        
        // Placeholders
        'enter_project_name': 'Enter project name',
        'enter_project_address': 'Enter project address',
        'price_per_sheet': 'Price per sheet',
        'search_components': 'Search components...',
        
        // Tooltips
        'add_material': 'Add Material',
        'load_defaults': 'Load Defaults',
        'import_csv': 'Import CSV',
        'export_database': 'Export Database',
        'remove_material': 'Remove material',
        'highlight_material': 'Highlight material',
        'clear_highlight': 'Clear Highlight',
        'print_save_pdf': 'Print / Save as PDF',
        'export_csv_report': 'Export CSV Report',
        'export_interactive_html': 'Export Interactive HTML',
        'refresh_report': 'Refresh Report'
    },
    
    'es': {
        // Main UI
        'app_title': 'AutoNestCut',
        'developer_credit': 'Desarrollado por: Int. Arch. M.Shkeir',
        'configuration': 'Configuración',
        'report': 'Informe',
        
        // Buttons
        'generate_cut_list': 'Generar Lista de Corte',
        'refresh_selection': 'Actualizar Selección',
        'cancel': 'Cancelar',
        'add': 'Agregar',
        'defaults': 'Predeterminados',
        'import': 'Importar',
        'export': 'Exportar',
        'refresh': 'Actualizar',
        'pdf': 'PDF',
        'csv': 'CSV',
        'html': 'HTML',
        
        // Settings
        'general_settings': 'Configuración General',
        'kerf_width': 'Ancho de Corte (mm):',
        'allow_rotation': 'Permitir rotación de piezas',
        'stock_materials_pricing': 'Materiales de Stock y Precios',
        'default_currency': 'Moneda Predeterminada:',
        
        // Materials
        'material_name': 'Nombre del Material',
        'width_mm': 'Ancho (mm)',
        'height_mm': 'Alto (mm)',
        'price': 'Precio',
        'currency': 'Moneda',
        'actions': 'Acciones',
        'status': 'Estado',
        'used': 'Usado',
        'not_used': 'No Usado',
        'show_used_only': 'Solo Usados',
        'show_all_materials': 'Mostrar Todos los Materiales',
        'clear': 'Limpiar',
        
        // Parts
        'parts_preview': 'Vista Previa de Piezas',
        'parts_found': 'Piezas Encontradas',
        'name': 'Nombre',
        'thick_mm': 'Grosor (mm)',
        'qty': 'Cant.',
        'total': 'Total:',
        
        // Report sections
        'diagrams': 'Diagramas',
        'report_details': 'Detalles del Informe',
        'project_name': 'Nombre del Proyecto:',
        'address': 'Dirección:',
        'date': 'Fecha:',
        'materials_used': 'Materiales Utilizados',
        'overall_summary': 'Resumen General',
        'unique_part_types': 'Tipos de Piezas Únicas',
        'unique_board_types': 'Tipos de Tableros Únicos',
        'boards_summary': 'Resumen de Tableros',
        'parts_placed_detailed': 'Piezas Colocadas (Detallado)',
        'show_tree_structure': 'Mostrar Estructura de Árbol',
        'hide_tree_structure': 'Ocultar Estructura de Árbol',
        
        // Placeholders
        'enter_project_name': 'Ingrese nombre del proyecto',
        'enter_project_address': 'Ingrese dirección del proyecto',
        'price_per_sheet': 'Precio por hoja',
        'search_components': 'Buscar componentes...',
        
        // Tooltips
        'add_material': 'Agregar Material',
        'load_defaults': 'Cargar Predeterminados',
        'import_csv': 'Importar CSV',
        'export_database': 'Exportar Base de Datos',
        'remove_material': 'Eliminar material',
        'highlight_material': 'Resaltar material',
        'clear_highlight': 'Limpiar Resaltado',
        'print_save_pdf': 'Imprimir / Guardar como PDF',
        'export_csv_report': 'Exportar Informe CSV',
        'export_interactive_html': 'Exportar HTML Interactivo',
        'refresh_report': 'Actualizar Informe'
    },
    
    'fr': {
        // Main UI
        'app_title': 'AutoNestCut',
        'developer_credit': 'Développé par: Int. Arch. M.Shkeir',
        'configuration': 'Configuration',
        'report': 'Rapport',
        
        // Buttons
        'generate_cut_list': 'Générer Liste de Découpe',
        'refresh_selection': 'Actualiser Sélection',
        'cancel': 'Annuler',
        'add': 'Ajouter',
        'defaults': 'Par Défaut',
        'import': 'Importer',
        'export': 'Exporter',
        'refresh': 'Actualiser',
        'pdf': 'PDF',
        'csv': 'CSV',
        'html': 'HTML',
        
        // Settings
        'general_settings': 'Paramètres Généraux',
        'kerf_width': 'Largeur de Trait (mm):',
        'allow_rotation': 'Autoriser la rotation des pièces',
        'stock_materials_pricing': 'Matériaux de Stock et Prix',
        'default_currency': 'Devise par Défaut:',
        
        // Materials
        'material_name': 'Nom du Matériau',
        'width_mm': 'Largeur (mm)',
        'height_mm': 'Hauteur (mm)',
        'price': 'Prix',
        'currency': 'Devise',
        'actions': 'Actions',
        'status': 'Statut',
        'used': 'Utilisé',
        'not_used': 'Non Utilisé',
        'show_used_only': 'Utilisés Seulement',
        'show_all_materials': 'Afficher Tous les Matériaux',
        'clear': 'Effacer',
        
        // Parts
        'parts_preview': 'Aperçu des Pièces',
        'parts_found': 'Pièces Trouvées',
        'name': 'Nom',
        'thick_mm': 'Épaisseur (mm)',
        'qty': 'Qté',
        'total': 'Total:',
        
        // Report sections
        'diagrams': 'Diagrammes',
        'report_details': 'Détails du Rapport',
        'project_name': 'Nom du Projet:',
        'address': 'Adresse:',
        'date': 'Date:',
        'materials_used': 'Matériaux Utilisés',
        'overall_summary': 'Résumé Général',
        'unique_part_types': 'Types de Pièces Uniques',
        'unique_board_types': 'Types de Panneaux Uniques',
        'boards_summary': 'Résumé des Panneaux',
        'parts_placed_detailed': 'Pièces Placées (Détaillé)',
        'show_tree_structure': 'Afficher Structure Arborescente',
        'hide_tree_structure': 'Masquer Structure Arborescente',
        
        // Placeholders
        'enter_project_name': 'Entrez le nom du projet',
        'enter_project_address': 'Entrez l\'adresse du projet',
        'price_per_sheet': 'Prix par feuille',
        'search_components': 'Rechercher composants...',
        
        // Tooltips
        'add_material': 'Ajouter Matériau',
        'load_defaults': 'Charger Par Défaut',
        'import_csv': 'Importer CSV',
        'export_database': 'Exporter Base de Données',
        'remove_material': 'Supprimer matériau',
        'highlight_material': 'Surligner matériau',
        'clear_highlight': 'Effacer Surlignage',
        'print_save_pdf': 'Imprimer / Sauvegarder PDF',
        'export_csv_report': 'Exporter Rapport CSV',
        'export_interactive_html': 'Exporter HTML Interactif',
        'refresh_report': 'Actualiser Rapport'
    },
    
    'ar': {
        // Main UI
        'app_title': 'AutoNestCut',
        'developer_credit': 'تطوير: المهندس المعماري م.شكير',
        'configuration': 'الإعدادات',
        'report': 'التقرير',
        
        // Buttons
        'generate_cut_list': 'إنشاء قائمة القطع',
        'refresh_selection': 'تحديث التحديد',
        'cancel': 'إلغاء',
        'add': 'إضافة',
        'defaults': 'افتراضي',
        'import': 'استيراد',
        'export': 'تصدير',
        'refresh': 'تحديث',
        'pdf': 'PDF',
        'csv': 'CSV',
        'html': 'HTML',
        
        // Settings
        'general_settings': 'الإعدادات العامة',
        'kerf_width': 'عرض القطع (مم):',
        'allow_rotation': 'السماح بدوران القطع',
        'stock_materials_pricing': 'مواد المخزون والأسعار',
        'default_currency': 'العملة الافتراضية:',
        
        // Materials
        'material_name': 'اسم المادة',
        'width_mm': 'العرض (مم)',
        'height_mm': 'الارتفاع (مم)',
        'price': 'السعر',
        'currency': 'العملة',
        'actions': 'الإجراءات',
        'status': 'الحالة',
        'used': 'مستخدم',
        'not_used': 'غير مستخدم',
        'show_used_only': 'المستخدم فقط',
        'show_all_materials': 'إظهار جميع المواد',
        'clear': 'مسح',
        
        // Parts
        'parts_preview': 'معاينة القطع',
        'parts_found': 'القطع الموجودة',
        'name': 'الاسم',
        'thick_mm': 'السماكة (مم)',
        'qty': 'الكمية',
        'total': 'المجموع:',
        
        // Report sections
        'diagrams': 'المخططات',
        'report_details': 'تفاصيل التقرير',
        'project_name': 'اسم المشروع:',
        'address': 'العنوان:',
        'date': 'التاريخ:',
        'materials_used': 'المواد المستخدمة',
        'overall_summary': 'الملخص العام',
        'unique_part_types': 'أنواع القطع الفريدة',
        'unique_board_types': 'أنواع الألواح الفريدة',
        'boards_summary': 'ملخص الألواح',
        'parts_placed_detailed': 'القطع الموضوعة (مفصل)',
        'show_tree_structure': 'إظهار هيكل الشجرة',
        'hide_tree_structure': 'إخفاء هيكل الشجرة',
        
        // Placeholders
        'enter_project_name': 'أدخل اسم المشروع',
        'enter_project_address': 'أدخل عنوان المشروع',
        'price_per_sheet': 'السعر لكل لوح',
        'search_components': 'البحث في المكونات...',
        
        // Tooltips
        'add_material': 'إضافة مادة',
        'load_defaults': 'تحميل الافتراضي',
        'import_csv': 'استيراد CSV',
        'export_database': 'تصدير قاعدة البيانات',
        'remove_material': 'إزالة المادة',
        'highlight_material': 'تمييز المادة',
        'clear_highlight': 'مسح التمييز',
        'print_save_pdf': 'طباعة / حفظ PDF',
        'export_csv_report': 'تصدير تقرير CSV',
        'export_interactive_html': 'تصدير HTML تفاعلي',
        'refresh_report': 'تحديث التقرير'
    },
    
    'de': {
        // Main UI
        'app_title': 'AutoNestCut',
        'developer_credit': 'Entwickelt von: Int. Arch. M.Shkeir',
        'configuration': 'Konfiguration',
        'report': 'Bericht',
        
        // Buttons
        'generate_cut_list': 'Schnittliste Erstellen',
        'refresh_selection': 'Auswahl Aktualisieren',
        'cancel': 'Abbrechen',
        'add': 'Hinzufügen',
        'defaults': 'Standard',
        'import': 'Importieren',
        'export': 'Exportieren',
        'refresh': 'Aktualisieren',
        'pdf': 'PDF',
        'csv': 'CSV',
        'html': 'HTML',
        
        // Settings
        'general_settings': 'Allgemeine Einstellungen',
        'kerf_width': 'Schnittbreite (mm):',
        'allow_rotation': 'Teile-Rotation erlauben',
        'stock_materials_pricing': 'Lagermaterialien & Preise',
        'default_currency': 'Standardwährung:',
        
        // Materials
        'material_name': 'Materialname',
        'width_mm': 'Breite (mm)',
        'height_mm': 'Höhe (mm)',
        'price': 'Preis',
        'currency': 'Währung',
        'actions': 'Aktionen',
        'status': 'Status',
        'used': 'Verwendet',
        'not_used': 'Nicht Verwendet',
        'show_used_only': 'Nur Verwendete',
        'show_all_materials': 'Alle Materialien Anzeigen',
        'clear': 'Löschen',
        
        // Parts
        'parts_preview': 'Teile-Vorschau',
        'parts_found': 'Gefundene Teile',
        'name': 'Name',
        'thick_mm': 'Dicke (mm)',
        'qty': 'Anz.',
        'total': 'Gesamt:',
        
        // Report sections
        'diagrams': 'Diagramme',
        'report_details': 'Berichtdetails',
        'project_name': 'Projektname:',
        'address': 'Adresse:',
        'date': 'Datum:',
        'materials_used': 'Verwendete Materialien',
        'overall_summary': 'Gesamtübersicht',
        'unique_part_types': 'Einzigartige Teiletypen',
        'unique_board_types': 'Einzigartige Plattentypen',
        'boards_summary': 'Plattenübersicht',
        'parts_placed_detailed': 'Platzierte Teile (Detailliert)',
        'show_tree_structure': 'Baumstruktur Anzeigen',
        'hide_tree_structure': 'Baumstruktur Verbergen',
        
        // Placeholders
        'enter_project_name': 'Projektname eingeben',
        'enter_project_address': 'Projektadresse eingeben',
        'price_per_sheet': 'Preis pro Platte',
        'search_components': 'Komponenten suchen...',
        
        // Tooltips
        'add_material': 'Material Hinzufügen',
        'load_defaults': 'Standard Laden',
        'import_csv': 'CSV Importieren',
        'export_database': 'Datenbank Exportieren',
        'remove_material': 'Material entfernen',
        'highlight_material': 'Material hervorheben',
        'clear_highlight': 'Hervorhebung löschen',
        'print_save_pdf': 'Drucken / Als PDF Speichern',
        'export_csv_report': 'CSV-Bericht Exportieren',
        'export_interactive_html': 'Interaktives HTML Exportieren',
        'refresh_report': 'Bericht Aktualisieren'
    }
};

let currentLanguage = 'en';

function setLanguage(lang) {
    if (translations[lang]) {
        currentLanguage = lang;
        updateUI();
        localStorage.setItem('autoNestCutLanguage', lang);
    }
}

function t(key) {
    return translations[currentLanguage][key] || translations['en'][key] || key;
}

function updateUI() {
    // Update all elements with data-translate attribute
    document.querySelectorAll('[data-translate]').forEach(element => {
        const key = element.getAttribute('data-translate');
        const translation = t(key);
        
        if (element.tagName === 'INPUT' && (element.type === 'text' || element.type === 'date')) {
            element.placeholder = translation;
        } else if (element.hasAttribute('title')) {
            element.title = translation;
        } else {
            element.textContent = translation;
        }
    });
    
    // Update specific elements by ID
    const elementsToUpdate = {
        'projectName': 'enter_project_name',
        'projectAddress': 'enter_project_address'
    };
    
    Object.keys(elementsToUpdate).forEach(id => {
        const element = document.getElementById(id);
        if (element) {
            element.placeholder = t(elementsToUpdate[id]);
        }
    });
}

// Initialize language on page load
function initializeLanguage() {
    const savedLanguage = localStorage.getItem('autoNestCutLanguage') || 'en';
    setLanguage(savedLanguage);
}

// Auto-detect browser language
function detectBrowserLanguage() {
    const browserLang = navigator.language || navigator.userLanguage;
    const langCode = browserLang.split('-')[0];
    
    if (translations[langCode]) {
        return langCode;
    }
    return 'en';
}