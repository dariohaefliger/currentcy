import 'package:flutter/material.dart';

class ExchangeRatesInfoPage extends StatelessWidget {
  const ExchangeRatesInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ExchangeRates API'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'How to set up ExchangeRates API',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          Text(
            '1. Create an account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• Go to exchangeratesapi.io\n'
            '• Create a free account or log in with your existing account.\n'
            '• After logging in, open your dashboard.',
          ),

          SizedBox(height: 16),

          Text(
            '2. Find your API key',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• In the dashboard, look for your API Access Key.\n'
            '• Copy the API key string (a long combination of letters and numbers).',
          ),

          SizedBox(height: 16),

          Text(
            '3. Enter the API key in this app',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• Go back to the Settings screen of this app.\n'
            '• Scroll to the "ExchangeRates API" section.\n'
            '• Paste your API key into the "API key" field.\n'
            '• Tap the "Save API key" button.',
          ),

          SizedBox(height: 16),

          Text(
            '4. Disable mock mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• In the "ExchangeRates API" section, turn OFF "Use mock rates".\n'
            '• Now the app will use live exchange rates from exchangeratesapi.io instead of built-in test values.',
          ),

          SizedBox(height: 16),

          Text(
            '5. Synchronize rates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• Open one of the conversion tabs (Single or Multi).\n'
            '• Tap the "synchronize now" button at the bottom.\n'
            '• If everything is set up correctly, the latest rates will be fetched and used for all conversions.',
          ),

          SizedBox(height: 24),

          Text(
            'Troubleshooting',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• If you see error messages when synchronizing, check:\n'
            '  – Is the API key correct (no spaces, fully copied)?\n'
            '  – Is your plan still active and not over the monthly limit?\n\n'
            '• You can always re-enable "Use mock rates" if the API is not available.',
          ),
        ],
      ),
    );
  }
}
