import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvailabilityPage extends StatefulWidget {
  final String myuid;
  const AvailabilityPage({super.key, required this.myuid});

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
    fetchExistingAvailability();
    for (String day in days) {
      selectedDays[day] = false; // 요일 선택 초기화
    }
  }

  // Firestore에서 기존의 내 데이터 가져오기
  Future<void> fetchExistingAvailability() async {
    final existingRoomQuery = await _firestore
        .collection('meetingRooms')
        .where('participants', arrayContains: widget.myuid)
        .get();

    if (existingRoomQuery.docs.isNotEmpty) {
      final roomDoc = existingRoomQuery.docs.first;
      final roomData = roomDoc.data() as Map<String, dynamic>;

      final availability = roomData['availability'] as Map<String, dynamic>?;

      if (availability != null && availability.containsKey(widget.myuid)) {
        final userAvailability = availability[widget.myuid] as Map<String, dynamic>;

        setState(() {
          // Firestore에서 가져온 데이터를 startTimes, endTimes, selectedDays에 반영
          userAvailability.forEach((day, times) {
            startTimes[day] = times['start'] ?? "없음";
            endTimes[day] = times['end'] ?? "없음";
            selectedDays[day] = true; // 선택된 요일 표시
          });
        });
      }
    }
  }

  Future<void> leaveRoom() async {
    // 방 검색
    final existingRoomQuery = await _firestore
        .collection('meetingRooms')
        .where('participants', arrayContains: widget.myuid)
        .get();

    if (existingRoomQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("현재 참여 중인 방이 없습니다.")),
      );
      return;
    }

    final roomDoc = existingRoomQuery.docs.first;
    final roomId = roomDoc.id;

    final roomData = roomDoc.data() as Map<String, dynamic>;

    // 방에서 사용자 데이터 제거
    await _firestore.collection('meetingRooms').doc(roomId).update({
      'availability.${widget.myuid}': FieldValue.delete(), // availability 내 특정 UID 삭제
      'participants': FieldValue.arrayRemove([widget.myuid]), // 참가자 목록에서 제거
      'participantDetails': FieldValue.arrayRemove([
        {'uid': widget.myuid, 'name': userName}
      ]), // 참가자 상세 정보에서 제거
    });


    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("방에서 나갔습니다.")),
    );

    setState(() {
      _roomId = null; // 방 ID 초기화
    });
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

    // 선택된 요일 데이터를 정리
    for (String day in days) {
      if (selectedDays[day]!) {
        selectedDayData[day] = {
          'start': startTimes[day] ?? "없음",
          'end': endTimes[day] ?? "없음",
        };
      }
    }

    // 기존 방 검색
    final existingRoomQuery = await _firestore
        .collection('meetingRooms')
        .where('participants', arrayContains: widget.myuid)
        .get();

    if (existingRoomQuery.docs.isNotEmpty) {
      // 기존 방이 있으면 그 방에 데이터를 추가
      final roomDoc = existingRoomQuery.docs.first;
      final roomId = roomDoc.id;
      // 기존 availability 데이터 가져오기
      final Map<String, dynamic> currentAvailability =
          roomDoc.data()['availability'] as Map<String, dynamic>? ?? {};

      // 현재 사용자의 UID로 데이터 추가 또는 업데이트
      currentAvailability[widget.myuid] = selectedDayData;

      await _firestore.collection('meetingRooms').doc(roomId).update({
        'availability': currentAvailability, // 병합된 데이터 저장
      });


      setState(() {
        _roomId = roomId; // 기존 방 ID 저장
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("기존 방에 데이터가 추가되었습니다.")),
      );
    } else {
      // 기존 방이 없으면 새 방 생성
      final roomId = DateTime.now().millisecondsSinceEpoch.toString();

      await _firestore.collection('meetingRooms').doc(roomId).set({
        'availability': {
          widget.myuid: selectedDayData, // UID 기준으로 데이터 저장
        },
        'participants': [widget.myuid], // 현재 사용자 추가
        'participantDetails': [
          {'uid': widget.myuid, 'name': userName}
        ],
        'readyStatus': {}, // 초기화된 레디 상태
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _roomId = roomId; // 새로 생성된 방 ID 저장
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("시간이 기록되었습니다.")),
      );
    }
  }


  Future<void> findOverlapAndShowPopup() async {
    // 기존 방 검색
    final existingRoomQuery = await _firestore
        .collection('meetingRooms')
        .where('participants', arrayContains: widget.myuid)
        .get();

    if (existingRoomQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("먼저 방을 생성하세요!")),
      );
      return;
    }
    final roomDoc = existingRoomQuery.docs.first;

    if (!roomDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("방 정보를 찾을 수 없습니다.")),
      );
      return;
    }

    final roomData = roomDoc.data() as Map<String, dynamic>;
    final availability = roomData['availability'] as Map<String, dynamic>;

    // 결과를 저장할 Map
    Map<String, String> overlaps = {};

    // 시간을 정렬 및 비교하기 위한 함수
    int convertTo24HourFormat(String time) {
      final parts = time.split(' '); // ["10", "AM"] 형태로 나눔
      final hour = int.parse(parts[0]);
      final isPm = parts[1] == "PM";
      return (hour % 12) + (isPm ? 12 : 0); // 12시간 기준을 24시간으로 변환 8 PM -> 20 6 AM -> 6
    }

    // 요일별 교집합 계산
    Map<String, List<Map<String, String>>> daywiseData = {};

    // 데이터를 요일별로 그룹화
    availability.forEach((uid, data) {
      data.forEach((day, times) {
        if (!daywiseData.containsKey(day)) {
          daywiseData[day] = [];
        }
        daywiseData[day]!.add({
          'start': times['start'],
          'end': times['end'],
        });
      });
    });

    // 요일별로 교집합 계산
    daywiseData.forEach((day, timeRanges) {
      int? maxStart; // 가장 늦은 시작 시간
      int? minEnd;   // 가장 빠른 종료 시간

      for (var range in timeRanges) {
        final otherStart = convertTo24HourFormat(range['start']!);
        final otherEnd = convertTo24HourFormat(range['end']!);

        if (maxStart == null || otherStart > maxStart) {
          maxStart = otherStart;
        }

        if (minEnd == null || otherEnd < minEnd) {
          minEnd = otherEnd;
        }
      }

      // 교집합이 있다면 결과에 추가
      if (maxStart != null && minEnd != null && maxStart < minEnd) {
        overlaps[day] = "${maxStart % 12 == 0 ? 12 : maxStart % 12} ${maxStart >= 12 ? 'PM' : 'AM'} - ${minEnd % 12 == 0 ? 12 : minEnd % 12} ${minEnd >= 12 ? 'PM' : 'AM'}";
      }
    });


    // 결과 출력
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("겹치는 시간"),
          content: overlaps.isEmpty
              ? const Text("겹치는 시간이 없습니다.")
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: overlaps.entries
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
              leaveRoom();
              Navigator.pop(context);
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
