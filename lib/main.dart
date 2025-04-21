import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:text/features/auth/auth_page.dart';
import 'package:text/features/home/home_page.dart'; // Assuming you have this

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fbncabaoddfceuwcgehi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZibmNhYmFvZGRmY2V1d2NnZWhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ3MjUwNDAsImV4cCI6MjA2MDMwMTA0MH0.XBHTWBin0apaWxlfuKjNX7bbU86vFTwNQBTzjsOCm_I',
    // You can omit authFlowType if you're not doing OAuth right now
    // authFlowType: AuthFlowType.pkce,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return MaterialApp(
      title: 'Supabase Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      home: user != null ? const HomePage() : const AuthPage(),
    );
  }
}
