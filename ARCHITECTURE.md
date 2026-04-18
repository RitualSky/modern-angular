# Arquitectura del Proyecto — AngularDemo

Documentación técnica del scaffolding empresarial implementado sobre Angular 17.

---

## Tabla de contenidos

1. [Contexto y objetivos](#1-contexto-y-objetivos)
2. [Stack tecnológico](#2-stack-tecnológico)
3. [Estructura de carpetas](#3-estructura-de-carpetas)
4. [Capa Core](#4-capa-core)
5. [Capa Layout](#5-capa-layout)
6. [Capa Features](#6-capa-features)
7. [Capa Shared](#7-capa-shared)
8. [Routing y lazy loading](#8-routing-y-lazy-loading)
9. [Configuración de la aplicación](#9-configuración-de-la-aplicación)
10. [Cómo agregar una nueva feature](#10-cómo-agregar-una-nueva-feature)
11. [Cómo conectar la API real](#11-cómo-conectar-la-api-real)

---

## 1. Contexto y objetivos

El proyecto parte de un `ng new` limpio con Angular 17 (standalone components). El objetivo fue construir un scaffolding empresarial listo para escalar, que resuelva desde el inicio los problemas comunes de una aplicación de negocio:

| Necesidad | Solución implementada |
|---|---|
| Consumo de APIs REST | `HttpClient` + `ApiService` + interceptores |
| Autenticación con tokens | `AuthInterceptor` + `AuthService` + `AuthGuard` |
| Layout con navegación lateral | `LayoutComponent` con `MatSidenav` responsive |
| Notificaciones en tiempo real | `NotificationService` con Angular Signals |
| CRUDs reutilizables | Feature `customers` como plantilla base |
| Separación por dominio | Estructura de carpetas `core / layout / features / shared` |

---

## 2. Stack tecnológico

```
Angular 17.3     → standalone components, control flow (@if/@for), signals
Angular Material 17 → componentes UI (tabla, formularios, sidenav, toolbar)
Angular CDK 17   → BreakpointObserver para responsive
RxJS 7.8         → manejo de streams HTTP
TypeScript 5.4   → tipado estricto
```

**¿Por qué Angular Material?**
Es la librería UI oficial de Angular, mantenida por el mismo equipo. Garantiza compatibilidad de versiones y sigue los estándares de accesibilidad (ARIA) de forma nativa. Para una aplicación empresarial interna, su look & feel es claro y funcional sin necesidad de personalización profunda desde el inicio.

**¿Por qué Signals en lugar de NgRx?**
Para el estado de notificaciones y autenticación, los `signal()` de Angular 17 son suficientes y mucho más simples. NgRx agrega valor cuando el estado es compartido entre muchos módulos no relacionados, tiene side effects complejos o se necesita time-travel debugging. En este proyecto el estado es local a cada servicio, por lo que Signals es la elección correcta.

---

## 3. Estructura de carpetas

```
src/
├── environments/
│   ├── environment.ts          → configuración dev (apiUrl local)
│   └── environment.prod.ts     → configuración producción
└── app/
    ├── core/                   → singleton: servicios, interceptores, guards, modelos base
    │   ├── guards/
    │   ├── interceptors/
    │   ├── models/
    │   └── services/
    ├── layout/                 → shell visual de la aplicación
    │   └── components/
    │       ├── navbar/
    │       ├── sidebar/
    │       └── notification-panel/
    ├── features/               → dominios de negocio (lazy loaded)
    │   ├── dashboard/
    │   └── customers/
    │       ├── models/
    │       ├── services/
    │       └── pages/
    │           ├── customer-list/
    │           ├── customer-detail/
    │           └── customer-form/
    ├── shared/                 → componentes reutilizables entre features
    │   └── components/
    │       └── confirm-dialog/
    ├── auth/                   → flujo de autenticación (fuera del layout)
    │   └── login/
    ├── app.component.ts
    ├── app.config.ts
    └── app.routes.ts
```

**¿Por qué esta separación?**

- **`core/`** contiene todo lo que debe instanciarse **una sola vez** en toda la app (servicios `providedIn: 'root'`, interceptores, guards). Centralizar aquí evita inyectar servicios globales en features específicas.

- **`layout/`** está separado de `features/` porque el shell visual (navbar + sidebar) no pertenece a ningún dominio de negocio. Cambiarlo no debería afectar a ninguna feature.

- **`features/`** son unidades autónomas por dominio. Cada una tiene sus propios modelos, servicios y páginas. Esto permite que equipos distintos trabajen en paralelo sin conflictos y que Angular cargue cada feature solo cuando el usuario la necesita (lazy loading).

- **`shared/`** contiene componentes puramente visuales y reutilizables que **no tienen lógica de negocio** (dialogs, spinners, badges, etc.). Si un componente necesita un servicio de negocio, probablemente no pertenece aquí.

- **`auth/`** vive fuera del layout principal porque las pantallas de login, recuperación de contraseña, etc. tienen su propio diseño visual (sin sidebar ni navbar).

---

## 4. Capa Core

### 4.1 Modelos base

**`core/models/user.model.ts`**
Define la entidad `User` que usa `AuthService`. Se mantiene en `core` porque el usuario autenticado es un concepto global de la aplicación, no de una feature específica.

**`core/models/notification.model.ts`**
Define `Notification` y el tipo `NotificationType` (`info | success | warning | error`). Al estar tipado, los componentes que llaman a `NotificationService.add()` no pueden pasar un tipo inválido.

### 4.2 Servicios

**`core/services/auth.service.ts`**
```typescript
private _currentUser = signal<User | null>(null);
readonly isAuthenticated = computed(() => !!this._currentUser());
```
El estado del usuario autenticado se mantiene en un `signal`. Cualquier componente puede leer `isAuthenticated()` de forma reactiva sin suscripciones. El token se persiste en `localStorage` para sobrevivir recargas de página.

**`core/services/notification.service.ts`**
```typescript
private _notifications = signal<Notification[]>([]);
readonly unreadCount = computed(() => this._notifications().filter(n => !n.read).length);
```
El contador de no leídas es un `computed()`: se recalcula automáticamente cada vez que cambia la lista. El `NavbarComponent` lo lee directamente en el template con `notificationService.unreadCount()` — sin `async pipe`, sin suscripciones.

**`core/services/api.service.ts`**
Wrapper genérico sobre `HttpClient` que antepone automáticamente la `baseUrl` del `environment`. Centralizar las llamadas HTTP aquí tiene dos ventajas:
1. Si la URL base cambia (ej. se agrega un prefijo de versión `/v2`), se cambia en un solo lugar.
2. Los servicios de features quedan limpios: solo llaman `this.api.get<T>('/endpoint')` sin importar `HttpClient` directamente.

### 4.3 Interceptores

Los interceptores de Angular 17 son **funcionales** (`HttpInterceptorFn`), no clases. Son más simples y se integran mejor con la inyección de dependencias de la nueva API.

**`core/interceptors/auth.interceptor.ts`**
Lee el token de `AuthService` y lo agrega como header `Authorization: Bearer <token>` a **todas** las peticiones salientes. El componente que hace la llamada no necesita saber nada de tokens.

**`core/interceptors/error.interceptor.ts`**
Intercepta errores HTTP y actúa según el código de estado:
- `401` → redirige a `/auth/login` (sesión expirada)
- `403` → notificación de "Sin permisos"
- `404` → notificación de "No encontrado"
- `5xx` → notificación de "Error del servidor"

Centralizar esto aquí evita repetir bloques `catchError` en cada servicio de feature.

### 4.4 Auth Guard

**`core/guards/auth.guard.ts`**
Implementado como función (`CanActivateFn`). Redirige a `/auth/login` si `isAuthenticated()` es `false`.

> **Para activarlo:** descomenta `canActivate: [authGuard]` en `app.routes.ts` en la ruta del `LayoutComponent`. Está comentado intencionalmente para poder navegar durante el desarrollo sin necesidad de un backend de autenticación.

---

## 5. Capa Layout

### 5.1 LayoutComponent

`layout/layout.component.ts` es el **shell** de la aplicación. Contiene el `MatSidenavContainer` con el sidebar a la izquierda y el contenido principal (navbar + `<router-outlet>`) a la derecha.

**Comportamiento responsive:**
```typescript
isHandset = toSignal(
  this.breakpointObserver.observe(Breakpoints.Handset).pipe(map(r => r.matches)),
  { initialValue: false }
);

get sidenavMode() { return this.isHandset() ? 'over' : 'side'; }
```
- **Desktop**: el sidebar es `mode="side"` — siempre visible, empuja el contenido.
- **Mobile**: el sidebar es `mode="over"` — flota sobre el contenido y se cierra al tocar fuera.

El botón de hamburguesa en el navbar llama a `sidenav.toggle()` a través de un `@Output() toggleSidenav`.

### 5.2 NavbarComponent

Toolbar fijo con tres zonas:
1. **Izquierda**: botón de hamburguesa para toggle del sidebar
2. **Centro**: nombre de la aplicación
3. **Derecha**: campana de notificaciones + menú de usuario

El badge de notificaciones usa `[matBadgeHidden]="unreadCount === 0"` para ocultarse cuando no hay pendientes — evita mostrar un "0" que confunde.

### 5.3 SidebarComponent

Lista de navegación con `mat-nav-list`. Cada ítem usa `routerLinkActive="active-link"` para resaltar la ruta activa automáticamente. Los ítems son un array de objetos `NavItem`:
```typescript
navItems: NavItem[] = [
  { label: 'Dashboard', icon: 'dashboard', route: '/dashboard' },
  { label: 'Clientes',  icon: 'people',    route: '/customers' },
  // ...
];
```
Para agregar una nueva sección al menú, **solo se agrega un objeto al array**.

### 5.4 NotificationPanelComponent

Se abre como `MatMenu` al hacer clic en la campana. Lee directamente de `NotificationService` (inyectado). Cada notificación tiene:
- Un indicador de color lateral según el tipo (`info/success/warning/error`)
- Estado leído/no leído (fondo diferenciado)
- Botón de cierre individual
- Botón "Marcar todas como leídas"

---

## 6. Capa Features

### 6.1 Estructura de una feature

Cada feature sigue el mismo patrón:

```
features/
└── [nombre-feature]/
    ├── [nombre-feature].routes.ts   → rutas del dominio
    ├── models/                      → interfaces y tipos del dominio
    ├── services/                    → lógica de negocio y llamadas API
    └── pages/                       → componentes de página (list / detail / form)
```

Esta estructura hace que cada feature sea **autónoma**: se puede mover, duplicar o eliminar sin afectar al resto de la aplicación.

### 6.2 Feature: Customers

Implementada como plantilla base para todos los futuros CRUDs del sistema.

**`customer.model.ts`**
```typescript
export type CustomerPayload = Omit<Customer, 'id' | 'createdAt'>;
```
El tipo `CustomerPayload` excluye los campos que genera el servidor (`id` y `createdAt`). Se usa en create y update para garantizar que el frontend no envíe esos campos por accidente.

**`customer.service.ts`**
Actualmente usa un `signal` como store en memoria con datos mock. Esto permite que la aplicación funcione y sea demostrable sin un backend disponible. Cada método tiene comentada la llamada real a la API:
```typescript
getAll(): Observable<Customer[]> {
  // TODO: return this.api.get<Customer[]>('/customers');
  return of(this._store()).pipe(delay(300));
}
```
Para pasar a producción: descomentar las líneas `TODO` y eliminar el `signal` `_store`.

**`customer-list.component.ts`**
Usa `MatTableDataSource` que tiene soporte nativo para filtro, sort y paginación:
```typescript
dataSource = new MatTableDataSource<Customer>();
// El filtro de texto busca en todos los campos automáticamente:
this.dataSource.filter = value.trim().toLowerCase();
```

**`customer-form.component.ts`**
Un solo componente reutilizado para crear y editar. Detecta el modo por la presencia del parámetro `:id` en la URL:
```typescript
ngOnInit(): void {
  this.customerId = this.route.snapshot.paramMap.get('id');
  this.isEditMode = !!this.customerId;
  if (this.isEditMode) this.loadCustomer();
}
```
En modo edición pre-carga los datos con `form.patchValue(customer)`. En modo creación el formulario queda vacío con `status: 'active'` como default.

---

## 7. Capa Shared

### ConfirmDialogComponent

`shared/components/confirm-dialog/confirm-dialog.component.ts`

Dialog reutilizable para cualquier acción destructiva. Recibe datos a través de `MAT_DIALOG_DATA`:
```typescript
this.dialog.open(ConfirmDialogComponent, {
  width: '380px',
  data: {
    title: 'Eliminar cliente',
    message: '¿Estás seguro?',
    confirmLabel: 'Eliminar'  // opcional, default: 'Confirmar'
  }
});
```
Devuelve `true` si el usuario confirma, `undefined` si cancela. Se usa con `dialogRef.afterClosed()`.

> **Regla para `shared/`**: un componente entra aquí solo si no importa ningún servicio de negocio y puede funcionar en cualquier contexto. Si necesita `CustomerService`, pertenece a `features/customers/`.

---

## 8. Routing y lazy loading

**`app.routes.ts`** define tres niveles:

```typescript
[
  // 1. Rutas de autenticación — sin layout, carga independiente
  { path: 'auth', loadChildren: () => import('./auth/auth.routes') },

  // 2. Rutas protegidas — dentro del LayoutComponent (sidebar + navbar)
  {
    path: '',
    loadComponent: () => import('./layout/layout.component'),
    // canActivate: [authGuard],  ← descomentar cuando la auth esté lista
    children: [
      { path: 'dashboard',  loadComponent: ... },
      { path: 'customers',  loadChildren: () => import('./features/customers/customers.routes') },
    ]
  },

  // 3. Wildcard
  { path: '**', redirectTo: 'dashboard' }
]
```

**¿Por qué `loadChildren` para features y `loadComponent` para páginas individuales?**
- `loadChildren` carga todo el sub-árbol de rutas de una feature como un chunk separado. Angular agrupa todos los componentes de esa feature en un solo archivo descargable.
- `loadComponent` carga un solo componente como chunk. Se usa para páginas aisladas como el dashboard.

El resultado es que el bundle inicial es mínimo: el usuario descarga solo el layout y la página que visita, no toda la aplicación.

---

## 9. Configuración de la aplicación

**`app.config.ts`**
```typescript
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withViewTransitions()),
    provideHttpClient(withInterceptors([authInterceptor, errorInterceptor])),
    provideAnimations()
  ]
};
```

- `withViewTransitions()`: habilita transiciones animadas entre rutas (View Transitions API). Mejora la percepción de fluidez sin código adicional.
- `withInterceptors([...])`: registra los interceptores funcionales. El orden importa: `authInterceptor` agrega el token antes de que `errorInterceptor` procese la respuesta.
- `provideAnimations()`: requerido por Angular Material para que los componentes animados (sidenav, menús, ripples) funcionen correctamente.

**`environments/`**
```typescript
// environment.ts (desarrollo)
export const environment = { production: false, apiUrl: 'http://localhost:3000/api' };

// environment.prod.ts (producción)
export const environment = { production: true, apiUrl: 'https://api.yourdomain.com/api' };
```
El `angular.json` tiene configurado `fileReplacements` para que al compilar con `--configuration production` se reemplace automáticamente `environment.ts` por `environment.prod.ts`.

---

## 10. Cómo agregar una nueva feature

Ejemplo: agregar un CRUD de **Products**.

### Paso 1 — Crear la estructura

```
src/app/features/products/
├── products.routes.ts
├── models/
│   └── product.model.ts
├── services/
│   └── product.service.ts
└── pages/
    ├── product-list/
    ├── product-detail/
    └── product-form/
```

### Paso 2 — Definir el modelo

```typescript
// models/product.model.ts
export interface Product {
  id: string;
  name: string;
  price: number;
  stock: number;
  status: 'active' | 'inactive';
  createdAt: Date;
}

export type ProductPayload = Omit<Product, 'id' | 'createdAt'>;
```

### Paso 3 — Crear el servicio

Copiar `customer.service.ts` como base y reemplazar el tipo y el endpoint:
```typescript
getAll(): Observable<Product[]> {
  return this.api.get<Product[]>('/products');
}
```

### Paso 4 — Definir las rutas

```typescript
// products.routes.ts
export const productsRoutes: Routes = [
  { path: '',         loadComponent: () => import('./pages/product-list/...')   },
  { path: 'new',      loadComponent: () => import('./pages/product-form/...')   },
  { path: ':id',      loadComponent: () => import('./pages/product-detail/...') },
  { path: ':id/edit', loadComponent: () => import('./pages/product-form/...')   }
];
```

### Paso 5 — Registrar en app.routes.ts

```typescript
{
  path: 'products',
  loadChildren: () => import('./features/products/products.routes').then(m => m.productsRoutes)
}
```

### Paso 6 — Agregar al sidebar

```typescript
// sidebar.component.ts
navItems = [
  { label: 'Dashboard',  icon: 'dashboard',    route: '/dashboard'  },
  { label: 'Clientes',   icon: 'people',        route: '/customers'  },
  { label: 'Productos',  icon: 'inventory_2',   route: '/products'   }, // ← agregar
];
```

---

## 11. Cómo conectar la API real

El servicio de cada feature tiene los métodos reales comentados. Para activarlos:

### En el servicio de la feature

```typescript
// customer.service.ts — ANTES (mock)
getAll(): Observable<Customer[]> {
  // TODO: return this.api.get<Customer[]>('/customers');
  return of(this._store()).pipe(delay(300));
}

// DESPUÉS (API real)
getAll(): Observable<Customer[]> {
  return this.api.get<Customer[]>('/customers');
}
```

Eliminar el `signal` `_store` y los datos mock (`MOCK_CUSTOMERS`) una vez que todos los métodos estén conectados.

### URL base de la API

Editar `src/environments/environment.ts`:
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://tu-servidor.com/api'  // ← cambiar aquí
};
```

### Activar autenticación

Una vez que el backend de auth esté disponible:

1. Implementar la lógica de login en `AuthService`:
```typescript
login(email: string, password: string): Observable<void> {
  return this.api.post<{ token: string; user: User }>('/auth/login', { email, password })
    .pipe(tap(({ token, user }) => this.setToken(token, user)));
}
```

2. Conectar el formulario en `LoginComponent.onSubmit()`.

3. Descomentar `canActivate: [authGuard]` en `app.routes.ts`.
