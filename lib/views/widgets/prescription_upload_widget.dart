import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../config/app_theme.dart';

class PrescriptionUploadWidget extends StatefulWidget {
  const PrescriptionUploadWidget({super.key});

  @override
  State<PrescriptionUploadWidget> createState() => _PrescriptionUploadWidgetState();
}

class _PrescriptionUploadWidgetState extends State<PrescriptionUploadWidget> {
  List<Map<String, dynamic>> prescriptions = [
    {
      'id': '1',
      'doctorName': 'Dr. Sarah Wilson',
      'date': '2024-01-15',
      'status': 'Ready for Pickup',
      'medicines': ['Metformin 500mg', 'Lisinopril 10mg'],
      'statusColor': Colors.green,
    },
    {
      'id': '2',
      'doctorName': 'Dr. Michael Chen',
      'date': '2024-01-10',
      'status': 'Processing',
      'medicines': ['Atorvastatin 20mg', 'Aspirin 81mg'],
      'statusColor': Colors.orange,
    },
    {
      'id': '3',
      'doctorName': 'Dr. Emily Davis',
      'date': '2024-01-05',
      'status': 'Completed',
      'medicines': ['Amoxicillin 500mg'],
      'statusColor': Colors.blue,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prescription Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload new prescriptions and track existing ones',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _uploadPrescription(),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload New Prescription'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final prescription = prescriptions[index];
              return _buildPrescriptionCard(prescription);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prescription['doctorName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: prescription['statusColor'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    prescription['status'],
                    style: TextStyle(
                      color: prescription['statusColor'],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  prescription['date'],
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Medicines:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...prescription['medicines'].map<Widget>((medicine) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.medication, size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(medicine),
                ],
              ),
            )).toList(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _viewPrescriptionDetails(prescription),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                if (prescription['status'] == 'Ready for Pickup')
                  ElevatedButton.icon(
                    onPressed: () => _requestDelivery(prescription),
                    icon: const Icon(Icons.local_shipping, size: 16),
                    label: const Text('Request Delivery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  void _uploadPrescription() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: () {
                  // Simulate file picker
                  Navigator.pop(context);
                  _showUploadSuccess();
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 40, color: AppTheme.primaryBlue),
                    SizedBox(height: 8),
                    Text('Tap to select image'),
                    Text('or drag & drop here', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Doctor Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Additional Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showUploadSuccess();
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _showUploadSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription uploaded successfully! We\'ll process it within 2 hours.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _viewPrescriptionDetails(Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prescription Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor: ${prescription['doctorName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Date: ${prescription['date']}'),
            const SizedBox(height: 8),
            Text('Status: ${prescription['status']}'),
            const SizedBox(height: 12),
            const Text('Medicines:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...prescription['medicines'].map<Widget>((medicine) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text('• $medicine'),
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _requestDelivery(Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Home Delivery'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Would you like us to deliver this prescription to your home?'),
            SizedBox(height: 16),
            Text('Delivery charge: ₹50', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Estimated delivery: Within 2 hours'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delivery requested! We\'ll call you to confirm the address.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Request Delivery'),
          ),
        ],
      ),
    );
  }
}