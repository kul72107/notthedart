class NavVisibilityPolicy {
  NavVisibilityPolicy._();

  // Web parity: Bottom nav only appears on these route groups.
  static bool shouldShowBottomNav(String path) {
    if (path == '/') return true;
    if (path.startsWith('/market-cats')) return true;
    if (path.startsWith('/my-listings')) return true;
    if (path.startsWith('/my-cats')) return true;
    if (path.startsWith('/profile/')) return true;
    return false;
  }
}
