import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({Key? key}) : super(key: key);



  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final List<String> days = ["월", "화", "수", "목", "금", "토", "일"];
  final Map<String, String> startTimes = {};
  final Map<String, String> endTimes = {};
  final Map<String, bool> selectedDays = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userName;


  String? _roomId; // 방 ID 저장

  @override
  void initState() {
    super.initState();
    fetchUserName();
    for (String day in days) {
      selectedDays[day] = false; // 요일 선택 초기화
    }
  }

  // Firestore에서 사용자 이름 가져오기
  Future<void> fetchUserName() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          setState(() {
            userName = userDoc['name'] ?? '사용자';
          });
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
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

  Future<void> createRoomAndSaveData() async {
    Map<String, Map<String, String>> selectedDayData = {};

    for (String day in days) {
      if (selectedDays[day]!) {
        selectedDayData[day] = {
          'start': startTimes[day] ?? "없음",
          'end': endTimes[day] ?? "없음",
        };
      }
    }

    final roomId = DateTime.now().millisecondsSinceEpoch.toString();

    await _firestore.collection('meetingRooms').doc(roomId).set({
      'participants': userName, // 현재 사용자 ID (Firebase Auth로 대체 가능)
      'availability': selectedDayData,
    });

    setState(() {
      _roomId = roomId; // 생성된 방 ID 저장
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("방이 생성되었습니다.")),
    );
  }

  Future<void> findOverlapAndShowPopup() async {
    if (_roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("먼저 방을 생성하세요!")),
      );
      return;
    }

    final roomDoc = await _firestore.collection('meetingRooms').doc(_roomId).get();

    if (!roomDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("방 정보를 찾을 수 없습니다.")),
      );
      return;
    }

    final roomData = roomDoc.data() as Map<String, dynamic>;
    final availability = roomData['availability'] as Map<String, dynamic>;

    Map<String, String> overlap = {};

    for (String day in availability.keys) {
      if (startTimes.containsKey(day) && endTimes.containsKey(day)) {
        final otherStart = availability[day]['start'];
        final otherEnd = availability[day]['end'];

        final myStart = startTimes[day]!;
        final myEnd = endTimes[day]!;

        final start = myStart.compareTo(otherStart) > 0 ? myStart : otherStart;
        final end = myEnd.compareTo(otherEnd) < 0 ? myEnd : otherEnd;

        if (start.compareTo(end) < 0) {
          overlap[day] = "$start - $end";
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("겹치는 시간"),
          content: overlap.isEmpty
              ? const Text("겹치는 시간이 없습니다.")
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: overlap.entries
                .map((entry) => Text("${entry.key}: ${entry.value}"))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("닫기"),
            ),
          ],
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {

            },
          ),
        ],

      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
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
          Expanded(
            child: ListView.builder(
              itemCount: days.where((day) => selectedDays[day]!).length,
              itemBuilder: (context, index) {
                final day = days.where((day) => selectedDays[day]!).toList()[index];

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [


              ElevatedButton(
                onPressed: createRoomAndSaveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  "내 시간 기록",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              ElevatedButton(
                onPressed: findOverlapAndShowPopup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  "겹치는 시간 확인",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}
