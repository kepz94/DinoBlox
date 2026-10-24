# ik_check_creep.py v1.1 — offline check of WalkPose v3.1 creep gait + crouch stance (knee IK reach,
# planted feet, toe clearance, knee range) using the T-Rex leg measurements and hip-shift compensation.
# v1.1: rig 1.3 leg measurements (thigh + shin +30%).
# Run: python3 tools/ik_check_creep.py
import math
K0=(0.946833,-5.141611); A0=(K0[0]-2.869107,K0[1]-3.639919); HIP=(-2.5,0.0)
l1=math.hypot(*K0); l2=math.hypot(A0[0]-K0[0],A0[1]-K0[1])
phi1_0=math.atan2(K0[1],K0[0]); phi2_0=math.atan2(A0[1]-K0[1],A0[0]-K0[0])
bend=1 if (A0[0]*K0[1]-A0[1]*K0[0])>=0 else -1; scale=l1/4.03; toe=6.61
KEYS=['StepLength','Duty','Lift','Crouch','FootForward','ToeDrop','Bounce','BodyRock']
W=dict(StepLength=6,Duty=0.6,Lift=1.6,Crouch=0.5,FootForward=1.2,ToeDrop=25,Bounce=0.35,BodyRock=4)
R=dict(StepLength=6.5,Duty=0.48,Lift=2.4,Crouch=1.0,FootForward=1.6,ToeDrop=35,Bounce=0.3,BodyRock=6)  # heavy run (Studio)
C=dict(StepLength=5.5,Duty=0.7,Lift=1.3,Crouch=2.2,FootForward=1.4,ToeDrop=15,Bounce=0.05,BodyRock=1.5)
RunLean=11; CreepLean=5
def clamp(x,a,b): return max(a,min(b,x))
def ss(t): return t*t*(3-2*t)
def q_of(g,c):
    q={k:(W[k]*(1-g)+R[k]*g)*(1-c)+C[k]*c for k in KEYS}; q['Duty']=clamp(q['Duty'],0.3,0.8)
    q['Lean']=RunLean*g*(1-c)+CreepLean*c; return q
def foot(u,q):
    b=q['Duty']; H=q['StepLength']*scale/2
    if u<b: t=u/b; return H-2*H*t,0,0,'stance'
    t=(u-b)/(1-b); return -H+2*H*ss(t), q['Lift']*scale*math.sin(math.pi*t), math.radians(-q['ToeDrop']*math.sin(math.pi*t)*(1-t)),'swing'
def solve(T):
    d=math.hypot(*T); dmin=abs(l1-l2)+0.01; dmax=(l1+l2)*0.999; r=dmin<=d<=dmax; d=clamp(d,dmin,dmax)
    cA=clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1); p1=math.atan2(T[1],T[0])+bend*math.acos(cA)
    K=(l1*math.cos(p1),l1*math.sin(p1)); n=math.hypot(*T); Tc=(T[0]/n*d,T[1]/n*d)
    p2=math.atan2(Tc[1]-K[1],Tc[0]-K[0]); return p1,p2,Tc,r,d
def rot(v,a): return (v[0]*math.cos(a)-v[1]*math.sin(a), v[0]*math.sin(a)+v[1]*math.cos(a))
def world_ankle(Tc,bodyY,rz):
    # ankle in body frame = hip + rot(counter) ... hip frame counter-rotated, so world = rot(hip,rz) + Tc + (0,bodyY)
    h=rot(HIP,rz); return (h[0]+Tc[0], bodyY+h[1]+Tc[1])
rest=world_ankle(A0,0,0)
print(f'leg l1 {l1:.2f} l2 {l2:.2f} reach {abs(l1-l2):.2f}..{l1+l2:.2f} | rest hip->ankle {math.hypot(*A0):.2f}')
for g,c in ((0,0),(0,0.5),(0,1),(1,1)):
    q=q_of(g,c); b=q['Duty']; stride=q['StepLength']*scale/b
    N=720; unreached=0; maxErr=0; drift=0; prev=None; minToe=9; knee=[]; dmax=0
    for i in range(N):
        p=2*math.pi*i/N; bodyX=stride*i/N
        c2=math.cos(2*(p-math.pi*b))
        bodyY=-q['Crouch']*scale+(W['Bounce']*(1-g)*(1-c)+C['Bounce']*c)*scale*(0.5+0.5*c2)+R['Bounce']*g*(1-c)*scale*(0.5-0.5*c2)
        rz=math.radians(q['BodyRock']*math.sin(2*p+0.6)-q['Lean'])
        u=(p/(2*math.pi))%1
        fx,fy,pitch,ph=foot(u,q)
        h=rot(HIP,rz); shift=(h[0]-HIP[0],h[1]-HIP[1])
        T=(A0[0]+q['FootForward']*scale+fx-shift[0], A0[1]+fy-bodyY-shift[1])
        p1,p2,Tc,r,d=solve(T); dmax=max(dmax,math.hypot(*T)/(l1+l2))
        if not r: unreached+=1
        wa=world_ankle(Tc,bodyY,0); wa=(wa[0]+shift[0],wa[1]+shift[1])
        ay=wa[1]-rest[1]; ax=bodyX+wa[0]
        pitch=max(pitch, math.asin(clamp((0.05-fy)/toe,-1,1)))
        minToe=min(minToe, ay+toe*math.sin(pitch))
        knee.append(math.degrees((p2-phi2_0)-(p1-phi1_0)))
        if ph=='stance':
            maxErr=max(maxErr,abs(ay))
            if prev is not None: drift=max(drift,abs(ax-prev))
            prev=ax
        else: prev=None
    print(f'g={g} c={c}: stride {stride:.2f} (cycles/s at 10 studs/s {10/stride:.2f}) | unreached {unreached} | stance height err {maxErr:.3f} | stance drift {drift:.4f} | min toe {minToe:.2f} | knee {min(knee):.0f}..{max(knee):.0f} deg | max reach {dmax*100:.0f}%')
# crouch stance (WalkPose.stance): body lowered CreepCrouch, pitched -CreepLean, feet at rest spots
bodyY=-C['Crouch']*scale; rz=math.radians(-CreepLean)
h=rot(HIP,rz); shift=(h[0]-HIP[0],h[1]-HIP[1])
T=(A0[0]-shift[0], A0[1]-bodyY-shift[1]); p1,p2,Tc,r,d=solve(T)
wa=(HIP[0]+shift[0]+Tc[0], bodyY+shift[1]+Tc[1]); wr=(HIP[0]+A0[0],A0[1])
print(f'stance: reached {r} | ankle error ({wa[0]-wr[0]:.4f}, {wa[1]-wr[1]:.4f}) | knee {math.degrees((p2-phi2_0)-(p1-phi1_0)):.0f} deg | hip {math.degrees(p1-phi1_0):.0f} deg | reach {math.hypot(*T)/(l1+l2)*100:.0f}%')
