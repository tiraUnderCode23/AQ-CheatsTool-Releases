import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/zgw_provider.dart';
import '../../core/providers/cc_messages_provider.dart';
import '../../core/providers/activation_provider.dart';
import '../../core/services/auto_update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/log_bar.dart';
// import '../../widgets/ai_chat_widget.dart'; // AI Chat hidden
import '../../widgets/update_dialog.dart';
import '../mgu/mgu_unlock_tab.dart';
import '../cc_messages/cc_messages_tab.dart';
import '../coding/coding_tab.dart';
import '../nbt_evo/nbt_evo_tab.dart';
import '../welcome_light/welcome_light_tab.dart';
import '../psdz/psdz_tab.dart';

/// BMW M Colors - Matching Python's AQ_THEME_CONFIG
const Color _bmwBlue = Color(0xFF3b82f6);
const Color _bmwRed = Color(0xFFef4444);
const Color _bmwWhite = Color(0xFFFFFFFF);
const Color _bmwCyan = Color(0xFF00ffd0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  // Coding Tab is first and main on entry - as requested
  final List<_TabItem> _tabs = [
    _TabItem(
      icon: Icons.code_rounded,
      label: 'BMW Codings',
      color: _bmwBlue,
    ),
    _TabItem(
      icon: Icons.memory_rounded,
      label: 'NBT Evo',
      color: const Color(0xFFf97316), // Orange
    ),
    _TabItem(
      icon: Icons.message_rounded,
      label: 'CC Messages',
      color: const Color(0xFF10b981), // Green
    ),
    _TabItem(
      icon: Icons.lightbulb_rounded,
      label: 'Welcome Light',
      color: const Color(0xFFfbbf24), // Yellow
    ),
    _TabItem(
      icon: Icons.lock_open_rounded,
      label: 'MGU Unlock',
      color: _bmwRed,
    ),
    _TabItem(
      icon: Icons.storage_rounded,
      label: 'PSDZ Utility',
      color: _bmwCyan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Load CC Messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CCMessagesProvider>().loadMessages();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AQColors.backgroundGradient,
            ),
            child: Column(
              children: [
                // App Bar
                _buildAppBar(),

                // Tab Bar
                _buildTabBar(),

                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      CodingTab(), // BMW Codings - First and main tab
                      NbtEvoTab(), // NBT Evo (HDD Guide + Image Retrofit)
                      CCMessagesTab(), // CC Messages
                      WelcomeLightTab(), // Welcome Light
                      MguUnlockTab(), // MGU Unlock
                      PsdzTab(), // PSDZ Data Utility
                    ],
                  ),
                ),

                // LogBar at bottom - matching Python
                LogBar(key: logBarKey),
              ],
            ),
          ),

          // AI Chat Widget - Floating in bottom-right corner (HIDDEN)
          // AIChatWidget(
          //   currentTabIndex: _tabController.index,
          //   onNavigate: (tabIndex) {
          //     setState(() {
          //       _tabController.animateTo(tabIndex);
          //     });
          //   },
          //   onSearch: (tabIndex, query) {
          //     // Navigate to tab and trigger search
          //     setState(() {
          //       _tabController.animateTo(tabIndex);
          //     });
          //     // TODO: Trigger search in the specific tab
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // BMW Logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _bmwBlue.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/bmw_logo.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_bmwBlue, _bmwCyan],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'BMW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // AQ///bimmer Branding - Matching Python's LogBar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'AQ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _bmwBlue,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    '///',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _bmwWhite,
                    ),
                  ),
                  const Text(
                    'bimmer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _bmwRed,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // .com badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _bmwCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _bmwCyan.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '.com',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _bmwCyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.verified_rounded,
                      size: 12, color: _bmwCyan.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'BMW Professional Coding Tool',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Username Display with ✅ checkmark - matching Python
          Consumer<ActivationProvider>(
            builder: (context, activation, _) {
              final username = activation.username ?? 'User';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _bmwBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _bmwBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: _bmwCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _bmwCyan,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // ✅ Green checkmark - matching Python
                    const Icon(
                      Icons.verified,
                      size: 14,
                      color: Color(0xFF00FF00),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 10),

          // ZGW Status
          Consumer<ZGWProvider>(
            builder: (context, zgw, _) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: zgw.isConnected
                      ? const Color(0xFF27C93F).withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: zgw.isConnected
                        ? const Color(0xFF27C93F).withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: zgw.isConnected
                            ? const Color(0xFF27C93F)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      zgw.isConnected
                          ? (zgw.vin.isEmpty ? 'Connected' : zgw.vin)
                          : 'Not Connected',
                      style: TextStyle(
                        fontSize: 12,
                        color: zgw.isConnected
                            ? const Color(0xFF27C93F)
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // WhatsApp Button
          _buildWhatsAppButton(),

          const SizedBox(width: 4),

          // Facebook Button - matching Python
          _buildSocialButton(
            icon: Icons.facebook_rounded,
            color: const Color(0xFF1877F2),
            tooltip: 'Facebook',
            url: 'https://facebook.com/AQbimmer',
          ),

          const SizedBox(width: 4),

          // TikTok Button - matching Python
          _buildSocialButton(
            icon: Icons.music_note_rounded,
            color: const Color(0xFF000000),
            tooltip: 'TikTok',
            url: 'https://tiktok.com/@aqbimmer',
          ),

          const SizedBox(width: 4),

          // Website Button - matching Python
          _buildSocialButton(
            icon: Icons.language_rounded,
            color: _bmwCyan,
            tooltip: 'Website',
            url: 'https://AQbimmer.com',
          ),

          const SizedBox(width: 8),

          // Version Badge with Update Check
          _buildVersionBadge(),

          const SizedBox(width: 8),

          // Settings
          IconButton(
            icon: Icon(
              Icons.settings_rounded,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () {
              _showUserSettingsDialog();
            },
          ),
        ],
      ),
    );
  }

  /// Show user settings dialog with registration data and device fingerprint
  Future<void> _showUserSettingsDialog() async {
    final provider = context.read<ActivationProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bmwBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.person_rounded, color: _bmwBlue, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'User Settings',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User Info Section
                _buildSettingsSection(
                  title: 'Account Information',
                  icon: Icons.account_circle_rounded,
                  color: _bmwBlue,
                  children: [
                    _buildSettingsRow(
                      icon: Icons.person_rounded,
                      label: 'Username',
                      value: provider.username ?? 'Not set',
                    ),
                    _buildSettingsRow(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: provider.email ?? 'Not set',
                    ),
                    _buildSettingsRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: provider.phoneNumber ?? 'Not set',
                    ),
                    _buildSettingsRow(
                      icon: Icons.verified_user_rounded,
                      label: 'Status',
                      value:
                          provider.isActivated ? 'Activated' : 'Not Activated',
                      valueColor:
                          provider.isActivated ? Colors.green : Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Activation Info Section
                _buildSettingsSection(
                  title: 'Activation Details',
                  icon: Icons.vpn_key_rounded,
                  color: _bmwCyan,
                  children: [
                    _buildSettingsRow(
                      icon: Icons.key_rounded,
                      label: 'Activation Key',
                      value: _maskActivationKey(
                          provider.activationKey ?? 'Not set'),
                      copyable: true,
                      fullValue: provider.activationKey ?? '',
                    ),
                    _buildSettingsRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Activated On',
                      value: _formatDate(provider.activationDate),
                    ),
                    _buildSettingsRow(
                      icon: Icons.timer_rounded,
                      label: 'Expires On',
                      value: _formatDate(provider.expirationDate),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Device Info Section
                _buildSettingsSection(
                  title: 'Device Information',
                  icon: Icons.devices_rounded,
                  color: _bmwRed,
                  children: [
                    _buildSettingsRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'Device Fingerprint (HWID)',
                      value: _maskHwid(provider.hwid ?? 'Not available'),
                      copyable: true,
                      fullValue: provider.hwid ?? '',
                    ),
                    _buildSettingsRow(
                      icon: Icons.computer_rounded,
                      label: 'Device ID',
                      value: provider.deviceId ?? 'Unknown',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Manage Account Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bmwBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bmwBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Need to update your account?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate back to activation screen for account management
                          Navigator.pushReplacementNamed(
                              context, '/activation');
                        },
                        icon:
                            const Icon(Icons.manage_accounts_rounded, size: 18),
                        label: const Text('Manage Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bmwBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Build a settings section with title and children
  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  /// Build a settings row with icon, label, and value
  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool copyable = false,
    String? fullValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (copyable && fullValue != null && fullValue.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: fullValue));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied to clipboard'),
                          backgroundColor: const Color(0xFF1E1E2E),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format DateTime for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Mask activation key for display (show first 4 and last 4 chars)
  String _maskActivationKey(String key) {
    if (key.isEmpty || key == 'Not set') return key;
    if (key.length <= 8) return key;
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  /// Mask HWID for display (show first 8 and last 4 chars)
  String _maskHwid(String hwid) {
    if (hwid.isEmpty || hwid == 'Not available') return hwid;
    if (hwid.length <= 12) return hwid;
    return '${hwid.substring(0, 8)}...${hwid.substring(hwid.length - 4)}';
  }

  /// WhatsApp contact button - matching Python's contact feature
  Widget _buildWhatsAppButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _launchWhatsApp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF25D366).withOpacity(0.2),
                const Color(0xFF128C7E).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/whats.png',
                width: 18,
                height: 18,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.chat_rounded,
                  size: 18,
                  color: Color(0xFF25D366),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF25D366),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Launch WhatsApp with predefined number
  Future<void> _launchWhatsApp() async {
    const whatsappNumber = '+972528180757';
    const message = 'Hello, I need help with AQ CheatsTool';
    final url = Uri.parse(
      'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Build social media button - matching Python's social icons
  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required String url,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// Build version badge with update indicator
  Widget _buildVersionBadge() {
    return Consumer<AutoUpdateService>(
      builder: (context, updateService, child) {
        final hasUpdate = updateService.updateAvailable;
        final isChecking = updateService.isChecking;

        return Tooltip(
          message: hasUpdate
              ? 'Update available: ${updateService.latestVersion}'
              : 'Version ${AutoUpdateService.currentVersion}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                if (hasUpdate) {
                  await UpdateDialog.show(context);
                } else {
                  // Check for updates
                  await updateService.checkForUpdates();
                  if (context.mounted && updateService.updateAvailable) {
                    await UpdateDialog.show(context);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'You are on the latest version (${AutoUpdateService.currentVersion})',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        backgroundColor: Color(0xFF1E1E2E),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasUpdate
                      ? _bmwCyan.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasUpdate
                        ? _bmwCyan.withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChecking)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _bmwCyan.withOpacity(0.7),
                        ),
                      )
                    else if (hasUpdate)
                      Stack(
                        children: [
                          const Icon(
                            Icons.system_update_rounded,
                            size: 16,
                            color: _bmwCyan,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      'v${AutoUpdateService.currentVersion}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            hasUpdate ? FontWeight.bold : FontWeight.normal,
                        color: hasUpdate
                            ? _bmwCyan
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                    if (hasUpdate) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _bmwCyan,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AQColors.accent,
        indicatorWeight: 3,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        tabs: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          return AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final isSelected = _tabController.index == index;
              return Tab(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tab.color.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: tab.color.withOpacity(0.3))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: isSelected
                            ? tab.color
                            : Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab.label,
                        style: TextStyle(
                          color: isSelected
                              ? tab.color
                              : Colors.white.withOpacity(0.5),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final Color color;

  _TabItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}
