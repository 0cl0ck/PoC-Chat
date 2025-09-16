import { Injectable } from '@angular/core';
import { Client, IMessage } from '@stomp/stompjs';
import SockJS from 'sockjs-client';
import { BehaviorSubject, Observable } from 'rxjs';

export interface ChatMessage {
  sender: string;
  content: string;
  conversationId: string;
  role: string;
  timestamp?: string;
}

@Injectable({ providedIn: 'root' })
export class ChatService {
  private client: Client | null = null;
  private connected$ = new BehaviorSubject<boolean>(false);
  private messages$ = new BehaviorSubject<ChatMessage | null>(null);

  connect(): void {
    if (this.client && this.connected$.value) return;

    this.client = new Client({
      webSocketFactory: () => new SockJS('/ws'),
      reconnectDelay: 5000,
      debug: () => {},
    });

    this.client.onConnect = () => {
      this.connected$.next(true);
      this.client?.subscribe('/topic/public', (msg: IMessage) => {
        try {
          const parsed: ChatMessage = JSON.parse(msg.body);
          this.messages$.next(parsed);
        } catch (e) {
          console.error('Failed to parse message', e);
        }
      });
    };

    this.client.onWebSocketError = (err: any) => {
      console.error('WebSocket error', err);
    };
    this.client.onStompError = (frame) => {
      console.error('Broker error', frame.headers['message'], frame.body);
    };

    this.client.activate();
  }

  isConnected(): Observable<boolean> {
    return this.connected$.asObservable();
  }

  messages(): Observable<ChatMessage | null> {
    return this.messages$.asObservable();
  }

  send(message: ChatMessage): void {
    if (!this.client || !this.connected$.value) return;
    this.client.publish({
      destination: '/app/chat.sendMessage',
      body: JSON.stringify(message),
    });
  }
}
