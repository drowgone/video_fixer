/* ============================================================
   VideoFixer · Asosiy (Home) — refined state-card flow
   pick → selected → processing (with stage stepper) → done
   Mirrors home_screen.dart's _buildStateCard switch.
   ============================================================ */
const { useState: useState, useEffect: useEffect } = React;
const { Icon: HIcon, Btn: HBtn, Thumb: HThumb, Card: HCard, SectionLabel: HLabel } = window;

function HomeHeader() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 26 }}>
      <div className="vf-pulse" style={{
        width: 76, height: 76, borderRadius: 20, overflow: 'hidden',
        boxShadow: 'var(--glow-red-md)',
      }}>
        <img src="../../assets/brand/logo.png" alt="VideoFixer"
             style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      </div>
      <div style={{
        marginTop: 16, color: 'var(--text-primary)', fontSize: 'var(--text-6xl)',
        fontWeight: 900, letterSpacing: '-0.5px', lineHeight: 1,
      }}>VideoFixer</div>
      <div style={{
        marginTop: 8, color: 'var(--text-tertiary)', fontSize: 'var(--text-sm)',
        letterSpacing: '1.5px', textTransform: 'uppercase',
      }}>Shorts Converter</div>
    </div>
  );
}

/* ---- compliance chip ---- */
function ComplianceChip({ label, ok }) {
  const color = ok ? 'var(--green-accent)' : 'var(--orange-accent)';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, height: 28, padding: '0 11px 0 9px',
      borderRadius: 'var(--radius-pill)', background: `color-mix(in srgb, ${color} 12%, transparent)`,
      border: `1px solid color-mix(in srgb, ${color} 38%, transparent)`,
    }}>
      <HIcon name={ok ? 'check_circle' : 'warning'} size={15} fill={1} color={color} />
      <span style={{ color, fontSize: 'var(--text-xs)', fontWeight: 700 }}>{label}</span>
    </span>
  );
}

/* ---- PICK ---- */
function PickState({ onPick }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '8px 0' }}>
      <div className="vf-pulse" style={{
        width: 104, height: 104, borderRadius: '50%', marginTop: 8,
        background: 'var(--red-06)', display: 'flex', alignItems: 'center', justifyContent: 'center',
        border: '1px solid color-mix(in srgb, var(--red-500) 22%, transparent)',
      }}>
        <HIcon name="video_file" size={50} color="var(--red-500)" />
      </div>
      <div style={{ marginTop: 22, color: 'var(--text-primary)', fontSize: 'var(--text-xl)', fontWeight: 700 }}>
        Video tanlash uchun bosing
      </div>
      <div style={{ marginTop: 6, color: 'var(--text-quaternary)', fontSize: 'var(--text-base)' }}>
        MP4, MOV, AVI va boshqalar
      </div>
      <div style={{ height: 24 }} />
      <HBtn icon="video_library" onClick={onPick} glow height={52}>Video Tanlash</HBtn>
    </div>
  );
}

/* ---- SELECTED ---- */
function SelectedState({ volume, setVolume, onProcess, onReset }) {
  const item = { format: 'Normal', tint: 'green', dur: '1:24' };
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <HIcon name="video_library" size={20} fill={1} color="var(--red-500)" />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ color: 'var(--text-primary)', fontSize: 'var(--text-md)', fontWeight: 700,
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            mahsulot_sharhi_3.mp4
          </div>
          <div style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-sm)', fontFamily: 'var(--font-mono)' }}>
            142.6 MB · 1:24
          </div>
        </div>
      </div>

      <div style={{ position: 'relative' }}>
        <HThumb item={item} radius="var(--radius-lg)" showPlay badge={false} dur />
      </div>

      <div style={{ marginTop: 16 }}>
        <HLabel>Shorts format holati</HLabel>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 10 }}>
          <ComplianceChip label="Video" ok={true} />
          <ComplianceChip label="Audio" ok={true} />
          <ComplianceChip label="Davomiylik" ok={false} />
        </div>
        <div style={{ marginTop: 8, color: 'var(--text-disabled)', fontSize: 'var(--text-xs)', fontFamily: 'var(--font-mono)' }}>
          1920×1080 · 30fps · H264 / AAC
        </div>
      </div>

      {/* volume */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 18 }}>
        <HIcon name="volume_down" size={18} color="var(--text-quaternary)" />
        <input type="range" min="0" max="3" step="0.1" value={volume}
               onChange={(e) => setVolume(parseFloat(e.target.value))}
               className="vf-range" style={{ flex: 1 }} />
        <HIcon name="volume_up" size={18} color="var(--text-quaternary)" />
        <span style={{ width: 34, textAlign: 'right', color: 'var(--text-tertiary)',
          fontSize: 'var(--text-sm)', fontFamily: 'var(--font-mono)' }}>{volume.toFixed(1)}x</span>
      </div>

      <div style={{ height: 1, background: 'var(--divider)', margin: '18px 0' }} />

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <HBtn icon="bolt" iconColor="var(--amber)" onClick={onProcess} glow>Videoni qayta ishlash</HBtn>
        <HBtn variant="secondary" icon="movie_filter" iconColor="var(--text-secondary)" iconFill={0}>Video Editor</HBtn>
      </div>
      <button className="vf-pressable" onClick={onReset} style={{
        margin: '8px auto 0', display: 'flex', alignItems: 'center', gap: 6, background: 'none',
        border: 'none', cursor: 'pointer', color: 'var(--text-quaternary)', fontSize: 'var(--text-base)',
        fontFamily: 'var(--font-sans)',
      }}>
        <HIcon name="refresh" size={16} color="var(--text-quaternary)" /> Boshqa video tanlash
      </button>
    </div>
  );
}

/* ---- PROCESSING (with stage stepper) ---- */
const STAGES = [
  { key: 'analiz', label: 'Analiz', icon: 'search', at: 0.0 },
  { key: 'convert', label: 'Konvertatsiya', icon: 'autorenew', at: 0.18 },
  { key: 'save', label: 'Saqlash', icon: 'save', at: 0.86 },
];
function Stepper({ progress }) {
  let active = 0;
  STAGES.forEach((s, i) => { if (progress >= s.at) active = i; });
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', marginTop: 18 }}>
      {STAGES.map((s, i) => {
        const done = i < active, cur = i === active;
        const color = done ? 'var(--green-accent)' : cur ? 'var(--red-500)' : 'var(--text-disabled)';
        return (
          <React.Fragment key={s.key}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7, width: 64 }}>
              <div style={{
                width: 34, height: 34, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: cur ? 'var(--red-12)' : done ? 'color-mix(in srgb, var(--green-accent) 14%, transparent)' : 'var(--ink-700)',
                border: `1.5px solid ${cur ? 'color-mix(in srgb, var(--red-500) 50%, transparent)' : done ? 'color-mix(in srgb, var(--green-accent) 40%, transparent)' : 'var(--border-faint)'}`,
              }}>
                <HIcon name={done ? 'check' : s.icon} size={18} fill={cur ? 1 : 0} color={color}
                       style={cur ? { animation: 'vf-spin 1.1s linear infinite' } : {}} />
              </div>
              <span style={{ color, fontSize: 'var(--text-2xs)', fontWeight: cur ? 700 : 500, textAlign: 'center' }}>{s.label}</span>
            </div>
            {i < STAGES.length - 1 && (
              <div style={{ flex: 1, height: 2, marginTop: 16, borderRadius: 1,
                background: i < active ? 'var(--green-accent)' : 'var(--ink-500)' }} />
            )}
          </React.Fragment>
        );
      })}
    </div>
  );
}
function ProcessingState({ progress }) {
  const pct = Math.round(progress * 100);
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 56, height: 36, borderRadius: 8, overflow: 'hidden', flexShrink: 0 }}>
          <HThumb item={{ format: 'Shorts', tint: 'red' }} radius="8px" badge={false} dur={false} />
        </div>
        <div style={{ color: 'var(--text-secondary)', fontSize: 'var(--text-base)',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          mahsulot_sharhi_3.mp4
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 20 }}>
        <span style={{ color: 'var(--text-secondary)', fontSize: 'var(--text-base)', fontWeight: 500 }}>Jarayon</span>
        <span style={{ color: 'var(--red-400)', fontSize: 'var(--text-base)', fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{pct}%</span>
      </div>
      <div style={{ height: 10, borderRadius: 8, background: 'var(--ink-500)', overflow: 'hidden', marginTop: 8 }}>
        <div style={{ height: '100%', width: `${pct}%`, borderRadius: 8, background: 'var(--grad-cta)',
          transition: 'width 220ms linear' }} />
      </div>

      <Stepper progress={progress} />

      <div style={{
        display: 'flex', alignItems: 'center', gap: 10, marginTop: 18, padding: 12,
        borderRadius: 'var(--radius-lg)', background: 'var(--surface-inset)',
      }}>
        <span className="vf-spin" style={{ width: 14, height: 14, borderRadius: '50%',
          border: '2px solid var(--red-400)', borderTopColor: 'transparent', flexShrink: 0 }} />
        <span style={{ color: 'var(--text-secondary)', fontSize: 'var(--text-base)', lineHeight: 1.5 }}>
          Video Shorts formatiga o‘tkazilmoqda — 9:16, 1080×1920
        </span>
      </div>
    </div>
  );
}

/* ---- DONE ---- */
function DoneState({ onReset }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{
        width: 64, height: 64, borderRadius: '50%', marginTop: 6,
        background: 'color-mix(in srgb, var(--green-accent) 14%, transparent)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: 'var(--glow-success)',
      }}>
        <HIcon name="check_circle" size={40} fill={1} color="var(--green-accent)" />
      </div>
      <div style={{ marginTop: 14, color: 'var(--text-primary)', fontSize: 'var(--text-2xl)', fontWeight: 700 }}>
        Muvaffaqiyatli tayyor!
      </div>
      <div style={{ marginTop: 6, color: 'var(--text-tertiary)', fontSize: 'var(--text-base)', textAlign: 'center' }}>
        Fayl saqlandi va Tarixga qo‘shildi.
      </div>

      <div style={{ width: '100%', marginTop: 18, padding: 12, borderRadius: 'var(--radius-lg)',
        background: 'var(--surface-inset)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--text-quaternary)', fontSize: 'var(--text-xs)' }}>
          <HIcon name="folder" size={14} color="var(--text-quaternary)" />
          Downloads/VideoFixer/
        </div>
        <div style={{ marginTop: 4, color: 'var(--text-primary)', fontSize: 'var(--text-md)', fontWeight: 600,
          fontFamily: 'var(--font-mono)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          mahsulot_sharhi_3_shorts.mp4
        </div>
      </div>

      <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10, marginTop: 18 }}>
        <HBtn variant="success" icon="cloud_upload">YouTube'ga yuklash</HBtn>
        <HBtn variant="secondary" icon="refresh" iconFill={0} iconColor="var(--text-secondary)" onClick={onReset}>Yangi Video</HBtn>
      </div>
    </div>
  );
}

function borderForState(s) {
  if (s === 'processing') return 'color-mix(in srgb, var(--red-500) 35%, transparent)';
  if (s === 'done') return 'color-mix(in srgb, var(--green-accent) 30%, transparent)';
  return 'var(--border-default)';
}
function glowForState(s) {
  if (s === 'processing') return '0 0 24px 2px var(--red-12)';
  if (s === 'done') return 'var(--glow-success)';
  return 'var(--shadow-card)';
}

function HomeScreen({ state, setState }) {
  const [volume, setVolume] = useState(1.0);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (state !== 'processing') return;
    setProgress(0);
    let p = 0;
    const t = setInterval(() => {
      p += 0.0125 + Math.random() * 0.02;
      if (p >= 1) { p = 1; setProgress(1); clearInterval(t); setTimeout(() => setState('done'), 480); }
      else setProgress(p);
    }, 90);
    return () => clearInterval(t);
  }, [state]);

  return (
    <div style={{ minHeight: '100%', background: 'var(--surface-app)', padding: '0 var(--gutter-screen) 28px' }}>
      <HomeHeader />
      <div style={{ height: 24 }} />
      <HCard pad={22} radius="var(--radius-4xl)" border={borderForState(state)}
             glow={glowForState(state)} bg="var(--surface-card)">
        {state === 'pick' && <PickState onPick={() => setState('selected')} />}
        {state === 'selected' && <SelectedState volume={volume} setVolume={setVolume}
                                   onProcess={() => setState('processing')} onReset={() => setState('pick')} />}
        {state === 'processing' && <ProcessingState progress={progress} />}
        {state === 'done' && <DoneState onReset={() => setState('pick')} />}
      </HCard>
    </div>
  );
}

window.HomeScreen = HomeScreen;
