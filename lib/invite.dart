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
      // Firestore에서 현재 사용자 문서 업데이트
      await _firestore.collection('users').doc(Myuid).update({
        'friends': FieldValue.arrayRemove([friend]), // 친구 삭제
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend['name']}님을 친구 목록에서 삭제했습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
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
        final friendRequests = List<Map<String, dynamic>>.from(
          friendDoc['friendRequests'] ?? [],
        );

        final friendList = List<String>.from(
          friendDoc['friends'] ?? [],
        );

        // 중복 확인: 친구 요청 목록에 존재하는지
        final alreadyRequested = friendRequests.any((request) => request['uid'] == Myuid);

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 목록'),
        actions: [
          TextButton(
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
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(Myuid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // friends 필드를 가져오기
          List<Map<String, String>> friends = (snapshot.data!['friends'] ?? [])
              .map<Map<String, String>>((dynamic friend) {
            return Map<String, String>.from(friend);
          }).toList();


          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final friendName = friend['name']!;

                    return ListTile(
                      title: Text(friendName), // 친구 이름 표시
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await removeFriend(friend); // 친구 삭제
                        },
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('친구 추가'),
                        content: TextField(
                          controller: _friendEmailController,
                          decoration: const InputDecoration(
                            hintText: '친구의 이메일을 입력하세요',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
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
                            child: const Text('요청 보내기'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('친구 추가'),
              ),
            ],
          );
        },
      ),
    );
  }
}
