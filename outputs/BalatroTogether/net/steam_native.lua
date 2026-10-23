-- Windows x64 bridge to the Steam library already initialized by Balatro.
-- No replacement DLL, App ID, SteamAPI_Init, manual dispatch or shutdown.
local N={}
local ok,ffi=pcall(require,'ffi')
if not ok or ffi.os~='Windows' or ffi.arch~='x64' then return N end
ffi.cdef[[
typedef unsigned long long BTSteamID;
typedef struct { int type; int size; unsigned char data[128]; } BTSteamIdentity;
typedef struct { void *data; int size; unsigned int connection; BTSteamIdentity peer; } BTSteamMessage;
typedef struct { int result; BTSteamID lobby; } BTSteamLobbyCreated;
typedef struct { BTSteamID lobby; unsigned int permissions; bool locked; unsigned int response; } BTSteamLobbyEntered;
typedef struct { BTSteamID lobby; BTSteamID friend_id; } BTSteamJoinRequested;
typedef struct { BTSteamID friend_id; char connect[256]; } BTSteamPresenceRequested;
typedef struct { char unused; } BTSteamNewUrl;
typedef struct { unsigned int count; } BTSteamLobbyList;
typedef struct { void **vtable; unsigned char flags; int callback; } BTSteamCallback;
void *SteamAPI_SteamUser_v022(void);
void *SteamAPI_SteamFriends_v017(void);
void *SteamAPI_SteamUtils_v010(void);
void *SteamAPI_SteamApps_v008(void);
int SteamAPI_ISteamApps_GetLaunchCommandLine(void *, char *, int);
bool SteamAPI_ISteamFriends_InviteUserToGame(void *, BTSteamID, const char *);
const unsigned short *GetCommandLineW(void);
void *SteamAPI_SteamMatchmaking_v009(void);
void *SteamAPI_SteamNetworkingMessages_SteamAPI_v002(void);
void *SteamAPI_SteamNetworkingUtils_SteamAPI_v004(void);
BTSteamID SteamAPI_ISteamUser_GetSteamID(void *);
bool SteamAPI_ISteamUser_BLoggedOn(void *);
unsigned int SteamAPI_ISteamUtils_GetAppID(void *);
bool SteamAPI_ISteamUtils_IsAPICallCompleted(void *, BTSteamID, bool *);
bool SteamAPI_ISteamUtils_GetAPICallResult(void *, BTSteamID, void *, int, int, bool *);
BTSteamID SteamAPI_ISteamMatchmaking_CreateLobby(void *, int, int);
BTSteamID SteamAPI_ISteamMatchmaking_JoinLobby(void *, BTSteamID);
void SteamAPI_ISteamMatchmaking_LeaveLobby(void *, BTSteamID);
bool SteamAPI_ISteamMatchmaking_SetLobbyData(void *, BTSteamID, const char *, const char *);
const char *SteamAPI_ISteamMatchmaking_GetLobbyData(void *, BTSteamID, const char *);
int SteamAPI_ISteamMatchmaking_GetNumLobbyMembers(void *, BTSteamID);
BTSteamID SteamAPI_ISteamMatchmaking_GetLobbyMemberByIndex(void *, BTSteamID, int);
BTSteamID SteamAPI_ISteamMatchmaking_GetLobbyOwner(void *, BTSteamID);
bool SteamAPI_ISteamMatchmaking_SetLobbyJoinable(void *, BTSteamID, bool);
bool SteamAPI_ISteamMatchmaking_InviteUserToLobby(void *, BTSteamID, BTSteamID);
BTSteamID SteamAPI_ISteamMatchmaking_RequestLobbyList(void *);
void SteamAPI_ISteamMatchmaking_AddRequestLobbyListStringFilter(void *,const char *,const char *,int);
void SteamAPI_ISteamMatchmaking_AddRequestLobbyListDistanceFilter(void *,int);
void SteamAPI_ISteamMatchmaking_AddRequestLobbyListResultCountFilter(void *,int);
BTSteamID SteamAPI_ISteamMatchmaking_GetLobbyByIndex(void *,int);
int SteamAPI_ISteamFriends_GetFriendCount(void *, int);
BTSteamID SteamAPI_ISteamFriends_GetFriendByIndex(void *, int, int);
const char *SteamAPI_ISteamFriends_GetFriendPersonaName(void *, BTSteamID);
int SteamAPI_ISteamFriends_GetFriendPersonaState(void *, BTSteamID);
int SteamAPI_ISteamFriends_GetFriendRelationship(void *, BTSteamID);
bool SteamAPI_ISteamFriends_SetRichPresence(void *, const char *, const char *);
void SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess(void *);
void SteamAPI_SteamNetworkingIdentity_SetSteamID64(BTSteamIdentity *, BTSteamID);
BTSteamID SteamAPI_SteamNetworkingIdentity_GetSteamID64(const BTSteamIdentity *);
int SteamAPI_ISteamNetworkingMessages_SendMessageToUser(void *, const BTSteamIdentity *, const void *, unsigned int, int, int);
int SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel(void *, int, BTSteamMessage **, int);
bool SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser(void *, const BTSteamIdentity *);
bool SteamAPI_ISteamNetworkingMessages_CloseChannelWithUser(void *, const BTSteamIdentity *, int);
void SteamAPI_SteamNetworkingMessage_t_Release(BTSteamMessage *);
void SteamAPI_RegisterCallback(BTSteamCallback *, int);
void SteamAPI_UnregisterCallback(BTSteamCallback *);
void SteamAPI_RunCallbacks(void);
]]
local api,interfaces,callbacks
local function decimal(id) return (tostring(id):gsub('ULL$',''):gsub('LL$','')) end
local function id(value)
    -- Never pass Steam IDs through a Lua double (they exceed 2^53).
    if type(value)~='string' or not value:match('^%d+$') or #value<16 or #value>20 then return nil end
    local result=ffi.new('BTSteamID',0)
    for digit in value:gmatch('.') do result=result*10+tonumber(digit) end
    if decimal(result)~=value then return nil end
    return result
end
N.valid_id=function(value) return id(value)~=nil end
local function identity(value)
    local v=assert(id(value),'Invalid Steam ID'); local remote=ffi.new('BTSteamIdentity')
    api.SteamAPI_SteamNetworkingIdentity_SetSteamID64(remote,v); return remote
end
local function register(callback,ctype,queue,convert)
    local object=ffi.new('BTSteamCallback'); local vt=ffi.new('void *[3]')
    local run=ffi.cast('void (*)(void *, void *)',function(_,data)
        if #queue<8 then local value=convert(ffi.cast(ctype..' *',data)); if value then queue[#queue+1]=value end end
    end)
    local result=ffi.cast('void (*)(void *, void *, bool, BTSteamID)',function() end)
    local size=ffi.cast('int (*)(void *)',function() return ffi.sizeof(ctype) end)
    vt[0]=ffi.cast('void *',run); vt[1]=ffi.cast('void *',result); vt[2]=ffi.cast('void *',size)
    object.vtable=vt; object.callback=callback
    -- Root all three callbacks for the process lifetime. Never allocate per frame.
    local refs={object=object,vt=vt,run=run,result=result,size=size}
    api.SteamAPI_RegisterCallback(object,callback); return refs
end
local function register_invites()
    local queue={}; callbacks={queue=queue}
    callbacks.lobby=register(333,'BTSteamJoinRequested',queue,function(v) return decimal(v.lobby) end)
    callbacks.presence=register(337,'BTSteamPresenceRequested',queue,function(v) return ffi.string(v.connect,256):match('^[^%z]*') end)
    -- Empty C++ payloads occupy one byte. Read only when the callback fires.
    callbacks.url=register(1014,'BTSteamNewUrl',queue,function() return N.launch_command() end)
end
function N.init()
    if interfaces then return interfaces end
    local now=love and love.timer and love.timer.getTime() or os.clock()
    if N.retry_at and now<N.retry_at then return nil,N.failure end
    if not (G and G.STEAM) then return nil,'Open Balatro through Steam while signed in.' end
    local success,err=pcall(function()
        api=ffi.load('steam_api64')
        local v={user=api.SteamAPI_SteamUser_v022(),friends=api.SteamAPI_SteamFriends_v017(),utils=api.SteamAPI_SteamUtils_v010(),
            matchmaking=api.SteamAPI_SteamMatchmaking_v009(),messages=api.SteamAPI_SteamNetworkingMessages_SteamAPI_v002(),
            networking=api.SteamAPI_SteamNetworkingUtils_SteamAPI_v004()}
        for _,pointer in pairs(v) do assert(pointer~=nil,'Steam interface unavailable') end
        assert(api.SteamAPI_ISteamUtils_GetAppID(v.utils)==2379780,'This session is not Balatro on Steam')
        assert(api.SteamAPI_ISteamUser_BLoggedOn(v.user),'Steam is offline; sign in first')
        -- Probe every symbol used below before any room is replaced.
        local required={'SteamAPI_ISteamUtils_IsAPICallCompleted','SteamAPI_ISteamUtils_GetAPICallResult',
            'SteamAPI_ISteamMatchmaking_CreateLobby','SteamAPI_ISteamMatchmaking_JoinLobby','SteamAPI_ISteamMatchmaking_LeaveLobby',
            'SteamAPI_ISteamMatchmaking_SetLobbyData','SteamAPI_ISteamMatchmaking_GetLobbyData','SteamAPI_ISteamMatchmaking_GetLobbyOwner',
            'SteamAPI_ISteamMatchmaking_GetNumLobbyMembers','SteamAPI_ISteamMatchmaking_GetLobbyMemberByIndex',
            'SteamAPI_ISteamMatchmaking_SetLobbyJoinable','SteamAPI_ISteamMatchmaking_RequestLobbyList',
            'SteamAPI_ISteamMatchmaking_AddRequestLobbyListStringFilter','SteamAPI_ISteamMatchmaking_AddRequestLobbyListDistanceFilter',
            'SteamAPI_ISteamMatchmaking_AddRequestLobbyListResultCountFilter','SteamAPI_ISteamMatchmaking_GetLobbyByIndex',
            'SteamAPI_ISteamMatchmaking_InviteUserToLobby','SteamAPI_ISteamFriends_GetFriendCount',
            'SteamAPI_ISteamFriends_GetFriendByIndex','SteamAPI_ISteamFriends_GetFriendPersonaName',
            'SteamAPI_ISteamFriends_GetFriendPersonaState','SteamAPI_ISteamFriends_GetFriendRelationship',
            'SteamAPI_ISteamFriends_SetRichPresence','SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess',
            'SteamAPI_SteamNetworkingIdentity_SetSteamID64','SteamAPI_SteamNetworkingIdentity_GetSteamID64',
            'SteamAPI_ISteamNetworkingMessages_SendMessageToUser','SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel',
            'SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser','SteamAPI_ISteamNetworkingMessages_CloseChannelWithUser',
            'SteamAPI_SteamNetworkingMessage_t_Release','SteamAPI_RegisterCallback','SteamAPI_UnregisterCallback'}
        for _,symbol in ipairs(required) do assert(api[symbol]) end
        -- Older Steam DLLs can still use OS arguments and ordinary lobby invites.
        pcall(function() assert(api.SteamAPI_ISteamApps_GetLaunchCommandLine); v.apps=api.SteamAPI_SteamApps_v008() end)
        pcall(function() N.game_invite=api.SteamAPI_ISteamFriends_InviteUserToGame end)
        v.id=decimal(api.SteamAPI_ISteamUser_GetSteamID(v.user)); assert(id(v.id),'Invalid local Steam ID')
        api.SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess(v.networking)
        register_invites(); interfaces=v
    end)
    if not success then N.retry_at=now+2; N.failure='Steam networking unavailable: '..tostring(err); return nil,N.failure end
    N.failure=nil; N.retry_at=nil
    return interfaces
end
function N.launch_command()
    if not (interfaces and interfaces.apps~=nil) then return end
    local buffer=ffi.new('char[32768]')
    local size=api.SteamAPI_ISteamApps_GetLaunchCommandLine(interfaces.apps,buffer,32768)
    if size>0 and size<32768 then return ffi.string(buffer) end
end
function N.launch_args()
    local out={}
    if not N.checked_os then
        N.checked_os=true
        local success,line=pcall(function()
            local wide=ffi.C.GetCommandLineW(); local chars={}
            for i=0,32767 do
                local c=tonumber(wide[i]); if c==0 then return table.concat(chars) end
                chars[#chars+1]=c<128 and string.char(c) or '?'
            end
        end)
        if success and line then out[#out+1]=line end
    end
    local line=N.launch_command()
    if line and line~=N.last_launch then N.last_launch=line; out[#out+1]=line end
    return out
end
function N.create() return api.SteamAPI_ISteamMatchmaking_CreateLobby(interfaces.matchmaking,2,4) end
function N.search(code)
    assert(type(code)=='string' and code:match('^%d%d%d%d%d%d$'),'Invalid room code')
    local m=interfaces.matchmaking
    api.SteamAPI_ISteamMatchmaking_AddRequestLobbyListStringFilter(m,'bt_mod','BalatroTogether',0)
    api.SteamAPI_ISteamMatchmaking_AddRequestLobbyListStringFilter(m,'bt_code',code,0)
    api.SteamAPI_ISteamMatchmaking_AddRequestLobbyListDistanceFilter(m,3)
    api.SteamAPI_ISteamMatchmaking_AddRequestLobbyListResultCountFilter(m,8)
    return api.SteamAPI_ISteamMatchmaking_RequestLobbyList(m)
end
function N.poll_search(call)
    local failed=ffi.new('bool[1]')
    if not api.SteamAPI_ISteamUtils_IsAPICallCompleted(interfaces.utils,call,failed) then return end
    if failed[0] then return false,'Steam code lookup failed. Check that Steam is online.' end
    local list=ffi.new('BTSteamLobbyList')
    if not api.SteamAPI_ISteamUtils_GetAPICallResult(interfaces.utils,call,list,ffi.sizeof(list),510,failed) or failed[0] then return false,'Steam code lookup is unavailable.' end
    local out={}
    for i=0,math.min(8,tonumber(list.count))-1 do out[#out+1]=decimal(api.SteamAPI_ISteamMatchmaking_GetLobbyByIndex(interfaces.matchmaking,i)) end
    return out
end
function N.join(lobby) return api.SteamAPI_ISteamMatchmaking_JoinLobby(interfaces.matchmaking,assert(id(lobby))) end
function N.poll(call,creating)
    local failed=ffi.new('bool[1]')
    if not api.SteamAPI_ISteamUtils_IsAPICallCompleted(interfaces.utils,call,failed) then return end
    if failed[0] then return false,'Steam lobby request failed.' end
    local result=ffi.new(creating and 'BTSteamLobbyCreated' or 'BTSteamLobbyEntered')
    if not api.SteamAPI_ISteamUtils_GetAPICallResult(interfaces.utils,call,result,ffi.sizeof(result),creating and 513 or 504,failed) or failed[0] then return false,'Steam lobby response unavailable.' end
    local response=tonumber(creating and result.result or result.response)
    if response~=1 then return false,'Steam refused the lobby request (code '..response..').' end
    return decimal(result.lobby)
end
function N.leave(lobby) api.SteamAPI_ISteamMatchmaking_LeaveLobby(interfaces.matchmaking,assert(id(lobby))) end
function N.joinable(lobby,value) return api.SteamAPI_ISteamMatchmaking_SetLobbyJoinable(interfaces.matchmaking,assert(id(lobby)),value==true) end
function N.set(lobby,key,value) return api.SteamAPI_ISteamMatchmaking_SetLobbyData(interfaces.matchmaking,assert(id(lobby)),key,value) end
function N.get(lobby,key) return ffi.string(api.SteamAPI_ISteamMatchmaking_GetLobbyData(interfaces.matchmaking,assert(id(lobby)),key)) end
function N.owner(lobby) return decimal(api.SteamAPI_ISteamMatchmaking_GetLobbyOwner(interfaces.matchmaking,assert(id(lobby)))) end
function N.members(lobby)
    local members={}; local lobbyid=assert(id(lobby)); local n=api.SteamAPI_ISteamMatchmaking_GetNumLobbyMembers(interfaces.matchmaking,lobbyid)
    for i=0,math.min(4,n)-1 do members[#members+1]=decimal(api.SteamAPI_ISteamMatchmaking_GetLobbyMemberByIndex(interfaces.matchmaking,lobbyid,i)) end
    return members
end
function N.accept(remote) return api.SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser(interfaces.messages,identity(remote)) end
function N.send(remote,line)
    -- Reliable, ordered, automatic restart after transient session failure.
    return tonumber(api.SteamAPI_ISteamNetworkingMessages_SendMessageToUser(interfaces.messages,identity(remote),line,#line,8+32,27))
end
function N.receive()
    local list=ffi.new('BTSteamMessage *[32]'); local messages={}
    local count=api.SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel(interfaces.messages,27,list,32)
    for i=0,count-1 do
        local m=list[i]
        if m~=nil then
            if m.size>0 and m.size<=65600 then messages[#messages+1]={remote=decimal(api.SteamAPI_SteamNetworkingIdentity_GetSteamID64(m.peer)),line=ffi.string(m.data,m.size)} end
            api.SteamAPI_SteamNetworkingMessage_t_Release(m)
        end
    end
    return messages
end
function N.close(remote) api.SteamAPI_ISteamNetworkingMessages_CloseChannelWithUser(interfaces.messages,identity(remote),27) end
function N.friend_list()
    local list={}; local count=api.SteamAPI_ISteamFriends_GetFriendCount(interfaces.friends,4)
    for i=0,math.min(count,1000)-1 do
        local friend=api.SteamAPI_ISteamFriends_GetFriendByIndex(interfaces.friends,i,4)
        local name=api.SteamAPI_ISteamFriends_GetFriendPersonaName(interfaces.friends,friend)
        list[#list+1]={id=decimal(friend),name=name~=nil and ffi.string(name) or 'Steam friend',
            state=tonumber(api.SteamAPI_ISteamFriends_GetFriendPersonaState(interfaces.friends,friend))}
    end
    return list
end
function N.invite_friend(lobby,friend)
    local friendid=id(friend); if not friendid then return nil,'Choose a Steam friend from the list.' end
    if api.SteamAPI_ISteamFriends_GetFriendRelationship(interfaces.friends,friendid)~=3 then return nil,'That account is no longer on your Steam friends list.' end
    local lobbyid=assert(id(lobby))
    -- Explicit game invites carry the connect string through cold launch as well
    -- as GameRichPresenceJoinRequested while Balatro is already running.
    if N.game_invite and N.game_invite(interfaces.friends,friendid,'+connect_lobby '..lobby) then return true end
    if not api.SteamAPI_ISteamMatchmaking_InviteUserToLobby(interfaces.matchmaking,lobbyid,friendid) then return nil,'Steam could not send the game invite. Try again or copy the table link.' end
    return true
end
function N.presence(lobby)
    api.SteamAPI_ISteamFriends_SetRichPresence(interfaces.friends,'connect',lobby and ('+connect_lobby '..lobby) or nil)
end
function N.invites()
    local q={}; if callbacks then for i,v in ipairs(callbacks.queue) do q[i]=v end; for i=#callbacks.queue,1,-1 do callbacks.queue[i]=nil end end
    return q
end
function N.pump() if interfaces then api.SteamAPI_RunCallbacks() end end
function N.shutdown()
    if callbacks then
        api.SteamAPI_UnregisterCallback(callbacks.lobby.object); api.SteamAPI_UnregisterCallback(callbacks.presence.object); api.SteamAPI_UnregisterCallback(callbacks.url.object)
    end
end
-- Steam invokes registered callbacks from the game's existing RunCallbacks.
-- LuaJIT must never compile a stack that can reenter Lua via a C callback.
if jit then jit.off(register,true); jit.off(register_invites,true); jit.off(N.init,true); jit.off(N.pump,true) end
return N
