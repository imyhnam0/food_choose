import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'resultfood.dart';
import 'utils.dart';

class FoodChoosePage extends StatefulWidget {
  final String gameId; // 현재 사용자가 속한 게임 ID
  const FoodChoosePage({super.key, required this.gameId});

  @override
  State<FoodChoosePage> createState() => _FoodChoosePageState();
}

class _FoodChoosePageState extends State<FoodChoosePage> {
  final TextEditingController _foodController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isSubmitted = false; // 내가 제출했는지 여부
  List<Map<String, String>> participants = []; // 참가자 목록

  @override
  void initState() {
    super.initState();
    fetchParticipants();
  }

  // 참가자 목록 가져오기
  void fetchParticipants() {
    _firestore.collection('games').doc(widget.gameId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final participantDetails = List<Map<String, dynamic>>.from(snapshot.data()?['participantDetails'] ?? []);
        setState(() {
          participants = participantDetails.map((p) {
            return {
              'uid': p['uid'] as String,
              'name': p['name'] as String,
            };
          }).toList();
        });

      }
    });
  }

  // Firestore 업데이트 함수 분리
  Future<void> updateFoodChooseStatus() async {
    final gameDoc = await _firestore.collection('games').doc(widget.gameId).get();
    final readyStatus = gameDoc['readyStatus'] ?? {};

    // 모든 참가자가 준비 상태인지 확인
    if (readyStatus.values.every((status) => status == true)) {
      await _firestore.collection('games').doc(widget.gameId).update({
        'foodchoose': 'Done',
        'readyStatus': readyStatus.map((key, value) => MapEntry(key, false)), // 상태 초기화
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<UserProvider>(context, listen: false).uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('투표 입력'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('games').doc(widget.gameId).snapshots(),
        builder: (context, gameSnapshot) {
          if (!gameSnapshot.hasData || gameSnapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final gameData = gameSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final foodchoose = gameData['foodchoose'] ?? 'waiting';


          // `foodchoose` 상태가 `Done`이면 페이지 전환
          if (foodchoose == "Done" ) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ResultPage(gameId: widget.gameId)),
              );
            });
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSubmitted) ...[
                const Text(
                  '투표할 것을 적어주세요!',
                  style: TextStyle(fontSize: 20),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _foodController,
                    decoration: const InputDecoration(
                      hintText: '단 , 로 분류해서 적으세요!',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final foodInput = _foodController.text.trim();
                    if (foodInput.isNotEmpty) {
                      final newFoods = foodInput.split(',').map((e) => e.trim()).toSet();

                      // Firestore에 기존 데이터 가져오기
                      final existingFoodsSnapshot = await _firestore
                          .collection('games')
                          .doc(widget.gameId)
                          .collection('foods')
                          .doc('allFoods')
                          .get();

                      Set<String> existingFoods = {};
                      if (existingFoodsSnapshot.exists) {
                        final existingFoodsList = List<String>.from(existingFoodsSnapshot['food'] ?? []);
                        existingFoods = existingFoodsList.toSet();
                      }

                      // 기존 데이터와 새로운 데이터 병합 및 중복 제거
                      final updatedFoods = existingFoods.union(newFoods).toList();

                      // 병합된 데이터를 Firestore에 저장
                      await _firestore
                          .collection('games')
                          .doc(widget.gameId)
                          .collection('foods')
                          .doc('allFoods')
                          .set({'food': updatedFoods});

                      // 현재 사용자의 readyStatus를 true로 설정
                      await _firestore.collection('games').doc(widget.gameId).update({
                        'readyStatus.$myUid': true,
                      });

                      // 모든 참가자 상태 확인 후 업데이트
                      await updateFoodChooseStatus();

                      setState(() {
                        isSubmitted = true;
                      });
                    }
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
