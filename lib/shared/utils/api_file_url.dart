/// Resolves uploaded files against the active deployment, including its proxy
/// prefix. Already-prefixed and absolute file URLs must not gain it twice.
String? resolveApiFileUrl(String baseUrl, String path) {
  path = path.trim();
  if (path.isEmpty || path == '-' || path.startsWith('//')) return null;
  final uri = Uri.tryParse(path);
  if (uri == null) return null;
  if (uri.hasScheme) {
    return uri.hasAuthority && (uri.scheme == 'https' || uri.scheme == 'http')
        ? path
        : null;
  }
  final base = Uri.tryParse(baseUrl.trim().replaceAll(RegExp(r'/+$'), ''));
  if (base == null ||
      !base.hasAuthority ||
      (base.scheme != 'http' && base.scheme != 'https')) {
    return null;
  }
  final normalized = path.startsWith('/') ? path : '/$path';
  final prefix = base.path.replaceAll(RegExp(r'/+$'), '');
  if (prefix.isNotEmpty && normalized.startsWith('$prefix/')) {
    return '${base.scheme}://${base.authority}$normalized';
  }
  return '$base$normalized';
}
