import 'package:flutter/material.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({Key? key}) : super(key: key);

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final List<String> days = ["월", "화", "수", "목", "금", "토", "일"];
  final Map<String, bool?> availability = {};
  final Map<String, String> startTimes = {};
  final Map<String, String> endTimes = {};
  final Map<String, bool> selectedDays = {};

  @override
  void initState() {
    super.initState();
    for (String day in days) {
      availability[day] = null; // 초기 상태
      selectedDays[day] = false; // 요일 선택 초기화
    }
  }

  void showTimePickerDialog(String day, String type) {
    String tempAmPm = "AM";
    int? tempHour;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("$type 시간 선택 ($day)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AM/PM 선택
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text("AM"),
                        selected: tempAmPm == "AM",
                        onSelected: (selected) {
                          setDialogState(() {
                            tempAmPm = "AM";
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text("PM"),
                        selected: tempAmPm == "PM",
                        onSelected: (selected) {
                          setDialogState(() {
                            tempAmPm = "PM";
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 시간 선택
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(12, (index) {
                      int hour = index + 1;
                      return ChoiceChip(
                        label: Text("$hour"),
                        selected: tempHour == hour,
                        onSelected: (selected) {
                          setDialogState(() {
                            tempHour = hour;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (type == "시작") {
                        startTimes[day] = "${tempHour ?? 4} $tempAmPm";
                      } else {
                        endTimes[day] = "${tempHour ?? 5} $tempAmPm";
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("확인"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "요일별 가능 여부",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // 상단 요일 선택 버튼
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: days.map((day) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FilterChip(
                    label: Text(day),
                    selected: selectedDays[day]!,
                    onSelected: (selected) {
                      setState(() {
                        selectedDays[day] = selected;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),
          // 선택된 요일만 표시
          Expanded(
            child: ListView.builder(
              itemCount: days.where((day) => selectedDays[day]!).length,
              itemBuilder: (context, index) {
                final day =
                    days.where((day) => selectedDays[day]!).toList()[index];

                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              showTimePickerDialog(day, "시작");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            child: Text(
                              startTimes[day] ?? "시작 시간",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              showTimePickerDialog(day, "끝나는");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                            ),
                            child: Text(
                              endTimes[day] ?? "끝나는 시간",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                availability[day] = null;
                                startTimes.remove(day);
                                endTimes.remove(day);
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            child: const Text("리셋"),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
