import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../widgets/bottom_nav.dart';
import '../avatar/animated_cat_avatar.dart';
import '../avatar/cat_avatar_constants.dart';
import '../avatar/cat_avatar_models.dart';
import '../shared/widgets/nav_primitives.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen>
    with TickerProviderStateMixin {
  static const String _kGithubTreeUrl =
      'https://api.github.com/repos/kul72107/offf/git/trees/main?recursive=1';

  bool _didInit = false;
  bool _loading = true;
  String? _loadError;

  String _selectedCategory = 'body';
  bool _uiVisible = true;
  bool _showPublishPopup = false;
  bool _showExportPopup = false;
  bool _isPickingOrigin = false;
  bool _showStickyPreview = false;
  Offset? _originMarker;
  Timer? _originMarkerTimer;

  bool _saving = false;
  bool _saveSuccess = false;
  bool _publishing = false;
  bool _publishSuccess = false;
  bool _rankedSubmitted = false;

  String _activeAnimationTab = 'rotation';
  String _activeGlobalTab = 'rotate';

  int _historyIndex = 0;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[
    <String, dynamic>{},
  ];
  bool _isUndoRedoAction = false;

  int? _editingCatId;
  String? _rankedMatchId;
  _PublishInfo? _publishInfo;
  _BoxConfig _boxConfig = const _BoxConfig();

  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _previewLayoutKey = GlobalKey();
  final GlobalKey _avatarBoundaryKey = GlobalKey();

  Map<String, dynamic> _manifest = <String, dynamic>{};
  Map<String, CatAvatarPart> _parts = <String, CatAvatarPart>{};
  final List<Map<String, dynamic>> _savedSettings = <Map<String, dynamic>>[];

  double _globalRotateDuration = 0;
  double _globalRotatePause = 0;
  double _globalRotateAmount = 0;
  double _globalHorizontalDuration = 0;
  double _globalHorizontalDistance = 0;
  double _globalVerticalDuration = 0;
  double _globalVerticalDistance = 0;

  static const List<String> _backgroundHexColors = <String>[
    '#FFB8A5',
    '#FFFFFF',
    '#FF0000',
    '#FF8800',
    '#FFFF00',
    '#00FF00',
    '#00FFFF',
    '#88BBFF',
    '#0000FF',
    '#FF00FF',
    '#884488',
  ];
  Color _backgroundColor = const Color(0xFFFFB8A5);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _bootstrap();
  }

  @override
  void dispose() {
    _originMarkerTimer?.cancel();
    _descriptionController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _readQueryFlags();
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final manifest = await _loadManifestWithFallback(api);
      var parts = <String, CatAvatarPart>{
        'body': _defaultPartFor('body', manifest),
      };

      if (_editingCatId != null) {
        final edited = await _loadEditingCat(_editingCatId!);
        if (edited != null && edited.isNotEmpty) {
          parts = edited;
        }
      }

      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _parts = parts;
        _loading = false;
      });
      _resetHistory();
      _scheduleStickyCheck();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _parts = <String, CatAvatarPart>{'body': _fallbackPart('body')};
        _loading = false;
        _loadError = '$error';
      });
      _resetHistory();
      _scheduleStickyCheck();
    }
  }

  void _readQueryFlags() {
    final query = Uri.base.queryParameters;
    final editRaw = query['edit'];
    _editingCatId = int.tryParse(editRaw ?? '');
    _rankedMatchId = query['ranked'];
  }

  Future<Map<String, CatAvatarPart>?> _loadEditingCat(int catId) async {
    try {
      final data = await context.read<ApiClient>().getJson('/api/my-cats');
      final cats = (data['cats'] as List?) ?? const [];
      for (final raw in cats) {
        if (raw is! Map) continue;
        final id = _asInt(raw['id']);
        if (id != catId) continue;
        final avatarData = raw['avatar_data'];
        if (avatarData is Map) {
          return _decodeParts(avatarData.cast<String, dynamic>());
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _loadManifestWithFallback(ApiClient api) async {
    try {
      final data = await api.getJson('/api/manifest');
      if (_isManifestUsable(data)) return data;
    } catch (_) {}
    final githubManifest = await _loadManifestFromGithubTree();
    if (_isManifestUsable(githubManifest)) return githubManifest;
    throw Exception('Manifest load failed (API + GitHub fallback).');
  }

  Future<Map<String, dynamic>> _loadManifestFromGithubTree() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 35),
      ),
    );
    final response = await dio.get<Map<String, dynamic>>(
      _kGithubTreeUrl,
      options: Options(
        headers: const <String, String>{
          'Accept': 'application/vnd.github+json',
        },
      ),
    );
    final payload = response.data ?? const <String, dynamic>{};
    final tree = (payload['tree'] as List?) ?? const [];

    final manifest = <String, Map<String, List<Map<String, dynamic>>>>{};
    final seen = <String>{};
    final filePattern = RegExp(r'^(\d+)\.([a-zA-Z0-9]+)$');

    for (final node in tree) {
      if (node is! Map) continue;
      final path = node['path']?.toString() ?? '';
      if (!path.startsWith('cat1/')) continue;

      final parts = path.split('/');
      if (parts.length != 4) continue;
      final category = parts[1];
      final color = parts[2];
      final filename = parts[3];
      final match = filePattern.firstMatch(filename);
      if (match == null) continue;

      final number = int.tryParse(match.group(1) ?? '');
      final extension = (match.group(2) ?? '').toLowerCase();
      if (number == null || extension.isEmpty) continue;

      final dedupe = '$category|$color|$number|$extension';
      if (!seen.add(dedupe)) continue;

      final categoryMap = manifest.putIfAbsent(
        category,
        () => <String, List<Map<String, dynamic>>>{},
      );
      final colorList = categoryMap.putIfAbsent(
        color,
        () => <Map<String, dynamic>>[],
      );
      colorList.add(<String, dynamic>{
        'number': number,
        'extension': extension,
      });
    }

    final normalized = <String, dynamic>{};
    final categories = manifest.keys.toList()..sort();
    for (final category in categories) {
      final colors = manifest[category]!.keys.toList()..sort();
      final colorMap = <String, dynamic>{};
      for (final color in colors) {
        final list = manifest[category]![color]!;
        list.sort(
          (a, b) =>
              (_asInt(a['number']) ?? 0).compareTo(_asInt(b['number']) ?? 0),
        );
        colorMap[color] = list;
      }
      normalized[category] = colorMap;
    }
    return normalized;
  }

  bool _isManifestUsable(Map<String, dynamic> raw) {
    if (raw.isEmpty) return false;
    for (final value in raw.values) {
      if (value is Map && value.isNotEmpty) return true;
    }
    return false;
  }

  CatAvatarPart _fallbackPart(String categoryId) {
    return _buildPart(
      categoryId: categoryId,
      number: 1,
      color: '24ffff',
      extension: 'png',
    );
  }

  CatAvatarPart _defaultPartFor(
    String categoryId,
    Map<String, dynamic> manifest,
  ) {
    final items = _itemsForCategory(categoryId, manifest);
    if (items.isEmpty) return _fallbackPart(categoryId);
    final item = items.first;
    return _buildPart(
      categoryId: categoryId,
      number: item.number,
      color: item.colors.isNotEmpty ? item.colors.first : 'default',
      extension: item.extension,
    );
  }

  CatAvatarPart _buildPart({
    required String categoryId,
    required int number,
    required String color,
    required String extension,
  }) {
    return CatAvatarPart(
      categoryId: categoryId,
      number: number,
      color: color,
      extension: extension,
      x: 0,
      y: 0,
      scaleX: 1,
      scaleY: 1,
      hueRotate: 0,
      rotation: 0,
      brightness: 1,
      saturation: 1,
      opacity: 1,
      glowRadius: 0,
      glowIntensity: 0.5,
      animationEnabled: false,
      animationDuration: 3,
      animationEasing: 'linear',
      animationDelay: 0,
      rotationAmount: 360,
      rotationStartDelay: 0,
      rotationReverse: false,
      rotationPauseMode: 'afterCycle',
      transformOriginX: 50,
      transformOriginY: 50,
      positionXAnimationEnabled: false,
      positionXAnimationDuration: 2,
      positionXAnimationAmount: 50,
      positionXAnimationEasing: 'ease-in-out',
      positionXStartDelay: 0,
      positionYAnimationEnabled: false,
      positionYAnimationDuration: 2,
      positionYAnimationAmount: 50,
      positionYAnimationEasing: 'ease-in-out',
      positionYStartDelay: 0,
    );
  }

  CatAvatarPart? get _selectedPart => _parts[_selectedCategory];
  List<_ManifestItem> get _currentItems =>
      _itemsForCategory(_selectedCategory, _manifest);

  _ManifestItem? get _selectedItem {
    final current = _selectedPart;
    if (current == null) return null;
    for (final item in _currentItems) {
      if (item.number == current.number) return item;
    }
    return null;
  }

  List<String> get _availableColors {
    final selected = _selectedItem;
    if (selected != null && selected.colors.isNotEmpty) return selected.colors;
    final current = _selectedPart;
    if (current != null && current.color.isNotEmpty) {
      return <String>[current.color];
    }
    return const <String>[];
  }

  List<_ManifestItem> _itemsForCategory(
    String categoryId,
    Map<String, dynamic> manifest,
  ) {
    final rawCategory = manifest[categoryId];
    if (rawCategory is! Map) return const <_ManifestItem>[];

    final collectors = <int, Map<String, dynamic>>{};
    rawCategory.forEach((dynamic colorKey, dynamic entries) {
      if (entries is! List) return;
      final color = colorKey.toString();
      for (final raw in entries) {
        if (raw is! Map) continue;
        final number = _asInt(raw['number']);
        if (number == null) continue;
        final extension =
            (raw['extension']?.toString().trim().isNotEmpty ?? false)
            ? raw['extension'].toString().trim()
            : 'webp';
        final collector = collectors.putIfAbsent(
          number,
          () => <String, dynamic>{
            'number': number,
            'extension': extension,
            'colors': <String>{},
          },
        );
        (collector['colors'] as Set<String>).add(color);
      }
    });

    final items = collectors.values.map((raw) {
      final colors = (raw['colors'] as Set<String>).toList()..sort();
      return _ManifestItem(
        number: raw['number'] as int,
        extension: raw['extension'] as String,
        colors: colors,
      );
    }).toList()..sort((a, b) => a.number.compareTo(b.number));
    return items;
  }

  Map<String, dynamic> _encodeParts([Map<String, CatAvatarPart>? source]) {
    final map = source ?? _parts;
    return <String, dynamic>{
      for (final entry in map.entries) entry.key: entry.value.toJson(),
    };
  }

  Map<String, CatAvatarPart> _decodeParts(Map<String, dynamic> raw) {
    final output = <String, CatAvatarPart>{};
    raw.forEach((key, value) {
      if (value is Map) {
        output[key] = CatAvatarPart.fromJson(
          key,
          value.cast<String, dynamic>(),
        );
      }
    });
    return output;
  }

  Map<String, CatAvatarPart> _partsWithGlobalOffsets() {
    final output = <String, CatAvatarPart>{};
    _parts.forEach((key, value) {
      output[key] = _copyWith(
        value,
        animationDuration: math.max(
          0.1,
          value.animationDuration + _globalRotateDuration,
        ),
        animationDelay: math.max(0, value.animationDelay + _globalRotatePause),
        rotationAmount: value.rotationAmount + _globalRotateAmount,
        positionXAnimationDuration: math.max(
          0.1,
          value.positionXAnimationDuration + _globalHorizontalDuration,
        ),
        positionXAnimationAmount: math.max(
          0,
          value.positionXAnimationAmount + _globalHorizontalDistance,
        ),
        positionYAnimationDuration: math.max(
          0.1,
          value.positionYAnimationDuration + _globalVerticalDuration,
        ),
        positionYAnimationAmount: math.max(
          0,
          value.positionYAnimationAmount + _globalVerticalDistance,
        ),
      );
    });
    return output;
  }

  void _resetHistory() {
    setState(() {
      _history = <Map<String, dynamic>>[_encodeParts(_parts)];
      _historyIndex = 0;
    });
  }

  void _commitParts(Map<String, CatAvatarPart> next) {
    if (_isUndoRedoAction) {
      setState(() {
        _parts = next;
      });
      return;
    }
    setState(() {
      _parts = next;
      var trimmed = _history.sublist(0, _historyIndex + 1);
      trimmed = <Map<String, dynamic>>[...trimmed, _encodeParts(next)];
      if (trimmed.length > 120) {
        trimmed = trimmed.sublist(trimmed.length - 120);
      }
      _history = trimmed;
      _historyIndex = _history.length - 1;
    });
    _scheduleStickyCheck();
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    final nextIndex = _historyIndex - 1;
    _isUndoRedoAction = true;
    setState(() {
      _historyIndex = nextIndex;
      _parts = _decodeParts(_history[nextIndex]);
      _isUndoRedoAction = false;
    });
    _scheduleStickyCheck();
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    final nextIndex = _historyIndex + 1;
    _isUndoRedoAction = true;
    setState(() {
      _historyIndex = nextIndex;
      _parts = _decodeParts(_history[nextIndex]);
      _isUndoRedoAction = false;
    });
    _scheduleStickyCheck();
  }

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex < _history.length - 1;

  void _setCategory(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
      _isPickingOrigin = false;
      _originMarker = null;
    });
  }

  void _updateSelected(CatAvatarPart Function(CatAvatarPart current) change) {
    final current = _selectedPart;
    if (current == null) return;
    _commitParts(<String, CatAvatarPart>{
      ..._parts,
      _selectedCategory: change(current),
    });
  }

  void _selectItem(_ManifestItem item) {
    final current = _parts[_selectedCategory];
    final next = _buildPart(
      categoryId: _selectedCategory,
      number: item.number,
      color: item.colors.isNotEmpty ? item.colors.first : 'default',
      extension: item.extension,
    );
    if (current == null) {
      _commitParts(<String, CatAvatarPart>{..._parts, _selectedCategory: next});
      return;
    }
    _commitParts(<String, CatAvatarPart>{
      ..._parts,
      _selectedCategory: _copyWith(
        next,
        x: current.x,
        y: current.y,
        scaleX: current.scaleX,
        scaleY: current.scaleY,
        hueRotate: current.hueRotate,
        rotation: current.rotation,
        brightness: current.brightness,
        saturation: current.saturation,
        opacity: current.opacity,
        glowRadius: current.glowRadius,
        glowIntensity: current.glowIntensity,
        animationEnabled: current.animationEnabled,
        animationDuration: current.animationDuration,
        animationEasing: current.animationEasing,
        animationDelay: current.animationDelay,
        rotationAmount: current.rotationAmount,
        rotationStartDelay: current.rotationStartDelay,
        rotationReverse: current.rotationReverse,
        rotationPauseMode: current.rotationPauseMode,
        transformOriginX: current.transformOriginX,
        transformOriginY: current.transformOriginY,
        positionXAnimationEnabled: current.positionXAnimationEnabled,
        positionXAnimationDuration: current.positionXAnimationDuration,
        positionXAnimationAmount: current.positionXAnimationAmount,
        positionXAnimationEasing: current.positionXAnimationEasing,
        positionXStartDelay: current.positionXStartDelay,
        positionYAnimationEnabled: current.positionYAnimationEnabled,
        positionYAnimationDuration: current.positionYAnimationDuration,
        positionYAnimationAmount: current.positionYAnimationAmount,
        positionYAnimationEasing: current.positionYAnimationEasing,
        positionYStartDelay: current.positionYStartDelay,
      ),
    });
  }

  void _clearSelection() {
    if (!_parts.containsKey(_selectedCategory)) return;
    final next = <String, CatAvatarPart>{..._parts};
    next.remove(_selectedCategory);
    _commitParts(next);
  }

  void _changeColor(String color) {
    _updateSelected((current) => _copyWith(current, color: color));
  }

  void _moveSelected(String direction) {
    _updateSelected((current) {
      const step = 1.0;
      var x = current.x;
      var y = current.y;
      switch (direction) {
        case 'up':
          y -= step;
          break;
        case 'down':
          y += step;
          break;
        case 'left':
          x -= step;
          break;
        case 'right':
          x += step;
          break;
      }
      return _copyWith(current, x: x, y: y);
    });
  }

  void _changeScale(String axis, double delta) {
    _updateSelected((current) {
      if (axis == 'x') {
        return _copyWith(
          current,
          scaleX: (current.scaleX + delta).clamp(0.5, 1.5).toDouble(),
        );
      }
      return _copyWith(
        current,
        scaleY: (current.scaleY + delta).clamp(0.5, 1.5).toDouble(),
      );
    });
  }

  void _setScaleFromPercent(String axis, double percent) {
    final value = 0.5 + (percent.clamp(0, 1).toDouble() * 1.0);
    _updateSelected((current) {
      if (axis == 'x') return _copyWith(current, scaleX: value);
      return _copyWith(current, scaleY: value);
    });
  }

  void _changeHue(double delta) {
    _updateSelected((current) {
      var value = current.hueRotate + delta;
      while (value < 0) {
        value += 360;
      }
      while (value >= 360) {
        value -= 360;
      }
      return _copyWith(current, hueRotate: value);
    });
  }

  void _setHueFromPercent(double percent) {
    _updateSelected(
      (current) => _copyWith(current, hueRotate: (percent.clamp(0, 1) * 360)),
    );
  }

  void _changeBrightness(double delta) {
    _updateSelected((current) {
      final next = (current.brightness + delta).clamp(0.0, 2.0).toDouble();
      return _copyWith(current, brightness: next);
    });
  }

  void _setBrightnessFromPercent(double percent) {
    _updateSelected((current) {
      final next = 2.0 - (percent.clamp(0, 1) * 2.0);
      return _copyWith(current, brightness: next);
    });
  }

  void _setSaturationFromPercent(double percent) {
    _updateSelected(
      (current) => _copyWith(current, saturation: percent.clamp(0, 1) * 2.0),
    );
  }

  void _changeRotation(double delta) {
    _updateSelected((current) {
      var next = current.rotation + delta;
      if (next > 180) next -= 360;
      if (next < -180) next += 360;
      return _copyWith(current, rotation: next);
    });
  }

  void _saveCurrentSetting() {
    final current = _selectedPart;
    if (current == null) return;
    final settings = <String, dynamic>{
      'x': current.x,
      'y': current.y,
      'scaleX': current.scaleX,
      'scaleY': current.scaleY,
      'rotation': current.rotation,
      'hueRotate': current.hueRotate,
      'brightness': current.brightness,
      'saturation': current.saturation,
      'opacity': current.opacity,
      'glowRadius': current.glowRadius,
      'glowIntensity': current.glowIntensity,
      'transformOriginX': current.transformOriginX,
      'transformOriginY': current.transformOriginY,
    };
    final duplicate = _savedSettings.any(
      (entry) => const DeepCollectionEquality().equals(entry, settings),
    );
    if (duplicate) return;
    setState(() {
      _savedSettings.insert(0, settings);
      if (_savedSettings.length > 20) _savedSettings.removeLast();
    });
  }

  void _applySavedSetting(Map<String, dynamic> setting) {
    _updateSelected((current) {
      return _copyWith(
        current,
        x: _asDouble(setting['x']) ?? current.x,
        y: _asDouble(setting['y']) ?? current.y,
        scaleX: _asDouble(setting['scaleX']) ?? current.scaleX,
        scaleY: _asDouble(setting['scaleY']) ?? current.scaleY,
        rotation: _asDouble(setting['rotation']) ?? current.rotation,
        hueRotate: _asDouble(setting['hueRotate']) ?? current.hueRotate,
        brightness: _asDouble(setting['brightness']) ?? current.brightness,
        saturation: _asDouble(setting['saturation']) ?? current.saturation,
        opacity: _asDouble(setting['opacity']) ?? current.opacity,
        glowRadius: _asDouble(setting['glowRadius']) ?? current.glowRadius,
        glowIntensity:
            _asDouble(setting['glowIntensity']) ?? current.glowIntensity,
        transformOriginX:
            _asDouble(setting['transformOriginX']) ?? current.transformOriginX,
        transformOriginY:
            _asDouble(setting['transformOriginY']) ?? current.transformOriginY,
      );
    });
  }

  void _toggleTransformOriginPick() {
    setState(() {
      _isPickingOrigin = !_isPickingOrigin;
      if (!_isPickingOrigin) _originMarker = null;
    });
  }

  void _resetTransformOrigin() {
    _updateSelected(
      (current) =>
          _copyWith(current, transformOriginX: 50, transformOriginY: 50),
    );
  }

  void _handlePreviewTapDown(TapDownDetails details) {
    if (!_isPickingOrigin || _selectedPart == null) return;
    final context = _previewLayoutKey.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    final x = (local.dx / box.size.width * 100).clamp(0, 100).toDouble();
    final y = (local.dy / box.size.height * 100).clamp(0, 100).toDouble();

    _updateSelected(
      (current) => _copyWith(current, transformOriginX: x, transformOriginY: y),
    );
    setState(() {
      _originMarker = Offset(x, y);
      _isPickingOrigin = false;
    });
    _originMarkerTimer?.cancel();
    _originMarkerTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _originMarker = null;
      });
    });
  }

  Future<void> _handleSave() async {
    if (_parts.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveSuccess = false;
    });

    try {
      final api = context.read<ApiClient>();
      final payloadParts = _encodeParts(_partsWithGlobalOffsets());
      final imageDataUrl = await _captureAvatarPngDataUrl();

      if (_rankedMatchId != null && _rankedMatchId!.isNotEmpty) {
        await api.postJson(
          '/api/ranked',
          data: <String, dynamic>{
            'action': 'submit_cat',
            'matchId': int.tryParse(_rankedMatchId!),
            'avatarData': payloadParts,
            'imageDataUrl': imageDataUrl,
          },
        );
        if (mounted) setState(() => _rankedSubmitted = true);
      } else if (_editingCatId != null) {
        await api.putJson(
          '/api/my-cats',
          data: <String, dynamic>{
            'id': _editingCatId,
            'avatarData': payloadParts,
            'imageDataUrl': imageDataUrl,
          },
        );
      } else {
        await api.postJson(
          '/api/save-private',
          data: <String, dynamic>{
            'avatarData': payloadParts,
            'imageDataUrl': imageDataUrl,
          },
        );
      }

      if (!mounted) return;
      setState(() => _saveSuccess = true);
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() => _saveSuccess = false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handlePublishClick() async {
    if (_parts.isEmpty) return;
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to publish your cat.')),
      );
      context.go('/account');
      return;
    }
    await _loadPublishInfo();
    if (!mounted) return;
    setState(() {
      _showPublishPopup = true;
      _uiVisible = false;
    });
  }

  Future<void> _loadPublishInfo() async {
    try {
      final api = context.read<ApiClient>();
      final data = await api.getJson(
        '/api/publish',
        queryParameters: _editingCatId == null
            ? null
            : <String, dynamic>{'avatarId': _editingCatId},
      );
      if (!mounted) return;
      setState(() => _publishInfo = _PublishInfo.fromJson(data));
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishInfo = null);
    }
  }

  void _cancelPublish() {
    setState(() {
      _showPublishPopup = false;
      _uiVisible = true;
      _descriptionController.clear();
    });
  }

  Future<void> _handleFinalPublish() async {
    if (_publishing || _parts.isEmpty) return;
    setState(() {
      _publishing = true;
      _publishSuccess = false;
    });
    try {
      final api = context.read<ApiClient>();
      final payloadParts = _encodeParts(_partsWithGlobalOffsets());
      final imageDataUrl = await _captureAvatarPngDataUrl();

      await api.postJson(
        '/api/publish',
        data: <String, dynamic>{
          'avatarData': payloadParts,
          'imageDataUrl': imageDataUrl,
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'avatarId': _editingCatId,
          'boxConfig': _boxConfig.enabled ? _boxConfig.toJson() : null,
        },
      );

      if (!mounted) return;
      setState(() {
        _publishSuccess = true;
        _showPublishPopup = false;
        _uiVisible = true;
        _boxConfig = const _BoxConfig();
      });
      _descriptionController.clear();
      Future<void>.delayed(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        setState(() => _publishSuccess = false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $error')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<String?> _captureAvatarPngDataUrl() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _avatarBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      final base64 = base64Encode(bytes.buffer.asUint8List());
      return 'data:image/png;base64,$base64';
    } catch (_) {
      return null;
    }
  }

  bool get _hasAnimations {
    for (final part in _parts.values) {
      if (part.animationEnabled ||
          part.positionXAnimationEnabled ||
          part.positionYAnimationEnabled) {
        return true;
      }
    }
    return false;
  }

  Future<void> _handleDownloadTap() async {
    if (_hasAnimations) {
      setState(() => _showExportPopup = true);
      return;
    }
    final dataUrl = await _captureAvatarPngDataUrl();
    if (!mounted) return;
    if (dataUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed.')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: dataUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PNG data URL copied to clipboard.')),
    );
  }

  Future<void> _handleExport(int fps) async {
    final dataUrl = await _captureAvatarPngDataUrl();
    if (!mounted) return;
    if (dataUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed.')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: dataUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export ($fps FPS) copied as PNG data URL.')),
    );
    setState(() => _showExportPopup = false);
  }

  void _onScroll() {
    _updateStickyPreview();
  }

  void _scheduleStickyCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateStickyPreview());
  }

  void _updateStickyPreview() {
    if (!_scrollController.hasClients) return;
    final ctx = _previewLayoutKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final offset = box.localToGlobal(Offset.zero);
    final shouldShow = offset.dy < -(box.size.height * 0.1);
    if (_showStickyPreview != shouldShow && mounted) {
      setState(() => _showStickyPreview = shouldShow);
    }
  }

  void _resetGlobalOffsets() {
    setState(() {
      if (_activeGlobalTab == 'rotate') {
        _globalRotateDuration = 0;
        _globalRotatePause = 0;
        _globalRotateAmount = 0;
      } else if (_activeGlobalTab == 'horizontal') {
        _globalHorizontalDuration = 0;
        _globalHorizontalDistance = 0;
      } else {
        _globalVerticalDuration = 0;
        _globalVerticalDistance = 0;
      }
    });
  }

  Widget _buildRankedBanner() {
    if (_rankedSubmitted) {
      return _SoftCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Your cat was submitted to ranked match.',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/ranked'),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }
    return _SoftCard(
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.sports_martial_arts,
            color: Color(0xFFB45309),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ranked match #$_rankedMatchId - use Save to submit.',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/ranked'),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyPreview(Map<String, dynamic> avatarData) {
    return Positioned(
      top: 10,
      left: 10,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF8BB4), width: 3),
          ),
          child: SizedBox(
            width: 120,
            height: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedCatAvatar(
                avatarData: avatarData,
                backgroundColor: _backgroundColor,
                animationsEnabled: true,
                effectsEnabled: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mergedParts = _partsWithGlobalOffsets();
    final avatarData = _encodeParts(mergedParts);
    final selectedPart = _selectedPart;
    final isPopupOpen = _showPublishPopup || _showExportPopup;

    var categoryName = _selectedCategory;
    for (final category in catCategories) {
      if (category.id == _selectedCategory) {
        categoryName = category.name;
        break;
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFCE7F3), Color(0xFFF3E8FF)],
          ),
        ),
        child: Stack(
          children: <Widget>[
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
                      children: <Widget>[
                        if (!isPopupOpen)
                          _CreateHeader(
                            saving: _saving,
                            saveSuccess: _saveSuccess,
                            publishing: _publishing,
                            publishSuccess: _publishSuccess,
                            hasParts: _parts.isNotEmpty,
                            onBack: () => context.go('/'),
                            onSave: _handleSave,
                            onPublish: _handlePublishClick,
                            isEditing: _editingCatId != null,
                          ),
                        if (_rankedMatchId != null && !isPopupOpen) ...<Widget>[
                          const SizedBox(height: 8),
                          _buildRankedBanner(),
                        ],
                        if (_editingCatId != null && !isPopupOpen) ...<Widget>[
                          const SizedBox(height: 8),
                          const _SoftCard(
                            child: Text(
                              'Edit mode active - save to update your cat.',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        if (_loadError != null) ...<Widget>[
                          const SizedBox(height: 8),
                          _SoftCard(
                            child: Text(
                              'Manifest load issue: $_loadError',
                              style: const TextStyle(
                                color: Color(0xFF7F1D1D),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (_savedSettings.isNotEmpty &&
                            !isPopupOpen) ...<Widget>[
                          const SizedBox(height: 10),
                          _SavedSettingsStrip(
                            settings: _savedSettings,
                            onApply: _applySavedSetting,
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildPreviewCard(
                          avatarData,
                          selectedPart,
                          isPopupOpen,
                        ),
                        if (!isPopupOpen) ...<Widget>[
                          const SizedBox(height: 10),
                          _buildAnimationControls(selectedPart),
                          const SizedBox(height: 10),
                          _buildGlobalAnimationControls(),
                        ],
                        if (_uiVisible && !isPopupOpen) ...<Widget>[
                          const SizedBox(height: 10),
                          _buildSingleBarCard(
                            title: 'Glow Radius',
                            value: selectedPart?.glowRadius ?? 0,
                            min: 0,
                            max: 50,
                            step: 2,
                            gradient: const <Color>[
                              Color(0xFF1F2937),
                              Color(0xFFEC4899),
                            ],
                            onChange: (value) => _updateSelected(
                              (p) => _copyWith(p, glowRadius: value),
                            ),
                            enabled: selectedPart != null,
                          ),
                          const SizedBox(height: 10),
                          _buildSingleBarCard(
                            title: 'Glow Intensity',
                            value: selectedPart?.glowIntensity ?? 0.5,
                            min: 0,
                            max: 3,
                            step: 0.1,
                            gradient: const <Color>[
                              Color(0x66FFFFFF),
                              Color(0xFFFFFFFF),
                            ],
                            onChange: (value) => _updateSelected(
                              (p) => _copyWith(p, glowIntensity: value),
                            ),
                            enabled: selectedPart != null,
                          ),
                          const SizedBox(height: 10),
                          _buildSingleBarCard(
                            title: 'Saturation',
                            value: selectedPart?.saturation ?? 1,
                            min: 0,
                            max: 2,
                            step: 0.05,
                            gradient: const <Color>[
                              Color(0xFF808080),
                              Color(0xFFFF0080),
                            ],
                            onChange: (value) =>
                                _setSaturationFromPercent(value / 2),
                            enabled: selectedPart != null,
                          ),
                          const SizedBox(height: 10),
                          _buildSingleBarCard(
                            title: 'Opacity',
                            value: selectedPart?.opacity ?? 1,
                            min: 0,
                            max: 1,
                            step: 0.05,
                            gradient: const <Color>[
                              Color(0x4D9CA3AF),
                              Color(0xFF6366F1),
                            ],
                            onChange: (value) => _updateSelected(
                              (p) => _copyWith(p, opacity: value),
                            ),
                            enabled: selectedPart != null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _UndoRedoButton(
                                label: 'Undo',
                                icon: Icons.undo_rounded,
                                enabled: _canUndo,
                                onTap: _undo,
                              ),
                              const SizedBox(width: 12),
                              _UndoRedoButton(
                                label: 'Redo',
                                icon: Icons.redo_rounded,
                                enabled: _canRedo,
                                onTap: _redo,
                              ),
                            ],
                          ),
                        ],
                        if (!isPopupOpen) ...<Widget>[
                          const SizedBox(height: 10),
                          _buildAccessoryPaletteCard(selectedPart),
                          const SizedBox(height: 10),
                          _buildCategoryTabsCard(),
                          const SizedBox(height: 10),
                          _buildItemsGridCard(categoryName),
                        ],
                      ],
                    ),
            ),
            if (!isPopupOpen && _showStickyPreview && _parts.isNotEmpty)
              _buildStickyPreview(avatarData),
            if (_showPublishPopup)
              _PublishPopup(
                avatarData: avatarData,
                backgroundColor: _backgroundColor,
                descriptionController: _descriptionController,
                publishing: _publishing,
                publishInfo: _publishInfo,
                boxConfig: _boxConfig,
                onBoxConfigChanged: (next) => setState(() => _boxConfig = next),
                onCancel: _cancelPublish,
                onPublish: _handleFinalPublish,
                hasAnimation: _hasAnimations,
              ),
            if (_showExportPopup)
              _ExportPopup(
                onClose: () => setState(() => _showExportPopup = false),
                onExport: _handleExport,
              ),
            CatBottomNav(
              currentPath: '/create',
              onTap: (path) => context.go(path),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    Map<String, dynamic> avatarData,
    CatAvatarPart? selectedPart,
    bool isPopupOpen,
  ) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isPopupOpen)
            Row(
              children: <Widget>[
                const Text(
                  'Avatar Preview',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                _TinyPillButton(
                  label: 'Save Setting',
                  color: const Color(0xFF22C55E),
                  onTap: _saveCurrentSetting,
                ),
                const SizedBox(width: 8),
                _TinyPillButton(
                  label: _uiVisible ? 'Hide UI' : 'Show UI',
                  color: const Color(0xFFEC4899),
                  onTap: () => setState(() => _uiVisible = !_uiVisible),
                ),
              ],
            ),
          if (!isPopupOpen) const SizedBox(height: 10),
          GestureDetector(
            key: _previewLayoutKey,
            onTapDown: _handlePreviewTapDown,
            child: RepaintBoundary(
              key: _avatarBoundaryKey,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x40462C71),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: AnimatedCatAvatar(
                            avatarData: avatarData,
                            backgroundColor: _backgroundColor,
                            animationsEnabled: true,
                            effectsEnabled: true,
                            focusedPart: _selectedCategory,
                            onPartTap: (categoryId) => _setCategory(categoryId),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(child: _FrameDecorations()),
                      ),
                      if (_isPickingOrigin)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0x30000000),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: const Center(
                                child: _OverlayLabel(
                                  text: 'Tap a point for transform origin',
                                  color: Color(0xFFF97316),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_originMarker != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment(
                                ((_originMarker!.dx / 100) * 2) - 1,
                                ((_originMarker!.dy / 100) * 2) - 1,
                              ),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_uiVisible && !isPopupOpen) ...<Widget>[
                        Positioned(
                          right: 10,
                          top: 10,
                          child: _buildTopRightButtons(selectedPart),
                        ),
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _VerticalBarControl(
                              height: 190,
                              width: 42,
                              plusColor: const Color(0xFFEC4899),
                              minusColor: const Color(0xFFEC4899),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0xFFFF0000),
                                  Color(0xFFFFFF00),
                                  Color(0xFF00FF00),
                                  Color(0xFF00FFFF),
                                  Color(0xFF0000FF),
                                  Color(0xFFFF00FF),
                                  Color(0xFFFF0000),
                                ],
                              ),
                              valuePercent:
                                  ((selectedPart?.hueRotate ?? 0) / 360)
                                      .clamp(0, 1)
                                      .toDouble(),
                              enabled: selectedPart != null,
                              onPlus: () => _changeHue(-10),
                              onMinus: () => _changeHue(10),
                              onChanged: _setHueFromPercent,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _VerticalBarControl(
                              height: 190,
                              width: 42,
                              plusColor: const Color(0xFFF59E0B),
                              minusColor: const Color(0xFFF59E0B),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0xFFFFFFFF),
                                  Color(0xFF808080),
                                  Color(0xFF000000),
                                ],
                              ),
                              valuePercent:
                                  ((2 - (selectedPart?.brightness ?? 1)) / 2)
                                      .clamp(0, 1)
                                      .toDouble(),
                              enabled: selectedPart != null,
                              onPlus: () => _changeBrightness(-0.02),
                              onMinus: () => _changeBrightness(0.02),
                              onChanged: _setBrightnessFromPercent,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: _JoystickControl(
                            enabled: selectedPart != null,
                            onMove: _moveSelected,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _ScaleControlPanel(
                            enabled: selectedPart != null,
                            valueX: ((selectedPart?.scaleX ?? 1) - 0.5)
                                .clamp(0, 1)
                                .toDouble(),
                            valueY: ((selectedPart?.scaleY ?? 1) - 0.5)
                                .clamp(0, 1)
                                .toDouble(),
                            onPlusX: () => _changeScale('x', 0.05),
                            onMinusX: () => _changeScale('x', -0.05),
                            onPlusY: () => _changeScale('y', 0.05),
                            onMinusY: () => _changeScale('y', -0.05),
                            onChangeX: (value) =>
                                _setScaleFromPercent('x', value),
                            onChangeY: (value) =>
                                _setScaleFromPercent('y', value),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isPopupOpen) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              'Background',
              style: TextStyle(
                color: Color(0xFF4A2F73),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _backgroundHexColors.map((hex) {
                final color = _hexToColor(hex);
                final selected =
                    _backgroundColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _backgroundColor = color),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF111827)
                            : const Color(0x33948BAF),
                        width: selected ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopRightButtons(CatAvatarPart? selectedPart) {
    return Row(
      children: <Widget>[
        _CircleActionButton(
          icon: Icons.rotate_left,
          color: const Color(0xFFEC4899),
          enabled: selectedPart != null && !selectedPart.animationEnabled,
          onTap: () => _changeRotation(-2),
        ),
        const SizedBox(width: 6),
        _CircleActionButton(
          icon: Icons.rotate_right,
          color: const Color(0xFFEC4899),
          enabled: selectedPart != null && !selectedPart.animationEnabled,
          onTap: () => _changeRotation(2),
        ),
        const SizedBox(width: 6),
        _CircleActionButton(
          icon: Icons.save_rounded,
          color: const Color(0xFF22C55E),
          enabled: selectedPart != null,
          onTap: _saveCurrentSetting,
        ),
        const SizedBox(width: 6),
        _CircleActionButton(
          icon: _uiVisible ? Icons.visibility : Icons.visibility_off,
          color: const Color(0xFF8B5CF6),
          enabled: true,
          onTap: () => setState(() => _uiVisible = !_uiVisible),
        ),
        const SizedBox(width: 6),
        _CircleActionButton(
          icon: Icons.download_rounded,
          color: const Color(0xFFEC4899),
          enabled: true,
          onTap: _handleDownloadTap,
        ),
      ],
    );
  }

  Widget _buildAnimationControls(CatAvatarPart? selectedPart) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Animation Controls',
                style: TextStyle(
                  color: Color(0xFF4A2F73),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _SegmentedTabs(
                value: _activeAnimationTab,
                leftLabel: 'Rotation',
                leftValue: 'rotation',
                rightLabel: 'Position',
                rightValue: 'position',
                onChanged: (value) =>
                    setState(() => _activeAnimationTab = value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedPart == null)
            const Text(
              'Select an accessory first.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (selectedPart != null)
            _AnimationTabContent(
              part: selectedPart,
              activeTab: _activeAnimationTab,
              isPickingOrigin: _isPickingOrigin,
              onTogglePickOrigin: _toggleTransformOriginPick,
              onResetOrigin: _resetTransformOrigin,
              onChange: (part) => _updateSelected((_) => part),
            ),
        ],
      ),
    );
  }

  Widget _buildGlobalAnimationControls() {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Global Animation Controls',
            style: TextStyle(
              color: Color(0xFF4A2F73),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _ChoiceChip(
                label: 'Rotate',
                selected: _activeGlobalTab == 'rotate',
                onTap: () => setState(() => _activeGlobalTab = 'rotate'),
              ),
              const SizedBox(width: 8),
              _ChoiceChip(
                label: 'Horizontal',
                selected: _activeGlobalTab == 'horizontal',
                onTap: () => setState(() => _activeGlobalTab = 'horizontal'),
              ),
              const SizedBox(width: 8),
              _ChoiceChip(
                label: 'Vertical',
                selected: _activeGlobalTab == 'vertical',
                onTap: () => setState(() => _activeGlobalTab = 'vertical'),
              ),
              const Spacer(),
              _TinyPillButton(
                label: 'Reset',
                color: const Color(0xFF6B7280),
                onTap: _resetGlobalOffsets,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_activeGlobalTab == 'rotate') ...<Widget>[
            _LabeledSlider(
              label: 'Extra Duration',
              value: _globalRotateDuration,
              min: -5,
              max: 10,
              onChanged: (value) =>
                  setState(() => _globalRotateDuration = value),
            ),
            _LabeledSlider(
              label: 'Extra Pause',
              value: _globalRotatePause,
              min: -3,
              max: 5,
              onChanged: (value) => setState(() => _globalRotatePause = value),
            ),
            _LabeledSlider(
              label: 'Extra Rotation Amount',
              value: _globalRotateAmount,
              min: -360,
              max: 360,
              onChanged: (value) => setState(() => _globalRotateAmount = value),
            ),
          ],
          if (_activeGlobalTab == 'horizontal') ...<Widget>[
            _LabeledSlider(
              label: 'Extra Duration',
              value: _globalHorizontalDuration,
              min: -5,
              max: 10,
              onChanged: (value) =>
                  setState(() => _globalHorizontalDuration = value),
            ),
            _LabeledSlider(
              label: 'Extra Distance',
              value: _globalHorizontalDistance,
              min: -200,
              max: 200,
              onChanged: (value) =>
                  setState(() => _globalHorizontalDistance = value),
            ),
          ],
          if (_activeGlobalTab == 'vertical') ...<Widget>[
            _LabeledSlider(
              label: 'Extra Duration',
              value: _globalVerticalDuration,
              min: -5,
              max: 10,
              onChanged: (value) =>
                  setState(() => _globalVerticalDuration = value),
            ),
            _LabeledSlider(
              label: 'Extra Distance',
              value: _globalVerticalDistance,
              min: -200,
              max: 200,
              onChanged: (value) =>
                  setState(() => _globalVerticalDistance = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleBarCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required double step,
    required List<Color> gradient,
    required ValueChanged<double> onChange,
    required bool enabled,
  }) {
    return _SoftCard(
      child: _SingleBar(
        title: title,
        value: value,
        min: min,
        max: max,
        step: step,
        gradient: gradient,
        onChange: onChange,
        enabled: enabled,
      ),
    );
  }

  Widget _buildAccessoryPaletteCard(CatAvatarPart? selectedPart) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Accessory Color Palette',
            style: TextStyle(
              color: Color(0xFF4A2F73),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (selectedPart == null)
            const Text(
              'Select an item first.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (selectedPart != null && _availableColors.isEmpty)
            const Text(
              'No color list in manifest for this item.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (selectedPart != null && _availableColors.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableColors.map((colorName) {
                final active = selectedPart.color == colorName;
                final swatchColor = _colorFromFolderName(colorName);
                final isHex = swatchColor != null;
                return GestureDetector(
                  onTap: () => _changeColor(colorName),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: swatchColor ?? const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? const Color(0xFFEC4899)
                            : const Color(0xFFD1D5DB),
                        width: active ? 3 : 2,
                      ),
                    ),
                    child: !isHex
                        ? Center(
                            child: Text(
                              colorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabsCard() {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Category Tabs',
            style: TextStyle(
              color: Color(0xFF4A2F73),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final category = catCategories[index];
                final selected = category.id == _selectedCategory;
                final hasPart = _parts.containsKey(category.id);
                return GestureDetector(
                  onTap: () => _setCategory(category.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEC4899)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          category.name,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF374151),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasPart) ...<Widget>[
                          const SizedBox(width: 6),
                          Text(
                            'OK',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemCount: catCategories.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGridCard(String categoryName) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            categoryName,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_currentItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No item found in this category.',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (_currentItems.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentItems.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final active = _selectedPart == null;
                  return GestureDetector(
                    onTap: _clearSelection,
                    child: Container(
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFFBCFE8)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? const Color(0xFFEC4899)
                              : const Color(0xFFD1D5DB),
                          width: active ? 3 : 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 26,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                }
                final item = _currentItems[index - 1];
                final selected =
                    _selectedPart?.number == item.number &&
                    _selectedPart?.categoryId == _selectedCategory;
                final previewColor = item.colors.isNotEmpty
                    ? item.colors.first
                    : 'default';
                final image = catImageUrl(
                  categoryId: _selectedCategory,
                  number: item.number,
                  color: previewColor,
                  extension: item.extension,
                );
                return GestureDetector(
                  onTap: () => _selectItem(item),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFBCFE8)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFEC4899)
                            : const Color(0xFFD1D5DB),
                        width: selected ? 3 : 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.network(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) {
                              return Center(
                                child: Text(
                                  '#${item.number}',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            right: 4,
                            bottom: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xAA111827),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.number}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ManifestItem {
  const _ManifestItem({
    required this.number,
    required this.extension,
    required this.colors,
  });

  final int number;
  final String extension;
  final List<String> colors;
}

class _PublishInfo {
  const _PublishInfo({
    required this.publishCount,
    required this.needsCatlove,
    required this.cost,
    required this.catloveBalance,
    required this.level,
  });

  final int publishCount;
  final bool needsCatlove;
  final double cost;
  final double catloveBalance;
  final int level;

  factory _PublishInfo.fromJson(Map<String, dynamic> json) {
    return _PublishInfo(
      publishCount: _asInt(json['publishCount']) ?? 0,
      needsCatlove: json['needsCatlove'] == true,
      cost: _asDouble(json['cost']) ?? 0,
      catloveBalance: _asDouble(json['catloveBalance']) ?? 0,
      level: _asInt(json['level']) ?? 0,
    );
  }
}

class _BoxConfig {
  const _BoxConfig({
    this.enabled = false,
    this.color = '#ffffff',
    this.size = 200,
    this.styleType = 'solid',
    this.borderRadius = 24,
    this.edgeFade = 0,
    this.opacity = 80,
    this.animRotate = false,
    this.animVertical = false,
    this.animHorizontal = false,
    this.animDuration = 3,
    this.animDelay = 0,
    this.animAmount = 20,
    this.animEasing = 'ease-in-out',
  });

  final bool enabled;
  final String color;
  final double size;
  final String styleType;
  final double borderRadius;
  final double edgeFade;
  final double opacity;
  final bool animRotate;
  final bool animVertical;
  final bool animHorizontal;
  final double animDuration;
  final double animDelay;
  final double animAmount;
  final String animEasing;

  _BoxConfig copyWith({
    bool? enabled,
    String? color,
    double? size,
    String? styleType,
    double? borderRadius,
    double? edgeFade,
    double? opacity,
    bool? animRotate,
    bool? animVertical,
    bool? animHorizontal,
    double? animDuration,
    double? animDelay,
    double? animAmount,
    String? animEasing,
  }) {
    return _BoxConfig(
      enabled: enabled ?? this.enabled,
      color: color ?? this.color,
      size: size ?? this.size,
      styleType: styleType ?? this.styleType,
      borderRadius: borderRadius ?? this.borderRadius,
      edgeFade: edgeFade ?? this.edgeFade,
      opacity: opacity ?? this.opacity,
      animRotate: animRotate ?? this.animRotate,
      animVertical: animVertical ?? this.animVertical,
      animHorizontal: animHorizontal ?? this.animHorizontal,
      animDuration: animDuration ?? this.animDuration,
      animDelay: animDelay ?? this.animDelay,
      animAmount: animAmount ?? this.animAmount,
      animEasing: animEasing ?? this.animEasing,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'color': color,
    'size': size,
    'styleType': styleType,
    'borderRadius': borderRadius,
    'edgeFade': edgeFade,
    'opacity': opacity,
    'animRotate': animRotate,
    'animVertical': animVertical,
    'animHorizontal': animHorizontal,
    'animDuration': animDuration,
    'animDelay': animDelay,
    'animAmount': animAmount,
    'animEasing': animEasing,
  };
}

class _EasingOption {
  const _EasingOption({required this.value, required this.label});

  final String value;
  final String label;
}

const List<_EasingOption> _easingOptions = <_EasingOption>[
  _EasingOption(value: 'linear', label: 'Linear'),
  _EasingOption(value: 'ease', label: 'Ease'),
  _EasingOption(value: 'ease-in', label: 'Ease In'),
  _EasingOption(value: 'ease-out', label: 'Ease Out'),
  _EasingOption(value: 'ease-in-out', label: 'Ease In-Out'),
  _EasingOption(
    value: 'cubic-bezier(0.68, -0.55, 0.265, 1.55)',
    label: 'Ease Back',
  ),
  _EasingOption(
    value: 'cubic-bezier(0.6, -0.28, 0.735, 0.045)',
    label: 'Ease In Back',
  ),
  _EasingOption(
    value: 'cubic-bezier(0.175, 0.885, 0.32, 1.275)',
    label: 'Ease Out Back',
  ),
];

CatAvatarPart _copyWith(
  CatAvatarPart current, {
  int? number,
  String? color,
  String? extension,
  double? x,
  double? y,
  double? scaleX,
  double? scaleY,
  double? hueRotate,
  double? rotation,
  double? brightness,
  double? saturation,
  double? opacity,
  double? glowRadius,
  double? glowIntensity,
  bool? animationEnabled,
  double? animationDuration,
  String? animationEasing,
  double? animationDelay,
  double? rotationAmount,
  double? rotationStartDelay,
  bool? rotationReverse,
  String? rotationPauseMode,
  double? transformOriginX,
  double? transformOriginY,
  bool? positionXAnimationEnabled,
  double? positionXAnimationDuration,
  double? positionXAnimationAmount,
  String? positionXAnimationEasing,
  double? positionXStartDelay,
  bool? positionYAnimationEnabled,
  double? positionYAnimationDuration,
  double? positionYAnimationAmount,
  String? positionYAnimationEasing,
  double? positionYStartDelay,
}) {
  return CatAvatarPart(
    categoryId: current.categoryId,
    number: number ?? current.number,
    color: color ?? current.color,
    extension: extension ?? current.extension,
    x: x ?? current.x,
    y: y ?? current.y,
    scaleX: scaleX ?? current.scaleX,
    scaleY: scaleY ?? current.scaleY,
    hueRotate: hueRotate ?? current.hueRotate,
    rotation: rotation ?? current.rotation,
    brightness: brightness ?? current.brightness,
    saturation: saturation ?? current.saturation,
    opacity: opacity ?? current.opacity,
    glowRadius: glowRadius ?? current.glowRadius,
    glowIntensity: glowIntensity ?? current.glowIntensity,
    animationEnabled: animationEnabled ?? current.animationEnabled,
    animationDuration: animationDuration ?? current.animationDuration,
    animationEasing: animationEasing ?? current.animationEasing,
    animationDelay: animationDelay ?? current.animationDelay,
    rotationAmount: rotationAmount ?? current.rotationAmount,
    rotationStartDelay: rotationStartDelay ?? current.rotationStartDelay,
    rotationReverse: rotationReverse ?? current.rotationReverse,
    rotationPauseMode: rotationPauseMode ?? current.rotationPauseMode,
    transformOriginX: transformOriginX ?? current.transformOriginX,
    transformOriginY: transformOriginY ?? current.transformOriginY,
    positionXAnimationEnabled:
        positionXAnimationEnabled ?? current.positionXAnimationEnabled,
    positionXAnimationDuration:
        positionXAnimationDuration ?? current.positionXAnimationDuration,
    positionXAnimationAmount:
        positionXAnimationAmount ?? current.positionXAnimationAmount,
    positionXAnimationEasing:
        positionXAnimationEasing ?? current.positionXAnimationEasing,
    positionXStartDelay: positionXStartDelay ?? current.positionXStartDelay,
    positionYAnimationEnabled:
        positionYAnimationEnabled ?? current.positionYAnimationEnabled,
    positionYAnimationDuration:
        positionYAnimationDuration ?? current.positionYAnimationDuration,
    positionYAnimationAmount:
        positionYAnimationAmount ?? current.positionYAnimationAmount,
    positionYAnimationEasing:
        positionYAnimationEasing ?? current.positionYAnimationEasing,
    positionYStartDelay: positionYStartDelay ?? current.positionYStartDelay,
  );
}

Color _hexToColor(String raw) {
  var hex = raw.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return const Color(0xFFCCCCCC);
  return Color(int.parse(hex, radix: 16));
}

Color? _colorFromFolderName(String folder) {
  final only = folder.trim().replaceAll('#', '');
  if (only.length == 6 && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(only)) {
    return _hexToColor('#$only');
  }
  if (only.length == 8 && RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(only)) {
    return _hexToColor('#$only');
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class DeepCollectionEquality {
  const DeepCollectionEquality();

  bool equals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!equals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!equals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

class _CreateHeader extends StatelessWidget {
  const _CreateHeader({
    required this.saving,
    required this.saveSuccess,
    required this.publishing,
    required this.publishSuccess,
    required this.hasParts,
    required this.onBack,
    required this.onSave,
    required this.onPublish,
    required this.isEditing,
  });

  final bool saving;
  final bool saveSuccess;
  final bool publishing;
  final bool publishSuccess;
  final bool hasParts;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onPublish;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return GlassHeaderShell(
      backgroundColor: const Color(0x1FFFFFFF),
      borderColor: const Color(0x40FFB8A5),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x29462C71),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.arrow_back_rounded, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Back to Gallery',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _HeaderAction(
            label: saving
                ? 'Saving...'
                : saveSuccess
                ? 'Saved!'
                : isEditing
                ? 'Update Cat'
                : 'Save Your Cat',
            enabled: hasParts && !saving,
            color: saveSuccess
                ? const Color(0xFF22C55E)
                : const Color(0xFF3B82F6),
            onTap: onSave,
          ),
          const SizedBox(width: 8),
          _HeaderAction(
            label: publishing
                ? 'Publishing...'
                : publishSuccess
                ? 'Published!'
                : 'Publish Your Cat',
            enabled: hasParts && !publishing,
            color: publishSuccess
                ? const Color(0xFF22C55E)
                : const Color(0xFFEC4899),
            onTap: onPublish,
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xD1FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33948BAF)),
      ),
      child: child,
    );
  }
}

class _TinyPillButton extends StatelessWidget {
  const _TinyPillButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEC4899) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFEC4899) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SavedSettingsStrip extends StatelessWidget {
  const _SavedSettingsStrip({required this.settings, required this.onApply});

  final List<Map<String, dynamic>> settings;
  final ValueChanged<Map<String, dynamic>> onApply;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Saved Settings',
            style: TextStyle(
              color: Color(0xFF4A2F73),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(settings.length, (index) {
              final setting = settings[index];
              final hue = (_asDouble(setting['hueRotate']) ?? 0).round();
              final sat = (_asDouble(setting['saturation']) ?? 1).clamp(
                0.2,
                2.0,
              );
              final bright = (_asDouble(setting['brightness']) ?? 1).clamp(
                0.3,
                2.0,
              );
              final opacity = (_asDouble(setting['opacity']) ?? 1).clamp(
                0.2,
                1.0,
              );
              final colorA = HSLColor.fromAHSL(
                opacity,
                hue.toDouble(),
                0.7 * sat,
                (0.48 * bright).clamp(0.2, 0.85),
              ).toColor();
              final colorB = HSLColor.fromAHSL(
                opacity,
                (hue + 35).toDouble(),
                0.68 * sat,
                (0.58 * bright).clamp(0.2, 0.92),
              ).toColor();
              return GestureDetector(
                onTap: () => onApply(setting),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[colorA, colorB],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA111827),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFD1D5DB),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0xFF6B7280),
          size: 22,
        ),
      ),
    );
  }
}

class _FrameDecorations extends StatelessWidget {
  const _FrameDecorations();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 4),
        ),
      ),
    );
  }
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _VerticalBarControl extends StatelessWidget {
  const _VerticalBarControl({
    required this.height,
    required this.width,
    required this.plusColor,
    required this.minusColor,
    required this.gradient,
    required this.valuePercent,
    required this.enabled,
    required this.onPlus,
    required this.onMinus,
    required this.onChanged,
  });

  final double height;
  final double width;
  final Color plusColor;
  final Color minusColor;
  final Gradient gradient;
  final double valuePercent;
  final bool enabled;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MiniSquareButton(
          label: '+',
          color: plusColor,
          enabled: enabled,
          onTap: onPlus,
        ),
        const SizedBox(height: 6),
        _VerticalBarTrack(
          height: height,
          width: width,
          gradient: gradient,
          valuePercent: valuePercent,
          enabled: enabled,
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        _MiniSquareButton(
          label: '-',
          color: minusColor,
          enabled: enabled,
          onTap: onMinus,
        ),
      ],
    );
  }
}

class _VerticalBarTrack extends StatelessWidget {
  const _VerticalBarTrack({
    required this.height,
    required this.width,
    required this.gradient,
    required this.valuePercent,
    required this.enabled,
    required this.onChanged,
  });

  final double height;
  final double width;
  final Gradient gradient;
  final double valuePercent;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: enabled
          ? (details) => _notify(context, details.globalPosition)
          : null,
      onVerticalDragUpdate: enabled
          ? (details) => _notify(context, details.globalPosition)
          : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: valuePercent.clamp(0, 1).toDouble() * (height - 2),
              child: Container(height: 2, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _notify(BuildContext context, Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    onChanged((local.dy / height).clamp(0, 1).toDouble());
  }
}

class _MiniSquareButton extends StatelessWidget {
  const _MiniSquareButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : const Color(0xFF6B7280),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _JoystickControl extends StatelessWidget {
  const _JoystickControl({required this.enabled, required this.onMove});

  final bool enabled;
  final ValueChanged<String> onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _MiniSquareButton(
          label: '^',
          color: const Color(0xFF8B5CF6),
          enabled: enabled,
          onTap: () => onMove('up'),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            _MiniSquareButton(
              label: '<',
              color: const Color(0xFF8B5CF6),
              enabled: enabled,
              onTap: () => onMove('left'),
            ),
            const SizedBox(width: 4),
            _MiniSquareButton(
              label: 'v',
              color: const Color(0xFF8B5CF6),
              enabled: enabled,
              onTap: () => onMove('down'),
            ),
            const SizedBox(width: 4),
            _MiniSquareButton(
              label: '>',
              color: const Color(0xFF8B5CF6),
              enabled: enabled,
              onTap: () => onMove('right'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScaleControlPanel extends StatelessWidget {
  const _ScaleControlPanel({
    required this.enabled,
    required this.valueX,
    required this.valueY,
    required this.onPlusX,
    required this.onMinusX,
    required this.onPlusY,
    required this.onMinusY,
    required this.onChangeX,
    required this.onChangeY,
  });

  final bool enabled;
  final double valueX;
  final double valueY;
  final VoidCallback onPlusX;
  final VoidCallback onMinusX;
  final VoidCallback onPlusY;
  final VoidCallback onMinusY;
  final ValueChanged<double> onChangeX;
  final ValueChanged<double> onChangeY;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ScaleRow(
          axis: 'X',
          enabled: enabled,
          value: valueX,
          onPlus: onPlusX,
          onMinus: onMinusX,
          onChange: onChangeX,
        ),
        const SizedBox(height: 4),
        _ScaleRow(
          axis: 'Y',
          enabled: enabled,
          value: valueY,
          onPlus: onPlusY,
          onMinus: onMinusY,
          onChange: onChangeY,
        ),
      ],
    );
  }
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.axis,
    required this.enabled,
    required this.value,
    required this.onPlus,
    required this.onMinus,
    required this.onChange,
  });

  final String axis;
  final bool enabled;
  final double value;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final ValueChanged<double> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            axis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _MiniSquareButton(
          label: '-',
          color: const Color(0xFFEC4899),
          enabled: enabled,
          onTap: onMinus,
        ),
        const SizedBox(width: 4),
        _HorizontalBarMini(value: value, enabled: enabled, onChanged: onChange),
        const SizedBox(width: 4),
        _MiniSquareButton(
          label: '+',
          color: const Color(0xFFEC4899),
          enabled: enabled,
          onTap: onPlus,
        ),
      ],
    );
  }
}

class _HorizontalBarMini extends StatelessWidget {
  const _HorizontalBarMini({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: enabled
          ? (details) => _notify(context, details.globalPosition)
          : null,
      onHorizontalDragUpdate: enabled
          ? (details) => _notify(context, details.globalPosition)
          : null,
      child: Container(
        width: 74,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0x88FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _notify(BuildContext context, Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    onChanged((local.dx / box.size.width).clamp(0, 1).toDouble());
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.value,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.onChanged,
  });

  final String value;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final leftActive = value == leftValue;
    final rightActive = value == rightValue;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => onChanged(leftValue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: leftActive
                    ? const Color(0xFFEC4899)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                leftLabel,
                style: TextStyle(
                  color: leftActive ? Colors.white : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(rightValue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rightActive
                    ? const Color(0xFF3B82F6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                rightLabel,
                style: TextStyle(
                  color: rightActive ? Colors.white : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF4A2F73),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              clamped.toStringAsFixed(2),
              style: const TextStyle(
                color: Color(0xFF6D4AA3),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(value: clamped, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _AnimationTabContent extends StatelessWidget {
  const _AnimationTabContent({
    required this.part,
    required this.activeTab,
    required this.isPickingOrigin,
    required this.onTogglePickOrigin,
    required this.onResetOrigin,
    required this.onChange,
  });

  final CatAvatarPart part;
  final String activeTab;
  final bool isPickingOrigin;
  final VoidCallback onTogglePickOrigin;
  final VoidCallback onResetOrigin;
  final ValueChanged<CatAvatarPart> onChange;

  @override
  Widget build(BuildContext context) {
    if (activeTab == 'rotation') {
      return Column(
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Rotation Animation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            value: part.animationEnabled,
            onChanged: (value) =>
                onChange(_copyWith(part, animationEnabled: value)),
          ),
          if (part.animationEnabled) ...<Widget>[
            _LabeledSlider(
              label: 'Start Delay',
              value: part.rotationStartDelay,
              min: 0,
              max: 10,
              onChanged: (v) =>
                  onChange(_copyWith(part, rotationStartDelay: v)),
            ),
            _LabeledSlider(
              label: 'Duration',
              value: part.animationDuration,
              min: 0.1,
              max: 10,
              onChanged: (v) => onChange(_copyWith(part, animationDuration: v)),
            ),
            _LabeledSlider(
              label: 'Pause Between Loops',
              value: part.animationDelay,
              min: 0,
              max: 5,
              onChanged: (v) => onChange(_copyWith(part, animationDelay: v)),
            ),
            _LabeledSlider(
              label: 'Rotation Amount',
              value: part.rotationAmount,
              min: 0,
              max: 1080,
              onChanged: (v) => onChange(_copyWith(part, rotationAmount: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Reverse Loop',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: part.rotationReverse,
              onChanged: (value) =>
                  onChange(_copyWith(part, rotationReverse: value)),
            ),
            if (part.rotationReverse)
              Row(
                children: <Widget>[
                  const Text(
                    'Pause Mode:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        _ChoiceChip(
                          label: 'After Cycle',
                          selected: part.rotationPauseMode == 'afterCycle',
                          onTap: () => onChange(
                            _copyWith(part, rotationPauseMode: 'afterCycle'),
                          ),
                        ),
                        _ChoiceChip(
                          label: 'Each Direction',
                          selected:
                              part.rotationPauseMode == 'betweenDirections',
                          onTap: () => onChange(
                            _copyWith(
                              part,
                              rotationPauseMode: 'betweenDirections',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    part.transformOriginX == 50 && part.transformOriginY == 50
                        ? 'Transform Origin: center'
                        : 'Transform Origin: ${part.transformOriginX.round()}%, ${part.transformOriginY.round()}%',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                _TinyPillButton(
                  label: isPickingOrigin ? 'Picking' : 'Pick Point',
                  color: isPickingOrigin
                      ? const Color(0xFFF97316)
                      : const Color(0xFFFB923C),
                  onTap: onTogglePickOrigin,
                ),
                const SizedBox(width: 6),
                _TinyPillButton(
                  label: 'Reset',
                  color: const Color(0xFF6B7280),
                  onTap: onResetOrigin,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Easing',
                style: TextStyle(
                  color: Color(0xFF4A2F73),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _easingOptions
                  .map(
                    (option) => _ChoiceChip(
                      label: option.label,
                      selected: part.animationEasing == option.value,
                      onTap: () => onChange(
                        _copyWith(part, animationEasing: option.value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      );
    }

    return Column(
      children: <Widget>[
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Horizontal Movement',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          value: part.positionXAnimationEnabled,
          onChanged: (value) =>
              onChange(_copyWith(part, positionXAnimationEnabled: value)),
        ),
        if (part.positionXAnimationEnabled) ...<Widget>[
          _LabeledSlider(
            label: 'Start Delay',
            value: part.positionXStartDelay,
            min: 0,
            max: 10,
            onChanged: (v) => onChange(_copyWith(part, positionXStartDelay: v)),
          ),
          _LabeledSlider(
            label: 'Duration',
            value: part.positionXAnimationDuration,
            min: 0.1,
            max: 10,
            onChanged: (v) =>
                onChange(_copyWith(part, positionXAnimationDuration: v)),
          ),
          _LabeledSlider(
            label: 'Distance',
            value: part.positionXAnimationAmount,
            min: 10,
            max: 200,
            onChanged: (v) =>
                onChange(_copyWith(part, positionXAnimationAmount: v)),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Vertical Movement',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          value: part.positionYAnimationEnabled,
          onChanged: (value) =>
              onChange(_copyWith(part, positionYAnimationEnabled: value)),
        ),
        if (part.positionYAnimationEnabled) ...<Widget>[
          _LabeledSlider(
            label: 'Start Delay',
            value: part.positionYStartDelay,
            min: 0,
            max: 10,
            onChanged: (v) => onChange(_copyWith(part, positionYStartDelay: v)),
          ),
          _LabeledSlider(
            label: 'Duration',
            value: part.positionYAnimationDuration,
            min: 0.1,
            max: 10,
            onChanged: (v) =>
                onChange(_copyWith(part, positionYAnimationDuration: v)),
          ),
          _LabeledSlider(
            label: 'Distance',
            value: part.positionYAnimationAmount,
            min: 10,
            max: 200,
            onChanged: (v) =>
                onChange(_copyWith(part, positionYAnimationAmount: v)),
          ),
        ],
      ],
    );
  }
}

class _SingleBar extends StatelessWidget {
  const _SingleBar({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.gradient,
    required this.onChange,
    required this.enabled,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final double step;
  final List<Color> gradient;
  final ValueChanged<double> onChange;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4A2F73),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _MiniCircle(
              label: '-',
              onTap: enabled
                  ? () => onChange((clamped - step).clamp(min, max).toDouble())
                  : null,
            ),
            Expanded(
              child: Container(
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: clamped,
                    min: min,
                    max: max,
                    onChanged: enabled ? onChange : null,
                  ),
                ),
              ),
            ),
            _MiniCircle(
              label: '+',
              onTap: enabled
                  ? () => onChange((clamped + step).clamp(min, max).toDouble())
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniCircle extends StatelessWidget {
  const _MiniCircle({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF8B5CF6) : const Color(0xFFD1D5DB),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : const Color(0xFF6B7280),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoRedoButton extends StatelessWidget {
  const _UndoRedoButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF97316) : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: enabled ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishPopup extends StatelessWidget {
  const _PublishPopup({
    required this.avatarData,
    required this.backgroundColor,
    required this.descriptionController,
    required this.publishing,
    required this.publishInfo,
    required this.boxConfig,
    required this.onBoxConfigChanged,
    required this.onCancel,
    required this.onPublish,
    required this.hasAnimation,
  });

  final Map<String, dynamic> avatarData;
  final Color backgroundColor;
  final TextEditingController descriptionController;
  final bool publishing;
  final _PublishInfo? publishInfo;
  final _BoxConfig boxConfig;
  final ValueChanged<_BoxConfig> onBoxConfigChanged;
  final VoidCallback onCancel;
  final VoidCallback onPublish;
  final bool hasAnimation;

  @override
  Widget build(BuildContext context) {
    final info = publishInfo;
    final needsCatlove = info?.needsCatlove ?? false;
    final canAfford = !needsCatlove || (info!.catloveBalance >= info.cost);

    return Positioned.fill(
      child: Container(
        color: const Color(0x99000000),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Publish Your Cat',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (info != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Published: ${info.publishCount}, Level: ${info.level}, Cost: ${info.cost}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Positioned.fill(
                            child: Container(color: const Color(0xFFFFD1E3)),
                          ),
                          if (boxConfig.enabled)
                            Container(
                              width: boxConfig.size,
                              height: boxConfig.size,
                              decoration: BoxDecoration(
                                color: _hexToColor(
                                  boxConfig.color,
                                ).withValues(alpha: boxConfig.opacity / 100),
                                borderRadius: BorderRadius.circular(
                                  boxConfig.borderRadius,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 190,
                            height: 190,
                            child: AnimatedCatAvatar(
                              avatarData: avatarData,
                              backgroundColor: Colors.transparent,
                              animationsEnabled: true,
                              effectsEnabled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Box'),
                    value: boxConfig.enabled,
                    onChanged: (value) =>
                        onBoxConfigChanged(boxConfig.copyWith(enabled: value)),
                  ),
                  if (boxConfig.enabled) ...<Widget>[
                    _LabeledSlider(
                      label: 'Size',
                      value: boxConfig.size,
                      min: 80,
                      max: 320,
                      onChanged: (v) =>
                          onBoxConfigChanged(boxConfig.copyWith(size: v)),
                    ),
                    _LabeledSlider(
                      label: 'Opacity',
                      value: boxConfig.opacity,
                      min: 0,
                      max: 100,
                      onChanged: (v) =>
                          onBoxConfigChanged(boxConfig.copyWith(opacity: v)),
                    ),
                    _LabeledSlider(
                      label: 'Corner Radius',
                      value: boxConfig.borderRadius,
                      min: 0,
                      max: 80,
                      onChanged: (v) => onBoxConfigChanged(
                        boxConfig.copyWith(borderRadius: v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: (!canAfford || publishing)
                              ? null
                              : onPublish,
                          child: Text(publishing ? 'Publishing...' : 'Publish'),
                        ),
                      ),
                    ],
                  ),
                  if (hasAnimation)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Animation effects are preserved in publish payload.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportPopup extends StatefulWidget {
  const _ExportPopup({required this.onClose, required this.onExport});

  final VoidCallback onClose;
  final ValueChanged<int> onExport;

  @override
  State<_ExportPopup> createState() => _ExportPopupState();
}

class _ExportPopupState extends State<_ExportPopup> {
  int _adsWatched = 0;
  final bool _isPremium = false;

  static const List<_FpsTier> _tiers = <_FpsTier>[
    _FpsTier(fps: 30, requiredAds: 0),
    _FpsTier(fps: 60, requiredAds: 1),
    _FpsTier(fps: 120, requiredAds: 4),
    _FpsTier(fps: 144, requiredAds: 5),
  ];

  bool _isUnlocked(_FpsTier tier) =>
      _isPremium || _adsWatched >= tier.requiredAds;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0x99000000),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Export Video',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (!_isPremium)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Ads watched: $_adsWatched/5'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => setState(
                              () => _adsWatched = (_adsWatched + 1).clamp(0, 5),
                            ),
                            child: const Text('Watch Rewarded Ad'),
                          ),
                        ],
                      ),
                    ),
                  ..._tiers.map((tier) {
                    final unlocked = _isUnlocked(tier);
                    final progress = tier.requiredAds == 0
                        ? 1.0
                        : (_adsWatched / tier.requiredAds)
                              .clamp(0, 1)
                              .toDouble();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: unlocked
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                '${tier.fps} FPS',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(unlocked ? 'Unlocked' : 'Locked'),
                            ],
                          ),
                          if (!unlocked) ...<Widget>[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 4),
                            Text(
                              '$_adsWatched/${tier.requiredAds} ads watched',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: unlocked
                                ? () => widget.onExport(tier.fps)
                                : null,
                            child: Text('Export ${tier.fps} FPS'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FpsTier {
  const _FpsTier({required this.fps, required this.requiredAds});

  final int fps;
  final int requiredAds;
}
