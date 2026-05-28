/* Profile screens — Mine (profile center), Account, Edit info, Settings, Password */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder, TabBar, iconBtn, Field, Cell } = window;

const MineScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <FloralCorner flip style={{bottom:80, left:-40}}/>

    {/* Hero w/ gradient */}
    <div style={{
      position:'relative',
      padding:'14px 18px 22px',
      background:'linear-gradient(180deg, #FFD3E3 0%, #FFE4EE 60%, transparent 100%)',
    }}>
      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:18}}>
        <div className="font-display italic" style={{fontSize:14, color:'#A93C68'}}>Salon de Elysée</div>
        <div style={{display:'flex', gap:8}}>
          <button style={iconBtn}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#A93C68" strokeWidth="1.6"><circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 1-0.7 3l2 1.5-2 3.5-2.3-1A7 7 0 0 1 13 21l-0.3 2h-3l-0.3-2a7 7 0 0 1-3-1l-2.3 1-2-3.5 2-1.5A7 7 0 0 1 3.6 13l-2-0.5v-1l2-0.5A7 7 0 0 1 4.7 8l-2-1.5 2-3.5L7 4A7 7 0 0 1 10 3l0.3-2h3l0.3 2a7 7 0 0 1 3 1L19 3l2 3.5-2 1.5"/></svg></button>
        </div>
      </div>

      <div style={{display:'flex', alignItems:'center', gap:14}}>
        <div style={{position:'relative'}}>
          <Monogram size={72}/>
          <div style={{
            position:'absolute', bottom:-2, right:-2,
            width:22, height:22, borderRadius:'50%',
            background:'linear-gradient(135deg,#FF9FBE,#F2709C)',
            border:'2px solid #FFF',
            display:'flex', alignItems:'center', justifyContent:'center'
          }}>
            <Heart size={10} color="#fff"/>
          </div>
        </div>
        <div style={{flex:1}}>
          <div className="font-display italic" style={{fontSize:24, color:'#A93C68'}}>Elysia · 同学</div>
          <div style={{fontSize:11, color:'#7A5266', marginTop:2}}>软件学院 · 软件工程 2304</div>
          <div style={{fontSize:10, color:'#B294A4', marginTop:4, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>SID · 20231104</div>
        </div>
      </div>

      {/* Quick stats */}
      <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:6, marginTop:16, background:'rgba(255,255,255,0.65)', borderRadius:16, padding:'10px 4px'}}>
        {[
          {v:'3.86', k:'GPA'},
          {v:'21.5', k:'学分'},
          {v:'06', k:'待评教'},
          {v:'02', k:'待办'},
        ].map((s,i)=>(
          <div key={i} style={{textAlign:'center', borderRight: i<3 ? '1px dashed rgba(255,179,206,0.6)' : 'none'}}>
            <div className="font-display italic" style={{fontSize:18, color:'#A93C68'}}>{s.v}</div>
            <div style={{fontSize:9, color:'#7A5266', letterSpacing:'0.2em'}}>{s.k}</div>
          </div>
        ))}
      </div>
    </div>

    <div className="scroll" style={{paddingTop:4}}>
      {/* primary entries */}
      <div style={{display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:10, marginBottom:16}}>
        {[
          {ico:'❀', t:'课表'},
          {ico:'✿', t:'成绩'},
          {ico:'❁', t:'选课'},
          {ico:'❃', t:'学籍'},
          {ico:'✾', t:'考试'},
          {ico:'❋', t:'评教'},
          {ico:'✼', t:'通知'},
          {ico:'❉', t:'更多'},
        ].map((q,i)=>(
          <div key={i} style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
            <div style={{
              width:46, height:46, borderRadius:14,
              background:'linear-gradient(135deg,#FFFFFF,#FFE9F1)',
              border:'1px solid rgba(255,179,206,0.5)',
              display:'flex', alignItems:'center', justifyContent:'center',
              fontSize:18, color:'#A93C68'
            }}>{q.ico}</div>
            <div style={{fontSize:10, color:'#7A5266'}}>{q.t}</div>
          </div>
        ))}
      </div>

      <div className="divider-rose"><Rose size={10}/> 我的事务 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        {[
          {ico:'👤', t:'我的账户', s:'账号信息 · 状态 · 有效期', badge:null},
          {ico:'✎', t:'修改个人信息', s:'手机 · 邮箱 · 头像 · 联系人', badge:null},
          {ico:'⌘', t:'修改密码', s:'强度建议 · 8 位以上', badge:null},
          {ico:'🌸', t:'我的请假', s:'3 条记录', badge:'1'},
          {ico:'📜', t:'办事大厅', s:'课程替代 · 缓考 · 转专业…', badge:null},
        ].map((s,i)=>(
          <RowEntry key={i} {...s}/>
        ))}
      </div>

      <div className="divider-rose"><Rose size={10}/> 偏好与系统 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px', marginBottom:30}}>
        {[
          {ico:'⚙', t:'系统设置', s:'消息 · 缓存 · 深色模式'},
          {ico:'💌', t:'意见反馈', s:'帮我们变得更好'},
          {ico:'☾', t:'夜间模式', s:'减少屏幕灼伤', toggle:true},
          {ico:'ⓘ', t:'关于', s:'v1.1.0 · 协议 · 隐私政策'},
          {ico:'⏏', t:'退出登录', s:'清除本地凭据', danger:true},
        ].map((s,i)=>(<RowEntry key={i} {...s}/>))}
      </div>
    </div>
    <TabBar active="mine"/>
  </Phone>
);

const RowEntry = ({ico, t, s, badge, toggle, danger}) => (
  <div style={{display:'flex', alignItems:'center', gap:12, padding:'10px 0', borderTop:'1px dashed rgba(255,179,206,0.45)'}}>
    <div style={{
      width:34, height:34, borderRadius:11,
      background: danger ? 'linear-gradient(135deg,#FFE4EE,#FFD3E3)' : 'linear-gradient(135deg,#FFFFFF,#F1E2FF)',
      display:'flex', alignItems:'center', justifyContent:'center',
      color: danger ? '#A93C68' : '#A93C68', fontSize:14
    }}>{ico}</div>
    <div style={{flex:1}}>
      <div style={{fontSize:12.5, fontWeight:600, color: danger ? '#A93C68' : '#4B2A38'}}>{t}</div>
      <div style={{fontSize:10, color:'#7A5266', marginTop:2}}>{s}</div>
    </div>
    {badge && (
      <span style={{
        background:'linear-gradient(135deg,#FF9FBE,#F2709C)', color:'#fff',
        fontSize:9, fontWeight:700, padding:'2px 7px', borderRadius:999
      }}>{badge}</span>
    )}
    {toggle ? (
      <div style={{width:36, height:20, borderRadius:999, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', position:'relative', boxShadow:'inset 0 1px 3px rgba(0,0,0,0.1)'}}>
        <div style={{position:'absolute', top:2, right:2, width:16, height:16, borderRadius:'50%', background:'#fff', boxShadow:'0 1px 3px rgba(0,0,0,0.2)'}}/>
      </div>
    ) : (
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#B294A4" strokeWidth="2"><path d="M9 6l6 6-6 6"/></svg>
    )}
  </div>
);

const AccountScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Account" title="我 的 账 户"/>
    <div className="scroll">
      <div style={{
        borderRadius:24, padding:'20px',
        background:'linear-gradient(135deg, #FFD3E3 0%, #EFDFFF 70%, #FFF1D6 100%)',
        position:'relative', overflow:'hidden',
      }}>
        <FloralCorner style={{top:-30, right:-30, opacity:0.4}}/>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-start'}}>
          <Monogram size={56}/>
          <span className="pill" style={{background:'rgba(255,255,255,0.7)'}}>激活</span>
        </div>
        <div className="font-display italic" style={{fontSize:24, color:'#A93C68', marginTop:14}}>Elysia</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:2}}>20231104 · elysia@school.edu.cn</div>
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8, marginTop:14, fontSize:11, color:'#4B2A38'}}>
          <Cell k="账号状态" v="正常 ✦"/>
          <Cell k="有效期起算" v="2023·09·01"/>
          <Cell k="创建日期" v="2023·09·01"/>
          <Cell k="最近修改" v="2025·09·12"/>
          <Cell k="密码策略" v="永不过期"/>
          <Cell k="登录次数" v="142"/>
        </div>
      </div>

      <div className="divider-rose"><Rose size={10}/> 快捷操作 <Rose size={10}/></div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:10}}>
        {[
          {ico:'⌘', t:'修改密码'},
          {ico:'📷', t:'更换头像'},
          {ico:'⏏', t:'退出登录'},
        ].map((q,i)=>(
          <button key={i} className="card" style={{padding:'14px 6px', textAlign:'center', cursor:'pointer'}}>
            <div style={{fontSize:24, color:'#A93C68', marginBottom:6}}>{q.ico}</div>
            <div style={{fontSize:11, color:'#4B2A38', fontWeight:600}}>{q.t}</div>
          </button>
        ))}
      </div>

      <div className="divider-rose"><Rose size={10}/> 登录历史 · LATEST <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px', marginBottom:30}}>
        {[
          {t:'10·19 23:47', ip:'校园网 · 桂林', d:'42 min'},
          {t:'10·18 09:12', ip:'校园网 · 桂林', d:'2 h 14 min'},
          {t:'10·15 14:30', ip:'移动网络 · 桂林', d:'1 h 02 min'},
          {t:'10·12 21:00', ip:'校园网 · 桂林', d:'38 min'},
        ].map((l,i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', gap:10, padding:'10px 0', borderTop:i?'1px dashed rgba(255,179,206,0.5)':'none'}}>
            <span style={{width:8, height:8, borderRadius:'50%', background:'#F2709C'}}/>
            <div style={{flex:1}}>
              <div style={{fontSize:12, color:'#4B2A38', fontWeight:600, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>{l.t}</div>
              <div style={{fontSize:10, color:'#7A5266'}}>{l.ip}</div>
            </div>
            <span style={{fontSize:10, color:'#B294A4'}}>在线 {l.d}</span>
          </div>
        ))}
      </div>
    </div>
  </Phone>
);

const EditInfoScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Edit Profile" title="修 改 资 料"
      right={<button style={{...iconBtn, width:'auto', padding:'0 12px', fontSize:11, color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>save</button>}
    />
    <div className="scroll">
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', padding:'10px 0 18px'}}>
        <div style={{position:'relative'}}>
          <Monogram size={84}/>
          <div style={{
            position:'absolute', bottom:0, right:0,
            width:26, height:26, borderRadius:'50%',
            background:'linear-gradient(135deg,#FF9FBE,#F2709C)',
            border:'2px solid #fff', display:'flex', alignItems:'center', justifyContent:'center'
          }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2"><rect x="3" y="7" width="18" height="14" rx="2"/><circle cx="12" cy="14" r="3.5"/><path d="M9 7l1-3h4l1 3"/></svg>
          </div>
        </div>
        <span style={{fontSize:10, color:'#A93C68', marginTop:8, fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>change avatar</span>
      </div>

      <div className="divider-rose"><Rose size={10}/> 可编辑 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        <EditRow label="手机号" value="138 0013 8888"/>
        <EditRow label="邮箱" value="elysia@school.edu.cn"/>
        <EditRow label="通讯地址" value="桂林市 · 雁山区"/>
        <EditRow label="紧急联系人" value="艾莉萨白 · 138••••8000"/>
        <EditRow label="个人简介" value="若一切尽善尽美，也只剩玫瑰..."/>
      </div>

      <div className="divider-rose"><Rose size={10}/> 只读字段 (由教务同步) <Rose size={10}/></div>
      <div className="card" style={{padding:'4px 14px', marginBottom:14, opacity:0.85}}>
        {[
          ['学号','20231104'],
          ['姓名','艾莉希雅'],
          ['学院','软件学院'],
          ['专业','软件工程'],
          ['班级','软件 2304'],
        ].map(([k,v],i)=>(
          <div key={i} style={{display:'flex', justifyContent:'space-between', padding:'10px 0', borderTop: i?'1px dashed rgba(255,179,206,0.5)':'none', fontSize:12}}>
            <span style={{color:'#7A5266'}}>{k}</span>
            <span style={{color:'#4B2A38', fontWeight:600}}>{v}</span>
          </div>
        ))}
      </div>

      <div style={{
        padding:'12px 14px', borderRadius:14,
        background:'rgba(255,237,213,0.7)', border:'1px dashed rgba(217,182,117,0.5)',
        fontSize:11, color:'#A8854A', lineHeight:1.5, marginBottom:80
      }}>
        ✦ 学籍字段如需变更，请前往 <b>资料申请修改</b> 提交申请。当前有 1 条审批中。
      </div>
    </div>
  </Phone>
);

const EditRow = ({label, value}) => (
  <div style={{display:'flex', alignItems:'center', gap:8, padding:'12px 0', borderTop:'1px dashed rgba(255,179,206,0.45)'}}>
    <div style={{width:80, fontSize:11, color:'#7A5266'}}>{label}</div>
    <div style={{flex:1, fontSize:12.5, color:'#4B2A38', fontWeight:500, textAlign:'right'}}>{value}</div>
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#B294A4" strokeWidth="2"><path d="M9 6l6 6-6 6"/></svg>
  </div>
);

const PasswordScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Password" title="修 改 密 码"/>
    <div className="scroll">
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', padding:'14px 0 20px'}}>
        <div style={{
          width:80, height:80, borderRadius:'50%',
          background:'radial-gradient(circle at 30% 30%, #FFC0D6, #F2709C)',
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:'0 12px 28px -10px rgba(242,112,156,0.55)'
        }}>
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.6">
            <rect x="5" y="11" width="14" height="10" rx="2"/>
            <path d="M8 11V8a4 4 0 0 1 8 0v3"/>
            <circle cx="12" cy="16" r="1.5" fill="#fff"/>
          </svg>
        </div>
        <div className="font-display italic" style={{fontSize:20, color:'#A93C68', marginTop:14}}>Keep it Safe</div>
        <div style={{fontSize:11, color:'#7A5266', marginTop:6, padding:'0 30px', textAlign:'center', lineHeight:1.6}}>
          请输入原密码并设置一个新的、安全的密码。
        </div>
      </div>

      <div className="card-glow" style={{padding:'16px'}}>
        <Field label="原密码 / Current" placeholder="请输入当前密码" type="password"/>
        <div style={{height:12}}/>
        <Field label="新密码 / New" placeholder="≥ 8 位，含大小写与数字" type="password"/>
        <div style={{display:'flex', gap:6, marginTop:8, alignItems:'center'}}>
          {[1,2,3,4].map(i=>(
            <div key={i} style={{
              flex:1, height:4, borderRadius:2,
              background: i<=3 ? `linear-gradient(90deg, ${i===1?'#F2709C':i===2?'#E8C896':'#9DCB8A'}, ${i===1?'#FF9FBE':i===2?'#F2D5A0':'#B7DFA9'})` : 'rgba(255,179,206,0.3)'
            }}/>
          ))}
          <span style={{fontSize:10, color:'#3F7A4A', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>strong</span>
        </div>
        <div style={{height:12}}/>
        <Field label="确认密码 / Confirm" placeholder="再次输入新密码" type="password"/>
      </div>

      <div className="card" style={{padding:'12px 14px', marginTop:14, background:'rgba(255,237,245,0.6)'}}>
        <div style={{fontSize:11, color:'#7A5266', lineHeight:1.7}}>
          ✿ 至少 8 位字符<br/>
          ✿ 包含大写、小写字母与数字<br/>
          ✿ 建议加入符号增强安全性<br/>
          ✿ 不要与近 3 次密码相同
        </div>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:16}}>
        保 存 · CONFIRM
      </button>
    </div>
  </Phone>
);

const SettingsScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, right:-30}}/>
    <TopBar en="Settings" title="系 统 设 置"/>
    <div className="scroll">
      <div className="divider-rose"><Rose size={10}/> 通知 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        <RowToggle t="消息推送" s="选课结果 · 成绩 · 通知" on/>
        <RowToggle t="评教提醒" s="开放期间每日提醒" on/>
        <RowToggle t="勿扰模式" s="22:00 – 07:30"/>
        <RowToggle t="作业截止前" s="提前 24 小时提醒" on/>
      </div>

      <div className="divider-rose"><Rose size={10}/> 外观 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        <RowEntry ico="☾" t="主题" s="玫瑰 · Rose"/>
        <RowEntry ico="A" t="字体大小" s="标准"/>
        <RowToggle t="深色模式" s="跟随系统" on/>
      </div>

      <div className="divider-rose"><Rose size={10}/> 数据 & 安全 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px'}}>
        <RowEntry ico="🗑" t="清除缓存" s="共 12.4 MB"/>
        <RowEntry ico="↻" t="检查更新" s="当前为最新版本 v1.1.0"/>
        <RowEntry ico="🔒" t="生物识别登录" s="未开启"/>
      </div>

      <div className="divider-rose"><Rose size={10}/> 关于 <Rose size={10}/></div>
      <div className="card-glow" style={{padding:'4px 14px', marginBottom:30}}>
        <RowEntry ico="ⓘ" t="关于应用" s="教学管理学生端 · HarmonyOS"/>
        <RowEntry ico="§" t="用户协议" s=""/>
        <RowEntry ico="∮" t="隐私政策" s=""/>
        <RowEntry ico="✉" t="联系我们" s="hub@school.edu.cn"/>
      </div>

      <button className="btn-ghost" style={{width:'100%', color:'#A93C68', borderColor:'rgba(242,112,156,0.4)'}}>
        退 出 登 录
      </button>
      <div style={{textAlign:'center', padding:'18px 0', fontSize:10, color:'#B294A4', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic', letterSpacing:'0.3em'}}>
        with love · v 1.1.0
      </div>
    </div>
  </Phone>
);

const RowToggle = ({t, s, on}) => (
  <div style={{display:'flex', alignItems:'center', gap:12, padding:'12px 0', borderTop:'1px dashed rgba(255,179,206,0.45)'}}>
    <div style={{flex:1}}>
      <div style={{fontSize:12.5, fontWeight:600, color:'#4B2A38'}}>{t}</div>
      <div style={{fontSize:10, color:'#7A5266', marginTop:2}}>{s}</div>
    </div>
    <div style={{
      width:36, height:20, borderRadius:999, position:'relative',
      background: on ? 'linear-gradient(135deg,#FF9FBE,#F2709C)' : 'rgba(178,148,164,0.3)',
      boxShadow:'inset 0 1px 3px rgba(0,0,0,0.1)'
    }}>
      <div style={{position:'absolute', top:2, [on?'right':'left']:2, width:16, height:16, borderRadius:'50%', background:'#fff', boxShadow:'0 1px 3px rgba(0,0,0,0.2)'}}/>
    </div>
  </div>
);

Object.assign(window, { MineScreen, AccountScreen, EditInfoScreen, PasswordScreen, SettingsScreen });
