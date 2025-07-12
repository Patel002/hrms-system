import 'package:flutter/material.dart';

class AttendanceSummaryWidget extends StatelessWidget {
  final String workingHours;
  final int presentDays;
  final int leaveDays;
  final int absentDays;

  const AttendanceSummaryWidget({
    super.key,
    required this.workingHours,
    required this.presentDays,
    required this.leaveDays,
    required this.absentDays,
  });

  @override
  Widget build(BuildContext context) {
    // final TextStyle valueStyle = TextStyle(
    //   fontSize: 22,
    //   fontWeight: FontWeight.bold,
    //   color: Colors.black87,
    // );

    // final TextStyle labelStyle = TextStyle(
    //   fontSize: 14,
    //   color: Colors.grey[600],
    // );

    Widget buildCard(String label, IconData icon, Color color, String value) {
        return Expanded(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            shadowColor: color.withOpacity(0.4),
            child: Padding(

              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.11),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),

                      Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                         ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }


    return Column(
      children: [
        Row(
          children: [
            buildCard('Working Days', Icons.work, Colors.blue.shade600, workingHours),
            const SizedBox(width: 10),
            buildCard('Present', Icons.emoji_people_sharp, Colors.green, '$presentDays'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            buildCard('Leave', Icons.work_off, Colors.orange, '$leaveDays'),
            const SizedBox(width: 10),
            buildCard('Absent', Icons.timer_off_rounded, Colors.red, '$absentDays'),
          ],
        ),  
      ],
    );
  }
}
