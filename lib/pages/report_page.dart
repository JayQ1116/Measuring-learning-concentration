import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class LearningReportPage extends StatelessWidget {
  final String studentId;
  final String courseName;

  const LearningReportPage({
    super.key,
    required this.studentId,
    required this.courseName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "학습 결과 보고서",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF172B4D)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_outlined, color: Color(0xFF172B4D), size: 18),
            label: const Text("홈으로", style: TextStyle(color: Color(0xFF172B4D), fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 통계 카드 2x2
            Row(
              children: [
                _buildStatCard("평균 집중도", "76점", Colors.green, Icons.track_changes_outlined),
                const SizedBox(width: 12),
                _buildStatCard("학습 시간", "47분", Colors.orange, Icons.trending_up),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard("휴대폰 간섭", "8회", Colors.red, Icons.smartphone_outlined),
                const SizedBox(width: 12),
                _buildStatCard("피로도", "중간", Colors.purple, Icons.coffee_outlined),
              ],
            ),

            const SizedBox(height: 20),

            // 집중도 변화 추이
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("집중도 변화 추이",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
                  const Text("5초 알고리즘 기반", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 20),
                  SizedBox(height: 200, child: LineChart(_focusChartData())),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 방해 요소 분석
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("주요 방해 요소 분석",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
                  const SizedBox(height: 20),
                  SizedBox(height: 180, child: BarChart(_distractionChartData())),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // AI 종합 평가
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B71CA).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF3B71CA), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text("AI 종합 평가",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAiCommentItem(
                    icon: Icons.check_circle_outline, color: Colors.green, title: "강점",
                    content: "수업 초반 25분간 집중도가 85점 이상으로 매우 높았습니다. 딥러닝 개념 설명 구간에서 집중력이 최고조에 달했습니다.",
                  ),
                  const SizedBox(height: 16),
                  _buildAiCommentItem(
                    icon: Icons.warning_amber_outlined, color: Colors.orange, title: "개선 필요",
                    content: "35분 이후 집중도가 급격히 하락했습니다. 5~10분 휴식을 권장합니다. 휴대폰 사용이 8회로 집중력 저하의 주요 원인으로 분석됩니다.",
                  ),
                  const SizedBox(height: 16),
                  _buildAiCommentItem(
                    icon: Icons.lightbulb_outline, color: Colors.blue, title: "추천 학습 전략",
                    content: "포모도로 기법(25분 집중 + 5분 휴식)을 활용하고, 학습 중 휴대폰을 무음 모드로 전환하세요.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 집중도 구간 분포
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("집중도 구간 분포",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        height: 150, width: 150,
                        child: PieChart(PieChartData(
                          sections: [
                            PieChartSectionData(value: 45, color: Colors.green, title: '45%', radius: 60,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            PieChartSectionData(value: 35, color: Colors.orange, title: '35%', radius: 60,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            PieChartSectionData(value: 20, color: Colors.red, title: '20%', radius: 60,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                          sectionsSpace: 3, centerSpaceRadius: 25,
                        )),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(children: [
                          _buildLegendItem(Colors.green, "고집중 (70+)", "45%"),
                          const SizedBox(height: 12),
                          _buildLegendItem(Colors.orange, "보통 (40~70)", "35%"),
                          const SizedBox(height: 12),
                          _buildLegendItem(Colors.red, "저집중 (40-)", "20%"),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.replay),
                label: const Text("다시 학습하기"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102C57),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15)],
      ),
      child: child,
    );
  }

  LineChartData _focusChartData() {
    final spots = [
      const FlSpot(0, 85), const FlSpot(5, 88), const FlSpot(10, 80),
      const FlSpot(15, 63), const FlSpot(20, 70), const FlSpot(25, 90),
      const FlSpot(30, 83), const FlSpot(35, 75), const FlSpot(40, 60), const FlSpot(45, 55),
    ];
    return LineChartData(
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1, dashArray: [5, 5]),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 30, interval: 25,
          getTitlesWidget: (v, _) => Text("${v.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24, interval: 10,
          getTitlesWidget: (v, _) => Text("${v.toInt()}분", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0, maxX: 45, minY: 0, maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots, isCurved: true, color: const Color(0xFF4C9EFF), barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF4C9EFF).withValues(alpha: 0.35), const Color(0xFF4C9EFF).withValues(alpha: 0.0)],
          )),
        ),
      ],
    );
  }

  BarChartData _distractionChartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround, maxY: 10,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24, interval: 2,
          getTitlesWidget: (v, _) => Text("${v.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) {
            const labels = ["휴대폰", "졸음", "소음", "기타"];
            final i = v.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(labels[i], style: const TextStyle(fontSize: 11, color: Colors.grey)));
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: const Color(0xFFFFC107), width: 40, borderRadius: BorderRadius.circular(6))]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 5, color: const Color(0xFFFFC107), width: 40, borderRadius: BorderRadius.circular(6))]),
        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 1, color: const Color(0xFFFFC107), width: 40, borderRadius: BorderRadius.circular(6))]),
        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 3, color: const Color(0xFFFFC107), width: 40, borderRadius: BorderRadius.circular(6))]),
      ],
    );
  }

  Widget _buildAiCommentItem({required IconData icon, required Color color, required String title, required String content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 3),
          Text(content, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.6)),
        ])),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, String percent) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Text(percent, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}