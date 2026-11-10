import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flow/ui/core/theme/app_colors.dart';
import 'package:flow/ui/core/widgets/tangible_button.dart';
import 'package:flow/ui/features/game/views/game_view.dart';
import 'package:flow/ui/features/how_to_play/views/how_to_play_view.dart';
import 'package:flow/ui/features/level_select/views/level_select_view.dart';
import 'package:flow/ui/features/settings/views/settings_view.dart';
import 'package:flow/ui/providers.dart';
import 'package:flow/data/services/app_haptics.dart';

/// Official RCBFlow logo shown on the home screen (transparent-background copy
/// of assets/branding/rcbflow_icon.png).
const String homeLogoAsset = 'assets/branding/rcbflow_logo_transparent.png';

/// Opened by the star button on the home screen.
const String rcbflowRepositoryUrl = 'https://github.com/Rananjaya/RCBFlow';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  static const double _fixedContentHeight = 500;
  static const double _minLogoSize = 56;
  static const double _maxLogoSize = 168;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(homeViewModelProvider.notifier).loadProgress(),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _circleButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    Color? iconColor,
  }) {
    return GestureDetector(
      key: key,
      onTap: () {
        AppHaptics.selectionClick();
        onTap();
      },
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
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? AppColors.headingDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final state = ref.watch(homeViewModelProvider);
    AppColors.currentTheme = settings.theme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The logo takes most of the height left over after the fixed
            // content (top bar, title, buttons, version: ~500 logical px), so
            // the screen fits small phones without overflow. Scrolling is only
            // a fallback for unusually short viewports (landscape, split
            // screen, very large font scaling).
            final logoSize =
                ((constraints.maxHeight - _fixedContentHeight) * 0.6)
                    .clamp(_minLogoSize, _maxLogoSize)
                    .toDouble();
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _circleButton(
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFFF9800),
                              onTap: () => _launchUrl(rcbflowRepositoryUrl),
                            ),
                            if (state.progress != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  'Level ${state.progress!.currentLevel}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.headingDark,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            _circleButton(
                              key: const Key('home_heart_button'),
                              icon: Icons.favorite_rounded,
                              iconColor: const Color(0xFFEF4444),
                              // Decorative only: keeps the original look and
                              // tap feedback but opens nothing.
                              onTap: () {},
                            ),
                          ],
                        ),
                        const Spacer(flex: 3),
                        Image.asset(
                          homeLogoAsset,
                          key: const Key('home_logo'),
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          cacheWidth:
                              (logoSize *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          semanticLabel: 'RCBFlow logo',
                        ),
                        const SizedBox(height: 12),
                        // Original title style; only scales down if a very
                        // narrow screen cannot fit it on one line.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'RCBFlow',
                            key: const Key('home_title'),
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6.0,
                              color: AppColors.headingDark,
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        TangibleButton(
                          text: 'Play',
                          onPressed: state.isLoading
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GameView(
                                        levelNumber:
                                            state.progress?.currentLevel ?? 1,
                                      ),
                                    ),
                                  );
                                  ref
                                      .read(homeViewModelProvider.notifier)
                                      .loadProgress();
                                },
                        ),
                        const SizedBox(height: 16),
                        TangibleButton(
                          text: 'Levels',
                          isSecondary: true,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LevelSelectView(),
                              ),
                            );
                            ref
                                .read(homeViewModelProvider.notifier)
                                .loadProgress();
                          },
                        ),
                        const SizedBox(height: 16),
                        TangibleButton(
                          text: 'Random',
                          isSecondary: true,
                          onPressed: () => _showDifficultyDialog(context),
                        ),
                        const SizedBox(height: 16),
                        TangibleButton(
                          text: 'How to Play',
                          isSecondary: true,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HowToPlayView(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TangibleButton(
                          text: 'Settings',
                          isSecondary: true,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsView(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildVersionLabel(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Subtle version line under Settings, e.g. "Version 1.0.0 (1)".
  ///
  /// The value comes from the platform (pubspec.yaml `version:` via Gradle),
  /// never from a hardcoded string. Height is reserved while loading so the
  /// layout does not shift.
  Widget _buildVersionLabel() {
    final version = ref.watch(appVersionProvider);
    return SizedBox(
      height: 16,
      child: Text(
        version.maybeWhen(data: (v) => v.label, orElse: () => ''),
        key: const Key('home_version'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: AppColors.subtext,
        ),
      ),
    );
  }

  void _showDifficultyDialog(BuildContext context) {
    final stages = ['Easy', 'Medium', 'Hard', 'Expert', 'Master'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Choose Difficulty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.headingDark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Play a dynamically generated Flow puzzle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.subtext),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: stages.map((stage) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TangibleButton(
                          text: stage,
                          height: 48,
                          isSecondary: true,
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameView(
                                  levelNumber: 1,
                                  isRandom: true,
                                  randomDifficulty: stage,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TangibleButton(
                text: 'Cancel',
                height: 44,
                isSecondary: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
