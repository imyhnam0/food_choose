import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'resultfood.dart';

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

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<UserProvider>(context, listen: false).uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('투표 입력'),
      ),
      body: Column(
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
                  // 입력값 쉼표로 분리 및 중복 제거
                  final newFoods = foodInput.split(',').map((e) => e.trim()).toSet();

                  // Firestore에 기존 데이터 가져오기
                  final existingFoodsSnapshot = await _firestore
                      .collection('games')
                      .doc(widget.gameId)
                      .collection('foods')
                      .doc('allFoods') // allFoods라는 문서에 저장
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
                      .doc('allFoods') // 'allFoods'라는 문서에 업데이트
                      .set({
                    'food': updatedFoods,
                  });
                  // 현재 사용자의 readyStatus를 true로 설정
                  await _firestore.collection('games').doc(widget.gameId).update({
                    'readyStatus.$myUid': true, // 내 상태를 true로 변경
                  });

                  setState(() {
                    isSubmitted = true;
                  });
                }
              },
              child: const Text('확인'),
            ),

          ],
          if (isSubmitted)
            const Center( // 글자를 중앙에 배치
              child: Text(
                '다른 참가자들이 완료할 때까지 기다려주세요.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center, // 텍스트 중앙 정렬
              ),
            ),
          const SizedBox(height: 20),

          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('games').doc(widget.gameId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final gameData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final readyStatus = gameData['readyStatus'] ?? {};

              // 모든 사용자의 readyStatus가 true인지 확인
              final allSubmitted = readyStatus.values.every((status) => status == true);

              if (allSubmitted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultPage(gameId: widget.gameId),
                    ),
                  );
                });
                return const SizedBox.shrink(); // Return an empty widget
              }

              return const Center( // 모든 참가자가 완료 메시지 중앙 정렬
                child: Text(
                  '모든 참가자가 입력을 완료하면 결과를 볼 수 있습니다.',
                  textAlign: TextAlign.center, // 텍스트 중앙 정렬
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

