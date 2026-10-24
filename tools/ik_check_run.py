import math
K0=(0.73,-3.96); A0=(-1.48,-6.76)
l1=math.hypot(*K0); l2=math.hypot(A0[0]-K0[0],A0[1]-K0[1])
phi1_0=math.atan2(K0[1],K0[0]); phi2_0=math.atan2(A0[1]-K0[1],A0[0]-K0[0])
bend=1; scale=l1/4.03; toe=6.61
W=dict(StepLength=6,Duty=0.6,Lift=1.6,Crouch=0.5,FootForward=1.2,ToeDrop=25,Bounce=0.35)
R=dict(StepLength=6.5,Duty=0.4,Lift=2.4,Crouch=1.0,FootForward=1.6,ToeDrop=35,Bounce=0.6)
def clamp(x,a,b): return max(a,min(b,x))
def ss(t): return t*t*(3-2*t)
def q_of(g): 
    q={k:W[k]*(1-g)+R[k]*g for k in W}; q['Duty']=clamp(q['Duty'],0.3,0.8); return q
def foot(u,q):
    b=q['Duty']; H=q['StepLength']*scale/2
    if u<b: t=u/b; return H-2*H*t,0,0,'stance'
    t=(u-b)/(1-b); return -H+2*H*ss(t), q['Lift']*scale*math.sin(math.pi*t), math.radians(-q['ToeDrop']*math.sin(math.pi*t)*(1-t)),'swing'
def solve(T):
    d=math.hypot(*T); dmin=abs(l1-l2)+0.01; dmax=(l1+l2)*0.999; r=dmin<=d<=dmax; d=clamp(d,dmin,dmax)
    cA=clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1); p1=math.atan2(T[1],T[0])+bend*math.acos(cA)
    K=(l1*math.cos(p1),l1*math.sin(p1)); n=math.hypot(*T); Tc=(T[0]/n*d,T[1]/n*d)
    p2=math.atan2(Tc[1]-K[1],Tc[0]-K[0]); return p1,p2,Tc,r
for g in (0,0.5,1):
    q=q_of(g); b=q['Duty']; stride=q['StepLength']*scale/b
    N=600; unreached=0; maxErr=0; drift=0; prev=None; minToe=9; flight=0; knee=[]
    for i in range(N):
        p=2*math.pi*i/N; bodyX=stride*i/N
        c2=math.cos(2*(p-math.pi*b))
        bodyY=-q['Crouch']*scale+W['Bounce']*(1-g)*scale*(0.5+0.5*c2)+R['Bounce']*g*scale*(0.5-0.5*c2)
        uL=(p/(2*math.pi))%1; uR=((p+math.pi)/(2*math.pi))%1
        if uL>=b and uR>=b: flight+=1
        fx,fy,pitch,ph=foot(uL,q)
        T=(A0[0]+q['FootForward']*scale+fx, A0[1]+fy-bodyY)
        p1,p2,Tc,r=solve(T)
        if not r: unreached+=1
        ay=(bodyY+Tc[1])-A0[1]; ax=bodyX+Tc[0]
        pitch=max(pitch, math.asin(clamp((0.05-fy)/toe,-1,1)))
        minToe=min(minToe, ay+toe*math.sin(pitch))
        knee.append(math.degrees((p2-phi2_0)-(p1-phi1_0)))
        if ph=='stance':
            maxErr=max(maxErr,abs(ay))
            if prev is not None: drift=max(drift,abs(ax-prev))
            prev=ax
        else: prev=None
    print(f'g={g}: stride/cycle {stride:.1f} (cycles/s at {16+12*g:.0f} studs/s = {(16+12*g)/stride:.2f}) | unreached {unreached} | stance height err {maxErr:.3f} | stance drift {drift:.4f} | min toe {minToe:.2f} | flight {flight/N*100:.0f}% | knee {min(knee):.0f}..{max(knee):.0f} deg')
