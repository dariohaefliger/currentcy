import 'package:flutter/material.dart';

class Single extends StatelessWidget {
  const Single({super.key});

  // This is the main page or Single Conversion Tab.
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: Colors.amberAccent,
      child: Text(
        'Single-Conv. Content',
        style: TextStyle(
          fontSize: 32,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
