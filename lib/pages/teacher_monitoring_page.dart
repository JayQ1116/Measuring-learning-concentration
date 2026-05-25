import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherMonitoringPage extends StatefulWidget {
  final String courseName;
  final String? pdfId;

  const TeacherMonitoringPage({
    super.key,
    required this.courseName,
    this.pdfId,
  });

  @override
  State<TeacherMonitoringPage> createState() => _TeacherMonitoringPageState();
}

class _TeacherMonitoringPageState extends State<TeacherMonitoringPage> {
  final _supabase = Supabase.instance.client;

  Timer? _timer;
  String _timeStr = '';
  bool _loading = true;
  List<_StudentFocus> _students = [];
  List<_PageFocus> _pageFocus = [];
  Map<int, List<_PageStudentScore>> _pageStudentScores = {};
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _timeStr = timeStr;
          _students = [];
          _loading = false;
        });
        return;
      }

      final rosterRows = await _supabase
          .from('teacher_students')
          .select('student_id, students(name)')
          .eq('teacher_id', user.id);

      final studentIds = <String>[];
      final nameById = <String, String>{};
      for (final row in rosterRows) {
        final id = row['student_id'] as String?;
        if (id == null || id.isEmpty) continue;
        studentIds.add(id);
        String? joinedName;
        final joined = row['students'];
        if (joined is Map<String, dynamic>) {
          joinedName = joined['name'] as String?;
        } else if (joined is List && joined.isNotEmpty) {
          final first = joined.first;
          if (first is Map<String, dynamic>) {
            joinedName = first['name'] as String?;
          }
        }
        if (joinedName != null && joinedName.trim().isNotEmpty) {
          nameById[id] = joinedName.trim();
        }
      }

      if (studentIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _timeStr = timeStr;
          _students = [];
          _loading = false;
        });
        return;
      }

      final unresolved = studentIds.where((id) => !nameById.containsKey(id)).toList();
      if (unresolved.isNotEmpty) {
        await _fillNamesFromStudents(
          unresolvedIds: unresolved,
          nameById: nameById,
        );
      }

      var query = _supabase
          .from('engagement_metrics')
          .select('student_id, engagement, timestamp, pdf_id, pdf_name, pdf_page, pdf_total_pages')
          .inFilter('student_id', studentIds);

      if (widget.pdfId != null && widget.pdfId!.isNotEmpty) {
        query = query.eq('pdf_id', widget.pdfId!);
      } else {
        query = query.eq('pdf_name', widget.courseName);
      }

      final metricRows = await query.order('timestamp', ascending: false).limit(3000);

      final latestByStudent = <String, Map<String, dynamic>>{};
      for (final row in metricRows) {
        final id = row['student_id'] as String?;
        if (id == null || id.isEmpty || latestByStudent.containsKey(id)) continue;
        latestByStudent[id] = row;
      }

      final students = <_StudentFocus>[];
      for (final id in studentIds) {
        final latest = latestByStudent[id];
        final engagement = (latest?['engagement'] as num?)?.toDouble() ?? 0.0;
        final score = (engagement * 100).round().clamp(0, 100);
        students.add(_StudentFocus(
          studentId: id,
          studentName: (nameById[id]?.isNotEmpty == true) ? nameById[id]! : id,
          score: score,
          timestamp: latest?['timestamp'] as String?,
          isOffline: _isOffline(latest?['timestamp'] as String?),
        ));
      }

      students.sort((a, b) => a.studentName.compareTo(b.studentName));

      final byPage = <int, _PageBucket>{};
      final byPageStudent = <int, Map<String, _StudentAggregate>>{};
      var totalPages = 0;
      for (final row in metricRows) {
        final page = (row['pdf_page'] as num?)?.toInt();
        final total = (row['pdf_total_pages'] as num?)?.toInt();
        final engagement = (row['engagement'] as num?)?.toDouble();
        final studentId = row['student_id'] as String?;
        final timestamp = row['timestamp'] as String?;
        if (total != null && total > totalPages) totalPages = total;
        if (page == null || page <= 0 || engagement == null) continue;
        byPage.putIfAbsent(page, () => _PageBucket()).add(engagement.clamp(0.0, 1.0));
        if (studentId != null && studentId.isNotEmpty) {
          byPageStudent.putIfAbsent(page, () => <String, _StudentAggregate>{});
          final map = byPageStudent[page]!;
          final agg = map.putIfAbsent(studentId, () => _StudentAggregate());
          agg.sum += engagement.clamp(0.0, 1.0);
          agg.count += 1;
          if (timestamp != null && (agg.latestTimestamp == null || timestamp.compareTo(agg.latestTimestamp!) > 0)) {
            agg.latestTimestamp = timestamp;
          }
        }
      }
      final pageFocus = byPage.entries.map((e) {
        final avg = e.value.count == 0 ? 0.0 : e.value.sum / e.value.count;
        return _PageFocus(page: e.key, score: (avg * 100).round().clamp(0, 100));
      }).toList()
        ..sort((a, b) => a.page.compareTo(b.page));
      final pageStudentScores = <int, List<_PageStudentScore>>{};
      for (final entry in byPageStudent.entries) {
        final list = entry.value.entries.map((e) {
          final studentId = e.key;
          final agg = e.value;
          final avgScore = agg.count == 0 ? 0 : ((agg.sum / agg.count) * 100).round().clamp(0, 100);
          final latest = agg.latestTimestamp;
          return _PageStudentScore(
            studentId: studentId,
            studentName: (nameById[studentId]?.isNotEmpty == true) ? nameById[studentId]! : studentId,
            score: avgScore,
            timestamp: latest,
            isOffline: _isOffline(latest),
          );
        }).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        pageStudentScores[entry.key] = list;
      }

      if (!mounted) return;
      setState(() {
        _timeStr = timeStr;
        _students = students;
        _pageFocus = pageFocus;
        _pageStudentScores = pageStudentScores;
        _totalPages = totalPages;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[TeacherMonitoringPage] load failed: $e');
      if (!mounted) return;
      setState(() {
        _timeStr = timeStr;
        _loading = false;
      });
    }
  }

  Future<void> _fillNamesFromStudents({
    required List<String> unresolvedIds,
    required Map<String, String> nameById,
  }) async {
    Future<void> tryKey(String key) async {
      try {
        final rows = await _supabase
            .from('students')
            .select('id, name, $key')
            .inFilter(key, unresolvedIds);
        for (final row in rows) {
          final rawName = row['name'] as String?;
          if (rawName == null || rawName.trim().isEmpty) continue;
          final mapped = row[key] as String?;
          if (mapped != null && mapped.isNotEmpty) {
            nameById[mapped] = rawName.trim();
          }
          final id = row['id'] as String?;
          if (id != null && id.isNotEmpty) {
            nameById[id] = rawName.trim();
          }
        }
      } catch (_) {
        // ignore missing-column and RLS-path failures for fallback keys
      }
    }

    await tryKey('id');
    final still = unresolvedIds.where((id) => !nameById.containsKey(id)).toList();
    if (still.isEmpty) return;
    await tryKey('student_id');
    await tryKey('user_id');
    await tryKey('auth_user_id');
    await tryKey('email');
  }

  Color _focusColor(int score) {
    if (score >= 70) return const Color(0xFF2ECC71);
    if (score >= 50) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  bool _isOffline(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return true;
    final ts = DateTime.tryParse(timestamp);
    if (ts == null) return true;
    final diff = DateTime.now().toUtc().difference(ts.toUtc()).inSeconds.abs();
    return diff > 5;
  }

  @override
  Widget build(BuildContext context) {
    final focused = _students.where((s) => !s.isOffline && s.score >= 70).length;
    final normal = _students.where((s) => !s.isOffline && s.score >= 50 && s.score < 70).length;
    final attention = _students.where((s) => !s.isOffline && s.score < 50).length;
    final offline = _students.where((s) => s.isOffline).length;
    final total = _students.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B35),
      appBar: AppBar(
        backgroundColor: const Color(0xFF162040),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class Monitoring',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(widget.courseName, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          Text(_timeStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _showHeatmapDialog(context),
            icon: const Icon(Icons.bar_chart, color: Color(0xFFF39C12)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatCard('Students', '$total', Icons.people_outline, const Color(0xFF1E2D4F), Colors.white70),
                      const SizedBox(width: 12),
                      _buildStatCard('Focused', '$focused', Icons.trending_up, const Color(0xFF1A3A2A), const Color(0xFF2ECC71)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard('Normal', '$normal', Icons.access_time_outlined, const Color(0xFF3A2A10), const Color(0xFFF39C12)),
                      const SizedBox(width: 12),
                      _buildStatCard('Need Help', '$attention', Icons.warning_amber_outlined, const Color(0xFF3A1020), const Color(0xFFE74C3C)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard('Offline', '$offline', Icons.cloud_off_outlined, const Color(0xFF2A2F3A), Colors.white70),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF162040), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Focus Grid',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        if (_students.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No student metrics yet for this course.', style: TextStyle(color: Colors.white60)),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 1,
                            ),
                            itemCount: _students.length,
                            itemBuilder: (context, i) {
                              final student = _students[i];
                              final color = student.isOffline ? Colors.grey : _focusColor(student.score);
                              return GestureDetector(
                                onTap: () => _showStudentDetail(context, student),
                                child: Container(
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${i + 1}'.padLeft(2, '0'),
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                        if (student.isOffline)
                                          const Text(
                                            'OFF',
                                            style: TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF162040), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Focus Distribution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              height: 150,
                              width: 150,
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: focused.toDouble(),
                                      color: const Color(0xFF2ECC71),
                                      title: total > 0 && focused > 0 ? '${(focused / total * 100).round()}%' : '',
                                      radius: 60,
                                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    PieChartSectionData(
                                      value: normal.toDouble(),
                                      color: const Color(0xFFF39C12),
                                      title: total > 0 && normal > 0 ? '${(normal / total * 100).round()}%' : '',
                                      radius: 60,
                                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    PieChartSectionData(
                                      value: attention.toDouble(),
                                      color: const Color(0xFFE74C3C),
                                      title: total > 0 && attention > 0 ? '${(attention / total * 100).round()}%' : '',
                                      radius: 60,
                                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildLegendRow(const Color(0xFF2ECC71), 'Focused (70+)', focused),
                                  const SizedBox(height: 12),
                                  _buildLegendRow(const Color(0xFFF39C12), 'Normal (50-69)', normal),
                                  const SizedBox(height: 12),
                                  _buildLegendRow(const Color(0xFFE74C3C), 'Need Help (<50)', attention),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF162040), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C), size: 18),
                            SizedBox(width: 8),
                            Text('Students Need Help', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final student in _students.where((s) => !s.isOffline && s.score < 50))
                                _buildAttentionStudentCard(student),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color bgColor, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.white60), overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, color: Colors.white30, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60))),
        Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildAttentionStudentCard(_StudentFocus student) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D4F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(student.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            student.isOffline ? 'Offline' : '${student.score}',
            style: TextStyle(
              color: student.isOffline ? Colors.white60 : const Color(0xFFE74C3C),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: student.isOffline ? 0 : (student.score / 100),
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(student.isOffline ? Colors.grey : const Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetail(BuildContext context, _StudentFocus student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162040),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(student.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              student.isOffline ? 'Offline' : '${student.score}',
              style: TextStyle(
                color: student.isOffline ? Colors.grey : _focusColor(student.score),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              student.timestamp ?? 'No timestamp',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Color _pageHeatColor(int score) {
    if (score >= 70) return const Color(0xFF2ECC71);
    if (score >= 50) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  Widget _buildHeatCell(int page, int score) {
    final color = _pageHeatColor(score);
    return GestureDetector(
      onTap: () => _showPageStudentScoresDialog(page),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$page', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('$score', style: const TextStyle(color: Colors.white, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHeatCell(int page) {
    return GestureDetector(
      onTap: () => _showPageStudentScoresDialog(page),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text('$page', style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showPageStudentScoresDialog(int page) {
    final scores = _pageStudentScores[page] ?? const <_PageStudentScore>[];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF162040),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Page $page Student Scores', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (scores.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No student data on this page yet.', style: TextStyle(color: Colors.white60)),
                )
              else
                SizedBox(
                  width: 420,
                  height: 320,
                  child: ListView.separated(
                    itemCount: scores.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (_, i) {
                      final s = scores[i];
                      return ListTile(
                        dense: true,
                        title: Text(s.studentName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(s.timestamp ?? '-', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        trailing: Text(
                          s.isOffline ? 'Offline · Avg ${s.score}' : '${s.score}',
                          style: TextStyle(
                            color: s.isOffline ? Colors.grey : _focusColor(s.score),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHeatmapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF162040),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PDF Page Focus Heatmap', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                _totalPages > 0
                    ? 'Average engagement by page (total pages: $_totalPages)'
                    : 'Average engagement by page',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (_pageFocus.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No page-level data yet.', style: TextStyle(color: Colors.white60)),
                  ),
                )
              else
                Builder(
                  builder: (_) {
                    final byPage = {for (final p in _pageFocus) p.page: p.score};
                    final cells = <Widget>[];
                    if (_totalPages > 0) {
                      for (var p = 1; p <= _totalPages; p++) {
                        final score = byPage[p];
                        cells.add(score == null ? _buildEmptyHeatCell(p) : _buildHeatCell(p, score));
                      }
                    } else {
                      for (final page in _pageFocus) {
                        cells.add(_buildHeatCell(page.page, page.score));
                      }
                    }
                    return Wrap(spacing: 8, runSpacing: 8, children: cells);
                  },
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _legendDot(const Color(0xFFE74C3C), '<50'),
                  const SizedBox(width: 10),
                  _legendDot(const Color(0xFFF39C12), '50-69'),
                  const SizedBox(width: 10),
                  _legendDot(const Color(0xFF2ECC71), '70+'),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
      child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white60)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _StudentFocus {
  final String studentId;
  final String studentName;
  final int score;
  final String? timestamp;
  final bool isOffline;

  const _StudentFocus({
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.timestamp,
    required this.isOffline,
  });
}

class _PageBucket {
  double sum = 0.0;
  int count = 0;

  void add(double value) {
    sum += value;
    count += 1;
  }
}

class _PageFocus {
  final int page;
  final int score;

  const _PageFocus({required this.page, required this.score});
}

class _StudentAggregate {
  double sum = 0.0;
  int count = 0;
  String? latestTimestamp;
}

class _PageStudentScore {
  final String studentId;
  final String studentName;
  final int score;
  final String? timestamp;
  final bool isOffline;

  const _PageStudentScore({
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.timestamp,
    required this.isOffline,
  });
}
