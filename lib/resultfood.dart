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
  bool isLoading = true;
  bool isSubmitted = false;

  @override
  void initState() {
    super.initState();
    fetchFoods();
  }

  // 음식 데이터 가져오기
  Future<void> fetchFoods() async {
    try {
      setState(() {
        isLoading = true; // 로딩 시작
      });

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
          isLoading = false; // 로딩 종료
        });
        print('Fetched food list: $currentSelection');
      } else {
        setState(() {
          currentSelection = [];
          isLoading = false; // 로딩 종료
        });
        print('No food data found in allFoods.');
      }
    } catch (error) {
      setState(() {
        isLoading = false; // 로딩 종료
      });
      print('Error fetching foods: $error');
    }
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

    final sortedFoodList = sortedFoods
        .map((entry) => {
              'food': entry.key,
              'votes': entry.value,
            })
        .toList();

    // Firestore에 저장
    try {
      await _firestore
          .collection('games')
          .doc(widget.gameId)
          .collection('foods')
          .doc('nextFoods') // 'nextFoods' 문서에 저장
          .set({
        'food': sortedFoodList,
      });

      print('Votes aggregated and saved: $sortedFoodList');
    } catch (error) {
      print('Error saving votes: $error');
    }
  }

  // Firestore 업데이트 함수 분리
  Future<void> updateresultfoodStatus() async {
    final gameDoc =
        await _firestore.collection('games').doc(widget.gameId).get();
    final readyStatus = gameDoc['readyStatus'] ?? {};

    // 모든 참가자가 준비 상태인지 확인
    if (readyStatus.values.every((status) => status == true)) {
      await _firestore.collection('games').doc(widget.gameId).update({
        'resultfood': 'Done',
        'readyStatus': readyStatus.map((key, value) => MapEntry(key, false)),
        // 상태 초기화
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
        title: const Text(
          '음식 투표',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 10,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.blueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('games').doc(widget.gameId).snapshots(),
          builder: (context, gameSnapshot) {
            if (!gameSnapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final gameData =
                gameSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final resultfood = gameData['resultfood'] ?? 'waiting';

            // `resultState`가 `done`으로 변경되었을 때 자동으로 넘어가기

            if (resultfood == "Done") {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          NextstagePage(gameId: widget.gameId)),
                );
              });
            }

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '가장 마음에 드는 음식을 선택하세요!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 5.0,
                          color: Colors.black54,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!isSubmitted) ...[
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentSelection.length,
                      itemBuilder: (context, index) {
                        final food = currentSelection[index];
                        final voteValue = votes[food] ?? 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                food,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  voteValue == 0
                                      ? Icons.circle_outlined
                                      : Icons.check_circle,
                                  color:
                                      voteValue > 0 ? Colors.green : Colors.red,
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    votes[food] = voteValue == 0 ? 1 : 0;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        await aggregateVotes({myUid: votes}); // 투표 결과 저장
                        await _firestore
                            .collection('games')
                            .doc(widget.gameId)
                            .update({
                          'readyStatus.$myUid': true, // 내 상태를 true로 변경
                        });

                        // 모든 참가자 상태 확인 후 업데이트
                        await updateresultfoodStatus();

                        setState(() {
                          isSubmitted = true; // 확인 버튼을 눌렀음을 표시
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 10,
                      ),
                      child: const Text(
                        '투표 완료',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
                if (isSubmitted)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        '다른 참가자들이 완료할 때까지 기다려주세요.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 3.0,
                              color: Colors.black54,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
              ],
            );
          },
        ),
      ),
    );
  }
}
