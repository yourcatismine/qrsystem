import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../utils/notification_service.dart';
import '../models/qr_code.dart' as model;

class ManageQrScreen extends StatefulWidget {
  const ManageQrScreen({super.key});

  @override
  State<ManageQrScreen> createState() => _ManageQrScreenState();
}

class _ManageQrScreenState extends State<ManageQrScreen> {
  List<model.QrCode> _qrCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoles();
  }

  Future<void> _loadPoles() async {
    try {
      final data = await Supabase.instance.client
          .from('qr_codes')
          .select()
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _qrCodes = (data as List).map((e) => model.QrCode.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading QR codes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationService.showError(context, 'DB Error: ${e.toString()}');
      }
    }
  }



  void _showGenerateDialog() {
    final controller = TextEditingController();
    bool isGenerating = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Generate QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter a unique Pole ID or Name:', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  enabled: !isGenerating,
                  decoration: InputDecoration(
                    hintText: 'e.g. POLE-101A',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isGenerating ? null : () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isGenerating ? null : () async {
                  final poleId = controller.text.trim();
                  // Check if it already exists locally first for fast feedback
                  if (poleId.isNotEmpty && !_qrCodes.any((qr) => qr.poleId == poleId)) {
                    setStateDialog(() => isGenerating = true);
                    
                    try {
                      final newQrData = await Supabase.instance.client
                          .from('qr_codes')
                          .insert({'pole_id': poleId})
                          .select()
                          .single();
                          
                      setState(() {
                        _qrCodes.insert(0, model.QrCode.fromJson(newQrData));
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        NotificationService.showSuccess(context, 'QR Code for $poleId generated securely!');
                      }
                    } catch (e) {
                      debugPrint('Error inserting QR code: $e');
                      setStateDialog(() => isGenerating = false);
                      if (context.mounted) {
                        NotificationService.showError(context, 'Insert Error: ${e.toString()}');
                      }
                    }
                  } else if (_qrCodes.any((qr) => qr.poleId == poleId)) {
                    NotificationService.showError(context, 'QR Code for $poleId already exists.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isGenerating 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Generate', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
  
  void _confirmDeletePole(String poleId) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to delete the QR code for $poleId?'),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isDeleting ? null : () async {
                  setStateDialog(() => isDeleting = true);
                  
                  try {
                    await Supabase.instance.client
                        .from('qr_codes')
                        .delete()
                        .eq('pole_id', poleId);
                        
                    setState(() {
                      _qrCodes.removeWhere((qr) => qr.poleId == poleId);
                    });
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      NotificationService.showSuccess(context, 'QR Code deleted from database.');
                    }
                  } catch (e) {
                    debugPrint('Error deleting QR code: $e');
                    setStateDialog(() => isDeleting = false);
                    if (context.mounted) {
                      NotificationService.showError(context, 'Delete Error: ${e.toString()}');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isDeleting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showQrFullscreen(String poleId) {
    bool isDownloading = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pole: $poleId',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Screenshot to save or print this QR Code.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'QRSYS_POLE_$poleId',
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isDownloading ? null : () async {
                            setStateDialog(() => isDownloading = true);
                            
                            try {
                              final qrData = 'QRSYS_POLE_$poleId';
                              final qrValidationResult = QrValidator.validate(
                                data: qrData,
                                version: QrVersions.auto,
                                errorCorrectionLevel: QrErrorCorrectLevel.L,
                              );

                              if (qrValidationResult.status == QrValidationStatus.valid) {
                                final qrCode = qrValidationResult.qrCode;
                                final painter = QrPainter.withQr(
                                  qr: qrCode!,
                                  color: const Color(0xFF000000),
                                  emptyColor: const Color(0xFFFFFFFF),
                                  gapless: true,
                                );
                                
                                // Draw QR onto a white canvas so background is not transparent
                                const imageSize = 2048.0;
                                const padding = 64.0;
                                const totalSize = imageSize + padding * 2;
                                
                                final recorder = ui.PictureRecorder();
                                final canvas = Canvas(recorder);
                                
                                // Draw white background
                                canvas.drawRect(
                                  Rect.fromLTWH(0, 0, totalSize, totalSize),
                                  Paint()..color = Colors.white,
                                );
                                
                                // Draw QR code in the center with padding
                                canvas.save();
                                canvas.translate(padding, padding);
                                painter.paint(canvas, const Size(imageSize, imageSize));
                                canvas.restore();
                                
                                final picture = recorder.endRecording();
                                final img = await picture.toImage(totalSize.toInt(), totalSize.toInt());
                                final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
                                
                                if (byteData != null) {
                                  final buffer = byteData.buffer.asUint8List();
                                  
                                  final result = await ImageGallerySaver.saveImage(
                                    buffer,
                                    quality: 100,
                                    name: "QR_POLE_$poleId",
                                  );
                                  
                                  if (context.mounted) {
                                    setStateDialog(() => isDownloading = false);
                                    if (result != null && result['isSuccess'] == true) {
                                      NotificationService.showSuccess(context, 'QR Code saved to gallery!');
                                    } else {
                                      NotificationService.showError(context, 'Failed to save. Check storage permissions.');
                                    }
                                  }
                                }
                              }
                            } catch (e) {
                              debugPrint('Failed to save QR Code: $e');
                              if (context.mounted) {
                                setStateDialog(() => isDownloading = false);
                                NotificationService.showError(context, 'Failed to save QR code.');
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.blue.shade700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: isDownloading 
                              ? const SizedBox.shrink()
                              : SvgPicture.asset(
                                  'assets/icons/download.svg',
                                  width: 18,
                                  height: 18,
                                  colorFilter: ColorFilter.mode(Colors.blue.shade700, BlendMode.srcIn),
                                ),
                          label: isDownloading
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.blue.shade700, strokeWidth: 2))
                              : Text('Download', style: TextStyle(color: Colors.blue.shade700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isDownloading ? null : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Done', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Manage QR Codes',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade700,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loading QR Codes...',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _qrCodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 100, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No QR Codes Generated',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate your first QR code to get started.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _qrCodes.length,
                  itemBuilder: (context, index) {
                    final qrCode = _qrCodes[index];
                    return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: 'QRSYS_POLE_${qrCode.poleId}',
                        version: QrVersions.auto,
                        size: 40.0,
                      ),
                    ),
                    title: Text(
                      'Pole: ${qrCode.poleId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: const Text('Tap to view & save', style: TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDeletePole(qrCode.poleId),
                    ),
                    onTap: () => _showQrFullscreen(qrCode.poleId),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateDialog,
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Generate QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
