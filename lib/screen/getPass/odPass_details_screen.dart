import 'package:flutter/material.dart';
class OdDetailPage extends StatelessWidget {
  final Map<String, dynamic> od;
  final void Function(String action, [String? rejectreason]) onAction;
  final bool showActions;

  OdDetailPage({
    super.key, 
    required this.od,
    required this.onAction,
    this.showActions = false,
  });


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = od['approval_status'] ?? 'pending';
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
        title: const Text("On-Duty Details", style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: false,
        forceMaterialTransparency: true,
        elevation: 2,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
                child: Card(
                  color:Theme.of(context).brightness == Brightness.light ? Color(0xFFF2F5F8) : Colors.grey.shade900,
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
                        _buildInfoTile(context,Icons.badge_outlined, "Employee ID", od['emp_id'].toString()),
                        _buildInfoTile(context,Icons.person, "Name",od['empname']),
                        _buildInfoTile(context,Icons.business_outlined, "Company",od['compname']),
                        _buildInfoTile(context,Icons.credit_card_outlined, "Department",od['dep_name']),
                        
                        const Divider(height: 32),
                        
                        _buildSectionHeader(Icons.date_range_outlined, 'Od Dates'),
                        _buildInfoTile(context,Icons.play_circle_outline, "Start Date", od['fromdate']),
                        _buildInfoTile(context,Icons.stop_circle_outlined, "End Date", od['todate']),
                        _buildInfoTile(context,Icons.timelapse_outlined, "Duration", "${od['oddays']} day(s)"),
                        
                        const Divider(height: 32),
                        
                        _buildInfoTile(context,Icons.note_outlined, "Reason", od['remark']),

                        if (od['approval_status'] == 'REJECTED' && od['rejectreason'] != null && od['rejectreason'] != '') ... [
                        _buildInfoTile(context,Icons.block_outlined, "Reject Reason", od['rejectreason'], color: Colors.red),

                        _buildInfoTile(context,Icons.confirmation_num, "Rejected By", od['approval_by'], color: Colors.red),

                        _buildInfoTile(context,Icons.timer, "Rejected At", od['approval_at'], color: Colors.red),
                        ],

                        if(od['approval_status'] == 'APPROVED') ...[
                          _buildInfoTile(context,Icons.confirmation_num, "Approved By", od['approval_by'], color: Colors.green),
                          _buildInfoTile(context,Icons.timer, "Approved At", od['approval_at'], color: Colors.green),
                        ],
                        
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

  Widget _buildInfoTile(
  BuildContext context,
  IconData icon,
  String label,
  String value, {
  Color? color,
  VoidCallback? onTap,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                if (label.isNotEmpty) const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color ?? theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
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
