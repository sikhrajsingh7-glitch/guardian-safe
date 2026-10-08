import 'package:flutter/material.dart';

void main() {
  runApp(const GuardianSafeApp());
}

class GuardianSafeApp extends StatelessWidget {
  const GuardianSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Safe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Modern Material 3 कलर स्कीम
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Safe'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield, 
              size: 100, 
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'Guardian Safe',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Your safety app is ready!'),
          ],
        ),
      ),
    );
  }
}
