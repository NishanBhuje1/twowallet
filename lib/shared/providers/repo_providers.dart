import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/settlement_repository.dart';
import '../../data/repositories/household_repository.dart';

/// Canonical singleton providers for every repository.
///
/// Centralised here so that:
///   - auth_provider.dart can use householdRepoProvider without importing
///     fair_split_provider.dart (which would create a circular dependency).
///   - Every feature imports from one place rather than each re-declaring its own.

final transactionRepoProvider = Provider((_) => TransactionRepository());
final settlementRepoProvider  = Provider((_) => SettlementRepository());
final householdRepoProvider   = Provider((_) => HouseholdRepository());
