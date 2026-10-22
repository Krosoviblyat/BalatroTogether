-- Every percentile result is beneficial. Only native-compatible rewards.
local B={tiers={
    {max=5,name='TREASURY',money=35},
    {max=10,name='ON THE HOUSE',rerolls=3},
    {max=15,name='SECOND WIND',hands=2},
    {max=20,name='FRESH START',discards=3},
    {max=25,name='CHIP CACHE',chips=100},
    {max=30,name='POWER SURGE',mult=25},
    {max=35,name='STARS ALIGN',levels=1},
    {max=40,name='MERCHANT GIFT',money=50,rerolls=2},
    {max=45,name='FULL TOOLKIT',hands=1,discards=1,chips=100},
    {max=50,name='LUCKY ORBIT',levels=1,money=25},
    {max=55,name='HOT STREAK',hands=2,mult=25},
    {max=60,name='DEEP POCKETS',chips=200,discards=3},
    {max=65,name='SHOPPING SPREE',rerolls=6},
    {max=70,name='CONSTELLATION',levels=2},
    {max=75,name='GOLDEN ORBIT',money=75,levels=1},
    {max=80,name='LIMIT BREAK',hands=2,discards=2,mult=35},
    {max=85,name='OVERDRIVE',chips=250,mult=40},
    {max=90,name='COSMIC MARKET',levels=2,rerolls=4},
    {max=95,name='ROYAL FORTUNE',money=100,levels=2,mult=50},
    {max=99,name='CROWN JEWEL',hands=3,discards=3,chips=300,mult=60,money=50},
    {max=100,name='PERFECT HUNDRED',levels=3,money=100,rerolls=6,hands=3,discards=3,chips=400,mult=100}
}}
function B.get(face)
    if type(face)~='number' or face%1~=0 or face<1 or face>100 then return end
    for _,tier in ipairs(B.tiers) do if face<=tier.max then local r={}; for k,v in pairs(tier) do r[k]=v end; return r end end
end
function B.describe(r)
    local parts={}
    if r.money then parts[#parts+1]='+$'..r.money end
    if r.levels then parts[#parts+1]='ALL HANDS +'..r.levels..' LEVELS' end
    if r.rerolls then parts[#parts+1]=r.rerolls..' FREE SHOP REFRESHES' end
    if r.hands then parts[#parts+1]='+'..r.hands..' HANDS' end
    if r.discards then parts[#parts+1]='+'..r.discards..' DISCARDS' end
    if r.chips then parts[#parts+1]='+'..r.chips..' CHIPS / HAND' end
    if r.mult then parts[#parts+1]='+'..r.mult..' MULT / HAND' end
    return table.concat(parts,' / ')
end
return B
