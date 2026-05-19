// lib/pages/course_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import 'learning_page.dart';

class CourseListPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const CourseListPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    try {
      // Supabase에서 강의 목록 로드
      final courses = await _supabase
          .from('courses')
          .select('id, name, pdf_url, created_at')
          .order('created_at', ascending: false);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(courses);
      });
    } catch (e) {
      debugPrint('[CourseList] 로드 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('내 강의'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCourses,
              child: _courses.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 60, color: Colors.black26),
                          SizedBox(height: 16),
                          Text('등록된 강의가 없습니다',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('교사가 강의를 등록하면 여기에 표시됩니다',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('전체 강의 목록',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                          const SizedBox(height: 4),
                          const Text('학습하고 싶은 강의를 선택해주세요',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 24),
                          const Text('📖 강의 목록',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ...List.generate(_courses.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _courseCard(context, _courses[i]),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _courseCard(BuildContext context, Map<String, dynamic> course) {
    final courseId = course['id'] as String;
    final courseName = course['name'] as String;
    final pdfUrl = course['pdf_url'] as String?;
    final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(courseName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasPdf
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasPdf ? 'PDF 있음' : 'PDF 준비 중',
                  style: TextStyle(
                    color: hasPdf ? Colors.green : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPdf ? 'PDF 강의 자료가 준비되었습니다' : '교사가 PDF를 업로드하면 학습할 수 있습니다',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasPdf
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentLearningPage(
                            courseName: courseName,
                            studentId: widget.studentId,
                            pdfUrl: pdfUrl!, // ← PDF URL 전달
                          ),
                        ),
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasPdf
                    ? const Color(0xFF3B71CA)
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                hasPdf ? '학습 시작하기' : 'PDF 준비 중',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}