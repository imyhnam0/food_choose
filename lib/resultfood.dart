import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'nextStage.dart';

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
  bool allReady = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    resetReadyStatus(); // readyStatus 초기화
    fetchFoods();
    monitorReadyState();
  }

  // `readyStatus` 초기화
  void resetReadyStatus() async {
    try {
      final gameDoc = await _firestore.collection('games').doc(widget.gameId).get();
      if (gameDoc.exists) {
        final readyStatus = gameDoc.data()?['readyStatus'] ?? {};

        // 모든 참가자의 readyStatus를 false로 초기화
        final updatedReadyStatus = readyStatus.map((key, value) => MapEntry(key, false));
        await _firestore.collection('games').doc(widget.gameId).update({
          'readyStatus': updatedReadyStatus,
        });

        print('readyStatus 초기화 완료.');
      }
    } catch (e) {
      print('readyStatus 초기화 중 오류 발생: $e');
    }
  }

  // 음식 데이터 가져오기
  void fetchFoods() async {
    setState(() {
      isLoading = true;
    });

    try {
      final doc = await _firestore
          .collection('games')
          .doc(widget.gameId)
          .collection('foods')
          .doc('allFoods') // 'allFoods' 문서에서 데이터 가져오기
          .get();

      if (doc.exists) {
        final List<dynamic> foodList = doc['food'] ?? [];
        setState(() {
          currentSelection = List<String>.from(foodList);
        });
        print('Fetched food list: $currentSelection');
      } else {
        setState(() {
          currentSelection = [];
        });
      }
    } catch (error) {
      print('Error fetching foods: $error');
    } finally {
      setState(() {
        isLoading = false; // 로딩 종료
      });
    }
  }



  // 모든 참가자가 준비되었는지 모니터링
  void monitorReadyState() async{
    _firestore
        .collection('games')
        .doc(widget.gameId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final readyStatus = snapshot.data()?['readyStatus'] ?? {};
        final votesData = snapshot.data()?['votes'] ?? {};

        // 모든 사용자가 준비 상태인지 확인
        final allReady = readyStatus.values.every((status) => status == true);

        setState(() {
          this.allReady = allReady;
        });

        if (allReady) {
          await aggregateVotes(votesData); // 투표 데이터 합산 및 저장
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 모든 사람이 준비되면 화면 넘어가기
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NextstagePage(gameId: widget.gameId),
              ),
            );
          });
        }
      }
    });
  }

  // 투표 데이터를 Firestore에 저장 (합산 및 내림차순 정렬)
  Future<void> aggregateVotes(Map<String, dynamic> votesData) async {
    final aggregatedVotes = <String, int>{};

    // 모든 사용자 투표 데이터를 합산
    votesData.forEach((userId, userVotes) {
      final userVoteMap = Map<String, int>.from(userVotes);
      userVoteMap.forEach((food, count) {
        aggregatedVotes[food] = (aggregatedVotes[food] ?? 0) + count;
      });
    });

    // 내림차순 정렬
    final sortedFoods = aggregatedVotes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedFoodList = sortedFoods.map((entry) => {
      'food': entry.key,
      'votes': entry.value,
    }).toList();

    // Firestore에 저장
    await _firestore
        .collection('games')
        .doc(widget.gameId)
        .collection('foods')
        .doc('nextFoods') // 'nextFoods' 문서에 저장
        .set({
      'food': sortedFoodList,
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<UserProvider>(context, listen: false).uid!;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentSelection.isEmpty) {
      return const Center(child: Text('음식 데이터가 없습니다.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('투표해주세요'), // 제목 변경
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: currentSelection.length,
              itemBuilder: (context, index) {
                final food = currentSelection[index];

                // votes에서 값이 없을 경우 기본값으로 0을 반환
                final voteValue = votes[food] ?? 0;

                return ListTile(
                  title: Text(food),
                  trailing: IconButton(
                    icon: Icon(
                      voteValue == 0
                          ? Icons.circle_outlined
                          : Icons.check_circle,
                      color: voteValue > 0 ? Colors.green : Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        if (voteValue == 0) {
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