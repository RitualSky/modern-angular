import { Injectable, inject, signal } from '@angular/core';
import { Observable, of, throwError } from 'rxjs';
import { delay } from 'rxjs/operators';
import { Customer, CustomerPayload } from '../models/customer.model';
import { ApiService } from '../../../core/services/api.service';

const MOCK_CUSTOMERS: Customer[] = [
  {
    id: '1',
    name: 'Ana García',
    email: 'ana.garcia@techsolutions.com',
    phone: '+51 987 654 321',
    company: 'Tech Solutions S.A.',
    status: 'active',
    createdAt: new Date('2024-01-15')
  },
  {
    id: '2',
    name: 'Carlos Mendoza',
    email: 'c.mendoza@globalcorp.pe',
    phone: '+51 912 345 678',
    company: 'Global Corp',
    status: 'active',
    createdAt: new Date('2024-02-20')
  },
  {
    id: '3',
    name: 'Lucía Torres',
    email: 'lucia.t@innovatech.io',
    phone: '+51 965 123 456',
    company: 'InnovaTech',
    status: 'inactive',
    createdAt: new Date('2024-03-05')
  },
  {
    id: '4',
    name: 'Roberto Silva',
    email: 'r.silva@datagroup.com',
    phone: '+51 978 901 234',
    company: 'Data Group',
    status: 'active',
    createdAt: new Date('2024-04-10')
  },
  {
    id: '5',
    name: 'María Pérez',
    email: 'mperez@nexusco.com',
    phone: '+51 934 567 890',
    company: 'Nexus Co.',
    status: 'active',
    createdAt: new Date('2024-05-22')
  }
];

@Injectable({ providedIn: 'root' })
export class CustomerService {
  private api = inject(ApiService);

  // Mock store — remove this signal when the API is ready
  private _store = signal<Customer[]>(MOCK_CUSTOMERS);

  getAll(): Observable<Customer[]> {
    // TODO: replace with → return this.api.get<Customer[]>('/customers');
    return of(this._store()).pipe(delay(300));
  }

  getById(id: string): Observable<Customer> {
    // TODO: replace with → return this.api.get<Customer>(`/customers/${id}`);
    const customer = this._store().find(c => c.id === id);
    if (!customer) return throwError(() => new Error('Customer not found'));
    return of(customer).pipe(delay(200));
  }

  create(payload: CustomerPayload): Observable<Customer> {
    // TODO: replace with → return this.api.post<Customer>('/customers', payload);
    const newCustomer: Customer = {
      ...payload,
      id: crypto.randomUUID(),
      createdAt: new Date()
    };
    this._store.update(list => [newCustomer, ...list]);
    return of(newCustomer).pipe(delay(300));
  }

  update(id: string, payload: CustomerPayload): Observable<Customer> {
    // TODO: replace with → return this.api.put<Customer>(`/customers/${id}`, payload);
    const existing = this._store().find(c => c.id === id)!;
    const updated: Customer = { ...existing, ...payload };
    this._store.update(list => list.map(c => c.id === id ? updated : c));
    return of(updated).pipe(delay(300));
  }

  delete(id: string): Observable<void> {
    // TODO: replace with → return this.api.delete<void>(`/customers/${id}`);
    this._store.update(list => list.filter(c => c.id !== id));
    return of(undefined).pipe(delay(200));
  }
}
