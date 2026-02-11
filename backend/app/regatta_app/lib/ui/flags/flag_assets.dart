// Maps a flag code (P/I/Z/U/BLACK) to an SVG asset path.

String prepFlagAsset(String code) {
  switch (code.toUpperCase().trim()) {
    case 'P':
      return 'assets/flags/p.png';
    case 'I':
      return 'assets/flags/i.png';
    case 'Z':
      return 'assets/flags/z.png';
    case 'U':
      return 'assets/flags/u.png';
    case 'BLACK':
      return 'assets/flags/black.png';
    default:
      // Safe fallback
      return 'assets/flags/p.png';
  }
}
