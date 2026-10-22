-- Original deterministic reward wheel. The pointer selects the final sector.
local W={TAU=2*math.pi}
function W.face(angle)
    return math.min(100,math.floor((-angle%W.TAU)/W.TAU*100)+1)
end
function W.sample(roll,time)
    local t=math.max(0,math.min(1,time/roll.duration))
    local angle=roll.start+roll.travel*(1-(1-t)^4)
    return {angle=angle,impacts=math.floor((angle-roll.start)/W.TAU*100)}
end
function W.spin(seed,forced)
    local value=math.floor(seed)%2147483647; if value<1 then value=1 end
    local function random() value=value*16807%2147483647; return value/2147483647 end
    local r={start=random()*W.TAU,travel=(6+random()*3)*W.TAU,duration=5.6+random()*0.8,settled=true}
    if forced then
        assert(forced>=1 and forced<=100 and forced%1==0)
        local target=-(forced-0.5)/100*W.TAU
        r.travel=r.travel+(target-(r.start+r.travel))%W.TAU
    end
    r.pose=W.sample(r,r.duration); r.face=W.face(r.pose.angle)
    return r
end
return W
