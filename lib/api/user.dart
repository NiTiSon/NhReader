/// Public profile of the account behind an API key.
class UserProfile {
  const UserProfile({required this.username, required this.avatarUrl});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String,
      avatarUrl: _resolveAvatar(json['avatar_url'] as String),
    );
  }

  final String username;
  final String avatarUrl;
}

/// The API returns avatar paths relative to the image host, e.g.
/// `avatars/1.png`, which image widgets cannot load as-is.
String _resolveAvatar(String url) {
  if (url.isEmpty || url.startsWith('http')) return url;
  return 'https://i.nhentai.net/${url.replaceFirst(RegExp('^/+'), '')}';
}
