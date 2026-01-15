import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Terminal Widget - Console-like output display
class TerminalWidget extends StatefulWidget {
  final List<String> logs;
  final double? height;
  final bool autoScroll;
  final VoidCallback? onClear;
  final Function(String)? onCommand;
  final bool showInput;

  const TerminalWidget({
    super.key,
    required this.logs,
    this.height,
    this.autoScroll = true,
    this.onClear,
    this.onCommand,
    this.showInput = false,
  });

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(TerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.autoScroll && widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleCommand() {
    if (_inputController.text.isNotEmpty) {
      widget.onCommand?.call(_inputController.text);
      _inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AQColors.accent.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                // Window buttons
                Row(
                  children: [
                    _buildWindowButton(const Color(0xFFFF5F56)),
                    const SizedBox(width: 6),
                    _buildWindowButton(const Color(0xFFFFBD2E)),
                    const SizedBox(width: 6),
                    _buildWindowButton(const Color(0xFF27C93F)),
                  ],
                ),

                const Spacer(),

                Text(
                  'Terminal',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),

                const Spacer(),

                // Actions
                if (widget.onClear != null)
                  IconButton(
                    icon: Icon(
                      Icons.cleaning_services_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: 16,
                    ),
                    onPressed: widget.onClear,
                    tooltip: 'Clear',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),

                IconButton(
                  icon: Icon(
                    Icons.copy_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 16,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.logs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied to clipboard'),
                        backgroundColor: AQColors.accent.withOpacity(0.9),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copy all',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                return _buildLogLine(widget.logs[index]);
              },
            ),
          ),

          // Input
          if (widget.showInput)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  const Text(
                    '\$ ',
                    style: TextStyle(
                      color: AQColors.accent,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _handleCommand(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AQColors.accent,
                      size: 18,
                    ),
                    onPressed: _handleCommand,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWindowButton(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLogLine(String log) {
    // Parse log format: [timestamp] emoji message
    Color textColor = Colors.white.withOpacity(0.8);

    if (log.contains('✅') || log.contains('success')) {
      textColor = const Color(0xFF27C93F);
    } else if (log.contains('❌') || log.contains('error')) {
      textColor = const Color(0xFFFF5F56);
    } else if (log.contains('⚠️') || log.contains('warning')) {
      textColor = const Color(0xFFFFBD2E);
    } else if (log.contains('🔵') || log.contains('blue')) {
      textColor = AQColors.primary;
    } else if (log.contains('ℹ️') || log.contains('info')) {
      textColor = Colors.white.withOpacity(0.6);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText(
        log,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Simple log display widget
class LogDisplay extends StatelessWidget {
  final String log;
  final Color? color;

  const LogDisplay({
    super.key,
    required this.log,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? AQColors.accent).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? AQColors.accent).withOpacity(0.2),
        ),
      ),
      child: Text(
        log,
        style: TextStyle(
          color: color ?? Colors.white,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}
