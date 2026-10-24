-- Host-timed Space challenge. A failure keeps the ordinary wheel reward.
local Q={DURATION=5,REQUIRED=32,MAX_RATE=20,BURST=2}
function Q.begin(m,roll)
    roll.status='challenge'
    roll.challenge={started=m.now or 0,duration=Q.DURATION,required=Q.REQUIRED,hits=0,taps=0,elapsed=0}
end
function Q.resolve(m,p,roll,won)
    if roll.status~='challenge' then return end
    local D=m.Dice;local result=D.Wheel.spin(roll.seed,won and 100 or nil)
    roll.force=won and 100 or nil;roll.face=result.face;roll.pose=result.pose
    roll.start=result.start;roll.travel=result.travel;roll.duration=result.duration
    roll.reward=D.Boss.get(result.face);roll.payout=roll.reward.money or 0;roll.status='rolling'
    roll.challenge.won=won;roll.challenge.elapsed=math.min(roll.challenge.duration,(m.now or 0)-roll.challenge.started)
    p.dice_receipt={tx=roll.tx,status='rolling',roll=roll.id}
    m:event(p.id,'dice',won and 'FUCK THE TABLE / JACKPOT SECURED' or 'TABLE HELD / NORMAL WHEEL SPIN')
    m:changed()
end
function Q.tap(m,id,data)
    local p=m.players[id];local roll=m.dice.rolls[tostring(id)]
    if not roll or roll.status~='challenge' or data.roll~=roll.id then return nil,'No active wheel challenge.' end
    local c=roll.challenge;local now=m.now or 0
    if now-c.started>=c.duration then Q.resolve(m,p,roll,false);return nil,'Challenge finished.' end
    if type(data.tap)~='number' or data.tap%1~=0 or data.tap<1 or data.tap>256 then return nil,'Invalid challenge press.' end
    if data.tap<=c.taps then return true,'duplicate' end
    c.taps=data.tap
    -- Accumulated allowance tolerates real key presses arriving in one network
    -- batch. Per-packet spacing incorrectly drops taps on a jittery connection.
    if c.hits>=math.floor(math.max(0,now-c.started)*Q.MAX_RATE)+Q.BURST then return true end
    c.last=now;c.hits=c.hits+1;c.elapsed=now-c.started
    if c.hits>=c.required then Q.resolve(m,p,roll,true) end
    return true
end
function Q.tick(m,now)
    m.now=now
    for seat,roll in pairs(m.dice.rolls) do
        if roll.status=='challenge' then
            local c=roll.challenge;local age=math.max(0,now-c.started)
            if age>=c.duration then Q.resolve(m,m.players[tonumber(seat)],roll,false)
            elseif age-(c.elapsed or 0)>=0.1 then c.elapsed=age;m:changed() end
        end
    end
end
return Q
