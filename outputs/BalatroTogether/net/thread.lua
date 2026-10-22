-- The only socket owner. Nonblocking IO with bounded queues and partial writes.
local root, channel_name, mode, address, port = ...
local socket=require('socket')
local inbound=love.thread.getChannel(channel_name..':in')
local outbound=love.thread.getChannel(channel_name..':out')
local links, listener, next_id = {},nil,1
local function emit(t) outbound:push(t) end
local function close(id,why)
    if links[id] then pcall(links[id].socket.close,links[id].socket); links[id]=nil; emit{type='closed',id=id,error=why} end
end
local function add(s,id)
    s:settimeout(0); pcall(s.setoption,s,'tcp-nodelay',true)
    links[id]={socket=s,tx='',rx='',last=socket.gettime(),window=socket.gettime(),messages=0}
    emit{type='connected',id=id}
end
if mode=='host' then
    local err; listener,err=socket.bind(address,port,8)
    if not listener then emit{type='error',error='Cannot host: '..tostring(err)}; return end
    listener:settimeout(0); local _,bound_port=listener:getsockname(); emit{type='listening',port=bound_port}
else
    -- Timeout happens only in this worker; never freezes the game's main thread.
    local s=socket.tcp(); s:settimeout(5)
    local ok,err=s:connect(address,port)
    if not ok then emit{type='error',error='Cannot connect: '..tostring(err)}; s:close(); return end
    add(s,1)
end
while true do
    local cmd=inbound:pop()
    while cmd do
        if cmd.type=='stop' then
            for _,l in pairs(links) do l.socket:close() end
            if listener then listener:close() end; return
        elseif cmd.type=='close' then close(cmd.id,'closed by host')
        elseif cmd.type=='send' then
            for id,l in pairs(links) do if cmd.id==0 or cmd.id==id then
                if #l.tx+#cmd.line>524288 then close(id,'send queue overflow') else l.tx=l.tx..cmd.line..'\n' end
            end end
        end
        cmd=inbound:pop()
    end
    if listener then
        local s=listener:accept()
        if s then
            local n=0; for _ in pairs(links) do n=n+1 end
            if n>=8 then s:close() else next_id=next_id+1; add(s,next_id) end
        end
    end
    for id,l in pairs(links) do
        local data,err,partial=l.socket:receive(4096)
        local bytes=data or partial
        if bytes and #bytes>0 then l.rx=l.rx..bytes; l.last=socket.gettime() end
        if #l.rx>131072 then close(id,'receive queue overflow')
        else
            local i=l.rx:find('\n',1,true)
            while i do
                if socket.gettime()-l.window>=1 then l.window=socket.gettime(); l.messages=0 end
                l.messages=l.messages+1
                if i>65536 or l.messages>100 then close(id,'frame/rate limit'); break end
                emit{type='line',id=id,line=l.rx:sub(1,i-1)}; l.rx=l.rx:sub(i+1); i=l.rx:find('\n',1,true)
            end
            if err=='closed' then close(id,'connection closed')
            elseif socket.gettime()-l.last>20 then close(id,'heartbeat timed out') end
        end
        if links[id] and #l.tx>0 then
            local sent,senderr,last=l.socket:send(l.tx)
            local count=sent or last or 0; l.tx=l.tx:sub(count+1)
            if senderr and senderr~='timeout' then close(id,senderr) end
        end
    end
    socket.sleep(0.005)
end
