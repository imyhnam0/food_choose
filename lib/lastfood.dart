import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'nextStage.dart';
import 'main.dart'; // HomePage를 위한 import



class LastfoodPage extends StatefulWidget {
  final String gameId;

  const LastfoodPage({super.key, required this.gameId});

  @override
  State<LastfoodPage> createState() => _LastfoodPageState();
}

class _LastfoodPageState extends State<LastfoodPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? topFood; // Top 1 음식 이름
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTopFood(); // Firestore에서 Top 1 음식 데이터 가져오기
  }

  // Firestore에서 'lastFoods' 데이터 가져오기
  void fetchTopFood() async {
    try {
      final doc = await _firestore
          .collection('games')
          .doc(widget.gameId)
          .collection('foods')
          .doc('lastFoods')
          .get();

      if (doc.exists) {
        final List<dynamic> foodList = doc['food'] ?? [];
        print("hihi");

        if (foodList.isNotEmpty) {
          // 내림차순으로 저장된 첫 번째 항목이 Top 1
          setState(() {
            topFood = foodList[0]['food']; // Top 1 음식 이름 저장
          });
        }
      }
    } catch (error) {
      print('Error fetching top food: $error');
    } finally {
      setState(() {
        isLoading = false; // 로딩 상태 해제
      });
    }
  }

  // 참가자 나가기
  Future<void> leaveGame(String uid) async {
    try {
      await _firestore.collection('games').doc(widget.gameId).update({
        'participants': FieldValue.arrayRemove([uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방에서 나갔습니다.')),
      );

      // HomePage로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
      );
    } catch (error) {
      print('Error leaving game: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<UserProvider>(context, listen: false).uid!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (topFood == null) {
      return const Center(child: Text('투표 결과를 가져올 수 없습니다.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('최종 결과'),
      ),
      body: Center(
      child:Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // 수평 정렬
          children: [
            Text(
              '투표를 제일 많이 받은 값은',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center, // 텍스트 중앙 정렬
            ),
            const SizedBox(height: 10),
            Text(
              topFood!, // Top 1 음식
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.red, // 빨간색으로 강조
              ),
              textAlign: TextAlign.center, // 텍스트 중앙 정렬
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await leaveGame(myUid); // 참가자 나가기 함수 호출
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}

