# leg_stretch.py v1.0 — rig v1.3: lengthen the T-Rex thigh + shin by FACTOR (feet unchanged), applied to
# src/shared/Models/TRexModelData.luau. Same math as the Studio install (install_legs_v1_3.luau):
#   bone u (unit, HRP space); part centre p -> p + (F-1) * ((p - joint) . u) * u (+ upstream joint shift)
#   part size per local axis e -> size * |e + (F-1) (e . u) u|; rotation unchanged
#   Knee / Ankle C0 positions * F; foot segments shift by (F-1) * (ankle - hip); HipHeight += that drop.
# Run: python3 tools/leg_stretch.py [factor]   (only on the v1.2 rig data: legs at original length)
import re, sys, math
F = float(sys.argv[1]) if len(sys.argv) > 1 else 1.3
path = 'src/shared/Models/TRexModelData.luau'
src = open(path).read()
def nums(s): return [float(x) for x in s.split(',')]
def fmt(v):
    s = ('%.6f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s
def sub(a, b): return [a[i]-b[i] for i in range(3)]
def add(a, b): return [a[i]+b[i] for i in range(3)]
def mul(a, k): return [x*k for x in a]
def dot(a, b): return sum(a[i]*b[i] for i in range(3))
def norm(a): return math.sqrt(dot(a, a))
seg = {}
for m in re.finditer(r'\{name = "(\w+)", root = \{([^}]*)\}', src):
    seg[m.group(1)] = nums(m.group(2))
out = src
report = []
for S in ('L', 'R'):
    H = seg['Leg'+S][:3]; K = seg['Shin'+S][:3]; A = seg['Foot'+S][:3]
    u = mul(sub(K, H), 1/norm(sub(K, H))); v = mul(sub(A, K), 1/norm(sub(A, K)))
    K2 = add(H, mul(sub(K, H), F)); A2 = add(K2, mul(sub(A, K), F))
    dK = sub(K2, K); dA = sub(A2, A)
    def seg_block(name):
        m = re.search(r'\{name = "%s", root = \{[^}]*\}, parts = \{.*?\n\t\t\}\},' % name, out, re.S)
        return m
    # thigh parts stretch about the hip, shin parts about the knee (+ knee shift), feet only shift
    for name, joint, axis, shift, rootnew in (('Leg'+S, H, u, [0,0,0], None), ('Shin'+S, K, v, dK, K2), ('Foot'+S, A, None, dA, A2)):
        m = seg_block(name); block = m.group(0)
        if rootnew is not None:
            r = seg[name]; block = block.replace('root = {%s}' % re.search(r'root = \{([^}]*)\}', block).group(1),
                'root = {%s}' % ','.join([fmt(x) for x in rootnew] + [fmt(x) for x in r[3:]]), 1)
        def part(pm, joint=joint, axis=axis, shift=shift):
            size = nums(pm.group(2)); cf = nums(pm.group(3)); p = cf[:3]; R = cf[3:]
            if axis is None:
                p2 = add(p, shift); size2 = size
            else:
                a = dot(sub(p, joint), axis)
                p2 = add(add(p, shift), mul(axis, (F-1)*a))
                cols = [[R[0], R[3], R[6]], [R[1], R[4], R[7]], [R[2], R[5], R[8]]]
                size2 = [size[i]*norm(add(cols[i], mul(axis, (F-1)*dot(cols[i], axis)))) for i in range(3)]
            report.append((pm.group(1), size2, p2))
            return '{name = "%s", size = {%s}, cf = {%s}' % (pm.group(1), ','.join(fmt(x) for x in size2),
                ','.join([fmt(x) for x in p2] + [fmt(x) for x in R]))
        block2 = re.sub(r'\{name = "(\w+)", size = \{([^}]*)\}, cf = \{([^}]*)\}', part, block)
        out = out.replace(m.group(0), block2, 1)
    drop = -dA[1]
# joints: Knee / Ankle C0 positions * F
out = re.sub(r'\{name = "((?:Knee|Ankle)[LR])", part0 = ("\w+", part1 = "\w+"), c0 = \{([^}]*)\}',
             lambda m: '{name = "%s", part0 = %s, c0 = {%s}' % (m.group(1), m.group(2), ','.join(fmt(x) for x in (lambda c: [c[0]*F, c[1]*F, c[2]*F] + c[3:])(nums(m.group(3))))), out)
hh = float(re.search(r'HipHeight = ([\d.]+)', out).group(1))
out = out.replace('HipHeight = %s,' % fmt(hh), 'HipHeight = %s,' % fmt(hh + drop), 1)
rh = float(re.search(r'RigHipHeight = ([\d.]+)', out).group(1))
out = out.replace('RigHipHeight = %s,' % fmt(rh), 'RigHipHeight = %s,' % fmt(rh + drop), 1)
open(path, 'w').write(out)
print('drop %.6f HipHeight %s RigHipHeight %s' % (drop, fmt(hh + drop), fmt(rh + drop)))
for r in report: print(r[0], [round(x, 4) for x in r[1]], [round(x, 4) for x in r[2]])
