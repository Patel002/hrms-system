import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/user_session.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  Map<String, String?> salaryData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getSalaryStructure();
  }

  Future<void> getSalaryStructure() async {
    final token = await UserSession.getToken();

    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    try {
      final uri = Uri.parse('$baseUrl/MyApis/getthesalary');

      print("uri of salary,$uri");

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': token,
          'user_id': empId!
        },
      );

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data_packet'];

        setState(() {
        salaryData = Map<String, String?>.from(data);
        isLoading = false;
      });

      } else {
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'An error occurred';
        _showCustomSnackBar(context, errorMessage, Colors.red, Icons.error);
      }
    } catch (e) {
      _showCustomSnackBar(context, e.toString(), Colors.red, Icons.error);
    }
  }

  void _showCustomSnackBar(
      BuildContext context, String message, Color color, IconData icon) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
  if (salaryData.isEmpty) return const SizedBox();
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 4,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Salary Summary",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem("Gross Pay", salaryData["Gross Pay"],FontAwesomeIcons.indianRupeeSign),
              _summaryItem("Net Pay", salaryData["Net Pay"], FontAwesomeIcons.handHoldingDollar),
              _summaryItem("CTC", salaryData["Monthly CTC"], FontAwesomeIcons.coins),
            ],
          )
        ],
      ),
    ),
  );
}


  Widget _summaryItem(String title, String? value, IconData icon) {
  return Column(
    children: [
      Icon(icon, color: Colors.white, size: 22),
      const SizedBox(height: 6),
      Text(title,
          style: const TextStyle(
              fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(value ?? "-",
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    ],
  );
}

Widget _buildSalaryCard(String key, String? value, {bool isAlternate = false}) {

final isDark = Theme.of(context).brightness == Brightness.dark;

final baseColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
final alternateColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50;

  return Container(
    decoration: BoxDecoration(
      color: isAlternate ? alternateColor : baseColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(key,
              style:  TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color:Theme.of(context).iconTheme.color)),
        ),
        const SizedBox(width: 12),
        Text(value ?? "-",
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.teal)),
      ],
    ),
  );
}


Widget _buildSalaryList() {
  final entries = salaryData.entries.toList();
  return RefreshIndicator(
    onRefresh: getSalaryStructure,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeaderCard()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = entries[index];
              return _buildSalaryCard(entry.key, entry.value,
                  isAlternate: index % 2 == 0);
            },
            childCount: entries.length,
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade100
        : Color(0xFF121212),
      body: SafeArea(
        child: isLoading ? _buildShimmer() : _buildSalaryList(),
      ),
    );
  }
}