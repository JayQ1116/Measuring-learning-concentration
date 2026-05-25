// lib/pages/dashboard_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import 'course_list_page.dart';
import 'learning_page.dart';
import 'login_page.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentDashboard({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _boundTeachers = [];
  bool _loading = true;
  bool _binding = false;
  int _boundTeacherCount = 0;
  Map<String, double> _progressByCourse = {};
  int _totalStudyMinutes = 0;
  double _avgEngagement = 0.0;
  int _completedCourses = 0;
  int _streakDays = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadBoundTeachers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadCourses();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
          .order('created_at', ascending: false)
          .limit(3);

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
      int totalSamples = 0;
      double engagementSum = 0.0;
      int engagementCount = 0;
      final Set<String> studyDays = {};
        final metrics = await _supabase
            .from('engagement_metrics')
            .select('samples, engagement, timestamp')
            .eq('student_id', widget.studentId)
            .order('timestamp', ascending: false);

        for (final row in metrics) {
          final samples = row['samples'] as num?;
          if (samples != null) totalSamples += samples.toInt();
          final engagement = row['engagement'] as num?;
          if (engagement != null) {
            engagementSum += engagement.toDouble();
            engagementCount += 1;
          }
          final ts = row['timestamp'] as String?;
          if (ts != null && ts.isNotEmpty) {
            final dayKey = ts.split('T').first;
            studyDays.add(dayKey);
          }
        }

      if (pdfIds.isNotEmpty) {
        final metrics = await _supabase
            .from('engagement_metrics')
            .select('pdf_id, pdf_page, pdf_total_pages')
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
            .select('pdf_id, pdf_name, pdf_page, pdf_total_pages')
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

      final totalMinutes = ((totalSamples * 5) / 60).round();
      final avgEngagement = engagementCount == 0
          ? 0.0
          : (engagementSum / engagementCount).clamp(0.0, 1.0);
      final completedCount = progressMap.values.where((p) => p >= 1.0).length;
      final streak = _computeStreakDays(studyDays);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(courses);
        _progressByCourse = progressMap;
        _totalStudyMinutes = totalMinutes;
        _avgEngagement = avgEngagement;
        _completedCourses = completedCount;
        _streakDays = streak;
      });
    } catch (e) {
      debugPrint('[StudentDashboard] 강의 로드 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  int _computeStreakDays(Set<String> dayKeys) {
    if (dayKeys.isEmpty) return 0;
    final days = dayKeys
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    if (days.isEmpty) return 0;

    final today = DateTime.now();
    var current = DateTime(today.year, today.month, today.day);
    var streak = 0;
    while (days.contains(current)) {
      streak += 1;
      current = current.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _loadBoundTeachers() async {
    try {
      final rows = await _supabase
          .from('teacher_students')
          .select('teacher_id, teachers(name, email)')
          .eq('student_id', widget.studentId);

      if (mounted) {
        setState(() {
          _boundTeachers = List<Map<String, dynamic>>.from(rows);
          _boundTeacherCount = _boundTeachers.length;
        });
      }
    } catch (e) {
      debugPrint('[StudentDashboard] 교사 로드 실패: $e');
    }
  }

  Future<void> _bindTeacherByEmail() async {
    final emailCtrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('교사 이메일로 연결'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'teacher@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
            child: const Text('연결'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    setState(() => _binding = true);
    try {
      final teacher = await _supabase
          .from('teachers')
          .select('id, name, email')
          .ilike('email', email)
          .maybeSingle();

      if (teacher == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('해당 이메일의 교사를 찾지 못했습니다.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final teacherId = teacher['id'] as String;
      await _supabase.from('teacher_students').upsert({
        'teacher_id': teacherId,
        'student_id': widget.studentId,
      });

      if (mounted) {
        final teacherName = teacher['name'] as String? ?? '교사';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$teacherName 교사와 연결되었습니다.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadBoundTeachers();
      _loadCourses();
    } on PostgrestException catch (e) {
      if (e.code == '23505' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 연결된 교사입니다.'),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      debugPrint('[StudentDashboard] 교사 연결 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('교사 연결 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[StudentDashboard] 교사 연결 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('교사 연결 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  Future<void> _unbindTeacher(String teacherId, String teacherName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('교사 연결 해제'),
        content: Text('$teacherName 교사와의 연결을 해제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('teacher_students')
          .delete()
          .eq('teacher_id', teacherId)
          .eq('student_id', widget.studentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$teacherName 교사와의 연결이 해제되었습니다.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadBoundTeachers();
      _loadCourses();
    } catch (e) {
      debugPrint('[StudentDashboard] 교사 해제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('교사 연결 해제 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatCourseTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(createdAt).toLocal();
      final y = parsed.year.toString().padLeft(4, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final d = parsed.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return createdAt;
    }
  }

  Future<void> _openCourse(BuildContext context, Map<String, dynamic> course) async {
    final courseName = course['name'] as String;
    final pdfId = course['pdf_id'] as String?;
    final pdfUrl = course['pdf_url'] as String?;

    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF가 준비되지 않았습니다.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentLearningPage(
          courseName: courseName,
          studentId: widget.studentId,
          pdfUrl: pdfUrl,
          pdfId: pdfId,
        ),
      ),
    );
    if (mounted) {
      await _loadCourses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.book, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('학습 플랫폼', style: TextStyle(fontSize: 16)),
                Text('${widget.studentName} 학생',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '안녕하세요, ${widget.studentName}님! 👋',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('오늘도 열심히 학습해볼까요?',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),

            // 통계 카드
            Row(
              children: [
                _statCard('총 학습 시간', '${_totalStudyMinutes}분',
                    Colors.orange, Icons.trending_up),
                const SizedBox(width: 12),
                _statCard('평균 집중도', '${(_avgEngagement * 100).toInt()}점',
                    Colors.green, Icons.psychology),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('완료한 강의', '${_completedCourses}개',
                    Colors.purple, Icons.check_circle_outline),
                const SizedBox(width: 12),
                _statCard('학습 연속일', '${_streakDays}일',
                    Colors.blue, Icons.local_fire_department),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _binding ? null : _bindTeacherByEmail,
                    icon: _binding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('교사 연결'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('연결 ${_boundTeacherCount}명',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            if (_boundTeachers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                children: _boundTeachers.map((row) {
                  final teacher = row['teachers'] as Map<String, dynamic>?;
                  final teacherId = row['teacher_id'] as String;
                  final teacherName =
                      teacher?['name'] as String? ?? '교사';
                  final teacherEmail = teacher?['email'] as String? ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teacherName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              if (teacherEmail.isNotEmpty)
                                Text(teacherEmail,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _unbindTeacher(teacherId, teacherName),
                          child: const Text('해제',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),

            // 강의 섹션
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📖 내 강의',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseListPage(
                                studentId: widget.studentId,
                                studentName: widget.studentName,
                              ),
                            ),
                          );
                          if (mounted) {
                            await _loadCourses();
                          }
                        },
                        child: const Text('전체 보기 →',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_courses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('표시할 강의가 없습니다',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  else
                    ...List.generate(_courses.length, (i) {
                      final course = _courses[i];
                      final createdAt = course['created_at'] as String?;
                      final courseName = course['name'] as String;
                      final key = (course['pdf_id'] as String?)?.isNotEmpty == true
                          ? course['pdf_id'] as String
                          : courseName;
                      final progress = _progressByCourse[key] ??
                          _progressByCourse[courseName] ??
                          0.0;
                      return GestureDetector(
                        onTap: () => _openCourse(context, course),
                        child: _courseItem(
                          courseName,
                          progress,
                          _formatCourseTime(createdAt),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String title, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, size: 16, color: color.withOpacity(0.7)),
              ],
            ),
            const SizedBox(height: 8),
            Text(val,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _courseItem(String name, double progress, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress, minHeight: 7),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
