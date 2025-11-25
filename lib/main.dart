import 'package:flutter/material.dart';
import 'package:currentcy/page/single_conv.dart';
import 'package:currentcy/page/multi_conv.dart';
import 'package:currentcy/page/charts_history.dart';
import 'package:currentcy/settings/settings_main.dart';
import 'package:currentcy/settings/theme_manager.dart';

void main() {
  runApp(const MyApp());
}

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
          themeMode: mode,
          theme: ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
            ),
          ),

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

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
            actions: [
              IconButton(
                onPressed: () {
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
                        final offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                          position: offsetAnimation,
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
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Single-Conv.', icon: Icon(Icons.currency_bitcoin)),
                Tab(text: 'Multi-Conv.', icon: Icon(Icons.currency_exchange)),
                Tab(text: 'Charts', icon: Icon(Icons.trending_up)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [SingleConv(), MultiConv(), ChartsHistory()],
          ),
        ),
      );
}
