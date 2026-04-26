import 'package:posthog_flutter/posthog_flutter.dart';

class AnalyticsService {
  static const _apiKey = String.fromEnvironment('POSTHOG_API_KEY');

  static Future<void> init() async {
    final config = PostHogConfig(_apiKey)
      ..host = 'https://app.posthog.com'
      ..debug = false
      ..captureApplicationLifecycleEvents = true;

    await Posthog().setup(config);
  }

  static Future<void> identify(String userId) async {
    await Posthog().identify(userId: userId);
  }

  // Auth events
  static Future<void> signupCompleted(String role) async {
    await Posthog().capture(
      eventName: 'signup_completed',
      properties: {'role': role},
    );
  }

  static Future<void> partnerInvited() async {
    await Posthog().capture(eventName: 'partner_invited');
  }

  static Future<void> partnerJoined() async {
    await Posthog().capture(eventName: 'partner_joined');
  }

  // Feature events
  static Future<void> transactionAdded(String bucket, String category) async {
    await Posthog().capture(
      eventName: 'transaction_added',
      properties: {'bucket': bucket, 'category': category},
    );
  }

  static Future<void> goalCreated() async {
    await Posthog().capture(eventName: 'goal_created');
  }

  static Future<void> moneyDateOpened() async {
    await Posthog().capture(eventName: 'money_date_opened');
  }

  static Future<void> fairSplitViewed() async {
    await Posthog().capture(eventName: 'fair_split_viewed');
  }

  static Future<void> settleUpTapped() async {
    await Posthog().capture(eventName: 'settle_up_tapped');
  }

  // Paywall events
  static Future<void> paywallViewed(String source) async {
    await Posthog().capture(
      eventName: 'paywall_viewed',
      properties: {'source': source},
    );
  }

  static Future<void> subscriptionPurchased(String tier) async {
    await Posthog().capture(
      eventName: 'subscription_purchased',
      properties: {'tier': tier},
    );
  }

  static Future<void> subscriptionRestored() async {
    await Posthog().capture(eventName: 'subscription_restored');
  }
}
