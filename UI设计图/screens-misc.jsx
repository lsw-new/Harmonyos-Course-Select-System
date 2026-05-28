/* Evaluation, Leave, Feedback, Practice & Public services */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder, TabBar, iconBtn, tabPill, Field } = window;

const EvalListScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Evaluation" title="量 化 评 教"/>
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
        <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>Voice of the Rose</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:6, lineHeight:1.5}}>
          每一份诚挚的反馈，都是花瓣般温柔的力量。请于 <b style={{color:'#A93C68'}}>11·05 24:00</b> 前完成本学期教师评教问卷。
        </div>
        <div style={{display:'flex', alignItems:'baseline', gap:8, marginTop:10}}>
          <span className="font-display italic" style={{fontSize:32, color:'#A93C68'}}>2 / 6</span>
          <span style={{fontSize:11, color:'#7A5266'}}>已完成</span>
        </div>
        <div style={{height:6, background:'rgba(255,255,255,0.6)', borderRadius:3, marginTop:6, overflow:'hidden'}}>
          <div style={{width:'33%', height:'100%', background:'linear-gradient(90deg,#F2709C,#B589FF)'}}/>
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> tasks <Rose size={10}/></div>

      {[
        {name:'鸿蒙应用开发综合实践', code:'SE-4023.01', cls:'专业拓展', t:'林玫', status:'open', q:'教师课堂教学情况学生问卷调查'},
        {name:'软件工程经济学', code:'SE-3041.02', cls:'专业选修', t:'苏柔', status:'open', q:'教师课堂教学情况学生问卷调查'},
        {name:'操作系统', code:'CS-3022.03', cls:'专业必修', t:'王素', status:'done', q:'教师课堂教学情况学生问卷调查'},
        {name:'近代史纲要', code:'GE-1003.05', cls:'通识必修', t:'周岑', status:'done', q:'教师课堂教学情况学生问卷调查'},
        {name:'宋词鉴赏与吟诵', code:'GE-2031.02', cls:'通识选修', t:'柳萤', status:'closed', q:'教师课堂教学情况学生问卷调查'},
        {name:'体育 · 网球', code:'PE-2011.04', cls:'实践教学', t:'陈宇', status:'open', q:'体育课程学生问卷调查'},
      ].map((task,i)=><EvalCard key={i} {...task}/>)}
    </div>
  </Phone>
);

const EvalCard = ({name, code, cls, t, status, q}) => {
  const cfg = {
    open:{label:'去评教', bg:'linear-gradient(135deg,#FF9FBE,#F2709C)', color:'#fff'},
    done:{label:'已提交', bg:'rgba(232,242,232,0.6)', color:'#3F7A4A', border:'1px solid rgba(63,122,74,0.3)'},
    closed:{label:'不在开放时间', bg:'rgba(178,148,164,0.15)', color:'#B294A4', border:'1px solid rgba(178,148,164,0.3)'},
  }[status];
  return (
    <div className="card" style={{padding:'14px', marginBottom:10}}>
      <div style={{display:'flex', alignItems:'flex-start', gap:10}}>
        <div style={{
          width:38, height:38, borderRadius:'50%', flexShrink:0,
          background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)',
          display:'flex', alignItems:'center', justifyContent:'center',
          color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', fontSize:15, fontWeight:600
        }}>{t.charAt(0)}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontSize:12.5, fontWeight:700, color:'#4B2A38'}}>{name}</div>
          <div style={{fontSize:10, color:'#B294A4', marginTop:2}}>
            <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{code}</span> · {cls} · {t}老师
          </div>
        </div>
      </div>
      <div style={{
        marginTop:10, padding:'8px 10px', borderRadius:10,
        background:'rgba(255,237,245,0.5)',
        fontSize:11, color:'#7A5266',
        display:'flex', justifyContent:'space-between', alignItems:'center'
      }}>
        <span>📝 {q}</span>
        <button style={{
          padding:'6px 12px', borderRadius:999, fontSize:10, fontWeight:700,
          background:cfg.bg, color:cfg.color, border:cfg.border||'none', cursor:'pointer'
        }}>{cfg.label}</button>
      </div>
    </div>
  );
};

const EvalFormScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Survey" title="评 教 问 卷"/>
    <div className="scroll">
      <div style={{
        padding:'14px 16px', borderRadius:18,
        background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)',
      }}>
        <div className="font-display italic" style={{fontSize:16, color:'#A93C68'}}>For Teacher 林玫</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:4}}>
          鸿蒙应用开发综合实践 · 教师课堂教学情况学生问卷调查
        </div>
        <div style={{height:4, background:'rgba(255,255,255,0.6)', borderRadius:2, marginTop:10, overflow:'hidden'}}>
          <div style={{width:'40%', height:'100%', background:'linear-gradient(90deg,#F2709C,#B589FF)'}}/>
        </div>
        <div style={{fontSize:10, color:'#7A5266', marginTop:4}}>进度 · 4 / 10</div>
      </div>

      <div className="card" style={{padding:'16px', marginTop:14}}>
        <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em'}}>Q · 04 · 单选</div>
        <div style={{fontSize:13, fontWeight:600, color:'#4B2A38', marginTop:6, lineHeight:1.5}}>
          教师能合理设计教学环节，关注学生参与度
        </div>
        <div style={{display:'flex', flexDirection:'column', gap:8, marginTop:14}}>
          {[
            ['非常满意','5'],['比较满意','4'],['一般','3'],['不太满意','2'],['不满意','1']
          ].map(([l,n],i)=>(
            <label key={i} style={{
              display:'flex', alignItems:'center', gap:10,
              padding:'10px 12px', borderRadius:12,
              background: i===0 ? 'linear-gradient(135deg,#FFE4EE,#F1E2FF)' : 'rgba(255,255,255,0.6)',
              border: i===0 ? '1px solid rgba(242,112,156,0.5)' : '1px solid rgba(255,179,206,0.3)',
              cursor:'pointer'
            }}>
              <span style={{
                width:20, height:20, borderRadius:'50%',
                background: i===0 ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : 'rgba(255,255,255,0.8)',
                border: i===0 ? 'none' : '1px solid rgba(255,179,206,0.5)',
                display:'flex', alignItems:'center', justifyContent:'center'
              }}>
                {i===0 && <span style={{width:8, height:8, borderRadius:'50%', background:'#fff'}}/>}
              </span>
              <span style={{flex:1, fontSize:12.5, color: i===0 ? '#A93C68' : '#4B2A38', fontWeight: i===0 ? 600 : 400}}>{l}</span>
              <span style={{fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', color:'#B294A4', fontSize:14}}>{n}</span>
            </label>
          ))}
        </div>
      </div>

      <div className="card" style={{padding:'16px', marginTop:14}}>
        <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em'}}>Q · 05 · 主观题</div>
        <div style={{fontSize:13, fontWeight:600, color:'#4B2A38', marginTop:6, lineHeight:1.5}}>
          您对这门课程有什么建议？
        </div>
        <textarea className="input" rows={3} placeholder="温柔地分享你的想法吧 ✿" style={{marginTop:10, resize:'none', minHeight:84}}/>
        <div style={{textAlign:'right', fontSize:10, color:'#B294A4', marginTop:4}}>0 / 500</div>
      </div>

      <div style={{display:'flex', gap:10, marginTop:16}}>
        <button className="btn-ghost" style={{flex:1}}>上一题</button>
        <button className="btn-primary" style={{flex:1.4}}>下 一 题 · NEXT</button>
      </div>
    </div>
  </Phone>
);

const LeaveScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Leave" title="请 假 申 请"/>
    <div className="scroll">
      <div style={{display:'flex', gap:6, marginBottom:12}}>
        {['新建申请','我的申请·3'].map((t,i)=>(
          <button key={i} style={tabPill(i===0)}>{t}</button>
        ))}
      </div>

      <div className="card-glow" style={{padding:'16px'}}>
        <label style={{display:'block', marginBottom:12}}>
          <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>类型 · TYPE</div>
          <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:6}}>
            {['事假','病假','其他'].map((t,i)=>(
              <button key={i} style={{
                padding:'10px', borderRadius:12, fontSize:12, fontWeight:600,
                background: i===1 ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : 'rgba(255,255,255,0.7)',
                color: i===1 ? '#fff' : '#A93C68',
                border: i===1 ? 'none' : '1px solid rgba(255,179,206,0.5)',
              }}>{t}</button>
            ))}
          </div>
        </label>

        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:10}}>
          <div>
            <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>开始 · FROM</div>
            <div className="input" style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
              <span>10·22 08:00</span>
              <Rose size={12}/>
            </div>
          </div>
          <div>
            <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>结束 · TO</div>
            <div className="input" style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
              <span>10·22 17:30</span>
              <Rose size={12}/>
            </div>
          </div>
        </div>

        <div style={{marginTop:12}}>
          <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>事由 · REASON</div>
          <textarea className="input" rows={4} style={{minHeight:88, resize:'none'}} placeholder="请简述请假事由..." defaultValue="因身体不适需至校医院就医，附就诊证明。"/>
        </div>

        <div style={{marginTop:12}}>
          <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>附件 · ATTACHMENT</div>
          <div style={{display:'flex', gap:8}}>
            <Placeholder w={64} h={64} label="附件1" radius={12}/>
            <div style={{
              width:64, height:64, borderRadius:12,
              border:'1px dashed rgba(255,179,206,0.6)',
              display:'flex', alignItems:'center', justifyContent:'center',
              color:'#A93C68', fontSize:24, fontWeight:300
            }}>+</div>
          </div>
        </div>
      </div>

      <div style={{display:'flex', gap:10, marginTop:16}}>
        <button className="btn-ghost" style={{flex:1}}>保 存 草 稿</button>
        <button className="btn-primary" style={{flex:1.4}}>提 交 申 请</button>
      </div>

      <div className="divider-rose"><Rose size={10}/> previous · 3 <Rose size={10}/></div>

      {[
        {type:'病假', date:'09·28–09·29', status:'已通过', color:'#3F7A4A'},
        {type:'事假', date:'09·15', status:'待审批', color:'#A8854A'},
        {type:'病假', date:'08·22', status:'已驳回', color:'#A93C68'},
      ].map((l,i)=>(
        <div key={i} className="card" style={{padding:'12px 14px', marginBottom:8, display:'flex', alignItems:'center', gap:10}}>
          <span className="pill">{l.type}</span>
          <span style={{fontSize:11, color:'#7A5266', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{l.date}</span>
          <span style={{marginLeft:'auto', fontSize:11, fontWeight:600, color:l.color}}>{l.status}</span>
        </div>
      ))}
    </div>
  </Phone>
);

const FeedbackScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Feedback" title="意 见 反 馈"/>
    <div className="scroll">
      <div style={{
        padding:'16px',
        borderRadius:22,
        background:'linear-gradient(135deg, #FFE4EE 0%, #F1E2FF 100%)',
      }}>
        <div className="font-display italic" style={{fontSize:20, color:'#A93C68'}}>Tell us, gently.</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:4, lineHeight:1.5}}>
          一束玫瑰，一份心意 —— 我们倾听每一片花瓣的声音。
        </div>
      </div>

      <div style={{marginTop:14}}>
        <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:8}}>类型</div>
        <div style={{display:'flex', gap:8, flexWrap:'wrap'}}>
          {[
            {icon:'🪷', t:'Bug 反馈', active:true},
            {icon:'✿', t:'功能建议'},
            {icon:'❀', t:'界面体验'},
            {icon:'⌘', t:'其他'},
          ].map((c,i)=>(
            <button key={i} style={{
              padding:'10px 14px', borderRadius:14, fontSize:12, fontWeight:600,
              display:'flex', alignItems:'center', gap:6,
              background: c.active ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : 'rgba(255,255,255,0.7)',
              color: c.active ? '#fff' : '#A93C68',
              border: c.active ? 'none' : '1px solid rgba(255,179,206,0.5)',
            }}><span>{c.icon}</span>{c.t}</button>
          ))}
        </div>
      </div>

      <Field label="标题" placeholder="一句话概括..." />
      <div style={{height:10}}/>
      <div>
        <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>正文 · CONTENT</div>
        <textarea className="input" rows={5} style={{minHeight:100, resize:'none'}} placeholder="描述你的发现或建议..."/>
      </div>

      <Field label="联系方式 (可选)" placeholder="elysia@school.edu.cn" />

      <div style={{marginTop:12}}>
        <div style={{fontSize:10, color:'#A93C68', letterSpacing:'0.3em', marginBottom:6}}>截图 · UP TO 3</div>
        <div style={{display:'flex', gap:8}}>
          <Placeholder w={64} h={64} label="img1" radius={12}/>
          <Placeholder w={64} h={64} label="img2" radius={12}/>
          <div style={{
            width:64, height:64, borderRadius:12,
            border:'1px dashed rgba(255,179,206,0.6)',
            display:'flex', alignItems:'center', justifyContent:'center',
            color:'#A93C68', fontSize:24, fontWeight:300
          }}>+</div>
        </div>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:18}}>
        投 递 信 笺 · SEND
      </button>

      <div className="divider-rose"><Rose size={10}/> previous <Rose size={10}/></div>

      {[
        {tag:'Bug 反馈', title:'课表夜间模式色彩对比不够', status:'已回复', date:'10·12'},
        {tag:'功能建议', title:'希望成绩页支持对比', status:'处理中', date:'10·05'},
      ].map((f,i)=>(
        <div key={i} className="card" style={{padding:'12px 14px', marginBottom:8}}>
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <span className="pill" style={{fontSize:9}}>{f.tag}</span>
            <span style={{marginLeft:'auto', fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{f.date}</span>
          </div>
          <div style={{fontSize:12, color:'#4B2A38', fontWeight:600, marginTop:5}}>{f.title}</div>
          <div style={{fontSize:11, color:'#A93C68', marginTop:3}}>● {f.status}</div>
        </div>
      ))}
    </div>
  </Phone>
);

const PracticeScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Practice" title="实 践 与 公 服" back={false}/>
    <div className="scroll">
      <div style={{
        borderRadius:22, padding:'18px',
        background:'linear-gradient(135deg, #FFE4EE 0%, #FBE8D8 100%)',
        position:'relative', overflow:'hidden'
      }}>
        <FloralCorner style={{top:-30, right:-30, opacity:0.4}}/>
        <span className="pill">2025 · 秋</span>
        <div className="font-display italic" style={{fontSize:22, color:'#A93C68', marginTop:8}}>Atelier · 实践集</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:4, maxWidth:220, lineHeight:1.5}}>
          实习、实训、社会实践与公共服务，皆汇于此处。
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> 实践模块 <Rose size={10}/></div>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:10}}>
        {[
          {en:'Intern', zh:'实习实践', desc:'企业 / 顶岗实习记录', count:'1'},
          {en:'Atelier', zh:'集中实践', desc:'实训 · 项目 · 课程设计', count:'3'},
          {en:'Field', zh:'社会实践', desc:'暑期社会调研', count:'2'},
          {en:'Service', zh:'志愿服务', desc:'校园 / 社会志愿', count:'5'},
        ].map((m,i)=>(
          <div key={i} className="card" style={{padding:'14px', position:'relative', overflow:'hidden'}}>
            <Sparkle size={14} style={{position:'absolute', top:10, right:10, opacity:0.5}}/>
            <div className="font-display italic" style={{fontSize:16, color:'#A93C68'}}>{m.en}</div>
            <div style={{fontSize:12, fontWeight:600, color:'#4B2A38', marginTop:2}}>{m.zh}</div>
            <div style={{fontSize:10, color:'#7A5266', marginTop:6, lineHeight:1.4}}>{m.desc}</div>
            <div style={{display:'flex', alignItems:'baseline', gap:4, marginTop:10}}>
              <span className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>{m.count}</span>
              <span style={{fontSize:10, color:'#B294A4'}}>条记录</span>
            </div>
          </div>
        ))}
      </div>

      <div className="divider-rose"><Rose size={10}/> 公共服务 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'6px 4px'}}>
        {[
          {ico:'❀', t:'办事指南', s:'校园办事流程与表格下载'},
          {ico:'✿', t:'常用链接', s:'图书馆 · 教务 · 校园卡'},
          {ico:'❁', t:'失物招领', s:'最近 12 条物品信息'},
          {ico:'❃', t:'空教室查询', s:'按校区 / 楼栋 / 节次'},
          {ico:'✾', t:'缴费查询', s:'学费 · 住宿 · 杂费'},
        ].map((s,i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', gap:12, padding:'10px 12px', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none'}}>
            <div style={{width:36, height:36, borderRadius:12, background:'linear-gradient(135deg,#FFE4EE,#EFDFFF)', display:'flex', alignItems:'center', justifyContent:'center', color:'#A93C68', fontSize:16}}>{s.ico}</div>
            <div style={{flex:1}}>
              <div style={{fontSize:12.5, fontWeight:600, color:'#4B2A38'}}>{s.t}</div>
              <div style={{fontSize:10, color:'#7A5266', marginTop:2}}>{s.s}</div>
            </div>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#B294A4" strokeWidth="2"><path d="M9 6l6 6-6 6"/></svg>
          </div>
        ))}
      </div>
    </div>
    <TabBar active="pra"/>
  </Phone>
);

Object.assign(window, { EvalListScreen, EvalFormScreen, LeaveScreen, FeedbackScreen, PracticeScreen });
