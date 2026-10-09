/* global React */
// Custom icon set for Bones (no SF Symbols).
// All icons are 24×24 viewBox, accept size + stroke + color.
// Two stylistic flavors via the `weight` prop:
//   "fine"   → 1.4px hairline, organic (Historia Clínica)
//   "solid"  → 1.7px + filled accents (Vet Pro)

const _icon = (paths, { size = 20, color = 'currentColor', stroke = 1.4, fill = 'none' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    {paths({ color, stroke, fill })}
  </svg>
);

// ── Vaccine — a syringe at 45° ─────────────────────────────
const Syringe = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <path d="M14.5 3.5l6 6" />
    <path d="M17 6l-9.5 9.5a2 2 0 01-1.4.6H4v-2.1c0-.5.2-1 .6-1.4L14 3.2" />
    <path d="M3 21l3-3" />
    <path d="M11 7l6 6" />
    <path d="M8 10l2 2" />
    <path d="M14 4l-2 2" />
  </g>
), p);

// ── Deworming — leaf-shaped drop with bug dot ──────────────
const Drop = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <path d="M12 3c-3.5 4.5-5.5 7-5.5 10a5.5 5.5 0 0011 0c0-3-2-5.5-5.5-10z" />
    <path d="M10 13.5c0.7 0.7 2.3 0.7 3 0" />
  </g>
), p);

// ── Scale — vet scale with subtle dish ─────────────────────
const Scale = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <path d="M4.5 19h15" />
    <rect x="6" y="6" width="12" height="13" rx="1.5" />
    <path d="M9 6V4.5A1.5 1.5 0 0110.5 3h3A1.5 1.5 0 0115 4.5V6" />
    <path d="M9 11h6" />
    <circle cx="12" cy="14.5" r="2" />
  </g>
), p);

// ── Paw — soft pads, no slop ───────────────────────────────
const Paw = (p) => _icon(({ color, stroke, fill }) => (
  <g stroke={color} strokeWidth={stroke} fill={fill === 'solid' ? color : 'none'} strokeLinecap="round" strokeLinejoin="round">
    <ellipse cx="6.5" cy="10" rx="1.8" ry="2.3" />
    <ellipse cx="17.5" cy="10" rx="1.8" ry="2.3" />
    <ellipse cx="9.5" cy="6" rx="1.5" ry="2" />
    <ellipse cx="14.5" cy="6" rx="1.5" ry="2" />
    <path d="M12 12c-3 0-5 2.2-5 4.5C7 18.4 8.3 19 10 19c.8 0 1.3-.3 2-.3s1.2.3 2 .3c1.7 0 3-.6 3-2.5 0-2.3-2-4.5-5-4.5z" />
  </g>
), p);

// ── Calendar — clinical, hairline ──────────────────────────
const Calendar = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <rect x="3.5" y="5" width="17" height="15.5" rx="2" />
    <path d="M3.5 10h17" />
    <path d="M8 3v4M16 3v4" />
    <circle cx="12" cy="15" r="0.8" fill={color} stroke="none" />
  </g>
), p);

// ── Plus — for add ─────────────────────────────────────────
const Plus = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke + 0.3} strokeLinecap="round">
    <path d="M12 5v14M5 12h14" />
  </g>
), p);

// ── Search ─────────────────────────────────────────────────
const Search = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" fill="none">
    <circle cx="11" cy="11" r="6" />
    <path d="M15.5 15.5L20 20" />
  </g>
), p);

// ── Chevron right ──────────────────────────────────────────
const ChevronRight = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <path d="M9 5l7 7-7 7" />
  </g>
), p);

// ── Arrow up/down for weight delta ─────────────────────────
const ArrowUp = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <path d="M12 19V5M6 11l6-6 6 6" />
  </g>
), p);
const ArrowDown = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <path d="M12 5v14M6 13l6 6 6-6" />
  </g>
), p);
const Dash = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke + 0.3} strokeLinecap="round"><path d="M5 12h14" /></g>
), p);

// ── Tabbar icons ───────────────────────────────────────────
const PawTab = (p) => Paw(p);
const CalTab = (p) => Calendar(p);
const Gear = (p) => _icon(({ color, stroke }) => (
  <g stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" fill="none">
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.7 1.7 0 00.3 1.9l.1.1a2 2 0 11-2.9 2.9l-.1-.1a1.7 1.7 0 00-1.9-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1-1.5 1.7 1.7 0 00-1.9.3l-.1.1a2 2 0 11-2.9-2.9l.1-.1a1.7 1.7 0 00.3-1.9 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1 1.7 1.7 0 00-.3-1.9l-.1-.1a2 2 0 112.9-2.9l.1.1a1.7 1.7 0 001.9.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.9-.3l.1-.1a2 2 0 112.9 2.9l-.1.1a1.7 1.7 0 00-.3 1.9V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z" />
  </g>
), p);

// ── Status dot — semantic ──────────────────────────────────
const StatusDot = ({ status = 'ok', size = 8, ring = false }) => {
  const colors = { ok: '#3D8A5A', soon: '#C99A2C', overdue: '#B0413E' };
  const c = colors[status] || colors.ok;
  return (
    <span style={{
      display: 'inline-block', width: size, height: size, borderRadius: 999,
      background: c,
      boxShadow: ring ? `0 0 0 3px ${c}22` : 'none',
      verticalAlign: 'middle',
    }} />
  );
};

// ── PetAvatar — silhouette placeholder (no real photo asset) ──
// Uses pet.species + pet.tone to draw a subtle illustrated portrait card.
const PetAvatar = ({ pet, size = 56, square = false, frame = false }) => {
  const isCat = pet.species === 'Gato';
  const bg = pet.tone.soft;
  const ink = pet.tone.ink;
  const radius = square ? 8 : '50%';
  return (
    <div style={{
      width: size, height: size, borderRadius: radius, background: bg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      overflow: 'hidden', position: 'relative',
      boxShadow: frame ? `inset 0 0 0 1px ${ink}22` : 'none',
      flexShrink: 0,
    }}>
      {isCat ? (
        <svg viewBox="0 0 64 64" width={size * 0.78} height={size * 0.78}>
          {/* cat */}
          <path d="M14 26 L18 12 L26 22 Q32 19 38 22 L46 12 L50 26 Q54 34 50 44 Q46 54 32 54 Q18 54 14 44 Q10 34 14 26 Z"
                fill={ink} opacity="0.85" />
          <circle cx="26" cy="34" r="2" fill={bg} />
          <circle cx="38" cy="34" r="2" fill={bg} />
          <path d="M30 41 Q32 43 34 41" stroke={bg} strokeWidth="1.4" fill="none" strokeLinecap="round" />
          <path d="M22 41 L18 42 M22 43 L18 44 M42 41 L46 42 M42 43 L46 44"
                stroke={bg} strokeWidth="0.8" strokeLinecap="round" opacity="0.7" />
        </svg>
      ) : (
        <svg viewBox="0 0 64 64" width={size * 0.82} height={size * 0.82}>
          {/* dog */}
          <path d="M18 22 Q16 12 22 12 Q26 12 26 18 L26 24 Q32 21 38 24 L38 18 Q38 12 42 12 Q48 12 46 22 Q52 28 50 40 Q48 54 32 54 Q16 54 14 40 Q12 28 18 22 Z"
                fill={ink} opacity="0.85" />
          <circle cx="26" cy="36" r="2" fill={bg} />
          <circle cx="38" cy="36" r="2" fill={bg} />
          <ellipse cx="32" cy="44" rx="3" ry="2.2" fill={bg} />
          <path d="M32 46 Q32 49 30 50 M32 46 Q32 49 34 50" stroke={bg} strokeWidth="1.2" fill="none" strokeLinecap="round" />
        </svg>
      )}
    </div>
  );
};

window.BonesIcons = {
  Syringe, Drop, Scale, Paw, Calendar, Plus, Search, ChevronRight,
  ArrowUp, ArrowDown, Dash, PawTab, CalTab, Gear, StatusDot, PetAvatar,
};
