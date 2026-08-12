/* ============================================================
   VideoFixer · Videolar (History) — refined list
   Adds an always-visible status segment filter (the app hides
   this behind a bottom sheet). List · Grid · Compact views,
   clean dot-status chips, faithful thumbnails.
   ============================================================ */
const { useState: useState } = React;
const { Icon: YIcon, IconBtn: YIconBtn, StatusChip: YChip, Thumb: YThumb, SegRow: YSeg } = window;

const SEGS = [
  { value: 'all',          label: 'Barchasi' },
  { value: 'uploaded',     label: 'Yuklangan',   color: 'var(--green-accent)',  dot: true },
  { value: 'not_uploaded', label: 'Qurilmada',   color: 'var(--white-54)',      dot: true },
  { value: 'processing',   label: 'Jarayonda',   color: 'var(--orange-accent)', dot: true },
  { value: 'deleted',      label: "O'chirilgan", color: 'var(--red-accent)',    dot: true },
];

function matchSeg(item, seg) {
  if (seg === 'all') return true;
  if (seg === 'processing') return ['processing', 'uploading', 'queued'].includes(item.state);
  if (seg === 'deleted') return ['deleted', 'failed'].includes(item.state);
  return item.state === seg;
}

/* ---- list row ---- */
function ListRow({ item }) {
  const isDeleted = item.state === 'deleted';
  return (
    <div className="vf-pressable" style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: 10, borderRadius: 'var(--radius-lg)',
      background: isDeleted ? '#2E1A1A' : 'var(--surface-card)',
      border: `1px solid ${isDeleted ? 'color-mix(in srgb, var(--red-accent) 32%, transparent)' : 'var(--white-04)'}`,
    }}>
      <div style={{ width: 104, flexShrink: 0 }}>
        <YThumb item={item} radius="var(--radius-sm)" badge dur />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          color: isDeleted ? '#FF8888' : 'var(--text-primary)', fontSize: 'var(--text-base)', fontWeight: 700,
          lineHeight: 1.35, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{item.name}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 7, flexWrap: 'wrap' }}>
          <YChip state={item.state} small />
          {item.channel && (
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
              <YIcon name="tv" size={12} color="var(--blue-accent)" />
              <span style={{ color: 'var(--text-tertiary)', fontSize: 10, maxWidth: 90, overflow: 'hidden',
                textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.channel}</span>
            </span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6,
          color: 'var(--text-quaternary)', fontSize: 10, fontFamily: 'var(--font-mono)' }}>
          <span>{item.date}</span><span style={{ opacity: 0.6 }}>{item.size}</span>
        </div>
      </div>
      <YIcon name="more_vert" size={18} color="var(--text-disabled)" />
    </div>
  );
}

/* ---- grid cell (9:16) ---- */
function GridCell({ item }) {
  return (
    <div className="vf-pressable" style={{ position: 'relative', borderRadius: 'var(--radius-lg)', overflow: 'hidden' }}>
      <YThumb item={item} radius="var(--radius-lg)" ar="9 / 16" badge dur={false} />
      <div style={{ position: 'absolute', top: 8, right: 8 }}><YChip state={item.state} small /></div>
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0, padding: '24px 10px 10px',
        background: 'var(--grad-scrim)',
      }}>
        <div style={{ color: '#fff', fontSize: 'var(--text-xs)', fontWeight: 700, lineHeight: 1.3,
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{item.name}</div>
        <div style={{ marginTop: 5, color: 'var(--white-54)', fontSize: 9, fontFamily: 'var(--font-mono)' }}>{item.date} · {item.size}</div>
      </div>
    </div>
  );
}

/* ---- compact row ---- */
function CompactRow({ item }) {
  return (
    <div className="vf-pressable" style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 6px' }}>
      <div style={{ width: 44, height: 44, borderRadius: 'var(--radius-sm)', overflow: 'hidden', flexShrink: 0 }}>
        <YThumb item={item} radius="var(--radius-sm)" ar="1 / 1" badge={false} dur={false} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ color: 'var(--text-primary)', fontSize: 'var(--text-base)', fontWeight: 500,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.name}</div>
        <div style={{ color: 'var(--text-quaternary)', fontSize: 10, fontFamily: 'var(--font-mono)', marginTop: 2 }}>{item.date} · {item.size}</div>
      </div>
      <YChip state={item.state} small />
    </div>
  );
}

function EmptyFiltered({ onClear }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      padding: '64px 24px', textAlign: 'center' }}>
      <YIcon name="search_off" size={64} color="var(--white-24)" />
      <div style={{ marginTop: 16, color: 'var(--text-secondary)', fontSize: 'var(--text-lg)' }}>
        Bu filtr bo‘yicha video topilmadi
      </div>
      <button className="vf-pressable" onClick={onClear} style={{
        marginTop: 20, height: 40, padding: '0 18px', borderRadius: 'var(--radius-pill)', cursor: 'pointer',
        background: 'transparent', border: '1px solid color-mix(in srgb, var(--red-accent) 55%, transparent)',
        color: 'var(--text-primary)', fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', fontWeight: 600,
        display: 'inline-flex', alignItems: 'center', gap: 8,
      }}>
        <YIcon name="clear_all" size={18} color="var(--red-accent)" /> Filtrni tozalash
      </button>
    </div>
  );
}

const VIEW_CYCLE = { list: 'grid', grid: 'compact', compact: 'list' };
const VIEW_ICON = { list: 'view_list', grid: 'grid_view', compact: 'view_headline' };

function HistoryScreen() {
  const [seg, setSeg] = useState('all');
  const [view, setView] = useState('list');
  const all = window.VFData.HISTORY;
  const counts = {};
  SEGS.forEach((s) => { counts[s.value] = s.value === 'all' ? all.length : all.filter((i) => matchSeg(i, s.value)).length; });
  const list = all.filter((i) => matchSeg(i, seg));
  const queueCount = all.filter((i) => i.state === 'queued' || i.state === 'uploading').length;
  const segsWithCount = SEGS.map((s) => ({ ...s, count: counts[s.value] }));

  return (
    <div style={{ minHeight: '100%', background: 'var(--surface-app)' }}>
      {/* Sticky header: app bar + status segments */}
      <div style={{ position: 'sticky', top: 0, zIndex: 5, background: 'var(--surface-app)' }}>
        <div style={{
          height: 56, background: 'var(--surface-card)', display: 'flex', alignItems: 'center',
          padding: '0 6px 0 var(--gutter-screen)',
        }}>
          <span style={{ flex: 1, color: 'var(--text-primary)', fontSize: 'var(--text-2xl)', fontWeight: 700 }}>Videolar</span>
          <YIconBtn name="filter_list" />
          <YIconBtn name="refresh" />
          <YIconBtn name={VIEW_ICON[view]} color="var(--text-secondary)" onClick={() => setView(VIEW_CYCLE[view])} title="Ko‘rinish" />
        </div>
        <div style={{ padding: '12px 0 12px', borderBottom: '1px solid var(--white-04)' }}>
          <YSeg segments={segsWithCount} value={seg} onChange={setSeg} />
        </div>
      </div>

      {/* Content */}
      <div>
        {list.length === 0 ? (
          <EmptyFiltered onClear={() => setSeg('all')} />
        ) : view === 'grid' ? (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, padding: 'var(--gutter-screen)' }}>
            {list.map((it) => <GridCell key={it.id} item={it} />)}
          </div>
        ) : view === 'compact' ? (
          <div style={{ padding: '6px var(--gutter-screen) 16px' }}>
            {list.map((it, idx) => (
              <div key={it.id}>
                {idx > 0 && <div style={{ height: 1, background: 'var(--white-06)' }} />}
                <CompactRow item={it} />
              </div>
            ))}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, padding: '4px var(--gutter-screen) 16px' }}>
            {list.map((it) => <ListRow key={it.id} item={it} />)}
          </div>
        )}
      </div>
    </div>
  );
}

window.HistoryScreen = HistoryScreen;
