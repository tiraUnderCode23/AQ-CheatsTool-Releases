import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP Client Service with SSL handling for Windows production builds
/// Handles SSL certificate issues and provides robust HTTP functionality
class HttpClientService {
  static HttpClientService? _instance;
  static http.Client? _client;

  // Timeout configuration
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Singleton
  factory HttpClientService() {
    _instance ??= HttpClientService._internal();
    return _instance!;
  }

  HttpClientService._internal();

  /// Get the configured HTTP client
  /// Uses IOClient with custom HttpClient for Windows to handle SSL issues
  static http.Client get client {
    if (_client == null) {
      _initClient();
    }
    return _client!;
  }

  /// Initialize the HTTP client with SSL configuration
  static void _initClient() {
    if (Platform.isWindows) {
      // Create custom HttpClient for Windows with SSL handling
      final httpClient = HttpClient()
        ..connectionTimeout = connectionTimeout
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // Allow Facebook Graph API and GitHub API certificates
          // These are trusted domains for our application
          final trustedHosts = [
            'graph.facebook.com',
            'api.github.com',
            'github.com',
            'objects.githubusercontent.com',
          ];

          if (trustedHosts.any((trusted) => host.contains(trusted))) {
            debugPrint('[HTTP] Allowing certificate for trusted host: $host');
            return true;
          }

          // For other hosts, still allow if in debug mode
          if (kDebugMode) {
            debugPrint('[HTTP] Debug mode: Allowing certificate for: $host');
            return true;
          }

          // In release mode, only allow trusted hosts
          debugPrint(
              '[HTTP] ⚠️ Rejecting certificate for untrusted host: $host');
          return false;
        };

      _client = IOClient(httpClient);
      debugPrint('[HTTP] Initialized Windows HTTP client with SSL handling');
    } else {
      // For other platforms, use the standard client
      _client = http.Client();
      debugPrint('[HTTP] Initialized standard HTTP client');
    }
  }

  /// Reset the client (useful for reconnection)
  static void resetClient() {
    _client?.close();
    _client = null;
    _initClient();
  }

  /// Check if we have internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      debugPrint('[HTTP] Connectivity check error: $e');
      return false;
    }
  }

  /// Make a GET request with timeout and error handling
  static Future<http.Response?> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      // Check internet connectivity first
      if (!await hasInternetConnection()) {
        debugPrint('[HTTP] No internet connection');
        return null;
      }

      final response = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout ?? connectionTimeout);

      return response;
    } on TimeoutException {
      debugPrint('[HTTP] GET request timed out: $url');
      return null;
    } on SocketException catch (e) {
      debugPrint('[HTTP] Socket exception on GET: $e');
      return null;
    } on HandshakeException catch (e) {
      debugPrint('[HTTP] SSL Handshake failed on GET: $e');
      // Try to reset client and retry once
      resetClient();
      try {
        final retryResponse = await client
            .get(Uri.parse(url), headers: headers)
            .timeout(timeout ?? connectionTimeout);
        return retryResponse;
      } catch (retryError) {
        debugPrint('[HTTP] Retry also failed: $retryError');
        return null;
      }
    } catch (e) {
      debugPrint('[HTTP] GET error: $e');
      return null;
    }
  }

  /// Make a POST request with timeout and error handling
  static Future<http.Response?> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      // Check internet connectivity first
      if (!await hasInternetConnection()) {
        debugPrint('[HTTP] No internet connection');
        return null;
      }

      final response = await client
          .post(
            Uri.parse(url),
            headers: headers,
            body: body is String ? body : json.encode(body),
          )
          .timeout(timeout ?? connectionTimeout);

      return response;
    } on TimeoutException {
      debugPrint('[HTTP] POST request timed out: $url');
      return null;
    } on SocketException catch (e) {
      debugPrint('[HTTP] Socket exception on POST: $e');
      return null;
    } on HandshakeException catch (e) {
      debugPrint('[HTTP] SSL Handshake failed on POST: $e');
      // Try to reset client and retry once
      resetClient();
      try {
        final retryResponse = await client
            .post(
              Uri.parse(url),
              headers: headers,
              body: body is String ? body : json.encode(body),
            )
            .timeout(timeout ?? connectionTimeout);
        return retryResponse;
      } catch (retryError) {
        debugPrint('[HTTP] Retry also failed: $retryError');
        return null;
      }
    } catch (e) {
      debugPrint('[HTTP] POST error: $e');
      return null;
    }
  }

  /// Make a PUT request with timeout and error handling
  static Future<http.Response?> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      if (!await hasInternetConnection()) {
        debugPrint('[HTTP] No internet connection');
        return null;
      }

      final response = await client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body is String ? body : json.encode(body),
          )
          .timeout(timeout ?? connectionTimeout);

      return response;
    } on TimeoutException {
      debugPrint('[HTTP] PUT request timed out: $url');
      return null;
    } on SocketException catch (e) {
      debugPrint('[HTTP] Socket exception on PUT: $e');
      return null;
    } on HandshakeException catch (e) {
      debugPrint('[HTTP] SSL Handshake failed on PUT: $e');
      resetClient();
      return null;
    } catch (e) {
      debugPrint('[HTTP] PUT error: $e');
      return null;
    }
  }

  /// Download file with progress callback
  static Future<List<int>?> downloadFile(
    String url, {
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await hasInternetConnection()) {
        debugPrint('[HTTP] No internet connection for download');
        return null;
      }

      final request = http.Request('GET', Uri.parse(url));
      if (headers != null) {
        request.headers.addAll(headers);
      }

      final response = await client.send(request);

      if (response.statusCode != 200) {
        debugPrint('[HTTP] Download failed: ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;

        if (contentLength > 0 && onProgress != null) {
          onProgress(received / contentLength);
        }
      }

      return bytes;
    } catch (e) {
      debugPrint('[HTTP] Download error: $e');
      return null;
    }
  }
}
