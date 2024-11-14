import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestsPage extends StatelessWidget {
  final String userId; // 현재 사용자 ID
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FriendRequestsPage({super.key, required this.userId});

  // 친구 요청 수락
  Future<void> acceptFriendRequest(Map<String, String> friend) async {
    try {
      final friendUid = friend['uid']!;
      final friendName = friend['name']!;

// 친구 요청 수락 처리
      await _firestore.collection('users').doc(userId).update({
        'friends': FieldValue.arrayUnion([
          {'uid': friendUid, 'name': friendName} // 친구 목록에 Map으로 추가
        ]),
        'friendRequests': FieldValue.arrayRemove([friend]), // 요청 목록에서 제거
      });

// 상대방의 friends 필드에도 현재 사용자의 uid와 name 추가
      final currentUserDoc = await _firestore.collection('users').doc(userId).get();
      final currentUserName = currentUserDoc['name'];

      await _firestore.collection('users').doc(friendUid).update({
        'friends': FieldValue.arrayUnion([
          {'uid': userId, 'name': currentUserName} // 상대방도 Map 형태로 추가
        ]),
      });

      print('친구 요청 수락 완료: $friendName');
    } catch (e) {
      print('오류 발생: $e');
    }
  }

  // 친구 요청 거절
  Future<void> rejectFriendRequest(Map<String, String> friend) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'friendRequests': FieldValue.arrayRemove([friend]), // 요청 목록에서 제거
      });
      print('친구 요청 거절 완료');
    } catch (e) {
      print('오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 요청 목록'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Firestore에서 요청 목록 가져오기
          List<Map<String, String>> friendRequests = (snapshot.data!['friendRequests'] ?? [])
              .map<Map<String, String>>((dynamic item) {
            return Map<String, String>.from(item);
          }).toList();

          return ListView.builder(
            itemCount: friendRequests.length,
            itemBuilder: (context, index) {
              final friend = friendRequests[index];
              final friendName = friend['name']!; // 이름만 표시

              return ListTile(
                title: Text(friendName), // 이름만 표시
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await acceptFriendRequest(friend); // 요청 수락
                      },
                      child: const Text('수락'),
                    ),
                    const SizedBox(width: 8), // 버튼 간 간격 추가
                    ElevatedButton(
                      onPressed: () async {
                        await rejectFriendRequest(friend); // 요청 거절
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // 거절 버튼 색상
                      ),
                      child: const Text('거절'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
