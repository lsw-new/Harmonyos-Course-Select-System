/* Courses screens — Schedule, Course Detail, Course Selection, Selection Detail */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder, TabBar, iconBtn, tabPill } = window;

const ScheduleScreen = () => {
  const days = ['一','二','三','四','五','六','日'];
  const lessons = [
    {day:0, p1:1, p2:2, name:'鸿蒙开发', room:'软305', t:'林', hue:'rose'},
    {day:0, p1:3, p2:4, name:'软件经济学', room:'一教207', t:'苏', hue:'lav'},
    {day:1, p1:1, p2:2, name:'数据库原理', room:'软208', t:'李', hue:'gold'},
    {day:1, p1:5, p2:6, name:'近代史纲要', room:'二教102', t:'周', hue:'rose'},
    {day:2, p1:3, p2:4, name:'操作系统', room:'软301', t:'王', hue:'lav'},
    {day:3, p1:1, p2:2, name:'鸿蒙开发', room:'软305', t:'林', hue:'rose'},
    {day:3, p1:5, p2:6, name:'体育 · 网球', room:'网球场', t:'陈', hue:'gold'},
    {day:4, p1:3, p2:4, name:'毛中特', room:'一教305', t:'郑', hue:'rose'},
    {day:5, p1:1, p2:2, name:'计算机网络实验', room:'软实验室', t:'孙', hue:'lav'},
  ];

  const hueMap = {
    rose:{bg:'linear-gradient(160deg,#FFD3E3,#FFB4CE)', text:'#A93C68', line:'#F2709C'},
    lav:{bg:'linear-gradient(160deg,#EFDFFF,#D9BFFF)', text:'#6F47A8', line:'#B589FF'},
    gold:{bg:'linear-gradient(160deg,#FFF1D6,#F2D5A0)', text:'#A8854A', line:'#D9B675'},
  };

  return (
    <Phone>
      <FloralCorner style={{top:-30, right:-30}}/>
      <TopBar en="Schedule" title="我 的 课 表"
        right={<button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M3 6h18M3 12h18M3 18h12"/></svg></button>}
      />
      <div style={{padding:'4px 16px 8px'}}>
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between'}}>
          <div>
            <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Week IX</div>
            <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.2em'}}>2025–2026 秋季 · 第 9 周</div>
          </div>
          <div style={{display:'flex', gap:6}}>
            <button style={iconBtn}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="2"><path d="M15 6l-6 6 6 6"/></svg></button>
            <button style={iconBtn}><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="2"><path d="M9 6l6 6-6 6"/></svg></button>
          </div>
        </div>
        {/* week scroller */}
        <div style={{display:'flex', gap:5, marginTop:10, overflowX:'auto'}}>
          {Array.from({length:18}).map((_,i)=>(
            <button key={i} style={{
              flexShrink:0, padding:'4px 10px', borderRadius:999,
              background: i===8 ? 'linear-gradient(135deg,#F2709C,#E08AB8)' : 'rgba(255,255,255,0.65)',
              color: i===8 ? '#fff' : '#A93C68',
              border: i===8 ? 'none' : '1px solid rgba(255,179,206,0.5)',
              fontSize:10, fontWeight:600, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'
            }}>{i+1}</button>
          ))}
        </div>
      </div>

      <div style={{flex:1, padding:'4px 12px 80px', overflow:'auto'}}>
        {/* Header row */}
        <div style={{display:'grid', gridTemplateColumns:'24px repeat(7, 1fr)', gap:4, alignItems:'center', marginBottom:6}}>
          <div/>
          {days.map((d,i)=>(
            <div key={i} style={{textAlign:'center'}}>
              <div style={{fontSize:9, color:'#B294A4'}}>{d}</div>
              <div className="font-display italic" style={{
                fontSize:13,
                color: i===0 ? '#F2709C' : '#A93C68'
              }}>{20+i}</div>
            </div>
          ))}
        </div>
        {/* Grid */}
        <div style={{display:'grid', gridTemplateColumns:'24px repeat(7, 1fr)', gap:4, position:'relative'}}>
          {/* periods column + cells */}
          {Array.from({length:6}).map((_,row)=>{
            const period = row*2+1;
            return (
              <React.Fragment key={row}>
                <div style={{
                  display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center',
                  fontSize:10, color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic',
                  height:64
                }}>
                  <div>{period}</div>
                  <div style={{opacity:0.5}}>·</div>
                  <div>{period+1}</div>
                </div>
                {days.map((d, col)=>{
                  const lesson = lessons.find(l=>l.day===col && l.p1===period);
                  if (lesson) {
                    const p = hueMap[lesson.hue];
                    return (
                      <div key={col} style={{
                        height:64, borderRadius:10,
                        background: p.bg,
                        padding:'6px 5px',
                        position:'relative', overflow:'hidden',
                        boxShadow:'0 4px 10px -4px rgba(242,112,156,0.3)'
                      }}>
                        <div style={{position:'absolute', left:0, top:0, bottom:0, width:2, background:p.line}}/>
                        <div style={{fontSize:9, fontWeight:700, color:p.text, lineHeight:1.2}}>{lesson.name}</div>
                        <div style={{fontSize:8, color:p.text, opacity:0.75, marginTop:3, lineHeight:1.2}}>{lesson.room}</div>
                        <div style={{fontSize:8, color:p.text, opacity:0.6, marginTop:1}}>{lesson.t}</div>
                      </div>
                    );
                  }
                  return <div key={col} style={{height:64, borderRadius:10, background:'rgba(255,255,255,0.4)', border:'1px dashed rgba(255,179,206,0.3)'}}/>;
                })}
              </React.Fragment>
            );
          })}
        </div>

        <div style={{display:'flex', gap:8, marginTop:14, padding:'0 4px', flexWrap:'wrap'}}>
          <Legend color="#F2709C" label="必修"/>
          <Legend color="#B589FF" label="选修"/>
          <Legend color="#D9B675" label="公选 / 体育"/>
        </div>
      </div>
      <TabBar active="home"/>
    </Phone>
  );
};

const Legend = ({color, label}) => (
  <div style={{display:'flex', alignItems:'center', gap:5, fontSize:10, color:'#7A5266'}}>
    <span style={{width:10, height:10, borderRadius:3, background:color}}/>{label}
  </div>
);

const CourseDetailScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Course" title="课 程 详 情"
      right={<button style={iconBtn}><Heart size={14}/></button>}
    />
    <div className="scroll">
      <div style={{
        position:'relative', borderRadius:22, padding:'18px',
        background:'linear-gradient(135deg, #FFC0D6 0%, #EFDFFF 100%)',
        boxShadow:'0 10px 24px -10px rgba(242,112,156,0.5)',
      }}>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-start'}}>
          <div>
            <span className="pill">必修 · 4 学分</span>
            <div className="font-display" style={{fontSize:22, color:'#4B2A38', fontWeight:600, marginTop:8, lineHeight:1.2}}>
              鸿蒙应用开发<br/>综合实践
            </div>
            <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.2em', marginTop:6}}>
              SE-4023 · 2025-2026-1
            </div>
          </div>
          <Sparkle size={32} color="#FFF"/>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8, marginTop:14, fontSize:11, color:'#4B2A38'}}>
          <Cell k="教师" v="林 玫 老师"/>
          <Cell k="学院" v="软件学院"/>
          <Cell k="周次" v="2 – 16 周"/>
          <Cell k="课堂" v="1-2 节 · 软305"/>
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> teaching plan <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'14px', fontSize:12.5, color:'#4B2A38', lineHeight:1.7}}>
        本课程以鸿蒙原生应用开发为主线，覆盖 ArkTS 声明式 UI、状态管理、分布式能力、原子化服务等内容。要求学生在完成实验的同时，以 5 人小组形式完成一个完整的项目。
      </div>

      <div className="divider-rose"><Rose size={10}/> schedule <Rose size={10}/></div>
      <div className="card" style={{padding:'12px 14px'}}>
        {[
          {w:'W02', t:'课程导引 · 环境搭建'},
          {w:'W04', t:'ArkTS 与声明式 UI'},
          {w:'W08', t:'状态管理与路由'},
          {w:'W12', t:'分布式能力 & 原子化服务'},
          {w:'W16', t:'项目答辩 · 期末检视'},
        ].map((s,i)=>(
          <div key={i} style={{display:'flex', gap:12, padding:'8px 0', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none'}}>
            <div style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', color:'#A93C68', fontSize:14, width:34}}>{s.w}</div>
            <div style={{fontSize:12, color:'#4B2A38'}}>{s.t}</div>
          </div>
        ))}
      </div>

      <div className="divider-rose"><Rose size={10}/> evaluation <Rose size={10}/></div>
      <div style={{display:'flex', gap:8}}>
        {[{k:'平时',v:'30%'},{k:'实验',v:'30%'},{k:'答辩',v:'40%'}].map((e,i)=>(
          <div key={i} className="card" style={{flex:1, padding:'12px 6px', textAlign:'center'}}>
            <div className="font-display italic" style={{fontSize:22, color:'#A93C68'}}>{e.v}</div>
            <div style={{fontSize:10, color:'#7A5266', letterSpacing:'0.2em'}}>{e.k}</div>
          </div>
        ))}
      </div>

      <div style={{display:'flex', gap:10, marginTop:18, marginBottom:60}}>
        <button className="btn-ghost" style={{flex:1}}>课件下载</button>
        <button className="btn-primary" style={{flex:1}}>进 入 评 教</button>
      </div>
    </div>
  </Phone>
);

const Cell = ({k, v}) => (
  <div>
    <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.25em'}}>{k}</div>
    <div style={{fontSize:12, fontWeight:600, marginTop:3}}>{v}</div>
  </div>
);

const SelectionScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Selection" title="选 课 中 心"/>
    <div className="scroll">
      <div style={{
        position:'relative', borderRadius:22, padding:'16px',
        background:'linear-gradient(135deg, #FFE4EE 0%, #EFDFFF 100%)',
        boxShadow:'0 6px 18px -8px rgba(242,112,156,0.4)',
      }}>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-end'}}>
          <div>
            <span className="pill">正选阶段 · 进行中</span>
            <div className="font-display italic" style={{fontSize:18, color:'#A93C68', marginTop:6}}>Round II · Selection</div>
          </div>
          <div style={{textAlign:'right'}}>
            <div className="font-display italic" style={{fontSize:14, color:'#A93C68'}}>03d 14h</div>
            <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.2em'}}>剩余 · UNTIL 10·24</div>
          </div>
        </div>
        <div style={{height:6, borderRadius:3, background:'rgba(255,255,255,0.6)', marginTop:12, overflow:'hidden'}}>
          <div style={{width:'62%', height:'100%', background:'linear-gradient(90deg,#F2709C,#B589FF)', borderRadius:3}}/>
        </div>
        <div style={{display:'flex', justifyContent:'space-between', marginTop:8, fontSize:11, color:'#7A5266'}}>
          <span>已选 <b style={{color:'#A93C68'}}>14.5</b> 学分</span>
          <span>上限 <b style={{color:'#A93C68'}}>24</b> 学分</span>
        </div>
      </div>

      <div style={{display:'flex', gap:8, marginTop:14, alignItems:'center'}}>
        <div style={{flex:1, position:'relative'}}>
          <div style={{position:'absolute', left:12, top:11}}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>
          </div>
          <input className="input" placeholder="搜索课程 / 教师 / 课号" style={{paddingLeft:34}}/>
        </div>
        <button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M3 6h18M6 12h12M10 18h4"/></svg></button>
      </div>

      <div style={{display:'flex', gap:6, marginTop:12, overflowX:'auto'}}>
        {['全部','专业必修','专业选修','公选','体育','通识'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      <div style={{marginTop:14, display:'flex', flexDirection:'column', gap:10}}>
        {[
          {name:'人机交互设计', code:'SE-5012', t:'林·老师', cap:'56 / 60', cred:'2.0', tag:'专选', status:'select', hue:'rose'},
          {name:'宋词鉴赏与吟诵', code:'GE-2031', t:'柳·老师', cap:'120 / 120', cred:'1.5', tag:'公选', status:'full', hue:'gold'},
          {name:'机器学习导论', code:'CS-4108', t:'谢·老师', cap:'42 / 60', cred:'3.0', tag:'专选', status:'select', hue:'lav'},
          {name:'西方艺术史', code:'GE-1021', t:'宋·老师', cap:'已选 · 14:00-15:35', cred:'1.5', tag:'已选', status:'taken', hue:'rose'},
          {name:'户外运动 · 山野', code:'PE-3022', t:'郭·老师', cap:'18 / 30', cred:'1.0', tag:'体育', status:'conflict', hue:'gold'},
        ].map((c,i)=>(
          <SelectCard key={i} {...c}/>
        ))}
      </div>
    </div>
  </Phone>
);

const SelectCard = ({name, code, t, cap, cred, tag, status, hue}) => {
  const colors = {
    rose:'#F2709C', lav:'#B589FF', gold:'#D9B675'
  };
  const btn = {
    select: {label:'选 课', bg:'linear-gradient(135deg,#FF9FBE,#F2709C)', color:'#fff'},
    full: {label:'已 满', bg:'rgba(255,255,255,0.6)', color:'#B294A4', border:'1px solid rgba(178,148,164,0.3)'},
    taken: {label:'退 选', bg:'rgba(255,255,255,0.8)', color:'#A93C68', border:'1px solid rgba(255,179,206,0.5)'},
    conflict: {label:'冲突', bg:'rgba(255,237,213,0.7)', color:'#A8854A', border:'1px solid rgba(217,182,117,0.4)'},
  }[status];

  return (
    <div className="card" style={{padding:'14px', display:'flex', gap:12, position:'relative', overflow:'hidden'}}>
      <div style={{
        width:6, alignSelf:'stretch', borderRadius:3, background:colors[hue],
        margin:'-14px 0 -14px -14px', marginRight:6
      }}/>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:6, flexWrap:'wrap'}}>
          <div style={{fontSize:13, fontWeight:700, color:'#4B2A38'}}>{name}</div>
          <span style={{fontSize:9, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{code}</span>
        </div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:4}}>{t} · {cap}</div>
        <div style={{display:'flex', gap:6, marginTop:6}}>
          <span className="pill" style={{fontSize:9}}>{tag}</span>
          <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#FFF1D6,#FBE6C2)', color:'#A8854A'}}>{cred} 学分</span>
        </div>
      </div>
      <button style={{
        alignSelf:'center', padding:'8px 14px', borderRadius:999,
        background:btn.bg, color:btn.color, border:btn.border||'none',
        fontSize:11, fontWeight:700, cursor:'pointer', flexShrink:0,
      }}>{btn.label}</button>
    </div>
  );
};

Object.assign(window, { ScheduleScreen, CourseDetailScreen, SelectionScreen, Cell });
