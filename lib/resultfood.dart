import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';

class ResultPage extends StatefulWidget {
  final String gameId;

  const ResultPage({super.key, required this.gameId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, int> votes = {};
  List<String> currentSelection = [];
  int stage = 5; // 단계별 음식 개수 (5 → 3 → 1)
  bool allReady = false;

  @override
  void initState() {
    super.initState();
    fetchFoods();
    monitorReadyState();
  }

  // 음식 데이터 가져오기
  void fetchFoods() {
    _firestore
        .collection('games')
        .doc(widget.gameId)
        .collection('foods')
        .get()
        .then((querySnapshot) {
      final allFoods = <String>[];
      for (var doc in querySnapshot.docs) {
        final foodString = doc['food'] as String;
        allFoods.addAll(foodString.split(',').map((food) => food.trim()));
      }
      setState(() {
        currentSelection = allFoods.toSet().toList(); // 중복 제거
        resetVotes();
      });
    });
  }

  // 투표 초기화
  void resetVotes() {
    votes = {for (var food in currentSelection) food: 0};
  }

  // 모든 참가자가 준비되었는지 모니터링
  void monitorReadyState() {
    _firestore
        .collection('games')
        .doc(widget.gameId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final readyStatus = snapshot.data()?['readyStatus'] ?? {};
        final allVotes = snapshot.data()?['votes'] ?? {};
        final participantCount = readyStatus.keys.length;

        // 모든 사용자가 준비되었는지 확인
        setState(() {
          allReady = readyStatus.values.where((status) => status == true).length ==
              participantCount;
        });

        if (allReady) {
          // 합산 후 다음 단계로 진행
          await aggregateVotes(allVotes);
          if (stage > 1) {
            showResultsPopup();
            Future.delayed(const Duration(seconds: 3), () {
              filterTopFoods();
            });
          } else {
            showResultsPopup();
            Future.delayed(const Duration(seconds: 3), () {
              showFinalResult(currentSelection.first);
            });
          }

          // `readyStatus`를 다시 초기화 (다음 투표를 위해)
          resetReadyStatus();
        }
      }
    });
  }

  // `readyStatus` 초기화
  void resetReadyStatus() async {
    final readyStatus = await _firestore
        .collection('games')
        .doc(widget.gameId)
        .get()
        .then((doc) => doc.data()?['readyStatus'] ?? {});

    final updatedReadyStatus = readyStatus.map((key, value) => MapEntry(key, false));

    await _firestore.collection('games').doc(widget.gameId).update({
      'readyStatus': updatedReadyStatus,
    });
  }

  // Firestore에서 모든 사용자 투표 데이터를 합산
  Future<void> aggregateVotes(Map<String, dynamic> allVotes) async {
    final aggregatedVotes = <String, int>{};
    for (final userVotes in allVotes.values) {
      final userVoteMap = Map<String, int>.from(userVotes);
      userVoteMap.forEach((food, count) {
        aggregatedVotes[food] = (aggregatedVotes[food] ?? 0) + count;
      });
    }

    setState(() {
      votes = aggregatedVotes;
    });
  }

  // 상위 음식 필터링
  void filterTopFoods() {
    final sortedVotes = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final filtered = sortedVotes.where((entry) => entry.value > 0).toList();

    if (filtered.isEmpty) {
      showFinalResult('투표된 항목이 없습니다');
      return;
    }

    setState(() {
      if (filtered.length <= stage) {
        currentSelection = filtered.map((entry) => entry.key).toList();
      } else {
        currentSelection = filtered.take(stage).map((entry) => entry.key).toList();
      }

      stage = stage == 5 ? 3 : 1; // 단계 감소
      resetVotes();
    });
  }

  // 투표 결과 팝업 표시
  void showResultsPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('투표 결과'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: votes.entries
                .where((entry) => entry.value > 0) // 0표 제외
                .map((entry) => Text('${entry.key}: ${entry.value}표'))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 최종 결과 표시
  void showFinalResult(String winner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('최종 선택'),
          content: Text('최종 선택된 음식은 "$winner"입니다!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 닫기
                Navigator.pop(context); // 결과 페이지 닫기
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<UserProvider>(context, listen: false).uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(stage == 5
            ? 'Top 5 투표'
            : stage == 3
            ? 'Top 3 투표'
            : '최종 선택'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: currentSelection.length,
              itemBuilder: (context, index) {
                final food = currentSelection[index];
                return ListTile(
                  title: Text(food),
                  trailing: IconButton(
                    icon: Icon(
                      votes[food] == 0
                          ? Icons.circle_outlined
                          : Icons.check_circle,
                      color: votes[food]! > 0 ? Colors.green : Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        if (votes[food] == 0) {
                          votes[food] = 1; // 투표
                        } else {
                          votes[food] = 0; // 취소
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          if (!allReady) // 모든 사용자가 준비되지 않으면 메시지 표시
            const Text(
              '다른 참가자가 투표 중입니다. 기다려주세요.',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ElevatedButton(
            onPressed: () async {
              // Firestore에 현재 사용자 투표 데이터 저장
              await _firestore.collection('games').doc(widget.gameId).update({
                'votes.$myUid': votes,
                'readyStatus.$myUid': true,
              });
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
