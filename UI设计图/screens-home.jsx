/* Home screens — Workbench, Today's courses, Notifications, Notification detail */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder, TabBar } = window;

const HomeScreen = () => (
  <Phone>
    <FloralCorner style={{top:-40, right:-30}}/>
    <div style={{padding:'8px 18px 0', position:'relative'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between'}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <Monogram size={38}/>
          <div>
            <div style={{fontSize:11, color:'#7A5266', letterSpacing:'0.2em'}}>Bonjour ✦</div>
            <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Elysia · 同学</div>
          </div>
        </div>
        <div style={{display:'flex', gap:8}}>
          <button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg></button>
          <button style={{...iconBtn, position:'relative'}}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9z"/><path d="M10 21a2 2 0 0 0 4 0"/></svg>
            <span style={{position:'absolute', top:6, right:6, width:8, height:8, borderRadius:'50%', background:'#F2709C', boxShadow:'0 0 0 2px #FFF0F5'}}></span>
          </button>
        </div>
      </div>
    </div>

    {/* Hero card — current term & week */}
    <div style={{padding:'12px 16px 0'}}>
      <div style={{
        position:'relative', overflow:'hidden',
        borderRadius:24, padding:'18px 18px',
        background:'linear-gradient(135deg, #FFC0D6 0%, #FFE0E9 40%, #EFDFFF 100%)',
        boxShadow:'0 10px 28px -10px rgba(242,112,156,0.5)',
      }}>
        <svg width="120" height="120" viewBox="0 0 120 120" style={{position:'absolute', right:-20, top:-20, opacity:0.35}}>
          <g fill="none" stroke="#A93C68" strokeWidth="0.6">
            <circle cx="60" cy="60" r="40"/>
            <circle cx="60" cy="60" r="30"/>
            <circle cx="60" cy="60" r="20"/>
            <circle cx="60" cy="60" r="10"/>
            <path d="M60 20v80M20 60h80M30 30l60 60M90 30l-60 60"/>
          </g>
        </svg>
        <div style={{fontSize:10, letterSpacing:'0.4em', color:'#A93C68'}}>2025 — 2026 · AUTUMN</div>
        <div style={{display:'flex', alignItems:'baseline', gap:8, marginTop:2}}>
          <span className="font-display italic" style={{fontSize:48, color:'#A93C68', lineHeight:1}}>W 09</span>
          <span style={{fontSize:11, color:'#7A5266'}}>第九教学周 · Monday</span>
        </div>
        <div style={{display:'flex', gap:6, marginTop:14}}>
          {['一','二','三','四','五','六','日'].map((d,i)=>(
            <div key={i} style={{
              flex:1, textAlign:'center', padding:'6px 0',
              borderRadius:10,
              background: i===0 ? 'linear-gradient(135deg,#F2709C,#E08AB8)' : 'rgba(255,255,255,0.55)',
              color: i===0 ? '#fff' : '#A93C68',
              fontSize:11, fontWeight:600
            }}>
              <div style={{fontSize:9, opacity:0.8}}>{d}</div>
              <div style={{marginTop:2, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:14}}>{20+i}</div>
            </div>
          ))}
        </div>
      </div>
    </div>

    <div className="scroll" style={{paddingTop:14}}>
      {/* Quick entries */}
      <div className="divider-rose"><Rose size={11}/> quick entrance <Rose size={11}/></div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:10}}>
        {[
          {en:'Schedule', zh:'我的课表', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 9h18M8 3v4M16 3v4"/></svg>)},
          {en:'Grades', zh:'我的成绩', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><path d="M4 18V6a2 2 0 0 1 2-2h11l3 3v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><path d="M9 13l2 2 4-5"/></svg>)},
          {en:'Select', zh:'选课中心', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><path d="M4 7h16M4 12h16M4 17h10"/><circle cx="19" cy="17" r="2"/></svg>)},
          {en:'Eval.', zh:'量化评教', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><path d="M12 3l2.5 6L21 9.5l-5 4.5 1.5 6.5L12 17l-5.5 3.5L8 14l-5-4.5L9.5 9z"/></svg>)},
          {en:'Exam', zh:'考试安排', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h4"/></svg>)},
          {en:'Notice', zh:'通知公告', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><path d="M4 11l16-7v16L4 13z"/><path d="M8 13v3a2 2 0 0 0 4 0"/></svg>)},
          {en:'Records', zh:'学籍信息', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5"><circle cx="12" cy="9" r="3.5"/><path d="M5 21c0-3 3-6 7-6s7 3 7 6"/><path d="M4 4h16v3H4z"/></svg>)},
          {en:'+', zh:'添加', icon:(c)=>(<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6"><path d="M12 5v14M5 12h14"/></svg>)},
        ].map((q,i)=>(
          <div key={i} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
            <div style={{
              width:46, height:46, borderRadius:16,
              background: i===7 ? 'rgba(255,255,255,0.6)' : 'linear-gradient(135deg, #FFFFFF 0%, #FFE9F1 100%)',
              border:'1px solid rgba(255,179,206,0.5)',
              display:'flex', alignItems:'center', justifyContent:'center',
              boxShadow:'0 4px 10px -4px rgba(242,112,156,0.35)'
            }}>{q.icon('#D85487')}</div>
            <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.05em'}}>{q.zh}</div>
          </div>
        ))}
      </div>

      {/* Today's courses */}
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:18, padding:'0 4px'}}>
        <div>
          <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Today's Lessons</div>
          <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.2em'}}>10·20 周一 · 共 3 节</div>
        </div>
        <span style={{fontSize:10, color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>view all ›</span>
      </div>
      <div style={{display:'flex', flexDirection:'column', gap:10, marginTop:10}}>
        <TodayCard time="08:00–09:35" period="1-2 节" name="鸿蒙应用开发综合实践" room="软件楼 · 305" teacher="林 · 老师" tag="必修" hue="rose"/>
        <TodayCard time="10:00–11:35" period="3-4 节" name="软件工程经济学" room="一教 · 207" teacher="苏 · 老师" tag="选修" hue="lav"/>
        <TodayCard time="14:00–15:35" period="5-6 节" name="近代史纲要" room="二教 · 102" teacher="周 · 老师" tag="公选" hue="gold"/>
      </div>

      {/* Notice */}
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:18, padding:'0 4px'}}>
        <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>From the Hall</div>
        <span style={{fontSize:10, color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>more ›</span>
      </div>
      <div className="card-glow" style={{marginTop:8, padding:'12px 14px'}}>
        {[
          {tag:'教务处', title:'2025-2026学年第一学期期中教学检查通知', time:'10·18'},
          {tag:'学生处', title:'关于做好秋季校园安全自查工作的通知', time:'10·15'},
          {tag:'图书馆', title:'十月主题书展《玫瑰与少女》开放借阅', time:'10·12'},
        ].map((n,i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'8px 0', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none'}}>
            <span className="pill" style={{flexShrink:0}}>{n.tag}</span>
            <div style={{flex:1, fontSize:12, color:'#4B2A38', lineHeight:1.3}}>{n.title}</div>
            <div style={{fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{n.time}</div>
          </div>
        ))}
      </div>

      {/* Files */}
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:18, padding:'0 4px'}}>
        <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Atelier · 资料下载</div>
      </div>
      <div className="card-glow" style={{marginTop:8, padding:'12px 14px', display:'grid', gridTemplateColumns:'1fr 1fr', gap:10}}>
        <FileBubble name="2025-2026 校历.pdf" date="2025·08·30"/>
        <FileBubble name="课表模板.pdf" date="2025·09·02"/>
      </div>

      {/* Last login */}
      <div style={{marginTop:18, padding:'10px 14px', borderRadius:14, background:'rgba(255,255,255,0.55)', border:'1px dashed rgba(255,179,206,0.6)', display:'flex', alignItems:'center', gap:10}}>
        <Sparkle size={14}/>
        <div style={{fontSize:11, color:'#7A5266', lineHeight:1.4}}>
          上次登录 · 10·19 23:47 · 校园网 · 桂林
        </div>
      </div>
    </div>
    <TabBar active="home"/>
  </Phone>
);

const iconBtn = {
  width:34, height:34, borderRadius:'50%',
  background:'rgba(255,255,255,0.65)', border:'1px solid rgba(255,179,206,0.6)',
  display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer'
};

const TodayCard = ({time, period, name, room, teacher, tag, hue}) => {
  const palettes = {
    rose:{from:'#FFE4EE', to:'#FFD3E3', stroke:'#F2709C'},
    lav:{from:'#F1E2FF', to:'#E2C4FF', stroke:'#B589FF'},
    gold:{from:'#FFF1D6', to:'#FBE6C2', stroke:'#D9B675'},
  };
  const p = palettes[hue];
  return (
    <div className="card" style={{padding:'12px 14px', display:'flex', gap:12, alignItems:'center', position:'relative', overflow:'hidden'}}>
      <div style={{
        width:54, flexShrink:0, padding:'10px 6px', borderRadius:14,
        background:`linear-gradient(180deg, ${p.from}, ${p.to})`,
        textAlign:'center', color:'#A93C68',
      }}>
        <div className="font-display italic" style={{fontSize:14, color:p.stroke}}>{period}</div>
        <div style={{fontSize:9, color:'#7A5266', marginTop:2, letterSpacing:'0.08em'}}>{time}</div>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:13, fontWeight:600, color:'#4B2A38'}}>{name}</div>
        <div style={{display:'flex', alignItems:'center', gap:6, marginTop:4, fontSize:11, color:'#7A5266'}}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#7A5266" strokeWidth="1.6"><path d="M12 22s-7-7-7-12a7 7 0 0 1 14 0c0 5-7 12-7 12z"/><circle cx="12" cy="10" r="2.5"/></svg>
          {room} · {teacher}
        </div>
      </div>
      <span className="pill" style={{flexShrink:0, fontSize:10}}>{tag}</span>
    </div>
  );
};

const FileBubble = ({name, date}) => (
  <div style={{display:'flex', gap:8, alignItems:'center', padding:'8px 10px', borderRadius:12, background:'rgba(255,237,245,0.5)', border:'1px solid rgba(255,179,206,0.4)'}}>
    <div style={{width:30, height:34, borderRadius:6, background:'linear-gradient(180deg,#FFC0D6,#F2709C)', display:'flex', alignItems:'center', justifyContent:'center', color:'#fff', fontSize:9, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', flexShrink:0}}>PDF</div>
    <div style={{minWidth:0, flex:1}}>
      <div style={{fontSize:11, color:'#4B2A38', fontWeight:600, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{name}</div>
      <div style={{fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{date}</div>
    </div>
  </div>
);

const TodayScreen = () => (
  <Phone>
    <FloralCorner style={{top:-40, right:-30}}/>
    <TopBar en="Today" title="今 日 课 程"/>
    <div className="scroll">
      <div style={{display:'flex', gap:8, marginBottom:14}}>
        <button style={tabPill(true)}>今天</button>
        <button style={tabPill(false)}>明天</button>
        <button style={tabPill(false)}>本周</button>
        <div style={{flex:1}}/>
        <button style={tabPill(false)}>10·20</button>
      </div>

      <div style={{position:'relative'}}>
        <div style={{position:'absolute', left:54, top:0, bottom:0, width:1, background:'linear-gradient(180deg, rgba(255,179,206,0.5), rgba(217,191,255,0.5), rgba(242,213,160,0.5))'}}/>
        {[
          {t:'08:00', e:'09:35', n:'1-2', name:'鸿蒙应用开发综合实践', room:'软件楼 305', teacher:'林老师', tag:'必修', hue:'rose'},
          {t:'10:00', e:'11:35', n:'3-4', name:'软件工程经济学', room:'一教 207', teacher:'苏老师', tag:'选修', hue:'lav'},
          {t:'14:00', e:'15:35', n:'5-6', name:'近代史纲要', room:'二教 102', teacher:'周老师', tag:'公选', hue:'gold'},
          {t:'19:00', e:'20:35', n:'9-10', name:'考研英语 · 自习', room:'图书馆 · 静读', teacher:'自习', tag:'自习', hue:'lav'},
        ].map((c,i)=>(
          <div key={i} style={{display:'flex', gap:14, marginBottom:14, position:'relative'}}>
            <div style={{width:48, textAlign:'right', paddingTop:4, flexShrink:0}}>
              <div className="font-display italic" style={{fontSize:14, color:'#A93C68'}}>{c.t}</div>
              <div style={{fontSize:9, color:'#B294A4'}}>{c.e}</div>
            </div>
            <div style={{position:'absolute', left:50, top:8, width:9, height:9, borderRadius:'50%', background:'#F2709C', boxShadow:'0 0 0 3px #FFE4EE'}}/>
            <TodayCard {...c} period={c.n+' 节'} time={c.t+'–'+c.e}/>
          </div>
        ))}
      </div>

      <div style={{textAlign:'center', padding:'12px 0 60px', fontSize:11, color:'#B294A4', letterSpacing:'0.3em', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>
        — fin de la journée —
      </div>
    </div>
    <TabBar active="home"/>
  </Phone>
);

const tabPill = (active) => ({
  padding:'6px 14px', borderRadius:999,
  background: active ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : 'rgba(255,255,255,0.7)',
  color: active ? '#fff' : '#A93C68',
  border: active ? 'none' : '1px solid rgba(255,179,206,0.5)',
  fontSize:11, fontWeight:600, cursor:'pointer',
  boxShadow: active ? '0 6px 14px -6px rgba(242,112,156,0.6)' : 'none',
});

const NotificationsScreen = () => (
  <Phone>
    <FloralCorner style={{top:-40, right:-30}}/>
    <TopBar en="Notices" title="通 知 公 告"
      right={<button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg></button>}
    />
    <div className="scroll">
      <div style={{display:'flex', gap:6, marginBottom:12, overflowX:'auto'}}>
        {['全部·12','教务·5','学生处·3','图书馆·2','学院·2'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      {[
        {tag:'教务处', unread:true, title:'2025-2026 学年第一学期期中教学检查通知', body:'各教学单位、全体同学：根据校历安排，本周起开展期中教学检查工作...', time:'10·18 · 09:24'},
        {tag:'学生处', unread:true, title:'关于做好秋季校园安全自查的通知', body:'秋冬交替时节，宿舍用电安全尤为重要，请同学们...', time:'10·15 · 14:00'},
        {tag:'图书馆', unread:false, title:'《玫瑰与少女》主题书展开放借阅', body:'十月馆藏新品 56 册已上架二楼东厅，欢迎品鉴...', time:'10·12'},
        {tag:'软件学院', unread:false, title:'关于鸿蒙开发综合实践项目验收的说明', body:'第十周起项目验收正式开始，请各小组按时提交...', time:'10·10'},
        {tag:'教务处', unread:false, title:'重修与缓考申请提交截止提醒', body:'本学期缓考申请将于 10·25 24:00 关闭通道...', time:'10·08'},
      ].map((n,i)=>(
        <div key={i} className="card" style={{padding:'14px 14px', marginBottom:10, display:'flex', gap:12, position:'relative'}}>
          {n.unread && <span style={{position:'absolute', top:14, right:14, width:8, height:8, borderRadius:'50%', background:'#F2709C', boxShadow:'0 0 0 2px #FFE4EE'}}/>}
          <div style={{
            width:44, height:44, borderRadius:14, flexShrink:0,
            background:'linear-gradient(135deg, #FFE4EE, #EFDFFF)',
            display:'flex', alignItems:'center', justifyContent:'center',
            border:'1px solid rgba(255,179,206,0.5)'
          }}>
            <Rose size={22}/>
          </div>
          <div style={{flex:1, minWidth:0}}>
            <div style={{display:'flex', alignItems:'center', gap:6}}>
              <span className="pill" style={{fontSize:9}}>{n.tag}</span>
              <span style={{fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{n.time}</span>
            </div>
            <div style={{fontSize:12.5, fontWeight:600, color:'#4B2A38', marginTop:5, lineHeight:1.35}}>{n.title}</div>
            <div style={{fontSize:11, color:'#7A5266', marginTop:4, lineHeight:1.5, overflow:'hidden', display:'-webkit-box', WebkitLineClamp:2, WebkitBoxOrient:'vertical'}}>{n.body}</div>
          </div>
        </div>
      ))}
    </div>
  </Phone>
);

const NoticeDetailScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Notice" title="通 知 详 情"
      right={<button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7"/><path d="M16 6l-4-4-4 4M12 2v14"/></svg></button>}
    />
    <div className="scroll">
      <span className="pill" style={{marginBottom:8}}>教务处 · 紧急</span>
      <div className="font-display" style={{fontSize:20, color:'#4B2A38', lineHeight:1.35, marginTop:8, fontWeight:600}}>
        2025-2026 学年第一学期<br/>期中教学检查通知
      </div>
      <div style={{display:'flex', gap:12, alignItems:'center', marginTop:10, fontSize:11, color:'#7A5266'}}>
        <span>发布单位 · 教务处</span>
        <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>10·18 · 09:24</span>
        <span style={{marginLeft:'auto', color:'#A93C68'}}>已读</span>
      </div>

      <div style={{height:1, background:'linear-gradient(90deg, transparent, rgba(255,179,206,0.6), transparent)', margin:'14px 0'}}/>

      <div style={{fontSize:12.5, color:'#4B2A38', lineHeight:1.85}}>
        各教学单位、全体同学：
        <br/><br/>
        根据校历安排，本周起开展 2025-2026 学年第一学期期中教学检查工作，现将有关事项通知如下：
        <br/><br/>
        <strong style={{color:'#A93C68'}}>一 · 检查时间</strong><br/>
        2025 年 10 月 21 日 — 10 月 31 日，共两周。
        <br/><br/>
        <strong style={{color:'#A93C68'}}>二 · 检查内容</strong><br/>
        课程进度执行情况、师生到课率、教学秩序与课堂质量。请各位同学按时到课，积极配合检查工作。
        <br/><br/>
        <strong style={{color:'#A93C68'}}>三 · 学生须知</strong><br/>
        请各位同学完成本期量化评教问卷，截止时间为 11 月 5 日 24:00。
      </div>

      <div className="card-glow" style={{marginTop:18, padding:'12px 14px', display:'flex', gap:8}}>
        <FileBubble name="附件·教学检查表.pdf" date="10·18"/>
      </div>

      <div style={{display:'flex', gap:10, marginTop:18}}>
        <button className="btn-ghost" style={{flex:1}}>收藏</button>
        <button className="btn-primary" style={{flex:1}}>知 道 了</button>
      </div>
    </div>
  </Phone>
);

Object.assign(window, { HomeScreen, TodayScreen, NotificationsScreen, NoticeDetailScreen, iconBtn, tabPill, TodayCard, FileBubble });
