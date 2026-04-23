// Editor modunun beyin'i. Global state burada:
// - enabled: Editor modu acik mi?
// - selectedId: Hangi EditableWidget secili?
// - widgetStates: Her widget'in yasayan property map'i (persistence yok)
// - variantOverrides: Hangi widget hangi varyanti kullaniyor
//
// Kullanici widget'a sag tik yapinca selectPath cagrilir, PropertyPanel buna
// reaksiyon verip ilgili editor'leri acar. Property degistiginde
// updateProperty cagrilir, widget ChangeNotifier'i dinledigi icin rebuild
// eder. JSON export/import burada gerceklesir.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Editor global state. MultiProvider ustunde Consumer ile dinlenir.
class EditorController extends ChangeNotifier {
  EditorController();

  /// Editor modu AcikKapali. Ctrl+E ile toggle olur.
  bool _enabled = false;
  bool get enabled => _enabled;

  /// Panel kapali mi? (Enabled ama panel minimize edilmis olabilir)
  bool _panelOpen = true;
  bool get panelOpen => _panelOpen;

  /// Secili widget'in id'si. null ise hicbir sey secili degil.
  String? _selectedId;
  String? get selectedId => _selectedId;

  /// Hover edilen widget'in id'si (highlight icin).
  String? _hoveredId;
  String? get hoveredId => _hoveredId;

  /// Her widget icin yasayan property map.
  /// Key: widget id (ornek: 'bottom-nav-main')
  /// Value: { 'shellColor': 0xE0F7E7F9, 'blurSigma': 20, ... }
  final Map<String, Map<String, dynamic>> _widgetStates = {};
  Map<String, dynamic> propsOf(String id) => _widgetStates[id] ?? const {};

  /// Widget id -> aktif varyant ismi.
  final Map<String, String> _variantOverrides = {};
  String? variantOf(String id) => _variantOverrides[id];

  /// Widget id -> widget tipi (ActionButton, CatBottomNav, PageGradient...)
  final Map<String, String> _widgetTypes = {};
  String? typeOf(String id) => _widgetTypes[id];
  List<String> get registeredWidgetIds {
    final ids = _widgetTypes.keys.toList()..sort();
    return ids;
  }

  /// Property panel'in pozisyonu (draggable).
  Offset _panelPosition = const Offset(20, 80);
  Offset get panelPosition => _panelPosition;

  /// Editable widget build edilirken tip + ilk props bilgisini kaydeder.
  /// notify yapmaz, build dongusunu bozmaz.
  void registerWidget({
    required String id,
    required String typeName,
    Map<String, dynamic>? initialProps,
  }) {
    _widgetTypes[id] = typeName;
    if (!_widgetStates.containsKey(id) && initialProps != null) {
      _widgetStates[id] = Map<String, dynamic>.from(initialProps);
    }
  }

  // ── Mutators ──────────────────────────────────────────────────────────────

  void toggle() {
    _enabled = !_enabled;
    if (!_enabled) {
      _selectedId = null;
      _hoveredId = null;
    }
    notifyListeners();
  }

  void togglePanel() {
    _panelOpen = !_panelOpen;
    notifyListeners();
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void setHovered(String? id) {
    if (_hoveredId == id) return;
    _hoveredId = id;
    notifyListeners();
  }

  void setPanelPosition(Offset p) {
    _panelPosition = p;
    notifyListeners();
  }

  /// Bir widget'in property'sini gunceller.
  void updateProperty(String widgetId, String propertyKey, dynamic value) {
    final current = Map<String, dynamic>.from(_widgetStates[widgetId] ?? {});
    current[propertyKey] = value;
    _widgetStates[widgetId] = current;
    notifyListeners();
  }

  /// Tum property'leri birden set eder (ornek: varyant uygulama).
  void setProperties(String widgetId, Map<String, dynamic> props) {
    _widgetStates[widgetId] = Map<String, dynamic>.from(props);
    notifyListeners();
  }

  /// Varyant degistirir. Varyant defaults'unu JSON'dan almaniz gerekebilir.
  void setVariant(
    String widgetId,
    String variantName, {
    Map<String, dynamic>? defaults,
  }) {
    _variantOverrides[widgetId] = variantName;
    if (defaults != null) {
      _widgetStates[widgetId] = Map<String, dynamic>.from(defaults);
    }
    notifyListeners();
  }

  /// Widget'in tum ayarlarini sifirlar (kod'daki default'a doner).
  void resetWidget(String widgetId) {
    _widgetStates.remove(widgetId);
    _variantOverrides.remove(widgetId);
    notifyListeners();
  }

  /// Tum editor state'i sifirlar.
  void resetAll() {
    _widgetStates.clear();
    _variantOverrides.clear();
    _widgetTypes.clear();
    _selectedId = null;
    notifyListeners();
  }

  // ── JSON Export / Import ──────────────────────────────────────────────────

  /// Suanki sayfanin tum editor state'ini JSON'a cevirir.
  /// pageRoute: '/home', '/create' vs. (etiket icin)
  String exportJson({String? pageRoute}) {
    final out = <String, dynamic>{
      'page': pageRoute ?? 'unknown',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'widgets': <String, dynamic>{},
    };
    final widgets = out['widgets'] as Map<String, dynamic>;
    for (final id in _widgetStates.keys) {
      widgets[id] = <String, dynamic>{
        if (_widgetTypes[id] != null) 'type': _widgetTypes[id],
        if (_variantOverrides[id] != null) 'variant': _variantOverrides[id],
        'props': _widgetStates[id],
      };
    }
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  /// JSON'u clipboard'a kopyalar. Return: basarili mi?
  Future<bool> copyExportToClipboard({String? pageRoute}) async {
    final json = exportJson(pageRoute: pageRoute);
    await Clipboard.setData(ClipboardData(text: json));
    return true;
  }

  /// JSON'dan state yukler. Hata durumunda false doner ve errorMessage set edilir.
  String? _lastError;
  String? get lastError => _lastError;

  bool applyJson(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        _lastError = 'JSON kok nesne olmali.';
        notifyListeners();
        return false;
      }
      final widgets = parsed['widgets'];
      if (widgets is! Map<String, dynamic>) {
        _lastError = '"widgets" alani Map olmali.';
        notifyListeners();
        return false;
      }

      _widgetStates.clear();
      _variantOverrides.clear();

      for (final entry in widgets.entries) {
        final v = entry.value;
        if (v is! Map<String, dynamic>) continue;
        final variant = v['variant'];
        final props = v['props'];
        if (variant is String) {
          _variantOverrides[entry.key] = variant;
        }
        if (props is Map<String, dynamic>) {
          _widgetStates[entry.key] = Map<String, dynamic>.from(props);
        }
      }

      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Parse hatasi: $e';
      notifyListeners();
      return false;
    }
  }
}
