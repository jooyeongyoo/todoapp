import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:table_calendar/table_calendar.dart'; 

class Task {
  String id;
  String title;
  bool isDone;
  String memo;
  String category;
  String startTime;
  String endTime;

  Task({
    String? id,
    required this.title,
    this.isDone = false,
    this.memo = "",
    this.category = "기본",
    this.startTime = "",
    this.endTime = "",
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() + title;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'memo': memo,
    'category': category,
    'startTime': startTime,
    'endTime': endTime,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'],
    isDone: json['isDone'] ?? false,
    memo: json['memo'] ?? "",
    category: json['category'] ?? "기본",
    startTime: json['startTime'] ?? "",
    endTime: json['endTime'] ?? "",
  );
}

class Routine {
  String id;
  String title;
  String memo;
  String category;
  String startTime;
  String endTime;
  String repeatType;
  String repeatValue;
  DateTime startDate;

  Routine({
    String? id,
    required this.title,
    this.memo = "",
    this.category = "기본",
    this.startTime = "",
    this.endTime = "",
    required this.repeatType,
    required this.repeatValue,
    required this.startDate,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() + title;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'memo': memo,
    'category': category,
    'startTime': startTime,
    'endTime': endTime,
    'repeatType': repeatType,
    'repeatValue': repeatValue,
    'startDate': startDate.toIso8601String(),
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'],
    memo: json['memo'] ?? "",
    category: json['category'] ?? "기본",
    startTime: json['startTime'] ?? "",
    endTime: json['endTime'] ?? "",
    repeatType: json['repeatType'] ?? "매주",
    repeatValue: json['repeatValue'] ?? "",
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
  );
}

final ValueNotifier<Color> appThemeColor = ValueNotifier<Color>(const Color(0xFFE2F0CB));
final ValueNotifier<String> appFontFamily = ValueNotifier<String>('Noto Sans KR');

Color _darkenColor(Color c, [int percent = 40]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.fromARGB(
    c.alpha,
    (c.red * f).round(),
    (c.green * f).round(),
    (c.blue * f).round()
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  final colorInt = prefs.getInt('themeColor');
  if (colorInt != null) {
    appThemeColor.value = Color(colorInt);
  }
  
  final fontStr = prefs.getString('themeFont');
  if (fontStr != null) {
    appFontFamily.value = fontStr;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  TextTheme _getTextTheme(String font, TextTheme base) {
    switch (font) {
      case 'Nanum Pen Script': return GoogleFonts.nanumPenScriptTextTheme(base);
      case 'Jua': return GoogleFonts.juaTextTheme(base);
      case 'Dongle': return GoogleFonts.dongleTextTheme(base);
      case 'Gowun Dodum': return GoogleFonts.gowunDodumTextTheme(base);
      case 'Noto Sans KR':
      default:
        return GoogleFonts.notoSansKrTextTheme(base);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appThemeColor,
      builder: (context, color, child) {
        return ValueListenableBuilder<String>(
          valueListenable: appFontFamily,
          builder: (context, font, child) {
            return MaterialApp(
              title: '스케줄 앱',
              debugShowCheckedModeBanner: false, 
              theme: ThemeData(
                useMaterial3: true, 
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  primary: color,
                  brightness: Brightness.light,
                ),
                textTheme: _getTextTheme(font, Theme.of(context).textTheme),
                appBarTheme: AppBarTheme(
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: color,
                  foregroundColor: Colors.black87,
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  labelStyle: TextStyle(color: Colors.black87),
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                dialogTheme: const DialogThemeData(
                  contentTextStyle: TextStyle(color: Colors.black87),
                  titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              home: const TaskScreen(),
            );
          },
        );
      }
    );
  }
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  
  final Map<String, List<Task>> _tasksMap = {};
  List<Routine> _routines = [];
  final Map<String, List<String>> _completedRoutines = {}; 
  List<String> _categories = ['기본', '업무', '개인'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _getDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load categories
    String? categoriesData = prefs.getString('categories');
    if (categoriesData != null) {
      _categories = List<String>.from(jsonDecode(categoriesData));
    }
    
    // Load tasks
    String? tasksData = prefs.getString('tasks');
    if (tasksData != null) {
      Map<String, dynamic> decoded = jsonDecode(tasksData);
      decoded.forEach((key, value) {
        _tasksMap[key] = (value as List).map((taskJson) => Task.fromJson(taskJson)).toList();
      });
    }
    
    // Load routines
    String? routinesData = prefs.getString('routines');
    if (routinesData != null) {
      List<dynamic> decoded = jsonDecode(routinesData);
      _routines = decoded.map((json) => Routine.fromJson(json)).toList();
    }
    
    // Load routine completions
    String? completionsData = prefs.getString('routineCompletions');
    if (completionsData != null) {
      Map<String, dynamic> decoded = jsonDecode(completionsData);
      decoded.forEach((key, value) {
        _completedRoutines[key] = List<String>.from(value);
      });
    }

    setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categories', jsonEncode(_categories));
    
    Map<String, dynamic> encodedTasks = {};
    _tasksMap.forEach((key, value) {
      encodedTasks[key] = value.map((task) => task.toJson()).toList();
    });
    await prefs.setString('tasks', jsonEncode(encodedTasks));
    
    await prefs.setString('routines', jsonEncode(_routines.map((r) => r.toJson()).toList()));
    
    await prefs.setString('routineCompletions', jsonEncode(_completedRoutines));
  }

  List<Routine> _getTodayRoutines(DateTime date) {
    return _routines.where((r) {
      DateTime start = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      DateTime checkDate = DateTime(date.year, date.month, date.day);
      if (checkDate.isBefore(start)) return false;
      
      try {
        if (r.repeatType == '매주') {
          if (r.repeatValue.isEmpty) return false;
          List<int> days = r.repeatValue.split(',').map((e) => int.parse(e.trim())).toList();
          return days.contains(checkDate.weekday);
        } else if (r.repeatType == '매월') {
          if (r.repeatValue.isEmpty) return false;
          int day = int.parse(r.repeatValue.trim());
          return checkDate.day == day;
        } else if (r.repeatType == 'N일마다') {
          if (r.repeatValue.isEmpty) return false;
          int interval = int.parse(r.repeatValue.trim());
          if (interval <= 0) return false;
          int diff = checkDate.difference(start).inDays;
          return diff % interval == 0;
        }
      } catch (e) {
        return false;
      }
      return false;
    }).toList();
  }

  void _showAddRoutineDialog() {
    TextEditingController titleController = TextEditingController();
    String selectedCategory = _categories.first;
    String repeatType = '매주';
    String repeatValue = '1';
    List<int> selectedWeekdays = [1];
    TextEditingController intervalController = TextEditingController(text: '3');
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('반복 루틴 추가', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '루틴 내용',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: '카테고리',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: repeatType,
                      decoration: InputDecoration(
                        labelText: '반복 유형',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: ['매주', '매월', 'N일마다'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setDialogState(() {
                        repeatType = val!;
                        if (repeatType == '매주') selectedWeekdays = [1];
                        if (repeatType == '매월') repeatValue = '1';
                        if (repeatType == 'N일마다') repeatValue = intervalController.text;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (repeatType == '매주')
                      Wrap(
                        spacing: 8,
                        children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                          final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
                          final isSelected = selectedWeekdays.contains(day);
                          return ChoiceChip(
                            label: Text(dayNames[day - 1]),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedWeekdays.add(day);
                                } else {
                                  if (selectedWeekdays.length > 1) {
                                    selectedWeekdays.remove(day);
                                  }
                                }
                                repeatValue = selectedWeekdays.join(',');
                              });
                            },
                          );
                        }).toList(),
                      ),
                    if (repeatType == '매월')
                      DropdownButtonFormField<String>(
                        value: repeatValue,
                        decoration: InputDecoration(
                          labelText: '반복할 일',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: List.generate(31, (i) => (i + 1).toString())
                            .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                            .toList(),
                        onChanged: (val) => setDialogState(() => repeatValue = val!),
                      ),
                    if (repeatType == 'N일마다')
                      TextField(
                        controller: intervalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '반복 주기 (일)',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          repeatValue = val;
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      if (repeatType == '매주') repeatValue = selectedWeekdays.join(',');
                      if (repeatType == 'N일마다' && intervalController.text.isEmpty) repeatValue = '1';
                      
                      Routine newRoutine = Routine(
                        title: titleController.text,
                        category: selectedCategory,
                        repeatType: repeatType,
                        repeatValue: repeatValue,
                        startDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
                      );
                      setState(() {
                        _routines.add(newRoutine);
                      });
                      _saveData();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTaskDialog() {
    TextEditingController titleController = TextEditingController();
    String selectedCategory = _categories.first;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('할 일 추가', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '할 일 내용',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: '카테고리',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.now(), initialEntryMode: TimePickerEntryMode.input);
                            if (time != null) setDialogState(() => startTime = time);
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(startTime != null ? startTime!.format(context) : '시작 시간'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.now(), initialEntryMode: TimePickerEntryMode.input);
                            if (time != null) setDialogState(() => endTime = time);
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(endTime != null ? endTime!.format(context) : '종료 시간'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      setState(() {
                        String dateKey = _getDateKey(_selectedDate);
                        if (_tasksMap[dateKey] == null) _tasksMap[dateKey] = [];
                        _tasksMap[dateKey]!.add(Task(
                          title: titleController.text,
                          category: selectedCategory,
                          startTime: startTime != null ? startTime!.format(context) : '',
                          endTime: endTime != null ? endTime!.format(context) : '',
                        ));
                      });
                      _saveData();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMemoDetailsDialog(dynamic item, String itemType) {
    // item is either Task or Routine. Note: Routines modifying memo is tricky because they are definitions.
    // For simplicity, modifying a Routine's memo applies to the Routine globally.
    TextEditingController memoController = TextEditingController(text: item.memo);
    TextEditingController titleController = TextEditingController(text: item.title);
    TimeOfDay? parsedStartTime;
    TimeOfDay? parsedEndTime;
    
    if (item.startTime.isNotEmpty) {
      final parts = item.startTime.split(RegExp(r'[:\s]'));
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        int m = int.tryParse(parts[1]) ?? 0;
        if (item.startTime.contains('PM') && h < 12) h += 12;
        if (item.startTime.contains('AM') && h == 12) h = 0;
        parsedStartTime = TimeOfDay(hour: h, minute: m);
      }
    }
    if (item.endTime.isNotEmpty) {
      final parts = item.endTime.split(RegExp(r'[:\s]'));
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        int m = int.tryParse(parts[1]) ?? 0;
        if (item.endTime.contains('PM') && h < 12) h += 12;
        if (item.endTime.contains('AM') && h == 12) h = 0;
        parsedEndTime = TimeOfDay(hour: h, minute: m);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('상세 내용 수정', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '제목',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: memoController,
                      decoration: InputDecoration(
                        labelText: '메모 (길게 눌러서 추가 가능)',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: parsedStartTime ?? TimeOfDay.now(), initialEntryMode: TimePickerEntryMode.input);
                            if (time != null) setDialogState(() => parsedStartTime = time);
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(parsedStartTime != null ? parsedStartTime!.format(context) : '시작 시간'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: parsedEndTime ?? TimeOfDay.now(), initialEntryMode: TimePickerEntryMode.input);
                            if (time != null) setDialogState(() => parsedEndTime = time);
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(parsedEndTime != null ? parsedEndTime!.format(context) : '종료 시간'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      item.title = titleController.text;
                      item.memo = memoController.text;
                      item.startTime = parsedStartTime != null ? parsedStartTime!.format(context) : '';
                      item.endTime = parsedEndTime != null ? parsedEndTime!.format(context) : '';
                    });
                    _saveData();
                    Navigator.pop(context);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTaskOptions(BuildContext context, dynamic item, String dateKey, String itemType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blue),
                title: const Text('수정하기'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMemoDetailsDialog(item, itemType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제하기'),
                onTap: () {
                  setState(() {
                    if (itemType == 'task') {
                      _tasksMap[dateKey]?.remove(item);
                    } else if (itemType == 'routine') {
                      _routines.removeWhere((r) => r.id == item.id);
                    }
                  });
                  _saveData();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateKey = _getDateKey(_selectedDate);
    List<Routine> todayRoutines = _getTodayRoutines(_selectedDate);
    List<Task> todayTasks = _tasksMap[dateKey] ?? [];

    Color fontColor = _darkenColor(Theme.of(context).colorScheme.primary, 85);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${_selectedDate.month}월 ${_selectedDate.day}일', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: '메뉴',
            onSelected: (value) {
              if (value == 'routine') {
                _showAddRoutineDialog();
              } else if (value == 'manage_routines') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => RoutineListScreen(
                  routines: _routines,
                  onDelete: (r) {
                    setState(() {
                      _routines.remove(r);
                    });
                    _saveData();
                  }
                )));
              } else if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'routine',
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('반복 루틴 추가'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manage_routines',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('루틴 관리'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('설정'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDate,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDate, selectedDay)) {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDate = focusedDay;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDate = focusedDay;
            },
            availableCalendarFormats: const {
              CalendarFormat.month: '월',
              CalendarFormat.week: '주',
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonShowsNext: false,
            ),
          ),
          Expanded(
            child: (todayRoutines.isEmpty && todayTasks.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note_rounded, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          '오늘은 일정이 없네요!\n휴식을 취하거나 새 일정을 추가해보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 80),
                    children: [
                      // Routines Section
                      if (todayRoutines.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            '루틴(반복적으로 할 일)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        ...todayRoutines.map((r) {
                          bool isDone = _completedRoutines[dateKey]?.contains(r.id) ?? false;
                          String timeStr = "";
                          if (r.startTime.isNotEmpty && r.endTime.isNotEmpty) timeStr = "${r.startTime} ~ ${r.endTime}";
                          else if (r.startTime.isNotEmpty) timeStr = r.startTime;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Checkbox(
                                value: isDone,
                                shape: const CircleBorder(),
                                activeColor: Theme.of(context).colorScheme.primary,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _completedRoutines.putIfAbsent(dateKey, () => []).add(r.id);
                                    } else {
                                      _completedRoutines[dateKey]?.remove(r.id);
                                    }
                                  });
                                  _saveData();
                                },
                              ),
                              title: Text(
                                r.title,
                                style: TextStyle(
                                  fontSize: r.memo.isEmpty ? 17.0 : 15.0,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? Colors.grey[400] : fontColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onPressed: () => _showTaskOptions(context, r, dateKey, 'routine'),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                                  if (r.memo.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(r.memo, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                    ),
                                ],
                              ),
                              onLongPress: () => _showTaskOptions(context, r, dateKey, 'routine'),
                            ),
                          );
                        }).toList(),
                      ],

                      // Todo Section
                      if (todayTasks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Todo',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        ..._categories.map((cat) {
                          List<Task> catTasks = todayTasks.where((t) => t.category == cat).toList();
                          if (catTasks.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 20, top: 8, bottom: 4),
                                child: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 13)),
                              ),
                              ...catTasks.map((task) {
                                String timeStr = "";
                                if (task.startTime.isNotEmpty && task.endTime.isNotEmpty) timeStr = "${task.startTime} ~ ${task.endTime}";
                                else if (task.startTime.isNotEmpty) timeStr = task.startTime;

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.grey[200]!, width: 1),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Checkbox(
                                      value: task.isDone,
                                      shape: const CircleBorder(),
                                      activeColor: Theme.of(context).colorScheme.primary,
                                      onChanged: (value) {
                                        setState(() => task.isDone = value!);
                                        _saveData();
                                      },
                                    ),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: task.memo.isEmpty ? 17.0 : 15.0,
                                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                                        color: task.isDone ? Colors.grey[400] : fontColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                      onPressed: () => _showTaskOptions(context, task, dateKey, 'task'),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (timeStr.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                              ],
                                            ),
                                          ),
                                        if (task.memo.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(task.memo, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                          ),
                                      ],
                                    ),
                                    onLongPress: () => _showTaskOptions(context, task, dateKey, 'task'),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }).toList(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('할 일 추가'),
        elevation: 4,
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Color> colorOptions = [
      const Color(0xFF6A9C89), 
      const Color(0xFFE2F0CB), 
      const Color(0xFFFFFBD4), 
      const Color(0xFFFFE6EB), 
      const Color(0xFFE0D8F7), 
      const Color(0xFFD7E3FC), 
      const Color(0xFFFFDAC1), 
      Colors.blueAccent,
      Colors.indigo,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
      Colors.brown,
      Colors.teal,
      Colors.blueGrey,
    ];

    final List<String> fontOptions = [
      'Noto Sans KR',
      'Nanum Pen Script',
      'Jua',
      'Dongle',
      'Gowun Dodum',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('글자 폰트 변경', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ValueListenableBuilder<String>(
              valueListenable: appFontFamily,
              builder: (context, currentFont, child) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: fontOptions.map((fontName) {
                    bool isSelected = currentFont == fontName;
                    return ChoiceChip(
                      label: Text(fontName),
                      selected: isSelected,
                      onSelected: (selected) async {
                        if (selected) {
                          appFontFamily.value = fontName;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('themeFont', fontName);
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const Divider(height: 40),
          const ListTile(
            title: Text('테마 색상 변경', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colorOptions.map((color) {
                return GestureDetector(
                  onTap: () async {
                    appThemeColor.value = color;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('themeColor', color.value);
                  },
                  child: ValueListenableBuilder<Color>(
                    valueListenable: appThemeColor,
                    builder: (context, currentColor, child) {
                      bool isSelected = currentColor.value == color.value;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class RoutineListScreen extends StatefulWidget {
  final List<Routine> routines;
  final Function(Routine) onDelete;

  const RoutineListScreen({super.key, required this.routines, required this.onDelete});

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('루틴 관리'),
      ),
      body: widget.routines.isEmpty 
          ? const Center(child: Text('등록된 루틴이 없습니다.', style: TextStyle(color: Colors.black87)))
          : ListView.builder(
              itemCount: widget.routines.length,
              itemBuilder: (context, index) {
                final r = widget.routines[index];
                String repeatStr = '';
                if (r.repeatType == '매주') {
                  List<String> days = ['월', '화', '수', '목', '금', '토', '일'];
                  List<String> selected = r.repeatValue.split(',').map((e) => days[int.parse(e) - 1]).toList();
                  repeatStr = '매주 ${selected.join(", ")}';
                } else if (r.repeatType == '매월') {
                  repeatStr = '매월 ${r.repeatValue}일';
                } else if (r.repeatType == 'N일마다') {
                  repeatStr = '${r.repeatValue}일 마다';
                }
                
                return ListTile(
                  title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  subtitle: Text(repeatStr, style: const TextStyle(color: Colors.black54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('루틴 삭제', style: TextStyle(color: Colors.black87)),
                          content: const Text('이 루틴을 삭제하시겠습니까?', style: TextStyle(color: Colors.black87)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                            FilledButton(
                              onPressed: () {
                                widget.onDelete(r);
                                setState(() {});
                                Navigator.pop(ctx);
                              },
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
