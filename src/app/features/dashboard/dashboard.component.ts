import { Component, inject, OnInit } from '@angular/core';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { NotificationService } from '../../core/services/notification.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [MatCardModule, MatButtonModule, MatIconModule],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.css'
})
export class DashboardComponent implements OnInit {
  private notificationService = inject(NotificationService);

  ngOnInit(): void {
    this.notificationService.add('Bienvenido', 'Dashboard cargado correctamente.', 'success');
  }

  addTestNotification(): void {
    const types = ['info', 'success', 'warning', 'error'] as const;
    const type = types[Math.floor(Math.random() * types.length)];
    this.notificationService.add('Notificación de prueba', `Este es un mensaje de tipo "${type}".`, type);
  }
}
