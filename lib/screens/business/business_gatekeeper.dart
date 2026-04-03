import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../licences/license_type.dart';
import 'business_locked_screen.dart';
import 'business_list_screen.dart';

class BusinessGatekeeper extends StatelessWidget {
  const BusinessGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Check license (Pro or Enterprise level required)
    if (provider.licenseType.level != LicenseLevel.pro &&
        provider.licenseType.level != LicenseLevel.enterprise) {
      return const BusinessLockedScreen();
    }

    // Show Business List Screen
    return const BusinessListScreen();
  }
}
