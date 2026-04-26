import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/partner.dart';
import '../models/household.dart';

class MoneyDateInsights {
  final List<String> talkingPoints;
  final String decisionPrompt;
  final Map<String, dynamic> weekInNumbers;

  const MoneyDateInsights({
    required this.talkingPoints,
    required this.decisionPrompt,
    required this.weekInNumbers,
  });
}

class ClaudeService {
  static const _model = 'claude-haiku-4-5-20251001';
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiKey = String.fromEnvironment('CLAUDE_API_KEY');

  Future<MoneyDateInsights> generateMoneyDateInsights({
    required List<Transaction> weekTransactions,
    required Household household,
    required List<Partner> partners,
  }) async {
    final partnerA = partners.where((p) => p.role == 'partner_a').firstOrNull;
    final partnerB = partners.where((p) => p.role == 'partner_b').firstOrNull;

    if (partnerA == null || partnerB == null) {
      throw Exception('Waiting for your partner to join before Money Date is available.');
    }

    // Build week summary
    final expenses = weekTransactions.where((t) => !t.isIncome && !t.isPrivate);
    final totalSpent = expenses.fold(0.0, (s, t) => s + t.amountAud.abs());
    final oursSpent = expenses
        .where((t) => t.bucket == 'ours')
        .fold(0.0, (s, t) => s + t.amountAud.abs());

    // Top categories
    final Map<String, double> cats = {};
    for (final t in expenses) {
      final cat = t.category ?? 'Other';
      cats[cat] = (cats[cat] ?? 0) + t.amountAud.abs();
    }
    final topCats = (cats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => '${e.key}: \$${e.value.toStringAsFixed(0)}')
        .join(', ');

    final prompt = '''
You are a warm, practical financial coach for couples. 
Generate a weekly money check-in for ${partnerA.displayName} and ${partnerB.displayName}.

This week's data:
- Total household spending: \$${totalSpent.toStringAsFixed(2)} AUD
- Shared (Ours) spending: \$${oursSpent.toStringAsFixed(2)} AUD  
- Top categories: $topCats
- Number of transactions: ${weekTransactions.length}
- Split method: ${household.splitMethod}

Generate exactly this JSON structure and nothing else:
{
  "talking_points": [
    "one sentence talking point 1",
    "one sentence talking point 2", 
    "one sentence talking point 3"
  ],
  "decision_prompt": "one optional action item they could take this week"
}

Rules:
- Tone: warm, non-judgemental, encouraging
- Reference real numbers from the data
- Keep each talking point to one sentence
- Decision prompt should be a specific actionable suggestion
- Use AUD amounts with \$ sign
- Do not include any text outside the JSON
''';

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 300,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['content'][0]['text'] as String;
    final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(clean);

    final weekInNumbers = {
      'total_spent': totalSpent,
      'ours_spent': oursSpent,
      'transaction_count': weekTransactions.length,
      'top_categories': cats,
    };

    return MoneyDateInsights(
      talkingPoints:
          (parsed['talking_points'] as List).map((e) => e as String).toList(),
      decisionPrompt: parsed['decision_prompt'] as String,
      weekInNumbers: weekInNumbers,
    );
  }
}
