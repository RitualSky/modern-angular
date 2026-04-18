import { Component, inject } from '@angular/core';
import { DatePipe, NgClass } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatTooltipModule } from '@angular/material/tooltip';
import { NotificationService } from '../../../core/services/notification.service';

@Component({
  selector: 'app-notification-panel',
  standalone: true,
  imports: [DatePipe, NgClass, MatButtonModule, MatIconModule, MatDividerModule, MatTooltipModule],
  templateUrl: './notification-panel.component.html',
  styleUrl: './notification-panel.component.css'
})
export class NotificationPanelComponent {
  protected notificationService = inject(NotificationService);

  onNotificationClick(id: string, event: Event): void {
    event.stopPropagation();
    this.notificationService.markAsRead(id);
  }

  onMarkAllRead(event: Event): void {
    event.stopPropagation();
    this.notificationService.markAllAsRead();
  }

  onRemove(id: string, event: Event): void {
    event.stopPropagation();
    this.notificationService.remove(id);
  }
}
