import 'dart:core';

import 'package:flutter/material.dart';
import 'chat_bubble.dart';

enum Role { user, assistant }

class Score {
  final String emotion;
  final double score;

  Score({required this.emotion, required this.score});

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion,
      'score': score,
    };
  }
}

class ChatEntry {
  final Role role;
  final String timestamp;
  final String content;
  final List<Score> scores;

  ChatEntry(
      {required this.role,
      required this.timestamp,
      required this.content,
      required this.scores});
}

class ChatCard extends StatelessWidget {
  final ChatEntry message;
  const ChatCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Main message bubble
        Container(
          margin: const EdgeInsets.only(top: 8.0),
          child: ChatBubble(
            message: message.content,
            isUser: isUser,
          ),
        ),
        
        // Emotion scores display - Small text below the bubble
        Padding(
          padding: EdgeInsets.only(
            left: isUser ? 0 : 16.0, 
            right: isUser ? 16.0 : 0,
            bottom: 4.0,
          ),
          child: Text(
            message.scores
                .map((score) => "${score.emotion} (${score.score.toStringAsFixed(1)})")
                .join(", "),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

class ChatDisplay extends StatelessWidget {
  final List<ChatEntry> entries;
  const ChatDisplay({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          return ChatCard(message: entries[index]);
        },
      ),
    );
  }
}
