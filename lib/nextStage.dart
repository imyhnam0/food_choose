import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'nextStage.dart';
import 'lastfood.dart';

class NextstagePage extends StatefulWidget {
  final String gameId;

  const NextstagePage({super.key, required this.gameId});

  @override
  State<NextstagePage> createState() => _NextstagePageState();
}

class _NextstagePageState extends State<NextstagePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, int> votes = {};
  List<String> topFoods = []; // 상위 3개 음식 데이터
  bool isLoading = true;
  bool isSubmitted = false;

  @override
  void initState() {
    super.initState();
    fetchTopFoods();
  }

  // Firestore에서 'nextFoods' 문서의 데이터를 가져와 상위 3개의 food 값을 추출
  Future<void>  fetchTopFoods() async {
    try {
      final doc = await _firestore
          .collection('games')
          .doc(widget.gameId)
          .collection('foods')
          .doc('nextFoods')
          .get();

      if (doc.exists) {
        final List<dynamic> foodList = doc['food'] ?? [];

        // 상위 3개의 food 값만 추출
        setState(() {
          topFoods = foodList
              .take(3) // 상위 3개의 항목만 가져옴
              .map((item) => (item as Map<String, dynamic>)['food'] as String) // 각 항목에서 food 값 추출
              .toList();
        });

        print('Top 3 Foods: $topFoods');
      } else {
        print('nextFoods 문서가 없습니다.');
      }
    } catch (error) {
      print('Error fetching top foods: $error');
    } finally {
      setState(() {
        isLoading = false; // 로딩 상태 해제
      });
    }
  }

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
    try {
      await _firestore
          .collection('games')
          .doc(widget.gameId)
          .collection('foods')
          .doc('lastFoods') // 'nextFoods' 문서에 저장
          .set({
        'food': sortedFoodList,
      });

      print('Votes aggregated and saved: $sortedFoodList');
    } catch (error) {
      print('Error saving votes: $error');
    }
  }

  // Firestore 업데이트 함수 분리
  Future<void> updatenextStageStatus() async {
    final gameDoc = await _firestore.collection('games').doc(widget.gameId).get();
    final readyStatus = gameDoc['readyStatus'] ?? {};

    // 모든 참가자가 준비 상태인지 확인
    if (readyStatus.values.every((status) => status == true)) {
      await _firestore.collection('games').doc(widget.gameId).update({
        'resultfood': 'Done',
        'readyStatus': readyStatus.map((key, value) => MapEntry(key, false)), // 상태 초기화
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<UserProvider>(context, listen: false).uid!;
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(), // 로딩 중 표시
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top 3 투표'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('games').doc(widget.gameId).snapshots(),
        builder: (context, gameSnapshot) {
          if (!gameSnapshot.hasData) {
            return const CircularProgressIndicator();
          }

          final gameData = gameSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final nextStage = gameData['nextStage'] ?? 'waiting';


          // `State`가 `done`으로 변경되었을 때 자동으로 넘어가기
          if (nextStage == "Done" ) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LastfoodPage(gameId: widget.gameId)),
              );
            });
          }


          return Column(
            children: [
              if (!isSubmitted) ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: topFoods.length,
                    itemBuilder: (context, index) {
                      final food = topFoods[index];
                      final votesCount = votes[food] ?? 0;

                      return ListTile(
                        title: Text(food),
                        trailing: IconButton(
                          icon: Icon(
                            votesCount == 0
                                ? Icons.circle_outlined
                                : Icons.check_circle,
                            color: votesCount > 0 ? Colors.green : Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              if (votesCount == 0) {
                                votes[food] = 1;
                              } else {
                                votes[food] = 0;
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await aggregateVotes({myUid: votes}); // 투표 결과 저장
                    await _firestore.collection('games').doc(widget.gameId).update({
                      'readyStatus.$myUid': true, // 내 상태를 true로 변경
                    });

                    // 모든 참가자 상태 확인 후 업데이트
                    await updatenextStageStatus();

                    setState(() {
                      isSubmitted = true;
                    });
                  },
                  child: const Text('확인'),
                ),
              ],
              if (isSubmitted)
                const Center(
                  child: Text(
                    '다른 참가자들이 완료할 때까지 기다려주세요.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}