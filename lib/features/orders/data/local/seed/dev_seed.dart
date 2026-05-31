import 'package:comand_ia/core/logger.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/repositories/menu_local_repository.dart';
import 'package:comand_ia/features/orders/data/local/app_database.dart';
import 'package:comand_ia/features/orders/data/local/mappers.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// venueId del usuario mock definido en [MockAuthRepository].
/// Mantener sincronizado si cambia el mock.
const String kMockVenueId = 'venue-001-mock';

const _uuid = Uuid();

/// Siembra datos de desarrollo en la base local si el venue aún no tiene datos.
///
/// Idempotente: si ya existen categorías para [kMockVenueId] no hace nada.
/// Se llama desde el provider de inicialización al arrancar la app.
///
/// Siembra:
/// - 20 mesas (`dining_table`) con ids `"1"`.."20"` para calzar con el grid mock.
/// - 6 categorías de menú (Entradas, Almuerzos, Parrilladas, Bebidas, Postres, Café).
/// - Ítems con precios en centavos (CLP × 100). Sin floats.
Future<void> seedDevData(AppDatabase db, MenuLocalRepository menuRepo) async {
  // ─── Idempotencia ──────────────────────────────────────────────────────────
  final existing = await menuRepo.categories(kMockVenueId);
  if (existing.isNotEmpty) {
    AppLogger.info(
      'Dev seed: ya existe menú para $kMockVenueId; saltando.',
      tag: 'DevSeed',
    );
    return;
  }

  AppLogger.info(
    'Dev seed: sembrando datos de dev para venue $kMockVenueId…',
    tag: 'DevSeed',
  );

  // ─── Mesas ─────────────────────────────────────────────────────────────────
  // IDs "1".."20" para calzar con los ids que usa el grid mock.
  await db.batch((batch) {
    for (var i = 1; i <= 20; i++) {
      batch.insertAll(db.diningTables, [
        diningTableToCompanion(
          DiningTable(
            id: '$i',
            venueId: kMockVenueId,
            label: 'Mesa $i',
            capacity: 4,
            sortOrder: i,
          ),
        ),
      ], mode: InsertMode.insertOrIgnore);
    }
  });

  // ─── Categorías ────────────────────────────────────────────────────────────
  final categories = <MenuCategory>[
    MenuCategory(
      id: _uuid.v4(),
      venueId: kMockVenueId,
      name: 'Entradas',
      sortOrder: 1,
    ),
    MenuCategory(
      id: _uuid.v4(),
      venueId: kMockVenueId,
      name: 'Almuerzos',
      sortOrder: 2,
    ),
    MenuCategory(
      id: _uuid.v4(),
      venueId: kMockVenueId,
      name: 'Parrilladas',
      sortOrder: 3,
    ),
    MenuCategory(
      id: _uuid.v4(),
      venueId: kMockVenueId,
      name: 'Bebidas',
      sortOrder: 4,
    ),
    MenuCategory(
      id: _uuid.v4(),
      venueId: kMockVenueId,
      name: 'Postres',
      sortOrder: 5,
    ),
    MenuCategory(
      id: _uuid.v4(),
      venueId: kMockVenueId,
      name: 'Café',
      sortOrder: 6,
    ),
  ];
  await menuRepo.cacheCategories(categories);

  final catByName = {for (final c in categories) c.name: c};

  // ─── Ítems de menú ─────────────────────────────────────────────────────────
  // Precios en centavos (CLP × 100). Sin floats.
  // Ej. $4.500 CLP → priceCents = 450000
  final items = <MenuItem>[
    // Entradas
    _item(
      catByName['Entradas']!,
      'Ceviche de Reineta',
      'Con limón, cilantro y cebolla morada.',
      450000,
      1,
    ),
    _item(
      catByName['Entradas']!,
      'Empanada de Pino',
      'Empanada frita con pino de vacuno.',
      280000,
      2,
    ),
    _item(
      catByName['Entradas']!,
      'Humita al Vapor',
      'Humita casera envuelta en chala.',
      320000,
      3,
    ),
    _item(
      catByName['Entradas']!,
      'Pan de Queso',
      'Brocheta de pan con queso gratinado.',
      250000,
      4,
    ),

    // Almuerzos
    _item(
      catByName['Almuerzos']!,
      'Hamburguesa Clásica',
      'Carne de res, lechuga, tomate, cebolla y queso cheddar.',
      1500000,
      1,
    ),
    _item(
      catByName['Almuerzos']!,
      'Lomo a lo Pobre',
      'Lomo saltado con huevo frito, papas fritas y cebolla.',
      1200000,
      2,
    ),
    _item(
      catByName['Almuerzos']!,
      'Cazuela de Vacuno',
      'Caldo con trozos de vacuno, papas y choclo.',
      980000,
      3,
    ),
    _item(
      catByName['Almuerzos']!,
      'Ensalada Mixta',
      'Lechuga, tomate, pepino y palta con vinagreta.',
      650000,
      4,
    ),
    _item(
      catByName['Almuerzos']!,
      'Pollo al Merkén',
      'Pechuga a la plancha con aliño de merkén, arroz y ensalada.',
      1100000,
      5,
    ),

    // Parrilladas
    _item(
      catByName['Parrilladas']!,
      'Entraña 300 g',
      'Corte fino de entraña a las brasas.',
      2200000,
      1,
    ),
    _item(
      catByName['Parrilladas']!,
      'Asado de Tira 400 g',
      'Costillar de vacuno a las brasas, servido con papas al horno.',
      2800000,
      2,
    ),
    _item(
      catByName['Parrilladas']!,
      'Pollo a la Brasa',
      'Pollo entero al carbón con chimichurri.',
      1800000,
      3,
    ),
    _item(
      catByName['Parrilladas']!,
      'Chorizo Artesanal',
      'Chorizo de cerdo especiado, servido con pan y pebre.',
      950000,
      4,
    ),
    _item(
      catByName['Parrilladas']!,
      'Parrillada Mixta (2 personas)',
      '300 g entraña + chorizo + pollo + acompañamientos.',
      5500000,
      5,
    ),

    // Bebidas
    _item(
      catByName['Bebidas']!,
      'Agua Mineral 500 ml',
      'Con o sin gas.',
      150000,
      1,
    ),
    _item(
      catByName['Bebidas']!,
      'Bebida en Lata 350 ml',
      'Coca-Cola, Sprite o Fanta.',
      180000,
      2,
    ),
    _item(
      catByName['Bebidas']!,
      'Jugo de Naranja Natural',
      'Naranja exprimida al momento.',
      350000,
      3,
    ),
    _item(
      catByName['Bebidas']!,
      'Cerveza Artesanal 330 ml',
      'IPA o Rubia artesanal local.',
      420000,
      4,
    ),
    _item(
      catByName['Bebidas']!,
      'Copa de Vino Tinto',
      'Carménère reserva del valle.',
      500000,
      5,
    ),
    _item(
      catByName['Bebidas']!,
      'Limonada Natural',
      'Limón, agua, azúcar y menta.',
      290000,
      6,
    ),

    // Postres
    _item(
      catByName['Postres']!,
      'Leche Asada',
      'Postre tradicional chileno de leche y canela.',
      380000,
      1,
    ),
    _item(
      catByName['Postres']!,
      'Torta de Chocolate',
      'Brownie húmedo con salsa de chocolate caliente.',
      520000,
      2,
    ),
    _item(
      catByName['Postres']!,
      'Helado Artesanal (2 bochas)',
      'Lúcuma, manjar o vainilla.',
      450000,
      3,
    ),
    _item(
      catByName['Postres']!,
      'Fruta de Temporada',
      'Selección de frutas frescas con yogur.',
      350000,
      4,
    ),

    // Café
    _item(
      catByName['Café']!,
      'Espresso Simple',
      'Shot doble de espresso.',
      200000,
      1,
    ),
    _item(
      catByName['Café']!,
      'Café con Leche',
      'Espresso con leche vaporizada al gusto.',
      260000,
      2,
    ),
    _item(
      catByName['Café']!,
      'Cappuccino',
      'Espresso, leche vaporizada y espuma.',
      290000,
      3,
    ),
    _item(
      catByName['Café']!,
      'Té Selección',
      'Variedad de tés en saquito con azúcar.',
      220000,
      4,
    ),
    _item(
      catByName['Café']!,
      'Marraqueta con Mantequilla',
      'Pan fresco con mantequilla.',
      180000,
      5,
    ),
  ];

  await menuRepo.cacheItems(items);

  AppLogger.info(
    'Dev seed: ${categories.length} categorías, ${items.length} ítems, 20 mesas sembradas.',
    tag: 'DevSeed',
  );
}

/// Constructor helper para crear [MenuItem] del seed.
MenuItem _item(
  MenuCategory category,
  String name,
  String description,
  int priceCents,
  int sortOrder,
) {
  return MenuItem(
    id: _uuid.v4(),
    venueId: kMockVenueId,
    categoryId: category.id,
    name: name,
    description: description,
    priceCents: priceCents,
    sortOrder: sortOrder,
    // imageUrl: null — sin imágenes en dev seed
  );
}
