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
          _errorMessage = 'No camera was found on this device.';
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
        _errorMessage = 'Could not start the camera.';
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
      ResolutionPreset.high,
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
        'Allow camera access so you can capture your daily moment.',
      'CameraAccessDeniedWithoutPrompt' =>
        'Camera permission is off. Enable it in device settings.',
      'CameraAccessRestricted' => 'Camera access is restricted on this device.',
      _ => 'Camera error: ${error.description ?? error.code}',
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
      _showSnackBar('Could not change flash mode.');
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
      _showSnackBar('Could not capture this moment.');
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CameraBody(
            controller: controller,
            isInitializing: _isInitializing,
            errorMessage: _errorMessage,
            onRetry: _loadCameras,
          ),
          const _SoftVignette(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassButton(
                        icon: Icons.grid_view_rounded,
                        label: 'Moments',
                        onPressed: _openHistory,
                      ),
                      const Spacer(),
                      const _DailyBadge(),
                      const Spacer(),
                      _GlassButton(
                        icon: Icons.cameraswitch_rounded,
                        label: 'Switch',
                        onPressed: cameraReady && _cameras.length > 1
                            ? _switchCamera
                            : null,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Capture\nwhat today felt like.',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 30,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 18,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _GlassButton(
                        icon: _flashMode == FlashMode.off
                            ? Icons.flash_off_rounded
                            : Icons.flash_auto_rounded,
                        label: 'Flash',
                        onPressed: cameraReady ? _toggleFlash : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SmallAction(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () => _showSnackBar('Gallery import comes later.'),
                      ),
                      const SizedBox(width: 26),
                      _CaptureButton(
                        isBusy: _isCapturing,
                        enabled: cameraReady,
                        onPressed: _captureMoment,
                      ),
                      const SizedBox(width: 26),
                      _SmallAction(
                        icon: Icons.person_outline_rounded,
                        label: 'Me',
                        onTap: () => _showSnackBar('Profile comes later.'),
                      ),
                    ],
                  ),
                ],
              ),
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
        title: 'Camera unavailable',
        message: errorMessage!,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }

    if (isInitializing ||
        controller == null ||
        !controller!.value.isInitialized) {
      return const _CameraFallback(
        title: 'Opening camera…',
        message: 'Your next moment is almost ready.',
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

class _SoftVignette extends StatelessWidget {
  const _SoftVignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x66000000),
            Color(0x00000000),
            Color(0x11000000),
            Color(0xAA000000),
          ],
          stops: [0, 0.25, 0.58, 1],
        ),
      ),
    );
  }
}

class _DailyBadge extends StatelessWidget {
  const _DailyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.lime,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'DAILY',
        style: TextStyle(
          color: AppTheme.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
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
        backgroundColor: Colors.black.withValues(alpha: 0.32),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassButton(icon: icon, label: label, onPressed: onTap),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            color: Colors.black.withValues(alpha: 0.18),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.lime,
            ),
            child: isBusy
                ? const Padding(
                    padding: EdgeInsets.all(22),
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
            Color(0xFF2B2535),
            Color(0xFF141414),
            Color(0xFF263126),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_rounded,
                color: AppTheme.lime,
                size: 54,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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
                FilledButton.tonal(
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
