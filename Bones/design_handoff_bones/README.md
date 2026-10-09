# Handoff: Bones · Rediseño PetsListView + PetDetailView

> **Para Claude Code en Xcode.** Pegá este README + carpeta en el proyecto Bones y pedile que implemente las pantallas en SwiftUI siguiendo los patrones existentes del codebase.

---

## Overview

Rediseño de dos pantallas centrales de **Bones** (app iOS para tracking de salud de mascotas):

1. **`PetsListView`** — pantalla principal. 4 estados: vacío, 1 mascota (dashboard), grilla de 2+ mascotas, swipe de acciones rápidas.
2. **`PetDetailView`** — detalle de mascota con 4 tabs: **Próximos**, **Vacunas**, **Parásitos**, **Peso**.

Dirección estética elegida: **"Vet Pro"** — dashboard clínico moderno. Cards blancos sobre fondo cálido, sombras micro, pills de estado, números en monoespaciada, y un **chip monograma con color saturado por mascota** como identidad sutil.

---

## ⚠️ Sobre los archivos de este bundle

Los archivos `.html` y `.jsx` en esta carpeta son **referencias de diseño** — prototipos HTML/React que muestran look & feel e interacciones intencionadas. **No son código para copiar.**

La tarea es **recrear estas pantallas en SwiftUI** dentro del proyecto Xcode existente de Bones, usando los patrones, componentes, modelos de datos (`Pet`, `Vaccine`, `Weight`, etc.) y design tokens que ya estén establecidos en el codebase. Si hay un sistema de diseño/tokens, **úsenlos**; los hex values acá son referencia visual.

**Fidelidad: HIFI.** Colores, tipografía, spacing y radios son finales. El developer debe recrear lo más parecido posible, ajustándose a las APIs nativas de SwiftUI.

---

## Cómo ver los mocks

Abrí `PetsListView Redesign.html` en un navegador. Es un canvas paneable/zoomeable con todas las pantallas en marcos de iPhone (402×874). Cada artboard tiene un label.

Las pantallas están en este orden:

| # | Sección | Artboards |
|---|---------|-----------|
| 01 | Estado vacío | `EmptyState` |
| 02 | 1 mascota — Dashboard | `Dashboard(pet)` |
| 03 | 3 mascotas — Grilla | `Grid(pets)` |
| Detail 01 | Próximos | `PetDetail.Upcoming` |
| Detail 02 | Vacunas | `PetDetail.Vaccines` |
| Detail 03 | Peso + Sheet | `PetDetail.Weight`, `PetDetail.WeightSheet` |
| 04 | 6 mascotas — Grilla + swipe | `Grid(pets, showSwipeHint)` |

---

## Design Tokens

```swift
// Color.swift — extender los tokens existentes si no están todos
extension Color {
    static let bonesBg        = Color(hex: 0xF6F6F4)   // fondo app
    static let bonesPanel     = Color.white            // cards
    static let bonesInk       = Color(hex: 0x13161A)   // texto primario
    static let bonesInkSoft   = Color(hex: 0x5C636E)   // texto secundario
    static let bonesInkFaint  = Color(hex: 0x9CA3AF)   // texto terciario / placeholders
    static let bonesRule      = Color(hex: 0xECEDEF)   // bordes / divisores
    static let bonesRuleSoft  = Color(hex: 0xF4F4F2)   // divisores internos
    static let bonesAccent    = Color(hex: 0x0E5C4F)   // clinical teal (sistema, no pet)

    // Estado
    static let bonesOk        = Color(hex: 0x3D8A5A)   // verde "al día"
    static let bonesSoon      = Color(hex: 0xC99A2C)   // ámbar "próximo"
    static let bonesOverdue   = Color(hex: 0xB0413E)   // rojo "vencido"

    // Categorías (usar para iconos/tints, NO como color de mascota)
    static let bonesVaccine   = Color(hex: 0x3D8A5A)   // jeringa
    static let bonesDeworming = Color(hex: 0xC99A2C)   // gota
    static let bonesWeight    = Color(hex: 0x3C4A6B)   // balanza
}
```

### Paleta por mascota (identidad)
Cada `Pet` lleva una paleta de 3 tonos. Si el modelo `Pet` actual no la tiene, agregarla:

```swift
struct PetTone { let ink: Color; let soft: Color; let hue: Color }

// Opciones predefinidas (orden = primera mascota → última)
static let forestPalette    = PetTone(ink: .init(hex: 0x3D5A4A), soft: .init(hex: 0xE8EDE6), hue: .init(hex: 0x7A9988))
static let terracottaPalette = PetTone(ink: .init(hex: 0x8B4A2E), soft: .init(hex: 0xF2E6DC), hue: .init(hex: 0xC57A52))
static let slatePalette     = PetTone(ink: .init(hex: 0x3C4A6B), soft: .init(hex: 0xE4E8EF), hue: .init(hex: 0x6E84A8))
static let ochrePalette     = PetTone(ink: .init(hex: 0x8A6E1F), soft: .init(hex: 0xF1ECD8), hue: .init(hex: 0xBFA13E))
static let plumPalette      = PetTone(ink: .init(hex: 0x5C3D6E), soft: .init(hex: 0xECE3F1), hue: .init(hex: 0x9272A6))
static let caramelPalette   = PetTone(ink: .init(hex: 0x7A5230), soft: .init(hex: 0xF1E6D8), hue: .init(hex: 0xB8895A))
```

`hue` se usa para el monograma; `soft` para fondos suaves opcionales; `ink` reservado para tipografía sobre `soft`.

### Tipografía

| Token | Family | Uso |
|-------|--------|-----|
| **Sans** | Inter (fallback: SF Pro) | Toda la UI |
| **Mono** | JetBrains Mono (fallback: SF Mono) | Números: peso, fechas cortas, edad, conteos |

Tamaños usados (en pt iOS, derivados del mock):

| Rol | Size | Weight | Tracking |
|-----|------|--------|----------|
| Title (NavBar grande) | 26 | 600 | -0.02em |
| H2 (nombre mascota en hero) | 26 | 600 | -0.02em |
| H3 card (nombre en grid) | 17 | 600 | -0.01em |
| Section head (eyebrow) | 13 | 600 uppercase | 0.04em |
| Body | 13.5 | 500 |  |
| Body soft | 12.5 | 500 |  |
| Caption | 12 | 500 |  |
| Micro / eyebrow | 11 | 600 uppercase | 0.04em |
| Pill / chip | 11 | 500 |  |
| Counter (mono) | 12 | 500 | tabular |
| Big number (peso) | 24 mono | 600 | tabular |
| KPI date (mono) | 19 mono | 600 | tabular |

### Spacing & radius

| Token | Valor |
|-------|-------|
| Card radius (hero) | 18–20 |
| Card radius (estándar) | 16 |
| Mini card radius | 12–14 |
| Pill radius | 999 (capsule) |
| Icon container radius | 9–12 |
| Card padding interior | 13–18 |
| Lista vertical gap | 10 |
| Card horizontal margin | 20 |
| Bottom tabbar height | 86 (22 safe area) |

### Sombras
**Sin sombras pesadas.** Solo bordes hairline: `1px solid bonesRule`. El monograma usa un `inset shadow` muy sutil + un drop de 1px del mismo hue al 20%.

---

## Iconografía

Custom outline, 1.6–1.9 stroke. Set definido en `icons.jsx`:

- **Syringe** — vacunas
- **Drop** (gota) — desparasitación
- **Scale** (balanza de 2 platos) — peso
- **Paw** — marca / tab Mascotas
- **Calendar** — agenda
- **Plus**, **Search**, **ChevronRight**, **ArrowUp/Down**, **Dash**
- **Gear** — ajustes

En SwiftUI sugerir mapeo:
- `Syringe` → `Image(systemName: "syringe.fill")` o custom SVG
- `Drop` → `Image(systemName: "drop.fill")` (con tint amarillo)
- `Scale` → `Image(systemName: "scalemass.fill")`
- `Paw` → `Image(systemName: "pawprint.fill")`
- Resto: SF Symbols equivalentes (`plus`, `magnifyingglass`, `chevron.right`, `arrow.up`, `arrow.down`, `minus`, `gearshape`).

Si Bones ya tiene set custom, **usar el existente** y no SF Symbols.

---

## Componentes a construir

Crear estos componentes reusables. Cada uno está implementado en `variant-b.jsx` o `pet-detail-b.jsx` — leer ahí la lógica.

### 1. `StatusPill`
Pill capsule con punto + label.
- Props: `status: .ok | .soon | .overdue`, `label: String`
- Color: `pill bg = status.color × 8%`, `text = status.color`
- Tamaño: 11pt, padding `4×10×4×8`, punto 6×6 redondeado

### 2. `Monogram(pet:size:radius:)`
Cuadrado redondeado con la inicial del nombre. Fondo = `pet.tone.hue`, texto blanco peso 600 (40% del tamaño).
- Marca de agua interior: silueta de pata a 13% opacidad blanca
- `boxShadow: inset 0 0 0 1px black @ 4%`

### 3. `MiniTimeline`
Barra de 4pt mostrando proximidad de un evento en una ventana de 14 días.
- Si `overdue`, marker en la izquierda
- Fill al `color × 50%`, marker tick al `color` sólido

### 4. `KpiCard`
Card 1/2 de ancho para "Próx. vacuna" / "Próx. desparas." en el dashboard.
- Header: icono (chip 30×30 tinted) + pill con `event.in` (ej. "en 9 días", "hoy", "hace 8 días")
- Body: eyebrow + fecha grande mono + nombre + `MiniTimeline`
- Min height: 132
- Si overdue → fondo del pill `overdue × 12%`, texto rojo

### 5. `DeltaBadge`
Pill mono con flecha arriba/abajo/dash + valor (`+0.3`, `-0.1`, `+0.0`).
- Up = verde (ok), Down = rojo (overdue), Flat = gris

### 6. `RegRow`
Fila horizontal: icono chip (30×30 fondo `bonesBg`) + label uppercase + value + meta a la derecha en mono.

### 7. `MiniStat` (grid card)
Mini cell en la grilla 3-up dentro de `PetCard`. Fondo `bonesBg`, radius 10, padding `8×10`. Icono pequeño + label + value bold + sub mono.

### 8. `PetCard` (item de Grid)
Card horizontal con:
- Header: Monogram 48 + nombre + StatusPill, segunda línea con `especie · raza · edad(mono)`
- Strip 3-up: MiniStat Vacuna / Desparas. / Peso
- Swipe a la izquierda revela 2 acciones de 64pt: **Peso** (azul slate) y **Vacuna** (color del pet)
  - Reveal width: 138pt
  - Implementar con `.swipeActions` o gesture custom

### 9. `NavBar` (top chrome)
- Título grande (26pt) + contador opcional `01`-style en pill mono
- Botones derecha: search (outline) + plus (negro sólido)
- Sin separador inferior, fondo `bonesBg`

### 10. `TabBar` (bottom)
3 items: Mascotas / Agenda / Ajustes. Activo = ink 600, inactivo = faint 500. Altura 86pt (incluye safe area).

### 11. `TabPicker` (segmented pill en PetDetail)
Pill negro de fondo (`bonesInk`), cada tab activa = chip blanco con sombra leve. 4 tabs: Próximos / Vacunas / Parásitos / Peso.

### 12. `PetHeader` (en detail)
Monogram 88 + nombre 32pt + chips de meta (especie, raza, sexo, edad, peso actual en mono).

### 13. `EventRow` (lista de próximos)
Fila con icono tinted + nombre + dosis (chip) + fecha mono + (si inminente) hora.

### 14. `SeriesCard` (vacunas como serie)
- Header: nombre serie + StatusPill
- Métricas: progreso barra con ticks (1 por dosis), label "3 de 5"
- Lista de dosis expandida (próximo, último, futuras)
- Card también funciona colapsada (mostrar solo header + progress)

### 15. `WeightChart`
SVG line chart con relleno gradient suave debajo. Padding `l24 r8 t12 b18`.
- Selector rango: 1M / 3M / 6M / 1A / Todo (pill mono)
- KPIs debajo: Mín / Prom / Máx en mono
- Lista de registros en mono

### 16. `WeightSheet`
Bottom sheet para registrar peso. Form fields: peso (numérico mono grande), fecha, notas. CTA negro full-width.

### 17. `AdherenceDots`
Fila de 6 dots (un dot por mes). Estados:
- `done` → relleno verde
- `missed` → relleno rojo
- `pending` → ring ámbar (sin relleno)
- `na` → relleno gris (mes en el que el protocolo no estaba activo)

### 18. `ParasiteProtocolCard`
Card para protocolo recurrente de parásitos. Ver detalle de la sección "Parásitos" más abajo. Diferencia clave con `SeriesCard`: no hay progreso de N/N dosis, sino **cadencia + adherencia histórica**.

---

## Modelo de datos esperado

Ver `data.js` para ejemplos completos. Estructura propuesta para Swift:

```swift
struct Pet: Identifiable {
    let id: String
    var name: String
    var species: String   // "Perro" | "Gato"
    var breed: String
    var sex: Sex          // .male | .female
    var birth: Date
    var color: String     // color del pelaje, ej "Tricolor"

    var status: HealthStatus  // .ok | .soon | .overdue (computado)
    var statusLabel: String

    var currentWeight: WeightSample
    var nextVaccine: ScheduledEvent
    var nextDeworming: ScheduledEvent
    var lastVaccine: HistoryEvent
    var lastDeworming: HistoryEvent

    var tone: PetTone        // identidad visual
}

struct ScheduledEvent {
    var name: String       // "Polivalente (3/3)"
    var date: Date
    var relativeLabel: String  // "en 9 días", "hoy", "mañana", "hace 8 días"
    var isOverdue: Bool
}

struct WeightSample {
    var value: Double
    var unit: String       // "kg"
    var deltaValue: String // "+0.3", "-0.1", "+0.0"
    var deltaDirection: Trend // .up | .down | .flat
    var recordedAt: Date
    var relativeLabel: String  // "hace 5 días"
}

enum HealthStatus { case ok, soon, overdue }
```

`relativeLabel` debe ser una función helper (`RelativeDateTimeFormatter`) con override para "hoy/mañana/pasado mañana".

---

## Pantallas — detalle por pantalla

### A · Estado vacío (`EmptyState`)
- Card central blanca radius 20 padding `32×28`
- Ilustración: 3 cards apilados (uno con borde dashed, dos rotados con sólido)
- Card frontal trae icono Paw en chip dashed
- Title `Aún no hay mascotas` (20/600) + body soft centrado max-width 240
- CTA negro `+ Añadir mascota`
- Debajo grid 3-up "Qué podrás registrar": Vacunas / Desparas. / Peso con icono tinted

### B · Dashboard 1 mascota (`Dashboard`)
- NavBar `Resumen`
- **Hero card** con gradient band del `pet.tone.hue` arriba (opacity 1F→00), Monogram 68, nombre 26, StatusPill, meta
- **Sección "Próximos eventos"**: 2 KpiCard lado a lado
- **Sección "Estado"**: card con Peso panel (icono `bonesWeight` chip, value 24mono + unit + DeltaBadge + `when` a la derecha) + 2 RegRow (Última vacuna, Última desparas.) separados por hairline
- Hint card al final: "Desliza una fila a la izquierda para registrar peso o vacuna" — fondo blanco border dashed

### C · Grilla 2+ mascotas (`Grid`)
- NavBar con contador `XX`
- Lista vertical de `PetCard`s, gap 10
- En 6 mascotas: la segunda muestra swipe revelado con acciones Peso (slate) + Vacuna (hue del pet)

### D · Pet Detail (4 tabs)

**Próximos (default)**
- Hero oscuro destacando próximo evento (fondo `bonesInk`, texto blanco). Icono grande, nombre, dosis chip, fecha grande mono + countdown
- Secciones por proximidad: "Esta semana" / "Próximos 30 días" / "Más adelante"
- Cada `EventRow` con icono tinted, dosis chip, fecha, hora si <24h

**Vacunas**
- Lista de `SeriesCard` (Polivalente, Rabia, etc.)
- Primera serie expandida (muestra dosis), última con estado overdue
- Botón flotante `+` para registrar

**Parásitos**
- Modelo distinto a Vacunas: **protocolos recurrentes** (no series finitas). Cada protocolo es un tratamiento continuo (pipeta mensual, tableta trimestral, collar 8 meses).
- Header strip: KPI `Protocolos activos` + `Adherencia · 6m` (con barra de progreso teñida según el %).
- Leyenda de 4 estados de dot: Aplicada (verde) / Pendiente (ring ámbar) / Saltada (rojo) / N/A (gris).
- `ParasiteProtocolCard` por protocolo:
  - Header con icono tinted (gota = interno, paw = externo) + nombre + chip **INTERNO/EXTERNO** + `StatusPill`
  - Producto (subtítulo)
  - Row 3-up sobre fondo `bonesBg`: **Cadencia** / **Próxima** (mono) / **Última** (mono)
  - **AdherenceDots**: 6 dots (un dot por mes, más antiguo → reciente) + KPI `%` alineado a derecha
  - Footer con CTA `+ Registrar aplicación` y chevron a la derecha
- CTA dashed `+ Añadir protocolo` al final.

**Peso**
- Header card: peso actual (mono 32) + DeltaBadge + label "vs hace X"
- Range selector pill: 1M · 3M · 6M · 1A · Todo
- `WeightChart` SVG
- KPIs row: Mín / Prom / Máx
- Lista de `WeightRow` con fecha mono + hora + kg + notas opcionales
- CTA flotante `+ Registrar peso` abre `WeightSheet`

---

## Interacciones & navegación

| Acción | Trigger | Resultado |
|--------|---------|-----------|
| Tap card de mascota | Tap en `PetCard` | Push a `PetDetailView` |
| Swipe izquierda | Drag horizontal en `PetCard` | Revela 2 acciones (Peso, Vacuna) — usar `.swipeActions(edge: .trailing)` |
| Tap acción swipe | Tap en `SwipeAction` | Abre sheet correspondiente |
| Tap `+` en NavBar | Tap | Modal de "Nueva mascota" |
| Tap tab en PetDetail | Tap | Cambio de tab con animación cross-fade 200ms |
| Tap fila en Próximos | Tap | Push a detalle del evento o sheet de "marcar como hecho" |
| Pull-down | Drag desde top | Refresh |

### Animaciones
- Tab switch: `.animation(.easeOut(duration: 0.2))`
- Swipe reveal: spring suave, distancia 138pt
- Card press: `scale 0.98` opacity → usar `.buttonStyle(.plain)` con `pressed` state

---

## Estado / state management

- `PetsListViewModel` con `@Published var pets: [Pet]`
- Estado vacío automático cuando `pets.isEmpty`
- `Dashboard` cuando `pets.count == 1`
- `Grid` cuando `pets.count >= 2`
- Compartir el VM o usar router separado para `PetDetailView`
- Tabs en detail: `@State var activeTab: PetDetailTab = .upcoming` o navigation segment

---

## Assets a generar / pedir

- Iconos custom outline (si Bones no los tiene ya): Syringe, Drop, Scale, Paw — entregables como SVG o SF Symbols custom
- Fuente Inter (variable o weights 400/500/600/700) en el bundle
- Fuente JetBrains Mono (weights 400/500/600) en el bundle
- Registrarlas en `Info.plist` (`UIAppFonts`)

---

## Files en este bundle

| Archivo | Qué contiene |
|---------|--------------|
| `PetsListView Redesign.html` | Canvas principal con todos los mocks |
| `variant-b.jsx` | Componentes de PetsListView (EmptyState, Dashboard, Grid, PetCard, etc.) |
| `pet-detail-b.jsx` | Componentes de PetDetailView (4 tabs, WeightChart, SeriesCard, etc.) |
| `icons.jsx` | Set de iconos custom como referencia visual |
| `data.js` | Datos mock con la estructura completa esperada |
| `ios-frame.jsx`, `design-canvas.jsx` | Infraestructura del canvas (ignorar para implementación) |

---

## Lo que NO está cubierto (preguntar al diseñador antes de inventar)

- Onboarding / primer uso después de tocar "Añadir mascota"
- Modal "Añadir protocolo" (form de nuevo protocolo de parásitos)
- Estados de loading & error
- Pantalla de configuración / settings y tab Agenda (los otros 2 tabs del bottom bar)
- Notificaciones push (mock)
- Modo oscuro — el diseño es light-only por ahora
- Accesibilidad — Dynamic Type aún no se probó en el mock

---

## Checklist de implementación sugerida

- [ ] Registrar fuentes Inter + JetBrains Mono
- [ ] Extender tokens de Color con la paleta nueva
- [ ] Agregar `PetTone` al modelo `Pet`
- [ ] Construir átomos: `StatusPill`, `Monogram`, `MiniTimeline`, `DeltaBadge`
- [ ] Construir `KpiCard`, `RegRow`, `MiniStat`
- [ ] Implementar `PetsListView` con los 3 estados (empty / dashboard / grid)
- [ ] Implementar swipe actions
- [ ] Implementar `PetDetailView` shell con `TabPicker`
- [ ] Tab Próximos
- [ ] Tab Vacunas con `SeriesCard`
- [ ] Tab Peso con `WeightChart` + sheet
- [ ] Tab Parásitos con `ParasiteProtocolCard` + `AdherenceDots`
- [ ] QA visual contra el HTML mock
