-- Byte-indexed UTF-8 editor. Key repeat is local to the focused field, never
-- enabled globally (Space-repeat must not count as wheel challenge taps).
local E={};E.__index=E
local function previous(s,i)
    i=math.max(0,i-1)
    while i>0 and s:byte(i+1)>=128 and s:byte(i+1)<192 do i=i-1 end
    return i
end
local function following(s,i)
    if i>=#s then return #s end
    i=i+1;while i<#s and s:byte(i+1)>=128 and s:byte(i+1)<192 do i=i+1 end
    return i
end
local function trim(s,n)
    if #s<=n then return s end
    local i=math.max(0,n)
    while i>0 and s:byte(i+1)>=128 and s:byte(i+1)<192 do i=i-1 end
    return s:sub(1,i)
end
function E.new(options)
    options=options or {};local s=options.value or ''
    return setmetatable({value=s,cursor=#s,anchor=options.select_all and 0 or #s,limit=options.limit or 100,
        filter=options.filter,clipboard=options.clipboard,changed=options.changed,blink=0},E)
end
function E:selection() return math.min(self.cursor,self.anchor),math.max(self.cursor,self.anchor) end
function E:write(value)
    value=value:gsub('[%z\1-\31\127]','')
    if self.filter then value=self.filter(value);if value==nil then return false end end
    local lo,hi=self:selection();value=trim(value,math.max(0,self.limit-(#self.value-hi+lo)))
    local result=self.value:sub(1,lo)..value..self.value:sub(hi+1)
    self.value=result;self.cursor=lo+#value;self.anchor=self.cursor;self.blink=0
    if self.changed then self.changed(result) end;return true
end
function E:move(target,shift)
    self.cursor=math.max(0,math.min(#self.value,target));if not shift then self.anchor=self.cursor end;self.blink=0
end
function E:perform(key,ctrl,shift)
    local lo,hi=self:selection();local selected=hi>lo
    if ctrl and key=='a' then self.anchor=0;self.cursor=#self.value
    elseif ctrl and (key=='c' or key=='x') then
        if selected and self.clipboard then self.clipboard('write',self.value:sub(lo+1,hi)) end
        if key=='x' and selected then self:write('') end
    elseif ctrl and key=='v' then if self.clipboard then self:write(self.clipboard('read') or '') end
    elseif key=='backspace' or key=='delete' then
        if not selected then
            if key=='backspace' then
                local at=previous(self.value,self.cursor)
                if ctrl then while at>0 and self.value:sub(at+1,self.cursor):match('^%s*%S*$') do local before=previous(self.value,at);if self.value:sub(before+1,at):match('%s') then break end;at=before end end
                self.anchor=at
            else self.anchor=following(self.value,self.cursor) end
        end
        self:write('')
    elseif key=='left' then self:move(not shift and selected and lo or previous(self.value,self.cursor),shift)
    elseif key=='right' then self:move(not shift and selected and hi or following(self.value,self.cursor),shift)
    elseif key=='home' then self:move(0,shift)
    elseif key=='end' then self:move(#self.value,shift)
    else return false end
    self.blink=0;return true
end
function E:key(key,ctrl,shift,isrepeat)
    if isrepeat then return true end
    local handled=self:perform(key,ctrl,shift)
    if handled and (key=='backspace' or key=='delete' or key=='left' or key=='right') then self.held={key=key,ctrl=ctrl,shift=shift,wait=0.36} end
    return handled
end
function E:release(key) if self.held and self.held.key==key then self.held=nil end end
function E:update(dt,is_down)
    self.blink=self.blink+dt
    local held=self.held;if not held then return end
    if not is_down(held.key) then self.held=nil;return end
    held.wait=held.wait-math.min(dt,0.15)
    for _=1,4 do if held.wait>0 then break end;self:perform(held.key,held.ctrl,held.shift);held.wait=held.wait+0.045 end
end
return E
