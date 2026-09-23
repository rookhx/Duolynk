import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config/app_environment.dart';

class RevenueCatService {
  const RevenueCatService();

  Future<bool> initialize() async {
    if (!AppEnvironment.revenueCatEnabled || kIsWeb) {
      return false;
    }

    final apiKey = Platform.isIOS
        ? AppEnvironment.revenueCatAppleApiKey
        : AppEnvironment.revenueCatGoogleApiKey;
    if (apiKey.isEmpty) {
      return false;
    }

    await Purchases.setLogLevel(LogLevel.warn);

    final isConfigured = await Purchases.isConfigured;
    if (!isConfigured) {
      await Purchases.configure(PurchasesConfiguration(apiKey));
    }
    return true;
  }

  Future<bool> identify(String appUserId) async {
    final initialized = await initialize();
    if (!initialized || appUserId.isEmpty) {
      return false;
    }

    await Purchases.logIn(appUserId);
    return true;
  }

  Future<void> logOut() async {
    final initialized = await initialize();
    if (!initialized) {
      return;
    }

    await Purchases.logOut();
  }

  Future<Offerings?> getOfferings() async {
    final initialized = await initialize();
    if (!initialized) {
      return null;
    }

    return Purchases.getOfferings();
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    final initialized = await initialize();
    if (!initialized) {
      return null;
    }

    return Purchases.getCustomerInfo();
  }

  Future<CustomerInfo?> purchasePackage(Package package) async {
    final initialized = await initialize();
    if (!initialized) {
      return null;
    }

    // ignore: deprecated_member_use
    final result = await Purchases.purchasePackage(package);
    return result.customerInfo;
  }

  Future<CustomerInfo?> restorePurchases() async {
    final initialized = await initialize();
    if (!initialized) {
      return null;
    }

    return Purchases.restorePurchases();
  }
}
