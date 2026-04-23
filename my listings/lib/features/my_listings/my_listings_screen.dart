import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/cache/runtime_cache.dart';
import '../../core/monetization/native_monetization_bridge.dart';
import '../../core/network/api_client.dart';
import '../../editor/editable_widget.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../avatar/animated_cat_avatar.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/models.dart';
import '../shared/widgets/market_background.dart';

const Duration _kMyListingsCacheTtl = Duration(minutes: 3);
const int _kMaxAdsPerDay = 5;
const double _kCatpoisonToCatlove = 40;

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final RuntimeCache _cache = RuntimeCache.instance;

  AuthController? _auth;
  bool _didInit = false;
  String _userScope = 'anon';

  bool _loading = true;
  bool _watchingAd = false;
  bool _processing = false;
  String _tab = 'active';
  String? _adError;
  double _cpBalance = 0;
  int _adsToday = 0;

  List<AvatarRecord> _activeListings = const [];
  List<AvatarRecord> _soldListings = const [];

  AvatarRecord? _boostConfirmListing;
  int? _boostingListingId;

  String _cacheKey() =>
      'my-listings:data:${_userScope.isEmpty ? 'anon' : _userScope}';
  String get _cacheLastKey => 'my-listings:data:last';
  bool get _signedIn => _auth?.isSignedIn ?? false;

  MeowverseApi _api() => MeowverseApi(context.read<ApiClient>());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAuth = context.read<AuthController>();
    if (!identical(_auth, nextAuth)) {
      _auth?.removeListener(_handleAuthChanged);
      _auth = nextAuth;
      _auth?.addListener(_handleAuthChanged);
    }
    if (!_didInit) {
      _handleAuthChanged();
      _didInit = true;
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final nextScope = _signedIn ? (_auth?.user?.id ?? 'anon') : 'anon';
    if (_userScope == nextScope && _didInit) return;
    _userScope = nextScope;

    if (!_signedIn) {
      setState(() {
        _loading = false;
        _cpBalance = 0;
        _adsToday = 0;
        _activeListings = const [];
        _soldListings = const [];
      });
      return;
    }
    _bootstrapFromCacheAndFetch();
  }

  Future<void> _bootstrapFromCacheAndFetch() async {
    final cached =
        _cache.get<Map<String, dynamic>>(_cacheKey()) ??
        _cache.get<Map<String, dynamic>>(_cacheLastKey);
    final hasCached =
        cached != null &&
        (((cached['activeListings'] as List?)?.isNotEmpty ?? false) ||
            ((cached['soldListings'] as List?)?.isNotEmpty ?? false));

    if (cached != null) {
      _applyCacheSnapshot(cached);
    } else {
      setState(() => _loading = true);
    }

    await _loadListings(silent: hasCached);
    await _loadCpBalance();
  }

  void _applyCacheSnapshot(Map<String, dynamic> cache) {
    final active = ((cache['activeListings'] as List?) ?? const [])
        .whereType<AvatarRecord>()
        .toList();
    final sold = ((cache['soldListings'] as List?) ?? const [])
        .whereType<AvatarRecord>()
        .toList();
    final cp = _toDouble(cache['cpBalance']) ?? _cpBalance;
    setState(() {
      _activeListings = active;
      _soldListings = sold;
      _cpBalance = cp;
      _loading = false;
    });
  }

  void _writeCacheSnapshot() {
    final snapshot = <String, dynamic>{
      'activeListings': _activeListings,
      'soldListings': _soldListings,
      'cpBalance': _cpBalance,
    };
    _cache.put<Map<String, dynamic>>(
      _cacheKey(),
      snapshot,
      _kMyListingsCacheTtl,
    );
    _cache.put<Map<String, dynamic>>(
      _cacheLastKey,
      snapshot,
      _kMyListingsCacheTtl,
    );
  }

  Future<void> _loadListings({bool silent = false}) async {
    if (!_signedIn) return;
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final data = await _api().fetchMyListings();
      if (!mounted) return;
      setState(() {
        _activeListings = data.active;
        _soldListings = data.sold;
      });
      _writeCacheSnapshot();
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCpBalance() async {
    if (!_signedIn) return;
    try {
      final balance = await _api().fetchCatpoisonBalance();
      if (!mounted) return;
      setState(() {
        _cpBalance = balance.balance;
        _adsToday = balance.watchedToday;
      });
      _writeCacheSnapshot();
    } catch (_) {
      // Keep current values if this fetch fails.
    }
  }

  Future<void> _watchAdForCp() async {
    if (_watchingAd || !_signedIn) return;
    setState(() {
      _watchingAd = true;
      _adError = null;
    });
    try {
      final adCompleted = await _runRewardedAdWithWebFallback();
      if (!adCompleted) {
        if (!mounted) return;
        setState(
          () => _adError = 'Please watch the full ad to receive the reward.',
        );
        return;
      }

      final result = await _api().watchAdForCp();
      if (!mounted) return;
      setState(() {
        _cpBalance = _toDouble(result['newBalance']) ?? _cpBalance;
        _adsToday = _toInt(result['watchedToday']) ?? _adsToday;
      });
      _writeCacheSnapshot();

      final awarded =
          result['cpAwarded'] == true || (result['earned'] ?? 0) > 0;
      if (awarded) {
        _showToast('5 ads completed. +1 CP earned.');
      } else {
        _showToast('Ad watched. (${_adsToday.toString()}/$_kMaxAdsPerDay)');
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _adError = _toEnglishError(err));
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  Future<bool> _runRewardedAdWithWebFallback() async {
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return true;
    }
    return NativeMonetizationBridge.showRewardedAd();
  }

  void _openBoostConfirm(AvatarRecord listing) {
    setState(() {
      _adError = null;
      _boostConfirmListing = listing;
    });
  }

  Future<void> _startBoostFlow() async {
    final listing = _boostConfirmListing;
    if (listing == null) return;
    setState(() {
      _boostConfirmListing = null;
      _processing = true;
      _boostingListingId = listing.listingId ?? listing.id;
    });
    try {
      final adCompleted = await _runRewardedAdWithWebFallback();
      if (!adCompleted) {
        if (!mounted) return;
        setState(() => _adError = 'Please watch the full ad to apply boost.');
        return;
      }
      await _api().boostMarketListing(listing.listingId ?? listing.id);
      if (!mounted) return;
      _showToast('Listing boosted in market feed.');
      await _loadListings();
    } catch (err) {
      if (!mounted) return;
      setState(() => _adError = _toEnglishError(err));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _boostingListingId = null;
        });
      }
    }
  }

  Future<void> _removeListing(AvatarRecord listing) async {
    final shouldRemove =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Listing'),
            content: const Text(
              'Do you want to remove this cat from market listings?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRemove) return;

    setState(() => _processing = true);
    try {
      await _api().removeMarketListing(listing.listingId ?? listing.id);
      if (!mounted) return;
      setState(() {
        _activeListings = _activeListings
            .where((item) => item.id != listing.id)
            .toList();
      });
      _writeCacheSnapshot();
    } catch (err) {
      if (!mounted) return;
      setState(() => _adError = _toEnglishError(err));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _toEnglishError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return 'Something went wrong.';
    final lower = raw.toLowerCase();

    if (lower.contains('giris gerekli')) return 'Sign in required.';
    if (lower.contains('boost yapilamadi')) {
      return 'Boost could not be applied.';
    }
    if (lower.contains('listeleme bulunamadi')) return 'Listing not found.';
    if (lower.contains('silme basarisiz')) return 'Could not remove listing.';
    if (lower.contains('bugunluk reklam limitine ulastin')) {
      return 'Daily ad limit reached (5/day).';
    }
    if (lower.contains('hata')) return 'Something went wrong.';
    return raw;
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _tab == 'active' ? _activeListings : _soldListings;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: MarketBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildAdEarnCard(),
                Expanded(
                  child: !_signedIn
                      ? _buildSignedOutState()
                      : _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6),
                          ),
                        )
                      : displayList.isEmpty
                      ? _buildEmptyState()
                      : _buildListingsGrid(displayList),
                ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/my-listings',
            onTap: (path) => context.go(path),
          ),
          if (_boostConfirmListing != null) _buildBoostConfirmModal(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return _frostedPanel(
      editorId: 'my-listings-header-shell',
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      borderRadius: 18,
      blurSigma: 16,
      backgroundColor: const Color(0xC2ECDFFF),
      borderColor: const Color(0x4D533886),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          children: [
            Row(
              children: [
                _iconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.go('/market-cats'),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Satislarim',
                    style: TextStyle(
                      color: Color(0xFF3B2363),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ActionButton(
                  label: '${_cpBalance.toStringAsFixed(1)} CP',
                  variant: ActionButtonVariant.pillSuccess,
                  fontSize: 11,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  onPressed: null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ActionButton(
                  label: 'Aktif (${_activeListings.length})',
                  variant: _tab == 'active'
                      ? ActionButtonVariant.pillPrimary
                      : ActionButtonVariant.pillSoftPurple,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => setState(() => _tab = 'active'),
                ),
                const SizedBox(width: 8),
                ActionButton(
                  label: 'Satilan (${_soldListings.length})',
                  variant: _tab == 'sold'
                      ? ActionButtonVariant.pillPrimary
                      : ActionButtonVariant.pillSoftPurple,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => setState(() => _tab = 'sold'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdEarnCard() {
    return _frostedPanel(
      editorId: 'my-listings-ad-card-shell',
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      borderRadius: 16,
      blurSigma: 10,
      backgroundColor: const Color(0xD6F7EFFF),
      borderColor: const Color(0x47634995),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Watch Ads, Earn CP',
                    style: TextStyle(
                      color: Color(0xFF3E295F),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '5 ads = 1 CP (daily max $_kMaxAdsPerDay ads)',
                    style: const TextStyle(
                      color: Color(0xFF63408F),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Today: $_adsToday/$_kMaxAdsPerDay ads watched',
                    style: const TextStyle(
                      color: Color(0xFF63408F),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_adError != null)
                    Text(
                      _adError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            ActionButton(
              label: _watchingAd ? '...' : 'Watch',
              variant: ActionButtonVariant.pillPrimary,
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onPressed:
                  (!_signedIn || _watchingAd || _adsToday >= _kMaxAdsPerDay)
                  ? null
                  : _watchAdForCp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedOutState() {
    return Center(
      child: ActionButton(
        label: 'Sign In',
        variant: ActionButtonVariant.actionPrimary,
        onPressed: () => context.go('/login'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Text(
          _tab == 'active' ? 'No active listings' : 'No sold cats yet',
          style: const TextStyle(
            color: Color(0xFF5B3B85),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildListingsGrid(List<AvatarRecord> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 78),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final listing = list[index];
        final cp = listing.priceCatpoison ?? 0;
        final cl = (cp * _kCatpoisonToCatlove).toStringAsFixed(0);
        final isActive = _tab == 'active';
        final boostingThis =
            _boostingListingId == (listing.listingId ?? listing.id);

        return _frostedPanel(
          editorId: 'my-listings-listing-card-shell',
          borderRadius: 16,
          blurSigma: 10,
          backgroundColor: const Color(0xEBF9F4FF),
          borderColor: const Color(0x47634995),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedCatAvatar(
                          avatarData: listing.avatarData,
                          backgroundColor: const Color(0xFFF3F4F6),
                        ),
                      ),
                      if (!isActive)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: ActionButton(
                            label: 'Sold',
                            variant: ActionButtonVariant.pillSuccess,
                            fontSize: 10,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            onPressed: null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '${_formatCp(cp)} CP',
                                style: const TextStyle(
                                  color: Color(0xFF5D34A5),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '= $cl CL',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF876BBD),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Row(
                            children: [
                              _iconActionButton(
                                icon: Icons.trending_up_rounded,
                                gradient: const [
                                  Color(0xFF9464FA),
                                  Color(0xFF6439C4),
                                ],
                                onTap:
                                    (_processing || _watchingAd || boostingThis)
                                    ? null
                                    : () => _openBoostConfirm(listing),
                              ),
                              const SizedBox(width: 4),
                              _iconActionButton(
                                icon: Icons.close_rounded,
                                gradient: const [
                                  Color(0xFFFF7A9F),
                                  Color(0xFFE7396E),
                                ],
                                onTap: _processing
                                    ? null
                                    : () => _removeListing(listing),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Views: ${listing.viewCount ?? 0}',
                          style: const TextStyle(
                            color: Color(0xFF876BBD),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (!isActive && listing.soldAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _formatDate(listing.soldAt!),
                          style: const TextStyle(
                            color: Color(0xFF876BBD),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoostConfirmModal() {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _boostConfirmListing = null),
            child: Container(color: const Color(0x72000000)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _frostedPanel(
                editorId: 'my-listings-boost-modal-shell',
                borderRadius: 16,
                blurSigma: 10,
                backgroundColor: const Color(0xD6F7EFFF),
                borderColor: const Color(0x47634995),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Boost this cat's market popularity by 1/10!",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E295F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ActionButton(
                            label: 'Cancel',
                            variant: ActionButtonVariant.pillSoftPurple,
                            fontSize: 12,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            onPressed: () =>
                                setState(() => _boostConfirmListing = null),
                          ),
                          const SizedBox(width: 8),
                          ActionButton(
                            label: _processing ? '...' : 'Watch',
                            variant: ActionButtonVariant.pillPrimary,
                            fontSize: 12,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            onPressed: _processing ? null : _startBoostFlow,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    const defaults = <String, dynamic>{
      'size': 36.0,
      'radius': 999.0,
      'gradient': [0xFF9261F7, 0xFF6F43D3],
      'borderColor': 0xFF462C71,
      'borderWidth': 2.0,
      'shadowColor': 0x33462C71,
      'shadowOffsetY': 8.0,
      'shadowBlur': 14.0,
      'iconColor': 0xFFFFFFFF,
      'iconSize': 20.0,
    };

    return EditableWidget(
      id: 'my-listings-header-back-button',
      typeName: 'MarketHeaderIconButton',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        final size = _editorNumber(props['size'], 36);
        final radius = _editorNumber(props['radius'], 999);
        final gradient = _editorGradient(
          props['gradient'],
          const [Color(0xFF9261F7), Color(0xFF6F43D3)],
        );
        final borderColor = _editorColor(
          props['borderColor'],
          const Color(0xFF462C71),
        );
        final borderWidth = _editorNumber(props['borderWidth'], 2);
        final shadowColor = _editorColor(
          props['shadowColor'],
          const Color(0x33462C71),
        );
        final shadowY = _editorNumber(props['shadowOffsetY'], 8);
        final shadowBlur = _editorNumber(props['shadowBlur'], 14);
        final iconColor = _editorColor(props['iconColor'], Colors.white);
        final iconSize = _editorNumber(props['iconSize'], 20);

        return InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient,
              ),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  offset: Offset(0, shadowY),
                  blurRadius: shadowBlur,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        );
      },
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradient,
            ),
            border: Border.all(color: const Color(0xFF462C71), width: 2),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }

  Widget _frostedPanel({
    required Widget child,
    required double borderRadius,
    required double blurSigma,
    required Color backgroundColor,
    required Color borderColor,
    EdgeInsets? margin,
    String? editorId,
  }) {
    Widget buildPanel({
      required double radius,
      required double blur,
      required Color bg,
      required Color border,
      required double borderWidth,
      required Color shadowColor,
      required double shadowY,
      required double shadowBlur,
    }) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, shadowY),
              blurRadius: shadowBlur,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border, width: borderWidth),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    if (editorId == null) {
      return buildPanel(
        radius: borderRadius,
        blur: blurSigma,
        bg: backgroundColor,
        border: borderColor,
        borderWidth: 1,
        shadowColor: const Color(0x2E533886),
        shadowY: 14,
        shadowBlur: 24,
      );
    }

    final defaults = <String, dynamic>{
      'radius': borderRadius,
      'blurSigma': blurSigma,
      'backgroundColor': backgroundColor.toARGB32(),
      'borderColor': borderColor.toARGB32(),
      'borderWidth': 1.0,
      'shadowColor': const Color(0x2E533886).toARGB32(),
      'shadowOffsetY': 14.0,
      'shadowBlur': 24.0,
    };

    return EditableWidget(
      id: editorId,
      typeName: 'FrostedPanel',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        return buildPanel(
          radius: _editorNumber(props['radius'], borderRadius),
          blur: _editorNumber(props['blurSigma'], blurSigma),
          bg: _editorColor(props['backgroundColor'], backgroundColor),
          border: _editorColor(props['borderColor'], borderColor),
          borderWidth: _editorNumber(props['borderWidth'], 1),
          shadowColor: _editorColor(props['shadowColor'], const Color(0x2E533886)),
          shadowY: _editorNumber(props['shadowOffsetY'], 14),
          shadowBlur: _editorNumber(props['shadowBlur'], 24),
        );
      },
    );
  }

  Color _editorColor(dynamic raw, Color fallback) {
    if (raw is int) return Color(raw);
    if (raw is num) return Color(raw.toInt());
    if (raw is Color) return raw;
    return fallback;
  }

  double _editorNumber(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  List<Color> _editorGradient(dynamic raw, List<Color> fallback) {
    if (raw is List) {
      final out = <Color>[];
      for (final item in raw) {
        if (item is int) out.add(Color(item));
        if (item is num) out.add(Color(item.toInt()));
      }
      if (out.isNotEmpty) return out;
    }
    return fallback;
  }
}

String _formatCp(double value) {
  if (value.truncateToDouble() == value) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
