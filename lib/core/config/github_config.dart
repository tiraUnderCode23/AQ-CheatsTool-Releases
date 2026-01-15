/// GitHub Configuration
/// 
/// This file provides secure GitHub token management.
/// Tokens are loaded from environment variables at build time.
/// 
/// To build with tokens:
/// flutter build windows --release --dart-define=GITHUB_TOKEN=your_token_here
/// 
/// Or set multiple tokens:
/// flutter build windows --release \
///   --dart-define=GITHUB_TOKEN_1=token1 \
///   --dart-define=GITHUB_TOKEN_2=token2

class GitHubConfig {
  /// Primary GitHub token from environment
  static const String token1 = String.fromEnvironment(
    'GITHUB_TOKEN_1',
    defaultValue: '',
  );

  /// Secondary GitHub token from environment (for rate limit rotation)
  static const String token2 = String.fromEnvironment(
    'GITHUB_TOKEN_2',
    defaultValue: '',
  );

  /// Single token alias for simpler usage
  static const String token = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );

  /// Get list of available tokens
  static List<String> get tokens {
    final tokenList = <String>[];
    if (token1.isNotEmpty) tokenList.add(token1);
    if (token2.isNotEmpty) tokenList.add(token2);
    if (token.isNotEmpty && !tokenList.contains(token)) tokenList.add(token);
    return tokenList;
  }

  /// Check if any token is configured
  static bool get hasValidToken => tokens.isNotEmpty;

  /// Repository configuration
  static const String repoOwner = 'tiraUnderCode23';
  static const String repoName = 'AQ';
  static const String branch = 'main';
  static const String usersFile = 'users.json';
  
  /// API base URL
  static String get apiBase => 
    'https://api.github.com/repos/$repoOwner/$repoName/contents/';
}
