import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../history/presentation/history_screen.dart';
import '../../moment/data/moment_repository.dart';
import '../../moment/domain/moment.dart';
import '../../moment/presentation/moment_detail_screen.dart';
import '../../moment/presentation/moment_preview_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final PageController _feedController = PageController();

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  List<Moment> _moments = const [];

  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isLoadingMoments = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadCameras());
    unawaited(_loadMoments());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedController.dispose();

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller = null;
      unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      unawaited(_initializeCamera(_selectedCameraIndex));
    }
  }

  Future<void> _loadMoments() async {
    final moments = await MomentRepository.instance.getMoments();
    if (!mounted) return;

    setState(() {
      _moments = moments;
      _isLoadingMoments = false;
    });
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _cameras = const [];
          _isInitializing = false;
          _errorMessage = 'Không tìm thấy camera trên thiết bị này.';
        });
        return;
      }

      _cameras = cameras;
      final preferredIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = preferredIndex >= 0 ? preferredIndex : 0;
      await _initializeCamera(_selectedCameraIndex);
    } on CameraException catch (error) {
      _showCameraError(error);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Không thể khởi động camera.';
      });
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (_cameras.isEmpty || cameraIndex < 0 || cameraIndex >= _cameras.length) {
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    final oldController = _controller;
    _controller = null;
    if (oldController != null) await oldController.dispose();

    CameraException? lastError;

    for (final preset in const [
      ResolutionPreset.max,
      ResolutionPreset.veryHigh,
      ResolutionPreset.high,
    ]) {
      final controller = CameraController(
        _cameras[cameraIndex],
        preset,
        enableAudio: false,
      );

      try {
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);

        try {
          await controller.setFocusMode(FocusMode.auto);
        } on CameraException {
          // Some cameras do not expose focus controls.
        }

        try {
          await controller.setExposureMode(ExposureMode.auto);
        } on CameraException {
          // Some cameras do not expose exposure controls.
        }

        if (!mounted) {
          await controller.dispose();
          return;
        }

        setState(() {
          _controller = controller;
          _selectedCameraIndex = cameraIndex;
          _flashMode = FlashMode.off;
          _isInitializing = false;
        });
        return;
      } on CameraException catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }

    if (lastError != null) {
      _showCameraError(lastError);
    }
  }

  void _showCameraError(CameraException error) {
    if (!mounted) return;

    final message = switch (error.code) {
      'CameraAccessDenied' =>
        'Hãy cho phép truy cập camera để lưu lại khoảnh khắc hôm nay.',
      'CameraAccessDeniedWithoutPrompt' =>
        'Quyền camera đang bị tắt. Hãy bật lại trong cài đặt thiết bị.',
      'CameraAccessRestricted' => 'Thiết bị này đang hạn chế quyền truy cập camera.',
      _ => 'Lỗi camera: ${error.description ?? error.code}',
    };

    setState(() {
      _isInitializing = false;
      _errorMessage = message;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing || _isCapturing) return;
    await _initializeCamera((_selectedCameraIndex + 1) % _cameras.length);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final nextMode =
        _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;

    try {
      await controller.setFlashMode(nextMode);
      if (mounted) setState(() => _flashMode = nextMode);
    } on CameraException {
      _showSnackBar('Không thể thay đổi chế độ flash.');
    }
  }

  Future<void> _captureMoment() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final photo = await controller.takePicture();
      if (!mounted) return;

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MomentPreviewScreen(imagePath: photo.path),
        ),
      );

      if (saved == true) {
        await _loadMoments();
      }
    } on CameraException {
      _showSnackBar('Không thể chụp khoảnh khắc này.');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _openMoment(Moment moment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentDetailScreen(moment: moment),
      ),
    );

    await _loadMoments();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );

    await _loadMoments();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _backToCamera() {
    _feedController.animateToPage(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final cameraReady =
        controller != null && controller.value.isInitialized && !_isInitializing;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: PageView.builder(
          controller: _feedController,
          scrollDirection: Axis.vertical,
          itemCount: 1 + _moments.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _CameraPage(
                controller: controller,
                cameraReady: cameraReady,
                cameraCount: _cameras.length,
                flashMode: _flashMode,
                isInitializing: _isInitializing,
                isCapturing: _isCapturing,
                errorMessage: _errorMessage,
                momentCount: _moments.length,
                isLoadingMoments: _isLoadingMoments,
                onOpenHistory: _openHistory,
                onSwitchCamera: _switchCamera,
                onToggleFlash: _toggleFlash,
                onCapture: _captureMoment,
                onOpenProfile: _openProfile,
                onRetry: _loadCameras,
              );
            }

            final moment = _moments[index - 1];
            return _MomentFeedPage(
              moment: moment,
              position: index,
              total: _moments.length,
              onTap: () => _openMoment(moment),
              onBackToCamera: _backToCamera,
            );
          },
        ),
      ),
    );
  }
}

class _CameraPage extends StatelessWidget {
  const _CameraPage({
    required this.controller,
    required this.cameraReady,
    required this.cameraCount,
    required this.flashMode,
    required this.isInitializing,
    required this.isCapturing,
    required this.errorMessage,
    required this.momentCount,
    required this.isLoadingMoments,
    required this.onOpenHistory,
    required this.onSwitchCamera,
    required this.onToggleFlash,
    required this.onCapture,
    required this.onOpenProfile,
    required this.onRetry,
  });

  final CameraController? controller;
  final bool cameraReady;
  final int cameraCount;
  final FlashMode flashMode;
  final bool isInitializing;
  final bool isCapturing;
  final String? errorMessage;
  final int momentCount;
  final bool isLoadingMoments;
  final VoidCallback onOpenHistory;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleFlash;
  final VoidCallback onCapture;
  final VoidCallback onOpenProfile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.grid_view_rounded,
                label: 'Khoảnh khắc',
                onPressed: onOpenHistory,
              ),
              const Spacer(),
              const _BrandPill(),
              const Spacer(),
              _RoundIconButton(
                icon: Icons.cameraswitch_rounded,
                label: 'Đổi camera',
                onPressed:
                    cameraReady && cameraCount > 1 ? onSwitchCamera : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: AspectRatio(
                aspectRatio: 0.82,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CameraBody(
                        controller: controller,
                        isInitializing: isInitializing,
                        errorMessage: errorMessage,
                        onRetry: onRetry,
                      ),
                      const _CameraGradient(),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                'giữ lại\\nmột chút hôm nay.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 25,
                                      height: 1.02,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 18,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                            _MiniGlassButton(
                              icon: flashMode == FlashMode.off
                                  ? Icons.flash_off_rounded
                                  : Icons.flash_auto_rounded,
                              label: 'Flash',
                              onPressed: cameraReady ? onToggleFlash : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomAction(
                icon: Icons.photo_library_outlined,
                label: 'Thư viện',
                onTap: onOpenHistory,
              ),
              _CaptureButton(
                isBusy: isCapturing,
                enabled: cameraReady,
                onPressed: onCapture,
              ),
              _BottomAction(
                icon: Icons.person_outline_rounded,
                label: 'Tôi',
                onTap: onOpenProfile,
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: isLoadingMoments
              ? const SizedBox(height: 31)
              : Padding(
                  key: ValueKey(momentCount),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        momentCount == 0
                            ? 'chụp khoảnh khắc đầu tiên của bạn'
                            : 'lướt xuống xem $momentCount khoảnh khắc đã chụp',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _MomentFeedPage extends StatelessWidget {
  const _MomentFeedPage({
    required this.moment,
    required this.position,
    required this.total,
    required this.onTap,
    required this.onBackToCamera,
  });

  final Moment moment;
  final int position;
  final int total;
  final VoidCallback onTap;
  final VoidCallback onBackToCamera;

  @override
  Widget build(BuildContext context) {
    final image = File(moment.imagePath);
    final hasImage = image.existsSync();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.camera_alt_rounded,
                label: 'Quay lại camera',
                onPressed: onBackToCamera,
              ),
              const Spacer(),
              Text(
                '$position / $total',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Hero(
                tag: 'moment-${moment.id}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(34),
                    child: AspectRatio(
                      aspectRatio: 0.82,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasImage)
                              Image.file(
                                image,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              )
                            else
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.softBlue,
                                      AppTheme.softPink,
                                      AppTheme.softYellow,
                                    ],
                                  ),
                                ),
                              ),
                            const _CameraGradient(),
                            Positioned(
                              left: 18,
                              right: 18,
                              top: 18,
                              child: Text(
                                _formatDate(moment.createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 18,
                              bottom: 18,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (moment.caption.isNotEmpty)
                                    Text(
                                      moment.caption,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 23,
                                        height: 1.06,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 14,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (moment.caption.isNotEmpty &&
                                      moment.spending != null)
                                    const SizedBox(height: 12),
                                  if (moment.spending != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.yellow,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        _formatAmount(moment.spending!.amount),
                                        style: const TextStyle(
                                          color: AppTheme.ink,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 18),
          child: Text(
            'lướt để xem tiếp  ·  chạm ảnh để xem chi tiết',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (sameDay) return 'Hôm nay · $hour:$minute';
    if (isYesterday) return 'Hôm qua · $hour:$minute';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')} · $hour:$minute';
  }

  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return '${buffer.toString()} ₫';
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.yellow,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: AppTheme.ink),
          SizedBox(width: 7),
          Text(
            'HÔM NAY',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBody extends StatelessWidget {
  const _CameraBody({
    required this.controller,
    required this.isInitializing,
    required this.errorMessage,
    required this.onRetry,
  });

  final CameraController? controller;
  final bool isInitializing;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _CameraFallback(
        title: 'Không thể dùng camera',
        message: errorMessage!,
        actionLabel: 'Thử lại',
        onAction: onRetry,
      );
    }

    if (isInitializing ||
        controller == null ||
        !controller!.value.isInitialized) {
      return const _CameraFallback(
        title: 'Đang mở camera…',
        message: 'Khoảnh khắc tiếp theo sắp sẵn sàng rồi.',
      );
    }

    final previewSize = controller!.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller!);
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller!),
      ),
    );
  }
}

class _CameraGradient extends StatelessWidget {
  const _CameraGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x22000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0x99000000),
          ],
          stops: [0, 0.35, 0.62, 1],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}

class _MiniGlassButton extends StatelessWidget {
  const _MiniGlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        minimumSize: const Size(46, 46),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 27),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isBusy,
    required this.enabled,
    required this.onPressed,
  });

  final bool isBusy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !isBusy ? onPressed : null,
      child: AnimatedScale(
        scale: isBusy ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.yellow,
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.ink,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      size: 27,
                      color: AppTheme.ink,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A3E22),
            Color(0xFF242018),
            Color(0xFF171717),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppTheme.yellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.ink,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
