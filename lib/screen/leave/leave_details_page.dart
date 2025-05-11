import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
// import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LeaveDetailPage extends StatelessWidget {
  final Map<String, dynamic> leave;
  final String? departmentName;
  final String employeeCode;
  final String compFname;
  final void Function(String action, [String? reason]) onAction;
  final baseUrl = dotenv.env['API_BASE_URL'];

  LeaveDetailPage({
    required this.leave,
    this.departmentName,
    required this.employeeCode,
    required this.compFname,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = leave['leave_status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave Details"),
        centerTitle: false,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: IntrinsicHeight(
                child: Card(
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
                        // Status Badge
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
                        
                        // Leave Type
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(child: Text(leave['leave_type'] ?? ''))
                            ],
                          )
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 32),
                        
                        // Employee Information Section
                        _buildSectionHeader(Icons.person_outline, 'Employee Information'),
                        _buildInfoTile(Icons.badge_outlined, "Employee ID", leave['em_id'].toString()),
                        _buildInfoTile(Icons.credit_card_outlined, "Employee Code", employeeCode),
                        _buildInfoTile(Icons.business_outlined, "Company Name", compFname),
                        if (departmentName != null) 
                          _buildInfoTile(Icons.group_outlined, "Department", departmentName!),
                        
                        const Divider(height: 32),
                        
                        // Leave Dates Section
                        _buildSectionHeader(Icons.date_range_outlined, 'Leave Dates'),
                        _buildInfoTile(Icons.play_circle_outline, "Start Date", leave['start_date']),
                        _buildInfoTile(Icons.stop_circle_outlined, "End Date", leave['end_date']),
                        _buildInfoTile(Icons.timelapse_outlined, "Duration", "${leave['leave_duration']} day(s)"),
                        
                        const Divider(height: 32),
                        
                        _buildInfoTile(Icons.note_outlined, "Reason", leave['reason']),

                        _buildInfoTile(Icons.attach_file_outlined, "Attachment",   leave['leaveattachment'] ?? '',
                        color: Colors.blueGrey,
                        onTap: () async {
                        print('onTap triggered');
                        final fileName = leave['leaveattachment'];
                        print('File Name: $fileName');

                        if (fileName == null || fileName.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No attachment found')),
                        );
                        return;
                        }
                        
                         print('Attachment: ${leave['leaveattachment']}');
                        final url = '$baseUrl/api/emp-leave/attachment/$fileName';
                      try {
                        final dir = await getTemporaryDirectory();
                        final filePath = '${dir.path}/$fileName';

                        await Dio().download(url, filePath);
                        final result = await OpenFile.open(filePath);
                        if (result.type != ResultType.done) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open attachment')),
                          );
                        }
                      }catch(e){
                        print('Download/open error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to download attachment')),
                        );
                      } 
                    }        
                    ),
                        if (leave['reject_reason'] != null && leave['reject_reason'] != '')
                          _buildInfoTile(Icons.block_outlined, "Reject Reason", leave['reject_reason'], color: Colors.red),
                        
                        if (status.toLowerCase() == 'pending') ...[
                          const Divider(height: 32),
                          _buildActionButtons(context),
                        ],
                      ],
                    ),
                  ),
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
    onTap: onTap,  // This makes the whole row tappable
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
    // Handle the reject action and show a dialog to input reject reason.
  }

  IconData _getStatusIcon(String status) {
    if (status.toLowerCase() == 'approved') {
      return Icons.check_circle_outline;
    } else if (status.toLowerCase() == 'rejected') {
      return Icons.cancel_outlined;
    } else {
      return Icons.pending_outlined;
    }
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'approve') {
      return Colors.green.withOpacity(0.1);
    } else if (status.toLowerCase() == 'rejected') {
      return Colors.red.withOpacity(0.1);
    } else {
      return Colors.orange.withOpacity(0.1);
    }
  }

  Color _getStatusTextColor(String status) {
    if (status.toLowerCase() == 'approve') {
      return Colors.green;
    } else if (status.toLowerCase() == 'rejected') {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }
}