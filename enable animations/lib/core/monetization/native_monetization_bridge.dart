import 'package:flutter/services.dart';

class NativeMonetizationBridge {
  NativeMonetizationBridge._();

  static const MethodChannel _channel = MethodChannel('meowverse/monetization');

  static Future<bool> showRewardedAd() async {
    try {
      final result = await _channel.invokeMethod<bool>('showRewardedAd');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startSubscriptionPurchase(String packageId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startSubscriptionPurchase',
        <String, dynamic>{'packageId': packageId},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restoreSubscriptionPurchase() async {
    try {
      final result = await _channel.invokeMethod<bool>('restoreSubscriptionPurchase');
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
