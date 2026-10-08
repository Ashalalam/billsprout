import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

class AppointmentsWidget extends StatefulWidget {
  const AppointmentsWidget({super.key});

  @override
  State<AppointmentsWidget> createState() => _AppointmentsWidgetState();
}

class _AppointmentsWidgetState extends State<AppointmentsWidget> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDemoAppointments(); // Load demo data since table might not exist
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadDemoAppointments() {
    // Demo appointments data since the table might not exist in Supabase
    _appointments = [
      {
        'id': '1',
        'doctor_name': 'Dr. Sarah Johnson',
        'specialty': 'Cardiologist',
        'appointment_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'appointment_time': '10:00',
        'status': 'confirmed',
        'type': 'consultation',
        'notes': 'Regular checkup for blood pressure',
        'location': 'LifeSprout Medical Center, Room 203',
        'phone': '+91 98765 43210',
        'fee': 500.0,
      },
      {
        'id': '2',
        'doctor_name': 'Dr. Michael Chen',
        'specialty': 'General Physician',
        'appointment_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'appointment_time': '14:30',
        'status': 'confirmed',
        'type': 'follow_up',
        'notes': 'Follow-up for diabetes medication',
        'location': 'LifeSprout Medical Center, Room 105',
        'phone': '+91 98765 43211',
        'fee': 350.0,
      },
      {
        'id': '3',
        'doctor_name': 'Dr. Priya Sharma',
        'specialty': 'Dermatologist',
        'appointment_date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'appointment_time': '11:15',
        'status': 'completed',
        'type': 'consultation',
        'notes': 'Skin allergy consultation',
        'location': 'LifeSprout Medical Center, Room 301',
        'phone': '+91 98765 43212',
        'fee': 400.0,
      },
      {
        'id': '4',
        'doctor_name': 'Dr. Rajesh Kumar',
        'specialty': 'Orthopedist',
        'appointment_date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'appointment_time': '16:00',
        'status': 'cancelled',
        'type': 'consultation',
        'notes': 'Knee pain consultation - Cancelled by patient',
        'location': 'LifeSprout Medical Center, Room 205',
        'phone': '+91 98765 43213',
        'fee': 600.0,
      },
    ];
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
                'Appointments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Book and manage your medical appointments',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderStat(
                      'Upcoming',
                      _getUpcomingCount().toString(),
                      Icons.schedule,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHeaderStat(
                      'Completed',
                      _getCompletedCount().toString(),
                      Icons.check_circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showBookAppointmentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Book New Appointment'),
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
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'All'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentsList('upcoming'),
              _buildAppointmentsList('past'),
              _buildAppointmentsList('all'),
            ],
          ),
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

  int _getUpcomingCount() {
    return _appointments
        .where((apt) => DateTime.parse(apt['appointment_date']).isAfter(DateTime.now()) && apt['status'] != 'cancelled')
        .length;
  }

  int _getCompletedCount() {
    return _appointments
        .where((apt) => apt['status'] == 'completed')
        .length;
  }

  Widget _buildAppointmentsList(String filter) {
    List<Map<String, dynamic>> filteredAppointments;
    final now = DateTime.now();

    switch (filter) {
      case 'upcoming':
        filteredAppointments = _appointments
            .where((apt) => 
                DateTime.parse(apt['appointment_date']).isAfter(now) && 
                apt['status'] != 'cancelled')
            .toList();
        break;
      case 'past':
        filteredAppointments = _appointments
            .where((apt) => 
                DateTime.parse(apt['appointment_date']).isBefore(now) ||
                apt['status'] == 'completed' ||
                apt['status'] == 'cancelled')
            .toList();
        break;
      default:
        filteredAppointments = _appointments;
    }

    // Sort by date
    filteredAppointments.sort((a, b) {
      final dateA = DateTime.parse(a['appointment_date']);
      final dateB = DateTime.parse(b['appointment_date']);
      return filter == 'upcoming' ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    if (filteredAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filter == 'upcoming' ? Icons.event_available : Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              filter == 'upcoming' 
                  ? 'No upcoming appointments' 
                  : 'No past appointments',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Text(
              'Your appointments will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAppointments.length,
      itemBuilder: (context, index) {
        final appointment = filteredAppointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final appointmentDate = DateTime.parse(appointment['appointment_date']);
    final isUpcoming = appointmentDate.isAfter(DateTime.now());
    final status = appointment['status'];

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUpcoming && status == 'confirmed' 
            ? const BorderSide(color: AppTheme.primaryBlue, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['doctor_name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        appointment['specialty'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  appointment['appointment_time'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payment, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '₹${appointment['fee'].toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (appointment['location'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appointment['location'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        appointment['notes'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (appointment['phone'] != null) ...[
                  TextButton.icon(
                    onPressed: () => _showContactDialog(appointment),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Contact'),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: () => _viewAppointmentDetails(appointment),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                if (isUpcoming && status == 'confirmed') ...[
                  ElevatedButton.icon(
                    onPressed: () => _rescheduleAppointment(appointment),
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('Reschedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ] else if (status == 'completed') ...[
                  ElevatedButton.icon(
                    onPressed: () => _bookFollowUp(appointment),
                    icon: const Icon(Icons.event_repeat, size: 16),
                    label: const Text('Book Follow-up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookAppointmentDialog() {
    final doctorController = TextEditingController();
    final specialtyController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Book New Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Doctor',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Dr. Sarah Johnson - Cardiologist',
                    'Dr. Michael Chen - General Physician',
                    'Dr. Priya Sharma - Dermatologist',
                    'Dr. Rajesh Kumar - Orthopedist',
                    'Dr. Anjali Patel - ENT Specialist',
                  ].map((doctor) => DropdownMenuItem(value: doctor, child: Text(doctor))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final parts = value.split(' - ');
                      doctorController.text = parts[0];
                      specialtyController.text = parts[1];
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            selectedTime.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Describe your symptoms or reason for visit',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: doctorController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _confirmAppointmentBooking(
                        doctorController.text,
                        specialtyController.text,
                        selectedDate,
                        selectedTime,
                        notesController.text,
                      );
                    },
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAppointmentBooking(
    String doctor,
    String specialty,
    DateTime date,
    TimeOfDay time,
    String notes,
  ) {
    // Add to demo appointments list
    setState(() {
      _appointments.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'doctor_name': doctor,
        'specialty': specialty,
        'appointment_date': date.toIso8601String(),
        'appointment_time': time.format(context),
        'status': 'confirmed',
        'type': 'consultation',
        'notes': notes,
        'location': 'LifeSprout Medical Center',
        'phone': '+91 98765 43210',
        'fee': 400.0,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment booked successfully! You will receive a confirmation call.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _viewAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Doctor', appointment['doctor_name']),
              _buildDetailRow('Specialty', appointment['specialty']),
              _buildDetailRow('Date', DateTime.parse(appointment['appointment_date']).toString().split(' ')[0]),
              _buildDetailRow('Time', appointment['appointment_time']),
              _buildDetailRow('Status', appointment['status'].toUpperCase()),
              _buildDetailRow('Fee', '₹${appointment['fee'].toStringAsFixed(0)}'),
              if (appointment['location'] != null)
                _buildDetailRow('Location', appointment['location']),
              if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
                _buildDetailRow('Notes', appointment['notes']),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showContactDialog(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Doctor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact ${appointment['doctor_name']}'),
            const SizedBox(height: 16),
            Text('Phone: ${appointment['phone']}'),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
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
                  content: Text('Calling... (Demo feature)'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  void _rescheduleAppointment(Map<String, dynamic> appointment) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reschedule feature would be implemented here'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _bookFollowUp(Map<String, dynamic> appointment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Book follow-up with ${appointment['doctor_name']}'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'Book',
          textColor: Colors.white,
          onPressed: _showBookAppointmentDialog,
        ),
      ),
    );
  }
}