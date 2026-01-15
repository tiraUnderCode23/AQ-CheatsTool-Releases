import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/auto_update_service.dart';

/// App color constants
class _AppColors {
  static const Color accent = Color(0xFF00ffd0);
  static const Color primary = Color(0xFF3b82f6);
  // ignore: unused_field
  static const Color background = Color(0xFF1E1E2E);
}

/// Update Dialog Widget - Shows update available, download progress, and install button
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoUpdateService>(
      builder: (context, updateService, child) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _AppColors.accent.withOpacity(0.3)),
          ),
          title: _buildTitle(updateService),
          content: _buildContent(context, updateService),
          actions: _buildActions(context, updateService),
        );
      },
    );
  }

  Widget _buildTitle(AutoUpdateService updateService) {
    IconData icon;
    String title;
    Color color;

    if (updateService.downloadComplete) {
      icon = Icons.check_circle_rounded;
      title = 'Download Complete';
      color = Colors.green;
    } else if (updateService.isDownloading) {
      icon = Icons.download_rounded;
      title = 'Downloading Update...';
      color = _AppColors.accent;
    } else {
      icon = Icons.system_update_rounded;
      title = 'Update Available';
      color = _AppColors.accent;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AutoUpdateService updateService) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Version: ${AutoUpdateService.currentVersion}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'New Version: ${updateService.latestVersion ?? "Unknown"}',
                      style: const TextStyle(
                        color: _AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Release notes
        if (updateService.releaseNotes != null &&
            updateService.releaseNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'What\'s New:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                updateService.releaseNotes!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],

        // Download progress
        if (updateService.isDownloading || updateService.downloadComplete) ...[
          const SizedBox(height: 20),
          _buildDownloadProgress(updateService),
        ],

        // Error message
        if (updateService.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    updateService.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadProgress(AutoUpdateService updateService) {
    final progress = updateService.downloadProgress;
    final percentage = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              updateService.downloadComplete ? 'Completed' : 'Downloading...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: _AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              updateService.downloadComplete ? Colors.green : _AppColors.accent,
            ),
            minHeight: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    AutoUpdateService updateService,
  ) {
    final actions = <Widget>[];

    if (updateService.downloadComplete) {
      // Download complete - show install button
      actions.add(
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Later',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ),
      );
      actions.add(
        ElevatedButton.icon(
          onPressed: () async {
            await updateService.installUpdate();
          },
          icon: const Icon(Icons.install_desktop_rounded, size: 18),
          label: const Text('Install Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
    } else if (updateService.isDownloading) {
      // Downloading - show cancel
      actions.add(
        TextButton(
          onPressed: () {
            updateService.reset();
            Navigator.pop(context);
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ),
      );
    } else {
      // Update available - show skip, remind later, download
      actions.add(
        TextButton(
          onPressed: () async {
            await updateService.skipVersion();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(
            'Skip Version',
            style: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Later',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ),
      );
      actions.add(
        ElevatedButton.icon(
          onPressed: () async {
            await updateService.downloadUpdate();
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppColors.accent,
            foregroundColor: Colors.black,
          ),
        ),
      );
    }

    return actions;
  }
}

/// Update Banner Widget - Shows at top of screen when update available
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoUpdateService>(
      builder: (context, updateService, child) {
        if (!updateService.updateAvailable) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _AppColors.accent.withOpacity(0.9),
                _AppColors.primary.withOpacity(0.9),
              ],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Version ${updateService.latestVersion} is ready to download',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => UpdateDialog.show(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
