// Web'deki src/app/global.css ve page.jsx'lerden birebir cekilmis renk paleti.
// Buradaki her key web'deki kullanim yerine gore isimlendirildi.

import 'dart:ui';

class AppColors {
  AppColors._();

  // Sayfa arka planlari
  static const bgPinkPurple = Color(0xFFF1E8FB);
  static const bgPinkSoft = Color(0xFFFFE6F4);
  static const bgMarketPurple = Color(0xFFBE9BFF);
  static const bgBlack = Color(0xFF000000);

  // Metin
  static const text = Color(0xFF2F1C4A);
  static const textDark = Color(0xFF3B2363);
  static const textMuted = Color(0xFF63408F);
  static const textOnDark = Color(0xFFFFFFFF);
  static const textOnLight = Color(0xFF38243F);
  static const textPurpleDeep = Color(0xFF462C71);
  static const textMarketHeading = Color(0xFF3B2363);
  static const textMarketBody = Color(0xFF3E295F);
  static const textMarketAccent = Color(0xFF5D34A5);
  static const textMarketMuted = Color(0xFF7F61B6);
  static const textMarketSub = Color(0xFF876BBD);
  static const textMarketLink = Color(0xFF5B3B85);
  static const textMarketSuccess = Color(0xFF184D2D);
  static const textMarketSuccessAlt = Color(0xFF1F6D3F);

  // Aksanlar
  static const accentPink = Color(0xFFFF7EB3);
  static const accentPinkDark = Color(0xFFEF1679);
  static const accentPurple = Color(0xFFC084FC);
  static const accentPurpleDark = Color(0xFF8B5CF6);
  static const accentGold = Color(0xFFFBBF24);

  // BottomNav
  static const navIdle = Color(0xFFB89AAD);
  static const navActive = Color(0xFFFF7EB3);
  static const navMarketIdle = Color(0xFF7557A9);
  static const navMarketActive = Color(0xFF5F36A8);
  static const navShellPink = Color(0xE0F7E7F9); // rgba(247,231,249,0.88)
  static const navShellPurple = Color(0xE0E9DAFF); // rgba(233,218,255,0.88)
  static const navBorderPink = Color(0x59FFB8A5); // rgba(255,184,165,0.35)
  static const navBorderPurple = Color(0x425F36A8); // rgba(95,54,168,0.26)

  // Market theme
  static const marketSurface = Color(0xD6F7EFFF); // rgba(247,239,255,0.84)
  static const marketCard = Color(0xEBF9F4FF); // rgba(249,244,255,0.92)
  static const marketAvatar = Color(0xF0E6D8FA); // rgba(230,216,250,0.94)
  static const marketHeader = Color(0xC2ECDFFF); // rgba(236,223,255,0.76)
  static const marketBorder = Color(0x4D644997); // rgba(100,73,151,0.3)
  static const marketBorderSoft = Color(0x47634995); // rgba(99,73,149,0.28)
  static const marketBorderStrong = Color(0x4D684D9D); // rgba(104,77,157,0.3)
  static const marketPatternStroke = Color(0xFF805ECF);
  static const marketModalBackdrop = Color(0x70231437); // rgba(35,20,55,0.44)

  // Pill metin renkleri
  static const textPillDark = Color(0xFFF7E7F9);
  static const textPillSoft = Color(0xFF38243F);
  static const textPillSuccess = Color(0xFF134B2A);
  static const textPillMuted = Color(0xFF563B86);
  static const textPillSoftPurple = Color(0xFF3F2B66);

  // BottomNav aktif alt cizgi gradient stops
  static const indicatorPinkA = Color(0xFFFF7EB3);
  static const indicatorPinkB = Color(0xFFC084FC);
  static const indicatorPurpleA = Color(0xFF8F6BDE);
  static const indicatorPurpleB = Color(0xFF5F36A8);

  // Border default
  static const borderSoft = Color(0x40948BAF); // rgba(148,163,184,0.25)
}

// Gradyan listeleri - web'deki linear-gradient(180deg, ...) stop'lari.
class AppGradients {
  AppGradients._();

  // Pill / action button gradientleri (yukari -> asagi)
  static const gradPillPrimary = [
    Color(0xFF9464FA),
    Color(0xFF7A4DDD),
    Color(0xFF6439C4),
  ];
  static const gradPillSuccess = [
    Color(0xFF7BE08F),
    Color(0xFF50C875),
    Color(0xFF3DA75D),
  ];
  static const gradPillPink = [
    Color(0xFFFF63AD),
    Color(0xFFFF2989),
    Color(0xFFEF1679),
  ];
  static const gradPillDark = [
    Color(0xFF3E3451),
    Color(0xFF242424),
    Color(0xFF17171C),
  ];
  static const gradPillSoftPurple = [
    Color(0xFFF9F3FF),
    Color(0xFFEBDCFF),
    Color(0xFFDCC5FF),
  ];
  static const gradPillMuted = [
    Color(0xFFEFE6FF),
    Color(0xFFE0D0FF),
  ];
  static const gradPillPinkSoft = [
    Color(0xFFFFD4E7),
    Color(0xFFFFADD2),
    Color(0xFFFF8FC1),
  ];

  static const gradActionPrimary = [
    Color(0xFF9767FF),
    Color(0xFF7D4FE0),
    Color(0xFF6738C7),
  ];
  static const gradActionSoft = [
    Color(0xF5FFFFFF),
    Color(0xF0F1E8FF),
  ];
  static const gradActionSuccess = [
    Color(0xFF60C25F),
    Color(0xFF46AB53),
    Color(0xFF2F9244),
  ];
  static const gradActionDanger = [
    Color(0xFFFF7A9F),
    Color(0xFFFF5482),
    Color(0xFFE7396E),
  ];
  static const gradActionPinkWeb = [
    Color(0xFFFF69B1),
    Color(0xFFFF2989),
    Color(0xFFEF1679),
  ];
  static const gradActionPurpleWeb = [
    Color(0xFFA973FF),
    Color(0xFF8B5CF6),
    Color(0xFF7440EA),
  ];
  static const gradActionWhiteWeb = [
    Color(0xF5FFFFFF),
    Color(0xEBFFF1F8),
  ];
  static const gradActionAmberWeb = [
    Color(0xFFFFCF67),
    Color(0xFFF8A845),
    Color(0xFFEE7C2C),
  ];

  // Sayfa arka planlari (dogal gradient)
  static const homePinkPurple = [
    Color(0xFFFFE6F4),
    Color(0xFFF8D9EF),
    Color(0xFFEAC9FF),
    Color(0xFFE0BCFF),
  ];
  static const marketPurple = [
    Color(0xFFEFE2FF),
    Color(0xFFE2CAFF),
    Color(0xFFD3B5FF),
    Color(0xFFBE9BFF),
  ];
  static const exploreDark = [
    Color(0xFF0B0514),
    Color(0xFF1A0A2E),
    Color(0xFF2A0F3D),
    Color(0xFF0B0514),
  ];
}

// BoxShadow preset'leri (web'deki shadow-lg, shadow-xl vs. karsiliklari).
class AppShadows {
  AppShadows._();

  static final actionButton = [
    ShadowSpec(
      color: Color(0x38462C71), // rgba(70,44,113,0.22)
      offsetY: 12,
      blur: 24,
    ),
  ];
  static final pillButton = [
    ShadowSpec(
      color: Color(0x29462C71), // rgba(70,44,113,0.16)
      offsetY: 8,
      blur: 16,
    ),
  ];
  static final navShellPink = [
    ShadowSpec(
      color: Color(0x19C0648C), // rgba(192,100,140,0.1)
      offsetY: -4,
      blur: 20,
    ),
  ];
  static final navShellPurple = [
    ShadowSpec(
      color: Color(0x384C2D7F), // rgba(76,45,127,0.22)
      offsetY: -6,
      blur: 20,
    ),
  ];
  static final marketCard = [
    ShadowSpec(
      color: Color(0x2E533886), // rgba(83,56,134,0.18)
      offsetY: 12,
      blur: 24,
    ),
  ];
  static final marketSurface = [
    ShadowSpec(
      color: Color(0x2E533886),
      offsetY: 14,
      blur: 24,
    ),
  ];
  static final marketHeader = [
    ShadowSpec(
      color: Color(0x2E533886),
      offsetY: 16,
      blur: 28,
    ),
  ];
}

class ShadowSpec {
  final Color color;
  final double offsetX;
  final double offsetY;
  final double blur;
  final double spread;
  const ShadowSpec({
    required this.color,
    this.offsetX = 0,
    required this.offsetY,
    required this.blur,
    this.spread = 0,
  });
}
