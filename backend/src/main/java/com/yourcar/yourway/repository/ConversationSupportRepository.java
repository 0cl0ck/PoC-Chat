package com.yourcar.yourway.repository;

import com.yourcar.yourway.model.ConversationSupport;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.Optional;

public interface ConversationSupportRepository extends MongoRepository<ConversationSupport, String> {
    Optional<ConversationSupport> findByConversationId(String conversationId);
}