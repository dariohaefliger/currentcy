import 'package:flutter/material.dart';

class ChartsHistory extends StatelessWidget {
  const ChartsHistory({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      color: Colors.lightGreen,
      child: Text(
        'Charts and History Content',
        style: TextStyle(
          fontSize: 32,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        )
      )
  );
}