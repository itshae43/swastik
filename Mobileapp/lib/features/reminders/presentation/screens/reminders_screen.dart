import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:swastik_mobile_app/features/reminders/providers/reminder_providers.dart';
import 'package:swastik_mobile_app/core/models/reminder_model.dart';
import 'package:swastik_mobile_app/features/reminders/providers/appointment_providers.dart';
import 'package:swastik_mobile_app/features/reminders/providers/reminder_navigation_provider.dart';
import 'package:swastik_mobile_app/core/models/appointment_model.dart';
import 'package:swastik_mobile_app/core/utils/communication_utils.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'Today';
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_lastTabIndex != _tabController.index) {
        setState(() {
          _lastTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReminderNavigationRequest?>(reminderNavigationProvider, (
      previous,
      next,
    ) {
      if (next == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_tabController.index != next.tabIndex) {
          _tabController.animateTo(next.tabIndex);
        }
        setState(() {
          _selectedFilter = next.filter;
          _lastTabIndex = next.tabIndex;
        });
      });
    });

    final isTablet = AppResponsive.isTablet(context);
    return Container(
      color: isTablet ? const Color(0xFFFAF6EE) : const Color(0xFFFDFBF7),
      child: SafeArea(
        child: Column(
          children: [
            _buildTabBar(isTablet),
            SizedBox(height: isTablet ? 20 : 16),
            _buildHeader(isTablet),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpcomingList(isTablet),
                  _buildAppointmentsList(isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isTablet) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0D8CA), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6B5800),
        unselectedLabelColor: Colors.grey[600],
        labelStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: isTablet ? 16 : 14,
        ),
        unselectedLabelStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w500,
          fontSize: isTablet ? 16 : 14,
        ),
        indicatorColor: const Color(0xFF6B5800),
        indicatorWeight: isTablet ? 3 : 2,
        tabs: const [
          Tab(text: 'Reminders'),
          Tab(text: 'Appointments'),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    final title = _tabController.index == 0
        ? 'Upcoming Calls'
        : 'Upcoming Appointments';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 22.0 : 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 14 : 12,
              vertical: isTablet ? 6 : 4,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0D8CA)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(
                  Icons.filter_list,
                  size: isTablet ? 18 : 16,
                  color: const Color(0xFF6B5800),
                ),
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 15 : 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B5800),
                ),
                isDense: true,
                items: ['Today', 'This Week', 'All'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFilter = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<T> _filterListByDate<T>(List<T> items, DateTime Function(T) getDate) {
    final now = TimeUtils.now;
    if (_selectedFilter == 'Today') {
      return items.where((item) {
        final date = getDate(item);
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList();
    } else if (_selectedFilter == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
      return items.where((item) {
        final date = getDate(item);
        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }
    return items;
  }

  Widget _buildUpcomingList(bool isTablet) {
    final remindersAsync = ref.watch(remindersStreamProvider);

    return remindersAsync.when(
      data: (reminders) {
        final upcoming = reminders
            .where((r) => r.status != ReminderStatus.completed)
            .toList();

        final filtered = _filterListByDate(upcoming, (r) => r.date);

        // Sorting by date (sooner first)
        filtered.sort((a, b) => a.date.compareTo(b.date));

        if (filtered.isEmpty) {
          return _buildEmptyState('No upcoming reminders');
        }

        return ListView.builder(
          padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == filtered.length) {
              return _buildFooter(isTablet);
            }
            final reminder = filtered[index];
            return _buildCallCard(reminder, isTablet);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildAppointmentsList(bool isTablet) {
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);

    return appointmentsAsync.when(
      data: (appointments) {
        final upcoming = appointments
            .where((a) => a.status != AppointmentStatus.completed)
            .toList();

        final filtered = _filterListByDate(upcoming, (a) => a.date);

        // Sorting by date (sooner first)
        filtered.sort((a, b) => a.date.compareTo(b.date));

        if (filtered.isEmpty) {
          return _buildEmptyState('No upcoming appointments');
        }

        return ListView.builder(
          padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final appointment = filtered[index];
            return _buildAppointmentCard(appointment, isTablet);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment, bool isTablet) {
    final isPending = appointment.status != AppointmentStatus.completed;

    // Logic for status label and color
    String statusLabel = '';
    Color statusColor = const Color(0xFF6B5800); // Default UPCOMING
    IconData statusIcon = Icons.access_time;

    final now = TimeUtils.now;
    final isOverdue = appointment.date.isBefore(now) && isPending;
    final isTomorrow =
        appointment.date.day == now.add(const Duration(days: 1)).day &&
        appointment.date.month == now.month &&
        appointment.date.year == now.year;
    final isToday =
        appointment.date.day == now.day &&
        appointment.date.month == now.month &&
        appointment.date.year == now.year;

    if (!isPending) {
      statusLabel = 'COMPLETED';
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle_outline;
    } else if (isOverdue) {
      statusLabel = 'OVERDUE';
      statusColor = const Color(0xFFC62828);
      statusIcon = Icons.error_outline;
    } else if (isToday) {
      statusLabel = 'TODAY';
      statusColor = const Color(0xFF6B5800);
      statusIcon = Icons.access_time;
    } else if (isTomorrow) {
      statusLabel = 'TOMORROW';
      statusColor = const Color(0xFF2852C6);
      statusIcon = Icons.calendar_today_outlined;
    } else {
      statusLabel = 'UPCOMING';
      statusColor = const Color(0xFF6B5800);
      statusIcon = Icons.access_time;
    }

    final dateStr = DateFormat('dd MMM, hh:mm a').format(appointment.date);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: isTablet ? 6 : 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isTablet ? 16 : 12),
                  bottomLeft: Radius.circular(isTablet ? 16 : 12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 18.0 : 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              statusIcon,
                              size: isTablet ? 16 : 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: GoogleFonts.montserrat(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 10 : 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.customerName,
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (appointment.remindBefore)
                          Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 14,
                                color: Color(0xFF6B5800),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Remind 1d before',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: const Color(0xFF6B5800),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 5 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_android,
                                size: isTablet ? 16 : 14,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                appointment.phoneNumber.isNotEmpty
                                    ? appointment.phoneNumber
                                    : 'No phone number saved',
                                style: GoogleFonts.montserrat(
                                  fontSize: isTablet ? 15 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 14 : 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 14 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appointment.notes.isNotEmpty
                            ? appointment.notes
                            : 'No additional notes.',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (isPending) ...[
                      SizedBox(height: isTablet ? 18 : 16),
                      Row(
                        children: [
                          _buildActionIcon(
                            icon: Icons.call,
                            color: const Color(0xFF2E7D32),
                            onTap: () => CommunicationUtils.makeCall(
                              appointment.phoneNumber,
                            ),
                            label: 'Call',
                            isTablet: isTablet,
                          ),
                          SizedBox(width: isTablet ? 14 : 12),
                          _buildActionIcon(
                            icon: Icons.chat_outlined,
                            color: const Color(0xFF25D366),
                            onTap: () => CommunicationUtils.launchWhatsApp(
                              appointment.phoneNumber,
                              appointment.notes,
                            ),
                            label: 'WA',
                            isTablet: isTablet,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _showEditAppointmentDialog(
                              appointment,
                              isTablet,
                            ),
                            child: Text(
                              'Edit',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: isTablet ? 15 : 13,
                              ),
                            ),
                          ),
                          SizedBox(width: isTablet ? 12 : 0),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(appointmentNotifierProvider.notifier)
                                  .markAsDone(appointment.id);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 14 : 12,
                                vertical: isTablet ? 10 : 8,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: isTablet ? 20 : 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAppointmentDialog(AppointmentModel appointment, bool isTablet) {
    final notesController = TextEditingController(text: appointment.notes);
    final nameController = TextEditingController(
      text: appointment.customerName,
    );
    final phoneController = TextEditingController(
      text: appointment.phoneNumber,
    );
    DateTime selectedDate = appointment.date;
    bool remindBefore = appointment.remindBefore;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFDFBF7),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          ),
          title: Text(
            'Edit Appointment',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 22 : 18,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Name',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 15 : 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: nameController,
                    style: GoogleFonts.montserrat(fontSize: isTablet ? 16 : 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(isTablet ? 16 : 12),
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Text(
                  'Phone Number',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 15 : 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: phoneController,
                    style: GoogleFonts.montserrat(fontSize: isTablet ? 16 : 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(isTablet ? 16 : 12),
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Text(
                  'Notes',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 15 : 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: notesController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.montserrat(fontSize: isTablet ? 16 : 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(isTablet ? 16 : 12),
                    ),
                    maxLines: 3,
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 20),
                Text(
                  'Date & Time',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 15 : 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                InkWell(
                  onTap: () async {
                    final now = TimeUtils.now;
                    final firstDate = selectedDate.isBefore(now)
                        ? selectedDate
                        : now;
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: firstDate,
                      lastDate: now.add(const Duration(days: 365 * 5)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF6B5800),
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      if (!context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF6B5800),
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: isTablet ? 22 : 20,
                          color: const Color(0xFF6B5800),
                        ),
                        SizedBox(width: isTablet ? 12 : 10),
                        Expanded(
                          child: Text(
                            DateFormat(
                              'dd MMM yyyy • hh:mm a',
                            ).format(selectedDate),
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: isTablet ? 20 : 18,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF6B5800),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Remind 1 day before',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Switch(
                      value: remindBefore,
                      activeColor: const Color(0xFF6B5800),
                      onChanged: (val) {
                        setDialogState(() {
                          remindBefore = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: EdgeInsets.only(
            right: isTablet ? 24 : 20,
            bottom: isTablet ? 20 : 16,
            top: 8,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 12,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(width: isTablet ? 8 : 4),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(appointmentNotifierProvider.notifier)
                    .updateAppointment(
                      appointment.copyWith(
                        customerName: nameController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        notes: notesController.text.trim(),
                        date: selectedDate,
                        remindBefore: remindBefore,
                      ),
                    );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5800),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'Save Changes',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.montserrat(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCallCard(ReminderModel reminder, bool isTablet) {
    final isPending = reminder.status != ReminderStatus.completed;

    // Logic for status label and color
    String statusLabel = '';
    Color statusColor = const Color(0xFF6B5800); // Default UPCOMING
    IconData statusIcon = Icons.access_time;

    final now = TimeUtils.now;
    final isOverdue = reminder.date.isBefore(now) && isPending;
    final isTomorrow =
        reminder.date.day == now.add(const Duration(days: 1)).day &&
        reminder.date.month == now.month &&
        reminder.date.year == now.year;
    final isToday =
        reminder.date.day == now.day &&
        reminder.date.month == now.month &&
        reminder.date.year == now.year;

    if (!isPending) {
      statusLabel = 'COMPLETED';
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle_outline;
    } else if (isOverdue) {
      statusLabel = 'OVERDUE';
      statusColor = const Color(0xFFC62828);
      statusIcon = Icons.error_outline;
    } else if (isToday) {
      statusLabel = 'TODAY';
      statusColor = const Color(0xFF6B5800);
      statusIcon = Icons.access_time;
    } else if (isTomorrow) {
      statusLabel = 'TOMORROW';
      statusColor = const Color(0xFF2852C6);
      statusIcon = Icons.calendar_today_outlined;
    } else {
      statusLabel = 'UPCOMING';
      statusColor = const Color(0xFF6B5800);
      statusIcon = Icons.access_time;
    }

    final dateStr = DateFormat('dd MMM, hh:mm a').format(reminder.date);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: isTablet ? 6 : 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isTablet ? 16 : 12),
                  bottomLeft: Radius.circular(isTablet ? 16 : 12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 18.0 : 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              statusIcon,
                              size: isTablet ? 16 : 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: GoogleFonts.montserrat(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 10 : 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.partyName,
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          reminder.title,
                          style: GoogleFonts.montserrat(
                            fontSize: isTablet ? 13 : 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 5 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_android,
                                size: isTablet ? 16 : 14,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                reminder.partyPhone.isNotEmpty
                                    ? reminder.partyPhone
                                    : 'No phone number saved',
                                style: GoogleFonts.montserrat(
                                  fontSize: isTablet ? 15 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 14 : 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 14 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reminder.note,
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (isPending) ...[
                      SizedBox(height: isTablet ? 18 : 16),
                      Row(
                        children: [
                          _buildActionIcon(
                            icon: Icons.call,
                            color: const Color(0xFF2E7D32),
                            onTap: () => CommunicationUtils.makeCall(
                              reminder.partyPhone,
                            ),
                            label: 'Call',
                            isTablet: isTablet,
                          ),
                          SizedBox(width: isTablet ? 14 : 12),
                          _buildActionIcon(
                            icon: Icons.chat_outlined,
                            color: const Color(0xFF25D366),
                            onTap: () => CommunicationUtils.launchWhatsApp(
                              reminder.partyPhone,
                              reminder.note,
                            ),
                            label: 'WA',
                            isTablet: isTablet,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                _showEditReminderDialog(reminder, isTablet),
                            child: Text(
                              'Edit',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: isTablet ? 15 : 13,
                              ),
                            ),
                          ),
                          SizedBox(width: isTablet ? 12 : 0),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(reminderNotifierProvider.notifier)
                                  .markAsDone(reminder.id);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 14 : 12,
                                vertical: isTablet ? 10 : 8,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: isTablet ? 20 : 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    required bool isTablet,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isTablet ? 22 : 20),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 11 : 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showEditReminderDialog(ReminderModel reminder, bool isTablet) {
    final noteController = TextEditingController(text: reminder.note);
    DateTime selectedDate = reminder.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFFFDFBF7),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          ),
          title: Text(
            'Edit Reminder',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 22 : 18,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 15 : 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: noteController,
                    style: GoogleFonts.montserrat(fontSize: isTablet ? 16 : 14),
                    decoration: InputDecoration(
                      hintText: 'Enter your note here...',
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(isTablet ? 16 : 12),
                    ),
                    maxLines: 4,
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 20),
                Text(
                  'Date & Time',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 15 : 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                InkWell(
                  onTap: () async {
                    final now = TimeUtils.now;
                    final firstDate = selectedDate.isBefore(now)
                        ? selectedDate
                        : now;
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: firstDate,
                      lastDate: now.add(const Duration(days: 365 * 5)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(
                                0xFF6B5800,
                              ), // header background color
                              onPrimary: Colors.white, // header text color
                              onSurface: Colors.black, // body text color
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      if (!context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF6B5800),
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: isTablet ? 22 : 20,
                          color: const Color(0xFF6B5800),
                        ),
                        SizedBox(width: isTablet ? 12 : 10),
                        Expanded(
                          child: Text(
                            DateFormat(
                              'dd MMM yyyy • hh:mm a',
                            ).format(selectedDate),
                            style: GoogleFonts.montserrat(
                              fontSize: isTablet ? 15 : 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: isTablet ? 20 : 18,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: EdgeInsets.only(
            right: isTablet ? 24 : 20,
            bottom: isTablet ? 20 : 16,
            top: 8,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 12,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(width: isTablet ? 8 : 4),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(reminderNotifierProvider.notifier)
                    .updateReminder(
                      reminder.copyWith(
                        note: noteController.text,
                        date: selectedDate,
                      ),
                    );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5800),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'Save Changes',
                style: GoogleFonts.montserrat(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 28.0 : 24.0),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: isTablet ? 48 : 40,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'No more upcoming reminders for this week.',
            style: GoogleFonts.montserrat(
              fontSize: isTablet ? 15 : 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 96 : 80),
        ],
      ),
    );
  }
}
