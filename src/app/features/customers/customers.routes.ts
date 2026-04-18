import { Routes } from '@angular/router';

export const customersRoutes: Routes = [
  {
    path: '',
    loadComponent: () => import('./pages/customer-list/customer-list.component')
      .then(m => m.CustomerListComponent)
  },
  {
    path: 'new',
    loadComponent: () => import('./pages/customer-form/customer-form.component')
      .then(m => m.CustomerFormComponent)
  },
  {
    path: ':id',
    loadComponent: () => import('./pages/customer-detail/customer-detail.component')
      .then(m => m.CustomerDetailComponent)
  },
  {
    path: ':id/edit',
    loadComponent: () => import('./pages/customer-form/customer-form.component')
      .then(m => m.CustomerFormComponent)
  }
];
