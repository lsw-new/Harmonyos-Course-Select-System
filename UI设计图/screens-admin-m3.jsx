/* Mobile admin part 3 — Evaluation, Approvals, Settings, Profile */
const { Phone: AP3, TopBar: ATB3, Rose: AR3, Sparkle: AS3, Heart: AH3, FloralCorner: AFC3,
  Monogram: AM3, iconBtn: aib3, tabPill: atp3, AdTabBar: ATab3, miniIco: mIco3 } = window;

/* ─── A8 · Evaluation Management ─── */
const AdminEval = () => (
  <AP3>
    <AFC3 style={{top:-30, right:-30}}/>
    <ATB3 en="Évaluation" title="评 教 管 理"
      right={<button style={mIco3}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><path d="M12 5v14M5 12h14"/></svg></button>}
    />
    <div className="scroll">
      <div style={{
        position:'relative', borderRadius:22, padding:'16px',
        background:'linear-gradient(135deg, #EFDFFF 0%, #FFE4EE 70%, #FFF1D6 100%)',
        overflow:'hidden'
      }}>
        <AFC3 style={{top:-40, right:-40, opacity:0.4}}/>
        <span className="pill">开放期 · 进行中</span>
        <div className="font-display italic" style={{fontSize:22, color:'#A93C68', marginTop:6}}>2025-1 学期评教</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:2}}>10·15 — 11·05 · 截止 11d 09h</div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(2,1fr)', gap:8, marginTop:14}}>
          {[
            {k:'参与率', v:'68%', sub:'1,936 / 2,847'},
            {k:'完成率', v:'42%', sub:'824 / 1,936'},
            {k:'平均分', v:'4.62', sub:'满分 5.0'},
            {k:'问卷', v:'186', sub:'覆盖 412 课'},
          ].map((s,i)=>(
            <div key={i} style={{background:'rgba(255,255,255,0.55)', borderRadius:12, padding:'10px'}}>
              <div style={{fontSize:9, letterSpacing:'0.25em', color:'#7A5266'}}>{s.k}</div>
              <div className="font-display italic" style={{fontSize:20, color:'#A93C68', marginTop:2}}>{s.v}</div>
              <div style={{fontSize:9, color:'#7A5266', marginTop:2}}>{s.sub}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="divider-rose"><AR3 size={10}/> 评 分 分 布 <AR3 size={10}/></div>
      <div className="card" style={{padding:'14px'}}>
        {[
          {l:'优秀 (4.5+)', v:62, c:'linear-gradient(90deg,#F2709C,#FF9FBE)'},
          {l:'良好 (4.0-4.5)', v:24, c:'linear-gradient(90deg,#B589FF,#D9BFFF)'},
          {l:'一般 (3.0-4.0)', v:10, c:'linear-gradient(90deg,#D9B675,#F2D5A0)'},
          {l:'待改进 (<3.0)', v:4, c:'linear-gradient(90deg,#B294A4,#D4BAC5)'},
        ].map((d,i)=>(
          <div key={i} style={{marginBottom: i<3?12:0}}>
            <div style={{display:'flex', justifyContent:'space-between', fontSize:11, color:'#4B2A38', marginBottom:4}}>
              <span>{d.l}</span>
              <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', color:'#A93C68'}}>{d.v}%</span>
            </div>
            <div style={{height:8, borderRadius:4, background:'rgba(255,179,206,0.15)', overflow:'hidden'}}>
              <div style={{width:d.v+'%', height:'100%', background:d.c}}/>
            </div>
          </div>
        ))}
      </div>

      <div className="divider-rose"><AR3 size={10}/> 学生评价 · TOP <AR3 size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        {[
          {n:'柳萤', c:'宋词鉴赏与吟诵', v:4.96},
          {n:'林玫', c:'鸿蒙开发综合实践', v:4.89},
          {n:'宋婉', c:'西方艺术史', v:4.84},
          {n:'周岑', c:'近代史纲要', v:4.76},
          {n:'谢敏', c:'机器学习导论', v:4.72},
        ].map((r,i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 0', borderTop: i?'1px dashed rgba(255,179,206,0.4)':'none'}}>
            <span className="font-display italic" style={{fontSize:18, color:'#A93C68', width:20, fontWeight:600}}>{i+1}</span>
            <div style={{flex:1, minWidth:0}}>
              <div style={{fontSize:12, fontWeight:600, color:'#4B2A38'}}>{r.n} 老师</div>
              <div style={{fontSize:10, color:'#7A5266', marginTop:2}}>{r.c}</div>
            </div>
            <div style={{display:'flex', gap:1.5}}>
              {[1,2,3,4,5].map(s=>(
                <svg key={s} width="11" height="11" viewBox="0 0 24 24" fill={s<=Math.round(r.v)?'#F2709C':'#FFD3E3'}>
                  <path d="M12 2 L14.5 9 L22 9 L16 13.5 L18 21 L12 16.5 L6 21 L8 13.5 L2 9 L9.5 9 Z"/>
                </svg>
              ))}
            </div>
            <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:14, color:'#A93C68', width:36, textAlign:'right', flexShrink:0}}>{r.v}</span>
          </div>
        ))}
      </div>

      <div className="divider-rose"><AR3 size={10}/> 问 卷 模 板 <AR3 size={10}/></div>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:10}}>
        {[
          {n:'教师课堂教学问卷', q:10, used:412, on:true},
          {n:'实验课程评教', q:8, used:64, on:true},
          {n:'体育课程问卷', q:6, used:18, on:true},
          {n:'毕业论文指导', q:12, used:0, on:false},
        ].map((s,i)=>(
          <div key={i} style={{padding:'12px', borderRadius:14, background:'linear-gradient(135deg,#FFFBF6,#FFE9F1)', border:'1px solid rgba(255,179,206,0.3)'}}>
            <span style={{
              padding:'2px 8px', borderRadius:999, fontSize:9, fontWeight:700,
              background: s.on ? 'linear-gradient(135deg,#E6F7E6,#D8F0D8)' : 'rgba(178,148,164,0.2)',
              color: s.on ? '#3F7A4A' : '#7A5266'
            }}>{s.on ? '启用' : '草稿'}</span>
            <div style={{fontSize:12, fontWeight:700, color:'#4B2A38', marginTop:8, lineHeight:1.4}}>{s.n}</div>
            <div style={{display:'flex', justifyContent:'space-between', marginTop:6, fontSize:9, color:'#7A5266'}}>
              <span>📝 {s.q} 题</span>
              <span>使用 {s.used}</span>
            </div>
          </div>
        ))}
      </div>
      <div style={{height:30}}/>
    </div>
  </AP3>
);

/* ─── A9 · Approval Center ─── */
const AdminApprovals = () => (
  <AP3>
    <AFC3 style={{top:-30, right:-30}}/>
    <ATB3 en="Approbations" title="审 批 中 心"/>
    <div className="scroll">
      <div style={{display:'flex', gap:6, marginBottom:12, overflowX:'auto'}}>
        {['待审批·18','已通过·142','已驳回·9','已撤回·3'].map((t,i)=>(
          <button key={i} style={atp3(i===0)}>{t}</button>
        ))}
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:10}}>
        {[
          {t:'学籍异动', n:'王 同学 · 20231203', s:'转专业 · 软件 → 计算机', time:'10·18 14:22', urg:true, ico:'❀', hl:true},
          {t:'缓考申请', n:'李 同学 · 20231408', s:'操作系统 · 期末 · 因病', time:'10·17 09:14', urg:true, ico:'✿'},
          {t:'课程替代', n:'陈 同学 · 20221102', s:'高数A → 高数B 替代', time:'10·16 16:08', ico:'❃'},
          {t:'请假申请', n:'赵 同学 · 20231104', s:'病假 · 10·22 全天', time:'10·15 11:30', ico:'❉'},
          {t:'毕业论文开题', n:'刘 同学 · 20211031', s:'开题报告提交', time:'10·14 18:42', ico:'❋'},
          {t:'辅修报名', n:'孙 同学 · 20231408', s:'数字媒体艺术 辅修', time:'10·12 10:21', ico:'✼'},
        ].map((a,i)=>(
          <div key={i} className="card" style={{padding:'12px', display:'flex', gap:12, alignItems:'center', background: a.hl ? 'rgba(255,228,238,0.4)' : undefined, position:'relative'}}>
            {a.hl && <div style={{position:'absolute', top:0, left:0, bottom:0, width:3, background:'#F2709C', borderRadius:'14px 0 0 14px'}}/>}
            <div style={{
              width:42, height:42, borderRadius:14, flexShrink:0,
              background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)',
              display:'flex', alignItems:'center', justifyContent:'center',
              color:'#A93C68', fontSize:18,
              border:'1px solid rgba(255,179,206,0.4)'
            }}>{a.ico}</div>
            <div style={{flex:1, minWidth:0}}>
              <div style={{display:'flex', alignItems:'center', gap:5, flexWrap:'wrap'}}>
                <span className="pill" style={{fontSize:9}}>{a.t}</span>
                {a.urg && <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#FFE0E0,#FFC8C8)', color:'#C04040', borderColor:'rgba(192,64,64,0.3)'}}>紧急</span>}
                <span style={{fontSize:9, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{a.time}</span>
              </div>
              <div style={{fontSize:12, fontWeight:700, color:'#4B2A38', marginTop:5}}>{a.n}</div>
              <div style={{fontSize:10, color:'#7A5266', marginTop:1, lineHeight:1.4}}>{a.s}</div>
            </div>
          </div>
        ))}
      </div>
      <div style={{height:30}}/>
    </div>
    <ATab3 active="app"/>
  </AP3>
);

/* ─── A9b · Approval Detail ─── */
const AdminApprovalDetail = () => (
  <AP3>
    <AFC3 style={{top:-30, right:-30}}/>
    <ATB3 en="Detail" title="审 批 详 情"/>
    <div className="scroll">
      <div style={{
        padding:'16px', borderRadius:20,
        background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)',
        position:'relative', overflow:'hidden'
      }}>
        <AFC3 style={{top:-30, right:-30, opacity:0.4}}/>
        <span className="pill" style={{background:'linear-gradient(135deg,#FFE0E0,#FFC8C8)', color:'#C04040', borderColor:'rgba(192,64,64,0.3)'}}>学籍异动 · 紧急</span>
        <div className="font-display italic" style={{fontSize:22, color:'#A93C68', marginTop:8}}>转专业申请</div>
        <div style={{fontSize:10, color:'#7A5266', marginTop:2, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>APP-2025-1018-0042</div>
      </div>

      <div className="divider-rose"><AR3 size={10}/> 申请人信息 <AR3 size={10}/></div>
      <div className="card" style={{padding:'14px', display:'grid', gridTemplateColumns:'1fr 1fr', gap:12}}>
        {[
          ['申请人', '王 瓦尔特'],
          ['学号', '20231203'],
          ['原专业', '软件工程'],
          ['目标专业', '计算机科学'],
          ['当前 GPA', '3.40'],
          ['班级', '软件 2304'],
        ].map(([k,v],i)=>(
          <div key={i}>
            <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.2em'}}>{k}</div>
            <div style={{fontSize:13, color:'#4B2A38', fontWeight:600, marginTop:3}}>{v}</div>
          </div>
        ))}
      </div>

      <div className="divider-rose"><AR3 size={10}/> 申请理由 <AR3 size={10}/></div>
      <div className="card-glow" style={{padding:'14px', fontSize:12, color:'#4B2A38', lineHeight:1.8}}>
        自入学以来，我对人工智能与算法方向产生浓厚兴趣，长期参加计算机学院实验室项目，认为转入计算机科学专业能更好地发挥个人优势 ...
      </div>

      <div className="divider-rose"><AR3 size={10}/> 审 批 流 程 <AR3 size={10}/></div>
      <div className="card" style={{padding:'14px'}}>
        {[
          {n:'学生提交', d:'10·15 · 已完成', who:'王瓦尔特', done:true},
          {n:'原院系审核', d:'10·17 · 已通过', who:'软件学院·张老师', done:true},
          {n:'目标院系审核', d:'当前节点', who:'计算机学院 · 待审', curr:true},
          {n:'教务处终审', d:'待审', who:'教务处'},
          {n:'流程结束', d:'—', who:'—'},
        ].map((s,i)=>(
          <div key={i} style={{display:'flex', gap:12, paddingBottom: i<4?14:0, position:'relative'}}>
            {i<4 && <div style={{position:'absolute', left:14, top:30, bottom:0, width:1, background:'linear-gradient(180deg, rgba(255,179,206,0.6), rgba(255,179,206,0.2))'}}/>}
            <div style={{
              width:30, height:30, borderRadius:'50%',
              background: s.done ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : (s.curr ? 'rgba(255,255,255,0.9)' : 'rgba(255,237,245,0.5)'),
              border: s.curr ? '2px solid #F2709C' : 'none',
              display:'flex', alignItems:'center', justifyContent:'center',
              color: s.done ? '#fff' : '#A93C68', fontSize:12, fontWeight:700,
              flexShrink:0, zIndex:1
            }}>{s.done ? '✓' : (i+1)}</div>
            <div style={{flex:1}}>
              <div style={{fontSize:12, color: s.curr?'#A93C68':'#4B2A38', fontWeight: s.curr?700:600}}>{s.n}</div>
              <div style={{fontSize:10, color:'#7A5266', marginTop:2}}>{s.d}</div>
              <div style={{fontSize:10, color:'#B294A4', marginTop:1}}>{s.who}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="divider-rose"><AR3 size={10}/> 审 批 意 见 <AR3 size={10}/></div>
      <textarea className="input" rows={3} style={{minHeight:84, resize:'none'}} placeholder="请填写审批意见..."/>

      <div style={{display:'flex', gap:10, marginTop:14, marginBottom:30}}>
        <button className="btn-ghost" style={{flex:1, color:'#C04040', borderColor:'rgba(192,64,64,0.3)'}}>驳 回</button>
        <button className="btn-primary" style={{flex:1.5}}>✦ 同 意 通 过</button>
      </div>
    </div>
  </AP3>
);

/* ─── A10 · Admin Profile / Settings ─── */
const AdminProfile = () => (
  <AP3>
    <AFC3 style={{top:-30, right:-30}}/>
    <AFC3 flip style={{bottom:80, left:-40}}/>

    <div style={{
      padding:'14px 18px 22px',
      background:'linear-gradient(180deg, #FFD3E3 0%, #FFE4EE 60%, transparent 100%)',
    }}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:18}}>
        <div className="font-display italic" style={{fontSize:14, color:'#A93C68'}}>Salon de Madame</div>
        <button style={mIco3}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="12" cy="12" r="3"/><path d="M19 12c0 1-0.4 2-0.8 2.8l1.6 1.4-2 3.4-2.2-0.8c-0.8 0.5-1.7 0.8-2.7 1L12.5 22h-3l-0.4-2.2c-1-0.2-1.9-0.5-2.7-1L4.2 19.6l-2-3.4 1.6-1.4C3.4 14 3 13 3 12s0.4-2 0.8-2.8L2.2 7.8l2-3.4 2.2 0.8c0.8-0.5 1.7-0.8 2.7-1L9.5 2h3l0.4 2.2c1 0.2 1.9 0.5 2.7 1L17.8 4.4l2 3.4-1.6 1.4C18.6 10 19 11 19 12z"/></svg></button>
      </div>

      <div style={{display:'flex', alignItems:'center', gap:14}}>
        <AM3 size={72}/>
        <div style={{flex:1}}>
          <div className="font-display italic" style={{fontSize:24, color:'#A93C68'}}>艾莉萨白 · 老师</div>
          <div style={{fontSize:11, color:'#7A5266', marginTop:2}}>教务处 · 超级管理员</div>
          <div style={{display:'flex', gap:6, marginTop:6}}>
            <span className="pill" style={{fontSize:9}}>SUPER ADMIN</span>
            <span className="pill" style={{fontSize:9, background:'linear-gradient(135deg,#E6F7E6,#D8F0D8)', color:'#3F7A4A'}}>在线</span>
          </div>
        </div>
      </div>

      <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:6, marginTop:16, background:'rgba(255,255,255,0.65)', borderRadius:16, padding:'10px 4px'}}>
        {[
          {v:'186', k:'今日审批'},
          {v:'4.8h', k:'平均时长'},
          {v:'18', k:'待办'},
          {v:'99%', k:'通过率'},
        ].map((s,i)=>(
          <div key={i} style={{textAlign:'center', borderRight: i<3 ? '1px dashed rgba(255,179,206,0.6)' : 'none'}}>
            <div className="font-display italic" style={{fontSize:16, color:'#A93C68'}}>{s.v}</div>
            <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.15em'}}>{s.k}</div>
          </div>
        ))}
      </div>
    </div>

    <div className="scroll" style={{paddingTop:4}}>
      <div className="divider-rose"><AR3 size={10}/> 角色与权限 <AR3 size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        {[
          {ico:'❀', t:'角色管理', s:'8 个角色 · 32 项权限'},
          {ico:'✿', t:'权限矩阵', s:'8 模块 × 6 操作'},
          {ico:'❁', t:'我的权限', s:'超级管理员 · 全部 32 项'},
          {ico:'❃', t:'操作日志', s:'本月 1,284 条操作'},
        ].map((s,i)=>(<AdRow key={i} {...s}/>))}
      </div>

      <div className="divider-rose"><AR3 size={10}/> 系 统 设 置 <AR3 size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        {[
          {ico:'❉', t:'学期与校历', s:'2025-2026-1 · 第 9 周'},
          {ico:'✼', t:'审批流配置', s:'已配置 12 条流程'},
          {ico:'✉', t:'消息模板', s:'通知 · 短信 · 邮件'},
          {ico:'🔒', t:'安全策略', s:'密码 · 登录 · 二步验证'},
          {ico:'☾', t:'夜间模式', s:'跟随系统', toggle:true},
          {ico:'🔔', t:'消息推送', s:'选课 · 审批 · 提醒', toggle:true},
        ].map((s,i)=>(<AdRow key={i} {...s}/>))}
      </div>

      <div className="divider-rose"><AR3 size={10}/> 关于与账户 <AR3 size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px', marginBottom:30}}>
        {[
          {ico:'ⓘ', t:'关于系统', s:'教务管理 v1.1.0 · 鸿蒙'},
          {ico:'⌘', t:'修改密码', s:'上次修改 · 60 天前'},
          {ico:'⏏', t:'退出登录', s:'清除本地凭据', danger:true},
        ].map((s,i)=>(<AdRow key={i} {...s}/>))}
      </div>
    </div>
    <ATab3 active="me"/>
  </AP3>
);

const AdRow = ({ico, t, s, toggle, danger}) => (
  <div style={{display:'flex', alignItems:'center', gap:12, padding:'10px 0', borderTop:'1px dashed rgba(255,179,206,0.45)'}}>
    <div style={{
      width:34, height:34, borderRadius:11,
      background: 'linear-gradient(135deg,#FFFFFF,#F1E2FF)',
      display:'flex', alignItems:'center', justifyContent:'center',
      color: danger ? '#C04040' : '#A93C68', fontSize:14
    }}>{ico}</div>
    <div style={{flex:1}}>
      <div style={{fontSize:12.5, fontWeight:600, color: danger ? '#C04040' : '#4B2A38'}}>{t}</div>
      <div style={{fontSize:10, color:'#7A5266', marginTop:2}}>{s}</div>
    </div>
    {toggle ? (
      <div style={{width:36, height:20, borderRadius:999, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', position:'relative'}}>
        <div style={{position:'absolute', top:2, right:2, width:16, height:16, borderRadius:'50%', background:'#fff', boxShadow:'0 1px 3px rgba(0,0,0,0.2)'}}/>
      </div>
    ) : (
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#B294A4" strokeWidth="2"><path d="M9 6l6 6-6 6"/></svg>
    )}
  </div>
);

Object.assign(window, { AdminEval, AdminApprovals, AdminApprovalDetail, AdminProfile });
