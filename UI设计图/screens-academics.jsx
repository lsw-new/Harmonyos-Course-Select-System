/* Academics screens — Grades, Exam, Student Record (Roster) */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder, TabBar, iconBtn, tabPill, Cell } = window;

const GradesScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Grades" title="我 的 成 绩"
      right={<button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M3 12h18M3 6h18M3 18h18"/></svg></button>}
    />
    <div className="scroll">
      {/* Term selector */}
      <div style={{display:'flex', gap:6, overflowX:'auto', marginBottom:12}}>
        {['2025-1 当前','2024-2','2024-1','2023-2','2023-1','所有学期'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      {/* Stats card */}
      <div style={{
        borderRadius:24, padding:'18px',
        background:'linear-gradient(135deg, #FFE4EE 0%, #F1E2FF 50%, #FFF1D6 100%)',
        position:'relative', overflow:'hidden'
      }}>
        <svg width="160" height="160" viewBox="0 0 160 160" style={{position:'absolute', right:-30, top:-30, opacity:0.3}}>
          <defs><radialGradient id="g2"><stop offset="0" stopColor="#F2709C"/><stop offset="1" stopColor="#F2709C" stopOpacity="0"/></radialGradient></defs>
          <circle cx="60" cy="60" r="60" fill="url(#g2)"/>
        </svg>
        <div style={{fontSize:10, letterSpacing:'0.4em', color:'#A93C68'}}>2025-2026 · AUTUMN</div>
        <div style={{display:'flex', alignItems:'baseline', gap:8, marginTop:4}}>
          <span className="font-display italic" style={{fontSize:42, color:'#A93C68', lineHeight:1}}>3.86</span>
          <span style={{fontSize:11, color:'#7A5266'}}>学期 · GPA</span>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:8, marginTop:14}}>
          {[
            {k:'已修学分', v:'21.5'},
            {k:'加权平均', v:'89.7'},
            {k:'累计 GPA', v:'3.82'}
          ].map((s,i)=>(
            <div key={i} style={{
              background:'rgba(255,255,255,0.6)', borderRadius:14, padding:'10px 8px', textAlign:'center'
            }}>
              <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>{s.v}</div>
              <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.15em'}}>{s.k}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> records · 8 门 <Rose size={10}/></div>

      <div style={{display:'flex', flexDirection:'column', gap:10}}>
        {[
          {name:'鸿蒙应用开发综合实践', code:'SE-4023', cls:'专业拓展课程', cred:4.0, mid:88, fin:92, total:91, gpa:4.0},
          {name:'软件工程经济学', code:'SE-3041', cls:'专业选修课程', cred:2.0, mid:85, fin:90, total:88, gpa:3.7},
          {name:'操作系统', code:'CS-3022', cls:'专业必修课程', cred:3.5, mid:82, fin:88, total:86, gpa:3.5},
          {name:'近代史纲要', code:'GE-1003', cls:'通识必修课程', cred:2.0, mid:90, fin:91, total:91, gpa:4.0},
          {name:'体育 · 网球', code:'PE-2011', cls:'集中实践教学', cred:1.0, mid:'—', fin:'合格', total:'优秀', gpa:'—'},
          {name:'宋词鉴赏与吟诵', code:'GE-2031', cls:'通识选修课程', cred:1.5, mid:92, fin:94, total:93, gpa:4.0},
        ].map((g,i)=><GradeCard key={i} {...g}/>)}
      </div>

      <div style={{textAlign:'center', padding:'12px 0 16px', fontSize:11, color:'#B294A4', letterSpacing:'0.3em', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>
        — sweet rewards —
      </div>
    </div>
  </Phone>
);

const GradeCard = ({name, code, cls, cred, mid, fin, total, gpa}) => {
  const isHigh = typeof total === 'number' && total >= 90;
  return (
    <div className="card" style={{padding:'14px', position:'relative', overflow:'hidden'}}>
      {isHigh && (
        <div style={{position:'absolute', top:8, right:10, display:'flex', alignItems:'center', gap:3, fontSize:9, color:'#A8854A', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>
          <Sparkle size={10} color="#D9B675"/> excellent
        </div>
      )}
      <div style={{display:'flex', alignItems:'flex-start', gap:10}}>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontSize:13, fontWeight:700, color:'#4B2A38'}}>{name}</div>
          <div style={{fontSize:10, color:'#B294A4', marginTop:2, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{code}</div>
          <div style={{display:'flex', gap:6, marginTop:6, flexWrap:'wrap'}}>
            <span className="pill" style={{fontSize:9}}>{cls}</span>
            <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#FFF1D6,#FBE6C2)', color:'#A8854A'}}>{cred} 学分</span>
          </div>
        </div>
        <div style={{textAlign:'right', flexShrink:0}}>
          <div className="font-display italic" style={{fontSize:30, color: isHigh ? '#A93C68' : '#7A5266', lineHeight:1}}>{total}</div>
          <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.15em'}}>最终成绩</div>
        </div>
      </div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:8, marginTop:10, paddingTop:10, borderTop:'1px dashed rgba(255,179,206,0.5)'}}>
        <Mini k="期中" v={mid}/>
        <Mini k="期末" v={fin}/>
        <Mini k="绩点" v={gpa}/>
      </div>
    </div>
  );
};

const Mini = ({k,v}) => (
  <div style={{textAlign:'center'}}>
    <div style={{fontSize:13, fontWeight:600, color:'#4B2A38', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{v}</div>
    <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.2em', marginTop:2}}>{k}</div>
  </div>
);

const ExamScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Exams" title="考 试 安 排"
      right={<button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M3 10h18M8 2v4M16 2v4"/></svg></button>}
    />
    <div className="scroll">
      <div style={{display:'flex', gap:6, marginBottom:12}}>
        {['本学期','2024-2','2024-1','所有'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      <div style={{
        borderRadius:22, padding:'16px',
        background:'linear-gradient(135deg, #FFC0D6 0%, #F1E2FF 100%)',
      }}>
        <div style={{display:'flex', alignItems:'center', gap:8}}>
          <span className="pill" style={{background:'rgba(255,255,255,0.7)'}}>距下场 · 18 天</span>
          <Sparkle size={14}/>
        </div>
        <div className="font-display" style={{fontSize:22, color:'#4B2A38', fontWeight:600, marginTop:6}}>
          鸿蒙应用开发 · 期末
        </div>
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8, marginTop:14, fontSize:11, color:'#4B2A38'}}>
          <Cell k="日期" v="2026·01·07"/>
          <Cell k="时间" v="14:00–16:00"/>
          <Cell k="考场" v="软件楼 305"/>
          <Cell k="座位" v="第 02 列 第 04 排"/>
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> upcoming · 5 门 <Rose size={10}/></div>

      {[
        {date:'2026·01·07', day:'三', time:'14:00–16:00', name:'鸿蒙应用开发综合实践', room:'软305', seat:'2-04', type:'闭卷', soon:true},
        {date:'2026·01·09', day:'五', time:'09:00–11:00', name:'操作系统', room:'软201', seat:'5-12', type:'闭卷'},
        {date:'2026·01·12', day:'一', time:'14:00–16:00', name:'软件工程经济学', room:'一教 207', seat:'3-08', type:'开卷'},
        {date:'2026·01·15', day:'四', time:'09:00–11:00', name:'近代史纲要', room:'二教 102', seat:'4-15', type:'闭卷'},
        {date:'2026·01·17', day:'六', time:'14:00–16:00', name:'宋词鉴赏与吟诵', room:'文楼 305', seat:'1-06', type:'论文'},
      ].map((e,i)=>(
        <div key={i} className="card" style={{padding:'14px', marginBottom:10, display:'flex', gap:14}}>
          <div style={{
            width:60, flexShrink:0, padding:'8px 4px', borderRadius:14,
            background:`linear-gradient(180deg, ${e.soon?'#FFD3E3':'#FFE4EE'}, ${e.soon?'#FFB4CE':'#F1E2FF'})`,
            textAlign:'center',
            border: e.soon ? '1px solid rgba(242,112,156,0.4)' : 'none'
          }}>
            <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.15em'}}>JAN</div>
            <div className="font-display italic" style={{fontSize:22, color:'#A93C68', lineHeight:1}}>{e.date.slice(-2)}</div>
            <div style={{fontSize:9, color:'#A93C68', marginTop:3}}>周 {e.day}</div>
          </div>
          <div style={{flex:1, minWidth:0}}>
            <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-start'}}>
              <div style={{fontSize:13, fontWeight:700, color:'#4B2A38'}}>{e.name}</div>
              <span className="pill" style={{fontSize:9, flexShrink:0}}>{e.type}</span>
            </div>
            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:4, marginTop:8, fontSize:11, color:'#7A5266'}}>
              <span>🕐 {e.time}</span>
              <span>📍 {e.room}</span>
              <span style={{gridColumn:'span 2'}}>🪑 座位 · {e.seat}</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  </Phone>
);

const RosterScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Roster" title="学 籍 信 息"/>
    <div className="scroll">
      <div style={{display:'flex', gap:6, marginBottom:12}}>
        {['学籍信息','资料申请','联系信息'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      {/* Avatar card */}
      <div style={{
        position:'relative',
        borderRadius:22, padding:'18px',
        background:'linear-gradient(135deg, #FFE4EE 0%, #EFDFFF 100%)',
        display:'flex', gap:14, alignItems:'center',
      }}>
        <div style={{
          width:84, height:108, borderRadius:12,
          background:'repeating-linear-gradient(45deg, #FFD3E3 0 6px, #FFE9F1 6px 12px)',
          border:'2px solid #fff',
          boxShadow:'0 6px 18px -6px rgba(242,112,156,0.5)',
          display:'flex', alignItems:'center', justifyContent:'center',
          color:'#A93C68', fontFamily:'monospace', fontSize:9, letterSpacing:'0.2em'
        }}>PHOTO</div>
        <div style={{flex:1}}>
          <div className="font-display italic" style={{fontSize:22, color:'#A93C68'}}>Elysia · 同学</div>
          <div style={{fontSize:11, color:'#7A5266', marginTop:4}}>软件学院 · 软件工程</div>
          <div style={{fontSize:10, color:'#B294A4', marginTop:2, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>SE-2023-04 · 20231104</div>
          <div style={{display:'flex', gap:6, marginTop:8}}>
            <span className="pill" style={{fontSize:9}}>在籍</span>
            <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#E6F7E6,#D8F0D8)', color:'#3F7A4A'}}>在校</span>
          </div>
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> 基本档案 <Rose size={10}/></div>

      <div className="card" style={{padding:'4px 14px'}}>
        {[
          ['学号','20231104'],
          ['姓名','艾莉希雅'],
          ['英文名','Elysia'],
          ['性别','女'],
          ['年级','2023 级'],
          ['学制','四年'],
          ['项目 · 学历','本科 · 本科'],
          ['学生类别','普通全日制'],
          ['专业','软件工程'],
          ['院系','软件学院'],
          ['行政院系','软件学院'],
          ['方向','移动应用'],
          ['班级','软件 2304 班'],
          ['入校时间','2023·09·01'],
          ['毕业时间','2027·07 (预)'],
          ['学习形式','普通'],
          ['是否在籍 / 在校','是 / 是'],
          ['所属校区','花江校区'],
          ['学籍状态','正常'],
          ['学籍生效日期','2023·09·01'],
          ['是否在职','否'],
          ['备注','—'],
        ].map(([k,v],i)=>(
          <div key={i} style={{display:'flex', justifyContent:'space-between', padding:'10px 0', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none', fontSize:12}}>
            <span style={{color:'#7A5266'}}>{k}</span>
            <span style={{color:'#4B2A38', fontWeight:600}}>{v}</span>
          </div>
        ))}
      </div>

      <div style={{height:30}}/>
    </div>
  </Phone>
);

Object.assign(window, { GradesScreen, ExamScreen, RosterScreen });
