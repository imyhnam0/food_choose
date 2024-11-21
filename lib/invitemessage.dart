import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foodchoose/loginpage.dart';
import 'firebase_options.dart';
import 'user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loginpage.dart';
import 'signuppage.dart';
import 'invite.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'foodchoose.dart';

class InviteMessagesPage extends StatefulWidget {
  const InviteMessagesPage({super.key});

  @override
  _InviteMessagesPageState createState() => _InviteMessagesPageState();
}

class _InviteMessagesPageState extends State<InviteMessagesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? Myuid;

  @override
  void initState() {
    super.initState();
    Myuid = Provider.of<UserProvider>(context, listen: false).uid;
  }

  // 초대 요청 수락
  Future<void> acceptInvite(Map<String, dynamic> invite) async {
    final senderName = invite['senderName'];
    final senderUid = invite['senderUid'];
    final whatGame = invite['whatgame'];

    // Firestore에서 현재 사용자 이름 가져오기
    final currentUserDoc =
    await _firestore.collection('users').doc(Myuid).get();
    final currentUserName = currentUserDoc['name'];

    // 초대 요청 제거
    await _firestore.collection('users').doc(Myuid).update({
      'gameRequests': FieldValue.arrayRemove([invite]),
    });

    // 컬렉션 선택: 투표 초대 -> games, 미팅 정하기 -> meetingRooms
    final targetCollection = whatGame == '투표 초대' ? 'games' : 'meetingRooms';

    // 기존 방 검색
    final existingGameQuery = await _firestore
        .collection(targetCollection)
        .where('participants', arrayContains: senderUid)
        .get();

    String gameId;

    if (existingGameQuery.docs.isNotEmpty) {
      // 기존 방이 있으면 그 방에 참가자 추가
      final gameDoc = existingGameQuery.docs.first;
      gameId = gameDoc.id;

      await _firestore.collection(targetCollection).doc(gameId).update({
        'participants': FieldValue.arrayUnion([senderUid]),
        'participantDetails': FieldValue.arrayUnion([
          {'uid': Myuid, 'name': currentUserName}
        ]),
      });
    } else {
      // 기존 방이 없으면 새 방 생성
      gameId = DateTime.now().millisecondsSinceEpoch.toString();
      if(whatGame=='투표 초대'){
        await _firestore.collection(targetCollection).doc(gameId).set({
          'participants': [senderUid, Myuid], // 초대한 사람과 현재 사용자 추가
          'participantDetails': [
            {'uid': senderUid, 'name': senderName},
            {'uid': Myuid, 'name': currentUserName}
          ],
          'readyStatus': {}, // 초기화된 레디 상태
          'gameState': 'waiting', // 초기 상태는 대기 상태
          'foodchoose': 'waiting',
          'resultfood': 'waiting',
          'nextStage': 'waiting',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      else{
        await _firestore.collection(targetCollection).doc(gameId).set({
          'participants': [senderUid, Myuid], // 초대한 사람과 현재 사용자 추가
          'participantDetails': [
            {'uid': senderUid, 'name': senderName},
            {'uid': Myuid, 'name': currentUserName}
          ],
          'readyStatus': {}, // 초기화된 레디 상태
          'createdAt': FieldValue.serverTimestamp(),
        });

      }


    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$senderName님의 초대를 수락했습니다.')),
    );
  }
  // 초대 거절
  Future<void> rejectInvite(Map<String, dynamic> invite) async {
    final senderName = invite['senderName'];

    await _firestore.collection('users').doc(Myuid).update({
      'gameRequests': FieldValue.arrayRemove([invite]),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$senderName님의 초대를 거절했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '받은 초대 메시지',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurpleAccent, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(Myuid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final gameRequests = userData['gameRequests'] ?? [];

            if (gameRequests.isEmpty) {
              return const Center(
                child: Text(
                  '받은 초대 요청이 없습니다.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: gameRequests.length,
              itemBuilder: (context, index) {
                final invite = gameRequests[index];

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${invite['senderName']}-> ${invite['whatgame']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              backgroundColor: Colors.greenAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 5,
                            ),
                            onPressed: () {
                              acceptInvite(invite);
                            },
                            child: const Text(
                              '수락',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 5,
                            ),
                            onPressed: () {
                              rejectInvite(invite);
                            },
                            child: const Text(
                              '거절',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}