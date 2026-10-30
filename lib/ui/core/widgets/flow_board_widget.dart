import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flow/ui/core/theme/app_colors.dart';

class FlowBoardPainter extends CustomPainter {
  FlowBoardPainter({
    required this.gridSize,
    required this.dots,
    required this.paths,
    this.hintColor,
    this.isComplete = false,
    required this.surfaceColor,
    required this.borderColor,
    required this.gridColor,
    this.completionProgress = 0.0,
  });

  final int gridSize;
  final Map<int, List<int>> dots;
  final Map<int, List<int>> paths;
  final int? hintColor;
  final bool isComplete;
  final Color surfaceColor;
  final Color borderColor;
  final Color gridColor;
  final double completionProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16.0),
    );

    canvas.save();
    canvas.clipRRect(boardRect);

    final bgPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridLinePaint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < gridSize; i++) {
      final pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridLinePaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridLinePaint);
    }

    final dotMarkerPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = r * gridSize + c;
        final hasDot = dots.values.any((list) => list.contains(cell));
        final hasPipe = paths.values.any((p) => p.contains(cell));
        if (!hasDot && !hasPipe) {
          canvas.drawCircle(
            Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2),
            cellSize * 0.08,
            dotMarkerPaint,
          );
        }
      }
    }

    for (final entry in paths.entries) {
      final colorId = entry.key;
      final path = entry.value;
      if (path.length >= 2) {
        final color = FlowColors.getColor(colorId);
        final pipePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.40
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final pathObj = Path();
        final firstR = path.first ~/ gridSize;
        final firstC = path.first % gridSize;
        pathObj.moveTo(
          firstC * cellSize + cellSize / 2,
          firstR * cellSize + cellSize / 2,
        );

        for (int i = 1; i < path.length; i++) {
          final r = path[i] ~/ gridSize;
          final c = path[i] % gridSize;
          pathObj.lineTo(
            c * cellSize + cellSize / 2,
            r * cellSize + cellSize / 2,
          );
        }
        canvas.drawPath(pathObj, pipePaint);
      }
    }

    for (final entry in dots.entries) {
      final colorId = entry.key;
      final endpoints = entry.value;
      final color = FlowColors.getColor(colorId);
      final isConnected = paths.containsKey(colorId) &&
          paths[colorId]!.length >= 2 &&
          ((paths[colorId]!.first == endpoints[0] &&
                  paths[colorId]!.last == endpoints[1]) ||
              (paths[colorId]!.first == endpoints[1] &&
                  paths[colorId]!.last == endpoints[0]));

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final endpoint in endpoints) {
        final r = endpoint ~/ gridSize;
        final c = endpoint % gridSize;
        final center = Offset(
          c * cellSize + cellSize / 2,
          r * cellSize + cellSize / 2,
        );
        final radius = cellSize * 0.34;

        if (hintColor == colorId) {
          final pulsePaint = Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5;
          canvas.drawCircle(center, radius + 4, pulsePaint);
        }

        canvas.drawCircle(center, radius, dotPaint);

        if (isConnected) {
          final corePaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, radius * 0.35, corePaint);
        }
      }
    }

    if (isComplete && completionProgress > 0.0) {
      final waveFront = completionProgress * gridSize * 1.414;
      final centerR = gridSize / 2;
      final centerC = gridSize / 2;

      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          final dist = math.sqrt(
            (r - centerR) * (r - centerR) + (c - centerC) * (c - centerC),
          );
          final diff = (dist - waveFront).abs();
          if (diff < 1.2) {
            final intensity = (1.0 - diff / 1.2).clamp(0.0, 1.0) *
                (1.0 - completionProgress * 0.3).clamp(0.0, 1.0);
            final ripplePaint = Paint()
              ..color = GameColors.successGreen.withValues(
                alpha: 0.3 * intensity,
              )
              ..style = PaintingStyle.fill;
            canvas.drawRect(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
              ripplePaint,
            );
          }
        }
      }
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(boardRect, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FlowBoardPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
        oldDelegate.dots != dots ||
        oldDelegate.paths != paths ||
        oldDelegate.hintColor != hintColor ||
        oldDelegate.isComplete != isComplete ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.completionProgress != completionProgress;
  }
}

class FlowGameBoard extends StatefulWidget {
  const FlowGameBoard({
    super.key,
    required this.levelId,
    required this.gridSize,
    required this.dots,
    required this.paths,
    this.hintColor,
    this.isComplete = false,
    this.completionProgress = 0.0,
    required this.bgColor,
    required this.onMove,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final int levelId;
  final int gridSize;
  final Map<int, List<int>> dots;
  final Map<int, List<int>> paths;
  final int? hintColor;
  final bool isComplete;
  final double completionProgress;
  final Color bgColor;
  final void Function(int cell)? onMove;
  final void Function(int cell)? onDragStart;
  final VoidCallback? onDragEnd;

  @override
  State<FlowGameBoard> createState() => _FlowGameBoardState();
}

class _FlowGameBoardState extends State<FlowGameBoard> {
  int? _cellFromOffset(Offset pos, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final cellSize = size.width / widget.gridSize;
    final c = (pos.dx / cellSize).floor();
    final r = (pos.dy / cellSize).floor();
    if (r < 0 || r >= widget.gridSize || c < 0 || c >= widget.gridSize) {
      return null;
    }
    return r * widget.gridSize + c;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.isComplete
              ? null
              : (details) {
                  final cell = _cellFromOffset(details.localPosition, size);
                  if (cell != null) {
                    widget.onDragStart?.call(cell);
                  }
                },
          onPanUpdate: widget.isComplete
              ? null
              : (details) {
                  final cell = _cellFromOffset(details.localPosition, size);
                  if (cell != null) {
                    widget.onMove?.call(cell);
                  }
                },
          onPanEnd: widget.isComplete
              ? null
              : (_) {
                  widget.onDragEnd?.call();
                },
          onPanCancel: widget.isComplete
              ? null
              : () {
                  widget.onDragEnd?.call();
                },
          child: CustomPaint(
            size: size,
            painter: FlowBoardPainter(
              gridSize: widget.gridSize,
              dots: widget.dots,
              paths: widget.paths,
              hintColor: widget.hintColor,
              isComplete: widget.isComplete,
              surfaceColor: widget.bgColor,
              borderColor: AppColors.border,
              gridColor: AppColors.gridLines,
              completionProgress: widget.completionProgress,
            ),
          ),
        );
      },
    );
  }
}

class VictoryShockwavePainter extends CustomPainter {
  VictoryShockwavePainter({
    required this.progress,
    required this.gridSize,
    required this.sourceRow,
    required this.sourceCol,
    required this.waveColor,
  });

  final double progress;
  final int gridSize;
  final int sourceRow;
  final int sourceCol;
  final Color waveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final maxRadius = size.width * 0.85;
    final radius = progress * maxRadius;
    final strokeWidth = (1.0 - progress) * 12.0 + 2.0;
    final alpha = ((1.0 - progress) * 0.6).clamp(0.0, 1.0);

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = waveColor.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant VictoryShockwavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
