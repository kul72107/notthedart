import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cat_avatar_models.dart';

const Set<String> _keepNaturalZ = <String>{
  'rightear',
  'rightear1',
  'rightear2',
  'leftear',
  'leftear1',
  'leftear2',
  'rightmustache',
  'leftmustache',
};

class AnimatedCatAvatar extends StatelessWidget {
  const AnimatedCatAvatar({
    super.key,
    required this.avatarData,
    this.backgroundColor = const Color(0xFFFFB8A5),
    this.animationsEnabled = true,
    this.effectsEnabled = true,
    this.focusedPart,
    this.onPartTap,
  });

  final Map<String, dynamic> avatarData;
  final Color backgroundColor;
  final bool animationsEnabled;
  final bool effectsEnabled;
  final String? focusedPart;
  final ValueChanged<String>? onPartTap;

  @override
  Widget build(BuildContext context) {
    final parts = parseAvatarParts(avatarData).values.toList()
      ..sort((a, b) => _effectiveZ(a).compareTo(_effectiveZ(b)));

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            for (final part in parts)
              _AvatarPartLayer(
                key: ValueKey<String>(
                  '${part.categoryId}-${part.number}-${part.color}-${part.extension}',
                ),
                part: part,
                focusedPart: focusedPart,
                animationsEnabled: animationsEnabled,
                effectsEnabled: effectsEnabled,
                onTap: onPartTap == null
                    ? null
                    : () => onPartTap!(part.categoryId),
              ),
          ],
        ),
      ),
    );
  }

  int _effectiveZ(CatAvatarPart part) {
    if (focusedPart == part.categoryId &&
        !_keepNaturalZ.contains(part.categoryId)) {
      return 999;
    }
    return part.zIndex;
  }
}

class _AvatarPartLayer extends StatefulWidget {
  const _AvatarPartLayer({
    super.key,
    required this.part,
    required this.animationsEnabled,
    required this.effectsEnabled,
    required this.focusedPart,
    this.onTap,
  });

  final CatAvatarPart part;
  final bool animationsEnabled;
  final bool effectsEnabled;
  final String? focusedPart;
  final VoidCallback? onTap;

  @override
  State<_AvatarPartLayer> createState() => _AvatarPartLayerState();
}

class _AvatarPartLayerState extends State<_AvatarPartLayer>
    with TickerProviderStateMixin {
  AnimationController? _rotation;
  AnimationController? _positionX;
  AnimationController? _positionY;

  Curve _rotationCurve = Curves.linear;
  Curve _xCurve = Curves.easeInOut;
  Curve _yCurve = Curves.easeInOut;

  Timer? _rotationDelayTimer;
  Timer? _xDelayTimer;
  Timer? _yDelayTimer;

  bool _rotationStarted = false;
  bool _xStarted = false;
  bool _yStarted = false;

  _ImageOffset _imageOffset = const _ImageOffset(offsetX: 0, offsetY: 0);
  String? _loadingOffsetUrl;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _loadImageOffset();
  }

  @override
  void didUpdateWidget(covariant _AvatarPartLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPart = oldWidget.part;
    final part = widget.part;

    final changed =
        oldPart.categoryId != part.categoryId ||
        oldPart.number != part.number ||
        oldPart.color != part.color ||
        oldPart.extension != part.extension ||
        oldPart.animationEnabled != part.animationEnabled ||
        oldPart.animationDuration != part.animationDuration ||
        oldPart.animationDelay != part.animationDelay ||
        oldPart.rotationAmount != part.rotationAmount ||
        oldPart.rotationReverse != part.rotationReverse ||
        oldPart.rotationPauseMode != part.rotationPauseMode ||
        oldPart.rotationStartDelay != part.rotationStartDelay ||
        oldPart.positionXAnimationEnabled != part.positionXAnimationEnabled ||
        oldPart.positionXAnimationDuration != part.positionXAnimationDuration ||
        oldPart.positionXStartDelay != part.positionXStartDelay ||
        oldPart.positionYAnimationEnabled != part.positionYAnimationEnabled ||
        oldPart.positionYAnimationDuration != part.positionYAnimationDuration ||
        oldPart.positionYStartDelay != part.positionYStartDelay ||
        oldWidget.animationsEnabled != widget.animationsEnabled;

    if (changed) {
      _disposeControllers();
      _setupControllers();
    }

    if (oldPart.imageUrl != part.imageUrl) {
      _loadImageOffset();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _rotationDelayTimer?.cancel();
    _xDelayTimer?.cancel();
    _yDelayTimer?.cancel();
    _rotation?.dispose();
    _positionX?.dispose();
    _positionY?.dispose();
    _rotation = null;
    _positionX = null;
    _positionY = null;
  }

  Future<void> _loadImageOffset() async {
    final url = widget.part.imageUrl;
    _loadingOffsetUrl = url;
    final result = await _ImageOffsetCache.read(url);
    if (!mounted || _loadingOffsetUrl != url) return;
    setState(() {
      _imageOffset = result;
    });
  }

  void _setupControllers() {
    final part = widget.part;
    if (!widget.animationsEnabled) return;

    if (part.animationEnabled) {
      _rotationCurve = _curveFromEasing(part.animationEasing);
      _rotation = AnimationController(
        vsync: this,
        duration: _seconds(_rotationCycleSeconds(part)),
      )..addListener(_onTick);

      final delay = math.max(0.0, part.rotationStartDelay);
      if (delay > 0) {
        _rotationDelayTimer = Timer(_seconds(delay), () {
          if (!mounted || _rotation == null) return;
          _rotationStarted = true;
          _rotation!.repeat();
        });
      } else {
        _rotationStarted = true;
        _rotation!.repeat();
      }
    }

    if (part.positionXAnimationEnabled) {
      _xCurve = _curveFromEasing(part.positionXAnimationEasing);
      _positionX = AnimationController(
        vsync: this,
        duration: _seconds(math.max(0.1, part.positionXAnimationDuration)),
      )..addListener(_onTick);
      final delay = math.max(0.0, part.positionXStartDelay);
      if (delay > 0) {
        _xDelayTimer = Timer(_seconds(delay), () {
          if (!mounted || _positionX == null) return;
          _xStarted = true;
          _positionX!.repeat(reverse: true);
        });
      } else {
        _xStarted = true;
        _positionX!.repeat(reverse: true);
      }
    }

    if (part.positionYAnimationEnabled) {
      _yCurve = _curveFromEasing(part.positionYAnimationEasing);
      _positionY = AnimationController(
        vsync: this,
        duration: _seconds(math.max(0.1, part.positionYAnimationDuration)),
      )..addListener(_onTick);
      final delay = math.max(0.0, part.positionYStartDelay);
      if (delay > 0) {
        _yDelayTimer = Timer(_seconds(delay), () {
          if (!mounted || _positionY == null) return;
          _yStarted = true;
          _positionY!.repeat(reverse: true);
        });
      } else {
        _yStarted = true;
        _positionY!.repeat(reverse: true);
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final part = widget.part;
    final isFocused = widget.focusedPart == part.categoryId;
    final isBlurred = widget.focusedPart != null && !isFocused;

    final xOffset = _currentX(part);
    final yOffset = _currentY(part);
    final rotation = _currentRotation(part);
    final opacity = part.opacity.clamp(0.0, 1.0).toDouble();

    final effectiveOpacity = isBlurred ? opacity * 0.45 : opacity;
    final blurSigma = widget.effectsEnabled && isBlurred ? 3.0 : 0.0;

    Widget image = _buildPartImage(part: part, opacity: effectiveOpacity);

    if (blurSigma > 0) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: image,
      );
    }

    if (widget.effectsEnabled &&
        part.glowRadius > 0 &&
        part.glowIntensity > 0 &&
        !isBlurred) {
      image = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Opacity(
            opacity: (part.glowIntensity * 0.8).clamp(0.0, 1.0).toDouble(),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: math.max(0.0, part.glowRadius),
                sigmaY: math.max(0.0, part.glowRadius),
              ),
              child: _buildPartImage(
                part: part,
                opacity: effectiveOpacity,
                glowBoost: 1 + part.glowIntensity,
              ),
            ),
          ),
          image,
        ],
      );
    }

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pivotPercent = _resolveTransformOrigin(part);
          final pivotOffset = Offset(
            ((pivotPercent.dx - 50) / 100) * constraints.maxWidth,
            ((pivotPercent.dy - 50) / 100) * constraints.maxHeight,
          );

          return Transform.translate(
            offset: Offset(part.x + xOffset, part.y + yOffset),
            child: Transform.translate(
              offset: pivotOffset,
              child: Transform.rotate(
                angle: rotation * math.pi / 180,
                child: Transform.translate(
                  offset: Offset(-pivotOffset.dx, -pivotOffset.dy),
                  child: Transform.scale(
                    scaleX: part.scaleX,
                    scaleY: part.scaleY,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: widget.onTap,
                      child: image,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Offset _resolveTransformOrigin(CatAvatarPart part) {
    final useAutoCenter =
        part.transformOriginX == 50 && part.transformOriginY == 50;
    if (useAutoCenter) {
      return Offset(50 + _imageOffset.offsetX, 50 + _imageOffset.offsetY);
    }
    return Offset(part.transformOriginX, part.transformOriginY);
  }

  Widget _buildPartImage({
    required CatAvatarPart part,
    required double opacity,
    double glowBoost = 1,
  }) {
    Widget image = Image.network(
      part.imageUrl,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, _, __) => const SizedBox.shrink(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const SizedBox.shrink();
      },
    );

    if (part.hueRotate != 0) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(_hueRotateMatrix(part.hueRotate)),
        child: image,
      );
    }
    if (part.saturation != 1) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(_saturationMatrix(part.saturation)),
        child: image,
      );
    }
    if (part.brightness != 1 || glowBoost != 1) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          _brightnessMatrix(part.brightness * glowBoost),
        ),
        child: image,
      );
    }

    return Opacity(opacity: opacity, child: image);
  }

  double _rotationCycleSeconds(CatAvatarPart part) {
    final duration = math.max(0.1, part.animationDuration);
    final pause = math.max(0.0, part.animationDelay);
    if (!part.rotationReverse) {
      return duration + pause;
    }
    if (part.rotationPauseMode == 'betweenDirections') {
      return (duration + pause) * 2;
    }
    return (duration * 2) + pause;
  }

  double _currentRotation(CatAvatarPart part) {
    if (!widget.animationsEnabled ||
        !part.animationEnabled ||
        !_rotationStarted) {
      return part.rotation;
    }
    final controller = _rotation;
    if (controller == null) return part.rotation;

    final duration = math.max(0.1, part.animationDuration);
    final pause = math.max(0.0, part.animationDelay);
    final amount = part.rotationAmount;
    final elapsed =
        controller.value.clamp(0.0, 1.0).toDouble() *
        _rotationCycleSeconds(part);

    if (!part.rotationReverse) {
      if (elapsed <= duration) {
        final progress = (elapsed / duration).clamp(0.0, 1.0).toDouble();
        return part.rotation + (amount * _rotationCurve.transform(progress));
      }
      return part.rotation + amount;
    }

    if (part.rotationPauseMode == 'betweenDirections') {
      final phase = elapsed % ((duration + pause) * 2);
      if (phase < duration + pause) {
        if (phase <= duration) {
          final progress = (phase / duration).clamp(0.0, 1.0).toDouble();
          return part.rotation + (amount * _rotationCurve.transform(progress));
        }
        return part.rotation + amount;
      }
      final backward = phase - (duration + pause);
      if (backward <= duration) {
        final progress = (backward / duration).clamp(0.0, 1.0).toDouble();
        return part.rotation +
            (amount * (1 - _rotationCurve.transform(progress)));
      }
      return part.rotation;
    }

    final phase = elapsed % ((duration * 2) + pause);
    if (phase < duration * 2) {
      if (phase <= duration) {
        final progress = (phase / duration).clamp(0.0, 1.0).toDouble();
        return part.rotation + (amount * _rotationCurve.transform(progress));
      }
      final progress = ((phase - duration) / duration)
          .clamp(0.0, 1.0)
          .toDouble();
      return part.rotation +
          (amount * (1 - _rotationCurve.transform(progress)));
    }
    return part.rotation;
  }

  double _currentX(CatAvatarPart part) {
    if (!widget.animationsEnabled ||
        !part.positionXAnimationEnabled ||
        !_xStarted) {
      return 0;
    }
    final controller = _positionX;
    if (controller == null) return 0;
    final curved = _xCurve.transform(
      controller.value.clamp(0.0, 1.0).toDouble(),
    );
    return (-part.positionXAnimationAmount / 2) +
        (part.positionXAnimationAmount * curved);
  }

  double _currentY(CatAvatarPart part) {
    if (!widget.animationsEnabled ||
        !part.positionYAnimationEnabled ||
        !_yStarted) {
      return 0;
    }
    final controller = _positionY;
    if (controller == null) return 0;
    final curved = _yCurve.transform(
      controller.value.clamp(0.0, 1.0).toDouble(),
    );
    return part.positionYAnimationAmount * curved;
  }
}

class _ImageOffset {
  const _ImageOffset({required this.offsetX, required this.offsetY});

  final double offsetX;
  final double offsetY;
}

class _ImageOffsetCache {
  static final Map<String, _ImageOffset> _cache = <String, _ImageOffset>{};
  static final Map<String, Future<_ImageOffset>> _pending =
      <String, Future<_ImageOffset>>{};

  static Future<_ImageOffset> read(String imageUrl) {
    final cached = _cache[imageUrl];
    if (cached != null) return Future<_ImageOffset>.value(cached);
    final wait = _pending[imageUrl];
    if (wait != null) return wait;
    final compute = _calculate(imageUrl);
    _pending[imageUrl] = compute;
    return compute
        .then((value) {
          _cache[imageUrl] = value;
          _pending.remove(imageUrl);
          return value;
        })
        .catchError((_) {
          _pending.remove(imageUrl);
          return const _ImageOffset(offsetX: 0, offsetY: 0);
        });
  }

  static Future<_ImageOffset> _calculate(String imageUrl) async {
    try {
      final image = await _resolveUiImage(NetworkImage(imageUrl));
      final width = image.width;
      final height = image.height;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null || width <= 0 || height <= 0) {
        return const _ImageOffset(offsetX: 0, offsetY: 0);
      }
      final rgba = byteData.buffer.asUint8List();

      var minX = width;
      var minY = height;
      var maxX = 0;
      var maxY = 0;
      var hasVisible = false;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final alpha = rgba[((y * width + x) * 4) + 3];
          if (alpha > 10) {
            hasVisible = true;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (!hasVisible) return const _ImageOffset(offsetX: 0, offsetY: 0);

      final centerX = (minX + maxX) / 2;
      final centerY = (minY + maxY) / 2;
      final offsetX = ((centerX - (width / 2)) / width) * 100;
      final offsetY = ((centerY - (height / 2)) / height) * 100;
      return _ImageOffset(offsetX: offsetX, offsetY: offsetY);
    } catch (_) {
      return const _ImageOffset(offsetX: 0, offsetY: 0);
    }
  }

  static Future<ui.Image> _resolveUiImage(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    final stream = provider.resolve(const ImageConfiguration());
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 12));
  }
}

Duration _seconds(double seconds) {
  return Duration(milliseconds: (seconds * 1000).round());
}

Curve _curveFromEasing(String easing) {
  switch (easing.trim()) {
    case 'linear':
      return Curves.linear;
    case 'ease':
      return Curves.ease;
    case 'ease-in':
      return Curves.easeIn;
    case 'ease-out':
      return Curves.easeOut;
    case 'ease-in-out':
      return Curves.easeInOut;
    default:
      final match = RegExp(
        r'cubic-bezier\(([^,]+),([^,]+),([^,]+),([^)]+)\)',
      ).firstMatch(easing);
      if (match == null) return Curves.linear;
      final a = double.tryParse(match.group(1)!.trim()) ?? 0.25;
      final b = double.tryParse(match.group(2)!.trim()) ?? 0.1;
      final c = double.tryParse(match.group(3)!.trim()) ?? 0.25;
      final d = double.tryParse(match.group(4)!.trim()) ?? 1.0;
      return Cubic(a, b, c, d);
  }
}

List<double> _brightnessMatrix(double brightness) {
  final b = brightness.clamp(0.0, 3.0).toDouble();
  return <double>[b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
}

List<double> _saturationMatrix(double saturation) {
  final s = saturation.clamp(0.0, 3.0).toDouble();
  final inv = 1 - s;
  final r = 0.213 * inv;
  final g = 0.715 * inv;
  final b = 0.072 * inv;
  return <double>[
    r + s,
    g,
    b,
    0,
    0,
    r,
    g + s,
    b,
    0,
    0,
    r,
    g,
    b + s,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _hueRotateMatrix(double degrees) {
  final angle = degrees * math.pi / 180;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);

  return <double>[
    (0.213 + cosA * 0.787 - sinA * 0.213),
    (0.715 - cosA * 0.715 - sinA * 0.715),
    (0.072 - cosA * 0.072 + sinA * 0.928),
    0,
    0,
    (0.213 - cosA * 0.213 + sinA * 0.143),
    (0.715 + cosA * 0.285 + sinA * 0.140),
    (0.072 - cosA * 0.072 - sinA * 0.283),
    0,
    0,
    (0.213 - cosA * 0.213 - sinA * 0.787),
    (0.715 - cosA * 0.715 + sinA * 0.715),
    (0.072 + cosA * 0.928 + sinA * 0.072),
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
