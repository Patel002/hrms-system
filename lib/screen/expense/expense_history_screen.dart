import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:photo_view/photo_view.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/cupertino.dart';
import '../utils/user_session.dart';
import 'expense_details_update.dart';
import '../helper/top_snackbar.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

  class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> with TickerProviderStateMixin {

  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  String? emId, emUsername, compFname, compId, department;
  List expenseList = [];
  Map<String, dynamic> userList= {};
  DateTime? selectedDate;
  String? errorMessage;
  bool isLoading = true;
  bool isFirstLoadDone = false; 
  late TabController _tabController;
  String selectedStatus = "pending"; 
  Set<String> selectedExpense= {};
  bool selectionMode = false;

  @override
  void initState() {
    _tabController = TabController(length:3, vsync: this);
    super.initState();

   selectedStatus = _getStatusFromIndex(_tabController.index);

   _tabController.addListener(() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        selectedStatus = _getStatusFromIndex(_tabController.index);
        isLoading = true;
      });

      final fromDate = firstDayOfMonth(selectedDate ?? DateTime.now());
      final toDate = lastDayOfMonth(selectedDate ?? DateTime.now());

      fetchExpenseData(fromDate, toDate, selectedStatus);
    }
  });

    final today = DateTime.now();
    selectedDate = today;
    final fromDate = firstDayOfMonth(today);
    final toDate = lastDayOfMonth(today);

    fetchExpenseData(fromDate, toDate, selectedStatus);
}

  String _getStatusFromIndex(int index) {
    switch (index) {
      case 0:
        return "pending";
      case 1:
        return "approved";
      case 2:
        return "rejected";
      default:
        return "pending";
    }
  }

  String getFormattedDate(String dateString) {
    try {
    DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(dateString);
    return DateFormat('dd-MMM').format(parsedDate);
    } catch (e) {
      return "Invalid Date"; 
    }
  }

  DateTime firstDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month, 1);
}

DateTime lastDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month + 1, 0);
}


  Future<void> _selectMonth(BuildContext context) async {
  final DateTime? picked = await showMonthPicker(
    context: context,
    initialDate: selectedDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    monthPickerDialogSettings: MonthPickerDialogSettings(
    headerSettings: PickerHeaderSettings(
    headerBackgroundColor: Colors.black87,
    headerCurrentPageTextStyle : TextStyle(
    color: Colors.grey,
    fontWeight: FontWeight.bold,
  ), 
),
    dialogSettings: PickerDialogSettings(
    dialogBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
  ),

  dateButtonsSettings: PickerDateButtonsSettings(
  selectedMonthBackgroundColor: Theme.of(context).iconTheme.color,
  selectedMonthTextColor: Theme.of(context).scaffoldBackgroundColor,
  unselectedMonthsTextColor: Theme.of(context).iconTheme.color,
  currentMonthTextColor: Colors.green,
  ),

    actionBarSettings: PickerActionBarSettings(
      confirmWidget: Text(
        'Done',
        style: TextStyle(
          color: Theme.of(context).iconTheme.color,
          fontWeight: FontWeight.bold,
        ),
      ),

    cancelWidget: Text(
      'Cancel',
      style: TextStyle(
        color: Theme.of(context).iconTheme.color,
        fontWeight: FontWeight.bold,
      ),
    )
    ),
  )
);

  if (picked != null) {
    final firstDay = DateTime(picked.year, picked.month, 1);
    final lastDay = DateTime(picked.year, picked.month + 1, 0);

    setState(() {
      isLoading = true;
      selectedDate = picked;
    });

    await fetchExpenseData(firstDay, lastDay, selectedStatus);

    setState(() {
      isLoading = false;
    });
  }
}


  Future<void> fetchExpenseData(DateTime fromDate, DateTime toDate,String approvedStatus) async {
    try { 

    final statusMap = {
        'pending': 'PENDING',
        'approved': 'APPROVED',
        'rejected': 'REJECTED',
      }; 

      final token = await UserSession.getToken();

      if(token == null){
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      emId = await UserSession.getUserId();
     
      print("emp_id: $emId");

      final formattedFromDate =
        "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}";
      final formattedToDate =
        "${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}";


      final apiStatus = statusMap[approvedStatus] ?? '';  

      final url = Uri.parse(
        '$baseUrl/MyApis/expensetherecords?from_date=$formattedFromDate&to_date=$formattedToDate&approval_status=$apiStatus&fetch_type=SELF',
      );
      print("URL: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': token,
          'user_id': emId!
        },
      );

      print("Response Status Code: ${response.statusCode}");
      print("url: $response");
      print("body: ${response.body}");

      final jsonData = json.decode(response.body);

       await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

     if (response.statusCode == 200) {
        if (jsonData['data_packet'] != null && jsonData['data_packet'] is List) {
          expenseList = jsonData['data_packet'];
          userList = jsonData['user_details'] ?? {};

        
          userList = userList['name'] ?? 'N/A';
          print("Expenser Name: $userList");
          print("Expense List: $expenseList");
          
        } else {
          expenseList = [];
          userList = {};
        }

      await Future.delayed(Duration(seconds: 2));

        setState(() {
          isLoading = false;
          isFirstLoadDone = true;
        });
      } else {
        throw Exception(
          "Failed to load Expense data, status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isFirstLoadDone = true;
        errorMessage = e.toString();
      });
    }
  }


 Future<bool> deleteExpense(String expenseId) async {
  try {
    final _token = await UserSession.getToken();
    final _empId = await UserSession.getUserId();

    if (_token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    final url = Uri.parse('$baseUrl/MyApis/expensethedelete?id=$expenseId');

    print('URL: $url');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiToken',
        'auth_token': _token,
        'user_id': _empId!,
      },
    );

    await UserSession.checkInvalidAuthToken(
      context,
      json.decode(response.body),
      response.statusCode,
    );

    if (response.statusCode == 200) {
      // showCustomSnackBar(context, "expense deleted successfully", Colors.green, Icons.check_circle);
      // _refreshData();
      return true;
    } else {
      print('Failed to delete expense: ${response.body}');
      showCustomSnackBar(context, "Failed to delete expense", Colors.red, Icons.error);
      return false;
    }
  } catch (e) {
    showCustomSnackBar(context, "Error: $e", Colors.red, Icons.error);
    return false;
  }
}


 Future<void> deleteMultipleExpenses(List<String> exspenseId) async {
  int successCount = 0;

  print('sccesscount,$successCount');

  for (String id in exspenseId) {
    bool success = await deleteExpense(id);

    print('sccesscount1,$success');
    if (success) successCount++;
  }

  if (mounted) {
    setState(() {
      selectionMode = false;
      selectedExpense.clear();
    });

    if (successCount > 0) {
      showCustomSnackBar(
        context,
        "$successCount expense(s) deleted successfully",
        Colors.green,
        Icons.check_circle,
      );
    } else {
      showCustomSnackBar(
        context,
        "Failed to delete selected expesne(s)",
        Colors.red,
        Icons.error,
      );
      print("Failed to delete selected expesne(s), success count: $successCount");
    }
  }
}

Future<void> _confirmDelete(List<String> expesneIds) async {
  bool isDeleting = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
               Lottie.asset(
                  'assets/icon/trash.json',
                  repeat: true,
                  height: 125,
                  ),
                const SizedBox(height: 16),
                const Text(
                  "Delete expesne(s)?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "expesne has deleted parmanently from your device.you can't restore them once deleted from your device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // TextButton(
                    //   onPressed: isDeleting
                    //       ? null
                    //       : () {
                    //           Navigator.pop(context);
                    //         },
                    //   child: const Text("Cancel"),
                    // ),
                    // const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.delete),
                      label: Text(isDeleting ? "Deleting..." : "Delete"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: isDeleting
                          ? null
                          : () async {
                              setModalState(() {
                                isDeleting = true;
                              });

                              try {
                                await deleteMultipleExpenses(expesneIds);
                                if (mounted) {
                                  Navigator.pop(context);

                                  await fetchExpenseData(
                                  firstDayOfMonth(selectedDate ?? DateTime.now()),
                                  lastDayOfMonth(selectedDate ?? DateTime.now()),
                                  selectedStatus,
                                );
                              }
                            } catch (e) {
                                setModalState(() {
                                  isDeleting = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Failed to delete expesne(s): $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// void showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {
//     final scaffoldMessenger = ScaffoldMessenger.of(context);

//     scaffoldMessenger.clearSnackBars();

//     final snackBar = SnackBar(
//       content: Row(
//         children: [
//           Icon(icon, color: Colors.white),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ],
//       ),
//       backgroundColor: color,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       margin: const EdgeInsets.all(16),
//       duration: const Duration(seconds: 1),
//     );

//     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//   }

    

void showImagePreview(BuildContext context, String image) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(image),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
              enableRotation: false,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuart,
      );

      final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        ),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}

  Widget buildExpenseCard(Map item) {
    final image = item['expense_img'];
    final status = item['approval_status'] ?? "PENDING";

    final statusIcon = {
    "APPROVED": Icons.verified,
    "REJECTED": Icons.cancel_outlined,
    "PENDING": FontAwesomeIcons.clockRotateLeft,
  };

  final statusColor = {
    "APPROVED": Colors.green,
    "REJECTED": Colors.red,
    "PENDING": Colors.orange,
  };

    // print("image expense history:${item['expense_img']}");
          return InkWell(
            // behavior: HitTestBehavior.opaque,
            onLongPress: () {
              if(status == "PENDING") {
              setState(() {
                selectionMode = true;
                selectedExpense.add(item['id'].toString());
              });
            }
            },
            onTap: () {
               if (status == "PENDING" && selectionMode) {
                setState(() {
                  final id = item['id'].toString();
                  if (selectedExpense.contains(id)) {
                    selectedExpense.remove(id);
                    if (selectedExpense.isEmpty) selectionMode = false;
                  } else {
                    selectedExpense.add(id);
                  }
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExpenseHistoryDetails(item:item),
                  ),
                );
              }
            },
    child: Card(
    margin: EdgeInsets.all(10),
      color: selectedExpense.contains(item['id'].toString())
      ? (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2E) 
          : const Color(0xFFE4EBF5)) 
      : (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E) 
          : const Color(0xFFF5F7FA)), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),

            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == "PENDING" && selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                selectedExpense.contains(item['id'].toString())
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selectedExpense.contains(item['id'].toString())
                    ? Colors.blue
                    : Colors.grey,
              ),
            ),          
            Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "₹${item['expense_amount'] ?? ''}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['exp_description'] ?? "",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  item['expense_name'] ?? "",
                  style: const TextStyle(fontSize: 14,fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      getFormattedDate(item['exp_date_formatted'] ?? ""),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: statusColor[status]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon[status],
                      color: statusColor[status],
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor[status],
                      ),
                    ),
                  ],
                ),
              ),

              buildImageOrPlaceholder(image, context),
            ],
          ),
        ],
      ),
    ),
  ),
 );
}


  @override
  Widget build(BuildContext context) {
    final filteredList = expenseList.where((item) {
      return item['approval_status']?.toString().toUpperCase() == selectedStatus.toUpperCase();
       }).toList();

     print("Filtered List: $filteredList");

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
      backgroundColor: Colors.transparent,
      forceMaterialTransparency: true,
      foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
      elevation: 0,
      leading: selectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  selectionMode = false;
                  selectedExpense.clear();
                });
              },
            )
          : null,

      title: selectionMode
          ?  Text(
              "${selectedExpense.length} Selected",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            )
          : Row(
              children: [
                 Text(
                  "Expense History",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _selectMonth(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFF2F5F8),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      selectedDate == null
                          ? DateFormat('MM').format(DateTime.now())
                          : DateFormat('MM').format(selectedDate!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),

      actions: selectionMode
          ? [
              IconButton(
                icon: const Icon(FontAwesomeIcons.trashCan,size: 18.0),
                onPressed: () async {
                  if (selectedExpense.isNotEmpty) {
                    _confirmDelete(selectedExpense.toList());
                  }
                },
              ),
            ]
          : [],
    ),

      body: Stack( 
       children: [
        Container(
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
      ),

      Column(
        children: [
          TabBar(
          controller: _tabController,
          indicatorColor: _tabController.index == 0 ? Colors.orange : _tabController.index == 1 ? Colors.green : Colors.red,
          labelColor: Theme.of(context).iconTheme.color,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
 
          const SizedBox(height: 8),

          Expanded(
            child:
                isLoading
                    ? Center(child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color,))
                    : isFirstLoadDone
                    ? expenseList.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/image/Animation.json',
                              width: 200,
                              height: 200,
                              repeat: true,
                              fit: BoxFit.cover
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "No Expense Records Found !",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : RefreshIndicator(
                       color: Theme.of(context).iconTheme.color,
                       backgroundColor: Theme.of(context).scaffoldBackgroundColor ,
                      onRefresh: () async {
                        await fetchExpenseData(
                        firstDayOfMonth(selectedDate ?? DateTime.now()),
                        lastDayOfMonth(selectedDate ?? DateTime.now()),
                        selectedStatus,
                      );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {

                          print('Open Filtered List:-$filteredList');

                          return buildExpenseCard(filteredList[index]);
                        },
                      ),
                    )
                    : const SizedBox(), 
          ),
        ],
      )
       ],
      )
    );
  }


Widget buildImageOrPlaceholder(String? image, BuildContext context) {
  try {
    if (image != null && image.isNotEmpty) {
      if (image.contains('data:image')) {
        // Base64 image
        final imageBytes = base64Decode(image.split(',').last);
        return GestureDetector(
          onTap: () => showImagePreview(context, image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageBytes,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        // URL
        return GestureDetector(
          onTap: () => showImagePreview(context, image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              image,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderContainer();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 80,
                  width: 80,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).iconTheme.color,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes!)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      return _buildPlaceholderContainer();
    }
  } catch (e) {
    print("Image load error: $e");
    return _buildPlaceholderContainer();
  }
}

Widget _buildPlaceholderContainer() {
  return Container(
    height: 95,
    width: 95,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.image_not_supported,
      size: 40,
      color: Colors.grey,
    ),
  );
}
}
