import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { ChatService, ChatMessage } from './chat.service';
import { Subscription, firstValueFrom } from 'rxjs';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FormsModule, CommonModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'Chat PoC (Angular)';

  sender = '';
  role = 'CLIENT';
  conversationId = 'default';
  message = '';

  history: ChatMessage[] = [];
  private sub?: Subscription;

  constructor(private chat: ChatService, private http: HttpClient) {}

  ngOnInit(): void {
    this.chat.connect();
    this.sub = this.chat.messages().subscribe((m) => {
      if (m) this.history.push(m);
      setTimeout(() => this.scrollToBottom(), 0);
    });
    this.loadHistory();
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  async loadHistory(): Promise<void> {
    try {
      const msgs = await firstValueFrom(
        this.http.get<ChatMessage[]>(`/conversations/${encodeURIComponent(this.conversationId)}`)
      );
      this.history = msgs ?? [];
      setTimeout(() => this.scrollToBottom(), 0);
    } catch (e) {
      console.warn('Failed to load history', e);
    }
  }

  send(): void {
    const content = this.message.trim();
    const sender = this.sender.trim();
    if (!content || !sender) return;
    const msg: ChatMessage = {
      sender,
      content,
      role: this.role,
      conversationId: this.conversationId,
    };
    this.chat.send(msg);
    this.message = '';
  }

  scrollToBottom(): void {
    const el = document.getElementById('chat-messages');
    if (el) el.scrollTop = el.scrollHeight;
  }
}
