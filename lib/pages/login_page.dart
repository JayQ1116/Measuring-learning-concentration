import 'package:flutter/material.dart';
import 'teacher_dashboard_page.dart';
import 'dashboard_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _role = 'Student';
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A469D), Color(0xFF3B71CA)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 450,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF102C57),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _role == 'Student' ? Icons.school : Icons.computer,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    _role == 'Student' ? "학생 로그인" : "교사 로그인",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF102C57),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _role == 'Student' ? "학습 플랫폼에 오신 것을 환영합니다" : "학급 모니터링 시스템",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // 身份切换
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Student', label: Text('학생'), icon: Icon(Icons.person)),
                        ButtonSegment(value: 'Teacher', label: Text('교사'), icon: Icon(Icons.school)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (set) => setState(() => _role = set.first),
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildInputLabel(_role == 'Student' ? "학번" : "교사 ID"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(hintText: "ID를 입력하세요"),
                  ),
                  const SizedBox(height: 20),
                  _buildInputLabel("비밀번호"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: "비밀번호를 입력하세요"),
                  ),
                  const SizedBox(height: 40),

                  // 登录按钮
                  ElevatedButton(
                    onPressed: () {
                      if (_role == 'Student') {
                        final id = _idController.text.trim();
                        if (id.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentDashboard(studentId: id),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('학번을 입력하세요')),
                          );
                        }
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TeacherDashboardPage()),
                        );
                      }
                    },
                    child: const Text("로그인"),
                  ),
                  const SizedBox(height: 20),                    // ← 这行之前缺失
                  const Text(                                     // ← 这行之前缺失
                    "비밀번호를 잊으셨나요?",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF172B4D)),
      ),
    );
  }
} 