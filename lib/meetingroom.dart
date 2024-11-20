import 'package:flutter/material.dart';

class MeetingRoomPage extends StatefulWidget {
  const MeetingRoomPage({Key? key}) : super(key: key);

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  String startAmPm = "AM";
  String endAmPm = "AM";
  int? startHour;
  int? endHour;

  void showTimePickerDialog(String type) {
    String tempAmPm = type == "시작" ? startAmPm : endAmPm;
    int? tempHour = type == "시작" ? startHour : endHour;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("$type 시간 선택"),
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
                        startAmPm = tempAmPm;
                        startHour = tempHour;
                      } else {
                        endAmPm = tempAmPm;
                        endHour = tempHour;
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
    List<String> days = ["일", "월", "화", "수", "목", "금", "토"];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "미팅 정하기",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: () {
              print("친구 초대");
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // 시작 시간, 끝나는 시간 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => showTimePickerDialog("시작"),
                    child: const Text("시작 시간"),
                  ),
                  if (startHour != null)
                    Text(
                      "$startHour $startAmPm",
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => showTimePickerDialog("끝나는"),
                    child: const Text("끝나는 시간"),
                  ),
                  if (endHour != null)
                    Text(
                      "$endHour $endAmPm",
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 요일 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: days
                .map((day) => Text(
              day,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ))
                .toList(),
          ),
          const Spacer(),
          // 겹치는 시간 확인 버튼
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
                print("겹치는 시간 확인");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding:
                const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                "겹치는 시간 확인",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
