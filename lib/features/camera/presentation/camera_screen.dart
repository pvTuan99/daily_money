import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../history/presentation/history_screen.dart';
import '../../moment/presentation/moment_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadCameras());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    final controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

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
    } on CameraException catch (error) {
      await controller.dispose();
      _showCameraError(error);
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

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MomentPreviewScreen(imagePath: photo.path),
        ),
      );
    } on CameraException {
      _showSnackBar('Không thể chụp khoảnh khắc này.');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.grid_view_rounded,
                    label: 'Khoảnh khắc',
                    onPressed: _openHistory,
                  ),
                  const Spacer(),
                  const _BrandPill(),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Đổi camera',
                    onPressed: cameraReady && _cameras.length > 1
                        ? _switchCamera
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CameraBody(
                        controller: controller,
                        isInitializing: _isInitializing,
                        errorMessage: _errorMessage,
                        onRetry: _loadCameras,
                      ),
                      const _CameraGradient(),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Những khoảnh khắc nhỏ\nlàm nên một ngày.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 28,
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
                              icon: _flashMode == FlashMode.off
                                  ? Icons.flash_off_rounded
                                  : Icons.flash_auto_rounded,
                              label: 'Flash',
                              onPressed: cameraReady ? _toggleFlash : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BottomAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Thư viện',
                    onTap: () => _showSnackBar('Tính năng chọn ảnh từ thư viện sẽ có sau.'),
                  ),
                  _CaptureButton(
                    isBusy: _isCapturing,
                    enabled: cameraReady,
                    onPressed: _captureMoment,
                  ),
                  _BottomAction(
                    icon: Icons.person_outline_rounded,
                    label: 'Tôi',
                    onTap: () => _showSnackBar('Trang cá nhân sẽ có sau.'),
                  ),
                ],
              ),
            ),
            Text(
              'chạm một lần, giữ lại hôm nay.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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

    final size = MediaQuery.sizeOf(context);
    final scale = 1 /
        (controller!.value.aspectRatio * (size.width / size.height));

    return ClipRect(
      child: Transform.scale(
        scale: scale < 1 ? 1 / scale : scale,
        child: Center(child: CameraPreview(controller!)),
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
            width: 88,
            height: 88,
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
                      padding: EdgeInsets.all(21),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.ink,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      size: 28,
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
