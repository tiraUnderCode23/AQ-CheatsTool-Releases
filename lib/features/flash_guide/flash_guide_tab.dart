import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class FlashGuideTab extends StatefulWidget {
  const FlashGuideTab({super.key});

  @override
  State<FlashGuideTab> createState() => _FlashGuideTabState();
}

class _FlashGuideTabState extends State<FlashGuideTab> {
  int _currentStep = 0;

  final List<_GuideStep> _steps = [
    _GuideStep(
      title: 'Preparation',
      description:
          'Connect your laptop to the car via ENET cable and ensure battery is charged.',
      icon: Icons.power_rounded,
      imagePath: 'assets/images/flash1.jpg',
    ),
    _GuideStep(
      title: 'Launch E-Sys',
      description:
          'Open E-Sys and connect to the vehicle. Select the target ECU.',
      icon: Icons.computer_rounded,
      imagePath: 'assets/images/flash2.jpg',
    ),
    _GuideStep(
      title: 'Read Coding Data',
      description:
          'Read the current coding data and save a backup before making changes.',
      icon: Icons.download_rounded,
      imagePath: 'assets/images/flash3.jpg',
    ),
    _GuideStep(
      title: 'Flash Process',
      description:
          'Select the flash file and start the flashing process. Do not interrupt!',
      icon: Icons.flash_on_rounded,
      imagePath: 'assets/images/flash4.jpg',
    ),
    _GuideStep(
      title: 'Verification',
      description:
          'Verify the flash was successful and test the updated functionality.',
      icon: Icons.check_circle_rounded,
      imagePath: 'assets/images/flash5.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: AQColors.accent,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Flash Guide',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Step-by-step guide for BMW ECU flashing',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 24),

          // Progress indicators
          _buildProgressBar(),

          const SizedBox(height: 24),

          // Content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Steps list
                SizedBox(
                  width: 280,
                  child: _buildStepsList(),
                ),

                const SizedBox(width: 24),

                // Current step content
                Expanded(
                  child: _buildCurrentStep(),
                ),
              ],
            ),
          ),

          // Navigation
          const SizedBox(height: 24),
          _buildNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < _currentStep;

          return Expanded(
            child: Container(
              height: 2,
              color:
                  isCompleted ? AQColors.accent : Colors.white.withOpacity(0.1),
            ),
          );
        } else {
          // Step dot
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == _currentStep;
          final isCompleted = stepIndex < _currentStep;

          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted
                  ? AQColors.accent.withOpacity(isActive ? 1 : 0.8)
                  : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: isActive ? AQColors.accent : Colors.transparent,
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AQColors.accent.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.black, size: 18)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        color: isActive
                            ? Colors.black
                            : Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
            ),
          );
        }
      }),
    );
  }

  Widget _buildStepsList() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step = _steps[index];
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return InkWell(
            onTap: () => setState(() => _currentStep = index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? AQColors.accent.withOpacity(0.1) : null,
                border: Border(
                  left: BorderSide(
                    color: isActive ? AQColors.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AQColors.accent.withOpacity(0.2)
                          : isCompleted
                              ? const Color(0xFF27C93F).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : step.icon,
                      color: isActive
                          ? AQColors.accent
                          : isCompleted
                              ? const Color(0xFF27C93F)
                              : Colors.white.withOpacity(0.5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            color: isActive ? AQColors.accent : Colors.white,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStep() {
    final step = _steps[_currentStep];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AQColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  step.icon,
                  color: AQColors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${_currentStep + 1}: ${step.title}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            step.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
              height: 1.6,
            ),
          ),

          const SizedBox(height: 24),

          // Image placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_rounded,
                      color: Colors.white.withOpacity(0.2),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Step ${_currentStep + 1} Image',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tips
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AQColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AQColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AQColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getTipForStep(_currentStep),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous button
        OutlinedButton.icon(
          onPressed:
              _currentStep > 0 ? () => setState(() => _currentStep--) : null,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Previous'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),

        // Step counter
        Text(
          '${_currentStep + 1} / ${_steps.length}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),

        // Next button
        ElevatedButton.icon(
          onPressed: _currentStep < _steps.length - 1
              ? () => setState(() => _currentStep++)
              : null,
          icon: const Text('Next'),
          label: const Icon(Icons.arrow_forward_rounded),
          style: ElevatedButton.styleFrom(
            backgroundColor: AQColors.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  String _getTipForStep(int step) {
    switch (step) {
      case 0:
        return 'Tip: Always ensure the car battery is at least 80% charged before starting any flash operation.';
      case 1:
        return 'Tip: Make sure you have the correct PSdZData version for your vehicle.';
      case 2:
        return 'Tip: Always backup your current coding before making any changes!';
      case 3:
        return 'Tip: Never turn off the ignition or disconnect cables during flashing!';
      case 4:
        return 'Tip: If verification fails, try the flash again. If it persists, restore from backup.';
      default:
        return 'Follow each step carefully to ensure successful flashing.';
    }
  }
}

class _GuideStep {
  final String title;
  final String description;
  final IconData icon;
  final String imagePath;

  _GuideStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.imagePath,
  });
}
