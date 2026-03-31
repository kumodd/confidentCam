# 07 — RevenueCat Mobile Integration (Flutter)

## Prerequisites

- RevenueCat account at [app.revenuecat.com](https://app.revenuecat.com)
- iOS app in App Store Connect with subscription products created
- Android app in Google Play Console with subscription products created
- RevenueCat project configured (see [06_subscription_plan.md](./06_subscription_plan.md))

---

## Step 1: Add Dependency

Add to `pubspec.yaml`:

```yaml
dependencies:
  purchases_flutter: ^7.x.x    # Check latest at pub.dev
```

Run:
```bash
flutter pub get
```

---

## Step 2: iOS Native Configuration

### Info.plist

No special keys needed for RevenueCat itself, but ensure:
```xml
<!-- Required for in-app purchases -->
<key>SKAdNetworkItems</key>
<array>...</array>
```

### StoreKit Configuration (Testing)

For local testing without hitting App Store:
1. Xcode → File → New → StoreKit Configuration File
2. Add a subscription product
3. Enable in Xcode scheme: Edit Scheme → Run → Options → StoreKit Configuration

---

## Step 3: Android Native Configuration

### `android/app/build.gradle`

```groovy
android {
    defaultConfig {
        minSdkVersion 24    // RevenueCat requires API 24+
    }
}
```

### `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

---

## Step 4: API Keys

Store keys in `lib/core/config/app_config.dart`:

```dart
class AppConfig {
  // RevenueCat
  static const String revenueCatApiKeyAndroid = 'goog_xxxxxxxxxxxxxx';
  static const String revenueCatApiKeyIos     = 'appl_xxxxxxxxxxxxxx';
}
```

> ⚠️ **These are PUBLIC SDK keys** — safe to store in source (not secret keys). Still, consider using `--dart-define` for CI/CD.

---

## Step 5: Create SubscriptionService

Create `lib/services/subscription_service.dart`:

```dart
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/config/app_config.dart';
import '../core/utils/logger.dart';

class SubscriptionService {
  
  /// Initialize RevenueCat SDK.
  /// Call after Supabase auth is initialized.
  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug); // Disable in production
    
    final apiKey = Platform.isIOS
        ? AppConfig.revenueCatApiKeyIos
        : AppConfig.revenueCatApiKeyAndroid;

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
    
    logger.i('RevenueCat initialized');
  }

  /// Set the user identity — MUST be called when user logs in.
  /// Uses Supabase auth.uid() as RevenueCat appUserID.
  Future<void> identifyUser(String supabaseUserId) async {
    try {
      final logInResult = await Purchases.logIn(supabaseUserId);
      logger.i('RC user identified: ${logInResult.customerInfo.originalAppUserId}');
    } catch (e) {
      logger.e('RC identify error', e);
    }
  }

  /// Call when user logs out.
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      logger.i('RC user logged out');
    } catch (e) {
      logger.e('RC logout error', e);
    }
  }

  /// Check if user has the 'premium' entitlement.
  Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      logger.e('RC isPremium error', e);
      return false;
    }
  }

  /// Fetch the current offering (plans/packages).
  Future<Offering?> getCurrentOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      logger.e('RC getOfferings error', e);
      return null;
    }
  }

  /// Purchase a package (monthly or yearly).
  Future<CustomerInfo?> purchase(Package package) async {
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      logger.i('RC purchase success');
      return purchaseResult;
    } on PurchasesErrorCode catch (e) {
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        logger.e('RC purchase error', e);
      }
      return null;
    }
  }

  /// Restore purchases (for returning users / uninstall-reinstall).
  Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      logger.e('RC restore error', e);
      return null;
    }
  }
}
```

---

## Step 6: Wire to Auth (main.dart)

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies(); // existing

  // Initialize RevenueCat AFTER Supabase
  await sl<SubscriptionService>().initialize();

  runApp(const ConfidentCamApp());
}
```

In `injection_container.dart`, register `SubscriptionService`:

```dart
// In _initServices()
sl.registerLazySingleton<SubscriptionService>(() => SubscriptionService());
```

In `AuthBloc`, after successful login:

```dart
// After AuthSuccess is emitted, identify user in RevenueCat
await sl<SubscriptionService>().identifyUser(userId);

// After logout
await sl<SubscriptionService>().logOut();
```

---

## Step 7: SubscriptionBloc

Create `lib/presentation/bloc/subscription/`:

### `subscription_event.dart`
```dart
abstract class SubscriptionEvent {}

class LoadSubscriptionStatus extends SubscriptionEvent {}
class PurchasePackage extends SubscriptionEvent {
  final Package package;
  PurchasePackage(this.package);
}
class RestorePurchases extends SubscriptionEvent {}
```

### `subscription_state.dart`
```dart
abstract class SubscriptionState {}

class SubscriptionInitial extends SubscriptionState {}
class SubscriptionLoading extends SubscriptionState {}
class SubscriptionLoaded extends SubscriptionState {
  final bool isPremium;
  final Offering? offering;
  SubscriptionLoaded({required this.isPremium, this.offering});
}
class SubscriptionPurchaseSuccess extends SubscriptionState {}
class SubscriptionError extends SubscriptionState {
  final String message;
  SubscriptionError(this.message);
}
```

### `subscription_bloc.dart`
```dart
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final SubscriptionService _subscriptionService;

  SubscriptionBloc(this._subscriptionService) : super(SubscriptionInitial()) {
    on<LoadSubscriptionStatus>(_onLoad);
    on<PurchasePackage>(_onPurchase);
    on<RestorePurchases>(_onRestore);
  }

  Future<void> _onLoad(LoadSubscriptionStatus event, emit) async {
    emit(SubscriptionLoading());
    final isPremium = await _subscriptionService.isPremium();
    final offering = await _subscriptionService.getCurrentOffering();
    emit(SubscriptionLoaded(isPremium: isPremium, offering: offering));
  }

  Future<void> _onPurchase(PurchasePackage event, emit) async {
    emit(SubscriptionLoading());
    final result = await _subscriptionService.purchase(event.package);
    if (result != null && result.entitlements.active.containsKey('premium')) {
      emit(SubscriptionPurchaseSuccess());
    } else {
      emit(SubscriptionError('Purchase failed or cancelled'));
    }
  }

  Future<void> _onRestore(RestorePurchases event, emit) async {
    emit(SubscriptionLoading());
    final result = await _subscriptionService.restorePurchases();
    final isPremium = result?.entitlements.active.containsKey('premium') ?? false;
    final offering = await _subscriptionService.getCurrentOffering();
    emit(SubscriptionLoaded(isPremium: isPremium, offering: offering));
  }
}
```

---

## Step 8: Paywall Screen

Create `lib/presentation/screens/subscription/paywall_screen.dart`:

### Key UI Elements

```
PaywallScreen
├── Dismiss button (X)
├── Header (app logo + "Go Premium")
├── Feature list (what they get)
├── Plan cards (Monthly / Yearly — tap to select)
│   ├── Yearly: show "BEST VALUE" badge + savings %
│   └── Monthly: show per-month breakdown
├── Subscribe CTA button (big gradient button)
├── "Restore Purchases" text link
└── Terms of Service + Privacy Policy links
```

### Plan Cards Display Pattern

```dart
// Get packages from offering
final offering = state.offering;
final monthlyPackage = offering?.monthly;
final annualPackage = offering?.annual;

// Display price from package
final monthlyPrice = monthlyPackage?.storeProduct.priceString;   // "$9.99/month"
final annualPrice = annualPackage?.storeProduct.priceString;     // "$59.99/year"

// Calculate savings
final monthlyCost = monthlyPackage?.storeProduct.price ?? 0;
final annualCost = annualPackage?.storeProduct.price ?? 0;
final savings = ((monthlyCost * 12 - annualCost) / (monthlyCost * 12) * 100).round();
// "Save 50%"
```

---

## Step 9: Entitlement Checks

Replace `AppConfig.isPremiumUser` with a real check:

```dart
// Before showing paywall-gated content:
BlocBuilder<SubscriptionBloc, SubscriptionState>(
  builder: (context, state) {
    final isPremium = state is SubscriptionLoaded && state.isPremium;
    
    if (!isPremium) {
      return PremiumLockedCard(
        onUpgrade: () => showPaywall(context),
      );
    }
    
    return ActualPremiumContent();
  },
)
```

In `UserProgress.isDayUnlocked()`, pass real premium status:

```dart
// In DashboardScreen or ChallengeBloc:
final isPremium = sl<SubscriptionBloc>().state is SubscriptionLoaded
    ? (sl<SubscriptionBloc>().state as SubscriptionLoaded).isPremium
    : false;

final unlocked = userProgress.isDayUnlocked(day, isPremium: isPremium);
```

---

## Testing

| Scenario | How to Test |
|---|---|
| Purchase flow | Use Sandbox Apple ID (iOS) / License Tester (Android) |
| Free trial | Create a product with trial in App Store Connect |
| Restore purchases | Re-install app, tap "Restore" |
| Expiration | Set short sub duration in Sandbox settings |
| Webhook | Use RevenueCat Dashboard → "Send Test Event" |

---

## RevenueCat API Keys Location

After setup, add to `lib/core/config/app_config.dart`:

```dart
// RevenueCat
static const String revenueCatApiKeyAndroid = 'goog_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
static const String revenueCatApiKeyIos     = 'appl_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
static const String revenueCatEntitlement   = 'premium';
static const String revenueCatOffering      = 'default';
```
