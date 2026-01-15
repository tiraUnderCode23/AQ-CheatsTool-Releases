import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/gemini_chat_service.dart';

/// Floating AI Chat Widget
/// Appears in bottom-right corner, can be expanded/collapsed
class AIChatWidget extends StatefulWidget {
  final Function(int tabIndex)? onNavigate;
  final Function(int tabIndex, String query)? onSearch;
  final int currentTabIndex;

  const AIChatWidget({
    super.key,
    this.onNavigate,
    this.onSearch,
    this.currentTabIndex = 0,
  });

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _sendMessage(GeminiChatService chatService) async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    _textController.clear();
    setState(() {
      _showSuggestions = false;
    });

    final response = await chatService.sendMessage(message);

    // Scroll to bottom after response
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Execute actions if any
    if (response.success && response.actions.isNotEmpty) {
      for (final action in response.actions) {
        await _executeAction(action);
      }
    }
  }

  Future<void> _executeAction(GeminiChatAction action) async {
    switch (action.type) {
      case GeminiChatActionType.navigate:
        if (action.tabIndex != null && widget.onNavigate != null) {
          widget.onNavigate!(action.tabIndex!);
        }
        break;
      case GeminiChatActionType.search:
        if (action.tabIndex != null &&
            action.query != null &&
            widget.onSearch != null) {
          widget.onSearch!(action.tabIndex!, action.query!);
        }
        break;
      case GeminiChatActionType.copy:
        if (action.text != null) {
          await Clipboard.setData(ClipboardData(text: action.text!));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied!'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
        break;
      case GeminiChatActionType.openUrl:
        if (action.url != null) {
          final uri = Uri.parse(action.url!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
        break;
    }
  }

  void _useSuggestion(String suggestion, GeminiChatService chatService) {
    _textController.text = suggestion;
    _sendMessage(chatService);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GeminiChatService(),
      child: Consumer<GeminiChatService>(
        builder: (context, chatService, child) {
          return Stack(
            children: [
              // Expanded chat window
              if (_isExpanded)
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    alignment: Alignment.bottomRight,
                    child: _buildChatWindow(chatService),
                  ),
                ),

              // Floating action button
              Positioned(
                right: 16,
                bottom: 16,
                child: _buildFloatingButton(chatService),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFloatingButton(GeminiChatService chatService) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                _isExpanded ? Icons.close : Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
              // Processing indicator
              if (chatService.isProcessing)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(Colors.white.withOpacity(0.5)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatWindow(GeminiChatService chatService) {
    return Container(
      width: 380,
      height: 500,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(chatService),

          // Messages area
          Expanded(
            child: _buildMessagesArea(chatService),
          ),

          // Input area
          _buildInputArea(chatService),
        ],
      ),
    );
  }

  Widget _buildHeader(GeminiChatService chatService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'AQ AI Assistant',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          if (chatService.conversationHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white70, size: 20),
              onPressed: () {
                chatService.clearHistory();
                setState(() {
                  _showSuggestions = true;
                });
              },
              tooltip: 'Clear chat',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(GeminiChatService chatService) {
    if (chatService.conversationHistory.isEmpty && _showSuggestions) {
      return _buildSuggestions(chatService);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: chatService.conversationHistory.length +
          (chatService.isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chatService.conversationHistory.length) {
          // Show typing indicator
          return _buildTypingIndicator();
        }

        final message = chatService.conversationHistory[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildSuggestions(GeminiChatService chatService) {
    final suggestions = chatService.getSuggestions(widget.currentTabIndex);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text(
                'Quick Suggestions',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return InkWell(
                onTap: () => _useSuggestion(suggestion, chatService),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D3D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    suggestion,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          Center(
            child: Text(
              'Powered by Gemini AI',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == MessageRole.user;
    final cleanText =
        message.content.replaceAll(RegExp(r'\[ACTION:[^\]]+\]'), '').trim();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 40 : 0,
          right: isUser ? 0 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6366F1) : const Color(0xFF2D2D3D),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 12),
          ),
        ),
        child: Text(
          cleanText,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
            fontSize: 13,
          ),
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D3D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white24,
              const Color(0xFF6366F1),
              (1 + (value * 2 - 1).abs()) / 2,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(GeminiChatService chatService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF252535),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                hintTextDirection: TextDirection.ltr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(chatService),
              enabled: !chatService.isProcessing,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: chatService.isProcessing
                ? Colors.grey
                : const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: chatService.isProcessing
                  ? null
                  : () => _sendMessage(chatService),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  chatService.isProcessing ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
