import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FullCommentDialog extends StatefulWidget {
  final String postId;
  final String adminUsername;

  const FullCommentDialog({super.key, required this.postId, required this.adminUsername});

  @override
  State<FullCommentDialog> createState() => _FullCommentDialogState();
}

class _FullCommentDialogState extends State<FullCommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  String? _adminName;

  @override
  void initState() {
    super.initState();
    _fetchAdminName();
  }

  Future<void> _fetchAdminName() async {
    final adminDoc = await FirebaseFirestore.instance.collection('admins').where('username', isEqualTo: widget.adminUsername).get();
    if (adminDoc.docs.isNotEmpty) {
      setState(() {
        _adminName = adminDoc.docs.first['name'] ?? widget.adminUsername;
      });
    } else {
      setState(() {
        _adminName = widget.adminUsername;
      });
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    // Add the comment
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'comment': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'user': _adminName ?? widget.adminUsername,
    });

    // Fetch post data to get the title
    final postDoc = await FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.postId)
        .get();
    final postData = postDoc.data();
    final postTitle = postData?['title'] ?? '';

    // Check if commenter is an admin
    final adminDocForCheck = await FirebaseFirestore.instance
        .collection('admins')
        .where('username', isEqualTo: widget.adminUsername)
        .get();
    final isAdmin = adminDocForCheck.docs.isNotEmpty;

    // Only send notification if the commenter is NOT an admin
    if (!isAdmin) {
      // Fetch all admins
      final adminsSnapshot = await FirebaseFirestore.instance.collection('admins').get();
      // Fetch user profile to get first name
      final userProfileSnapshot = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: widget.adminUsername).get();
      String userFirstName = widget.adminUsername;
      if (userProfileSnapshot.docs.isNotEmpty) {
        userFirstName = userProfileSnapshot.docs.first['firstName'] ?? widget.adminUsername;
      }
      for (var admin in adminsSnapshot.docs) {
        final adminUsername = admin['username'] ?? '';
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'comment',
          'to': adminUsername,
          'from': widget.adminUsername,
          'postId': widget.postId,
          'message': '$userFirstName commented on this post',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    }

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('announcements').doc(widget.postId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load post.'));
        }
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.data() == null) {
          return const Center(child: Text('No post data found.'));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((data['title'] ?? '').isNotEmpty)
                  Text(
                    data['title'],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),

                if ((data['content'] ?? '').isNotEmpty)
                  Text(data['content'], style: const TextStyle(fontSize: 16)),

                const SizedBox(height: 12),

                if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildImageGrid(data['imageUrl'], widget.postId),
                  ),

                const Divider(height: 32),
                const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('announcements')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, commentSnapshot) {
                    if (commentSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (commentSnapshot.hasError) {
                      return const Center(child: Text('Failed to load comments.'));
                    }
                    if (!commentSnapshot.hasData || commentSnapshot.data == null || commentSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No comments yet.'));
                    }

                    return Column(
                      children: commentSnapshot.data!.docs.map((doc) {
                        var comment = doc.data() as Map<String, dynamic>;
                        var commentId = doc.id;
                        return _buildCommentSection(widget.postId, commentId, comment);
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Add Comment Field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: "Write a comment...",
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _postComment();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _postComment,
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

final Map<String, bool> _replyVisibilityMap = {};

Widget _buildCommentSection(String postId, String commentId, Map<String, dynamic> commentData) {
  TextEditingController replyController = TextEditingController();

  // Initialize visibility state if not already present
  _replyVisibilityMap.putIfAbsent(commentId, () => false);

  return StatefulBuilder(
    builder: (context, setState) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person),
              title: Text("${commentData['user'] ?? 'Anonymous'}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commentData['comment'] ?? ''),
                  Text(
                    _formatTimestamp(commentData['timestamp']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                color: const Color.fromARGB(255, 250, 250, 250),
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Comment"),
                        content: const Text("Are you sure you want to delete this comment?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await FirebaseFirestore.instance
                          .collection('announcements')
                          .doc(postId)
                          .collection('comments')
                          .doc(commentId)
                          .delete();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Comment deleted")),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ),

            // Reply button
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _replyVisibilityMap[commentId] = !_replyVisibilityMap[commentId]!;
                  });
                },
                icon: const Icon(Icons.reply, size: 18, color: Color.fromARGB(255, 0, 48, 96)),
                label: const Text("Reply", style: TextStyle(fontSize: 13, color: Color.fromARGB(255, 0, 48, 96))),
              ),
            ),

            // Replies
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .collection('replies')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  children: snapshot.data!.docs.map((replyDoc) {
                    var reply = replyDoc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 32.0, top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.reply, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${reply['author'] ?? 'Anonymous'}: ${reply['text']}",
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                                Text(
                                  _formatTimestamp(reply['timestamp']),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            color: const Color.fromARGB(255, 250, 250, 250),
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Delete Reply"),
                                    content: const Text("Are you sure you want to delete this reply?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await FirebaseFirestore.instance
                                      .collection('announcements')
                                      .doc(postId)
                                      .collection('comments')
                                      .doc(commentId)
                                      .collection('replies')
                                      .doc(replyDoc.id)
                                      .delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Reply deleted")),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            // Conditional Reply Field
            if (_replyVisibilityMap[commentId] == true)
              Padding(
                padding: const EdgeInsets.only(left: 32.0, top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        decoration: const InputDecoration(
                          hintText: "Write a reply...",
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) async {
                          if (value.trim().isNotEmpty) {
                            await FirebaseFirestore.instance
                                .collection('announcements')
                                .doc(postId)
                                .collection('comments')
                                .doc(commentId)
                                .collection('replies')
                                .add({
                              'text': value.trim(),
                              'timestamp': Timestamp.now(),
                              'author': _adminName ?? widget.adminUsername,
                            });

                           
                            

                            replyController.clear();
                            setState(() {
                              _replyVisibilityMap[commentId] = false;
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      onPressed: () async {
                        if (replyController.text.trim().isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('announcements')
                              .doc(postId)
                              .collection('comments')
                              .doc(commentId)
                              .collection('replies')
                              .add({
                            'text': replyController.text.trim(),
                            'timestamp': Timestamp.now(),
                            'author': _adminName ?? widget.adminUsername,
                          });

                       

                          replyController.clear();
                          setState(() {
                            _replyVisibilityMap[commentId] = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _buildImageGrid(dynamic imageData, String postId) {
  List<String> imageUrls = [];
  if (imageData is String) {
    imageUrls = [imageData];
  } else if (imageData is List) {
    imageUrls = List<String>.from(imageData);
  }

  if (imageUrls.isEmpty) return const SizedBox();

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = width * 0.75; // Maintain aspect ratio

      if (imageUrls.length == 1) {
        return SizedBox(
          height: height,
          child: GestureDetector(
            onTap: () => _showImageDialog(context, imageUrls[0]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[0],
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }

      if (imageUrls.length == 2) {
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls[0]),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    child: Image.network(
                      imageUrls[0],
                      fit: BoxFit.cover,
                      height: height,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls[1]),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                    child: Image.network(
                      imageUrls[1],
                      fit: BoxFit.cover,
                      height: height,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (imageUrls.length == 3) {
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls[0]),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    child: Image.network(
                      imageUrls[0],
                      fit: BoxFit.cover,
                      height: height,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, imageUrls[1]),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                          child: Image.network(
                            imageUrls[1],
                            fit: BoxFit.cover,
                            height: height / 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, imageUrls[2]),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                          child: Image.network(
                            imageUrls[2],
                            fit: BoxFit.cover,
                            height: height / 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // For 4 or more images
      return SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[0]),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                        child: Image.network(
                          imageUrls[0],
                          fit: BoxFit.cover,
                          height: height / 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[1]),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                        child: Image.network(
                          imageUrls[1],
                          fit: BoxFit.cover,
                          height: height / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[2]),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrls[2],
                              fit: BoxFit.cover,
                              height: height / 2,
                            ),
                            if (imageUrls.length > 4)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Text(
                                    '+${imageUrls.length - 4}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, imageUrls[3]),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                        child: Image.network(
                          imageUrls[3],
                          fit: BoxFit.cover,
                          height: height / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showImageDialog(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = (constraints.maxWidth < 900 ? constraints.maxWidth : 900).toDouble();
          return SizedBox(
            width: dialogWidth,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    ),
  );
}

String _formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate();
  return "${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
}
}
