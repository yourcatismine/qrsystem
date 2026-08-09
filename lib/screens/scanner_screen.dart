import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'report_form_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isNavigating = false;

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
              if (isNavigating) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                final String? rawValue = barcode.rawValue;
                
                if (rawValue != null) {
                  setState(() {
                    isNavigating = true;
                  });
                  print("Scanned QR Code: $rawValue");
                  
                  // Return the scanned pole ID back to the HomeScreen
                  Navigator.pop(context, rawValue);
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
