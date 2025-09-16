package com.yourcar.yourway.service;

import com.yourcar.yourway.model.ChatMessage;
import com.yourcar.yourway.model.ConversationStatus;
import com.yourcar.yourway.model.ConversationSupport;
import com.yourcar.yourway.repository.ChatMessageRepository;
import com.yourcar.yourway.repository.ConversationSupportRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class ChatService {

    private final ChatMessageRepository messageRepository;
    private final ConversationSupportRepository conversationRepository;

    @Autowired
    public ChatService(ChatMessageRepository messageRepository,
                       ConversationSupportRepository conversationRepository) {
        this.messageRepository = messageRepository;
        this.conversationRepository = conversationRepository;
    }

    public ChatMessage saveMessage(ChatMessage chatMessage) {
        LocalDateTime now = LocalDateTime.now();
        chatMessage.setTimestamp(now);
        upsertConversation(chatMessage, now);
        return messageRepository.save(chatMessage);
    }

    public List<ChatMessage> getMessagesByConversationId(String conversationId) {
        return messageRepository.findByConversationIdOrderByTimestampAsc(conversationId);
    }

    public List<ConversationSupport> getConversations() {
        return conversationRepository.findAll(Sort.by(Sort.Direction.DESC, "lastActivityAt"));
    }

    public ConversationSupport getConversationMetadata(String conversationId) {
        return conversationRepository.findByConversationId(conversationId).orElse(null);
    }

    private void upsertConversation(ChatMessage message, LocalDateTime now) {
        ConversationSupport conversation = conversationRepository
                .findByConversationId(message.getConversationId())
                .orElseGet(() -> {
                    ConversationSupport created = new ConversationSupport();
                    created.setConversationId(message.getConversationId());
                    created.setCreatedAt(now);
                    created.setStatus(ConversationStatus.OPEN);
                    return created;
                });

        if ("CLIENT".equalsIgnoreCase(message.getRole())) {
            conversation.setClientName(message.getSender());
        }
        if ("AGENT".equalsIgnoreCase(message.getRole())) {
            conversation.setAgentName(message.getSender());
        }

        conversation.setLastActivityAt(now);

        if ("AGENT".equalsIgnoreCase(message.getRole())
                && conversation.getStatus() == ConversationStatus.OPEN) {
            conversation.setStatus(ConversationStatus.IN_PROGRESS);
        }

        conversationRepository.save(conversation);
    }
}