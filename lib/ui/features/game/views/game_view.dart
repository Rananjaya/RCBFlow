import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flow/ui/core/theme/app_colors.dart';
import 'package:flow/ui/core/widgets/flow_board_widget.dart';
import 'package:flow/ui/core/widgets/tangible_button.dart';
import 'package:flow/ui/features/game/view_models/game_view_model.dart';
import 'package:flow/ui/providers.dart';

class GameView extends ConsumerStatefulWidget {
  const GameView({
    super.key,
    required this.levelNumber,
    this.isRandom = false,
    this.randomDifficulty = 'Easy',
  });

  final int levelNumber;
  final bool isRandom;
  final String randomDifficulty;

  @override
  ConsumerState<GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<GameView>
    with TickerProviderStateMixin {
  late AnimationController _shockwaveController;

  @override
  void initState() {
    super.initState();
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.microtask(() {
      if (!mounted) return;
      if (widget.isRandom) {
        ref
            .read(gameViewModelProvider.notifier)
            .loadRandomLevel(widget.randomDifficulty);
      } else {
        ref.read(gameViewModelProvider.notifier).loadLevel(widget.levelNumber);
      }
    });
  }

  @override
  void dispose() {
    _shockwaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final state = ref.watch(gameViewModelProvider);
    AppColors.currentTheme = settings.theme;

    ref.listen<GameViewModelState>(gameViewModelProvider, (prev, next) {
      if (next.isComplete && !(prev?.isComplete ?? false)) {
        _onLevelComplete(next);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        iconSize: 18,
                        onTap: () => Navigator.pop(context),
                      ),
                      Text(
                        state.isRandomMode
                            ? (state.randomDifficulty ??
                                widget.randomDifficulty)
                            : 'Level ${widget.levelNumber}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.headingDark,
                        ),
                      ),
                      _circleButton(
                        icon: Icons.refresh_rounded,
                        iconSize: 20,
                        onTap: () => ref
                            .read(gameViewModelProvider.notifier)
                            .resetLevel(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: (state.isLoading ||
                          (!state.isRandomMode &&
                              (state.level == null ||
                                  state.level!.levelNumber !=
                                      widget.levelNumber)))
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => ref
                                        .read(gameViewModelProvider.notifier)
                                        .resetLevel(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _buildGame(state),
                ),
              ],
            ),
            ConfettiExplosion(trigger: state.isComplete),
          ],
        ),
      ),
    );
  }

  Widget _buildGame(GameViewModelState state) {
    final settings = ref.watch(settingsProvider);
    final level = state.level;
    if (level == null) return const SizedBox.shrink();
    if (!state.isRandomMode && level.levelNumber != widget.levelNumber) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('Moves', '${state.moveCount}', Icons.trending_up_rounded),
              _verticalDivider(),
              _stat(
                'Time',
                _formatTime(state.elapsedSeconds),
                Icons.timer_outlined,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: AnimatedBuilder(
                  animation: _shockwaveController,
                  builder: (context, _) {
                    final curvedProgress = _shockwaveController.value > 0.0
                        ? const Cubic(
                            0.34,
                            1.56,
                            0.64,
                            1.0,
                          ).transform(_shockwaveController.value)
                        : 0.0;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        FlowGameBoard(
                          key: ValueKey(
                            'board_${state.isRandomMode ? (state.randomSeed ?? 0) : level.levelNumber}',
                          ),
                          levelId: state.isRandomMode
                              ? (state.randomSeed ?? 0)
                              : level.levelNumber,
                          gridSize: level.gridSize,
                          dots: level.dots,
                          paths: state.paths,
                          hintColor: state.hintColor,
                          isComplete: state.isComplete,
                          completionProgress: curvedProgress,
                          bgColor: AppColors.surface,
                          onDragStart: state.isComplete
                              ? null
                              : (cell) {
                                  ref
                                      .read(gameViewModelProvider.notifier)
                                      .startDrag(cell);
                                },
                          onMove: state.isComplete
                              ? null
                              : (cell) {
                                  ref
                                      .read(gameViewModelProvider.notifier)
                                      .dragStep(cell);
                                },
                          onDragEnd: state.isComplete
                              ? null
                              : () {
                                  ref
                                      .read(gameViewModelProvider.notifier)
                                      .endDrag();
                                },
                        ),
                        if (_shockwaveController.value > 0.0 &&
                            _shockwaveController.value < 1.0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: VictoryShockwavePainter(
                                  progress: curvedProgress,
                                  gridSize: level.gridSize,
                                  sourceRow: level.gridSize ~/ 2,
                                  sourceCol: level.gridSize ~/ 2,
                                  waveColor: GameColors.successGreen,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (state.isComplete)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 24 * (1.0 - value)),
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: _buildCompletionBottomBar(state),
          )
        else ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionButton(
                icon: Icons.undo_rounded,
                label: 'Undo',
                onTap: state.history.isNotEmpty
                    ? () => ref.read(gameViewModelProvider.notifier).undo()
                    : null,
              ),
              const SizedBox(width: 12),
              _actionButton(
                icon: Icons.refresh_rounded,
                label: 'Clear',
                onTap: state.paths.isNotEmpty
                    ? () =>
                        ref.read(gameViewModelProvider.notifier).clearBoard()
                    : null,
              ),
              if (settings.isHintEnabled) ...[
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.lightbulb_rounded,
                  label: 'Hint',
                  iconColor: const Color(0xFFFFCC00),
                  onTap: () =>
                      ref.read(gameViewModelProvider.notifier).revealHint(),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Connect matching colors with pipes to fill the whole grid',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.subtext),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.currentTheme.isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : AppColors.headingDark.withValues(alpha: 0.06),
                offset: const Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor ?? AppColors.headingDark, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.currentTheme.isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : AppColors.headingDark.withValues(alpha: 0.08),
                offset: const Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: AppColors.headingDark),
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.headingDark),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.headingDark,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.subtext,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 32, color: AppColors.gridLines);
  }

  Future<void> _onLevelComplete(GameViewModelState state) async {
    _shockwaveController.forward(from: 0.0);
    HapticFeedback.heavyImpact();
    await ref.read(gameViewModelProvider.notifier).completeLevel();
  }

  Widget _buildCompletionBottomBar(GameViewModelState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Congratulations!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 10),
          TangibleButton(
            text: state.isRandomMode ? 'Play Again' : 'Next Level',
            height: 42,
            backgroundColor: GameColors.successGreen,
            textColor: Colors.white,
            borderColor: GameColors.successGreen,
            onPressed: () {
              final notifier = ref.read(gameViewModelProvider.notifier);
              if (state.isRandomMode) {
                notifier.loadRandomLevel(state.randomDifficulty ?? 'Easy');
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GameView(levelNumber: widget.levelNumber + 1),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          TangibleButton(
            text: 'Home',
            isSecondary: true,
            height: 42,
            backgroundColor: AppColors.surface,
            textColor: AppColors.headingDark,
            borderColor: AppColors.border,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  bool isCircle;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.isCircle,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 300.0 * dt;
    vx *= math.pow(0.98, dt * 60);
    vy *= math.pow(0.98, dt * 60);
    rotation += rotationSpeed * dt;
  }
}

class ConfettiExplosion extends StatefulWidget {
  const ConfettiExplosion({super.key, required this.trigger});

  final bool trigger;

  @override
  State<ConfettiExplosion> createState() => _ConfettiExplosionState();
}

class _ConfettiExplosionState extends State<ConfettiExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _rng = math.Random();

  final List<Color> _colors = const [
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _controller.addListener(() {
      final dt = 1.0 / 60.0;
      for (final p in _particles) {
        p.update(dt);
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ConfettiExplosion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _spawnParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _spawnParticles() {
    _particles.clear();
    const count = 50;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (_rng.nextDouble() - 0.5) * 0.5;
      final speed = 180.0 + _rng.nextDouble() * 260.0;
      final color = _colors[_rng.nextInt(_colors.length)];

      _particles.add(
        ConfettiParticle(
          x: 0,
          y: 0,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 120.0,
          size: 6.0 + _rng.nextDouble() * 5.0,
          rotation: _rng.nextDouble() * 2 * math.pi,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 8.0,
          color: color,
          isCircle: _rng.nextBool(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    final opacity = (1.0 - _controller.value).clamp(0.0, 1.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: CustomPaint(
            painter: _ConfettiPainter(particles: _particles),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.particles});

  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(cx + p.x, cy + p.y);
      canvas.rotate(p.rotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
