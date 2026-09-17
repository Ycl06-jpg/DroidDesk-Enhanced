import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:droiddesk/theme/droid_theme.dart';
import 'package:droiddesk/state/app_state.dart';
import 'package:droiddesk/screens/home_screen.dart';

/// Setup progress screen — step 3 of setup wizard.
/// Shows download, extraction, and configuration progress.
class SetupProgressScreen extends StatefulWidget {
  const SetupProgressScreen({super.key});

  @override
  State<SetupProgressScreen> createState() => _SetupProgressScreenState();
}

class _SetupProgressScreenState extends State<SetupProgressScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSetup();
    });
  }

  Future<void> _startSetup() async {
    if (_started) return;
    _started = true;
    final state = context.read<AppState>();

    final freeStorage = (state.deviceInfo['availableStorageMB'] as num?)
        ?.toInt();
    if (freeStorage != null && freeStorage < 2048) {
      final continueAnyway =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(
                Icons.storage_rounded,
                color: DroidTheme.warning,
                size: 38,
              ),
              title: const Text('Depolama Alanı Az'),
              content: Text(
                'Yalnızca $freeStorage MB kullanılabilir. Masaüstü Temelleri en iyi en az 2 GB boş alanla çalışır. Devam edebilirsiniz, ancak paket kurulumu başarısız olabilir.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Geri dön'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Yine de devam et'),
                ),
              ],
            ),
          ) ??
          false;
      if (!continueAnyway) {
        _started = false;
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
    }

    final rooted = await state.detectRootForSetup();
    if (!mounted) return;

    var useRoot = false;
    if (rooted) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(
                Icons.admin_panel_settings_rounded,
                color: DroidTheme.accent,
                size: 38,
              ),
              title: const Text('Root erişimi tespit edildi'),
              content: const Text(
                'Cihazınız root\'lu. En iyi performans ve tam Linux desteği için '
                'root\'lu chroot çalışma zamanıyla devam edilsin mi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Root ile devam et'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        _started = false;
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      useRoot = true;
    }

    if (!mounted) return;
    state.runSetup(useRoot: useRoot);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Determine overall phase
    final phase = _getPhase(state);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: DroidTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => state.toggleThemeMode(),
                    tooltip: state.isDarkMode
                        ? 'Açık Temaya Geç'
                        : 'Koyu Temaya Geç',
                    icon: Icon(
                      state.isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: DroidTheme.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                const Spacer(flex: 1),

                // ── Circular Progress ──
                CircularPercentIndicator(
                      radius: 80,
                      lineWidth: 6,
                      percent: phase.progress.clamp(0.0, 1.0),
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            phase.icon,
                            size: 36,
                            color: phase.error
                                ? DroidTheme.error
                                : DroidTheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(phase.progress * 100).toInt()}%',
                            style: DroidTheme.headingSm.copyWith(
                              color: phase.error
                                  ? DroidTheme.error
                                  : DroidTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      progressColor: phase.error
                          ? DroidTheme.error
                          : DroidTheme.primary,
                      backgroundColor: DroidTheme.surfaceBorder,
                      circularStrokeCap: CircularStrokeCap.round,
                      animateFromLastPercent: true,
                      animation: true,
                      animationDuration: 500,
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    )
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 32),

                // ── Phase Title ──
                Text(
                  phase.title,
                  style: DroidTheme.headingLg,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 12),

                // ── Status Message ──
                Text(
                  phase.message,
                  style: DroidTheme.bodyMd.copyWith(
                    color: phase.error
                        ? DroidTheme.error
                        : DroidTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: 48),

                // ── Steps Checklist ──
                _buildChecklist(state),

                if (state.setupLog.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildInstallLog(state.setupLog),
                ],

                const Spacer(flex: 1),

                // ── Action Buttons ──
                if (phase.error) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        state.clearError();
                        _started = false;
                        _startSetup();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DroidTheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Tekrar Dene'),
                    ),
                  ),
                ] else if (phase.complete) ...[
                  SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DroidTheme.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('DroidDesk\'i Başlat'),
                              SizedBox(width: 8),
                              Icon(Icons.rocket_launch_rounded, size: 20),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                ],

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklist(AppState state) {
    final isChroot = state.hasRoot;
    if (!isChroot) {
      final progress = state.extractProgress;
      return _checklistColumn([
        _ChecklistItem(
          label: 'Ortam hazırlanıyor',
          done: progress >= 0.08,
          active: progress < 0.08,
          progress: progress < 0.08 ? progress / 0.08 : null,
        ),
        _ChecklistItem(
          label: 'Paket depoları yapılandırılıyor',
          done: progress >= 0.24,
          active: progress >= 0.08 && progress < 0.24,
        ),
        _ChecklistItem(
          label: 'Masaüstü Temelleri kuruluyor',
          done: progress >= 0.70,
          active: progress >= 0.24 && progress < 0.70,
        ),
        _ChecklistItem(
          label: 'Masaüstü Temelleri tamamlanıyor',
          done: state.isSetupComplete,
          active: progress >= 0.70 && !state.isSetupComplete,
        ),
      ]);
    }

    final steps = [
      _ChecklistItem(
        label: isChroot ? 'Root erişimi onaylandı' : 'Ortam hazırlanıyor',
        done:
            state.hasRoot ||
            (!state.isDownloading && state.downloadProgress == 0),
        active: false,
      ),
      _ChecklistItem(
        label: isChroot ? 'Ubuntu kök dosya sistemi indiriliyor' : 'Yerel paketler kuruluyor',
        done: state.downloadProgress >= 1.0,
        active: state.isDownloading,
        progress: state.isDownloading ? state.downloadProgress : null,
      ),
      _ChecklistItem(
        label: isChroot ? 'Kök dosya sistemi çıkarılıyor' : 'Masaüstü yapılandırılıyor',
        done: state.extractProgress >= 1.0,
        active: state.isExtracting,
        progress: state.isExtracting ? state.extractProgress : null,
      ),
      _ChecklistItem(
        label: 'Linux yapılandırılıyor',
        done: state.isSetupComplete,
        active: state.extractProgress >= 1.0 && !state.isSetupComplete,
      ),
    ];

    return _checklistColumn(steps);
  }

  Widget _buildInstallLog(String log) {
    final cleanLog = log.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080D18),
        border: Border.all(color: DroidTheme.surfaceBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          cleanLog,
          style: DroidTheme.monoSm.copyWith(
            color: DroidTheme.textSecondary,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _checklistColumn(List<_ChecklistItem> steps) {
    return Column(
      children: steps
          .asMap()
          .entries
          .map((entry) {
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Status icon
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: item.done
                        ? Icon(
                            Icons.check_circle,
                            color: DroidTheme.accent,
                            size: 20,
                          )
                        : item.active
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DroidTheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.circle_outlined,
                            color: DroidTheme.textDim,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: DroidTheme.bodyMd.copyWith(
                        color: item.done
                            ? DroidTheme.textPrimary
                            : item.active
                            ? DroidTheme.textSecondary
                            : DroidTheme.textDim,
                      ),
                    ),
                  ),
                  if (item.progress != null)
                    Text(
                      '${(item.progress! * 100).toInt()}%',
                      style: DroidTheme.monoSm.copyWith(
                        color: DroidTheme.primary,
                      ),
                    ),
                ],
              ),
            );
          })
          .toList()
          .animate(interval: 100.ms)
          .fadeIn(delay: 400.ms, duration: 300.ms)
          .slideX(begin: -0.05, duration: 300.ms),
    );
  }

  _PhaseInfo _getPhase(AppState state) {
    if (state.errorMessage != null) {
      return _PhaseInfo(
        title: 'Kurulum Başarısız',
        message: state.errorMessage!,
        progress: 0,
        icon: Icons.error_outline_rounded,
        error: true,
        complete: false,
      );
    }

    if (state.isDownloading) {
      return _PhaseInfo(
        title: 'İndiriliyor',
        message: state.downloadStatus.isNotEmpty
            ? state.downloadStatus
            : 'İndirme hazırlanıyor...',
        progress: state.downloadProgress * 0.5, // 0–50% of total
        icon: Icons.cloud_download_rounded,
        error: false,
        complete: false,
      );
    }

    if (state.isExtracting || state.isInstallingDE) {
      if (!state.hasRoot) {
        return _PhaseInfo(
          title: state.extractProgress < 0.08
              ? 'Çalışma Zamanı Hazırlanıyor'
              : 'Yerel Linux Kuruluyor',
          message: state.extractStatus.isNotEmpty
              ? state.extractStatus
              : 'Yerel Termux ortamı hazırlanıyor...',
          progress: state.extractProgress,
          icon: state.extractProgress < 0.08
              ? Icons.inventory_2_rounded
              : Icons.terminal_rounded,
          error: false,
          complete: false,
        );
      }
      return _PhaseInfo(
        title: state.isInstallingDE ? 'Masaüstü Kuruluyor' : 'Çıkarılıyor',
        message: state.extractStatus.isNotEmpty
            ? state.extractStatus
            : 'Dosya sistemi çıkarılıyor...',
        progress: 0.5 + state.extractProgress * 0.4, // 50–90% of total
        icon: state.isInstallingDE
            ? Icons.desktop_windows_rounded
            : Icons.unarchive_rounded,
        error: false,
        complete: false,
      );
    }

    if (state.isSetupComplete) {
      return _PhaseInfo(
        title: 'Kurulum Tamamlandı!',
        message: 'Linux masaüstünüz başlatılmaya hazır.',
        progress: 1.0,
        icon: Icons.check_circle_rounded,
        error: false,
        complete: true,
      );
    }

    // Default: not started yet
    return _PhaseInfo(
      title: 'Kuruluyor',
      message: 'Başlatılıyor...',
      progress: 0,
      icon: Icons.settings_rounded,
      error: false,
      complete: false,
    );
  }
}

class _PhaseInfo {
  final String title;
  final String message;
  final double progress;
  final IconData icon;
  final bool error;
  final bool complete;

  _PhaseInfo({
    required this.title,
    required this.message,
    required this.progress,
    required this.icon,
    required this.error,
    required this.complete,
  });
}

class _ChecklistItem {
  final String label;
  final bool done;
  final bool active;
  final double? progress;

  _ChecklistItem({
    required this.label,
    required this.done,
    required this.active,
    this.progress,
  });
}
