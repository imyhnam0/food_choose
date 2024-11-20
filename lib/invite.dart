import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friendrequest.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  _InvitePageState createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final TextEditingController _friendEmailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? Myuid;

  @override
  void initState() {
    super.initState();
    Myuid = Provider.of<UserProvider>(context, listen: false).uid;
  }

  // 친구 삭제 함수
  Future<void> removeFriend(Map<String, String> friend) async {
    try {
      final friendUid = friend['uid']!;
      final friendName = friend['name']!;

      // 현재 사용자 이름 가져오기
      final myDoc = await _firestore.collection('users').doc(Myuid).get();
      final myName = myDoc['name'] as String;

      // 현재 사용자 문서에서 친구 제거
      await _firestore.collection('users').doc(Myuid).update({
        'friends': FieldValue.arrayRemove([friend]), // 내 친구 목록에서 친구 삭제
      });

      // 상대방 문서에서 현재 사용자 삭제
      await _firestore.collection('users').doc(friendUid).update({
        'friends': FieldValue.arrayRemove([
          {'uid': Myuid, 'name': myName}, // 상대방의 친구 목록에서 내 정보 삭제
        ]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$friendName님을 친구 목록에서 삭제했습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }


  // 게임 참가 요청
  Future<void> sendGameRequest(String friendUid, String friendName, String gameName) async {
    try {
      // 내 정보 가져오기
      final myDoc = await _firestore.collection('users').doc(Myuid).get();
      final myName = myDoc['name']; // 내 이름
      final myUid = myDoc['uid']; // 내 UID

      // 초대 요청 추가
      await _firestore.collection('users').doc(friendUid).update({
        'gameRequests': FieldValue.arrayUnion([
          {
            'senderUid': myUid, // 내 UID
            'senderName': myName, // 내 이름
            'status': 'pending',
            'whatgame': gameName,
          }
        ]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$friendName님에게 초대를 보냈습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초대 요청 실패: $e')),
      );
    }
  }

  // 친구 추가 요청 함수
  Future<void> sendFriendRequest(String friendEmail) async {
    try {
      // Firestore에서 이메일로 사용자 검색
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: friendEmail)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 친구 UID 가져오기
        final friendDoc = querySnapshot.docs.first;
        final friendUid = friendDoc['uid'];

        // Firestore에서 내 이름 가져오기
        final myDoc = await _firestore.collection('users').doc(Myuid).get();
        final myName = myDoc['name']; // 내 이름 가져오기

        // 친구 요청 및 친구 목록 확인
        final friendRequests = friendDoc['friendRequests'] != null &&
                friendDoc['friendRequests'] is List
            ? (friendDoc['friendRequests'] as List)
                .map((request) =>
                    Map<String, String>.from(request as Map<String, dynamic>))
                .toList()
            : [];

        final friendList = friendDoc['friends'] != null &&
                friendDoc['friends'] is List
            ? (friendDoc['friends'] as List)
                .map((friend) =>
                    Map<String, String>.from(friend as Map<String, dynamic>))
                .toList()
            : [];

        // 중복 확인: 친구 요청 목록에 존재하는지
        final alreadyRequested =
            friendRequests.any((request) => request['uid'] == Myuid);

        // 중복 확인: 친구 목록에 존재하는지
        final alreadyFriend = friendList.contains(Myuid);

        if (alreadyRequested || alreadyFriend) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 친구 요청을 보냈거나 친구로 등록되어 있습니다.')),
          );
          return;
        }

        // 친구 요청 추가
        await _firestore.collection('users').doc(friendUid).update({
          'friendRequests': FieldValue.arrayUnion([
            {'uid': Myuid, 'name': myName} // Map<String, String> 형태로 추가
          ]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 보냈습니다!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('해당 이메일을 가진 사용자가 없습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  void showInvitePopup(BuildContext context, String friendUid, String friendName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '초대 유형 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  sendGameRequest(friendUid, friendName, "투표 초대");
                  Navigator.pop(context); // 팝업 닫기

                },
                child: const Text(
                  '투표 초대',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  backgroundColor: Colors.orangeAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  sendGameRequest(friendUid, friendName, "미팅 정하기 초대");
                  Navigator.pop(context); // 팝업 닫기

                },
                child: const Text(
                  '미텅 정하기 초대',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '친구 목록',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24,color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 10,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendRequestsPage(userId: Myuid!),
                  ),
                );
              },
              child: const Text(
                '요청 목록',
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.indigoAccent],
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

            // friends 필드를 가져오기
            // 친구 목록 처리
            List<Map<String, String>> friends = [];
            if (snapshot.data!['friends'] != null &&
                snapshot.data!['friends'] is List) {
              friends = (snapshot.data!['friends'] as List)
                  .map((friend) =>
                      Map<String, String>.from(friend as Map<String, dynamic>))
                  .toList();
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              friend['name']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black, // 텍스트 색상 조정
                                shadows: [
                                  Shadow(
                                    blurRadius: 3,
                                    color: Colors.black38,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    backgroundColor: Colors.greenAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 5,
                                  ),
                                  onPressed: () {
                                    showInvitePopup(context, friend['uid']!, friend['name']!);
                                  },
                                  child: const Text(
                                    '초대',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 5,
                                  ),
                                  onPressed: () async {
                                    await removeFriend(friend);
                                  },
                                  child: const Text(
                                    '삭제',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],

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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
                            title: const Text(
                              '친구 추가',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 5.0,
                                    color: Colors.black45,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                            content: TextField(
                              controller: _friendEmailController,
                              decoration: InputDecoration(
                                hintText: '친구의 이메일을 입력하세요',
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white70),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white),
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text('취소'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final friendEmail = _friendEmailController.text.trim();
                                  if (friendEmail.isNotEmpty) {
                                    await sendFriendRequest(friendEmail);
                                    Navigator.pop(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  '요청 보내기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );

                        },
                      );
                    },
                    child: const Text(
                      '친구 추가',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
