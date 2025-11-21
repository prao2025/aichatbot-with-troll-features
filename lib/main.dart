import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  // text scale factor: 0.9 = small, 1.0 = medium (default), 1.2 = large
  double _textScale = 1.0;
  // app primary color (user-selectable)
  Color _primaryColor = Colors.blue;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load theme mode (0=light, 1=dark, 2=system)
      final themeModeIndex = prefs.getInt('themeMode') ?? 0;
      _themeMode = ThemeMode.values[themeModeIndex];
      
      // Load text scale
      _textScale = prefs.getDouble('textScale') ?? 1.0;
      
      // Load primary color (saved as ARGB int)
      final colorValue = prefs.getInt('primaryColor') ?? Colors.blue.toARGB32();
      _primaryColor = Color(colorValue);
      
      _isLoading = false;
    });
  }

  void _setDarkMode(bool enabled) async {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
  }

  void _setTextScale(double scale) async {
    setState(() {
      _textScale = scale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textScale', scale);
  }

  void _setPrimaryColor(Color color) async {
    setState(() {
      _primaryColor = color;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while preferences are being loaded
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    // derive themes from selected primary color
    final lightTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor, brightness: Brightness.light),
    );
    final darkTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor, brightness: Brightness.dark),
    );

    return MaterialApp(
      title: 'Chatbot',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      // Ensure the selected text scale applies everywhere by overriding MediaQuery's textScaleFactor.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(_textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleDark: _setDarkMode,
        textScale: _textScale,
        onChangeTextScale: _setTextScale,
        primaryColor: _primaryColor,
        onChangePrimaryColor: _setPrimaryColor,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onToggleDark;
  final double textScale;
  final ValueChanged<double> onChangeTextScale;
  final Color primaryColor;
  final ValueChanged<Color> onChangePrimaryColor;

  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleDark,
    required this.textScale,
    required this.onChangeTextScale,
    required this.primaryColor,
    required this.onChangePrimaryColor,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // simple version counter used as a key to rebuild ChatScreen to "clear" it
  int _chatVersion = 0;

  // Chat list: each chat is a map {id, title, messages}
  final List<Map<String, dynamic>> _chats = [
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': 'Chat 1',
      'messages': <Message>[
        Message(text: 'Welcome! This is your new chat interface.', isUser: false),
        Message(text: 'Hi — try typing a message below.', isUser: false),
      ],
    }
  ];
  int _selectedIndex = 0;

  // AI speaking mode (shared across all chats)
  AiMode _aiMode = AiMode.normal;

  @override
  void initState() {
    super.initState();
    _loadAiMode();
  }

  Future<void> _loadAiMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('aiMode') ?? 0;
    setState(() {
      _aiMode = AiMode.values[modeIndex];
    });
  }

  void _clearChat() {
    setState(() {
      _chats[_selectedIndex]['messages'] = <Message>[
        Message(text: 'Welcome! This is your new chat interface.', isUser: false),
        Message(text: 'Hi — try typing a message below.', isUser: false),
      ];
      _chatVersion++;
    });
  }

  void _newChat() {
    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _chats.add({
        'id': id,
        'title': 'Chat ${_chats.length + 1}',
        'messages': <Message>[
          Message(text: 'New chat started.', isUser: false),
        ],
      });
      _selectedIndex = _chats.length - 1;
    });
  }

  void _deleteChat(int index) {
    if (_chats.length == 1) {
      // keep at least one chat: clear it instead
      _clearChat();
      return;
    }
    setState(() {
      _chats.removeAt(index);
      if (_selectedIndex >= _chats.length) _selectedIndex = _chats.length - 1;
    });
  }

  void _setAiMode(AiMode mode) async {
    setState(() {
      _aiMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aiMode', mode.index);
  }

  // show color picker dialog with a few color circles
  Future<void> _showColorPicker(BuildContext context) async {
    final colors = <Color>[
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose primary color'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((c) {
              return GestureDetector(
                onTap: () {
                  widget.onChangePrimaryColor(c);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Primary color updated')),
                  );
                },
                child: CircleAvatar(
                  backgroundColor: c,
                  radius: 22,
                  child: widget.primaryColor == c
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Chatbot'),
        actions: [
          // Open history (side panel) popup
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Open chat history',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          // Clear chat button (not inside the three-line menu)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
          // Three-line icon on the top-right that opens a dropdown
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu),
            itemBuilder: (context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                // Column: Dark mode row + font size buttons row
                enabled: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Dark mode'),
                        const SizedBox(width: 8),
                        Switch(
                          value: widget.isDark,
                          onChanged: (v) {
                            // Update parent theme and close the menu
                            widget.onToggleDark(v);
                            Navigator.of(context).pop();
                          },
                        ),
                        // Palette button beside Dark mode
                        IconButton(
                          icon: const Icon(Icons.palette),
                          tooltip: 'Choose primary color',
                          onPressed: () {
                            // open color picker dialog
                            Navigator.of(context).pop();
                            _showColorPicker(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Font size buttons: Small / Medium / Large
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            widget.onChangeTextScale(0.9); // small
                            Navigator.of(context).pop();
                          },
                          child: const Text('Small'),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onChangeTextScale(1.0); // medium
                            Navigator.of(context).pop();
                          },
                          child: const Text('Medium'),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onChangeTextScale(1.2); // large
                            Navigator.of(context).pop();
                          },
                          child: const Text('Large'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Chat area is full width; history lives in the endDrawer popup.
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(child: Text('Chats', style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                      tooltip: 'New chat',
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _newChat();
                        // keep drawer open so user can see new chat
                      },
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (ctx, idx) {
                    final chat = _chats[idx];
                    final isSelected = idx == _selectedIndex;
                    return ListTile(
                      selected: isSelected,
                      title: Text(chat['title'] as String),
                      subtitle: (chat['messages'] as List<Message>).isNotEmpty
                          ? Text((chat['messages'] as List<Message>).last.text,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () {
                        setState(() => _selectedIndex = idx);
                        Navigator.of(context).pop(); // close drawer so chat area is visible
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () {
                          _deleteChat(idx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Chat area uses the ChatScreen and passes messages + persistence callback
      body: ChatScreen(
        key: ValueKey('${_chats[_selectedIndex]['id']}_$_chatVersion'),
        messages: List<Message>.from(_chats[_selectedIndex]['messages'] as List<Message>),
        onMessagesChanged: (updated) {
          setState(() {
            _chats[_selectedIndex]['messages'] = List<Message>.from(updated);
          });
        },
        aiMode: _aiMode,
        onAiModeChanged: _setAiMode,
      ),
    );
  }
}
