-- Original fixed-step cube rigid body. The resting upward face is the result.
-- Units: half-edge=1, mass=1, gravity=18; five static tray planes.
local H={DT=1/240,HALF=1,LENGTH=6,WIDTH=3.4}
H.faces={
    {value=1,n={0,0,1},u={1,0,0},v={0,1,0}},
    {value=6,n={0,0,-1},u={-1,0,0},v={0,1,0}},
    {value=3,n={1,0,0},u={0,1,0},v={0,0,1}},
    {value=4,n={-1,0,0},u={0,-1,0},v={0,0,1}},
    {value=2,n={0,1,0},u={-1,0,0},v={0,0,1}},
    {value=5,n={0,-1,0},u={1,0,0},v={0,0,1}}}
local cube={vertices={},faces=H.faces,height=1}
for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do cube.vertices[#cube.vertices+1]={x,y,z} end end end
local ico={vertices={},faces={},height=0}; local phi=(1+math.sqrt(5))/2; local radius=1.6/math.sqrt(1+phi^2)
for a=-1,1,2 do for b=-1,1,2 do
    ico.vertices[#ico.vertices+1]={a*radius,b*phi*radius,0}
    ico.vertices[#ico.vertices+1]={0,a*radius,b*phi*radius}
    ico.vertices[#ico.vertices+1]={b*phi*radius,0,a*radius}
end end
local function edge(a,b) return math.abs((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2-4*radius^2)<0.000001 end
for i=1,10 do for j=i+1,11 do for k=j+1,12 do
    local a,b,c=ico.vertices[i],ico.vertices[j],ico.vertices[k]
    if edge(a,b) and edge(a,c) and edge(b,c) then
        local u,v={},{}; for axis=1,3 do u[axis]=b[axis]-a[axis]; v[axis]=c[axis]-a[axis] end
        local n={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
        local length=math.sqrt(n[1]^2+n[2]^2+n[3]^2); for axis=1,3 do n[axis]=n[axis]/length end
        if n[1]*a[1]+n[2]*a[2]+n[3]*a[3]<0 then for axis=1,3 do n[axis]=-n[axis] end; b,c=c,b end
        ico.height=n[1]*a[1]+n[2]*a[2]+n[3]*a[3]
        ico.faces[#ico.faces+1]={n=n,vertices={a,b,c}}
    end
end end end
local value=1
for _,a in ipairs(ico.faces) do if not a.value then
    a.value=value
    for _,b in ipairs(ico.faces) do if a.n[1]*b.n[1]+a.n[2]*b.n[2]+a.n[3]*b.n[3]< -0.999 then b.value=21-value; break end end
    value=value+1
end end
H.shapes={gold=cube,red=ico}
function H.rotate(q,v)
    local tx=2*(q[3]*v[3]-q[4]*v[2]); local ty=2*(q[4]*v[1]-q[2]*v[3]); local tz=2*(q[2]*v[2]-q[3]*v[1])
    return {v[1]+q[1]*tx+q[3]*tz-q[4]*ty,v[2]+q[1]*ty+q[4]*tx-q[2]*tz,v[3]+q[1]*tz+q[2]*ty-q[3]*tx}
end
function H.face(q,kind)
    local value,alignment=0,-1
    for _,f in ipairs((H.shapes[kind] or cube).faces) do local z=H.rotate(q,f.n)[3]; if z>alignment then value,alignment=f.value,z end end
    return value,alignment
end
local function rng(seed)
    local value=math.floor(seed)%2147483647; if value<1 then value=1 end
    return function() value=value*16807%2147483647; return value/2147483647 end
end
function H.new(seed,kind)
    local r=rng(seed); local a,b,c=r(),r()*2*math.pi,r()*2*math.pi
    -- Uniform starting orientation, independent of toss velocity.
    local q={math.sqrt(a)*math.cos(c),math.sqrt(1-a)*math.sin(b),math.sqrt(1-a)*math.cos(b),math.sqrt(a)*math.sin(c)}
    return {x=-3.8+r()*0.6,y=(r()-0.5)*1.8,z=3.8+r()*0.6,
        vx=6+r()*3,vy=(r()-0.5)*4,vz=2+r()*2,
        wx=(r()-0.5)*24,wy=(r()-0.5)*24,wz=(r()-0.5)*22,q=q,t=0,quiet=0,impacts=0,kind=kind or 'gold'}
end
local planes={{0,0,1,0},{1,0,0,H.LENGTH},{-1,0,0,H.LENGTH},{0,1,0,H.WIDTH},{0,-1,0,H.WIDTH}}
local function contact(s,r,n,penetration)
    local nx,ny,nz=n[1],n[2],n[3]
    local cx=s.vx+s.wy*r[3]-s.wz*r[2]; local cy=s.vy+s.wz*r[1]-s.wx*r[3]; local cz=s.vz+s.wx*r[2]-s.wy*r[1]
    local vn=cx*nx+cy*ny+cz*nz
    if vn>=0 then return end
    local ax=r[2]*nz-r[3]*ny; local ay=r[3]*nx-r[1]*nz; local az=r[1]*ny-r[2]*nx
    local restitution=vn< -1.5 and 0.35 or 0
    local impulse=-(1+restitution)*vn/(1+1.5*(ax*ax+ay*ay+az*az))
    local jx,jy,jz=nx*impulse,ny*impulse,nz*impulse
    local tx,ty,tz=cx-vn*nx,cy-vn*ny,cz-vn*nz; local length=math.sqrt(tx*tx+ty*ty+tz*tz)
    if length>0.00001 then
        tx,ty,tz=tx/length,ty/length,tz/length
        local fx,fy,fz=r[2]*tz-r[3]*ty,r[3]*tx-r[1]*tz,r[1]*ty-r[2]*tx
        local friction=math.min(impulse*0.62,length/(1+1.5*(fx*fx+fy*fy+fz*fz)))
        jx,jy,jz=jx-tx*friction,jy-ty*friction,jz-tz*friction
    end
    s.vx=s.vx+jx; s.vy=s.vy+jy; s.vz=s.vz+jz
    s.wx=s.wx+1.5*(r[2]*jz-r[3]*jy); s.wy=s.wy+1.5*(r[3]*jx-r[1]*jz); s.wz=s.wz+1.5*(r[1]*jy-r[2]*jx)
    if vn< -1.5 then s.impacts=s.impacts+1 end
end
function H.step(s)
    local dt=H.DT; s.t=s.t+dt; s.vz=s.vz-18*dt
    s.vx=s.vx*0.9995; s.vy=s.vy*0.9995; s.wx=s.wx*0.9992; s.wy=s.wy*0.9992; s.wz=s.wz*0.9992
    s.x=s.x+s.vx*dt; s.y=s.y+s.vy*dt; s.z=s.z+s.vz*dt
    local q=s.q; local w,x,y,z=q[1],q[2],q[3],q[4]
    q[1]=w+(-s.wx*x-s.wy*y-s.wz*z)*dt/2
    q[2]=x+(s.wx*w+s.wy*z-s.wz*y)*dt/2
    q[3]=y+(-s.wx*z+s.wy*w+s.wz*x)*dt/2
    q[4]=z+(s.wx*y-s.wy*x+s.wz*w)*dt/2
    local length=math.sqrt(q[1]^2+q[2]^2+q[3]^2+q[4]^2); for i=1,4 do q[i]=q[i]/length end
    local shape=H.shapes[s.kind] or cube
    local offsets={}; for i,c in ipairs(shape.vertices) do offsets[i]=H.rotate(q,c) end
    for iteration=1,6 do
        for _,n in ipairs(planes) do
            local deepest=0
            for _,r in ipairs(offsets) do
                local distance=(s.x+r[1])*n[1]+(s.y+r[2])*n[2]+(s.z+r[3])*n[3]+n[4]
                if distance<0.002 then contact(s,r,n,-distance); deepest=math.max(deepest,-distance) end
            end
            if iteration==1 and deepest>0 then s.x=s.x+n[1]*deepest*0.85; s.y=s.y+n[2]*deepest*0.85; s.z=s.z+n[3]*deepest*0.85 end
        end
    end
    local speed=s.vx^2+s.vy^2+s.vz^2+s.wx^2+s.wy^2+s.wz^2
    local _,alignment=H.face(q,s.kind)
    if speed<0.025 and alignment>0.998 and s.z<shape.height+0.04 then s.quiet=s.quiet+dt else s.quiet=0 end
    s.settled=s.quiet>=0.25
end
function H.pose(s) return {x=s.x,y=s.y,z=s.z,q={s.q[1],s.q[2],s.q[3],s.q[4]},impacts=s.impacts} end
function H.simulate(seed,trace,kind)
    local s=H.new(seed,kind); local frames=trace and {H.pose(s)} or nil
    for i=1,2400 do
        H.step(s)
        if frames and i%4==0 then frames[#frames+1]=H.pose(s) end
        if s.settled then
            local pose=H.pose(s); if frames then frames[#frames+1]=pose end
            return {face=H.face(s.q,s.kind),duration=s.t,pose=pose,frames=frames,impacts=s.impacts,settled=true}
        end
    end
    return {face=H.face(s.q,s.kind),duration=s.t,pose=H.pose(s),frames=frames,impacts=s.impacts,settled=false}
end
function H.sample(frames,time)
    local position=math.max(0,time)*60+1; local i=math.min(#frames,math.floor(position)); local a,b=frames[i],frames[math.min(#frames,i+1)]
    local t=math.min(1,position-i); local dot=0; for k=1,4 do dot=dot+a.q[k]*b.q[k] end
    local q,length={},0
    for k=1,4 do q[k]=a.q[k]+((dot<0 and -b.q[k] or b.q[k])-a.q[k])*t; length=length+q[k]^2 end
    for k=1,4 do q[k]=q[k]/math.sqrt(length) end
    return {x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,z=a.z+(b.z-a.z)*t,q=q,impacts=a.impacts}
end
return H
