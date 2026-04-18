export type CustomerStatus = 'active' | 'inactive';

export interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string;
  company: string;
  status: CustomerStatus;
  createdAt: Date;
}

export type CustomerPayload = Omit<Customer, 'id' | 'createdAt'>;
