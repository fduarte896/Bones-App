/* global React, BonesIcons */
// PetDetailView — Variant B (Vet Pro)
// 4 tabs: Próximos / Vacunas / Parásitos / Peso
// Header: large monogram + name + meta. Edit + add-event toolbar.
// Tabs: segmented pill. Each tab is its own scrollable surface.
// Built to share visual DNA with the PetsListView Variant B.

const PDB = {
  bg: '#F6F6F4',
  panel: '#FFFFFF',
  ink: '#13161A',
  inkSoft: '#5C636E',
  inkFaint: '#9CA3AF',
  rule: '#ECEDEF',
  ruleSoft: '#F4F4F2',
  accent: '#0E5C4F',
  ok: '#3D8A5A',
  soon: '#C99A2C',
  overdue: '#B0413E',
  weightTone: '#3C4A6B',
  sans: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", "IBM Plex Mono", ui-monospace, Menlo, monospace',
};

const { Syringe, Drop, Scale, Paw, Calendar, Plus, ChevronRight,
        ArrowUp, ArrowDown, Dash } = BonesIcons;

// ─────────────────────────────────────────────────────────────
// Shared atoms
// ─────────────────────────────────────────────────────────────

const StatusPillD = ({ status, label }) => {
  const colorMap = { ok: PDB.ok, soon: PDB.soon, overdue: PDB.overdue };
  const c = colorMap[status] || PDB.ok;
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '4px 10px 4px 8px', background: `${c}14`,
      borderRadius: 999, fontFamily: PDB.sans, fontSize: 11,
      color: c, fontWeight: 500, letterSpacing: '0.01em',
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 999, background: c }} />
      {label}
    </div>
  );
};

const MonogramD = ({ pet, size = 88, radius = 22 }) => (
  <div style={{
    width: size, height: size, borderRadius: radius,
    background: pet.tone.hue, color: '#fff',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: PDB.sans, fontWeight: 600, fontSize: size * 0.4,
    letterSpacing: '-0.02em', flexShrink: 0,
    boxShadow: `inset 0 0 0 1px rgba(0,0,0,.04), 0 1px 0 ${pet.tone.hue}33`,
    position: 'relative', overflow: 'hidden',
  }}>
    <div style={{ position: 'absolute', inset: 0, opacity: 0.13, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Paw size={size * 0.85} color="#fff" stroke={1.8} />
    </div>
    <span style={{ position: 'relative', zIndex: 1 }}>{pet.name[0]}</span>
  </div>
);

const Chip = ({ label, value, tint = PDB.inkSoft, mono = false, bg = null }) => (
  <span style={{
    display: 'inline-flex', alignItems: 'baseline', gap: 4,
    padding: '3px 8px', borderRadius: 999,
    background: bg !== null ? bg : `${tint}12`,
    fontSize: 10.5, color: tint, fontWeight: 500,
    letterSpacing: '0.01em', whiteSpace: 'nowrap',
  }}>
    <span style={{ opacity: 0.75 }}>{label}</span>
    {value && (
      <span style={{
        fontFamily: mono ? PDB.mono : PDB.sans, fontWeight: 600,
        fontVariantNumeric: 'tabular-nums',
      }}>{value}</span>
    )}
  </span>
);

// ─────────────────────────────────────────────────────────────
// Top chrome — nav + header + tabs
// ─────────────────────────────────────────────────────────────

function NavBarBack({ title }) {
  return (
    <div style={{ padding: '8px 16px 8px', background: PDB.bg, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <button style={{ ...iconBtnD, width: 'auto', padding: '0 12px 0 8px', gap: 4 }}>
        <span style={{ display: 'inline-flex', transform: 'rotate(180deg)' }}>
          <ChevronRight size={16} color={PDB.ink} stroke={1.9} />
        </span>
        <span style={{ fontSize: 13, color: PDB.ink, fontWeight: 500 }}>Mascotas</span>
      </button>
      <div style={{ fontFamily: PDB.sans, fontSize: 14, color: PDB.ink, fontWeight: 600 }}>{title}</div>
      <div style={{ display: 'flex', gap: 6 }}>
        <button style={iconBtnD} aria-label="Editar">
          <Pencil size={15} color={PDB.ink} stroke={1.7} />
        </button>
        <button style={{ ...iconBtnD, background: PDB.ink, borderColor: PDB.ink }}>
          <Plus size={15} color={PDB.panel} stroke={1.9} />
        </button>
      </div>
    </div>
  );
}

const iconBtnD = {
  height: 34, minWidth: 34, borderRadius: 10, border: `1px solid ${PDB.rule}`,
  background: PDB.panel, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  cursor: 'pointer', padding: 0, fontFamily: PDB.sans,
};

// Pencil icon (local)
const Pencil = ({ size = 16, color = PDB.ink, stroke = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 4l6 6L8 22H2v-6L14 4z" />
      <path d="M13 5l6 6" />
    </g>
  </svg>
);

function PetHeader({ pet }) {
  return (
    <div style={{
      padding: '6px 20px 18px', background: PDB.bg,
      borderBottom: `1px solid ${PDB.rule}`,
    }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}>
        <MonogramD pet={pet} size={84} radius={22} />
        <div style={{ flex: 1, minWidth: 0, paddingTop: 4 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <h1 style={{
              fontFamily: PDB.sans, fontWeight: 600, fontSize: 26,
              color: PDB.ink, margin: 0, letterSpacing: '-0.02em', lineHeight: 1,
            }}>{pet.name}</h1>
            <StatusPillD status={pet.status} label={pet.statusLabel} />
          </div>
          <div style={{
            marginTop: 8, fontFamily: PDB.sans, fontSize: 12.5,
            color: PDB.inkSoft, fontWeight: 500,
          }}>
            {pet.species} · {pet.breed} · {pet.sex === 'M' ? '♂' : '♀'}
          </div>
          <div style={{
            marginTop: 4, fontFamily: PDB.mono, fontSize: 11,
            color: PDB.inkFaint, fontVariantNumeric: 'tabular-nums',
            letterSpacing: '0.02em', display: 'flex', gap: 10,
          }}>
            <span>{pet.age}</span>
            <span style={{ color: PDB.rule }}>|</span>
            <span>Nac. {pet.birth}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function TabPicker({ active }) {
  const tabs = [
    { id: 'upcoming', label: 'Próximos' },
    { id: 'vaccines', label: 'Vacunas' },
    { id: 'parasites', label: 'Parásitos' },
    { id: 'weight', label: 'Peso' },
  ];
  return (
    <div style={{
      padding: '10px 16px 14px', background: PDB.bg,
      display: 'flex', gap: 6,
      borderBottom: `1px solid ${PDB.rule}`,
    }}>
      {tabs.map(t => {
        const on = t.id === active;
        return (
          <div key={t.id} style={{
            flex: 1, height: 32, borderRadius: 9,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: on ? PDB.ink : 'transparent',
            border: on ? 'none' : `1px solid ${PDB.rule}`,
            fontFamily: PDB.sans, fontSize: 12.5, fontWeight: on ? 600 : 500,
            color: on ? PDB.panel : PDB.inkSoft, letterSpacing: '-0.005em',
          }}>{t.label}</div>
        );
      })}
    </div>
  );
}

function PageShell({ pet, activeTab, children }) {
  return (
    <div style={{
      background: PDB.bg, height: '100%', position: 'relative',
      paddingTop: 54, fontFamily: PDB.sans, overflow: 'hidden',
    }}>
      <NavBarBack title="" />
      <PetHeader pet={pet} />
      <TabPicker active={activeTab} />
      <div style={{ flex: 1, overflowY: 'auto', maxHeight: 'calc(100% - 54px - 138px - 60px - 34px)', padding: '14px 16px 32px' }}>
        {children}
      </div>
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: PDB.panel, borderTop: `1px solid ${PDB.rule}`,
        height: 34, paddingBottom: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{ width: 134, height: 5, borderRadius: 99, background: PDB.ink, opacity: 0.85 }} />
      </div>
    </div>
  );
}

function SectionHeadD({ label, count }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      margin: '4px 4px 8px',
    }}>
      <h3 style={{
        fontFamily: PDB.sans, fontWeight: 600, fontSize: 11.5,
        color: PDB.inkSoft, margin: 0,
        letterSpacing: '0.06em', textTransform: 'uppercase',
      }}>{label}</h3>
      {count !== undefined && (
        <span style={{
          fontFamily: PDB.mono, fontSize: 10.5, color: PDB.inkFaint,
          fontVariantNumeric: 'tabular-nums',
        }}>{String(count).padStart(2, '0')}</span>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// TAB · PRÓXIMOS
// ─────────────────────────────────────────────────────────────

function EventRow({ kind, name, dose, date, time, badge, badgeColor, overdue = false, hideRule = false }) {
  const iconMap = {
    vaccine: { Icon: Syringe, c: PDB.ok },
    deworming: { Icon: Drop, c: PDB.soon },
    weight: { Icon: Scale, c: PDB.weightTone },
  };
  const { Icon, c } = iconMap[kind];
  return (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '12px 14px', gap: 12,
      borderBottom: hideRule ? 'none' : `1px solid ${PDB.ruleSoft}`,
    }}>
      <div style={{
        width: 32, height: 32, borderRadius: 10, background: `${c}15`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        <Icon size={16} color={c} stroke={1.7} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 14, color: PDB.ink, fontWeight: 500,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>{name}</div>
        <div style={{ marginTop: 3, display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
          {dose && (
            <span style={{
              fontFamily: PDB.mono, fontSize: 10, color: PDB.inkSoft,
              background: PDB.bg, padding: '2px 6px', borderRadius: 5,
              fontVariantNumeric: 'tabular-nums',
            }}>{dose}</span>
          )}
          <span style={{ fontFamily: PDB.mono, fontSize: 11, color: PDB.inkFaint, fontVariantNumeric: 'tabular-nums' }}>
            {date}
          </span>
          {overdue && (
            <span style={{
              fontSize: 10, color: PDB.overdue, background: `${PDB.overdue}14`,
              padding: '1px 6px', borderRadius: 5, fontWeight: 600,
              letterSpacing: '0.02em', textTransform: 'uppercase',
            }}>Vencida</span>
          )}
        </div>
      </div>
      {time ? (
        <div style={{
          fontFamily: PDB.mono, fontSize: 15, fontWeight: 600,
          color: PDB.ink, fontVariantNumeric: 'tabular-nums',
        }}>{time}</div>
      ) : badge ? (
        <span style={{
          fontFamily: PDB.sans, fontSize: 10.5, color: badgeColor || PDB.inkFaint,
          background: `${badgeColor || PDB.inkFaint}14`,
          padding: '4px 9px', borderRadius: 999, fontWeight: 600, letterSpacing: '0.01em',
        }}>{badge}</span>
      ) : null}
    </div>
  );
}

function UpcomingTab({ pet }) {
  // mock event sections shaped like CalendarSections.swift output
  const sections = [
    {
      title: 'Hoy',
      rows: [
        { kind: 'deworming', name: 'Pipeta mensual', dose: 'Dosis 5/12', date: 'hoy', time: '09:00', badgeColor: PDB.soon },
      ],
    },
    {
      title: 'Mañana',
      rows: [
        { kind: 'vaccine', name: 'Polivalente (DHPPi)', dose: 'Dosis 2/3', date: 'mañana', time: '11:30', badgeColor: PDB.ok },
      ],
    },
    {
      title: 'Esta semana',
      rows: [
        { kind: 'weight', name: 'Control de peso mensual', dose: null, date: 'jue · 29 May · 10:00', badge: 'en 4 días', badgeColor: PDB.weightTone },
        { kind: 'vaccine', name: 'Leptospirosis', dose: 'Dosis 1/2', date: 'vie · 30 May · 16:00', badge: 'en 5 días', badgeColor: PDB.ok },
      ],
    },
    {
      title: 'Más adelante',
      rows: [
        { kind: 'vaccine', name: 'Polivalente (DHPPi)', dose: 'Dosis 3/3', date: 'jun · 14 Jun', badge: 'en 20 días', badgeColor: PDB.inkFaint },
        { kind: 'deworming', name: 'Drontal Plus', dose: 'Refuerzo', date: 'ago · 14 Ago', badge: 'en 81 días', badgeColor: PDB.inkFaint },
        { kind: 'vaccine', name: 'Antirrábica', dose: 'Refuerzo anual', date: 'jun · 25 Jun', badge: 'en 31 días', badgeColor: PDB.inkFaint },
      ],
    },
  ];

  // hero "next" card
  const hero = {
    kind: 'deworming',
    name: 'Pipeta mensual',
    dose: 'Dosis 5/12',
    when: 'Hoy, 09:00',
    countdown: 'en 3 h',
  };

  return (
    <>
      {/* Hero — próxima acción */}
      <div style={{
        background: PDB.ink, color: PDB.panel, borderRadius: 16,
        padding: '14px 16px', display: 'flex', gap: 14, alignItems: 'center',
        marginBottom: 14, position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', inset: 0, opacity: 0.08,
          background: `radial-gradient(120% 80% at 100% 0%, ${PDB.soon} 0%, transparent 60%)`,
        }} />
        <div style={{
          width: 44, height: 44, borderRadius: 12,
          background: `${PDB.soon}28`, color: PDB.soon,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          position: 'relative',
        }}>
          <Drop size={20} color={PDB.soon} stroke={1.8} />
        </div>
        <div style={{ flex: 1, position: 'relative' }}>
          <div style={{ fontSize: 10.5, color: '#9CA3AF', letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 600 }}>
            Próximo evento
          </div>
          <div style={{ marginTop: 3, fontSize: 16, fontWeight: 600, letterSpacing: '-0.01em' }}>
            {hero.name}
          </div>
          <div style={{
            marginTop: 2, fontFamily: PDB.mono, fontSize: 11.5, color: '#9CA3AF',
            fontVariantNumeric: 'tabular-nums',
          }}>
            {hero.when} · {hero.dose}
          </div>
        </div>
        <div style={{
          padding: '5px 11px', background: PDB.soon, color: PDB.ink,
          borderRadius: 999, fontSize: 11, fontWeight: 700,
          fontFamily: PDB.sans, letterSpacing: '0.02em',
        }}>{hero.countdown}</div>
      </div>

      {sections.map((sec, i) => (
        <div key={i} style={{ marginBottom: 14 }}>
          <SectionHeadD label={sec.title} count={sec.rows.length} />
          <div style={{
            background: PDB.panel, border: `1px solid ${PDB.rule}`,
            borderRadius: 14, overflow: 'hidden',
          }}>
            {sec.rows.map((r, j) => (
              <EventRow key={j} {...r} hideRule={j === sec.rows.length - 1} />
            ))}
          </div>
        </div>
      ))}

      <div style={{
        marginTop: 18, padding: '11px 14px',
        background: 'transparent', border: `1px dashed ${PDB.rule}`,
        borderRadius: 12, display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ width: 26, height: 26, borderRadius: 8, background: PDB.panel, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, border: `1px solid ${PDB.rule}` }}>
          <ChevronRight size={14} color={PDB.inkSoft} stroke={1.8} />
        </div>
        <div style={{ fontSize: 12, color: PDB.inkSoft, lineHeight: 1.4 }}>
          Desliza a la izquierda para borrar, a la derecha para marcar como completado.
        </div>
      </div>
    </>
  );
}

// ─────────────────────────────────────────────────────────────
// TAB · VACUNAS
// ─────────────────────────────────────────────────────────────

function VaccineDoseRow({ status, dose, dateLong, manufacturer, completed }) {
  // status: 'next' | 'overdue' | 'future' | 'history'
  const isNext = status === 'next';
  const isOverdue = status === 'overdue';
  const isFuture = status === 'future';
  const c = isOverdue ? PDB.overdue : isNext ? PDB.ok : isFuture ? PDB.inkSoft : PDB.inkFaint;
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', padding: '10px 14px 10px 30px', gap: 10,
      position: 'relative', borderBottom: `1px solid ${PDB.ruleSoft}`,
    }}>
      {/* timeline rail */}
      <div style={{
        position: 'absolute', left: 16, top: 14,
        width: 10, height: 10, borderRadius: 999,
        background: completed ? c : PDB.panel,
        border: `1.5px solid ${c}`,
      }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: PDB.ink }}>
            {dose}
          </span>
          {isOverdue && (
            <span style={{
              fontSize: 9.5, color: PDB.overdue, background: `${PDB.overdue}14`,
              padding: '1px 6px', borderRadius: 4, fontWeight: 700,
              letterSpacing: '0.04em', textTransform: 'uppercase',
            }}>Vencida</span>
          )}
          {completed && (
            <span style={{ fontSize: 9.5, color: PDB.ok, fontWeight: 700, letterSpacing: '0.04em', textTransform: 'uppercase' }}>
              ✓ Aplicada
            </span>
          )}
        </div>
        <div style={{
          marginTop: 2, fontFamily: PDB.mono, fontSize: 11, color: PDB.inkFaint,
          fontVariantNumeric: 'tabular-nums', display: 'flex', gap: 8, alignItems: 'baseline',
        }}>
          <span>{dateLong}</span>
          {manufacturer && <span>· {manufacturer}</span>}
        </div>
      </div>
    </div>
  );
}

function SeriesCard({ series, expanded = false }) {
  const totalDoses = series.doses.length;
  const completed = series.doses.filter(d => d.completed).length;
  const nextDose = series.doses.find(d => d.status === 'next');
  const overdueCount = series.doses.filter(d => d.status === 'overdue').length;
  const futureDoses = series.doses.filter(d => d.status === 'future');
  const overdueDoses = series.doses.filter(d => d.status === 'overdue');
  const historyDoses = series.doses.filter(d => d.completed);
  const pct = completed / totalDoses;

  return (
    <div style={{
      background: PDB.panel, border: `1px solid ${PDB.rule}`,
      borderRadius: 14, overflow: 'hidden', marginBottom: 10,
    }}>
      {/* header */}
      <div style={{ padding: '14px 14px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, minWidth: 0, flex: 1 }}>
            <div style={{
              width: 30, height: 30, borderRadius: 9, background: `${PDB.ok}15`,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              marginTop: 1,
            }}>
              <Syringe size={15} color={PDB.ok} stroke={1.7} />
            </div>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{
                fontSize: 14.5, fontWeight: 600, color: PDB.ink, letterSpacing: '-0.005em',
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              }}>{series.name}</div>
              <div style={{ marginTop: 2, fontSize: 11, color: PDB.inkSoft }}>
                {series.manufacturer}
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
            <span style={{
              fontFamily: PDB.mono, fontSize: 11, color: PDB.inkFaint,
              fontVariantNumeric: 'tabular-nums', background: PDB.bg,
              padding: '2px 7px', borderRadius: 5,
            }}>{completed}/{totalDoses}</span>
            {overdueCount > 0 && (
              <span style={{
                fontSize: 10, color: PDB.overdue, fontWeight: 700,
                letterSpacing: '0.02em',
              }}>{overdueCount} vencida{overdueCount > 1 ? 's' : ''}</span>
            )}
          </div>
        </div>

        {/* progress + next */}
        <div style={{ marginTop: 12 }}>
          <div style={{
            height: 4, borderRadius: 2, background: PDB.ruleSoft,
            position: 'relative', overflow: 'hidden',
          }}>
            <div style={{
              position: 'absolute', left: 0, top: 0, bottom: 0,
              width: `${pct * 100}%`, background: PDB.ok,
            }} />
            {/* tick marks for each dose */}
            {series.doses.map((d, i) => i > 0 && (
              <div key={i} style={{
                position: 'absolute', left: `${(i / totalDoses) * 100}%`,
                top: -1, bottom: -1, width: 1.5, background: PDB.panel,
              }} />
            ))}
          </div>
          <div style={{ marginTop: 8, display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <Chip label="Próx." value={nextDose ? nextDose.dateShort : '—'} tint={nextDose && nextDose.status === 'overdue' ? PDB.overdue : PDB.inkSoft} mono />
            {series.lastCompleted && <Chip label="Últ." value={series.lastCompleted} tint={PDB.inkSoft} mono />}
            {series.boosters > 0 && <Chip label={`Refuerzo ${series.completedBoosters}/${series.boosters}`} value={null} tint={PDB.inkSoft} />}
          </div>
        </div>
      </div>

      {expanded && (
        <div style={{ borderTop: `1px solid ${PDB.ruleSoft}` }}>
          {nextDose && (
            <>
              <SectionDivider label="Próxima" />
              <VaccineDoseRow {...nextDose} />
            </>
          )}
          {overdueDoses.length > 0 && (
            <>
              <SectionDivider label="Vencidas" />
              {overdueDoses.map((d, i) => <VaccineDoseRow key={i} {...d} />)}
            </>
          )}
          {futureDoses.length > 0 && (
            <>
              <SectionDivider label="Dosis futuras" />
              {futureDoses.map((d, i) => <VaccineDoseRow key={i} {...d} />)}
            </>
          )}
          {historyDoses.length > 0 && (
            <>
              <SectionDivider label={`Historial (${historyDoses.length})`} collapsed />
            </>
          )}
        </div>
      )}
    </div>
  );
}

function SectionDivider({ label, collapsed = false }) {
  return (
    <div style={{
      padding: '8px 14px 6px', background: PDB.ruleSoft + '88',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      borderBottom: `1px solid ${PDB.ruleSoft}`,
    }}>
      <span style={{
        fontSize: 10, color: PDB.inkFaint, fontWeight: 600,
        letterSpacing: '0.08em', textTransform: 'uppercase',
      }}>{label}</span>
      {collapsed && (
        <span style={{ display: 'inline-flex', transform: 'rotate(90deg)' }}>
          <ChevronRight size={12} color={PDB.inkFaint} stroke={1.8} />
        </span>
      )}
    </div>
  );
}

function VaccinesTab({ pet }) {
  const series = [
    {
      name: 'Polivalente (DHPPi)',
      manufacturer: 'VetLabs · Lote V-2024',
      lastCompleted: '14 Mar',
      boosters: 0, completedBoosters: 0,
      doses: [
        { dose: 'Dosis 1/3', dateLong: '14 Mar 2025 · 10:00', status: 'history', completed: true, manufacturer: null },
        { dose: 'Dosis 2/3', dateLong: '26 May 2025 · 11:30', status: 'next', dateShort: 'mañana', completed: false },
        { dose: 'Dosis 3/3', dateLong: '14 Jun 2025 · 11:30', status: 'future', completed: false },
      ],
    },
    {
      name: 'Antirrábica',
      manufacturer: 'Rabivet · Anual',
      lastCompleted: '12 Jun (2024)',
      boosters: 1, completedBoosters: 1,
      doses: [
        { dose: 'Dosis inicial', dateLong: '12 Jun 2024', status: 'history', completed: true },
        { dose: 'Refuerzo anual', dateLong: '25 Jun 2025', status: 'next', dateShort: 'en 31 d', completed: false },
      ],
    },
    {
      name: 'Leptospirosis',
      manufacturer: 'BioVet',
      lastCompleted: null,
      boosters: 0, completedBoosters: 0,
      doses: [
        { dose: 'Dosis 1/2', dateLong: '18 Abr 2025 · 09:00', status: 'overdue', dateShort: 'hace 38 d', completed: false },
        { dose: 'Dosis 2/2', dateLong: '02 May 2025 · 09:00', status: 'overdue', dateShort: 'hace 24 d', completed: false },
      ],
    },
  ];

  return (
    <>
      {/* Summary strip */}
      <div style={{
        background: PDB.panel, border: `1px solid ${PDB.rule}`, borderRadius: 14,
        padding: '12px 14px', marginBottom: 14,
        display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12,
      }}>
        <SummaryStat label="Series" value="3" />
        <SummaryStat label="Dosis aplicadas" value="2" />
        <SummaryStat label="Vencidas" value="2" tint={PDB.overdue} />
      </div>

      <SectionHeadD label="Series" count={series.length} />
      {series.map((s, i) => (
        <SeriesCard key={i} series={s} expanded={i === 0} />
      ))}
    </>
  );
}

function SummaryStat({ label, value, tint = PDB.ink }) {
  return (
    <div>
      <div style={{
        fontSize: 10, color: PDB.inkFaint, fontWeight: 600,
        letterSpacing: '0.06em', textTransform: 'uppercase',
      }}>{label}</div>
      <div style={{
        marginTop: 4, fontFamily: PDB.mono, fontSize: 22, fontWeight: 600,
        color: tint, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em',
      }}>{value}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// TAB · PESO
// ─────────────────────────────────────────────────────────────

function WeightChart({ data, width = 338, height = 160 }) {
  const pad = { l: 24, r: 8, t: 12, b: 18 };
  const xs = data.map(d => d.t);
  const ys = data.map(d => d.kg);
  const minY = Math.min(...ys) - 0.3;
  const maxY = Math.max(...ys) + 0.3;
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const sx = (x) => pad.l + (width - pad.l - pad.r) * (x - minX) / (maxX - minX);
  const sy = (y) => pad.t + (height - pad.t - pad.b) * (1 - (y - minY) / (maxY - minY));

  const path = data.map((d, i) => `${i === 0 ? 'M' : 'L'} ${sx(d.t).toFixed(1)} ${sy(d.kg).toFixed(1)}`).join(' ');
  const area = `${path} L ${sx(maxX).toFixed(1)} ${(height - pad.b).toFixed(1)} L ${sx(minX).toFixed(1)} ${(height - pad.b).toFixed(1)} Z`;

  // y axis labels — min, mid, max
  const yTicks = [minY, (minY + maxY) / 2, maxY];

  // selected point (latest)
  const last = data[data.length - 1];

  return (
    <svg width={width} height={height} style={{ display: 'block' }}>
      <defs>
        <linearGradient id="weightFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={PDB.weightTone} stopOpacity="0.18" />
          <stop offset="100%" stopColor={PDB.weightTone} stopOpacity="0" />
        </linearGradient>
      </defs>
      {/* grid */}
      {yTicks.map((y, i) => (
        <g key={i}>
          <line x1={pad.l} x2={width - pad.r} y1={sy(y)} y2={sy(y)} stroke={PDB.ruleSoft} strokeWidth={1} />
          <text x={pad.l - 4} y={sy(y) + 3} textAnchor="end" fontSize="9.5" fill={PDB.inkFaint} fontFamily={PDB.mono}>
            {y.toFixed(1)}
          </text>
        </g>
      ))}
      {/* x labels — first, mid, last */}
      {[0, Math.floor(data.length / 2), data.length - 1].map((idx, i) => (
        <text key={i} x={sx(data[idx].t)} y={height - 4} textAnchor="middle" fontSize="9.5" fill={PDB.inkFaint} fontFamily={PDB.mono}>
          {data[idx].label}
        </text>
      ))}
      {/* area */}
      <path d={area} fill="url(#weightFill)" />
      {/* line */}
      <path d={path} stroke={PDB.weightTone} strokeWidth={2} fill="none" strokeLinecap="round" strokeLinejoin="round" />
      {/* dots */}
      {data.map((d, i) => (
        <circle key={i} cx={sx(d.t)} cy={sy(d.kg)} r={i === data.length - 1 ? 3.5 : 2}
          fill={i === data.length - 1 ? PDB.panel : PDB.weightTone}
          stroke={PDB.weightTone} strokeWidth={i === data.length - 1 ? 2 : 0}
        />
      ))}
      {/* callout for last */}
      <g>
        <line x1={sx(last.t)} x2={sx(last.t)} y1={pad.t} y2={sy(last.kg) - 6} stroke={PDB.weightTone} strokeDasharray="2 2" strokeWidth={1} opacity={0.5} />
      </g>
    </svg>
  );
}

function WeightTab({ pet, onAdd }) {
  // weight history — last 6 months
  const data = [
    { t: 0,  kg: 21.2, label: 'Dic' },
    { t: 1,  kg: 21.5, label: '' },
    { t: 2,  kg: 21.8, label: 'Ene' },
    { t: 3,  kg: 21.7, label: '' },
    { t: 4,  kg: 22.0, label: 'Feb' },
    { t: 5,  kg: 22.1, label: '' },
    { t: 6,  kg: 22.3, label: 'Mar' },
    { t: 7,  kg: 22.0, label: '' },
    { t: 8,  kg: 22.2, label: 'Abr' },
    { t: 9,  kg: 22.1, label: '' },
    { t: 10, kg: 22.4, label: 'May' },
  ];
  const current = data[data.length - 1].kg;
  const prev = data[data.length - 2].kg;
  const delta = (current - prev).toFixed(1);
  const dir = current > prev ? 'up' : current < prev ? 'down' : 'flat';

  const stats = {
    min: Math.min(...data.map(d => d.kg)),
    max: Math.max(...data.map(d => d.kg)),
    avg: data.reduce((s, d) => s + d.kg, 0) / data.length,
  };

  const records = [
    { date: '20 May', time: '10:00', kg: 22.4, notes: 'Control mensual' },
    { date: '02 May', time: '09:30', kg: 22.1, notes: null },
    { date: '14 Abr', time: '11:00', kg: 22.2, notes: 'Pesado en casa' },
    { date: '01 Abr', time: '10:00', kg: 22.0, notes: null },
    { date: '15 Mar', time: '09:00', kg: 22.3, notes: 'Tras vacuna' },
    { date: '01 Mar', time: '10:30', kg: 22.0, notes: null },
  ];

  return (
    <>
      {/* Current weight panel */}
      <div style={{
        background: PDB.panel, border: `1px solid ${PDB.rule}`, borderRadius: 16,
        padding: '16px 16px 14px', marginBottom: 14,
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <div>
            <div style={{
              fontSize: 10, color: PDB.inkFaint, fontWeight: 600,
              letterSpacing: '0.08em', textTransform: 'uppercase',
            }}>Peso actual</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 6 }}>
              <span style={{
                fontFamily: PDB.mono, fontSize: 36, fontWeight: 600,
                color: PDB.ink, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.03em',
              }}>{current.toFixed(1)}</span>
              <span style={{ fontSize: 14, color: PDB.inkSoft, fontWeight: 500 }}>kg</span>
              <DeltaPill dir={dir} value={`${delta > 0 ? '+' : ''}${delta}`} />
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontSize: 10, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase' }}>
              Último registro
            </div>
            <div style={{ marginTop: 6, fontFamily: PDB.mono, fontSize: 13, color: PDB.inkSoft, fontVariantNumeric: 'tabular-nums' }}>
              hace 3 días
            </div>
            <div style={{ marginTop: 2, fontFamily: PDB.mono, fontSize: 10.5, color: PDB.inkFaint, fontVariantNumeric: 'tabular-nums' }}>
              20 May · 10:00
            </div>
          </div>
        </div>

        {/* range picker */}
        <div style={{
          marginTop: 14, display: 'flex', gap: 4,
          background: PDB.bg, padding: 3, borderRadius: 8,
        }}>
          {['1M', '3M', '6M', '1A', 'Todo'].map((r, i) => {
            const on = r === '6M';
            return (
              <div key={r} style={{
                flex: 1, padding: '5px 0', borderRadius: 6,
                background: on ? PDB.panel : 'transparent',
                fontFamily: PDB.mono, fontSize: 11, fontWeight: 600,
                color: on ? PDB.ink : PDB.inkSoft, textAlign: 'center',
                boxShadow: on ? `0 1px 2px rgba(0,0,0,0.04), 0 0 0 1px ${PDB.rule}` : 'none',
                fontVariantNumeric: 'tabular-nums',
              }}>{r}</div>
            );
          })}
        </div>

        {/* chart */}
        <div style={{ marginTop: 8, marginLeft: -4 }}>
          <WeightChart data={data} width={328} height={160} />
        </div>

        {/* KPIs */}
        <div style={{
          marginTop: 6, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
          borderTop: `1px solid ${PDB.ruleSoft}`, paddingTop: 12,
        }}>
          {[
            { label: 'Mín.', value: stats.min.toFixed(1) },
            { label: 'Prom.', value: stats.avg.toFixed(1) },
            { label: 'Máx.', value: stats.max.toFixed(1) },
          ].map((s, i) => (
            <div key={i} style={{ textAlign: i === 0 ? 'left' : i === 1 ? 'center' : 'right' }}>
              <div style={{ fontSize: 10, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase' }}>
                {s.label}
              </div>
              <div style={{
                marginTop: 3, fontFamily: PDB.mono, fontSize: 15, fontWeight: 600,
                color: PDB.ink, fontVariantNumeric: 'tabular-nums',
              }}>{s.value} <span style={{ fontSize: 11, color: PDB.inkFaint, fontWeight: 500 }}>kg</span></div>
            </div>
          ))}
        </div>
      </div>

      {/* Records list */}
      <SectionHeadD label="Registros" count={records.length} />
      <div style={{
        background: PDB.panel, border: `1px solid ${PDB.rule}`,
        borderRadius: 14, overflow: 'hidden',
      }}>
        {records.map((r, i) => (
          <WeightRow key={i} {...r} hideRule={i === records.length - 1} />
        ))}
      </div>

      {/* CTA — add weight */}
      <button onClick={onAdd} style={{
        marginTop: 14, width: '100%', padding: '14px',
        background: PDB.ink, color: PDB.panel, border: 'none', borderRadius: 12,
        fontFamily: PDB.sans, fontSize: 14, fontWeight: 600,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        cursor: 'pointer',
      }}>
        <Plus size={16} color={PDB.panel} stroke={1.9} />
        Registrar peso
      </button>
    </>
  );
}

function DeltaPill({ dir, value }) {
  const c = dir === 'up' ? PDB.ok : dir === 'down' ? PDB.overdue : PDB.inkFaint;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 2,
      padding: '3px 8px 3px 6px', background: `${c}14`, color: c,
      borderRadius: 999, fontFamily: PDB.mono, fontSize: 11.5, fontWeight: 600,
      fontVariantNumeric: 'tabular-nums',
    }}>
      {dir === 'up' && <ArrowUp size={10} color={c} stroke={2.2} />}
      {dir === 'down' && <ArrowDown size={10} color={c} stroke={2.2} />}
      {dir === 'flat' && <Dash size={10} color={c} stroke={2.2} />}
      {value} kg
    </span>
  );
}

function WeightRow({ date, time, kg, notes, hideRule }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '12px 14px', gap: 12,
      borderBottom: hideRule ? 'none' : `1px solid ${PDB.ruleSoft}`,
    }}>
      <div style={{
        width: 32, height: 32, borderRadius: 10, background: `${PDB.weightTone}14`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        <Scale size={15} color={PDB.weightTone} stroke={1.7} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: PDB.mono, fontSize: 12.5, color: PDB.ink, fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>
          {date} · <span style={{ color: PDB.inkFaint }}>{time}</span>
        </div>
        {notes && (
          <div style={{ marginTop: 2, fontSize: 11.5, color: PDB.inkSoft, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {notes}
          </div>
        )}
      </div>
      <div style={{
        fontFamily: PDB.mono, fontSize: 16, fontWeight: 600, color: PDB.ink,
        fontVariantNumeric: 'tabular-nums',
      }}>{kg.toFixed(1)} <span style={{ fontSize: 11, color: PDB.inkFaint, fontWeight: 500 }}>kg</span></div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SHEET · Registrar peso
// ─────────────────────────────────────────────────────────────

function WeightSheet({ pet }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, fontFamily: PDB.sans,
      background: 'rgba(19,22,26,0.45)',
      display: 'flex', alignItems: 'flex-end',
    }}>
      <div style={{
        background: PDB.bg, width: '100%', borderRadius: '20px 20px 0 0',
        paddingBottom: 34, overflow: 'hidden',
        boxShadow: '0 -8px 30px rgba(0,0,0,0.18)',
      }}>
        {/* grabber */}
        <div style={{ padding: '8px 0 4px', display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 38, height: 5, borderRadius: 99, background: PDB.rule }} />
        </div>
        {/* nav */}
        <div style={{
          padding: '6px 16px 14px', display: 'flex',
          alignItems: 'center', justifyContent: 'space-between',
        }}>
          <button style={{ ...iconBtnD, width: 'auto', padding: '0 12px', border: 'none', background: 'transparent' }}>
            <span style={{ fontSize: 14, color: PDB.inkSoft, fontWeight: 500 }}>Cancelar</span>
          </button>
          <div style={{ fontSize: 15, fontWeight: 600, color: PDB.ink }}>Nuevo peso</div>
          <button disabled style={{
            ...iconBtnD, width: 'auto', padding: '0 14px',
            background: PDB.ink, borderColor: PDB.ink, color: PDB.panel, opacity: 0.4,
          }}>
            <span style={{ fontSize: 14, color: PDB.panel, fontWeight: 600 }}>Guardar</span>
          </button>
        </div>

        <div style={{ padding: '0 16px' }}>
          {/* pet header */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '12px 14px', background: PDB.panel,
            border: `1px solid ${PDB.rule}`, borderRadius: 14, marginBottom: 14,
          }}>
            <MonogramD pet={pet} size={40} radius={10} />
            <div>
              <div style={{ fontSize: 14, color: PDB.ink, fontWeight: 600 }}>{pet.name}</div>
              <div style={{ fontFamily: PDB.mono, fontSize: 10.5, color: PDB.inkFaint, fontVariantNumeric: 'tabular-nums' }}>
                último: 22.1 kg · hace 23 días
              </div>
            </div>
          </div>

          {/* weight input — big */}
          <div style={{
            background: PDB.panel, border: `1px solid ${PDB.rule}`,
            borderRadius: 14, padding: '16px 18px 18px', marginBottom: 12,
          }}>
            <div style={{
              fontSize: 10, color: PDB.inkFaint, fontWeight: 600,
              letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 8,
            }}>Medición</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
              <div style={{
                flex: 1, padding: '8px 12px', background: PDB.bg,
                borderRadius: 12, border: `1.5px solid ${PDB.ink}`,
                fontFamily: PDB.mono, fontSize: 36, fontWeight: 600,
                color: PDB.ink, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em',
              }}>22.4</div>
              <div style={{
                display: 'flex', background: PDB.bg, borderRadius: 8, padding: 3, gap: 2,
              }}>
                {['kg', 'lb'].map((u, i) => {
                  const on = u === 'kg';
                  return (
                    <div key={u} style={{
                      padding: '7px 14px', borderRadius: 6,
                      background: on ? PDB.panel : 'transparent',
                      fontFamily: PDB.mono, fontSize: 12, fontWeight: 600,
                      color: on ? PDB.ink : PDB.inkSoft,
                      boxShadow: on ? `0 1px 2px rgba(0,0,0,0.04), 0 0 0 1px ${PDB.rule}` : 'none',
                    }}>{u}</div>
                  );
                })}
              </div>
            </div>
            <div style={{ marginTop: 10, fontSize: 11, color: PDB.inkFaint }}>
              Rango sugerido para perro: 0.5 – 120 kg
            </div>
          </div>

          {/* date + notes */}
          <div style={{
            background: PDB.panel, border: `1px solid ${PDB.rule}`, borderRadius: 14, overflow: 'hidden',
            marginBottom: 12,
          }}>
            <div style={{
              padding: '14px 16px', display: 'flex',
              alignItems: 'center', justifyContent: 'space-between',
              borderBottom: `1px solid ${PDB.ruleSoft}`,
            }}>
              <div style={{ fontSize: 13.5, color: PDB.ink, fontWeight: 500 }}>Fecha y hora</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Calendar size={14} color={PDB.inkSoft} stroke={1.7} />
                <span style={{ fontFamily: PDB.mono, fontSize: 12.5, color: PDB.inkSoft, fontVariantNumeric: 'tabular-nums' }}>
                  Hoy · 14:32
                </span>
              </div>
            </div>
            <div style={{ padding: '14px 16px' }}>
              <div style={{ fontSize: 13.5, color: PDB.ink, fontWeight: 500, marginBottom: 6 }}>Notas</div>
              <div style={{
                padding: '8px 0', fontSize: 12.5, color: PDB.inkFaint,
                fontStyle: 'italic',
              }}>Control mensual · pesado en casa…</div>
            </div>
          </div>

          {/* numeric keypad placeholder */}
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8,
            background: PDB.bg,
          }}>
            {['1','2','3','4','5','6','7','8','9','.','0','⌫'].map((k, i) => (
              <div key={i} style={{
                height: 44, background: PDB.panel,
                border: `1px solid ${PDB.rule}`, borderRadius: 10,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: PDB.mono, fontSize: 18, fontWeight: 500, color: PDB.ink,
                fontVariantNumeric: 'tabular-nums',
              }}>{k}</div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREENS — wrappers for the design canvas
// ─────────────────────────────────────────────────────────────
// PARÁSITOS TAB
// Modelo: "Protocolo" recurrente (no serie finita).
// Cada protocolo tiene tipo (interno / externo), cadencia, próximo, último,
// y una mini-grilla de adherencia (últimos 6 meses).
// ─────────────────────────────────────────────────────────────

function AdherenceDots({ history }) {
  // history: array de 6 entries (más antiguo → más reciente)
  // entry: 'done' | 'missed' | 'pending' | 'na'
  const map = {
    done:    { bg: PDB.ok,      ring: false, fill: true  },
    missed:  { bg: PDB.overdue, ring: false, fill: true  },
    pending: { bg: PDB.soon,    ring: true,  fill: false },
    na:      { bg: PDB.rule,    ring: false, fill: true  },
  };
  return (
    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
      {history.map((h, i) => {
        const s = map[h] || map.na;
        return (
          <div key={i} style={{
            width: 8, height: 8, borderRadius: 999,
            background: s.fill ? s.bg : 'transparent',
            border: s.ring ? `1.5px solid ${s.bg}` : 'none',
          }} />
        );
      })}
    </div>
  );
}

function ParasiteProtocolCard({ protocol }) {
  // protocol: { name, kind: 'internal'|'external', product, cadenceLabel, cadenceDays,
  //   next: {dateShort, in, overdue}, last: {dateShort, agoLabel}, history: [...], status }
  const isInternal = protocol.kind === 'internal';
  const tint = isInternal ? PDB.soon : '#7A5230'; // ámbar para internos, marrón para externos
  const Icon = isInternal ? Drop : Paw;
  const statusMap = { ok: PDB.ok, soon: PDB.soon, overdue: PDB.overdue };
  const statusColor = statusMap[protocol.status] || PDB.ok;

  return (
    <div style={{
      background: PDB.panel, border: `1px solid ${PDB.rule}`,
      borderRadius: 14, overflow: 'hidden', marginBottom: 10,
    }}>
      {/* header */}
      <div style={{ padding: '14px 14px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, minWidth: 0, flex: 1 }}>
            <div style={{
              width: 30, height: 30, borderRadius: 9, background: `${tint}15`,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              marginTop: 1,
            }}>
              <Icon size={15} color={tint} stroke={1.7} />
            </div>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{
                  fontSize: 14.5, fontWeight: 600, color: PDB.ink, letterSpacing: '-0.005em',
                }}>{protocol.name}</div>
                <span style={{
                  fontSize: 9.5, color: tint, background: `${tint}14`,
                  padding: '2px 6px', borderRadius: 4, fontWeight: 700,
                  letterSpacing: '0.06em', textTransform: 'uppercase',
                }}>
                  {isInternal ? 'Interno' : 'Externo'}
                </span>
              </div>
              <div style={{ marginTop: 2, fontSize: 11, color: PDB.inkSoft }}>
                {protocol.product}
              </div>
            </div>
          </div>
          <StatusPillD status={protocol.status} label={protocol.statusLabel} />
        </div>

        {/* cadence + next/last row */}
        <div style={{
          marginTop: 12, padding: '10px 12px',
          background: PDB.bg, borderRadius: 10,
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 9.5, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              Cadencia
            </div>
            <div style={{ marginTop: 2, fontFamily: PDB.sans, fontSize: 13, color: PDB.ink, fontWeight: 600 }}>
              {protocol.cadenceLabel}
            </div>
          </div>
          <div style={{ width: 1, alignSelf: 'stretch', background: PDB.rule }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 9.5, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              Próxima
            </div>
            <div style={{
              marginTop: 2, fontFamily: PDB.mono, fontSize: 13, fontWeight: 600,
              color: protocol.next.overdue ? PDB.overdue : PDB.ink,
              fontVariantNumeric: 'tabular-nums',
            }}>{protocol.next.dateShort}</div>
            <div style={{ fontSize: 10.5, color: protocol.next.overdue ? PDB.overdue : PDB.inkSoft, marginTop: 1 }}>
              {protocol.next.in}
            </div>
          </div>
          <div style={{ width: 1, alignSelf: 'stretch', background: PDB.rule }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 9.5, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              Última
            </div>
            <div style={{
              marginTop: 2, fontFamily: PDB.mono, fontSize: 13, fontWeight: 600,
              color: PDB.inkSoft, fontVariantNumeric: 'tabular-nums',
            }}>{protocol.last.dateShort}</div>
            <div style={{ fontSize: 10.5, color: PDB.inkFaint, marginTop: 1 }}>
              {protocol.last.agoLabel}
            </div>
          </div>
        </div>

        {/* adherence */}
        <div style={{
          marginTop: 12, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div>
            <div style={{ fontSize: 9.5, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              Adherencia · 6 meses
            </div>
            <div style={{ marginTop: 6 }}>
              <AdherenceDots history={protocol.history} />
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{
              fontFamily: PDB.mono, fontSize: 16, fontWeight: 600, color: PDB.ink,
              fontVariantNumeric: 'tabular-nums',
            }}>
              {protocol.adherencePct}<span style={{ fontSize: 11, color: PDB.inkFaint }}>%</span>
            </div>
            <div style={{ fontSize: 10, color: PDB.inkFaint, fontWeight: 500, marginTop: -2 }}>
              {protocol.history.filter(h => h === 'done').length}/{protocol.history.filter(h => h !== 'na').length} dosis
            </div>
          </div>
        </div>
      </div>

      {/* footer action */}
      <div style={{
        borderTop: `1px solid ${PDB.ruleSoft}`,
        padding: '10px 14px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          background: 'transparent', border: 'none', cursor: 'pointer',
          fontSize: 12, fontWeight: 600, color: PDB.ink, padding: 0,
          fontFamily: PDB.sans,
        }}>
          <Plus size={13} color={PDB.ink} stroke={2} />
          Registrar aplicación
        </button>
        <ChevronRight size={14} color={PDB.inkFaint} stroke={1.7} />
      </div>
    </div>
  );
}

function ParasitesTab({ pet }) {
  const protocols = [
    {
      name: 'Pipeta antipulgas',
      kind: 'external',
      product: 'Frontline Plus · Tópico',
      cadenceLabel: 'Mensual',
      cadenceDays: 30,
      status: 'soon',
      statusLabel: 'Mañana',
      next:  { dateShort: '02 Jun', in: 'en 1 día', overdue: false },
      last:  { dateShort: '02 May', agoLabel: 'hace 23 d' },
      history: ['done','done','done','done','done','pending'],
      adherencePct: 100,
    },
    {
      name: 'Desparasitación oral',
      kind: 'internal',
      product: 'Drontal · Tableta amplio espectro',
      cadenceLabel: 'Cada 3 meses',
      cadenceDays: 90,
      status: 'ok',
      statusLabel: 'Al día',
      next:  { dateShort: '12 Jul', in: 'en 41 d', overdue: false },
      last:  { dateShort: '12 Abr', agoLabel: 'hace 43 d' },
      history: ['na','done','na','na','done','na'],
      adherencePct: 100,
    },
    {
      name: 'Collar antiparasitario',
      kind: 'external',
      product: 'Seresto · 8 meses',
      cadenceLabel: 'Cada 8 meses',
      cadenceDays: 240,
      status: 'overdue',
      statusLabel: 'Vencido',
      next:  { dateShort: '10 May', in: 'hace 15 d', overdue: true },
      last:  { dateShort: '10 Sep (2024)', agoLabel: 'hace 8 m' },
      history: ['done','na','na','na','na','missed'],
      adherencePct: 50,
    },
  ];

  // Summary header — adherencia global
  const allDoses = protocols.flatMap(p => p.history);
  const total = allDoses.filter(d => d !== 'na').length;
  const done = allDoses.filter(d => d === 'done').length;
  const overall = total > 0 ? Math.round((done / total) * 100) : 0;
  const activeCount = protocols.length;
  const overdueCount = protocols.filter(p => p.status === 'overdue').length;

  return (
    <div style={{ padding: '14px 16px 24px' }}>
      {/* Summary strip */}
      <div style={{
        background: PDB.panel, border: `1px solid ${PDB.rule}`,
        borderRadius: 14, padding: '14px 14px',
        display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14,
      }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 9.5, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            Protocolos activos
          </div>
          <div style={{ marginTop: 3, display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span style={{ fontFamily: PDB.mono, fontSize: 22, fontWeight: 600, color: PDB.ink, fontVariantNumeric: 'tabular-nums' }}>
              {activeCount}
            </span>
            {overdueCount > 0 && (
              <span style={{ fontSize: 10.5, color: PDB.overdue, fontWeight: 600 }}>
                · {overdueCount} vencido
              </span>
            )}
          </div>
        </div>
        <div style={{ width: 1, alignSelf: 'stretch', background: PDB.rule, marginRight: 4 }} />
        <div style={{ flex: 1.4 }}>
          <div style={{ fontSize: 9.5, color: PDB.inkFaint, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            Adherencia · 6 m
          </div>
          <div style={{ marginTop: 3, display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontFamily: PDB.mono, fontSize: 22, fontWeight: 600, color: overall >= 80 ? PDB.ok : overall >= 50 ? PDB.soon : PDB.overdue, fontVariantNumeric: 'tabular-nums' }}>
              {overall}<span style={{ fontSize: 12, color: PDB.inkFaint }}>%</span>
            </span>
            <div style={{ flex: 1, height: 5, background: PDB.ruleSoft, borderRadius: 999, overflow: 'hidden' }}>
              <div style={{
                width: `${overall}%`, height: '100%',
                background: overall >= 80 ? PDB.ok : overall >= 50 ? PDB.soon : PDB.overdue,
              }} />
            </div>
          </div>
        </div>
      </div>

      {/* Legend */}
      <div style={{
        display: 'flex', gap: 14, alignItems: 'center', marginBottom: 12,
        fontSize: 10.5, color: PDB.inkSoft,
      }}>
        <LegendDot color={PDB.ok} label="Aplicada" />
        <LegendDot color={PDB.soon} label="Pendiente" ring />
        <LegendDot color={PDB.overdue} label="Saltada" />
        <LegendDot color={PDB.rule} label="N/A" />
      </div>

      {/* Cards */}
      {protocols.map(p => (
        <ParasiteProtocolCard key={p.name} protocol={p} />
      ))}

      {/* Add protocol CTA */}
      <button style={{
        marginTop: 4, width: '100%', padding: '14px',
        background: 'transparent', border: `1.5px dashed ${PDB.rule}`,
        borderRadius: 14, cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        fontFamily: PDB.sans, fontSize: 13, color: PDB.inkSoft, fontWeight: 500,
      }}>
        <Plus size={15} color={PDB.inkSoft} stroke={1.8} />
        Añadir protocolo
      </button>
    </div>
  );
}

function LegendDot({ color, label, ring = false }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      <div style={{
        width: 7, height: 7, borderRadius: 999,
        background: ring ? 'transparent' : color,
        border: ring ? `1.5px solid ${color}` : 'none',
      }} />
      <span>{label}</span>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────

function ScreenUpcoming({ pet }) {
  return (
    <PageShell pet={pet} activeTab="upcoming">
      <UpcomingTab pet={pet} />
    </PageShell>
  );
}

function ScreenVaccines({ pet }) {
  return (
    <PageShell pet={pet} activeTab="vaccines">
      <VaccinesTab pet={pet} />
    </PageShell>
  );
}

function ScreenParasites({ pet }) {
  return (
    <PageShell pet={pet} activeTab="parasites">
      <ParasitesTab pet={pet} />
    </PageShell>
  );
}

function ScreenWeight({ pet }) {
  return (
    <PageShell pet={pet} activeTab="weight">
      <WeightTab pet={pet} />
    </PageShell>
  );
}

function ScreenWeightSheet({ pet }) {
  return (
    <div style={{ position: 'relative', height: '100%' }}>
      <PageShell pet={pet} activeTab="weight">
        <WeightTab pet={pet} />
      </PageShell>
      <WeightSheet pet={pet} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// EXPORT
// ─────────────────────────────────────────────────────────────

window.PetDetailB = {
  Upcoming: ScreenUpcoming,
  Vaccines: ScreenVaccines,
  Parasites: ScreenParasites,
  Weight: ScreenWeight,
  WeightSheet: ScreenWeightSheet,
};
