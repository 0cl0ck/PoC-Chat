'use strict';

const messageForm = document.querySelector('#message-form');
const messageInput = document.querySelector('#message-input');
const senderInput = document.querySelector('#sender');
const chatMessages = document.querySelector('#chat-messages');

// Prefill sender field when a default value is provided by the page
const defaultSender = document.body.dataset.sender;
if (defaultSender) {
    senderInput.value = defaultSender;
}
const role = document.body.dataset.role;
const conversationId = document.body.dataset.conversationId || 'default';

let stompClient = null;

function connect() {
    const socket = new SockJS('/ws');
    stompClient = Stomp.over(socket);

    stompClient.connect({}, onConnected, onError);
}

function onConnected() {
    // Subscribe to the Public Topic
    stompClient.subscribe('/topic/public', onMessageReceived);

    loadHistory();
}

function onError(error) {
    console.error('Could not connect to WebSocket server. Please refresh and try again!');
}

function sendMessage(event) {
    event.preventDefault();

    const messageContent = messageInput.value.trim();
    const sender = senderInput.value.trim();

    if (messageContent && stompClient) {
        const chatMessage = {
            sender: sender,
            content: messageInput.value,
            role: role,
            conversationId: conversationId,
        };
        stompClient.send('/app/chat.sendMessage', {}, JSON.stringify(chatMessage));
        messageInput.value = '';
    }
}

function onMessageReceived(payload) {
    const message = JSON.parse(payload.body);
    appendMessage(message);
}

function appendMessage(message) {
    const messageElement = document.createElement('div');
    messageElement.classList.add('message');

    const senderElement = document.createElement('p');
    senderElement.classList.add('sender');
    senderElement.textContent = message.sender;

    const contentElement = document.createElement('p');
    contentElement.classList.add('content');
    contentElement.textContent = message.content;

    messageElement.appendChild(senderElement);
    messageElement.appendChild(contentElement);

    chatMessages.appendChild(messageElement);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function loadHistory() {
    fetch(`/conversations/${conversationId}`)
        .then(response => response.json())
        .then(messages => {
            messages.forEach(appendMessage);
        });
}

// Connect to WebSocket on page load
connect();

messageForm.addEventListener('submit', sendMessage, true);
