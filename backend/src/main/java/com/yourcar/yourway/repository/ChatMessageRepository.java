package com.yourcar.yourway.repository;

import com.yourcar.yourway.model.ChatMessage;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface ChatMessageRepository extends MongoRepository<ChatMessage, String> {
    List<ChatMessage> findByConversationIdOrderByTimestampAsc(String conversationId);
}
