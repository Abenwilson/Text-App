import 'package:flutter/material.dart';
import 'package:text/features/auth/login_page.dart';
import 'package:text/features/auth/register_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool showLoginpage = true;

  void togglepage() {
    setState(() {
      showLoginpage = !showLoginpage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginpage) {
      return LoginPage(togglepage: togglepage);
    } else {
      return RegisterPage(togglepage: togglepage);
    }
  }
}
