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
  Map<String, double> _progressByCourse = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    try {
      final boundRows = await _supabase
          .from('teacher_students')
          .select('teachers(email)')
          .eq('student_id', widget.studentId);

      final teacherEmails = boundRows
          .map((row) => (row['teachers'] as Map<String, dynamic>?)?['email'])
          .whereType<String>()
          .where((email) => email.isNotEmpty)
          .toList();

      if (teacherEmails.isEmpty) {
        setState(() => _courses = []);
        return;
      }

      final courses = await _supabase
          .from('courses')
          .select('id, name, pdf_url, pdf_id, created_at, teacher_email')
          .inFilter('teacher_email', teacherEmails)
          .order('created_at', ascending: false);

      final pdfIds = courses
          .map((c) => c['pdf_id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final courseNames = courses
          .map((c) => c['name'])
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toList();
      final Map<String, String> courseKeyByName = {
        for (final c in courses)
          if ((c['name'] as String?)?.isNotEmpty == true)
            c['name'] as String:
                ((c['pdf_id'] as String?)?.isNotEmpty == true
                    ? c['pdf_id'] as String
                    : c['name'] as String),
      };

      Map<String, double> progressMap = {};
      if (pdfIds.isNotEmpty) {
        final metrics = await _supabase
            .from('engagement_metrics')
            .select('pdf_id, pdf_name, pdf_page, pdf_total_pages, timestamp')
            .eq('student_id', widget.studentId)
            .inFilter('pdf_id', pdfIds)
            .order('timestamp', ascending: false);

        for (final row in metrics) {
          final key = row['pdf_id'] as String?;
          if (key == null || key.isEmpty || progressMap.containsKey(key)) {
            continue;
          }
          final page = (row['pdf_page'] as num?)?.toDouble();
          final total = (row['pdf_total_pages'] as num?)?.toDouble();
          if (page == null || total == null || total <= 0) continue;
          progressMap[key] = (page / total).clamp(0.0, 1.0);
        }
      }

      if (courseNames.isNotEmpty) {
        final metrics = await _supabase
            .from('engagement_metrics')
            .select('pdf_id, pdf_name, pdf_page, pdf_total_pages, timestamp')
            .eq('student_id', widget.studentId)
            .inFilter('pdf_name', courseNames)
            .order('timestamp', ascending: false);

        for (final row in metrics) {
          final rawName = row['pdf_name'] as String?;
          final key = row['pdf_id'] as String? ??
              (rawName != null ? courseKeyByName[rawName] : null) ??
              rawName;
          if (key == null || key.isEmpty || progressMap.containsKey(key)) {
            continue;
          }
          final page = (row['pdf_page'] as num?)?.toDouble();
          final total = (row['pdf_total_pages'] as num?)?.toDouble();
          if (page == null || total == null || total <= 0) continue;
          progressMap[key] = (page / total).clamp(0.0, 1.0);
        }
      }

      setState(() {
        _courses = List<Map<String, dynamic>>.from(courses);
        _progressByCourse = progressMap;
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
    final pdfId = course['pdf_id'] as String?;
    final pdfUrl = course['pdf_url'] as String?;
    final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;
    final key = (pdfId != null && pdfId.isNotEmpty) ? pdfId : courseName;
    final progress = _progressByCourse[key] ?? _progressByCourse[courseName] ?? 0.0;

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
          if (progress > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B71CA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
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
                            pdfUrl: pdfUrl!,
                            pdfId: pdfId,
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
