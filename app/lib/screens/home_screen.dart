import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:droiddesk/theme/droid_theme.dart';
import 'package:droiddesk/state/app_state.dart';
import 'package:droiddesk/services/platform_bridge.dart';
import 'package:droiddesk/screens/setup/de_install_screen.dart';
import 'package:droiddesk/screens/apps/app_catalog_screen.dart';
import 'package:droiddesk/screens/desktop_tools_screen.dart';

/// Home dashboard — shown after setup is complete.
/// Central hub for launching the desktop, terminal, and managing the environment.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDarkMode;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: Container(
        decoration: BoxDecoration(
          gradient: DroidTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/icons/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DroidDesk', style: DroidTheme.headingSm),
                          Text(
                            state.isRunning ? 'Masaüstü Çalışıyor' : 'Hazır',
                            style: DroidTheme.bodySm.copyWith(
                              color: state.isRunning
                                  ? DroidTheme.accent
                                  : DroidTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => state.toggleThemeMode(),
                        tooltip: state.isDarkMode
                            ? 'Açık Temaya Geç'
                            : 'Koyu Temaya Geç',
                        icon: Icon(
                          state.isDarkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: DroidTheme.textMuted,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showSettings(context),
                        icon: Icon(
                          Icons.settings_rounded,
                          color: DroidTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Status Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _buildStatusCard(state)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.05, duration: 500.ms),
                ),
              ),

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text(
                    'HIZLI İŞLEMLER',
                    style: DroidTheme.label,
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    children: [
                      // Installation is only actionable when setup is missing.
                      // Do not show an "Installed" card that can reinstall the DE.
                      if (!state.isDEInstalled) ...[
                        _ActionCard(
                          icon: Icons.download_rounded,
                          title: '${state.selectedDE.toUpperCase()} Kur',
                          subtitle:
                              'Masaüstü ortamı paketlerini kur (tek seferlik kurulum)',
                          color: DroidTheme.secondary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DEInstallScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      // ── Launch Desktop / Reconnect ──
                      if (state.isRunning)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActionCard(
                            icon: Icons.fullscreen_rounded,
                            title: 'Masaüstüne Dön',
                            subtitle:
                                '${state.selectedDE.toUpperCase()} şu anda arka planda çalışıyor',
                            color: DroidTheme.primary,
                            gradient: DroidTheme.primaryGradient,
                            onTap: () {
                              state.launchDesktopActivity();
                            },
                          ),
                        ),

                      _ActionCard(
                        icon: state.isRunning
                            ? Icons.stop_circle_rounded
                            : Icons.desktop_mac_rounded,
                        title: state.isRunning
                            ? 'Sunucuyu Durdur'
                            : 'Masaüstünü Başlat',
                        subtitle: state.isRunning
                            ? 'Linux ortamını kapat'
                            : '${state.selectedDE.toUpperCase()} masaüstü ortamını başlat',
                        color: state.isRunning
                            ? DroidTheme.error
                            : DroidTheme.primary,
                        gradient: state.isRunning
                            ? null
                            : DroidTheme.primaryGradient,
                        onTap: () async {
                          if (state.isRunning) {
                            state.stopLinux();
                          } else {
                            if (!state.isDEInstalled) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Kurulu bir Masaüstü Ortamı yok. Lütfen önce kurulumu tamamlayın.',
                                  ),
                                  backgroundColor: DroidTheme.error,
                                ),
                              );
                              return;
                            }
                            await state.startLinux(mode: 'x11');
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      // ── Terminal ──
                      _ActionCard(
                        icon: Icons.terminal_rounded,
                        title: 'Terminal',
                        subtitle:
                            'Linux kabuğunu ${state.hasRoot ? 'Ubuntu chroot' : 'yerel Termux'} ortamında aç',
                        color: DroidTheme.secondary,
                        onTap: () {
                          state.useNativeTerminal();
                          _showTerminal(context, state);
                        },
                      ),

                      if (!state.hasRoot &&
                          state.optionalApps['proot_debian'] == true) ...[
                        const SizedBox(height: 10),
                        _ActionCard(
                          icon: Icons.inventory_2_rounded,
                          title: 'Debian kabuğu',
                          subtitle:
                              'İsteğe bağlı minimal PRoot uyumluluk ortamını aç',
                          color: const Color(0xFFD70A53),
                          onTap: () => _showDebianTerminal(context, state),
                        ),
                      ],

                      const SizedBox(height: 10),

                      _ActionCard(
                        icon: Icons.apps_rounded,
                        title: 'Uygulama ekle',
                        subtitle:
                            'Uygulama kur veya isteğe bağlı Debian uyumluluğu ekle',
                        color: DroidTheme.primaryLight,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AppCatalogScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                    ].animate(interval: 80.ms).fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),
                  ),
                ),
              ),

              // ── System Info ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Text(
                    'SİSTEM',
                    style: DroidTheme.label,
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DroidTheme.cardBg,
                      borderRadius: BorderRadius.circular(DroidTheme.radiusMd),
                      border: Border.all(color: DroidTheme.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          'Dağıtım',
                          _distroLabel(state.installedDistro),
                        ),
                        _divider(),
                        _infoRow('Masaüstü', state.selectedDE.toUpperCase()),
                        _divider(),
                        _infoRow('GPU', state.gpuType),
                        _divider(),
                        _infoRow(
                          'İşleyici',
                          state.deviceInfo['graphicsMode']?.toString() ??
                              'Otomatik',
                        ),
                        _divider(),
                        _infoRow(
                          'Cihaz',
                          '${state.deviceInfo['brand'] ?? ''} ${state.deviceInfo['model'] ?? ''}',
                        ),
                        _divider(),
                        _infoRow(
                          'Android',
                          '${state.deviceInfo['androidVersion'] ?? ''} (SDK ${state.deviceInfo['sdkVersion'] ?? ''})',
                        ),
                        _divider(),
                        _infoRow(
                          'RAM',
                          '${state.deviceInfo['totalRamMB'] ?? 'N/A'} MB',
                        ),
                        _divider(),
                        _infoRow(
                          'Boş Depolama',
                          '${state.deviceInfo['availableStorageMB'] ?? 'N/A'} MB',
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ── Status Card ──

  Widget _buildStatusCard(AppState state) {
    final isDark = DroidTheme.isDark;

    final activeGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0D2818), Color(0xFF0A1F14)],
          )
        : const LinearGradient(
            colors: [Color(0xFFECFDF5), Color(0xFFE6F4EA)],
          );

    final activeBorderColor = isDark
        ? DroidTheme.accent.withValues(alpha: 0.3)
        : const Color(0xFFA7F3D0);

    final activeTitleColor = isDark
        ? DroidTheme.accent
        : const Color(0xFF047857);

    final activeSubtitleColor = isDark
        ? const Color(0xFFA7F3D0)
        : const Color(0xFF065F46);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: state.isRunning ? activeGradient : DroidTheme.cardGradient,
        borderRadius: BorderRadius.circular(DroidTheme.radiusLg),
        border: Border.all(
          color: state.isRunning ? activeBorderColor : DroidTheme.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isRunning
                  ? (isDark ? DroidTheme.accent : const Color(0xFF10B981))
                  : DroidTheme.textDim,
              boxShadow: state.isRunning
                  ? [
                      BoxShadow(
                        color: DroidTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.isRunning ? 'Masaüstü Aktif' : 'Masaüstü Boşta',
                  style: DroidTheme.headingSm.copyWith(
                    color: state.isRunning
                        ? activeTitleColor
                        : DroidTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.isRunning
                      ? '${state.selectedDE.toUpperCase()} · ${_distroLabel(state.installedDistro)}'
                      : '"Masaüstünü Başlat"a dokunarak başlatın',
                  style: DroidTheme.bodySm.copyWith(
                    color: state.isRunning
                        ? activeSubtitleColor
                        : DroidTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: DroidTheme.bodySm),
          const Spacer(),
          Text(
            value,
            style: DroidTheme.monoSm.copyWith(color: DroidTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      color: DroidTheme.surfaceBorder.withValues(alpha: 0.5),
    );
  }

  String _distroLabel(String distro) {
    switch (distro) {
      case 'ubuntu-chroot':
        return 'Ubuntu 24.04 (chroot)';
      case 'ubuntu':
        return 'Ubuntu 24.04';
      case 'alpine':
        return 'Alpine Linux 3.20';
      case 'kali':
        return 'Kali Linux';
      case 'termux-native':
        return 'Termux Native';
      default:
        return distro;
    }
  }

  // ── Dialogs ──

  void _showSettings(BuildContext pageContext) {
    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer<AppState>(
        builder: (context, state, _) {
          return Container(
            decoration: BoxDecoration(
              color: DroidTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: DroidTheme.surfaceBorder),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(sheetContext).padding.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ayarlar', style: DroidTheme.headingLg),
                  const SizedBox(height: 20),

                  // App Theme Section
                  Row(
                    children: [
                      Icon(
                        state.isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: DroidTheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uygulama Teması', style: DroidTheme.headingSm),
                          Text(
                            state.themeMode == ThemeMode.system
                                ? 'Sistem Varsayılanı'
                                : state.isDarkMode
                                    ? 'Koyu Tema'
                                    : 'Açık Tema',
                            style: DroidTheme.bodySm,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Koyu'),
                          icon: Icon(Icons.dark_mode_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Açık'),
                          icon: Icon(Icons.light_mode_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Sistem'),
                          icon: Icon(Icons.brightness_auto_outlined, size: 16),
                        ),
                      ],
                      selected: {state.themeMode},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        state.setThemeMode(selection.first);
                      },
                    ),
                  ),
                  const Divider(height: 28),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.battery_charging_full,
                      color: DroidTheme.warning,
                    ),
                    title: const Text('Pil Optimizasyonu'),
                    subtitle: const Text('Oturumun sonlandırılmasını önlemek için kapatın'),
                    onTap: () {
                      DroidDeskPlatform.requestBatteryOptimization();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.home_rounded,
                      color: DroidTheme.primaryLight,
                    ),
                    title: const Text('Varsayılan başlatıcı olarak ayarla'),
                    subtitle: const Text(
                      'Telefon açıldığında Linux masaüstünü aç',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      DroidDeskPlatform.requestDefaultLauncher();
                    },
                  ),
                  FutureBuilder<bool>(
                    future: DroidDeskPlatform.isDefaultLauncher(),
                    builder: (_, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.home_outlined,
                          color: DroidTheme.error,
                        ),
                        title: const Text('Varsayılan başlatıcı olarak kullanmayı durdur'),
                        subtitle: const Text('Doğrudan başka bir Ana Ekran uygulaması seç'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _confirmUnsetLauncher(pageContext);
                        },
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.auto_awesome_rounded,
                      color: DroidTheme.accent,
                    ),
                    title: const Text('Masaüstü Araçları'),
                    subtitle: const Text('Dock uygulamalarını ve masaüstü yedeklerini yönet'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(pageContext).push(
                        MaterialPageRoute(builder: (_) => const DesktopToolsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.refresh, color: DroidTheme.secondary),
                    title: const Text('Linux\'u Yeniden Kur'),
                    subtitle: const Text('Kök dosya sistemini yeniden indir ve kur'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmUnsetLauncher(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Varsayılan başlatıcıyı değiştir?'),
        content: const Text(
          'DroidDesk artık Ana Ekran uygulamanız olarak otomatik açılmayacak. Android sizden başka bir başlatıcı seçmenizi isteyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Başlatıcıyı değiştir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DroidDeskPlatform.unsetDefaultLauncher();
    }
  }

  void _showTerminal(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TerminalSheet(state: state),
    );
  }

  void _showDebianTerminal(BuildContext context, AppState state) {
    _showTerminal(context, state);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      state.startDebianShell();
    });
  }
}

/// Simple terminal bottom sheet with command execution.
class _TerminalSheet extends StatefulWidget {
  final AppState state;
  const _TerminalSheet({required this.state});

  @override
  State<_TerminalSheet> createState() => _TerminalSheetState();
}

class _TerminalSheetState extends State<_TerminalSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll when new output arrives via state listener
    widget.state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _runCommand() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty) return;

    _controller.clear();

    // Execute command and stream output (handled globally by AppState)
    await widget.state.executeCommand(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isDark = DroidTheme.isDark;

        return Container(
          decoration: BoxDecoration(
            color: DroidTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: DroidTheme.surfaceBorder),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollCtrl) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DroidTheme.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.terminal,
                            size: 18,
                            color: DroidTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text('Terminal', style: DroidTheme.headingSm),
                          const Spacer(),
                          // Stop Command Button
                          IconButton(
                            icon: const Icon(
                              Icons.stop_circle_rounded,
                              color: DroidTheme.error,
                              size: 20,
                            ),
                            onPressed: () {
                              widget.state.interruptCommand();
                              widget.state.appendTerminalOutput(
                                '\n^C (Komut durduruldu)\n',
                              );
                            },
                            tooltip: 'Komutu Durdur (Ctrl+C)',
                            splashRadius: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.state.isProotTerminal
                                ? 'uyumluluk · Debian PRoot'
                                : widget.state.hasRoot
                                ? 'chroot · ${_distroLabel(widget.state.installedDistro)}'
                                : 'yerel · Termux/TUR',
                            style: DroidTheme.monoSm,
                          ),
                        ],
                      ),
                    ),

                    Divider(color: DroidTheme.surfaceBorder, height: 1),

                    // Output Viewport (Dark container in both light & dark mode for high terminal contrast)
                    Expanded(
                      child: Container(
                        color: isDark ? const Color(0xFF0A0E17) : const Color(0xFF0F172A),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: widget.state.terminalOutput.length,
                          itemBuilder: (context, index) {
                            final line = widget.state.terminalOutput[index];
                            final isCommand = line.startsWith('\$');
                            return SelectableText(
                              line,
                              style: DroidTheme.mono.copyWith(
                                color: isCommand
                                    ? const Color(0xFF34D399) // Emerald prompt
                                    : const Color(0xFFE2E8F0), // Crisp white text
                                height: 1.4,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Input Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D131F) : const Color(0xFF1E293B),
                        border: Border(
                          top: BorderSide(color: DroidTheme.surfaceBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '\$ ',
                            style: DroidTheme.mono.copyWith(
                              color: const Color(0xFF34D399),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: DroidTheme.mono.copyWith(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Komut girin...',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _runCommand(),
                              autofocus: true,
                            ),
                          ),
                          IconButton(
                            onPressed: _runCommand,
                            icon: const Icon(Icons.send_rounded, size: 20),
                            color: DroidTheme.primary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _distroLabel(String distro) {
    switch (distro) {
      case 'ubuntu-chroot':
        return 'Ubuntu 24.04';
      case 'termux-native':
        return 'Termux';
      default:
        return distro;
    }
  }
}

// ── Small Action Card widget ──

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Gradient? gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient != null
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: gradient == null ? DroidTheme.cardBg : null,
          borderRadius: BorderRadius.circular(DroidTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DroidTheme.headingSm),
                  Text(
                    subtitle,
                    style: DroidTheme.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: DroidTheme.textDim),
          ],
        ),
      ),
    );
  }
}
