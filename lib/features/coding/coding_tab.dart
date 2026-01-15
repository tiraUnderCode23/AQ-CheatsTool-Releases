import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/services/resource_decryptor.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../core/config/secrets.dart';

/// Coding data model - matches Python version exactly
class CodingItem {
  final String id;
  final String ecu;
  final String title;
  final String description;
  final String function;
  final List<String> steps;
  final String series;
  final String? submittedBy;
  final String? submissionDate;
  final String status;
  final String version;

  CodingItem({
    required this.id,
    required this.ecu,
    this.title = '',
    this.description = '',
    this.function = '',
    this.steps = const [],
    this.series = '',
    this.submittedBy,
    this.submissionDate,
    this.status = 'active',
    this.version = '1.0',
  });

  factory CodingItem.fromJson(Map<String, dynamic> json) {
    List<String> parseSteps(dynamic stepsData) {
      if (stepsData == null) return [];
      if (stepsData is List) {
        return stepsData.map((e) => e.toString()).toList();
      }
      if (stepsData is String) {
        return stepsData.split('\n').where((s) => s.trim().isNotEmpty).toList();
      }
      return [];
    }

    return CodingItem(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      ecu: json['ecu']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      function: json['function']?.toString() ?? '',
      steps: parseSteps(json['steps']),
      series: json['series']?.toString() ?? '',
      submittedBy:
          json['submitted_by']?.toString() ?? json['added_by']?.toString(),
      submissionDate:
          json['submission_date']?.toString() ?? json['added_date']?.toString(),
      status: json['status']?.toString() ?? 'active',
      version: json['version']?.toString() ?? '1.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ecu': ecu,
        'title': title,
        'description': description,
        'function': function,
        'steps': steps,
        'series': series,
        'submitted_by': submittedBy,
        'submission_date': submissionDate,
        'status': status,
        'version': version,
      };

  String get displayTitle {
    if (title.isNotEmpty &&
        title.toLowerCase() != 'no title' &&
        title.toLowerCase() != 'na') {
      return title;
    }
    if (description.isNotEmpty &&
        description.toLowerCase() != 'no description' &&
        description.toLowerCase() != 'na') {
      return description;
    }
    return 'No Information Available';
  }
}

class CodingTab extends StatefulWidget {
  const CodingTab({super.key});

  @override
  State<CodingTab> createState() => _CodingTabState();
}

class _CodingTabState extends State<CodingTab> {
  // Data
  List<CodingItem> _allCodings = [];
  List<CodingItem> _filteredCodings = [];
  List<CodingItem> _ecuCodings = [];

  // Selection
  String? _selectedEcu;
  CodingItem? _selectedCoding;

  // UI State
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isPushing = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _searchPlaceholderActive = true;

  // GitHub Settings - Same as Python version
  // Token loaded from environment or secrets file
  static String get _githubToken {
    final envToken = const String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
    if (envToken.isNotEmpty) return envToken;
    // Fall back to secrets file
    final tokens = Secrets.githubTokens;
    return tokens.isNotEmpty ? tokens.first : '';
  }
  static const String _repoOwner = 'tiraUnderCode23';
  static const String _repoName = 'AQ';
  static const String _branch = 'main';
  static const String _githubApiBase =
      'https://api.github.com/repos/tiraUnderCode23/AQ/contents/';

  // ECU list from data
  List<String> get _ecus {
    final ecuSet =
        _allCodings.map((c) => c.ecu).where((e) => e.isNotEmpty).toSet();
    return ecuSet.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _loadCodings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCodings() async {
    setState(() => _isLoading = true);

    try {
      // Try loading from ResourceDecryptor (supports both encrypted and dev mode)
      final jsonString = await ResourceDecryptor.loadDataFile('codings.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      setState(() {
        _allCodings = jsonList
            .map((item) => CodingItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _filteredCodings = List.from(_allCodings);
        _isLoading = false;
      });

      debugPrint('ג… Loaded ${_allCodings.length} codings from assets');
    } catch (e) {
      debugPrint('Error loading codings from assets: $e');
      // Try loading from GitHub
      await _syncFromGitHub();
    }
  }

  /// Sync codings from GitHub - matches Python push_changes_to_github
  Future<void> _syncFromGitHub() async {
    setState(() => _isSyncing = true);

    try {
      // Try codingss.json first (English)
      final url = Uri.parse(
          'https://raw.githubusercontent.com/$_repoOwner/$_repoName/$_branch/codingss.json');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        setState(() {
          _allCodings = jsonList
              .map((item) => CodingItem.fromJson(item as Map<String, dynamic>))
              .toList();
          _filteredCodings = List.from(_allCodings);
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('ג… Synced ${_allCodings.length} codings from GitHub'),
                ],
              ),
              backgroundColor: const Color(0xFF27C93F),
            ),
          );
        }
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Sync failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }

    setState(() => _isSyncing = false);
  }

  /// Push changes to GitHub - matches Python push_changes_to_github exactly
  Future<void> _pushToGitHub() async {
    if (_allCodings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No codings to save. Please add some codings first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Color(0xFF00ffd0)),
            SizedBox(width: 8),
            Text('Confirm Save to Server',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'נ“₪ Save all local changes to server?\n\n'
          'ג€¢ Total codings: ${_allCodings.length}\n'
          'ג€¢ This will update the server file\n'
          'ג€¢ Operation cannot be undone\n\n'
          'Continue?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ffd0),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save to Server'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPushing = true);

    try {
      const filePath = 'codingss.json';
      const apiUrl = '$_githubApiBase$filePath';

      // Get current SHA first
      String? currentSha;
      final getResponse = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 30));

      if (getResponse.statusCode == 200) {
        final fileInfo = json.decode(getResponse.body);
        currentSha = fileInfo['sha'];
      }

      // Prepare content
      final newContentJson =
          json.encode(_allCodings.map((c) => c.toJson()).toList());
      final newContentB64 = base64.encode(utf8.encode(newContentJson));
      final commitMessage =
          'Update $filePath via AQ Cheats Flutter app on ${DateTime.now().toIso8601String()}';

      final data = {
        'message': commitMessage,
        'content': newContentB64,
        'branch': _branch,
        if (currentSha != null) 'sha': currentSha,
      };

      // Push to GitHub
      final updateResponse = await http
          .put(
            Uri.parse(apiUrl),
            headers: {
              'Authorization': 'token $_githubToken',
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json',
            },
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (updateResponse.statusCode == 200 ||
          updateResponse.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      'ג… Successfully saved ${_allCodings.length} codings to server!'),
                ],
              ),
              backgroundColor: const Color(0xFF27C93F),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${updateResponse.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('ג Failed to save: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isPushing = false);
  }

  /// Filter codings based on search and ECU selection
  void _filterCodings() {
    final query = _searchController.text.toLowerCase().trim();

    if (_searchPlaceholderActive ||
        query.isEmpty ||
        query == 'search codings...') {
      // Show all codings for selected ECU
      if (_selectedEcu != null) {
        setState(() {
          _ecuCodings =
              _allCodings.where((c) => c.ecu == _selectedEcu).toList();
          _filteredCodings = _ecuCodings;
        });
      } else {
        setState(() {
          _filteredCodings = List.from(_allCodings);
          _ecuCodings = [];
        });
      }
      return;
    }

    // Search within selected ECU only (like Python version)
    if (_selectedEcu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ג ן¸ Please select an ECU first to search'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _filteredCodings = _ecuCodings.where((coding) {
        final searchFields = [
          coding.title,
          coding.description,
          coding.function,
          coding.steps.join(' '),
        ];
        return searchFields.any((field) => field.toLowerCase().contains(query));
      }).toList();
    });
  }

  /// Clear search
  void _clearSearch() {
    _searchController.text = 'Search codings...';
    _searchPlaceholderActive = true;
    _filterCodings();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive padding based on available width
        final horizontalPadding = constraints.maxWidth > 1200 ? 24.0 : 16.0;
        final verticalPadding = constraints.maxHeight > 800 ? 20.0 : 12.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            children: [
              // Header with AQ Branding
              _buildHeader(constraints),

              SizedBox(height: constraints.maxHeight > 600 ? 16 : 8),

              // Main content - 3 panels like Python version
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Panel - ECU List (Green select) - Flexible width
                    Flexible(
                      flex: 2,
                      child: _buildEcuPanel(),
                    ),

                    SizedBox(width: constraints.maxWidth > 1000 ? 12 : 8),

                    // Middle Panel - Codings List (Yellow select)
                    Flexible(
                      flex: 3,
                      child: _buildCodingsPanel(),
                    ),

                    SizedBox(width: constraints.maxWidth > 1000 ? 12 : 8),

                    // Right Panel - Coding Details
                    Flexible(
                      flex: 4,
                      child: _buildDetailsPanel(),
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

  Widget _buildHeader(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 900;

    return Row(
      children: [
        // AQ Brand Header
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AQColors.accent, AQColors.accent.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code_rounded,
                    color: Colors.black, size: isCompact ? 20 : 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isCompact
                        ? 'BMW Coding Database'
                        : 'AQ///bimmer - BMW Coding Database',
                    style: TextStyle(
                      fontSize: isCompact ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Search - Flexible width
        Flexible(
          flex: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150, maxWidth: 300),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: _searchPlaceholderActive ? Colors.grey : Colors.white,
              ),
              onTap: () {
                if (_searchPlaceholderActive) {
                  _searchController.clear();
                  setState(() => _searchPlaceholderActive = false);
                }
              },
              onChanged: (_) {
                if (!_searchPlaceholderActive) {
                  _filterCodings();
                }
              },
              onSubmitted: (_) => _filterCodings(),
              decoration: InputDecoration(
                hintText: 'Search codings...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.5)),
                  onPressed: _clearSearch,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        SizedBox(width: isCompact ? 8 : 12),

        // Add New Coding Button
        ElevatedButton.icon(
          onPressed: _showAddCodingDialog,
          icon: const Icon(Icons.add, size: 18),
          label: Text(isCompact ? 'Add' : 'Add New Coding'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF27C93F),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: 12,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Refresh Button
        ElevatedButton.icon(
          onPressed: _isSyncing ? null : _syncFromGitHub,
          icon: _isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(isCompact ? '' : 'Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AQColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEcuPanel() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AQColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory, color: AQColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'ECUs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AQColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_ecus.length}',
                    style: const TextStyle(
                      color: AQColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ECU List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _ecus.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final ecu = _ecus[index];
                      final isSelected = ecu == _selectedEcu;
                      final count =
                          _allCodings.where((c) => c.ecu == ecu).length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: isSelected
                              ? const Color(0xFF28a745).withOpacity(0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onSecondaryTapDown: (details) {
                              setState(() => _selectedEcu = ecu);
                              _showEcuContextMenu(
                                  context, details.globalPosition, ecu);
                            },
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedEcu = ecu;
                                  _selectedCoding = null;
                                  _ecuCodings = _allCodings
                                      .where((c) => c.ecu == ecu)
                                      .toList();
                                  _filteredCodings = _ecuCodings;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ecu,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.8),
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$count',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Push to GitHub Button
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPushing ? null : _pushToGitHub,
                icon: _isPushing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Save to AQbimmer.com'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ffd0),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodingsPanel() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFffc107).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: Color(0xFFffc107), size: 20),
                const SizedBox(width: 8),
                Text(
                  _selectedEcu != null ? 'Codings - $_selectedEcu' : 'Codings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_filteredCodings.length}',
                    style: const TextStyle(
                      color: Color(0xFFffc107),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Codings List
          Expanded(
            child: _selectedEcu == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back,
                            color: Colors.white.withOpacity(0.3), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Select an ECU to view codings',
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  )
                : _filteredCodings.isEmpty
                    ? Center(
                        child: Text(
                          'No codings found',
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCodings.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final coding = _filteredCodings[index];
                          final isSelected = coding == _selectedCoding;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: isSelected
                                  ? const Color(0xFFffc107).withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: GestureDetector(
                                onSecondaryTapDown: (details) {
                                  setState(() => _selectedCoding = coding);
                                  _showCodingContextMenu(
                                      context, details.globalPosition, coding);
                                },
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedCoding = coding);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          coding.displayTitle,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.9),
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (coding.function.isNotEmpty &&
                                            coding.function.toLowerCase() !=
                                                'na') ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            coding.function,
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                      ),
          ),

          // Add Coding Button
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedEcu != null ? _showAddCodingDialog : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Coding'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27C93F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AQColors.accent.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, color: AQColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Coding Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_selectedCoding != null) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    onPressed: _copyAllDetails,
                    tooltip: 'Copy All',
                  ),
                ],
              ],
            ),
          ),

          // Details Content
          Expanded(
            child: _selectedCoding == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app,
                            color: Colors.white.withOpacity(0.3), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Select a coding to view details',
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onSecondaryTapDown: (details) {
                      _showDetailsContextMenu(context, details.globalPosition);
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText.rich(
                        _buildColoredDetails(_selectedCoding!),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build colored text details like Python version
  TextSpan _buildColoredDetails(CodingItem coding) {
    final spans = <TextSpan>[];

    // ECU
    spans.add(const TextSpan(
      text: 'ECU: ',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ));
    spans.add(TextSpan(
      text: '${coding.ecu}\n',
      style: const TextStyle(
          color: Color(0xFFff3333), fontWeight: FontWeight.bold), // Red
    ));

    // Title
    if (coding.title.isNotEmpty) {
      spans.add(const TextSpan(
        text: 'Title: ',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ));
      spans.add(TextSpan(
        text: '${coding.title}\n',
        style: const TextStyle(color: Colors.white),
      ));
    }

    // Description
    if (coding.description.isNotEmpty) {
      spans.add(const TextSpan(
        text: 'Description: ',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ));
      spans.add(TextSpan(
        text: '${coding.description}\n',
        style: const TextStyle(color: Colors.white),
      ));
    }

    // Submitted by
    final submittedBy = coding.submittedBy ?? 'AQ///bimmer';
    spans.add(TextSpan(
      text: '$submittedBy\n',
      style: const TextStyle(
          color: Color(0xFF00ffd0), fontWeight: FontWeight.bold), // Cyan
    ));

    // Date
    if (coding.submissionDate != null) {
      spans.add(const TextSpan(
        text: 'Date: ',
        style: TextStyle(color: Colors.white70),
      ));
      spans.add(TextSpan(
        text: '${coding.submissionDate}\n',
        style: const TextStyle(
            color: Color(0xFFffc107), fontStyle: FontStyle.italic), // Yellow
      ));
    }

    // Steps
    if (coding.steps.isNotEmpty) {
      spans.add(const TextSpan(
        text: '\nSteps:\n',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ));

      for (int i = 0; i < coding.steps.length; i++) {
        spans.add(_buildColoredStep(i + 1, coding.steps[i]));
      }
    }

    return TextSpan(children: spans);
  }

  /// Build colored step like Python _insert_colored_step
  TextSpan _buildColoredStep(int idx, String step) {
    final spans = <TextSpan>[];

    // Step number
    spans.add(TextSpan(
      text: '$idx. ',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ));

    // Split by '->'
    final tokens = step.split('->').map((t) => t.trim()).toList();

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      Color color = Colors.white;
      FontWeight weight = FontWeight.normal;

      // ECU (first token)
      if (i == 0) {
        color = const Color(0xFFff3333); // Red
        weight = FontWeight.bold;
      }
      // ID (numeric or 3068)
      else if (RegExp(r'^\d+$').hasMatch(token) || token == '3068') {
        color = const Color(0xFFffc107); // Yellow
        weight = FontWeight.bold;
      }
      // Function (all uppercase or contains _)
      else if (token == token.toUpperCase() || token.contains('_')) {
        color = Colors.white;
        weight = FontWeight.bold;
      }
      // OFF states
      else if (['set to off', 'nict_aktiv', 'nicht_aktiv']
          .contains(token.toLowerCase())) {
        color = const Color(0xFFff3333); // Red
        weight = FontWeight.bold;
      }
      // ON states
      else if (['set to on', 'set to aktiv', 'aktiv']
          .contains(token.toLowerCase())) {
        color = const Color(0xFF28a745); // Green
        weight = FontWeight.bold;
      }

      spans.add(TextSpan(
        text: token,
        style: TextStyle(color: color, fontWeight: weight),
      ));

      if (i < tokens.length - 1) {
        spans.add(const TextSpan(
          text: ' -> ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ));
      }
    }

    spans.add(const TextSpan(text: '\n\n'));

    return TextSpan(children: spans);
  }

  /// Copy all details to clipboard
  void _copyAllDetails() {
    if (_selectedCoding == null) return;

    final coding = _selectedCoding!;
    final buffer = StringBuffer();

    buffer.writeln('ECU: ${coding.ecu}');
    if (coding.title.isNotEmpty) buffer.writeln('Title: ${coding.title}');
    if (coding.description.isNotEmpty) {
      buffer.writeln('Description: ${coding.description}');
    }
    buffer.writeln(coding.submittedBy ?? 'AQ///bimmer');
    if (coding.submissionDate != null) {
      buffer.writeln('Date: ${coding.submissionDate}');
    }

    if (coding.steps.isNotEmpty) {
      buffer.writeln('\nSteps:');
      for (int i = 0; i < coding.steps.length; i++) {
        buffer.writeln('${i + 1}. ${coding.steps[i]}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ג… Copied to clipboard'),
        backgroundColor: Color(0xFF27C93F),
      ),
    );
  }

  /// Show Add Coding Dialog
  void _showAddCodingDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final stepsController = TextEditingController();
    String selectedEcu = _selectedEcu ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1A1A2E),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.add_circle,
                            color: Color(0xFF27C93F), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Add New Coding',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ECU Dropdown
                    _buildDialogLabel('ECU'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedEcu.isEmpty ? null : selectedEcu,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        hint: const Text('Select ECU',
                            style: TextStyle(color: Colors.grey)),
                        items: _ecus.map((ecu) {
                          return DropdownMenuItem(value: ecu, child: Text(ecu));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => selectedEcu = value ?? ''),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    _buildDialogLabel('Title'),
                    _buildDialogTextField(titleController),

                    const SizedBox(height: 16),

                    // Description
                    _buildDialogLabel('Description'),
                    _buildDialogTextField(descController, maxLines: 2),

                    const SizedBox(height: 16),

                    // Steps
                    _buildDialogLabel('Steps (one per line)'),
                    _buildDialogTextField(stepsController, maxLines: 5),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (selectedEcu.isEmpty ||
                                titleController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ECU and Title are required'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final steps = stepsController.text
                                .split('\n')
                                .where((s) => s.trim().isNotEmpty)
                                .toList();

                            // Add user attribution
                            steps.add('Added by: AQ///bimmer');

                            final newCoding = CodingItem(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              ecu: selectedEcu,
                              title: titleController.text,
                              description: descController.text,
                              steps: steps,
                              submissionDate: DateTime.now().toIso8601String(),
                              submittedBy: 'AQ///bimmer',
                            );

                            // Add locally
                            this.setState(() {
                              _allCodings.insert(0, newCoding);
                              if (_selectedEcu == selectedEcu) {
                                _ecuCodings.insert(0, newCoding);
                                _filteredCodings.insert(0, newCoding);
                              }
                            });

                            Navigator.of(context).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'ג… Coding "${newCoding.title}" added locally. Remember to Push to GitHub!'),
                                backgroundColor: const Color(0xFF27C93F),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Add Coding'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27C93F),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AQColors.accent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  /// Show context menu for details panel - like Python _show_context_menu
  void _showDetailsContextMenu(BuildContext context, Offset position) {
    if (_selectedCoding == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF2b3e50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        const PopupMenuItem(
          value: 'copy_all',
          child: Row(
            children: [
              Icon(Icons.copy, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('נ“‹ Copy All Content',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_steps',
          child: Row(
            children: [
              Icon(Icons.list, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('נ“ Copy Steps Only',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_numbered',
          child: Row(
            children: [
              Icon(Icons.format_list_numbered, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('נ”¢ Copy Steps with Numbers',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'text_info',
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('ג„¹ן¸ Get Text Info',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy_all':
          _copyAllDetails();
          break;
        case 'copy_steps':
          _copyStepsOnly();
          break;
        case 'copy_numbered':
          _copyNumberedSteps();
          break;
        case 'text_info':
          _showTextInfo();
          break;
      }
    });
  }

  /// Copy only the steps - like Python _copy_steps_only
  void _copyStepsOnly() {
    if (_selectedCoding == null) return;

    final steps = _selectedCoding!.steps;
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ג No steps found to copy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clean steps (remove "Added by:" lines)
    final cleanSteps =
        steps.where((s) => !s.toLowerCase().contains('added by:')).toList();

    final stepsText = cleanSteps.join('\n');
    Clipboard.setData(ClipboardData(text: stepsText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ג… Steps copied (${cleanSteps.length} steps)'),
        backgroundColor: const Color(0xFF27C93F),
      ),
    );
  }

  /// Copy steps with numbers - like Python _copy_numbered_steps
  void _copyNumberedSteps() {
    if (_selectedCoding == null) return;

    final steps = _selectedCoding!.steps;
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ג No steps found to copy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clean and number steps
    final cleanSteps =
        steps.where((s) => !s.toLowerCase().contains('added by:')).toList();

    final buffer = StringBuffer();
    for (int i = 0; i < cleanSteps.length; i++) {
      // Remove existing numbers if present
      String step = cleanSteps[i].replaceFirst(RegExp(r'^\d+[\.\-\)\s]*'), '');
      buffer.writeln('${i + 1}. $step');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ג… Numbered steps copied (${cleanSteps.length} steps)'),
        backgroundColor: const Color(0xFF27C93F),
      ),
    );
  }

  /// Show text info dialog - like Python _show_text_info
  void _showTextInfo() {
    if (_selectedCoding == null) return;

    final coding = _selectedCoding!;
    final buffer = StringBuffer();

    buffer.writeln('ECU: ${coding.ecu}');
    if (coding.title.isNotEmpty) buffer.writeln('Title: ${coding.title}');
    if (coding.description.isNotEmpty) {
      buffer.writeln('Description: ${coding.description}');
    }
    buffer.writeln(coding.submittedBy ?? 'AQ///bimmer');
    if (coding.submissionDate != null) {
      buffer.writeln('Date: ${coding.submissionDate}');
    }
    if (coding.steps.isNotEmpty) {
      buffer.writeln('\nSteps:');
      for (int i = 0; i < coding.steps.length; i++) {
        buffer.writeln('${i + 1}. ${coding.steps[i]}');
      }
    }

    final fullText = buffer.toString();
    final lines = fullText.split('\n').where((l) => l.isNotEmpty).length;
    final chars = fullText.length;
    final words =
        fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final stepsCount = coding.steps.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.info, color: Color(0xFF00ffd0)),
            SizedBox(width: 8),
            Text('Text Information', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('נ“„ Lines', lines.toString()),
            _buildInfoRow('נ“ Characters', chars.toString()),
            _buildInfoRow('נ’¬ Words', words.toString()),
            _buildInfoRow('נ“‹ Steps', stepsCount.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF00ffd0))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Show ECU context menu - like Python show_ecu_menu
  void _showEcuContextMenu(BuildContext context, Offset position, String ecu) {
    final codingsCount = _allCodings.where((c) => c.ecu == ecu).length;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF2b3e50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          value: 'info',
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('ג„¹ן¸ $ecu ($codingsCount codings)',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'add_coding',
          child: Row(
            children: [
              Icon(Icons.add, color: Color(0xFF27C93F), size: 18),
              SizedBox(width: 8),
              Text('ג• Add New Coding', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'disabled_add',
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.grey, size: 18),
              SizedBox(width: 8),
              Text('נ« Add ECU (Disabled)',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'disabled_rename',
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.grey, size: 18),
              SizedBox(width: 8),
              Text('נ« Rename ECU (Disabled)',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'disabled_delete',
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.grey, size: 18),
              SizedBox(width: 8),
              Text('נ« Delete ECU (Disabled)',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'add_coding') {
        setState(() {
          _selectedEcu = ecu;
          _ecuCodings = _allCodings.where((c) => c.ecu == ecu).toList();
          _filteredCodings = _ecuCodings;
        });
        _showAddCodingDialog();
      } else if (value?.startsWith('disabled_') ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'ג ן¸ ECU management is disabled. Contact administrator.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  /// Show Coding context menu - like Python show_coding_menu
  void _showCodingContextMenu(
      BuildContext context, Offset position, CodingItem coding) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF2b3e50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          value: 'info',
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('ג„¹ן¸ ${coding.displayTitle}',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_title',
          child: Row(
            children: [
              Icon(Icons.copy, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('נ“‹ Copy Title', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_all',
          child: Row(
            children: [
              Icon(Icons.content_copy, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('נ“„ Copy All Details',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'disabled_edit',
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.grey, size: 18),
              SizedBox(width: 8),
              Text('נ« Edit Coding (Disabled)',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'disabled_delete',
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.grey, size: 18),
              SizedBox(width: 8),
              Text('נ« Delete Coding (Disabled)',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy_title':
          Clipboard.setData(ClipboardData(text: coding.displayTitle));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ג… Title copied'),
              backgroundColor: Color(0xFF27C93F),
            ),
          );
          break;
        case 'copy_all':
          setState(() => _selectedCoding = coding);
          _copyAllDetails();
          break;
        case 'disabled_edit':
        case 'disabled_delete':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'ג ן¸ Editing/Deleting codings is disabled. You can only add new codings.'),
              backgroundColor: Colors.orange,
            ),
          );
          break;
      }
    });
  }
}
