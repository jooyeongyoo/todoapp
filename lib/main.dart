import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Task 클래스 (저장을 위해 JSON 변환 기능 추가)
class Task {
  String title;
  bool isDone;
  String memo;
  String category;

  Task({
    required this.title,
    this.isDone = false,
    this.memo = "",
    this.category = "기본",
  });

  // Task 객체를 JSON(문자열)으로 변환
  Map<String, dynamic> toJson() => {
    'title': title,
    'isDone': isDone,
    'memo': memo,
    'category': category,
  };

  // JSON(문자열)을 다시 Task 객체로 복원
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    title: json['title'],
    isDone: json['isDone'] ?? false,
    memo: json['memo'] ?? "",
    category: json['category'] ?? "기본",
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스케줄 앱',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TaskScreen(),
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
  final Map<String, List<Task>> _tasksMap = {};
  
  List<String> _categories = ['기본', '업무', '개인', '운동'];
  String _currentCategoryFilter = '전체';
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _routineTitleController = TextEditingController();

  // [신규] 앱이 처음 실행될 때 저장된 데이터 불러오기
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // [신규] 기기에서 데이터 불러오기 함수
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 카테고리 목록 불러오기
    List<String>? savedCategories = prefs.getStringList('categories');
    if (savedCategories != null) {
      _categories = savedCategories;
    }

    // 2. 할 일 목록 불러오기
    String? jsonString = prefs.getString('tasksMap');
    if (jsonString != null) {
      Map<String, dynamic> decodedMap = jsonDecode(jsonString);
      Map<String, List<Task>> loadedTasks = {};
      
      decodedMap.forEach((key, value) {
        loadedTasks[key] = (value as List).map((item) => Task.fromJson(item)).toList();
      });

      setState(() {
        _tasksMap.addAll(loadedTasks);
      });
    }
  }

  // [신규] 기기에 데이터 저장하기 함수 (변경사항이 생길 때마다 호출)
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 카테고리 목록 저장
    await prefs.setStringList('categories', _categories);

    // 2. 할 일 목록 저장
    Map<String, dynamic> encodedMap = {};
    _tasksMap.forEach((key, list) {
      encodedMap[key] = list.map((task) => task.toJson()).toList();
    });
    
    await prefs.setString('tasksMap', jsonEncode(encodedMap));
  }

  String _getDateString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentCategoryFilter = '전체';
      });
    }
  }

  void _moveTaskToDate(Task task, DateTime fromDate, DateTime toDate) {
    setState(() {
      String fromKey = _getDateString(fromDate);
      String toKey = _getDateString(toDate);

      _tasksMap[fromKey]?.remove(task);

      if (_tasksMap[toKey] == null) _tasksMap[toKey] = [];
      _tasksMap[toKey]!.add(task);
    });
    _saveData(); // 저장
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${toDate.month}월 ${toDate.day}일로 일정이 이동되었습니다.')),
    );
  }

  Future<void> _selectDateAndMoveTask(Task task, DateTime currentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != currentDate) {
      _moveTaskToDate(task, currentDate, picked);
    }
  }

  void _showEditTitleDialog(Task task) {
    _titleController.text = task.title; 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('할 일 이름 변경'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: '새로운 이름을 입력하세요'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty) {
                setState(() => task.title = _titleController.text);
                _saveData(); // 저장
                _titleController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showEditMemoDetailsDialog(Task task) {
    _memoController.text = task.memo; 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상세 메모 작성'),
        content: TextField(
          controller: _memoController,
          decoration: const InputDecoration(hintText: '참고할 내용을 입력하세요'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              setState(() => task.memo = _memoController.text);
              _saveData(); // 저장
              _memoController.clear();
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(Task task) {
    String selectedCategory = task.category;
    if (!_categories.contains(selectedCategory)) _categories.add(selectedCategory);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('카테고리 변경'),
          content: DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(icon: Icon(Icons.folder_open)),
            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) {
              if (val != null) setDialogState(() => selectedCategory = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () {
                setState(() => task.category = selectedCategory);
                _saveData(); // 저장
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewCategoryDialog() {
    TextEditingController newCategoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 카테고리 추가'),
        content: TextField(
          controller: newCategoryController,
          decoration: const InputDecoration(hintText: '카테고리 이름 입력'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (newCategoryController.text.isNotEmpty) {
                setState(() {
                  if (!_categories.contains(newCategoryController.text)) {
                    _categories.add(newCategoryController.text);
                  }
                });
                _saveData(); // 카테고리 추가 시 저장
                Navigator.pop(context);
                _showCategoryFilterDialog(); 
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilterDialog() {
    List<String> filterOptions = ['전체', ..._categories];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('카테고리 선택'),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
              onPressed: () {
                Navigator.pop(context);
                _showAddNewCategoryDialog();
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: filterOptions.map((cat) {
              return ListTile(
                title: Text(cat),
                trailing: _currentCategoryFilter == cat ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _currentCategoryFilter = cat);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showTaskOptions(BuildContext context, Task task, DateTime currentDate) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.subject), title: const Text('상세 메모 작성/수정'),
              onTap: () { Navigator.pop(context); _showEditMemoDetailsDialog(task); },
            ),
            ListTile(
              leading: const Icon(Icons.edit), title: const Text('이름 변경'),
              onTap: () { Navigator.pop(context); _showEditTitleDialog(task); },
            ),
            ListTile(
              leading: const Icon(Icons.folder), title: const Text('카테고리 변경'),
              onTap: () { Navigator.pop(context); _showEditCategoryDialog(task); },
            ),
            ListTile(
              leading: const Icon(Icons.next_plan), title: const Text('내일 하기'),
              onTap: () {
                Navigator.pop(context);
                _moveTaskToDate(task, currentDate, currentDate.add(const Duration(days: 1))); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month), title: const Text('다른 날 하기'),
              onTap: () { Navigator.pop(context); _selectDateAndMoveTask(task, currentDate); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('삭제하기', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _tasksMap[_getDateString(currentDate)]?.remove(task));
                _saveData(); // 삭제 후 저장
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    _titleController.clear();
    String selectedCategory = '기본';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${_selectedDate.month}월 ${_selectedDate.day}일 할 일 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: '할 일을 입력하세요'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(icon: Icon(Icons.folder_open, size: 20)),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedCategory = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () {
                if (_titleController.text.isNotEmpty) {
                  setState(() {
                    String dateKey = _getDateString(_selectedDate);
                    if (_tasksMap[dateKey] == null) _tasksMap[dateKey] = [];
                    _tasksMap[dateKey]!.add(Task(title: _titleController.text, category: selectedCategory));
                  });
                  _saveData(); // 추가 후 저장
                  _titleController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRoutineDialog() {
    _routineTitleController.clear();
    String selectedCategory = '기본';
    String repeatType = '매주';
    List<int> selectedWeekdays = []; 
    int selectedMonthDay = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('반복 루틴 추가 (1년치 자동 생성)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _routineTitleController,
                  decoration: const InputDecoration(hintText: '루틴 이름 (예: 헬스장, 회의)'),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(icon: Icon(Icons.folder_open, size: 20)),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 20),
                const Text('반복 주기', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Radio<String>(
                      value: '매주', groupValue: repeatType,
                      onChanged: (val) => setDialogState(() => repeatType = val!),
                    ), const Text('매주 '),
                    Radio<String>(
                      value: '매월', groupValue: repeatType,
                      onChanged: (val) => setDialogState(() => repeatType = val!),
                    ), const Text('매월 '),
                  ],
                ),
                if (repeatType == '매주')
                  Wrap(
                    spacing: 4.0,
                    children: List.generate(7, (index) {
                      int dayIndex = index + 1; 
                      List<String> dayNames = ['월', '화', '수', '목', '금', '토', '일'];
                      return FilterChip(
                        label: Text(dayNames[index]),
                        selected: selectedWeekdays.contains(dayIndex),
                        onSelected: (bool selected) {
                          setDialogState(() {
                            if (selected) selectedWeekdays.add(dayIndex);
                            else selectedWeekdays.remove(dayIndex);
                          });
                        },
                      );
                    }),
                  ),
                if (repeatType == '매월')
                  Row(
                    children: [
                      const Text('매월  '),
                      DropdownButton<int>(
                        value: selectedMonthDay,
                        items: List.generate(31, (index) => index + 1)
                            .map((day) => DropdownMenuItem(value: day, child: Text('$day일')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedMonthDay = val);
                        },
                      ),
                      const Text(' 마다'),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () {
                if (_routineTitleController.text.isEmpty) return;
                if (repeatType == '매주' && selectedWeekdays.isEmpty) return; 

                setState(() {
                  DateTime startDate = DateTime.now(); 
                  for (int i = 0; i < 365; i++) {
                    DateTime loopDate = startDate.add(Duration(days: i));
                    bool shouldAdd = false;

                    if (repeatType == '매주' && selectedWeekdays.contains(loopDate.weekday)) {
                      shouldAdd = true;
                    } else if (repeatType == '매월' && loopDate.day == selectedMonthDay) {
                      shouldAdd = true;
                    }

                    if (shouldAdd) {
                      String dateKey = _getDateString(loopDate);
                      if (_tasksMap[dateKey] == null) _tasksMap[dateKey] = [];
                      
                      _tasksMap[dateKey]!.add(Task(
                        title: _routineTitleController.text,
                        category: selectedCategory,
                        memo: '🔄 반복 루틴',
                      ));
                    }
                  }
                });
                
                _saveData(); // 루틴 자동 생성 완료 후 일괄 저장
                _routineTitleController.clear();
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('1년간의 반복 일정이 성공적으로 등록되었습니다!')),
                );
              },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _categoryController.dispose();
    _routineTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dateKey = _getDateString(_selectedDate);
    List<Task> allDayTasks = _tasksMap[dateKey] ?? [];
    
    List<Task> displayTasks = _currentCategoryFilter == '전체' 
        ? allDayTasks 
        : allDayTasks.where((task) => task.category == _currentCategoryFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${_selectedDate.month}월 ${_selectedDate.day}일 할 일'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: '반복 루틴 추가',
            onPressed: _showAddRoutineDialog,
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: '카테고리 필터',
            onPressed: _showCategoryFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '날짜 변경',
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: displayTasks.isEmpty
          ? Center(
              child: Text(
                _currentCategoryFilter == '전체' 
                  ? '이 날의 할 일이 없습니다! 우측 하단 버튼을 눌러 추가해보세요.'
                  : '[$_currentCategoryFilter] 카테고리에 해당하는 할 일이 없습니다.'
              )
            )
          : ListView.builder(
              itemCount: displayTasks.length,
              itemBuilder: (context, index) {
                final task = displayTasks[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: CheckboxListTile(
                    value: task.isDone,
                    onChanged: (bool? newValue) {
                      setState(() {
                        task.isDone = newValue ?? false;
                      });
                      _saveData(); // 체크박스를 터치할 때도 저장
                    },
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.category,
                            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                          ),
                        ),
                        Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: task.isDone ? Colors.grey : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: task.memo.isNotEmpty
                        ? Text(
                            task.memo,
                            style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: Colors.grey[700],
                            ),
                          )
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        _showTaskOptions(context, task, _selectedDate);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}