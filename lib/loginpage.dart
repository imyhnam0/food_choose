import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_auth_service.dart';
import 'signuppage.dart';
import 'main.dart';
import 'user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력하세요';
    }
    final RegExp emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$');
    if (!emailRegExp.hasMatch(value)) {
      return '유효한 이메일 주소를 입력하세요';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력하세요';
    }
    if (value.length < 6) {
      return '비밀번호는 최소 6자리 이상이어야 합니다';
    }
    return null;
  }

Future<void> _login() async {

    if (_formKey.currentState?.validate() == true) {
      UserCredential? userCredential = await AuthService().login(
        _emailController.text,
        _passwordController.text,
      );
      if (userCredential != null) {
        String uid = userCredential.user!.uid; // 여기에서 uid를 가져옵니다.
        Provider.of<UserProvider>(context, listen: false).setUid(uid);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', uid);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '로그인',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 5,

      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurpleAccent, Colors.blueAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '환영합니다!',
                      style: TextStyle(
                        fontFamily: 'Pacifico',
                        fontSize: 32.0,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 5.0,
                            color: Colors.black54,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        labelStyle: TextStyle(color: Colors.black),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      validator: _validateEmail,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        labelStyle: TextStyle(color: Colors.black),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 15),
                        backgroundColor: Colors.lightBlueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.blueGrey.shade100,
    );
  }
}
