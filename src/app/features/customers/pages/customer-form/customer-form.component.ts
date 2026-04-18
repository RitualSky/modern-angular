import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { CustomerService } from '../../services/customer.service';
import { NotificationService } from '../../../../core/services/notification.service';
import { CustomerPayload } from '../../models/customer.model';

@Component({
  selector: 'app-customer-form',
  standalone: true,
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule
  ],
  templateUrl: './customer-form.component.html',
  styleUrl: './customer-form.component.css'
})
export class CustomerFormComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private fb = inject(FormBuilder);
  private customerService = inject(CustomerService);
  private notificationService = inject(NotificationService);

  isEditMode = false;
  customerId: string | null = null;
  loading = signal(false);
  saving = signal(false);

  form = this.fb.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    email: ['', [Validators.required, Validators.email]],
    phone: ['', Validators.required],
    company: ['', Validators.required],
    status: ['active', Validators.required]
  });

  get title(): string {
    return this.isEditMode ? 'Editar cliente' : 'Nuevo cliente';
  }

  get submitLabel(): string {
    return this.isEditMode ? 'Guardar cambios' : 'Crear cliente';
  }

  ngOnInit(): void {
    this.customerId = this.route.snapshot.paramMap.get('id');
    this.isEditMode = !!this.customerId;

    if (this.isEditMode) {
      this.loadCustomer();
    }
  }

  onSubmit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.saving.set(true);
    const payload = this.form.value as CustomerPayload;

    const operation = this.isEditMode
      ? this.customerService.update(this.customerId!, payload)
      : this.customerService.create(payload);

    operation.subscribe({
      next: () => {
        this.notificationService.add(
          this.isEditMode ? 'Cliente actualizado' : 'Cliente creado',
          `"${payload.name}" fue ${this.isEditMode ? 'actualizado' : 'creado'} exitosamente.`,
          'success'
        );
        this.router.navigate(['/customers']);
      },
      error: () => this.saving.set(false)
    });
  }

  private loadCustomer(): void {
    this.loading.set(true);
    this.customerService.getById(this.customerId!).subscribe({
      next: (customer) => {
        this.form.patchValue(customer);
        this.loading.set(false);
      },
      error: () => {
        this.notificationService.add('Error', 'Cliente no encontrado.', 'error');
        this.router.navigate(['/customers']);
      }
    });
  }
}
