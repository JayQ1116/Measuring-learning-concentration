import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LearningReportPage extends StatefulWidget {
  final String studentId;
  final String courseName;
  final String? pdfId;

  const LearningReportPage({
    super.key,
    required this.studentId,
    required this.courseName,
    this.pdfId,
  });

  @override
  State<LearningReportPage> createState() => _LearningReportPageState();
}

class _LearningReportPageState extends State<LearningReportPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  int _totalStudyMinutes = 0;
  int _avgEngagementScore = 0;
  List<FlSpot> _focusSpots = const [];
  int _maxMinute = 1;
  int _highFocusPct = 0;
  int _midFocusPct = 0;
  int _lowFocusPct = 0;
  List<_PageFocus> _pageFocus = const [];
  int _pdfTotalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    try {
      var query = _supabase
          .from('engagement_metrics')
          .select('samples, engagement, timestamp, pdf_page, pdf_total_pages')
          .eq('student_id', widget.studentId);

      if (widget.pdfId != null && widget.pdfId!.isNotEmpty) {
        query = query.eq('pdf_id', widget.pdfId!);
      } else {
        query = query.eq('pdf_name', widget.courseName);
      }

      final rows = await query.order('timestamp', ascending: true);

      var totalSamples = 0;
      var engagementSum = 0.0;
      var engagementCount = 0;
      final Map<int, _Bucket> buckets = {};
      final Map<int, _Bucket> pageBuckets = {};
      final List<_SamplePoint> samplesBuffer = [];
      var elapsedSeconds = 0.0;
      var highWeight = 0.0;
      var midWeight = 0.0;
      var lowWeight = 0.0;
      var totalWeight = 0.0;
      var pdfTotalPages = 0;

      for (final row in rows) {
        final samples = row['samples'] as num?;
        if (samples != null) totalSamples += samples.toInt();
        final engagement = row['engagement'] as num?;
        final pdfPage = (row['pdf_page'] as num?)?.toInt();
        final pdfTotal = (row['pdf_total_pages'] as num?)?.toInt();
        if (pdfTotal != null && pdfTotal > pdfTotalPages) pdfTotalPages = pdfTotal;
        if (engagement != null) {
          final value = engagement.toDouble().clamp(0.0, 1.0);
          engagementSum += value;
          engagementCount += 1;

          final weight = (samples ?? 1).toDouble();
          totalWeight += weight;
          if (value >= 0.7) {
            highWeight += weight;
          } else if (value >= 0.4) {
            midWeight += weight;
          } else {
            lowWeight += weight;
          }

          final sampleSeconds = (samples ?? 1).toDouble() * 5.0;
          elapsedSeconds += sampleSeconds;
          final minuteIndex = (elapsedSeconds / 60).floor();
          samplesBuffer.add(_SamplePoint(minuteIndex, value, weight));

          if (pdfPage != null && pdfPage > 0) {
            pageBuckets.putIfAbsent(pdfPage, () => _Bucket()).add(value, weight);
          }
        }
      }

      final totalMinutes = ((totalSamples * 5) / 60).round();
      final avgEngagement = engagementCount == 0
          ? 0.0
          : (engagementSum / engagementCount).clamp(0.0, 1.0);

      final bucketSize = totalMinutes <= 10
          ? 1
          : ((totalMinutes / 10).ceil().clamp(1, 60));

      for (final point in samplesBuffer) {
        final bucketIndex = (point.minute ~/ bucketSize) * bucketSize;
        buckets.putIfAbsent(bucketIndex, () => _Bucket()).add(point.value, point.weight);
      }

      final spots = <FlSpot>[];
      if (buckets.isNotEmpty) {
        final keys = buckets.keys.toList()..sort();
        for (final k in keys) {
          final bucket = buckets[k]!;
          final avg = bucket.totalWeight == 0
              ? 0.0
              : (bucket.totalValue / bucket.totalWeight);
          spots.add(FlSpot(k.toDouble(), (avg * 100).clamp(0.0, 100.0)));
        }
      }

      int highPct = 0;
      int midPct = 0;
      int lowPct = 0;
      if (totalWeight > 0) {
        highPct = ((highWeight / totalWeight) * 100).round();
        midPct = ((midWeight / totalWeight) * 100).round();
        lowPct = 100 - highPct - midPct;
      }

      final pageFocus = pageBuckets.entries.map((e) {
        final b = e.value;
        final avg = b.totalWeight == 0 ? 0.0 : (b.totalValue / b.totalWeight);
        return _PageFocus(page: e.key, score: (avg * 100).round().clamp(0, 100));
      }).toList()
        ..sort((a, b) => a.page.compareTo(b.page));

      if (mounted) {
        setState(() {
          _totalStudyMinutes = totalMinutes;
          _avgEngagementScore = (avgEngagement * 100).round();
          _focusSpots = spots.isEmpty ? const [FlSpot(0, 0)] : spots;
            _maxMinute = totalMinutes <= 0 ? 1 : totalMinutes;
          _highFocusPct = highPct.clamp(0, 100);
          _midFocusPct = midPct.clamp(0, 100);
          _lowFocusPct = lowPct.clamp(0, 100);
          _pageFocus = pageFocus;
          _pdfTotalPages = pdfTotalPages;
        });
      }
    } catch (e) {
      debugPrint('[LearningReportPage] 지표 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                _buildStatCard(
                  "평균 집중도",
                  _loading ? "-" : "${_avgEngagementScore}점",
                  Colors.green,
                  Icons.track_changes_outlined,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  "학습 시간",
                  _loading ? "-" : "${_totalStudyMinutes}분",
                  Colors.orange,
                  Icons.trending_up,
                ),
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
                            PieChartSectionData(
                              value: _highFocusPct.toDouble(),
                              color: Colors.green,
                              title: '${_highFocusPct}%',
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              value: _midFocusPct.toDouble(),
                              color: Colors.orange,
                              title: '${_midFocusPct}%',
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              value: _lowFocusPct.toDouble(),
                              color: Colors.red,
                              title: '${_lowFocusPct}%',
                              radius: 60,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                          sectionsSpace: 3, centerSpaceRadius: 25,
                        )),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(children: [
                          _buildLegendItem(Colors.green, "고집중 (70+)", '${_highFocusPct}%'),
                          const SizedBox(height: 12),
                          _buildLegendItem(Colors.orange, "보통 (40~70)", '${_midFocusPct}%'),
                          const SizedBox(height: 12),
                          _buildLegendItem(Colors.red, "저집중 (40-)", '${_lowFocusPct}%'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PDF Page Focus Heatmap",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
                  const SizedBox(height: 6),
                  Text(
                    _pdfTotalPages > 0
                        ? "Average focus by page (total: $_pdfTotalPages pages)"
                        : "Average focus by page",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_pageFocus.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text("No page-level focus data yet.",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  else
                    Builder(
                      builder: (_) {
                        final byPage = {for (final p in _pageFocus) p.page: p.score};
                        final cells = <Widget>[];
                        if (_pdfTotalPages > 0) {
                          for (var p = 1; p <= _pdfTotalPages; p++) {
                            final score = byPage[p];
                            cells.add(score == null ? _emptyPageCell(p) : _pageCell(p, score));
                          }
                        } else {
                          for (final p in _pageFocus) {
                            cells.add(_pageCell(p.page, p.score));
                          }
                        }
                        return Wrap(spacing: 8, runSpacing: 8, children: cells);
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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
    final spots = _focusSpots.isEmpty ? const [FlSpot(0, 0)] : _focusSpots;
    final maxX = _maxMinute <= 0 ? 1.0 : _maxMinute.toDouble();
    final interval = maxX <= 10
      ? 2.0
      : (maxX <= 30 ? 5.0 : (maxX <= 60 ? 10.0 : 20.0));
    return LineChartData(
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.white,
          tooltipRoundedRadius: 8,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final minute = spot.x.round();
              final score = spot.y.round();
              return LineTooltipItem(
                '$minute분\n$score점',
                const TextStyle(color: Color(0xFF172B4D), fontSize: 12),
              );
            }).toList();
          },
        ),
      ),
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
          showTitles: true, reservedSize: 24, interval: interval,
          getTitlesWidget: (v, _) => Text("${v.toInt()}분", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minX: 0, maxX: maxX, minY: 0, maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots.where((s) => s.x <= maxX).toList(),
          isCurved: true,
          color: const Color(0xFF4C9EFF),
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF4C9EFF).withValues(alpha: 0.35), const Color(0xFF4C9EFF).withValues(alpha: 0.0)],
          )),
        ),
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

  Color _heatColor(int score) {
    if (score >= 70) return const Color(0xFF2ECC71);
    if (score >= 50) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  Widget _pageCell(int page, int score) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _heatColor(score).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$page', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          Text('$score', style: const TextStyle(color: Colors.white, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _emptyPageCell(int page) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text('$page', style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _Bucket {
  double totalValue = 0.0;
  double totalWeight = 0.0;

  void add(double value, double weight) {
    totalValue += value * weight;
    totalWeight += weight;
  }
}

class _SamplePoint {
  final int minute;
  final double value;
  final double weight;

  _SamplePoint(this.minute, this.value, this.weight);
}

class _PageFocus {
  final int page;
  final int score;

  const _PageFocus({required this.page, required this.score});
}
