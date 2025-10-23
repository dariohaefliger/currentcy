import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/single_conv.dart';
import 'package:flutter_application_1/page/multi_conv.dart';
import 'package:flutter_application_1/page/charts_history.dart';
import 'package:flutter_application_1/settings/settings_main.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3, 
    child: Scaffold(
    appBar: AppBar(
      title: Text('Currentcy'),
      centerTitle: false,
      actions: [
        IconButton(
          onPressed: () {
            // Settings();
          },
          icon: Icon(Icons.settings, size: 40, color: Colors.white))
      ],
      backgroundColor: Colors.blue,
      bottom: TabBar(
        tabs: [
          Tab(text: 'Single-Conv.', icon: Icon(Icons.currency_bitcoin),),
          Tab(text: 'Multi-Conv.', icon: Icon(Icons.currency_exchange),),
          Tab(text: 'Charts / History', icon: Icon(Icons.trending_up)),
        ]
        ),
      ),
      body: TabBarView(
        children: [
          // Single(),
          // Multi(),
          // ChartsHistory(),
          Center(child: Text('Content Single-Conv.')),
          Center(child: Text('Content Multi-Conv.')),
          Center(child: Text('Content Charts / History')),
        ]),
    )
  );
}
