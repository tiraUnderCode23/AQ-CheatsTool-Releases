import 'package:fluent_ui/fluent_ui.dart';

import '../theme/aq_theme.dart';

class ProgressDialog extends StatefulWidget {
  final String title;
  final String? message;
  final double? progress;
  final String? currentItem;
  final VoidCallback? onCancel;
  final Future<void>? future;

  const ProgressDialog({
    super.key,
    required this.title,
    this.message,
    this.progress,
    this.currentItem,
    this.onCancel,
    this.future,
  });

  @override
  State<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<ProgressDialog> {
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    if (widget.future != null) {
      widget.future!
          .then((_) {
            if (mounted) {
              setState(() => _isComplete = true);
              Navigator.of(context).pop();
            }
          })
          .catchError((e) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: ProgressRing(strokeWidth: 3),
          ),
          const SizedBox(width: 12),
          Text(widget.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) Text(widget.message!),
          const SizedBox(height: 16),
          if (widget.progress != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(widget.progress! * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.currentItem != null)
                  Expanded(
                    child: Text(
                      widget.currentItem!,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(value: widget.progress! * 100),
          ] else
            const Center(child: ProgressRing()),
          const SizedBox(height: 8),
          const MStripes(height: 3),
        ],
      ),
      actions: widget.onCancel != null
          ? [
              Button(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel?.call();
                },
              ),
            ]
          : null,
    );
  }
}

class ProgressOverlay extends StatefulWidget {
  final String title;
  final Stream<ProgressUpdate>? progressStream;
  final Widget child;

  const ProgressOverlay({
    super.key,
    required this.title,
    this.progressStream,
    required this.child,
  });

  @override
  State<ProgressOverlay> createState() => _ProgressOverlayState();
}

class _ProgressOverlayState extends State<ProgressOverlay> {
  bool _isVisible = false;
  double _progress = 0.0;
  String _message = '';

  @override
  void initState() {
    super.initState();
    widget.progressStream?.listen((update) {
      setState(() {
        _isVisible = update.isActive;
        _progress = update.progress;
        _message = update.message;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).micaBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: ProgressRing(),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ProgressBar(value: _progress * 100),
                    const SizedBox(height: 8),
                    Text(_message, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    const MStripes(height: 3),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ProgressUpdate {
  final bool isActive;
  final double progress;
  final String message;

  ProgressUpdate({
    required this.isActive,
    required this.progress,
    required this.message,
  });
}
