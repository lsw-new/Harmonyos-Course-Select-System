/* Mobile admin screens — HarmonyOS phone size, Elysia rose theme */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder,
  iconBtn, tabPill, Field, Cell } = window;

/* Admin bottom tab bar */
const AdTabBar = ({active='dash'}) => {
  const tabs = [
    {id:'dash', label:'仪表', en:'Tableau', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><rect x="3" y="3" width="8" height="9" rx="2"/><rect x="13" y="3" width="8" height="5" rx="2"/><rect x="13" y="10" width="8" height="11" rx="2"/><rect x="3" y="14" width="8" height="7" rx="2"/></svg>)},
    {id:'stu', label:'学生', en:'Students', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><circle cx="9" cy="8" r="3.5"/><path d="M3 21c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.5"/><path d="M15 16c1-2 5-2 6 1"/></svg>)},
    {id:'crs', label:'课程', en:'Cours', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><path d="M4 5a2 2 0 0 1 2-2h11l3 3v15a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><path d="M8 10h8M8 14h8M8 18h5"/></svg>)},
    {id:'app', label:'审批', en:'Approve', icon:(c)=>(<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><path d="M4 6h16v12H4z"/><path d="M8 11l3 3 5-6"/></svg>)},
    {id:'me', label:'我的', en:'Madame', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>)},
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

/* ─── A1 · Admin Login ─── */
const AdminLogin = () => (
  <Phone>
    <FloralCorner style={{top:-30, left:-30}}/>
    <FloralCorner flip style={{bottom:60, right:-40}}/>
    <div className="phone-body" style={{padding:'24px 26px 0', position:'relative'}}>
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', marginTop:24}}>
        <Monogram size={72}/>
        <div style={{display:'flex', alignItems:'center', gap:6, marginTop:14}}>
          <div style={{height:1, width:30, background:'rgba(169,60,104,0.4)'}}/>
          <span style={{fontSize:10, letterSpacing:'0.4em', color:'#A93C68'}}>ADMIN · 教 务</span>
          <div style={{height:1, width:30, background:'rgba(169,60,104,0.4)'}}/>
        </div>
        <div className="font-display italic" style={{fontSize:30, color:'#A93C68', marginTop:14}}>Bonsoir,</div>
        <div className="font-display italic" style={{fontSize:30, color:'#A93C68', marginTop:-4}}>Madame.</div>
        <div style={{fontSize:11, letterSpacing:'0.35em', color:'#7A5266', marginTop:10}}>
          以 教 师 身 份 登 录
        </div>
      </div>

      <div className="divider-rose" style={{marginTop:30}}><Rose size={12}/> sign in <Rose size={12}/></div>

      <div style={{display:'flex', flexDirection:'column', gap:12}}>
        <div style={{position:'relative'}}>
          <div style={{position:'absolute', top:13, left:14}}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#D85487" strokeWidth="1.6"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="M9 6V4h6v2"/></svg>
          </div>
          <input className="input" placeholder="工号 / Faculty ID" style={{paddingLeft:38}} defaultValue="A0042"/>
        </div>
        <div style={{position:'relative'}}>
          <div style={{position:'absolute', top:13, left:14}}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#D85487" strokeWidth="1.6"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
          </div>
          <input className="input" type="password" placeholder="密码 / Password" style={{paddingLeft:38}} defaultValue="••••••••"/>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'1fr 110px', gap:8}}>
          <input className="input" placeholder="图形验证码"/>
          <div style={{
            padding:'9px 12px', borderRadius:14,
            background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)',
            display:'flex', alignItems:'center', justifyContent:'center',
            fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:20, color:'#A93C68', letterSpacing:'0.18em'
          }}>3F7A</div>
        </div>
      </div>

      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:12, fontSize:11, color:'#7A5266'}}>
        <label style={{display:'flex', alignItems:'center', gap:6}}>
          <span style={{width:14, height:14, borderRadius:4, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', display:'inline-flex', alignItems:'center', justifyContent:'center'}}>
            <svg width="9" height="9" viewBox="0 0 24 24" stroke="#fff" strokeWidth="3" fill="none"><path d="M4 12l5 5L20 6"/></svg>
          </span>
          仅限本机记住
        </label>
        <span style={{color:'#A93C68', fontStyle:'italic', fontFamily:'Cormorant Garamond, serif'}}>forgot ?</span>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:20, display:'flex', justifyContent:'center', alignItems:'center', gap:8}}>
        进 入 控 制 台 · ENTER <Sparkle size={12} color="#FFFFFF"/>
      </button>
      <div style={{textAlign:'center', marginTop:18, fontSize:10, color:'#B294A4', letterSpacing:'0.3em', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>
        — Roses ne fanent jamais —
      </div>
    </div>
  </Phone>
);

/* ─── A2 · Dashboard ─── */
const AdminDashboard = () => (
  <Phone>
    <FloralCorner style={{top:-40, right:-30}}/>
    <div style={{padding:'8px 18px 0'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between'}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <Monogram size={38}/>
          <div>
            <div style={{fontSize:11, color:'#7A5266', letterSpacing:'0.2em'}}>Bonsoir ✦</div>
            <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>艾莉萨白 · 老师</div>
          </div>
        </div>
        <div style={{display:'flex', gap:8}}>
          <button style={miniIco}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg></button>
          <button style={{...miniIco, position:'relative'}}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9z"/></svg>
            <span style={{position:'absolute', top:6, right:6, width:8, height:8, borderRadius:'50%', background:'#F2709C', boxShadow:'0 0 0 2px #FFF0F5'}}/>
          </button>
        </div>
      </div>
    </div>

    {/* Hero stats */}
    <div style={{padding:'12px 16px 0'}}>
      <div style={{
        borderRadius:24, padding:'18px',
        background:'linear-gradient(135deg, #FFC0D6 0%, #FFE0E9 40%, #EFDFFF 100%)',
        position:'relative', overflow:'hidden',
        boxShadow:'0 10px 28px -10px rgba(242,112,156,0.5)'
      }}>
        <svg width="120" height="120" viewBox="0 0 120 120" style={{position:'absolute', right:-20, top:-20, opacity:0.3}}>
          <g fill="none" stroke="#A93C68" strokeWidth="0.6">
            <circle cx="60" cy="60" r="40"/><circle cx="60" cy="60" r="30"/><circle cx="60" cy="60" r="20"/>
            <path d="M60 20v80M20 60h80"/>
          </g>
        </svg>
        <div style={{fontSize:10, letterSpacing:'0.4em', color:'#A93C68'}}>2025-2026 · AUTUMN · W 09</div>
        <div style={{display:'flex', alignItems:'baseline', gap:8, marginTop:4}}>
          <span className="font-display italic" style={{fontSize:38, color:'#A93C68', lineHeight:1}}>2,847</span>
          <span style={{fontSize:11, color:'#7A5266'}}>在校学生</span>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:8, marginTop:14}}>
          {[
            {k:'在职教师', v:'186'},
            {k:'开课门数', v:'412'},
            {k:'待审批', v:'18'},
          ].map((s,i)=>(
            <div key={i} style={{background:'rgba(255,255,255,0.55)', borderRadius:12, padding:'8px 4px', textAlign:'center'}}>
              <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>{s.v}</div>
              <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.18em'}}>{s.k}</div>
            </div>
          ))}
        </div>
      </div>
    </div>

    <div className="scroll" style={{paddingTop:14}}>
      <div className="divider-rose"><Rose size={11}/> 管 理 快 捷 <Rose size={11}/></div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:10}}>
        {[
          {ico:'✿', t:'学生'},
          {ico:'❀', t:'教师'},
          {ico:'❁', t:'课程'},
          {ico:'❃', t:'选课'},
          {ico:'❉', t:'课表'},
          {ico:'✼', t:'成绩'},
          {ico:'❋', t:'考试'},
          {ico:'❀', t:'评教'},
          {ico:'⌘', t:'审批'},
          {ico:'✉', t:'通知'},
          {ico:'⚙', t:'设置'},
          {ico:'＋', t:'更多'},
        ].map((q,i)=>(
          <div key={i} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
            <div style={{
              width:46, height:46, borderRadius:16,
              background:'linear-gradient(135deg,#FFFFFF,#FFE9F1)',
              border:'1px solid rgba(255,179,206,0.5)',
              display:'flex', alignItems:'center', justifyContent:'center',
              boxShadow:'0 4px 10px -4px rgba(242,112,156,0.35)', color:'#A93C68', fontSize:18
            }}>{q.ico}</div>
            <div style={{fontSize:10, color:'#7A5266'}}>{q.t}</div>
          </div>
        ))}
      </div>

      {/* Selection chart card */}
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:18, padding:'0 4px'}}>
        <div>
          <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Selection Trend</div>
          <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.2em'}}>选课参与 · 近 7 日</div>
        </div>
        <span className="pill" style={{fontSize:9}}>本周 +18%</span>
      </div>
      <div className="card" style={{padding:'14px', marginTop:8}}>
        <svg viewBox="0 0 320 130" style={{width:'100%', height:130}}>
          <defs>
            <linearGradient id="dlg" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#F2709C" stopOpacity="0.4"/>
              <stop offset="100%" stopColor="#F2709C" stopOpacity="0"/>
            </linearGradient>
          </defs>
          {[0,1,2,3].map(i=>(
            <line key={i} x1="22" y1={20+i*30} x2="305" y2={20+i*30} stroke="#FFD3E3" strokeWidth="0.5" strokeDasharray="3,3"/>
          ))}
          <path d="M30 100 L70 80 L110 60 L150 45 L190 30 L230 22 L270 28 L270 110 L30 110 Z" fill="url(#dlg)"/>
          <path d="M30 100 L70 80 L110 60 L150 45 L190 30 L230 22 L270 28"
            stroke="#F2709C" strokeWidth="2.2" fill="none" strokeLinecap="round"/>
          {[100,80,60,45,30,22,28].map((y,i)=>(
            <circle key={i} cx={30+i*40} cy={y} r="3.5" fill="#fff" stroke="#F2709C" strokeWidth="2"/>
          ))}
          {['周一','二','三','四','五','六','日'].map((d,i)=>(
            <text key={i} x={30+i*40} y="124" fontSize="9" fill="#7A5266" textAnchor="middle">{d}</text>
          ))}
        </svg>
      </div>

      {/* Distribution mini */}
      <div className="card-glow" style={{padding:'14px', marginTop:14, display:'flex', gap:14, alignItems:'center'}}>
        <svg width="84" height="84" viewBox="0 0 120 120" style={{transform:'rotate(-90deg)', flexShrink:0}}>
          <circle cx="60" cy="60" r="44" fill="none" stroke="rgba(255,237,245,0.6)" strokeWidth="14"/>
          <circle cx="60" cy="60" r="44" fill="none" stroke="#F2709C" strokeWidth="14" strokeDasharray="110 276" strokeLinecap="round"/>
          <circle cx="60" cy="60" r="44" fill="none" stroke="#B589FF" strokeWidth="14" strokeDasharray="82 276" strokeDashoffset="-115" strokeLinecap="round"/>
          <circle cx="60" cy="60" r="44" fill="none" stroke="#D9B675" strokeWidth="14" strokeDasharray="55 276" strokeDashoffset="-202" strokeLinecap="round"/>
        </svg>
        <div style={{flex:1}}>
          <div className="font-display italic" style={{fontSize:16, color:'#A93C68'}}>Course Mix</div>
          <div style={{fontSize:10, color:'#7A5266', marginBottom:6}}>课程类型占比</div>
          {[
            {c:'#F2709C', t:'必修', v:'40%'},
            {c:'#B589FF', t:'选修', v:'30%'},
            {c:'#D9B675', t:'公选 · 实践', v:'30%'},
          ].map((d,i)=>(
            <div key={i} style={{display:'flex', alignItems:'center', gap:6, fontSize:11, color:'#4B2A38', marginTop:3}}>
              <span style={{width:8, height:8, borderRadius:2, background:d.c}}/>
              <span style={{flex:1}}>{d.t}</span>
              <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', color:'#A93C68', fontSize:12}}>{d.v}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Approvals */}
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:18, padding:'0 4px'}}>
        <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Approvals · 待办</div>
        <span style={{fontSize:10, color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>more ›</span>
      </div>
      <div style={{display:'flex', flexDirection:'column', gap:8, marginTop:8}}>
        {[
          {t:'学籍异动', n:'王 同学 · 20231203', s:'转专业申请', urg:true, ico:'❀'},
          {t:'缓考申请', n:'李 同学 · 20231408', s:'操作系统 期末', urg:true, ico:'✿'},
          {t:'课程替代', n:'陈 同学 · 20221102', s:'高数A → 高数B', ico:'❃'},
        ].map((a,i)=>(
          <div key={i} className="card" style={{padding:'12px', display:'flex', gap:10, alignItems:'center'}}>
            <div style={{width:36, height:36, borderRadius:12, background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)', display:'flex', alignItems:'center', justifyContent:'center', color:'#A93C68', fontSize:14, flexShrink:0}}>{a.ico}</div>
            <div style={{flex:1, minWidth:0}}>
              <div style={{display:'flex', gap:5, alignItems:'center'}}>
                <span className="pill" style={{fontSize:9}}>{a.t}</span>
                {a.urg && <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#FFE0E0,#FFC8C8)', color:'#C04040', borderColor:'rgba(192,64,64,0.3)'}}>紧急</span>}
              </div>
              <div style={{fontSize:12, fontWeight:600, color:'#4B2A38', marginTop:4}}>{a.n}</div>
              <div style={{fontSize:10, color:'#7A5266', marginTop:1}}>{a.s}</div>
            </div>
            <button style={{padding:'6px 12px', borderRadius:999, fontSize:10, fontWeight:700, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', color:'#fff', border:'none'}}>处理</button>
          </div>
        ))}
      </div>

      <div style={{textAlign:'center', padding:'10px 0 16px', fontSize:10, color:'#B294A4', letterSpacing:'0.3em', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>
        — au revoir —
      </div>
    </div>
    <AdTabBar active="dash"/>
  </Phone>
);

const miniIco = {
  width:34, height:34, borderRadius:'50%',
  background:'rgba(255,255,255,0.65)', border:'1px solid rgba(255,179,206,0.6)',
  display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'
};

/* ─── A3 · Students ─── */
const AdminStudents = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Étudiants" title="学 生 管 理"
      right={<button style={miniIco}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M12 5v14M5 12h14"/></svg></button>}
    />
    <div className="scroll">
      <div style={{
        padding:'14px 16px', borderRadius:18,
        background:'linear-gradient(135deg, #FFE4EE 0%, #F1E2FF 100%)',
      }}>
        <div style={{display:'flex', alignItems:'baseline', gap:6}}>
          <span className="font-display italic" style={{fontSize:30, color:'#A93C68', lineHeight:1}}>2,847</span>
          <span style={{fontSize:11, color:'#7A5266'}}>在校学生 · 较上周 +12</span>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:6, marginTop:12}}>
          {[
            {k:'本科', v:'2,418'},
            {k:'研究生', v:'429'},
            {k:'毕业班', v:'586'},
            {k:'休学', v:'12'},
          ].map((s,i)=>(
            <div key={i} style={{background:'rgba(255,255,255,0.6)', borderRadius:10, padding:'8px 4px', textAlign:'center'}}>
              <div className="font-display italic" style={{fontSize:15, color:'#A93C68'}}>{s.v}</div>
              <div style={{fontSize:9, color:'#7A5266'}}>{s.k}</div>
            </div>
          ))}
        </div>
      </div>

      <div style={{display:'flex', gap:6, marginTop:14, alignItems:'center'}}>
        <div style={{flex:1, position:'relative'}}>
          <div style={{position:'absolute', left:12, top:11}}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>
          </div>
          <input className="input" placeholder="搜索学号 / 姓名 / 班级..." style={{paddingLeft:34}}/>
        </div>
        <button style={miniIco}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M3 6h18M6 12h12M10 18h4"/></svg></button>
      </div>

      <div style={{display:'flex', gap:6, marginTop:10, overflowX:'auto'}}>
        {['全部·2,847','软件·418','计算机·286','机械·352','外语·198'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:8, marginTop:14}}>
        {[
          {id:'20231104', n:'艾莉希雅', d:'软件学院 · 软件工程', c:'软件 2304', gpa:'3.86', s:'在籍', sc:'#3F7A4A', hl:true},
          {id:'20231105', n:'琪亚娜', d:'软件学院 · 软件工程', c:'软件 2304', gpa:'3.62', s:'在籍', sc:'#3F7A4A'},
          {id:'20231203', n:'瓦尔特', d:'计算机学院 · 计算机', c:'计算 2308', gpa:'3.40', s:'转专业中', sc:'#A93C68'},
          {id:'20231408', n:'布洛妮娅', d:'软件学院 · 软件工程', c:'软件 2305', gpa:'3.94', s:'在籍', sc:'#3F7A4A'},
          {id:'20221102', n:'希儿', d:'软件学院 · 软件工程', c:'软件 2204', gpa:'3.71', s:'在籍', sc:'#3F7A4A'},
          {id:'20221115', n:'丽塔', d:'软件学院 · 软件工程', c:'软件 2206', gpa:'—', s:'休学', sc:'#7A5266'},
          {id:'20212201', n:'符华', d:'软件学院 · 软件工程', c:'软件 2108', gpa:'3.88', s:'毕业班', sc:'#A8854A'},
        ].map((s,i)=>(
          <div key={i} className="card" style={{padding:'12px', display:'flex', gap:10, alignItems:'center', background: s.hl?'rgba(255,228,238,0.5)':undefined}}>
            <div style={{
              width:42, height:42, borderRadius:'50%',
              background:'linear-gradient(135deg,#FFD3E3,#EFDFFF)',
              display:'flex', alignItems:'center', justifyContent:'center',
              fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:17, color:'#A93C68', flexShrink:0
            }}>{s.n[0]}</div>
            <div style={{flex:1, minWidth:0}}>
              <div style={{display:'flex', alignItems:'baseline', gap:6}}>
                <span style={{fontSize:13, fontWeight:700, color:'#4B2A38'}}>{s.n}</span>
                <span style={{fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{s.id}</span>
              </div>
              <div style={{fontSize:11, color:'#7A5266', marginTop:3}}>{s.d}</div>
              <div style={{fontSize:10, color:'#B294A4', marginTop:1}}>{s.c}</div>
            </div>
            <div style={{textAlign:'right', flexShrink:0}}>
              <div className="font-display italic" style={{fontSize:18, color:'#A93C68', lineHeight:1}}>{s.gpa}</div>
              <div style={{fontSize:9, color:s.sc, marginTop:4, fontWeight:600}}>● {s.s}</div>
            </div>
          </div>
        ))}
      </div>

      <div style={{textAlign:'center', padding:'12px 0 60px', fontSize:11, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', letterSpacing:'0.2em'}}>
        显 示 1 — 7 / 共 2,847 条
      </div>
    </div>
    <AdTabBar active="stu"/>
  </Phone>
);

Object.assign(window, { AdminLogin, AdminDashboard, AdminStudents, AdTabBar, miniIco });
