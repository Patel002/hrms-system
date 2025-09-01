import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import 'utils/user_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }
  

  Future<void> _fetchHolidays() async {

    setState(() {
    _error = null;
    _isLoading = true;
  });

  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult == ConnectivityResult.none) {
    if (mounted) {
      setState(() {
        _error = 'No internet connection. Please check your network and try again.';
        _isLoading = false;
      });
    }
    return;
  }

    
    final token = await UserSession.getToken();

    if(token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final empId = await UserSession.getUserId();

    final currentYear = DateTime.now().year.toString();

    final url = Uri.parse('$baseUrl/MyApis/holidaytherecords?year=$currentYear');

    print("Url: $url");

    try {
      final response = await http.get(url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiToken',
        'auth_token': token,
        'user_id': empId!
      });

       await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      print('Response Status: ${response.body}');

      if (response.statusCode == 200) {
        final finalData = json.decode(response.body);
        final data = finalData['data_packet'];
        print('Data: $data');

       setState(() {
          _holidays = data;
          _isLoading = false;
        });     
        
      } else {
        final error = jsonDecode(response.body)['error'];
        setState(() {
          _error = 'Failed to load holidays -> $error';
          _isLoading = false;
        });
      }
}
   
    catch (e) {
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
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
       backgroundColor: Colors.transparent, 
        title: const Text(
          "Holiday",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        forceMaterialTransparency: true,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
        elevation: 0,
      ),
      body: Container(
       decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? const LinearGradient(
                      colors: [Color(0xFF121212), Color(0xFF121212)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)], 
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
            ),
      child : _isLoading
          ? ListView.builder(
          itemCount: 4,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Card(
              elevation: 2,
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[300]
                    : Colors.grey[700],
                ),
                title: Container(
                  height: 16,
                  color: Colors.grey[300],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Container(
                      height: 14,
                      width: double.infinity,
                      color: Colors.grey[300],
                    ),
                  )),
                ),
              ),
            ),
          ),
        )
          : _error != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(Icons.wifi_off, size: 100, color: Colors.grey.shade500),
            const SizedBox(height: 24),
            const Text(
              'No Internet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                // color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Seems like you are not connected to the internet',
              style: TextStyle(
                fontSize: 14,
                // color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _fetchHolidays,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Refresh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).iconTheme.color,
                foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ],
          
            ),
          )
           : RefreshIndicator(
                onRefresh: _fetchHolidays,
                color: Theme.of(context).iconTheme.color,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                padding: const EdgeInsets.all(12),
                  itemCount: _holidays.length,
                  itemBuilder: (context, index) {
                    final holiday = _holidays[index];
                    return Card(
                      elevation: 3,
                      color: Theme.of(context).brightness == Brightness.light
                      ? Color(0xFFF5F7FA)
                      : Colors.grey[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor:  Theme.of(context).brightness == Brightness.light
                          ? Color(0xFFE4EBF5)
                          : Colors.blueGrey.shade800,
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
                              'Year: ${holiday['from_date'].split('-')[0]}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    ),
    ),
    );
  }
}
