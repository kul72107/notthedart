const String catAssetsBaseUrl =
    String.fromEnvironment(
      'MEOWVERSE_CAT_ASSETS_BASE_URL',
      defaultValue: 'https://raw.githubusercontent.com/kul72107/offf/main/cat1',
    );

class CatCategory {
  const CatCategory({
    required this.id,
    required this.name,
    required this.zIndex,
  });

  final String id;
  final String name;
  final int zIndex;
}

const List<CatCategory> catCategories = [
  CatCategory(id: 'rightear', name: 'Sag Kulak', zIndex: 0),
  CatCategory(id: 'rightear1', name: 'Sag Kulak 1', zIndex: 0),
  CatCategory(id: 'rightear2', name: 'Sag Kulak 2', zIndex: 0),
  CatCategory(id: 'leftear', name: 'Sol Kulak', zIndex: 0),
  CatCategory(id: 'leftear1', name: 'Sol Kulak 1', zIndex: 0),
  CatCategory(id: 'leftear2', name: 'Sol Kulak 2', zIndex: 0),
  CatCategory(id: 'rightmustache', name: 'Sag Biyik', zIndex: 0),
  CatCategory(id: 'leftmustache', name: 'Sol Biyik', zIndex: 0),
  CatCategory(id: 'body', name: 'Vucut', zIndex: 1),
  CatCategory(id: 'accessories3', name: 'Aksesuar 3', zIndex: 2),
  CatCategory(id: 'facepaint', name: 'Yuz Boyasi', zIndex: 2),
  CatCategory(id: 'righteye', name: 'Sag Goz', zIndex: 20),
  CatCategory(id: 'lefteye', name: 'Sol Goz', zIndex: 20),
  CatCategory(id: 'iris', name: 'Goz Bebegi', zIndex: 19),
  CatCategory(id: 'eyes', name: 'Goz Detay', zIndex: 22),
  CatCategory(id: 'eyebrows', name: 'Kas', zIndex: 23),
  CatCategory(id: 'mouth', name: 'Agiz', zIndex: 30),
  CatCategory(id: 'mouth1', name: 'Agiz 1', zIndex: 31),
  CatCategory(id: 'blush', name: 'Allik', zIndex: 33),
  CatCategory(id: 'collar', name: 'Tasma', zIndex: 40),
  CatCategory(id: 'rightearring', name: 'Sag Kupe', zIndex: 13),
  CatCategory(id: 'leftearring', name: 'Sol Kupe', zIndex: 13),
  CatCategory(id: 'mask', name: 'Maske', zIndex: 50),
  CatCategory(id: 'mask1', name: 'Maske 1', zIndex: 51),
  CatCategory(id: 'mask2', name: 'Maske 2', zIndex: 52),
  CatCategory(id: 'hair', name: 'Sac', zIndex: 60),
  CatCategory(id: 'tophair', name: 'Ust Sac', zIndex: 61),
  CatCategory(id: 'hat', name: 'Sapka', zIndex: 70),
  CatCategory(id: 'righthand', name: 'Sag El', zIndex: 80),
  CatCategory(id: 'lefthand', name: 'Sol El', zIndex: 80),
  CatCategory(id: 'accessories', name: 'Aksesuar', zIndex: 90),
  CatCategory(id: 'accessories1', name: 'Aksesuar 1', zIndex: 91),
  CatCategory(id: 'accessories2', name: 'Aksesuar 2', zIndex: 92),
  CatCategory(id: 'effect', name: 'Efekt', zIndex: 100),
];

String catImageUrl({
  required String categoryId,
  required int number,
  required String color,
  required String extension,
}) {
  return '$catAssetsBaseUrl/$categoryId/$color/$number.$extension';
}

CatCategory? findCategory(String id) {
  for (final cat in catCategories) {
    if (cat.id == id) return cat;
  }
  return null;
}
