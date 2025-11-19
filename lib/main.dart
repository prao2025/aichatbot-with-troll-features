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

  @override
  Widget build(BuildContext context) {
    // Use default ThemeData and drive scaling only via MediaQuery.textScaleFactor
    final lightTheme = ThemeData.light();
    final darkTheme = ThemeData.dark();

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
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onToggleDark;
  final double textScale;
  final ValueChanged<double> onChangeTextScale;

  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleDark,
    required this.textScale,
    required this.onChangeTextScale,
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
