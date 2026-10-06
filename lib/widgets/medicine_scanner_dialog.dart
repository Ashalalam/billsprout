import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/medicine_ocr_service.dart';
import '../services/barcode_scanner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Scanned medicine data with metadata
class ScannedMedicine {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? imagePath;
  final Map<String, double> confidence;

  ScannedMedicine({
    required this.data,
    required this.timestamp,
    this.imagePath,
    this.confidence = const {},
  });

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
    'confidence': confidence,
  };

  factory ScannedMedicine.fromJson(Map<String, dynamic> json) {
    return ScannedMedicine(
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      imagePath: json['imagePath'],
      confidence: Map<String, double>.from(json['confidence'] ?? {}),
    );
  }
}

/// Dialog for scanning medicine information using camera or photo
class MedicineScannerDialog extends StatefulWidget {
  final bool batchMode;
  
  const MedicineScannerDialog({
    super.key,
    this.batchMode = false,
  });

  @override
  State<MedicineScannerDialog> createState() => _MedicineScannerDialogState();
}

class _MedicineScannerDialogState extends State<MedicineScannerDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  final MedicineOCRService _ocrService = MedicineOCRService();
  final BarcodeScannerService _barcodeService = BarcodeScannerService();

  bool _isProcessing = false;
  String? _statusMessage;
  File? _capturedImage;
  List<ScannedMedicine> _scannedItems = [];
  List<ScannedMedicine> _scanHistory = [];
  int _currentTab = 0; // 0: scan, 1: batch, 2: history

  @override
  void initState() {
    super.initState();
    _loadScanHistory();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _barcodeService.dispose();
    super.dispose();
  }

  /// Load scan history from local storage
  Future<void> _loadScanHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('medicine_scan_history');
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        setState(() {
          _scanHistory = historyList
              .map((item) => ScannedMedicine.fromJson(item))
              .toList()
              .reversed
              .take(20) // Keep last 20 scans
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load scan history: $e');
    }
  }

  /// Save scan to history
  Future<void> _saveScanToHistory(ScannedMedicine scan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _scanHistory.insert(0, scan);
      if (_scanHistory.length > 20) {
        _scanHistory = _scanHistory.take(20).toList();
      }
      final historyJson = jsonEncode(
        _scanHistory.map((s) => s.toJson()).toList(),
      );
      await prefs.setString('medicine_scan_history', historyJson);
    } catch (e) {
      debugPrint('Failed to save scan history: $e');
    }
  }

  /// Capture image from camera
  Future<void> _captureFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _statusMessage = 'Image captured. Processing...';
        });
        await _processImage(photo.path);
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _statusMessage = 'Image selected. Processing...';
        });
        await _processImage(photo.path);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  /// Process the captured/selected image
  Future<void> _processImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // First, try to scan barcode
      final barcodeValue = await _barcodeService.scanBarcodeFromImage(imagePath);
      
      // Then extract text using OCR
      final extractedData = await _ocrService.extractMedicineData(imagePath);

      // Add barcode to extracted data if found
      if (barcodeValue != null && barcodeValue.isNotEmpty) {
        extractedData['barcode'] = barcodeValue;
      }

      // Calculate confidence scores (mock for now - can be enhanced with ML Kit confidence)
      final confidence = {
        'name': extractedData['name']?.isNotEmpty == true ? 0.85 : 0.0,
        'dosage': extractedData['dosage']?.isNotEmpty == true ? 0.75 : 0.0,
        'manufacturer': extractedData['manufacturer']?.isNotEmpty == true ? 0.70 : 0.0,
        'expiry': extractedData['expiry']?.isNotEmpty == true ? 0.80 : 0.0,
      };

      final scannedItem = ScannedMedicine(
        data: extractedData,
        timestamp: DateTime.now(),
        imagePath: imagePath,
        confidence: confidence,
      );

      // Save to history
      await _saveScanToHistory(scannedItem);

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Processing complete!';
      });

      if (widget.batchMode) {
        // In batch mode, add to list
        setState(() {
          _scannedItems.add(scannedItem);
          _capturedImage = null;
          _statusMessage = 'Item added! Scan another or finish.';
          _currentTab = 1; // Switch to batch tab
        });
      } else {
        // Single scan mode - return immediately
        if (mounted) {
          final result = await _showReviewDialog(scannedItem);
          if (result != null && mounted) {
            Navigator.of(context).pop(result);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to process image: $e');
    }
  }

  /// Show review dialog for scanned data
  Future<Map<String, dynamic>?> _showReviewDialog(ScannedMedicine scan) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ScanReviewDialog(scan: scan),
    );
  }

  /// Show error message
  void _showError(String message) {
    if (!mounted) return;
    
    setState(() {
      _statusMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Medicine Scanner',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.batchMode)
                          Text(
                            '${_scannedItems.length} items scanned',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab bar
            if (widget.batchMode)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTab('Scan', 0, Icons.camera_alt),
                    _buildTab('Batch (${_scannedItems.length})', 1, Icons.inventory),
                    _buildTab('History', 2, Icons.history),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.batchMode) {
      return IndexedStack(
        index: _currentTab,
        children: [
          _buildScanTab(),
          _buildBatchTab(),
          _buildHistoryTab(),
        ],
      );
    }
    return _buildScanTab();
  }

  Widget _buildScanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Capture or select a photo of medicine packaging',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Image preview
          if (_capturedImage != null) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_capturedImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Status message
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_statusMessage!, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          if (!_isProcessing) ...[
            ElevatedButton.icon(
              onPressed: _captureFromCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            ),
          ],

          // Batch mode finish button
          if (widget.batchMode && _scannedItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(_scannedItems),
              icon: const Icon(Icons.check),
              label: Text('Finish Batch (${_scannedItems.length} items)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchTab() {
    if (_scannedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No items scanned yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _currentTab = 0),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Scanning'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _scannedItems.length,
            itemBuilder: (context, index) {
              final item = _scannedItems[index];
              return _buildScannedItemCard(item, index);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentTab = 0),
                  icon: const Icon(Icons.add),
                  label: const Text('Scan More'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_scannedItems),
                  icon: const Icon(Icons.check),
                  label: Text('Done (${_scannedItems.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_scanHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No scan history',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _scanHistory.length,
      itemBuilder: (context, index) {
        final item = _scanHistory[index];
        return _buildHistoryItemCard(item);
      },
    );
  }

  Widget _buildScannedItemCard(ScannedMedicine item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(item.imagePath!),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication, color: Colors.grey),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.data['name'] ?? 'Unknown Medicine',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.data['dosage'] != null)
                    Text(
                      item.data['dosage'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _buildConfidenceIndicator(item),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() => _scannedItems.removeAt(index));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItemCard(ScannedMedicine item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.medication, size: 20),
        ),
        title: Text(
          item.data['name'] ?? 'Unknown Medicine',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatTimestamp(item.timestamp),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.redo),
          onPressed: () async {
            final result = await _showReviewDialog(item);
            if (result != null && mounted) {
              Navigator.of(context).pop(result);
            }
          },
          tooltip: 'Use this scan',
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(ScannedMedicine item) {
    final avgConfidence = item.confidence.values.isEmpty
        ? 0.0
        : item.confidence.values.reduce((a, b) => a + b) / item.confidence.length;
    
    Color color;
    String label;
    if (avgConfidence >= 0.75) {
      color = Colors.green;
      label = 'High confidence';
    } else if (avgConfidence >= 0.5) {
      color = Colors.orange;
      label = 'Medium confidence';
    } else {
      color = Colors.red;
      label = 'Low confidence';
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Show medicine scanner dialog and return extracted data
Future<Map<String, dynamic>?> showMedicineScannerDialog(
  BuildContext context, {
  bool batchMode = false,
}) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => MedicineScannerDialog(batchMode: batchMode),
  );
}

/// Review dialog for scanned medicine data
class _ScanReviewDialog extends StatefulWidget {
  final ScannedMedicine scan;

  const _ScanReviewDialog({required this.scan});

  @override
  State<_ScanReviewDialog> createState() => _ScanReviewDialogState();
}

class _ScanReviewDialogState extends State<_ScanReviewDialog> {
  late Map<String, dynamic> _editedData;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _editedData = Map.from(widget.scan.data);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.rate_review, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Review Scanned Data',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Review and edit extracted information',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Image preview
            if (widget.scan.imagePath != null) ...[
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.scan.imagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Editable fields
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildEditableField(
                      'Medicine Name',
                      'name',
                      Icons.medication,
                      widget.scan.confidence['name'] ?? 0.0,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableField(
                      'Dosage/Strength',
                      'dosage',
                      Icons.science,
                      widget.scan.confidence['dosage'] ?? 0.0,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableField(
                      'Manufacturer',
                      'manufacturer',
                      Icons.business,
                      widget.scan.confidence['manufacturer'] ?? 0.0,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableField(
                      'Expiry Date',
                      'expiry',
                      Icons.event,
                      widget.scan.confidence['expiry'] ?? 0.0,
                    ),
                    if (_editedData['barcode'] != null) ...[
                      const SizedBox(height: 12),
                      _buildEditableField(
                        'Barcode',
                        'barcode',
                        Icons.qr_code,
                        1.0,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        Navigator.of(context).pop(_editedData);
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    String key,
    IconData icon,
    double confidence,
  ) {
    Color confidenceColor;
    if (confidence >= 0.75) {
      confidenceColor = Colors.green;
    } else if (confidence >= 0.5) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: confidenceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: confidenceColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _editedData[key]?.toString() ?? '',
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onSaved: (value) => _editedData[key] = value,
        ),
      ],
    );
  }
}
