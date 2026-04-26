import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../fair_split/providers/fair_split_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  int _selectedDay = 0;
  int _selectedHour = 18;
  bool _loading = false;
  bool _saved = false;

  final _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final _hours = [
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
  ];

  String _formatHour(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final display = h == 0
        ? 12
        : h > 12
            ? h - 12
            : h;
    return '$display:00 $period';
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final household = await ref.read(householdRepoProvider).fetchMyHousehold();
    if (household != null && mounted) {
      setState(() {
        _selectedDay = household.moneyDateDay;
        _selectedHour = household.moneyDateHour;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _saved = false;
    });

    try {
      // 1. Update remote database
      await ref.read(householdRepoProvider).updateMoneyDateSchedule(
            day: _selectedDay,
            hour: _selectedHour,
          );

      // 2. Schedule local notifications
      await NotificationService.scheduleMoneyDate(
        dayOfWeek: _selectedDay,
        hour: _selectedHour,
      );

      // 3. Refresh global state
      ref.invalidate(householdProvider);

      if (mounted) {
        setState(() => _saved = true);

        // Success feedback with the specific formatting requested
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Money Date set for every ${_days[_selectedDay]} at ${_formatHour(_selectedHour)}',
            ),
            backgroundColor: AppColors.ours,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        title: const Text('Money Date schedule'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.oursLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ours),
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite_outline, color: AppColors.ours),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose when you and your partner get your weekly Money Date notification.',
                      style: TextStyle(fontSize: 13, color: AppColors.oursDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Day picker
            const Text('Day',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.asMap().entries.map((e) {
                final i = e.key;
                final day = e.value;
                final selected = _selectedDay == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.ours : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.ours : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Time picker
            const Text('Time',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedHour,
                  isExpanded: true,
                  items: _hours
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text(_formatHour(h)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedHour = v!),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_outlined,
                      size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'You\'ll be notified every ${_days[_selectedDay]} at ${_formatHour(_selectedHour)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_saved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.oursLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.ours, size: 18),
                    const SizedBox(width: 8),
                    Text('Schedule saved!',
                        style: TextStyle(
                            color: AppColors.oursDark,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ours,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save schedule',
                        style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
