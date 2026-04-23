import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/cache/runtime_cache.dart';
import '../../core/monetization/native_monetization_bridge.dart';
import '../../core/network/api_client.dart';
import '../../editor/editor_controller.dart';
import '../../editor/editable_widget.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../avatar/animated_cat_avatar.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/models.dart';
import '../shared/widgets/market_background.dart';

const double _kCatpoisonToCatlove = 40;
const Duration _kMarketListingsCacheTtl = Duration(minutes: 3);
const Duration _kMarketBalanceCacheTtl = Duration(minutes: 2);

class MarketCatsScreen extends StatefulWidget {
  const MarketCatsScreen({super.key});

  @override
  State<MarketCatsScreen> createState() => _MarketCatsScreenState();
}

class _MarketCatsScreenState extends State<MarketCatsScreen>
    with TickerProviderStateMixin {
  final RuntimeCache _cache = RuntimeCache.instance;
  final PageController _exploreController = PageController();
  final TextEditingController _sellPriceController = TextEditingController();
  final Set<int> _viewedListingIds = <int>{};

  late final AnimationController _freeCpPulse;

  AuthController? _auth;
  bool _didInit = false;
  String _userScope = 'anon';

  bool _loading = true;
  bool _processing = false;
  bool _watchingCpAd = false;
  MarketSubTab _mode = MarketSubTab.explore;
  String _listSort = 'newest';

  List<AvatarRecord> _listings = const [];
  int _currentIndex = 0;

  double _cpBalance = 0;
  int _pendingCount = 0;
  List<_PendingReward> _pendingRewards = const [];
  _PendingReward? _activeReward;

  AvatarRecord? _buyListing;
  bool _showRewardPopup = false;
  bool _showSellPopup = false;
  bool _showCpEarnPopup = false;
  bool _showCpBuyPopup = false;
  String? _cpAdError;

  List<AvatarRecord> _myCats = const [];
  AvatarRecord? _selectedCatToSell;

  @override
  void initState() {
    super.initState();
    _freeCpPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

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
    _sellPriceController.dispose();
    _exploreController.dispose();
    _freeCpPulse.dispose();
    super.dispose();
  }

  String _marketListingsCacheKey(String mode) =>
      'market-cats:listings:$mode:${_userScope.isEmpty ? 'anon' : _userScope}';

  String _marketBalanceCacheKey() =>
      'market-cats:balance:${_userScope.isEmpty ? 'anon' : _userScope}';

  MeowverseApi _api() => MeowverseApi(context.read<ApiClient>());

  void _handleAuthChanged() {
    if (!mounted) return;
    final signedIn = _auth?.isSignedIn ?? false;
    final nextScope = signedIn ? (_auth?.user?.id ?? 'anon') : 'anon';
    if (_userScope == nextScope && _didInit) return;

    _userScope = nextScope;
    _viewedListingIds.clear();
    _currentIndex = 0;
    _buyListing = null;
    _showRewardPopup = false;
    _activeReward = null;
    _showSellPopup = false;
    _showCpEarnPopup = false;
    _showCpBuyPopup = false;
    _cpAdError = null;
    _selectedCatToSell = null;
    _sellPriceController.clear();

    if (!signedIn) {
      _cpBalance = 0;
      _pendingCount = 0;
      _pendingRewards = const [];
    }
    setState(() {});

    _loadListingsForCurrentMode();
    if (signedIn) {
      _loadBalance();
    }
  }

  Future<void> _loadListingsForCurrentMode() async {
    final mode = _mode == MarketSubTab.explore ? 'explore' : _listSort;
    final cacheKey = _marketListingsCacheKey(mode);
    final cached = _cache.get<List<AvatarRecord>>(cacheKey);
    final hasCached = cached != null && cached.isNotEmpty;

    if (hasCached) {
      setState(() {
        _listings = cached;
        _loading = false;
        _currentIndex = 0;
      });
      _jumpExploreToFirst();
      _markViewedIfNeeded(0);
    }

    await _loadListings(mode: mode, silent: hasCached);
  }

  Future<void> _loadListings({
    required String mode,
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _loading = true;
      });
    }
    try {
      final listings = await _api().fetchMarketListings(mode: mode);
      if (!mounted) return;
      _cache.put<List<AvatarRecord>>(
        _marketListingsCacheKey(mode),
        listings,
        _kMarketListingsCacheTtl,
      );
      setState(() {
        _listings = listings;
        _currentIndex = 0;
      });
      _jumpExploreToFirst();
      _markViewedIfNeeded(0);
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    } finally {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
        });
      } else if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _jumpExploreToFirst() {
    if (_mode != MarketSubTab.explore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_exploreController.hasClients) return;
      _exploreController.jumpToPage(0);
    });
  }

  Future<void> _loadBalance() async {
    if (!(_auth?.isSignedIn ?? false)) return;

    final cached = _cache.get<Map<String, dynamic>>(_marketBalanceCacheKey());
    if (cached != null) {
      _applyBalanceSnapshot(cached, fromCache: true);
    }

    try {
      final balance = await _api().fetchCatpoisonBalance();
      if (!mounted) return;
      final snapshot = <String, dynamic>{
        'balance': balance.balance,
        'pendingCount': balance.pendingCount,
        'pendingRewards': balance.pendingRewards,
      };
      _cache.put<Map<String, dynamic>>(
        _marketBalanceCacheKey(),
        snapshot,
        _kMarketBalanceCacheTtl,
      );
      _applyBalanceSnapshot(snapshot, fromCache: false);
    } catch (_) {
      // Keep UI responsive with latest available cache.
    }
  }

  void _applyBalanceSnapshot(
    Map<String, dynamic> snapshot, {
    required bool fromCache,
  }) {
    final pendingRewards = ((snapshot['pendingRewards'] as List?) ?? const [])
        .whereType<Map>()
        .map((raw) => _PendingReward.fromJson(raw.cast<String, dynamic>()))
        .toList();

    final pendingCount =
        _toInt(snapshot['pendingCount']) ?? pendingRewards.length;
    final cpBalance = _toDouble(snapshot['balance']) ?? 0;

    setState(() {
      _cpBalance = cpBalance;
      _pendingCount = pendingCount;
      _pendingRewards = pendingRewards;
      if (!fromCache && pendingRewards.isNotEmpty && !_showRewardPopup) {
        _activeReward = pendingRewards.first;
        _showRewardPopup = true;
      } else if (pendingRewards.isEmpty && _showRewardPopup) {
        _showRewardPopup = false;
        _activeReward = null;
      }
    });
  }

  void _markViewedIfNeeded(int index) {
    if (_mode != MarketSubTab.explore) return;
    if (index < 0 || index >= _listings.length) return;
    final listing = _listings[index];
    final listingId = listing.listingId ?? listing.id;
    if (_viewedListingIds.contains(listingId)) return;
    _viewedListingIds.add(listingId);
    _api().markMarketListingViewed(listingId).catchError((_) {});
  }

  Future<void> _onModeChange(MarketSubTab next) async {
    if (_mode == next) return;
    setState(() {
      _mode = next;
      _currentIndex = 0;
    });
    await _loadListingsForCurrentMode();
  }

  Future<void> _onSortChange(String nextSort) async {
    if (_listSort == nextSort) return;
    setState(() => _listSort = nextSort);
    if (_mode == MarketSubTab.list) {
      await _loadListingsForCurrentMode();
    }
  }

  Future<void> _openBuyPopup(AvatarRecord listing) async {
    if (!(_auth?.isSignedIn ?? false)) {
      if (!mounted) return;
      context.go('/login');
      return;
    }
    setState(() {
      _buyListing = listing;
    });
  }

  Future<void> _confirmBuy() async {
    final target = _buyListing;
    if (target == null) return;

    final listingId = target.listingId ?? target.id;
    final price = target.priceCatpoison ?? 0;
    setState(() => _processing = true);
    try {
      await _api().buyMarketListing(listingId);
      if (!mounted) return;
      setState(() {
        _buyListing = null;
        _cpBalance = math.max(0, _cpBalance - price);
        _listings = _listings.where((item) => item.id != target.id).toList();
      });
      _showToast('Cat purchased. You can find it in My Cats.');
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _claimPendingReward(String rewardType) async {
    final reward = _activeReward;
    if (reward == null) return;
    setState(() => _processing = true);
    try {
      await _api().claimPendingReward(
        rewardId: reward.id,
        rewardType: rewardType,
      );
      if (!mounted) return;

      final remaining = _pendingRewards
          .where((item) => item.id != reward.id)
          .toList();
      setState(() {
        _pendingRewards = remaining;
        _pendingCount = math.max(0, _pendingCount - 1);
        if (remaining.isEmpty) {
          _showRewardPopup = false;
          _activeReward = null;
        } else {
          _activeReward = remaining.first;
        }
      });

      await _loadBalance();

      if (!mounted) return;
      if (rewardType == 'catpoison') {
        _showToast(
          '+${(reward.priceCatpoison / 4).toStringAsFixed(2)} CP earned.',
        );
      } else {
        _showToast(
          '+${(reward.priceCatpoison * _kCatpoisonToCatlove).toStringAsFixed(0)} CL earned.',
        );
      }
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openSellPopup() async {
    if (!(_auth?.isSignedIn ?? false)) {
      if (!mounted) return;
      context.go('/login');
      return;
    }
    setState(() {
      _showSellPopup = true;
      _selectedCatToSell = null;
      _sellPriceController.clear();
      _myCats = const [];
    });
    await _loadMyCatsForSelling();
  }

  Future<void> _loadMyCatsForSelling() async {
    try {
      final cats = await _api().fetchMyCats();
      if (!mounted) return;
      setState(() {
        _myCats = cats;
      });
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    }
  }

  double _calculateMinPriceCp(AvatarRecord cat) {
    final likes = cat.likes ?? 0;
    final totalRatings = cat.totalRatings ?? 0;
    final ratingSum = cat.ratingSum ?? 0;
    final likeBonus = (likes ~/ 100) * 0.05;
    double ratingMultiplier = 1;
    if (totalRatings >= 300 && totalRatings > 0) {
      final avgRating = ratingSum / totalRatings;
      ratingMultiplier = avgRating / 3.0;
    }
    final minPrice = likeBonus * ratingMultiplier;
    return (minPrice * 100).round() / 100;
  }

  Future<void> _handleListCat() async {
    final cat = _selectedCatToSell;
    final price = double.tryParse(
      _sellPriceController.text.trim().replaceAll(',', '.'),
    );

    if (cat == null) {
      _showToast('Select a cat to list.');
      return;
    }
    if (price == null || price <= 0) {
      _showToast('Enter a valid listing price.');
      return;
    }

    final minPrice = _calculateMinPriceCp(cat);
    if (price < minPrice) {
      _showToast('Minimum allowed price is ${minPrice.toStringAsFixed(2)} CP.');
      return;
    }

    setState(() => _processing = true);
    try {
      await _api().createMarketListing(avatarId: cat.id, priceCatpoison: price);
      if (!mounted) return;
      setState(() {
        _showSellPopup = false;
        _selectedCatToSell = null;
        _sellPriceController.clear();
      });
      await _loadListingsForCurrentMode();
      _showToast('Your cat has been listed on the market.');
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _watchAdForCp() async {
    if (_watchingCpAd) return;

    setState(() {
      _watchingCpAd = true;
      _cpAdError = null;
    });

    try {
      final adCompleted = await _runRewardedAdWithWebFallback();
      if (!adCompleted) {
        if (!mounted) return;
        setState(
          () => _cpAdError = 'Please watch the full ad to receive the reward.',
        );
        return;
      }

      final result = await _api().watchAdForCp();
      if (!mounted) return;

      final nextCp = _toDouble(result['newBalance']) ?? _cpBalance;
      final watchedToday = _toInt(result['watchedToday']) ?? 0;
      final awarded =
          result['cpAwarded'] == true || (result['earned'] ?? 0) > 0;
      setState(() {
        _cpBalance = nextCp;
      });

      if (awarded) {
        _showToast('5 ads completed. +1 CP earned.');
      } else {
        _showToast('Ad watched. ($watchedToday/5)');
      }
    } catch (err) {
      if (!mounted) return;
      final message = _toEnglishError(err);
      setState(() => _cpAdError = message);
    } finally {
      if (mounted) {
        setState(() => _watchingCpAd = false);
      }
    }
  }

  Future<bool> _runRewardedAdWithWebFallback() async {
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return true;
    }
    return NativeMonetizationBridge.showRewardedAd();
  }

  Future<void> _buyCpPackage(_CpPackage pkg) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final result = await _api().buyCpPack(pkg.key);
      if (!mounted) return;
      setState(() {
        _cpBalance = _toDouble(result['newBalance']) ?? _cpBalance;
        _showCpBuyPopup = false;
      });
      _showToast('+${pkg.cp.toStringAsFixed(0)} CP added to your account.');
    } catch (err) {
      if (!mounted) return;
      _showToast(_toEnglishError(err));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _displayName(AvatarRecord listing) {
    final username = listing.userUsername?.trim();
    if (username != null && username.isNotEmpty) return username;
    final email = listing.userEmail?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Anonymous';
  }

  String _toEnglishError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return 'Something went wrong.';
    final lower = raw.toLowerCase();

    if (lower.contains('giris gerekli')) return 'Sign in required.';
    if (lower.contains('yetersiz catpoison')) return 'Insufficient CP balance.';
    if (lower.contains('kendi kedini satin alamazsin')) {
      return 'You cannot buy your own cat.';
    }
    if (lower.contains('listeleme bulunamadi')) return 'Listing not found.';
    if (lower.contains('listeleme basarisiz')) return 'Listing failed.';
    if (lower.contains('satin alma basarisiz')) return 'Purchase failed.';
    if (lower.contains('odul bulunamadi')) return 'Reward not found.';
    if (lower.contains('odul alinamadi')) return 'Reward claim failed.';
    if (lower.contains('bugunluk reklam limitine ulastin')) {
      return 'Daily ad limit reached (5/day).';
    }
    if (lower.contains('boost yapilamadi')) return 'Boost failed.';
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
    final signedIn = _auth?.isSignedIn ?? false;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: MarketBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(signedIn: signedIn),
                Expanded(
                  child: _mode == MarketSubTab.explore
                      ? _buildExploreMode(signedIn: signedIn)
                      : _buildListMode(signedIn: signedIn),
                ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: _mode == MarketSubTab.list
                ? '/market-cats/list'
                : '/market-cats',
            marketMode: _mode,
            onMarketModeChange: (next) => _onModeChange(next),
            onTap: (path) => context.go(path),
          ),
          if (_buyListing != null) _buildBuyModal(),
          if (_showRewardPopup && _activeReward != null) _buildRewardModal(),
          if (_showSellPopup) _buildSellSheet(),
          if (_showCpEarnPopup) _buildCpEarnModal(),
          if (_showCpBuyPopup) _buildCpBuyModal(),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool signedIn}) {
    const defaults = <String, dynamic>{
      'blurSigma': 16.0,
      'backgroundColor': 0xC2ECDFFF,
      'borderColor': 0x4D533886,
      'borderWidth': 1.0,
      'shadowColor': 0x2E533886,
      'shadowOffsetY': 16.0,
      'shadowBlur': 28.0,
      'paddingTop': 10.0,
      'paddingBottom': 8.0,
      'paddingH': 8.0,
    };

    return EditableWidget(
      id: 'market-cats-header-shell',
      typeName: 'GlassHeaderBar',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        final blur = _editorNumber(props['blurSigma'], 16);
        final background = _editorColor(
          props['backgroundColor'],
          const Color(0xC2ECDFFF),
        );
        final borderColor = _editorColor(
          props['borderColor'],
          const Color(0x4D533886),
        );
        final borderWidth = _editorNumber(props['borderWidth'], 1);
        final shadowColor = _editorColor(
          props['shadowColor'],
          const Color(0x2E533886),
        );
        final shadowY = _editorNumber(props['shadowOffsetY'], 16);
        final shadowBlur = _editorNumber(props['shadowBlur'], 28);
        final padTop = _editorNumber(props['paddingTop'], 10);
        final padBottom = _editorNumber(props['paddingBottom'], 8);
        final padH = _editorNumber(props['paddingH'], 8);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: Offset(0, shadowY),
                blurRadius: shadowBlur,
              ),
            ],
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: borderWidth),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _iconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => context.go('/'),
                          ),
                          const SizedBox(width: 4),
                          const SizedBox(
                            width: 44,
                            child: Text(
                              'Cat\nMarket',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 0.95,
                                color: Color(0xFF3B2363),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _cpBalanceChip(),
                          const SizedBox(width: 4),
                          _headerRoundActionButton(
                            top: 'Buy',
                            bottom: 'CP',
                            onTap: () => setState(() => _showCpBuyPopup = true),
                          ),
                          const SizedBox(width: 4),
                          _headerRoundActionButton(
                            top: 'Free',
                            bottom: 'CP',
                            success: true,
                            pulse: true,
                            onTap: () => setState(() => _showCpEarnPopup = true),
                          ),
                          const SizedBox(width: 4),
                          _headerRoundActionButton(
                            top: 'Sell',
                            bottom: '\u{1F431}',
                            onTap: _openSellPopup,
                          ),
                        ],
                      ),
                      if (_mode == MarketSubTab.list) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _sortChip('newest', 'Newest'),
                              _sortChip('oldest', 'Oldest'),
                              _sortChip('cheapest', 'Cheapest'),
                              _sortChip('expensive', 'Most Expensive'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExploreMode({required bool signedIn}) {
    if (_loading && _listings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B43BE)),
      );
    }

    if (_listings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No listed cats yet',
                style: TextStyle(
                  color: Color(0xFF5B3B85),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _exploreController,
          scrollDirection: Axis.vertical,
          itemCount: _listings.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            _markViewedIfNeeded(index);
          },
          itemBuilder: (context, index) {
            final listing = _listings[index];
            final cp = listing.priceCatpoison ?? 0;
            final cl = (cp * _kCatpoisonToCatlove).toStringAsFixed(0);
            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = math.max(
                  220.0,
                  math.min(constraints.maxWidth - 92, 360.0),
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 76),
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: cardWidth,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _frostedPanel(
                              editorId: 'market-cats-explore-main-card',
                              borderRadius: 24,
                              blurSigma: 10,
                              backgroundColor: const Color(0xEBF9F4FF),
                              borderColor: const Color(0x4D634995),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: AnimatedCatAvatar(
                                  avatarData: listing.avatarData,
                                  backgroundColor: const Color(0xFFF3F4F6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if ((listing.level ?? 0) > 0)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ActionButton(
                              label: '✦ Lv.${listing.level}',
                              variant: ActionButtonVariant.pillSoftPurple,
                              fontSize: 11,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              onPressed: null,
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _frostedPanel(
                            editorId: 'market-cats-explore-price-card',
                            borderRadius: 16,
                            blurSigma: 10,
                            backgroundColor: const Color(0xD6F7EFFF),
                            borderColor: const Color(0x47634995),
                            child: SizedBox(
                              width: 82,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatCp(cp),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF5D34A5),
                                      ),
                                    ),
                                    const Text(
                                      'CP',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7B59B5),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (!listing.isOwn)
                                      ActionButton(
                                        label: 'Buy',
                                        variant:
                                            ActionButtonVariant.pillPrimary,
                                        fontSize: 12,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        onPressed: () => _openBuyPopup(listing),
                                      )
                                    else
                                      const Text(
                                        'Yours',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF7A59B3),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 92,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@${_displayName(listing)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF3D2A5C),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '❤️ ${listing.likes ?? 0}   ⭐ ${listing.totalRatings ?? 0}${(listing.totalRatings ?? 0) > 0 ? ' (${((listing.ratingSum ?? 0) / (listing.totalRatings ?? 1)).toStringAsFixed(1)})' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF684395),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '= $cl CL',
                              style: const TextStyle(
                                color: Color(0xFF7A59B3),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
          },
        ),
        Positioned(
          left: 8,
          top: 0,
          bottom: 72,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _visibleDotIndexes().map((realIndex) {
                final active = realIndex == _currentIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  width: active ? 6 : 4,
                  height: active ? 16 : 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? const Color(0xFF5F36A8)
                        : const Color(0x605D3C92),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<int> _visibleDotIndexes() {
    final start = math.max(0, _currentIndex - 3);
    final end = math.min(_listings.length, _currentIndex + 4);
    return List<int>.generate(end - start, (i) => start + i);
  }

  Widget _buildListMode({required bool signedIn}) {
    if (_loading && _listings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B43BE)),
      );
    }

    if (_listings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 56),
          child: Text(
            'No listed cats yet',
            style: TextStyle(
              color: Color(0xFF5B3B85),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 78),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _listings.length,
      itemBuilder: (context, index) {
        final listing = _listings[index];
        final cp = listing.priceCatpoison ?? 0;
        final cl = (cp * _kCatpoisonToCatlove).toStringAsFixed(0);

        return _frostedPanel(
          editorId: 'market-cats-list-card',
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
                  child: AnimatedCatAvatar(
                    avatarData: listing.avatarData,
                    backgroundColor: const Color(0xFFF3F4F6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${_displayName(listing)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7555AC),
                      ),
                    ),
                    if ((listing.level ?? 0) > 0)
                      Text(
                        '✦ Lv.${listing.level}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5F3D95),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatCp(cp)} CP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5D34A5),
                      ),
                    ),
                    Text(
                      '= $cl CL',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7F61B6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!listing.isOwn)
                      SizedBox(
                        width: double.infinity,
                        child: ActionButton(
                          label: 'Buy',
                          variant: ActionButtonVariant.pillPrimary,
                          fontSize: 12,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onPressed: () => _openBuyPopup(listing),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ActionButton(
                          label: 'Your listing',
                          variant: ActionButtonVariant.pillMuted,
                          fontSize: 11,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onPressed: null,
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

  Widget _buildBuyModal() {
    final listing = _buyListing!;
    final cp = listing.priceCatpoison ?? 0;
    final cl = cp * _kCatpoisonToCatlove;
    final insufficient = _cpBalance < cp;

    return _centerModal(
      child: _modalSheet(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buy Cat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF311F4F),
              ),
            ),
            const SizedBox(height: 12),
            _frostedPanel(
              editorId: 'market-cats-buy-modal-card',
              borderRadius: 14,
              blurSigma: 10,
              backgroundColor: const Color(0xD6F7EFFF),
              borderColor: const Color(0x47634995),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedCatAvatar(
                          avatarData: listing.avatarData,
                          backgroundColor: const Color(0xFFF3F4F6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${_displayName(listing)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B4A99),
                            ),
                          ),
                          Text(
                            '${_formatCp(cp)} CP',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF5D34A5),
                            ),
                          ),
                          Text(
                            '= ${cl.toStringAsFixed(0)} Catlove',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A59B3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF6B4A99),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  const TextSpan(text: 'Your balance: '),
                  TextSpan(
                    text: '${_cpBalance.toStringAsFixed(1)} CP',
                    style: const TextStyle(
                      color: Color(0xFF5D34A5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (insufficient)
                    const TextSpan(
                      text: '  Insufficient',
                      style: TextStyle(color: Color(0xFFDC2626)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    label: 'Cancel',
                    variant: ActionButtonVariant.actionSoft,
                    onPressed: _processing
                        ? null
                        : () => setState(() => _buyListing = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ActionButton(
                    label: _processing ? '...' : 'Buy',
                    variant: ActionButtonVariant.actionPrimary,
                    onPressed: (_processing || insufficient)
                        ? null
                        : _confirmBuy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardModal() {
    final reward = _activeReward!;
    final cpReward = reward.priceCatpoison / 4;
    final clReward = reward.priceCatpoison * _kCatpoisonToCatlove;

    return _centerModal(
      child: _modalSheet(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sale Completed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF311F4F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatCp(reward.priceCatpoison)} CP sale value. Choose your reward:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B4A99),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ActionButton(
                label: _processing
                    ? '...'
                    : 'Claim CP  (+${cpReward.toStringAsFixed(2)} CP)',
                variant: ActionButtonVariant.actionSuccess,
                onPressed: _processing
                    ? null
                    : () => _claimPendingReward('catpoison'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ActionButton(
                label: _processing
                    ? '...'
                    : 'Claim CL  (+${clReward.toStringAsFixed(0)} CL)',
                variant: ActionButtonVariant.actionPrimary,
                onPressed: _processing
                    ? null
                    : () => _claimPendingReward('catlove'),
              ),
            ),
            if (_pendingCount > 1) ...[
              const SizedBox(height: 10),
              Text(
                '${_pendingCount - 1} pending reward(s) remaining.',
                style: const TextStyle(
                  color: Color(0xFF7758AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSellSheet() {
    final selected = _selectedCatToSell;
    final minPrice = selected == null ? 0 : _calculateMinPriceCp(selected);
    final enteredPrice =
        double.tryParse(
          _sellPriceController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final canSubmit =
        !_processing &&
        selected != null &&
        enteredPrice > 0 &&
        enteredPrice >= minPrice;

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showSellPopup = false),
            child: Container(color: const Color(0x70231437)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: 0.86,
                child: _modalSheet(
                  maxWidth: double.infinity,
                  borderRadius: 20,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'List a Cat',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3A245E),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _showSellPopup = false),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF6E4BA6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Price (CatPoison)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF573A84),
                                ),
                              ),
                              if (selected != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFFEFF6FF),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Minimum price recommendation',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${minPrice.toStringAsFixed(2)} CP  (${selected.likes ?? 0} likes, ${selected.totalRatings ?? 0} ratings)',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'This minimum is enforced.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextField(
                                controller: _sellPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: selected == null
                                      ? 'Select a cat first'
                                      : 'Enter total price (min ${minPrice.toStringAsFixed(2)} CP)',
                                  filled: true,
                                  fillColor: const Color(0xFFF8F2FF),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFB89FE8),
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFB89FE8),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF3F2668),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (selected != null && enteredPrice > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Total: ${enteredPrice.toStringAsFixed(2)} CP',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7A59B3),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Text(
                                'Choose Cat to Sell',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF573A84),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_myCats.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'You do not have any cats in your inventory.',
                                    style: TextStyle(
                                      color: Color(0xFF7A59B3),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ..._myCats.map((cat) {
                                final selectedState =
                                    _selectedCatToSell?.id == cat.id &&
                                    _selectedCatToSell?.source == cat.source;
                                final sourceLabel = cat.isPublished == true
                                    ? 'Published Cat'
                                    : (cat.source == 'private_cats'
                                          ? 'Saved Cat'
                                          : 'Unpublished Cat');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        if (selectedState) {
                                          _selectedCatToSell = null;
                                        } else {
                                          _selectedCatToSell = cat;
                                        }
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: selectedState
                                            ? const Color(0xFFEFE4FF)
                                            : const Color(0xFFF3EBFF),
                                        border: Border.all(
                                          color: selectedState
                                              ? const Color(0xFF7B56C5)
                                              : const Color(0xFFC3B0EA),
                                          width: selectedState ? 2 : 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: AnimatedCatAvatar(
                                                avatarData: cat.avatarData,
                                                backgroundColor: const Color(
                                                  0xFFF3F4F6,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sourceLabel,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF4A2F73),
                                                  ),
                                                ),
                                                if (cat.createdAt != null)
                                                  Text(
                                                    _formatDate(cat.createdAt!),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF7A59B3),
                                                    ),
                                                  ),
                                                if (cat.isPublished == true)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF2E8FF,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFCFB9EF,
                                                        ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Published',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF6F48AC,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (selectedState)
                                            const Text(
                                              'Selected',
                                              style: TextStyle(
                                                color: Color(0xFF5D34A5),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          child: ActionButton(
                            label: _processing
                                ? 'Listing...'
                                : 'List on Market',
                            variant: ActionButtonVariant.actionPrimary,
                            onPressed: canSubmit ? _handleListCat : null,
                          ),
                        ),
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

  Widget _buildCpEarnModal() {
    return _centerModal(
      child: _modalSheet(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Earn CatPoison',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF311F4F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Watch 5 ads to earn 1 CP (daily max: 5 ads).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B4A99),
              ),
            ),
            if (_cpAdError != null) ...[
              const SizedBox(height: 8),
              Text(
                _cpAdError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    label: 'Close',
                    variant: ActionButtonVariant.actionSoft,
                    onPressed: () => setState(() => _showCpEarnPopup = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ActionButton(
                    label: _watchingCpAd ? '...' : 'Watch Ad',
                    variant: ActionButtonVariant.actionPrimary,
                    onPressed: _watchingCpAd ? null : _watchAdForCp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCpBuyModal() {
    const packages = <_CpPackage>[
      _CpPackage(key: '2', cp: 2, usd: 1, label: 'Starter'),
      _CpPackage(key: '12', cp: 12, usd: 5, label: 'Value', bonus: 2),
      _CpPackage(key: '25', cp: 25, usd: 10, label: 'Popular', bonus: 5),
      _CpPackage(key: '65', cp: 65, usd: 25, label: 'Pro', bonus: 15),
      _CpPackage(key: '140', cp: 140, usd: 50, label: 'Ultra', bonus: 40),
      _CpPackage(key: '300', cp: 300, usd: 100, label: 'Mega', bonus: 100),
    ];

    return _centerModal(
      child: _modalSheet(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Buy CatPoison',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF311F4F),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: packages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final pkg = packages[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _processing ? null : () => _buyCpPackage(pkg),
                      child: _frostedPanel(
                        editorId: 'market-cats-cp-package-card',
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
                                    Row(
                                      children: [
                                        Text(
                                          '${pkg.cp.toStringAsFixed(0)} CP',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF4A2F73),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          pkg.label,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B4A99),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (pkg.bonus > 0)
                                      Text(
                                        '+${pkg.bonus.toStringAsFixed(0)} bonus CP',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5D34A5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${pkg.usd.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF5D34A5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ActionButton(
                label: 'Close',
                variant: ActionButtonVariant.actionSoft,
                onPressed: _processing
                    ? null
                    : () => setState(() => _showCpBuyPopup = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String key, String label) {
    final active = _listSort == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionButton(
        label: label,
        variant: active
            ? ActionButtonVariant.pillPrimary
            : ActionButtonVariant.pillSoftPurple,
        fontSize: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onPressed: () => _onSortChange(key),
      ),
    );
  }

  Widget _headerRoundActionButton({
    required String top,
    required String bottom,
    required VoidCallback onTap,
    bool success = false,
    bool pulse = false,
  }) {
    final slug = _slugify('$top-$bottom');
    final defaults = <String, dynamic>{
      'size': 50.0,
      'radius': 999.0,
      'gradient': success
          ? [0xFF7BE08F, 0xFF50C875, 0xFF3DA75D]
          : [0xFF9261F7, 0xFF6F43D3],
      'borderColor': 0xFF462C71,
      'borderWidth': 2.0,
      'shadowColor': 0x33462C71,
      'shadowOffsetY': 8.0,
      'shadowBlur': 14.0,
      'textColor': success ? 0xFF134B2A : 0xFFFFFFFF,
      'fontSize': 11.5,
      'lineHeight': 0.98,
      'pulseColor': success ? 0xFF3DA75D : 0xFF5F36A8,
    };

    Widget core = EditableWidget(
      id: 'market-cats-header-btn-$slug',
      typeName: 'MarketHeaderRoundButton',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        final size = _editorNumber(props['size'], 50);
        final radius = _editorNumber(props['radius'], 999);
        final gradient = _editorGradient(
          props['gradient'],
          success
              ? const [Color(0xFF7BE08F), Color(0xFF50C875), Color(0xFF3DA75D)]
              : const [Color(0xFF9261F7), Color(0xFF6F43D3)],
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
        final textColor = _editorColor(
          props['textColor'],
          success ? const Color(0xFF134B2A) : Colors.white,
        );
        final fontSize = _editorNumber(props['fontSize'], 11.5);
        final lineHeight = _editorNumber(props['lineHeight'], 0.98);

        return InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: _marketIconFrame(
              borderRadius: radius,
              colors: gradient,
              borderColor: borderColor,
              borderWidth: borderWidth,
              shadowColor: shadowColor,
              shadowOffsetY: shadowY,
              shadowBlur: shadowBlur,
              child: Center(
                child: Text(
                  '$top\n$bottom',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    height: lineHeight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!pulse) return core;
    return AnimatedBuilder(
      animation: _freeCpPulse,
      builder: (context, child) {
        final props = _propsFor('market-cats-header-btn-$slug');
        final pulseColor = _editorColor(
          props['pulseColor'],
          success ? const Color(0xFF3DA75D) : const Color(0xFF5F36A8),
        );
        final radius = _editorNumber(props['radius'], 999);
        final wave = (math.sin(_freeCpPulse.value * math.pi * 2) + 1) / 2;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: pulseColor.withValues(alpha: 0.28 * wave),
                spreadRadius: 3.2 * wave,
                blurRadius: 12,
              ),
            ],
          ),
          child: child,
        );
      },
      child: core,
    );
  }

  Widget _cpBalanceChip() {
    final hasPendingRewards = _pendingCount > 0 && _pendingRewards.isNotEmpty;
    const defaults = <String, dynamic>{
      'size': 50.0,
      'radius': 999.0,
      'gradient': [0xFF7BE08F, 0xFF50C875, 0xFF3DA75D],
      'borderColor': 0xFF462C71,
      'borderWidth': 2.0,
      'shadowColor': 0x33462C71,
      'shadowOffsetY': 8.0,
      'shadowBlur': 14.0,
      'valueColor': 0xFF134B2A,
      'labelColor': 0xFF1F6D3F,
      'valueFontSize': 12.5,
      'labelFontSize': 11.0,
      'badgeColor': 0xFFEF4444,
      'badgeTextColor': 0xFFFFFFFF,
      'badgeBorderColor': 0xFFFFFFFF,
    };

    return EditableWidget(
      id: 'market-cats-cp-balance-chip',
      typeName: 'MarketBalanceChip',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        final size = _editorNumber(props['size'], 50);
        final radius = _editorNumber(props['radius'], 999);
        final gradient = _editorGradient(
          props['gradient'],
          const [Color(0xFF7BE08F), Color(0xFF50C875), Color(0xFF3DA75D)],
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
        final valueColor = _editorColor(
          props['valueColor'],
          const Color(0xFF134B2A),
        );
        final labelColor = _editorColor(
          props['labelColor'],
          const Color(0xFF1F6D3F),
        );
        final valueFontSize = _editorNumber(props['valueFontSize'], 12.5);
        final labelFontSize = _editorNumber(props['labelFontSize'], 11);
        final badgeColor = _editorColor(
          props['badgeColor'],
          const Color(0xFFEF4444),
        );
        final badgeTextColor = _editorColor(props['badgeTextColor'], Colors.white);
        final badgeBorderColor = _editorColor(
          props['badgeBorderColor'],
          Colors.white,
        );

        return InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: hasPendingRewards
              ? () {
                  setState(() {
                    _activeReward = _pendingRewards.first;
                    _showRewardPopup = true;
                  });
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: _marketIconFrame(
                  borderRadius: radius,
                  colors: gradient,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  shadowColor: shadowColor,
                  shadowOffsetY: shadowY,
                  shadowBlur: shadowBlur,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _cpBalance.toStringAsFixed(1),
                              maxLines: 1,
                              style: TextStyle(
                                color: valueColor,
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.w800,
                                height: 0.96,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'CP',
                          style: TextStyle(
                            color: labelColor,
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.w800,
                            height: 0.96,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_pendingCount > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badgeBorderColor, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        '$_pendingCount',
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    const defaults = <String, dynamic>{
      'width': 32.0,
      'height': 34.0,
      'radius': 14.0,
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
      id: 'market-cats-header-back-button',
      typeName: 'MarketHeaderIconButton',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        final width = _editorNumber(props['width'], 32);
        final height = _editorNumber(props['height'], 34);
        final radius = _editorNumber(props['radius'], 14);
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
          child: SizedBox(
            width: width,
            height: height,
            child: _marketIconFrame(
              borderRadius: radius,
              colors: gradient,
              borderColor: borderColor,
              borderWidth: borderWidth,
              shadowColor: shadowColor,
              shadowOffsetY: shadowY,
              shadowBlur: shadowBlur,
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        );
      },
    );
  }

  Widget _marketIconFrame({
    required Widget child,
    double borderRadius = 999,
    List<Color>? colors,
    Color borderColor = const Color(0xFF462C71),
    double borderWidth = 2,
    Color shadowColor = const Color(0x33462C71),
    double shadowOffsetY = 8,
    double shadowBlur = 14,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors ?? const [Color(0xFF9261F7), Color(0xFF6F43D3)],
        ),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: Offset(0, shadowOffsetY),
            blurRadius: shadowBlur,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: child),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x3DFFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _propsFor(String id) {
    return context.read<EditorController>().propsOf(id);
  }

  String _slugify(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
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

  Widget _centerModal({required Widget child}) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _buyListing = null;
                _showRewardPopup = false;
                _showCpEarnPopup = false;
                _showCpBuyPopup = false;
              });
            },
            child: Container(color: const Color(0x70231437)),
          ),
          Center(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ],
      ),
    );
  }

  Widget _modalSheet({
    required Widget child,
    required double maxWidth,
    double borderRadius = 16,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _frostedPanel(
        editorId: 'market-cats-modal-sheet',
        borderRadius: borderRadius,
        blurSigma: 12,
        backgroundColor: const Color(0xFAF8F2FF),
        borderColor: const Color(0x4D684D9D),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
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
}

class _PendingReward {
  const _PendingReward({required this.id, required this.priceCatpoison});

  final int id;
  final double priceCatpoison;

  factory _PendingReward.fromJson(Map<String, dynamic> json) {
    return _PendingReward(
      id: _toInt(json['id']) ?? 0,
      priceCatpoison: _toDouble(json['price_catpoison']) ?? 0,
    );
  }
}

class _CpPackage {
  const _CpPackage({
    required this.key,
    required this.cp,
    required this.usd,
    required this.label,
    this.bonus = 0,
  });

  final String key;
  final double cp;
  final double usd;
  final String label;
  final double bonus;
}

String _formatCp(double value) {
  if (value.truncateToDouble() == value) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _formatDate(DateTime date) {
  final d = date.toLocal();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
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
