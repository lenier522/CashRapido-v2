import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'business_locked_screen.dart';
import 'business_list_screen.dart';

class BusinessGatekeeper extends StatelessWidget {
  const BusinessGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Check license (Pro or Enterprise required)
    if (provider.licenseType != LicenseType.pro &&
        provider.licenseType != LicenseType.enterprise) {
      return const BusinessLockedScreen();
    }

    // Show Business List Screen
    return const BusinessListScreen();
  }
}
