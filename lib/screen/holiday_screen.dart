import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HolidayScreen extends StatefulWidget {
  const HolidayScreen({super.key});

  @override
  State<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends State<HolidayScreen> {
  List<dynamic> _holidays = [];
  bool _isLoading = true;
  String? _error;
  final baseUrl = dotenv.env['API_BASE_URL'];


  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    final url = Uri.parse('$baseUrl/api/holiday/holiday');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _holidays = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load holidays';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String date) {
    final parsedDate = DateTime.parse(date);
    return '${parsedDate.day.toString().padLeft(2, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Holiday List')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
           : RefreshIndicator(
                onRefresh: _fetchHolidays,
                color: Colors.black,
                backgroundColor: Colors.white,
                child: _holidays.isEmpty
              ? ListView(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
              )
              : ListView.builder(
                  itemCount: _holidays.length,
                  itemBuilder: (context, index) {
                    final holiday = _holidays[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          radius: 24,
                          child: Text(
                            holiday['holiday_name'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(
                          holiday['holiday_name'],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'From: ${_formatDate(holiday['from_date'])}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'To: ${_formatDate(holiday['to_date'])}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Number of Days: ${holiday['number_of_days']}',
                              style: const TextStyle(color: Colors.green),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Year: ${holiday['year']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    ),
    );
  }
}
