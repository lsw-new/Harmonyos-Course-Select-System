/* Shared Elysia UI primitives */

const Rose = ({ size = 18, color = "#F2709C", opacity = 1, style }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={style}>
    <g opacity={opacity}>
      <path d="M12 3c2 2 2 4 1 5 2-1 4 0 5 2 1 2-1 4-3 4 2 1 3 3 2 5-1 2-3 2-5 1 1 2 0 4-2 4s-3-2-2-4c-2 1-4 1-5-1-1-2 0-4 2-5-2 0-4-2-3-4 1-2 3-3 5-2-1-1-1-3 1-5z" stroke={color} strokeWidth="1.1" strokeLinejoin="round"/>
      <circle cx="12" cy="12" r="2.4" fill={color} opacity="0.4"/>
      <circle cx="12" cy="12" r="1.1" fill={color}/>
    </g>
  </svg>
);

const Sparkle = ({ size = 12, color = "#D9B675", style }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={style}>
    <path d="M12 2 L13.6 9.4 L21 11 L13.6 12.6 L12 20 L10.4 12.6 L3 11 L10.4 9.4 Z" fill={color} />
  </svg>
);

const Heart = ({ size = 14, color = "#F2709C", style }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={color} style={style}>
    <path d="M12 21s-7-4.5-9.5-9C0.7 8 3 4 7 4c2 0 4 1 5 3 1-2 3-3 5-3 4 0 6.3 4 4.5 8C19 16.5 12 21 12 21z"/>
  </svg>
);

const StatusBar = () => (
  <div className="phone-status">
    <span className="font-display" style={{fontSize:14}}>9:24</span>
    <div className="right" style={{fontSize:11, opacity:0.8}}>
      <span>5G</span>
      <Sparkle size={10} color="#F2709C"/>
      <span>96%</span>
    </div>
  </div>
);

/* The phone shell every screen uses */
const Phone = ({ children, label, showHome = true, bgGlow = true }) => (
  <div className="phone">
    {bgGlow && (
      <>
        <div className="corner-bloom" style={{top:-30, left:-30}}></div>
        <div className="corner-bloom" style={{bottom:-30, right:-30, background:"radial-gradient(circle at 70% 70%, rgba(217,191,255,0.55), transparent 60%)"}}></div>
      </>
    )}
    <StatusBar/>
    <div className="phone-body">{children}</div>
    {showHome && (
      <div style={{position:'absolute', bottom:6, left:'50%', transform:'translateX(-50%)', width:110, height:4, borderRadius:4, background:'rgba(75,42,56,0.25)', zIndex:6}}></div>
    )}
  </div>
);

/* Common app header w/ back button */
const TopBar = ({ title, en, back = true, right }) => (
  <div className="app-header" style={{paddingTop:8}}>
    {back ? (
      <button style={{background:'rgba(255,255,255,0.6)', border:'1px solid rgba(255,179,206,0.6)', width:34, height:34, borderRadius:'50%', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'}}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="2"><path d="M15 6l-6 6 6 6"/></svg>
      </button>
    ) : <div style={{width:34}}></div>}
    <div style={{textAlign:'center', flex:1}}>
      <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>{en}</div>
      <div style={{fontSize:11, letterSpacing:'0.35em', color:'#7A5266', marginTop:2}}>{title}</div>
    </div>
    {right || <div style={{width:34}}></div>}
  </div>
);

/* Bottom tabbar */
const TabBar = ({ active = 'home' }) => {
  const tabs = [
    {id:'home', label:'首页', en:'Home', icon: (c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><path d="M3 11l9-8 9 8v9a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2z"/></svg>)},
    {id:'mine', label:'我的', en:'Mine', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>)},
    {id:'eval', label:'评教', en:'Eval', icon:(c)=>(<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><path d="M12 3 L14 9 L20 9 L15.2 13 L17 19 L12 15.5 L7 19 L8.8 13 L4 9 L10 9 Z"/></svg>)},
    {id:'pra', label:'实践', en:'Practice', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="M9 6V4h6v2M8 12h8M8 16h5"/></svg>)},
    {id:'pub', label:'公共', en:'Public', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>)},
  ];
  return (
    <div className="tabbar">
      {tabs.map(t => {
        const a = t.id === active;
        const c = a ? '#D85487' : '#B294A4';
        return (
          <div key={t.id} className={"tab" + (a ? ' active':'')}>
            <div className="ico" style={a?{filter:'drop-shadow(0 2px 6px rgba(242,112,156,0.45))'}:{}}>{t.icon(c)}</div>
            <div style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:11, color:c}}>{t.en}</div>
          </div>
        );
      })}
    </div>
  );
};

/* Placeholder image area */
const Placeholder = ({ w='100%', h=80, label='image', radius=14 }) => (
  <div style={{
    width:w, height:h, borderRadius:radius,
    background: 'repeating-linear-gradient(45deg, #FFE6EF 0 8px, #FFF1F7 8px 16px)',
    border:'1px dashed rgba(216,84,135,0.4)',
    display:'flex', alignItems:'center', justifyContent:'center',
    color:'#A93C68', fontFamily:'monospace', fontSize:10, letterSpacing:'0.2em', textTransform:'uppercase',
  }}>{label}</div>
);

/* Floral decorative SVG that sits behind page chrome */
const FloralCorner = ({ flip = false, style }) => (
  <svg viewBox="0 0 200 200" style={{
    position:'absolute', width:160, height:160,
    transform: flip ? 'scaleX(-1)' : 'none',
    opacity: 0.45, pointerEvents:'none', ...style
  }}>
    <defs>
      <radialGradient id="rg" cx="30%" cy="30%" r="80%">
        <stop offset="0%" stopColor="#FFC0D6"/>
        <stop offset="100%" stopColor="#F2709C" stopOpacity="0"/>
      </radialGradient>
    </defs>
    <circle cx="50" cy="50" r="70" fill="url(#rg)"/>
    <g fill="none" stroke="#F2709C" strokeWidth="0.8" opacity="0.7">
      <path d="M20 40 Q60 60 110 30"/>
      <path d="M10 80 Q70 100 140 60"/>
      <path d="M40 20 Q60 50 90 30"/>
      <circle cx="30" cy="40" r="6"/>
      <circle cx="60" cy="50" r="4"/>
      <circle cx="90" cy="25" r="5"/>
      <circle cx="100" cy="60" r="3"/>
    </g>
    <g fill="#F2709C" opacity="0.45">
      <circle cx="30" cy="40" r="2"/>
      <circle cx="60" cy="50" r="1.5"/>
      <circle cx="90" cy="25" r="2"/>
    </g>
  </svg>
);

/* monogram/logo */
const Monogram = ({ size = 56 }) => (
  <div style={{
    width:size, height:size, borderRadius:'50%',
    background: 'conic-gradient(from 220deg, #FFD3E3, #FFE9F1, #EFDFFF, #FFF4EB, #FFD3E3)',
    boxShadow:'0 8px 24px -8px rgba(242,112,156,0.6), inset 0 0 0 2px rgba(255,255,255,0.7)',
    display:'flex', alignItems:'center', justifyContent:'center',
    position:'relative',
  }}>
    <span style={{
      fontFamily:'Cormorant Garamond, Italiana, serif',
      fontStyle:'italic', fontSize: size*0.5, color:'#A93C68',
      textShadow:'0 1px 0 rgba(255,255,255,0.6)'
    }}>E</span>
  </div>
);

Object.assign(window, { Rose, Sparkle, Heart, StatusBar, Phone, TopBar, TabBar, Placeholder, FloralCorner, Monogram });
