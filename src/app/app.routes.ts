import { Routes } from '@angular/router';
// import { authGuard } from './core/guards/auth.guard'; // Uncomment when authentication is ready

export const routes: Routes = [
  {
    path: '',
    redirectTo: 'dashboard',
    pathMatch: 'full'
  },
  {
    path: 'auth',
    loadChildren: () => import('./auth/auth.routes').then(m => m.authRoutes)
  },
  {
    path: '',
    loadComponent: () => import('./layout/layout.component').then(m => m.LayoutComponent),
    // canActivate: [authGuard],  // Uncomment when authentication is ready
    children: [
      {
        path: 'dashboard',
        loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent)
      },
      {
        path: 'customers',
        loadChildren: () => import('./features/customers/customers.routes').then(m => m.customersRoutes)
      }
      // Add more feature routes here as children
    ]
  },
  {
    path: '**',
    redirectTo: 'dashboard'
  }
];
