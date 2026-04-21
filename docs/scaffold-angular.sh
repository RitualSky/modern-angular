#!/bin/bash

echo "🚀 Creando proyecto Angular Enterprise..."

# 1. Crear proyecto Angular
ng new enterprise-app \
  --standalone \
  --routing \
  --style=scss \
  --strict \
  --skip-install

cd enterprise-app

echo "📁 Creando estructura enterprise..."

# 2. Crear carpetas base
mkdir -p src/app/core/{auth,interceptors,guards,errors,services,config}
mkdir -p src/app/shared/{components,directives,models}
mkdir -p src/app/layout
mkdir -p src/app/features/{dashboard,admin,auth}

###############################################
# 3. MSAL CONFIG
###############################################
cat << 'EOF' > src/app/core/auth/msal.config.ts
import { PublicClientApplication, LogLevel } from '@azure/msal-browser';

export const msalConfig = {
  auth: {
    clientId: 'REEMPLAZAR_CLIENT_ID',
    authority: 'https://login.microsoftonline.com/REEMPLAZAR_TENANT_ID',
    redirectUri: '/',
  },
  cache: {
    cacheLocation: 'sessionStorage',
    storeAuthStateInCookie: false,
  },
  system: {
    loggerOptions: {
      logLevel: LogLevel.Warning,
    },
  },
};

export const msalInstance = new PublicClientApplication(msalConfig);
EOF

###############################################
# 4. AuthService
###############################################
cat << 'EOF' > src/app/core/auth/auth.service.ts
import { Injectable } from '@angular/core';
import { MsalService } from '@azure/msal-angular';

@Injectable({ providedIn: 'root' })
export class AuthService {
  constructor(private msal: MsalService) {}

  login() {
    return this.msal.loginPopup({ scopes: ['openid', 'profile', 'email'] });
  }

  logout() {
    return this.msal.logoutPopup();
  }

  get activeAccount() {
    return this.msal.instance.getActiveAccount();
  }
}
EOF

###############################################
# 5. AuthorizationService
###############################################
cat << 'EOF' > src/app/core/auth/authorization.service.ts
import { Injectable } from '@angular/core';
import { MsalService } from '@azure/msal-angular';

@Injectable({ providedIn: 'root' })
export class AuthorizationService {
  constructor(private msal: MsalService) {}

  private get roles(): string[] {
    const account = this.msal.instance.getActiveAccount();
    return (account?.idTokenClaims?.roles as string[]) ?? [];
  }

  hasRole(role: string): boolean {
    return this.roles.includes(role);
  }

  hasAnyRole(roles: string[]): boolean {
    return roles.some(r => this.hasRole(r));
  }
}
EOF

###############################################
# 6. Guards
###############################################
cat << 'EOF' > src/app/core/guards/auth.guard.ts
import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.activeAccount) return true;

  router.navigate(['/login']);
  return false;
};
EOF

cat << 'EOF' > src/app/core/guards/role.guard.ts
import { CanActivateFn } from '@angular/router';
import { inject } from '@angular/core';
import { AuthorizationService } from '../auth/authorization.service';

export const roleGuard = (requiredRoles: string[]): CanActivateFn => {
  return () => {
    const authz = inject(AuthorizationService);
    return authz.hasAnyRole(requiredRoles);
  };
};
EOF

###############################################
# 7. Interceptores
###############################################
cat << 'EOF' > src/app/core/interceptors/auth.interceptor.ts
import { HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { MsalService } from '@azure/msal-angular';
import { from, mergeMap } from 'rxjs';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const msal = inject(MsalService);
  const account = msal.instance.getActiveAccount();
  if (!account) return next(req);

  return from(
    msal.acquireTokenSilent({
      account,
      scopes: ['api://mi-api/.default'],
    })
  ).pipe(
    mergeMap(result => {
      const authReq: HttpRequest<any> = req.clone({
        setHeaders: { Authorization: `Bearer ${result.accessToken}` },
      });
      return next(authReq);
    })
  );
};
EOF

cat << 'EOF' > src/app/core/interceptors/error.interceptor.ts
import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { LoggerService } from '../services/logger.service';
import { catchError, throwError } from 'rxjs';

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  const logger = inject(LoggerService);

  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      logger.error('HTTP Error', { url: req.url, status: error.status });

      switch (error.status) {
        case 401:
          router.navigate(['/login']);
          break;
        case 403:
          router.navigate(['/forbidden']);
          break;
        case 500:
          router.navigate(['/error']);
          break;
      }

      return throwError(() => error);
    })
  );
};
EOF

cat << 'EOF' > src/app/core/interceptors/retry.interceptor.ts
import { HttpInterceptorFn } from '@angular/common/http';
import { retry, timer } from 'rxjs';

export const retryInterceptor: HttpInterceptorFn = (req, next) => {
  if (req.method !== 'GET') return next(req);

  return next(req).pipe(
    retry({
      count: 3,
      delay: (_, retryCount) => timer(200 * Math.pow(2, retryCount)),
    })
  );
};
EOF

cat << 'EOF' > src/app/core/interceptors/logging.interceptor.ts
import { HttpInterceptorFn, HttpResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { LoggerService } from '../services/logger.service';
import { tap } from 'rxjs';

export const loggingInterceptor: HttpInterceptorFn = (req, next) => {
  const logger = inject(LoggerService);
  const correlationId = crypto.randomUUID();

  const logReq = req.clone({
    setHeaders: { 'X-Correlation-ID': correlationId },
  });

  logger.info('Request', { url: req.url, method: req.method, correlationId });

  return next(logReq).pipe(
    tap(event => {
      if (event instanceof HttpResponse) {
        logger.info('Response', {
          url: req.url,
          status: event.status,
          correlationId,
        });
      }
    })
  );
};
EOF

###############################################
# 8. LoggerService
###############################################
cat << 'EOF' > src/app/core/services/logger.service.ts
import { Injectable } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class LoggerService {
  info(message: string, data?: any) {
    console.log('[INFO]', message, data);
  }

  error(message: string, data?: any) {
    console.error('[ERROR]', message, data);
  }
}
EOF

###############################################
# 9. Global Error Handler
###############################################
cat << 'EOF' > src/app/core/errors/global-error-handler.ts
import { ErrorHandler, Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { LoggerService } from '../services/logger.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  constructor(private logger: LoggerService, private router: Router) {}

  handleError(error: any): void {
    this.logger.error('Global Error', {
      message: error?.message,
      stack: error?.stack,
    });

    this.router.navigate(['/error']);
  }
}
EOF

###############################################
# 10. Directiva hasRole
###############################################
cat << 'EOF' > src/app/shared/directives/has-role.directive.ts
import { Directive, Input, TemplateRef, ViewContainerRef } from '@angular/core';
import { AuthorizationService } from '../../core/auth/authorization.service';

@Directive({
  selector: '[hasRole]',
  standalone: true,
})
export class HasRoleDirective {
  @Input() set hasRole(role: string) {
    if (this.authz.hasRole(role)) {
      this.view.createEmbeddedView(this.tpl);
    } else {
      this.view.clear();
    }
  }

  constructor(
    private tpl: TemplateRef<any>,
    private view: ViewContainerRef,
    private authz: AuthorizationService
  ) {}
}
EOF

###############################################
# 11. Layout
###############################################
cat << 'EOF' > src/app/layout/main-layout.component.ts
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { HasRoleDirective } from '../shared/directives/has-role.directive';

@Component({
  selector: 'app-main-layout',
  standalone: true,
  imports: [RouterOutlet, HasRoleDirective],
  templateUrl: './main-layout.component.html',
  styleUrls: ['./main-layout.component.scss'],
})
export class MainLayoutComponent {}
EOF

cat << 'EOF' > src/app/layout/main-layout.component.html
<nav>
  <a routerLink="/dashboard">Dashboard</a>
  <a routerLink="/admin" *hasRole="'Admin'">Admin</a>
</nav>

<router-outlet></router-outlet>
EOF

###############################################
# 12. Features
###############################################
cat << 'EOF' > src/app/features/dashboard/dashboard.component.ts
import { Component } from '@angular/core';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  template: '<h1>Dashboard</h1>',
})
export class DashboardComponent {}
EOF

cat << 'EOF' > src/app/features/dashboard/dashboard.routes.ts
import { Routes } from '@angular/router';
import { DashboardComponent } from './dashboard.component';

export const DASHBOARD_ROUTES: Routes = [
  { path: '', component: DashboardComponent },
];
EOF

cat << 'EOF' > src/app/features/admin/admin.component.ts
import { Component } from '@angular/core';

@Component({
  selector: 'app-admin',
  standalone: true,
  template: '<h1>Admin Panel</h1>',
})
export class AdminComponent {}
EOF

cat << 'EOF' > src/app/features/admin/admin.routes.ts
import { Routes } from '@angular/router';
import { AdminComponent } from './admin.component';
import { roleGuard } from '../../core/guards/role.guard';

export const ADMIN_ROUTES: Routes = [
  {
    path: '',
    component: AdminComponent,
    canActivate: [roleGuard(['Admin'])],
  },
];
EOF

###############################################
# 13. Login Component
###############################################
cat << 'EOF' > src/app/features/auth/login.component.ts
import { Component } from '@angular/core';
import { AuthService } from '../../core/auth/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  template: `
    <h1>Login</h1>
    <button (click)="login()">Iniciar sesión</button>
  `,
})
export class LoginComponent {
  constructor(private auth: AuthService) {}

  login() {
    this.auth.login();
  }
}
EOF

###############################################
# 14. app.routes.ts
###############################################
cat << 'EOF' > src/app/app.routes.ts
import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';

export const appRoutes: Routes = [
  {
    path: '',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      {
        path: 'dashboard',
        loadChildren: () =>
          import('./features/dashboard/dashboard.routes').then(m => m.DASHBOARD_ROUTES),
      },
      {
        path: 'admin',
        loadChildren: () =>
          import('./features/admin/admin.routes').then(m => m.ADMIN_ROUTES),
      },
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
    ],
  },
  {
    path: 'login',
    loadComponent: () =>
      import('./features/auth/login.component').then(m => m.LoginComponent),
  },
  { path: '**', redirectTo: '' },
];
EOF

###############################################
# 15. app.config.ts
###############################################
cat << 'EOF' > src/app/app.config.ts
import { ApplicationConfig, ErrorHandler } from '@angular/core';
import { provideRouter } from '@angular/router';
import { appRoutes } from './app.routes';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { authInterceptor } from './core/interceptors/auth.interceptor';
import { errorInterceptor } from './core/interceptors/error.interceptor';
import { loggingInterceptor } from './core/interceptors/logging.interceptor';
import { retryInterceptor } from './core/interceptors/retry.interceptor';
import { GlobalErrorHandler } from './core/errors/global-error-handler';
import { provideMsal } from '@azure/msal-angular';
import { msalInstance } from './core/auth/msal.config';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(appRoutes),
    provideHttpClient(
      withInterceptors([
        authInterceptor,
        loggingInterceptor,
        retryInterceptor,
        errorInterceptor,
      ])
    ),
    { provide: ErrorHandler, useClass: GlobalErrorHandler },
    provideMsal(() => msalInstance),
  ],
};
EOF

###############################################
# 16. README
###############################################
cat << 'EOF' > README.md
# Enterprise Angular 20 + Entra ID Starter

Este proyecto incluye:

- Autenticación con Entra ID (MSAL)
- Roles y perfiles
- Interceptores enterprise
- Error handling global
- Directivas de seguridad
- Lazy loading
- Standalone components
- Layout modular
- Guards de autenticación y roles

## 🚀 Instalación

```bash
npm install
npm start
