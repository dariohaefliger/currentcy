import 'package:flutter/material.dart';

class MultiConv extends StatelessWidget {
  const MultiConv({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: Colors.deepPurple,
      child: Text(
        'Multi-Conv. Content',
        style: TextStyle(
          fontSize: 32,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        )
      )
  );
}