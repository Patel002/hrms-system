import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../helper/top_snackbar.dart';

class ExpenseRequestDetails extends StatelessWidget {

  final Map<String, dynamic> expense;
  final void Function(String action, [String? reason]) onAction;
  final baseUrl = dotenv.env['API_BASE_URL'];

  ExpenseRequestDetails({super.key, 
    required this.expense,
    required this.onAction,
  });

    void _launchMap(BuildContext context,String latitude, String longitude) async {
    final url =
        "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar(context, 'Cannot open map', Colors.red, Icons.error);

    }
  }

    @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = expense['approval_status'] ?? 'PENDING';

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Expense Request Details", style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: false,
        elevation: 0,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
        forceMaterialTransparency: true,
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
                        
                        // expense Type
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(child: Text(expense['expense_name'] ?? ''))
                            ],
                          )
                        ),

                        const SizedBox(height: 8),
                        const Divider(height: 32),
                    
                        _buildSectionHeader(Icons.person_outline, 'Employee Information'),
                        _buildInfoTile(context,Icons.badge_outlined, "Employee ID", expense['emp_id'].toString()),
                        _buildInfoTile(context,Icons.person, "Employee", expense['empname']),
                        _buildInfoTile(context,Icons.business_outlined, "Company", expense['compname']),
                        _buildInfoTile(context,Icons.construction, "Department", expense['dep_name']),
                        
                        const Divider(height: 32),
                        
                        _buildSectionHeader(Icons.date_range_outlined, 'expense Information'),
              
                        _buildInfoTile(context,Icons.timelapse_outlined, "Date", "${expense['exp_date_formatted']}"),

                        _buildInfoTile(context,Icons.currency_rupee, "Amount", "${expense['expense_amount']}"),
                        
                        _buildInfoTile(context,Icons.note_outlined, "Description", expense['exp_description']),

                        if (expense['approval_status'] == 'REJECTED' && expense['rejectreason'] != null && expense['rejectreason'] != '') ...[
                          _buildInfoTile(context,Icons.block_outlined, "Reject Reason", expense['rejectreason'], color: Colors.red),

                        _buildInfoTile(context,Icons.confirmation_num, "Rejected By", expense['approval_by'], color: Colors.red),

                        _buildInfoTile(context,Icons.timer, "Rejected At", expense['approval_at'], color: Colors.red),
                        ],

                       if(expense['approval_status'] == 'APPROVED') ...[
                          _buildInfoTile(context,Icons.confirmation_num, "Approved By", expense['approval_by'], color: Colors.green),

                          _buildInfoTile(context,Icons.timer, "Approved At", expense['approval_at'], color: Colors.green),

                          _buildInfoTile(context,FontAwesomeIcons.rupeeSign, "Approved Amount", expense['approve_amt'], color: Colors.green),
                       ],

                        const SizedBox(height: 16),

                 if (expense['latitude'] != null && expense['longitude'] != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      elevation: 2,
                    ),
                    onPressed: () => _launchMap(context,expense['latitude'], expense['longitude']),
                    icon: const Icon(FontAwesomeIcons.locationCrosshairs, size: 16),
                    label: const Text(
                      "View Location",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
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


  IconData _getStatusIcon(String status) {
    if (status.toLowerCase() == 'approved') {
      return Icons.verified;
    } else if (status.toLowerCase() == 'rejected') {
      return Icons.cancel_outlined;
    } else {
      return Icons.pending_outlined;
    }
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'approved') {
      return Colors.green.withOpacity(0.1);
    } else if (status.toLowerCase() == 'rejected') {
      return Colors.red.withOpacity(0.1);
    } else {
      return Colors.orange.withOpacity(0.1);
    }
  }

  Color _getStatusTextColor(String status) {
    if (status.toLowerCase() == 'approved') {
      return Colors.green;
    } else if (status.toLowerCase() == 'rejected') {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }
}