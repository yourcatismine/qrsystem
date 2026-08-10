import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isNavigating = false;
  bool isErrorShowing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (isNavigating || isErrorShowing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                final String? rawValue = barcode.rawValue;
                
                if (rawValue != null && rawValue.startsWith('QRSYS_POLE_')) {
                  setState(() {
                    isNavigating = true;
                  });
                  final poleId = rawValue.replaceFirst('QRSYS_POLE_', '');
                  debugPrint('Found pole: $poleId');
                  
                  // Return the scanned pole ID back to the HomeScreen
                  Navigator.pop(context, poleId);
                } else if (rawValue != null) {
                   setState(() {
                     isErrorShowing = true;
                   });
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid QR Code. Please scan an official QR code.'),
                        duration: Duration(seconds: 2),
                      ),
                   );
                   // Add a short delay before allowing another scan attempt
                   Future.delayed(const Duration(seconds: 3), () {
                     if (mounted) setState(() => isErrorShowing = false);
                   });
                }
              }
            },
          ),
          // QR Scanner Overlay
          Column(
            children: [
              Expanded(child: Container(color: Colors.black54)),
              Row(
                children: [
                  Expanded(child: Container(height: 250, color: Colors.black54)),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Expanded(child: Container(height: 250, color: Colors.black54)),
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.black54,
                  width: double.infinity,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        'Align QR code within the frame to scan',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
