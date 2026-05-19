// lib/pages/teacher_dashboard_page.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_monitoring_page.dart';
import 'login_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  String _teacherName = '선생님';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final teacher = await _supabase
          .from('teachers')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      if (teacher != null) {
        setState(() => _teacherName = teacher['name'] ?? '선생님');
      }

      final courses = await _supabase
          .from('courses')
          .select('id, name, pdf_url, created_at')
          .order('created_at', ascending: false);

      setState(() => _courses = List<Map<String, dynamic>>.from(courses));
    } catch (e) {
      debugPrint('[Teacher] 데이터 로드 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadPdf(String courseId, String courseName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      setState(() => _uploading = true);

      final bytes = result.files.single.bytes!;
      final fileName = '${courseId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await _supabase.storage.from('pdfs').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'application/pdf',
          upsert: true,
        ),
      );

      final url = _supabase.storage.from('pdfs').getPublicUrl(fileName);

      await _supabase
          .from('courses')
          .update({'pdf_url': url})
          .eq('id', courseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('$courseName PDF 업로드 완료!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('[PDF Upload] 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF 업로드 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addCourse() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B71CA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline,
                        color: Color(0xFF3B71CA)),
                  ),
                  const SizedBox(width: 12),
                  const Text('새 강의 추가',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B4D))),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '강의 이름을 입력하세요',
                  filled: true,
                  fillColor: const Color(0xFFF4F7FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.menu_book_outlined,
                      color: Color(0xFF3B71CA)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('취소',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, nameCtrl.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B71CA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('추가',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await _supabase.from('courses').insert({'name': result});
      _loadData();
    } catch (e) {
      debugPrint('[Course] 추가 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPdfCount = _courses.where((c) {
      final url = c['pdf_url'] as String?;
      return url != null && url.isNotEmpty;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // ── 헤더 ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A469D), Color(0xFF3B71CA)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_teacherName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const Text('교사',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await _supabase.auth.signOut();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout,
                              color: Colors.white70, size: 16),
                          label: const Text('로그아웃',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('안녕하세요! 👋',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('강의를 관리하고 학생을 모니터링하세요',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _statCard(
                          icon: Icons.menu_book,
                          label: '전체 강의',
                          value: '${_courses.length}개',
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF 업로드',
                          value: '$hasPdfCount개',
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          icon: Icons.pending_outlined,
                          label: 'PDF 미업로드',
                          value: '${_courses.length - hasPdfCount}개',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 강의 목록 헤더 ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '강의 목록 (${_courses.length})',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B4D)),
                ),
                SizedBox(
                  width: 110,
                  child: ElevatedButton.icon(
                    onPressed: _addCourse,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('강의 추가'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B71CA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 강의 목록 ──────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _courses.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_outlined,
                                    size: 60, color: Colors.black26),
                                SizedBox(height: 16),
                                Text('강의가 없습니다',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                                SizedBox(height: 8),
                                Text('강의 추가 버튼을 눌러 시작하세요',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                            itemCount: _courses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, i) => _courseCard(_courses[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _courseCard(Map<String, dynamic> course) {
    final courseId = course['id'] as String;
    final courseName = course['name'] as String;
    final pdfUrl = course['pdf_url'] as String?;
    final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: hasPdf
                  ? const Color(0xFF3B71CA).withOpacity(0.04)
                  : Colors.orange.withOpacity(0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: hasPdf
                        ? const Color(0xFF3B71CA).withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasPdf ? Icons.menu_book : Icons.menu_book_outlined,
                    color: hasPdf ? const Color(0xFF3B71CA) : Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(courseName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172B4D))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: hasPdf ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasPdf ? 'PDF 자료 있음' : 'PDF 자료 없음',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasPdf ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _uploadPdf(courseId, courseName),
                    icon: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_outlined, size: 16),
                    label: Text(hasPdf ? 'PDF 교체' : 'PDF 업로드'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B71CA),
                      side: const BorderSide(
                          color: Color(0xFF3B71CA), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TeacherMonitoringPage(courseName: courseName),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text('모니터링'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B71CA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}