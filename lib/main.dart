// -----------------------------------------------------------------------------
// currentcy – Main Entry Point
//
// This file contains:
// - The application entry point (`main()`)
// - The root widget `MyApp`
// - The tab-based home page `MyHomePage` with navigation to Settings
//
// Responsibilities:
// - Initialize the Flutter app
// - Apply dynamic theme switching via ThemeManager
// - Provide the main tab navigation (Single, Multi, Charts)
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:currentcy/page/single_conv.dart';
import 'package:currentcy/page/multi_conv.dart';
import 'package:currentcy/page/charts_history.dart';
import 'package:currentcy/settings/settings_main.dart';
import 'package:currentcy/settings/theme_manager.dart';

/// Application entry point.
///
/// Initializes the Flutter app and runs the root widget [MyApp].
void main() {
  runApp(const MyApp());
}

/// Root widget of the currentcy application.
///
/// Listens to theme changes via [ThemeManager.themeModeNotifier] and rebuilds
/// the [MaterialApp] accordingly.
///
/// Provides:
/// - App theming (light/dark)
/// - Root navigation
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Currentcy',

          // Apply theme mode from ThemeManager.
          themeMode: mode,

          // Light theme configuration.
          theme: ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.light,
            ),
          ),

          // Dark theme configuration.
          darkTheme: ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
            ),
          ),

          // Main home page with tab navigation.
          home: MyHomePage(
            title: Image.asset(
              'images/Currentcy-Logo_ohne_Hintergrund.png',
              scale: 1,
            ),
          ),
        );
      },
    );
  }
}

/// Home page containing the top-level tab navigation.
///
/// Displays three primary features:
/// - Single currency converter
/// - Multi currency converter
/// - Historical charts
///
/// A settings icon in the app bar navigates to the settings page.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  /// Widget displayed as the app bar title (logo in this case).
  final Widget title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: widget.title,
            centerTitle: false,

            // ---- Settings button ----
            actions: [
              IconButton(
                onPressed: () {
                  // Navigate to Settings with a slide transition from the right.
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const Settings(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        final tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));

                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.settings,
                  size: 40,
                ),
              ),
            ],

            // ---- Tab Buttons ----
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Single-Conv.', icon: Icon(Icons.currency_bitcoin)),
                Tab(text: 'Multi-Conv.', icon: Icon(Icons.currency_exchange)),
                Tab(text: 'Charts', icon: Icon(Icons.trending_up)),
              ],
            ),
          ),

          // ---- Tab Content ----
          body: const TabBarView(
            children: [
              SingleConv(),
              MultiConv(),
              ChartsHistory(),
            ],
          ),
        ),
      );
}
