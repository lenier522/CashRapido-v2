import 'package:material_ui/material_ui.dart';

/// Claves de los grupos de iconos (localizables en cada idioma).
class CategoryIconGroups {
  static const food = 'icon_group_food';
  static const transport = 'icon_group_transport';
  static const home = 'icon_group_home';
  static const shopping = 'icon_group_shopping';
  static const health = 'icon_group_health';
  static const education = 'icon_group_education';
  static const entertainment = 'icon_group_entertainment';
  static const sports = 'icon_group_sports';
  static const tech = 'icon_group_tech';
  static const work = 'icon_group_work';
  static const business = 'icon_group_business';
  static const money = 'icon_group_money';
  static const bank = 'icon_group_bank';
  static const income = 'icon_group_income';
  static const payments = 'icon_group_payments';
  static const travel = 'icon_group_travel';
  static const family = 'icon_group_family';
  static const people = 'icon_group_people';
  static const pets = 'icon_group_pets';
  static const clothing = 'icon_group_clothing';
  static const services = 'icon_group_services';
  static const communication = 'icon_group_communication';
  static const security = 'icon_group_security';
  static const tools = 'icon_group_tools';
  static const time = 'icon_group_time';
  static const nature = 'icon_group_nature';
  static const other = 'icon_group_other';

  /// Orden estable de presentación de los grupos.
  static const List<String> groups = <String>[
    food,
    transport,
    home,
    shopping,
    health,
    education,
    entertainment,
    sports,
    tech,
    work,
    business,
    money,
    bank,
    income,
    payments,
    travel,
    family,
    people,
    pets,
    clothing,
    services,
    communication,
    security,
    tools,
    time,
    nature,
    other,
  ];
}

/// Un icono del catálogo de categorías.
class CategoryIconOption {
  /// Código que se persiste en `Category.iconCode`.
  final int codePoint;

  final IconData icon;

  /// Nombre canónico (para búsqueda y tooltips).
  final String name;

  /// Palabras clave de búsqueda en varios idiomas.
  final List<String> keywords;

  /// Grupo al que pertenece (ver [CategoryIconGroups]).
  final String group;

  CategoryIconOption(this.icon, this.name, this.keywords, this.group)
    : codePoint = icon.codePoint;
}

/// REGISTRO ÚNICO de iconos de categoría.
///
/// Es la única fuente de verdad para el icono, su nombre, sus keywords y su
/// grupo. El catálogo es estático y se reutiliza: la búsqueda sólo filtra esta
/// lista y nunca se recalcula en cada build.
class CategoryIconRegistry {
  CategoryIconRegistry._();

  /// Catálogo completo, agrupado y ordenado.
  ///
  /// Es una lista estática evaluada una sola vez: el catálogo no se reconstruye
  /// en cada build ni en cada búsqueda.
  static final List<CategoryIconOption> icons = <CategoryIconOption>[
    // ---------------------------------------------------------------- COMIDA
    CategoryIconOption(Icons.restaurant, 'restaurant', [
      'comida',
      'food',
      'eat',
      'dining',
      'nourriture',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.fastfood, 'fastfood', [
      'rapida',
      'burger',
      'fast',
      'hamburguesa',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.local_pizza, 'pizza', [
      'pizza',
      'italiana',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.local_bar, 'bar', [
      'bar',
      'cocktail',
      'trago',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.local_cafe, 'cafe', [
      'cafe',
      'coffee',
      'cafeteria',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.bakery_dining, 'bakery', [
      'pan',
      'bread',
      'panaderia',
      'bakery',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.lunch_dining, 'lunch', [
      'almuerzo',
      'lunch',
      'plato',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.dinner_dining, 'dinner', [
      'cena',
      'dinner',
      'plato',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.brunch_dining, 'brunch', [
      'brunch',
      'desayuno',
      'breakfast',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.coffee, 'coffee', [
      'cafe',
      'infusion',
      'tea',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.icecream, 'icecream', [
      'helado',
      'ice',
      'postre',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.cake, 'cake', [
      'pastel',
      'torta',
      'cumpleaños',
      'cake',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.ramen_dining, 'ramen', [
      'sopa',
      'ramen',
      'fideos',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.rice_bowl, 'rice', [
      'arroz',
      'rice',
      'tazon',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.outdoor_grill, 'grill', [
      'parrilla',
      'asado',
      'grill',
      'bbq',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.kebab_dining, 'kebab', [
      'kebab',
      'carne',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.tapas, 'tapas', [
      'tapas',
      'aperitivo',
      'snack',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.egg, 'egg', [
      'huevo',
      'huevos',
      'egg',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.egg_alt, 'eggs', [
      'huevos',
      'desayuno',
      'egg',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.set_meal, 'setmeal', [
      'comida',
      'bandeja',
      'menu',
      'meal',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.liquor, 'liquor', [
      'licor',
      'bebida',
      'bottle',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.wine_bar, 'wine', [
      'vino',
      'wine',
      'barra',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.local_drink, 'drink', [
      'bebida',
      'refresco',
      'soda',
    ], CategoryIconGroups.food),
    CategoryIconOption(Icons.soup_kitchen, 'soup', [
      'sopa',
      'caldo',
      'soup',
    ], CategoryIconGroups.food),
    // ------------------------------------------------------------ TRANSPORTE
    CategoryIconOption(Icons.directions_car, 'car', [
      'coche',
      'auto',
      'carro',
      'vehiculo',
      'car',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.directions_bus, 'bus', [
      'guagua',
      'omnibus',
      'autobus',
      'bus',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.directions_bike, 'bike', [
      'bicicleta',
      'bici',
      'bike',
      'bicycle',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.directions_boat, 'boat', [
      'barco',
      'lancha',
      'yate',
      'boat',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.directions_walk, 'walk', [
      'caminar',
      'a pie',
      'walk',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.directions_subway, 'subway', [
      'metro',
      'tren',
      'subway',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.directions_train, 'train', [
      'tren',
      'rail',
      'train',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.local_taxi, 'taxi', [
      'taxi',
      'almendron',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.local_gas_station, 'gas', [
      'gasolina',
      'combustible',
      'gas station',
      'essence',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.car_repair, 'carrepair', [
      'taller',
      'mecanico',
      'reparacion',
      'repair',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.two_wheeler, 'moto', [
      'moto',
      'motocicleta',
      'motorcycle',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.airport_shuttle, 'shuttle', [
      'van',
      'lanzadera',
      'shuttle',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.flight, 'flight', [
      'vuelo',
      'avion',
      'avion',
      'plane',
      'vol',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.flight_takeoff, 'takeoff', [
      'despegue',
      'vuelo',
      'takeoff',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.flight_land, 'landing', [
      'aterrizaje',
      'vuelo',
      'landing',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.local_shipping, 'shipping', [
      'envio',
      'camion',
      'paquete',
      'shipping',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.rv_hookup, 'rv', [
      'caravana',
      'camper',
      'rv',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.no_transfer, 'notransfer', [
      'sin transferencia',
      'parada',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.electric_car, 'ecar', [
      'coche electrico',
      'ev',
      'tesla',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.electric_moped, 'moped', [
      'moto electrica',
      'scooter',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.electric_scooter, 'escooter', [
      'patinete',
      'scooter',
    ], CategoryIconGroups.transport),
    CategoryIconOption(Icons.electric_bike, 'ebike', [
      'bici electrica',
      'ebike',
    ], CategoryIconGroups.transport),
    // ------------------------------------------------------------------ HOGAR
    CategoryIconOption(Icons.home, 'home', [
      'casa',
      'hogar',
      'vivienda',
      'house',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.home_work, 'homework', [
      'casa trabajo',
      'edificio',
      'apartamento',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.chair, 'chair', [
      'silla',
      'mueble',
      'chair',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.bed, 'bed', [
      'cama',
      'dormitorio',
      'cama',
      'bed',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.kitchen, 'kitchen', [
      'cocina',
      'nevera',
      'kitchen',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.local_laundry_service, 'laundry', [
      'lavanderia',
      'lavadora',
      'laundry',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.weekend, 'sofa', [
      'sofa',
      'salon',
      'living',
      'couch',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.table_restaurant, 'table', [
      'mesa',
      'comedor',
      'table',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.door_front_door, 'door', [
      'puerta',
      'entrada',
      'door',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.balcony, 'balcony', [
      'balcon',
      'terraza',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.house_siding, 'siding', [
      'revestimiento',
      'fachada',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.roofing, 'roof', [
      'techo',
      'roof',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.yard, 'yard', [
      'jardin',
      'patio',
      'yard',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.deck, 'deck', [
      'terraza',
      'deck',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.cottage, 'cottage', [
      'casita',
      'cottage',
      'casa de campo',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.cabin, 'cabin', [
      'cabaña',
      'cabin',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.villa, 'villa', [
      'villa',
      'casa lujo',
    ], CategoryIconGroups.home),
    CategoryIconOption(Icons.apartment, 'apartment', [
      'apartamento',
      'edificio',
      'apartment',
    ], CategoryIconGroups.home),
    // ---------------------------------------------------------------- COMPRAS
    CategoryIconOption(Icons.local_mall, 'mall', [
      'centro comercial',
      'tienda',
      'mall',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.shopping_cart, 'cart', [
      'carrito',
      'compras',
      'cart',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.shopping_bag, 'bag', [
      'bolsa',
      'tienda',
      'shopping',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.shopping_basket, 'basket', [
      'cesta',
      'market',
      'basket',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.store, 'store', [
      'tienda',
      'local',
      'store',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.storefront, 'storefront', [
      'tienda',
      'fachada',
      'local',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.point_of_sale, 'pos', [
      'caja',
      'punto de venta',
      'pos',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.sell, 'sell', [
      'venta',
      'oferta',
      'sell',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.shopping_cart_checkout, 'cartcheckout', [
      'pagar',
      'carrito',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.receipt_long, 'receiptlong', [
      'factura',
      'recibo',
      'ticket',
      'receipt',
    ], CategoryIconGroups.shopping),
    CategoryIconOption(Icons.receipt, 'receipt', [
      'recibo',
      'ticket',
      'factura',
    ], CategoryIconGroups.shopping),
    // ------------------------------------------------------------------ SALUD
    CategoryIconOption(Icons.local_hospital, 'hospital', [
      'hospital',
      'clinica',
      'salud',
      'medical',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.favorite, 'heart', [
      'corazon',
      'salud',
      'favorito',
      'heart',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.favorite_border, 'heartborder', [
      'corazon',
      'salud',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.healing, 'healing', [
      'curacion',
      'sanacion',
      'healing',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.medication, 'medication', [
      'medicina',
      'pastillas',
      'farmacia',
      'medication',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.medical_services, 'medical', [
      'medico',
      'salud',
      'medical',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.monitor_heart, 'monitorheart', [
      'corazon',
      'monitor',
      'cardio',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.bloodtype, 'blood', [
      'sangre',
      'donacion',
      'blood',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.vaccines, 'vaccine', [
      'vacuna',
      'vacunas',
      'vaccine',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.coronavirus, 'mask', [
      'mascarilla',
      'tapaboca',
      'mask',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.health_and_safety, 'healthsafety', [
      'seguro medico',
      'salud',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.psychology, 'psychology', [
      'psicologia',
      'salud mental',
      'mente',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.self_improvement, 'wellness', [
      'bienestar',
      'meditacion',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.spa, 'spa', [
      'spa',
      'relax',
      'belleza',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.sanitizer, 'sanitizer', [
      'desinfectante',
      'higiene',
    ], CategoryIconGroups.health),
    CategoryIconOption(Icons.volunteer_activism, 'volunteer', [
      'voluntariado',
      'ayuda',
    ], CategoryIconGroups.health),
    // --------------------------------------------------------------- EDUCACION
    CategoryIconOption(Icons.school, 'school', [
      'escuela',
      'colegio',
      'estudio',
      'school',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.local_library, 'library', [
      'biblioteca',
      'libros',
      'library',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.menu_book, 'menubook', [
      'libro',
      'lectura',
      'book',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.book, 'book', [
      'libro',
      'lectura',
      'book',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.auto_stories, 'ebook', [
      'libro',
      'historia',
      'ebook',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.history_edu, 'history', [
      'historia',
      'clases',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.science, 'science', [
      'ciencia',
      'laboratorio',
      'science',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.biotech, 'biotech', [
      'biologia',
      'laboratorio',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.computer, 'computer', [
      'informatica',
      'computadora',
      'pc',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.calculate, 'calculate', [
      'matematicas',
      'calculadora',
      'calcular',
      'calculatrice',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.quiz, 'quiz', [
      'examen',
      'preguntas',
      'quiz',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.fact_check, 'factcheck', [
      'verificar',
      'datos',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.translate, 'translate', [
      'idioma',
      'traducir',
      'translate',
    ], CategoryIconGroups.education),
    CategoryIconOption(Icons.import_contacts, 'contactsbook', [
      'libreta',
      'agenda',
    ], CategoryIconGroups.education),
    // ---------------------------------------------------------- ENTRETENIMIENTO
    CategoryIconOption(Icons.movie, 'movie', [
      'cine',
      'pelicula',
      'movie',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.theater_comedy, 'theater', [
      'teatro',
      'comedia',
      'theater',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.sports_esports, 'gaming', [
      'videojuegos',
      'gaming',
      'juegos',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.casino, 'casino', [
      'casino',
      'apuestas',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.local_activity, 'ticket', [
      'ticket',
      'entradas',
      'eventos',
      'ticket',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.ondemand_video, 'streaming', [
      'streaming',
      'video',
      'netflix',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.subscriptions, 'subscriptions', [
      'suscripcion',
      'suscripciones',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.music_note, 'music', [
      'musica',
      'nota',
      'music',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.library_music, 'musicalbum', [
      'musica',
      'album',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.headphones, 'headphones', [
      'audifonos',
      'musica',
      'headphones',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.smart_display, 'smarttv', [
      'tv',
      'pantalla',
      'smart',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.video_library, 'videos', [
      'videos',
      'videoteca',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.live_tv, 'livetv', [
      'tv',
      'television',
      'en vivo',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.celebration, 'celebration', [
      'fiesta',
      'celebracion',
      'celebrar',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.palette, 'art', [
      'arte',
      'pintura',
      'paleta',
      'art',
    ], CategoryIconGroups.entertainment),
    CategoryIconOption(Icons.extension, 'puzzle', [
      'rompecabezas',
      'juego',
      'puzzle',
    ], CategoryIconGroups.entertainment),
    // ---------------------------------------------------------------- DEPORTES
    CategoryIconOption(Icons.fitness_center, 'gym', [
      'gimnasio',
      'pesas',
      'ejercicio',
      'fitness',
      'sport',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_soccer, 'soccer', [
      'futbol',
      'soccer',
      'football',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_basketball, 'basketball', [
      'baloncesto',
      'basquet',
      'basket',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_baseball, 'baseball', [
      'beisbol',
      'baseball',
      'pelota',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_tennis, 'tennis', [
      'tenis',
      'raqueta',
      'tennis',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_volleyball, 'volleyball', [
      'voleibol',
      'voley',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_hockey, 'hockey', [
      'hockey',
      'polo',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_golf, 'golf', [
      'golf',
      'campo',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_motorsports, 'motorsport', [
      'motociclismo',
      'carreras',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.sports_martial_arts, 'martial', [
      'artes marciales',
      'karate',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.hiking, 'hiking', [
      'senderismo',
      'montaña',
      'hiking',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.kayaking, 'kayak', [
      'kayak',
      'remo',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.surfing, 'surf', [
      'surf',
      'olas',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.pool, 'swim', [
      'natacion',
      'nadar',
      'piscina',
      'swimming',
    ], CategoryIconGroups.sports),
    CategoryIconOption(Icons.emoji_events, 'trophy', [
      'trofeo',
      'premio',
      'trophy',
    ], CategoryIconGroups.sports),
    // ------------------------------------------------------------- TECNOLOGIA
    CategoryIconOption(Icons.devices, 'devices', [
      'dispositivos',
      'tecnologia',
      'devices',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.laptop, 'laptop', [
      'portatil',
      'laptop',
      'computadora',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.desktop_windows, 'desktop', [
      'computadora',
      'escritorio',
      'desktop',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.smartphone, 'smartphone', [
      'movil',
      'telefono',
      'celular',
      'smartphone',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.tablet, 'tablet', [
      'tableta',
      'tablet',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.watch, 'watch', [
      'reloj',
      'smartwatch',
      'watch',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.speaker, 'speakers', [
      'parlantes',
      'bocinas',
      'audio',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.tv, 'tv', [
      'television',
      'tv',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.camera_alt, 'camera', [
      'camara',
      'fotos',
      'camera',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.memory, 'memory', [
      'memoria',
      'ram',
      'chip',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.sd_card, 'sdcard', [
      'tarjeta sd',
      'almacenamiento',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.router, 'router', [
      'router',
      'wifi',
      'internet',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.keyboard, 'keyboard', [
      'teclado',
      'keyboard',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.mouse, 'mouse', [
      'raton',
      'mouse',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.print, 'printer', [
      'impresora',
      'print',
      'imprimir',
    ], CategoryIconGroups.tech),
    CategoryIconOption(Icons.developer_board, 'devboard', [
      'placa',
      'circuito',
      'arduino',
    ], CategoryIconGroups.tech),
    // ------------------------------------------------------------------ TRABAJO
    CategoryIconOption(Icons.business_center, 'work', [
      'trabajo',
      'oficina',
      'empleo',
      'work',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.badge, 'badge', [
      'identificacion',
      'empleado',
      'badge',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.assignment, 'assignment', [
      'tarea',
      'asignacion',
      'proyecto',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.description, 'description', [
      'documento',
      'informe',
      'descripcion',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.insert_drive_file, 'file', [
      'archivo',
      'documento',
      'file',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.folder, 'folder', [
      'carpeta',
      'folder',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.folder_open, 'folderopen', [
      'carpeta abierta',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.handshake, 'handshake', [
      'acuerdo',
      'apreton de manos',
      'negocio',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.engineering, 'engineering', [
      'ingenieria',
      'tecnico',
      'engineering',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.architecture, 'architecture', [
      'arquitectura',
      'diseño',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.task_alt, 'task', [
      'tarea completada',
      'check',
      'listo',
    ], CategoryIconGroups.work),
    CategoryIconOption(Icons.work_history, 'workhistory', [
      'historial laboral',
      'trabajo',
    ], CategoryIconGroups.work),
    // ---------------------------------------------------------------- NEGOCIOS
    CategoryIconOption(Icons.business, 'business', [
      'empresa',
      'negocio',
      'compania',
      'business',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.corporate_fare, 'corporate', [
      'corporativo',
      'empresa',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.domain, 'domain', [
      'dominio',
      'oficina',
      'sede',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.factory, 'factory', [
      'fabrica',
      'planta',
      'industry',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.warehouse, 'warehouse', [
      'almacen',
      'deposito',
      'bodega',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.campaign, 'campaign', [
      'campaña',
      'publicidad',
      'marketing',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.rocket_launch, 'startup', [
      'startup',
      'lanzamiento',
      'emisor',
    ], CategoryIconGroups.business),
    CategoryIconOption(Icons.groups, 'groups', [
      'equipo',
      'grupo',
      'personas',
    ], CategoryIconGroups.business),
    // ------------------------------------------------------------------ DINERO
    CategoryIconOption(Icons.attach_money, 'cash', [
      'efectivo',
      'dinero',
      'cash',
      'argent',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.payments, 'payments', [
      'pagos',
      'pagar',
      'dinero',
      'payments',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.currency_exchange, 'exchange', [
      'cambio',
      'divisa',
      'tipo de cambio',
      'exchange',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.monetization_on, 'coins', [
      'monedas',
      'coin',
      'dinero',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.price_change, 'pricechange', [
      'precio',
      'cambio',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.price_check, 'pricecheck', [
      'precio',
      'verificar',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.credit_score, 'creditscore', [
      'credito',
      'puntaje',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.account_balance_wallet, 'wallet', [
      'billetera',
      'cartera',
      'monedero',
      'wallet',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.money, 'money', [
      'dinero',
      'billetes',
      'money',
    ], CategoryIconGroups.money),
    CategoryIconOption(Icons.paid, 'paid', [
      'pagado',
      'pago',
      'dinero',
    ], CategoryIconGroups.money),
    // ------------------------------------------------------------------- BANCA
    CategoryIconOption(Icons.account_balance, 'bank', [
      'banco',
      'banco',
      'institucion',
      'bank',
    ], CategoryIconGroups.bank),
    CategoryIconOption(Icons.savings, 'savings', [
      'ahorros',
      'ahorrar',
      'alcancia',
      'savings',
    ], CategoryIconGroups.bank),
    CategoryIconOption(Icons.local_atm, 'atm', [
      'cajero',
      'atm',
      'efectivo',
    ], CategoryIconGroups.bank),
    CategoryIconOption(Icons.card_travel, 'cardtravel', [
      'tarjeta',
      'viajes',
      'credito',
    ], CategoryIconGroups.bank),
    // ---------------------------------------------------------------- INGRESOS
    CategoryIconOption(Icons.euro, 'euro', [
      'euro',
      'europa',
      'divisa',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.request_quote, 'quote', [
      'cotizacion',
      'presupuesto',
      'quote',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.trending_up, 'trendingup', [
      'subida',
      'crecimiento',
      'ganancia',
      'ingresos',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.trending_down, 'trendingdown', [
      'bajada',
      'perdida',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.show_chart, 'chart', [
      'grafico',
      'estadistica',
      'chart',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.analytics, 'analytics', [
      'analisis',
      'estadisticas',
      'analytics',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.insights, 'insights', [
      'percepcion',
      'insights',
      'ideas',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.leaderboard, 'leaderboard', [
      'ranking',
      'tabla',
      'clasificacion',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.donut_large, 'donut', [
      'grafico',
      'dona',
      'resumen',
    ], CategoryIconGroups.income),
    CategoryIconOption(Icons.pie_chart, 'pie', [
      'grafico',
      'torta',
      'pie',
    ], CategoryIconGroups.income),
    // ---------------------------------------------------------------- PAGOS
    CategoryIconOption(Icons.payment, 'payment', [
      'pago',
      'tarjeta',
      'payment',
    ], CategoryIconGroups.payments),
    CategoryIconOption(Icons.credit_card, 'creditcard', [
      'tarjeta de credito',
      'credito',
      'card',
    ], CategoryIconGroups.payments),
    CategoryIconOption(Icons.swap_horiz, 'swaphoriz', [
      'transferencia',
      'intercambio',
    ], CategoryIconGroups.payments),
    CategoryIconOption(Icons.swap_vert, 'swapvert', [
      'transferencia',
      'intercambio',
    ], CategoryIconGroups.payments),
    CategoryIconOption(Icons.send, 'send', [
      'enviar',
      'transferencia',
      'send',
    ], CategoryIconGroups.payments),
    CategoryIconOption(Icons.call_made, 'made', [
      'saliente',
      'transferencia',
    ], CategoryIconGroups.payments),
    CategoryIconOption(Icons.cached, 'cached', [
      'recargar',
      'actualizar',
      'ciclo',
    ], CategoryIconGroups.payments),
    // ------------------------------------------------------------------ VIAJES
    CategoryIconOption(Icons.luggage, 'luggage', [
      'equipaje',
      'maleta',
      'viaje',
      'baggage',
    ], CategoryIconGroups.travel),
    CategoryIconOption(Icons.beach_access, 'beach', [
      'playa',
      'vacaciones',
      'beach',
    ], CategoryIconGroups.travel),
    CategoryIconOption(Icons.landscape, 'landscape', [
      'paisaje',
      'naturaleza',
      'vistas',
    ], CategoryIconGroups.travel),
    CategoryIconOption(Icons.photo_camera, 'photo', [
      'fotos',
      'camara',
      'turismo',
    ], CategoryIconGroups.travel),
    CategoryIconOption(Icons.maps_home_work, 'mapshome', [
      'mapa',
      'ubicacion',
    ], CategoryIconGroups.travel),
    CategoryIconOption(Icons.add_location_alt, 'location', [
      'ubicacion',
      'lugar',
      'mapa',
    ], CategoryIconGroups.travel),
    CategoryIconOption(Icons.explore, 'explore', [
      'explorar',
      'aventura',
      'brújula',
    ], CategoryIconGroups.travel),
    // ------------------------------------------------------------------ FAMILIA
    CategoryIconOption(Icons.family_restroom, 'family', [
      'familia',
      'ninos',
      'family',
    ], CategoryIconGroups.family),
    CategoryIconOption(Icons.child_friendly, 'child', [
      'nino',
      'infantil',
      'bebe',
      'child',
    ], CategoryIconGroups.family),
    CategoryIconOption(Icons.child_care, 'nursery', [
      'guarderia',
      'bebe',
      'cuna',
    ], CategoryIconGroups.family),
    CategoryIconOption(Icons.wc, 'wc', [
      'banos',
      'wc',
    ], CategoryIconGroups.family),
    CategoryIconOption(Icons.meeting_room, 'room', [
      'habitacion',
      'salon',
    ], CategoryIconGroups.family),
    CategoryIconOption(Icons.emoji_people, 'people', [
      'personas',
      'familia',
    ], CategoryIconGroups.family),
    // ---------------------------------------------------------------- PERSONAS
    CategoryIconOption(Icons.person, 'person', [
      'persona',
      'usuario',
      'individual',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.people, 'people2', [
      'personas',
      'grupo',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.person_add, 'personadd', [
      'agregar persona',
      'invitar',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.person_outline, 'personoutline', [
      'persona',
      'silueta',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.group_add, 'groupadd', [
      'agregar grupo',
      'invitar',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.person_search, 'persons', [
      'buscar persona',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.supervised_user_circle, 'supervised', [
      'administrar',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.admin_panel_settings, 'admin', [
      'administrador',
      'admin',
    ], CategoryIconGroups.people),
    CategoryIconOption(Icons.accessibility, 'accessibility', [
      'accesibilidad',
      'persona',
    ], CategoryIconGroups.people),
    // ---------------------------------------------------------------- MASCOTAS
    CategoryIconOption(Icons.pets, 'pets', [
      'mascota',
      'perro',
      'gato',
      'animal',
      'pets',
    ], CategoryIconGroups.pets),
    // ------------------------------------------------------------------- ROPA
    CategoryIconOption(Icons.checkroom, 'clothing', [
      'ropa',
      'vestuario',
      'clothes',
    ], CategoryIconGroups.clothing),
    CategoryIconOption(Icons.dry_cleaning, 'drycleaning', [
      'tintoreria',
      'limpieza',
    ], CategoryIconGroups.clothing),
    CategoryIconOption(Icons.wash, 'laundry2', [
      'lavanderia',
      'ropa',
    ], CategoryIconGroups.clothing),
    // ---------------------------------------------------------------- SERVICIOS
    CategoryIconOption(Icons.home_repair_service, 'repair', [
      'reparacion',
      'mantenimiento',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.handyman, 'handyman', [
      'manitas',
      'reparaciones',
      'handyman',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.electrical_services, 'electric', [
      'electricidad',
      'luz',
      'electric',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.plumbing, 'plumbing', [
      'plomeria',
      'grifo',
      'tuberias',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.cleaning_services, 'cleaning', [
      'limpieza',
      'aseo',
      'cleaning',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.water_drop, 'water', [
      'agua',
      'gota',
      'water',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.gas_meter, 'gasmeter', [
      'gas',
      'gasolina',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.solar_power, 'solar', [
      'solar',
      'energia solar',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.wind_power, 'wind', [
      'viento',
      'energia eolica',
    ], CategoryIconGroups.services),
    CategoryIconOption(Icons.oil_barrel, 'oil', [
      'aceite',
      'petroleo',
    ], CategoryIconGroups.services),
    // ----------------------------------------------------------- COMUNICACION
    CategoryIconOption(Icons.phone, 'phone', [
      'telefono',
      'llamada',
      'phone',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.call, 'call', [
      'llamada',
      'telefono',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.chat, 'chat', [
      'chat',
      'mensaje',
      'conversacion',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.sms, 'sms', [
      'sms',
      'mensaje',
      'texto',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.email, 'email', [
      'correo',
      'email',
      'mail',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.forum, 'forum', [
      'foro',
      'discusion',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.contact_phone, 'contactphone', [
      'contacto',
      'telefono',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.notifications, 'notifications', [
      'notificacion',
      'alerta',
    ], CategoryIconGroups.communication),
    CategoryIconOption(Icons.notifications_active, 'notificationsactive', [
      'notificaciones',
      'alerta',
    ], CategoryIconGroups.communication),
    // ---------------------------------------------------------------- SEGURIDAD
    CategoryIconOption(Icons.lock, 'lock', [
      'candado',
      'seguridad',
      'bloqueo',
      'lock',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.lock_open, 'lockopen', [
      'candado abierto',
      'desbloqueado',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.security, 'security', [
      'seguridad',
      'proteccion',
      'security',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.verified_user, 'verified', [
      'verificado',
      'confianza',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.fingerprint, 'fingerprint', [
      'huella',
      'biometria',
      'fingerprint',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.shield, 'shield', [
      'escudo',
      'proteccion',
      'shield',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.vpn_key, 'key', [
      'llave',
      'clave',
      'acceso',
    ], CategoryIconGroups.security),
    CategoryIconOption(Icons.gpp_good, 'gpp', [
      'proteccion',
      'seguro',
    ], CategoryIconGroups.security),
    // ---------------------------------------------------------------- HERRAMIENTAS
    CategoryIconOption(Icons.build, 'tools', [
      'herramientas',
      'reparar',
      'build',
      'outils',
    ], CategoryIconGroups.tools),
    CategoryIconOption(Icons.construction, 'construction', [
      'construccion',
      'obra',
      'construction',
    ], CategoryIconGroups.tools),
    CategoryIconOption(Icons.settings, 'settings', [
      'ajustes',
      'configuracion',
      'settings',
    ], CategoryIconGroups.tools),
    CategoryIconOption(Icons.tune, 'tune', [
      'ajustar',
      'control',
    ], CategoryIconGroups.tools),
    CategoryIconOption(Icons.content_cut, 'cut', [
      'cortar',
      'tijeras',
    ], CategoryIconGroups.tools),
    CategoryIconOption(Icons.design_services, 'design', [
      'diseño',
      'pantalla',
    ], CategoryIconGroups.tools),
    CategoryIconOption(Icons.precision_manufacturing, 'precision', [
      'precisión',
      'maquina',
    ], CategoryIconGroups.tools),
    // ------------------------------------------------------------------- TIEMPO
    CategoryIconOption(Icons.schedule, 'time', [
      'hora',
      'reloj',
      'tiempo',
      'time',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.alarm, 'alarm', [
      'alarma',
      'despertador',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.alarm_on, 'alarmon', [
      'alarma',
      'activa',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.timer, 'timer', [
      'cronometro',
      'temporizador',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.hourglass_empty, 'hourglass', [
      'reloj de arena',
      'espera',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.event, 'event', [
      'evento',
      'fecha',
      'calendario',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.calendar_today, 'calendar', [
      'calendario',
      'fecha',
      'hoy',
    ], CategoryIconGroups.time),
    CategoryIconOption(Icons.calendar_month, 'calendarmonth', [
      'calendario',
      'mes',
    ], CategoryIconGroups.time),
    // ---------------------------------------------------------------- NATURALEZA
    CategoryIconOption(Icons.park, 'park', [
      'parque',
      'arboles',
      'naturaleza',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.eco, 'eco', [
      'ecologia',
      'hoja',
      'eco',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.forest, 'forest', [
      'bosque',
      'arboles',
      'forest',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.local_florist, 'florist', [
      'flores',
      'floreria',
      'flor',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.waves, 'waves', [
      'olas',
      'mar',
      'agua',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.water, 'water2', [
      'agua',
      'recurso',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.agriculture, 'agriculture', [
      'agricultura',
      'campo',
      'cosecha',
    ], CategoryIconGroups.nature),
    CategoryIconOption(Icons.grass, 'grass', [
      'hierba',
      'jardin',
      'cesped',
    ], CategoryIconGroups.nature),
    // ------------------------------------------------------------------- OTROS
    CategoryIconOption(Icons.help_outline, 'other', [
      'otro',
      'otros',
      'misc',
      'help',
      'autre',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.more_horiz, 'more', [
      'mas',
      'extra',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.apps, 'apps', [
      'aplicaciones',
      'cuadricula',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.star, 'star', [
      'estrella',
      'favorito',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.bookmark, 'bookmark', [
      'marcador',
      'guardar',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.label, 'label', [
      'etiqueta',
      'categoria',
      'label',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.category, 'category', [
      'categoria',
      'clasificar',
      'category',
    ], CategoryIconGroups.other),
    CategoryIconOption(Icons.dashboard, 'dashboard', [
      'panel',
      'tablero',
    ], CategoryIconGroups.other),
  ];

  /// Mapa codePoint → icono del catálogo (para resolución O(1)).
  static final Map<int, CategoryIconOption> _byCodePoint =
      <int, CategoryIconOption>{
        for (final CategoryIconOption option in icons) option.codePoint: option,
      };

  /// Alias de los catálogos legados al catálogo moderno.
  ///
  /// Se mantienen intactos para que todo icono guardado por usuarios antiguos
  /// siga renderizándose. Los códigos históricos que no existen en el catálogo
  /// actual (por ejemplo los de algunas categorías por defecto antiguas) se
  /// resuelven al mismo fallback [Icons.help_outline] de siempre.
  static const Map<int, IconData> _legacyAliases = <int, IconData>{
    0xe532: Icons.restaurant,
    0xe25a: Icons.fastfood,
    0xe3a0: Icons.local_pizza,
    0xe38c: Icons.local_bar,
    0xe38d: Icons.local_cafe,
    0xe1d7: Icons.directions_car,
    0xe1d5: Icons.directions_bus,
    0xe394: Icons.local_gas_station,
    0xe180: Icons.commute,
    0xe318: Icons.home,
    0xe40d: Icons.movie,
    0xe5e8: Icons.sports_esports,
    0xe39a: Icons.local_mall,
    0xe59c: Icons.shopping_cart,
    0xe59a: Icons.shopping_bag,
    0xe25b: Icons.favorite,
    0xe396: Icons.local_hospital,
    0xe28d: Icons.fitness_center,
    0xe15d: Icons.checkroom,
    0xe14d: Icons.chair,
    0xe37b: Icons.lightbulb,
    0xe559: Icons.school,
    0xe399: Icons.local_library,
    0xe4a3: Icons.phone,
    0xe11c: Icons.business_center,
    0xe3ae: Icons.lock,
    0xe31d: Icons.home_work,
    0xe116: Icons.build,
    0xe4a1: Icons.pets,
    0xe297: Icons.flight,
    0xe8fd: Icons.help_outline,
  };

  /// Número exacto de iconos del catálogo (>= 200 por diseño).
  static int get count => icons.length;

  /// Iconos de un grupo concreto.
  static List<CategoryIconOption> byGroup(String group) =>
      icons.where((option) => option.group == group).toList(growable: false);

  /// Búsqueda por nombre, keywords o grupo. No toca el catálogo: sólo filtra.
  static List<CategoryIconOption> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return icons;
    return icons
        .where(
          (option) =>
              option.name.toLowerCase().contains(q) ||
              option.group.toLowerCase().contains(q) ||
              option.keywords.any((k) => k.toLowerCase().contains(q)),
        )
        .toList(growable: false);
  }

  /// Resuelve el icono de un `iconCode` guardado.
  ///
  /// Mantiene compatibilidad con los catálogos antiguos y termina en un
  /// fallback seguro; nunca lanza.
  static IconData resolve(int codePoint) {
    final CategoryIconOption? match = _byCodePoint[codePoint];
    if (match != null) return match.icon;
    final IconData? legacy = _legacyAliases[codePoint];
    return legacy ?? Icons.help_outline;
  }
}
