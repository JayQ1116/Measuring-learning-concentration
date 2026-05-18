import 'package:flutter/material.dart';

class TeacherMainPage extends StatelessWidget {
  const TeacherMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
      ),
      body: const Center(
        child: Text('교사용 메인 페이지'),
      ),
    );
  }
}
