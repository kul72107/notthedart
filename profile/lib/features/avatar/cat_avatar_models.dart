import 'cat_avatar_constants.dart';

class CatAvatarPart {
  const CatAvatarPart({
    required this.categoryId,
    required this.number,
    required this.color,
    required this.extension,
    this.x = 0,
    this.y = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.hueRotate = 0,
    this.rotation = 0,
    this.brightness = 1,
    this.saturation = 1,
    this.opacity = 1,
    this.glowRadius = 0,
    this.glowIntensity = 0.5,
    this.animationEnabled = false,
    this.animationDuration = 3,
    this.animationEasing = 'linear',
    this.animationDelay = 0,
    this.rotationAmount = 360,
    this.rotationStartDelay = 0,
    this.rotationReverse = false,
    this.rotationPauseMode = 'afterCycle',
    this.transformOriginX = 50,
    this.transformOriginY = 50,
    this.positionXAnimationEnabled = false,
    this.positionXAnimationDuration = 2,
    this.positionXAnimationAmount = 50,
    this.positionXAnimationEasing = 'ease-in-out',
    this.positionXStartDelay = 0,
    this.positionYAnimationEnabled = false,
    this.positionYAnimationDuration = 2,
    this.positionYAnimationAmount = 50,
    this.positionYAnimationEasing = 'ease-in-out',
    this.positionYStartDelay = 0,
  });

  final String categoryId;
  final int number;
  final String color;
  final String extension;
  final double x;
  final double y;
  final double scaleX;
  final double scaleY;
  final double hueRotate;
  final double rotation;
  final double brightness;
  final double saturation;
  final double opacity;
  final double glowRadius;
  final double glowIntensity;

  final bool animationEnabled;
  final double animationDuration;
  final String animationEasing;
  final double animationDelay;
  final double rotationAmount;
  final double rotationStartDelay;
  final bool rotationReverse;
  final String rotationPauseMode;
  final double transformOriginX;
  final double transformOriginY;

  final bool positionXAnimationEnabled;
  final double positionXAnimationDuration;
  final double positionXAnimationAmount;
  final String positionXAnimationEasing;
  final double positionXStartDelay;

  final bool positionYAnimationEnabled;
  final double positionYAnimationDuration;
  final double positionYAnimationAmount;
  final String positionYAnimationEasing;
  final double positionYStartDelay;

  int get zIndex => findCategory(categoryId)?.zIndex ?? 0;

  String get imageUrl => catImageUrl(
    categoryId: categoryId,
    number: number,
    color: color,
    extension: extension,
  );

  factory CatAvatarPart.fromJson(String categoryId, Map<String, dynamic> json) {
    return CatAvatarPart(
      categoryId: categoryId,
      number: _asInt(json['number']) ?? 1,
      color: json['color']?.toString() ?? 'default',
      extension: json['extension']?.toString() ?? 'webp',
      x: _asDouble(json['x']) ?? 0,
      y: _asDouble(json['y']) ?? 0,
      scaleX: _asDouble(json['scaleX']) ?? 1,
      scaleY: _asDouble(json['scaleY']) ?? 1,
      hueRotate: _asDouble(json['hueRotate']) ?? 0,
      rotation: _asDouble(json['rotation']) ?? 0,
      brightness: _asDouble(json['brightness']) ?? 1,
      saturation: _asDouble(json['saturation']) ?? 1,
      opacity: _asDouble(json['opacity']) ?? 1,
      glowRadius: _asDouble(json['glowRadius']) ?? 0,
      glowIntensity: _asDouble(json['glowIntensity']) ?? 0.5,
      animationEnabled: json['animationEnabled'] == true,
      animationDuration: _asDouble(json['animationDuration']) ?? 3,
      animationEasing: json['animationEasing']?.toString() ?? 'linear',
      animationDelay: _asDouble(json['animationDelay']) ?? 0,
      rotationAmount: _asDouble(json['rotationAmount']) ?? 360,
      rotationStartDelay: _asDouble(json['rotationStartDelay']) ?? 0,
      rotationReverse: json['rotationReverse'] == true,
      rotationPauseMode:
          json['rotationPauseMode']?.toString() == 'betweenDirections'
          ? 'betweenDirections'
          : 'afterCycle',
      transformOriginX: _asDouble(json['transformOriginX']) ?? 50,
      transformOriginY: _asDouble(json['transformOriginY']) ?? 50,
      positionXAnimationEnabled: json['positionXAnimationEnabled'] == true,
      positionXAnimationDuration:
          _asDouble(json['positionXAnimationDuration']) ?? 2,
      positionXAnimationAmount:
          _asDouble(json['positionXAnimationAmount']) ?? 50,
      positionXAnimationEasing:
          json['positionXAnimationEasing']?.toString() ?? 'ease-in-out',
      positionXStartDelay: _asDouble(json['positionXStartDelay']) ?? 0,
      positionYAnimationEnabled: json['positionYAnimationEnabled'] == true,
      positionYAnimationDuration:
          _asDouble(json['positionYAnimationDuration']) ?? 2,
      positionYAnimationAmount:
          _asDouble(json['positionYAnimationAmount']) ?? 50,
      positionYAnimationEasing:
          json['positionYAnimationEasing']?.toString() ?? 'ease-in-out',
      positionYStartDelay: _asDouble(json['positionYStartDelay']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'color': color,
    'extension': extension,
    'x': x,
    'y': y,
    'scaleX': scaleX,
    'scaleY': scaleY,
    'hueRotate': hueRotate,
    'rotation': rotation,
    'brightness': brightness,
    'saturation': saturation,
    'opacity': opacity,
    'glowRadius': glowRadius,
    'glowIntensity': glowIntensity,
    'animationEnabled': animationEnabled,
    'animationDuration': animationDuration,
    'animationEasing': animationEasing,
    'animationDelay': animationDelay,
    'rotationAmount': rotationAmount,
    'rotationStartDelay': rotationStartDelay,
    'rotationReverse': rotationReverse,
    'rotationPauseMode': rotationPauseMode,
    'transformOriginX': transformOriginX,
    'transformOriginY': transformOriginY,
    'positionXAnimationEnabled': positionXAnimationEnabled,
    'positionXAnimationDuration': positionXAnimationDuration,
    'positionXAnimationAmount': positionXAnimationAmount,
    'positionXAnimationEasing': positionXAnimationEasing,
    'positionXStartDelay': positionXStartDelay,
    'positionYAnimationEnabled': positionYAnimationEnabled,
    'positionYAnimationDuration': positionYAnimationDuration,
    'positionYAnimationAmount': positionYAnimationAmount,
    'positionYAnimationEasing': positionYAnimationEasing,
    'positionYStartDelay': positionYStartDelay,
  };
}

Map<String, CatAvatarPart> parseAvatarParts(Map<String, dynamic> avatarData) {
  final map = <String, CatAvatarPart>{};
  avatarData.forEach((key, value) {
    if (value is Map) {
      map[key] = CatAvatarPart.fromJson(key, value.cast<String, dynamic>());
    }
  });
  return map;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
