import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { NotificationService } from '../services/notification.service';

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  const notificationService = inject(NotificationService);

  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      switch (error.status) {
        case 401:
          router.navigate(['/auth/login']);
          break;
        case 403:
          notificationService.add('Sin permisos', 'No tienes permiso para realizar esta acción.', 'warning');
          break;
        case 404:
          notificationService.add('No encontrado', 'El recurso solicitado no existe.', 'warning');
          break;
        default:
          if (error.status >= 500) {
            notificationService.add('Error del servidor', 'Ocurrió un error inesperado. Intenta nuevamente.', 'error');
          }
      }
      return throwError(() => error);
    })
  );
};
