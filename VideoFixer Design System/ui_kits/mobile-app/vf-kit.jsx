/* ============================================================
   VideoFixer · Mobile-app UI kit — shared primitives (VFKit)
   Inline-styled against the design-system CSS variables.
   All exports go on window for the babel screen modules.
   ============================================================ */
const { useState, useRef, useEffect, useCallback } = React;

/* ---- Icon — Material Symbols Rounded ---------------------- */
function Icon({ name, fill = 0, size = 24, color = 'currentColor', weight = 400, style = {} }) {
  return (
    <span
      className="material-symbols-rounded"
      style={{
        fontSize: size, color, lineHeight: 1, flexShrink: 0,
        fontVariationSettings: `'FILL' ${fill}, 'wght' ${weight}, 'GRAD' 0, 'opsz' ${size > 36 ? 40 : 24}`,
        userSelect: 'none', ...style,
      }}
    >{name}</span>
  );
}

/* ---- Button — brand variants, scale-on-press -------------- */
const VF_BTN = {
  primary:   { bg: 'var(--primary)',        fg: '#fff' },
  success:   { bg: 'var(--green-spotify)',  fg: '#fff' },
  info:      { bg: 'var(--blue-accent)',    fg: '#fff' },
  secondary: { bg: 'var(--ink-450)',        fg: 'var(--text-primary)' },
  ghost:     { bg: 'transparent',           fg: 'var(--text-quaternary)' },
};
function Btn({ variant = 'primary', icon, iconColor, iconFill = 1, children, onClick,
              full = true, height = 50, disabled = false, glow = false, style = {} }) {
  const v = VF_BTN[variant] || VF_BTN.primary;
  return (
    <button
      className="vf-pressable"
      onClick={disabled ? undefined : onClick}
      style={{
        width: full ? '100%' : 'auto', height, border: 'none', outline: 'none',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10,
        padding: '0 18px', borderRadius: 'var(--radius-xl)', cursor: disabled ? 'default' : 'pointer',
        background: disabled ? 'var(--white-12)' : v.bg,
        color: disabled ? 'var(--text-disabled)' : v.fg,
        fontFamily: 'var(--font-sans)', fontSize: 'var(--text-lg)', fontWeight: 700,
        letterSpacing: 0.2, boxShadow: glow && !disabled ? 'var(--glow-red-md)' : 'none',
        opacity: disabled ? 0.85 : 1, transition: 'background var(--dur-fast) var(--ease-standard)',
        ...style,
      }}
    >
      {icon && <Icon name={icon} size={20} fill={iconFill} color={iconColor || (disabled ? 'var(--text-disabled)' : v.fg)} />}
      {children}
    </button>
  );
}

/* ---- Icon button (app-bar actions) ------------------------ */
function IconBtn({ name, fill = 0, size = 22, color = 'var(--text-secondary)', onClick, badge, title, style = {} }) {
  return (
    <button
      className="vf-pressable" onClick={onClick} title={title}
      style={{
        position: 'relative', width: 44, height: 44, borderRadius: 'var(--radius-pill)',
        border: 'none', background: 'transparent', cursor: 'pointer',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', ...style,
      }}
    >
      <Icon name={name} size={size} fill={fill} color={color} />
      {badge != null && (
        <span style={{
          position: 'absolute', top: 5, right: 4, minWidth: 16, height: 16, padding: '0 4px',
          borderRadius: 'var(--radius-pill)', background: 'var(--blue-accent)', color: '#fff',
          fontSize: 9, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center',
          border: '2px solid var(--ink-650)', boxSizing: 'content-box',
        }}>{badge}</span>
      )}
    </button>
  );
}

/* ---- Status chip — colored dot + clean label -------------- */
function StatusChip({ state, pulse = false, small = false }) {
  const m = (window.VFData.STATUS)[state] || window.VFData.STATUS.not_uploaded;
  const live = pulse || state === 'uploading' || state === 'queued';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, height: small ? 20 : 22,
      padding: small ? '0 8px 0 7px' : '0 10px 0 8px', borderRadius: 'var(--radius-pill)',
      background: `color-mix(in srgb, ${m.color} 13%, transparent)`,
      border: `1px solid color-mix(in srgb, ${m.color} 36%, transparent)`,
    }}>
      <span style={{
        width: 6, height: 6, borderRadius: '50%', background: m.color, flexShrink: 0,
        animation: live ? 'vf-statusdot 1.4s var(--ease-standard) infinite' : 'none',
      }} />
      <span style={{ color: m.color, fontSize: small ? 10 : 'var(--text-xs)', fontWeight: 700, letterSpacing: 0.2, whiteSpace: 'nowrap' }}>
        {m.label}
      </span>
    </span>
  );
}

/* ---- Thumbnail — faithful tinted-icon fallback ------------ */
function Thumb({ item, radius = 'var(--radius-sm)', ar = '16 / 9', showPlay = false, badge = true, dur = true }) {
  const isShorts = item.format === 'Shorts';
  const tint = item.tint === 'green' ? 'var(--green-accent)' : 'var(--red-500)';
  const glyph = isShorts ? 'bolt' : 'video_library';
  return (
    <div style={{
      position: 'relative', aspectRatio: ar, width: '100%', borderRadius: radius, overflow: 'hidden',
      background: `linear-gradient(150deg, color-mix(in srgb, ${tint} 15%, var(--ink-700)) 0%, var(--ink-850) 78%)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <Icon name={glyph} size={ar === '16 / 9' ? 30 : 40} fill={1}
            color={`color-mix(in srgb, ${tint} 70%, var(--white-30))`} />
      {showPlay && (
        <span style={{
          position: 'absolute', width: 40, height: 40, borderRadius: '50%', background: 'rgba(0,0,0,0.42)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', backdropFilter: 'blur(2px)',
        }}>
          <Icon name="play_arrow" size={24} fill={1} color="#fff" />
        </span>
      )}
      {badge && (
        <span style={{
          position: 'absolute', top: 6, left: 6, padding: '1px 6px', borderRadius: 4,
          background: isShorts ? 'var(--red-500)' : 'color-mix(in srgb, var(--green-spotify) 90%, #000)',
          color: '#fff', fontSize: 9, fontWeight: 800, letterSpacing: 0.3,
        }}>{isShorts ? 'SHORTS' : 'VIDEO'}</span>
      )}
      {dur && item.dur && (
        <span style={{
          position: 'absolute', bottom: 6, right: 6, padding: '1px 6px', borderRadius: 4,
          background: 'rgba(0,0,0,0.66)', color: '#fff', fontFamily: 'var(--font-mono)',
          fontSize: 10, fontWeight: 500, letterSpacing: 0.2,
        }}>{item.dur}</span>
      )}
    </div>
  );
}

/* ---- Section label (screen sub-headers) ------------------- */
function SectionLabel({ children, icon, color = 'var(--text-tertiary)', style = {} }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 7, ...style }}>
      {icon && <Icon name={icon} size={16} color={color} />}
      <span style={{
        color, fontSize: 'var(--text-sm)', fontWeight: 600, letterSpacing: 0.3,
        textTransform: 'none',
      }}>{children}</span>
    </div>
  );
}

/* ---- Segmented filter row (always-visible status filter) -- */
function SegRow({ segments, value, onChange }) {
  return (
    <div style={{
      display: 'flex', gap: 8, padding: '0 var(--gutter-screen)', overflowX: 'auto',
      scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch',
    }}>
      {segments.map((s) => {
        const on = s.value === value;
        const accent = s.color || 'var(--primary)';
        return (
          <button
            key={s.value} className="vf-pressable" onClick={() => onChange(s.value)}
            style={{
              flex: '0 0 auto', height: 34, padding: '0 14px', borderRadius: 'var(--radius-pill)',
              display: 'inline-flex', alignItems: 'center', gap: 6, cursor: 'pointer',
              border: on ? `1px solid color-mix(in srgb, ${accent} 55%, transparent)` : '1px solid var(--border-faint)',
              background: on ? `color-mix(in srgb, ${accent} 15%, transparent)` : 'var(--ink-700)',
              color: on ? accent : 'var(--text-secondary)',
              fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', fontWeight: on ? 700 : 500,
              whiteSpace: 'nowrap', transition: 'all var(--dur-fast) var(--ease-standard)',
            }}
          >
            {s.dot && <span style={{ width: 6, height: 6, borderRadius: '50%', background: on ? accent : 'var(--text-quaternary)' }} />}
            {s.label}
            {s.count != null && (
              <span style={{
                fontSize: 11, fontWeight: 700, fontFamily: 'var(--font-mono)',
                color: on ? accent : 'var(--text-quaternary)', opacity: 0.9,
              }}>{s.count}</span>
            )}
          </button>
        );
      })}
    </div>
  );
}

/* ---- Card surface ----------------------------------------- */
function Card({ children, pad = 16, border = 'var(--border-faint)', bg = 'var(--surface-card)', radius = 'var(--radius-2xl)', glow, style = {} }) {
  return (
    <div style={{
      background: bg, borderRadius: radius, border: `1px solid ${border}`,
      padding: pad, boxShadow: glow || 'none', ...style,
    }}>{children}</div>
  );
}

/* ---- Avatar (channel initials) ---------------------------- */
function Avatar({ initials, hue = 0, size = 44 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      background: hue === 0
        ? 'linear-gradient(140deg, var(--red-600), var(--red-700))'
        : `linear-gradient(140deg, hsl(${hue} 60% 42%), hsl(${hue} 55% 28%))`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: '#fff', fontWeight: 700, fontSize: size * 0.36, letterSpacing: 0.3,
    }}>{initials}</div>
  );
}

/* ---- Toggle switch (Material) ----------------------------- */
function Switch({ on, onChange }) {
  return (
    <button
      className="vf-pressable" onClick={() => onChange(!on)}
      style={{
        width: 46, height: 28, borderRadius: 'var(--radius-pill)', border: 'none', cursor: 'pointer',
        padding: 2, background: on ? 'var(--primary)' : 'var(--ink-450)',
        display: 'flex', alignItems: 'center', justifyContent: on ? 'flex-end' : 'flex-start',
        transition: 'background var(--dur-fast) var(--ease-standard)',
      }}
    >
      <span style={{
        width: 24, height: 24, borderRadius: '50%', background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.4)', transition: 'all var(--dur-fast) var(--ease-standard)',
      }} />
    </button>
  );
}

Object.assign(window, { Icon, Btn, IconBtn, StatusChip, Thumb, SectionLabel, SegRow, Card, Avatar, Switch });
