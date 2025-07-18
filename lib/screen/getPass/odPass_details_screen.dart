import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OdDetailPage extends StatelessWidget {
  final Map<String, dynamic> od;
  // final String? departmentName;
  // final String compFname;
  final void Function(String action, [String? rejectreason]) onAction;
  final bool showActions;
  final baseUrl = dotenv.env['API_BASE_URL'];

  OdDetailPage({
    super.key, 
    required this.od,
    required this.onAction,
    // required this.departmentName,
    // required this.compFname,
    this.showActions = false,
  });


    @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = od['approved'] ?? 'pending';
    return Scaffold(
      backgroundColor: Color(0xFFF2F5F8),
      appBar: AppBar(
        title: const Text("Od Pass Details", style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: false,
        forceMaterialTransparency: true,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                size: 16,
                                color: _getStatusTextColor(status),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                status.toUpperCase(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _getStatusTextColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                    
                        _buildSectionHeader(Icons.person_outline, 'Employee Information'),
                        _buildInfoTile(Icons.badge_outlined, "Employee ID", od['emp_id'].toString()),
                        _buildInfoTile(Icons.business_outlined, "Company Name", od['employee']?['company']?['comp_fname'] ?? '-'),
                        _buildInfoTile(Icons.credit_card_outlined, "Department Name", od['employee']?['department']?['dep_name'] ?? '-'),

                        
                        const Divider(height: 32),
                        
                        _buildSectionHeader(Icons.date_range_outlined, 'Od Dates'),
                        _buildInfoTile(Icons.play_circle_outline, "Start Date", od['fromdate']),
                        _buildInfoTile(Icons.stop_circle_outlined, "End Date", od['todate']),
                        _buildInfoTile(Icons.timelapse_outlined, "Duration", "${od['oddays']} day(s)"),
                        
                        const Divider(height: 32),
                        
                        _buildInfoTile(Icons.note_outlined, "Reason", od['remark']),

                        if ((od['rejectreason'] != null && od['rejectreason'] != '') &&
                        status.toLowerCase().trim() == 'rejected')
                        _buildInfoTile(Icons.block_outlined, "Reject Reason", od['rejectreason'], color: Colors.red),
                        
                        if (showActions && status.toLowerCase().trim() == 'pending') ...[
                          const Divider(height: 32),
                          _buildActionButtons(context),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {
  Color color = Colors.black, 
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap, 
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty) Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                if (label.isNotEmpty) const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(color: color, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildActionButtons(BuildContext context) {
  return Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 20),
          onPressed: () => onAction('approve'),
          label: const Text("Approve"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            textStyle: const TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.cancel_outlined, size: 20),
          onPressed: () => _showRejectDialog(context),
          label: const Text("Reject"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            textStyle: const TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ),
    ],
  );
} 
  void _showRejectDialog(BuildContext context) {
  }

  IconData _getStatusIcon(String status) {
    if (status.toLowerCase().trim() == 'approved') {
      return Icons.verified;
    } else if (status.toLowerCase().trim() == 'rejected') {
      return Icons.cancel_outlined;
    } else {
      return Icons.pending_outlined;
    }
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase().trim() == 'approved') {
      return Colors.green.withOpacity(0.1);
    } else if (status.toLowerCase().trim() == 'rejected') {
      return Colors.red.withOpacity(0.1);
    } else {
      return Colors.orange.withOpacity(0.1);
    }
  }

  Color _getStatusTextColor(String status) {
    if (status.toLowerCase().trim() == 'approved') {
      return Colors.green;
    } else if (status.toLowerCase().trim() == 'rejected') {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }
}
