import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _handled = false;
  bool _cameraGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _requestCamera();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _cameraGranted = true;
          _checking = false;
        });
      }
      return;
    }
    final r = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraGranted = r.isGranted;
      _checking = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _handled = true;
        Navigator.pop(context, raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('扫一扫'),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
          ),
          IconButton(
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_checking)
            const Center(child: CircularProgressIndicator())
          else if (!_cameraGranted)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography, size: 56, color: Colors.white70),
                    const SizedBox(height: 12),
                    const Text('未获得相机权限', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('请在系统设置中允许相机后重试', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => openAppSettings(),
                      child: const Text('打开系统设置'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _requestCamera,
                      child: const Text('重新申请'),
                    ),
                  ],
                ),
              ),
            )
          else
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          if (_cameraGranted) ...[
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Center(
                child: Text(
                  '将二维码放入框内自动识别',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

