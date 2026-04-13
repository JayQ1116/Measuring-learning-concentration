import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TeacherMonitoringPage extends StatefulWidget {
  final String courseName;
  const TeacherMonitoringPage({super.key, required this.courseName});

  @override
  State<TeacherMonitoringPage> createState() => _TeacherMonitoringPageState();
}

class _TeacherMonitoringPageState extends State<TeacherMonitoringPage> {
  final Random _rng = Random();
  Timer? _timer;
  late DateTime _startTime;
  late List<int> _focusScores;
  final List<Map<String, dynamic>> _heatmapMarks = [];
  String _timeStr = '';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _focusScores = List.generate(32, (i) => 50 + _rng.nextInt(50));
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _simulateFocusChange());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() => _timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}");
  }

  void _simulateFocusChange() {
    setState(() {
      for (int i = 0; i < 32; i++) {
        final delta = _rng.nextInt(11) - 5;
        _focusScores[i] = (_focusScores[i] + delta).clamp(10, 100);
      }
      final lowCount = _focusScores.where((s) => s < 40).length;
      if (lowCount >= 3 && _heatmapMarks.length < 5) {
        final elapsed = DateTime.now().difference(_startTime).inMinutes;
        final topics = ["역전파(Backpropagation)", "경사하강법(Gradient Descent)", "활성화 함수(Activation)", "손실 함수(Loss Function)", "배치 정규화(Batch Norm)"];
        final alreadyMarked = _heatmapMarks.map((m) => m['topic']).toSet();
        for (final topic in topics) {
          if (!alreadyMarked.contains(topic)) {
            _heatmapMarks.add({'topic': topic, 'minute': elapsed, 'count': lowCount});
            break;
          }
        }
      }
      _updateTime();
    });
  }

  Color _focusColor(int score) {
    if (score >= 70) return const Color(0xFF2ECC71);
    if (score >= 50) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusScores.where((s) => s >= 70).length;
    final normal = _focusScores.where((s) => s >= 50 && s < 70).length;
    final attention = _focusScores.where((s) => s < 50).length;

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
            const Text("교사 대시보드", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard("전체 학생", "32명", Icons.people_outline, const Color(0xFF1E2D4F), Colors.white70),
                const SizedBox(width: 12),
                _buildStatCard("집중 중", "${focused}명", Icons.trending_up, const Color(0xFF1A3A2A), const Color(0xFF2ECC71)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard("보통", "${normal}명", Icons.access_time_outlined, const Color(0xFF3A2A10), const Color(0xFFF39C12)),
                const SizedBox(width: 12),
                _buildStatCard("주의 필요", "${attention}명", Icons.warning_amber_outlined, const Color(0xFF3A1020), const Color(0xFFE74C3C)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF162040), borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("실시간 학급 현황", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1,
                    ),
                    itemCount: 32,
                    itemBuilder: (context, i) {
                      final score = _focusScores[i];
                      final color = _focusColor(score);
                      return GestureDetector(
                        onTap: () => _showStudentDetail(context, i, score),
                        child: Container(
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                          child: Center(
                            child: Text("${(i + 1).toString().padLeft(2, '0')}",
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 16, children: [
                    _buildLegendDot(const Color(0xFF2ECC71), "집중"),
                    _buildLegendDot(const Color(0xFFF39C12), "보통"),
                    _buildLegendDot(const Color(0xFFE74C3C), "주의"),
                  ]),
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
                  const Text("집중도 분포", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 150, width: 150,
                        child: PieChart(PieChartData(
                          sections: [
                            PieChartSectionData(value: focused.toDouble(), color: const Color(0xFF2ECC71),
                              title: focused > 0 ? "${(focused / 32 * 100).round()}%" : "", radius: 60,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            PieChartSectionData(value: normal.toDouble(), color: const Color(0xFFF39C12),
                              title: normal > 0 ? "${(normal / 32 * 100).round()}%" : "", radius: 60,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            PieChartSectionData(value: attention.toDouble(), color: const Color(0xFFE74C3C),
                              title: attention > 0 ? "${(attention / 32 * 100).round()}%" : "", radius: 60,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                          sectionsSpace: 3, centerSpaceRadius: 25,
                        )),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Column(children: [
                        _buildLegendRow(const Color(0xFF2ECC71), "집중 (70+)", focused),
                        const SizedBox(height: 12),
                        _buildLegendRow(const Color(0xFFF39C12), "보통 (50~69)", normal),
                        const SizedBox(height: 12),
                        _buildLegendRow(const Color(0xFFE74C3C), "분산/피로", attention),
                      ])),
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
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C), size: 18),
                    const SizedBox(width: 8),
                    const Text("주의가 필요한 학생", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (int i = 0; i < 32; i++)
                        if (_focusScores[i] < 50) _buildAttentionStudentCard(i, _focusScores[i]),
                    ]),
                  ),
                ],
              ),
            ),
            if (_heatmapMarks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF162040), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.bar_chart, color: Color(0xFFF39C12), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("집중도 저하 구간", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))),
                      TextButton(onPressed: () => _showHeatmapDialog(context),
                        child: const Text("전체 보기 →", style: TextStyle(color: Color(0xFFF39C12), fontSize: 12))),
                    ]),
                    const SizedBox(height: 12),
                    for (final mark in _heatmapMarks) _buildHeatmapItem(mark),
                  ],
                ),
              ),
            ],
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.white60), overflow: TextOverflow.ellipsis)),
            Icon(icon, color: Colors.white30, size: 16),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor)),
        ]),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
    ]);
  }

  Widget _buildLegendRow(Color color, String label, int count) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60))),
      Text("$count명", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _buildAttentionStudentCard(int index, int score) {
    final names = ["학생 A","학생 B","학생 C","학생 D","학생 E","학생 F","학생 G","학생 H","학생 I","학생 J","학생 K","학생 L","학생 M","학생 N","학생 O","학생 P","학생 Q","학생 R","학생 S","학생 T","학생 U","학생 V","학생 W","학생 X","학생 Y","학생 Z","학생 AA","학생 BB","학생 CC","학생 DD","학생 EE","학생 FF"];
    return Container(
      width: 120, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D4F), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(names[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Text("$score점", style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: score / 100, minHeight: 4,
            backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFFE74C3C)))),
      ]),
    );
  }

  Widget _buildHeatmapItem(Map<String, dynamic> mark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.flag_outlined, color: Color(0xFFE74C3C), size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mark['topic'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          Text("${mark['minute']}분 경 • ${mark['count']}명 영향", style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFE74C3C).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
          child: const Text("난이도 높음", style: TextStyle(color: Color(0xFFE74C3C), fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  void _showStudentDetail(BuildContext context, int index, int score) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF162040),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("학생 ${(index + 1).toString().padLeft(3, '0')} 상세",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("$score점", style: TextStyle(color: _focusColor(score), fontSize: 36, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(score >= 70 ? "✅ 정상적으로 학습 중입니다" : score >= 50 ? "⚠️ 집중도가 다소 낮습니다" : "🚨 주의가 필요합니다",
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기", style: TextStyle(color: Colors.white60))),
        if (score < 50) ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
          child: const Text("AI 도움 전송")),
      ],
    ));
  }

  void _showHeatmapDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF162040),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("교재 난이도 히트맵", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("집중도가 낮아진 구간을 자동으로 감지합니다", style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 20),
          if (_heatmapMarks.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20),
              child: Text("아직 감지된 구간이 없습니다", style: TextStyle(color: Colors.white60))))
          else
            for (final mark in _heatmapMarks) _buildHeatmapItem(mark),
          if (_heatmapMarks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("구간별 영향 학생 수", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(height: 130, child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround, maxY: 32,
              gridData: FlGridData(show: false), borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= _heatmapMarks.length) return const SizedBox();
                    return Text("${_heatmapMarks[i]['minute']}분", style: const TextStyle(color: Colors.white60, fontSize: 10));
                  })),
              ),
              barGroups: [for (int i = 0; i < _heatmapMarks.length; i++)
                BarChartGroupData(x: i, barRods: [BarChartRodData(
                  toY: (_heatmapMarks[i]['count'] as int).toDouble(),
                  color: const Color(0xFFE74C3C), width: 24, borderRadius: BorderRadius.circular(4))])],
            ))),
          ],
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text("닫기", style: TextStyle(color: Colors.white60)))),
        ]),
      ),
    ));
  }
}