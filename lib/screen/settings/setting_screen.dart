import 'package:flutter/material.dart';


class SettingScreen extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode?)? onThemeChanged;

  const SettingScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text("Settings",
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
        ),
       ),
      ),
     body: Padding(
  padding: const EdgeInsets.all(20.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Appearance",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
      ),
      const SizedBox(height: 16),

      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Theme.of(context).brightness == Brightness.light
                      ? Color(0xFFF5F7FA)
                      : Colors.grey[900],
        child: ListTileTheme(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeMode,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: onThemeChanged,
                title: Row(
                  children: [
                    Icon(Icons.light_mode,
                        color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 12),
                    const Text("Light Mode"),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.6, color: Colors.grey.withOpacity(0.3)),

              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeMode,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: onThemeChanged,
                title: Row(
                  children: [
                    Icon(Icons.dark_mode,
                        color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 12),
                    const Text("Dark Mode"),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.6, color: Colors.grey.withOpacity(0.3)),

              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeMode,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: onThemeChanged,
                title: Row(
                  children: [
                    Icon(Icons.settings_suggest,
                        color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 12),
                    const Text("Follow OS setting"),
                  ],
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
}