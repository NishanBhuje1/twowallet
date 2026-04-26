import '../../data/models/transaction.dart';

class FairSplitResult {
  final double totalOurs;
  final double partnerAPaid;
  final double partnerBPaid;
  final double partnerAShare;
  final double partnerBShare;
  final double settlementAmount; // positive = A overpaid (B owes A)
  final String fromPartnerId;
  final String toPartnerId;

  const FairSplitResult({
    required this.totalOurs,
    required this.partnerAPaid,
    required this.partnerBPaid,
    required this.partnerAShare,
    required this.partnerBShare,
    required this.settlementAmount,
    required this.fromPartnerId,
    required this.toPartnerId,
  });

  bool get isEven => settlementAmount.abs() < 0.01;
}

class FairSplitCalc {
  static FairSplitResult calculate({
    required List<Transaction> oursTransactions,
    required double splitRatioA,
    required String partnerAId,
    required String partnerBId,
  }) {
    // Default to 50/50 if ratio is invalid
    final ratio = (splitRatioA > 0 && splitRatioA < 1) ? splitRatioA : 0.5;
    final splitRatioB = 1.0 - ratio;

    // Step 1: total shared spending
    final totalOurs = oursTransactions
        .where((t) => !t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amountAud.abs());

    // Step 2: fair share per partner
    final partnerAShare = totalOurs * ratio;
    final partnerBShare = totalOurs * splitRatioB;

    // Step 3: what each partner actually paid
    final partnerAPaid = oursTransactions
        .where((t) => t.partnerId == partnerAId && !t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amountAud.abs());

    final partnerBPaid = oursTransactions
        .where((t) => t.partnerId == partnerBId && !t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amountAud.abs());

    // Step 4: settlement
    // Positive = A overpaid = B owes A
    // Negative = A underpaid = A owes B
    final settlement = partnerAPaid - partnerAShare;

    return FairSplitResult(
      totalOurs: totalOurs,
      partnerAPaid: partnerAPaid,
      partnerBPaid: partnerBPaid,
      partnerAShare: partnerAShare,
      partnerBShare: partnerBShare,
      settlementAmount: settlement.abs(),
      fromPartnerId: settlement < 0 ? partnerAId : partnerBId,
      toPartnerId: settlement < 0 ? partnerBId : partnerAId,
    );
  }
}
