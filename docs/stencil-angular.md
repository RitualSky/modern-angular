# Stencil en proyectos Angular

Stencil compila Web Components estándar (Custom Elements v1), por lo que Angular los consume de forma nativa sin adaptadores especiales. A continuación se documentan los patrones recomendados para este stack (Angular 21, standalone components, Signals).

---

## 1. Instalación del design system

```bash
npm install @mi-org/design-system
```

---

## 2. Registro global de componentes

Registrar los custom elements una sola vez al iniciar la aplicación:

```typescript
// src/main.ts
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';
import { defineCustomElements } from '@mi-org/design-system/loader';

defineCustomElements(window);

bootstrapApplication(AppComponent, appConfig);
```

---

## 3. Habilitar custom elements en componentes

Angular desconoce los tags de Stencil por defecto. Hay que indicarle que los acepte con `CUSTOM_ELEMENTS_SCHEMA`:

```typescript
import { Component } from '@angular/core';
import { CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';

@Component({
  selector: 'app-dashboard',
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  template: `<mi-button variant="primary">Guardar</mi-button>`
})
export class DashboardComponent {}
```

> **Nota:** `CUSTOM_ELEMENTS_SCHEMA` desactiva la validación de templates para tags desconocidos. Aplicarlo solo en los componentes que realmente usen web components externos.

---

## 4. Manejo de eventos y Change Detection

### Con `zone.js` (tradicional)

Los eventos nativos de Custom Elements no pasan por Zone.js, por lo que Angular no detecta los cambios automáticamente:

```typescript
import { Component, NgZone, inject } from '@angular/core';
import { CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';

@Component({
  selector: 'app-form',
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  template: `<mi-input (miChange)="onChange($event)"></mi-input>`
})
export class FormComponent {
  private ngZone = inject(NgZone);
  value = '';

  onChange(event: CustomEvent) {
    this.ngZone.run(() => {
      this.value = event.detail;
    });
  }
}
```

### Con Signals (recomendado — Angular 17+)

Signals no dependen de Zone.js, por lo que los eventos de Custom Elements funcionan directamente:

```typescript
import { Component, signal, CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';

@Component({
  selector: 'app-form',
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  template: `
    <mi-input (miChange)="onChange($event)"></mi-input>
    <p>Valor: {{ value() }}</p>
  `
})
export class FormComponent {
  value = signal('');

  onChange(event: CustomEvent) {
    this.value.set(event.detail);
  }
}
```

---

## 5. Wrappers Angular sobre componentes Stencil

Cuando se necesita tipado estricto, inputs/outputs declarados y mejor integración con el tooling de Angular, la mejor práctica es crear un wrapper:

```typescript
// shared/components/mi-button/mi-button.component.ts
import { Component, input, output, CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';

@Component({
  selector: 'app-mi-button',
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  template: `
    <mi-button
      [variant]="variant()"
      [disabled]="disabled()"
      (miClick)="clicked.emit($event)">
      <ng-content />
    </mi-button>
  `
})
export class MiButtonComponent {
  variant = input<'primary' | 'secondary' | 'ghost'>('primary');
  disabled = input<boolean>(false);
  clicked = output<CustomEvent>();
}
```

**Ventajas del wrapper:**
- Tipado completo con `input()` signals
- `CUSTOM_ELEMENTS_SCHEMA` queda aislado en un solo lugar
- El resto de la app usa componentes Angular normales
- Facilita tests con `TestBed`

---

## 6. Comparativa de enfoques

| Enfoque | Cuándo usar |
|---|---|
| `defineCustomElements` + `CUSTOM_ELEMENTS_SCHEMA` directo | Uso puntual, prototipos rápidos |
| Wrappers Angular | Design system en producción, tipado estricto necesario |
| Signals + eventos nativos | Angular 17+ sin dependencia de Zone.js |
| `NgZone.run()` | Proyectos legacy con zone.js que no pueden migrar aún |

---

## 7. Configuración recomendada para este proyecto

Este proyecto usa **Angular 21 + standalone components + Signals**. El patrón ideal es:

1. `defineCustomElements` en `main.ts`
2. Wrappers en `src/app/shared/components/` con `input()` / `output()` signals
3. `CUSTOM_ELEMENTS_SCHEMA` solo dentro de cada wrapper, nunca disperso
4. Eventos manejados directamente con signals (sin `NgZone`)
