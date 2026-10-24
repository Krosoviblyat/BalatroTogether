local C=dofile(ROOT..'/core/save_catalog.lua')
local function entry(party,run,serial,at,path)
 return C.entry({schema=1,at=at,version='test',builds={},model={party_id=party,run_id=run,checkpoint_serial=serial,
  checkpoint={status='saved'},seed='SAMESEED',deck='b_red',ante=2,blind_index=1,intended=2}},path,true)
end
local p=string.rep('a',32);local q=string.rep('b',32);local groups={}
for _,e in ipairs({entry(p,1,1,100,'old'),entry(p,1,2,101,'latest'),entry(p,1,1,100,'duplicate')}) do C.add(groups,e) end
local list=C.list(groups);assert(#list==1 and list[1].path=='latest')
print('PASS saving a run repeatedly replaces its single catalog entry')
C.add(groups,entry(p,2,1,102,'restart'));C.add(groups,entry(q,1,1,103,'new-party'))
list=C.list(groups);assert(#list==3 and list[1].path=='new-party' and list[2].path=='restart' and list[3].path=='latest')
print('PASS separate parties and fast restarts retain separate slots even with the same seed')
groups={};C.add(groups,entry(p,1,9,100,'serial9'));C.add(groups,entry(p,1,10,100,'serial10'))
assert(C.list(groups)[1].path=='serial10')
assert(not C.key{party_id='../outside',run_id=1} and not C.key{party_id=p,run_id=0})
assert(not C.entry({schema=1,at=100,builds={},model={party_id=p,run_id=1}},'partial',true))
print('PASS same-second saves choose numeric checkpoint order and incomplete identities never enter the hub')
return 3
