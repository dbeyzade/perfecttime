import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/localization_service.dart';

class HostSetupScreen extends StatefulWidget {
  final Function(DateTime startTime, bool isRecording, int reminderMinutes) onMeetingCreated;

  const HostSetupScreen({
    super.key,
    required this.onMeetingCreated,
  });

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isRecording = false;
  final TextEditingController _reminderController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final String _meetingId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    // Default to now for easier selection
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 10)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF1E1E1E),
              hourMinuteColor: Colors.grey[800],
              dayPeriodColor: Colors.grey[800],
              dayPeriodTextColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Future<void> _createMeeting() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectDateAndTime)),
      );
      return;
    }

    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterMeetingSubject)),
      );
      return;
    }

    final startTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    int reminderMinutes = 0;
    if (_reminderController.text.isNotEmpty) {
      reminderMinutes = int.tryParse(_reminderController.text) ?? 0;
    }

    // Create Meeting Links
    final String mobileLink = 'perfecttime://meeting/join?id=$_meetingId';
    final String webLink = 'https://web-redirect-6z91e7yag-dogukans-projects-ab227b2e.vercel.app/?id=$_meetingId';
    
    // Simulate sending link and scheduling reminder
    String message = l10n.meetingCreatedWithReminder;
    if (reminderMinutes > 0) {
      message += '\n$reminderMinutes ${l10n.reminderSet}';
    }

    // Persist meeting to Supabase with all details
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('meetings').insert({
        'id': _meetingId,
        'host_id': user?.id,
        'subject': _subjectController.text.trim(),
        'start_time': startTime.toIso8601String(),
        'is_recording': _isRecording,
        'reminder_minutes': reminderMinutes,
        'join_link': mobileLink,
        'web_link': webLink,
        'status': 'scheduled',
      });
      debugPrint('Meeting created successfully in Supabase');
    } catch (e) {
      debugPrint('Supabase insert error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.meetingCreateError} $e')),
        );
        return;
      }
    }

    // Format date and time for display
    final formattedDate = '${startTime.day}.${startTime.month}.${startTime.year}';
    final formattedTime = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

    // Share or Copy Link Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            Text(l10n.meetingCreated, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.subject, l10n.subject, _subjectController.text.trim()),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.calendar_today, l10n.date, formattedDate),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.access_time, l10n.time, formattedTime),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // macOS için kayıt uyarısı
              if (!kIsWeb && Platform.isMacOS)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.withOpacity(0.2), Colors.red.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.videocam_off, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.isTurkish ? '⚠️ Kayıt Uyarısı' : '⚠️ Recording Notice',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.isTurkish 
                          ? 'macOS\'ta otomatik kayıt desteklenmiyor.\n\n📹 Toplantıyı kaydetmek için:\n• ⌘ + Shift + 5 tuşlarına basın\n• "Ekran Kaydı" seçeneğini seçin\n• Toplantı başlamadan kayda başlayın'
                          : 'Auto recording is not supported on macOS.\n\n📹 To record the meeting:\n• Press ⌘ + Shift + 5\n• Select "Screen Recording"\n• Start recording before the meeting',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              Text('🔗 ${l10n.joinLink}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
                ),
                child: SelectableText(webLink, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              Text('📤 ${l10n.shareLink}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildShareButton(Icons.chat, 'WhatsApp', const Color(0xFF25D366), () async {
                    final text = Uri.encodeComponent('🎯 PerfecTime: ${_subjectController.text.trim()}\n📅 $formattedDate $formattedTime\n👉 $webLink');
                    await launchUrl(Uri.parse('https://wa.me/?text=$text'), mode: LaunchMode.externalApplication);
                  }),
                  _buildShareButton(Icons.email, l10n.email, Colors.blue, () async {
                    final subject = Uri.encodeComponent('PerfecTime: ${_subjectController.text.trim()}');
                    final body = Uri.encodeComponent('${l10n.meeting}: ${_subjectController.text.trim()}\n${l10n.date}: $formattedDate $formattedTime\n${l10n.join}: $webLink');
                    await launchUrl(Uri.parse('mailto:?subject=$subject&body=$body'));
                  }),
                  _buildShareButton(Icons.share, l10n.other, Colors.purple, () {
                    Share.share('🎯 PerfecTime: ${_subjectController.text.trim()}\n📅 $formattedDate $formattedTime\n👉 $webLink');
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: webLink));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.linkCopied} 📋'), backgroundColor: Colors.green));
            },
            style: TextButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.copy, color: Colors.white, size: 16), const SizedBox(width: 6), Text(l10n.copy, style: const TextStyle(color: Colors.white))]),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onMeetingCreated(startTime, _isRecording, reminderMinutes);
            },
            child: Text(l10n.ok, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Make background transparent
      body: Stack(
        children: [
          // Semi-transparent background overlay
          GestureDetector(
            onTap: () {}, // Engelle - dokunması modal'ı kapatmamıştır
            child: Container(
              color: Colors.black.withOpacity(0.75),
            ),
          ),
          
          Center(
            child: Container(
              width: 520, // Slightly wider
              constraints: const BoxConstraints(maxHeight: 550), // Slightly taller
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1D29),
                    Color(0xFF252837),
                    Color(0xFF1A1D29),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blueAccent.withOpacity(0.15),
                          Colors.purpleAccent.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.event_note, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          l10n.planSession,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.blueAccent.withOpacity(0.3),
                          Colors.purpleAccent.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader("📋 ${l10n.meetingInfoHeader}"),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.withOpacity(0.08),
                                  Colors.teal.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.topic_rounded, color: Colors.white, size: 20),
                              ),
                              title: TextField(
                                controller: _subjectController,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: l10n.meetingSubject,
                                  hintStyle: const TextStyle(color: Colors.white30, fontWeight: FontWeight.normal),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          _buildSectionHeader("⏰ ${l10n.scheduling}"),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.08),
                                  Colors.purple.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildCompactListTile(
                                  title: l10n.date,
                                  value: _selectedDate == null
                                      ? l10n.select
                                      : DateFormat('d MMM yyyy', l10n.isTurkish ? 'tr_TR' : 'en_US').format(_selectedDate!),
                                  icon: Icons.calendar_month_rounded,
                                  gradientColors: const [Color(0xFF4776E6), Color(0xFF8E54E9)],
                                  onTap: _pickDate,
                                ),
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.only(left: 62),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                _buildCompactListTile(
                                  title: l10n.time,
                                  value: _selectedTime == null
                                      ? l10n.select
                                      : _selectedTime!.format(context),
                                  icon: Icons.access_time_rounded,
                                  gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                  onTap: _pickTime,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          
                          _buildSectionHeader("⚙️ ${l10n.settingsSection}"),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.withOpacity(0.08),
                                  Colors.red.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                // macOS'ta video kaydı desteklenmiyor - seçeneği gizle
                                if (!kIsWeb && !Platform.isMacOS)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: SwitchListTile(
                                      title: Text(
                                        l10n.record,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        l10n.saveToGallery,
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      secondary: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                                      ),
                                      value: _isRecording,
                                      onChanged: (val) => setState(() => _isRecording = val),
                                      activeColor: const Color(0xFF667EEA),
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    ),
                                  ),
                                if (!kIsWeb && !Platform.isMacOS)
                                  Container(
                                    height: 1,
                                    margin: const EdgeInsets.only(left: 62),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.1),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF09819), Color(0xFFEDDE5D)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                                  ),
                                  title: Text(
                                    l10n.reminder,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: SizedBox(
                                      width: 50,
                                      child: TextField(
                                        controller: _reminderController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          hintText: "0 ${l10n.minutesShort}",
                                          hintStyle: const TextStyle(color: Colors.white30),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _createMeeting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.launchSession,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactListTile({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.4), size: 14),
        ],
      ),
    );
  }
}
