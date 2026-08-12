/* ============================================================
   VideoFixer · Sozlamalar (Settings) — YouTube channels
   Mirrors settings_screen.dart: connected-account cards with
   subs/videos, active toggle, per-channel settings, and the
   Google connect CTA. Refined into cleaner channel cards.
   ============================================================ */
const { useState: useState } = React;
const { Icon: SIcon, IconBtn: SIconBtn, Avatar: SAvatar, Switch: SSwitch, Card: SCard } = window;

function GoogleMark({ size = 22 }) {
  // Faithful fallback for the app's missing assets/google_logo.png
  // (its errorBuilder renders a blue "G").
  return (
    <span style={{
      width: size, height: size, borderRadius: '50%', background: '#fff',
      border: '1px solid #e3e3e3', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--font-sans)', fontWeight: 700, fontSize: size * 0.72, color: '#4285F4', lineHeight: 1,
    }}>G</span>
  );
}

function ChannelCard({ ch, onToggle }) {
  return (
    <SCard pad={14} radius="var(--radius-2xl)" bg="var(--surface-card)" border="var(--white-04)">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <SAvatar initials={ch.initials} hue={ch.hue} size={46} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
            <span style={{ color: 'var(--text-primary)', fontSize: 'var(--text-md)', fontWeight: 700,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ch.name}</span>
            {ch.active
              ? <SIcon name="check_circle" size={15} fill={1} color="var(--green-accent)" />
              : <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--text-disabled)' }} />}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 4 }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--text-tertiary)', fontSize: 'var(--text-sm)' }}>
              <SIcon name="group" size={14} color="var(--text-quaternary)" /> {ch.subs}
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--text-tertiary)', fontSize: 'var(--text-sm)' }}>
              <SIcon name="smart_display" size={14} color="var(--text-quaternary)" /> {ch.videos}
            </span>
          </div>
        </div>
        <SSwitch on={ch.active} onChange={() => onToggle(ch.id)} />
      </div>

      <div style={{ height: 1, background: 'var(--divider)', margin: '12px 0' }} />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <button className="vf-pressable" style={{
          flex: 1, height: 38, borderRadius: 'var(--radius-md)', cursor: 'pointer',
          background: 'var(--ink-450)', border: 'none', color: 'var(--text-secondary)',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 7,
          fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', fontWeight: 600,
        }}>
          <SIcon name="tune" size={16} color="var(--text-secondary)" /> Standart sozlamalar
        </button>
        <SIconBtn name="more_vert" size={20} color="var(--text-tertiary)"
                  style={{ width: 38, height: 38, background: 'var(--ink-450)', borderRadius: 'var(--radius-md)' }} />
      </div>
    </SCard>
  );
}

function SettingsScreen() {
  const [channels, setChannels] = useState(window.VFData.CHANNELS.map((c) => ({ ...c })));
  const toggle = (id) => setChannels((cs) => cs.map((c) => c.id === id ? { ...c, active: !c.active } : c));
  const activeCount = channels.filter((c) => c.active).length;

  return (
    <div style={{ minHeight: '100%', background: 'var(--surface-app)', display: 'flex', flexDirection: 'column' }}>
      {/* App bar */}
      <div style={{
        height: 56, background: 'var(--surface-card)', display: 'flex', alignItems: 'center',
        padding: '0 var(--gutter-screen)', position: 'sticky', top: 0, zIndex: 5,
      }}>
        <span style={{ color: 'var(--text-primary)', fontSize: 'var(--text-2xl)', fontWeight: 700 }}>YouTube Sozlamalari</span>
      </div>

      <div style={{ padding: 'var(--gutter-screen)', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Section header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ color: 'var(--text-primary)', fontSize: 'var(--text-2xl)', fontWeight: 700 }}>YouTube Kanallari</span>
          <span style={{
            minWidth: 22, height: 22, padding: '0 7px', borderRadius: 'var(--radius-pill)',
            background: 'var(--red-12)', border: '1px solid color-mix(in srgb, var(--red-500) 35%, transparent)',
            color: 'var(--red-400)', fontSize: 'var(--text-xs)', fontWeight: 700, fontFamily: 'var(--font-mono)',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          }}>{activeCount}/{channels.length}</span>
        </div>

        {channels.map((ch) => <ChannelCard key={ch.id} ch={ch} onToggle={toggle} />)}

        {/* Connect CTA (white Google button) */}
        <button className="vf-pressable" style={{
          height: 52, borderRadius: 'var(--radius-xl)', cursor: 'pointer', marginTop: 4,
          background: '#fff', border: 'none', display: 'inline-flex', alignItems: 'center',
          justifyContent: 'center', gap: 10, boxShadow: 'var(--shadow-card)',
          fontFamily: 'var(--font-sans)', fontSize: 'var(--text-lg)', fontWeight: 700, color: '#202124',
        }}>
          <GoogleMark size={22} /> Google orqali ulash
        </button>

        <div style={{ display: 'flex', alignItems: 'center', gap: 7, justifyContent: 'center', marginTop: 2 }}>
          <SIcon name="lock" size={13} color="var(--text-disabled)" />
          <span style={{ color: 'var(--text-disabled)', fontSize: 'var(--text-xs)' }}>
            Ulanish faqat yuklash uchun ishlatiladi
          </span>
        </div>
      </div>
    </div>
  );
}

window.SettingsScreen = SettingsScreen;
