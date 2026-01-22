import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('es'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static String getString(String langCode, String key) {
    if (!_localizedValues.containsKey(langCode)) return key;
    return _localizedValues[langCode]?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'es': {
      // Feedback
      'feedback_title': '¡Tu opinión nos importa!',
      'feedback_description':
          'Si te gusta CashRapido, valóranos en nuestro grupo de Telegram.',
      'join_telegram': 'Unirse a Telegram',
      'maybe_later': 'Quizás más tarde',
      'apklis': 'Apklis',
      'play_store': 'Play Store',

      // Notifications
      'notif_daily_title': '💰 Registra tus gastos',
      'notif_daily_body': '¡No olvides actualizar tu presupuesto de hoy!',
      'notif_weekly_title': '📊 Resumen Semanal',
      'notif_weekly_body': 'Revisa tus gastos de la semana en CashRapido',
      'notif_tip_title': '💡 Tip Financiero',
      'tip_1': 'Revisa tus gastos mensuales para encontrar áreas de ahorro 💡',
      'tip_2': 'El 70% de los gastos diarios son evitables 🎯',
      'tip_3': 'Pequeños ahorros diarios = grandes resultados 🌟',
      'tip_4': 'Establece metas de ahorro realistas y alcanzables 🚀',
      'tip_5': 'Registrar gastos aumenta tu conciencia financiera 📈',

      // Help Center
      'help_q_add_card': '¿Cómo agregar mi primera tarjeta?',
      'help_a_add_card':
          'Ve a la pantalla de Billetera (icono inferior), toca el botón "+" y rellena los datos de tu tarjeta o efectivo.',
      'help_q_add_transaction': '¿Cómo registrar una transacción?',
      'help_a_add_transaction':
          'Toca el botón "+" flotante. Selecciona gasto/ingreso, categoría, monto y descripción.',
      'help_q_scanner': '¿Cómo usar el escáner?',
      'help_a_scanner':
          'Toca "Más" en acciones rápidas → "Escanear Tarjeta". Alinea tu tarjeta con el marco.',
      'help_q_edit_transaction': '¿Cómo editar una transacción?',
      'help_a_edit_transaction':
          'Toca cualquier transacción en la lista para ver detalles y editarla o eliminarla.',
      'help_q_transfer': '¿Cómo transferir entre tarjetas?',
      'help_a_transfer':
          'Usa "Transferir" en acciones rápidas. Selecciona origen, destino y monto.',
      'help_q_categories': '¿Puedo crear categorías personalizadas?',
      'help_a_categories':
          'Con la licencia Pro o Enterprise, puedes crear tus propias categorías en Configuración.',
      'help_q_cards_limit': '¿Cuántas tarjetas puedo tener?',
      'help_a_cards_limit':
          'Depende de tu licencia. Gratis: 1, Pro: 4, Enterprise: Ilimitadas.',
      'help_q_change_balance': '¿Cómo cambiar el balance?',
      'help_a_change_balance':
          'Ve a Billetera → Toca la tarjeta → Editar → Ajusta el balance.',
      'help_q_money_counter': '¿Qué es el Contador de Dinero?',
      'help_a_money_counter':
          'Herramienta para contar billetes/monedas. Solo para cuentas de Efectivo.',
      'help_q_license_types': '¿Qué tipos de licencias existen?',
      'help_a_license_types':
          'Personal (Gratis), Pro y Enterprise. Cada una desbloquea más tarjetas, gráficos y sincronización.',
      'help_q_restore_purchase': '¿Cómo restauro mi compra?',
      'help_a_restore_purchase':
          'Ve a Configuración -> Licencias -> Verificar Licencia. La app comprobará tu compra en Apklis automáticamente.',
      'help_q_custom_bank': '¿Puedo agregar bancos personalizados?',
      'help_a_custom_bank':
          'Sí, en Configuración -> Bancos puedes crear y editar tus propias entidades bancarias (Plan Pro+).',
      'help_q_currency': '¿Cómo cambio la moneda principal?',
      'help_a_currency':
          'En Configuración -> Moneda Principal. Esto define la moneda por defecto para los totales.',
      'help_q_feedback': '¿Cómo puedo dar mi opinión?',
      'help_a_feedback':
          'La app te invitará a unirte a nuestro grupo de Telegram después de usarla varios días.',

      // General
      'app_name': 'CashRapido',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'save': 'Guardar',
      'close': 'Cerrar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'error': 'Error',
      'success': 'Éxito',
      'loading': 'Cargando...',
      'search': 'Buscar',
      'nav_home': 'Inicio',
      'nav_wallet': 'Billetera',
      'category_label': 'Categoría',
      'import': 'Importar',

      // Onboarding
      'onboarding_title_1': 'Control Total',
      'onboarding_desc_1':
          'Maneja todo tu dinero desde tu móvil, sin necesidad de conexión a internet.',
      'onboarding_title_2': 'Sin Complicaciones',
      'onboarding_desc_2':
          'Interfaz intuitiva y rápida para registrar tus gastos e ingresos al instante.',
      'onboarding_title_3': 'Asistente IA Experto',
      'onboarding_desc_3':
          'Tu asesor financiero personal. Pregunta sobre tus gastos y consejos las 24/7.',
      'tour_wallet_title': 'Tu Billetera',
      'tour_wallet_desc': 'Aquí ves tu saldo. Toca para cambiar de tarjeta.',
      'tour_scan_title': 'Escáner Rápido',
      'tour_scan_desc': 'Escanea tarjetas físicas para agregarlas al instante.',
      'tour_ai_title': 'Asistente IA',
      'tour_ai_desc': 'Tu asesor personal. Toca para recibir consejos.',
      'tour_transfer_title': 'Transferencias',
      'tour_transfer_desc': 'Mueve dinero o envía pagos rápidamente.',
      'tour_fab_title': 'Agregar Transacción',
      'tour_fab_desc':
          'Toca aquí para registrar un nuevo gasto o ingreso rápidamente.',
      'tour_navbar_title': 'Navegación Principal',
      'tour_navbar_desc':
          'Accede a Inicio, Billetera, Estadísticas y Configuración desde aquí.',
      'tour_card_selector_title': 'Selector de Tarjetas',
      'tour_card_selector_desc':
          'Toca el nombre de la tarjeta para cambiar entre tus cuentas.',
      'tour_transactions_title': 'Transacciones Recientes',
      'tour_transactions_desc':
          'Aquí verás tus últimos movimientos. Toca para ver detalles.',
      'tour_wallet_nav_title': 'Pestaña Billetera',
      'tour_wallet_nav_desc':
          'Ve todas tus tarjetas, edítalas o agrega nuevas.',
      'tour_stats_nav_title': 'Pestaña Estadísticas',
      'tour_stats_nav_desc':
          'Analiza tus gastos e ingresos con gráficos detallados.',
      'tour_settings_nav_title': 'Pestaña Configuración',
      'tour_settings_nav_desc':
          'Personaliza la app, gestiona seguridad y exporta datos.',
      // Scanner
      'scan_card_instruction': 'Encuadra la tarjeta',
      'align_card_instruction': 'Alinea la tarjeta con el marco',

      // Category
      'category_name_placeholder': 'Nombre Categoría',

      // Settings Extended
      'sync_drive_title': 'Sincronizar con Google Drive',
      'sync_drive_desc': 'Conectar cuenta para respaldos',
      'error_connecting': 'Error al conectar',
      'user_default': 'Usuario',
      'backup_action': 'Respaldar',
      'restore_action': 'Restaurar',
      'restore_dialog_title': '¿Restaurar datos?',
      'restore_dialog_desc':
          'Esto sobrescribirá todos los datos actuales con la copia de la nube. Esta acción no se puede deshacer.',
      'restore_success_msg': 'Datos restaurados exitosamente',
      'backup_success_msg': 'Respaldo completado',
      'developed_by': 'Desarrollado por',
      'developer_name': 'Lenier Cruz Perez',
      'app_desc':
          'CashRapido es una herramienta moderna de gestión financiera diseñada para la simplicidad y rapidez.',

      // Auth
      'locked_title': 'CashRapido Bloqueado',
      'enter_pin': 'Ingresa tu PIN',
      'enter_password': 'Ingresa tu Contraseña',
      'unlock': 'Desbloquear',
      'use_biometrics': 'Usar Biometría',
      'pin_incorrect': 'PIN incorrecto',
      'password_incorrect': 'Contraseña incorrecta',

      // Home
      'hello_user': 'Hola, Usuario 👋',
      'daily_summary': 'Resumen Diario',
      'total_balance': 'Balance Total',
      'income_month': 'Ingresos (Mes)',
      'expense_month': 'Gastos (Mes)',
      'recent_transactions': 'Recientes',
      'view_all': 'Ver todo',
      'no_recent_transactions': 'No hay transacciones recientes',
      'select_card': 'Seleccionar',

      // Quick Actions
      'action_transfer': 'Transferir',
      'action_recharge': 'Recargar',
      'action_request': 'Pedir',
      'action_more': 'Más',
      'action_scan': 'Escanear',
      'action_history': 'Historial',
      'action_balances': 'Balances',
      'action_help': 'Ayuda',

      // Action Dialogs
      'from': 'Desde',
      'to_card': 'Transferir a otra tarjeta',
      'select_dest': 'Seleccionar Destino',
      'amount': 'Monto',
      'balance': 'Saldo',
      'insufficient_funds': 'Fondos insuficientes',
      'edit_transaction': 'Editar Transacción',
      'delete_transaction': 'Eliminar Transacción',
      'delete_transaction_confirm':
          '¿Estás seguro de que deseas eliminar esta transacción?',
      'transaction_updated': 'Transacción actualizada',
      'transaction_deleted': 'Transacción eliminada',
      'card_locked': 'Tarjeta Bloqueada 🔒',
      'transfer_sent': 'Transferencia enviada',
      'recharge_success': 'Recarga de saldo',
      'request_received': 'Solicitud recibida',
      'success_action': 'exitoso',
      'select_destination_error': 'Selecciona destino',

      // Stats
      'statistics': 'Estadísticas',
      'income': 'Ingresos',
      'expense': 'Gastos',
      'week': 'Semana',
      'month': 'Mes',
      'year': 'Año',
      'cat_general': 'General',
      'cat_recharge': 'Recargas',
      'cat_transfer': 'Transferencias',
      'cat_request': 'Solicitudes',
      'cat_unknown': 'Desconocido',
      'cat_food': 'Comida',
      'cat_transport': 'Transporte',
      'cat_home': 'Hogar',
      'cat_health': 'Salud',
      'cat_entertainment': 'Entretenimiento',
      'cat_bills': 'Facturas',
      'cat_shopping': 'Compras',
      'cat_transfermovil': 'Transfermóvil',

      // Add Category
      'new_category': 'Nueva Categoría',
      'cat_name_label': 'Nombre',
      'cat_name_hint': 'Ej. Gimnasio, Freelance',
      'cat_icon_label': 'Icono',
      'cat_color_label': 'Color',
      'save_category': 'Guardar Categoría',
      'enter_name_error': 'Por favor ingresa un nombre',
      'no_data': 'Sin datos',
      'of_total': 'del total',
      'by_category': 'por Categoría',
      'day': 'Día',
      'range': 'Rango',

      // Wallet
      'wallet': 'Billetera',
      'no_cards': 'No tienes tarjetas',
      'add_now': 'Agregar Ahora',
      'my_cards': 'Mis Tarjetas',
      'of': 'de',
      'card_settings': 'Configuración de Tarjeta',
      'edit_card': 'Editar Tarjeta',
      'edit_card_subtitle': 'Modificar detalles o diseño',
      'unlock_card': 'Desbloquear Tarjeta',
      'lock_card': 'Bloquear Tarjeta',
      'enable_use': 'Habilitar uso',
      'disable_temporarily': 'Inhabilitar temporalmente',
      'change_pin': 'Cambiar PIN',
      'transaction_security': 'Seguridad de transacciones',
      'spending_limit': 'Límite de Gasto',
      'no_limit_set': 'Sin límite definido',
      'delete_card': 'Eliminar Tarjeta',
      'action_cannot_undone': 'Esta acción no se puede deshacer',
      'set_pin': 'Establecer PIN',
      'enter_4_digits': 'Ingrese 4 dígitos',
      'pin_updated': 'PIN actualizado',
      'monthly_amount': 'Monto mensual',
      'limit_updated': 'Límite actualizado',
      'delete_card_question': '¿Eliminar Tarjeta?',
      'delete_card_confirmation':
          '¿Estás seguro de que quieres eliminar esta tarjeta? Perderás el historial de saldo asociado a ella.',

      // Card Management
      'new_card': 'Nueva Tarjeta',
      'edit_card_title': 'Editar Tarjeta',
      'scan_card': 'Escanear Tarjeta',
      'card_scanned': '¡Tarjeta escaneada con éxito! 📸',
      'complete_data_error': 'Por favor completa los datos correctamente',
      'invalid_date_format': 'Formato de fecha inválido (MM/YY)',
      'bank_label': 'Banco',
      'select_bank': 'Selecciona un banco',
      'card_holder': 'Titular',
      'full_name': 'Nombre Completo',
      'card_number': 'Número de Tarjeta',
      'expiration': 'Expiración',
      'initial_balance': 'Saldo Inicial',
      'currency_label': 'Moneda',
      'color_label': 'Color',
      'save_card': 'Guardar Tarjeta',
      'card_holder_placeholder': 'NOMBRE TITULAR',
      'add_card_first': 'Por favor agrega una tarjeta primero',
      'card_cash': 'Efectivo',
      'account_type': 'Tipo de Cuenta',
      'bank_card': 'Tarjeta Bancaria',
      'wallet_name': 'Nombre de la Billetera',

      // Settings
      'settings_title': 'Configuración',
      'account_security': 'Cuenta y Seguridad',
      'biometrics': 'Biometría',
      'change_password': 'Cambiar Contraseña',
      'notifications': 'Notificaciones',
      'preferences': 'Preferencias',
      'language': 'Idioma',

      'dark_mode': 'Modo Oscuro',
      'chart_type': 'Tipo de Gráfico',
      'backup_title': 'Copia de Seguridad',
      'backup_local': 'Respaldar Datos (Local)',
      'backup_local_sub': 'Guardar copia en el dispositivo',
      'restore_local': 'Importar Datos',
      'restore_local_sub': 'Restaurar desde archivo',
      'export_excel': 'Exportar a Excel',
      'export_excel_sub': 'Generar reporte .xlsx',
      'export_pdf': 'Exportar a PDF',
      'export_pdf_sub': 'Generar reporte .pdf',
      'support_legal': 'Soporte & Legal',
      'terms': 'Términos y Condiciones',
      'open_source': 'Licencias de Código Abierto',
      'paid_licenses': 'Licencias de Pago',
      'help_center': 'Centro de Ayuda',
      'about': 'Acerca de CashRapido',
      'biometrics_enabled': 'Biometría activada',
      'biometrics_disabled': 'Biometría desactivada',
      'auth_failed': 'Fallo en autenticación',
      'notif_enabled': 'Notificaciones activadas',
      'notif_disabled': 'Notificaciones desactivadas',
      'dark_mode_sim': 'Modo oscuro simulado',
      'no_licenses': 'No hay licencias activas',
      'generating_excel': 'Generando Excel...',
      'generating_pdf': 'Generando PDF...',
      'success_backup': 'Respaldo completado',
      'success_restore': 'Datos importados correctamente',
      'confirm_import': 'Confirmar Importación',
      'import_warning':
          'Importar datos sobrescribirá toda la información actual. Esta acción no se puede deshacer.\n\n¿Deseas continuar?',
      'share_save': 'Compartir / Guardar',
      'sync_drive': 'Sincronizar con Google Drive',
      'sync_drive_sub': 'Conectar cuenta para respaldos',
      'last_copy': 'Última Copia:',
      'never': 'Nunca',
      'restore_cloud_title': '¿Restaurar datos?',
      'restore_cloud_warning':
          'Esto sobrescribirá todos los datos actuales con la copia de la nube.',
      'file_saved': 'Archivo guardado en',
      'enter_amount_category_error': 'Por favor ingrese monto y categoría',
      'incorrect_pin': 'PIN Incorrecto 🚫',
      'new_transaction': 'Nueva Transacción',
      'card_default_name': 'Tarjeta',
      'description_hint': 'Descripción (Opcional)',
      'create': 'Crear',
      'save_transaction': 'Guardar Transacción',
      'chart_type_pie': 'Circular',
      'chart_type_bar': 'Barras',
      'chart_type_line': 'Tendencia',
      'backup_success': 'Respaldo creado exitosamente',

      // Security Dialogs
      'set_pin_title': 'Establecer PIN',
      'current_pin_label': 'PIN Actual',
      'new_pin_label': 'Nuevo PIN (4-6 dígitos)',
      'confirm_pin_label': 'Confirmar PIN',
      'delete_pin_action': 'Eliminar PIN',
      'pin_deleted': 'PIN eliminado',
      'current_pin_incorrect': 'PIN actual incorrecto',
      'pin_length_error': 'El PIN debe tener 4-6 dígitos',
      'pin_mismatch': 'Los PINs no coinciden',
      'pin_saved': 'PIN guardado exitosamente',

      'set_password_title': 'Establecer Contraseña',
      'current_password_label': 'Contraseña Actual',
      'new_password_label': 'Nueva Contraseña (mín. 6 caracteres)',
      'confirm_password_label': 'Confirmar Contraseña',
      'delete_password_action': 'Eliminar Contraseña',
      'password_deleted': 'Contraseña eliminada',
      'current_password_incorrect': 'Contraseña actual incorrecta',
      'password_length_error': 'La contraseña debe tener al menos 6 caracteres',
      'password_mismatch': 'Las contraseñas no coinciden',
      'password_saved': 'Contraseña guardada exitosamente',

      // Main Currency
      'main_currency': 'Moneda Principal',
      'main_currency_desc': 'Selecciona la moneda por defecto',
      'select_currency': 'Seleccionar Moneda',
      'add_currency': 'Agregar Moneda',
      'currency_code': 'Código (ej. USD)',
      'currency_symbol': 'Símbolo (ej. \$)',
      'currency_added': 'Moneda agregada exitosamente',
      'enter_currency_details': 'Ingrese los detalles de la moneda',
      'custom_currency': 'Moneda Personalizada',
      'currency_exists': 'Esta moneda ya existe',

      // Income/Expense Toggle
      'transaction_type': 'Tipo de Transacción',
      'type_expense': 'Gasto',
      'type_income': 'Ingreso',

      // New Income Categories
      'cat_salary': 'Salario',
      'cat_business': 'Negocio',
      'cat_gifts': 'Regalos',
      'cat_other_income': 'Otros Ingresos',
      'cat_rent': 'Alquiler',
      'cat_investment': 'Inversiones',

      'cards': 'Tarjetas',
      // View All
      'history_title': 'Historial de Transacciones',
      'all_cards': 'Todas las Tarjetas',
      // Currency Management
      'currency_in_use_error': 'Esta moneda está en uso por una tarjeta',
      'edit_currency': 'Editar Moneda',
      'delete_currency': 'Eliminar Moneda',
      'confirm_delete_currency': '¿Estás seguro de eliminar esta moneda?',
      // Bank Management
      'manage_banks': 'Bancos',
      'add_bank': 'Agregar Banco',
      'edit_bank': 'Editar Banco',
      'delete_bank': 'Eliminar Banco',
      'bank_name': 'Nombre del Banco',
      'bank_in_use_error': 'Este banco está en uso por una tarjeta',
      'bank_exists': 'El banco ya existe',
      'confirm_delete_bank': '¿Estás seguro de eliminar este banco?',
      'bank_added': 'Banco agregado exitosamente',
      'all_accounts': 'Todas las Cuentas',
      'bank_cards_only': 'Solo Tarjetas',
      'cash_only': 'Solo Efectivo',
      'count_money': 'Contar Dinero',
      'bill_value': 'Valor',
      'quantity': 'Cantidad',
      'total': 'Total',
      'clear_all': 'Limpiar Todo',
      'money_counter_title': 'Contador de Dinero',
      'enable_ai': 'Habilitar Asistente IA',
      'ai_chat_title': 'Asistente Financiero',
      'ask_ai_hint': 'Pide consejos, análisis...',
      'ai_welcome_message': '¡Hola! Soy tu asistente financiero personal.',

      // Licenses
      'licenses_title': 'Licencias Disponibles',
      'license_personal': 'Personal',
      'license_pro': 'Pro',
      'license_enterprise': 'Empresarial',
      'feat_3_cards': '3 Tarjetas',
      'feat_transfers': 'Transferencias',
      'feat_lock_card': 'Bloqueo/Límite Tarjeta',
      'feat_adv_stats': 'Estadísticas (Día/Semana)',
      'feat_settings_basic': 'Config (Pass/Moneda/Imp)',
      'feat_pro_cards': '4 Tarjetas',
      'feat_pro_categories': 'Crear Categorías',
      'feat_pro_stats': 'Filtros (Tarjeta/Efectivo)',
      'feat_pro_settings': 'Config (PIN/Excel/Bancos)',
      'feat_pro_security': 'Cambiar PIN Tarjeta',
      // Enterprise
      'features_all_pro': 'Todo lo de PRO +:',
      'feat_ent_unlimited': 'Tarjetas Ilimitadas',
      'feat_ent_scanner': 'Escáner y Acciones Rápidas',
      'feat_ent_ai_bio': 'IA y Biometría',
      'feat_ent_charts_pdf': 'Gráficos Pro y PDF',
      'feat_ent_cloud': 'Sincronización Cloud',
      // Payment
      'payment_methods_title': 'Método de Pago',
      'payment_test_success': '¡Pago Exitoso! Disfruta tu nueva licencia.',
      'payment_success_title': '¡Pago Exitoso!',
      'payment_error': 'Error al procesar el pago',
      'payment_disabled': 'Este método no está disponible actualmente.',
      'payment_cancelled': 'Pago cancelado',
      'payment_pending':
          'El pago de la licencia está pendiente en Apklis. Revise su app de Apklis.',
      'auth_required': 'Autenticación requerida. Inicie sesión en Apklis.',
      'connection_error': 'Error de conexión. Verifique su internet.',
      'verify_license': 'Verificar licencia',
      'verifying': 'Verificando...',
      'license_restored': 'Licencia restaurada correctamente',
      'no_license_found': 'No se encontró licencia activa',
      'verify_error': 'Error al verificar la licencia',
      'already_paid': 'Ya tienes esta licencia activa.',
      'pay_now': 'Pagar Ahora',
      'test_method': 'Prueba (Desbloqueo al instante)',
      'select_payment_region': 'Región de Pago',
      'region_cuba': 'Cuba',
      'region_intl': 'Internacional',
      'select_plan': 'Seleccionar Plan',
      'current_plan': 'Plan Actual',
      'active_plan_banner': 'PLAN ACTIVO',
      'change_plan': 'Cambiar Plan',
      'popular': 'POPULAR',
      'month_short': '/ mes',

      // Holiday Promo
      'promo_title': '¡Feliz Año Nuevo! 🎉',
      'promo_message':
          'Como regalo de fin de año, disfruta de todas las funciones PRO totalmente gratis hasta el 10 de Enero. ¡Gracias por usar CashRapido!',
      'promo_button': '¡Genial! 🚀',

      // Default License
      'default_license_title': 'Licencia Básica (Gratuita)',
      'default_license_desc':
          'Comienzas con nuestra licencia gratuita. Estas son tus limitaciones actuales:',
      'limit_card_1': 'Máximo 1 Tarjeta / Efectivo',
      'limit_no_charts': 'Sin Gráficas Avanzadas',
      'limit_no_backup': 'Sin Respaldo en Nube',
      'current_plan_limits': 'LÍMITES DEL PLAN',
      'limit_restricted_features': 'Acceso Restringido a Funciones',
      'upgrade_btn': 'Mejorar Licencia',
      'continue_btn': 'Continuar',

      // Restrictions
      'feature_locked_title': 'Función Bloqueada 🔒',
      'feature_locked_desc':
          'Esta función solo está disponible en planes Premium. ¡Mejora tu licencia para desbloquearla!',
      'limit_reached_title': 'Límite Alcanzado',
      'limit_card_desc':
          'La licencia gratuita solo permite 1 tarjeta. Mejora tu plan para agregar más.',
      'skip': 'Omitir',

      // Ads
      'pay_watch_ads': 'Ver Anuncios (Gratis)',
      'plan_renew': 'Renovar',
      'plan_change': 'Cambiar Plan',
      'dialog_watch_ads_title': 'Ver Anuncios',
      'dialog_watch_ads_desc':
          'Mira {target} anuncios para activar la Licencia {license} gratis.',
      'btn_watch_video': 'Ver Video',
      'btn_loading_ad': 'Cargando anuncio...',
      'msg_license_activated': '¡Licencia {license} activada con éxito!',
      'btn_close': 'Cerrar',
    },
    'en': {
      // Help Center
      'help_q_add_card': 'How to add my first card?',
      'help_a_add_card':
          'Go to Wallet screen (bottom icon), tap (+) and fill in your card or cash details.',
      'help_q_add_transaction': 'How to record a transaction?',
      'help_a_add_transaction':
          'Tap the floating (+) button. Select expense/income, category, amount and description.',
      'help_q_scanner': 'How to use the scanner?',
      'help_a_scanner':
          'Tap "More" in quick actions -> "Scan Card". Align your card within the frame.',
      'help_q_edit_transaction': 'How to edit a transaction?',
      'help_a_edit_transaction':
          'Tap any transaction in the list to view details and edit or delete it.',
      'help_q_transfer': 'How to transfer between cards?',
      'help_a_transfer':
          'Use "Transfer" in quick actions. Select source, destination and amount.',
      'help_q_categories': 'Can I create custom categories?',
      'help_a_categories':
          'With Pro or Enterprise license, you can create your own categories in Settings.',
      'help_q_cards_limit': 'How many cards can I have?',
      'help_a_cards_limit':
          'Depends on your license. Free: 1, Pro: 4, Enterprise: Unlimited.',
      'help_q_change_balance': 'How to change balance?',
      'help_a_change_balance':
          'Go to Wallet -> Tap card -> Edit -> Adjust balance.',
      'help_q_money_counter': 'What is the Money Counter?',
      'help_a_money_counter':
          'Tool for counting bills/coins. Only for Cash accounts.',
      'help_q_license_types': 'What license types are available?',
      'help_a_license_types':
          'Personal (Free), Pro, and Enterprise. Each unlocks more cards, charts, and cloud sync.',
      'help_q_restore_purchase': 'How do I restore my purchase?',
      'help_a_restore_purchase':
          'Go to Settings -> Licenses -> Verify License. The app will check your Apklis purchase automatically.',
      'help_q_custom_bank': 'Can I add custom banks?',
      'help_a_custom_bank':
          'Yes, in Settings -> Banks you can create and edit your own banks (Pro+ Plan).',
      'help_q_currency': 'How to change main currency?',
      'help_a_currency':
          'In Settings -> Main Currency. This sets the default currency for totals.',
      'help_q_feedback': 'How can I give feedback?',
      'help_a_feedback':
          'The app will invite you to our Telegram group after a few days of use.',

      // Feedback
      'feedback_title': 'Your opinion matters!',
      'feedback_description':
          'If you like CashRapido, rate us in our Telegram group.',
      'join_telegram': 'Join Telegram',
      'maybe_later': 'Maybe later',
      'apklis': 'Apklis',
      'play_store': 'Play Store',

      // Notifications
      'notif_daily_title': '💰 Record your expenses',
      'notif_daily_body': 'Don\'t forget to update your budget today!',
      'notif_weekly_title': '📊 Weekly Summary',
      'notif_weekly_body': 'Check your weekly spending in CashRapido',
      'notif_tip_title': '💡 Financial Tip',
      'tip_1': 'Check your monthly expenses to find areas for savings 💡',
      'tip_2': '70% of daily expenses are avoidable 🎯',
      'tip_3': 'Small daily savings = big results 🌟',
      'tip_4': 'Set realistic and achievable savings goals 🚀',
      'tip_5': 'Tracking expenses increases your financial awareness 📈',

      // General
      'app_name': 'CashRapido',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'close': 'Close',
      'delete': 'Delete',
      'edit': 'Edit',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'search': 'Search',
      'nav_home': 'Home',
      'nav_wallet': 'Wallet',
      'category_label': 'Category',
      'import': 'Import',

      // Onboarding
      'onboarding_title_1': 'Total Control',
      'onboarding_desc_1':
          'Manage all your money from your mobile, without internet connection.',
      'onboarding_title_2': 'Hassle Free',
      'onboarding_desc_2':
          'Intuitive and fast interface to record your expenses and income instantly.',
      'onboarding_title_3': 'Expert AI Assistant',
      'onboarding_desc_3':
          'Your personal financial advisor. Ask about your spending and get advice 24/7.',
      'tour_wallet_title': 'Your Wallet',
      'tour_wallet_desc': 'Here is your balance. Tap to switch cards.',
      'tour_scan_title': 'Quick Scanner',
      'tour_scan_desc': 'Scan physical cards to add them instantly.',
      'tour_ai_title': 'AI Assistant',
      'tour_ai_desc': 'Your personal advisor. Tap for advice.',
      'tour_transfer_title': 'Transfers',
      'tour_transfer_desc': 'Move money or send payments quickly.',
      'tour_fab_title': 'Add Transaction',
      'tour_fab_desc': 'Tap here to quickly record a new expense or income.',
      'tour_navbar_title': 'Main Navigation',
      'tour_navbar_desc':
          'Access Home, Wallet, Statistics, and Settings from here.',
      'tour_card_selector_title': 'Card Selector',
      'tour_card_selector_desc':
          'Tap the card name to switch between your accounts.',
      'tour_transactions_title': 'Recent Transactions',
      'tour_transactions_desc':
          'See your latest movements here. Tap for details.',
      'tour_wallet_nav_title': 'Wallet Tab',
      'tour_wallet_nav_desc':
          'View all your cards, edit them, or add new ones.',
      'tour_stats_nav_title': 'Statistics Tab',
      'tour_stats_nav_desc':
          'Analyze your spending and income with detailed charts.',
      'tour_settings_nav_title': 'Settings Tab',
      'tour_settings_nav_desc':
          'Customize the app, manage security, and export data.',

      // Scanner
      'scan_card_instruction': 'Frame the card',
      'align_card_instruction': 'Align card with frame',

      // Category
      'category_name_placeholder': 'Category Name',

      // Settings Extended
      'sync_drive_title': 'Sync with Google Drive',
      'sync_drive_desc': 'Connect account for backups',
      'error_connecting': 'Error connecting',
      'user_default': 'User',
      'backup_action': 'Backup',
      'restore_action': 'Restore',
      'restore_dialog_title': 'Restore data?',
      'restore_dialog_desc':
          'This will overwrite all current data with the cloud backup. This action cannot be undone.',
      'restore_success_msg': 'Data restored successfully',
      'backup_success_msg': 'Backup completed',
      'developed_by': 'Developed by',
      'developer_name': 'Lenier Cruz Perez',
      'app_desc':
          'CashRapido is a modern financial management tool designed for simplicity and speed.',

      // Auth
      'locked_title': 'CashRapido Locked',
      'enter_pin': 'Enter PIN',
      'enter_password': 'Enter your Password',
      'unlock': 'Unlock',
      'use_biometrics': 'Use Biometrics',
      'pin_incorrect': 'Incorrect PIN',
      'password_incorrect': 'Incorrect Password',

      // Home
      'hello_user': 'Hello, User 👋',
      'daily_summary': 'Daily Summary',
      'total_balance': 'Total Balance',
      'income_month': 'Income (Month)',
      'expense_month': 'Expense (Month)',
      'recent_transactions': 'Recent',
      'view_all': 'View All',
      'no_recent_transactions': 'No recent transactions',
      'select_card': 'Select Card',

      // Quick Actions
      'action_transfer': 'Transfer',
      'action_recharge': 'Top Up',
      'action_request': 'Request',
      'action_more': 'More',
      'action_scan': 'Scan',
      'action_history': 'History',
      'action_balances': 'Balances',
      'action_help': 'Help',

      // Action Dialogs
      'from': 'From',
      'to_card': 'Transfer to another card',
      'select_dest': 'Select Destination',
      'amount': 'Amount',
      'balance': 'Balance',
      'insufficient_funds': 'Insufficient funds 💸',
      'edit_transaction': 'Edit Transaction',
      'delete_transaction': 'Delete Transaction',
      'delete_transaction_confirm':
          'Are you sure you want to delete this transaction?',
      'transaction_updated': 'Transaction updated',
      'transaction_deleted': 'Transaction deleted',
      'card_locked': 'This card is locked 🔒',
      'transfer_sent': 'Transfer sent',
      'recharge_success': 'Balance top up',
      'request_received': 'Request received',
      'success_action': 'successful',
      'select_destination_error': 'Select destination',

      // Stats
      'statistics': 'Statistics',
      'income': 'Income',
      'expense': 'Expense',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
      'cat_general': 'General',
      'cat_recharge': 'Recharges',
      'cat_transfer': 'Transfers',
      'cat_request': 'Requests',
      'cat_unknown': 'Unknown',
      'cat_food': 'Food',
      'cat_transport': 'Transport',
      'cat_home': 'Home',
      'cat_health': 'Health',
      'cat_entertainment': 'Entertainment',
      'cat_bills': 'Bills',
      'cat_shopping': 'Shopping',
      'cat_transfermovil': 'Transfermovil',

      // Add Category
      'new_category': 'New Category',
      'cat_name_label': 'Name',
      'cat_name_hint': 'Ex. Gym, Freelance',
      'cat_icon_label': 'Icon',
      'cat_color_label': 'Color',
      'save_category': 'Save Category',
      'enter_name_error': 'Please enter a name',
      'no_data': 'No data',
      'of_total': 'of total',
      'by_category': 'by Category',
      'day': 'Day',
      'range': 'Range',

      // Wallet
      'wallet': 'Wallet',
      'no_cards': 'You don\'t have any cards',
      'add_now': 'Add Now',
      'my_cards': 'My Cards',
      'of': 'of',
      'card_settings': 'Card Settings',
      'edit_card': 'Edit Card',
      'edit_card_subtitle': 'Modify details or design',
      'unlock_card': 'Unlock Card',
      'lock_card': 'Lock Card',
      'enable_use': 'Enable use',
      'disable_temporarily': 'Disable temporarily',
      'change_pin': 'Change PIN',
      'transaction_security': 'Transaction security',
      'spending_limit': 'Spending Limit',
      'no_limit_set': 'No limit set',
      'delete_card': 'Delete Card',
      'action_cannot_undone': 'This action cannot be undone',
      'set_pin': 'Set PIN',
      'enter_4_digits': 'Enter 4 digits',
      'pin_updated': 'PIN updated',
      'monthly_amount': 'Monthly amount',
      'limit_updated': 'Limit updated',
      'delete_card_question': 'Delete Card?',
      'delete_card_confirmation':
          'Are you sure you want to delete this card? You will lose the balance history associated with it.',

      // Card Management
      'new_card': 'New Card',
      'edit_card_title': 'Edit Card',
      'scan_card': 'Scan Card',
      'card_scanned': 'Card scanned successfully! 📸',
      'complete_data_error': 'Please complete the data correctly',
      'invalid_date_format': 'Invalid date format (MM/YY)',
      'bank_label': 'Bank',
      'select_bank': 'Select a bank',
      'card_holder': 'Card Holder',
      'full_name': 'Full Name',
      'card_number': 'Card Number',
      'expiration': 'Expiration',
      'initial_balance': 'Initial Balance',
      'currency_label': 'Currency',
      'color_label': 'Color',
      'save_card': 'Save Card',
      'card_holder_placeholder': 'CARD HOLDER NAME',
      'add_card_first': 'Please add a card first',
      'card_cash': 'Cash',
      'account_type': 'Account Type',
      'bank_card': 'Bank Card',
      'wallet_name': 'Wallet Name',

      // Settings
      'settings_title': 'Settings',
      'account_security': 'Account & Security',
      'biometrics': 'Biometrics',
      'change_password': 'Change Password',
      'notifications': 'Notifications',
      'preferences': 'Preferences',
      'language': 'Language',

      'dark_mode': 'Dark Mode',
      'chart_type': 'Chart Type',
      'backup_title': 'Backup & Restore',
      'backup_local': 'Backup Data (Local)',
      'backup_local_sub': 'Save copy to device',
      'restore_local': 'Import Data',
      'restore_local_sub': 'Restore from file',
      'export_excel': 'Export to Excel',
      'export_excel_sub': 'Generate .xlsx report',
      'export_pdf': 'Export to PDF',
      'export_pdf_sub': 'Generate .pdf report',
      'support_legal': 'Support & Legal',
      'terms': 'Terms & Conditions',
      'open_source': 'Open Source Licenses',
      'paid_licenses': 'Paid Licenses',
      'help_center': 'Help Center',
      'about': 'About CashRapido',
      'biometrics_enabled': 'Biometrics enabled',
      'biometrics_disabled': 'Biometrics disabled',
      'auth_failed': 'Authentication failed',
      'notif_enabled': 'Notifications enabled',
      'notif_disabled': 'Notifications disabled',
      'dark_mode_sim': 'Simulated Dark Mode',
      'no_licenses': 'No active licenses',
      'generating_excel': 'Generating Excel...',
      'generating_pdf': 'Generating PDF...',
      'success_backup': 'Backup completed',
      'success_restore': 'Data imported successfully',
      'confirm_import': 'Confirm Import',
      'import_warning':
          'Importing data will overwrite all current information. This action cannot be undone.\n\nDo you wish to continue?',
      'share_save': 'Share / Save',
      'sync_drive': 'Sync with Google Drive',
      'sync_drive_sub': 'Connect account for backups',
      'last_copy': 'Last Copy:',
      'never': 'Never',
      'restore_cloud_title': 'Restore data?',
      'restore_cloud_warning':
          'This will overwrite all current data with the cloud backup.',
      'file_saved': 'File saved at',
      'enter_amount_category_error': 'Please enter amount and category',
      'incorrect_pin': 'Incorrect PIN 🚫',
      'new_transaction': 'New Transaction',
      'card_default_name': 'Card',
      'description_hint': 'Description (Optional)',
      'create': 'Create',
      'save_transaction': 'Save Transaction',
      'chart_type_pie': 'Pie',
      'chart_type_bar': 'Bar',
      'chart_type_line': 'Trend',
      'backup_success': 'Backup created successfully',

      // Security Dialogs
      'set_pin_title': 'Set PIN',
      'current_pin_label': 'Current PIN',
      'new_pin_label': 'New PIN (4-6 digits)',
      'confirm_pin_label': 'Confirm PIN',
      'delete_pin_action': 'Delete PIN',
      'pin_deleted': 'PIN deleted',
      'current_pin_incorrect': 'Incorrect current PIN',
      'pin_length_error': 'PIN must be 4-6 digits',
      'pin_mismatch': 'PINs do not match',
      'pin_saved': 'PIN saved successfully',

      'set_password_title': 'Set Password',
      'current_password_label': 'Current Password',
      'new_password_label': 'New Password (min. 6 chars)',
      'confirm_password_label': 'Confirm Password',
      'delete_password_action': 'Delete Password',
      'password_deleted': 'Password deleted',
      'current_password_incorrect': 'Incorrect current password',
      'password_length_error': 'Password must be at least 6 characters',
      'password_mismatch': 'Passwords do not match',
      'password_saved': 'Password saved successfully',

      // Main Currency
      'main_currency': 'Main Currency',
      'main_currency_desc': 'Select default currency',
      'select_currency': 'Select Currency',
      'add_currency': 'Add Currency',
      'currency_code': 'Code (e.g. USD)',
      'currency_symbol': 'Symbol (e.g. \$)',
      'currency_added': 'Currency added successfully',
      'enter_currency_details': 'Enter currency details',
      'custom_currency': 'Custom Currency',
      'currency_exists': 'This currency already exists',

      // Income/Expense Toggle
      'transaction_type': 'Transaction Type',
      'type_expense': 'Expense',
      'type_income': 'Income',

      // New Income Categories
      'cat_salary': 'Salary',
      'cat_business': 'Business',
      'cat_gifts': 'Gifts',
      'cat_other_income': 'Other Income',
      'cat_rent': 'Rent',
      'cat_investment': 'Investment',

      'cards': 'Cards',
      'history_title': 'Transaction History',
      'all_cards': 'All Cards',
      // Currency Management
      'currency_in_use_error': 'Currency is in use by a card',
      'edit_currency': 'Edit Currency',
      'delete_currency': 'Delete Currency',
      'confirm_delete_currency':
          'Are you sure you want to delete this currency?',
      // Bank Management
      'manage_banks': 'Banks',
      'add_bank': 'Add Bank',
      'edit_bank': 'Edit Bank',
      'delete_bank': 'Delete Bank',
      'bank_name': 'Bank Name',
      'bank_in_use_error': 'Bank is in use by a card',
      'bank_exists': 'Bank already exists',
      'confirm_delete_bank': 'Are you sure you want to delete this bank?',
      'bank_added': 'Bank added successfully',
      'all_accounts': 'All Accounts',
      'bank_cards_only': 'Cards Only',
      'cash_only': 'Cash Only',
      'count_money': 'Count Money',
      'bill_value': 'Value',
      'quantity': 'Count',
      'total': 'Total',
      'clear_all': 'Clear All',
      'money_counter_title': 'Money Counter',
      'enable_ai': 'Enable AI Assistant',
      'ai_chat_title': 'Financial Assistant',
      'ask_ai_hint': 'Ask for advice, analysis...',
      'ai_welcome_message': 'Hello! I am your personal financial assistant.',

      // Licenses
      'licenses_title': 'Available Licenses',
      'skip': 'Skip',
      'license_personal': 'Personal',
      'license_pro': 'Pro',
      'license_enterprise': 'Enterprise',
      'feat_3_cards': '3 Cards',
      'feat_transfers': 'Transfers',
      'feat_lock_card': 'Lock/Limit Card',
      'feat_adv_stats': 'Stats (Day/Week)',
      'feat_settings_basic': 'Settings (Pass/Curr/Imp)',
      'feat_pro_cards': '4 Cards',
      'feat_pro_categories': 'Create Categories',
      'feat_pro_stats': 'Filters (Card/Cash)',
      'feat_pro_settings': 'Settings (PIN/Excel/Banks)',
      'feat_pro_security': 'Change Card PIN',
      // Enterprise
      'features_all_pro': 'Everything in PRO +:',
      'feat_ent_unlimited': 'Unlimited Cards',
      'feat_ent_scanner': 'Scanner & Quick Actions',
      'feat_ent_ai_bio': 'AI & Biometrics',
      'feat_ent_charts_pdf': 'Pro Charts & PDF',
      'feat_ent_cloud': 'Cloud Sync',
      // Payment
      'payment_methods_title': 'Payment Method',
      'payment_test_success': 'Payment Successful! Enjoy your new license.',
      'payment_success_title': 'Payment Successful!',
      'payment_error': 'Error processing payment',
      'payment_disabled': 'This method is currently unavailable.',
      'payment_cancelled': 'Payment cancelled',
      'payment_pending':
          'License payment is pending in Apklis. Check your Apklis app.',
      'auth_required': 'Authentication required. Please log in to Apklis.',
      'connection_error': 'Connection error. Check your internet.',
      'verify_license': 'Verify license',
      'verifying': 'Verifying...',
      'license_restored': 'License restored successfully',
      'no_license_found': 'No active license found',
      'verify_error': 'Error verifying license',
      'already_paid': 'You already have this license active.',
      'pay_now': 'Pay Now',
      'test_method': 'Test (Instant Unlock)',
      'select_payment_region': 'Payment Region',
      'region_cuba': 'Cuba',
      'region_intl': 'International',
      'select_plan': 'Select Plan',
      'current_plan': 'Current Plan',
      'active_plan_banner': 'ACTIVE PLAN',
      'change_plan': 'Change Plan',
      'popular': 'POPULAR',
      'month_short': '/ month',

      // Holiday Promo
      'promo_title': 'Happy New Year! 🎉',
      'promo_message':
          'As a year-end gift, enjoy all PRO features completely free until January 10th. Thanks for using CashRapido!',
      'promo_button': 'Awesome! 🚀',

      // Default License
      'default_license_title': 'Basic License (Free)',
      'default_license_desc':
          'You start with our free license. Here are your current limitations:',
      'limit_card_1': 'Max 1 Card / Cash',
      'limit_no_charts': 'No Advanced Charts',
      'limit_no_backup': 'No Cloud Backup',
      'current_plan_limits': 'PLAN LIMITS',
      'limit_restricted_features': 'Restricted Access to Features',
      'upgrade_btn': 'Upgrade License',
      'continue_btn': 'Continue',

      // Restrictions
      'feature_locked_title': 'Feature Locked 🔒',
      'feature_locked_desc':
          'This feature is available on Premium plans only. Upgrade your license to unlock!',
      'limit_reached_title': 'Limit Reached',
      'limit_card_desc':
          'The free license allows only 1 card. Upgrade your plan to add more.',

      // Ads
      'pay_watch_ads': 'Watch Ads (Free)',
      'plan_renew': 'Renew',
      'plan_change': 'Change Plan',
      'dialog_watch_ads_title': 'Watch Ads',
      'dialog_watch_ads_desc':
          'Watch {target} ads to activate {license} License for free.',
      'btn_watch_video': 'Watch Video',
      'btn_loading_ad': 'Loading ad...',
      'msg_license_activated': '{license} License activated successfully!',
      'btn_close': 'Close',
    },
    'fr': {
      // Help Center
      'help_q_add_card': 'Comment ajouter ma première carte ?',
      'help_a_add_card':
          'Allez à l\'écran Portefeuille, appuyez sur (+) et remplissez les détails de carte ou espèces.',
      'help_q_add_transaction': 'Comment enregistrer une transaction ?',
      'help_a_add_transaction':
          'Appuyez sur le bouton flottant (+). Sélectionnez dépense/revenu, catégorie, montant.',
      'help_q_scanner': 'Comment utiliser le scanner ?',
      'help_a_scanner':
          'Appuyez sur "Plus" -> "Scanner Carte". Alignez votre carte avec le cadre.',
      'help_q_edit_transaction': 'Comment modifier une transaction ?',
      'help_a_edit_transaction':
          'Appuyez sur une transaction pour voir les détails, la modifier ou la supprimer.',
      'help_q_transfer': 'Comment transférer entre cartes ?',
      'help_a_transfer':
          'Utilisez "Transférer". Sélectionnez la source, la destination et le montant.',
      'help_q_categories': 'Puis-je créer des catégories ?',
      'help_a_categories':
          'Avec la licence Pro ou Entreprise, vous pouvez créer vos propres catégories.',
      'help_q_cards_limit': 'Combien de cartes puis-je avoir ?',
      'help_a_cards_limit':
          'Dépend de votre licence. Gratuit : 1, Pro : 4, Entreprise : Illimité.',
      'help_q_change_balance': 'Comment changer le solde ?',
      'help_a_change_balance':
          'Portefeuille -> Carte -> Modifier -> Ajuster le solde.',
      'help_q_money_counter': 'Qu\'est-ce que le Compteur d\'Argent ?',
      'help_a_money_counter':
          'Outil pour compter billets/pièces. Uniquement pour les comptes Espèces.',
      'help_q_license_types': 'Quels types de licences existent ?',
      'help_a_license_types':
          'Personnel (Gratuit), Pro et Entreprise. Chacun débloque plus de fonctionnalités.',
      'help_q_restore_purchase': 'Comment restaurer mon achat ?',
      'help_a_restore_purchase':
          'Paramètres -> Licences -> Vérifier. L\'appli vérifiera votre achat Apklis.',
      'help_q_custom_bank': 'Puis-je ajouter des banques ?',
      'help_a_custom_bank':
          'Oui, dans Paramètres -> Banques, vous pouvez créer vos propres banques (Plan Pro+).',
      'help_q_currency': 'Comment changer la devise principale ?',
      'help_a_currency':
          'Dans Paramètres -> Devise Principale. Définit la devise par défaut.',
      'help_q_feedback': 'Comment donner mon avis ?',
      'help_a_feedback':
          'L\'application vous invitera à rejoindre notre groupe Telegram après quelques jours.',

      // Feedback
      'feedback_title': 'Votre avis compte !',
      'feedback_description':
          'Si vous aimez CashRapido, évaluez-nous dans notre groupe Telegram.',
      'join_telegram': 'Rejoindre Telegram',
      'maybe_later': 'Peut-être plus tard',
      'apklis': 'Apklis',
      'play_store': 'Play Store',

      // Notifications
      'notif_daily_title': '💰 Enregistrez vos dépenses',
      'notif_daily_body':
          'N\'oubliez pas de mettre à jour votre budget aujourd\'hui !',
      'notif_weekly_title': '📊 Résumé Hebdomadaire',
      'notif_weekly_body':
          'Vérifiez vos dépenses de la semaine dans CashRapido',
      'notif_tip_title': '💡 Conseil Financier',
      'tip_1': 'Vérifiez vos dépenses mensuelles pour trouver des économies 💡',
      'tip_2': '70% des dépenses quotidiennes sont évitables 🎯',
      'tip_3': 'Petites économies quotidiennes = grands résultats 🌟',
      'tip_4': 'Fixez des objectifs d\'épargne réalistes et réalisables 🚀',
      'tip_5': 'Le suivi des dépenses augmente votre conscience financière 📈',

      // General
      'app_name': 'CashRapido',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'save': 'Enregistrer',
      'close': 'Fermer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'error': 'Erreur',
      'success': 'Succès',
      'loading': 'Chargement...',
      'search': 'Rechercher',
      'nav_home': 'Accueil',
      'nav_wallet': 'Portefeuille',
      'category_label': 'Catégorie',
      'import': 'Importer',

      // Onboarding
      'onboarding_title_1': 'Contrôle Total',
      'onboarding_desc_1':
          'Gérez tout votre argent depuis votre mobile, sans connexion internet.',
      'onboarding_title_2': 'Sans Tracas',
      'onboarding_desc_2':
          'Interface intuitive et rapide pour enregistrer vos dépenses et revenus instantanément.',
      'onboarding_title_3': 'Assistant IA Expert',
      'onboarding_desc_3':
          'Votre conseiller financier personnel. Posez des questions sur vos dépenses 24/7.',
      'tour_wallet_title': 'Votre Portefeuille',
      'tour_wallet_desc': 'Voici votre solde. Appuyez pour changer de carte.',
      'tour_scan_title': 'Scanner Rapide',
      'tour_scan_desc':
          'Scannez des cartes physiques pour les ajouter instantanément.',
      'tour_ai_title': 'Assistant IA',
      'tour_ai_desc': 'Votre conseiller personnel. Appuyez pour des conseils.',
      'tour_transfer_title': 'Transferts',
      'tour_transfer_desc':
          'Déplacez de l\'argent ou envoyez des paiements rapidement.',
      'tour_fab_title': 'Ajouter Transaction',
      'tour_fab_desc':
          'Appuyez ici pour enregistrer rapidement une dépense ou un revenu.',
      'tour_navbar_title': 'Navigation Principale',
      'tour_navbar_desc':
          'Accédez à Accueil, Portefeuille, Statistiques et Paramètres d\'ici.',
      'tour_card_selector_title': 'Sélecteur de Cartes',
      'tour_card_selector_desc':
          'Appuyez sur le nom de la carte pour changer de compte.',
      'tour_transactions_title': 'Transactions Récentes',
      'tour_transactions_desc':
          'Voyez vos derniers mouvements ici. Appuyez pour les détails.',
      'tour_wallet_nav_title': 'Onglet Portefeuille',
      'tour_wallet_nav_desc':
          'Consultez toutes vos cartes, modifiez-les ou ajoutez-en de nouvelles.',
      'tour_stats_nav_title': 'Onglet Statistiques',
      'tour_stats_nav_desc':
          'Analysez vos dépenses et revenus avec des graphiques détaillés.',
      'tour_settings_nav_title': 'Onglet Paramètres',
      'tour_settings_nav_desc':
          'Personnalisez l\'application, gérez la sécurité et exportez les données.',

      // Scanner
      'scan_card_instruction': 'Encadrer la carte',
      'align_card_instruction': 'Aligner la carte avec le cadre',

      // Category
      'category_name_placeholder': 'Nom de la Catégorie',

      // Settings Extended
      'sync_drive_title': 'Sync avec Google Drive',
      'sync_drive_desc': 'Connecter compte pour sauvegardes',
      'error_connecting': 'Erreur de connexion',
      'user_default': 'Utilisateur',
      'backup_action': 'Sauvegarder',
      'restore_action': 'Restaurer',
      'restore_dialog_title': 'Restaurer les données ?',
      'restore_dialog_desc':
          'Cela écrasera toutes les données actuelles avec la sauvegarde cloud. Cette action est irréversible.',
      'restore_success_msg': 'Données restaurées avec succès',
      'backup_success_msg': 'Sauvegarde terminée',

      // Rest of keys... I will assume similar structure for FR if I see the end of file, but I don't see the end of FR block in the previous view_file.
      // Wait, I only saw up to line 800. I need to be careful. The chunk needs to be precise.
      // I'll skip FR for this specific chunk call and do a separate view to find the end of the FR block or just append to where I know it is safe.
      // Actually, looking at the previous file view, 'fr' starts at 723.
      // I can't see the end of 'fr'. I should verify the file content for FR before writing.
      // I will only write ES and EN for now and then read the rest to write FR.
      'developed_by': 'Développé par',
      'developer_name': 'Lenier Cruz Perez',
      'app_desc':
          'CashRapido est un outil de gestion financière moderne conçu pour la simplicité et la rapidité.',

      // Auth
      'locked_title': 'CashRapido Verrouillé',
      'enter_pin': 'Entrez le PIN',
      'enter_password': 'Entrez votre mot de passe',
      'unlock': 'Déverrouiller',
      'use_biometrics': 'Utiliser Biométrie',
      'pin_incorrect': 'PIN incorrect',
      'password_incorrect': 'Mot de passe incorrect',

      // Home
      'hello_user': 'Bonjour, Utilisateur 👋',
      'daily_summary': 'Résumé Quotidien',
      'total_balance': 'Solde Total',
      'income_month': 'Revenus (Mois)',
      'expense_month': 'Dépenses (Mois)',
      'recent_transactions': 'Récents',
      'view_all': 'Voir tout',
      'no_recent_transactions': 'Aucune transaction récente',
      'select_card': 'Sélectionner une carte',

      // Quick Actions
      'action_transfer': 'Transférer',
      'action_recharge': 'Recharger',
      'action_request': 'Demander',
      'action_more': 'Plus',
      'action_scan': 'Scanner',
      'action_history': 'Historique',
      'action_balances': 'Soldes',
      'action_help': 'Aide',

      // Action Dialogs
      'from': 'De',
      'to_card': 'Transférer vers une autre carte',
      'select_dest': 'Sélectionner la destination',
      'amount': 'Montant',
      'balance': 'Solde',
      'insufficient_funds': 'Fonds insuffisants 💸',
      'edit_transaction': 'Modifier la Transaction',
      'delete_transaction': 'Supprimer la Transaction',
      'delete_transaction_confirm':
          'Êtes-vous sûr de vouloir supprimer cette transaction?',
      'transaction_updated': 'Transaction mise à jour',
      'transaction_deleted': 'Transaction supprimée',
      'card_locked': 'Cette carte est verrouillée 🔒',
      'transfer_sent': 'Virement envoyé',
      'recharge_success': 'Recharge de solde',
      'request_received': 'Demande reçue',
      'success_action': 'réussi',
      'select_destination_error': 'Sélectionner la destination',

      // Stats
      'statistics': 'Statistiques',
      'income': 'Revenus',
      'expense': 'Dépenses',
      'week': 'Semaine',
      'month': 'Mois',
      'year': 'Année',
      'cat_general': 'Général',
      'cat_recharge': 'Recharges',
      'cat_transfer': 'Transferts',
      'cat_request': 'Demandes',
      'cat_unknown': 'Inconnu',
      'cat_food': 'Nourriture',
      'cat_transport': 'Transport',
      'cat_home': 'Maison',
      'cat_health': 'Santé',
      'cat_entertainment': 'Divertissement',
      'cat_bills': 'Factures',
      'cat_shopping': 'Achats',

      // Add Category
      'new_category': 'Nouvelle Catégorie',
      'cat_name_label': 'Nom',
      'cat_name_hint': 'Ex. Gym, Freelance',
      'cat_icon_label': 'Icône',
      'cat_color_label': 'Couleur',
      'save_category': 'Enregistrer la catégorie',
      'enter_name_error': 'Veuillez saisir un nom',
      'no_data': 'Aucune donnée',
      'of_total': 'du total',
      'by_category': 'par Catégorie',
      'day': 'Jour',
      'range': 'Gamme',

      // Wallet
      'wallet': 'Portefeuille',
      'no_cards': 'Vous n\'avez pas de cartes',
      'add_now': 'Ajouter maintenant',
      'my_cards': 'Mes Cartes',
      'of': 'de',
      'card_settings': 'Paramètres de la carte',
      'edit_card': 'Modifier la carte',
      'edit_card_subtitle': 'Modifier les détails ou le design',
      'unlock_card': 'Déverrouiller la carte',
      'lock_card': 'Verrouiller la carte',
      'enable_use': 'Activer l\'utilisation',
      'disable_temporarily': 'Désactiver temporairement',
      'change_pin': 'Changer le PIN',
      'transaction_security': 'Sécurité des transactions',
      'spending_limit': 'Limite de dépenses',
      'no_limit_set': 'Aucune limite définie',
      'delete_card': 'Supprimer la carte',
      'action_cannot_undone': 'Cette action ne peut pas être annulée',
      'set_pin': 'Établir un PIN',
      'enter_4_digits': 'Entrez 4 chiffres',
      'pin_updated': 'PIN mis à jour',
      'monthly_amount': 'Montant mensuel',
      'limit_updated': 'Limite mise à jour',
      'delete_card_question': 'Supprimer la carte?',
      'delete_card_confirmation':
          'Êtes-vous sûr de vouloir supprimer cette carte? Vous perdrez l\'historique du solde qui lui est associé.',

      // Card Management
      'new_card': 'Nouvelle Carte',
      'edit_card_title': 'Modifier la Carte',
      'scan_card': 'Scanner la Carte',
      'card_scanned': 'Carte scannée avec succès! 📸',
      'complete_data_error': 'Veuillez compléter les données correctement',
      'invalid_date_format': 'Format de date invalide (MM/AA)',
      'bank_label': 'Banque',
      'select_bank': 'Sélectionnez une banque',
      'card_holder': 'Titulaire',
      'full_name': 'Nom Complet',
      'card_number': 'Numéro de Carte',
      'expiration': 'Expiration',
      'initial_balance': 'Solde Initial',
      'currency_label': 'Devise',
      'color_label': 'Couleur',
      'save_card': 'Enregistrer la Carte',
      'card_holder_placeholder': 'NOM DU TITULAIRE',
      'add_card_first': 'Veuillez d\'abord ajouter une carte',
      'card_cash': 'Espèces',
      'account_type': 'Type de Compte',
      'bank_card': 'Carte Bancaire',
      'wallet_name': 'Nom du Portefeuille',

      // Settings
      'settings_title': 'Paramètres',
      'account_security': 'Compte et Sécurité',
      'biometrics': 'Biométrie',
      'change_password': 'Changer le mot de passe',
      'notifications': 'Notifications',
      'preferences': 'Préférences',
      'language': 'Langue',

      'dark_mode': 'Mode Sombre',
      'chart_type': 'Type de Graphique',
      'backup_title': 'Sauvegarde et Restauration',
      'backup_local': 'Sauvegarder (Local)',
      'backup_local_sub': 'Enregistrer sur l\'appareil',
      'restore_local': 'Importer des Données',
      'restore_local_sub': 'Restaurer depuis un fichier',
      'export_excel': 'Exporter vers Excel',
      'export_excel_sub': 'Générer rapport .xlsx',
      'export_pdf': 'Exporter vers PDF',
      'export_pdf_sub': 'Générer rapport .pdf',
      'support_legal': 'Support et Juridique',
      'terms': 'Termes et Conditions',
      'open_source': 'Licences Open Source',
      'paid_licenses': 'Licences Payantes',
      'help_center': 'Centre d\'Aide',
      'about': 'À propos de CashRapido',
      'biometrics_enabled': 'Biométrie activée',
      'biometrics_disabled': 'Biométrie désactivée',
      'auth_failed': 'Authentification échouée',
      'notif_enabled': 'Notifications activées',
      'notif_disabled': 'Notifications désactivées',
      'dark_mode_sim': 'Mode sombre simulé',
      'no_licenses': 'Aucune licence active',
      'generating_excel': 'Génération Excel...',
      'generating_pdf': 'Génération PDF...',
      'success_backup': 'Sauvegarde terminée',
      'success_restore': 'Données importées avec succès',
      'confirm_import': 'Confirmer l\'importation',
      'import_warning':
          'L\'importation écrasera toutes les données actuelles. Cette action est irréversible.\n\nVoulez-vous continuer ?',
      'share_save': 'Partager / Enregistrer',
      'sync_drive': 'Sync avec Google Drive',
      'sync_drive_sub': 'Connecter compte pour sauvegardes',
      'last_copy': 'Dernière Copie :',
      'never': 'Jamais',
      'restore_cloud_title': 'Restaurer les données ?',
      'restore_cloud_warning':
          'Cela écrasera toutes les données actuelles avec la sauvegarde cloud.',
      'file_saved': 'Fichier enregistré sous',
      'enter_amount_category_error':
          'Veuillez saisir le montant et la catégorie',
      // Income/Expense Toggle
      'transaction_type': 'Type de Transaction',
      'type_expense': 'Dépense',
      'type_income': 'Revenu',

      // New Income Categories
      'cat_salary': 'Salaire',
      'cat_business': 'Affaires',
      'cat_gifts': 'Cadeaux',
      'cat_other_income': 'Autres Revenus',
      'cat_rent': 'Loyer',
      'cat_investment': 'Investissement',
      'cat_transfermovil': 'Transfermovil',

      'cards': 'Cartes',
      // View All
      'history_title': 'Historique des transactions',
      'all_cards': 'Toutes les cartes',
      // Currency Management
      'currency_in_use_error': 'Cette devise est utilisée par une carte',
      'edit_currency': 'Modifier la devise',
      'delete_currency': 'Supprimer la devise',
      'confirm_delete_currency':
          'Voulez-vous vraiment supprimer cette devise ?',
      // Bank Management
      'manage_banks': 'Banques',
      'add_bank': 'Ajouter une banque',
      'edit_bank': 'Modifier la banque',
      'delete_bank': 'Supprimer la banque',
      'bank_name': 'Nom de la banque',
      'bank_in_use_error': 'Cette banque est utilisée par une carte',
      'bank_exists': 'La banque existe déjà',
      'confirm_delete_bank': 'Voulez-vous vraiment supprimer cette banque ?',
      'bank_added': 'Banque ajoutée avec succès',
      'incorrect_pin': 'PIN incorrect 🚫',
      'new_transaction': 'Nouvelle Transaction',
      'card_default_name': 'Carte',
      'description_hint': 'Description (Optionnel)',
      'create': 'Créer',
      'save_transaction': 'Enregistrer la transaction',
      'chart_type_pie': 'Circulaire',
      'chart_type_bar': 'Barres',
      'chart_type_line': 'Tendance',
      'backup_success': 'Sauvegarde créée avec succès',

      // Security Dialogs
      'set_pin_title': 'Définir PIN',
      'current_pin_label': 'PIN Actuel',
      'new_pin_label': 'Nouveau PIN (4-6 chiffres)',
      'confirm_pin_label': 'Confirmer PIN',
      'delete_pin_action': 'Supprimer PIN',
      'pin_deleted': 'PIN supprimé',
      'current_pin_incorrect': 'PIN actuel incorrect',
      'pin_length_error': 'Le PIN doit avoir 4-6 chiffres',
      'pin_mismatch': 'Les PINs ne correspondent pas',
      'pin_saved': 'PIN enregistré avec succès',

      'set_password_title': 'Définir Mot de Passe',
      'current_password_label': 'Mot de Passe Actuel',
      'new_password_label': 'Nouveau Mot de Passe (min. 6 car.)',
      'confirm_password_label': 'Confirmer Mot de Passe',
      'delete_password_action': 'Supprimer Mot de Passe',
      'password_deleted': 'Mot de Passe supprimé',
      'current_password_incorrect': 'Mot de passe actuel incorrect',
      'password_length_error':
          'Le mot de passe doit avoir au moins 6 caractères',
      'password_mismatch': 'Les mots de passe ne correspondent pas',
      'password_saved': 'Mot de passe enregistré avec succès',

      // Main Currency
      'main_currency': 'Devise Principale',
      'main_currency_desc': 'Sélectionner la devise par défaut',
      'select_currency': 'Sélectionner Devise',
      'add_currency': 'Ajouter Devise',
      'currency_code': 'Code (ex. USD)',
      'currency_symbol': 'Symbole (ex. \$)',
      'currency_added': 'Devise ajoutée avec succès',
      'enter_currency_details': 'Entrez les détails de la devise',
      'custom_currency': 'Devise Personnalisée',
      'currency_exists': 'Cette devise existe déjà',
      'all_accounts': 'Tous les Comptes',
      'bank_cards_only': 'Cartes Uniquement',
      'cash_only': 'Espèces Uniquement',
      'count_money': 'Compter l\'argent',
      'bill_value': 'Valeur',
      'quantity': 'Quantité',
      'total': 'Total',
      'clear_all': 'Tout Effacer',
      'money_counter_title': 'Compteur d\'Argent',
      'enable_ai': 'Activer l\'Assistant IA',
      'ai_chat_title': 'Assistant Financier',
      'ask_ai_hint': 'Demandez des conseils...',
      'ai_welcome_message':
          'Bonjour ! Je suis votre assistant financier personnel.',

      // Licenses
      'licenses_title': 'Licences Disponibles',
      'license_personal': 'Personnel',
      'license_pro': 'Pro',
      'license_enterprise': 'Entreprise',
      'feat_3_cards': '3 Cartes',
      'feat_transfers': 'Transferts',
      'feat_lock_card': 'Verrou/Limite Carte',
      'feat_adv_stats': 'Stats (Jour/Semaine)',
      'feat_settings_basic': 'Param (Pass/Dev/Imp)',
      'feat_pro_cards': '4 Cartes',
      'feat_pro_categories': 'Créer Catégories',
      'feat_pro_stats': 'Filtres (Carte/Espèces)',
      'feat_pro_settings': 'Param (PIN/Excel/Banques)',
      'feat_pro_security': 'Changer PIN Carte',
      // Enterprise
      'features_all_pro': 'Tout ce qui est PRO + :',
      'feat_ent_unlimited': 'Cartes Illimitées',
      'feat_ent_scanner': 'Scanner et Actions Rapides',
      'feat_ent_ai_bio': 'IA et Biométrie',
      'feat_ent_charts_pdf': 'Graphiques Pro et PDF',
      'feat_ent_cloud': 'Synchro Cloud',
      // Payment
      'payment_methods_title': 'Méthode de Paiement',
      'payment_test_success':
          'Paiement Réussi ! Profitez de votre nouvelle licence.',
      'payment_success_title': 'Paiement Réussi !',
      'payment_error': 'Erreur lors du traitement du paiement',
      'payment_disabled': 'Cette méthode n\'est pas disponible actuellement.',
      'payment_cancelled': 'Paiement annulé',
      'payment_pending':
          'Le paiement de la licence est en attente dans Apklis. Vérifiez votre application Apklis.',
      'auth_required':
          'Authentification requise. Veuillez vous connecter à Apklis.',
      'connection_error': 'Erreur de connexion. Vérifiez votre internet.',
      'verify_license': 'Vérifier la licence',
      'verifying': 'Vérification...',
      'license_restored': 'Licence restaurée avec succès',
      'no_license_found': 'Aucune licence active trouvée',
      'verify_error': 'Erreur lors de la vérification de la licence',
      'already_paid': 'Vous avez déjà cette licence active.',
      'pay_now': 'Payer Maintenant',
      'test_method': 'Test (Déverrouillage instantané)',
      'select_payment_region': 'Région de Paiement',
      'region_cuba': 'Cuba',
      'region_intl': 'International',
      'select_plan': 'Sélectionner le plan',
      'current_plan': 'Plan Actuel',
      'active_plan_banner': 'PLAN ACTIF',
      'change_plan': 'Changer de Plan',
      'popular': 'POPULAIRE',
      'month_short': '/ mois',

      // Holiday Promo
      'promo_title': 'Bonne Année ! 🎉',
      'promo_message':
          'En cadeau de fin d\'année, profitez de toutes les fonctionnalités PRO gratuitement jusqu\'au 10 janvier. Merci d\'utiliser CashRapido !',
      'promo_button': 'Génial ! 🚀',

      // Default License
      'default_license_title': 'Licence de Base (Gratuite)',
      'default_license_desc':
          'Vous commencez avec notre licence gratuite. Voici vos limitations actuelles :',
      'limit_card_1': 'Max 1 Carte / Espèces',
      'limit_no_charts': 'Pas de Graphiques Avancés',
      'limit_no_backup': 'Pas de Sauvegarde Cloud',
      'current_plan_limits': 'LIMITES DU PLAN',
      'limit_restricted_features': 'Accès Restreint aux Fonctionnalités',
      'upgrade_btn': 'Mettre à niveau',
      'continue_btn': 'Continuer',

      // Restrictions
      'feature_locked_title': 'Fonction Verrouillée 🔒',
      'feature_locked_desc':
          'Cette fonctionnalité est disponible uniquement sur les plans Premium. Mettez à niveau pour débloquer !',
      'limit_reached_title': 'Limite Atteinte',
      'limit_card_desc':
          'La licence gratuite permet seulement 1 carte. Mettez à niveau pour en ajouter plus.',
      'skip': 'Passer',

      // Ads
      'pay_watch_ads': 'Regarder Pubs (Gratuit)',
      'plan_renew': 'Renouveler',
      'plan_change': 'Changer de Plan',
      'dialog_watch_ads_title': 'Regarder Pubs',
      'dialog_watch_ads_desc':
          'Regardez {target} pubs pour activer la Licence {license} gratuitement.',
      'btn_watch_video': 'Regarder Vidéo',
      'btn_loading_ad': 'Chargement...',
      'msg_license_activated': 'Licence {license} activée avec succès !',
      'btn_close': 'Fermer',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Extension for easier access
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this);
  String t(String key) => AppLocalizations.of(this).translate(key);
}
