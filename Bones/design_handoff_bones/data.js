// Mock pet data shared across both variants.
// Each pet has identity (name, species, breed, age) + health snapshot
// (peso actual + delta, próxima vacuna, próxima desparasitación, last events).
// Color is the per-pet identity tone.

window.PETS = [
  {
    id: 'marcos',
    name: 'Marcos',
    species: 'Perro',
    breed: 'Husky',
    sex: 'M',
    age: '3 años, 4 meses',
    birth: 'Ene 2022',
    color: 'Blanco',
    photo: 'marcos',
    // health
    status: 'ok', // 'ok' | 'soon' | 'overdue'
    statusLabel: 'Al día',
    weight: { value: 22.4, unit: 'kg', delta: '+0.3', deltaDir: 'up', when: 'hace 5 días' },
    nextVaccine: { name: 'Polivalente (3/3)', date: '14 Jun', in: 'en 9 días', overdue: false },
    nextDeworming: { name: 'Pipeta mensual', date: '02 Jun', in: 'mañana', overdue: false },
    lastVaccine: { name: 'Rabia', date: '08 Mar' },
    lastDeworming: { name: 'Tableta', date: '02 May' },
    // palette
    tone: { ink: '#3D5A4A', soft: '#E8EDE6', hue: '#7A9988' }, // forest
  },
  {
    id: 'mishi',
    name: 'Mishi',
    species: 'Gato',
    breed: 'Siamés',
    sex: 'F',
    age: '7 años',
    birth: 'May 2018',
    color: 'Atigrado',
    photo: 'mishi',
    status: 'soon',
    statusLabel: 'Próximo',
    weight: { value: 4.1, unit: 'kg', delta: '-0.1', deltaDir: 'down', when: 'hace 2 sem.' },
    nextVaccine: { name: 'Triple felina', date: '28 May', in: 'pasado mañana', overdue: false },
    nextDeworming: { name: 'Antiparasitario', date: '26 May', in: 'hoy', overdue: false },
    lastVaccine: { name: 'Leucemia', date: '12 Feb' },
    lastDeworming: { name: 'Pipeta', date: '20 Abr' },
    tone: { ink: '#8B4A2E', soft: '#F2E6DC', hue: '#C57A52' }, // terracotta
  },
  {
    id: 'kira',
    name: 'Kira',
    species: 'Perro',
    breed: 'Pastor',
    sex: 'F',
    age: '5 años',
    birth: 'Sep 2020',
    color: 'Negro',
    photo: 'kira',
    status: 'overdue',
    statusLabel: 'Vencida',
    weight: { value: 28.7, unit: 'kg', delta: '+1.2', deltaDir: 'up', when: 'ayer' },
    nextVaccine: { name: 'Refuerzo anual', date: '18 May', in: 'hace 8 días', overdue: true },
    nextDeworming: { name: 'Mensual', date: '01 Jun', in: 'en 7 días', overdue: false },
    lastVaccine: { name: 'Moquillo', date: '10 Ene' },
    lastDeworming: { name: 'Pipeta', date: '01 May' },
    tone: { ink: '#3C4A6B', soft: '#E4E8EF', hue: '#6E84A8' }, // slate blue
  },
  {
    id: 'simba',
    name: 'Simba',
    species: 'Gato',
    breed: 'Persa',
    sex: 'M',
    age: '2 años',
    birth: 'Abr 2023',
    color: 'Crema',
    photo: 'simba',
    status: 'ok',
    statusLabel: 'Al día',
    weight: { value: 5.2, unit: 'kg', delta: '+0.0', deltaDir: 'flat', when: 'hace 1 sem.' },
    nextVaccine: { name: 'Refuerzo', date: '20 Jul', in: 'en 56 días', overdue: false },
    nextDeworming: { name: 'Pipeta', date: '08 Jun', in: 'en 14 días', overdue: false },
    lastVaccine: { name: 'Triple felina', date: '12 Abr' },
    lastDeworming: { name: 'Pipeta', date: '08 May' },
    tone: { ink: '#8A6E1F', soft: '#F1ECD8', hue: '#BFA13E' }, // ochre
  },
  {
    id: 'toby',
    name: 'Toby',
    species: 'Perro',
    breed: 'Beagle',
    sex: 'M',
    age: '8 años',
    birth: 'Mar 2017',
    color: 'Tricolor',
    photo: 'toby',
    status: 'soon',
    statusLabel: 'Próximo',
    weight: { value: 14.8, unit: 'kg', delta: '-0.2', deltaDir: 'down', when: 'hace 3 días' },
    nextVaccine: { name: 'Anual', date: '03 Jun', in: 'en 8 días', overdue: false },
    nextDeworming: { name: 'Tableta', date: '27 May', in: 'mañana', overdue: false },
    lastVaccine: { name: 'Parvo', date: '03 Jun (2024)' },
    lastDeworming: { name: 'Tableta', date: '27 Abr' },
    tone: { ink: '#5C3D6E', soft: '#ECE3F1', hue: '#9272A6' }, // plum
  },
  {
    id: 'nala',
    name: 'Nala',
    species: 'Perro',
    breed: 'Labrador',
    sex: 'F',
    age: '1 año, 6 meses',
    birth: 'Dic 2023',
    color: 'Dorado',
    photo: 'nala',
    status: 'ok',
    statusLabel: 'Al día',
    weight: { value: 19.5, unit: 'kg', delta: '+0.5', deltaDir: 'up', when: 'hace 4 días' },
    nextVaccine: { name: 'Refuerzo', date: '15 Jun', in: 'en 21 días', overdue: false },
    nextDeworming: { name: 'Pipeta', date: '10 Jun', in: 'en 16 días', overdue: false },
    lastVaccine: { name: 'Rabia', date: '15 Mar' },
    lastDeworming: { name: 'Pipeta', date: '10 May' },
    tone: { ink: '#7A5230', soft: '#F1E6D8', hue: '#B8895A' }, // caramel
  },
];

// Helper to slice for different states
window.petsFor = (n) => window.PETS.slice(0, n);
