local M={}
function M.reveal(age,delay,reduced)
    if reduced then return 1 end
    local t=math.max(0,age-(delay or 0))
    return 1-math.exp(-14*t)*(math.cos(15*t)+0.5*math.sin(15*t))
end
function M.spring(state,target,dt,reduced,speed)
    if reduced then state.x=target; state.v=0; return target end
    local remaining=math.min(math.max(dt,0),0.1)*(speed or 1)
    local omega=20; local damping=0.62
    state.x=state.x or 0; state.v=state.v or 0
    while remaining>0 do
        local step=math.min(remaining,1/120); remaining=remaining-step
        state.v=state.v+((target-state.x)*omega*omega-2*damping*omega*state.v)*step
        state.x=state.x+state.v*step
    end
    if math.abs(state.x-target)<0.0001 and math.abs(state.v)<0.001 then state.x=target; state.v=0 end
    return state.x
end
function M.arc(t,from,to)
    local u=math.max(0,math.min(1,t)); local smooth=1-(1-u)^3
    return from.x+(to.x-from.x)*smooth,from.y+(to.y-from.y)*smooth-math.sin(u*math.pi)*100
end
return M
