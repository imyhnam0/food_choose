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
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }

    if (topFood == null) {
      return const Center(
        child: Text(
          '투표 결과를 가져올 수 없습니다.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '최종 결과',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 5,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.indigo],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // 수평 정렬
            children: [
              Text(
                '🎉 투표 결과 🎉',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black38,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '가장 많이 선택된 음식은',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                topFood!,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                  shadows: [
                    Shadow(
                      blurRadius: 15.0,
                      color: Colors.black26,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                  backgroundColor: Colors.lightGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 10,
                  shadowColor: Colors.green,
                ),
                onPressed: () async {
                  await leaveGame(myUid); // 참가자 나가기 함수 호출
                },
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
