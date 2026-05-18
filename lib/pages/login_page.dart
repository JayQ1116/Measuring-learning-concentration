// lib/pages/login_page.dart
// 完整版：Firebase Auth 注册 + 登录

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_page.dart';
import 'teacher_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 'login' 또는 'register'
  String _mode = 'login';
  String _role = 'Student';
  bool _loading = false;

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // 로그인
  // ─────────────────────────────────────────
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      _showSnack('이메일과 비밀번호를 입력하세요');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pw);

      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      final role = doc.data()?['role'] ?? 'Student';
      final name = doc.data()?['name'] ?? email;

      if (role == 'Teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TeacherDashboardPage(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDashboard(studentId: uid, studentName: name),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_authError(e.code));
    } catch (e) {
      _showSnack('로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  // 회원가입
  // ─────────────────────────────────────────
  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || pw.isEmpty || name.isEmpty) {
      _showSnack('모든 항목을 입력하세요');
      return;
    }
    if (pw.length < 6) {
      _showSnack('비밀번호는 6자 이상이어야 합니다');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pw);

      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': _role,
        'classId': 'class_001',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnack('회원가입 성공! 로그인하세요');
      setState(() => _mode = 'login');
    } on FirebaseAuthException catch (e) {
      _showSnack(_authError(e.code));
    } catch (e) {
      _showSnack('회원가입 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return '존재하지 않는 계정입니다';
      case 'wrong-password':
        return '비밀번호가 틀렸습니다';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다';
      case 'weak-password':
        return '비밀번호가 너무 짧습니다';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 틀렸습니다';
      default:
        return '오류: $code';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == 'login';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A469D), Color(0xFF3B71CA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF102C57),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _role == 'Student' ? Icons.school : Icons.computer,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 제목
                    Text(
                      isLogin
                          ? (_role == 'Student' ? '학생 로그인' : '교사 로그인')
                          : (_role == 'Student' ? '학생 회원가입' : '교사 회원가입'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF102C57),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 역할 선택
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Student',
                            label: Text('학생'),
                            icon: Icon(Icons.person),
                          ),
                          ButtonSegment(
                            value: 'Teacher',
                            label: Text('교사'),
                            icon: Icon(Icons.school),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (s) =>
                            setState(() => _role = s.first),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 이름 (회원가입만)
                    if (!isLogin) ...[
                      _field(_nameCtrl, '이름', Icons.badge_outlined),
                      const SizedBox(height: 14),
                    ],

                    // 이메일
                    _field(_emailCtrl, '이메일',
                        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),

                    // 비밀번호
                    _field(_pwCtrl, '비밀번호',
                        Icons.lock_outline,
                        obscure: true),
                    const SizedBox(height: 24),

                    // 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : (isLogin ? _login : _register),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF102C57),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isLogin ? '로그인' : '회원가입',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 전환 링크
                    TextButton(
                      onPressed: () => setState(() {
                        _mode = isLogin ? 'register' : 'login';
                      }),
                      child: Text(
                        isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                        style: const TextStyle(
                            color: Color(0xFF3B71CA), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF4F7FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}