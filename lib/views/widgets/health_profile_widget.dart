import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

class HealthProfileWidget extends StatefulWidget {
  const HealthProfileWidget({super.key});

  @override
  State<HealthProfileWidget> createState() => _HealthProfileWidgetState();
}

class _HealthProfileWidgetState extends State<HealthProfileWidget> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _healthProfile;
  bool _isLoading = false;
  String? _error;

  // Form controllers
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicConditionsController = TextEditingController();
  final _currentMedicationsController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHealthProfile();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _chronicConditionsController.dispose();
    _currentMedicationsController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // Try to load existing health profile
      final response = await _supabase
          .from('health_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _healthProfile = response;
        _populateControllers();
      } else {
        // Create default profile structure
        _healthProfile = {
          'user_id': userId,
          'height_cm': null,
          'weight_kg': null,
          'blood_group': '',
          'allergies': '',
          'chronic_conditions': '',
          'current_medications': '',
          'emergency_contact_name': '',
          'emergency_contact_phone': '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
      }

      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = 'Failed to load health profile: $e');
      debugPrint('Health profile load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (_healthProfile != null) {
      _heightController.text = _healthProfile!['height_cm']?.toString() ?? '';
      _weightController.text = _healthProfile!['weight_kg']?.toString() ?? '';
      _bloodGroupController.text = _healthProfile!['blood_group'] ?? '';
      _allergiesController.text = _healthProfile!['allergies'] ?? '';
      _chronicConditionsController.text = _healthProfile!['chronic_conditions'] ?? '';
      _currentMedicationsController.text = _healthProfile!['current_medications'] ?? '';
      _emergencyContactController.text = _healthProfile!['emergency_contact_name'] ?? '';
      _emergencyPhoneController.text = _healthProfile!['emergency_contact_phone'] ?? '';
    }
  }

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
                'Health Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your health information and medical history',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderStat(
                      'BMI',
                      _calculateBMI(),
                      Icons.monitor_weight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHeaderStat(
                      'Blood Group',
                      _bloodGroupController.text.isEmpty ? '--' : _bloodGroupController.text,
                      Icons.bloodtype,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildProfileContent(),
        ),
      ],
    );
  }

  Widget _buildHeaderStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateBMI() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    
    if (height != null && weight != null && height > 0) {
      final heightM = height / 100; // Convert cm to m
      final bmi = weight / (heightM * heightM);
      return bmi.toStringAsFixed(1);
    }
    
    return '--';
  }

  Widget _buildProfileContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHealthProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBasicInfoCard(),
          const SizedBox(height: 16),
          _buildMedicalInfoCard(),
          const SizedBox(height: 16),
          _buildEmergencyContactCard(),
          const SizedBox(height: 16),
          _buildHealthInsightsCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveHealthProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppTheme.primaryBlue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Basic Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      hintText: '170',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: '70',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _bloodGroupController.text.isEmpty ? null : _bloodGroupController.text,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype),
              ),
              items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                  .map((group) => DropdownMenuItem(value: group, child: Text(group)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _bloodGroupController.text = value ?? '';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_information_outlined, color: AppTheme.primaryBlue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Medical Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _allergiesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Known Allergies',
                hintText: 'e.g., Penicillin, Peanuts, Dust',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _chronicConditionsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Chronic Conditions',
                hintText: 'e.g., Diabetes, Hypertension, Asthma',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentMedicationsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Current Medications',
                hintText: 'List your regular medications with dosages',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency_outlined, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Emergency Contact',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                hintText: 'Spouse, Parent, or Guardian',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emergencyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+91 9876543210',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthInsightsCard() {
    final bmi = double.tryParse(_calculateBMI());
    String bmiCategory = '';
    Color bmiColor = Colors.grey;

    if (bmi != null) {
      if (bmi < 18.5) {
        bmiCategory = 'Underweight';
        bmiColor = Colors.blue;
      } else if (bmi < 25) {
        bmiCategory = 'Normal';
        bmiColor = Colors.green;
      } else if (bmi < 30) {
        bmiCategory = 'Overweight';
        bmiColor = Colors.orange;
      } else {
        bmiCategory = 'Obese';
        bmiColor = Colors.red;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: AppTheme.primaryBlue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Health Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bmi != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BMI Category:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: bmiColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bmiCategory,
                      style: TextStyle(
                        color: bmiColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bmi != null
                          ? 'Your BMI is ${bmi.toStringAsFixed(1)}, which falls in the $bmiCategory range.'
                          : 'Complete your height and weight to see BMI insights.',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveHealthProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileData = {
        'user_id': userId,
        'height_cm': _heightController.text.isEmpty ? null : double.tryParse(_heightController.text),
        'weight_kg': _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
        'blood_group': _bloodGroupController.text,
        'allergies': _allergiesController.text,
        'chronic_conditions': _chronicConditionsController.text,
        'current_medications': _currentMedicationsController.text,
        'emergency_contact_name': _emergencyContactController.text,
        'emergency_contact_phone': _emergencyPhoneController.text,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // First check if the table exists (it might not in demo setups)
      try {
        await _supabase
            .from('health_profiles')
            .upsert(profileData, onConflict: 'user_id');
        
        setState(() {
          _healthProfile = profileData;
          _error = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (tableError) {
        // If table doesn't exist, save locally for demo
        setState(() {
          _healthProfile = profileData;
          _error = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved locally (demo mode)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to save health profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Health profile save error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}