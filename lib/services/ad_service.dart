import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  // Test ID for Rewarded Ad
  // Production ID should be swapped later

  //Codigo para pruebas de anuncio
  //static const String _adUnitId = 'ca-app-pub-3940256099942544/5224354917';

  //Codigo Real
  static const String _adUnitId = 'ca-app-pub-4546463696756021/8417813894';

  VoidCallback? onAdLoadedListener;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('$ad loaded.');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
          if (onAdLoadedListener != null) onAdLoadedListener!();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _numRewardedLoadAttempts += 1;
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            loadRewardedAd();
          }
        },
      ),
    );
  }

  // Returns true if ad is ready
  bool get isAdReady => _rewardedAd != null;

  void showRewardedAd({
    required Function onUserEarnedReward,
    Function? onAdDismissed,
    Function? onAdFailedToLoad,
  }) {
    if (_rewardedAd == null) {
      debugPrint('Warning: attempt to show rewarded before loaded.');
      if (onAdFailedToLoad != null) onAdFailedToLoad();
      // Try loading again for next time
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) =>
          debugPrint('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        loadRewardedAd(); // Load the next one
        if (onAdDismissed != null) onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        loadRewardedAd();
        if (onAdFailedToLoad != null) onAdFailedToLoad();
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint(
          '$ad with reward $RewardItem(${reward.amount}, ${reward.type})',
        );
        onUserEarnedReward();
      },
    );
    _rewardedAd = null;
  }
}
