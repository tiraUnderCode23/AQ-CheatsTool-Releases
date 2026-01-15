import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/resource_decryptor.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// CC Messages data model - Updated to match actual JSON structure
class CCMessage {
  final int id;
  final String controlUnit;
  final String shortText;
  final String longText;

  CCMessage({
    required this.id,
    required this.controlUnit,
    required this.shortText,
    required this.longText,
  });

  factory CCMessage.fromJson(Map<String, dynamic> json) {
    return CCMessage(
      id: json['ID'] ?? 0,
      controlUnit: json['Control unit']?.toString() ?? '',
      shortText: json['Text (short form)']?.toString() ?? '',
      longText: json['Text (long form)']?.toString() ?? '',
    );
  }

  // Search helper - checks all fields
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return id.toString().contains(query) ||
        controlUnit.toLowerCase().contains(lowerQuery) ||
        shortText.toLowerCase().contains(lowerQuery) ||
        longText.toLowerCase().contains(lowerQuery);
  }

  // Get category from control unit
  String get category {
    final unit = controlUnit.toLowerCase();
    if (unit.contains('engine') ||
        unit.contains('dme') ||
        unit.contains('motor')) {
      return 'Engine';
    }
    if (unit.contains('trans') ||
        unit.contains('gear') ||
        unit.contains('egf')) {
      return 'Transmission';
    }
    if (unit.contains('brake') ||
        unit.contains('dsc') ||
        unit.contains('abs')) {
      return 'Brakes';
    }
    if (unit.contains('airbag') ||
        unit.contains('srs') ||
        unit.contains('safety')) {
      return 'Safety';
    }
    if (unit.contains('light') ||
        unit.contains('lamp') ||
        unit.contains('led') ||
        unit.contains('flc')) {
      return 'Lighting';
    }
    if (unit.contains('klima') ||
        unit.contains('hvac') ||
        unit.contains('heat') ||
        unit.contains('ihka')) {
      return 'HVAC';
    }
    if (unit.contains('comfort') ||
        unit.contains('seat') ||
        unit.contains('door')) {
      return 'Comfort';
    }
    if (unit.contains('audio') ||
        unit.contains('radio') ||
        unit.contains('nbt') ||
        unit.contains('cid')) {
      return 'Entertainment';
    }
    if (unit.contains('acc') ||
        unit.contains('cruise') ||
        unit.contains('lim')) {
      return 'ACC';
    }
    if (unit.contains('trailer') ||
        unit.contains('ahm') ||
        unit.contains('aag')) {
      return 'Trailer';
    }
    if (unit.contains('kombi') ||
        unit.contains('cluster') ||
        unit.contains('instrument')) {
      return 'Cluster';
    }
    return 'Other';
  }
}

/// Tutorial Step model
class TutorialStep {
  final int step;
  final String title;
  final String description;
  final String imagePath;

  TutorialStep({
    required this.step,
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

/// CC Messages Tab with Tutorials
class CCMessagesTab extends StatefulWidget {
  const CCMessagesTab({super.key});

  @override
  State<CCMessagesTab> createState() => _CCMessagesTabState();
}

class _CCMessagesTabState extends State<CCMessagesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<CCMessage> _allMessages = [];
  List<CCMessage> _filteredMessages = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;

  // ISTA Tutorial Steps
  final List<TutorialStep> _istaSteps = [
    TutorialStep(
      step: 1,
      title: 'Open ISTA',
      description:
          'Launch ISTA application and connect to the vehicle. Make sure the ignition is ON.',
      imagePath: 'assets/images/ista1.png',
    ),
    TutorialStep(
      step: 2,
      title: 'Select Vehicle',
      description:
          'Select your BMW vehicle from the list. Click on "Read Vehicle" to load the configuration.',
      imagePath: 'assets/images/ista2.png',
    ),
    TutorialStep(
      step: 3,
      title: 'Open Service Functions',
      description:
          'Navigate to Service Functions > Body > Central Information Display (CID) > Check Control Messages.',
      imagePath: 'assets/images/ista3.png',
    ),
    TutorialStep(
      step: 4,
      title: 'Test CC Message',
      description:
          'Select the CC message you want to test and click "Activate". The message will appear on the dashboard.',
      imagePath: 'assets/images/ista4.png',
    ),
  ];

  // E-Sys Tutorial Steps
  final List<TutorialStep> _esysSteps = [
    TutorialStep(
      step: 1,
      title: 'Launch E-Sys',
      description:
          'Open E-Sys and connect to the vehicle via ENET cable or WiFi adapter.',
      imagePath: 'assets/images/esys_1.png',
    ),
    TutorialStep(
      step: 2,
      title: 'Read FA (Vehicle Order)',
      description:
          'Click on "Read FA" button to read the vehicle configuration. Wait for the process to complete.',
      imagePath: 'assets/images/esys_2.png',
    ),
    TutorialStep(
      step: 3,
      title: 'Read SVT (ECU List)',
      description:
          'Click "Read SVT" to get the list of all ECUs in the vehicle. This may take a few minutes.',
      imagePath: 'assets/images/esys_3.png',
    ),
    TutorialStep(
      step: 4,
      title: 'Select HU_CIC or HU_NBT',
      description:
          'In the ECU tree, locate and select HU_CIC (older) or HU_NBT (newer) depending on your vehicle.',
      imagePath: 'assets/images/esys_4.png',
    ),
    TutorialStep(
      step: 5,
      title: 'Open Coding Data',
      description:
          'Right-click on the HU ECU and select "Coding" > "Read Coding Data".',
      imagePath: 'assets/images/esys_5.png',
    ),
    TutorialStep(
      step: 6,
      title: 'Navigate to CC_MESSAGE',
      description:
          'In the coding parameters, search for "CC_MESSAGE" or navigate to the Check Control section.',
      imagePath: 'assets/images/esys_6.png',
    ),
    TutorialStep(
      step: 7,
      title: 'Modify CC Settings',
      description:
          'Change the CC message parameters as needed. Use the CC ID reference to find the correct values.',
      imagePath: 'assets/images/esys_7.png',
    ),
    TutorialStep(
      step: 8,
      title: 'Write Coding',
      description:
          'Click "Code" or "FDL Code" to write the changes to the ECU. Wait for confirmation.',
      imagePath: 'assets/images/esys_8.png',
    ),
  ];

  final List<String> _categories = [
    'All',
    'ACC',
    'Brakes',
    'Cluster',
    'Comfort',
    'Engine',
    'Entertainment',
    'HVAC',
    'Lighting',
    'Safety',
    'Trailer',
    'Transmission',
    'Other',
  ];

  // Search index for faster searching
  final Map<String, List<int>> _searchIndex = {};
  bool _indexBuilt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCCMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCCMessages() async {
    setState(() => _isLoading = true);

    try {
      final String jsonString =
          await ResourceDecryptor.loadDataFile('cc_id.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      final messages = jsonData.map((e) => CCMessage.fromJson(e)).toList();

      // Build search index for faster searching
      _buildSearchIndex(messages);

      setState(() {
        _allMessages = messages;
        _filteredMessages = _allMessages;
        _isLoading = false;
      });

      debugPrint('CC Messages loaded: ${_allMessages.length} items');
    } catch (e) {
      debugPrint('Error loading CC messages: $e');
      setState(() {
        _allMessages = [];
        _filteredMessages = [];
        _isLoading = false;
      });
    }
  }

  /// Build search index for O(1) prefix lookup
  void _buildSearchIndex(List<CCMessage> messages) {
    _searchIndex.clear();

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      // Index by ID
      _addToIndex(msg.id.toString(), i);

      // Index by words in control unit
      for (final word
          in msg.controlUnit.toLowerCase().split(RegExp(r'[\s/,]+'))) {
        if (word.length >= 2) {
          _addToIndex(word, i);
        }
      }

      // Index by words in short text
      for (final word
          in msg.shortText.toLowerCase().split(RegExp(r'[\s/,!?.]+'))) {
        if (word.length >= 2) {
          _addToIndex(word, i);
        }
      }
    }

    _indexBuilt = true;
    debugPrint('Search index built: ${_searchIndex.length} prefixes');
  }

  void _addToIndex(String text, int index) {
    // Add prefixes for autocomplete-style search
    for (int len = 1; len <= text.length && len <= 8; len++) {
      final prefix = text.substring(0, len);
      _searchIndex.putIfAbsent(prefix, () => []);
      if (!_searchIndex[prefix]!.contains(index)) {
        _searchIndex[prefix]!.add(index);
      }
    }
  }

  void _filterMessages(String query) {
    final lowerQuery = query.toLowerCase().trim();

    setState(() {
      if (lowerQuery.isEmpty && _selectedCategory == 'All') {
        _filteredMessages = _allMessages;
      } else if (_indexBuilt &&
          lowerQuery.isNotEmpty &&
          _searchIndex.containsKey(lowerQuery)) {
        // Fast index-based search
        final indices = _searchIndex[lowerQuery]!;
        _filteredMessages = indices
            .where((i) => i < _allMessages.length)
            .map((i) => _allMessages[i])
            .where((msg) =>
                _selectedCategory == 'All' || msg.category == _selectedCategory)
            .toList();
      } else {
        // Fallback to full text search
        _filteredMessages = _allMessages.where((msg) {
          final matchesSearch =
              lowerQuery.isEmpty || msg.matchesSearch(lowerQuery);
          final matchesCategory =
              _selectedCategory == 'All' || msg.category == _selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();
      }
    });
  }

  // ignore: unused_element
  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterMessages(_searchController.text);
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Image Container
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 400,
                        height: 300,
                        color: Colors.grey[900],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_rounded,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Image not found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              imagePath,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Close Button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // Zoom hint
            Positioned(
              bottom: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded,
                        color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Pinch to zoom • Drag to pan',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D0D1A),
                Color(0xFF1A1A2E),
                Color(0xFF0D0D1A),
              ],
            ),
          ),
          child: Column(
            children: [
              // Header with tabs
              _buildHeader(constraints),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSearchTab(constraints),
                    _buildTutorialTab(_istaSteps, 'ISTA Tutorial', Colors.blue),
                    _buildTutorialTab(
                        _esysSteps, 'E-Sys Tutorial', Colors.green),
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
    final isCompact = constraints.maxWidth < 800;
    final padding = isCompact ? 16.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AQColors.accent.withOpacity(0.3),
                      AQColors.primary.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.message_rounded,
                  color: Colors.white,
                  size: isCompact ? 20 : 24,
                ),
              ),
              SizedBox(width: isCompact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompact ? 'CC Messages' : 'CC Messages & Tutorials',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isCompact)
                      const Text(
                        'Check Control message reference and coding guides',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
              // Stats - hide on very small screens
              if (constraints.maxWidth > 600) ...[
                _buildStatBadge(
                    '${_allMessages.length}', 'Messages', Colors.blue),
                const SizedBox(width: 12),
                _buildStatBadge('4', 'ISTA', Colors.green),
                const SizedBox(width: 12),
                _buildStatBadge('8', 'E-Sys', Colors.orange),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 12 : 20),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AQColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AQColors.accent),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AQColors.accent,
              unselectedLabelColor: Colors.white60,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_rounded, size: 18),
                      if (!isCompact) const SizedBox(width: 8),
                      if (!isCompact) const Text('CC ID Search'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.desktop_windows_rounded, size: 18),
                      if (!isCompact) const SizedBox(width: 8),
                      if (!isCompact) const Text('ISTA Tutorial'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_rounded, size: 18),
                      if (!isCompact) const SizedBox(width: 8),
                      if (!isCompact) const Text('E-Sys Tutorial'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 900;
    final padding = isCompact ? 16.0 : 24.0;

    if (isCompact) {
      // Stack layout for smaller screens
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          children: [
            _buildSearchCard(),
            const SizedBox(height: 16),
            Expanded(child: _buildResultsCard()),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left - Search and Filters
          Flexible(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSearchCard(),
                  const SizedBox(height: 16),
                  _buildCategoryFilter(),
                ],
              ),
            ),
          ),
          SizedBox(width: padding),
          // Right - Results
          Flexible(
            flex: 2,
            child: _buildResultsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search_rounded, color: AQColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Search CC Messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _filterMessages,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, ID, or hex code...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.white.withOpacity(0.5)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      color: Colors.white.withOpacity(0.5),
                      onPressed: () {
                        _searchController.clear();
                        _filterMessages('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AQColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Found: ${_filteredMessages.length} messages',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_list_rounded,
                  color: AQColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              final count = category == 'All'
                  ? _allMessages.length
                  : _allMessages.where((m) => m.category == category).length;

              return FilterChip(
                label: Text('$category ($count)'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? category : 'All';
                    _filterMessages(_searchController.text);
                  });
                },
                backgroundColor: Colors.white.withOpacity(0.05),
                selectedColor: AQColors.accent.withOpacity(0.2),
                checkmarkColor: AQColors.accent,
                labelStyle: TextStyle(
                  color: isSelected ? AQColors.accent : Colors.white70,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AQColors.accent
                      : Colors.white.withOpacity(0.1),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded,
                  color: AQColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'CC Messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AQColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                ),
                child: Text(
                  '${_filteredMessages.length} Results',
                  style: const TextStyle(
                    color: AQColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMessages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredMessages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageItem(_filteredMessages[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(CCMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // ID Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AQColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AQColors.accent.withOpacity(0.3)),
            ),
            child: Text(
              'ID ${message.id}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AQColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Message Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.shortText.isNotEmpty
                      ? message.shortText
                      : 'CC Message ${message.id}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  message.controlUnit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // ECU Path like Python: DKOMBI -> 300A cc_Konfiguration -> cc_MELDUNG_XXXX
                Text(
                  'DKOMBI → 300A cc_Konfiguration → cc_MELDUNG_${message.id.toString().padLeft(4, '0')}',
                  style: TextStyle(
                    color: AQColors.accent.withOpacity(0.7),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.longText.isNotEmpty &&
                    message.longText != 'No further information.') ...[
                  const SizedBox(height: 4),
                  Text(
                    message.longText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor(message.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: _getCategoryColor(message.category).withOpacity(0.3)),
            ),
            child: Text(
              message.category,
              style: TextStyle(
                color: _getCategoryColor(message.category),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Copy Button - copies cc_MELDUNG_XXXX format like Python
          IconButton(
            onPressed: () {
              // Format ID as 4 digits like Python: f"{int(msg_id):04d}"
              final formattedId = message.id.toString().padLeft(4, '0');
              final textToCopy = 'cc_MELDUNG_$formattedId';
              Clipboard.setData(ClipboardData(text: textToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $textToCopy'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AQColors.accent,
                ),
              );
            },
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.5),
            ),
            tooltip: 'Copy cc_MELDUNG path',
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Engine':
        return Colors.red;
      case 'Transmission':
        return Colors.orange;
      case 'Brakes':
        return Colors.yellow;
      case 'Suspension':
        return Colors.purple;
      case 'Lighting':
        return Colors.amber;
      case 'HVAC':
        return Colors.cyan;
      case 'Safety':
        return Colors.pink;
      case 'Comfort':
        return Colors.teal;
      case 'Entertainment':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTutorialTab(
      List<TutorialStep> steps, String title, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tutorial Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.2),
                  accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    title.contains('ISTA')
                        ? Icons.desktop_windows_rounded
                        : Icons.code_rounded,
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${steps.length} steps to complete',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${steps.length} Steps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tutorial Steps Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              return _buildTutorialStepCard(steps[index], accentColor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialStepCard(TutorialStep step, Color accentColor) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${step.step}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image (clickable)
          Expanded(
            child: GestureDetector(
              onTap: () => _showImageDialog(step.imagePath),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          step.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[900],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_rounded,
                                    size: 40,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Step ${step.step}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Zoom overlay on hover
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            step.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
