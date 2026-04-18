import { Injectable, signal, computed } from '@angular/core';
import { User } from '../models/user.model';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private _currentUser = signal<User | null>(null);
  readonly currentUser = this._currentUser.asReadonly();
  readonly isAuthenticated = computed(() => !!this._currentUser());

  getToken(): string | null {
    return localStorage.getItem('auth_token');
  }

  setToken(token: string, user: User): void {
    localStorage.setItem('auth_token', token);
    this._currentUser.set(user);
  }

  logout(): void {
    localStorage.removeItem('auth_token');
    this._currentUser.set(null);
  }
}
