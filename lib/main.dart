import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

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

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _setTextScale(double scale) {
    setState(() {
      _textScale = scale;
    });
  }

  void _setPrimaryColor(Color color) {
    setState(() {
      _primaryColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          data: mq.copyWith(textScaleFactor: _textScale),
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
  // simple version counter used as a key to rebuild ChatScreen to "clear" it
  int _chatVersion = 0;

  void _clearChat() {
    setState(() {
      _chatVersion++;
    });
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
      appBar: AppBar(
        title: const Text('Chatbot'),
        actions: [
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
      // Rebuild ChatScreen with a new key to clear state/content when _chatVersion changes.
      body: ChatScreen(key: ValueKey(_chatVersion)),
    );
  }
}
