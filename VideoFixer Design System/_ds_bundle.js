/* @ds-bundle: {"format":3,"namespace":"VideoFixerDesignSystem_cfcd1b","components":[],"sourceHashes":{"ui_kits/mobile-app/vf-data.js":"d0d8e218c2e7","ui_kits/mobile-app/vf-history.jsx":"6fc990232355","ui_kits/mobile-app/vf-home.jsx":"5fd45a63ac05","ui_kits/mobile-app/vf-kit.jsx":"225b03dd8f3c","ui_kits/mobile-app/vf-settings.jsx":"bfb4ab328ae9","ui_kits/mobile-app/vf-shell.jsx":"88cab044da52"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.VideoFixerDesignSystem_cfcd1b = window.VideoFixerDesignSystem_cfcd1b || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// ui_kits/mobile-app/vf-data.js
try { (() => {
/* ============================================================
   VideoFixer · Mobile-app UI kit — mock data + status meta
   Mirrors lib/models/history_item.dart and the youtube_account
   model. Plain JS, attached to window so the babel-compiled
   screen modules can read it.
   ============================================================ */
(function () {
  // Video status → label + accent color (semantic tokens).
  // The improved UI surfaces state as a colored DOT + clean
  // label, replacing the app's emoji-in-chip pattern.
  const STATUS = {
    uploaded: {
      label: 'Yuklangan',
      color: 'var(--green-accent)'
    },
    not_uploaded: {
      label: 'Qurilmada',
      color: 'var(--white-54)'
    },
    processing: {
      label: 'Jarayonda',
      color: 'var(--orange-accent)'
    },
    queued: {
      label: 'Navbatda',
      color: 'var(--blue-accent)'
    },
    uploading: {
      label: 'Yuklanmoqda',
      color: 'var(--orange-accent)'
    },
    failed: {
      label: 'Xato',
      color: 'var(--red-accent)'
    },
    deleted: {
      label: "O'chirilgan",
      color: 'var(--red-accent)'
    }
  };

  // History items — a spread across every state the app renders.
  const HISTORY = [{
    id: 1,
    name: 'Toshkent kechasi — shahar bo‘ylab sayohat',
    format: 'Shorts',
    state: 'uploaded',
    channel: 'Sardor Vlog',
    date: '24-iyun',
    size: '18.4 MB',
    dur: '0:48',
    tint: 'red'
  }, {
    id: 2,
    name: 'Yangi mahsulot sharhi #3 — to‘liq versiya',
    format: 'Normal',
    state: 'not_uploaded',
    channel: '',
    date: 'Bugun',
    size: '142.6 MB',
    dur: '4:12',
    tint: 'green'
  }, {
    id: 3,
    name: 'Jonli konsert — eng yaxshi lahzalar',
    format: 'Shorts',
    state: 'uploading',
    channel: 'Sardor Vlog',
    date: 'Bugun',
    size: '24.1 MB',
    dur: '0:59',
    tint: 'red',
    progress: 0.62
  }, {
    id: 4,
    name: 'O‘yin obzori — final jang',
    format: 'Shorts',
    state: 'queued',
    channel: '',
    date: 'Bugun',
    size: '33.0 MB',
    dur: '0:55',
    tint: 'red'
  }, {
    id: 5,
    name: 'Retsept: bahor oshi tayyorlash',
    format: 'Normal',
    state: 'uploaded',
    channel: 'Tech Uzbek',
    date: '21-iyun',
    size: '88.2 MB',
    dur: '6:30',
    tint: 'green'
  }, {
    id: 6,
    name: 'Reklama roliki — qayta urinish',
    format: 'Shorts',
    state: 'failed',
    channel: '',
    date: 'Kecha',
    size: '9.4 MB',
    dur: '0:30',
    tint: 'red'
  }, {
    id: 7,
    name: 'Eski intervyu arxividan',
    format: 'Shorts',
    state: 'deleted',
    channel: 'Sardor Vlog',
    date: '4-iyun',
    size: '12.7 MB',
    dur: '0:51',
    tint: 'red'
  }];

  // Connected YouTube channels (settings_provider accounts).
  const CHANNELS = [{
    id: 'a',
    name: 'Sardor Vlog',
    subs: '12.4K',
    videos: 86,
    active: true,
    initials: 'SV',
    hue: 0
  }, {
    id: 'b',
    name: 'Tech Uzbek',
    subs: '3.2K',
    videos: 41,
    active: true,
    initials: 'TU',
    hue: 210
  }, {
    id: 'c',
    name: 'MVP Gaming',
    subs: '540',
    videos: 18,
    active: false,
    initials: 'MG',
    hue: 280
  }];
  window.VFData = {
    STATUS,
    HISTORY,
    CHANNELS
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/vf-data.js", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/vf-history.jsx
try { (() => {
/* ============================================================
   VideoFixer · Videolar (History) — refined list
   Adds an always-visible status segment filter (the app hides
   this behind a bottom sheet). List · Grid · Compact views,
   clean dot-status chips, faithful thumbnails.
   ============================================================ */
const {
  useState: useState
} = React;
const {
  Icon: YIcon,
  IconBtn: YIconBtn,
  StatusChip: YChip,
  Thumb: YThumb,
  SegRow: YSeg
} = window;
const SEGS = [{
  value: 'all',
  label: 'Barchasi'
}, {
  value: 'uploaded',
  label: 'Yuklangan',
  color: 'var(--green-accent)',
  dot: true
}, {
  value: 'not_uploaded',
  label: 'Qurilmada',
  color: 'var(--white-54)',
  dot: true
}, {
  value: 'processing',
  label: 'Jarayonda',
  color: 'var(--orange-accent)',
  dot: true
}, {
  value: 'deleted',
  label: "O'chirilgan",
  color: 'var(--red-accent)',
  dot: true
}];
function matchSeg(item, seg) {
  if (seg === 'all') return true;
  if (seg === 'processing') return ['processing', 'uploading', 'queued'].includes(item.state);
  if (seg === 'deleted') return ['deleted', 'failed'].includes(item.state);
  return item.state === seg;
}

/* ---- list row ---- */
function ListRow({
  item
}) {
  const isDeleted = item.state === 'deleted';
  return /*#__PURE__*/React.createElement("div", {
    className: "vf-pressable",
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: 10,
      borderRadius: 'var(--radius-lg)',
      background: isDeleted ? '#2E1A1A' : 'var(--surface-card)',
      border: `1px solid ${isDeleted ? 'color-mix(in srgb, var(--red-accent) 32%, transparent)' : 'var(--white-04)'}`
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 104,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement(YThumb, {
    item: item,
    radius: "var(--radius-sm)",
    badge: true,
    dur: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: isDeleted ? '#FF8888' : 'var(--text-primary)',
      fontSize: 'var(--text-base)',
      fontWeight: 700,
      lineHeight: 1.35,
      display: '-webkit-box',
      WebkitLineClamp: 2,
      WebkitBoxOrient: 'vertical',
      overflow: 'hidden'
    }
  }, item.name), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 7,
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement(YChip, {
    state: item.state,
    small: true
  }), item.channel && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 3
    }
  }, /*#__PURE__*/React.createElement(YIcon, {
    name: "tv",
    size: 12,
    color: "var(--blue-accent)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-tertiary)',
      fontSize: 10,
      maxWidth: 90,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, item.channel))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginTop: 6,
      color: 'var(--text-quaternary)',
      fontSize: 10,
      fontFamily: 'var(--font-mono)'
    }
  }, /*#__PURE__*/React.createElement("span", null, item.date), /*#__PURE__*/React.createElement("span", {
    style: {
      opacity: 0.6
    }
  }, item.size))), /*#__PURE__*/React.createElement(YIcon, {
    name: "more_vert",
    size: 18,
    color: "var(--text-disabled)"
  }));
}

/* ---- grid cell (9:16) ---- */
function GridCell({
  item
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "vf-pressable",
    style: {
      position: 'relative',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement(YThumb, {
    item: item,
    radius: "var(--radius-lg)",
    ar: "9 / 16",
    badge: true,
    dur: false
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 8,
      right: 8
    }
  }, /*#__PURE__*/React.createElement(YChip, {
    state: item.state,
    small: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      padding: '24px 10px 10px',
      background: 'var(--grad-scrim)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: '#fff',
      fontSize: 'var(--text-xs)',
      fontWeight: 700,
      lineHeight: 1.3,
      display: '-webkit-box',
      WebkitLineClamp: 2,
      WebkitBoxOrient: 'vertical',
      overflow: 'hidden'
    }
  }, item.name), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 5,
      color: 'var(--white-54)',
      fontSize: 9,
      fontFamily: 'var(--font-mono)'
    }
  }, item.date, " \xB7 ", item.size)));
}

/* ---- compact row ---- */
function CompactRow({
  item
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "vf-pressable",
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '10px 6px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 44,
      height: 44,
      borderRadius: 'var(--radius-sm)',
      overflow: 'hidden',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement(YThumb, {
    item: item,
    radius: "var(--radius-sm)",
    ar: "1 / 1",
    badge: false,
    dur: false
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--text-primary)',
      fontSize: 'var(--text-base)',
      fontWeight: 500,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, item.name), /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--text-quaternary)',
      fontSize: 10,
      fontFamily: 'var(--font-mono)',
      marginTop: 2
    }
  }, item.date, " \xB7 ", item.size)), /*#__PURE__*/React.createElement(YChip, {
    state: item.state,
    small: true
  }));
}
function EmptyFiltered({
  onClear
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '64px 24px',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement(YIcon, {
    name: "search_off",
    size: 64,
    color: "var(--white-24)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16,
      color: 'var(--text-secondary)',
      fontSize: 'var(--text-lg)'
    }
  }, "Bu filtr bo\u2018yicha video topilmadi"), /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    onClick: onClear,
    style: {
      marginTop: 20,
      height: 40,
      padding: '0 18px',
      borderRadius: 'var(--radius-pill)',
      cursor: 'pointer',
      background: 'transparent',
      border: '1px solid color-mix(in srgb, var(--red-accent) 55%, transparent)',
      color: 'var(--text-primary)',
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-base)',
      fontWeight: 600,
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(YIcon, {
    name: "clear_all",
    size: 18,
    color: "var(--red-accent)"
  }), " Filtrni tozalash"));
}
const VIEW_CYCLE = {
  list: 'grid',
  grid: 'compact',
  compact: 'list'
};
const VIEW_ICON = {
  list: 'view_list',
  grid: 'grid_view',
  compact: 'view_headline'
};
function HistoryScreen() {
  const [seg, setSeg] = useState('all');
  const [view, setView] = useState('list');
  const all = window.VFData.HISTORY;
  const counts = {};
  SEGS.forEach(s => {
    counts[s.value] = s.value === 'all' ? all.length : all.filter(i => matchSeg(i, s.value)).length;
  });
  const list = all.filter(i => matchSeg(i, seg));
  const queueCount = all.filter(i => i.state === 'queued' || i.state === 'uploading').length;
  const segsWithCount = SEGS.map(s => ({
    ...s,
    count: counts[s.value]
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      background: 'var(--surface-app)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'sticky',
      top: 0,
      zIndex: 5,
      background: 'var(--surface-app)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      background: 'var(--surface-card)',
      display: 'flex',
      alignItems: 'center',
      padding: '0 6px 0 var(--gutter-screen)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      color: 'var(--text-primary)',
      fontSize: 'var(--text-2xl)',
      fontWeight: 700
    }
  }, "Videolar"), /*#__PURE__*/React.createElement(YIconBtn, {
    name: "filter_list"
  }), /*#__PURE__*/React.createElement(YIconBtn, {
    name: "refresh"
  }), /*#__PURE__*/React.createElement(YIconBtn, {
    name: VIEW_ICON[view],
    color: "var(--text-secondary)",
    onClick: () => setView(VIEW_CYCLE[view]),
    title: "Ko\u2018rinish"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 0 12px',
      borderBottom: '1px solid var(--white-04)'
    }
  }, /*#__PURE__*/React.createElement(YSeg, {
    segments: segsWithCount,
    value: seg,
    onChange: setSeg
  }))), /*#__PURE__*/React.createElement("div", null, list.length === 0 ? /*#__PURE__*/React.createElement(EmptyFiltered, {
    onClear: () => setSeg('all')
  }) : view === 'grid' ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 8,
      padding: 'var(--gutter-screen)'
    }
  }, list.map(it => /*#__PURE__*/React.createElement(GridCell, {
    key: it.id,
    item: it
  }))) : view === 'compact' ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '6px var(--gutter-screen) 16px'
    }
  }, list.map((it, idx) => /*#__PURE__*/React.createElement("div", {
    key: it.id
  }, idx > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: 'var(--white-06)'
    }
  }), /*#__PURE__*/React.createElement(CompactRow, {
    item: it
  })))) : /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      padding: '4px var(--gutter-screen) 16px'
    }
  }, list.map(it => /*#__PURE__*/React.createElement(ListRow, {
    key: it.id,
    item: it
  })))));
}
window.HistoryScreen = HistoryScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/vf-history.jsx", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/vf-home.jsx
try { (() => {
/* ============================================================
   VideoFixer · Asosiy (Home) — refined state-card flow
   pick → selected → processing (with stage stepper) → done
   Mirrors home_screen.dart's _buildStateCard switch.
   ============================================================ */
const {
  useState: useState,
  useEffect: useEffect
} = React;
const {
  Icon: HIcon,
  Btn: HBtn,
  Thumb: HThumb,
  Card: HCard,
  SectionLabel: HLabel
} = window;
function HomeHeader() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      paddingTop: 26
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "vf-pulse",
    style: {
      width: 76,
      height: 76,
      borderRadius: 20,
      overflow: 'hidden',
      boxShadow: 'var(--glow-red-md)'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/brand/logo.png",
    alt: "VideoFixer",
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover',
      display: 'block'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16,
      color: 'var(--text-primary)',
      fontSize: 'var(--text-6xl)',
      fontWeight: 900,
      letterSpacing: '-0.5px',
      lineHeight: 1
    }
  }, "VideoFixer"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 8,
      color: 'var(--text-tertiary)',
      fontSize: 'var(--text-sm)',
      letterSpacing: '1.5px',
      textTransform: 'uppercase'
    }
  }, "Shorts Converter"));
}

/* ---- compliance chip ---- */
function ComplianceChip({
  label,
  ok
}) {
  const color = ok ? 'var(--green-accent)' : 'var(--orange-accent)';
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      height: 28,
      padding: '0 11px 0 9px',
      borderRadius: 'var(--radius-pill)',
      background: `color-mix(in srgb, ${color} 12%, transparent)`,
      border: `1px solid color-mix(in srgb, ${color} 38%, transparent)`
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: ok ? 'check_circle' : 'warning',
    size: 15,
    fill: 1,
    color: color
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color,
      fontSize: 'var(--text-xs)',
      fontWeight: 700
    }
  }, label));
}

/* ---- PICK ---- */
function PickState({
  onPick
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '8px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "vf-pulse",
    style: {
      width: 104,
      height: 104,
      borderRadius: '50%',
      marginTop: 8,
      background: 'var(--red-06)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      border: '1px solid color-mix(in srgb, var(--red-500) 22%, transparent)'
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: "video_file",
    size: 50,
    color: "var(--red-500)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 22,
      color: 'var(--text-primary)',
      fontSize: 'var(--text-xl)',
      fontWeight: 700
    }
  }, "Video tanlash uchun bosing"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 6,
      color: 'var(--text-quaternary)',
      fontSize: 'var(--text-base)'
    }
  }, "MP4, MOV, AVI va boshqalar"), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }), /*#__PURE__*/React.createElement(HBtn, {
    icon: "video_library",
    onClick: onPick,
    glow: true,
    height: 52
  }, "Video Tanlash"));
}

/* ---- SELECTED ---- */
function SelectedState({
  volume,
  setVolume,
  onProcess,
  onReset
}) {
  const item = {
    format: 'Normal',
    tint: 'green',
    dur: '1:24'
  };
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: "video_library",
    size: 20,
    fill: 1,
    color: "var(--red-500)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--text-primary)',
      fontSize: 'var(--text-md)',
      fontWeight: 700,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, "mahsulot_sharhi_3.mp4"), /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--text-tertiary)',
      fontSize: 'var(--text-sm)',
      fontFamily: 'var(--font-mono)'
    }
  }, "142.6 MB \xB7 1:24"))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(HThumb, {
    item: item,
    radius: "var(--radius-lg)",
    showPlay: true,
    badge: false,
    dur: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement(HLabel, null, "Shorts format holati"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexWrap: 'wrap',
      gap: 8,
      marginTop: 10
    }
  }, /*#__PURE__*/React.createElement(ComplianceChip, {
    label: "Video",
    ok: true
  }), /*#__PURE__*/React.createElement(ComplianceChip, {
    label: "Audio",
    ok: true
  }), /*#__PURE__*/React.createElement(ComplianceChip, {
    label: "Davomiylik",
    ok: false
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 8,
      color: 'var(--text-disabled)',
      fontSize: 'var(--text-xs)',
      fontFamily: 'var(--font-mono)'
    }
  }, "1920\xD71080 \xB7 30fps \xB7 H264 / AAC")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginTop: 18
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: "volume_down",
    size: 18,
    color: "var(--text-quaternary)"
  }), /*#__PURE__*/React.createElement("input", {
    type: "range",
    min: "0",
    max: "3",
    step: "0.1",
    value: volume,
    onChange: e => setVolume(parseFloat(e.target.value)),
    className: "vf-range",
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(HIcon, {
    name: "volume_up",
    size: 18,
    color: "var(--text-quaternary)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 34,
      textAlign: 'right',
      color: 'var(--text-tertiary)',
      fontSize: 'var(--text-sm)',
      fontFamily: 'var(--font-mono)'
    }
  }, volume.toFixed(1), "x")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: 'var(--divider)',
      margin: '18px 0'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(HBtn, {
    icon: "bolt",
    iconColor: "var(--amber)",
    onClick: onProcess,
    glow: true
  }, "Videoni qayta ishlash"), /*#__PURE__*/React.createElement(HBtn, {
    variant: "secondary",
    icon: "movie_filter",
    iconColor: "var(--text-secondary)",
    iconFill: 0
  }, "Video Editor")), /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    onClick: onReset,
    style: {
      margin: '8px auto 0',
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      background: 'none',
      border: 'none',
      cursor: 'pointer',
      color: 'var(--text-quaternary)',
      fontSize: 'var(--text-base)',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: "refresh",
    size: 16,
    color: "var(--text-quaternary)"
  }), " Boshqa video tanlash"));
}

/* ---- PROCESSING (with stage stepper) ---- */
const STAGES = [{
  key: 'analiz',
  label: 'Analiz',
  icon: 'search',
  at: 0.0
}, {
  key: 'convert',
  label: 'Konvertatsiya',
  icon: 'autorenew',
  at: 0.18
}, {
  key: 'save',
  label: 'Saqlash',
  icon: 'save',
  at: 0.86
}];
function Stepper({
  progress
}) {
  let active = 0;
  STAGES.forEach((s, i) => {
    if (progress >= s.at) active = i;
  });
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      marginTop: 18
    }
  }, STAGES.map((s, i) => {
    const done = i < active,
      cur = i === active;
    const color = done ? 'var(--green-accent)' : cur ? 'var(--red-500)' : 'var(--text-disabled)';
    return /*#__PURE__*/React.createElement(React.Fragment, {
      key: s.key
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 7,
        width: 64
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: 34,
        height: 34,
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: cur ? 'var(--red-12)' : done ? 'color-mix(in srgb, var(--green-accent) 14%, transparent)' : 'var(--ink-700)',
        border: `1.5px solid ${cur ? 'color-mix(in srgb, var(--red-500) 50%, transparent)' : done ? 'color-mix(in srgb, var(--green-accent) 40%, transparent)' : 'var(--border-faint)'}`
      }
    }, /*#__PURE__*/React.createElement(HIcon, {
      name: done ? 'check' : s.icon,
      size: 18,
      fill: cur ? 1 : 0,
      color: color,
      style: cur ? {
        animation: 'vf-spin 1.1s linear infinite'
      } : {}
    })), /*#__PURE__*/React.createElement("span", {
      style: {
        color,
        fontSize: 'var(--text-2xs)',
        fontWeight: cur ? 700 : 500,
        textAlign: 'center'
      }
    }, s.label)), i < STAGES.length - 1 && /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        height: 2,
        marginTop: 16,
        borderRadius: 1,
        background: i < active ? 'var(--green-accent)' : 'var(--ink-500)'
      }
    }));
  }));
}
function ProcessingState({
  progress
}) {
  const pct = Math.round(progress * 100);
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 56,
      height: 36,
      borderRadius: 8,
      overflow: 'hidden',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement(HThumb, {
    item: {
      format: 'Shorts',
      tint: 'red'
    },
    radius: "8px",
    badge: false,
    dur: false
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--text-secondary)',
      fontSize: 'var(--text-base)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, "mahsulot_sharhi_3.mp4")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline',
      marginTop: 20
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-secondary)',
      fontSize: 'var(--text-base)',
      fontWeight: 500
    }
  }, "Jarayon"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--red-400)',
      fontSize: 'var(--text-base)',
      fontWeight: 700,
      fontFamily: 'var(--font-mono)'
    }
  }, pct, "%")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 10,
      borderRadius: 8,
      background: 'var(--ink-500)',
      overflow: 'hidden',
      marginTop: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      width: `${pct}%`,
      borderRadius: 8,
      background: 'var(--grad-cta)',
      transition: 'width 220ms linear'
    }
  })), /*#__PURE__*/React.createElement(Stepper, {
    progress: progress
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginTop: 18,
      padding: 12,
      borderRadius: 'var(--radius-lg)',
      background: 'var(--surface-inset)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "vf-spin",
    style: {
      width: 14,
      height: 14,
      borderRadius: '50%',
      border: '2px solid var(--red-400)',
      borderTopColor: 'transparent',
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-secondary)',
      fontSize: 'var(--text-base)',
      lineHeight: 1.5
    }
  }, "Video Shorts formatiga o\u2018tkazilmoqda \u2014 9:16, 1080\xD71920")));
}

/* ---- DONE ---- */
function DoneState({
  onReset
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 64,
      height: 64,
      borderRadius: '50%',
      marginTop: 6,
      background: 'color-mix(in srgb, var(--green-accent) 14%, transparent)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: 'var(--glow-success)'
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: "check_circle",
    size: 40,
    fill: 1,
    color: "var(--green-accent)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14,
      color: 'var(--text-primary)',
      fontSize: 'var(--text-2xl)',
      fontWeight: 700
    }
  }, "Muvaffaqiyatli tayyor!"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 6,
      color: 'var(--text-tertiary)',
      fontSize: 'var(--text-base)',
      textAlign: 'center'
    }
  }, "Fayl saqlandi va Tarixga qo\u2018shildi."), /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      marginTop: 18,
      padding: 12,
      borderRadius: 'var(--radius-lg)',
      background: 'var(--surface-inset)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      color: 'var(--text-quaternary)',
      fontSize: 'var(--text-xs)'
    }
  }, /*#__PURE__*/React.createElement(HIcon, {
    name: "folder",
    size: 14,
    color: "var(--text-quaternary)"
  }), "Downloads/VideoFixer/"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 4,
      color: 'var(--text-primary)',
      fontSize: 'var(--text-md)',
      fontWeight: 600,
      fontFamily: 'var(--font-mono)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, "mahsulot_sharhi_3_shorts.mp4")), /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      marginTop: 18
    }
  }, /*#__PURE__*/React.createElement(HBtn, {
    variant: "success",
    icon: "cloud_upload"
  }, "YouTube'ga yuklash"), /*#__PURE__*/React.createElement(HBtn, {
    variant: "secondary",
    icon: "refresh",
    iconFill: 0,
    iconColor: "var(--text-secondary)",
    onClick: onReset
  }, "Yangi Video")));
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
function HomeScreen({
  state,
  setState
}) {
  const [volume, setVolume] = useState(1.0);
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    if (state !== 'processing') return;
    setProgress(0);
    let p = 0;
    const t = setInterval(() => {
      p += 0.0125 + Math.random() * 0.02;
      if (p >= 1) {
        p = 1;
        setProgress(1);
        clearInterval(t);
        setTimeout(() => setState('done'), 480);
      } else setProgress(p);
    }, 90);
    return () => clearInterval(t);
  }, [state]);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      background: 'var(--surface-app)',
      padding: '0 var(--gutter-screen) 28px'
    }
  }, /*#__PURE__*/React.createElement(HomeHeader, null), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }), /*#__PURE__*/React.createElement(HCard, {
    pad: 22,
    radius: "var(--radius-4xl)",
    border: borderForState(state),
    glow: glowForState(state),
    bg: "var(--surface-card)"
  }, state === 'pick' && /*#__PURE__*/React.createElement(PickState, {
    onPick: () => setState('selected')
  }), state === 'selected' && /*#__PURE__*/React.createElement(SelectedState, {
    volume: volume,
    setVolume: setVolume,
    onProcess: () => setState('processing'),
    onReset: () => setState('pick')
  }), state === 'processing' && /*#__PURE__*/React.createElement(ProcessingState, {
    progress: progress
  }), state === 'done' && /*#__PURE__*/React.createElement(DoneState, {
    onReset: () => setState('pick')
  })));
}
window.HomeScreen = HomeScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/vf-home.jsx", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/vf-kit.jsx
try { (() => {
/* ============================================================
   VideoFixer · Mobile-app UI kit — shared primitives (VFKit)
   Inline-styled against the design-system CSS variables.
   All exports go on window for the babel screen modules.
   ============================================================ */
const {
  useState,
  useRef,
  useEffect,
  useCallback
} = React;

/* ---- Icon — Material Symbols Rounded ---------------------- */
function Icon({
  name,
  fill = 0,
  size = 24,
  color = 'currentColor',
  weight = 400,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: size,
      color,
      lineHeight: 1,
      flexShrink: 0,
      fontVariationSettings: `'FILL' ${fill}, 'wght' ${weight}, 'GRAD' 0, 'opsz' ${size > 36 ? 40 : 24}`,
      userSelect: 'none',
      ...style
    }
  }, name);
}

/* ---- Button — brand variants, scale-on-press -------------- */
const VF_BTN = {
  primary: {
    bg: 'var(--primary)',
    fg: '#fff'
  },
  success: {
    bg: 'var(--green-spotify)',
    fg: '#fff'
  },
  info: {
    bg: 'var(--blue-accent)',
    fg: '#fff'
  },
  secondary: {
    bg: 'var(--ink-450)',
    fg: 'var(--text-primary)'
  },
  ghost: {
    bg: 'transparent',
    fg: 'var(--text-quaternary)'
  }
};
function Btn({
  variant = 'primary',
  icon,
  iconColor,
  iconFill = 1,
  children,
  onClick,
  full = true,
  height = 50,
  disabled = false,
  glow = false,
  style = {}
}) {
  const v = VF_BTN[variant] || VF_BTN.primary;
  return /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    onClick: disabled ? undefined : onClick,
    style: {
      width: full ? '100%' : 'auto',
      height,
      border: 'none',
      outline: 'none',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 10,
      padding: '0 18px',
      borderRadius: 'var(--radius-xl)',
      cursor: disabled ? 'default' : 'pointer',
      background: disabled ? 'var(--white-12)' : v.bg,
      color: disabled ? 'var(--text-disabled)' : v.fg,
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-lg)',
      fontWeight: 700,
      letterSpacing: 0.2,
      boxShadow: glow && !disabled ? 'var(--glow-red-md)' : 'none',
      opacity: disabled ? 0.85 : 1,
      transition: 'background var(--dur-fast) var(--ease-standard)',
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(Icon, {
    name: icon,
    size: 20,
    fill: iconFill,
    color: iconColor || (disabled ? 'var(--text-disabled)' : v.fg)
  }), children);
}

/* ---- Icon button (app-bar actions) ------------------------ */
function IconBtn({
  name,
  fill = 0,
  size = 22,
  color = 'var(--text-secondary)',
  onClick,
  badge,
  title,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    onClick: onClick,
    title: title,
    style: {
      position: 'relative',
      width: 44,
      height: 44,
      borderRadius: 'var(--radius-pill)',
      border: 'none',
      background: 'transparent',
      cursor: 'pointer',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      ...style
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: name,
    size: size,
    fill: fill,
    color: color
  }), badge != null && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 5,
      right: 4,
      minWidth: 16,
      height: 16,
      padding: '0 4px',
      borderRadius: 'var(--radius-pill)',
      background: 'var(--blue-accent)',
      color: '#fff',
      fontSize: 9,
      fontWeight: 700,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      border: '2px solid var(--ink-650)',
      boxSizing: 'content-box'
    }
  }, badge));
}

/* ---- Status chip — colored dot + clean label -------------- */
function StatusChip({
  state,
  pulse = false,
  small = false
}) {
  const m = window.VFData.STATUS[state] || window.VFData.STATUS.not_uploaded;
  const live = pulse || state === 'uploading' || state === 'queued';
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      height: small ? 20 : 22,
      padding: small ? '0 8px 0 7px' : '0 10px 0 8px',
      borderRadius: 'var(--radius-pill)',
      background: `color-mix(in srgb, ${m.color} 13%, transparent)`,
      border: `1px solid color-mix(in srgb, ${m.color} 36%, transparent)`
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: '50%',
      background: m.color,
      flexShrink: 0,
      animation: live ? 'vf-statusdot 1.4s var(--ease-standard) infinite' : 'none'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: m.color,
      fontSize: small ? 10 : 'var(--text-xs)',
      fontWeight: 700,
      letterSpacing: 0.2,
      whiteSpace: 'nowrap'
    }
  }, m.label));
}

/* ---- Thumbnail — faithful tinted-icon fallback ------------ */
function Thumb({
  item,
  radius = 'var(--radius-sm)',
  ar = '16 / 9',
  showPlay = false,
  badge = true,
  dur = true
}) {
  const isShorts = item.format === 'Shorts';
  const tint = item.tint === 'green' ? 'var(--green-accent)' : 'var(--red-500)';
  const glyph = isShorts ? 'bolt' : 'video_library';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      aspectRatio: ar,
      width: '100%',
      borderRadius: radius,
      overflow: 'hidden',
      background: `linear-gradient(150deg, color-mix(in srgb, ${tint} 15%, var(--ink-700)) 0%, var(--ink-850) 78%)`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: glyph,
    size: ar === '16 / 9' ? 30 : 40,
    fill: 1,
    color: `color-mix(in srgb, ${tint} 70%, var(--white-30))`
  }), showPlay && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      width: 40,
      height: 40,
      borderRadius: '50%',
      background: 'rgba(0,0,0,0.42)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backdropFilter: 'blur(2px)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "play_arrow",
    size: 24,
    fill: 1,
    color: "#fff"
  })), badge && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 6,
      left: 6,
      padding: '1px 6px',
      borderRadius: 4,
      background: isShorts ? 'var(--red-500)' : 'color-mix(in srgb, var(--green-spotify) 90%, #000)',
      color: '#fff',
      fontSize: 9,
      fontWeight: 800,
      letterSpacing: 0.3
    }
  }, isShorts ? 'SHORTS' : 'VIDEO'), dur && item.dur && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      bottom: 6,
      right: 6,
      padding: '1px 6px',
      borderRadius: 4,
      background: 'rgba(0,0,0,0.66)',
      color: '#fff',
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      fontWeight: 500,
      letterSpacing: 0.2
    }
  }, item.dur));
}

/* ---- Section label (screen sub-headers) ------------------- */
function SectionLabel({
  children,
  icon,
  color = 'var(--text-tertiary)',
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 7,
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(Icon, {
    name: icon,
    size: 16,
    color: color
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color,
      fontSize: 'var(--text-sm)',
      fontWeight: 600,
      letterSpacing: 0.3,
      textTransform: 'none'
    }
  }, children));
}

/* ---- Segmented filter row (always-visible status filter) -- */
function SegRow({
  segments,
  value,
  onChange
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      padding: '0 var(--gutter-screen)',
      overflowX: 'auto',
      scrollbarWidth: 'none',
      WebkitOverflowScrolling: 'touch'
    }
  }, segments.map(s => {
    const on = s.value === value;
    const accent = s.color || 'var(--primary)';
    return /*#__PURE__*/React.createElement("button", {
      key: s.value,
      className: "vf-pressable",
      onClick: () => onChange(s.value),
      style: {
        flex: '0 0 auto',
        height: 34,
        padding: '0 14px',
        borderRadius: 'var(--radius-pill)',
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        cursor: 'pointer',
        border: on ? `1px solid color-mix(in srgb, ${accent} 55%, transparent)` : '1px solid var(--border-faint)',
        background: on ? `color-mix(in srgb, ${accent} 15%, transparent)` : 'var(--ink-700)',
        color: on ? accent : 'var(--text-secondary)',
        fontFamily: 'var(--font-sans)',
        fontSize: 'var(--text-sm)',
        fontWeight: on ? 700 : 500,
        whiteSpace: 'nowrap',
        transition: 'all var(--dur-fast) var(--ease-standard)'
      }
    }, s.dot && /*#__PURE__*/React.createElement("span", {
      style: {
        width: 6,
        height: 6,
        borderRadius: '50%',
        background: on ? accent : 'var(--text-quaternary)'
      }
    }), s.label, s.count != null && /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 11,
        fontWeight: 700,
        fontFamily: 'var(--font-mono)',
        color: on ? accent : 'var(--text-quaternary)',
        opacity: 0.9
      }
    }, s.count));
  }));
}

/* ---- Card surface ----------------------------------------- */
function Card({
  children,
  pad = 16,
  border = 'var(--border-faint)',
  bg = 'var(--surface-card)',
  radius = 'var(--radius-2xl)',
  glow,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: bg,
      borderRadius: radius,
      border: `1px solid ${border}`,
      padding: pad,
      boxShadow: glow || 'none',
      ...style
    }
  }, children);
}

/* ---- Avatar (channel initials) ---------------------------- */
function Avatar({
  initials,
  hue = 0,
  size = 44
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      height: size,
      borderRadius: '50%',
      flexShrink: 0,
      background: hue === 0 ? 'linear-gradient(140deg, var(--red-600), var(--red-700))' : `linear-gradient(140deg, hsl(${hue} 60% 42%), hsl(${hue} 55% 28%))`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: '#fff',
      fontWeight: 700,
      fontSize: size * 0.36,
      letterSpacing: 0.3
    }
  }, initials);
}

/* ---- Toggle switch (Material) ----------------------------- */
function Switch({
  on,
  onChange
}) {
  return /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    onClick: () => onChange(!on),
    style: {
      width: 46,
      height: 28,
      borderRadius: 'var(--radius-pill)',
      border: 'none',
      cursor: 'pointer',
      padding: 2,
      background: on ? 'var(--primary)' : 'var(--ink-450)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: on ? 'flex-end' : 'flex-start',
      transition: 'background var(--dur-fast) var(--ease-standard)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 24,
      height: 24,
      borderRadius: '50%',
      background: '#fff',
      boxShadow: '0 1px 3px rgba(0,0,0,0.4)',
      transition: 'all var(--dur-fast) var(--ease-standard)'
    }
  }));
}
Object.assign(window, {
  Icon,
  Btn,
  IconBtn,
  StatusChip,
  Thumb,
  SectionLabel,
  SegRow,
  Card,
  Avatar,
  Switch
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/vf-kit.jsx", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/vf-settings.jsx
try { (() => {
/* ============================================================
   VideoFixer · Sozlamalar (Settings) — YouTube channels
   Mirrors settings_screen.dart: connected-account cards with
   subs/videos, active toggle, per-channel settings, and the
   Google connect CTA. Refined into cleaner channel cards.
   ============================================================ */
const {
  useState: useState
} = React;
const {
  Icon: SIcon,
  IconBtn: SIconBtn,
  Avatar: SAvatar,
  Switch: SSwitch,
  Card: SCard
} = window;
function GoogleMark({
  size = 22
}) {
  // Faithful fallback for the app's missing assets/google_logo.png
  // (its errorBuilder renders a blue "G").
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: size,
      height: size,
      borderRadius: '50%',
      background: '#fff',
      border: '1px solid #e3e3e3',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'var(--font-sans)',
      fontWeight: 700,
      fontSize: size * 0.72,
      color: '#4285F4',
      lineHeight: 1
    }
  }, "G");
}
function ChannelCard({
  ch,
  onToggle
}) {
  return /*#__PURE__*/React.createElement(SCard, {
    pad: 14,
    radius: "var(--radius-2xl)",
    bg: "var(--surface-card)",
    border: "var(--white-04)"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(SAvatar, {
    initials: ch.initials,
    hue: ch.hue,
    size: 46
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 7
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-primary)',
      fontSize: 'var(--text-md)',
      fontWeight: 700,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, ch.name), ch.active ? /*#__PURE__*/React.createElement(SIcon, {
    name: "check_circle",
    size: 15,
    fill: 1,
    color: "var(--green-accent)"
  }) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 7,
      height: 7,
      borderRadius: '50%',
      background: 'var(--text-disabled)'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      marginTop: 4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      color: 'var(--text-tertiary)',
      fontSize: 'var(--text-sm)'
    }
  }, /*#__PURE__*/React.createElement(SIcon, {
    name: "group",
    size: 14,
    color: "var(--text-quaternary)"
  }), " ", ch.subs), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      color: 'var(--text-tertiary)',
      fontSize: 'var(--text-sm)'
    }
  }, /*#__PURE__*/React.createElement(SIcon, {
    name: "smart_display",
    size: 14,
    color: "var(--text-quaternary)"
  }), " ", ch.videos))), /*#__PURE__*/React.createElement(SSwitch, {
    on: ch.active,
    onChange: () => onToggle(ch.id)
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: 'var(--divider)',
      margin: '12px 0'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    style: {
      flex: 1,
      height: 38,
      borderRadius: 'var(--radius-md)',
      cursor: 'pointer',
      background: 'var(--ink-450)',
      border: 'none',
      color: 'var(--text-secondary)',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 7,
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-sm)',
      fontWeight: 600
    }
  }, /*#__PURE__*/React.createElement(SIcon, {
    name: "tune",
    size: 16,
    color: "var(--text-secondary)"
  }), " Standart sozlamalar"), /*#__PURE__*/React.createElement(SIconBtn, {
    name: "more_vert",
    size: 20,
    color: "var(--text-tertiary)",
    style: {
      width: 38,
      height: 38,
      background: 'var(--ink-450)',
      borderRadius: 'var(--radius-md)'
    }
  })));
}
function SettingsScreen() {
  const [channels, setChannels] = useState(window.VFData.CHANNELS.map(c => ({
    ...c
  })));
  const toggle = id => setChannels(cs => cs.map(c => c.id === id ? {
    ...c,
    active: !c.active
  } : c));
  const activeCount = channels.filter(c => c.active).length;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      background: 'var(--surface-app)',
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      background: 'var(--surface-card)',
      display: 'flex',
      alignItems: 'center',
      padding: '0 var(--gutter-screen)',
      position: 'sticky',
      top: 0,
      zIndex: 5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-primary)',
      fontSize: 'var(--text-2xl)',
      fontWeight: 700
    }
  }, "YouTube Sozlamalari")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 'var(--gutter-screen)',
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-primary)',
      fontSize: 'var(--text-2xl)',
      fontWeight: 700
    }
  }, "YouTube Kanallari"), /*#__PURE__*/React.createElement("span", {
    style: {
      minWidth: 22,
      height: 22,
      padding: '0 7px',
      borderRadius: 'var(--radius-pill)',
      background: 'var(--red-12)',
      border: '1px solid color-mix(in srgb, var(--red-500) 35%, transparent)',
      color: 'var(--red-400)',
      fontSize: 'var(--text-xs)',
      fontWeight: 700,
      fontFamily: 'var(--font-mono)',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, activeCount, "/", channels.length)), channels.map(ch => /*#__PURE__*/React.createElement(ChannelCard, {
    key: ch.id,
    ch: ch,
    onToggle: toggle
  })), /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    style: {
      height: 52,
      borderRadius: 'var(--radius-xl)',
      cursor: 'pointer',
      marginTop: 4,
      background: '#fff',
      border: 'none',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 10,
      boxShadow: 'var(--shadow-card)',
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-lg)',
      fontWeight: 700,
      color: '#202124'
    }
  }, /*#__PURE__*/React.createElement(GoogleMark, {
    size: 22
  }), " Google orqali ulash"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 7,
      justifyContent: 'center',
      marginTop: 2
    }
  }, /*#__PURE__*/React.createElement(SIcon, {
    name: "lock",
    size: 13,
    color: "var(--text-disabled)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-disabled)',
      fontSize: 'var(--text-xs)'
    }
  }, "Ulanish faqat yuklash uchun ishlatiladi"))));
}
window.SettingsScreen = SettingsScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/vf-settings.jsx", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/vf-shell.jsx
try { (() => {
/* ============================================================
   VideoFixer · Mobile-app shell
   Dark Android bezel + status bar + gesture pill, and the
   Material 3 NavigationBar (Asosiy / Videolar / Sozlamalar)
   with the live green processing dot and blue queue badge.
   ============================================================ */
const {
  useState: useState,
  useRef: useRef,
  useEffect: useEffect
} = React;
const {
  Icon: AIcon
} = window;
function StatusBar() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 34,
      flexShrink: 0,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 18px',
      position: 'relative',
      background: 'var(--surface-app)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: '#fff',
      fontSize: 13,
      fontWeight: 600,
      fontFamily: 'var(--font-sans)',
      letterSpacing: 0.3
    }
  }, "9:30"), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      top: 9,
      transform: 'translateX(-50%)',
      width: 9,
      height: 9,
      borderRadius: '50%',
      background: '#000',
      border: '2px solid #181818'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 5
    }
  }, /*#__PURE__*/React.createElement(AIcon, {
    name: "signal_cellular_alt",
    size: 15,
    fill: 1,
    color: "#fff"
  }), /*#__PURE__*/React.createElement(AIcon, {
    name: "wifi",
    size: 15,
    fill: 1,
    color: "#fff"
  }), /*#__PURE__*/React.createElement(AIcon, {
    name: "battery_full",
    size: 16,
    fill: 1,
    color: "#fff",
    style: {
      transform: 'rotate(90deg)'
    }
  })));
}
const TABS = [{
  key: 0,
  label: 'Asosiy',
  icon: 'home'
}, {
  key: 1,
  label: 'Videolar',
  icon: 'history'
}, {
  key: 2,
  label: 'Sozlamalar',
  icon: 'settings'
}];
function NavDest({
  tab,
  active,
  onClick,
  processing,
  queue
}) {
  return /*#__PURE__*/React.createElement("button", {
    className: "vf-pressable",
    onClick: onClick,
    style: {
      flex: 1,
      height: '100%',
      border: 'none',
      background: 'transparent',
      cursor: 'pointer',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 4,
      paddingTop: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: 64,
      height: 32,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 'var(--radius-pill)',
      background: active ? 'var(--red-25)' : 'transparent',
      transition: 'background var(--dur-fast) var(--ease-standard)'
    }
  }), /*#__PURE__*/React.createElement(AIcon, {
    name: tab.icon,
    size: 24,
    fill: active ? 1 : 0,
    color: active ? 'var(--red-500)' : 'var(--text-secondary)',
    style: {
      position: 'relative'
    }
  }), tab.key === 0 && processing && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 0,
      right: 12,
      width: 9,
      height: 9,
      borderRadius: '50%',
      background: 'var(--green-signal)',
      boxShadow: 'var(--glow-signal)',
      animation: 'vf-statusdot 1s var(--ease-standard) infinite',
      zIndex: 2
    }
  }), tab.key === 1 && queue > 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: -1,
      right: 8,
      minWidth: 16,
      height: 16,
      padding: '0 4px',
      borderRadius: 'var(--radius-pill)',
      background: 'var(--blue-accent)',
      color: '#fff',
      fontSize: 9,
      fontWeight: 700,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      border: '2px solid var(--surface-nav)',
      boxSizing: 'content-box',
      zIndex: 2
    }
  }, queue)), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-xs)',
      fontWeight: active ? 700 : 500,
      fontFamily: 'var(--font-sans)',
      color: active ? 'var(--red-500)' : 'var(--text-secondary)'
    }
  }, tab.label));
}
function App() {
  const [tab, setTab] = useState(0);
  const [homeState, setHomeState] = useState('pick');
  const scrollRef = useRef(null);
  const queueCount = window.VFData.HISTORY.filter(i => i.state === 'queued' || i.state === 'uploading').length;

  // Reset scroll to top on tab change.
  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = 0;
  }, [tab]);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 412,
      height: 880,
      borderRadius: 40,
      padding: 8,
      boxSizing: 'border-box',
      background: '#000',
      boxShadow: '0 40px 90px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.04)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      height: '100%',
      borderRadius: 32,
      overflow: 'hidden',
      background: 'var(--surface-app)',
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement(StatusBar, null), /*#__PURE__*/React.createElement("div", {
    ref: scrollRef,
    style: {
      flex: 1,
      overflowY: 'auto',
      overflowX: 'hidden',
      position: 'relative'
    }
  }, tab === 0 && /*#__PURE__*/React.createElement(window.HomeScreen, {
    state: homeState,
    setState: setHomeState
  }), tab === 1 && /*#__PURE__*/React.createElement(window.HistoryScreen, null), tab === 2 && /*#__PURE__*/React.createElement(window.SettingsScreen, null)), /*#__PURE__*/React.createElement("div", {
    style: {
      flexShrink: 0,
      height: 68,
      background: 'var(--surface-nav)',
      display: 'flex',
      boxShadow: 'var(--shadow-nav)',
      position: 'relative',
      zIndex: 10
    }
  }, TABS.map(t => /*#__PURE__*/React.createElement(NavDest, {
    key: t.key,
    tab: t,
    active: tab === t.key,
    onClick: () => setTab(t.key),
    processing: homeState === 'processing',
    queue: queueCount
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      flexShrink: 0,
      height: 18,
      background: 'var(--surface-nav)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 120,
      height: 4,
      borderRadius: 2,
      background: 'var(--white-38)'
    }
  }))));
}
window.VFApp = App;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/vf-shell.jsx", error: String((e && e.message) || e) }); }

})();
