import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/resource_decryptor.dart';

/// CC Messages (CCID) data model
class CCMessage {
  final String ccId;
  final String name;
  final String nameArabic;
  final String description;
  final String category;
  final String longForm;

  CCMessage({
    required this.ccId,
    required this.name,
    this.nameArabic = '',
    this.description = '',
    this.category = '',
    this.longForm = '',
  });

  factory CCMessage.fromJson(Map<String, dynamic> json) {
    // Handle different JSON formats
    // Format 1: ID, Control unit, Text (short form), Text (long form)
    // Format 2: CCID, Name, NameArabic, Description, Category

    final id = json['ID']?.toString() ??
        json['CCID']?.toString() ??
        json['ccId']?.toString() ??
        '';

    final shortText = json['Text (short form)']?.toString() ??
        json['Name']?.toString() ??
        json['name']?.toString() ??
        '';

    final longText = json['Text (long form)']?.toString() ??
        json['Description']?.toString() ??
        json['desc']?.toString() ??
        '';

    final controlUnit = json['Control unit']?.toString() ??
        json['Category']?.toString() ??
        json['category']?.toString() ??
        '';

    final arabicName =
        json['NameArabic']?.toString() ?? json['name_ar']?.toString() ?? '';

    return CCMessage(
      ccId: id,
      name: shortText,
      nameArabic: arabicName,
      description: longText,
      category: controlUnit,
      longForm: longText,
    );
  }

  /// Get searchable text for indexing
  String get searchableText =>
      '$ccId $name $nameArabic $description $category'.toLowerCase();
}

/// CC Messages Provider with optimized search
class CCMessagesProvider extends ChangeNotifier {
  List<CCMessage> _allMessages = [];
  List<CCMessage> _filteredMessages = [];
  final Map<String, List<int>> _searchIndex = {};

  bool _isLoading = false;
  String _searchQuery = '';
  String? _lastError;
  Timer? _debounceTimer;

  // Getters
  List<CCMessage> get messages => _filteredMessages;
  List<CCMessage> get allMessages => _allMessages;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get lastError => _lastError;
  int get totalCount => _allMessages.length;
  int get filteredCount => _filteredMessages.length;

  /// Load CC messages from JSON asset
  Future<void> loadMessages() async {
    if (_isLoading || _allMessages.isNotEmpty) return;

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Try cc_id.json first (from data folder via ResourceDecryptor)
      String jsonString;
      try {
        jsonString = await ResourceDecryptor.loadDataFile('cc_id.json');
      } catch (e) {
        // Fallback to codings.json
        jsonString = await ResourceDecryptor.loadDataFile('codings.json');
      }

      final List<dynamic> jsonList = json.decode(jsonString);

      _allMessages = jsonList.map((item) => CCMessage.fromJson(item)).toList();

      // Try to load Arabic file and merge
      try {
        final arabicJson =
            await ResourceDecryptor.loadDataFile('codings_arabic.json');
        final List<dynamic> arabicList = json.decode(arabicJson);

        // Create map for fast lookup
        final arabicMap = <String, String>{};
        for (var item in arabicList) {
          final ccId =
              item['CCID']?.toString() ?? item['ccId']?.toString() ?? '';
          final nameAr = item['NameArabic']?.toString() ??
              item['name_ar']?.toString() ??
              '';
          if (ccId.isNotEmpty && nameAr.isNotEmpty) {
            arabicMap[ccId] = nameAr;
          }
        }

        // Merge Arabic names
        _allMessages = _allMessages.map((msg) {
          if (arabicMap.containsKey(msg.ccId)) {
            return CCMessage(
              ccId: msg.ccId,
              name: msg.name,
              nameArabic: arabicMap[msg.ccId]!,
              description: msg.description,
              category: msg.category,
            );
          }
          return msg;
        }).toList();
      } catch (e) {
        // Arabic file not available
      }

      // Build search index
      _buildSearchIndex();

      // Initialize filtered list
      _filteredMessages = List.from(_allMessages);

      debugPrint('CC Messages loaded: ${_allMessages.length} items');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error loading CC Messages: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Build optimized search index
  void _buildSearchIndex() {
    _searchIndex.clear();

    for (var i = 0; i < _allMessages.length; i++) {
      final message = _allMessages[i];
      final words = message.searchableText.split(RegExp(r'\s+'));

      for (var word in words) {
        if (word.length < 2) continue;

        // Index by first 3 characters
        final prefix = word.length >= 3 ? word.substring(0, 3) : word;

        if (!_searchIndex.containsKey(prefix)) {
          _searchIndex[prefix] = [];
        }

        if (!_searchIndex[prefix]!.contains(i)) {
          _searchIndex[prefix]!.add(i);
        }
      }
    }

    debugPrint('Search index built: ${_searchIndex.length} prefixes');
  }

  /// Search with debounce
  void search(String query) {
    _searchQuery = query;

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Debounce 150ms
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _performSearch(query);
    });
  }

  /// Perform search
  void _performSearch(String query) {
    if (query.isEmpty) {
      _filteredMessages = List.from(_allMessages);
      notifyListeners();
      return;
    }

    final searchTerms = query.toLowerCase().split(RegExp(r'\s+'));
    final candidateIndices = <int>{};

    // Use index for first term
    if (searchTerms.isNotEmpty) {
      final firstTerm = searchTerms.first;
      final prefix =
          firstTerm.length >= 3 ? firstTerm.substring(0, 3) : firstTerm;

      if (_searchIndex.containsKey(prefix)) {
        candidateIndices.addAll(_searchIndex[prefix]!);
      }

      // Also check nearby prefixes
      for (var key in _searchIndex.keys) {
        if (key.startsWith(prefix) || prefix.startsWith(key)) {
          candidateIndices.addAll(_searchIndex[key]!);
        }
      }
    }

    // Filter candidates
    final results = <CCMessage>[];

    if (candidateIndices.isEmpty) {
      // Fallback to full scan
      for (var message in _allMessages) {
        if (_matchesAllTerms(message, searchTerms)) {
          results.add(message);
          if (results.length >= 200) break;
        }
      }
    } else {
      // Check candidates
      for (var index in candidateIndices) {
        if (index < _allMessages.length) {
          final message = _allMessages[index];
          if (_matchesAllTerms(message, searchTerms)) {
            results.add(message);
            if (results.length >= 200) break;
          }
        }
      }
    }

    _filteredMessages = results;
    notifyListeners();
  }

  /// Check if message matches all search terms
  bool _matchesAllTerms(CCMessage message, List<String> terms) {
    final text = message.searchableText;

    for (var term in terms) {
      if (!text.contains(term)) {
        return false;
      }
    }

    return true;
  }

  /// Get message by CCID
  CCMessage? getMessageByCCID(String ccId) {
    try {
      return _allMessages.firstWhere((m) => m.ccId == ccId);
    } catch (e) {
      return null;
    }
  }

  /// Get messages by category
  List<CCMessage> getMessagesByCategory(String category) {
    return _allMessages
        .where((m) => m.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Get all categories
  List<String> get categories {
    final cats = <String>{};
    for (var msg in _allMessages) {
      if (msg.category.isNotEmpty) {
        cats.add(msg.category);
      }
    }
    return cats.toList()..sort();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _filteredMessages = List.from(_allMessages);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
