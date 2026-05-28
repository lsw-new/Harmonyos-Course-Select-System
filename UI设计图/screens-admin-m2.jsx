/* Mobile admin part 2 — Courses, Selection, Grades, Notice */
const { Phone: AP2, TopBar: ATB2, Rose: AR2, Sparkle: AS2, Heart: AH2, FloralCorner: AFC2,
  Monogram: AM2, Placeholder: APH2, iconBtn, tabPill, Field: AF2, AdTabBar: ATab2, miniIco } = window;

/* ─── A4 · Course Management ─── */
const AdminCourses = () => (
  <AP2>
    <AFC2 style={{top:-30, right:-30}}/>
    <ATB2 en="Cours" title="课 程 管 理"
      right={<button style={miniIco}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M12 5v14M5 12h14"/></svg></button>}
    />
    <div className="scroll">
      <div style={{
        padding:'14px 16px', borderRadius:18,
        background:'linear-gradient(135deg, #FFE4EE 0%, #FBE8D8 100%)',
      }}>
        <div style={{display:'flex', alignItems:'baseline', gap:6}}>
          <span className="font-display italic" style={{fontSize:30, color:'#A93C68', lineHeight:1}}>412</span>
          <span style={{fontSize:11, color:'#7A5266'}}>本学期开课门数</span>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:6, marginTop:12}}>
          {[
            {k:'必修', v:'165', c:'#F2709C'},
            {k:'选修', v:'124', c:'#B589FF'},
            {k:'公选', v:'82', c:'#D9B675'},
            {k:'实践', v:'41', c:'#3F7A4A'},
          ].map((s,i)=>(
            <div key={i} style={{background:'rgba(255,255,255,0.6)', borderRadius:10, padding:'8px 4px', textAlign:'center'}}>
              <div className="font-display italic" style={{fontSize:15, color:s.c}}>{s.v}</div>
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
          <input className="input" placeholder="搜索课程 / 课号 / 教师..." style={{paddingLeft:34}}/>
        </div>
      </div>

      <div style={{display:'flex', gap:6, marginTop:10, overflowX:'auto'}}>
        {['全部','必修','选修','公选','实践'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:10, marginTop:14}}>
        {[
          {name:'鸿蒙应用开发综合实践', code:'SE-4023', t:'林玫', cred:4, w:'周一 1-2', cap:'56/60', cls:'必修', hue:'rose'},
          {name:'操作系统', code:'CS-3022', t:'王素', cred:3.5, w:'周二 3-4', cap:'82/100', cls:'必修', hue:'rose'},
          {name:'软件工程经济学', code:'SE-3041', t:'苏柔', cred:2, w:'周一 3-4', cap:'48/60', cls:'选修', hue:'lav'},
          {name:'宋词鉴赏与吟诵', code:'GE-2031', t:'柳萤', cred:1.5, w:'周六 1-2', cap:'120/120', cls:'公选', hue:'gold'},
          {name:'数据库原理', code:'CS-3041', t:'李莹', cred:3, w:'周二 1-2', cap:'78/100', cls:'必修', hue:'lav'},
        ].map((c,i)=>{
          const hues = {
            rose:{bg:'linear-gradient(160deg,#FFD3E3,#FFB4CE)', text:'#A93C68', line:'#F2709C'},
            lav:{bg:'linear-gradient(160deg,#EFDFFF,#D9BFFF)', text:'#6F47A8', line:'#B589FF'},
            gold:{bg:'linear-gradient(160deg,#FFF1D6,#F2D5A0)', text:'#A8854A', line:'#D9B675'},
          }[c.hue];
          const full = c.cap.split('/')[0] === c.cap.split('/')[1];
          return (
            <div key={i} className="card" style={{padding:'12px', display:'flex', gap:12, position:'relative', overflow:'hidden'}}>
              <div style={{width:6, alignSelf:'stretch', borderRadius:3, background:hues.line, margin:'-12px 0 -12px -12px'}}/>
              <div style={{flex:1, minWidth:0, paddingLeft:6}}>
                <div style={{display:'flex', alignItems:'baseline', gap:6, flexWrap:'wrap'}}>
                  <span style={{fontSize:13, fontWeight:700, color:'#4B2A38'}}>{c.name}</span>
                  <span style={{fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{c.code}</span>
                </div>
                <div style={{display:'flex', gap:6, marginTop:5, alignItems:'center', flexWrap:'wrap'}}>
                  <span className="pill" style={{fontSize:9}}>{c.cls}</span>
                  <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#FFF1D6,#FBE6C2)', color:'#A8854A'}}>{c.cred} 学分</span>
                  <span style={{fontSize:10, color:'#7A5266'}}>{c.t} · {c.w}</span>
                </div>
                <div style={{display:'flex', alignItems:'center', gap:8, marginTop:8}}>
                  <div style={{flex:1, height:5, borderRadius:3, background:'rgba(255,179,206,0.15)', overflow:'hidden'}}>
                    <div style={{width: (parseInt(c.cap)/parseInt(c.cap.split('/')[1])*100)+'%', height:'100%', background: full ? 'linear-gradient(90deg,#C04040,#FF6868)' : 'linear-gradient(90deg,#FF9FBE,#F2709C)'}}/>
                  </div>
                  <span style={{fontSize:11, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', color:full?'#C04040':'#A93C68', fontWeight:600}}>{c.cap}</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
    <ATab2 active="crs"/>
  </AP2>
);

/* ─── A5 · Selection Management ─── */
const AdminSelection = () => (
  <AP2>
    <AFC2 style={{top:-30, right:-30}}/>
    <ATB2 en="Sélection" title="选 课 管 理"
      right={<button style={miniIco}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="12" cy="12" r="3"/><path d="M19 12c0 1-0.4 2-0.8 2.8l1.6 1.4-2 3.4-2.2-0.8c-0.8 0.5-1.7 0.8-2.7 1L12.5 22h-3l-0.4-2.2c-1-0.2-1.9-0.5-2.7-1L4.2 19.6l-2-3.4 1.6-1.4C3.4 14 3 13 3 12s0.4-2 0.8-2.8L2.2 7.8l2-3.4 2.2 0.8c0.8-0.5 1.7-0.8 2.7-1L9.5 2h3l0.4 2.2c1 0.2 1.9 0.5 2.7 1L17.8 4.4l2 3.4-1.6 1.4C18.6 10 19 11 19 12z"/></svg></button>}
    />
    <div className="scroll">
      <div style={{
        position:'relative', borderRadius:22, padding:'18px',
        background:'linear-gradient(135deg, #FFD3E3 0%, #EFDFFF 60%, #FFE9F1 100%)',
        boxShadow:'0 10px 28px -10px rgba(242,112,156,0.4)', overflow:'hidden'
      }}>
        <AFC2 style={{top:-40, right:-40, opacity:0.4}}/>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-end', position:'relative'}}>
          <div>
            <span className="pill">进行中</span>
            <div className="font-display italic" style={{fontSize:22, color:'#A93C68', marginTop:6}}>Round II · 正选</div>
            <div style={{fontSize:11, color:'#7A5266', marginTop:2}}>10·17 09:00 — 10·24 24:00</div>
          </div>
          <div style={{textAlign:'right'}}>
            <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>03d 14h</div>
            <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.2em'}}>剩 余</div>
          </div>
        </div>
        <div style={{height:6, borderRadius:3, background:'rgba(255,255,255,0.6)', marginTop:12, overflow:'hidden', position:'relative'}}>
          <div style={{width:'62%', height:'100%', background:'linear-gradient(90deg,#F2709C,#B589FF)', borderRadius:3}}/>
        </div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:8, marginTop:12}}>
          {[
            {k:'参与', v:'2,684'},
            {k:'门次', v:'14,302'},
            {k:'均学分', v:'18.7'},
            {k:'冲突', v:'412'},
          ].map((s,i)=>(
            <div key={i} style={{background:'rgba(255,255,255,0.55)', borderRadius:10, padding:'8px 4px', textAlign:'center'}}>
              <div className="font-display italic" style={{fontSize:15, color:'#A93C68'}}>{s.v}</div>
              <div style={{fontSize:9, color:'#7A5266'}}>{s.k}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="divider-rose"><AR2 size={10}/> 本学期轮次 <AR2 size={10}/></div>
      <div className="card" style={{padding:'4px 14px'}}>
        {[
          {n:'I · 预选', t:'09·15 — 09·22', s:'已结束', c:'#7A5266', done:true},
          {n:'II · 正选', t:'10·17 — 10·24', s:'进行中', c:'#3F7A4A', curr:true},
          {n:'III · 补选', t:'10·28 — 10·31', s:'待开放', c:'#A8854A'},
          {n:'IV · 退选', t:'11·05 — 11·12', s:'待开放', c:'#A8854A'},
        ].map((r,i)=>(
          <div key={i} style={{display:'flex', gap:10, alignItems:'center', padding:'10px 0', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none'}}>
            <span style={{
              width:30, height:30, borderRadius:'50%',
              background: r.curr ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : (r.done ? 'rgba(255,237,245,0.6)' : 'rgba(255,237,213,0.6)'),
              color: r.curr ? '#fff' : (r.done ? '#7A5266' : '#A8854A'),
              display:'flex', alignItems:'center', justifyContent:'center',
              fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:13, fontWeight:600,
              flexShrink:0
            }}>{r.n.split(' ')[0]}</span>
            <div style={{flex:1}}>
              <div style={{fontSize:12, fontWeight:600, color:'#4B2A38'}}>{r.n.split(' · ')[1]}</div>
              <div style={{fontSize:10, color:'#7A5266', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{r.t}</div>
            </div>
            <span style={{fontSize:11, fontWeight:600, color:r.c}}>● {r.s}</span>
          </div>
        ))}
      </div>

      <div className="divider-rose"><AR2 size={10}/> 选课热度 · TOP <AR2 size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        {[
          {n:'宋词鉴赏与吟诵', t:'柳萤', sel:120, cap:120, full:true},
          {n:'西方艺术史', t:'宋婉', sel:80, cap:80, full:true},
          {n:'人工智能基础', t:'谢敏', sel:58, cap:60},
          {n:'近代史纲要', t:'周岑', sel:118, cap:120},
          {n:'机器学习导论', t:'谢敏', sel:42, cap:60},
        ].map((c,i)=>{
          const pct = c.sel/c.cap*100;
          return (
            <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 0', borderTop: i?'1px dashed rgba(255,179,206,0.4)':'none'}}>
              <span className="font-display italic" style={{fontSize:18, color:'#A93C68', width:18, fontWeight:600}}>{i+1}</span>
              <div style={{flex:1, minWidth:0}}>
                <div style={{fontSize:12, fontWeight:600, color:'#4B2A38'}}>{c.n}</div>
                <div style={{display:'flex', alignItems:'center', gap:6, marginTop:4}}>
                  <span style={{fontSize:10, color:'#7A5266'}}>{c.t}</span>
                  <div style={{flex:1, height:5, borderRadius:3, background:'rgba(255,179,206,0.15)', overflow:'hidden'}}>
                    <div style={{width:pct+'%', height:'100%', background: c.full ? 'linear-gradient(90deg,#F2709C,#FF9FBE)' : 'linear-gradient(90deg,#B589FF,#D9BFFF)'}}/>
                  </div>
                </div>
              </div>
              <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:13, color: c.full ? '#A93C68':'#7A5266', flexShrink:0}}>{c.sel}/{c.cap}</span>
            </div>
          );
        })}
      </div>
      <div style={{height:30}}/>
    </div>
    <ATab2 active="crs"/>
  </AP2>
);

/* ─── A6 · Grades Audit ─── */
const AdminGrades = () => (
  <AP2>
    <AFC2 style={{top:-30, right:-30}}/>
    <ATB2 en="Notes · Audit" title="成 绩 管 理"/>
    <div className="scroll">
      <div style={{display:'grid', gridTemplateColumns:'repeat(2,1fr)', gap:10}}>
        {[
          {k:'待审核', v:'12', c:'#A8854A', bg:'linear-gradient(135deg,#FFF1D6,#FBE6C2)'},
          {k:'已审核', v:'68', c:'#3F7A4A', bg:'linear-gradient(135deg,#E6F7E6,#D8F0D8)'},
          {k:'已发布', v:'52', c:'#A93C68', bg:'linear-gradient(135deg,#FFE4EE,#FFD3E3)'},
          {k:'异议', v:'04', c:'#C04040', bg:'linear-gradient(135deg,#FFE0E0,#FFC8C8)'},
        ].map((s,i)=>(
          <div key={i} style={{padding:'14px', borderRadius:16, background:s.bg, border:'1px solid rgba(255,255,255,0.6)'}}>
            <div style={{fontSize:9, letterSpacing:'0.25em', color:s.c}}>{s.k}</div>
            <div className="font-display italic" style={{fontSize:26, color:s.c, marginTop:4}}>{s.v}</div>
          </div>
        ))}
      </div>

      <div style={{display:'flex', gap:6, marginTop:14, overflowX:'auto'}}>
        {['全部·8','待审核·3','录入中·2','已发布·2','异议·1'].map((t,i)=>(
          <button key={i} style={tabPill(i===1)}>{t}</button>
        ))}
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:10, marginTop:14}}>
        {[
          {n:'鸿蒙应用开发综合实践', c:'SE-4023.01', t:'林玫', s:60, d:60, st:'audit', hl:true, time:'10·18 14:22'},
          {n:'操作系统', c:'CS-3022.03', t:'王素', s:100, d:100, st:'audit', time:'10·16 16:08'},
          {n:'软件工程经济学', c:'SE-3041.02', t:'苏柔', s:60, d:58, st:'partial', time:'10·17 09:14'},
          {n:'数据库原理', c:'CS-3041.01', t:'李莹', s:100, d:42, st:'partial', time:'10·15 11:30'},
          {n:'近代史纲要', c:'GE-1003.05', t:'周岑', s:120, d:120, st:'published', time:'10·10 18:42'},
          {n:'宋词鉴赏与吟诵', c:'GE-2031.02', t:'柳萤', s:56, d:56, st:'issue', time:'10·08 09:00'},
        ].map((r,i)=>{
          const statCfg = {
            audit:{l:'待审核', c:'#A8854A', bg:'linear-gradient(135deg,#FFF1D6,#FBE6C2)'},
            partial:{l:'录入中', c:'#6F47A8', bg:'linear-gradient(135deg,#EFDFFF,#D9BFFF)'},
            published:{l:'已发布', c:'#3F7A4A', bg:'linear-gradient(135deg,#E6F7E6,#D8F0D8)'},
            issue:{l:'有异议', c:'#C04040', bg:'linear-gradient(135deg,#FFE0E0,#FFC8C8)'},
          }[r.st];
          return (
            <div key={i} className="card" style={{padding:'12px', background: r.hl?'rgba(255,228,238,0.4)':undefined}}>
              <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8}}>
                <div style={{flex:1, minWidth:0}}>
                  <div style={{fontSize:13, fontWeight:700, color:'#4B2A38'}}>{r.n}</div>
                  <div style={{fontSize:10, color:'#B294A4', marginTop:2}}>
                    <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{r.c}</span> · {r.t}老师
                  </div>
                </div>
                <span style={{padding:'3px 9px', borderRadius:999, fontSize:9, fontWeight:700, background:statCfg.bg, color:statCfg.c}}>{statCfg.l}</span>
              </div>
              <div style={{display:'flex', alignItems:'center', gap:8, marginTop:10}}>
                <div style={{flex:1, height:6, borderRadius:3, background:'rgba(255,179,206,0.15)', overflow:'hidden'}}>
                  <div style={{width:(r.d/r.s*100)+'%', height:'100%', background: r.d===r.s ? 'linear-gradient(90deg,#9DCB8A,#B7DFA9)' : 'linear-gradient(90deg,#FF9FBE,#F2709C)'}}/>
                </div>
                <span style={{fontSize:11, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', color: r.d===r.s ? '#3F7A4A' : '#A93C68', fontWeight:600}}>{r.d}/{r.s}</span>
              </div>
              <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginTop:8}}>
                <span style={{fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{r.time}</span>
                <div style={{display:'flex', gap:6}}>
                  <button style={{padding:'4px 10px', borderRadius:999, fontSize:10, background:'rgba(255,255,255,0.8)', border:'1px solid rgba(255,179,206,0.5)', color:'#A93C68', fontWeight:600}}>明细</button>
                  {r.st==='audit' && <button style={{padding:'4px 10px', borderRadius:999, fontSize:10, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', color:'#fff', border:'none', fontWeight:700}}>审核</button>}
                </div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{height:30}}/>
    </div>
  </AP2>
);

/* ─── A7 · Notice Composer ─── */
const AdminNotice = () => (
  <AP2>
    <AFC2 style={{top:-30, right:-30}}/>
    <ATB2 en="Annonce" title="发 布 通 知"
      right={<button style={{...miniIco, width:'auto', padding:'0 12px', fontSize:11, color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>send</button>}
    />
    <div className="scroll">
      {/* Title */}
      <div style={{fontSize:10, letterSpacing:'0.3em', color:'#A93C68', marginBottom:6}}>标 题 · TITLE</div>
      <input className="input" style={{fontSize:14, fontWeight:600, padding:'12px 14px'}} defaultValue="关于做好期末考试工作的通知"/>

      {/* Toolbar */}
      <div style={{
        display:'flex', gap:4, marginTop:12, padding:'6px',
        background:'linear-gradient(135deg,#FFE4EE,#F1E2FF)', borderRadius:10, overflowX:'auto'
      }}>
        {['B','I','U','¶','H1','—','✶','🔗','📎','📷'].map((t,i)=>(
          <button key={i} style={{
            width:30, height:28, borderRadius:6, border:'none',
            background:'rgba(255,255,255,0.6)', color:'#A93C68', fontSize:11, fontWeight:700, flexShrink:0
          }}>{t}</button>
        ))}
      </div>

      {/* Body */}
      <div style={{
        marginTop:8, padding:'14px 16px', borderRadius:12,
        border:'1px solid rgba(255,179,206,0.4)', background:'rgba(255,255,255,0.7)',
        minHeight:180, fontSize:12, color:'#4B2A38', lineHeight:1.8
      }}>
        各教学单位、全体同学：
        <br/><br/>
        2025-2026 学年第一学期期末考试将于 <b style={{color:'#A93C68'}}>2026·01·05</b> 至 <b style={{color:'#A93C68'}}>01·17</b> 进行...
        <br/><br/>
        <span style={{color:'#A93C68', fontWeight:600}}>一 · 考试时间</span><br/>
        闭卷考试 1·5—1·17，论文可至 1·20 提交。
      </div>

      <div className="divider-rose"><AR2 size={10}/> 发 布 设 置 <AR2 size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        {[
          ['发布单位', '教务处'],
          ['分类', '教学通知'],
          ['紧急程度', '紧急 ●'],
          ['发布时间', '立即发布'],
          ['过期时间', '2026·01·17'],
        ].map(([k,v],i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', padding:'10px 0', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none', fontSize:12}}>
            <span style={{flex:1, color:'#7A5266'}}>{k}</span>
            <span style={{color:'#4B2A38', fontWeight:600}}>{v}</span>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#B294A4" strokeWidth="2" style={{marginLeft:8}}><path d="M9 6l6 6-6 6"/></svg>
          </div>
        ))}
      </div>

      <div className="divider-rose"><AR2 size={10}/> 接 收 对 象 <AR2 size={10}/></div>
      <div className="card-glow" style={{padding:'14px'}}>
        <div style={{display:'flex', gap:6, marginBottom:10}}>
          {['全体', '学生', '教师', '指定'].map((t,i)=>(
            <button key={i} style={tabPill(i===1)}>{t}</button>
          ))}
        </div>
        <div style={{display:'flex', flexWrap:'wrap', gap:6}}>
          {['软件学院·全部','计算机·全部','机械·2023级'].map((t,i)=>(
            <span key={i} style={{
              padding:'4px 10px', borderRadius:999, fontSize:10,
              background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)', color:'#A93C68',
              border:'1px solid rgba(255,179,206,0.4)',
              display:'flex', alignItems:'center', gap:5
            }}>{t} <span>×</span></span>
          ))}
          <button style={{padding:'4px 10px', borderRadius:999, fontSize:10, background:'rgba(255,255,255,0.6)', border:'1px dashed rgba(255,179,206,0.6)', color:'#A93C68'}}>+ 添加</button>
        </div>
        <div style={{marginTop:12, padding:'8px 10px', borderRadius:10, background:'linear-gradient(135deg,#FFF1D6,#FBE6C2)', fontSize:11, color:'#A8854A'}}>
          ✦ 预计接收 <b className="font-display italic" style={{fontSize:14}}>2,847</b> 人
        </div>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:14}}>
        ✦ 发 送 公 告 · SEND
      </button>
      <div style={{height:30}}/>
    </div>
  </AP2>
);

Object.assign(window, { AdminCourses, AdminSelection, AdminGrades, AdminNotice });
