import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/user_session.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:convert';


class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  String? bankHolderName, bankName, accountNumber, ifscCode, accountType, branchName;

  bool isLoading = false;
  bool _showAccountNumber = false;
  bool _showIfscCode = false;

  @override
  void initState() {
    super.initState();
    _secure();
    fetchBankAccountDetails();
    Future.delayed(const Duration(seconds: 2), () {
    setState(() {
      isLoading = false;
    });
  });
}

  Future<void> _secure() async {
    await ScreenProtector.preventScreenshotOn();
  }


  Future<void> fetchBankAccountDetails() async {

    setState(() => isLoading = true);

    final token = await UserSession.getToken();

    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    try {
      
      final uri = Uri.parse('$baseUrl/MyApis/getthebankinfo');

      final response = await http.get(uri,headers: {
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data_packet'];
        setState(() {
          bankHolderName = data['holder_name'];
          bankName = data['bank_name'];
          accountNumber = data['account_number'];
          ifscCode = data['ifsc_code'];
          accountType = data['account_type'];
          branchName = data['branch_name'];
          isLoading = false;
        });
      } else {
      debugPrint('Failed to load bank account details: ${response.body}');
      final errorData = json.decode(response.body);
      String errorMessage = errorData['message'] ?? 'An error occurred';
      _showCustomSnackBar(context, errorMessage, Colors.red, Icons.error);
      setState(() => isLoading = false);
    }

    } catch (e) {
       _showCustomSnackBar(context, e.toString(), Colors.red, Icons.error);
       setState(() => isLoading = false);
    }
  }

@override
void dispose() {
  ScreenProtector.preventScreenshotOff();
  super.dispose();
}

void _showCustomSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Theme.of(context).scaffoldBackgroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 16),
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


  String _maskText(String? text, {int visibleDigits = 4}) {
    if (text == null || text.isEmpty) return "-";
    if (text.length <= visibleDigits) return text;
    final masked = "*" * (text.length - visibleDigits);
    return "$masked${text.substring(text.length - visibleDigits)}";
  }


Widget _buildGlassTile(String title, String? value, IconData icon, {bool isSensitive = false, bool isIfsc = false}) {

  bool isVisible = isSensitive
        ? (isIfsc ? _showIfscCode : _showAccountNumber)
        : true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.85),
            Colors.white.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue.shade100,
            child: Icon(icon, color: Colors.lightBlue.shade300),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).iconTheme.color,
                    )),
                const SizedBox(height: 4),
                Text(
                  isSensitive
                      ? (isVisible ? value ?? "-" : _maskText(value))
                      : (value ?? "-"),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color:  Theme.of(context).iconTheme.color,
                  ),
                ),
              ],
            ),
          ),
          if (isSensitive)
            IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.blue.shade800,
              ),
              onPressed: () {
                setState(() {
                  if (isIfsc) {
                    _showIfscCode = !_showIfscCode;
                    if (_showIfscCode) {
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) {
                          setState(() => _showIfscCode = false);
                        }
                      });
                    }
                  } else {
                    _showAccountNumber = !_showAccountNumber;
                    if (_showAccountNumber) {
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) {
                          setState(() => _showAccountNumber = false);
                        }
                      });
                    }
                  }
                });
              },
            ),
          ],
        ),
      );
    }

  Widget _buildShimmerTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
        child: ListView(
          padding: const EdgeInsets.only(top: 25, bottom: 40),
          children: [
           if (isLoading) ...[
              _buildShimmerTile(),
              _buildShimmerTile(),
              _buildShimmerTile(),
              _buildShimmerTile(),
              _buildShimmerTile(),
              _buildShimmerTile(),
            ] else ...[
              _buildGlassTile("Account Holder", bankHolderName, Icons.person),
              _buildGlassTile("Bank Name", bankName, Icons.account_balance), 

              _buildGlassTile("Account Number", accountNumber, Icons.numbers, isSensitive: true),

              _buildGlassTile("IFSC Code", ifscCode, Icons.qr_code,
              isSensitive: true, isIfsc: true),

              _buildGlassTile("Account Type", accountType, Icons.credit_card),
              _buildGlassTile("Branch Name", branchName, Icons.location_city),
            ],
          ],
        ),
      ),
    );
  }
}