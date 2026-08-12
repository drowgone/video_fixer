/* ============================================================
   VideoFixer · Mobile-app shell
   Dark Android bezel + status bar + gesture pill, and the
   Material 3 NavigationBar (Asosiy / Videolar / Sozlamalar)
   with the live green processing dot and blue queue badge.
   ============================================================ */
const { useState: useState, useRef: useRef, useEffect: useEffect } = React;
const { Icon: AIcon } = window;

function StatusBar() {
  return (
    <div style={{
      height: 34, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 18px', position: 'relative', background: 'var(--surface-app)',
    }}>
      <span style={{ color: '#fff', fontSize: 13, fontWeight: 600, fontFamily: 'var(--font-sans)', letterSpacing: 0.3 }}>9:30</span>
      <div style={{
        position: 'absolute', left: '50%', top: 9, transform: 'translateX(-50%)',
        width: 9, height: 9, borderRadius: '50%', background: '#000',
        border: '2px solid #181818',
      }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <AIcon name="signal_cellular_alt" size={15} fill={1} color="#fff" />
        <AIcon name="wifi" size={15} fill={1} color="#fff" />
        <AIcon name="battery_full" size={16} fill={1} color="#fff" style={{ transform: 'rotate(90deg)' }} />
      </div>
    </div>
  );
}

const TABS = [
  { key: 0, label: 'Asosiy',     icon: 'home' },
  { key: 1, label: 'Videolar',   icon: 'history' },
  { key: 2, label: 'Sozlamalar', icon: 'settings' },
];

function NavDest({ tab, active, onClick, processing, queue }) {
  return (
    <button className="vf-pressable" onClick={onClick} style={{
      flex: 1, height: '100%', border: 'none', background: 'transparent', cursor: 'pointer',
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
      paddingTop: 8,
    }}>
      <div style={{ position: 'relative', width: 64, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <span style={{
          position: 'absolute', inset: 0, borderRadius: 'var(--radius-pill)',
          background: active ? 'var(--red-25)' : 'transparent',
          transition: 'background var(--dur-fast) var(--ease-standard)',
        }} />
        <AIcon name={tab.icon} size={24} fill={active ? 1 : 0}
               color={active ? 'var(--red-500)' : 'var(--text-secondary)'} style={{ position: 'relative' }} />
        {/* processing dot on Asosiy */}
        {tab.key === 0 && processing && (
          <span style={{
            position: 'absolute', top: 0, right: 12, width: 9, height: 9, borderRadius: '50%',
            background: 'var(--green-signal)', boxShadow: 'var(--glow-signal)',
            animation: 'vf-statusdot 1s var(--ease-standard) infinite', zIndex: 2,
          }} />
        )}
        {/* queue badge on Videolar */}
        {tab.key === 1 && queue > 0 && (
          <span style={{
            position: 'absolute', top: -1, right: 8, minWidth: 16, height: 16, padding: '0 4px',
            borderRadius: 'var(--radius-pill)', background: 'var(--blue-accent)', color: '#fff',
            fontSize: 9, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: '2px solid var(--surface-nav)', boxSizing: 'content-box', zIndex: 2,
          }}>{queue}</span>
        )}
      </div>
      <span style={{
        fontSize: 'var(--text-xs)', fontWeight: active ? 700 : 500, fontFamily: 'var(--font-sans)',
        color: active ? 'var(--red-500)' : 'var(--text-secondary)',
      }}>{tab.label}</span>
    </button>
  );
}

function App() {
  const [tab, setTab] = useState(0);
  const [homeState, setHomeState] = useState('pick');
  const scrollRef = useRef(null);
  const queueCount = window.VFData.HISTORY.filter((i) => i.state === 'queued' || i.state === 'uploading').length;

  // Reset scroll to top on tab change.
  useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = 0; }, [tab]);

  return (
    <div style={{
      width: 412, height: 880, borderRadius: 40, padding: 8, boxSizing: 'border-box',
      background: '#000', boxShadow: '0 40px 90px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.04)',
    }}>
      <div style={{
        width: '100%', height: '100%', borderRadius: 32, overflow: 'hidden',
        background: 'var(--surface-app)', display: 'flex', flexDirection: 'column',
      }}>
        <StatusBar />

        {/* Screen content (single scroller) */}
        <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', position: 'relative' }}>
          {tab === 0 && <window.HomeScreen state={homeState} setState={setHomeState} />}
          {tab === 1 && <window.HistoryScreen />}
          {tab === 2 && <window.SettingsScreen />}
        </div>

        {/* Material NavigationBar */}
        <div style={{
          flexShrink: 0, height: 68, background: 'var(--surface-nav)', display: 'flex',
          boxShadow: 'var(--shadow-nav)', position: 'relative', zIndex: 10,
        }}>
          {TABS.map((t) => (
            <NavDest key={t.key} tab={t} active={tab === t.key} onClick={() => setTab(t.key)}
                     processing={homeState === 'processing'} queue={queueCount} />
          ))}
        </div>
        {/* gesture pill */}
        <div style={{ flexShrink: 0, height: 18, background: 'var(--surface-nav)', display: 'flex',
          alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ width: 120, height: 4, borderRadius: 2, background: 'var(--white-38)' }} />
        </div>
      </div>
    </div>
  );
}

window.VFApp = App;
