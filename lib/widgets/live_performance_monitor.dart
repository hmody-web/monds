import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'performance/performance_process_stub.dart'
    if (dart.library.io) 'performance/performance_process_io.dart' as process_info;

/// Lightweight in-game diagnostic overlay.
///
/// It intentionally avoids platform plugins so it can stay available in debug,
/// profile and release builds. On native platforms it reports the process RSS;
/// frame timing is sampled from Flutter's scheduler and refreshed at 5 Hz.
class LivePerformanceMonitor extends StatefulWidget {
  const LivePerformanceMonitor({
    super.key,
    this.compactAlignment = Alignment.topRight,
    this.topOffset = 0,
    this.rightOffset = 8,
    this.leftOffset,
    this.label = 'الأداء',
  });

  final Alignment compactAlignment;
  final double topOffset;
  final double rightOffset;
  final double? leftOffset;
  final String label;

  @override
  State<LivePerformanceMonitor> createState() => _LivePerformanceMonitorState();
}

class _LivePerformanceMonitorState extends State<LivePerformanceMonitor> {
  bool _open = false;
  Timer? _refresh;
  final List<FrameTiming> _timings = <FrameTiming>[];
  int _framesSinceRefresh = 0;
  DateTime _lastRefresh = DateTime.now();

  double _fps = 0;
  double _buildMs = 0;
  double _rasterMs = 0;
  double _frameLoad = 0;
  double _ramMb = 0;
  double _peakRamMb = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    // Keep the monitor essentially free while its tiny button is closed.
    if (!_open) return;
    _timings.addAll(timings);
    _framesSinceRefresh += timings.length;
    if (_timings.length > 90) {
      _timings.removeRange(0, _timings.length - 90);
    }
  }

  void _setOpen(bool value) {
    if (_open == value) return;
    _refresh?.cancel();
    _refresh = null;
    _open = value;
    _framesSinceRefresh = 0;
    _lastRefresh = DateTime.now();
    if (value) {
      _timings.clear();
      _sample();
      _refresh = Timer.periodic(const Duration(milliseconds: 200), (_) => _sample());
    }
    if (mounted) setState(() {});
  }

  void _sample() {
    if (!mounted) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefresh).inMicroseconds / 1000000.0;
    if (elapsed > .02) {
      _fps = (_framesSinceRefresh / elapsed).clamp(0.0, 240.0).toDouble();
    }
    _framesSinceRefresh = 0;
    _lastRefresh = now;

    if (_timings.isNotEmpty) {
      var buildUs = 0;
      var rasterUs = 0;
      final take = math.min(30, _timings.length);
      for (final timing in _timings.skip(_timings.length - take)) {
        buildUs += timing.buildDuration.inMicroseconds;
        rasterUs += timing.rasterDuration.inMicroseconds;
      }
      _buildMs = buildUs / take / 1000.0;
      _rasterMs = rasterUs / take / 1000.0;
      // 16.67ms = a 60fps frame budget. This is not a CPU percentage; it is
      // the useful pressure signal for deciding whether UI/build or raster/GPU
      // work needs attention.
      _frameLoad = ((_buildMs + _rasterMs) / 16.67 * 100).clamp(0.0, 999.0).toDouble();
    }

    if (!kIsWeb) {
      _ramMb = process_info.currentRssBytes() / (1024 * 1024);
      _peakRamMb = process_info.maxRssBytes() / (1024 * 1024);
    }

    if (_open) setState(() {});
  }

  @override
  void dispose() {
    _refresh?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = View.of(context).viewPadding.top / View.of(context).devicePixelRatio;
    final top = topInset + widget.topOffset;

    return Positioned(
      top: top,
      right: widget.leftOffset == null ? widget.rightOffset : null,
      left: widget.leftOffset,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _open ? _panel() : _button(),
        ),
      ),
    );
  }

  Widget _button() {
    return InkWell(
      key: const ValueKey('perf_button'),
      onTap: () => _setOpen(true),
      customBorder: const CircleBorder(),
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xD90B111B),
          border: Border.all(color: const Color(0x44FFFFFF)),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.monitor_heart_rounded, size: 17, color: Color(0xFF7DE6A8)),
      ),
    );
  }

  Widget _panel() {
    final loadColor = _frameLoad > 100
        ? const Color(0xFFFF6961)
        : _frameLoad > 65
            ? const Color(0xFFFFC857)
            : const Color(0xFF78E6A2);
    return ClipRRect(
      key: const ValueKey('perf_panel'),
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 188,
          padding: const EdgeInsets.fromLTRB(11, 8, 9, 9),
          decoration: BoxDecoration(
            color: const Color(0xE60A1019),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  InkWell(
                    onTap: () => _setOpen(false),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _line('FPS', _fps.toStringAsFixed(0), const Color(0xFF8CC8FF)),
              _line('Build', '${_buildMs.toStringAsFixed(1)} ms', Colors.white70),
              _line('Raster', '${_rasterMs.toStringAsFixed(1)} ms', Colors.white70),
              _line('ضغط الإطار', '${_frameLoad.toStringAsFixed(0)}%', loadColor),
              if (!kIsWeb) ...[
                _line('RAM', '${_ramMb.toStringAsFixed(0)} MB', const Color(0xFFD6B6FF)),
                _line('Peak RAM', '${_peakRamMb.toStringAsFixed(0)} MB', const Color(0xFFBFA1E7)),
              ],
              const SizedBox(height: 3),
              const Text(
                'يتحدّث كل 0.2 ثانية',
                style: TextStyle(color: Colors.white38, fontSize: 8.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5))),
          Text(value, style: TextStyle(color: valueColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
