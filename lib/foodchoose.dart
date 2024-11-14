import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friendrequest.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';

class FoodChoosePage extends StatefulWidget {
  final List<Map<String, String>> participants; // 수락한 참가자 리스트
  final String gameId; // 게임 ID
  const FoodChoosePage({super.key, required this.participants, required this.gameId});

  @override
  State<FoodChoosePage> createState() => _FoodChoosePageState();
}

class _FoodChoosePageState extends State<FoodChoosePage> {
  final TextEditingController _foodController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isSubmitted = false; // 내가 제출했는지 여부

  @override
  Widget build(BuildContext context) {
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
                      .doc(Provider.of<UserProvider>(context, listen: false).uid)
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
              final allSubmitted = foods.length == widget.participants.length;

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

class ResultPage extends StatelessWidget {
  final List<String> foods;

  const ResultPage({super.key, required this.foods});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결과 보기'),
      ),
      body: ListView.builder(
        itemCount: foods.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(foods[index]),
          );
        },
      ),
    );
  }
}

