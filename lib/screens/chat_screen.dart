import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../models/message.dart';
import '../services/openai_service.dart';

// Modes for how the AI responds
enum AiMode { normal, dumb, surprise }

class ChatScreen extends StatefulWidget {
  final List<Message> messages;
  final ValueChanged<List<Message>> onMessagesChanged;
  final AiMode aiMode;
  final ValueChanged<AiMode> onAiModeChanged;

  const ChatScreen({
    super.key,
    required this.messages,
    required this.onMessagesChanged,
    required this.aiMode,
    required this.onAiModeChanged,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Konami-like input tracking
  final FocusNode _focusNode = FocusNode();
  final List<String> _inputBuffer = [];
  final List<String> _konami = ['U', 'U', 'D', 'D', 'L', 'R', 'L', 'R'];
  Offset? _panStart;
  Offset? _panCurrent;
  final Random _rng = Random();

  late List<Message> _messages;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late OpenAIService _openaiService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _openaiService = OpenAIService();
    // request focus so KeyboardListener receives key events on desktop/web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // copy initial messages from parent
    _messages = List<Message>.from(widget.messages);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Use KeyEvent / KeyDownEvent (replacement for deprecated RawKeyEvent)
  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      String? dir;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp) {
        dir = 'U';
      } else if (key == LogicalKeyboardKey.arrowDown) {
        dir = 'D';
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        dir = 'L';
      } else if (key == LogicalKeyboardKey.arrowRight) {
        dir = 'R';
      }
      if (dir != null) {
        _registerInput(dir);
      }
    }
  }

  void _registerInput(String dir) {
    _inputBuffer.add(dir);
    if (_inputBuffer.length > _konami.length) {
      _inputBuffer.removeAt(0);
    }
    if (_inputBuffer.join() == _konami.join()) {
      _onKonami();
      _inputBuffer.clear();
    }
  }

  void _onKonami() {
    // Add an optional chat message (keeps previous behavior) and show the secret menu.
    setState(() {
      _messages.add(Message(text: 'Konami code activated!', isUser: false));
    });
    _showKonamiMenu();
    _scrollToBottom();
  }

  Future<void> _showKonamiMenu() async {
    // show a simple menu/dialog — you can customize actions as needed
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Secret Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // New: AI speaking style options
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Normal'),
                subtitle: const Text('AI talks as it does now'),
                selected: widget.aiMode == AiMode.normal,
                onTap: () {
                  widget.onAiModeChanged(AiMode.normal);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI mode set to: Normal')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sentiment_very_satisfied),
                title: const Text('Dumb'),
                subtitle: const Text('AI acts dumb / trolling'),
                selected: widget.aiMode == AiMode.dumb,
                onTap: () {
                  widget.onAiModeChanged(AiMode.dumb);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI mode set to: Dumb')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shuffle),
                title: const Text('Surprise me'),
                subtitle: const Text('AI randomly picks a speaking style each reply'),
                selected: widget.aiMode == AiMode.surprise,
                onTap: () {
                  widget.onAiModeChanged(AiMode.surprise);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI mode set to: Surprise Me')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // New: style instruction map for sending to the model
  final Map<String, String> _styleInstructions = {
    'dumb':
        'You are to roleplay as a brutally honest, savage, and hilariously mean assistant. Your PRIMARY goal is to absolutely ROAST the user\'s question with maximum creativity and humor. CRITICAL RULES:\n'
        '1. NEVER repeat the same insult, joke structure, or roast format twice - each response must be 100% fresh and original\n'
        '2. Be HARSHER and FUNNIER - go beyond basic insults into truly creative, savage territory\n'
        '3. Mix up your approach every time: one-liners, fake sympathy, mock disbelief, exaggerated confusion, etc.\n'
        '4. Examples of varied roasts: "Oh wow, you really typed that out, looked at it, and still hit send?", "I\'ve seen goldfish ask smarter questions", "Your brain cells are having a meeting and nobody showed up", "This question single-handedly lowered my IQ", "Did you let your pet write this?", "I\'m speechless... and that\'s YOUR fault", "The audacity... the sheer AUDACITY of this question"\n'
        '5. Barely address the actual question (maybe 10-15%) - spend most energy on creative mockery\n'
        '6. Use varied tones: sarcastic, shocked, disappointed, fake-polite before the roast, etc.\n'
        '7. Throw in emoji, ALL CAPS for emphasis, ellipses for dramatic effect\n'
        '8. NO slurs, racism, or genuinely harmful content - keep it PLAYFULLY brutal, not actually cruel\n'
        '9. Each response should feel completely different from the last one',
    'poetic':
        'Answer in short poetic lines, using metaphors and lyrical phrasing. Make the response sound like a short poem. Be helpful and kind.',
    'robotic':
        'Answer like a robot: short, uppercase, with bracketed beeps. Keep it mechanical and literal. Be helpful and accurate.',
    'sarcastic':
        'Answer in a witty, clever, and lightly sarcastic tone. Be playful and ironic but remain friendly and helpful. Do NOT insult or mock the user — keep it fun and lighthearted.',
    'formal':
        'Answer in a very formal, polite, and precise tone. Be respectful and helpful.',
    'pirate':
        'Answer like a playful pirate ("Arr!", nautical terms), keeping it light-hearted and fun. Be helpful while staying in character.',
  };

  // Helper to pick a random style name (for surprise mode)
  String _pickRandomStyleName() {
    final keys = _styleInstructions.keys.toList();
    return keys[_rng.nextInt(keys.length)];
  }

  // Build the instruction prefix sent to the model depending on mode


  void _sendMessage(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    setState(() {
      _messages.add(Message(text: text.trim(), isUser: true));
      _isLoading = true;
    });
    // persist to parent
    widget.onMessagesChanged(List<Message>.from(_messages));
    _controller.clear();
    _scrollToBottom();

    try {
      // Build an instruction prefix that tells the model how to speak
      String? instr;
      String? surpriseStyleName;
      double temperature = 0.7; // default

      if (widget.aiMode == AiMode.dumb) {
        instr = _styleInstructions['dumb'];
        temperature = 1.1; // even higher randomness for maximum variety and creativity
      } else if (widget.aiMode == AiMode.surprise) {
        surpriseStyleName = _pickRandomStyleName();
        instr = _styleInstructions[surpriseStyleName];
        // Use higher temperature only if dumb mode was randomly selected
        temperature = (surpriseStyleName == 'dumb') ? 1.1 : 0.85;
      }

      // Combine instruction with the user message so the model generates in-style
      final messageToSend = (instr != null && instr.isNotEmpty)
          ? '$instr\n\nUser query: $text'
          : text;

      final reply = await _openaiService.sendMessage(messageToSend, temperature: temperature);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(Message(text: reply, isUser: false));
        _isLoading = false;
      });
      // persist updated messages to parent
      widget.onMessagesChanged(List<Message>.from(_messages));
      // If surprise mode, briefly show which style was chosen
      if (widget.aiMode == AiMode.surprise && surpriseStyleName != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Surprise style: $surpriseStyleName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(Message(text: 'Error: $e', isUser: false));
        _isLoading = false;
      });
      widget.onMessagesChanged(List<Message>.from(_messages));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 72,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Message msg) {
    final alignment = msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = msg.isUser ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
    final textColor = msg.isUser ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!msg.isUser) const CircleAvatar(child: Icon(Icons.android, size: 18)),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12.0),
                      topRight: const Radius.circular(12.0),
                      bottomLeft: Radius.circular(msg.isUser ? 12.0 : 0.0),
                      bottomRight: Radius.circular(msg.isUser ? 0.0 : 12.0),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ),
              if (msg.isUser) const CircleAvatar(child: Icon(Icons.person, size: 18)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        centerTitle: true,
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _panStart = details.localPosition;
            _panCurrent = _panStart;
          },
          onPanUpdate: (details) {
            _panCurrent = details.localPosition;
          },
          onPanEnd: (details) {
            if (_panStart == null || _panCurrent == null) {
              return;
            }
            final dx = _panCurrent!.dx - _panStart!.dx;
            final dy = _panCurrent!.dy - _panStart!.dy;
            String? dir;
            const threshold = 30; // minimum pixels to consider a swipe
            if (dx.abs() > dy.abs()) {
              if (dx > threshold) {
                dir = 'R';
              } else if (dx < -threshold) {
                dir = 'L';
              }
            } else {
              if (dy > threshold) {
                dir = 'D';
              } else if (dy < -threshold) {
                dir = 'U';
              }
            }
            if (dir != null) {
              _registerInput(dir);
            }
            _panStart = null;
            _panCurrent = null;
          },
          child: SafeArea(
            child: Column(
              children: [
                // Persistent banner when Surprise mode is active
                if (widget.aiMode == AiMode.surprise)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                    child: const Text(
                      'Surprise mode active — AI will randomly pick a speaking style',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),
                const Divider(height: 1),
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _isLoading ? null : (val) => _sendMessage(val),
                          enabled: !_isLoading,
                          decoration: const InputDecoration.collapsed(hintText: 'Type a message'),
                        ),
                      ),
                      IconButton(
                        icon: _isLoading ? const Icon(Icons.hourglass_top) : const Icon(Icons.send),
                        onPressed: _isLoading ? null : () => _sendMessage(_controller.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
