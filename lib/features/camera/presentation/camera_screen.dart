import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

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
    if (oldController != null) {
      await oldController.dispose();
    }

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
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Could not initialize the camera.';
      });
    }
  }

  void _showCameraError(CameraException error) {
    if (!mounted) return;

    final message = switch (error.code) {
      'CameraAccessDenied' =>
        'Camera access was denied. Allow camera permission to take moments.',
      'CameraAccessDeniedWithoutPrompt' =>
        'Camera permission is disabled. Enable it in your device settings.',
      'CameraAccessRestricted' =>
        'Camera access is restricted on this device.',
      _ => 'Camera error: ${error.description ?? error.code}',
    };

    setState(() {
      _isInitializing = false;
      _errorMessage = message;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing || _isCapturing) return;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCamera(nextIndex);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final nextMode =
        _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;

    try {
      await controller.setFlashMode(nextMode);
      if (!mounted) return;
      setState(() => _flashMode = nextMode);
    } on CameraException catch (error) {
      _showSnackBar(error.description ?? 'Could not change flash mode.');
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

      _showSnackBar('Moment captured. Preview comes in Phase 3.');
      debugPrint('Captured photo: ${photo.path}');
    } on CameraException catch (error) {
      _showSnackBar(error.description ?? 'Could not capture this moment.');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = _controller;
    final cameraReady =
        controller != null && controller.value.isInitialized && !_isInitializing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CameraBody(
              controller: controller,
              isInitializing: _isInitializing,
              errorMessage: _errorMessage,
              onRetry: _loadCameras,
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundControl(
                    icon: Icons.history_rounded,
                    label: 'Moments',
                    onPressed: () => _showSnackBar(
                      'Moment history comes in Phase 3.',
                    ),
                  ),
                  _RoundControl(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Switch camera',
                    onPressed:
                        cameraReady && _cameras.length > 1 ? _switchCamera : null,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundControl(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onPressed: () => _showSnackBar(
                      'Gallery import comes in a later phase.',
                    ),
                  ),
                  _CaptureButton(
                    color: colors.primary,
                    isBusy: _isCapturing,
                    onPressed: cameraReady ? _captureMoment : null,
                  ),
                  _RoundControl(
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
      return _CameraMessage(
        icon: Icons.camera_alt_outlined,
        title: 'Camera unavailable',
        message: errorMessage!,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }

    if (isInitializing ||
        controller == null ||
        !controller!.value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFF101010),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller!.value.aspectRatio,
          child: CameraPreview(controller!),
        ),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101010),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.color,
    required this.isBusy,
    required this.onPressed,
  });

  final Color color;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture moment',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: onPressed == null ? 0.45 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
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
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}
