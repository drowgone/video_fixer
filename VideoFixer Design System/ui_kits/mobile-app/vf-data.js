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
    uploaded:     { label: 'Yuklangan',   color: 'var(--green-accent)'  },
    not_uploaded: { label: 'Qurilmada',   color: 'var(--white-54)'      },
    processing:   { label: 'Jarayonda',   color: 'var(--orange-accent)' },
    queued:       { label: 'Navbatda',    color: 'var(--blue-accent)'   },
    uploading:    { label: 'Yuklanmoqda', color: 'var(--orange-accent)' },
    failed:       { label: 'Xato',        color: 'var(--red-accent)'    },
    deleted:      { label: "O'chirilgan", color: 'var(--red-accent)'    },
  };

  // History items — a spread across every state the app renders.
  const HISTORY = [
    { id: 1, name: 'Toshkent kechasi — shahar bo‘ylab sayohat', format: 'Shorts',
      state: 'uploaded', channel: 'Sardor Vlog', date: '24-iyun', size: '18.4 MB',
      dur: '0:48', tint: 'red' },
    { id: 2, name: 'Yangi mahsulot sharhi #3 — to‘liq versiya', format: 'Normal',
      state: 'not_uploaded', channel: '', date: 'Bugun', size: '142.6 MB',
      dur: '4:12', tint: 'green' },
    { id: 3, name: 'Jonli konsert — eng yaxshi lahzalar', format: 'Shorts',
      state: 'uploading', channel: 'Sardor Vlog', date: 'Bugun', size: '24.1 MB',
      dur: '0:59', tint: 'red', progress: 0.62 },
    { id: 4, name: 'O‘yin obzori — final jang', format: 'Shorts',
      state: 'queued', channel: '', date: 'Bugun', size: '33.0 MB',
      dur: '0:55', tint: 'red' },
    { id: 5, name: 'Retsept: bahor oshi tayyorlash', format: 'Normal',
      state: 'uploaded', channel: 'Tech Uzbek', date: '21-iyun', size: '88.2 MB',
      dur: '6:30', tint: 'green' },
    { id: 6, name: 'Reklama roliki — qayta urinish', format: 'Shorts',
      state: 'failed', channel: '', date: 'Kecha', size: '9.4 MB',
      dur: '0:30', tint: 'red' },
    { id: 7, name: 'Eski intervyu arxividan', format: 'Shorts',
      state: 'deleted', channel: 'Sardor Vlog', date: '4-iyun', size: '12.7 MB',
      dur: '0:51', tint: 'red' },
  ];

  // Connected YouTube channels (settings_provider accounts).
  const CHANNELS = [
    { id: 'a', name: 'Sardor Vlog',  subs: '12.4K', videos: 86, active: true,  initials: 'SV', hue: 0   },
    { id: 'b', name: 'Tech Uzbek',   subs: '3.2K',  videos: 41, active: true,  initials: 'TU', hue: 210 },
    { id: 'c', name: 'MVP Gaming',   subs: '540',   videos: 18, active: false, initials: 'MG', hue: 280 },
  ];

  window.VFData = { STATUS, HISTORY, CHANNELS };
})();
