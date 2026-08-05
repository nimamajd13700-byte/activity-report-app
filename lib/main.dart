// lib/main.dart
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============= مدل داده =============
class Report {
  final String id;
  final String expertName;
  final String personnelCode;
  final String activity;
  final String description;
  final String date;
  final String time;
  final int minutes;

  const Report({
    required this.id,
    required this.expertName,
    required this.personnelCode,
    required this.activity,
    required this.description,
    required this.date,
    required this.time,
    required this.minutes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'expertName': expertName,
        'personnelCode': personnelCode,
        'activity': activity,
        'description': description,
        'date': date,
        'time': time,
        'minutes': minutes,
      };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id']?.toString() ?? '',
        expertName: json['expertName']?.toString() ?? '',
        personnelCode: json['personnelCode']?.toString() ?? '',
        activity: json['activity']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        time: json['time']?.toString() ?? '',
        minutes: int.tryParse(json['minutes']?.toString() ?? '0') ?? 0,
      );
}

// ============= سرویس ذخیره‌سازی =============
class StorageService {
  static const String _reportsKey = 'reports';
  static const String _activitiesKey = 'activities';
  static const String _expertNameKey = 'expertName';
  static const String _personnelCodeKey = 'personnelCode';
  static const String _expertPasswordKey = 'expertPassword';
  static const String _managerPasswordKey = 'managerPassword';

  Future<void> saveAll({
    required List<Report> reports,
    required List<String> activities,
    required String expertName,
    required String personnelCode,
    required String expertPassword,
    required String managerPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await Future.wait([
      prefs.setStringList(
        _reportsKey,
        reports.map((r) => jsonEncode(r.toJson())).toList(),
      ),
      prefs.setStringList(_activitiesKey, activities),
      prefs.setString(_expertNameKey, expertName),
      prefs.setString(_personnelCodeKey, personnelCode),
      prefs.setString(_expertPasswordKey, expertPassword),
      prefs.setString(_managerPasswordKey, managerPassword),
    ]);
  }

  Future<({
    List<Report> reports,
    List<String> activities,
    String expertName,
    String personnelCode,
    String expertPassword,
    String managerPassword,
  })> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedReports = prefs.getStringList(_reportsKey) ?? [];
    final savedActivities = prefs.getStringList(_activitiesKey);
    final expertName = prefs.getString(_expertNameKey) ?? 'کارشناس نمونه';
    final personnelCode = prefs.getString(_personnelCodeKey) ?? '';
    final expertPassword = prefs.getString(_expertPasswordKey) ?? '1234';
    final managerPassword = prefs.getString(_managerPasswordKey) ?? '1234';

    final reports = savedReports
        .map((item) {
          try {
            return Report.fromJson(jsonDecode(item));
          } catch (_) {
            return null;
          }
        })
        .whereType<Report>()
        .toList();

    final activities = (savedActivities != null && savedActivities.isNotEmpty)
        ? savedActivities
        : _defaultActivities();

    return (
      reports: reports,
      activities: activities,
      expertName: expertName,
      personnelCode: personnelCode,
      expertPassword: expertPassword,
      managerPassword: managerPassword,
    );
  }

  List<String> _defaultActivities() => [
        'بررسی پرونده',
        'تنظیم گزارش',
        'مکاتبات اداری',
        'پاسخگویی',
        'جلسه',
        'بازدید',
        'پیگیری پرونده',
        'مطالعه و تحقیق',
        'سایر',
      ];
}

// ============= سرویس فایل =============
class FileService {
  static const String _bom = '\uFEFF';

  Future<String> exportToCsv(List<Report> reports, {String? fileName}) async {
    final rows = [
      [
        'کد یکتا',
        'نام کارشناس',
        'کد پرسنلی',
        'تاریخ',
        'ساعت',
        'عنوان فعالیت',
        'مدت (دقیقه)',
        'شرح و جزئیات',
      ],
      ...reports.map((r) => [
            r.id,
            r.expertName,
            r.personnelCode,
            r.date,
            r.time,
            r.activity,
            r.minutes,
            r.description,
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    
    final finalFileName = fileName ??
        'گزارش_تجمیعی_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    
    final file = File('${directory.path}/$finalFileName');
    await file.writeAsString('$_bom$csv', encoding: utf8);
    
    return file.path;
  }

  Future<List<List<dynamic>>> importFromCsv(String path) async {
    final text = await File(path).readAsString(encoding: utf8);
    return const CsvToListConverter().convert(text);
  }
}

// ============= ویجت اصلی =============
void main() => runApp(const InspectionReportApp());

class InspectionReportApp extends StatelessWidget {
  const InspectionReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارشات مدیریت بازرسی',
      home: HomePage(),
    );
  }
}

// ============= صفحه اصلی با مدیریت وضعیت =============
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // سرویس‌ها
  final _storage = StorageService();
  final _fileService = FileService();

  // وضعیت
  int _currentTab = 0;
  bool _isLoading = true;
  bool _darkMode = false;

  // داده‌ها
  late List<Report> _reports;
  late List<String> _activities;
  late String _expertName;
  late String _personnelCode;
  late String _expertPassword;
  late String _managerPassword;

  // کنترلرها
  final _expertNameController = TextEditingController();
  final _personnelCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _expertNameController.dispose();
    _personnelCodeController.dispose();
    super.dispose();
  }

  // ============= متدهای بارگذاری و ذخیره =============
  Future<void> _loadData() async {
    try {
      final data = await _storage.loadAll();
      
      setState(() {
        _reports = data.reports;
        _activities = data.activities;
        _expertName = data.expertName;
        _personnelCode = data.personnelCode;
        _expertPassword = data.expertPassword;
        _managerPassword = data.managerPassword;
        _isLoading = false;
      });
    } catch (e) {
      _showMessage('خطا در بارگذاری داده‌ها: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await _storage.saveAll(
        reports: _reports,
        activities: _activities,
        expertName: _expertName,
        personnelCode: _personnelCode,
        expertPassword: _expertPassword,
        managerPassword: _managerPassword,
      );
    } catch (e) {
      _showMessage('خطا در ذخیره‌سازی: $e');
    }
  }

  // ============= متدهای کمکی =============
  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _getCurrentDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _getCurrentTime() => DateFormat('HH:mm').format(DateTime.now());
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<bool> _verifyPassword(String title, String correctPassword) async {
    final controller = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'رمز عبور',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text == correctPassword),
            child: const Text('ورود'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    return result ?? false;
  }

  // ============= متدهای تغییر برگه =============
  Future<void> _switchTab(int index) async {
    if (index == 1 && !await _verifyPassword('ورود به پنل مدیر', _managerPassword)) {
      _showMessage('رمز عبور مدیر صحیح نیست.');
      return;
    }
    setState(() => _currentTab = index);
  }

  // ============= متدهای مدیریت گزارش‌ها =============
  Future<void> _addReport() async {
    if (_activities.isEmpty) {
      _showMessage('ابتدا حداقل یک عنوان فعالیت ایجاد کنید.');
      return;
    }

    String selectedActivity = _activities.first;
    final descriptionController = TextEditingController();
    final minutesController = TextEditingController(text: '60');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ثبت فعالیت جدید'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedActivity,
                decoration: const InputDecoration(labelText: 'عنوان فعالیت'),
                items: _activities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => selectedActivity = v ?? selectedActivity,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مدت فعالیت به دقیقه',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'شرح و جزئیات فعالیت',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ثبت فعالیت'),
          ),
        ],
      ),
    );

    if (result != true) {
      descriptionController.dispose();
      minutesController.dispose();
      return;
    }

    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;
    descriptionController.dispose();
    minutesController.dispose();

    if (minutes <= 0) {
      _showMessage('مدت فعالیت باید بیشتر از صفر باشد.');
      return;
    }

    setState(() {
      _reports.add(Report(
        id: _generateId(),
        expertName: _expertName,
        personnelCode: _personnelCode,
        activity: selectedActivity,
        description: descriptionController.text.trim(),
        date: _getCurrentDate(),
        time: _getCurrentTime(),
        minutes: minutes,
      ));
    });

    await _saveData();
    _showMessage('فعالیت با موفقیت ثبت شد.');
  }

  // ============= متدهای خروجی/ورودی =============
  Future<void> _exportReports({String? customFileName}) async {
    if (_reports.isEmpty) {
      _showMessage('گزارشی برای خروجی وجود ندارد.');
      return;
    }

    try {
      final path = await _fileService.exportToCsv(_reports, fileName: customFileName);
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      _showMessage('خطا در خروجی گرفتن: $e');
    }
  }

  Future<void> _importReports() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) {
      _showMessage('فایل انتخاب‌شده قابل دسترسی نیست.');
      return;
    }

    try {
      final rows = await _fileService.importFromCsv(path);
      
      if (rows.length < 2) {
        _showMessage('فایل گزارش خالی است.');
        return;
      }

      int imported = 0, duplicated = 0;
      final existingIds = _reports.map((r) => r.id).toSet();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 8) continue;

        final id = row[0].toString();
        if (id.isEmpty || existingIds.contains(id)) {
          if (id.isNotEmpty) duplicated++;
          continue;
        }

        _reports.add(Report(
          id: id,
          expertName: row[1].toString(),
          personnelCode: row[2].toString(),
          date: row[3].toString(),
          time: row[4].toString(),
          activity: row[5].toString(),
          minutes: int.tryParse(row[6].toString()) ?? 0,
          description: row[7].toString(),
        ));
        
        existingIds.add(id);
        imported++;
      }

      await _saveData();
      setState(() {});
      
      final message = '$imported فعالیت وارد شد.${duplicated > 0 ? ' $duplicated مورد تکراری بود.' : ''}';
      _showMessage(message);
      
    } catch (e) {
      _showMessage('خطا در خواندن فایل گزارش.');
    }
  }

  // ============= متدهای مدیریت داده‌ها =============
  Future<void> _editExpertInfo() async {
    _expertNameController.text = _expertName;
    _personnelCodeController.text = _personnelCode;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اطلاعات کارشناس'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _expertNameController,
              decoration: const InputDecoration(labelText: 'نام و نام خانوادگی'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _personnelCodeController,
              decoration: const InputDecoration(labelText: 'کد پرسنلی'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() {
      _expertName = _expertNameController.text.trim().isEmpty 
          ? 'کارشناس نمونه' 
          : _expertNameController.text.trim();
      _personnelCode = _personnelCodeController.text.trim();
    });

    await _saveData();
    _showMessage('اطلاعات کارشناس ذخیره شد.');
  }

  Future<void> _manageActivities() async {
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final controller = TextEditingController();
          
          return AlertDialog(
            title: const Text('مدیریت عناوین فعالیت'),
            content: SizedBox(
              width: 450,
              height: 420,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _activities.length,
                      itemBuilder: (_, index) => ListTile(
                        title: Text(_activities[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setDialogState(() => _activities.removeAt(index));
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'عنوان فعالیت جدید'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty || _activities.contains(value)) {
                        if (_activities.contains(value)) {
                          _showMessage('این عنوان قبلاً وجود دارد.');
                        }
                        return;
                      }
                      setDialogState(() => _activities.add(value));
                      setState(() {});
                      controller.clear();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن عنوان'),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  await _saveData();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('ذخیره و بستن'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSettings() async {
    final managerController = TextEditingController(text: _managerPassword);
    final expertController = TextEditingController(text: _expertPassword);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تنظیمات'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('حالت تاریک'),
                value: _darkMode,
                onChanged: (value) => setState(() => _darkMode = value),
              ),
              const Divider(),
              TextField(
                controller: managerController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رمز مدیر'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expertController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رمز کارشناس'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () async {
              if (managerController.text.trim().isNotEmpty) {
                _managerPassword = managerController.text.trim();
              }
              if (expertController.text.trim().isNotEmpty) {
                _expertPassword = expertController.text.trim();
              }
              await _saveData();
              if (mounted) Navigator.pop(context);
              _showMessage('تنظیمات ذخیره شد.');
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    
    managerController.dispose();
    expertController.dispose();
  }

  // ============= متد build =============
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارشات مدیریت بازرسی',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2457A6),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2457A6),
        brightness: Brightness.dark,
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Scaffold(
              appBar: _buildAppBar(),
              body: _buildBody(),
              bottomNavigationBar: _buildBottomNavBar(),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('گزارشات مدیریت بازرسی'),
      actions: [
        if (_currentTab == 0) ...[
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _editExpertInfo,
            tooltip: 'اطلاعات کارشناس',
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: _manageActivities,
            tooltip: 'مدیریت فعالیت‌ها',
          ),
        ],
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
          tooltip: 'تنظیمات',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_currentTab == 0) {
      return _buildExpertPanel();
    } else {
      return _buildManagerPanel();
    }
  }

  Widget _buildExpertPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('کارشناس: $_expertName', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('کد پرسنلی: ${_personnelCode.isEmpty ? 'ثبت نشده' : _personnelCode}'),
                        Text('تعداد گزارش‌ها: ${_reports.length}'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _reports.isEmpty
              ? const Center(child: Text('هیچ گزارشی ثبت نشده است.'))
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (_, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(report.activity),
                        subtitle: Text(
                          '${report.date} - ${report.time} | ${report.minutes} دقیقه',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            setState(() => _reports.removeAt(index));
                            await _saveData();
                            _showMessage('گزارش حذف شد.');
                          },
                        ),
                        onTap: () => _showReportDetails(report),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildManagerPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('گزارش‌های مدیریت', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('تعداد کل گزارش‌ها: ${_reports.length}'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _reports.isEmpty
              ? const Center(child: Text('هیچ گزارشی ثبت نشده است.'))
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (_, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('${report.expertName} - ${report.activity}'),
                        subtitle: Text(
                          '${report.date} - ${report.time} | ${report.minutes} دقیقه',
                        ),
                        onTap: () => _showReportDetails(report),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showReportDetails(Report report) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(report.activity),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('کارشناس: ${report.expertName}'),
            Text('کد پرسنلی: ${report.personnelCode}'),
            Text('تاریخ: ${report.date}'),
            Text('ساعت: ${report.time}'),
            Text('مدت: ${report.minutes} دقیقه'),
            const Divider(),
            Text('شرح: ${report.description}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return NavigationBar(
      selectedIndex: _currentTab,
      onDestinationSelected: _switchTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'پنل کارشناس',
        ),
        NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: 'پنل مدیر',
        ),
      ],
      floating: true,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    );
  }
}

// ============= ویجت‌های اضافی (در صورت نیاز می‌توانید جدا کنید) =============
// می‌توانید ویجت‌های زیر را در فایل‌های جداگانه قرار دهید
