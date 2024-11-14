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
        title: const Text('음식 입력'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isSubmitted) ...[
            const Text(
              '먹고 싶은 음식을 적어주세요!',
              style: TextStyle(fontSize: 20),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _foodController,
                decoration: const InputDecoration(
                  hintText: '먹고 싶은 음식 입력',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final food = _foodController.text.trim();
                if (food.isNotEmpty) {
                  // Firebase에 내 음식을 저장
                  await _firestore
                      .collection('games')
                      .doc(widget.gameId)
                      .collection('foods')
                      .doc(myUid)
                      .set({
                    'food': food,
                    'submitted': true,
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
            const Text(
              '다른 참가자들이 완료할 때까지 기다려주세요.',
              style: TextStyle(fontSize: 18),
            ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('games')
                .doc(widget.gameId)
                .collection('foods')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final foods = snapshot.data!.docs.map((doc) => doc['food'] as String).toList();
              final allSubmitted = foods.length == participants.length;

              if (allSubmitted) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultPage(foods: foods),
                      ),
                    );
                  },
                  child: const Text('결과 보기'),
                );
              }

              return const Text('모든 참가자가 입력을 완료하면 결과를 볼 수 있습니다.');
            },
          ),
        ],
      ),
    );
  }
}

