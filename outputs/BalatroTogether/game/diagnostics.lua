-- Local reports only. Never serialize party tokens, PINs, player names, or saves.
local D={}
local function safe(value)
    local ok,text=pcall(tostring,value)
    return ok and text:sub(1,4000) or '<unprintable>'
end
function D.record(kind,message,extra)
    local ok,path=pcall(function()
        local s=BT.state;local native=G and G.GAME;local blind=native and native.blind
        local lines={'Balatro Together '..safe(BT.version),os.date('!%Y-%m-%d %H:%M:%S UTC'),
            'Report: '..kind,'Error: '..safe(message),
            'Party: '..safe(s and s.phase)..' / ante '..safe(s and s.ante)..' / round '..safe(s and s.round),
            'Native state: '..safe(G and G.STATE)..' / blind '..safe(blind and blind.config and blind.config.blind and blind.config.blind.key),
            'Team score: '..safe(s and s.score)..' / target '..safe(s and s.target)}
        for _,id in ipairs({'Cryptid','Amulet','Steamodded'}) do
            local mod=SMODS and SMODS.Mods and SMODS.Mods[id]
            if mod then lines[#lines+1]=id..': '..safe(mod.version) end
        end
        if extra then for _,key in ipairs({'chips','previous','delta','hand'}) do
            if extra[key]~=nil then lines[#lines+1]=key..': '..safe(extra[key]) end
        end end
        lines[#lines+1]=debug.traceback('',3)
        assert(love.filesystem.createDirectory('TogetherReports'))
        local name=kind=='score-error' and 'last-score-error.txt' or 'last-crash.txt'
        assert(love.filesystem.write('TogetherReports/'..name,table.concat(lines,'\n'):sub(1,32000)))
        return 'TogetherReports/'..name
    end)
    if ok then D.last_report=path;return path end
end
function D.install()
    -- Preserve the game's crash screen and the bot's existing headless handler.
    for _,key in ipairs({'errorhandler','errhand'}) do
        local previous=love[key]
        if previous then love[key]=function(message,...)
            D.record('crash',message)
            return previous(message,...)
        end end
    end
end
return D
