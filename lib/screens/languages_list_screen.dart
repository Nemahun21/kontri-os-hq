import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/languages_management_screen.dart';
// If LanguagesManagementScreen is already “list of languages”, use it directly:

class LanguagesListScreen extends StatelessWidget {
  const LanguagesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse existing management list (names + counts)
    return const LanguagesManagementScreen();
  }
}