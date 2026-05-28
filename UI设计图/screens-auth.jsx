/* Onboarding screens — Login, Register, Forgot password */
const { Phone, TopBar, Rose, Sparkle, Heart, FloralCorner, Monogram, Placeholder, TabBar } = window;

const LoginScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, left:-30}}/>
    <FloralCorner flip style={{bottom:60, right:-40}}/>
    <div className="phone-body" style={{padding:'24px 26px 0', position:'relative'}}>
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', marginTop:30}}>
        <Monogram size={72}/>
        <div className="font-display italic" style={{fontSize:32, color:'#A93C68', marginTop:18, letterSpacing:'0.02em'}}>
          Bonjour,
        </div>
        <div className="font-display italic" style={{fontSize:32, color:'#A93C68', marginTop:-4}}>
          Élysée.
        </div>
        <div style={{fontSize:11, letterSpacing:'0.4em', color:'#7A5266', marginTop:10}}>
          欢迎回到 · 教学管理学生端
        </div>
      </div>

      <div className="divider-rose" style={{marginTop:34}}>
        <Rose size={12}/> sign in <Rose size={12}/>
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:12}}>
        <div style={{position:'relative'}}>
          <div style={{position:'absolute', top:13, left:14, fontSize:14}}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#D85487" strokeWidth="1.6"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>
          </div>
          <input className="input" placeholder="学号 / Student ID" style={{paddingLeft:38}} defaultValue="20231104"/>
        </div>
        <div style={{position:'relative'}}>
          <div style={{position:'absolute', top:13, left:14, fontSize:14}}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#D85487" strokeWidth="1.6"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
          </div>
          <input className="input" type="password" placeholder="密码 / Password" style={{paddingLeft:38}} defaultValue="••••••••"/>
        </div>
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', fontSize:11, color:'#7A5266', padding:'2px 4px'}}>
          <label style={{display:'flex', alignItems:'center', gap:6}}>
            <span style={{width:14, height:14, borderRadius:4, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', display:'inline-flex', alignItems:'center', justifyContent:'center'}}>
              <svg width="9" height="9" viewBox="0 0 24 24" stroke="#fff" strokeWidth="3" fill="none"><path d="M4 12l5 5L20 6"/></svg>
            </span>
            记住我
          </label>
          <span style={{color:'#A93C68', fontStyle:'italic', fontFamily:'Cormorant Garamond, serif'}}>forgot password ?</span>
        </div>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:22, display:'flex', justifyContent:'center', alignItems:'center', gap:8}}>
        <span>登 录 · ENTER</span>
        <Sparkle size={12} color="#FFFFFF"/>
      </button>
      <button className="btn-ghost" style={{width:'100%', marginTop:10}}>
        注册新账号 · Register
      </button>

      <div style={{textAlign:'center', marginTop:28, fontSize:10, color:'#B294A4', letterSpacing:'0.2em'}}>
        — Pardon me, may I have the pleasure of your name? —
      </div>
    </div>
  </Phone>
);

const RegisterScreen = () => (
  <Phone>
    <FloralCorner style={{top:-40, right:-30}}/>
    <TopBar en="Register" title="注 册"/>
    <div className="scroll">
      <div className="font-display italic" style={{fontSize:24, color:'#A93C68', marginTop:6}}>
        Create your story
      </div>
      <div style={{fontSize:11, color:'#7A5266', letterSpacing:'0.2em', marginBottom:18}}>
        填写以下信息以开始你的旅程
      </div>

      <div style={{display:'flex', flexDirection:'column', gap:10}}>
        <Field label="学号 / ID" placeholder="请输入学号" required/>
        <Field label="姓名 / Name" placeholder="请输入真实姓名" required/>
        <Field label="手机号 / Phone" placeholder="+86 13800138000" required/>
        <div style={{display:'grid', gridTemplateColumns:'1fr 100px', gap:8, alignItems:'end'}}>
          <Field label="验证码 / Code" placeholder="6 位短信验证码"/>
          <button className="btn-ghost" style={{padding:'10px 8px', fontSize:11}}>获取验证码</button>
        </div>
        <Field label="初始密码 / Password" placeholder="≥8 位，含大小写字母与数字" required type="password"/>
        <Field label="确认密码 / Confirm" placeholder="再次输入" required type="password"/>
      </div>

      <div className="card" style={{padding:'12px 14px', marginTop:14, display:'flex', gap:10, alignItems:'flex-start'}}>
        <span style={{width:16, height:16, borderRadius:4, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', display:'inline-flex', alignItems:'center', justifyContent:'center', marginTop:2, flexShrink:0}}>
          <svg width="10" height="10" viewBox="0 0 24 24" stroke="#fff" strokeWidth="3" fill="none"><path d="M4 12l5 5L20 6"/></svg>
        </span>
        <div style={{fontSize:11, color:'#7A5266', lineHeight:1.5}}>
          我已阅读并同意《用户协议》与《隐私政策》。新账号注册成功后将进入待审核状态，请耐心等待教务老师确认。
        </div>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:16}}>
        提交注册 · CREATE
      </button>
      <div style={{textAlign:'center', marginTop:14, fontSize:11, color:'#7A5266'}}>
        已有账号？ <span style={{color:'#A93C68', fontFamily:'Cormorant Garamond, serif', fontStyle:'italic'}}>Sign in</span>
      </div>
    </div>
  </Phone>
);

const Field = ({label, placeholder, required, type='text', defaultValue}) => (
  <label style={{display:'block'}}>
    <div style={{display:'flex', alignItems:'baseline', gap:6, marginBottom:4, padding:'0 2px'}}>
      <span style={{fontSize:10, letterSpacing:'0.25em', color:'#A93C68'}}>{label}</span>
      {required && <span style={{color:'#F2709C', fontSize:10}}>✦</span>}
    </div>
    <input className="input" placeholder={placeholder} type={type} defaultValue={defaultValue}/>
  </label>
);

const ForgotScreen = () => (
  <Phone>
    <FloralCorner style={{top:-30, left:-30}}/>
    <TopBar en="Recover" title="找 回 密 码"/>
    <div className="scroll">
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', marginTop:20}}>
        <div style={{
          width:90, height:90, borderRadius:'50%',
          background:'radial-gradient(circle at 30% 30%, #FFD3E3, #F2709C)',
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:'0 12px 30px -10px rgba(242,112,156,0.6)'
        }}>
          <svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.6">
            <rect x="5" y="11" width="14" height="10" rx="2"/>
            <path d="M8 11V8a4 4 0 0 1 8 0M12 15v3"/>
          </svg>
        </div>
        <div className="font-display italic" style={{fontSize:24, color:'#A93C68', marginTop:14}}>
          Reclaim the rose
        </div>
        <div style={{fontSize:11, color:'#7A5266', letterSpacing:'0.2em', textAlign:'center', marginTop:6, lineHeight:1.6, padding:'0 24px'}}>
          忘记密码并不可怕 —— 玫瑰，依旧绽放为你
        </div>
      </div>

      <div className="card-glow" style={{padding:'16px 16px', marginTop:24}}>
        <div style={{display:'flex', gap:8, marginBottom:12}}>
          <button style={{flex:1, padding:'8px 10px', border:'none', borderRadius:12, background:'linear-gradient(135deg,#FF9FBE,#F2709C)', color:'#fff', fontWeight:700, fontSize:12}}>
            手机验证
          </button>
          <button style={{flex:1, padding:'8px 10px', border:'1px solid rgba(255,179,206,0.6)', borderRadius:12, background:'transparent', color:'#A93C68', fontSize:12}}>
            校园邮箱
          </button>
        </div>
        <Field label="学号 / ID" placeholder="请输入学号"/>
        <div style={{height:10}}/>
        <Field label="手机号 / Phone" placeholder="绑定的手机号"/>
        <div style={{height:10}}/>
        <div style={{display:'grid', gridTemplateColumns:'1fr 90px', gap:8, alignItems:'end'}}>
          <Field label="验证码 / Code" placeholder="6 位"/>
          <button className="btn-ghost" style={{padding:'10px 8px', fontSize:11}}>59 s</button>
        </div>
        <div style={{height:10}}/>
        <Field label="新密码 / New" placeholder="≥8 位" type="password"/>
      </div>

      <button className="btn-primary" style={{width:'100%', marginTop:18}}>
        重 置 密 码 · RESET
      </button>
    </div>
  </Phone>
);

Object.assign(window, { LoginScreen, RegisterScreen, ForgotScreen, Field });
