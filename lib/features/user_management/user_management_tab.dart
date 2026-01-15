import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/activation_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final activationProvider = context.read<ActivationProvider>();

    // Check if current user is admin
    _isAdmin = activationProvider.activationKey?.startsWith('ADMIN') ?? false;

    if (_isAdmin) {
      // Load users from GitHub (simulated)
      setState(() {
        _users = [
          {
            'id': '1',
            'name': 'User 1',
            'key': 'XXXXX-XXXXXXXX-XXXXX',
            'status': 'active',
            'createdAt': '2024-01-15',
            'expiresAt': '2025-01-15',
          },
          {
            'id': '2',
            'name': 'User 2',
            'key': 'YYYYY-YYYYYYYY-YYYYY',
            'status': 'active',
            'createdAt': '2024-02-20',
            'expiresAt': '2025-02-20',
          },
          {
            'id': '3',
            'name': 'User 3',
            'key': 'ZZZZZ-ZZZZZZZZ-ZZZZZ',
            'status': 'expired',
            'createdAt': '2023-01-01',
            'expiresAt': '2024-01-01',
          },
        ];
        _filteredUsers = List.from(_users);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          return user['name'].toLowerCase().contains(query.toLowerCase()) ||
              user['key'].toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.people_rounded,
                color: AQColors.accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_isAdmin)
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AQColors.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _isAdmin
                ? 'Manage user licenses and activations'
                : 'Your license information',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _isAdmin
                    ? _buildAdminView()
                    : _buildUserView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AQColors.accent),
    );
  }

  Widget _buildAdminView() {
    return Column(
      children: [
        // Stats
        Row(
          children: [
            _buildStatCard(
              title: 'Total Users',
              value: _users.length.toString(),
              icon: Icons.people_rounded,
              color: AQColors.primary,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'Active',
              value: _users
                  .where((u) => u['status'] == 'active')
                  .length
                  .toString(),
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF27C93F),
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'Expired',
              value: _users
                  .where((u) => u['status'] == 'expired')
                  .length
                  .toString(),
              icon: Icons.cancel_rounded,
              color: AQColors.secondary,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Search
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: _filterUsers,
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withOpacity(0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Users list
        Expanded(
          child: _filteredUsers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    return _buildUserCard(_filteredUsers[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserView() {
    final activationProvider = context.watch<ActivationProvider>();

    return Center(
      child: GlassCard(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // License icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activationProvider.isActivated
                    ? const Color(0xFF27C93F).withOpacity(0.1)
                    : AQColors.secondary.withOpacity(0.1),
              ),
              child: Icon(
                activationProvider.isActivated
                    ? Icons.verified_rounded
                    : Icons.warning_rounded,
                color: activationProvider.isActivated
                    ? const Color(0xFF27C93F)
                    : AQColors.secondary,
                size: 40,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              activationProvider.isActivated
                  ? 'License Active'
                  : 'License Inactive',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: activationProvider.isActivated
                    ? const Color(0xFF27C93F)
                    : AQColors.secondary,
              ),
            ),

            const SizedBox(height: 32),

            // License details
            _buildLicenseRow(
                'Activation Key', activationProvider.activationKey ?? 'N/A'),
            _buildLicenseRow(
                'Device ID', activationProvider.deviceId ?? 'Unknown'),
            _buildLicenseRow('Status',
                activationProvider.isActivated ? 'Activated' : 'Not Activated'),

            const SizedBox(height: 24),

            // Actions
            if (!activationProvider.isActivated)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to activation screen
                  },
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Activate License'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AQColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['status'] == 'active';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AQColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user['name'][0],
                style: const TextStyle(
                  color: AQColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user['key'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF27C93F).withOpacity(0.1)
                  : AQColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Expired',
              style: TextStyle(
                color: isActive ? const Color(0xFF27C93F) : AQColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Actions
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: Colors.white.withOpacity(0.5),
            ),
            color: const Color(0xFF1A1A2E),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'renew',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Renew', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded,
                        size: 18, color: AQColors.secondary),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AQColors.secondary)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              // Handle action
            },
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
            Icons.people_outline_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Add New User',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Name field
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'User Name',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Duration dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'License Duration',
                      labelStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: '1m', child: Text('1 Month')),
                      DropdownMenuItem(value: '3m', child: Text('3 Months')),
                      DropdownMenuItem(value: '6m', child: Text('6 Months')),
                      DropdownMenuItem(value: '1y', child: Text('1 Year')),
                      DropdownMenuItem(
                          value: 'lifetime', child: Text('Lifetime')),
                    ],
                    onChanged: (value) {},
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Generate and add user
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AQColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Generate License'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
