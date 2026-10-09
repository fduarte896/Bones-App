/* global React, BonesIcons */
// Variant B — "Vet Pro"
// Modern clinical dashboard. White space, structured panels, mono numerics,
// per-pet color as a saturated identity chip. Made to feel like the screen
// in a vet's modern desktop tool — composed, scannable, calm.

const B = {
  bg: '#F6F6F4',
  panel: '#FFFFFF',
  ink: '#13161A',
  inkSoft: '#5C636E',
  inkFaint: '#9CA3AF',
  rule: '#ECEDEF',
  ruleSoft: '#F4F4F2',
  accent: '#0E5C4F', // clinical teal — used for system not pet identity
  ok: '#3D8A5A',
  soon: '#C99A2C',
  overdue: '#B0413E',
  sans: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", "IBM Plex Mono", ui-monospace, Menlo, monospace',
};

const { Syringe, Drop, Scale, Paw, Calendar, Plus, Search, ChevronRight,
        ArrowUp, ArrowDown, Dash, Gear, StatusDot, PetAvatar } = BonesIcons;

// ─── helpers ────────────────────────────────────────────────
const StatusPill = ({ status, label, mono = false }) => {
  const colorMap = { ok: B.ok, soon: B.soon, overdue: B.overdue };
  const c = colorMap[status] || B.ok;
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '4px 10px 4px 8px', background: `${c}14`,
      borderRadius: 999, fontFamily: B.sans, fontSize: 11,
      color: c, fontWeight: 500, letterSpacing: '0.01em',
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 999, background: c }} />
      {label}
    </div>
  );
};

const Monogram = ({ pet, size = 56, radius = 14 }) => (
  <div style={{
    width: size, height: size, borderRadius: radius,
    background: pet.tone.hue, color: '#fff',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: B.sans, fontWeight: 600, fontSize: size * 0.4,
    letterSpacing: '-0.02em', flexShrink: 0,
    boxShadow: `inset 0 0 0 1px rgba(0,0,0,.04), 0 1px 0 ${pet.tone.hue}33`,
    position: 'relative', overflow: 'hidden',
  }}>
    {/* Subtle silhouette of paw watermark */}
    <div style={{ position: 'absolute', inset: 0, opacity: 0.13, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Paw size={size * 0.85} color="#fff" stroke={1.8} />
    </div>
    <span style={{ position: 'relative', zIndex: 1 }}>{pet.name[0]}</span>
  </div>
);

// Tiny urgency timeline — shows next 14 days with a marker on the event day
const MiniTimeline = ({ daysOut, color, width = 70, overdue = false }) => {
  const max = 14;
  const pct = overdue ? 0 : Math.max(0, Math.min(1, daysOut / max));
  return (
    <div style={{ width, height: 4, background: B.rule, borderRadius: 2, position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${(1 - pct) * 100}%`, background: color, opacity: 0.5 }} />
      <div style={{
        position: 'absolute', left: `${(1 - pct) * 100}%`, top: -2, bottom: -2,
        width: 2, background: color, transform: 'translateX(-1px)',
      }} />
    </div>
  );
};

const daysFromLabel = (label) => {
  if (!label) return 14;
  if (label.includes('hace')) return -1;
  if (label === 'hoy') return 0;
  if (label === 'mañana') return 1;
  if (label === 'pasado mañana') return 2;
  const m = label.match(/(\d+)/);
  return m ? parseInt(m[1], 10) : 14;
};

// ─── top chrome ─────────────────────────────────────────────
function NavBar({ title = 'Mascotas', count, action }) {
  return (
    <div style={{ padding: '8px 20px 14px', background: B.bg }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <h1 style={{
            fontFamily: B.sans, fontWeight: 600, fontSize: 26,
            color: B.ink, margin: 0, letterSpacing: '-0.02em',
          }}>{title}</h1>
          {count !== undefined && (
            <span style={{
              fontFamily: B.mono, fontSize: 12, color: B.inkFaint,
              fontVariantNumeric: 'tabular-nums',
              background: B.panel, padding: '2px 8px', borderRadius: 6,
              border: `1px solid ${B.rule}`,
            }}>
              {String(count).padStart(2, '0')}
            </span>
          )}
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button style={iconBtn}><Search size={17} color={B.ink} stroke={1.7} /></button>
          <button style={{ ...iconBtn, background: B.ink, borderColor: B.ink }}>
            <Plus size={17} color={B.panel} stroke={1.9} />
          </button>
        </div>
      </div>
    </div>
  );
}

const iconBtn = {
  width: 36, height: 36, borderRadius: 11, border: `1px solid ${B.rule}`,
  background: B.panel, display: 'flex', alignItems: 'center', justifyContent: 'center',
  cursor: 'pointer', padding: 0,
};

// ─── tab bar ────────────────────────────────────────────────
function TabBar({ active = 'pets' }) {
  const tabs = [
    { id: 'pets', label: 'Mascotas', Icon: Paw },
    { id: 'events', label: 'Agenda', Icon: Calendar },
    { id: 'settings', label: 'Ajustes', Icon: Gear },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, height: 86,
      background: B.panel, borderTop: `1px solid ${B.rule}`,
      paddingTop: 10, paddingBottom: 22, paddingLeft: 20, paddingRight: 20,
      display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start',
    }}>
      {tabs.map(({ id, label, Icon }) => {
        const on = id === active;
        return (
          <div key={id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
            <Icon size={22} color={on ? B.ink : B.inkFaint} stroke={on ? 1.9 : 1.4} fill={on ? 'solid' : 'none'} />
            <div style={{ fontFamily: B.sans, fontSize: 10.5, color: on ? B.ink : B.inkFaint, fontWeight: on ? 600 : 500 }}>
              {label}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ─── EMPTY STATE ────────────────────────────────────────────
function EmptyState() {
  return (
    <div style={{ background: B.bg, height: '100%', position: 'relative', paddingTop: 54, fontFamily: B.sans }}>
      <NavBar title="Mascotas" />
      <div style={{ padding: '24px 24px 0', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{
          marginTop: 36, padding: '32px 28px', width: '100%',
          background: B.panel, border: `1px solid ${B.rule}`, borderRadius: 20,
          display: 'flex', flexDirection: 'column', alignItems: 'center',
        }}>
          {/* Stylized empty illustration: 3 stacked outline cards */}
          <div style={{ position: 'relative', width: 180, height: 140 }}>
            <div style={{
              position: 'absolute', inset: '24px 32px -8px -8px',
              background: B.bg, border: `1.5px dashed ${B.rule}`, borderRadius: 14,
              transform: 'rotate(-6deg)',
            }} />
            <div style={{
              position: 'absolute', inset: '12px 16px 4px 12px',
              background: B.panel, border: `1.5px solid ${B.rule}`, borderRadius: 14,
              transform: 'rotate(2deg)',
            }} />
            <div style={{
              position: 'absolute', inset: 0,
              background: B.panel, border: `1.5px solid ${B.ink}`, borderRadius: 14,
              padding: 16, display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 11,
                background: B.bg, border: `1.5px dashed ${B.inkFaint}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <Paw size={22} color={B.inkFaint} stroke={1.6} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div style={{ height: 8, width: '70%', background: B.rule, borderRadius: 4 }} />
                <div style={{ height: 6, width: '45%', background: B.ruleSoft, borderRadius: 3 }} />
              </div>
            </div>
          </div>

          <h2 style={{ fontFamily: B.sans, fontSize: 20, fontWeight: 600, color: B.ink, margin: '32px 0 6px', letterSpacing: '-0.01em' }}>
            Aún no hay mascotas
          </h2>
          <p style={{ fontFamily: B.sans, fontSize: 13.5, color: B.inkSoft, lineHeight: 1.55, margin: 0, textAlign: 'center', maxWidth: 240 }}>
            Crea el primer perfil para registrar vacunas, desparasitaciones y peso.
          </p>

          <button style={{
            marginTop: 22, padding: '12px 22px', background: B.ink, color: B.panel,
            border: 'none', borderRadius: 11, fontFamily: B.sans, fontSize: 14, fontWeight: 500,
            display: 'inline-flex', alignItems: 'center', gap: 8, cursor: 'pointer',
          }}>
            <Plus size={16} color={B.panel} stroke={1.9} />
            Añadir mascota
          </button>
        </div>

        {/* What you'll track */}
        <div style={{ marginTop: 20, width: '100%' }}>
          <div style={{ fontFamily: B.sans, fontSize: 11, color: B.inkFaint, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 500, marginBottom: 10 }}>
            Qué podrás registrar
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
            {[
              { Icon: Syringe, label: 'Vacunas', color: '#3D8A5A' },
              { Icon: Drop, label: 'Desparas.', color: '#C99A2C' },
              { Icon: Scale, label: 'Peso', color: '#3C4A6B' },
            ].map(({ Icon, label, color }) => (
              <div key={label} style={{
                background: B.panel, border: `1px solid ${B.rule}`, borderRadius: 12,
                padding: 12, display: 'flex', flexDirection: 'column', gap: 8,
              }}>
                <div style={{
                  width: 30, height: 30, borderRadius: 9,
                  background: `${color}14`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <Icon size={16} color={color} stroke={1.7} />
                </div>
                <div style={{ fontFamily: B.sans, fontSize: 12, color: B.ink, fontWeight: 500 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
      <TabBar />
    </div>
  );
}

// ─── 1 PET DASHBOARD ────────────────────────────────────────
function Dashboard({ pet }) {
  return (
    <div style={{ background: B.bg, height: '100%', position: 'relative', paddingTop: 54, fontFamily: B.sans, overflow: 'hidden' }}>
      <NavBar title="Resumen" />
      <div style={{ padding: '4px 20px 110px', overflowY: 'auto', maxHeight: 'calc(100% - 110px)' }}>
        {/* HERO CARD */}
        <div style={{
          background: B.panel, border: `1px solid ${B.rule}`, borderRadius: 18,
          padding: '18px 18px 16px', position: 'relative', overflow: 'hidden',
        }}>
          {/* Top band of pet hue */}
          <div style={{
            position: 'absolute', left: 0, right: 0, top: 0, height: 64,
            background: `linear-gradient(180deg, ${pet.tone.hue}1F 0%, ${pet.tone.hue}00 100%)`,
          }} />
          <div style={{ position: 'relative', display: 'flex', gap: 14, alignItems: 'flex-start' }}>
            <Monogram pet={pet} size={68} radius={16} />
            <div style={{ flex: 1, minWidth: 0, paddingTop: 2 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <h2 style={{
                  fontFamily: B.sans, fontWeight: 600, fontSize: 26,
                  color: B.ink, margin: 0, letterSpacing: '-0.02em', lineHeight: 1.1,
                }}>{pet.name}</h2>
                <StatusPill status={pet.status} label={pet.statusLabel} />
              </div>
              <div style={{ marginTop: 6, fontSize: 12.5, color: B.inkSoft, fontWeight: 500 }}>
                {pet.species} · {pet.breed} · {pet.sex === 'M' ? '♂' : '♀'}
              </div>
              <div style={{ marginTop: 2, fontSize: 12, color: B.inkFaint, fontFamily: B.mono }}>
                {pet.age}
              </div>
            </div>
          </div>
        </div>

        {/* PROXIMOS — 2 KPI cards */}
        <div style={{ marginTop: 18 }}>
          <SectionHead label="Próximos eventos" />
          <div style={{ marginTop: 10, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <KpiCard
              kind="vaccine"
              event={pet.nextVaccine}
              petHue={pet.tone.hue}
            />
            <KpiCard
              kind="deworming"
              event={pet.nextDeworming}
              petHue={pet.tone.hue}
            />
          </div>
        </div>

        {/* ESTADO — peso prominente, últimos compactos */}
        <div style={{ marginTop: 20 }}>
          <SectionHead label="Estado" />
          <div style={{ marginTop: 10, background: B.panel, border: `1px solid ${B.rule}`, borderRadius: 16 }}>
            {/* Peso panel */}
            <div style={{ padding: '16px 16px 14px', display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{
                width: 42, height: 42, borderRadius: 12, background: `${B.accent}12`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <Scale size={20} color={B.accent} stroke={1.7} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 11, color: B.inkFaint, letterSpacing: '0.04em', textTransform: 'uppercase', fontWeight: 600 }}>
                  Peso actual
                </div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 4 }}>
                  <span style={{ fontFamily: B.mono, fontSize: 24, fontWeight: 600, color: B.ink, fontVariantNumeric: 'tabular-nums' }}>
                    {pet.weight.value.toFixed(1)}
                  </span>
                  <span style={{ fontSize: 12, color: B.inkSoft }}>{pet.weight.unit}</span>
                  <DeltaBadge dir={pet.weight.deltaDir} value={pet.weight.delta} />
                </div>
              </div>
              <div style={{ fontFamily: B.sans, fontSize: 11, color: B.inkFaint, textAlign: 'right' }}>
                {pet.weight.when}
              </div>
            </div>
            <div style={{ height: 1, background: B.ruleSoft }} />
            {/* Últimos */}
            <RegRow icon={<Syringe size={16} color={B.inkSoft} stroke={1.6} />} label="Última vacuna" value={pet.lastVaccine.name} meta={pet.lastVaccine.date} />
            <div style={{ height: 1, background: B.ruleSoft, marginLeft: 46 }} />
            <RegRow icon={<Drop size={16} color={B.inkSoft} stroke={1.6} />} label="Última desparasitación" value={pet.lastDeworming.name} meta={pet.lastDeworming.date} />
          </div>
        </div>

        {/* Quick actions hint */}
        <div style={{ marginTop: 18, padding: '11px 14px', background: B.panel, border: `1px dashed ${B.rule}`, borderRadius: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 26, height: 26, borderRadius: 8, background: B.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <ChevronRight size={14} color={B.inkSoft} stroke={1.8} />
          </div>
          <div style={{ fontSize: 12, color: B.inkSoft, lineHeight: 1.4 }}>
            Desliza una fila a la izquierda para registrar peso o vacuna.
          </div>
        </div>
      </div>
      <TabBar />
    </div>
  );
}

function SectionHead({ label }) {
  return (
    <h3 style={{
      fontFamily: B.sans, fontWeight: 600, fontSize: 13,
      color: B.inkSoft, margin: 0,
      letterSpacing: '0.04em', textTransform: 'uppercase',
    }}>{label}</h3>
  );
}

function KpiCard({ kind, event, petHue }) {
  const isVac = kind === 'vaccine';
  const Icon = isVac ? Syringe : Drop;
  const baseColor = event.overdue ? B.overdue : isVac ? '#3D8A5A' : '#C99A2C';
  const days = daysFromLabel(event.in);

  return (
    <div style={{
      background: B.panel, border: `1px solid ${B.rule}`, borderRadius: 14,
      padding: '12px 13px 12px', minHeight: 132,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div style={{
          width: 30, height: 30, borderRadius: 9, background: `${baseColor}15`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon size={16} color={baseColor} stroke={1.7} />
        </div>
        <span style={{
          fontFamily: B.sans, fontSize: 10, color: event.overdue ? B.overdue : B.inkFaint,
          background: event.overdue ? `${B.overdue}12` : B.bg,
          padding: '3px 8px', borderRadius: 999, fontWeight: 600, letterSpacing: '0.02em',
        }}>
          {event.in}
        </span>
      </div>
      <div>
        <div style={{ fontSize: 11, color: B.inkFaint, fontWeight: 500, letterSpacing: '0.02em', textTransform: 'uppercase' }}>
          {isVac ? 'Próx. vacuna' : 'Próx. desparas.'}
        </div>
        <div style={{
          marginTop: 4, fontFamily: B.mono, fontSize: 19, fontWeight: 600,
          color: B.ink, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.01em',
        }}>{event.date}</div>
        <div style={{ marginTop: 3, fontSize: 11.5, color: B.inkSoft, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {event.name}
        </div>
        <div style={{ marginTop: 10 }}>
          <MiniTimeline daysOut={days} color={baseColor} width="100%" overdue={event.overdue} />
        </div>
      </div>
    </div>
  );
}

function DeltaBadge({ dir, value }) {
  const c = dir === 'up' ? '#3D8A5A' : dir === 'down' ? B.overdue : B.inkFaint;
  const bg = `${c}14`;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 2,
      padding: '2px 7px 2px 5px', background: bg, color: c,
      borderRadius: 999, fontFamily: B.mono, fontSize: 11, fontWeight: 600,
    }}>
      <DeltaArrow dir={dir} color={c} />
      {value}
    </span>
  );
}
function DeltaArrow({ dir, color }) {
  if (dir === 'up') return <ArrowUp size={10} color={color} stroke={2} />;
  if (dir === 'down') return <ArrowDown size={10} color={color} stroke={2} />;
  return <Dash size={10} color={color} />;
}

function RegRow({ icon, label, value, meta }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '12px 16px', gap: 12 }}>
      <div style={{
        width: 30, height: 30, borderRadius: 9, background: B.bg,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 10.5, color: B.inkFaint, fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase' }}>{label}</div>
        <div style={{ marginTop: 2, fontSize: 13.5, color: B.ink, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{value}</div>
      </div>
      <div style={{ fontFamily: B.mono, fontSize: 11.5, color: B.inkFaint, fontVariantNumeric: 'tabular-nums', whiteSpace: 'nowrap' }}>{meta}</div>
    </div>
  );
}

// ─── GRID (2+ pets) ────────────────────────────────────────
function Grid({ pets, showSwipeHint = false }) {
  return (
    <div style={{ background: B.bg, height: '100%', position: 'relative', paddingTop: 54, fontFamily: B.sans, overflow: 'hidden' }}>
      <NavBar title="Mascotas" count={pets.length} />
      <div style={{ padding: '4px 20px 110px', overflowY: 'auto', maxHeight: 'calc(100% - 110px)' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {pets.map((pet, i) => (
            <PetCard key={pet.id} pet={pet} swipeRevealed={showSwipeHint && i === 1} />
          ))}
        </div>
      </div>
      <TabBar />
    </div>
  );
}

function PetCard({ pet, swipeRevealed = false }) {
  return (
    <div style={{ position: 'relative' }}>
      {swipeRevealed && (
        <div style={{
          position: 'absolute', top: 0, bottom: 0, right: 0,
          display: 'flex', alignItems: 'stretch', gap: 6,
        }}>
          <SwipeAction Icon={Scale} label="Peso" bg="#3C4A6B" />
          <SwipeAction Icon={Syringe} label="Vacuna" bg={pet.tone.hue} />
        </div>
      )}
      <div style={{
        background: B.panel, border: `1px solid ${B.rule}`, borderRadius: 16,
        padding: '13px 14px', position: 'relative',
        transform: swipeRevealed ? 'translateX(-138px)' : 'none',
        transition: 'transform .25s',
      }}>
        {/* header */}
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <Monogram pet={pet} size={48} radius={12} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
              <h3 style={{
                fontFamily: B.sans, fontWeight: 600, fontSize: 17,
                color: B.ink, margin: 0, letterSpacing: '-0.01em',
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              }}>{pet.name}</h3>
              <StatusPill status={pet.status} label={pet.statusLabel} />
            </div>
            <div style={{ marginTop: 2, fontSize: 11.5, color: B.inkSoft, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {pet.species} · {pet.breed} · <span style={{ fontFamily: B.mono, fontSize: 11 }}>{pet.age}</span>
            </div>
          </div>
        </div>

        {/* events strip */}
        <div style={{ marginTop: 11, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          <MiniStat
            Icon={Syringe}
            label="Vacuna"
            value={pet.nextVaccine.in}
            sub={pet.nextVaccine.date}
            color={pet.nextVaccine.overdue ? B.overdue : '#3D8A5A'}
            overdue={pet.nextVaccine.overdue}
          />
          <MiniStat
            Icon={Drop}
            label="Desparas."
            value={pet.nextDeworming.in}
            sub={pet.nextDeworming.date}
            color={pet.nextDeworming.overdue ? B.overdue : '#C99A2C'}
            overdue={pet.nextDeworming.overdue}
          />
          <MiniStat
            Icon={Scale}
            label="Peso"
            value={`${pet.weight.value} ${pet.weight.unit}`}
            sub={pet.weight.delta + ' ' + pet.weight.when.replace('hace ', '')}
            color={B.accent}
            mono
          />
        </div>
      </div>
    </div>
  );
}

function MiniStat({ Icon, label, value, sub, color, overdue = false, mono = false }) {
  return (
    <div style={{
      background: B.bg, borderRadius: 10, padding: '8px 10px',
      display: 'flex', flexDirection: 'column', gap: 4,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <Icon size={12} color={color} stroke={1.7} />
        <span style={{ fontSize: 10, color: B.inkFaint, fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase' }}>
          {label}
        </span>
      </div>
      <div style={{
        fontFamily: mono ? B.mono : B.sans, fontSize: 12.5, fontWeight: 600,
        color: overdue ? B.overdue : B.ink, fontVariantNumeric: 'tabular-nums',
        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
      }}>{value}</div>
      <div style={{ fontSize: 10, color: B.inkFaint, fontFamily: B.mono, fontVariantNumeric: 'tabular-nums', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
        {sub}
      </div>
    </div>
  );
}

function SwipeAction({ Icon, label, bg }) {
  return (
    <div style={{
      width: 64, background: bg, borderRadius: 14,
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
    }}>
      <Icon size={18} color="#fff" stroke={1.9} />
      <div style={{ fontFamily: B.sans, fontSize: 10, color: '#fff', fontWeight: 600 }}>{label}</div>
    </div>
  );
}

// ─── EXPORT ─────────────────────────────────────────────────
window.VariantB = { EmptyState, Dashboard, Grid };
