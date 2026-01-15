import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/activation_provider.dart';
import '../../core/services/whatsapp_business_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../home/home_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _activationKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isActivating = false;
  String? _errorMessage;
  int _currentMode =
      0; // 0 = Key, 1 = Login, 2 = Register, 3 = Account Management
  bool _obscurePassword = true;

  // OTP verification state
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  // ignore: unused_field
  bool _isSendingOtp = false;

  // Country code for phone
  String _selectedCountryCode = '+972'; // Default to Israel

  // Available country codes
  static const List<Map<String, String>> _countryCodes = [
    {'code': '+972', 'name': 'Israel', 'flag': '🇮🇱'},
    {'code': '+970', 'name': 'Palestine', 'flag': '🇵🇸'},
    {'code': '+966', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+962', 'name': 'Jordan', 'flag': '🇯🇴'},
    {'code': '+20', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+961', 'name': 'Lebanon', 'flag': '🇱🇧'},
    {'code': '+963', 'name': 'Syria', 'flag': '🇸🇾'},
    {'code': '+964', 'name': 'Iraq', 'flag': '🇮🇶'},
    {'code': '+968', 'name': 'Oman', 'flag': '🇴🇲'},
    {'code': '+974', 'name': 'Qatar', 'flag': '🇶🇦'},
    {'code': '+973', 'name': 'Bahrain', 'flag': '🇧🇭'},
    {'code': '+965', 'name': 'Kuwait', 'flag': '🇰🇼'},
    {'code': '+212', 'name': 'Morocco', 'flag': '🇲🇦'},
    {'code': '+216', 'name': 'Tunisia', 'flag': '🇹🇳'},
    {'code': '+213', 'name': 'Algeria', 'flag': '🇩🇿'},
    {'code': '+218', 'name': 'Libya', 'flag': '🇱🇾'},
    {'code': '+249', 'name': 'Sudan', 'flag': '🇸🇩'},
    {'code': '+967', 'name': 'Yemen', 'flag': '🇾🇪'},
    {'code': '+1', 'name': 'USA/Canada', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+90', 'name': 'Turkey', 'flag': '🇹🇷'},
    {'code': '+40', 'name': 'Romania', 'flag': '🇷🇴'},
    {'code': '+31', 'name': 'Netherlands', 'flag': '🇳🇱'},
    {'code': '+32', 'name': 'Belgium', 'flag': '🇧🇪'},
    {'code': '+34', 'name': 'Spain', 'flag': '🇪🇸'},
    {'code': '+39', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': '+41', 'name': 'Switzerland', 'flag': '🇨🇭'},
    {'code': '+43', 'name': 'Austria', 'flag': '🇦🇹'},
    {'code': '+45', 'name': 'Denmark', 'flag': '🇩🇰'},
    {'code': '+46', 'name': 'Sweden', 'flag': '🇸🇪'},
    {'code': '+47', 'name': 'Norway', 'flag': '🇳🇴'},
    {'code': '+48', 'name': 'Poland', 'flag': '🇵🇱'},
    {'code': '+36', 'name': 'Hungary', 'flag': '🇭🇺'},
    {'code': '+30', 'name': 'Greece', 'flag': '🇬🇷'},
    {'code': '+351', 'name': 'Portugal', 'flag': '🇵🇹'},
    {'code': '+380', 'name': 'Ukraine', 'flag': '🇺🇦'},
    {'code': '+7', 'name': 'Russia', 'flag': '🇷🇺'},
    {'code': 'custom', 'name': 'Other (Custom)', 'flag': '🌍'},
  ];

  // Custom country code for manual entry
  String _customCountryCode = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _activationKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final activationProvider = context.read<ActivationProvider>();
    bool success = false;

    if (_currentMode == 0) {
      // Activation key mode
      final key = _activationKeyController.text.trim();
      success = await activationProvider.activateWithKey(key);
    } else if (_currentMode == 1) {
      // Login mode
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      success = await activationProvider.login(email, password);
    } else if (_currentMode == 2) {
      // Register mode - First verify OTP if not verified
      if (!_isOtpVerified) {
        if (!_isOtpSent) {
          // Show WhatsApp HWID initiation dialog first
          final shouldContinue = await _showWhatsAppInitiationDialog();
          if (!shouldContinue) {
            setState(() => _isActivating = false);
            return;
          }

          // Send OTP first
          setState(() {
            _isSendingOtp = true;
            _errorMessage = null;
          });

          final otpSent = await activationProvider.sendOtpForRegistration(
            _getFullPhoneNumber(),
            _nameController.text.trim(),
          );

          setState(() {
            _isSendingOtp = false;
            _isOtpSent = otpSent;
          });

          if (otpSent) {
            // Show OTP input dialog
            await _showOtpVerificationDialog();
          } else {
            setState(() {
              _errorMessage =
                  'Failed to send OTP. Please check your phone number.';
              _isActivating = false;
            });
          }
          return;
        } else {
          // Show OTP dialog again
          await _showOtpVerificationDialog();
          return;
        }
      }

      // OTP verified, proceed with registration
      success = await activationProvider.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _getFullPhoneNumber(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        // Save email for later activation check
        final registeredEmail = _emailController.text.trim();

        // Show success dialog with instructions
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'Registration Successful!',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration request sent successfully.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 12),
                Text(
                  'You will be contacted with your activation code.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AQColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AQColors.accent, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'After receiving the activation code, enter it in the next step',
                          style:
                              TextStyle(color: AQColors.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                      color: AQColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        // Switch to activation key mode and pre-fill email
        setState(() {
          _currentMode = 0; // Switch to activation key mode
          _isActivating = false;
          // Clear password fields but keep email for reference
          _passwordController.clear();
          _confirmPasswordController.clear();
        });

        // Save pending registration email locally
        await activationProvider.savePendingRegistration(registeredEmail);

        return;
      }
    }

    if (mounted) {
      if (success) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        // Check for device mismatch error
        if (activationProvider.lastError == 'DEVICE_MISMATCH') {
          await _showDeviceMismatchDialog();
        } else {
          setState(() {
            _errorMessage = activationProvider.lastError ?? 'Activation failed';
            _isActivating = false;
          });
        }
      }
    }
  }

  /// Show forgot password dialog - sends password via WhatsApp for activated accounts
  Future<void> _showForgotPasswordDialog() async {
    final identifierController =
        TextEditingController(text: _emailController.text);
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text(
                'Account Recovery',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AQColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AQColors.accent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enter your email or phone number. Your account info and a new password will be sent to your registered WhatsApp (activated accounts only)',
                        style: TextStyle(color: AQColors.accent, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: identifierController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email or Phone Number',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintText: 'example@email.com or +972501234567',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person_search_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
              if (dialogMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.withOpacity(0.1)
                        : AQColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.3)
                          : AQColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isSuccess ? Colors.green : AQColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogMessage!,
                          style: TextStyle(
                            color:
                                isSuccess ? Colors.green : AQColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        final identifier = identifierController.text.trim();
                        if (identifier.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Enter your email or phone number';
                            isSuccess = false;
                          });
                          return;
                        }

                        // Check if it's email or phone
                        bool isEmail = identifier.contains('@');
                        if (!isEmail &&
                            !RegExp(r'^[\d+]+$').hasMatch(identifier.replaceAll(
                                RegExp(r'[\s\-()]'), ''))) {
                          setDialogState(() {
                            dialogMessage =
                                'Enter a valid email address or phone number';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final result = await provider
                            .recoverAccountViaEmailOrPhone(identifier);

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage = result['message'] ??
                                'Recovery info sent to your WhatsApp';
                            isSuccess = true;
                          } else {
                            final error = result['error'];
                            switch (error) {
                              case 'NOT_FOUND':
                                dialogMessage = isEmail
                                    ? 'Email not found in our records'
                                    : 'Phone number not found in our records';
                                break;
                              case 'NOT_ACTIVATED':
                                dialogMessage = 'Account not activated yet';
                                break;
                              case 'NO_PHONE':
                                dialogMessage =
                                    'No phone number registered for this account';
                                break;
                              default:
                                dialogMessage = provider.lastError ??
                                    'Failed to recover account';
                            }
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send via WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show account management dialog for activated users
  Future<void> _showAccountManagementDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.manage_accounts_rounded,
                color: AQColors.accent, size: 28),
            SizedBox(width: 12),
            Text('Account Management', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildManagementOption(
              icon: Icons.refresh_rounded,
              title: 'Renew Activation Key',
              subtitle: 'Delete old key and generate new one (OTP)',
              onTap: () {
                Navigator.pop(context);
                _showOtpBasedRenewActivationDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildManagementOption(
              icon: Icons.key_rounded,
              title: 'Recover Activation Key',
              subtitle: 'Send activation key via WhatsApp (OTP)',
              onTap: () {
                Navigator.pop(context);
                _showOtpBasedRecoverKeyDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildManagementOption(
              icon: Icons.lock_reset_rounded,
              title: 'Recover Password',
              subtitle: 'Send new password via WhatsApp (OTP)',
              onTap: () {
                Navigator.pop(context);
                _showOtpBasedRecoverPasswordDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildManagementOption(
              icon: Icons.password_rounded,
              title: 'Change Password',
              subtitle: 'Update your current password (OTP)',
              onTap: () {
                Navigator.pop(context);
                _showOtpBasedChangePasswordDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildManagementOption(
              icon: Icons.email_rounded,
              title: 'Change Email',
              subtitle: 'Update your email address (OTP)',
              onTap: () {
                Navigator.pop(context);
                _showOtpBasedChangeEmailDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildManagementOption(
              icon: Icons.phone_rounded,
              title: 'Change Phone Number',
              subtitle: 'Update your phone number',
              onTap: () {
                Navigator.pop(context);
                _showChangePhoneDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildManagementOption(
              icon: Icons.devices_rounded,
              title: 'Switch Device',
              subtitle: 'Transfer account to new device',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showDeviceSwitchDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: AQColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? AQColors.accent).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: (color ?? AQColors.accent).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? AQColors.accent, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  /// Show renew activation key dialog
  Future<void> _showRenewActivationDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;
    String? newActivationKey;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.refresh_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text('Renew Activation Key',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_rounded,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The old activation key will be deleted and a new one will be generated',
                          style: TextStyle(color: Colors.orange, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                if (dialogMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.1)
                          : AQColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSuccess
                            ? Colors.green.withOpacity(0.3)
                            : AQColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color:
                                  isSuccess ? Colors.green : AQColors.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogMessage!,
                                style: TextStyle(
                                  color: isSuccess
                                      ? Colors.green
                                      : AQColors.secondary,
                                  fontSize: 12,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                        if (isSuccess && newActivationKey != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AQColors.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    newActivationKey!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      color: AQColors.accent),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: newActivationKey!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Activation key copied')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please enter email and password';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final result = await provider.renewActivationKey(
                          emailController.text.trim(),
                          passwordController.text,
                        );

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage =
                                'Activation key renewed successfully and sent via WhatsApp';
                            newActivationKey = result['activationKey'];
                            isSuccess = true;
                          } else {
                            dialogMessage = provider.lastError ??
                                'Failed to renew activation key';
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Renew'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AQColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show get activation key dialog
  Future<void> _showGetActivationKeyDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text('Recover Activation Key',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AQColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AQColors.accent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Activation key will be sent to your registered WhatsApp number',
                        style: TextStyle(color: AQColors.accent, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
              if (dialogMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.withOpacity(0.1)
                        : AQColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.3)
                          : AQColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isSuccess ? Colors.green : AQColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogMessage!,
                          style: TextStyle(
                            color:
                                isSuccess ? Colors.green : AQColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please enter email and password';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final result =
                            await provider.requestActivationKeyViaWhatsApp(
                          emailController.text.trim(),
                          passwordController.text,
                        );

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage =
                                'Activation key sent to your registered WhatsApp number';
                            isSuccess = true;
                          } else {
                            dialogMessage = provider.lastError ??
                                'Failed to send activation key';
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show change password dialog
  Future<void> _showChangePasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.password_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text('Change Password', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                if (dialogMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.1)
                          : AQColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSuccess
                            ? Colors.green.withOpacity(0.3)
                            : AQColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: isSuccess ? Colors.green : AQColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogMessage!,
                            style: TextStyle(
                              color:
                                  isSuccess ? Colors.green : AQColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            oldPasswordController.text.isEmpty ||
                            newPasswordController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please fill in all fields';
                            isSuccess = false;
                          });
                          return;
                        }

                        if (newPasswordController.text !=
                            confirmPasswordController.text) {
                          setDialogState(() {
                            dialogMessage = 'New passwords do not match';
                            isSuccess = false;
                          });
                          return;
                        }

                        if (newPasswordController.text.length < 6) {
                          setDialogState(() {
                            dialogMessage =
                                'Password must be at least 6 characters';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final result = await provider.updatePassword(
                          email: emailController.text.trim(),
                          oldPassword: oldPasswordController.text,
                          newPassword: newPasswordController.text,
                        );

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage = 'Password changed successfully';
                            isSuccess = true;
                          } else {
                            dialogMessage = provider.lastError ??
                                'Failed to change password';
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AQColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show change email dialog
  Future<void> _showChangeEmailDialog() async {
    final currentEmailController =
        TextEditingController(text: _emailController.text);
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.email_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text('Change Email', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Current Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                if (dialogMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.1)
                          : AQColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSuccess
                            ? Colors.green.withOpacity(0.3)
                            : AQColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: isSuccess ? Colors.green : AQColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogMessage!,
                            style: TextStyle(
                              color:
                                  isSuccess ? Colors.green : AQColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (currentEmailController.text.isEmpty ||
                            newEmailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please fill in all fields';
                            isSuccess = false;
                          });
                          return;
                        }

                        if (!newEmailController.text.contains('@')) {
                          setDialogState(() {
                            dialogMessage =
                                'Please enter a valid email address';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final result = await provider.updateEmail(
                          currentEmail: currentEmailController.text.trim(),
                          newEmail: newEmailController.text.trim(),
                          password: passwordController.text,
                        );

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage = 'Email updated successfully';
                            isSuccess = true;
                          } else {
                            dialogMessage =
                                provider.lastError ?? 'Failed to update email';
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AQColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show change phone dialog
  Future<void> _showChangePhoneDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final newPhoneController = TextEditingController();
    final passwordController = TextEditingController();
    final customCountryCodeController = TextEditingController();
    String selectedCountryCode = _selectedCountryCode;
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.phone_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text('Change Phone Number',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: selectedCountryCode == 'custom' ? 70 : 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCountryCode,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1E2E),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.white.withOpacity(0.5)),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          menuMaxHeight: 400,
                          items: _countryCodes.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(country['flag']!,
                                      style: const TextStyle(fontSize: 16)),
                                  if (country['code'] != 'custom') ...[
                                    const SizedBox(width: 4),
                                    Text(country['code']!,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedCountryCode = value);
                            }
                          },
                        ),
                      ),
                    ),
                    // Custom country code input field
                    if (selectedCountryCode == 'custom') ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: customCountryCodeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: InputDecoration(
                            hintText: '40',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                            prefixText: '+',
                            prefixStyle:
                                const TextStyle(color: Colors.white, fontSize: 14),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AQColors.accent, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: newPhoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'New Phone Number',
                          hintText: '5XXXXXXXX',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.3)),
                          labelStyle:
                              TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.phone_rounded,
                              color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                if (dialogMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.1)
                          : AQColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSuccess
                            ? Colors.green.withOpacity(0.3)
                            : AQColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: isSuccess ? Colors.green : AQColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogMessage!,
                            style: TextStyle(
                              color:
                                  isSuccess ? Colors.green : AQColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            newPhoneController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please fill in all fields';
                            isSuccess = false;
                          });
                          return;
                        }

                        if (newPhoneController.text.length < 7) {
                          setDialogState(() {
                            dialogMessage = 'Phone number is too short';
                            isSuccess = false;
                          });
                          return;
                        }

                        // Validate custom country code if selected
                        if (selectedCountryCode == 'custom' &&
                            customCountryCodeController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please enter country code';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        // Remove leading zero if present
                        String phone = newPhoneController.text.trim();
                        if (phone.startsWith('0')) {
                          phone = phone.substring(1);
                        }
                        // Handle custom country code
                        final countryCode = selectedCountryCode == 'custom'
                            ? '+${customCountryCodeController.text.replaceAll('+', '')}'
                            : selectedCountryCode;
                        final fullPhone = '$countryCode$phone';

                        final provider = context.read<ActivationProvider>();
                        final result = await provider.updatePhone(
                          email: emailController.text.trim(),
                          newPhone: fullPhone,
                          password: passwordController.text,
                        );

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage = 'Phone number updated successfully';
                            isSuccess = true;
                          } else {
                            dialogMessage = provider.lastError ??
                                'Failed to update phone number';
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AQColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show device switch dialog
  Future<void> _showDeviceSwitchDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? dialogMessage;
    bool isSuccess = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.devices_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Switch Device', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The old device will be unlinked and this device will be linked',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.timer_rounded,
                            color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Device can be switched once every 24 hours',
                          style: TextStyle(color: Colors.orange, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
              if (dialogMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.withOpacity(0.1)
                        : AQColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.3)
                          : AQColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isSuccess ? Colors.green : AQColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogMessage!,
                          style: TextStyle(
                            color:
                                isSuccess ? Colors.green : AQColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess)
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          setDialogState(() {
                            dialogMessage = 'Please enter email and password';
                            isSuccess = false;
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          dialogMessage = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final result = await provider.manageDeviceBinding(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          unbindOldDevice: true,
                        );

                        setDialogState(() {
                          isLoading = false;
                          if (result['success'] == true) {
                            dialogMessage = 'New device linked successfully';
                            isSuccess = true;
                          } else {
                            dialogMessage =
                                provider.lastError ?? 'Failed to switch device';
                            isSuccess = false;
                          }
                        });
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Switch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show WhatsApp HWID initiation dialog before OTP
  /// User must send their HWID to the business WhatsApp to initiate conversation
  Future<bool> _showWhatsAppInitiationDialog() async {
    final hwid = context.read<ActivationProvider>().hwid ?? 'Loading...';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF25D366).withOpacity(0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Start WhatsApp Chat',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Important! You must send your HWID to our WhatsApp first to receive the OTP verification code.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your HWID:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hwid,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: Color(0xFF25D366), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: hwid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('HWID copied to clipboard'),
                              backgroundColor: Color(0xFF25D366),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF25D366), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Steps:',
                          style: TextStyle(
                            color: Color(0xFF25D366),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Click "Send HWID" button below\n'
                    '2. WhatsApp will open automatically\n'
                    '3. Send the message with your HWID\n'
                    '4. Come back and click "Continue"',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Open WhatsApp with pre-filled HWID message
              final phone = WhatsAppBusinessApiService.businessPhoneNumber
                  .replaceAll('+', '');
              final message = Uri.encodeComponent('HWID: $hwid');
              final whatsappUrl = 'https://wa.me/$phone?text=$message';

              if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                await launchUrl(Uri.parse(whatsappUrl),
                    mode: LaunchMode.externalApplication);
              } else {
                // Fallback - copy to clipboard
                Clipboard.setData(ClipboardData(text: 'HWID: $hwid'));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'HWID copied! Send it to: ${WhatsAppBusinessApiService.businessPhoneNumber}'),
                      backgroundColor: Color(0xFF25D366),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send HWID'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AQColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show OTP verification dialog
  Future<void> _showOtpVerificationDialog() async {
    String? dialogError;
    bool isVerifying = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
            ),
            title: const Row(
              children: [
                Icon(Icons.phone_android_rounded,
                    color: AQColors.accent, size: 28),
                SizedBox(width: 12),
                Text(
                  'Phone Verification',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Development mode notice
                if (WhatsAppBusinessApiService.isDevelopmentMode) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bug_report_rounded,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🔧 Development Mode: Check Console for OTP code',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AQColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AQColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          WhatsAppBusinessApiService.isDevelopmentMode
                              ? 'OTP code is shown in Console window (Debug)'
                              : 'A 5-digit verification code has been sent to your WhatsApp number',
                          style: const TextStyle(
                              color: AQColors.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 5,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    hintText: '• • • • •',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AQColors.accent, width: 2),
                    ),
                  ),
                ),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(
                          color: AQColors.secondary, fontSize: 12),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final provider = context.read<ActivationProvider>();
                    final sent = await provider.sendOtpForRegistration(
                      _getFullPhoneNumber(),
                      _nameController.text.trim(),
                    );
                    if (sent && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification code resent'),
                          backgroundColor: AQColors.accent,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(color: AQColors.accent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _otpController.clear();
                  Navigator.pop(context, false);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        if (_otpController.text.length != 5) {
                          setDialogState(() {
                            dialogError = 'Enter the 5-digit code';
                          });
                          return;
                        }

                        setDialogState(() {
                          isVerifying = true;
                          dialogError = null;
                        });

                        final provider = context.read<ActivationProvider>();
                        final verified = provider.verifyOtp(
                          _getFullPhoneNumber(),
                          _otpController.text,
                        );

                        setDialogState(() => isVerifying = false);

                        if (verified) {
                          if (context.mounted) Navigator.pop(context, true);
                        } else {
                          setDialogState(() {
                            dialogError =
                                'Invalid or expired verification code';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AQColors.accent,
                  foregroundColor: Colors.black,
                ),
                child: isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        _isOtpVerified = true;
      });
      // Now proceed with registration
      await _activate();
    } else {
      setState(() {
        _isActivating = false;
      });
    }
  }

  /// Show device mismatch warning dialog
  Future<void> _showDeviceMismatchDialog() async {
    // Remove unused variable
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AQColors.secondary.withOpacity(0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AQColors.secondary, size: 32),
            SizedBox(width: 12),
            Text(
              'Security Alert',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '⚠️ Your account is linked to another device!',
              style: TextStyle(
                color: AQColors.secondary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You cannot log in from this device because your account is linked to a different device.',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '📱 You can switch device once every 24 hours',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🔐 The old device will be unlinked',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'switch'),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Remove old device and link new'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AQColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == 'switch') {
      // Show password confirmation for device switch
      await _confirmDeviceSwitch();
    } else {
      setState(() {
        _errorMessage = 'Your account is linked to another device';
        _isActivating = false;
      });
    }
  }

  /// Confirm device switch with password
  Future<void> _confirmDeviceSwitch() async {
    final passwordController = TextEditingController();
    bool isLoading = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AQColors.accent, size: 28),
              SizedBox(width: 12),
              Text(
                'Confirm Password',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your password to confirm device switch',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      final provider = context.read<ActivationProvider>();
                      final result = await provider.switchDevice(
                        _emailController.text.trim(),
                        passwordController.text,
                      );
                      setDialogState(() => isLoading = false);
                      if (result['success'] == true) {
                        if (context.mounted) Navigator.pop(context, true);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  provider.lastError ?? 'Device switch failed'),
                              backgroundColor: AQColors.secondary,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AQColors.accent,
                foregroundColor: Colors.black,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Device switch successful, try login again
      await _activate();
    } else {
      setState(() {
        _isActivating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AQColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            // BMW Dark Wallpaper Background
            Positioned.fill(
              child: Image.asset(
                'assets/images/bmw_background.jpg',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.3),
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to gradient if image not found
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: AQColors.backgroundGradient,
                    ),
                  );
                },
              ),
            ),

            // Dark overlay for better readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0a0a14).withOpacity(0.7),
                      const Color(0xFF1a1a2e).withOpacity(0.85),
                      const Color(0xFF0a0a14).withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _HexagonPatternPainter(),
              ),
            ),

            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        _buildLogo(),

                        const SizedBox(height: 40),

                        // Activation card
                        _buildActivationCard(),

                        const SizedBox(height: 16),

                        // Mode switcher
                        _buildModeSwitcher(),

                        const SizedBox(height: 24),

                        // Contact info
                        _buildContactInfo(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AQColors.primary.withOpacity(0.3),
                AQColors.accent.withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: AQColors.accent.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AQColors.accent.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AQColors.primary, AQColors.accent],
              ).createShader(bounds),
              child: const Text(
                'AQ',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AQColors.primary, AQColors.accent],
          ).createShader(bounds),
          child: const Text(
            'AQ CheatsTool',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'BMW Professional Diagnostic Tool',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildActivationCard() {
    return GlassCard(
      width: 400,
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _currentMode == 0
                      ? Icons.key_rounded
                      : _currentMode == 1
                          ? Icons.login_rounded
                          : Icons.person_add_rounded,
                  color: AQColors.accent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _currentMode == 0
                      ? 'Activate Program'
                      : _currentMode == 1
                          ? 'Login'
                          : 'New Account',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              _currentMode == 0
                  ? 'Enter your activation key'
                  : _currentMode == 1
                      ? 'Enter your login credentials'
                      : 'Enter your details to register',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 32),

            // Mode-specific fields
            if (_currentMode == 0) ...[
              // Activation key input
              _buildActivationKeyField(),
            ] else if (_currentMode == 1) ...[
              // Login fields
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showForgotPasswordDialog,
                  icon: const Icon(Icons.lock_reset_rounded,
                      color: AQColors.accent, size: 16),
                  label: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AQColors.accent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Registration fields
              _buildNameField(),
              const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              _buildConfirmPasswordField(),
            ],

            // HWID Display
            if (_currentMode != 2) ...[
              const SizedBox(height: 16),
              _buildHWIDDisplay(),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AQColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AQColors.secondary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AQColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AQColors.secondary,
                          fontSize: 13,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isActivating ? null : _activate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AQColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isActivating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _currentMode == 0
                                ? Icons.check_circle_outline
                                : _currentMode == 1
                                    ? Icons.login_rounded
                                    : Icons.person_add_rounded,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentMode == 0
                                ? 'Activate'
                                : _currentMode == 1
                                    ? 'Login'
                                    : 'Register',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildActivationKeyField() {
    return TextFormField(
      controller: _activationKeyController,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        letterSpacing: 2,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
        UpperCaseTextFormatter(),
        ActivationKeyFormatter(),
      ],
      decoration: InputDecoration(
        hintText: 'XXXXX-XXXXXXXX-XXXXX',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          letterSpacing: 2,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AQColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AQColors.secondary),
        ),
        prefixIcon: Icon(
          Icons.vpn_key_rounded,
          color: Colors.white.withOpacity(0.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            Icons.paste_rounded,
            color: Colors.white.withOpacity(0.5),
          ),
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              _activationKeyController.text = data!.text!.toUpperCase();
            }
          },
          tooltip: 'Paste',
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the activation key';
        }
        final cleanKey = value.replaceAll('-', '');
        if (cleanKey.length != 18) {
          return 'Invalid activation key';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AQColors.accent, width: 2),
        ),
        prefixIcon:
            Icon(Icons.email_rounded, color: Colors.white.withOpacity(0.5)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return 'Invalid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AQColors.accent, width: 2),
        ),
        prefixIcon:
            Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.5)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white.withOpacity(0.5),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter password';
        }
        if (_currentMode == 2 && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Full Name',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AQColors.accent, width: 2),
        ),
        prefixIcon:
            Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.5)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code dropdown
            Container(
              width: _selectedCountryCode == 'custom' ? 70 : 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E2E),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: Icon(Icons.arrow_drop_down,
                      color: Colors.white.withOpacity(0.5)),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  menuMaxHeight: 400,
                  items: _countryCodes.map((country) {
                    return DropdownMenuItem<String>(
                      value: country['code'],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(country['flag']!,
                              style: const TextStyle(fontSize: 16)),
                          if (country['code'] != 'custom') ...[
                            const SizedBox(width: 4),
                            Text(country['code']!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCountryCode = value);
                    }
                  },
                ),
              ),
            ),
            // Custom country code input field
            if (_selectedCountryCode == 'custom') ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: _customCountryCode,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    hintText: '40',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixText: '+',
                    prefixStyle:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AQColors.accent, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _customCountryCode = value);
                  },
                  validator: (value) {
                    if (_selectedCountryCode == 'custom' &&
                        (value == null || value.isEmpty)) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
            const SizedBox(width: 8),
            // Phone number field
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '5XXXXXXXX',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AQColors.accent, width: 2),
                  ),
                  prefixIcon: Icon(Icons.phone_rounded,
                      color: Colors.white.withOpacity(0.5)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter phone number';
                  }
                  if (value.length < 7) {
                    return 'Phone number is too short';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Get full phone number with country code
  String _getFullPhoneNumber() {
    String phone = _phoneController.text.trim();
    // Remove leading zero if present
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    // Handle custom country code
    final countryCode = _selectedCountryCode == 'custom'
        ? '+${_customCountryCode.replaceAll('+', '')}'
        : _selectedCountryCode;
    return '$countryCode$phone';
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AQColors.accent, width: 2),
        ),
        prefixIcon:
            Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.5)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildHWIDDisplay() {
    final hwid = context.watch<ActivationProvider>().hwid ?? 'Loading...';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.computer_rounded,
              color: Colors.white.withOpacity(0.5), size: 18),
          const SizedBox(width: 8),
          Text(
            'HWID: ',
            style:
                TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          Expanded(
            child: Text(
              hwid,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded,
                color: Colors.white.withOpacity(0.5), size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hwid));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('HWID copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModeButton(0, Icons.key_rounded, 'Activation Code'),
            const SizedBox(width: 12),
            _buildModeButton(1, Icons.login_rounded, 'Login'),
            const SizedBox(width: 12),
            _buildModeButton(2, Icons.person_add_rounded, 'New Account'),
          ],
        ),
        const SizedBox(height: 12),
        // Account Management Button for activated users
        GestureDetector(
          onTap: _showAccountManagementDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AQColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AQColors.accent.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.manage_accounts_rounded,
                    color: AQColors.accent, size: 16),
                SizedBox(width: 8),
                Text(
                  'Account Management for Activated Users',
                  style: TextStyle(
                    color: AQColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(int mode, IconData icon, String label) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _currentMode = mode;
        _errorMessage = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AQColors.accent : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isSelected ? AQColors.accent : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? AQColors.accent
                    : Colors.white.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        Text(
          'To get an activation key, contact us',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        // First row - WhatsApp and Telegram
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildContactButton(
              icon: Icons.phone,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => _launchUrl('https://wa.me/+972528180757'),
            ),
            const SizedBox(width: 16),
            _buildContactButton(
              icon: Icons.send_rounded,
              label: 'Telegram',
              color: const Color(0xFF0088CC),
              onTap: () => _launchUrl('https://t.me/aqbimmer'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - Social media buttons matching Python
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildContactButton(
              icon: Icons.facebook_rounded,
              label: 'Facebook',
              color: const Color(0xFF1877F2),
              onTap: () => _launchUrl('https://facebook.com/AQbimmer'),
            ),
            const SizedBox(width: 12),
            _buildContactButton(
              icon: Icons.music_note_rounded,
              label: 'TikTok',
              color: Colors.white,
              onTap: () => _launchUrl('https://tiktok.com/@aqbimmer'),
            ),
            const SizedBox(width: 12),
            _buildContactButton(
              icon: Icons.language_rounded,
              label: 'Website',
              color: const Color(0xFF00ffd0), // AQ Cyan
              onTap: () => _launchUrl('https://AQbimmer.com'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Delete & Create New button - matching Python
        GestureDetector(
          onTap: _deleteAndCreateNew,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFef4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border:
                  Border.all(color: const Color(0xFFef4444).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Color(0xFFef4444), size: 16),
                SizedBox(width: 8),
                Text(
                  'Delete Old Registration & Create New',
                  style: TextStyle(
                    color: Color(0xFFef4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteAndCreateNew() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AQColors.secondary.withOpacity(0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AQColors.secondary, size: 28),
            SizedBox(width: 12),
            Text(
              'Confirm Delete',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ WARNING: This will permanently delete your current registration and activation!',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to:\n• Delete your current account\n• Remove your activation file\n• Start fresh registration',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AQColors.secondary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = context.read<ActivationProvider>();
      await provider.deleteRegistration();
      setState(() {
        _currentMode = 2; // Switch to register mode
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _activationKeyController.clear();
        _errorMessage = null;
      });
    }
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OTP-Based User Management Dialogs
  // All operations require OTP verification via WhatsApp
  // ============================================================

  /// Generic OTP-based operation dialog
  Future<void> _showOtpOperationDialog({
    required String title,
    required IconData icon,
    required String operationType,
    String? additionalFieldLabel,
    bool isPasswordField = false,
  }) async {
    final emailController = TextEditingController(text: _emailController.text);
    final otpController = TextEditingController();
    final additionalController = TextEditingController();

    bool isLoading = false;
    bool otpSent = false;
    String? dialogMessage;
    bool isSuccess = false;
    String? maskedPhone;
    String? resultValue;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
          ),
          title: Row(
            children: [
              Icon(icon, color: AQColors.accent, size: 28),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AQColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AQColors.accent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security_rounded,
                          color: AQColors.accent, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OTP verification required via WhatsApp',
                          style:
                              TextStyle(color: AQColors.accent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Email field
                TextField(
                  controller: emailController,
                  enabled: !otpSent,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),

                if (otpSent) ...[
                  const SizedBox(height: 12),

                  // OTP field
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Enter OTP',
                      labelStyle:
                          TextStyle(color: Colors.white.withOpacity(0.7)),
                      helperText:
                          maskedPhone != null ? 'Sent to $maskedPhone' : null,
                      helperStyle: const TextStyle(color: Colors.green),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),

                  // Additional field if needed (e.g., new email, new password)
                  if (additionalFieldLabel != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: additionalController,
                      obscureText: isPasswordField,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: additionalFieldLabel,
                        labelStyle:
                            TextStyle(color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(
                          isPasswordField
                              ? Icons.lock_rounded
                              : Icons.edit_rounded,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ],

                // Message display
                if (dialogMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Colors.green.withOpacity(0.1)
                          : AQColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSuccess
                            ? Colors.green.withOpacity(0.3)
                            : AQColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color:
                                  isSuccess ? Colors.green : AQColors.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogMessage!,
                                style: TextStyle(
                                  color: isSuccess
                                      ? Colors.green
                                      : AQColors.secondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isSuccess && resultValue != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AQColors.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    resultValue!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      color: AQColors.accent),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: resultValue!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Copied to clipboard')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isSuccess ? 'Close' : 'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            if (!isSuccess) ...[
              if (!otpSent)
                // Send OTP button
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (emailController.text.isEmpty) {
                            setDialogState(() {
                              dialogMessage = 'Please enter your email';
                              isSuccess = false;
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            dialogMessage = null;
                          });

                          final provider = context.read<ActivationProvider>();
                          final result =
                              await provider.sendOtpForUserManagement(
                            emailController.text.trim(),
                          );

                          setDialogState(() {
                            isLoading = false;
                            if (result['success'] == true) {
                              otpSent = true;
                              maskedPhone = result['phone'];
                              dialogMessage = 'OTP sent to your WhatsApp';
                              isSuccess = false; // Not final success yet
                            } else {
                              dialogMessage =
                                  provider.lastError ?? 'Failed to send OTP';
                              isSuccess = false;
                            }
                          });
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send OTP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                )
              else
                // Verify & Execute button
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (otpController.text.isEmpty ||
                              otpController.text.length < 5) {
                            setDialogState(() {
                              dialogMessage = 'Please enter the 5-digit OTP';
                              isSuccess = false;
                            });
                            return;
                          }

                          if (additionalFieldLabel != null &&
                              additionalController.text.isEmpty) {
                            setDialogState(() {
                              dialogMessage = 'Please fill in all fields';
                              isSuccess = false;
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            dialogMessage = null;
                          });

                          final provider = context.read<ActivationProvider>();
                          Map<String, dynamic> result;

                          // Execute based on operation type
                          switch (operationType) {
                            case 'recover_password':
                              result = await provider.recoverPasswordWithOtp(
                                email: emailController.text.trim(),
                                otp: otpController.text.trim(),
                              );
                              break;
                            case 'recover_key':
                              result =
                                  await provider.recoverActivationKeyWithOtp(
                                email: emailController.text.trim(),
                                otp: otpController.text.trim(),
                              );
                              resultValue = result['activationKey'];
                              break;
                            case 'renew_key':
                              result = await provider.renewActivationKeyWithOtp(
                                email: emailController.text.trim(),
                                otp: otpController.text.trim(),
                              );
                              resultValue = result['activationKey'];
                              break;
                            case 'change_email':
                              result = await provider.changeEmailWithOtp(
                                currentEmail: emailController.text.trim(),
                                newEmail: additionalController.text.trim(),
                                otp: otpController.text.trim(),
                              );
                              break;
                            case 'change_password':
                              result = await provider.changePasswordWithOtp(
                                email: emailController.text.trim(),
                                otp: otpController.text.trim(),
                                newPassword: additionalController.text.trim(),
                              );
                              break;
                            default:
                              result = {
                                'success': false,
                                'error': 'Unknown operation'
                              };
                          }

                          setDialogState(() {
                            isLoading = false;
                            if (result['success'] == true) {
                              dialogMessage =
                                  result['message'] ?? 'Operation successful';
                              isSuccess = true;
                            } else {
                              dialogMessage =
                                  provider.lastError ?? 'Operation failed';
                              isSuccess = false;
                            }
                          });
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Verify & Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AQColors.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show OTP-based recover password dialog
  Future<void> _showOtpBasedRecoverPasswordDialog() async {
    await _showOtpOperationDialog(
      title: 'Recover Password',
      icon: Icons.lock_reset_rounded,
      operationType: 'recover_password',
    );
  }

  /// Show OTP-based recover activation key dialog
  Future<void> _showOtpBasedRecoverKeyDialog() async {
    await _showOtpOperationDialog(
      title: 'Recover Activation Key',
      icon: Icons.key_rounded,
      operationType: 'recover_key',
    );
  }

  /// Show OTP-based renew activation key dialog
  Future<void> _showOtpBasedRenewActivationDialog() async {
    await _showOtpOperationDialog(
      title: 'Renew Activation Key',
      icon: Icons.refresh_rounded,
      operationType: 'renew_key',
    );
  }

  /// Show OTP-based change email dialog
  Future<void> _showOtpBasedChangeEmailDialog() async {
    await _showOtpOperationDialog(
      title: 'Change Email',
      icon: Icons.email_rounded,
      operationType: 'change_email',
      additionalFieldLabel: 'New Email',
    );
  }

  /// Show OTP-based change password dialog
  Future<void> _showOtpBasedChangePasswordDialog() async {
    await _showOtpOperationDialog(
      title: 'Change Password',
      icon: Icons.password_rounded,
      operationType: 'change_password',
      additionalFieldLabel: 'New Password',
      isPasswordField: true,
    );
  }
}

/// Uppercase text formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Activation key formatter (adds dashes)
class ActivationKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove existing dashes
    String text = newValue.text.replaceAll('-', '');

    // Add dashes at positions 5 and 13
    if (text.length > 5) {
      text = '${text.substring(0, 5)}-${text.substring(5)}';
    }
    if (text.length > 14) {
      text = '${text.substring(0, 14)}-${text.substring(14)}';
    }

    // Limit to 20 characters (18 + 2 dashes)
    if (text.length > 20) {
      text = text.substring(0, 20);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Hexagon pattern painter
class _HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const hexRadius = 40.0;
    const hexHeight = hexRadius * 1.732;

    for (double x = 0; x < size.width + hexRadius * 2; x += hexRadius * 1.5) {
      for (double y = 0; y < size.height + hexHeight; y += hexHeight) {
        final offsetY = (x ~/ (hexRadius * 1.5)) % 2 == 0 ? 0.0 : hexHeight / 2;
        _drawHexagon(canvas, Offset(x, y + offsetY), hexRadius, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();

    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * 3.14159 / 180;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  double cos(double angle) => _cos(angle);
  double sin(double angle) => _sin(angle);

  double _cos(double x) {
    return 1 - (x * x) / 2 + (x * x * x * x) / 24;
  }

  double _sin(double x) {
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
