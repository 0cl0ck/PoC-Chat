package com.yourcar.yourway.controller;

import com.yourcar.yourway.model.ChatMessage;
import com.yourcar.yourway.model.ConversationSupport;
import com.yourcar.yourway.service.ChatService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class ChatController {

    private final ChatService chatService;

    @Autowired
    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @MessageMapping("/chat.sendMessage")
    @SendTo("/topic/public")
    public ChatMessage sendMessage(@Payload ChatMessage chatMessage) {
        return chatService.saveMessage(chatMessage);
    }

    @GetMapping("/conversations/{conversationId}")
    public List<ChatMessage> getConversation(@PathVariable String conversationId) {
        return chatService.getMessagesByConversationId(conversationId);
    }

    @GetMapping("/support/conversations")
    public List<ConversationSupport> getAllConversations() {
        return chatService.getConversations();
    }

    @GetMapping("/support/conversations/{conversationId}")
    public ConversationSupport getConversationMetadata(@PathVariable String conversationId) {
        return chatService.getConversationMetadata(conversationId);
    }
}