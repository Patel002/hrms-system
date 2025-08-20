import 'package:flutter/material.dart';
import './user_info_screen.dart';

class SwipFunction extends StatefulWidget {
  const SwipFunction({super.key});

  @override
  State<SwipFunction> createState() => _SwipFunctionState();
}

class _SwipFunctionState extends State<SwipFunction> with TickerProviderStateMixin {
  late TabController _tabController;

  final List<String> sections = ['Profile', 'Account','Documents','Salary','Letter'];

  String selectedSection = "Profile";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: sections.length, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging == false) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
        setState(() {
          selectedSection = sections[_tabController.index];
        });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onDropdownChanged(String? value) {
    if (value != null) {
      setState(() {
        selectedSection = value;
      });

      final index = sections.indexOf(value);
      _tabController.animateTo(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F5F8),
        centerTitle: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: DropdownButton<String>(
            key: ValueKey<String>(selectedSection),
            value: selectedSection,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            dropdownColor: Colors.white,
            onChanged: _onDropdownChanged,
            items: sections.map((section) {
              return DropdownMenuItem(
                value: section,
                child: Text(section),
              );
            }).toList(),
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
            UserInfo(),
            _buildAccountPage(),
            _buildDocumentsPage(),
            _buildSalaryPage(),
            _buildLetterPage(),
        ]
      ),
    );
  }

  Widget _buildAccountPage() {
  return const Center(
    child: Text("Account Information", style: TextStyle(fontSize: 20)),
  );
}

Widget _buildDocumentsPage() {
  return const Center(
    child: Text("Documents Page", style: TextStyle(fontSize: 20)),
  );
}

Widget _buildSalaryPage() {
  return const Center(
    child: Text("Salary Details", style: TextStyle(fontSize: 20)),
  );
}

Widget _buildLetterPage() {
  return const Center(
    child: Text("Letters Section", style: TextStyle(fontSize: 20)),
  );
}

}
