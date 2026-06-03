import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../licences/license_type.dart';
import 'loans_locked_screen.dart';
import 'loans_list_screen.dart';

class LoansGatekeeper extends StatelessWidget {
  const LoansGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Check license (Enterprise level required)
    if (provider.licenseType.level != LicenseLevel.enterprise && !provider.isPromoActive) {
      return const LoansLockedScreen();
    }

    // Show Loans List Screen
    return const LoansListScreen();
  }
}
