-- Full default profile without Macro Map. Future settings save separately in FyrelithDefaultSettings.
local source=[=======[
-- FYRELITH_EXECUTOR_COMPAT_V1
-- Executor compatibility is scoped to Fyrelith chunks, never installed into global debug APIs.
local E=getgenv()
local nativeLoad=loadstring
local nativeRequire=require
local rawDebug=debug or{}
local C={Errors={},Missing={},Version=1}
E.FyrelithCompatibility=C
local d={};for k,v in pairs(rawDebug)do d[k]=v end
if type(d.getinfo)~='function'and type(d.info)=='function'then
 d.getinfo=function(fn)local source,line,name=d.info(fn,'sln');return {source=source,short_src=source,currentline=line,name=name}end
end
if type(d.getupvalues)~='function'and type(getupvalues)=='function'then d.getupvalues=getupvalues end
if type(d.setupvalue)~='function'and type(setupvalue)=='function'then d.setupvalue=setupvalue end
if type(d.traceback)~='function'then d.traceback=function(err)return tostring(err)end end
C.Debug=d
-- Some executors run the caller at RobloxScript identity. Game data modules
-- must be required at normal script identity; always restore the caller.
local getIdentity=getthreadidentity or getidentity or(syn and syn.get_thread_identity)
local setIdentity=setthreadidentity or setidentity or(syn and syn.set_thread_identity)
local loaders=setmetatable({},{__mode='k'})
function C.Require(module)
 local value=nativeRequire(module)
 if type(value)~='table'or type(value.load_data)~='function'then return value end
 if loaders[value]then return loaders[value]end
 local facade=setmetatable({load_data=false},{__index=value,__newindex=value})
 facade.load_data=function(...)
  local result=table.pack(pcall(value.load_data,...))
  if result[1]then return table.unpack(result,2,result.n)end
  if not tostring(result[2]):find('Cannot require a non%-RobloxScript module')then error(result[2],0)end
  if type(getIdentity)~='function'or type(setIdentity)~='function'then error('Game data requires normal script identity; executor identity API is unavailable: '..tostring(result[2]),0)end
  local before=getIdentity()
  setIdentity(2)
  local retried=table.pack(pcall(value.load_data,...))
  local restored,restoreError=pcall(setIdentity,before)
  if not restored then error('Could not restore executor identity: '..tostring(restoreError),0)end
  if not retried[1]then error(retried[2],0)end
  C.DataContextRetries=(C.DataContextRetries or 0)+1
  return table.unpack(retried,2,retried.n)
 end
 loaders[value]=facade
 return facade
end
function C.Report(name,err)
 C.Errors[#C.Errors+1]={Module=name,Error=tostring(err)}
 warn('Fyrelith ['..tostring(name)..']: '..tostring(err))
 local player=game:GetService('Players').LocalPlayer
 local parent=player and player:FindFirstChildOfClass('PlayerGui');if not parent then return end
 local notice=parent:FindFirstChild('FyrelithStartupNotice')
 if not notice then
  notice=Instance.new('ScreenGui');notice.Name='FyrelithStartupNotice';notice.ResetOnSpawn=false;notice.DisplayOrder=2147483646
  local label=Instance.new('TextBox');label.Name='Details';label.TextEditable=false;label.ClearTextOnFocus=false;label.TextWrapped=true;label.TextSize=14;label.TextColor3=Color3.fromRGB(255,225,225);label.BackgroundColor3=Color3.fromRGB(30,18,24);label.BackgroundTransparency=.1;label.Size=UDim2.new(.8,0,0,115);label.Position=UDim2.new(.1,0,0,20);label.Parent=notice;notice.Parent=parent
 end
 notice.Details.Text='Fyrelith could not load '..tostring(name)..'\n'..tostring(err)..'\nCopy this message when reporting the problem.'
end
local prefix='local __c=getgenv().FyrelithCompatibility;local debug=__c.Debug;local loadstring=__c.Load;local require=__c.Require;\n'
function C.Load(source,name)
 local fn,err=nativeLoad(prefix..source,name)
 if not fn then return nil,err end
 if type(name)=='string'and name:find('Fyrelith',1,true)then
  return function(...)
   local result=table.pack(xpcall(fn,d.traceback,...))
   if not result[1]then C.Report(name,result[2]);return end
   return table.unpack(result,2,result.n)
  end
 end
 return fn
end

local debug=C.Debug
local loadstring=C.Load
local require=C.Require
-- Keep this default profile independent from an already running custom profile.
do
 local env=getgenv()
 local prior=env.FyrelithExecutionState
 if not prior or prior.Profile~='FyrelithDefaultNoMap' then
  local runtime=env.FyrelithRuntime
  if runtime and runtime.Alive and runtime.Save then pcall(runtime.Save)end
  local map=env.FyrelithMacroMap
  if map and map.Stop then pcall(map.Stop)end
  local render=env.FyrelithRenderBootstrap
  if render and render.Finish then pcall(render.Finish)end
  env.FyrelithRenderBootstrap=nil
  local screen=env.FyrelithBlackScreen
  if screen and screen.Stop then pcall(screen.Stop)end
  pcall(function()game:GetService('RunService'):Set3dRenderingEnabled(true)end)
 end
end
-- Set this URL before obfuscating.
local FYRELITH_ASSET_BASE='https://raw.githubusercontent.com/tobedicided/New-Fyrelith/main/'
-- Acquire before any yield so executor autoexec and teleport autoexec share one run.
local fyStorage=(function()
 local env=getgenv();local existing=env.FyrelithDefaultLoaderStorage
 if existing and existing.Version==2 then return existing end
 local native={Read=readfile,Write=writefile,Exists=isfile,Delete=delfile,List=listfiles,Folder=isfolder,Make=makefolder,Asset=getcustomasset or getsynasset}
 local storage={Version=2,Cache='.FyrelithDefaultCache',Macros='FyrelithDefaultSettings/Macros',Moved=0,Errors=0,LegacyQueue=(existing and existing.LegacyQueue)or(env.FyrelithDefaultTeleportQueued==true and not env.FyrelithDefaultCacheQueueVersion)}
 env.FyrelithDefaultLoaderStorage=storage
 local function folder(path)
  if type(native.Folder)=='function'and type(native.Make)=='function'then if not native.Folder(path)then native.Make(path)end else error('Executor folder support is required')end
 end
 local ok=pcall(function()folder(storage.Cache);folder('FyrelithDefaultSettings');folder(storage.Macros)end)
 storage.Ready=ok
 local runtime={['FyrelithRuntime.luau']=true,['FyrelithRuntimePayload.luau']=true,['FyrelithLoadDelayPrelude.luau']=true}
 function storage.Map(path)
  if storage.Ready and type(path)=='string' then
   local name=path:gsub('\\','/'):match('([^/]+)$')
   local lower=name and name:lower() or ''
   if lower:match('^fyrelith') and lower:match('%.json$') and not lower:find('audit',1,true) then
    if name:match('^FyrelithMacros_%d+_%d+%.json$') then return storage.Macros..'/'..name end
    return 'FyrelithDefaultSettings/'..name
   end
  end
  if not storage.Ready or type(path)~='string'or path:find('[/\\]')then return path end
  if path:match('^FyrelithMacros_%d+_%d+%.json$')then return storage.Macros..'/'..path end
  local lower=path:lower()
  local image=lower:match('^fyrelith')and(lower:match('%.png$')or lower:match('%.jpg$')or lower:match('%.jpeg$')or lower:match('%.webp$')or lower:match('%.gif$'))
  local audit=lower:match('^fyrelith')and lower:find('audit',1,true)and lower:match('%.json$')
  if image or audit or runtime[path]then return storage.Cache..'/'..path end
  return path
 end
 local function move(source,target)
  if source==target or not native.Exists(source)then return end
  local content=native.Read(source)
  if native.Exists(target)and native.Read(target)~=content then
   local backup=target..'.previous.'..tostring(DateTime.now().UnixTimestampMillis)
   local old=native.Read(target);native.Write(backup,old);assert(native.Read(backup)==old,'Backup verification failed')
  end
  native.Write(target,content);assert(native.Read(target)==content,'Migration verification failed')
  native.Delete(source);storage.Moved+=1
 end
 function storage.Migrate()
  if not storage.Ready or type(native.List)~='function'or type(native.Delete)~='function'then return end
  local success,files=pcall(native.List,'');if not success then return end
  for _,path in ipairs(files)do
   local name=path:gsub('\\','/'):match('([^/]+)$')
   if name and not runtime[name]then
    local target=storage.Map(name)
    if target~=name and native.Exists(path)then
     local moved=pcall(function()
      if name:match('^FyrelithMacros_%d+_%d+%.json$')and native.Exists(target)then
       local data=native.Read(path)
       if native.Read(target)~=data then local backup=target..'.legacy.'..tostring(DateTime.now().UnixTimestampMillis);native.Write(backup,data);assert(native.Read(backup)==data)end
       native.Delete(path);storage.Moved+=1
      else move(path,target)end
     end);if not moved then storage.Errors+=1 end
    end
   end
  end
 end
 function storage.PublishRuntime()
  if not storage.Ready then return end
  -- One temporary bridge lets already-queued older versions reach the new folder.
  if storage.LegacyQueue and not env.FyrelithDefaultCacheBooted then
   native.Write('FyrelithRuntime.luau',"getgenv().FyrelithDefaultCacheBooted=true;local run=loadstring(readfile('.FyrelithDefaultCache/FyrelithRuntime.luau'));if run then run()end")
  elseif type(native.Delete)=='function'and native.Exists('FyrelithRuntime.luau')then native.Delete('FyrelithRuntime.luau')end
  for _,name in ipairs({'FyrelithRuntimePayload.luau','FyrelithLoadDelayPrelude.luau'})do if type(native.Delete)=='function'and native.Exists(name)then native.Delete(name)end end
 end
 function storage.Read(path)
  local target=storage.Map(path)
  -- An older macro module may save once while stopping, after the first migration.
  -- Existing macros belong to the original profile and stay there.
  return native.Read(target)
 end
 function storage.Write(path,data)
  local target=storage.Map(path);local result=native.Write(target,data)
  if target==storage.Cache..'/FyrelithRuntime.luau'then storage.PublishRuntime()end
  return result
 end
 function storage.Exists(path)return native.Exists(storage.Map(path))end
 function storage.Asset(path,...)return native.Asset(storage.Map(path),...)end
 if storage.Ready then
  -- Dedicated loader profile: never import or move another profile.
  if not env.FyrelithDefaultCacheQueueVersion then env.FyrelithDefaultTeleportQueued=false;env.FyrelithDefaultCacheQueueVersion=1 end
 end
 return storage
end)()
local readfile=fyStorage.Read
fyStorage.Epoch=fyStorage.Epoch or 0
local fyWriteEpoch=fyStorage.Epoch
local function writefile(path,data)
 if fyWriteEpoch~=fyStorage.Epoch then return end
 return fyStorage.Write(path,data)
end
local isfile=fyStorage.Exists
local getcustomasset=fyStorage.Ready and fyStorage.Asset or getcustomasset
local getsynasset=fyStorage.Ready and fyStorage.Asset or getsynasset

-- Images are downloaded as data only and cached locally.
local fyAssetSizes={['Obsidian-Logo-91ece6806f23-compact-v1.png']=43977,['Obsidian-Launcher-258f87eab02e-compact-v1.png']=38807,['Fyrelith-Halloween-pumpkin-8a50525726bf-compact-v1.png']=31341,['Fyrelith-Halloween-web-57f7718ec81b-compact-v1.png']=40013,['Fyrelith-Halloween-ghost-2a07c00a4af1-compact-v1.png']=30920,['Fyrelith-Halloween-bat-4044ac8c7d72-compact-v1.png']=27357,['Fyrelith-Halloween-moon-0a5b51923909-compact-v1.png']=22294,['Fyrelith-Deep-Void-ca8e3b10fabf-compact-v1.jpg']=131235,['FyrelithThemeHeader.v2.png']=2135476,['FyrelithHeader.rose-eclipse.atelier-v2.png']=1857289,['FyrelithHeader.event-horizon.atelier-v2.png']=1921535,['FyrelithHeader.nebula-violet.atelier-v2.png']=1958168,['FyrelithHeader.stardust-blue.atelier-v2.png']=1947393,['FyrelithBlackHole.v1.png']=1025842,['FyrelithWebhookAvatar.blackhole.png']=1047959}
local function fyReadRemoteAsset(name)
 local expected=fyAssetSizes[name]
 if not expected then return nil end
 local path='.FyrelithDefaultCache/'..name
 local function valid(data)
  return type(data)=='string' and #data==expected and (data:sub(1,8)=='\137PNG\13\10\26\10' or data:sub(1,3)=='\255\216\255')
 end
 if type(readfile)=='function' then
  local ok,data=pcall(readfile,path)
  if ok and valid(data) then return data,path end
 end
 if FYRELITH_ASSET_BASE:find('YOUR_',1,true) then warn('Fyrelith: set FYRELITH_ASSET_BASE before using remote images');return nil end
 local url=FYRELITH_ASSET_BASE:gsub('/+$','')..'/'..name
 local transport=request or http_request or (syn and syn.request) or (http and http.request)
 local data
 if type(transport)=='function' then
  local ok,response=pcall(transport,{Url=url,Method='GET'})
  if ok and type(response)=='table' and tonumber(response.StatusCode or response.Status)==200 then data=response.Body end
 else
  local ok,value=pcall(function()return game:HttpGet(url)end)
  if ok then data=value end
 end
 if not valid(data) then warn('Fyrelith: image unavailable: '..name);return nil end
 if type(writefile)=='function' then
  if type(makefolder)=='function' then pcall(makefolder,'.FyrelithDefaultCache') end
  local ok=pcall(writefile,path,data)
  if ok then return data,path end
 end
 return data,nil
end
local function loadRemoteImage(name)
 local _,path=fyReadRemoteAsset(name)
 local importer=getcustomasset or getsynasset
 if not path or type(importer)~='function' then return '' end
 local ok,value=pcall(importer,path)
 return ok and value or ''
end
local function fyAssetDataUri(name)
 local data=fyReadRemoteAsset(name)
 if not data then return nil end
 local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
 local chunks={}
 for i=1,#data,3 do
  local a,b,c=data:byte(i,i+2)
  local n=a*65536+(b or 0)*256+(c or 0)
  local x=math.floor(n/262144)%64+1
  local y=math.floor(n/4096)%64+1
  local z=math.floor(n/64)%64+1
  local w=n%64+1
  chunks[#chunks+1]=alphabet:sub(x,x)..alphabet:sub(y,y)..(b and alphabet:sub(z,z) or '=')..(c and alphabet:sub(w,w) or '=')
  if i%49152==1 then task.wait() end
 end
 return 'data:image/png;base64,'..table.concat(chunks)
end

local fyEnv=getgenv()
local fyLoadDelayPrelude=[============[-- Small destination prelude: install before parsing the full artwork/UI payload.
local env=getgenv()
local leaveRouter=(function()
local env=getgenv()
local existing=env.FyrelithDefaultLeaveRouter
if existing and existing.Game==game and existing.Version==1 then return existing end
local T=game:GetService('TeleportService');local P=game:GetService('Players')
local router={Game=game,Version=1,Key='FyrelithDefaultPendingAutoLeave'}
env.FyrelithDefaultLeaveRouter=router
function router.Decide(intent,experience,place,job,now)
 if type(intent)~='table'or tonumber(intent.Experience)~=tonumber(experience)or not tonumber(intent.LobbyPlaceId)then return 'Ignore' end
 local age=(tonumber(now)or 0)-(tonumber(intent.Issued)or -math.huge)
 if age<0 or age>600000 then return 'Expired' end
 if tonumber(intent.LobbyPlaceId)==tonumber(place)then return 'Lobby' end
 if intent.SourceJob==job then return 'Same match' end
 return 'Redirect'
end
function router.Read()
 local ok,intent=pcall(T.GetTeleportSetting,T,router.Key)
 return ok and intent or nil
end
function router.Clear()
 pcall(T.SetTeleportSetting,T,router.Key,false)
 local state=env.FyrelithLobbyReturnState
 if state and state.Game==game then state.Cancelled=true end
 env.FyrelithReturnLobbyInProgress=false
end
function router.Redirect(intent)
 if type(intent)~='table'or tonumber(intent.Experience)~=game.GameId or not tonumber(intent.LobbyPlaceId)then return false end
 if tonumber(intent.LobbyPlaceId)==game.PlaceId then router.Clear();return false end
 local prior=env.FyrelithLobbyReturnState
 if prior and prior.Game==game and not prior.Cancelled then return not prior.Failed end
 local state={Game=game,Attempts=0,Destination=tonumber(intent.LobbyPlaceId),Status='Returning to lobby',Connections={}}
 env.FyrelithLobbyReturnState=state;env.FyrelithReturnLobbyInProgress=true
 local delay=env.FyrelithLoadDelayState;if delay then delay.Cancelled=true;delay.Active=false end
 local function cleanup()for _,c in ipairs(state.Connections)do c:Disconnect()end;table.clear(state.Connections)end
 task.spawn(function()
  local deadline=os.clock()+15
  while not P.LocalPlayer and os.clock()<deadline and not state.Cancelled do task.wait(.1)end
  local player=P.LocalPlayer
  if player then
   local queue=queue_on_teleport or queueonteleport or(syn and syn.queue_on_teleport)
   if type(queue)=='function'and not env.FyrelithDefaultTeleportQueued then
    local ok=pcall(queue,"local run=loadstring(readfile('.FyrelithDefaultCache/FyrelithRuntime.luau'));if run then run()end")
    if ok then env.FyrelithDefaultTeleportQueued=true end
   end
   state.Connections[#state.Connections+1]=player.OnTeleport:Connect(function(value)
    if value==Enum.TeleportState.Failed then state.TeleportFailed=true;state.Departing=false
    elseif value==Enum.TeleportState.InProgress then state.Departing=true end
   end)
   state.Connections[#state.Connections+1]=T.TeleportInitFailed:Connect(function(who)if who==player then state.TeleportFailed=true;state.Departing=false end end)
   for attempt=1,4 do
    if state.Cancelled then break end
    state.Attempts=attempt;state.TeleportFailed=false
    local ok,err=pcall(T.Teleport,T,state.Destination,player)
    if not ok then state.TeleportFailed=true;state.Error=tostring(err)end
    local untilTime=os.clock()+20
    while not state.Cancelled and not state.TeleportFailed and not state.Departing and os.clock()<untilTime do task.wait(.1)end
    if state.Departing then state.Status='Joining lobby';return end
    if attempt<4 and not state.Cancelled then task.wait(attempt*2)end
   end
  end
  cleanup();state.Failed=not state.Cancelled;state.Status=state.Cancelled and 'Cancelled'or'Return failed'
  env.FyrelithReturnLobbyInProgress=false
  -- If an early redirect failed, restore the normal UI so the user can act.
  if not state.Cancelled and not(env.FyrelithExecutionState and env.FyrelithExecutionState.Game==game)then
   pcall(function()local source=readfile('.FyrelithDefaultCache/FyrelithRuntimePayload.luau');env.FyrelithScriptSource=source;assert(loadstring(source))()end)
  end
 end)
 return true
end
function router.Early()
 local intent=router.Read()
 local action=router.Decide(intent,game.GameId,game.PlaceId,game.JobId,DateTime.now().UnixTimestampMillis)
 if action=='Lobby'or action=='Expired'then router.Clear();return false end
 if action=='Redirect'then return router.Redirect(intent)end
 return false
end
return router

end)()
if leaveRouter.Early()then return end
]============]
local fyRuntimeEntry=[============[-- Fyrelith small teleport entry point. Install the delay before loading UI assets.
getgenv().FyrelithDefaultCacheBooted=true
local ok,err=pcall(function()
 local prelude=assert(loadstring(readfile('.FyrelithDefaultCache/FyrelithLoadDelayPrelude.luau')))
 prelude()
end)
if not ok then getgenv().FyrelithLoadDelayError=tostring(err)end
if getgenv().FyrelithReturnLobbyInProgress then return end
local source=readfile('.FyrelithDefaultCache/FyrelithRuntimePayload.luau')
getgenv().FyrelithScriptSource=source
local run,message=loadstring(source)
if run then run()else warn('Fyrelith: '..tostring(message))end]============]
local function fySaveRuntimeBundle(source)
 writefile('.FyrelithDefaultCache/FyrelithLoadDelayPrelude.luau',fyLoadDelayPrelude)
 writefile('.FyrelithDefaultCache/FyrelithRuntimePayload.luau',source)
 -- Publish the small loader last, once both dependencies have been written.
 writefile('.FyrelithDefaultCache/FyrelithRuntime.luau',fyRuntimeEntry)
end
do
 local ok,err=pcall(function()assert(loadstring(fyLoadDelayPrelude))()end)
 if not ok then fyEnv.FyrelithLoadDelayError=tostring(err)end
end
if fyEnv.FyrelithReturnLobbyInProgress then return end
local fyBuild='FYRELITH_SUMMER_21_20261103_DATA20'
local fyProfile='FyrelithDefaultNoMap'
local fyPrior=fyEnv.FyrelithExecutionState
if fyPrior and fyPrior.Game==game and fyPrior.Build==fyBuild and fyPrior.Profile==fyProfile and not fyPrior.Cancelled then
 local healthy=fyPrior.Starting or (fyPrior.Ready and fyPrior.Gui and fyPrior.Gui.Parent and fyEnv.FyrelithAutoJoin and fyEnv.FyrelithAutoJoin.Alive)
 if healthy then fyPrior.DuplicateCount=(fyPrior.DuplicateCount or 0)+1 return end
end
if fyPrior then fyPrior.Cancelled=true end
local fyExecution={Game=game,Build=fyBuild,Profile=fyProfile,Starting=true,Ready=false,Started=os.clock(),DuplicateCount=0}
fyEnv.FyrelithExecutionState=fyExecution
local function fyOwnsExecution()return fyEnv.FyrelithExecutionState==fyExecution and not fyExecution.Cancelled end

getgenv().FyrelithEarlyRenderSource=[========[
-- Restore rendering before waiting for game modules or constructing the UI.
do
 local env=getgenv()
 local execution=env.FyrelithExecutionState
 if execution and execution.Game==game and execution.Ready and execution.Gui and execution.Gui.Parent then
  local feature=env.FyrelithBlackScreen if feature and feature.Alive and feature.Enabled and feature.Reapply then feature.Reapply() end
  return
 end
 local old=env.FyrelithRenderBootstrap if old and not old.Active and old.Finish then old.Finish() end
 local prior=env.FyrelithRuntime if prior and prior.Alive and prior.Save then pcall(prior.Save) end
 local state=old and old.Active and old or {Active=false,Applied=false,Started=os.clock(),PreviousFeature=env.FyrelithBlackScreen}
 env.FyrelithRenderBootstrap=state
 local player=game:GetService('Players').LocalPlayer
 while not player do task.wait() player=game:GetService('Players').LocalPlayer end
 local disabled=false
 pcall(function()
  local data=game:GetService('HttpService'):JSONDecode(readfile('FyrelithSession_'..player.UserId..'_'..game.GameId..'.json'))
  disabled=type(data.UI)=='table' and data.UI.RenderingDisabled==true
 end)
 if not disabled then local feature=env.FyrelithBlackScreen disabled=feature and feature.Alive and feature.Enabled==true or false end
 local run=game:GetService('RunService')
 local overlay,connection
 if not state.Finish then function state.Finish()
  state.Active=false
  if connection then connection:Disconnect() connection=nil end
  if overlay then overlay:Destroy() overlay=nil end
 end end
 if disabled and not state.Active then
  local ok,err=pcall(function()run:Set3dRenderingEnabled(false)end)
  state.Applied=ok state.Error=not ok and tostring(err)or nil
  if ok then
   state.Active=true state.AppliedAt=os.clock()
   local function cover()
    if not state.Active or overlay then return end
    local parent=player:FindFirstChildOfClass('PlayerGui') if not parent then return end
    overlay=Instance.new('ScreenGui')overlay.Name='FyrelithRenderBootCover'overlay.IgnoreGuiInset=true overlay.ResetOnSpawn=false overlay.DisplayOrder=2147483645
    local fill=Instance.new('Frame')fill.Size=UDim2.fromScale(1,1)fill.BackgroundColor3=Color3.new()fill.BorderSizePixel=0 fill.Parent=overlay overlay.Parent=parent
   end
   cover()
   connection=run.Heartbeat:Connect(function()
    if not state.Active then return end
    local feature=env.FyrelithBlackScreen
    if feature and feature~=state.PreviousFeature and feature.Alive and feature.Enabled and feature.RenderingOff and feature.BootReady then state.Finish() return end
    pcall(function()run:Set3dRenderingEnabled(false)end) cover()
   end)
   task.delay(60,function()
    if state.Active then state.TimedOut=true state.Finish() pcall(function()run:Set3dRenderingEnabled(true)end) end
   end)
  end
 end
 local queue=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
 if type(queue)=='function' and type(env.FyrelithEarlyRenderSource)=='string' and not env.FyrelithDefaultRenderPreludeQueued then
  local ok,err=pcall(queue,env.FyrelithEarlyRenderSource)
  env.FyrelithDefaultRenderPreludeQueued=ok state.QueueError=not ok and tostring(err)or nil
 end
end
]========]
-- Restore rendering before waiting for game modules or constructing the UI.
do
 local env=getgenv()
 local execution=env.FyrelithExecutionState
 if execution and execution.Game==game and execution.Ready and execution.Gui and execution.Gui.Parent then
  local feature=env.FyrelithBlackScreen if feature and feature.Alive and feature.Enabled and feature.Reapply then feature.Reapply() end
  return
 end
 local old=env.FyrelithRenderBootstrap if old and not old.Active and old.Finish then old.Finish() end
 local prior=env.FyrelithRuntime if prior and prior.Alive and prior.Save then pcall(prior.Save) end
 local state=old and old.Active and old or {Active=false,Applied=false,Started=os.clock(),PreviousFeature=env.FyrelithBlackScreen}
 env.FyrelithRenderBootstrap=state
 local player=game:GetService('Players').LocalPlayer
 while not player do task.wait() player=game:GetService('Players').LocalPlayer end
 local disabled=false
 pcall(function()
  local data=game:GetService('HttpService'):JSONDecode(readfile('FyrelithSession_'..player.UserId..'_'..game.GameId..'.json'))
  disabled=type(data.UI)=='table' and data.UI.RenderingDisabled==true
 end)
 if not disabled then local feature=env.FyrelithBlackScreen disabled=feature and feature.Alive and feature.Enabled==true or false end
 local run=game:GetService('RunService')
 local overlay,connection
 if not state.Finish then function state.Finish()
  state.Active=false
  if connection then connection:Disconnect() connection=nil end
  if overlay then overlay:Destroy() overlay=nil end
 end end
 if disabled and not state.Active then
  local ok,err=pcall(function()run:Set3dRenderingEnabled(false)end)
  state.Applied=ok state.Error=not ok and tostring(err)or nil
  if ok then
   state.Active=true state.AppliedAt=os.clock()
   local function cover()
    if not state.Active or overlay then return end
    local parent=player:FindFirstChildOfClass('PlayerGui') if not parent then return end
    overlay=Instance.new('ScreenGui')overlay.Name='FyrelithRenderBootCover'overlay.IgnoreGuiInset=true overlay.ResetOnSpawn=false overlay.DisplayOrder=2147483645
    local fill=Instance.new('Frame')fill.Size=UDim2.fromScale(1,1)fill.BackgroundColor3=Color3.new()fill.BorderSizePixel=0 fill.Parent=overlay overlay.Parent=parent
   end
   cover()
   connection=run.Heartbeat:Connect(function()
    if not state.Active then return end
    local feature=env.FyrelithBlackScreen
    if feature and feature~=state.PreviousFeature and feature.Alive and feature.Enabled and feature.RenderingOff and feature.BootReady then state.Finish() return end
    pcall(function()run:Set3dRenderingEnabled(false)end) cover()
   end)
   task.delay(60,function()
    if state.Active then state.TimedOut=true state.Finish() pcall(function()run:Set3dRenderingEnabled(true)end) end
   end)
  end
 end
 local queue=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
 if type(queue)=='function' and type(env.FyrelithEarlyRenderSource)=='string' and not env.FyrelithDefaultRenderPreludeQueued then
  local ok,err=pcall(queue,env.FyrelithEarlyRenderSource)
  env.FyrelithDefaultRenderPreludeQueued=ok state.QueueError=not ok and tostring(err)or nil
 end
end


repeat task.wait() until game:IsLoaded()
if not fyOwnsExecution() then return end
do
 local env=getgenv()
 local prior=env.FyrelithRuntime
 if prior then
  if prior.Alive and prior.Save then pcall(prior.Save) end
  prior.Alive=false
  if prior.Connection then prior.Connection:Disconnect() end
  if prior.PreferenceConnection then prior.PreferenceConnection:Disconnect() end
 end
 local source=env.FyrelithScriptSource
 if type(source)=='string' and type(writefile)=='function' then pcall(fySaveRuntimeBundle,source) end
 local queue=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
 if type(queue)=='function' and not env.FyrelithDefaultTeleportQueued then
  local ok=pcall(queue,[=[
local source=readfile('.FyrelithDefaultCache/FyrelithRuntime.luau')
getgenv().FyrelithScriptSource=source
local run,err=loadstring(source)
if run then run() else warn('Fyrelith: '..tostring(err)) end
]=])
  if ok then env.FyrelithDefaultTeleportQueued=true end
 end
end


-- Stop the previous installation before attaching one shared idle controller.
do
 local environment=getgenv()
 for _,name in ipairs({'FyrelithAntiAFK','FyrelithIdleRecovery','FyrelithAutoCaptcha'})do
  local previous=environment[name]
  if previous then
   if previous.Cleanup then pcall(previous.Cleanup) elseif previous.Stop then pcall(previous.Stop)end
   previous.Alive=false
  end
 end
end
-- LastInput tracks real activity; synthetic keep-alives must not postpone Auto Walk.
do
 local environment=getgenv()
 local idle={Alive=true,LastInput=os.clock(),LastPulse=-math.huge,Connections={},PulseCount=0}
 environment.FyrelithAntiAFK=idle
 function idle.Stop()
  idle.Alive=false
  for _,connection in ipairs(idle.Connections)do connection:Disconnect()end
  table.clear(idle.Connections)
 end
 idle.Cleanup=idle.Stop
 task.spawn(function()
  local players=game:GetService('Players')
  local player=players.LocalPlayer
  while idle.Alive and not player do task.wait(.1) player=players.LocalPlayer end
  if not idle.Alive then return end
  local input=game:GetService('UserInputService')
  local function activity()
   if idle.Alive and not idle.SendingInput then idle.LastInput=os.clock() end
  end
  for _,signal in ipairs({input.InputBegan,input.InputChanged,input.InputEnded})do
   table.insert(idle.Connections,signal:Connect(activity))
  end
  function idle.Pulse()
   if not idle.Alive or idle.SendingInput or os.clock()-idle.LastPulse<60 then return end
   idle.LastPulse=os.clock() idle.SendingInput=true
   local ok,err=pcall(function()
    local user=game:GetService('VirtualUser')
    user:CaptureController()
    user:ClickButton2(Vector2.new(0,0))
   end)
   idle.SendingInput=false
   idle.LastError=not ok and tostring(err) or nil
   idle.Active=ok
   if ok then idle.PulseCount+=1 end
  end
  table.insert(idle.Connections,player.Idled:Connect(idle.Pulse))
  while idle.Alive do
   if os.clock()-idle.LastInput>=90 then idle.Pulse() end
   task.wait(1)
  end
 end)
end
task.spawn(function()
local startupOK,startupError=xpcall(function()
local function waitForFyrelithGame()
 local player=game:GetService('Players').LocalPlayer
 while not player do task.wait(.1) player=game:GetService('Players').LocalPlayer end
 local config=workspace:WaitForChild('_MAP_CONFIG') config:WaitForChild('IsLobby')
 local module=game:GetService('ReplicatedStorage'):WaitForChild('src'):WaitForChild('Loader')
 local Loader=require(module)
 local required={'EndpointsClient','LobbyServiceClient','UnitCollectionServiceClient','GUIService','SummonServiceClient','SummonFX','GoldShopServiceClient'}
 while true do
  local registry
  if debug and type(debug.getupvalues)=='function' then
   local ok,upvalues=pcall(debug.getupvalues,Loader.load_client_service)
   if ok then for _,v in pairs(upvalues) do if type(v)=='table' and v.EndpointsClient then registry=v break end end end
  end
  local ready={} local complete=true
  if registry then
   for _,name in ipairs(required) do local entry=registry[name]
    ready[name]=entry and entry.module
    if type(ready[name])~='table' then complete=false break end
   end
  elseif player:FindFirstChild('_stats') and player:FindFirstChild('_settings') then
   -- Fallback for executors without upvalue inspection.
   for _,name in ipairs(required) do local ok,value=pcall(Loader.load_client_service,module,name)
    ready[name]=ok and value or nil if type(ready[name])~='table' then complete=false break end
   end
  else complete=false end
  if complete then
   local U=ready.UnitCollectionServiceClient local E=ready.EndpointsClient local G=ready.GUIService
   if type(E.invoke_server)=='function' and E.session and G.session and U.session and U.session.profile_data and U.session.collection and U.session.inventory then
    getgenv().FyrelithGameReady={Loader=Loader,Services=ready,JobId=game.JobId}
    return Loader
   end
  end
  task.wait(.25)
 end
end
waitForFyrelithGame()

if not fyOwnsExecution() then return end
local function createHost()
-- FYRELITH HUB | Standalone UI framework. No game-specific functions.
-- OBSIDIAN / Space + Halloween / v6
-- Executor edition: run this one file. Both user-provided images are embedded.
-- Images use writefile + getcustomasset/getsynasset; no upload or HTTP required.
-- Preferences are saved automatically per account and experience across rejoins.
-- Set this to the uploaded Roblox Image ID for Obsidian-Logo.png.
-- Example format: "rbxassetid://YOUR_IMAGE_ID" (use your actual numeric ID).
-- The attached logo is embedded below, so no upload or separate image is required.


local LOGO_IMAGE=loadRemoteImage('Obsidian-Logo-91ece6806f23-compact-v1.png')
local LAUNCHER_IMAGE=loadRemoteImage('Obsidian-Launcher-258f87eab02e-compact-v1.png')


--[[
Microsoft Fluent Emoji artwork
https://github.com/microsoft/fluentui-emoji
    MIT License

    Copyright (c) Microsoft Corporation.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE

]]
local HALLOWEEN_IMAGES={pumpkin=loadRemoteImage('Fyrelith-Halloween-pumpkin-8a50525726bf-compact-v1.png'),web=loadRemoteImage('Fyrelith-Halloween-web-57f7718ec81b-compact-v1.png'),ghost=loadRemoteImage('Fyrelith-Halloween-ghost-2a07c00a4af1-compact-v1.png'),bat=loadRemoteImage('Fyrelith-Halloween-bat-4044ac8c7d72-compact-v1.png'),moon=loadRemoteImage('Fyrelith-Halloween-moon-0a5b51923909-compact-v1.png')}
local DEEP_VOID_IMAGE=loadRemoteImage('Fyrelith-Deep-Void-ca8e3b10fabf-compact-v1.jpg')
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local Input = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Lighting = game:GetService('Lighting')
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
for _,name in ipairs({'FyrelithUIOnly'}) do
 local old=playerGui:FindFirstChild(name)
 if old then old:Destroy() end
end
local store=playerGui:FindFirstChild('FyrelithDefaultPreferences')
if not store then store=Instance.new('Configuration'); store.Name='FyrelithDefaultPreferences'; store.Parent=playerGui end
pcall(function()
 local filename='FyrelithSession_'..player.UserId..'_'..game.GameId..'.json'
 if type(readfile)=='function' and type(isfile)=='function' and isfile(filename) then
  local saved=game:GetService('HttpService'):JSONDecode(readfile(filename))
  for k,v in pairs(saved.UI or {}) do if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then store:SetAttribute(k,v) end end
 end
end)
local function pref(key,default)
 local value=store:GetAttribute(key)
 if type(value)~=type(default) then value=store:GetAttribute(key) end
 if type(value)~=type(default) then return default end
 if value==nil then return default end
 return value
end
local state={theme=pref('Theme','Standard'),accent=pref('Accent',1),scale=pref('Scale',100),smooth=pref('Smooth',true),reduce=pref('ReduceMotion',false),tips=pref('Tooltips',true),stars=pref('Stars',true),showIcon=pref('ShowIcon',true),border=pref('AnimatedBorder',true),page='Settings',open=true}
if store:GetAttribute('RoseEclipseRevision')~=2 then state.theme='Space' state.accent=1 state.scale=100 store:SetAttribute('RoseEclipseRevision',2)end
local launcher
local savedHotkey=pref('Hotkey','LeftControl')
local hotkey=Enum.KeyCode.RightShift
for _,key in ipairs(Enum.KeyCode:GetEnumItems()) do if key.Name==savedHotkey then hotkey=key; break end end
if hotkey==Enum.KeyCode.Unknown or hotkey==Enum.KeyCode.Escape then hotkey=Enum.KeyCode.RightShift end
local capturingKey=false
local function keyName(key)
 return key.Name:gsub('(%l)(%u)','%1 %2')
end
if state.theme~='Space' and state.theme~='Halloween' and state.theme~='Standard' and state.theme~='Event Horizon' and state.theme~='Nebula Violet' and state.theme~='Stardust Blue' then state.theme='Standard' end
local scaleMaximum=game:GetService('UserInputService').TouchEnabled and 200 or 110
state.scale=math.clamp(tonumber(state.scale) or 100,75,scaleMaximum)
state.accent=math.clamp(tonumber(state.accent) or 1,1,7)
local themes={
 ['Event Horizon']={bg=Color3.fromRGB(12,12,13),card=Color3.fromRGB(24,23,22),side=Color3.fromRGB(18,17,16),field=Color3.fromRGB(38,34,29),line=Color3.fromRGB(91,78,58),accent=Color3.fromRGB(231,191,133),secondary=Color3.fromRGB(255,226,181)},
 ['Nebula Violet']={bg=Color3.fromRGB(14,12,22),card=Color3.fromRGB(25,22,38),side=Color3.fromRGB(20,17,30),field=Color3.fromRGB(38,31,54),line=Color3.fromRGB(79,65,112),accent=Color3.fromRGB(187,156,239),secondary=Color3.fromRGB(224,208,255)},
 ['Stardust Blue']={bg=Color3.fromRGB(9,15,24),card=Color3.fromRGB(17,27,41),side=Color3.fromRGB(12,21,33),field=Color3.fromRGB(25,40,59),line=Color3.fromRGB(52,78,110),accent=Color3.fromRGB(121,185,245),secondary=Color3.fromRGB(193,226,255)},
 Standard={accent=Color3.fromRGB(98,166,255)},
 Space={bg=Color3.fromRGB(15,13,17),card=Color3.fromRGB(24,21,26),side=Color3.fromRGB(19,16,21),field=Color3.fromRGB(37,29,35),line=Color3.fromRGB(83,62,73),accent=Color3.fromRGB(220,150,166),secondary=Color3.fromRGB(245,208,216)},
 Halloween={bg=Color3.fromRGB(19,17,29),card=Color3.fromRGB(29,25,40),side=Color3.fromRGB(21,18,31),field=Color3.fromRGB(39,31,48),line=Color3.fromRGB(75,57,89),accent=Color3.fromRGB(255,151,78),secondary=Color3.fromRGB(181,133,249)},
}
local white=Color3.fromRGB(240,243,249)
local muted=Color3.fromRGB(194,203,219)
local swatches={false,Color3.fromRGB(145,96,255),Color3.fromRGB(237,83,157),Color3.fromRGB(50,199,218),Color3.fromRGB(81,210,126),Color3.fromRGB(255,190,79),Color3.fromRGB(139,151,177)}
local connections,bindings,activeTweens={},{},{}
local dead=false
local function on(signal,fn)
 local c=signal:Connect(fn); table.insert(connections,c); return c
end
local function new(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props or {}) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local function round(obj,r) new('UICorner',{CornerRadius=UDim.new(0,r or 10)},obj) end
local function stroke(obj,color,transparency)
 return new('UIStroke',{Color=color or white,Thickness=1,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},obj)
end
local function palette()
 local p=themes[state.theme]
 local accent=swatches[state.accent] or p.accent
 if state.theme=='Standard' then
  -- Neutral dark surfaces receive a restrained tint from the selected accent.
  p={
   bg=Color3.fromRGB(13,16,22):Lerp(accent,.115),
   card=Color3.fromRGB(21,25,33):Lerp(accent,.13),
   side=Color3.fromRGB(15,18,25):Lerp(accent,.09),
   field=Color3.fromRGB(29,34,44):Lerp(accent,.15),
   line=Color3.fromRGB(55,63,78):Lerp(accent,.26),
   accent=accent,secondary=accent:Lerp(Color3.new(1,1,1),.15),
  }
 end
 return p,accent
end
local function bind(obj,property,role)
 table.insert(bindings,{obj=obj,property=property,role=role})
 local p,a=palette(); obj[property]=type(role)=='function' and role(p,a) or p[role]
end
local function animate(obj,props,duration)
 -- One tween per object prevents stale hover/theme animations fighting each other.
 if activeTweens[obj] then activeTweens[obj]:Cancel() end
 if not state.smooth or state.reduce then
  for k,v in pairs(props) do obj[k]=v end
  return
 end
 local goals={}
 for property,value in pairs(props) do
  local kind=typeof(value)
  if kind=='ColorSequence' or kind=='NumberSequence' then obj[property]=value
  else goals[property]=value end
 end
 if not next(goals) then activeTweens[obj]=nil return end
 local t=TweenService:Create(obj,TweenInfo.new(duration or .22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),goals)
 activeTweens[obj]=t; t:Play()
end
local function text(parent,value,x,y,w,h,size,color,bold)
 return new('TextLabel',{BackgroundTransparency=1,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=(size or 16)>=28 and (size or 16) or math.max(14,math.floor((size or 16)*1.16+.5)),TextColor3=color or white,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd},parent)
end
local function panel(parent,name,x,y,w,h,role,r)
 local obj=new('Frame',{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BorderSizePixel=0},parent)
 round(obj,r or 10); bind(obj,'BackgroundColor3',role or 'card')
 local s=stroke(obj); bind(s,'Color','line')
 return obj
end
local function line(parent,x,y,w)
 local obj=new('Frame',{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,1),BorderSizePixel=0},parent)
 bind(obj,'BackgroundColor3','line'); obj.BackgroundTransparency=.45
 return obj
end
-- Lucide (ISC) image assets via frappedevs/lucideblox (MIT).
-- https://github.com/frappedevs/lucideblox/blob/master/src/modules/util/icons.json
-- Static image IDs only: no remote code is downloaded or executed.
local iconAssets={Play=7743871480,Send=7734053039,Calendar=7733919198,Map=7733992829,MacroCode=7733779730,
 Overview=7733960981, Player=7743875962, Main=10734975486, Visuals=7733774602,
 Utilities=7733917120, Settings=7734053495, Appearance=7733701455,
 Interface=7734002839, Search=7734052925, Close=7743878857,
 Minimize=7734000129, Chevron=7733717447, Save=7734052335, Star=7734068321,
}
local iconImages={}
local function icon(parent,kind,x,y,size,color)
 local image=new('ImageLabel',{Name='Icon_'..kind,BackgroundTransparency=1,
  Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),
  Image='rbxassetid://'..assert(iconAssets[kind],'Unknown icon: '..kind),
  ImageColor3=color or white,ScaleType=Enum.ScaleType.Fit,
  ResampleMode=Enum.ResamplerMode.Default},parent)
 table.insert(iconImages,image)
 local function setColor(c) image.ImageColor3=c end
 return image,setColor,{image}
end
-- Load the shared font families before the first visible frame.
pcall(function()
 game:GetService('ContentProvider'):PreloadAsync({
  Font.fromEnum(Enum.Font.Gotham).Family,
  Font.fromEnum(Enum.Font.GothamBold).Family,
  Font.fromEnum(Enum.Font.GothamMedium).Family,
 })
end)
if not fyOwnsExecution()then return end
for _,previous in ipairs(playerGui:GetChildren())do
 if previous:IsA('ScreenGui')and previous.Name=='FyrelithUIOnly'then previous:Destroy()end
end
local gui=new('ScreenGui',{Name='FyrelithUIOnly',ResetOnSpawn=false,IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ClipToDeviceSafeArea=false,DisplayOrder=2147483647,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
fyExecution.Gui=gui
local blur=new('BlurEffect',{Name='FyrelithUIOnlyBlur',Size=0},Lighting)
local root=new('Frame',{Name='Window',Visible=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(960,1040),BackgroundTransparency=1},gui)
local uiScale=new('UIScale',{Scale=1},root)
local motion=new('CanvasGroup',{Name='Motion',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,48,1,48),BackgroundTransparency=1,GroupTransparency=0},root)

local canvas=new('Frame',{Name='Content',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(960,1040)},root)
local motionScale=new('UIScale',{Name='ContentMotionScale',Scale=1},canvas)
round(canvas,18)
-- Layered shadow avoids dependencies on external images.
for i=5,1,-1 do
 local shadow=new('Frame',{Name='Shadow',Position=UDim2.fromOffset(-i*3,i),Size=UDim2.new(1,i*6,1,i*5),BackgroundColor3=Color3.new(),BackgroundTransparency=.94,BorderSizePixel=0,ZIndex=1},canvas)
 round(shadow,12+i*2)
end
local surface=new('CanvasGroup',{Name='Surface',Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(960,1040),BorderSizePixel=0,ClipsDescendants=true},canvas)
surface.Active=true;round(surface,18);bind(surface,'BackgroundColor3','bg')
do local edge=stroke(surface);bind(edge,'Color','line') end
-- The outer CanvasGroup masks every background layer to the same rounded silhouette.
-- Layered perimeter lighting is native GUI geometry and follows the theme.
do
 local lighting=new('Frame',{Name='AnimatedBorder',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false,ZIndex=8,Visible=state.border},root)
 local gradients={}
 for i,width in ipairs({12,6,1.8})do
  local ring=new('Frame',{Name='GlowLayer'..i,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false},lighting)
  round(ring,18)
  local edge=stroke(ring,nil,({.92,.70,.05})[i]);edge.Thickness=width
  bind(edge,'Color','accent')
  local gradient=new('UIGradient',{Rotation=i*8,Color=ColorSequence.new(Color3.new(1,1,1)),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.32,.98),NumberSequenceKeypoint.new(.44,.65),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.56,.65),NumberSequenceKeypoint.new(.68,.98),NumberSequenceKeypoint.new(1,1)})},edge)
  gradients[i]=gradient
 end
 local elapsed=0
 on(RunService.RenderStepped,function(dt)
  lighting.Visible=state.border and state.open
  if not state.border or not state.open or state.reduce or not state.smooth then return end
  elapsed+=math.min(dt,.1)
  for i,gradient in ipairs(gradients)do gradient.Rotation=(elapsed*56+i*8)%360 end
 end)
end

-- Deep Void: one cinematic texture behind the existing, fixed-size controls.
local spaceArt={}
spaceArt.group=new('Frame',{Name='DeepVoidBackground',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=(state.theme=='Space' or state.theme=='Event Horizon' or state.theme=='Nebula Violet' or state.theme=='Stardust Blue'),Active=false},surface)
spaceArt.group.ClipsDescendants=true
spaceArt.image=new('ImageLabel',{Name='BlackHole',Image=DEEP_VOID_IMAGE,ImageColor3=Color3.fromRGB(255,176,195),BackgroundTransparency=1,ImageTransparency=.12,ScaleType=Enum.ScaleType.Crop,Position=UDim2.fromScale(-.03,-.03),Size=UDim2.fromScale(1.06,.29),Active=false},spaceArt.group)
spaceArt.shade=new('Frame',{Name='ReadabilityShade',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(12,8,13),BackgroundTransparency=.64,BorderSizePixel=0,Active=false},spaceArt.group)
new('UIGradient',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.10),NumberSequenceKeypoint.new(.5,.20),NumberSequenceKeypoint.new(1,.02)})},spaceArt.shade)
local starLayer=new('Frame',{Name='Starfield',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ClipsDescendants=true,ZIndex=2,Active=false},surface)
local stars={}; local random=Random.new(713)
for i=1,140 do
 local diameter=i%8==0 and 3.8 or random:NextNumber(1.8,3)
 local dot=new('Frame',{Name='Star',BorderSizePixel=0,BackgroundTransparency=.25,Position=UDim2.fromScale(random:NextNumber(),random:NextNumber()),Size=UDim2.fromOffset(diameter,diameter),Active=false},starLayer)
 round(dot,9); bind(dot,'BackgroundColor3',i%4==0 and 'secondary' or 'accent')
 if i%7==0 then
  local glow=new('ImageLabel',{Name='Glow',BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(14,14),Image='rbxassetid://6772783963',ImageTransparency=.35,Active=false},dot)
  bind(glow,'ImageColor3',i%4==0 and 'secondary' or 'accent')
 end
 stars[i]={dot=dot,x=dot.Position.X.Scale,y=dot.Position.Y.Scale,speed=random:NextNumber(.009,.023),drift=random:NextNumber(.002,.007),phase=random:NextNumber(0,6.28)}
end
-- Microsoft Fluent Emoji 3D artwork (MIT), embedded from original PNGs.
-- Full source links are listed in Halloween-ASSETS.txt.
local halloweenLayer=new('Frame',{Name='HalloweenBackground',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false,Visible=false},surface)
local decorationImages={}
local function decoration(parent,name,image,x,y,w,h,opacity,rotation)
 local obj=new('ImageLabel',{Name=name,BackgroundTransparency=1,Image=image,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),ScaleType=Enum.ScaleType.Fit,ImageTransparency=opacity,Rotation=rotation or 0,Active=false},parent)
 table.insert(decorationImages,obj)
 return obj
end
local cornerWeb=decoration(halloweenLayer,'CornerCobweb',HALLOWEEN_IMAGES.web,1091,55,180,180,.48,18)
cornerWeb.ImageColor3=Color3.fromRGB(196,168,232)
local pumpkin=decoration(halloweenLayer,'JackOLantern',HALLOWEEN_IMAGES.pumpkin,925,84,112,112,.04,-8)
local ghost=decoration(halloweenLayer,'LittleGhost',HALLOWEEN_IMAGES.ghost,1045,122,66,66,.1,8)
local header=new('Frame',{Name='Header',BackgroundTransparency=1,Size=UDim2.fromOffset(1200,68)},surface)
local brandLogo=new('ImageLabel',{Name='BrandLogo',BackgroundTransparency=1,Position=UDim2.fromOffset(15,7),Size=UDim2.fromOffset(54,54),Image=LOGO_IMAGE,ImageColor3=Color3.new(1,1,1),ScaleType=Enum.ScaleType.Fit,Visible=LOGO_IMAGE~=''},header)
if LOGO_IMAGE~='' then table.insert(iconImages,brandLogo) end
text(header,'·',62,0,16,68,20,muted)
local brand=text(header,'F Y R E L I T H',91,0,250,68,19,Color3.fromRGB(185,197,216))
local dragHandle=new('Frame',{Name='DragHandle',BackgroundTransparency=1,Active=true,Size=UDim2.fromOffset(590,68)},header)
local searchBox=panel(header,'Search',620,14,440,40,'field',9)
local _,_,searchParts=icon(searchBox,'Search',13,10,20,muted)
local search=new('TextBox',{Name='SearchInput',Position=UDim2.fromOffset(44,0),Size=UDim2.new(1,-54,1,0),BackgroundTransparency=1,Text='',PlaceholderText='Search settings...',ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=white,PlaceholderColor3=muted,Font=Enum.Font.Gotham,TextSize=16},searchBox)
local function control(parent,name,x,y,w,h,kind)
 local b=new('TextButton',{Name=name,Text='',AutoButtonColor=false,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BorderSizePixel=0},parent)
 round(b,8); bind(b,'BackgroundColor3','field'); local s=stroke(b); bind(s,'Color','line')
 if kind then icon(b,kind,(w-24)/2,(h-24)/2,24,Color3.fromRGB(203,213,230)) end
 on(b.MouseEnter,function() local p=palette(); animate(b,{BackgroundColor3=p.field:Lerp(white,.07)}) end)
 on(b.MouseLeave,function() local p=palette(); animate(b,{BackgroundColor3=p.field}) end)
 return b
end
local minimize=control(header,'Minimize',1080,14,40,40,'Minimize')
local close=control(header,'Close',1132,14,40,40,'Close')
do
 local dock=new('Frame',{Name='CommandDock',Position=UDim2.fromOffset(614,12),Size=UDim2.fromOffset(568,44),BackgroundColor3=Color3.fromRGB(10,12,19),BackgroundTransparency=.18,BorderSizePixel=0},header) round(dock,22)
 local rim=stroke(dock,Color3.fromRGB(166,175,203),.65)
 local rimLight=new('UIGradient',{Rotation=14,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(99,108,137)),ColorSequenceKeypoint.new(.45,Color3.fromRGB(214,213,239)),ColorSequenceKeypoint.new(.68,Color3.fromRGB(157,134,222)),ColorSequenceKeypoint.new(1,Color3.fromRGB(65,72,95))})},rim)
 new('UIGradient',{Rotation=95,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(183,183,183))},dock)
 bind(dock,'BackgroundColor3',function(p,a) return p.bg:Lerp(a,.045) end)
 bind(rim,'Color',function(p,a) return a:Lerp(white,.35) end)
 local function syncRim()
  local p,a=palette()
  rimLight.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,p.line),ColorSequenceKeypoint.new(.45,a:Lerp(white,.6)),ColorSequenceKeypoint.new(.68,a),ColorSequenceKeypoint.new(1,p.line)})
 end
 syncRim()
 on(dock:GetPropertyChangedSignal('BackgroundColor3'),syncRim)
 searchBox.Parent=dock searchBox.Position=UDim2.fromOffset(6,4) searchBox.Size=UDim2.fromOffset(446,36) searchBox.BackgroundTransparency=.75
 local old=searchBox:FindFirstChildOfClass('UIStroke') if old then old.Transparency=1 end
 searchBox:FindFirstChildOfClass('UICorner').CornerRadius=UDim.new(0,18)
 search.Position=UDim2.fromOffset(44,0) search.Size=UDim2.new(1,-90,1,0) search.Font=Enum.Font.GothamMedium search.TextSize=14
 local searchIcon=searchBox:FindFirstChild('Icon_Search') if searchIcon then searchIcon.Position=UDim2.fromOffset(14,8) end
 local focusLine=new('Frame',{Name='FocusLight',Position=UDim2.fromOffset(44,34),Size=UDim2.fromOffset(350,1),BackgroundColor3=Color3.fromRGB(185,166,255),BackgroundTransparency=.9,BorderSizePixel=0},searchBox)
 new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,0),NumberSequenceKeypoint.new(.75,0),NumberSequenceKeypoint.new(1,1)})},focusLine)
 local keycap=text(searchBox,'/',410,7,24,22,12,muted) keycap.Name='SearchShortcut' keycap.BackgroundColor3=Color3.fromRGB(37,41,56) keycap.BackgroundTransparency=.4 keycap.TextXAlignment=Enum.TextXAlignment.Center round(keycap,7)
 bind(focusLine,'BackgroundColor3',function(p,a) return a end)
 bind(keycap,'BackgroundColor3','field')
 local function active(value)
  local _,accent=palette()
  animate(focusLine,{BackgroundTransparency=value and .12 or .9},.24)
  if searchIcon then animate(searchIcon,{ImageColor3=value and accent:Lerp(white,.25) or muted},.24) end
  animate(rim,{Transparency=value and .35 or .65},.24)
 end
 on(search.Focused,function() active(true) keycap.Visible=false end)
 searchBox.Active=true
 on(searchBox.InputBegan,function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then search:CaptureFocus() end
 end)
 on(search.FocusLost,function() active(false) keycap.Visible=search.Text=='' end)
 on(search:GetPropertyChangedSignal('Text'),function() keycap.Visible=not search:IsFocused() and search.Text=='' end)
 on(searchBox.MouseEnter,function() if not search:IsFocused() then if searchIcon then animate(searchIcon,{ImageColor3=white},.2) end end end)
 on(searchBox.MouseLeave,function() if not search:IsFocused() then if searchIcon then animate(searchIcon,{ImageColor3=muted},.2) end end end)
 on(Input.InputBegan,function(input,processed)
  if state.open and not processed and input.KeyCode==Enum.KeyCode.Slash and not Input:GetFocusedTextBox() then task.defer(function() if not dead and state.open then search:CaptureFocus() end end) end
 end)
 for i,b in ipairs({minimize,close}) do
  b.Parent=dock b.Position=UDim2.fromOffset(i==1 and 462 or 514,4) b.Size=UDim2.fromOffset(42,36) b.BackgroundTransparency=.8
  local corner=b:FindFirstChildOfClass('UICorner') if corner then corner.CornerRadius=UDim.new(0,14) end
  local edge=b:FindFirstChildOfClass('UIStroke') if edge then edge.Transparency=1 end
  local image=b:FindFirstChildOfClass('ImageLabel') if image then image.Position=UDim2.fromOffset(11,8) image.Size=UDim2.fromOffset(20,20) end
  on(b.MouseEnter,function()
   local p,a=palette()
   animate(b,{BackgroundColor3=p.field:Lerp(a,.3),BackgroundTransparency=.26},.18)
   if image then animate(image,{ImageColor3=a:Lerp(white,.65),Rotation=i==2 and 90 or 0},.24) end
  end)
  on(b.MouseLeave,function()
   local p=palette() animate(b,{BackgroundColor3=p.field,BackgroundTransparency=.8},.22)
   if image then animate(image,{ImageColor3=Color3.fromRGB(203,213,230),Rotation=0},.24) end
  end)
 end
 for _,x in ipairs({456,508}) do new('Frame',{Position=UDim2.fromOffset(x,14),Size=UDim2.fromOffset(1,16),BackgroundColor3=muted,BackgroundTransparency=.85,BorderSizePixel=0},dock) end
 local t=0
 on(RunService.RenderStepped,function(dt)
  if not state.open or state.reduce or not state.smooth then return end
  t+=math.min(dt,.05) rimLight.Rotation=14+math.sin(t*.23)*12
 end)
end

line(surface,0,68,1200)
local sidebar=new('Frame',{Name='Sidebar',BackgroundTransparency=.18,BorderSizePixel=0,Position=UDim2.fromOffset(0,69),Size=UDim2.fromOffset(240,551)},surface); bind(sidebar,'BackgroundColor3','side')
local sidebarDecor=new('Frame',{Name='HalloweenSidebar',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false,Visible=false},sidebar)
local sidebarPumpkin=decoration(sidebarDecor,'Pumpkin',HALLOWEEN_IMAGES.pumpkin,59,350,118,118,.05,8)
local sidebarWeb=decoration(sidebarDecor,'Cobweb',HALLOWEEN_IMAGES.web,-65,328,156,156,.62,155)
sidebarWeb.ImageColor3=Color3.fromRGB(191,151,225)
local halloweenMoon=decoration(halloweenLayer,'CrescentMoon',HALLOWEEN_IMAGES.moon,839,102,66,66,.1,-18)
local halloweenBat=decoration(halloweenLayer,'VelvetBat',HALLOWEEN_IMAGES.bat,1042,77,63,63,.06,-16)
local sidebarBat=decoration(sidebarDecor,'LittleBat',HALLOWEEN_IMAGES.bat,24,355,51,51,.22,-15)
local sidebarGhost=decoration(sidebarDecor,'LittleGhost',HALLOWEEN_IMAGES.ghost,156,385,48,48,.3,12)
-- Ambient color is native UI shading, not another hosted image.
local ambient=new('Frame',{Name='AutumnAmbient',BackgroundColor3=Color3.fromRGB(108,57,146),BackgroundTransparency=.88,BorderSizePixel=0,Position=UDim2.fromOffset(805,85),Size=UDim2.fromOffset(325,105)},halloweenLayer)
round(ambient,52)
new('UIGradient',{Rotation=12,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.15),NumberSequenceKeypoint.new(1,1)})},ambient)
ambient.ZIndex=0
local divider=new('Frame',{BorderSizePixel=0,Position=UDim2.fromOffset(240,69),Size=UDim2.fromOffset(1,551)},surface); bind(divider,'BackgroundColor3','line')
local navIndicator=new('Frame',{Name='CategoryIndicator',BackgroundTransparency=1,Position=UDim2.fromOffset(10,274),Size=UDim2.fromOffset(220,38),Active=false},sidebar)
local navIndicatorFill=panel(navIndicator,'Fill',0,0,220,38,'field',9)
navIndicatorFill.BackgroundTransparency=.06
new('UIGradient',{Rotation=0,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(246,250,255)),ColorSequenceKeypoint.new(.45,Color3.fromRGB(220,228,241)),ColorSequenceKeypoint.new(1,Color3.fromRGB(173,183,202))})},navIndicatorFill)
do
 for i,width in ipairs({7,3})do
  local halo=new('Frame',{Name='SoftSelectionGlow',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false},navIndicator)
  round(halo,10)
  local edge=stroke(halo,nil,i==1 and .97 or .91);edge.Thickness=width
  bind(edge,'Color','accent')
 end
 -- A narrow inner reflection gives the selection a soft raised edge.
 local shine=new('Frame',{BackgroundTransparency=1,Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),Active=false},navIndicator)
 round(shine,9)
 local edge=stroke(shine,Color3.fromRGB(208,222,245),.75)
 new('UIGradient',{Rotation=120,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(.5,.8),NumberSequenceKeypoint.new(1,1)})},edge)
end
local navIndicatorBar=new('Frame',{Position=UDim2.fromOffset(1,8),Size=UDim2.new(0,2,1,-16),BorderSizePixel=0},navIndicator)
round(navIndicatorBar,99)
new('UIGradient',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.7),NumberSequenceKeypoint.new(.15,.08),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.85,.08),NumberSequenceKeypoint.new(1,.7)})},navIndicatorBar)
bind(navIndicatorBar,'BackgroundColor3','accent')
local indicatorPage='Settings'
local navs={}
for i,name in ipairs({'Overview','Main','Summon','Auto Play','Event','Macro','Dungeon','Misc','Webhook','Settings'}) do
 local b=new('TextButton',{Name=name,Text='',AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(10,12+(i-1)*42),Size=UDim2.fromOffset(220,38),BorderSizePixel=0},sidebar); round(b,9)
 local s=stroke(b); s.Transparency=1; bind(s,'Color','line')
 local bar=new('Frame',{Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,3,1,0),BorderSizePixel=0,Visible=false},b); bind(bar,'BackgroundColor3','accent')
 local _,setIcon=icon(b,({Summon='Star',['Auto Play']='Play',Event='Calendar',Macro='MacroCode',Dungeon='Map',Misc='Utilities',Webhook='Send'})[name] or name,22,8,22,muted)
 local title=text(b,name=='Overview' and 'Home' or name,58,0,152,38,16,muted,false)
 navs[name]={button=b,title=title,icon=setIcon,bar=bar,stroke=s,hover=false}
end
line(sidebar,0,468,240)
local avatar=panel(sidebar,'Avatar',20,484,50,50,'field',9)
local avatarImage=new('ImageLabel',{Name='Headshot',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image='rbxthumb://type=AvatarHeadShot&id='..player.UserId..'&w=150&h=150'},avatar); round(avatarImage,8)
local online=new('Frame',{BackgroundColor3=Color3.fromRGB(82,211,133),BorderSizePixel=0,Position=UDim2.fromOffset(62,524),Size=UDim2.fromOffset(11,11)},sidebar); round(online,9); stroke(online,Color3.fromRGB(19,24,32),0)
local profileName=text(sidebar,player.DisplayName,85,487,130,24,14,white,true)
local profileHandle=text(sidebar,'@'..player.Name,85,511,130,21,11,muted)
local body=new('Frame',{Name='Body',BackgroundTransparency=1,Position=UDim2.fromOffset(266,92),Size=UDim2.fromOffset(908,507)},surface)
local heading=text(body,'Settings',10,0,860,45,36,white,true)
local subtitle=text(body,'Make it feel like yours.',10,48,860,29,18,muted)
local pages={}
local function page(name)
 local obj=new('ScrollingFrame',{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,66),Size=UDim2.fromOffset(908,441),Visible=false,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=3,ScrollBarImageColor3=muted,ClipsDescendants=true},body); pages[name]=obj; return obj
end
for _,name in ipairs({'Summon','Auto Play','Event','Macro','Dungeon','Misc','Webhook'}) do page(name) end
local settings=page('Settings')
settings.Active=true
settings.AutomaticCanvasSize=Enum.AutomaticSize.Y
settings.ScrollingDirection=Enum.ScrollingDirection.Y
local appearance=panel(settings,'Appearance',3,3,439,407,'card',10)
local interface=panel(settings,'Interface',459,3,430,407,'card',10)
appearance.BackgroundTransparency=.16; interface.BackgroundTransparency=.16
local _,_,appearanceParts=icon(appearance,'Appearance',23,23,30)
local _,_,interfaceParts=icon(interface,'Interface',23,23,30)
for _,parts in ipairs({appearanceParts,interfaceParts}) do for _,part in ipairs(parts) do bind(part,'ImageColor3','accent') end end
text(appearance,'Appearance',74,17,345,30,20,white,true)
text(appearance,'Customize the look and feel of the interface.',74,49,345,25,12,muted)
text(interface,'Interface',72,17,350,30,20,white,true)
text(interface,'Fine-tune interface behavior and preferences.',72,49,350,25,12,muted)
line(appearance,23,88,396); line(interface,23,88,400)
local searchable={}
local descriptions={}
local function description(parent,value,x,y,w)
 local obj=text(parent,value,x,y,w,23,12,muted); table.insert(descriptions,obj); return obj
end
local function register(name,obj,desc) table.insert(searchable,{name=string.lower(name),obj=obj,desc=desc}) end
local themeRow=new('Frame',{Name='ThemeRow',BackgroundTransparency=1,Position=UDim2.fromOffset(23,102),Size=UDim2.fromOffset(396,65)},appearance)
text(themeRow,'Theme',0,3,190,25,16,white,true)
description(themeRow,'Choose your atmosphere.',0,30,190)
local themeButton=control(themeRow,'ThemePicker',196,5,200,40)
local themeText=text(themeButton,state.theme=='Space' and 'Rose Eclipse' or state.theme,13,0,156,40,14)
icon(themeButton,'Chevron',176,12,16,muted)
register('theme atmosphere rose eclipse event horizon nebula violet stardust blue standard halloween',themeRow)
line(appearance,23,169,396)
local accentRow=new('Frame',{Name='AccentRow',BackgroundTransparency=1,Position=UDim2.fromOffset(23,182),Size=UDim2.fromOffset(396,105)},appearance)
text(accentRow,'Accent color',0,0,300,25,16,white,true)
description(accentRow,'Select the accent color used across the UI.',0,27,396)
local swatchButtons={}
for i=1,7 do
 local b=new('TextButton',{Name='Swatch'..i,Text='',AutoButtonColor=false,Position=UDim2.fromOffset((i-1)*49,60),Size=UDim2.fromOffset(34,34),BorderSizePixel=0},accentRow); round(b,7)
 if i==1 then bind(b,'BackgroundColor3',function(p) return themes[state.theme].accent end) else b.BackgroundColor3=swatches[i] end
 local ring=stroke(b); ring.Thickness=2; bind(ring,'Color','accent')
 local inset=new('UIPadding',{PaddingTop=UDim.new(0,0)},b)
 swatchButtons[i]={button=b,ring=ring}
end
register('accent color',accentRow)
line(appearance,23,294,396)
local scaleRow=new('Frame',{Name='ScaleRow',BackgroundTransparency=1,Position=UDim2.fromOffset(23,306),Size=UDim2.fromOffset(396,80)},appearance)
text(scaleRow,'UI scale',0,0,300,25,16,white,true)
description(scaleRow,'Adjust the size of interface elements.',0,26,396)
local sliderHit=new('TextButton',{Name='ScaleSlider',Text='',AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(0,53),Size=UDim2.fromOffset(304,25)},scaleRow)
local sliderTrack=new('Frame',{BorderSizePixel=0,Position=UDim2.fromOffset(0,10),Size=UDim2.fromOffset(304,6)},sliderHit); round(sliderTrack,8); bind(sliderTrack,'BackgroundColor3','line')
local sliderFill=new('Frame',{BorderSizePixel=0,Size=UDim2.fromScale(.714,1)},sliderTrack); round(sliderFill,8); bind(sliderFill,'BackgroundColor3','accent')
local sliderKnob=new('Frame',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.714,.5),Size=UDim2.fromOffset(20,20),BorderSizePixel=0},sliderTrack); round(sliderKnob,99); bind(sliderKnob,'BackgroundColor3','accent')
local scaleField=panel(scaleRow,'ScaleValue',326,53,70,27,'field',6)
local scaleLabel=text(scaleField,'100%',0,0,70,27,14); scaleLabel.TextXAlignment=Enum.TextXAlignment.Center
register('ui scale size',scaleRow)
local toggles={}
local interfaceScroll=new('ScrollingFrame',{Name='Controls',BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(23,102),Size=UDim2.fromOffset(400,214),CanvasSize=UDim2.fromOffset(0,542),ScrollBarThickness=3,ScrollBarImageColor3=muted,ClipsDescendants=true,ScrollingDirection=Enum.ScrollingDirection.Y},interface)
local function toggle(name,title,desc,y,key)
 local row=new('Frame',{Name=name,BackgroundTransparency=1,Position=UDim2.fromOffset(0,y),Size=UDim2.fromOffset(390,65)},interfaceScroll)
 text(row,title,0,0,304,25,16,white,true)
 description(row,desc,0,28,325)
 local b=new('TextButton',{Name='Toggle',Text='',AutoButtonColor=false,Position=UDim2.fromOffset(334,6),Size=UDim2.fromOffset(56,29),BorderSizePixel=0},row); round(b,99)
 local s=stroke(b); s.Transparency=.4
 local k=new('Frame',{Name='Knob',BorderSizePixel=0,BackgroundColor3=white,Position=UDim2.fromOffset(30,3),Size=UDim2.fromOffset(23,23)},b); round(k,99)
 toggles[key]={button=b,knob=k,stroke=s,row=row}
 register(title..' '..desc,row)
 return b
end
local smoothButton=toggle('SmoothAnimations','Smooth animations','Enable smooth transitions and animations.',156,'smooth')
line(interfaceScroll,0,72,390)
local reduceButton=toggle('ReduceMotion','Reduce motion','Minimize motion for a calmer experience.',234,'reduce')
line(interfaceScroll,0,150,390)
local tipsButton=toggle('ShowTooltips','Show tooltips','Show helpful descriptions when hovering.',312,'tips')
line(interfaceScroll,0,228,390)
local particleButton=toggle('StarParticles','Star particles','Show floating particles inside the window.',0,'stars')
line(interfaceScroll,0,306,390)
local hotkeyRow=new('Frame',{Name='WindowHotkey',BackgroundTransparency=1,Position=UDim2.fromOffset(0,78),Size=UDim2.fromOffset(390,65)},interfaceScroll)
text(hotkeyRow,'Minimize hotkey',0,0,225,25,16,white,true)
description(hotkeyRow,'Click to rebind. Esc cancels.',0,28,225)
local hotkeyButton=control(hotkeyRow,'BindKey',242,4,148,36)
local hotkeyText=text(hotkeyButton,keyName(hotkey),5,0,138,36,13)
hotkeyText.TextXAlignment=Enum.TextXAlignment.Center
register('minimize hotkey keyboard shortcut keybind',hotkeyRow)
line(interfaceScroll,0,384,390)
local iconButton=toggle('ShowFloatingIcon','Show floating icon','Show the restore button while minimized.',390,'showIcon')
line(interfaceScroll,0,462,390)
toggle('AnimatedBorder','Animated border','Theme-colored light around the window.',468,'border')
text(interface,'Scroll for motion and tooltip preferences',23,320,400,18,10,muted)
local save=new('TextButton',{Name='SavePreferences',Text='',AutoButtonColor=false,Position=UDim2.fromOffset(23,346),Size=UDim2.fromOffset(400,44),BorderSizePixel=0},interface); round(save,8)
bind(save,'BackgroundColor3','accent')
new('UIGradient',{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(209,226,255))},save)
icon(save,'Save',92,12,21,Color3.fromRGB(10,22,39))
local saveText=text(save,'Save preferences',126,0,248,44,16,Color3.fromRGB(10,22,39),true)
-- Floating menus are outside the content cards, so they cannot be clipped.
local menu=new('CanvasGroup',{Name='ThemeMenu',Position=UDim2.new(),Size=UDim2.fromOffset(228,276),GroupTransparency=1,Visible=false,ClipsDescendants=false,ZIndex=20,BorderSizePixel=0},surface)
round(menu,9);menu.BackgroundTransparency=1
-- Keep the border inside the fading group so it cannot linger on its own.
do local backing=panel(menu,'Surface',3,3,222,270,'field',8);backing.ZIndex=20;backing:FindFirstChildOfClass('UIStroke').Thickness=1.5 end
local dropdown={open=false,revision=0,tween=nil,position=UDim2.new()}
function dropdown.place()
 local x=(themeButton.AbsolutePosition.X-surface.AbsolutePosition.X)/uiScale.Scale-34
 local y=(themeButton.AbsolutePosition.Y-surface.AbsolutePosition.Y)/uiScale.Scale+46
 if y+276>1040-12 then y=(themeButton.AbsolutePosition.Y-surface.AbsolutePosition.Y)/uiScale.Scale-282 end
 dropdown.position=UDim2.fromOffset(math.clamp(x,8,724),y)
end
function dropdown.set(value,instant)
 dropdown.revision+=1;local revision=dropdown.revision
 dropdown.open=value
 if dropdown.tween then dropdown.tween:Cancel();dropdown.tween=nil end
 dropdown.place()
 local duration=not instant and state.smooth and not state.reduce and .22 or 0
 local arrow=themeButton:FindFirstChild('Icon_Chevron')
 if arrow then animate(arrow,{Rotation=value and 180 or 0},duration) end
 -- Keep the render target at its final dimensions: no resizing text or corners.
 menu.Size=UDim2.fromOffset(228,276)
 if value and not menu.Visible then
  menu.GroupTransparency=1
  menu.Position=dropdown.position-UDim2.fromOffset(0,7)
 end
 if value then menu.Visible=true end
 local goal={GroupTransparency=value and 0 or 1,Position=value and dropdown.position or dropdown.position-UDim2.fromOffset(0,5)}
 if duration==0 or not menu.Visible then
  for k,v in pairs(goal)do menu[k]=v end
  menu.Visible=value
 else
  dropdown.tween=TweenService:Create(menu,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),goal)
  dropdown.tween.Completed:Once(function(playback)
   if dead or revision~=dropdown.revision or playback~=Enum.PlaybackState.Completed then return end
   if not dropdown.open then menu.Visible=false end
   dropdown.tween=nil
  end)
  dropdown.tween:Play()
 end
end

local menuItems={}
for i,name in ipairs({'Space','Event Horizon','Nebula Violet','Stardust Blue','Standard','Halloween'}) do
 local b=new('TextButton',{Name=name,Text=name=='Space' and 'Rose Eclipse' or name,Font=Enum.Font.GothamMedium,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=white,BackgroundTransparency=1,AutoButtonColor=false,Position=UDim2.fromOffset(8,8+(i-1)*44),Size=UDim2.fromOffset(212,40),ZIndex=21},menu); round(b,6)
 new('UIPadding',{PaddingLeft=UDim.new(0,12)},b); menuItems[name]=b
end
local function extraPage(name,title,subtitleText)
 local p=page(name)
 local c=panel(p,name..'Card',0,0,908,260,'card',10); c.BackgroundTransparency=.15
 local _,_,parts=icon(c,name,28,28,32)
 for _,part in ipairs(parts) do bind(part,'ImageColor3','accent') end
 text(c,title,82,24,780,36,24,white,true)
 text(c,subtitleText,28,91,850,34,16,muted)
 line(c,28,146,850)
 return c
end
local overview=page('Overview')
local shortcutHint=text(overview,keyName(hotkey)..' to hide or show  ·  Drag the top bar to move',8,402,892,18,10,muted)
do
 local identity=panel(overview,'PlayerProfile',8,8,892,88,'card',10)
 identity.BackgroundTransparency=.12
 local avatarBox=panel(identity,'Portrait',14,9,70,70,'field',10)
 local portrait=new('ImageLabel',{Name='Image',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image='rbxthumb://type=AvatarHeadShot&id='..player.UserId..'&w=180&h=180'},avatarBox)
 round(portrait,9)
 text(identity,player.DisplayName,104,12,280,30,20,white,true)
 text(identity,'@'..player.Name,104,44,280,24,13,muted)
 text(identity,'USER ID',416,17,190,18,10,muted,true)
 text(identity,tostring(player.UserId),416,40,190,27,15,white)
 new('Frame',{Position=UDim2.fromOffset(393,22),Size=UDim2.fromOffset(1,44),BackgroundColor3=muted,BackgroundTransparency=.7,BorderSizePixel=0},identity)
 new('Frame',{Position=UDim2.fromOffset(641,22),Size=UDim2.fromOffset(1,44),BackgroundColor3=muted,BackgroundTransparency=.7,BorderSizePixel=0},identity)
 local _,_,parts=icon(identity,'Player',668,30,26,muted)
 for _,part in ipairs(parts)do bind(part,'ImageColor3','accent')end
 text(identity,'CHARACTER',710,17,180,18,10,muted,true)
 local characterStatus=text(identity,'Ready',710,40,180,27,14,Color3.fromRGB(99,220,160))
 local function updateCharacter(character)
  characterStatus.Text=character and 'Spawned' or 'Respawning'
  characterStatus.TextColor3=character and Color3.fromRGB(99,220,160) or muted
  portrait.Image='rbxthumb://type=AvatarHeadShot&id='..player.UserId..'&w=180&h=180'
 end
 updateCharacter(player.Character)
 on(player.CharacterAdded,updateCharacter)
 on(player.CharacterRemoving,function()updateCharacter(nil)end)

 local map=panel(overview,'CurrentMap',8,112,624,278,'card',10)
 map.BackgroundTransparency=.12
 text(map,'Current Map',18,10,590,28,16,white,true)
 local thumbnailMask=new('CanvasGroup',{Name='Thumbnail',Position=UDim2.fromOffset(16,48),Size=UDim2.fromOffset(592,158),BackgroundColor3=Color3.fromRGB(12,16,24),BorderSizePixel=0,ClipsDescendants=true},map)
 round(thumbnailMask,9)
 local fallback=text(thumbnailMask,'Loading experience image…',16,60,566,34,13,muted)
 fallback.TextXAlignment=Enum.TextXAlignment.Center
 local mapImage=new('ImageLabel',{Name='Image',Image='rbxthumb://type=GameThumbnail&id='..game.PlaceId..'&w=768&h=432',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Crop},thumbnailMask)
 local mapName=text(map,'Loading experience…',18,213,412,27,18,white,true)
 mapName.Name='ExperienceName'
 text(map,'Current experience',18,244,400,18,12,muted)
 text(map,'PLACE ID',451,216,160,16,9,muted,true)
 text(map,tostring(game.PlaceId),451,238,160,23,12,white)
 task.spawn(function()
  -- A world/server is a Place; the parent experience is identified by GameId.
  -- Resolve the parent rather than showing a sub-place's title.
  local universeId=game.GameId
  local cacheKey='ExperienceName_'..tostring(universeId)
  local rootKey='ExperienceRoot_'..tostring(universeId)
  local cached=store:GetAttribute(cacheKey)
  if type(cached)=='string' and cached~='' then mapName.Text=cached end
  local function readExperience()
   local url='https://games.roblox.com/v1/games?universeIds='..tostring(universeId)
   local ok,body=pcall(function()return game:HttpGet(url)end)
   if not ok then
    local send=request or http_request
    if type(send)~='function' and type(syn)=='table' then send=syn.request end
    if type(send)~='function' then error('Experience metadata request unavailable')end
    local response=send({Url=url,Method='GET'})
    assert(response and response.StatusCode==200,'Experience metadata request failed')
    body=response.Body
   end
   local decoded=game:GetService('HttpService'):JSONDecode(body)
   local entry=decoded.data and decoded.data[1]
   assert(entry and tonumber(entry.id)==universeId and type(entry.name)=='string' and entry.name~='','Invalid experience metadata')
   return entry.name,tonumber(entry.rootPlaceId) or (type(entry.rootPlace)=='table' and tonumber(entry.rootPlace.id))
  end
  local ok,name,rootPlace=pcall(readExperience)
  if dead then return end
  if ok then
   mapName.Text=name
   store:SetAttribute(cacheKey,name)
   if rootPlace and rootPlace>0 then store:SetAttribute(rootKey,rootPlace)end
  elseif type(cached)=='string' and cached~='' then
   mapName.Text=cached
  else
   -- Never substitute a world title for the parent game's title.
   mapName.Text='Experience '..tostring(universeId)
  end
  local rootId=rootPlace or store:GetAttribute(rootKey)
  if type(rootId)=='number' and rootId>0 then
   mapImage.Image='rbxthumb://type=GameThumbnail&id='..rootId..'&w=768&h=432'
  end
  map:SetAttribute('UniverseId',universeId)
  map:SetAttribute('RootPlaceId',rootId)
 end)

 task.spawn(function()
  local started=os.clock()
  while not dead and not mapImage.IsLoaded and os.clock()-started<8 do task.wait(.2)end
  if dead then return end
  if not mapImage.IsLoaded then
   mapImage.Image='rbxthumb://type=GameIcon&id='..game.GameId..'&w=512&h=512'
   fallback.Text='Experience thumbnail unavailable'
  end
 end)

 for i,info in ipairs({{'FPSCard','FPS',7733799969},{'PingCard','PING',8997387546}})do
  local stat=panel(overview,info[1],648,112+(i-1)*147,252,131,'card',10)
  stat.BackgroundTransparency=.10
  local disc=panel(stat,'Badge',18,15,40,40,'field',20)
  local image=new('ImageLabel',{Image='rbxassetid://'..info[3],Size=UDim2.fromOffset(24,24),Position=UDim2.fromOffset(8,8),BackgroundTransparency=1},disc)
  bind(image,'ImageColor3','accent');table.insert(iconImages,image)
  text(stat,info[2],72,19,165,28,13,muted,true)
  local value=text(stat,'—',20,58,219,43,32,white,true);value.Name='Value'
  local dot=new('Frame',{Name='StatusDot',Position=UDim2.fromOffset(21,112),Size=UDim2.fromOffset(7,7),BackgroundColor3=muted,BorderSizePixel=0},stat);round(dot,9)
  local status=text(stat,'Measuring…',36,102,199,25,12,muted);status.Name='Status'
 end
end

local mainPage=page('Main')
local visuals=page('Visuals')
local utilities=page('Utilities')
local resetButton=control(interfaceScroll,'ResetPreferences',0,550,390,40);interfaceScroll.CanvasSize=UDim2.fromOffset(0,604)
text(resetButton,'Reset settings',16,0,358,40,15)
local toast=panel(surface,'Toast',836,565,337,38,'field',8); toast.Visible=false; toast.ZIndex=30
local toastText=text(toast,'Preferences saved for this session.',14,0,310,38,12); toastText.ZIndex=31
local toastId=0
local function notify(message)
 toastId+=1; local id=toastId; toastText.Text=message; toast.Visible=true
 task.delay(3,function() if not dead and id==toastId then toast.Visible=false end end)
end
local viewport=Vector2.zero
-- Preserve the same horizontal, two-column composition on every display.
-- The desktop size is capped; smaller viewports proportionally scale to fit.
local function fit()
 local camera=workspace.CurrentCamera
 if not camera then return end
 viewport=camera.ViewportSize
 local topInset,bottomInset=game:GetService('GuiService'):GetGuiInset()
 local safe=viewport-topInset-bottomInset
 local preferredWidth=math.min(960,safe.X*.94)
 local baseScale=math.min(preferredWidth/960,safe.Y*.92/1040)
 local fitScale=math.min(math.max(1,safe.X-28)/960,math.max(1,safe.Y-28)/1040)
 local mobile=game:GetService('UserInputService').TouchEnabled
 local target=baseScale*state.scale/100
 local height=1040
 if mobile then
  -- Increase control size while shortening the scroll viewport to fit vertically.
  target=math.max(.01,math.min(target,math.max(1,safe.Y-28)/480,math.max(1,safe.X-28)/960))
  height=math.clamp(math.max(1,safe.Y-28)/target,480,1040)
 end
 uiScale.Scale=mobile and target or math.min(target,fitScale)
 root.Size=UDim2.fromOffset(960,height)
 canvas.Size=UDim2.fromOffset(960,height)
 surface.Size=UDim2.fromOffset(960,height)
 local crisp=canvas:FindFirstChild('CrispContent')
 if crisp then crisp.Size=UDim2.fromOffset(960,height)end
 body.Size=UDim2.fromOffset(908,math.max(100,height-body.Position.Y.Offset-16))
 for _,p in pairs(pages)do
  p.Size=UDim2.fromOffset(908,math.max(80,body.Size.Y.Offset-p.Position.Y.Offset))
  p.ScrollingEnabled=true
  p.Active=true
 end
 for _,p in pairs(pages) do p.ClipsDescendants=true end
 if dropdown.open then dropdown.set(false,true) end
end
local function refreshNav()
 local p,a=palette()
 local destination=navs[state.page]
 if destination and destination.button.Parent==navIndicator.Parent and indicatorPage~=state.page then
  indicatorPage=state.page
  animate(navIndicator,{Position=destination.button.Position},.26)
 end
 navIndicator.Visible=destination~=nil and destination.button.Parent==navIndicator.Parent;navIndicatorFill.BackgroundColor3=p.field:Lerp(a,.26)
 for name,n in pairs(navs) do
  local selected=name==state.page
  animate(n.button,{BackgroundColor3=p.field,BackgroundTransparency=not selected and n.hover and .6 or 1},.15)
  animate(n.title,{TextColor3=selected and white or muted},.18)
  n.title.Font=selected and Enum.Font.GothamMedium or Enum.Font.Gotham
  n.icon(selected and a or Color3.fromRGB(196,207,224))
  n.bar.Visible=false;n.stroke.Transparency=selected and .25 or .65
 end
end
local function refreshToggles()
 for key,value in pairs({Smooth=state.smooth,ReduceMotion=state.reduce,Tooltips=state.tips,Stars=state.stars,ShowIcon=state.showIcon,AnimatedBorder=state.border}) do store:SetAttribute(key,value) end
 local p,a=palette()
 for key,t in pairs(toggles) do
  animate(t.button,{BackgroundColor3=state[key] and a or p.field})
  animate(t.knob,{Position=UDim2.fromOffset(state[key] and 30 or 3,3)})
  t.stroke.Color=state[key] and a or muted
 end
end
local function refresh()
 for key,value in pairs({Theme=state.theme,Accent=state.accent,Scale=state.scale,Smooth=state.smooth,ReduceMotion=state.reduce,Tooltips=state.tips,Stars=state.stars,ShowIcon=state.showIcon,AnimatedBorder=state.border,Hotkey=hotkey.Name}) do store:SetAttribute(key,value) end
 local p,a=palette()
 -- Publish a complete palette atomically, rather than sampling animated controls.
 for _,role in ipairs({'card','field','line'})do gui:SetAttribute('Palette_'..role,p[role])end
 gui:SetAttribute('Palette_accent',a)
 gui:SetAttribute('PaletteRevision',(gui:GetAttribute('PaletteRevision')or 0)+1)
 for _,scroll in ipairs(gui:QueryDescendants('ScrollingFrame'))do scroll.ScrollBarImageColor3=a end
 for _,b in ipairs(bindings) do
  if activeTweens[b.obj] then activeTweens[b.obj]:Cancel();activeTweens[b.obj]=nil end
  b.obj[b.property]=type(b.role)=='function' and b.role(p,a) or (b.role=='accent' and a or p[b.role])
 end
 -- Swatch 1 always previews the theme's default accent.
 swatchButtons[1].button.BackgroundColor3=themes[state.theme].accent
 for i,s in ipairs(swatchButtons) do s.ring.Transparency=i==state.accent and 0 or 1 end
 themeText.Text=state.theme=='Space' and 'Rose Eclipse' or state.theme
 spaceArt.image.ImageColor3=a:Lerp(white,.2);if spaceArt.applyHeader then spaceArt.applyHeader(state.theme)end
 brand.TextColor3=a:Lerp(white,.70)
 local signature=header:FindFirstChild('RoseSignature')
 if signature then signature.TextColor3=a:Lerp(white,.5)end
 spaceArt.group.Visible=(state.theme=='Space' or state.theme=='Event Horizon' or state.theme=='Nebula Violet' or state.theme=='Stardust Blue')
 appearance.BackgroundTransparency=state.theme=='Standard' and 0 or ((state.theme=='Space' or state.theme=='Event Horizon' or state.theme=='Nebula Violet' or state.theme=='Stardust Blue') and .06 or .10)
 interface.BackgroundTransparency=state.theme=='Standard' and 0 or ((state.theme=='Space' or state.theme=='Event Horizon' or state.theme=='Nebula Violet' or state.theme=='Stardust Blue') and .06 or .10)
 sidebar.BackgroundTransparency=state.theme=='Standard' and 0 or ((state.theme=='Space' or state.theme=='Event Horizon' or state.theme=='Nebula Violet' or state.theme=='Stardust Blue') and .02 or .08)
 starLayer.Visible=state.stars
 if launcher then launcher.Visible=not state.open and state.showIcon end
 halloweenLayer.Visible=state.theme=='Halloween'
 sidebarDecor.Visible=state.theme=='Halloween'
 refreshNav(); refreshToggles()
 local alpha=(state.scale-75)/(scaleMaximum-75)
 sliderFill.Size=UDim2.fromScale(alpha,1); sliderKnob.Position=UDim2.fromScale(alpha,.5)
 scaleLabel.Text=tostring(state.scale)..'%'
 fit()
end
local subtitles={Settings='Make it feel like yours.',Overview='Your session, at a glance.',Main='Add your own controls here.',Visuals='Customize your visual controls.',Utilities='Add your own tools here.'}
local function selectPage(name)
 capturingKey=false; hotkeyText.Text=keyName(hotkey)
 dropdown.set(false,true); state.page=name
 if name=='Event' then
  local eventPage=pages[name]
  local navigation=game:GetService('GuiService')
  local selected=navigation.SelectedObject
  if selected and selected:IsDescendantOf(eventPage) then navigation.SelectedObject=nil end
  eventPage.CanvasPosition=Vector2.zero
  task.defer(function()if state.page=='Event' then eventPage.CanvasPosition=Vector2.zero end end)
 end
 for key,p in pairs(pages) do p.Visible=key==name end
 heading.Text=name=='Overview' and 'Home' or name=='Event'and'Summer'or name;heading.Visible=name~='Auto Play';subtitle.Text='';subtitle.Visible=false;pages[name].Position=UDim2.fromOffset(0,name=='Auto Play'and 0 or 66)
 search.PlaceholderText=name=='Settings' and 'Search settings...' or 'Search pages...'
 search.Text=''
 refreshNav()
 if state.smooth and not state.reduce then
  pages[name].Position=UDim2.fromOffset(8,name=='Auto Play'and 0 or 66)
  animate(pages[name],{Position=UDim2.fromOffset(0,name=='Auto Play'and 0 or 66)},.25)
 end
end
for name,n in pairs(navs) do
 on(n.button.Activated,function() selectPage(name) end)
 on(n.button.MouseEnter,function() n.hover=true; refreshNav() end)
 on(n.button.MouseLeave,function() n.hover=false; refreshNav() end)
end
for i,s in ipairs(swatchButtons) do on(s.button.Activated,function() state.accent=i; refresh() end) end
for name,b in pairs(menuItems) do
 on(b.Activated,function() state.theme=name; state.accent=1; dropdown.set(false); refresh() end)
 on(b.MouseEnter,function() b.BackgroundTransparency=.3; local p=palette(); b.BackgroundColor3=p.card end)
 on(b.MouseLeave,function() b.BackgroundTransparency=1 end)
end
on(themeButton.Activated,function()
 dropdown.set(not dropdown.open)
end)
for key,t in pairs(toggles) do
 on(t.button.Activated,function()
  state[key]=not state[key]
  if key=='stars' then starLayer.Visible=state.stars end
  if key=='showIcon' and launcher then launcher.Visible=not state.open and state.showIcon end
  refreshToggles()
 end)
end

on(resetButton.Activated,function()
 state.theme='Standard'; state.accent=1; state.scale=100; state.smooth=true; state.reduce=false; state.tips=true; state.stars=true; state.showIcon=true; state.border=true
 hotkey=Enum.KeyCode.RightShift; capturingKey=false
 hotkeyText.Text=keyName(hotkey)
 shortcutHint.Text=keyName(hotkey)..' to hide or show  ·  Drag the top bar to move'
 refresh(); root.Position=UDim2.fromScale(.5,.5); notify('Appearance settings reset.')
end)
on(save.Activated,function()
 for key,value in pairs({Theme=state.theme,Accent=state.accent,Scale=state.scale,Smooth=state.smooth,ReduceMotion=state.reduce,Tooltips=state.tips,Stars=state.stars,ShowIcon=state.showIcon,AnimatedBorder=state.border,Hotkey=hotkey.Name}) do store:SetAttribute(key,value) end
 saveText.Text='Preferences saved'
 notify('Preferences saved for this session.')
 task.delay(1.8,function() if not dead then saveText.Text='Save preferences' end end)
end)
on(save.MouseEnter,function() local _,a=palette(); animate(save,{BackgroundColor3=a:Lerp(white,.12)}) end)
on(save.MouseLeave,function() local _,a=palette(); animate(save,{BackgroundColor3=a}) end)
do
local slideInput,dragInput,dragStart,startPosition
local dragTarget=Vector2.zero
local dragSettling=false
local dragViewport=gui.AbsoluteSize
local function windowCenter()
 local size=gui.AbsoluteSize
 return Vector2.new(root.Position.X.Scale*size.X+root.Position.X.Offset,root.Position.Y.Scale*size.Y+root.Position.Y.Offset)
end
local function clampPosition(pos)
 local half=root.AbsoluteSize/2
 local size=gui.AbsoluteSize
 if scaleMaximum>110 and (half.X*2>size.X or half.Y*2>size.Y)then
  -- Let a touch user reach either side of an oversized window.
  local function axis(value,extent,screen)
   if extent*2>screen then return math.clamp(value,screen-extent-14,extent+14)end
   return math.clamp(value,extent,math.max(extent,screen-extent))
  end
  return Vector2.new(axis(pos.X,half.X,size.X),axis(pos.Y,half.Y,size.Y))
 end
 local x=math.clamp(pos.X,half.X,math.max(half.X,size.X-half.X))
 local y=math.clamp(pos.Y,half.Y,math.max(half.Y,size.Y-half.Y))
 if x-half.X<14 then x=half.X elseif size.X-half.X-x<14 then x=size.X-half.X end
 if y-half.Y<14 then y=half.Y elseif size.Y-half.Y-y<14 then y=size.Y-half.Y end
 return Vector2.new(x,y)
end
local function updateSlider(x)
 local alpha=math.clamp((x-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X,0,1)
 state.scale=math.floor(75+alpha*(scaleMaximum-75)+.5); store:SetAttribute('Scale',state.scale)
 sliderFill.Size=UDim2.fromScale(alpha,1); sliderKnob.Position=UDim2.fromScale(alpha,.5)
 scaleLabel.Text=state.scale..'%'; fit()
end
on(sliderHit.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then slideInput=input; updateSlider(input.Position.X) end
end)
local function beginWindowDrag(input)
 if not state.open then return end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 dragInput=input
 dragStart=Vector2.new(input.Position.X,input.Position.Y)
 startPosition=windowCenter()
 dragTarget=startPosition
 dragSettling=true
end
on(dragHandle.InputBegan,beginWindowDrag)
-- Narrow edge handles never cover buttons or other controls.
for _,edge in ipairs({
 {'DragLeft',UDim2.new(),UDim2.new(0,7,1,0)},
 {'DragRight',UDim2.new(1,-7,0,0),UDim2.new(0,7,1,0)},
 {'DragTop',UDim2.new(),UDim2.new(1,0,0,7)},
 {'DragBottom',UDim2.new(0,0,1,-7),UDim2.new(1,0,0,7)},
})do
 local handle=new('Frame',{Name=edge[1],Position=edge[2],Size=edge[3],BackgroundTransparency=1,Active=true,ZIndex=40},root)
 on(handle.InputBegan,beginWindowDrag)
end
on(Input.InputChanged,function(input)
 local mouse=input.UserInputType==Enum.UserInputType.MouseMovement
 if slideInput and (input==slideInput or mouse and slideInput.UserInputType==Enum.UserInputType.MouseButton1) then updateSlider(input.Position.X) end
 if dragInput and (input==dragInput or mouse and dragInput.UserInputType==Enum.UserInputType.MouseButton1) then
  local delta=Vector2.new(input.Position.X,input.Position.Y)-dragStart
  dragTarget=clampPosition(startPosition+delta)
 end
end)
on(RunService.RenderStepped,function(dt)
 if gui.AbsoluteSize~=dragViewport then dragViewport=gui.AbsoluteSize;dragInput=nil;dragSettling=false end
 if not state.open then dragInput=nil;dragSettling=false;return end
 if not dragSettling then return end
 local current=windowCenter()
 local difference=(current-dragTarget).Magnitude
 if difference<.03 then root.Position=UDim2.fromOffset(dragTarget.X,dragTarget.Y)
  if not dragInput then dragSettling=false end
  return
 end
 local pos
 if state.reduce or not state.smooth then pos=dragTarget
 else pos=current:Lerp(dragTarget,1-math.exp(-45*math.min(dt,.1))) end
 root.Position=UDim2.fromOffset(pos.X,pos.Y)
end)
on(Input.InputEnded,function(input)
 if input==slideInput then slideInput=nil end
 if dragInput and (input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 and dragInput.UserInputType==Enum.UserInputType.MouseButton1) then dragInput=nil end
end)
on(Input.WindowFocusReleased,function() dragInput=nil;dragSettling=false;slideInput=nil end)

end
launcher=new('ImageButton',{Name='OpenObsidian',Position=UDim2.fromOffset(18,16),Size=UDim2.fromOffset(56,56),BackgroundColor3=Color3.fromRGB(8,10,15),BorderSizePixel=0,AutoButtonColor=false,Image=LAUNCHER_IMAGE,ImageColor3=Color3.new(1,1,1),ScaleType=Enum.ScaleType.Fit,Visible=false,ClipsDescendants=true,Active=true},gui)
round(launcher,13)
local floating={}
local hoverScale=new('UIScale',{Scale=1},launcher)
launcher.Image=''
launcher.BackgroundTransparency=1
floating.launcherVisual=new('CanvasGroup',{Name='BlackHoleVisual',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},launcher)
launcher.Size=UDim2.fromOffset(68,68)
launcher.Position=UDim2.fromOffset(math.floor(math.max(0,gui.AbsoluteSize.X-68)/2),8)
floating.asset=loadRemoteImage('FyrelithBlackHole.v1.png')
floating.glow=new('ImageLabel',{Name='AccretionGlow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.08,1.08),BackgroundTransparency=1,Image=floating.asset,ImageTransparency=.78,ImageColor3=Color3.fromRGB(181,160,255),ScaleType=Enum.ScaleType.Fit},floating.launcherVisual)
floating.lensPulse=new('Frame',{Name='LensPulse',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(22,22),BackgroundTransparency=1},floating.launcherVisual) round(floating.lensPulse,40)
floating.pulseEdge=stroke(floating.lensPulse,Color3.fromRGB(211,196,255),1) floating.pulseEdge.Thickness=1
floating.planet=new('ImageLabel',{Name='EventHorizon',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=floating.asset,ScaleType=Enum.ScaleType.Fit},floating.launcherVisual)
local iconAura=new('Frame',{Name='LauncherAura',BackgroundTransparency=1,Visible=false,Active=false,ZIndex=0},gui)
local auraStrokes,auraGradients={},{}
floating.energy=new('NumberValue',{Name='HoverEnergy',Value=0},launcher)
floating.flowLight=new('UIGradient',{Rotation=20,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(191,185,230)),ColorSequenceKeypoint.new(.42,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.62,Color3.fromRGB(222,215,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(174,176,215))})},floating.planet)
floating.dust={}
for i=1,7 do
 local trail={}
 for j=1,3 do
  local dot=new('Frame',{Name='InfallDust',AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(j==1 and 1.6 or 1,j==1 and 1.6 or 1),BackgroundColor3=i%2==0 and Color3.fromRGB(213,195,255) or Color3.fromRGB(228,234,255),BackgroundTransparency=1,BorderSizePixel=0},floating.launcherVisual) round(dot,3)
  trail[j]=dot
 end
 floating.dust[i]=trail
end
local hovered=false
local hoverRevision=0
local hoverCard=new('CanvasGroup',{Name='PerformanceHover',BackgroundTransparency=1,Size=UDim2.fromOffset(320,76),GroupTransparency=1,Visible=false,ZIndex=80,Active=false},gui)
local hoverCardScale=new('UIScale',{Scale=.97},hoverCard)
-- Minimal Luxe: actual translucent surfaces, sharp live type, restrained silver edges.
for i=3,1,-1 do
 local shadow=new('Frame',{Name='SoftShadow',Position=UDim2.fromOffset(6-i,12+i),Size=UDim2.fromOffset(308+i*2,56),BackgroundColor3=Color3.new(),BackgroundTransparency=.95,BorderSizePixel=0},hoverCard) round(shadow,30)
end
local perfPanel=new('Frame',{Name='Panel',BackgroundColor3=Color3.fromRGB(10,11,16),BackgroundTransparency=.20,BorderSizePixel=0,Position=UDim2.fromOffset(6,8),Size=UDim2.fromOffset(308,56)},hoverCard) round(perfPanel,28)
new('UIGradient',{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(151,155,177))},perfPanel)
floating.luxeEdge=stroke(perfPanel,white,.30)
floating.edgeLight=new('UIGradient',{Rotation=15,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(89,93,111)),ColorSequenceKeypoint.new(.35,Color3.fromRGB(232,235,249)),ColorSequenceKeypoint.new(.53,Color3.fromRGB(176,151,251)),ColorSequenceKeypoint.new(.72,Color3.fromRGB(117,122,150)),ColorSequenceKeypoint.new(1,Color3.fromRGB(52,56,71))})},floating.luxeEdge)
floating.inner=new('Frame',{Name='InsetEdge',Position=UDim2.fromOffset(2,2),Size=UDim2.new(1,-4,1,-4),BackgroundTransparency=1,BorderSizePixel=0},perfPanel) round(floating.inner,27) stroke(floating.inner,Color3.fromRGB(159,164,190),.88)
floating.glassGlow=new('Frame',{Name='AmbientEdge',Position=UDim2.fromOffset(-1,-1),Size=UDim2.new(1,2,1,2),BackgroundTransparency=1,BorderSizePixel=0},perfPanel) round(floating.glassGlow,30)
floating.haloEdge=stroke(floating.glassGlow,Color3.fromRGB(167,148,226),.94) floating.haloEdge.Thickness=4
floating.brand=text(perfPanel,'FYRELITH',17,0,82,56,13,white,true) floating.brand.TextSize=13
floating.liveDot=new('Frame',{Name='Live',Position=UDim2.fromOffset(107,25),Size=UDim2.fromOffset(6,6),BackgroundColor3=Color3.fromRGB(100,229,167),BorderSizePixel=0},perfPanel) round(floating.liveDot,6)
for _,x in ipairs({125,202}) do
 local line=new('Frame',{Position=UDim2.fromOffset(x,17),Size=UDim2.fromOffset(1,22),BackgroundColor3=Color3.fromRGB(171,176,199),BackgroundTransparency=.67,BorderSizePixel=0},perfPanel)
 new('UIGradient',{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})},line)
end
floating.fpsLabel=text(perfPanel,'FPS',136,0,25,56,10,muted) floating.fpsLabel.TextSize=10
local fpsValue=text(perfPanel,'—',165,0,34,56,16,white,true) fpsValue.Name='FPS' fpsValue.TextSize=16
floating.pingLabel=text(perfPanel,'PING',212,0,28,56,10,muted) floating.pingLabel.TextSize=10
local pingValue=text(perfPanel,'—',244,0,55,56,16,white,true) pingValue.Name='Ping' pingValue.TextSize=16
for _,value in ipairs({fpsValue,pingValue}) do
 value.TextScaled=true
 new('UITextSizeConstraint',{MinTextSize=11,MaxTextSize=16},value)
end
for _,item in ipairs(perfPanel:QueryDescendants('TextLabel')) do
 item.TextYAlignment=Enum.TextYAlignment.Center
 item.Font=item==floating.brand and Enum.Font.GothamBold or Enum.Font.GothamMedium
end
local perfParticles=new('Frame',{Name='LuxeEffects',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true},perfPanel) round(perfParticles,28)
floating.sweep=new('Frame',{Name='LightSweep',Size=UDim2.fromOffset(42,80),Position=UDim2.fromOffset(-70,-12),Rotation=18,BackgroundColor3=Color3.fromRGB(208,219,255),BackgroundTransparency=.975,BorderSizePixel=0},perfParticles)
new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)})},floating.sweep)
floating.topGlint=new('Frame',{Name='TopGlint',Position=UDim2.fromOffset(40,0),Size=UDim2.fromOffset(75,1),BackgroundColor3=Color3.fromRGB(222,213,255),BackgroundTransparency=.18,BorderSizePixel=0},perfParticles)
new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.05),NumberSequenceKeypoint.new(1,1)})},floating.topGlint)
floating.statusSpark={}
local perfDots={}
local function positionHover()
 local bounds=gui.AbsoluteSize
 floating.hoverFit=math.min(1,math.max(.25,(bounds.X-8)/320))
 local w,h=320*floating.hoverFit,76*floating.hoverFit
 local x=launcher.Position.X.Offset+launcher.AbsoluteSize.X+6
 floating.opensLeft=x+w>bounds.X-4
 if floating.opensLeft then x=launcher.Position.X.Offset-w-6 end
 local y=launcher.Position.Y.Offset+launcher.AbsoluteSize.Y/2-h/2
 hoverCard.Position=UDim2.fromOffset(math.clamp(x,4,math.max(4,bounds.X-w-4)),math.clamp(y,4,math.max(4,bounds.Y-h-4)))
end

local function hidePerformance()
 hovered=false;hoverRevision+=1;local revision=hoverRevision
 animate(floating.energy,{Value=0},.3)
 for _,edge in ipairs(auraStrokes)do animate(edge,{Transparency=1},.2) end
 animate(hoverScale,{Scale=1},.16)
 animate(hoverCard,{GroupTransparency=1},.16)
 animate(hoverCardScale,{Scale=(floating.hoverFit or 1)*.97},.16)
 task.delay(state.smooth and not state.reduce and .16 or 0,function()
  if not dead and revision==hoverRevision then hoverCard.Visible=false end
 end)
end
on(launcher.MouseEnter,function()
 if state.open or launcher:GetAttribute('Dragging') then return end
 hovered=true;hoverRevision+=1
 animate(floating.energy,{Value=1},.32)
 positionHover();hoverCard.Visible=true
 perfPanel.Position=UDim2.fromOffset(floating.opensLeft and 12 or 0,8) animate(perfPanel,{Position=UDim2.fromOffset(6,8)},.26)
 iconAura.Visible=true
 for i,edge in ipairs(auraStrokes)do animate(edge,{Transparency=({.94,.84,.25})[i]},.22) end
 animate(hoverScale,{Scale=1.055},.2)
 animate(hoverCard,{GroupTransparency=0},.22)
 animate(hoverCardScale,{Scale=floating.hoverFit or 1},.26)
end)
on(launcher.MouseLeave,hidePerformance)
on(launcher.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
    animate(hoverScale,{Scale=.97},.1)
  floating.lensPulse.Size=UDim2.fromOffset(22,22) floating.pulseEdge.Transparency=.35
  animate(floating.lensPulse,{Size=UDim2.fromOffset(62,62)},.36)
  animate(floating.pulseEdge,{Transparency=1},.36)
 end
end)
on(Input.InputEnded,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  animate(hoverScale,{Scale=hovered and 1.055 or 1},.18)
 end
end)
local frameCount,frameSeconds=0,0
local perfClock=0
on(RunService.RenderStepped,function(dt)
 frameCount+=1;frameSeconds+=dt;perfClock+=math.min(dt,.05)
 iconAura.Visible=launcher.Visible
 iconAura.Position=UDim2.fromOffset(launcher.Position.X.Offset-6,launcher.Position.Y.Offset-6)
 iconAura.Size=UDim2.fromOffset(launcher.AbsoluteSize.X+12,launcher.AbsoluteSize.Y+12)
 if launcher.Visible and state.smooth and not state.reduce then
  local energy=floating.energy.Value
  floating.planet.Rotation=math.sin(perfClock*.25)*1.4
  floating.glow.Rotation=floating.planet.Rotation
  floating.glow.ImageTransparency=.88-energy*.24+math.sin(perfClock*1.1)*.035
  floating.flowLight.Rotation=(perfClock*12)%360
  for i,trail in ipairs(floating.dust) do
   for j,dot in ipairs(trail) do
    local phase=(perfClock*(.085+energy*.035)+i/7-(j-1)*.012)%1
    local radius=31-21*phase
    local angle=phase*math.pi*3+i*2.399
    local px,py=radius*math.cos(angle),radius*.36*math.sin(angle)
    local tilt=math.rad(-16)
    dot.Position=UDim2.fromOffset(34+px*math.cos(tilt)-py*math.sin(tilt),34+px*math.sin(tilt)+py*math.cos(tilt))
    dot.BackgroundTransparency=1-math.sin(phase*math.pi)^2*(j==1 and .60 or .25)
   end
  end
  if hoverCard.Visible then
   floating.haloEdge.Transparency=.94+math.sin(perfClock*1.1)*.02
   floating.edgeLight.Rotation=12+math.sin(perfClock*.23)*28
   floating.topGlint.Position=UDim2.fromOffset(22+(perfClock%7)/7*200,0)
   floating.sweep.Position=UDim2.fromOffset((perfClock%5)/5*390-75,-12)
   floating.liveDot.BackgroundTransparency=.12+math.sin(perfClock*2)*.10
   for _,ray in ipairs(floating.statusSpark) do ray.BackgroundTransparency=.12+(math.sin(perfClock*2.2)+1)*.33 end
  end
  for i,gradient in ipairs(auraGradients)do gradient.Rotation=(perfClock*85+i*18)%360 end
 end
 if frameSeconds>=.4 then
    fpsValue.Text=tostring(math.floor(frameCount/frameSeconds+.5))
  pages.Overview.FPSCard.Value.Text=fpsValue.Text
  do
   local fps=frameCount/frameSeconds
   local card=pages.Overview.FPSCard
   local color=fps>=55 and Color3.fromRGB(99,220,160) or (fps>=30 and Color3.fromRGB(245,191,100) or Color3.fromRGB(242,123,130))
   card.Status.Text=fps>=55 and 'Smooth' or (fps>=30 and 'Moderate' or 'Low frame rate')
   card.Status.TextColor3=color;card.StatusDot.BackgroundColor3=color
  end
  if hoverCard.Visible or (state.open and state.page=='Overview') then
   local ok,value=pcall(function()return game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()end)
   pingValue.Text=ok and type(value)=='number' and tostring(math.floor(value+.5))..' ms' or '—'
   pages.Overview.PingCard.Value.Text=pingValue.Text
   do
    local card=pages.Overview.PingCard
    local valid=ok and type(value)=='number'
    local color=valid and (value<100 and Color3.fromRGB(99,220,160) or (value<180 and Color3.fromRGB(245,191,100) or Color3.fromRGB(242,123,130))) or muted
    card.Status.Text=valid and (value<100 and 'Stable' or (value<180 and 'Moderate latency' or 'High latency')) or 'Unavailable'
    card.Status.TextColor3=color;card.StatusDot.BackgroundColor3=color
   end
  end
  frameCount=0;frameSeconds=0
 end
 if not launcher.Visible then
  if hovered then hidePerformance() end
  return
 end
 if not hoverCard.Visible then return end
 positionHover();perfParticles.Visible=state.stars
 if not state.stars or state.reduce or not state.smooth then return end
 for _,s in ipairs(perfDots)do
  s.y=(s.y-s.speed*math.min(dt,.05))%1
  s.dot.Position=UDim2.fromScale(s.x,s.y)
  s.dot.BackgroundTransparency=.66+math.sin(perfClock*.7+s.phase)*.15
 end
end)

-- No hold timer: rebase at the drag threshold instead of jumping by the
-- accumulated press distance. Motion is smoothed once per rendered frame.
local launcherDrag,launcherStart,launcherOrigin
local launcherMoved=false
local suppressLauncherClickUntil=0
local dragTarget=Vector2.new(launcher.Position.X.Offset,launcher.Position.Y.Offset)
local function clampLauncher(pos)
 local camera=workspace.CurrentCamera
 if not camera then return pos end
 local top,bottom=game:GetService('GuiService'):GetGuiInset()
 local safe=camera.ViewportSize-top-bottom
 local bounds=gui.AbsoluteSize
 local width,height=launcher.AbsoluteSize.X,launcher.AbsoluteSize.Y
 local maxX,maxY=math.max(0,bounds.X-width),math.max(0,bounds.Y-height)
 local x,y=math.clamp(pos.X,0,maxX),math.clamp(pos.Y,0,maxY)
 if x<14 then x=0 elseif maxX-x<14 then x=maxX end
 if y<14 then y=0 elseif maxY-y<14 then y=maxY end
 return Vector2.new(x,y)
end
on(launcher.InputBegan,function(input)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 launcherDrag=input
 launcherStart=Vector2.new(input.Position.X,input.Position.Y)
 launcherOrigin=Vector2.new(launcher.Position.X.Offset,launcher.Position.Y.Offset)
 dragTarget=launcherOrigin
 launcherMoved=false
 suppressLauncherClickUntil=0
end)
on(Input.InputChanged,function(input)
 if not launcherDrag or not launcher.Visible then return end
 local mouse=launcherDrag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement
 if input~=launcherDrag and not mouse then return end
 local pos=Vector2.new(input.Position.X,input.Position.Y)
 local delta=pos-launcherStart
 if not launcherMoved then
  if delta.Magnitude<6 then return end
  launcherMoved=true
  launcher:SetAttribute('Dragging',true)
  launcherStart=pos
  launcherOrigin=Vector2.new(launcher.Position.X.Offset,launcher.Position.Y.Offset)
  dragTarget=launcherOrigin
  hidePerformance()
  animate(hoverScale,{Scale=1},.12)
  suppressLauncherClickUntil=os.clock()+.2
  return
 end
 dragTarget=clampLauncher(launcherOrigin+delta)
 suppressLauncherClickUntil=os.clock()+.2
end)
on(RunService.RenderStepped,function(dt)
 if not launcher.Visible then return end
 local current=Vector2.new(launcher.Position.X.Offset,launcher.Position.Y.Offset)
 if not launcherMoved then return end
 if (current-dragTarget).Magnitude<.02 then launcher.Position=UDim2.fromOffset(dragTarget.X,dragTarget.Y) return end
 local nextPosition
 if state.reduce or not state.smooth then nextPosition=dragTarget
 else nextPosition=current:Lerp(dragTarget,1-math.exp(-55*math.min(dt,.1))) end
 launcher.Position=UDim2.fromOffset(nextPosition.X,nextPosition.Y)
end)
on(Input.InputEnded,function(input)
 if not launcherDrag then return end
 local mouse=launcherDrag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1
 if input==launcherDrag or mouse then
  if launcherMoved then suppressLauncherClickUntil=os.clock()+.2 end
  launcherDrag=nil
  launcher:SetAttribute('Dragging',false)
 end
end)
on(Input.WindowFocusReleased,function()
 launcherDrag=nil
 launcher:SetAttribute('Dragging',false)
end)

local setOpen
do
local transitionId=0
local windowTransitionUntil=0
local savedScrollPositions=setmetatable({},{__mode='k'})
local windowFade=new('NumberValue',{Name='WindowTransitionAlpha',Value=0},root)
local fadeRecords
local function animateWindow(obj,properties,duration)
 if activeTweens[obj]then activeTweens[obj]:Cancel();activeTweens[obj]=nil end
 if duration<=0 then for key,value in pairs(properties)do obj[key]=value end;return end
 local animation=TweenService:Create(obj,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),properties)
 activeTweens[obj]=animation;animation:Play()
end
local function captureWindowFade()
 if fadeRecords then return end
 fadeRecords={}
 local foreground=canvas:FindFirstChild('CrispContent')
 if not foreground then return end
 for _,obj in ipairs(foreground:QueryDescendants('GuiObject, UIStroke'))do
  local shown=true;local ancestor=obj
  while ancestor and ancestor~=foreground do
   if ancestor:IsA('GuiObject')and not ancestor.Visible then shown=false;break end
   ancestor=ancestor.Parent
  end
  if not shown then continue end
  local properties={}
  if obj:IsA('GuiObject')then properties.BackgroundTransparency=obj.BackgroundTransparency end
  if obj:IsA('TextLabel')or obj:IsA('TextButton')or obj:IsA('TextBox')then
   properties.TextTransparency=obj.TextTransparency;properties.TextStrokeTransparency=obj.TextStrokeTransparency
  elseif obj:IsA('ImageLabel')or obj:IsA('ImageButton')or obj:IsA('ViewportFrame')then properties.ImageTransparency=obj.ImageTransparency
  elseif obj:IsA('UIStroke')then properties.Transparency=obj.Transparency end
  for property,base in pairs(properties)do if base>=1 then properties[property]=nil end end
  if next(properties)then fadeRecords[#fadeRecords+1]={Object=obj,Properties=properties}end
 end
end
local function applyWindowFade(alpha)
 for _,record in ipairs(fadeRecords or {})do if record.Object.Parent then
  for property,base in pairs(record.Properties)do record.Object[property]=base+(1-base)*alpha end
 end end
end
local function restoreWindowFade()
 applyWindowFade(0);fadeRecords=nil
end
on(windowFade.Changed,applyWindowFade)
setOpen=function(value)
 value=value==true
 local wasTransitioning=os.clock()<windowTransitionUntil
 if value==state.open and not wasTransitioning and root.Visible==value then return end
 transitionId+=1;local id=transitionId
 if not value and state.open and not wasTransitioning then
  for _,scroll in ipairs(canvas:QueryDescendants('ScrollingFrame'))do savedScrollPositions[scroll]=scroll.CanvasPosition end
 end
 state.open=value;dropdown.set(false,true)
 launcherDrag=nil;launcher:SetAttribute('Dragging',false);hidePerformance()
 local tooltip=canvas:FindFirstChild('Tooltip',true);if tooltip then tooltip.Visible=false end
 capturingKey=false;hotkeyText.Text=keyName(hotkey)
 local duration=state.smooth and not state.reduce and .24 or 0
 windowTransitionUntil=os.clock()+duration
 captureWindowFade()
 local center=UDim2.fromScale(.5,.5)
 local scale=math.max(uiScale.Scale,.01)
 local windowCenter=root.AbsolutePosition+root.AbsoluteSize/2
 local iconCenter=launcher.AbsolutePosition+launcher.AbsoluteSize/2
 local offset=(iconCenter-windowCenter)/scale
 local resting=UDim2.new(.5,offset.X,.5,offset.Y)
 local compactScale=math.clamp(launcher.AbsoluteSize.X/math.max(root.AbsoluteSize.X,1),.04,.16)
 if value and not root.Visible then
  canvas.Position=resting;motion.Position=resting;motionScale.Scale=compactScale
  windowFade.Value=1;applyWindowFade(1);surface.GroupTransparency=1;motion.GroupTransparency=1
 end
 root.Visible=true
 launcher.Active=not value
 animateWindow(canvas,{Position=value and center or resting},duration)
 animateWindow(motionScale,{Scale=value and 1 or compactScale},duration)
 animateWindow(windowFade,{Value=value and 0 or 1},duration)
 animateWindow(surface,{GroupTransparency=value and 0 or 1},duration)
 animateWindow(motion,{Position=value and center or resting,GroupTransparency=value and 0 or 1},duration)
 if value then
  if launcher.Visible then
   animateWindow(launcher,{ImageTransparency=1,BackgroundTransparency=1},duration)
   animateWindow(floating.launcherVisual,{GroupTransparency=1},duration)
   animateWindow(hoverScale,{Scale=.94},duration)
  end
 elseif state.showIcon then
  if not launcher.Visible then
   launcher.ImageTransparency=1;floating.launcherVisual.GroupTransparency=1;hoverScale.Scale=.94
  end
  launcher.Visible=true;launcher.Active=true
  animateWindow(launcher,{ImageTransparency=0,BackgroundTransparency=1},duration)
  animateWindow(floating.launcherVisual,{GroupTransparency=0},duration)
  animateWindow(hoverScale,{Scale=1},duration)
 else launcher.Visible=false end
 animateWindow(blur,{Size=value and 8 or 0},duration)
 task.delay(duration,function()
  if dead or transitionId~=id then return end
  root.Visible=state.open
  if state.open then
   launcher.Visible=false;motion.GroupTransparency=0;surface.GroupTransparency=0
   canvas.Position=center;motion.Position=center;motionScale.Scale=1
   restoreWindowFade()
   for scroll,position in pairs(savedScrollPositions)do if scroll.Parent then scroll.CanvasPosition=position end end
  else
   restoreWindowFade();launcher.Visible=state.showIcon;launcher.Active=true
   launcher.ImageTransparency=0;launcher.BackgroundTransparency=1;floating.launcherVisual.GroupTransparency=0
  end
 end)
end

end


local windowControl=Instance.new('BindableFunction')
windowControl.Name='SetWindowOpen'
windowControl.OnInvoke=function(value)
 local previous=state.open
 if type(value)=='boolean' then setOpen(value) end
 return previous
end
windowControl.Parent=gui
on(minimize.Activated,function() setOpen(false) end)
local function restoreFromIcon()
 if state.open or os.clock()<suppressLauncherClickUntil then return end
 -- No extra delay: icon fade and window reveal start together on the click.
 setOpen(true)
end
on(launcher.Activated,restoreFromIcon)
on(launcher.MouseButton1Click,restoreFromIcon)

-- Close hides the panel; the selected shortcut or launcher can reopen it.
on(close.Activated,function() setOpen(false) end)
on(hotkeyButton.Activated,function()
 capturingKey=not capturingKey
 hotkeyText.Text=capturingKey and 'Press a key…' or keyName(hotkey)
 if capturingKey then notify('Press a keyboard key. Esc cancels.') end
end)
on(search.Focused,function()
 capturingKey=false; hotkeyText.Text=keyName(hotkey)
end)
on(Input.InputBegan,function(input,processed)
 if capturingKey then
  if input.UserInputType~=Enum.UserInputType.Keyboard then return end
  if input.KeyCode==Enum.KeyCode.Escape then
   capturingKey=false; hotkeyText.Text=keyName(hotkey); return
  end
  if input.KeyCode==Enum.KeyCode.Unknown then return end
  hotkey=input.KeyCode; capturingKey=false; store:SetAttribute('Hotkey',hotkey.Name)
  hotkeyText.Text=keyName(hotkey)
  shortcutHint.Text=keyName(hotkey)..' to hide or show  ·  Drag the top bar to move'
  notify('Window shortcut: '..keyName(hotkey))
  return -- Binding a key must never minimize the window at the same time.
 end
 if not processed and not Input:GetFocusedTextBox() and input.KeyCode==hotkey then setOpen(not state.open) end
end)
local tooltip=panel(surface,'Tooltip',0,0,330,36,'field',7); tooltip.Visible=false; tooltip.ZIndex=25
local tooltipText=text(tooltip,'',12,0,306,36,12); tooltipText.ZIndex=26
for _,desc in ipairs(descriptions) do
 desc.Active=true
 on(desc.MouseEnter,function()
  if not state.tips then return end
  tooltipText.Text=desc.Text
  local x=(desc.AbsolutePosition.X-surface.AbsolutePosition.X)/uiScale.Scale
  local y=(desc.AbsolutePosition.Y-surface.AbsolutePosition.Y)/uiScale.Scale+27
  tooltip.Position=UDim2.fromOffset(math.clamp(x,8,root.Size.X.Offset-338),math.clamp(y,8,root.Size.Y.Offset-44)); tooltip.Visible=true
 end)
 on(desc.MouseLeave,function() tooltip.Visible=false end)
end
on(search:GetPropertyChangedSignal('Text'),function()
 local query=string.lower(search.Text)
 if state.page=='Settings' then
  for _,entry in ipairs(searchable) do
   local match=query=='' or string.find(entry.name,query,1,true)~=nil
   -- Preserve card geometry while dimming unrelated rows.
   for _,obj in ipairs(entry.obj:QueryDescendants('TextLabel')) do obj.TextTransparency=match and 0 or .7 end
  end
 end
end)
on(search.FocusLost,function(enter)
 if enter then
  local query=string.lower(search.Text)
  for name in pairs(pages) do if query~='' and string.find(string.lower(name),query,1,true) then selectPage(name); break end end
 end
end)
local viewportFocused=true
local pendingViewport=nil
local viewportStableSince=0
on(Input.WindowFocusReleased,function()
 viewportFocused=false pendingViewport=nil
end)
on(Input.WindowFocused,function()
 viewportFocused=true pendingViewport=nil viewportStableSince=os.clock()
end)
local clock=0
on(RunService.RenderStepped,function(dt)
 if dead then return end
 local camera=workspace.CurrentCamera
 if viewportFocused and camera then
  local size=camera.ViewportSize
  if size.X>=320 and size.Y>=240 and size~=viewport then
   if pendingViewport~=size then pendingViewport=size viewportStableSince=os.clock()
   elseif os.clock()-viewportStableSince>=.25 then
    fit() pendingViewport=nil
   end
  else pendingViewport=nil end
 end
 if not state.open then return end
 clock+=math.min(dt,.05)
 if not state.smooth or state.reduce then return end
 if (state.theme=='Space' or state.theme=='Event Horizon' or state.theme=='Nebula Violet' or state.theme=='Stardust Blue') then
  spaceArt.image.Position=UDim2.fromOffset(-2+math.sin(clock*.13),(spaceArt.image:GetAttribute('HeaderBaseY')or -2)+math.cos(clock*.11)*.5)
 end
 if state.theme=='Halloween' then
  ghost.Position=UDim2.fromOffset(1045,122+math.sin(clock*.8)*3)
  pumpkin.Rotation=-8+math.sin(clock*.45)*2
  sidebarPumpkin.Rotation=8+math.sin(clock*.4)*2
  halloweenBat.Rotation=-16+math.sin(clock*.65)*4
  halloweenMoon.Position=UDim2.fromOffset(839,102+math.sin(clock*.4)*2)
 end
 if not state.stars then return end
 for _,s in ipairs(stars) do
  s.y=(s.y-s.speed*math.min(dt,.05))%1
  s.dot.Position=UDim2.fromScale((s.x+math.sin(clock*.3+s.phase)*s.drift)%1,s.y)
  s.dot.BackgroundTransparency=.29+math.sin(clock*.85+s.phase)*.17
 end
end)
on(gui.Destroying,function()
 dead=true
 for _,c in ipairs(connections) do c:Disconnect() end
 for _,t in pairs(activeTweens) do t:Cancel() end
 if dropdown.tween then dropdown.tween:Cancel() end
 blur:Destroy()
end)
task.spawn(function()
 local assets={} for _,id in pairs(iconAssets) do table.insert(assets,'rbxassetid://'..id) end
 for _,obj in ipairs(decorationImages) do table.insert(assets,obj.Image) end
 table.insert(assets,'rbxassetid://6772783963')
 if DEEP_VOID_IMAGE~='' then table.insert(assets,DEEP_VOID_IMAGE) end
 local ok,err=pcall(function() game:GetService('ContentProvider'):PreloadAsync(assets) end)
 if not ok and not dead then warn('Obsidian icon preload: '..tostring(err)) end
end)
-- Only decorative backgrounds are rasterized for rounded clipping.
do
 local foreground=new('Frame',{Name='CrispContent',BackgroundTransparency=1,Size=UDim2.fromOffset(960,1040),ZIndex=3},canvas)
 foreground:SetAttribute('NativeTextRendering',true)
 for _,obj in ipairs(surface:GetChildren()) do
  if obj:IsA('CanvasGroup') or obj.Name=='Tooltip' then obj.Parent=foreground end
 end
 on(surface.ChildAdded,function(obj)if obj:IsA('CanvasGroup') or obj.Name=='Tooltip' then obj.Parent=foreground end end)
 header.Parent=foreground
 body.Parent=foreground
 local sidebarContent=new('Frame',{Name='SidebarContent',BackgroundTransparency=1,Position=sidebar.Position,Size=sidebar.Size},foreground)
 for _,obj in ipairs(sidebar:GetChildren()) do
  if obj:IsA('GuiObject') and obj.Name~='HalloweenSidebar' then obj.Parent=sidebarContent end
 end
end

-- Rose Eclipse host layout. All ten categories remain reachable in two compact rows.
;(function()
 header.Size=UDim2.fromOffset(960,138)
 brand.Text='FYRELITH' brand.Font=Enum.Font.GothamMedium brand.TextSize=30
 brand.Position=UDim2.fromOffset(28,54) brand.Size=UDim2.fromOffset(320,46) brand.TextColor3=Color3.fromRGB(249,229,235)
 brandLogo.Visible=false
 for _,obj in ipairs(header:GetChildren())do if obj:IsA('TextLabel')and obj~=brand then obj.Visible=false end end
 local signature=text(header,'R O S E   E C L I P S E',30,102,320,22,12,Color3.fromRGB(210,170,183))
 signature.Name='RoseSignature' signature.TextSize=13
 local dock=header:FindFirstChild('CommandDock')
 if dock then dock.Position=UDim2.fromOffset(374,16)end
 dragHandle.Size=UDim2.fromOffset(960,138) dragHandle.ZIndex=1
 if dock then dock.ZIndex=3 end
 sidebar.Position=UDim2.fromOffset(16,146) sidebar.Size=UDim2.fromOffset(928,86) sidebar.BackgroundTransparency=.15
 local navHost=canvas:FindFirstChild('CrispContent'):FindFirstChild('SidebarContent')
 navHost.Position=sidebar.Position navHost.Size=sidebar.Size
 local order={'Overview','Main','Auto Play','Summon','Event','Macro','Dungeon','Misc','Webhook','Settings'}
 for _,obj in ipairs(navHost:GetChildren())do if obj:IsA('GuiObject')then obj.Visible=false end end
 for i,name in ipairs(order)do
  local n=navs[name] local x=8+((i-1)%5)*184 local y=5+math.floor((i-1)/5)*40
  n.button.Visible=true n.button.Position=UDim2.fromOffset(x,y) n.button.Size=UDim2.fromOffset(176,36)
  n.title.Position=UDim2.fromOffset(42,0) n.title.Size=UDim2.fromOffset(130,36) n.title.TextSize=17
  local image=n.button:FindFirstChildWhichIsA('ImageLabel')if image then image.Position=UDim2.fromOffset(12,9)image.Size=UDim2.fromOffset(18,18)end
 end
 navIndicator.Visible=true navIndicator.Size=UDim2.fromOffset(176,36)
 navIndicatorFill.Size=UDim2.fromOffset(176,36)
 navIndicatorBar.Position=UDim2.fromOffset(12,34)navIndicatorBar.Size=UDim2.fromOffset(152,2)
 divider.Visible=false
 body.Position=UDim2.fromOffset(26,247) body.Size=UDim2.fromOffset(908,630)
 heading.TextSize=29 heading.Size=UDim2.fromOffset(860,43)
 for _,p in pairs(pages)do p.Size=UDim2.fromOffset(908,564)p.ScrollBarThickness=4 p.ScrollBarImageColor3=Color3.fromRGB(220,150,166)end
 toast.Position=UDim2.fromOffset(600,846)
 -- Hide the old horizontal divider, whose width belonged to the previous layout.
 for _,obj in ipairs(surface:GetChildren())do if obj:IsA('Frame')and obj.Size==UDim2.fromOffset(1200,1)then obj.Visible=false end end
 gui:SetAttribute('Design','Rose Eclipse')
end)()
;(function()
 local home=pages.Overview
 local map=home:FindFirstChild('CurrentMap')
 map.Position=UDim2.fromOffset(8,112) map.Size=UDim2.fromOffset(624,310)
 local thumb=map:FindFirstChild('Thumbnail')thumb.Size=UDim2.fromOffset(592,190)
 local fallback=thumb:FindFirstChildWhichIsA('TextLabel')if fallback then fallback.Position=UDim2.fromOffset(16,78)end
 for _,obj in ipairs(map:GetChildren())do
  if obj:IsA('TextLabel')and obj.Position.Y.Offset>=210 then obj.Position+=UDim2.fromOffset(0,32)end
 end
 for i,name in ipairs({'FPSCard','PingCard'})do
  local card=home[name]card.Position=UDim2.fromOffset(648,112+(i-1)*163)card.Size=UDim2.fromOffset(252,147)
  card.Value.TextSize=35 card.Value.Position=UDim2.fromOffset(20,61)
  card.Status.Position=UDim2.fromOffset(36,116)card.StatusDot.Position=UDim2.fromOffset(21,126)
 end
 shortcutHint.Position=UDim2.fromOffset(12,540)shortcutHint.Size=UDim2.fromOffset(880,24)shortcutHint.TextSize=14
 local cards={{'Auto Play','Play','Placement, upgrades & team'},{'Summon','Star','Units, traits & rerolls'},{'Settings','Settings','Appearance & preferences'}}
 for i,entry in ipairs(cards)do
  local b=control(home,'HomeShortcut'..i,8+(i-1)*300,438,292,90)
  b.BackgroundTransparency=.08
  local image=icon(b,entry[2],16,17,23)bind(image,'ImageColor3','accent')
  local title=text(b,entry[1],51,10,223,29,18,white,true)title.Name='Title'
  local caption=text(b,entry[3],16,48,260,26,14,muted)caption.Name='Description'caption.TextSize=14
  local arrow=icon(b,'Chevron',261,19,14)arrow.Rotation=-90 bind(arrow,'ImageColor3','accent')
  on(b.Activated,function()selectPage(entry[1])end)
 end
 home.CanvasSize=UDim2.fromOffset(0,564)
end)()
-- Reference layout: five tabs; secondary categories stay available under More.
;(function()
 header.Size=UDim2.fromOffset(960,218)
 brand.Text='F Y R E L I T H';brand.TextSize=44;brand.Position=UDim2.fromOffset(106,42);brand.Size=UDim2.fromOffset(530,64)
 local emblem=new('ImageLabel',{Name='RoseEmblem',Image='rbxassetid://16898613777',ImageRectOffset=Vector2.new(967,0),ImageRectSize=Vector2.new(48,48),Position=UDim2.fromOffset(28,42),Size=UDim2.fromOffset(64,64),BackgroundTransparency=1,ImageColor3=white,Active=false},header);bind(emblem,'ImageColor3','accent')
 local signature=header:FindFirstChild('RoseSignature')if signature then signature.Position=UDim2.fromOffset(110,106);signature.Size=UDim2.fromOffset(450,42);signature.TextSize=12;signature.Text='A  B R I G H T E R  T O M O R R O W\nI N  D A R K E R  S K I E S .';signature.TextWrapped=true end
 local dock=header:FindFirstChild('CommandDock')if dock then dock.Visible=false end
 for i,b in ipairs({minimize,close})do b.Parent=header;b.Position=UDim2.fromOffset(836+(i-1)*54,14);b.Size=UDim2.fromOffset(44,38);b.ZIndex=20;b.BackgroundTransparency=.25 end
 dragHandle.Size=UDim2.fromOffset(820,150)
 sidebar.Position=UDim2.fromOffset(12,166);sidebar.Size=UDim2.fromOffset(936,54);sidebar.BackgroundTransparency=1
 local navHost=canvas.CrispContent.SidebarContent;navHost.Position=sidebar.Position;navHost.Size=sidebar.Size
 local more=control(navHost,'More',752,0,182,54)
 text(more,'•••   More',16,0,152,54,20,white,true).TextXAlignment=Enum.TextXAlignment.Center
 local menu=panel(canvas.CrispContent,'MoreMenu',724,224,218,286,'card',12);menu.ZIndex=40;menu.Visible=false
 for _,obj in ipairs(navHost:GetChildren())do if obj:IsA('GuiObject')and obj~=more and obj~=navIndicator then obj.Visible=false end end
 for i,name in ipairs({'Overview','Auto Play','Summon','Event'})do
  local n=navs[name];n.button.Visible=true;n.button.Position=UDim2.fromOffset((i-1)*188,0);n.button.Size=UDim2.fromOffset(182,54)
  n.title.Text=name=='Overview'and'Main'or name;n.title.TextSize=20;n.title.Position=UDim2.fromOffset(48,0);n.title.Size=UDim2.fromOffset(130,54)
  local image=n.button:FindFirstChildWhichIsA('ImageLabel')if image then image.Position=UDim2.fromOffset(18,16);image.Size=UDim2.fromOffset(23,23)end
 end
 for i,name in ipairs({'Main','Macro','Dungeon','Misc','Webhook','Settings'})do
  local n=navs[name];n.button.Parent=menu;n.button.Visible=true;n.button.Position=UDim2.fromOffset(8,8+(i-1)*45);n.button.Size=UDim2.fromOffset(202,40);n.button.ZIndex=42
  n.title.Text=name=='Main'and'Auto Join'or name;n.title.Size=UDim2.fromOffset(155,40);n.title.TextSize=18;n.title.ZIndex=44
  for _,image in ipairs(n.button:GetChildren())do if image:IsA('ImageLabel')then image.ZIndex=44 end end
  on(n.button.Activated,function()menu.Visible=false end)
 end
 on(more.Activated,function()menu.Visible=not menu.Visible end)
 on(root:GetPropertyChangedSignal('Visible'),function()if not root.Visible then menu.Visible=false end end)
 on(Input.InputBegan,function(input)
  if not menu.Visible or input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
  local p=Vector2.new(input.Position.X,input.Position.Y)
  local function inside(o)local a=o.AbsolutePosition;local s=o.AbsoluteSize;return p.X>=a.X and p.X<=a.X+s.X and p.Y>=a.Y and p.Y<=a.Y+s.Y end
  if not inside(menu)and not inside(more)then menu.Visible=false end
 end)
 navIndicator.Size=UDim2.fromOffset(182,54);navIndicatorFill.Size=UDim2.fromOffset(182,54)
 navIndicatorBar.Position=UDim2.fromOffset(12,51);navIndicatorBar.Size=UDim2.fromOffset(158,2)
 body.Position=UDim2.fromOffset(26,242);body.Size=UDim2.fromOffset(908,772)
 for name,p in pairs(pages)do p.Size=UDim2.fromOffset(908,name=='Auto Play'and 772 or 706)end
 spaceArt.group.Size=UDim2.fromOffset(960,220)
 spaceArt.image.Position=UDim2.fromOffset(0,-40);spaceArt.image.Size=UDim2.fromOffset(960,387);spaceArt.image.ScaleType=Enum.ScaleType.Stretch;spaceArt.image.ImageTransparency=0;spaceArt.image.Image=loadRemoteImage('FyrelithThemeHeader.v2.png')
 spaceArt.shade.BackgroundTransparency=.88
 starLayer.Visible=false
 toast.Position=UDim2.fromOffset(600,988)
end)()
;(function()
 local images={Space=spaceArt.image.Image}
  images.Space=loadRemoteImage('FyrelithHeader.rose-eclipse.atelier-v2.png')
 images['Event Horizon']=loadRemoteImage('FyrelithHeader.event-horizon.atelier-v2.png')
 images['Nebula Violet']=loadRemoteImage('FyrelithHeader.nebula-violet.atelier-v2.png')
 images['Stardust Blue']=loadRemoteImage('FyrelithHeader.stardust-blue.atelier-v2.png')

 local emblem=header:FindFirstChild('RoseEmblem')
 local signature=header:FindFirstChild('RoseSignature')
 local ornaments=new('Frame',{Name='ThemeWordmarkDetails',BackgroundTransparency=1,Size=UDim2.fromOffset(960,166),Active=false},header)
 local brandRail=new('Frame',{Name='BrandAccentRail',Position=UDim2.fromOffset(28,58),Size=UDim2.fromOffset(3,32),BackgroundColor3=white,BorderSizePixel=0,Active=false},header);round(brandRail,2)
 local brandRule=new('Frame',{Name='BrandUnderline',Position=UDim2.fromOffset(48,105),Size=UDim2.fromOffset(176,1),BackgroundColor3=white,BorderSizePixel=0,Active=false},header)
 new('UIGradient',{Transparency=NumberSequence.new(0,1)},brandRule)
 local brandInk=new('UIGradient',{Rotation=0},brand)
 local ring=new('Frame',{Name='EventStarRing',BackgroundTransparency=1,Position=UDim2.fromOffset(30,39),Size=UDim2.fromOffset(76,76),Active=false},ornaments);round(ring,40)
 local ringEdge=stroke(ring);ringEdge.Thickness=1
 local function segment(name,x,y,w,h,angle)
  return new('Frame',{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=angle or 0,BackgroundColor3=white,BorderSizePixel=0,Active=false},ornaments)
 end
 local blueRules={segment('BlueRuleLeft',415,112,156,1),segment('BlueRuleRight',605,112,156,1)}
 local blueGem=new('ImageLabel',{Name='BlueRuleStar',Image=emblem.Image,ImageRectSize=emblem.ImageRectSize,ImageRectOffset=emblem.ImageRectOffset,BackgroundTransparency=1,Position=UDim2.fromOffset(578,102),Size=UDim2.fromOffset(22,22),Active=false},ornaments)
 local violetSwash={}
 for i=1,48 do
  local t=(i-1)/47;local x=44+t*500;local y=104+math.sin(t*math.pi*1.6)*8
  violetSwash[i]=segment('VioletSwash',x,y,12,1.4,math.cos(t*math.pi*1.6)*5)
 end
 local violetStar=new('ImageLabel',{Name='VioletSignatureStar',Image=emblem.Image,ImageRectSize=emblem.ImageRectSize,ImageRectOffset=emblem.ImageRectOffset,BackgroundTransparency=1,Position=UDim2.fromOffset(72,95),Size=UDim2.fromOffset(18,18),Active=false},ornaments)
 spaceArt.applyHeader=function(name)
  local _,accent=palette()
  local image=images[name]
  spaceArt.image.Image=image or images.Space
  spaceArt.image.ImageColor3=image and Color3.new(1,1,1)or accent:Lerp(white,.2)
  local dedicated=image and name~='Space'
  spaceArt.image.Size=dedicated and UDim2.fromOffset(960,320)or UDim2.fromOffset(960,387)
  spaceArt.image.Position=UDim2.fromOffset(0,dedicated and -20 or -40)
  spaceArt.image:SetAttribute('HeaderBaseY',dedicated and -20 or -40)
  spaceArt.image:SetAttribute('HeaderTheme',name)
  brand.Text='F Y R E L I T H';brand.Font=Enum.Font.GothamMedium;brand.TextSize=44
  brand.Position=UDim2.fromOffset(106,42);brand.Size=UDim2.fromOffset(530,64);brand.TextXAlignment=Enum.TextXAlignment.Left
  brand.TextStrokeColor3=accent;brand.TextStrokeTransparency=.88
  emblem.Visible=true;emblem.Position=UDim2.fromOffset(28,42);emblem.Size=UDim2.fromOffset(64,64)
  signature.Position=UDim2.fromOffset(110,106);signature.Size=UDim2.fromOffset(450,42);signature.TextSize=12;signature.TextXAlignment=Enum.TextXAlignment.Left
  signature.Text='A  B R I G H T E R  T O M O R R O W\nI N  D A R K E R  S K I E S .'
  ring.Visible=name=='Event Horizon';ringEdge.Color=accent
  for _,line in ipairs(blueRules)do line.Visible=name=='Stardust Blue';line.BackgroundColor3=accent end
  blueGem.Visible=name=='Stardust Blue';blueGem.ImageColor3=accent
  for _,line in ipairs(violetSwash)do line.Visible=name=='Nebula Violet';line.BackgroundColor3=accent;line.BackgroundTransparency=.3 end
  violetStar.Visible=name=='Nebula Violet';violetStar.ImageColor3=accent
  if name=='Event Horizon'then
   emblem.Position=UDim2.fromOffset(42,51);emblem.Size=UDim2.fromOffset(52,52)
   brand.Position=UDim2.fromOffset(126,42);brand.TextSize=42
   signature.Position=UDim2.fromOffset(128,104);signature.Size=UDim2.fromOffset(550,30);signature.TextSize=13
   signature.Text='BEYOND LIMITS, ANOTHER TOMORROW.'
  elseif name=='Nebula Violet'then
   emblem.Visible=false;brand.Text='FYRELITH';brand.Font=Enum.Font.Antique;brand.TextSize=66
   brand.Position=UDim2.fromOffset(42,32);brand.Size=UDim2.fromOffset(540,80)
   signature.Position=UDim2.fromOffset(52,116);signature.Size=UDim2.fromOffset(500,28);signature.TextSize=14
   signature.Text='P L A Y   B E Y O N D   L I M I T S'
  elseif name=='Stardust Blue'then
   emblem.Position=UDim2.fromOffset(568,12);emblem.Size=UDim2.fromOffset(42,42)
   brand.Position=UDim2.fromOffset(304,46);brand.Size=UDim2.fromOffset(570,60);brand.TextSize=44;brand.TextXAlignment=Enum.TextXAlignment.Center
   signature.Position=UDim2.fromOffset(320,118);signature.Size=UDim2.fromOffset(540,28);signature.TextSize=14;signature.TextXAlignment=Enum.TextXAlignment.Center
   signature.Text='G A M E   U T I L I T Y'
  end
  -- Native text stays crisp at every window scale; decorative image logos are unused.
  brand.Visible=true;brand.Text='FYRELITH';brand.Font=Enum.Font.GothamMedium;brand.TextSize=28
  brand.Position=UDim2.fromOffset(48,55);brand.Size=UDim2.fromOffset(310,48);brand.TextXAlignment=Enum.TextXAlignment.Left
  brand.TextColor3=white;brand.TextStrokeTransparency=1
  brandInk.Color=ColorSequence.new(white,accent:Lerp(white,.55))
  brandRail.BackgroundColor3=accent;brandRail.Visible=name=='Space';brandRule.Visible=false
  brandRail.Position=UDim2.fromOffset(28,62);brandRail.Size=UDim2.fromOffset(2,32)
  brandInk.Color=ColorSequence.new(accent:Lerp(white,.8),accent:Lerp(white,.8))
  -- Crop uniformly rather than stretching the panoramic texture.
  spaceArt.image.Size=UDim2.fromOffset(964,170)
  spaceArt.image.Position=UDim2.fromOffset(-2,-2)
  spaceArt.image.ScaleType=Enum.ScaleType.Crop
  spaceArt.image.ImageTransparency=0;spaceArt.image.ImageColor3=white
  spaceArt.image:SetAttribute('HeaderBaseY',-2)
  spaceArt.shade.BackgroundTransparency=1
  signature.Visible=false;emblem.Visible=false;ornaments.Visible=false
 end
 task.spawn(function()
  local assets={};for _,asset in pairs(images)do if asset~=''then assets[#assets+1]=asset end end
  pcall(function()game:GetService('ContentProvider'):PreloadAsync(assets)end)
 end)
end)()

;(function()
 local host=canvas.CrispContent.SidebarContent
 host.Size=UDim2.fromOffset(936,100);sidebar.Size=host.Size
 local more=host:FindFirstChild('More')if more then more.Visible=false end
 local menu=canvas.CrispContent:FindFirstChild('MoreMenu')if menu then menu.Visible=false end
 navs.Dungeon.button.Visible=false
 for i,name in ipairs({'Overview','Main','Auto Play','Summon','Event','Macro','Dungeon','Misc','Webhook','Settings'})do
  local n=navs[name];local row=math.floor((i-1)/5)
  n.button.Parent=host;n.button.Visible=true;n.button.Position=UDim2.fromOffset(((i-1)%5)*188,row*50);n.button.Size=UDim2.fromOffset(182,44)
  n.title.Text=name=='Overview'and'Main'or name=='Main'and'Auto Join'or name
  n.title.TextSize=18;n.title.Position=UDim2.fromOffset(44,0);n.title.Size=UDim2.fromOffset(136,44)
  for _,image in ipairs(n.button:GetChildren())do if image:IsA('ImageLabel')then image.Position=UDim2.fromOffset(16,11);image.Size=UDim2.fromOffset(22,22)end end
 end
 navIndicator.Size=UDim2.fromOffset(182,44);navIndicatorFill.Size=UDim2.fromOffset(182,44)
 navIndicatorBar.Position=UDim2.fromOffset(12,41)
 body.Position=UDim2.fromOffset(26,288);body.Size=UDim2.fromOffset(908,726)
 for name,p in pairs(pages)do p.Size=UDim2.fromOffset(908,name=='Auto Play'and 726 or 660)end
end)()
refresh(); selectPage('Auto Play'); fit(); setOpen(true)

end
local playerGui=game.Players.LocalPlayer.PlayerGui
for _,item in ipairs(playerGui:GetChildren())do if item:IsA('ScreenGui') and item.Name=='FyrelithUIOnly' then item:Destroy() end end
createHost()
if not fyOwnsExecution() then if fyExecution.Gui and fyExecution.Gui.Parent then fyExecution.Gui:Destroy()end return end
local function createAutoJoin()
local function waitForFyrelithGame()
 local player=game:GetService('Players').LocalPlayer
 while not player do task.wait(.1) player=game:GetService('Players').LocalPlayer end
 local config=workspace:WaitForChild('_MAP_CONFIG') config:WaitForChild('IsLobby')
 local module=game:GetService('ReplicatedStorage'):WaitForChild('src'):WaitForChild('Loader')
 local Loader=require(module)
 local required={'EndpointsClient','LobbyServiceClient','UnitCollectionServiceClient','GUIService','SummonServiceClient','SummonFX','GoldShopServiceClient'}
 while true do
  local registry
  if debug and type(debug.getupvalues)=='function' then
   local ok,upvalues=pcall(debug.getupvalues,Loader.load_client_service)
   if ok then for _,v in pairs(upvalues) do if type(v)=='table' and v.EndpointsClient then registry=v break end end end
  end
  local ready={} local complete=true
  if registry then
   for _,name in ipairs(required) do local entry=registry[name]
    ready[name]=entry and entry.module
    if type(ready[name])~='table' then complete=false break end
   end
  elseif player:FindFirstChild('_stats') and player:FindFirstChild('_settings') then
   -- Fallback for executors without upvalue inspection.
   for _,name in ipairs(required) do local ok,value=pcall(Loader.load_client_service,module,name)
    ready[name]=ok and value or nil if type(ready[name])~='table' then complete=false break end
   end
  else complete=false end
  if complete then
   local U=ready.UnitCollectionServiceClient local E=ready.EndpointsClient local G=ready.GUIService
   if type(E.invoke_server)=='function' and E.session and G.session and U.session and U.session.profile_data and U.session.collection and U.session.inventory then
    getgenv().FyrelithGameReady={Loader=Loader,Services=ready,JobId=game.JobId}
    return Loader
   end
  end
  task.wait(.25)
 end
end
waitForFyrelithGame()

local env=getgenv()
env.FyrelithStartupError=nil
if env.FyrelithAutoJoin then env.FyrelithAutoJoin.Stop() end
local player=game.Players.LocalPlayer
local gui=player.PlayerGui:WaitForChild('FyrelithUIOnly',10)
assert(gui,'Run Fyrelith UI first')
local window=gui:WaitForChild('Window')
local hostCanvas=window:FindFirstChild('Content',true)
while not hostCanvas and gui.Parent do task.wait(.1) hostCanvas=window:FindFirstChild('Content',true) end
local main=hostCanvas:WaitForChild('CrispContent'):WaitForChild('Body'):WaitForChild('Main')
local Loader=require(game.ReplicatedStorage.src.Loader)
local function hasUnitPortrait(id)
 local core=Loader.load_core_service(script,'UnitServiceCore')
 if type(core)~='table' or type(core.unit_chars)~='table' or type(id)~='string' then return false end
 local redacted=core.REDACTED_UNITS or {}
 return core.unit_chars[id]~=nil or ((redacted[id] or redacted[id:gsub('%:shiny','')]) and core.unit_chars.unselected_unit~=nil)
end
local Levels=Loader.load_data(script,'Levels')
local Worlds=Loader.load_data(script,'Worlds')
local WorldLevelOrder=Loader.load_data(script,'WorldLevelOrder')
local gameWorldRank,gameLevelRank={},{}
local worldSource,levelSource={},{}
for _,key in ipairs({'WORLD_ORDER','RAID_WORLD_ORDER','LEGEND_WORLD_ORDER'}) do
 for rank,id in ipairs(WorldLevelOrder[key] or {}) do gameWorldRank[id]=rank end
end
for rank,id in ipairs(WorldLevelOrder.LEVEL_ORDER or {}) do gameLevelRank[id]=rank end
local wi=0 for id,w in pairs(Worlds) do
 wi+=1 worldSource[id]=wi
 for rank,d in pairs(w.levels or {}) do
  if d.id then gameLevelRank[d.id]=gameLevelRank[d.id] or tonumber(rank) end
 end
end
local li=0 for id in pairs(Levels) do li+=1 levelSource[id]=li end
local function worldRank(id)
 local w=Worlds[id]
 return gameWorldRank[id] or (w and tonumber(w.order or w.layout_order or w.world_rank)) or math.huge
end
local function sortGameWorlds(items)
 table.sort(items,function(a,b)
  local x,y=worldRank(a.id),worldRank(b.id)
  if x~=y then return x<y end
  return (worldSource[a.id] or a.source or math.huge)<(worldSource[b.id] or b.source or math.huge)
 end)
 return items
end
local function sortGameStages(items)
 table.sort(items,function(a,b)
  local ad,bd=Levels[a.id] or {},Levels[b.id] or {}
  local aw,bw=worldRank(ad.world or a.world),worldRank(bd.world or b.world)
  if aw~=bw then return aw<bw end
  local ar=tonumber(a.rank or ad.story_level_rank or ad.order or ad.level_rank) or gameLevelRank[a.id] or tonumber(a.id:match('(%d+)$')) or math.huge
  local br=tonumber(b.rank or bd.story_level_rank or bd.order or bd.level_rank) or gameLevelRank[b.id] or tonumber(b.id:match('(%d+)$')) or math.huge
  if ar~=br then return ar<br end
  return (levelSource[a.id] or math.huge)<(levelSource[b.id] or math.huge)
 end)
 return items
end

local Lobby=Loader.load_client_service(script,'LobbyServiceClient')
local EP=Loader.load_client_service(script,'EndpointsClient')
-- Some native collection portraits request nonexistent visual-only trait modules.
-- Filter those missing effects for GUI models; never modify saved trait data.
do
 local S=Loader.load_core_service(script,'UnitScriptServiceCore')
 local previous=env.FyrelithTraitVisualGuard
 if not previous or previous.Service~=S or S.apply_trait~=previous.Wrapper then
  local registry
  if debug and type(debug.getupvalues)=='function' then
   for _,value in pairs(debug.getupvalues(Loader.load_core_service)) do
    if type(value)=='table' and value.UnitScriptServiceCore then registry=value break end
   end
  end
  if registry then
   local original=S.apply_trait
   local guard={Service=S,Skipped=0}
   local function guarded(...)
    local args=table.pack(...)
    local model=args[1] local traits=args[3]
    if typeof(model)=='Instance' and not model:IsDescendantOf(workspace) and type(traits)=='table' then
     local filtered={}
     for _,trait in ipairs(traits) do
      if type(trait)~='table' or not trait.trait or registry[trait.trait] then table.insert(filtered,trait)
      else guard.Skipped+=1 end
     end
     args[3]=filtered
    end
    return original(table.unpack(args,1,args.n))
   end
   guard.Wrapper=guarded S.apply_trait=guarded env.FyrelithTraitVisualGuard=guard
  end
 end
end

local api={Alive=true,Enabled=false,Busy=false,Connections={},Counts={}}
env.FyrelithAutoJoin=api
local cfg={Mode='Story',Difficulty='Normal',Friends=false,Floor=1,ContractSlot='1',ContractEntry='Solo'}
api.Ready=false
env.FyrelithLoadedSession=nil
pcall(function()
 local path='FyrelithSession_'..player.UserId..'_'..game.GameId..'.json'
 if type(isfile)=='function' and type(readfile)=='function' and isfile(path) then env.FyrelithLoadedSession=game:GetService('HttpService'):JSONDecode(readfile(path)) end
end)
api.Config=cfg
cfg.ContractEnabled=false
local preferences=player.PlayerGui:FindFirstChild('FyrelithDefaultPreferences')
local white=Color3.fromRGB(240,243,249)
local muted=Color3.fromRGB(194,203,219)
-- Sample the host's actual rendered palette so unsaved theme/accent changes
-- and translucent Space/Halloween surfaces stay in sync immediately.
local appearance=main.Parent:WaitForChild('Settings'):WaitForChild('Appearance')
local themeField=appearance:WaitForChild('ThemeRow'):WaitForChild('ThemePicker')
local accentIcon=appearance:WaitForChild('Icon_Appearance')
local hostStroke=appearance:FindFirstChildOfClass('UIStroke')
local function palette()
 return {card=gui:GetAttribute('Palette_card')or appearance.BackgroundColor3,field=gui:GetAttribute('Palette_field')or themeField.BackgroundColor3,
  accent=gui:GetAttribute('Palette_accent')or accentIcon.ImageColor3,line=gui:GetAttribute('Palette_line')or(hostStroke and hostStroke.Color or muted),
  transparency=appearance.BackgroundTransparency}
end
local colors=palette()
local function new(class,props,parent)
 local x=Instance.new(class) for k,v in pairs(props) do x[k]=v end x.Parent=parent return x
end
local root=new('Frame',{Name='AutoJoinMain',Size=UDim2.fromScale(1,1),BackgroundTransparency=1},main)
local function ui(name) return root:FindFirstChild(name) or gui:FindFirstChild(name,true) end
local function connect(signal,fn) local c=signal:Connect(fn) table.insert(api.Connections,c) return c end
local bindings={}
local function bind(x,prop,role) x[prop]=colors[role] table.insert(bindings,{x,prop,role}) end
local function round(x,r) new('UICorner',{CornerRadius=UDim.new(0,r or 9)},x) end
local function border(x) local s=new('UIStroke',{Thickness=1,Transparency=.4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},x) bind(s,'Color','line') end
local function label(parent,name,text,x,y,w,h,size,bold,z)
 return new('TextLabel',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=white,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=size or 15,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=z or 3},parent)
end
local function card(name,x,y,w,h)
 local c=new('Frame',{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BorderSizePixel=0,ZIndex=1},root)
 bind(c,'BackgroundColor3','card') c.BackgroundTransparency=.06 round(c,11) border(c) return c
end
local controlTweens=setmetatable({},{__mode='k'})
local function tween(x,props)
 if preferences and (preferences:GetAttribute('ReduceMotion') or preferences:GetAttribute('Smooth')==false) then for k,v in pairs(props) do x[k]=v end
 else
  local changed=false;for key,value in pairs(props)do if x[key]~=value then changed=true;break end end
  if not changed then return end
  if controlTweens[x]then controlTweens[x]:Cancel()end
  local animation=game:GetService('TweenService'):Create(x,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),props)
  controlTweens[x]=animation;animation:Play()
 end
end
local selectionStates=setmetatable({},{__mode='k'})
local function selectionVisual(row,on)
 on=on==true selectionStates[row]=on row:SetAttribute('Selected',on)
 local stroke=row:FindFirstChild('SelectionOutline')
 if not stroke then
  stroke=new('UIStroke',{Name='SelectionOutline',Thickness=1,Transparency=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},row) bind(stroke,'Color','accent')
 end
 tween(stroke,{Transparency=on and .34 or .85})
 tween(row,{BackgroundColor3=on and colors.field:Lerp(colors.accent,.11) or colors.field,BackgroundTransparency=on and .26 or .55})
end
local dropdownAnimations=setmetatable({},{__mode='k'})
local function animateDropdown(menu,opened,height)
 menu.ClipsDescendants=true
 local previous=dropdownAnimations[menu] if previous then previous:Cancel() end
 menu:SetAttribute('Open',opened)
 local owner=menu.Parent
 if owner and owner:IsA('GuiObject') then
  if owner:GetAttribute('DropdownBaseZ')==nil then owner:SetAttribute('DropdownBaseZ',owner.ZIndex) end
  if opened then owner.ZIndex=100 menu.BackgroundTransparency=.03 end
 end
 local function restoreLayer()
  if not owner or not owner.Parent then return end
  for _,child in ipairs(owner:GetChildren()) do if child:IsA('CanvasGroup') and child:GetAttribute('Open') then return end end
  owner.ZIndex=owner:GetAttribute('DropdownBaseZ') or 1
 end
 local base=menu:GetAttribute('RestY')
 if not base then base=menu.Position.Y.Offset menu:SetAttribute('RestY',base) end
 local width=menu.Size.X.Offset
 local smooth=not preferences or (preferences:GetAttribute('Smooth')~=false and not preferences:GetAttribute('ReduceMotion'))
 if not smooth then menu.Visible=opened menu.Size=UDim2.fromOffset(width,height) menu.GroupTransparency=opened and 0 or 1 if not opened then restoreLayer() end return end
 if opened then
  if not menu.Visible then menu.Size=UDim2.fromOffset(width,0) menu.GroupTransparency=1 menu.Position=UDim2.fromOffset(menu.Position.X.Offset,base-7) end
  menu.Visible=true
 end
 local animation=game:GetService('TweenService'):Create(menu,TweenInfo.new(opened and .26 or .14,Enum.EasingStyle.Quint,opened and Enum.EasingDirection.Out or Enum.EasingDirection.In),{Size=UDim2.fromOffset(width,opened and height or 0),GroupTransparency=opened and 0 or 1,Position=UDim2.fromOffset(menu.Position.X.Offset,opened and base or base-7)})
 dropdownAnimations[menu]=animation
 animation.Completed:Once(function() if dropdownAnimations[menu]==animation then dropdownAnimations[menu]=nil if not opened then menu.Visible=false restoreLayer() end end end)
 animation:Play()
end
local function viewportDropdown(menu,anchor,list,maximumHeight)
 if anchor.Name~='ChooseTraits'and not anchor:FindFirstChild('Chevron')and not anchor:FindFirstChild('TargetChevron')and not anchor:FindFirstChild('Icon_Chevron')then
  new('ImageLabel',{Name='Chevron',BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-12,.5,0),Size=UDim2.fromOffset(12,12),Image='rbxassetid://7733717447',ImageColor3=muted,ZIndex=anchor.ZIndex+2,Active=false},anchor)
  if anchor:IsA('TextButton')then local padding=anchor:FindFirstChildWhichIsA('UIPadding')or new('UIPadding',{},anchor);padding.PaddingRight=UDim.new(0,32);if padding.PaddingLeft.Offset==0 then padding.PaddingLeft=UDim.new(0,12)end;anchor.TextXAlignment=Enum.TextXAlignment.Left;anchor.TextTruncate=Enum.TextTruncate.AtEnd;anchor.Chevron.Position=UDim2.new(1,20,.5,0)end
 end
 local dismiss,scrollWatch,resizeWatch
 local function cleanup()
  if dismiss then dismiss:Destroy() dismiss=nil end
  if scrollWatch then scrollWatch:Disconnect() scrollWatch=nil end
  if resizeWatch then resizeWatch:Disconnect() resizeWatch=nil end
 end
 local function closeMenu(immediate)
  cleanup()
  if not menu.Parent or (not menu.Visible and not menu:GetAttribute('Open')) then return end
  animateDropdown(menu,false,menu:GetAttribute('PopupHeight') or maximumHeight)
  if immediate then
   local animation=dropdownAnimations[menu] if animation then animation:Cancel() dropdownAnimations[menu]=nil end
   menu.Visible=false menu.GroupTransparency=1 menu:SetAttribute('Open',false)
   local owner=menu.Parent
   if owner and owner:IsA('GuiObject') then
    local another=false for _,child in ipairs(owner:GetChildren()) do if child:IsA('CanvasGroup') and child:GetAttribute('Open') then another=true break end end
    if not another then owner.ZIndex=owner:GetAttribute('DropdownBaseZ') or 1 end
   end
  end
 end
 local function toggleMenu()
  if menu:GetAttribute('Open') then closeMenu() return end
  cleanup()
  local page=anchor:FindFirstAncestorWhichIsA('ScrollingFrame')
  if not page then return end
  local scale=page.Size.X.Offset>0 and page.AbsoluteSize.X/page.Size.X.Offset or 1
  scale=math.max(.01,scale)
  local viewTop=page.CanvasPosition.Y/scale
  local viewHeight=page.AbsoluteWindowSize.Y/scale
  local viewBottom=viewTop+viewHeight
  local anchorY=(anchor.AbsolutePosition.Y-page.AbsolutePosition.Y+page.CanvasPosition.Y)/scale
  local anchorX=(anchor.AbsolutePosition.X-page.AbsolutePosition.X+page.CanvasPosition.X)/scale
  local below=anchorY+anchor.AbsoluteSize.Y/scale+6
  local down=math.max(0,viewBottom-below-8)
  local up=math.max(0,anchorY-viewTop-8)
  local above=down<maximumHeight and up>down
  local height=math.min(maximumHeight,math.max(80,above and up or down),math.max(80,viewHeight-12))
  local top=above and anchorY-height-6 or below
  top=math.clamp(top,viewTop+6,math.max(viewTop+6,viewBottom-height-6))
  menu.Parent=page menu:SetAttribute('ViewportPopup',true)
  menu.Position=UDim2.fromOffset(anchorX,top)
  menu:SetAttribute('RestY',top) menu:SetAttribute('PopupHeight',height)
  if list then
   list.Size=UDim2.new(1,-12,0,math.max(30,height-list.Position.Y.Offset-6))
   list.Active=true list.ScrollingEnabled=true list.ScrollingDirection=Enum.ScrollingDirection.Y
   list.CanvasPosition=Vector2.zero
  end
  dismiss=new('TextButton',{Name=menu.Name..'Dismiss',Text='',BackgroundTransparency=1,AutoButtonColor=false,Size=UDim2.new(1,0,0,math.max(page.CanvasSize.Y.Offset,viewTop+viewHeight)),ZIndex=menu.ZIndex-1},page)
  dismiss:SetAttribute('ViewportPopup',true)
  dismiss.Activated:Connect(function() closeMenu() end)
  animateDropdown(menu,true,height)
  scrollWatch=page:GetPropertyChangedSignal('CanvasPosition'):Connect(function() closeMenu(true) end)
  resizeWatch=page:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() closeMenu(true) end)
 end
 connect(anchor.Destroying,function() closeMenu(true) if menu.Parent then menu:Destroy() end end)
 return toggleMenu,closeMenu
end
local overlay
local menuTween
local activeChevron
local function motionEnabled()
 return not preferences or (not preferences:GetAttribute('ReduceMotion') and preferences:GetAttribute('Smooth')~=false)
end
local function close(immediate)
 if activeChevron and activeChevron.Parent then tween(activeChevron,{Rotation=0}) end
 activeChevron=nil
 if not overlay then return end
 local old=overlay overlay=nil
 if menuTween then menuTween:Cancel() menuTween=nil end
 local menu=old:FindFirstChild('CompactMenu')
 if immediate==true or not motionEnabled() or not menu then old:Destroy() return end
 local outside=old:FindFirstChild('Outside') if outside then outside.Visible=false end
 local t=game:GetService('TweenService'):Create(menu,TweenInfo.new(.14,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Size=UDim2.fromOffset(244,0),GroupTransparency=1})
 t.Completed:Once(function() old:Destroy() end) t:Play()
end
function api.Stop()
 api.Alive=false api.Enabled=false if api.RestoreResultHooks then api.RestoreResultHooks() end if api.RestoreTeamHooks then api.RestoreTeamHooks() end close(true)
 for _,c in ipairs(api.Connections) do c:Disconnect() end
 root:Destroy()
end
label(root,'Title','Auto Join',26,20,396,28,20,true)
local status=label(root,'Status','Select a stage. An empty lobby is chosen automatically.',26,360,402,38,13)
status.TextColor3=muted api.Status=status.Text
local function report(s) api.Status=s status.Text=s end
card('DestinationCard',8,8,438,338)



local function button(name,text,x,y,w,fn,primary)
 local b=new('TextButton',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,40),BackgroundTransparency=.32,BorderSizePixel=0,TextColor3=white,TextSize=15,Font=primary and Enum.Font.GothamBold or Enum.Font.Gotham,AutoButtonColor=false,ZIndex=3},root)
 round(b,8) border(b)
 local function paint(hover) local c=primary and colors.accent:Lerp(colors.card,.62) or colors.field tween(b,{BackgroundColor3=hover and c:Lerp(colors.accent,.15) or c}) end
 bind(b,'BackgroundColor3','field') paint(false)
 connect(b.MouseEnter,function() paint(true) end) connect(b.MouseLeave,function() paint(false) end)
 connect(b.Activated,fn) b:SetAttribute('Primary',primary or false) return b
end
local function picker(title,x,y,options,current,selected)
 local caption=label(root,title..'Label',title,x,y,146,36,15)
 caption.TextColor3=muted
 local b=button('Select_'..title,'',x+158,y,244,function() end)
 b.Size=UDim2.fromOffset(244,36)
 local value=label(b,'Value',current(),12,0,200,36,14,false,4)
 local chevron=new('ImageLabel',{Name='Chevron',BackgroundTransparency=1,Position=UDim2.new(1,-25,.5,-6),Size=UDim2.fromOffset(12,12),Image='rbxassetid://7733717447',ImageColor3=muted,ZIndex=4},b)
 connect(b.Activated,function()
  local y=b.Position.Y.Offset
  if overlay then close() return end
  local all=options() local searchable=#all>12
  local header=searchable and 38 or 0
  local height=math.min(math.max(#all,1),6)*32+12+header
  local ownerPage=b.Parent:IsA('ScrollingFrame') and b.Parent or main
  local viewTop=ownerPage.CanvasPosition.Y local viewBottom=viewTop+441
  local top=y+42 if top+height>viewBottom then top=math.max(viewTop+8,y-height-6) end
  overlay=new('Frame',{Name='SelectionOverlay',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=50},b.Parent)
  local outside=new('TextButton',{Name='Outside',Text='',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=50},overlay)
  outside.Activated:Connect(close)
  local menu=new('CanvasGroup',{Name='CompactMenu',Position=UDim2.fromOffset(b.Position.X.Offset,top),Size=UDim2.fromOffset(244,height),BackgroundColor3=colors.card,BackgroundTransparency=.12,BorderSizePixel=0,ClipsDescendants=true,Active=true,ZIndex=51},overlay)
  round(menu,8) border(menu)
  activeChevron=chevron tween(chevron,{Rotation=180})
  local search
  if searchable then
   search=new('TextBox',{Name='Search',Text='',PlaceholderText='Search…',ClearTextOnFocus=false,Position=UDim2.fromOffset(8,7),Size=UDim2.fromOffset(228,28),BackgroundColor3=colors.field,TextColor3=white,PlaceholderColor3=muted,TextSize=14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,ZIndex=52},menu)
   round(search,6) new('UIPadding',{PaddingLeft=UDim.new(0,8)},search)
  end
  local list=new('ScrollingFrame',{Name='Options',Position=UDim2.fromOffset(6,6+header),Size=UDim2.fromOffset(232,height-12-header),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=colors.accent,ClipsDescendants=true,CanvasSize=UDim2.new(),ZIndex=52},menu)
  local function draw()
   list:ClearAllChildren() local count=0
   for _,entry in ipairs(all) do
    if not search or string.find(string.lower(entry.name),string.lower(search.Text),1,true) then
     local chosen=entry.name==value.Text
     local item=new('TextButton',{Name='Option_'..tostring(entry.id),Text=entry.name,Position=UDim2.fromOffset(2,count*34+2),Size=UDim2.new(1,-10,0,30),BackgroundColor3=colors.field,BackgroundTransparency=chosen and .1 or 1,TextColor3=chosen and colors.accent or white,TextSize=14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,AutoButtonColor=false,BorderSizePixel=0,ZIndex=53},list)
     round(item,5) selectionVisual(item,chosen) new('UIPadding',{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,8)},item)
     item.MouseEnter:Connect(function() tween(item,{BackgroundTransparency=.15}) end)
     item.MouseLeave:Connect(function() tween(item,{BackgroundTransparency=chosen and .1 or 1}) end)
     item.Activated:Connect(function() selected(entry) close() api.Refresh() end)
     count+=1
    end
   end
   list.CanvasSize=UDim2.fromOffset(0,(count*34)+4) list.CanvasPosition=Vector2.zero
  end
  if search then search:GetPropertyChangedSignal('Text'):Connect(draw) end draw()
  if motionEnabled() then
   menu.Size=UDim2.fromOffset(244,0)
   menu.Position=UDim2.fromOffset(b.Position.X.Offset,top-7)
   menu.GroupTransparency=1
   menuTween=game:GetService('TweenService'):Create(menu,TweenInfo.new(.26,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(244,height),Position=UDim2.fromOffset(b.Position.X.Offset,top),GroupTransparency=0})
   menuTween:Play()
  end
 end)
 return {Button=b,Value=value,Label=caption,Set=function(text,visible) value.Text=text b.Visible=visible~=false caption.Visible=visible~=false end}
end

local switchPainters={}
local function switch(name,title,subtitle,y,get,set,x)
 local row=new('TextButton',{Name=name,Text='',Position=UDim2.fromOffset(x or 26,y),Size=UDim2.fromOffset(402,32),BackgroundTransparency=1,AutoButtonColor=false,ZIndex=3},root)
 label(row,'Title',title,0,0,320,32,15,false,4)
 local hint=label(row,'Hint',subtitle,0,22,320,18,12,false,4) hint.TextColor3=muted hint.Visible=false
 local track=new('Frame',{Name='Track',Position=UDim2.fromOffset(346,1),Size=UDim2.fromOffset(54,29),BorderSizePixel=0,ZIndex=4},row) round(track,15)
 local knob=new('Frame',{Name='Knob',Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(21,21),BackgroundColor3=white,BorderSizePixel=0,ZIndex=5},track) round(knob,11)
 local function paint() local on=get() tween(track,{BackgroundColor3=on and colors.accent or colors.line}) tween(knob,{Position=UDim2.fromOffset(on and 29 or 4,4)}) row:SetAttribute('Enabled',on) end
 connect(row.Activated,function() set(not get()) paint() local runtime=env.FyrelithRuntime if runtime and runtime.Alive and runtime.Save then runtime.Save() end end)
 table.insert(switchPainters,paint)
 paint()
 return paint
end

local modes={'Story','Infinite','Legend Stage','Raid','Challenge','Daily Challenge','Event','Maps / Items','Dungeon','Portal','Infinity Mansion','Tournament'}
local paths={Story={'_LOBBIES','Story'},Infinite={'_LOBBIES','Story'},['Legend Stage']={'_LOBBIES','Story'},Raid={'_RAID','Raid'},Challenge={'_CHALLENGES','Challenges'},['Daily Challenge']={'_CHALLENGES','DailyChallenge'},Event={'_EVENT_CHALLENGES','Lobbies'},['Maps / Items']={'_MAPS','Maps'},Dungeon={'_DUNGEONS','Lobbies'},Portal={'_PORTALS','Lobbies'}}
local function entries(values) local o={} for _,v in ipairs(values) do table.insert(o,{id=v,name=v}) end return o end
local function staged() return cfg.Mode=='Story' or cfg.Mode=='Infinite' or cfg.Mode=='Legend Stage' or cfg.Mode=='Raid' end
local function worlds()
 local o={}
 for id,w in pairs(Worlds) do
  local yes=cfg.Mode=='Raid' and w.raid_world or cfg.Mode=='Legend Stage' and w.legend_stage or cfg.Mode=='Infinite' and w.infinite or cfg.Mode=='Story' and not w.raid_world and not w.legend_stage
  if yes then table.insert(o,{id=id,name=w.name or id}) end
 end
 return sortGameWorlds(o)
end
local function stages()
 local o={} local w=Worlds[cfg.World]
 if w then
  if cfg.Mode=='Infinite' then if w.infinite then table.insert(o,{id=w.infinite.id,name='Infinite'}) end
  else for rank,d in pairs(w.levels or {}) do if Levels[d.id] then table.insert(o,{id=d.id,name=Levels[d.id].name or d.id,rank=tonumber(rank) or 999}) end end end
 end
 return sortGameStages(o)
end
local function folder(mode)
 local p=paths[mode or cfg.Mode] if not p then return end
 local a=workspace:FindFirstChild(p[1]) return a and a:FindFirstChild(p[2])
end
local function rooms()
 local o={{id='Auto',name='Auto • first eligible room'}} local f=folder()
 if f then for _,r in ipairs(f:GetChildren()) do if r:FindFirstChild('Players') then
  local lv=r:FindFirstChild('Level') local id=lv and lv.Value or ''
  local name=Levels[id] and Levels[id].name or id
  table.insert(o,{id=r.Name,name=r.Name..' • '..(name~='' and name or 'Empty')..' • '..#r.Players:GetChildren()..' players'})
 end end end return o
end

local mode=picker('Mode',26,64,function() return entries(modes) end,function() return cfg.Mode end,function(v) cfg.Mode=v.id cfg.World=nil cfg.Level=nil end)
local world=picker('World',26,108,worlds,function() return 'Choose world' end,function(v) cfg.World=v.id cfg.Level=nil end)
local stage=picker('Stage',26,152,stages,function() return 'Choose stage' end,function(v) cfg.Level=v.id end)
local difficulty=picker('Difficulty',26,196,function() return entries({'Normal','Hard'}) end,function() return cfg.Difficulty end,function(v) cfg.Difficulty=v.id end)
local floorLabel=label(root,'FloorLabel','Floor',26,108,146,36,15) floorLabel.TextColor3=muted
local floor=new('TextBox',{Name='Floor',BackgroundTransparency=.32,Text='1',ClearTextOnFocus=false,Position=UDim2.fromOffset(184,108),Size=UDim2.fromOffset(244,36),TextColor3=white,Font=Enum.Font.Gotham,TextSize=15,BorderSizePixel=0,ZIndex=3},root)
bind(floor,'BackgroundColor3','field') round(floor,8) border(floor)
connect(floor.FocusLost,function() cfg.Floor=math.max(1,math.floor(tonumber(floor.Text) or 1)) floor.Text=tostring(cfg.Floor) api.Refresh() end)
local modeNote=label(root,'ModeNote','',26,108,402,78,14)
modeNote.TextWrapped=true modeNote.TextTruncate=Enum.TextTruncate.None modeNote.TextYAlignment=Enum.TextYAlignment.Top modeNote.TextColor3=muted
local paintFriends=switch('FriendsOnlySwitch','Friends only','Keep your lobby private.',242,function() return cfg.Friends end,function(value) cfg.Friends=value end)
local paintEnabled=switch('AutoJoinSwitch','Auto Join','Automatically finds an empty lobby.',294,function() return api.Enabled end,function(value) api.Enabled=value report(value and 'Auto Join enabled • finding an empty lobby' or 'Auto Join paused') end)
function api.Refresh()
 local ws=worlds() local found=false for _,v in ipairs(ws) do if v.id==cfg.World then found=true end end if not found then cfg.World=ws[1] and ws[1].id end
 local ss=stages() found=false for _,v in ipairs(ss) do if v.id==cfg.Level then found=true end end if not found then cfg.Level=ss[1] and ss[1].id end
 mode.Set(cfg.Mode) world.Set(Worlds[cfg.World] and Worlds[cfg.World].name or '—',staged()) stage.Set(Levels[cfg.Level] and Levels[cfg.Level].name or '—',staged())
 difficulty.Set(cfg.Difficulty)
 floor.Visible=cfg.Mode=='Infinity Mansion' floorLabel.Visible=floor.Visible
 modeNote.Visible=not staged() and not floor.Visible
 modeNote.Text=(cfg.Mode=='Portal' or cfg.Mode=='Dungeon' or cfg.Mode=='Maps / Items') and 'This mode needs its key or portal item. Set it up in the game first.' or 'The current event stage is assigned by the game. We will find an empty lobby automatically.'
 for _,key in ipairs({'FyrelithMerchant','FyrelithRedeemCodes','FyrelithGoldShop'})do
  local feature=env[key]if feature and feature.Alive and feature.RefreshUI then feature.RefreshUI()end
 end
 paintFriends() paintEnabled() api.Counts={Worlds=#ws,Stages=#ss}
end

local function invoke(name,...)
 local args=table.pack(...) local request={Name=name,Done=false}
 api.PendingRequest=request
 task.spawn(function() request.OK,request.Result=pcall(EP.invoke_server,name,table.unpack(args,1,args.n)) request.Done=true end)
 local deadline=os.clock()+8
 repeat task.wait(.05) until request.Done or not api.Alive or os.clock()>=deadline
 if not request.Done then error('Waiting for server response • '..name,0) end
 api.PendingRequest=nil
 if not request.OK then error(tostring(request.Result),0) end
 if request.Result==false then error('Server declined '..name..' • retrying after checking lobby state',0) end
 return request.Result
end
local function mine(value)
 return value==player or value==player.Name or value==player.UserId or value==tostring(player.UserId)
end
local function member(room)
 local owner=room:FindFirstChild('Owner') if owner and mine(owner.Value) then return true end
 local players=room:FindFirstChild('Players')
 if players then
  if players:FindFirstChild(player.Name) or players:FindFirstChild(tostring(player.UserId)) then return true end
  for _,entry in ipairs(players:GetChildren()) do if entry:IsA('ValueBase') and mine(entry.Value) then return true end end
 end
 return false
end
local lastSpecial=0
function api.Join(modeOverride,expectedChallenge)
 local joinMode=modeOverride or cfg.Mode
 local isStaged=joinMode=='Story' or joinMode=='Infinite' or joinMode=='Legend Stage' or joinMode=='Raid'
 if api.Busy or not api.Alive then return end
 local priority=env.FyrelithAutoChallenge
 if priority and priority.Priority and not priority.Joining then return end
 if api.PendingRequest and not api.PendingRequest.Done then report('Waiting for server response • '..api.PendingRequest.Name) return end
 api.PendingRequest=nil api.Busy=true
 local ok,err=pcall(function()
  if not Loader.IsLobby then report('Waiting until you return to the lobby') return end
  if joinMode=='Infinity Mansion' or joinMode=='Tournament' then
   if os.clock()-lastSpecial<25 then return end lastSpecial=os.clock()
   if api.ApplyTeam then local ok,err=api.ApplyTeam('__'..joinMode,joinMode) if not ok then error(err,0) end end
   if joinMode=='Tournament' then invoke('request_start_tournament') else invoke('request_start_infinite_tower',cfg.Floor,cfg.Difficulty) end
   report('Entry requested • waiting for teleport') return
  end
  if joinMode=='Dungeon' then local dungeon=env.FyrelithDungeon;if dungeon then dungeon.Tick()end;return end
  if joinMode=='Portal' or joinMode=='Maps / Items' then
   report('This mode requires a key or portal item. Set it up in the game first.') return
  end
  local f=folder(joinMode) if not f then error('Lobby area unavailable',0) end
  -- Keep the authoritative room membership in sync; never send repeated joins.
  local own
  for _,r in ipairs(f:GetChildren()) do if member(r) then own=r break end end
  local target=own
  if not target and Lobby.current_lobby then
   local actual
   for _,path in pairs(paths) do local area=workspace:FindFirstChild(path[1]) local group=area and area:FindFirstChild(path[2])
    if group then for _,room in ipairs(group:GetChildren()) do if member(room) then actual=room break end end end
    if actual then break end
   end
   if actual then report('Already in '..actual.Name..' • leave that lobby before changing mode') return end
   -- Client lobby pointers can survive an expired room/countdown; membership is authoritative.
   Lobby.current_lobby=nil Lobby.current_lobby_model=nil
  end
  if not target then
   for _,r in ipairs(f:GetChildren()) do
    local ps=r:FindFirstChild('Players') local owner=r:FindFirstChild('Owner') local active=r:FindFirstChild('Active') local tp=r:FindFirstChild('Teleporting')
    if not (api.LastRejectedRoom==r.Name and os.clock()-(api.LastRejectedAt or 0)<12) and ps and owner and (owner.Value==nil or owner.Value=='' or owner.Value==0) and #ps:GetChildren()==0 and (not tp or not tp.Value) then
     local lv=r:FindFirstChild('Level') local modifier=r:FindFirstChild('Challenge')
     local eventMatches=not api.EventLevel or joinMode~='Event' or (lv and lv.Value==api.EventLevel)
     if eventMatches and (not expectedChallenge or (lv and modifier and lv.Value==expectedChallenge.current_level_id and modifier.Value==expectedChallenge.current_challenge)) then target=r break end
    end
   end
   if not target then report('All lobbies are occupied • waiting for an empty lobby') return end
   if not isStaged and api.ApplyTeam and target:FindFirstChild('Level') and target.Level.Value~='' then
    local teamOK,teamErr=api.ApplyTeam(target.Level.Value,joinMode) if not teamOK then error(teamErr,0) end
   end
   report('Joining '..target.Name..'…')
   invoke('request_join_lobby',target.Name)
   local untilTime=os.clock()+3
   repeat task.wait(.05) until not api.Alive or member(target) or os.clock()>untilTime
   if not api.Alive then return end
   if not member(target) then report('Join not confirmed • checking another empty lobby next') api.LastRejectedRoom=target.Name api.LastRejectedAt=os.clock() return end
   Lobby.current_lobby=target.Name Lobby.current_lobby_model=target
  end
  local owner=target:FindFirstChild('Owner')
  local locked=target:FindFirstChild('Locked')
  if (joinMode=='Challenge' or joinMode=='Daily Challenge') and priority and priority.Joining and priority.EntryMode=='Solo' then
   local players=target:FindFirstChild('Players')
   if not players or #players:GetChildren()~=1 or not member(target) then
    report('Solo challenge room occupied • finding an empty room')
    api.LastRejectedRoom=target.Name;api.LastRejectedAt=os.clock()
    invoke('request_leave_lobby',target.Name)
    if not member(target) then Lobby.current_lobby=nil;Lobby.current_lobby_model=nil end
    return
   end
   local teleporting=target:FindFirstChild('Teleporting')
   if teleporting and teleporting.Value then report('Challenge solo • waiting for teleport');return end
   local needsOwner=target:FindFirstChild('requires_owner')
   local canStart=(needsOwner and needsOwner.Value==false) or (owner and mine(owner.Value))
   if canStart and (api.LastChallengeStartRoom~=target.Name or not api.LastChallengeStartAt or os.clock()-api.LastChallengeStartAt>=10) then
    api.LastChallengeStartRoom=target.Name;api.LastChallengeStartAt=os.clock()
    report('Starting challenge solo…');invoke('request_start_game',target.Name)
   else report('Challenge solo • waiting for start confirmation') end
   return
  end
  if joinMode=='Event' and api.EventSolo then
   local players=target:FindFirstChild('Players')
   if not players or #players:GetChildren()~=1 or not member(target) then
    report('Solo room occupied · leaving and finding an empty room')
    if not api.LastSoloLeaveAt or os.clock()-api.LastSoloLeaveAt>=10 then
     api.LastSoloLeaveAt=os.clock() api.LastRejectedRoom=target.Name api.LastRejectedAt=os.clock()
     invoke('request_leave_lobby',target.Name)
     local untilTime=os.clock()+3
     repeat task.wait(.05) until not api.Alive or not member(target) or os.clock()>untilTime
     if not member(target) then Lobby.current_lobby=nil Lobby.current_lobby_model=nil end
    end
    return
   end
   local needsOwner=target:FindFirstChild('requires_owner')
   local teleporting=target:FindFirstChild('Teleporting')
   if teleporting and teleporting.Value then report('Event solo is starting · waiting for teleport') return end
   local canStart=(needsOwner and needsOwner.Value==false)or(owner and mine(owner.Value))
   if canStart and(api.LastSoloStartRoom~=target.Name or not api.LastSoloStartAt or os.clock()-api.LastSoloStartAt>=10)then
    api.LastSoloStartRoom=target.Name;api.LastSoloStartAt=os.clock()
    report('Starting Event solo…');invoke('request_start_game',target.Name)
   else
    report('Joined Event solo · waiting for start confirmation')
   end
   return
  end
  if isStaged and owner and mine(owner.Value) and (not locked or not locked.Value or target.Level.Value=='') then
   assert(cfg.Level,'Choose a stage first')
   local lv=Levels[cfg.Level] local diff=lv._MATCHMAKING and lv._MATCHMAKING.difficulty or cfg.Difficulty
   invoke('request_lock_level',target.Name,cfg.Level,cfg.Friends,diff)
   Lobby.selected_level=cfg.Level Lobby.difficulty=diff Lobby.friends_only=cfg.Friends
   Lobby.on_request_lock_level()
   if api.ApplyTeam then local ok,err=api.ApplyTeam(cfg.Level,joinMode) if not ok then error(err,0) end end
  end
  if isStaged and owner and mine(owner.Value) and target:FindFirstChild('Level') and target.Level.Value~='' then
   if not api.LastStartAt or os.clock()-api.LastStartAt>=10 then
    api.LastStartAt=os.clock() report('Starting '..target.Name..'…') invoke('request_start_game',target.Name)
   end
  end
  report('Joined '..target.Name..' • waiting for the lobby countdown')
 end)
 api.Busy=false if not ok then report(tostring(err)) end
end

local function themeChanged()
 colors=palette() close()
 for _,v in ipairs(bindings) do if v[1].Parent then v[1][v[2]]=colors[v[3]] end end
 for _,b in ipairs(gui:QueryDescendants('TextButton')) do if b:GetAttribute('Primary') then b.BackgroundColor3=colors.accent:Lerp(colors.card,.62) end end
 for _,paint in ipairs(switchPainters) do paint() end
 for _,scroll in ipairs(gui:QueryDescendants('ScrollingFrame'))do scroll.ScrollBarImageColor3=colors.accent end
 local team=env.FyrelithTeamControl
 if team and team.Alive and team.PaintAutomation then team.PaintAutomation()end
 paintFriends() paintEnabled()
end
if preferences then connect(preferences.AttributeChanged,themeChanged) end
connect(gui:GetAttributeChangedSignal('PaletteRevision'),themeChanged)
connect(main:GetPropertyChangedSignal('Visible'),function()if main.Visible then for _,paint in ipairs(switchPainters)do paint()end end end)
connect(gui.DescendantAdded,function(obj)if obj:IsA('ScrollingFrame')then obj.ScrollBarImageColor3=colors.accent end end)
local queued=false
local function scheduleTheme()
 if queued or not api.Alive then return end queued=true
 task.delay(.04,function()
  queued=false if not api.Alive then return end
  themeChanged()
  ui('DestinationCard').BackgroundTransparency=.06

 end)
end
connect(appearance:GetPropertyChangedSignal('BackgroundColor3'),scheduleTheme)
connect(appearance:GetPropertyChangedSignal('BackgroundTransparency'),scheduleTheme)
connect(themeField:GetPropertyChangedSignal('BackgroundColor3'),scheduleTheme)
connect(accentIcon:GetPropertyChangedSignal('ImageColor3'),scheduleTheme)
if hostStroke then connect(hostStroke:GetPropertyChangedSignal('Color'),scheduleTheme) end
connect(gui.Destroying,api.Stop)
do
 local idle=env.FyrelithAntiAFK
 if idle then connect(gui.Destroying,function() idle.Stop() end)end
end
api.Refresh()
task.spawn(function() while api.Alive and root.Parent do if api.Enabled and api.Ready then api.Join() end task.wait(1) end end)







do
 local old=env.FyrelithRedeemCodes
 local results=old and old.Results or {}
 if old then old.Stop() end
 local redeem={Alive=true,Enabled=false,Busy=false,Results=results,Connections={}}
 env.FyrelithRedeemCodes=redeem
 local codes={'AACOMEBACK','DUNGEONS','UPDATESOON5189','APRILFOOLS','MILLIONFAVES','2BILLIONAA'}
 local utility=main.Parent:WaitForChild('Utilities')
 local panel=new('Frame',{Name='AutoRedeemCodes',Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(438,72),BorderSizePixel=0},utility)
 round(panel,11) border(panel)
 
 
 local toggle=new('TextButton',{Name='AutoRedeemSwitch',Text='',Position=UDim2.fromOffset(18,14),Size=UDim2.fromOffset(402,43),BackgroundTransparency=1,AutoButtonColor=false},panel)
 label(toggle,'Title','Auto Redeem Codes',0,0,315,43,15)
 
 local track=new('Frame',{Name='Track',Position=UDim2.fromOffset(346,7),Size=UDim2.fromOffset(54,29),BorderSizePixel=0,ZIndex=4},toggle) round(track,15)
 local knob=new('Frame',{Name='Knob',Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(21,21),BackgroundColor3=white,BorderSizePixel=0,ZIndex=5},track) round(knob,11)
 local function on(signal,fn) table.insert(redeem.Connections,signal:Connect(fn)) end
 local function paint()
  local p=palette() panel.BackgroundColor3=p.card panel.BackgroundTransparency=math.max(.38,p.transparency)
  tween(track,{BackgroundColor3=redeem.Enabled and p.accent or p.line})
  tween(knob,{Position=UDim2.fromOffset(redeem.Enabled and 29 or 4,4)})
  toggle:SetAttribute('Enabled',redeem.Enabled)

 end
 redeem.RefreshUI=paint
 function redeem.Stop()
  redeem.Alive=false redeem.Enabled=false
  for _,c in ipairs(redeem.Connections) do c:Disconnect() end
  panel:Destroy()
 end
 function redeem.Run()
  if redeem.Busy or not redeem.Alive or not redeem.Enabled then return end
  redeem.Busy=true
  for _,code in ipairs(codes) do
   if not redeem.Alive or not redeem.Enabled then break end
   if not results[code] then

    local ok,value=pcall(EP.invoke_server,'redeem_code',code)
    if not redeem.Alive then break end
    if ok then
     results[code]={label=value==true and 'Redeemed' or 'Not accepted',response=tostring(value)}
    else
     results[code]={label='Request error',response=tostring(value)}
    end
    paint() task.wait(.7)
   end
  end
  redeem.Busy=false
  if redeem.Alive then
   local n=0 for _,code in ipairs(codes) do if results[code] then n+=1 end end

  end
 end
 on(toggle.Activated,function()
  redeem.Enabled=not redeem.Enabled paint()
  if redeem.Enabled then task.spawn(redeem.Run) end
 end)
 on(appearance:GetPropertyChangedSignal('BackgroundColor3'),paint)
 on(appearance:GetPropertyChangedSignal('BackgroundTransparency'),paint)
 on(accentIcon:GetPropertyChangedSignal('ImageColor3'),paint)
 if hostStroke then on(hostStroke:GetPropertyChangedSignal('Color'),paint) end
 on(gui.Destroying,redeem.Stop)
 paint()
end




-- Saved team selection and per-stage overrides.
do
 local U=Loader.load_client_service(script,'UnitCollectionServiceClient')
 local Http=game:GetService('HttpService')
 local key='FyrelithTeamSettings_'..player.UserId..'_'..game.GameId..'.json'
 local state={Enabled=false,Default='current',Rules={},Snapshots={}}
 local memory=preferences and preferences:GetAttribute('TeamSettings')
 local ok,data=pcall(function()
  if type(readfile)=='function' and type(isfile)=='function' and isfile(key) then return Http:JSONDecode(readfile(key)) end
  if memory then return Http:JSONDecode(memory) end
 end)
 if ok and type(data)=='table' then
  state.Enabled=data.Enabled==true
  state.Snapshots=type(data.Snapshots)=='table' and data.Snapshots or {}
  state.Default=type(data.Default)=='string' and data.Default or 'current'
  if type(data.Rules)=='table' then for id,slot in pairs(data.Rules) do if type(id)=='string' and type(slot)=='string' then state.Rules[id]=slot end end end
 end
 api.TeamSettings=state
 local applied
 local refreshRules
 local function save()
  applied=nil
  local encoded=Http:JSONEncode(state)
  if preferences then preferences:SetAttribute('TeamSettings',encoded) end
  local saved,saveError=false,'File saving unavailable'
  if type(writefile)=='function' then saved,saveError=pcall(writefile,key,encoded)end
  api.TeamSaveError=not saved and tostring(saveError)or nil
  if refreshRules then refreshRules() end
  return saved
 end
 local modeNames={'Story','Infinite','Legend Stage','Raid','Challenge','Daily Challenge','Event','Summer Hunt','Maps / Items','Dungeon','Portal','Infinity Mansion','Tournament'}
 local slotOrder=Loader.load_data(script,'GameplaySettings').UNIT_SLOTS
 local function slotValue(slots,index)return slots[tostring(index)] or slots[index]end
 local function snapshotFor(id)return state.Snapshots and state.Snapshots[id]end
 function api.SaveModeTeam(mode)
  if not table.find(modeNames,mode)then return false,'Choose a valid mode' end
  local equipped=U.session.collection.collection_profile_data.equipped_units
  local copy={};local count=0
  for _,slot in ipairs(slotOrder)do
   local uuid=slotValue(equipped,slot)
   if type(uuid)=='string' and uuid~=''then
    if not U.session.collection:get_unit_by_uuid(uuid)then return false,'Equipped unit data unavailable' end
    copy[tostring(slot)]=uuid;count+=1
   end
  end
  if count==0 then return false,'Equip units before saving slots' end
  local id='snapshot:'..mode
  local oldSnapshot=state.Snapshots[id];local oldRule=state.Rules['mode:'..mode]
  state.Snapshots[id]={name=mode..' slots',saved_equipped=copy}
  state.Rules['mode:'..mode]=id
  if save()==false then
   state.Snapshots[id]=oldSnapshot;state.Rules['mode:'..mode]=oldRule
   return false,'Could not save slots • '..tostring(api.TeamSaveError)
  end
  return true,'Saved '..mode..' • '..count..' slots'
 end
 local function applySnapshot(snapshot)
  if not Loader.IsLobby then return false,'Teams must be equipped in the lobby before entering a battle' end
  local target=snapshot.saved_equipped
  if type(target)~='table' or not next(target)then return false,'Saved slots are empty' end
  local present={}
  for _,slot in ipairs(slotOrder)do
   local uuid=slotValue(target,slot)
   if uuid then
    if present[uuid] or not U.session.collection:get_unit_by_uuid(uuid)then return false,'Saved unit missing or duplicated • save this mode again' end
    present[uuid]=true
   end
  end
  local function current()return U.session.collection.collection_profile_data.equipped_units end
  local function matches()
   for _,slot in ipairs(slotOrder)do if slotValue(current(),slot)~=slotValue(target,slot)then return false end end
   return true
  end
  if matches()then return true end
  -- Clear changed slots first so units can move between slots without duplicates.
  local remove={}
  for _,slot in ipairs(slotOrder)do local uuid=slotValue(current(),slot)
   if uuid and uuid~=slotValue(target,slot)then remove[#remove+1]=uuid end
  end
  for _,uuid in ipairs(remove)do
   if not api.Alive then return false,'Team equip cancelled' end
   local ok,result=pcall(EP.invoke_server,'unequip_unit',uuid)
   if not ok or result==false then return false,'Could not clear changed team slots' end
  end
  for _,slot in ipairs(slotOrder)do local uuid=slotValue(target,slot)
   if uuid and slotValue(current(),slot)~=uuid then
    if not api.Alive then return false,'Team equip cancelled' end
    local ok,result=pcall(EP.invoke_server,'equip_unit',uuid,slot)
    if not ok or result==false then return false,'Could not equip saved slot '..tostring(slot) end
   end
  end
  local deadline=os.clock()+3
  repeat task.wait(.1)until not api.Alive or matches()or os.clock()>deadline
  return matches(),matches()and nil or 'Saved slot equip was not confirmed • retrying'
 end
 api.ApplyTeamSnapshot=applySnapshot

 local function loadouts() return U.session.profile_data.loadouts_v2 or {} end
 local function teamName(id)
  if id=='current' then return 'Keep current team' end
  if id=='inherit' then return 'Use default team' end
  local t=snapshotFor(id) or loadouts()[id]
  return t and ((t.name and t.name~='' and t.name) or 'Team '..id) or 'Team '..id..' (not saved)'
 end
 local function choices(inherit)
  local out={{id=inherit and 'inherit' or 'current',name=inherit and 'Use default team' or 'Keep current team'}}
  if inherit then table.insert(out,{id='current',name='Keep current team'}) end
  for i=1,6 do local id=tostring(i) local t=loadouts()[id]
   if t and type(t.saved_equipped)=='table' and next(t.saved_equipped) then table.insert(out,{id=id,name=teamName(id)}) end
  end
  return out
 end
 local editor={Mode='Story',World=nil,Level=nil,Team='current',Floor=1}
 api.TeamRuleEditor=editor
 local standard={}
 for wid,w in pairs(Worlds) do
  local kind=w.raid_world and 'Raid' or w.legend_stage and 'Legend Stage' or 'Story'
  for _,v in pairs(w.levels or {}) do standard[v.id]={Mode=kind,World=wid} end
  if w.infinite then standard[w.infinite.id]={Mode='Infinite',World=wid} end
 end
 local Maps=Loader.load_data(script,'Maps')
 local function category(id,d)
  if standard[id] then return standard[id].Mode end
  if d._portal_only_level or d.portal_group then return 'Portal' end
  if d._gamemode=='infinite_tower' then return 'Infinity Mansion' end
  if id:lower():find('dungeon',1,true) or d._gamemode=='dungeon' then return 'Dungeon' end
  return 'Event'
 end
 local function catalogue(mode)
  local out={}
  for id,d in pairs(Levels) do
   local kind=category(id,d)
   local yes=mode==kind or mode=='All stages' or mode=='Challenge' or mode=='Daily Challenge' or mode=='Maps / Items'
   -- Event selection also includes seasonal / portal variants used by events.
   if mode=='Event' and not standard[id] then yes=true end
   if yes and not id:lower():find('test',1,true) then
    local w=standard[id] and standard[id].World or d.world or d.map or 'Other'
    table.insert(out,{id=id,world=w,name=d.name or id})
   end
  end
  -- Fixed lobby stages may be added or rotated independently of the catalogue.
  local path=paths[mode] local f=path and workspace:FindFirstChild(path[1]) f=f and f:FindFirstChild(path[2])
  if f then for _,r in ipairs(f:GetChildren()) do local lv=r:FindFirstChild('Level')
   if lv and Levels[lv.Value] then local exists=false for _,v in ipairs(out) do if v.id==lv.Value then exists=true break end end
    if not exists then local d=Levels[lv.Value] table.insert(out,{id=lv.Value,world=d.world or d.map or 'Other',name=d.name or lv.Value}) end
   end
  end end
  return out
 end
 local function worldName(id) return Worlds[id] and Worlds[id].name or Maps[id] and Maps[id].name or id end
 local function ruleWorlds()
  local seen={} local out={}
  for _,v in ipairs(catalogue(editor.Mode)) do if not seen[v.world] then seen[v.world]=true table.insert(out,{id=v.world,name=worldName(v.world),source=#out+1}) end end
  return sortGameWorlds(out)
 end
 local function ruleStages()
  if editor.Mode=='Infinity Mansion' then local out={} for i=1,1000 do table.insert(out,{id='floor:'..i,name='Floor '..i}) end return out end
  if editor.Mode=='Tournament' then return {{id='tournament',name='Tournament'}} end
  local out={}
  for _,v in ipairs(catalogue(editor.Mode)) do if v.world==editor.World then table.insert(out,{id=v.id,name=v.name}) end end
  return sortGameStages(out)
 end
 local function levelId(value,depth)
  depth=depth or 0 if depth>3 then return nil end
  if type(value)=='string' then return value~='' and value or nil end
  if typeof(value)=='Instance' and value:IsA('ValueBase') then return levelId(value.Value,depth+1) end
  if type(value)=='table' then return levelId(value.id or value.level_id or value.level or value.Level,depth+1) end
  return nil
 end
 local function ruleKey(mode,level)
  level=levelId(level)
  if type(mode)~='string' or not level then return nil end
  return 'rule|'..mode..'|'..level
 end
 local function currentKey() return editor.Level and ruleKey(editor.Mode,editor.Level) end
 main.CanvasSize=UDim2.fromOffset(0,662) root.Size=UDim2.fromOffset(908,662)
 card('TeamSettingsCard',462,8,438,390)
 label(root,'TeamTitle','Mode → Team Slots',480,20,402,28,20,true)
 local selectMode=picker('Rule mode',480,64,function()return entries(modeNames)end,function()return editor.Mode end,function(v)editor.Mode=v.id;api.Refresh()end)
 local paintTeam=switch('AutoTeamSwitch','Auto Equip Team','',116,function()return state.Enabled end,function(v)state.Enabled=v;save()end,480)
 local add=button('SaveTeamRule','Save Current Slots',480,166,402,function()
  local ok,message=api.SaveModeTeam(editor.Mode);report(message);api.Refresh()
 end,true)
 local note=label(root,'TeamNote','',480,216,402,40,12);note.TextWrapped=true
 card('TeamAssignmentsCard',462,270,438,360)
 label(root,'AssignmentsTitle','Saved teams by mode',480,282,402,25,17,true)
 local list=new('ScrollingFrame',{Name='TeamAssignments',Position=UDim2.fromOffset(480,318),Size=UDim2.fromOffset(402,300),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=colors.accent,CanvasSize=UDim2.new(),ClipsDescendants=true,ZIndex=3},root)
 local function ruleName(id)
  local mode,level=id:match('^rule|([^|]+)|(.+)$')
  if mode then
   local d=Levels[level] local w=d and (Worlds[d.world] or Maps[d.map])
   return mode..' • '..(w and w.name..' • ' or '')..(d and d.name or level)
  end
  if id:sub(1,5)=='mode:' then return id:sub(6) end
  local d=Levels[id] return d and d.name or id
 end
 local PortraitGUI=Loader.load_client_service(script,'GUIService')
 local UnitData=Loader.load_data(script,'Units')
 local unitSlots=Loader.load_data(script,'GameplaySettings').UNIT_SLOTS
 local function teamPortraits(parent,slot)
  local saved=snapshotFor(slot) or loadouts()[slot] local equipped=saved and saved.saved_equipped
  if not equipped then return end
  local count=0
  for _,index in ipairs(unitSlots) do
   local uuid=slotValue(equipped,index)
   local unit=uuid and U.session.collection:get_unit_by_uuid(uuid)
   if unit then
    local holder=new('Frame',{Name='TeamUnit_'..tostring(index),Position=UDim2.fromOffset(12+count*46,53),Size=UDim2.fromOffset(38,38),BackgroundColor3=colors.card,BackgroundTransparency=.2,BorderSizePixel=0,ZIndex=6},parent)
    round(holder,8)
    local outline=new('UIStroke',{Thickness=1,Transparency=.3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},holder)
    local rarity=UnitData[unit.unit_id] and UnitData[unit.unit_id].rarity
    outline.Color=rarity=='Mythic' and Color3.fromRGB(181,132,249) or rarity=='Secret' and Color3.fromRGB(244,141,177) or colors.line
    local ok,frame=pcall(function() if hasUnitPortrait(unit.unit_id) then return PortraitGUI.make_unit_frame(unit.unit_id,unit.xp or 0,nil,nil,true,{hide_extra_info=true}) end end)
    if ok and frame then
     local view=frame:FindFirstChild('View',true)
     if view then
      view.Parent=holder view.Name='Portrait' view.AnchorPoint=Vector2.zero view.Position=UDim2.fromOffset(1,1) view.Size=UDim2.fromOffset(36,36) view.BackgroundTransparency=1 view.Visible=true view.Active=false view.ZIndex=7
      local model=view:FindFirstChildWhichIsA('Model')
      if model then
       local head=model:FindFirstChild('Head',true) local cf,size=model:GetBoundingBox()
       local target=head and head.Position or cf.Position local direction=head and head.CFrame.LookVector or Vector3.new(0,0,-1)
       local camera=Instance.new('Camera') camera.FieldOfView=35 camera.CFrame=CFrame.lookAt(target+direction*(head and 3.5 or math.max(size.X,size.Y,size.Z)*1.4),target) camera.Parent=view view.CurrentCamera=camera
      end
     end
     frame:Destroy()
    end
    if unit.shiny then local shine=label(holder,'Shiny','✦',25,-2,13,14,12,true,8) shine.TextColor3=Color3.fromRGB(255,215,100) end
    count+=1
   end
  end
 end

 refreshRules=function()
  list:ClearAllChildren() local ids={} for id in pairs(state.Rules) do if id:sub(1,5)=='mode:' then table.insert(ids,id)end end table.sort(ids)
  if #ids==0 then local empty=label(list,'Empty','Equip your units, choose a mode, then Save Current Slots.',0,0,390,60,13) empty.TextWrapped=true empty.TextColor3=muted end
  for i,id in ipairs(ids) do
   local row=new('Frame',{Name='Rule_'..i,Position=UDim2.fromOffset(0,(i-1)*104),Size=UDim2.fromOffset(390,98),BackgroundColor3=colors.field,BackgroundTransparency=.32,BorderSizePixel=0,ZIndex=4},list) round(row,10) bind(row,'BackgroundColor3','field')
   local edit=new('TextButton',{Name='Edit',Text='',Size=UDim2.new(1,-42,1,0),BackgroundTransparency=1,ZIndex=5},row)
   label(edit,'Stage',ruleName(id),12,6,324,23,13,true,6)
   local t=label(edit,'Team',teamName(state.Rules[id]),12,29,324,20,13,false,6) bind(t,'TextColor3','accent')
   teamPortraits(edit,state.Rules[id])
   edit.Activated:Connect(function()
    local mode=id:match('^mode:(.+)$');local level
    if mode then editor.Mode=mode;api.Refresh();return end
    mode,level=id:match('^rule|([^|]+)|(.+)$')
    if mode then editor.Mode=mode editor.Level=level
     local d=Levels[level] editor.World=standard[level] and standard[level].World or d and (d.world or d.map) or nil
     editor.Team=state.Rules[id] api.Refresh() main.CanvasPosition=Vector2.zero
    end
   end)
   local remove=new('TextButton',{Name='Remove',Text='×',Position=UDim2.fromOffset(350,13),Size=UDim2.fromOffset(32,32),BackgroundTransparency=1,TextColor3=white,TextSize=22,ZIndex=6},row)
   remove.Activated:Connect(function() state.Rules[id]=nil save() api.Refresh() end)
  end
  list.CanvasSize=UDim2.fromOffset(0,#ids*104)
 end
 local refresh=api.Refresh
 function api.Refresh()
  refresh()
  selectMode.Set(editor.Mode)
  note.Text='Save equipped slots separately for each mode.'
  paintTeam() refreshRules()
 end
 function api.RuleCatalogue(mode) return catalogue(mode) end
 function api.DetectTeamMode(level)
  local data=type(level)=='table' and level or (not Loader.IsLobby and Loader.LevelData)
  if type(data)=='table' then
   if type(data._dungeon)=='table'then return 'Dungeon' end
   if data._gamemode=='challenge' then return (data._is_daily_challenge or data.id=='__DAILY_CHALLENGE')and 'Daily Challenge' or 'Challenge' end
   if data.id=='summer2_event' then return 'Summer Hunt' end
   if data._event_contract then return 'Assassin Contracts' end
  end
  level=levelId(level)
  local room=Lobby.current_lobby_model
  if room then for mode,path in pairs(paths) do
   local p=workspace:FindFirstChild(path[1]) local f=p and p:FindFirstChild(path[2])
   if f and room.Parent==f then if mode=='Story' and standard[level] then return standard[level].Mode end return mode end
  end end
  return Levels[level] and category(level,Levels[level]) or cfg.Mode
 end
 function api.ResolveTeam(level,mode)
  level=levelId(level)
  if type(mode)=='table' then mode=mode.id or mode.Mode end
  if type(mode)~='string' or not table.find(modeNames,mode) then mode=api.DetectTeamMode(level) end
  if level=='summer2_event' then mode='Summer Hunt' end
  return state.Rules['mode:'..mode] or 'current'
 end

 function api.ApplyTeam(level,mode)
  if not state.Enabled then return true end
  local slot=api.ResolveTeam(level,mode)
  if slot=='current' then return true end
  local snapshot=snapshotFor(slot)
  if snapshot then local ok,message=applySnapshot(snapshot);if ok then applied=slot end;return ok,message end
  local t=loadouts()[slot]
  if not t or type(t.saved_equipped)~='table' or not next(t.saved_equipped) then return false,'Assigned team is empty or no longer saved' end
  if not Loader.IsLobby then return false,'Return to the lobby: teams must be equipped before entering a battle' end
  local equipped=U.session.collection.collection_profile_data.equipped_units
  local function matches()
   for k,v in pairs(t.saved_equipped) do if equipped[k]~=v then return false end end
   for k,v in pairs(equipped) do if v~=nil and t.saved_equipped[k]~=v then return false end end
   return true
  end
  if matches() then applied=slot return true end
  local ok,result=pcall(EP.invoke_server,'load_team_loadout',slot)
  if not ok or result==false then return false,'Could not equip '..teamName(slot) end
  local deadline=os.clock()+2
  repeat task.wait(.1) equipped=U.session.collection.collection_profile_data.equipped_units until not api.Alive or matches() or os.clock()>deadline
  if not matches() then return false,'Team change was not confirmed • check team slots and units' end
  applied=slot return true
 end
 -- Equip the matched saved loadout before either the game UI or Auto Join
 -- sends a start/lock request. Loadouts cannot be replaced after battle starts.
 local originalInvoke=EP.invoke_server
 local applying=false
 local function roomFor(name)
  for mode,path in pairs(paths) do
   local p=workspace:FindFirstChild(path[1]) local f=p and p:FindFirstChild(path[2])
   local room=f and f:FindFirstChild(tostring(name))
   if room then return room,mode end
  end
 end
 local function beforeStart(endpoint,...)
  if not applying and state.Enabled and Loader.IsLobby then
   local args=table.pack(...) local level,mode
   if endpoint=='request_lock_level' then
    level=args[2] mode=level and api.DetectTeamMode(level)
    local room,kind=roomFor(args[1]) if kind and kind~='Story' then mode=kind end
   elseif endpoint=='request_start_game' then
    local room,kind=roomFor(args[1] or Lobby.current_lobby)
    local lv=room and room:FindFirstChild('Level') level=lv and lv.Value~='' and lv.Value or Lobby.selected_level
    mode=kind=='Story' and level and api.DetectTeamMode(level) or kind
   elseif endpoint=='request_join_lobby' then
    local room,kind=roomFor(args[1]) local lv=room and room:FindFirstChild('Level')
    if lv and lv.Value~='' then level=lv.Value mode=kind end
   elseif endpoint=='request_matchmaking' then
    level=args[1]
    mode=level=='__NORMAL_CHALLENGE' and 'Challenge' or level=='__DAILY_CHALLENGE' and 'Daily Challenge' or level=='summer2_event' and 'Summer Hunt' or api.DetectTeamMode(level)
   elseif endpoint=='request_start_infinite_tower' then level='floor:'..tostring(args[1]) mode='Infinity Mansion'
   elseif endpoint=='request_start_tournament' then level='tournament' mode='Tournament' end
   if level then
    applying=true
    local callOK,equipped,message=pcall(api.ApplyTeam,level,mode)
    applying=false
    if not callOK or not equipped then
     report(callOK and message or tostring(equipped))
     api.TeamStatus={ok=false,level=level,error=callOK and message or tostring(equipped)}
     return false
    end
    api.TeamStatus={ok=true,level=level,team=api.ResolveTeam(level,mode)}
   end
  end
  return originalInvoke(endpoint,...)
 end
 EP.invoke_server=beforeStart
 api.RestoreTeamHooks=function() if EP.invoke_server==beforeStart then EP.invoke_server=originalInvoke end end

 connect(accentIcon:GetPropertyChangedSignal('ImageColor3'),paintTeam)
 if hostStroke then connect(hostStroke:GetPropertyChangedSignal('Color'),paintTeam) end
 connect(appearance:GetPropertyChangedSignal('BackgroundColor3'),function() ui('TeamSettingsCard').BackgroundTransparency=math.max(.38,appearance.BackgroundTransparency) ui('TeamAssignmentsCard').BackgroundTransparency=math.max(.38,appearance.BackgroundTransparency) end)
 api.Refresh()
 task.spawn(function()
  while api.Alive and root.Parent do
   if state.Enabled and Loader.IsLobby and not api.Busy then
    local room=Lobby.current_lobby_model local lv=room and room:FindFirstChild('Level')
    local level=lv and lv.Value~='' and lv.Value or Lobby.selected_level
    if level then local slot=api.ResolveTeam(level) if slot~='current' and slot~=applied then
     api.Busy=true local ok,err=api.ApplyTeam(level) api.Busy=false if not ok then report(err) end
    end end
   end
   task.wait(2)
  end
 end)
end







do
 if env.FyrelithGoldShop then env.FyrelithGoldShop.Stop() end
 local shop=Loader.load_client_service(script,'GoldShopServiceClient')
 local items=Loader.load_data(script,'Items')
 local Http=game:GetService('HttpService')
 local storageKey='FyrelithGoldShop_'..player.UserId..'_'..game.GameId..'.json'
 local selected={}
 pcall(function()
  local raw=preferences and preferences:GetAttribute('GoldShopSelection')
  if type(isfile)=='function' and type(readfile)=='function' and isfile(storageKey) then raw=readfile(storageKey) end
  if raw then local d=Http:JSONDecode(raw) if type(d)=='table' then for id,v in pairs(d) do if type(id)=='string' and v==true then selected[id]=true end end end end
 end)
 local auto={Alive=true,Enabled=false,Busy=false,Selected=selected,Connections={},Purchases=0,NextDelay=0}
 env.FyrelithGoldShop=auto
 local utility=main.Parent.Utilities
 local panel=new('Frame',{Name='AutoBuyGoldShop',Position=UDim2.fromOffset(8,92),Size=UDim2.fromOffset(438,246),BorderSizePixel=0},utility)
 round(panel,11) border(panel)
 label(panel,'Title','Gold Shop',18,14,402,28,19,true)
 local info=label(panel,'Info','Buy only your selected items.',18,45,402,22,13) info.TextColor3=muted
 local select=new('TextButton',{Name='SelectItems',Text='',Position=UDim2.fromOffset(18,82),Size=UDim2.fromOffset(402,36),BackgroundTransparency=.32,BorderSizePixel=0,AutoButtonColor=false},panel)
 round(select,8) border(select)
 local summary=label(select,'Value','Choose items…',12,0,350,36,14,false,4)
 local arrow=new('ImageLabel',{Name='Chevron',Position=UDim2.new(1,-25,.5,-6),Size=UDim2.fromOffset(12,12),BackgroundTransparency=1,Image='rbxassetid://7733717447',ImageColor3=muted,ZIndex=4},select)
 local toggle=new('TextButton',{Name='AutoBuySwitch',Text='',Position=UDim2.fromOffset(18,140),Size=UDim2.fromOffset(402,44),BackgroundTransparency=1,AutoButtonColor=false},panel)
 label(toggle,'Title','Auto Buy Gold Shop',0,0,320,24,15)
 local hint=label(toggle,'Hint','Buys selected items continuously.',0,24,320,18,12) hint.TextColor3=muted
 local track=new('Frame',{Name='Track',Position=UDim2.fromOffset(346,7),Size=UDim2.fromOffset(54,29),BorderSizePixel=0,ZIndex=4},toggle) round(track,15)
 local knob=new('Frame',{Name='Knob',Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(21,21),BackgroundColor3=white,BorderSizePixel=0,ZIndex=5},track) round(knob,11)
 local status=label(panel,'Status','Select items, then enable Auto Buy.',18,202,402,28,13) status.TextColor3=muted
 local menuOverlay
 local function on(signal,fn) table.insert(auto.Connections,signal:Connect(fn)) end
 local function hideMenu() if menuOverlay then menuOverlay:Destroy() menuOverlay=nil end tween(arrow,{Rotation=0}) end
 local function paint()
  local p=palette() panel.BackgroundColor3=p.card panel.BackgroundTransparency=math.max(.38,p.transparency) select.BackgroundColor3=p.field
  tween(track,{BackgroundColor3=auto.Enabled and p.accent or p.line}) tween(knob,{Position=UDim2.fromOffset(auto.Enabled and 29 or 4,4)}) toggle:SetAttribute('Enabled',auto.Enabled)
  local n=0 for _ in pairs(selected) do n+=1 end summary.Text=n==0 and 'Choose items…' or n..' items selected'
 end
 local function save()
  local encoded=Http:JSONEncode(selected)
  if preferences then preferences:SetAttribute('GoldShopSelection',encoded) end
  if type(writefile)=='function' then pcall(writefile,storageKey,encoded) end
 end
 local function available(uuid,d)
  local bought=shop.session.profile_data.gold_shop_data
  bought=bought and bought.bought_items or {}
  return d.stock=='inf' and math.huge or math.max(0,(tonumber(d.stock) or 0)-(tonumber(bought[uuid]) or 0))
 end
 local function name(id) return items[id] and items[id].name or id end
 local GameGUI=Loader.load_client_service(script,'GUIService')
 local function itemIcon(parent,id)
  local holder=new('Frame',{Name='ItemIcon',Position=UDim2.fromOffset(6,4),Size=UDim2.fromOffset(30,30),BackgroundColor3=palette().field,BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=54},parent)
  round(holder,6)
  local ok,frame=pcall(GameGUI.make_item_frame,id)
  if ok and frame then
   local viewport=frame:FindFirstChild('View',true)
   local image=frame:FindFirstChild('icon',true)
   local visual=viewport
   if image and image:IsA('ImageLabel') and image.Image~='' then visual=image end
   if visual and visual:IsA('GuiObject') then
    visual.Parent=holder visual.Name='Visual' visual.AnchorPoint=Vector2.zero visual.Position=UDim2.fromOffset(2,2) visual.Size=UDim2.fromOffset(26,26)
    visual.BackgroundTransparency=1 visual.Visible=true visual.Active=false visual.ZIndex=55
    if visual:IsA('ImageLabel') then visual.ScaleType=Enum.ScaleType.Fit end
   end
   frame:Destroy()
  end
  local ring=new('UIStroke',{Name='SelectedBorder',Color=palette().accent,Thickness=1.5,Transparency=selected[id] and 0 or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},holder)
  return ring
 end

 on(select.Activated,function()
  if menuOverlay then hideMenu() return end
  local p=palette()
  menuOverlay=new('Frame',{Name='GoldShopItemPicker',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=50},utility)
  local outside=new('TextButton',{Name='Outside',Text='',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=50},menuOverlay) outside.Activated:Connect(hideMenu)
  local menu=new('CanvasGroup',{Name='Menu',Position=UDim2.fromOffset(26,216),Size=UDim2.fromOffset(402,182),BackgroundColor3=p.card,BackgroundTransparency=.12,BorderSizePixel=0,ClipsDescendants=true,ZIndex=51},menuOverlay) round(menu,8) border(menu)
  local search=new('TextBox',{Name='Search',Text='',PlaceholderText='Search items…',ClearTextOnFocus=false,Position=UDim2.fromOffset(8,7),Size=UDim2.fromOffset(386,28),BackgroundColor3=p.field,BackgroundTransparency=.25,TextColor3=white,PlaceholderColor3=muted,TextSize=14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,ZIndex=52},menu)
  round(search,6) new('UIPadding',{PaddingLeft=UDim.new(0,10)},search)
  local list=new('ScrollingFrame',{Name='Items',Position=UDim2.fromOffset(6,43),Size=UDim2.fromOffset(390,133),CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=p.accent,BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ZIndex=52},menu)
  local catalogue={} local seen={}
  for uuid,d in pairs(shop.shop_items_for_sale or {}) do if not seen[d.id] then seen[d.id]=true table.insert(catalogue,{id=d.id,uuid=uuid,data=d}) end end
  for id in pairs(selected) do if not seen[id] then table.insert(catalogue,{id=id}) end end
  table.sort(catalogue,function(a,b) return name(a.id)<name(b.id) end)
  for i,v in ipairs(catalogue) do
   local row=new('TextButton',{Name='Item_'..v.id,Text='',Position=UDim2.fromOffset(0,(i-1)*40),Size=UDim2.new(1,-6,0,38),BackgroundColor3=p.field,BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,ZIndex=53},list) round(row,6)
   local ring=itemIcon(row,v.id)
   row.BackgroundTransparency=selected[v.id] and .35 or 1
   label(row,'ItemName',name(v.id),44,0,207,38,13,false,54)
   local price=label(row,'Price',v.data and (tostring(v.data.gold_cost or 0)..' G • '..(available(v.uuid,v.data)==math.huge and '∞' or tostring(available(v.uuid,v.data)))..' left') or 'Not in stock',253,0,120,38,12,false,54) price.TextColor3=muted
   selectionVisual(row,selected[v.id]==true)
   row.Activated:Connect(function() selected[v.id]=not selected[v.id] or nil ring.Transparency=selected[v.id] and 0 or 1 selectionVisual(row,selected[v.id]==true) save() paint() end)
   row.MouseEnter:Connect(function() tween(row,{BackgroundTransparency=.15}) end) row.MouseLeave:Connect(function() tween(row,{BackgroundTransparency=selected[v.id] and .35 or 1}) end)
  end
  list.CanvasSize=UDim2.fromOffset(0,#catalogue*40)
  local empty=label(menu,'NoResults','No matching items',16,74,370,32,13,false,53) empty.TextColor3=muted empty.Visible=false
  local function filterItems()
   local query=string.lower(search.Text) local count=0
   for _,entry in ipairs(catalogue) do
    local row=list:FindFirstChild('Item_'..entry.id)
    if row then
     local match=string.find(string.lower(name(entry.id)),query,1,true) or string.find(string.lower(entry.id),query,1,true)
     row.Visible=match~=nil
     if match then row.Position=UDim2.fromOffset(2,count*40+2) count+=1 end
    end
   end
   list.CanvasSize=UDim2.fromOffset(0,count*40) list.CanvasPosition=Vector2.zero empty.Visible=count==0
  end
  search:GetPropertyChangedSignal('Text'):Connect(filterItems)
  tween(arrow,{Rotation=180})
  if motionEnabled() then menu.Size=UDim2.fromOffset(402,0) menu.GroupTransparency=1 game:GetService('TweenService'):Create(menu,TweenInfo.new(.26,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(402,182),GroupTransparency=0}):Play() end
 end)
 on(toggle.Activated,function() auto.Enabled=not auto.Enabled if auto.Enabled then for _,state in pairs(auto.StockLedger)do state.BlockedSignature=nil state.RetryAt=nil end end paint() status.Text=auto.Enabled and 'Auto Buy enabled • checking selected items' or 'Auto Buy paused' if auto.Enabled then task.spawn(auto.Check) end end)
 auto.RefreshUI=paint
 function auto.Stop() auto.Alive=false auto.Enabled=false hideMenu() for _,c in ipairs(auto.Connections) do c:Disconnect() end panel:Destroy() end
 auto.StockLedger={}
 function auto.StockState(interval,uuid,stock,bought)
  if auto.StockInterval~=interval then auto.StockInterval=interval auto.StockLedger={} end
  local state=auto.StockLedger[uuid]
  if not state then state={Bought=tonumber(bought) or 0} auto.StockLedger[uuid]=state end
  state.Bought=math.max(state.Bought,tonumber(bought) or 0)
  local signature=tostring(stock)..':'..tostring(bought or 0)
  if state.BlockedSignature and (state.BlockedSignature~=signature or os.clock()>=(state.RetryAt or 0)) then state.BlockedSignature=nil state.RetryAt=nil end
  local remaining=stock=='inf' and math.huge or math.max(0,(tonumber(stock) or 0)-state.Bought)
  return state,remaining,signature
 end
 function auto.Check()
  if not auto.Alive or not auto.Enabled or auto.Busy then return end
  if not Loader.IsLobby or not shop.session then auto.NextDelay=2 return end
  if not next(selected) then status.Text='Choose at least one item first.' auto.NextDelay=.25 return end
  local profile=shop.session.profile_data local stockData=profile.gold_shop_data
  local interval=shop.gold_shop_interval
  if not stockData or interval==nil or tostring(stockData.highest_seen_interval)~=tostring(interval) then
   auto.NextDelay=2 status.Text='Waiting for shop stock synchronization…' return
  end
  local funds=tonumber(profile.gold_amount) or 0 local ids={} local stockReady=false local blocked=false
  for uuid,d in pairs(shop.shop_items_for_sale or {}) do if selected[d.id] then
   local bought=(stockData.bought_items or {})[uuid]
   local state,left,signature=auto.StockState(interval,uuid,d.stock,bought)
   if left>0 then
    stockReady=true
    if state.BlockedSignature==signature then blocked=true
    elseif tonumber(d.gold_cost) and d.gold_cost>=0 and funds>=d.gold_cost then
     ids[#ids+1]={id=d.id,uuid=uuid,State=state,Signature=signature,Before=state.Bought}
    end
   end
  end end
  table.sort(ids,function(x,y) return x.id<y.id end)
  if #ids==0 then
   auto.NextDelay=2 status.Text=blocked and 'Purchase declined • retrying after cooldown.' or stockReady and 'Not enough Gold • waiting.' or 'Selected items are sold out • waiting for restock.' return
  end
  local item=ids[1] auto.Busy=true auto.InFlight=1 auto.NextDelay=.4
  task.spawn(function()
   if not auto.Alive or not auto.Enabled then auto.Busy=false auto.InFlight=0 return end
   local success,value=pcall(EP.invoke_server,'buy_gold_shop_item',item.uuid,'1')
   local deadline=os.clock()+2 local observed=item.Before
   repeat
    local current=shop.session and shop.session.profile_data.gold_shop_data
    if current and tostring(current.highest_seen_interval)==tostring(interval) then observed=tonumber((current.bought_items or {})[item.uuid]) or 0 end
    if observed>item.Before or not auto.Alive or not auto.Enabled then break end
    task.wait(.1)
   until os.clock()>=deadline
   if success and value==true or observed>item.Before then
    item.State.Bought=math.max(item.State.Bought+1,observed)
    auto.Purchases+=1 item.State.Failures=nil item.State.BlockedSignature=nil item.State.RetryAt=nil
    if auto.Alive then status.Text='Purchased '..name(item.id)..' ×1' end
   else
    item.State.BlockedSignature=item.Signature item.State.Failures=math.min((item.State.Failures or 0)+1,4) item.State.RetryAt=os.clock()+math.min(60,10*2^(item.State.Failures-1))
    if auto.Alive then status.Text='Purchase not confirmed • checking stock before retry.' end
   end
   auto.Busy=false auto.InFlight=0
  end)
 end

 on(appearance:GetPropertyChangedSignal('BackgroundColor3'),paint)
 on(appearance:GetPropertyChangedSignal('BackgroundTransparency'),paint)
 on(accentIcon:GetPropertyChangedSignal('ImageColor3'),paint)
 if hostStroke then on(hostStroke:GetPropertyChangedSignal('Color'),paint) end
 on(gui.Destroying,auto.Stop)
 paint()
 task.spawn(function() while auto.Alive and panel.Parent do auto.Check() task.wait(auto.Enabled and auto.NextDelay or .25) end end)
end













do
 if env.FyrelithAutoSummon then env.FyrelithAutoSummon.Stop() end
 local S=Loader.load_client_service(script,'SummonServiceClient')
 local Core=Loader.load_core_service(script,'SummonServiceCore')
 local banners=Loader.load_data(script,'Banners')
 local Http=game:GetService('HttpService')
 local file='FyrelithSummon_'..player.UserId..'_'..game.GameId..'.json'
 local config={Banner=banners.EventClover and 'EventClover' or nil,Batch=1,Payment='banner',Limit=''}
 pcall(function()
  if type(readfile)=='function' and type(isfile)=='function' and isfile(file) then
   local d=Http:JSONDecode(readfile(file))
   if banners[d.Banner] then config.Banner=d.Banner end
   config.Batch=d.Batch==10 and 10 or 1 config.Payment=d.Payment=='ticket' and 'ticket' or 'banner'
   config.Limit=tonumber(d.Limit) and tostring(math.max(1,math.floor(tonumber(d.Limit)))) or ''
  end
 end)
 local a={Alive=true,Enabled=false,Busy=false,Count=0,Config=config,Connections={}}
 env.FyrelithAutoSummon=a
 local utility=main.Parent.Utilities
 local panel=new('Frame',{Name='AutoSummon',Position=UDim2.fromOffset(462,8),Size=UDim2.fromOffset(438,366),BorderSizePixel=0},utility)
 round(panel,11) border(panel)
 label(panel,'Title','Auto Summon',18,14,402,28,19,true)
 local status=label(panel,'Status','',18,268,402,14,11) status.TextColor3=muted status.TextWrapped=true status.TextTruncate=Enum.TextTruncate.None
 local function on(signal,fn) table.insert(a.Connections,signal:Connect(fn)) end
 local function save() if type(writefile)=='function' then pcall(writefile,file,Http:JSONEncode(config)) end end
 local menuOverlay
 local function closeMenu() if menuOverlay then menuOverlay:Destroy() menuOverlay=nil end end
 local bannerLabels={Summer2026='Summer',EventClover='Special',Legacy='Legacy'}
 local function bannerName(id) local d=banners[id] return bannerLabels[id] or (d and (d.name or d.display_name)) or tostring(id):gsub('(%l)(%u)','%1 %2') end
 local function bannerChoices()
  local out={} for id,d in pairs(banners) do if d.active then table.insert(out,{id=id,name=bannerName(id)}) end end
  local order={Summer2026=1,EventClover=2,Legacy=3}
  table.sort(out,function(x,y) local a,b=order[x.id] or 99,order[y.id] or 99 if a==b then return x.name<y.name end return a<b end) return out
 end
 if not config.Banner then config.Banner=bannerChoices()[1] and bannerChoices()[1].id end
 local function formPicker(title,y,getOptions,getValue,set)
  local l=label(panel,title..'Label',title,18,y,148,36,14) l.TextColor3=muted
  local b=new('TextButton',{Name=title,Text='',Position=UDim2.fromOffset(176,y),Size=UDim2.fromOffset(244,36),BackgroundTransparency=.32,BorderSizePixel=0,AutoButtonColor=false},panel) round(b,8) border(b)
  local text=label(b,'Value',getValue(),12,0,200,36,14,false,4)
  new('ImageLabel',{Name='Chevron',Position=UDim2.new(1,-25,.5,-6),Size=UDim2.fromOffset(12,12),Image='rbxassetid://7733717447',ImageColor3=muted,BackgroundTransparency=1,ZIndex=4},b)
  on(b.Activated,function()
   if menuOverlay then closeMenu() return end
   if a.Enabled or a.Busy then status.Text='Pause Auto Summon before changing settings.' return end
   local options=getOptions() local p=palette() local height=math.min(6,#options)*32+12 local top=y+50
   if top+height>399 then top=y+2-height end
   menuOverlay=new('Frame',{Name='SummonPicker',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=50},utility)
   local outside=new('TextButton',{Name='Outside',Text='',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=50},menuOverlay) outside.Activated:Connect(closeMenu)
   local menu=new('CanvasGroup',{Name='Menu',Position=UDim2.fromOffset(panel.Position.X.Offset+176,top),Size=UDim2.fromOffset(244,height),BackgroundColor3=p.card,BackgroundTransparency=.12,BorderSizePixel=0,ClipsDescendants=true,ZIndex=51},menuOverlay) round(menu,8) border(menu)
   for i,v in ipairs(options) do
    local item=new('TextButton',{Name='Option_'..tostring(v.id),Text=v.name,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(6,6+(i-1)*32),Size=UDim2.fromOffset(232,30),BackgroundTransparency=1,BackgroundColor3=p.field,TextColor3=white,TextSize=14,Font=Enum.Font.Gotham,BorderSizePixel=0,ZIndex=52},menu)
    new('UIPadding',{PaddingLeft=UDim.new(0,10)},item) round(item,5)
    item.Activated:Connect(function() set(v.id) a.Count=0 save() text.Text=getValue() if a.RefreshUI then a.RefreshUI() end closeMenu() end)
    item.MouseEnter:Connect(function() tween(item,{BackgroundTransparency=.15}) end) item.MouseLeave:Connect(function() tween(item,{BackgroundTransparency=1}) end)
   end
   if motionEnabled() then menu.Size=UDim2.fromOffset(244,0) menu.GroupTransparency=1 game:GetService('TweenService'):Create(menu,TweenInfo.new(.26,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(244,height),GroupTransparency=0}):Play() end
  end)
  return b
 end
 local bannerButton=formPicker('Banner',50,bannerChoices,function() return config.Banner and bannerName(config.Banner) or 'No active banners' end,function(v) config.Banner=v if banners[v]._no_summon_ticket then config.Payment='banner' end end)
 local batchButton=formPicker('Batch',92,function() return {{id=1,name='1 pull'},{id=10,name='10 pulls'}} end,function() return config.Batch..' pull'..(config.Batch==10 and 's' or '') end,function(v) config.Batch=v end)
 local paymentButton=formPicker('Currency',134,function()
  local out={{id='banner',name='Banner currency'}} if config.Banner and not banners[config.Banner]._no_summon_ticket then table.insert(out,{id='ticket',name='Summon ticket (1 pull)'}) end return out
 end,function() return config.Payment=='ticket' and 'Summon ticket' or 'Banner currency' end,function(v) config.Payment=v end)
 local l=label(panel,'LimitLabel','Total pulls',18,176,148,36,14) l.TextColor3=muted
 local limit=new('TextBox',{Name='Limit',Text=config.Limit,PlaceholderText='Blank / 0 = until empty',ClearTextOnFocus=false,Position=UDim2.fromOffset(176,176),Size=UDim2.fromOffset(244,36),BackgroundTransparency=.32,BorderSizePixel=0,TextColor3=white,PlaceholderColor3=muted,TextSize=14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},panel)
 round(limit,8) border(limit) new('UIPadding',{PaddingLeft=UDim.new(0,12)},limit)
 on(limit.FocusLost,function()
  if a.Enabled or a.Busy then limit.Text=config.Limit return end
  local n=tonumber(limit.Text)
  local nextLimit=n and n>=1 and tostring(math.floor(n)) or '' if nextLimit~=config.Limit then a.Count=0 end config.Limit=nextLimit limit.Text=config.Limit save() if a.RefreshUI then a.RefreshUI() end
 end)
 local toggle=new('TextButton',{Name='AutoSummonSwitch',Text='',Position=UDim2.fromOffset(18,220),Size=UDim2.fromOffset(402,44),BackgroundTransparency=1,AutoButtonColor=false},panel)
 label(toggle,'Title','Auto Summon',0,0,280,22,15)
 local progress=label(toggle,'Progress','0 pulls completed',0,24,320,18,12) progress.TextColor3=muted
 local track=new('Frame',{Name='Track',Position=UDim2.fromOffset(346,7),Size=UDim2.fromOffset(54,29),BorderSizePixel=0,ZIndex=4},toggle) round(track,15)
 local knob=new('Frame',{Name='Knob',Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(21,21),BackgroundColor3=white,BorderSizePixel=0,ZIndex=5},track) round(knob,11)
 local function paint()
  local p=palette() panel.BackgroundColor3=p.card panel.BackgroundTransparency=math.max(.38,p.transparency)
  for _,b in ipairs({bannerButton,batchButton,paymentButton,limit}) do b.BackgroundColor3=p.field end
  paymentButton.Value.Text=config.Payment=='ticket' and 'Summon ticket' or 'Banner currency'
  tween(track,{BackgroundColor3=a.Enabled and p.accent or p.line}) tween(knob,{Position=UDim2.fromOffset(a.Enabled and 29 or 4,4)}) toggle:SetAttribute('Enabled',a.Enabled)
  progress.Text=a.Count..' / '..(config.Limit~='' and config.Limit or '∞')..' pulls completed'
 end
 a.RefreshUI=paint
 local function stop(reason)
  a.Enabled=false
  if a.Runner and a.Runner~=coroutine.running() then pcall(task.cancel,a.Runner) end
  a.Runner=nil a.Busy=false
  status.Text=reason paint()
  if env.FyrelithRuntime and env.FyrelithRuntime.Save then env.FyrelithRuntime.Save() end
 end
 local function waitRetry(reason)
  status.Text=reason paint()
  local deadline=os.clock()+2
  while a.Alive and a.Enabled and os.clock()<deadline do task.wait(.1) end
 end
 local function balance(d,payment)
  local profile=S.session.profile_data
  local function live(name,fallback)
   local stats=player:FindFirstChild('_stats') local value=stats and stats:FindFirstChild(name)
   if value and value:IsA('ValueBase') and tonumber(value.Value) then return tonumber(value.Value) end
   return tonumber(fallback) or 0
  end
  if (payment or config.Payment)=='ticket' then return S.session.inventory:get_number_of_owned_item('summon_ticket'),1,'Summon tickets' end
  if d.item_cost then return S.session.inventory:get_number_of_owned_item(d.item_cost.item_id),d.item_cost.amount,d.item_cost.item_id end
  if d.resource_cost then return live('_resource'..d.resource_cost.id,profile.resources and profile.resources[d.resource_cost.id]),Core.calculate_hatch_price(S.session,d.resource_cost.amount,d.resource_cost.id),d.resource_cost.id end
  if d.gem_cost then return live('gem_amount',profile.gem_amount),Core.calculate_hatch_price(S.session,d.gem_cost,'gems'),'Gems' end
  return nil,nil,'Unsupported currency'
 end
 function a.ReadBalance() local d=banners[config.Banner] if d then return balance(d) end end
 function a.QuoteBanner(id,payment,batch,remaining)
  local d=banners[id]
  if not d or not d.active then return nil,'Banner unavailable' end
  if payment=='ticket' and d._no_summon_ticket then return nil,'Tickets unsupported by this banner' end
  local funds,cost,currency=balance(d,payment)
  if type(funds)~='number' or type(cost)~='number' or cost<=0 then return nil,'Currency data unavailable' end
  local count=payment=='ticket' and 1 or (batch==10 and (remaining or math.huge)>=10 and funds>=cost*10 and 10 or 1)
  return {Funds=funds,UnitCost=cost,Currency=currency,Count=count,Method=payment=='ticket' and 'ticket' or count==10 and 'gems10' or 'gems',Affordable=funds>=cost*count}
 end
 function a.ConfirmedPulls(before,after,cost,hatched,requested)
  local count=math.max(0,tonumber(hatched) or 0)
  if type(after)=='number' and after<before and cost>0 then count=math.max(count,math.floor((before-after)/cost+.001)) end
  return math.min(requested,count)
 end
 a.MinInterval=3.2 a.HatchedTotal=0
 function a.IsSummonRateLimit(text)
  if type(text)~='string' then return false end
  text=text:lower()
  return text:find('summon',1,true)~=nil and (text:find('too fast',1,true)~=nil or text:find('slow down',1,true)~=nil or text:find('cooldown',1,true)~=nil)
 end
 local function observeSummonMessage(...)
  if not a.Alive or not a.Busy or not a.LastSummonAt or os.clock()-a.LastSummonAt>15 then return end
  for _,message in ipairs({...}) do
   if type(message)=='table' then message=message.text or message.message or message.Text end
   if a.IsSummonRateLimit(message) then a.RateLimitedAt=os.clock() a.RateLimitMessage=message end
  end
 end
 local incoming=game.ReplicatedStorage:FindFirstChild('endpoints')
 incoming=incoming and incoming:FindFirstChild('server_to_client')
 if incoming then for _,name in ipairs({'show_message','show_quick_message','show_drop_message','push_notification'}) do local event=incoming:FindFirstChild(name) if event and event:IsA('RemoteEvent') then on(event.OnClientEvent,observeSummonMessage) end end end
 local GameGUI=Loader.load_client_service(script,'GUIService')
 local FX=Loader.load_client_service(script,'SummonFX')
 local originalShow=S.on_show_hatch_effect
 local originalOpen=FX.open_star_new
 local fxSource=type(debug.getinfo)=='function'and debug.getinfo(originalOpen).source or nil
 local function instantOpen(unit,isUnit,preview,closeWindows,onComplete,context,params,options)
  if a.Alive and a.Enabled then
   a.SkippedEffects=(a.SkippedEffects or 0)+1
   if type(onComplete)=='function' then task.defer(onComplete) end
   return
  end
  return originalOpen(unit,isUnit,preview,closeWindows,onComplete,context,params,options)
 end
 FX.open_star_new=instantOpen
 local function skipBannerVisual(...)
  if a.Alive and a.Enabled then a.SkippedEffects=(a.SkippedEffects or 0)+1 return end
  return originalShow(...)
 end
 S.on_show_hatch_effect=skipBannerVisual
 -- Use the game's own click-to-continue cleanup for an already-open result.
 function a.ClearSummonScreen()
  local ui=GameGUI.summon_ui
  if not ui or not ui.hatching then return true end
  local connections=type(getconnections)=='function' and getconnections(game:GetService('UserInputService').InputBegan) or {}
  for _,connection in ipairs(connections) do
   local fn=connection.Function
   if type(fn)=='function' then
    local ok,info=pcall(debug.getinfo,fn)
    if fxSource and ok and type(info)=='table'and info.source==fxSource then
     pcall(fn,{UserInputType=Enum.UserInputType.MouseButton1,KeyCode=Enum.KeyCode.Unknown},false)
    end
   end
  end
  if ui.hatching then
   pcall(function()
    local view=workspace.CurrentCamera.ViewportSize
    local input=game:GetService('VirtualInputManager')
    input:SendMouseButtonEvent(math.floor(view.X*.5),math.floor(view.Y*.75),0,true,game,0)
    input:SendMouseButtonEvent(math.floor(view.X*.5),math.floor(view.Y*.75),0,false,game,0)
   end)
  end
  return not ui.hatching
 end
 local previousStop=a.Stop
 -- Stop is attached below, once the UI cleanup function has been constructed.
 a.RestoreSummonEffects=function()
  if S.on_show_hatch_effect==skipBannerVisual then S.on_show_hatch_effect=originalShow end
  if FX.open_star_new==instantOpen then FX.open_star_new=originalOpen end
 end

 local Units=Loader.load_data(script,'Units')
 local historyKey=tostring(player.UserId)..':'..tostring(game.GameId)
 env.FyrelithSummonHistory=env.FyrelithSummonHistory or {}
 local history=env.FyrelithSummonHistory[historyKey] or {Rows={},Seen={}}
 env.FyrelithSummonHistory[historyKey]=history a.History=history
 panel.Size=UDim2.fromOffset(438,338)
 utility.CanvasSize=UDim2.fromOffset(0,388)
 local latestIcon=new('Frame',{Name='LatestMythicIcon',Position=UDim2.fromOffset(18,284),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Visible=false},panel)
 local latestIconId
 local latest=label(panel,'LatestMythicName','',74,284,346,44,16,true)
 latest.TextColor3=white
 local function drawHistory()
  local record=history.Rows[1]
  local height=record and 338 or 292
  panel.Size=UDim2.fromOffset(438,height)
  local nextCard=gui:FindFirstChild('AutoTraitCard',true)
  if nextCard then nextCard.Position=UDim2.fromOffset(panel.Position.X.Offset,panel.Position.Y.Offset+height+12) end
  latest.Text=record and record.Name or ''
  latestIcon.Visible=record~=nil
  local iconId=record and (record.Id..tostring(record.Shiny)) or nil
  if iconId~=latestIconId then
   latestIconId=iconId latestIcon:ClearAllChildren()
   if record then
    local ok,frame=pcall(function() if hasUnitPortrait(record.Id) then return GameGUI.make_unit_frame(record.Id,0,nil,nil,true,{hide_extra_info=true}) end end)
    if ok and frame then
     local view=frame:FindFirstChild('View',true)
     if view then view.Parent=latestIcon view.Name='Portrait' view.AnchorPoint=Vector2.zero view.Position=UDim2.fromOffset(0,0) view.Size=UDim2.fromScale(1,1) view.BackgroundTransparency=1 view.Visible=true view.Active=false view.ZIndex=4
      local model=view:FindFirstChildWhichIsA('Model')
      if model then
       local head=model:FindFirstChild('Head',true)
       local bounds,size=model:GetBoundingBox()
       local target=head and head.Position or bounds.Position
       local direction=head and head.CFrame.LookVector or Vector3.new(0,0,-1)
       local distance=head and 3.5 or math.max(size.X,size.Y,size.Z)*1.4
       local camera=Instance.new('Camera') camera.FieldOfView=35 camera.CFrame=CFrame.lookAt(target+direction*distance+Vector3.new(0,.15,0),target) camera.Parent=view view.CurrentCamera=camera
      end
     end
     frame:Destroy()
    end
   end
  end
 end
 local function capture(uuids)
  for _,uuid in pairs(uuids or {}) do
   if type(uuid)=='string' and not history.Seen[uuid] then
    local unit=S.session.collection:get_unit_by_uuid(uuid)
    local definition=unit and Units[unit.unit_id]
    if definition and (definition.rarity=='Mythic' or definition.rarity=='Secret' or definition.rarity=='Exclusive') then
     history.Seen[uuid]=true
     local existing
     for i,row in ipairs(history.Rows) do if row.Id==unit.unit_id and row.Shiny==(unit.shiny==true) then existing=table.remove(history.Rows,i) break end end
     local record=existing or {Id=unit.unit_id,Name=definition.name or unit.unit_id,Rarity=definition.rarity,Shiny=unit.shiny==true,Count=0}
     record.Count+=1 table.insert(history.Rows,1,record)
     if #history.Rows>50 then table.remove(history.Rows) end
    end
   end
  end
  drawHistory()
 end
 local originalHatched=S.on_units_hatched_through_banner
 local acknowledgedHatches={}
 local function trackHatched(uuids,...)
  if a.Alive and a.Busy and type(uuids)=='table' then for _,uuid in pairs(uuids) do if type(uuid)=='string' and not acknowledgedHatches[uuid] then acknowledgedHatches[uuid]=true a.HatchedTotal+=1 end end end
  if a.Alive and (a.Enabled or a.Busy or (a.LastSummonAt and os.clock()-a.LastSummonAt<5)) then pcall(capture,uuids) end
  return originalHatched(uuids,...)
 end
 S.on_units_hatched_through_banner=trackHatched
 local restorePrevious=a.RestoreSummonEffects
 a.RestoreSummonEffects=function()
  restorePrevious()
  if S.on_units_hatched_through_banner==trackHatched then S.on_units_hatched_through_banner=originalHatched end
 end
 drawHistory()

 function a.Run()
  if a.Busy or not a.Enabled or not a.Alive then return end a.Busy=true
  while a.Enabled and a.Alive do
   local ok,err=pcall(function()
    local nextAllowed=math.max(a.NextAllowedAt or 0,(a.LastSummonAt or -math.huge)+a.MinInterval)
    while a.Enabled and a.Alive and os.clock()<nextAllowed do status.Text='Waiting for summon cooldown…' task.wait(.1) end
    if not a.Enabled or not a.Alive then return end
    local d=banners[config.Banner] if not d or not d.active then waitRetry('Selected banner is unavailable • waiting.') return end
    if not Loader.IsLobby then status.Text='Waiting until you return to the lobby.' task.wait(1) return end
    if config.Payment=='ticket' and d._no_summon_ticket then waitRetry('This banner does not accept Summon tickets • pause to change currency.') return end
    local target=tonumber(config.Limit) local remaining=target and target-a.Count or math.huge
    if remaining<=0 then stop('Completed • '..a.Count..' pulls') return end
    local quote,quoteError=a.QuoteBanner(config.Banner,config.Payment,config.Batch,remaining)
    if not quote then stop('Stopped • '..tostring(quoteError)) return end
    local funds,cost,currency=quote.Funds,quote.UnitCost,quote.Currency
    if not quote.Affordable then stop(currency..' insufficient • Auto Summon stopped') return end
    if not a.ClearSummonScreen() then status.Text='Clearing the previous summon result…' task.wait(.05) return end
    local batch=quote.Count local method=quote.Method
    status.Text='Summoning '..bannerName(config.Banner)..' ×'..batch..'…'
    -- Recheck immediately before sending; UI cleanup may have yielded.
    local verified,verifiedCost=balance(d)
    if not a.Enabled or not a.Alive then return end
    if not verified or not verifiedCost or verifiedCost<=0 or verified<verifiedCost*batch then stop('Insufficient currency • Auto Summon stopped') return end
    funds=verified cost=verifiedCost
    local beforeHatches=a.HatchedTotal
    a.LastSummonAt=os.clock()
    local success,result=pcall(EP.invoke_server,'buy_from_banner',config.Banner,method)
    if not a.Alive then return end
    a.LastResponse={success=success,value=tostring(result)}
    local after=select(1,balance(d))
    local deadline=os.clock()+10
    while a.Alive and a.Enabled and not (after and after<funds) and a.HatchedTotal-beforeHatches<batch and os.clock()<deadline do task.wait(.05) after=select(1,balance(d)) end
    if not a.Enabled or not a.Alive then return end
    local confirmed=a.ConfirmedPulls(funds,after,cost,a.HatchedTotal-beforeHatches,batch)
    if confirmed>0 then
     a.LastProof=after and after<funds and 'Live balance' or 'Hatched units'
     a.Backoff=0
     a.Count+=confirmed paint()
     local current,nextCost=balance(d)
     if not current or not nextCost or current<nextCost then stop(currency..' insufficient • Auto Summon stopped') return end
    elseif (a.RateLimitedAt or -math.huge)>=a.LastSummonAt and a.HatchedTotal==beforeHatches and after and after>=funds then
     a.Backoff=math.min(20,math.max(6,(a.Backoff or 0)*1.5))
     a.MinInterval=math.min(10,a.MinInterval+1)
     a.NextAllowedAt=os.clock()+a.Backoff
     status.Text='Summoning too fast • waiting '..a.Backoff..'s before retry'
     return
    else stop('Stopped • '..bannerName(config.Banner)..' summon not confirmed; no duplicate request') return end
    task.wait()
   end)
   if not ok and a.Alive and a.Enabled then stop('Stopped • unable to verify summon payment') end
  end
  a.Busy=false
 end
 local lastToggle=-math.huge
 local function toggleSummon()
  if os.clock()-lastToggle<.15 then return end lastToggle=os.clock()
  if a.Enabled or a.Busy then stop('Paused • '..a.Count..' pulls completed') return end
  -- A new activation starts a fresh target; pausing never spends further currency.
  local entered=tonumber(limit.Text)
  local normalized=entered and entered>=1 and tostring(math.floor(entered)) or ''
  if config.Limit~=normalized then a.Count=0 end
  config.Limit=normalized limit.Text=normalized
  local target=tonumber(config.Limit) if target and a.Count>=target then a.Count=0 end a.Enabled=true paint() save() a.Runner=task.spawn(a.Run)
 end
 local hit=new('TextButton',{Name='HitTarget',Text='',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,AutoButtonColor=false,ZIndex=10},toggle)
 on(hit.Activated,toggleSummon) on(toggle.Activated,toggleSummon)
 function a.Stop() a.Alive=false a.Enabled=false if a.Runner and a.Runner~=coroutine.running() then pcall(task.cancel,a.Runner) end a.Busy=false if a.RestoreSummonEffects then a.RestoreSummonEffects() end closeMenu() for _,c in ipairs(a.Connections) do c:Disconnect() end panel:Destroy() end
 on(appearance:GetPropertyChangedSignal('BackgroundColor3'),paint) on(appearance:GetPropertyChangedSignal('BackgroundTransparency'),paint)
 on(accentIcon:GetPropertyChangedSignal('ImageColor3'),paint) if hostStroke then on(hostStroke:GetPropertyChangedSignal('Color'),paint) end
 on(gui.Destroying,a.Stop)
 paint()
end






















-- Persistent, ordered tower-defense macro recorder. Only gameplay requests are captured.
do
 local old=env.FyrelithMacro if old and old.Stop then pcall(old.Stop) end
 local H=game:GetService('HttpService')
 local m={Alive=true,State='Idle',Library={},Config={Name='My macro',Timing='Hybrid',Auto=false,Wait=60},Index=0,Steps={}}
 env.FyrelithMacro=m
 local clock=env.FyrelithMatchClock
 if not clock or clock.Job~=game.JobId then
  local started=workspace:FindFirstChild('_waves_started') local w=workspace:FindFirstChild('_wave_num')
  clock={Job=game.JobId,Known=not started or not started.Value or (w and w.Value==0),Start=started and started.Value and os.clock() or nil}
  env.FyrelithMatchClock=clock
 end
 local function matchTime() return clock.Start and math.max(0,os.clock()-clock.Start) or 0 end
 local waveStart=workspace:FindFirstChild('_waves_started')
 if waveStart then connect(waveStart.Changed,function(v) if v and not clock.Start then clock.Start=os.clock() clock.Known=true end end) end
 local file='FyrelithMacros_'..player.UserId..'_'..game.GameId..'.json'
 pcall(function() local d=H:JSONDecode(readfile(file)) m.Library=d.Library or {} m.Config=d.Config or m.Config end)
 m.Config.Wait=tonumber(m.Config.Wait) or 60
 local allowed={spawn_unit=true,upgrade_unit_ingame=true,sell_unit_ingame=true,use_active_attack=true,use_custom_unit_control=true,change_priority=true,vote_wave_skip=true,vote_start=true}
 local function val(parent,name) local v=parent and parent:FindFirstChild(name) return v and v:IsA('ValueBase') and v.Value end
 local function wave() return tonumber(val(workspace,'_wave_num') or val(game.ReplicatedStorage,'_wave_num')) or 0 end
 local function level() local d=Loader.LevelData return type(d)=='table' and (d.id or d.level_id) or tostring(d or '') end
 local function owned(u) return val(u:FindFirstChild('_stats'),'player')==player end
 local function encode(v,depth)
  depth=depth or 0 assert(depth<12,'Arguments too deep')
  local t=typeof(v)
  if t=='CFrame' then return {kind='CFrame',v={v:GetComponents()}} end
  if t=='Vector3' then return {kind='Vector3',v={v.X,v.Y,v.Z}} end
  if t=='EnumItem' then return {kind='Enum',enum=tostring(v.EnumType):gsub('Enum.',''),name=v.Name} end
  if t=='Instance' then
   local u=v while u and u.Parent~=workspace:FindFirstChild('_UNITS') do u=u.Parent end
   assert(u and owned(u),'Unsupported target: only your placed towers can be recorded')
   local p=u:GetPivot().Position local s=u:FindFirstChild('_stats')
   return {kind='Tower',uuid=val(s,'uuid'),id=val(s,'id'),p={p.X,p.Y,p.Z}}
  end
  if t=='table' then local out={} for k,x in pairs(v) do out[k]=encode(x,depth+1) end return out end
  assert(t=='number' or t=='boolean' or t=='string' or t=='nil','Unsupported argument '..t) return v
 end
 local function decode(v)
  if type(v)~='table' then return v end
  if v.kind=='CFrame' then return CFrame.new(unpack(v.v)) end
  if v.kind=='Vector3' then return Vector3.new(unpack(v.v)) end
  if v.kind=='Enum' then return Enum[v.enum][v.name] end
  if v.kind=='Tower' then
   local units=workspace:FindFirstChild('_UNITS') local best,dist=nil,4
   if units then for _,u in ipairs(units:GetChildren()) do if u:IsA('Model') and owned(u) then
    local s=u:FindFirstChild('_stats')
    if val(s,'uuid')==v.uuid and val(s,'id')==v.id then local p=u:GetPivot().Position local d=(Vector3.new(p.X,0,p.Z)-Vector3.new(v.p[1],0,v.p[3])).Magnitude if d<dist then best=u dist=d end end
   end end end
   assert(best,'Waiting for recorded tower') return best
  end
  local out={} for k,x in pairs(v) do out[k]=decode(x) end return out
 end
 local panel=card('MacroCard',8,414,438,420)
 label(root,'MacroTitle','Tower Defense Macro',26,428,400,28,19,true)
 local previewCard=card('MacroPreviewCard',462,662,438,172)
 label(root,'MacroPreviewTitle','Recorded actions',480,676,402,24,16,true)
 local preview=label(root,'MacroPreview','No recording selected',480,706,402,110,12) preview.TextWrapped=true preview.TextYAlignment=Enum.TextYAlignment.Top
 local note=label(root,'MacroStatus','',26,804,402,60,12)
 note.TextWrapped=true note.TextColor3=muted
 function m.RefreshActionsUI()
  if not m.Alive or not api.Alive or not root.Parent then return end
  if m.RefreshRecordSwitch then m.RefreshRecordSwitch() end
  local recording=m.State=='Recording' or m.State=='Finishing' or (m.State=='Paused' and m.BeforePause=='Recording')
  local playing=m.State=='Playing' or (m.State=='Paused' and m.BeforePause=='Playing')
  local visible=recording or playing
  local title=ui('MacroPreviewTitle')
  if title then title.Visible=visible end preview.Visible=visible previewCard.Visible=visible and not m.CleanLayout
  local text={}
  local first=playing and m.Index or math.max(1,#m.Steps-4)
  local last=playing and m.Index or #m.Steps
  for i=math.max(1,first),last do local a=m.Steps[i] if a then table.insert(text,string.format('%d · W%d · %.1fs · %s',i,a.Wave,a.Time,a.Action:gsub('_',' '))) end end
  preview.Text=table.concat(text,'\n')
  if api.Ready then
   local bottom=note.Position.Y.Offset+note.Size.Y.Offset
   if not m.CleanLayout then panel.Size=UDim2.fromOffset(438,bottom-panel.Position.Y.Offset+18) end
   local endY=math.max(bottom+34,ui('TeamSettingsCard').Position.Y.Offset+ui('TeamSettingsCard').Size.Y.Offset+16)
   local page=panel.Parent:IsA('ScrollingFrame') and panel.Parent or main
   if page==main then root.Size=UDim2.fromOffset(908,endY) end
   page.CanvasSize=UDim2.fromOffset(0,page==main and endY or bottom+34)
  end
 end
 local function say(s)
  m.Message=s note.Text=s local notice=ui('MacroNotice') if notice then notice.Text=s end m.RefreshActionsUI()
 end
 local function save()
  local ok,err=pcall(function() assert(type(writefile)=='function','Executor cannot save files') writefile(file,H:JSONEncode({Library=m.Library,Config=m.Config})) end)
  m.SaveError=not ok and tostring(err) or nil return ok
 end
 local name=new('TextBox',{Name='MacroName',Text=m.Config.Name or 'My macro',PlaceholderText='Macro name',Position=UDim2.fromOffset(184,470),Size=UDim2.fromOffset(244,36),BackgroundTransparency=.4,TextColor3=white,TextSize=14,Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=3},root)
 bind(name,'BackgroundColor3','field') round(name) border(name)
 label(root,'MacroNameLabel','Name',26,470,145,36,14)
 -- Name is a draft until Save is pressed; recording always targets the selected macro.
 name.Size=UDim2.fromOffset(158,36)
 local timing=picker('Timing',26,514,function() return {{id='Hybrid',name='Hybrid · wave + time'},{id='Time',name='Time · original delays'},{id='Wave',name='Wave · as soon as ready'}} end,function() return m.Config.Timing or 'Hybrid' end,function(v) m.Config.Timing=type(v)=='table' and v.id or v save() task.defer(function() local b=ui('Select_Timing') if b then b.Value.Text=m.Config.Timing end end) end)
 local library
 local paintPlay=function() end
 local function selected() return m.Library[m.Config.Name] end
 local function stop() m.Config.PlayRequested=false m.Token=(m.Token or 0)+1 m.State='Idle' paintPlay() save() say('Stopped • '..#m.Steps..' recorded actions') end
 function m.Select(n)
  if m.State~='Idle' then say('Stop before changing macro') return false end
  local d=m.Library[n] if not d then return false end
  m.Config.Name=n name.Text=n m.Steps=d.Steps or {} m.RecordLevel=d.Level m.RecordMode=d.Mode m.StartWave=d.StartWave m.RecordOffset=d.RecordOffset m.Index=0
  if library then library.Set(n) end save() say('Selected '..n..' • '..#m.Steps..' actions') return true
 end
 function m.Save()
  local n=m.Config.Name
  if not m.Library[n] then say('Enter a name and press Save first') return false end
  m.Library[n]={Version=1,Level=m.RecordLevel or '',Mode=m.RecordMode,StartWave=m.StartWave or 0,RecordOffset=m.RecordOffset or 0,Steps=m.Steps}
  local ok=save() say(ok and ('Saved '..n..' • '..#m.Steps..' actions') or m.SaveError) return ok
 end
 function m.SaveName()
  local n=name.Text:match('^%s*(.-)%s*$'):sub(1,60)
  if n=='' then say('Enter a macro name') return false end
  if m.State~='Idle' then say('Stop recording or playback before saving a name') return false end
  if not m.Library[n] then m.Library[n]={Version=1,Level='',StartWave=0,Steps={}} end
  return m.Select(n)
 end
 function m.Record()
  if api.MatchEnded then say('Match ended • recording is saved; enter a new match to record') return end
  if Loader.IsLobby then say('Enter a tower defense map before recording') return end
  if not selected() and not m.SaveName() then return end
  stop() m.Sequence=0 m.Steps={} m.Index=0 m.StartWave=wave() m.RecordOffset=matchTime() m.RecordLevel=level() m.RecordMode=cfg.Mode m.Start=os.clock() m.PausedTotal=0 m.State='Recording' m.Save()
  say('Recording '..m.Config.Name..' • Record again starts a new recording.')
 end
 local original=EP.invoke_server
 local claims=setmetatable({},{__mode='k'})
 local upgradeClaims=setmetatable({},{__mode='k'})
 local function evidence(endpoint,args,consume)
  if endpoint=='upgrade_unit_ingame' then
   local u=args[1] if typeof(u)~='Instance' then return function() return false end end
   local before=tonumber(val(u:FindFirstChild('_stats'),'upgrade'))
   return function()
    local now=tonumber(val(u:FindFirstChild('_stats'),'upgrade'))
    if not before or not now then return false end
    local expected=consume and math.max(before,upgradeClaims[u] or before)+1 or before+1
    if now>=expected then if consume then upgradeClaims[u]=expected end return true,expected end
    return false
   end
  elseif endpoint=='spawn_unit' then
   local folder=workspace:FindFirstChild('_UNITS') local before={}
   if folder then for _,u in ipairs(folder:GetChildren()) do before[u]=true end end
   return function()
    if not folder then return false end
    for _,u in ipairs(folder:GetChildren()) do
     local st=u:FindFirstChild('_stats')
     if not before[u] and (not consume or not claims[u]) and u:IsA('Model') and owned(u) and val(st,'uuid')==args[1] then
      local cf=args[2] local pos=u:GetPivot().Position
      if typeof(cf)=='CFrame' and (Vector3.new(pos.X,0,pos.Z)-Vector3.new(cf.X,0,cf.Z)).Magnitude<4 then if consume then claims[u]=true end return true end
     end
    end return false
   end
  elseif endpoint=='sell_unit_ingame' then
   local u=args[1] local existed=typeof(u)=='Instance' and u.Parent~=nil
   return function() return existed and (not u.Parent or u.Parent~=workspace:FindFirstChild('_UNITS')) end
  end
 end
 local wrapped
 wrapped=function(endpoint,...)
  local args=table.pack(...) local entry local recordingToken=m.Token local confirmed
  local buff=env.FyrelithAutoBuff
  local automaticBuff=buff and buff.RequestThreads and buff.RequestThreads[coroutine.running()]
  if m.Alive and m.State=='Recording' and allowed[endpoint] and not automaticBuff then
   local ok,data=pcall(encode,args)
   if ok then
    m.Sequence=(m.Sequence or 0)+1
    entry={Action=endpoint,Args=data,Time=clock.Known and math.max(0,matchTime()-(m.RecordOffset or 0)) or (os.clock()-m.Start-m.PausedTotal),Wave=wave(),Sequence=m.Sequence,Cash=tonumber(val(player:FindFirstChild('_stats'),'resource')) or 0}
    if endpoint=='upgrade_unit_ingame' and typeof(args[1])=='Instance' then entry.UpgradeAfter=(tonumber(val(args[1]:FindFirstChild('_stats'),'upgrade')) or 0)+1 end
    confirmed=evidence(endpoint,args,true)
   else say('Not recorded: '..tostring(data)) end
  end
  local result=table.pack(original(endpoint,...))
  if entry and result[1]~=false then
   task.spawn(function()
    local deadline=os.clock()+3
    local verified=not confirmed and result[1]==true
    repeat
     if not m.Alive or recordingToken~=m.Token then return end
     if confirmed then local ok,value,upgrade=pcall(confirmed) verified=ok and value if verified and endpoint=='upgrade_unit_ingame' and upgrade then entry.UpgradeAfter=upgrade end end
     if verified then break end task.wait(.04)
    until os.clock()>=deadline
    if verified and recordingToken==m.Token and (m.State=='Recording' or m.State=='Finishing' or (m.State=='Paused' and m.BeforePause=='Recording')) then
     table.insert(m.Steps,entry) table.sort(m.Steps,function(x,y) return (x.Sequence or 0)<(y.Sequence or 0) end)
     m.Save() say('Recording • '..#m.Steps..' actions • '..endpoint)
    end
   end)
  end
  return table.unpack(result,1,result.n)
 end
 EP.invoke_server=wrapped
 function m.Play()
  if m.State~='Idle' then say('Stop the current recording or playback first') return end
  local data=selected()
  if not data then m.Config.PlayRequested=false save() paintPlay() say('Select a saved macro before pressing Play') return false end
  if type(data.Steps)~='table' or #data.Steps==0 then m.Config.PlayRequested=false save() paintPlay() say('This macro has 0 actions. Turn Record on, perform actions, then turn Record off to save.') return false end
  if Loader.IsLobby or api.MatchEnded then m.Config.PlayRequested=true save() paintPlay() say('Play enabled • waiting for the recorded map') return true end
  if data.Level~='' and level()~='' and data.Level~=level() then say('Map does not match this macro') return end
  for _,step in ipairs(data.Steps) do if not allowed[step.Action] or type(step.Args)~='table' or type(step.Time)~='number' or type(step.Wave)~='number' then say('Invalid macro action • recording cannot be played') return end end
  m.Steps=data.Steps m.Token=(m.Token or 0)+1 local token=m.Token m.State='Playing' m.Index=0 m.PlayStart=os.clock() m.PausedTotal=0 m.Config.PlayRequested=true save() paintPlay() m.RefreshActionsUI()
  m.Runner=task.spawn(function()
   local heartbeat=game:GetService('RunService').Heartbeat
   local function active() return m.Alive and token==m.Token end
   local function waitFrame()
    heartbeat:Wait()
    while active() and m.State=='Paused' do heartbeat:Wait() end
    return active()
   end
   local offset=math.max(0,matchTime()-(tonumber(data.RecordOffset) or 0))
   if not clock.Known then
    for _,step in ipairs(data.Steps) do if step.Wave<wave() then offset=math.max(offset,step.Time) end end
   end
   local function elapsed()
    if clock.Known then return math.max(0,matchTime()-(tonumber(data.RecordOffset) or 0)) end
    return offset+os.clock()-m.PlayStart
   end
   local expected={}
   local upgradeTargets={}
   for i,step in ipairs(data.Steps) do
    if step.Action=='upgrade_unit_ingame' then
     local key=H:JSONEncode(step.Args[1]) expected[key]=(expected[key] or 0)+1 upgradeTargets[i]=step.UpgradeAfter or expected[key]
    end
   end
   local function alreadyDone(step,args,index)
    if step.Action=='upgrade_unit_ingame' and typeof(args[1])=='Instance' then
     return (tonumber(val(args[1]:FindFirstChild('_stats'),'upgrade')) or 0)>=(upgradeTargets[index] or math.huge)
    elseif step.Action=='spawn_unit' and typeof(args[2])=='CFrame' then
     local units=workspace:FindFirstChild('_UNITS') local position=args[2].Position
     if units then for _,tower in ipairs(units:GetChildren()) do
      if tower:IsA('Model') and owned(tower) and val(tower:FindFirstChild('_stats'),'uuid')==args[1] then
       local p=tower:GetPivot().Position if (Vector3.new(p.X,0,p.Z)-Vector3.new(position.X,0,position.Z)).Magnitude<1 then return true end
      end
     end end
    end
    return false
   end
   local ok,err=pcall(function()
    for i,step in ipairs(data.Steps) do
     -- Absolute deadlines avoid accumulating task.wait drift. After a delay,
     -- retain the original spacing rather than burst all overdue requests.
     local due=step.Time
     while active() do
      if m.State=='Playing' then
       local timeReady=elapsed()>=due or step.Wave<wave() local waveReady=wave()>=step.Wave
       if (m.Config.Timing=='Time' and timeReady) or (m.Config.Timing=='Wave' and waveReady) or (m.Config.Timing=='Hybrid' and timeReady and waveReady) then break end
      end
      if not waitFrame() then return end
     end
     if not active() then return end
     m.Index=i say((elapsed()>due+.2 and 'Catching up ' or 'Playing ')..i..' / '..#data.Steps..' • '..step.Action)
     local started=elapsed()
     while active() do
      if m.State=='Paused' and not waitFrame() then return end
      if elapsed()-started>=m.Config.Wait then say('Waiting • action '..i..' (unit / funds / cooldown)') started=elapsed() end
      local decoded,args=pcall(decode,step.Args)
      if not decoded then if not waitFrame() then return end continue end
      local play=env.FyrelithAutoPlay
      if step.Action=='sell_unit_ingame'then
       local id=typeof(args[1])=='Instance'and val(args[1]:FindFirstChild('_stats'),'id')
       if not play or not play.CanAutoSell or not play.CanAutoSell(id,args[1])then say('Skipped protected farm / buff sale • action '..i);break end
      elseif step.Action=='spawn_unit'and play and play.Config.Smart then
       local id
       for _,u in ipairs(play.GetEquipped(true))do if u.UUID==args[1]then id=u.Id break end end
       local valid=id and typeof(args[2])=='CFrame'and play.ValidateAutoAction({Action='Place',UnitId=id,CF={args[2]:GetComponents()}},nil,'macro')
       if not valid then say('Waiting • recorded position outside Smart circles');if not waitFrame()then return end;continue end
      end
      local buff=env.FyrelithAutoBuff
      if step.Action=='use_active_attack' and buff and buff.Alive and typeof(args[1])=='Instance' then
       local id=val(args[1]:FindFirstChild('_stats'),'id')
       if id and buff.Enabled[id] then say('Auto Buff controls this skill • action '..i) break end
      end
      if (step.Action=='vote_wave_skip' and wave()>step.Wave) or (step.Action=='vote_start' and wave()>0) then say('Vote already passed • action '..i) break end
      if alreadyDone(step,args,i) then say('Already applied • action '..i) break end
      local proof=evidence(step.Action,args,false)
      local sentAt=elapsed()
      local success,response=pcall(original,step.Action,table.unpack(args,1,args.n or #args))
      if not active() then return end
      local vote=step.Action=='vote_wave_skip' or step.Action=='vote_start'
      -- Vote calls can legitimately return nil, or false when the recorded
      -- vote window has passed. They must never block subsequent placements.
      local confirmed=success and not proof and (response==true or response==nil or vote)
      local verifyUntil=elapsed()+3
      if proof then
       repeat
        local checked,value=pcall(proof) confirmed=checked and value
        if confirmed or not active() then break end
        if not waitFrame() then return end
       until elapsed()>=verifyUntil
      end
      if confirmed then
       m.LastTiming={Index=i,Target=due,Sent=sentAt,Late=math.max(0,sentAt-due),Confirmed=true}
       break
      end
      -- Never blindly repeat an ambiguous request: it could place or upgrade twice.
      if not success or response~=false then
       -- Keep Play on, but never resend an ambiguous placement / upgrade.
       say('Waiting for confirmation • action '..i..' (Play off to cancel)')
       while active() do
        if proof then local checked,value=pcall(proof) if checked and value then confirmed=true break end end
        if alreadyDone(step,args,i) then confirmed=true break end
        if not waitFrame() then return end
       end
       if confirmed then break end
       return
      end
      say('Waiting • action '..i..' / '..#data.Steps..' (funds / tower / cooldown)')
      local retryAt=elapsed()+.1
      repeat if not waitFrame() then return end until elapsed()>=retryAt
     end
    end
   end)
   if token==m.Token then m.State='Idle' save() paintPlay() say(ok and ('Completed • waiting for the next match') or tostring(err)) end
  end)
 end
 function m.FinishPlayback()
  if m.State=='Playing' or (m.State=='Paused' and m.BeforePause=='Playing') then
   m.Token=(m.Token or 0)+1 m.State='Idle' save() paintPlay() say('Match ended • Play stays enabled for retry')
  end
 end
 function m.RestartForReplay()
  if not m.Alive then return end
  m.FinishPlayback()
  clock.Start=nil clock.Known=true api.MatchEnded=false
  task.spawn(function()
   task.wait(.5)
   local results=env.FyrelithGameReady.Services.GUIService.results_ui
   while m.Alive and results and results.screenGUI.Enabled do task.wait(.1) end
   if not m.Alive then return end
   clock.Start=os.clock()
   if m.Config.PlayRequested or m.Config.Auto then m.Play() end
  end)
 end
 library=picker('Saved macro',26,558,function() local t={} for n in pairs(m.Library) do table.insert(t,{id=n,name=n}) end table.sort(t,function(a,b) return a.name<b.name end) return t end,function() return m.Config.Name end,function(v) m.Select(v.id) end)
 button('MacroSave','Save',350,470,78,function() if name.Text==m.Config.Name and selected() then m.Save() else m.SaveName() end end,true).Size=UDim2.fromOffset(78,36)
 m.RefreshRecordSwitch=switch('MacroRecord','Record','On: start a new recording · Off: save and stop.',608,function()
  return m.State=='Recording' or (m.State=='Paused' and m.BeforePause=='Recording')
 end,function(v)
  if v then m.Record() else stop() m.Save() end
 end)
 button('MacroPause','Pause / Resume',26,658,195,function()
  if m.State=='Recording' or m.State=='Playing' then m.BeforePause=m.State m.PauseAt=os.clock() m.State='Paused' say('Paused')
  elseif m.State=='Paused' then m.PausedTotal+=os.clock()-m.PauseAt m.State=m.BeforePause say('Resumed • '..m.State) end
  paintPlay()
 end)
 button('MacroStop','Stop & Save',233,658,195,function() local recording=m.State=='Recording' or (m.State=='Paused' and m.BeforePause=='Recording') stop() if recording then m.Save() end end)
 paintPlay=switch('MacroPlay','Play','Play or stop the selected macro.',708,function() return m.Config.PlayRequested==true or m.State=='Playing' or (m.State=='Paused' and m.BeforePause=='Playing') end,function(v)
  if v then m.Play() else stop() end
 end)
 local confirmDelete
 button('MacroDelete','Delete',350,428,78,function()
  if m.State~='Idle' then say('Stop before deleting') return end
  if confirmDelete~=m.Config.Name then confirmDelete=m.Config.Name say('Click Delete again to remove '..m.Config.Name) return end
  m.Library[m.Config.Name]=nil confirmDelete=nil m.Steps={} m.Index=0 library.Set('Choose macro') save() say('Deleted saved macro')
 end).Size=UDim2.fromOffset(78,28)
 label(root,'MacroTitle','Tower Defense Macro',26,428,312,28,19,true).Name='MacroTitleCompact'
 ui('MacroTitle'):Destroy()
 if selected() then m.Select(m.Config.Name) else library.Set('Choose macro') end
 paintPlay()
 switch('MacroAuto','Auto Play','Run selected macro when its map loads.',760,function() return m.Config.Auto end,function(v) m.Config.Auto=v save() end)
 function m.ClearCurrent()
  if m.State~='Idle' then say('Stop before clearing the macro') return false end
  m.Steps={} m.Index=0 return m.Save()
 end
 function m.LoadSelected() return m.Select(m.Config.Name) end
 function m.RefreshLibrary()
  if m.State~='Idle' then say('Stop before refreshing saved macros') return false end
  local ok,data=pcall(function() return H:JSONDecode(readfile(file)) end)
  if ok and type(data.Library)=='table' then m.Library=data.Library library.Set(m.Config.Name or 'Choose macro') say('Saved macros refreshed') return true end
  say('Unable to read saved macros') return false
 end
 m.WaveActionStatus='Idle'
 local actionDone=false local actionBusy=false
 task.spawn(function()
  while m.Alive and gui.Parent do
   local current=wave()
   if Loader.IsLobby or api.MatchEnded or current==0 then actionDone=false end
   if m.Config.WaveActionEnabled and not Loader.IsLobby and not api.MatchEnded and current>0 and current>=(tonumber(m.Config.TargetWave) or 15) and not actionDone and not actionBusy then
    actionDone=true actionBusy=true m.WaveActionStatus='Running'
    local units=workspace:FindFirstChild('_UNITS') local count=0
    if units then for _,unit in ipairs(units:GetChildren()) do
     if not m.Alive or not m.Config.WaveActionEnabled then break end
     if owned(unit) then
      local selling=m.Config.WaveAction=='Sell All'or m.Config.WaveAction=='Sell Damage Only'
      local play=env.FyrelithAutoPlay
      local id=val(unit:FindFirstChild('_stats'),'id')
      if selling and(not play or not play.CanAutoSell or not play.CanAutoSell(id,unit))then continue end
      local ok,result=pcall(EP.invoke_server,selling and 'sell_unit_ingame' or 'upgrade_unit_ingame',unit)
      if ok and result~=false then count+=1 end task.wait(.15)
     end
    end end
    m.WaveActionStatus='Sent to '..count..' units' actionBusy=false
   end
   task.wait(.3)
  end
 end)
 function m.SaveConfig() return save() end
 local oldRestore=api.RestoreTeamHooks
 api.RestoreTeamHooks=function() if EP.invoke_server==wrapped then EP.invoke_server=original end if oldRestore then oldRestore() end end
 function m.Stop() if m.State=='Recording' or m.State=='Finishing' or (m.State=='Paused' and m.BeforePause=='Recording') then m.Save() end local requested=m.Config.PlayRequested m.Alive=false stop() m.Config.PlayRequested=requested save() if EP.invoke_server==wrapped then EP.invoke_server=original end end
 connect(gui.Destroying,m.Stop)
 root.Size=UDim2.new(1,0,0,850) main.CanvasSize=UDim2.fromOffset(0,850)
 task.spawn(function() while m.Alive and not api.Ready do task.wait(.1) end if m.Alive and (m.Config.Auto or m.Config.PlayRequested) and not Loader.IsLobby then task.wait(1) m.Play() end end)
end


do
 cfg.AutoStart=false cfg.AutoNext=false cfg.AutoRetry=false cfg.AutoSkip=false cfg.AutoNextRoom=false cfg.AutoNextPortal=false cfg.AutoLeave=false
 local saved=env.FyrelithLoadedSession
 if saved and saved.Main and saved.Main.Config then cfg.AutoStart=saved.Main.Config.AutoStart==true cfg.AutoNext=saved.Main.Config.AutoNext==true cfg.AutoRetry=saved.Main.Config.AutoRetry==true for _,key in ipairs({'AutoSkip','AutoNextRoom','AutoNextPortal','AutoLeave'}) do cfg[key]=saved.Main.Config[key]==true end end
 -- Match controls share the Auto Join surface.
 ui('DestinationCard').Size=UDim2.fromOffset(438,480)
 status.Position=UDim2.fromOffset(26,444) status.Size=UDim2.fromOffset(402,32)
 local paintStart=switch('AutoStart','Auto Start','Vote to start when the match is ready.',350,function() return cfg.AutoStart end,function(v) cfg.AutoStart=v end)
 local paintNext=switch('AutoNext','Auto Next','Continue when the next stage is available.',396,function() return cfg.AutoNext end,function(v) cfg.AutoNext=v end)
 paintStart() paintNext()
 -- Saved teams share the editor surface; retain the hidden card for theme listeners.
 ui('TeamSettingsCard').Size=UDim2.fromOffset(438,640)
 ui('TeamAssignmentsCard').Visible=false
 -- A single wide macro surface contains its controls and recorded actions.
 for _,child in ipairs(root:GetChildren()) do
  if child:IsA('GuiObject') and child.Position.X.Offset<450 and child.Position.Y.Offset>=414 and child~=status then
   child.Position+=UDim2.fromOffset(0,254)
  end
 end
 ui('MacroCard').Size=UDim2.fromOffset(438,590)
 ui('MacroPreviewCard').Visible=false
 ui('MacroPreviewTitle').Position=UDim2.fromOffset(26,1146)
 ui('MacroPreview').Position=UDim2.fromOffset(26,1182)
 ui('MacroPreview').Size=UDim2.fromOffset(402,108)
 -- Keep the macro directly below Auto Join, independent of the taller team column.
 for _,child in ipairs(root:GetChildren()) do
  if child:IsA('GuiObject') and child.Position.X.Offset<450 and child.Position.Y.Offset>=668 then
   child.Position-=UDim2.fromOffset(0,168)
  end
 end
 -- Place deletion beside the saved selection controls, before recording actions.
 ui('MacroDelete').Position=UDim2.fromOffset(184,694)
 ui('MacroDelete').Size=UDim2.fromOffset(244,32)
 for _,key in ipairs({'MacroRecord','MacroPause','MacroStop','MacroPlay','MacroAuto','MacroStatus','MacroPreviewTitle','MacroPreview'}) do
  local control=ui(key) if control then control.Position+=UDim2.fromOffset(0,44) end
 end
 ui('MacroCard').Size=UDim2.fromOffset(438,634)
 for _,child in ipairs(root:GetChildren()) do
  if child:IsA('GuiObject') and child.Position.X.Offset<450 and child.Position.Y.Offset>=500 then child.Position+=UDim2.fromOffset(0,46) end
 end
 ui('DestinationCard').Size=UDim2.fromOffset(438,526)
 status.Position=UDim2.fromOffset(26,490)
 local paintRetry=switch('AutoRetry','Auto Retry','Replay this stage when the match ends.',442,function() return cfg.AutoRetry end,function(v) cfg.AutoRetry=v end)
 paintRetry()
 root.Size=UDim2.fromOffset(908,1196) main.CanvasSize=UDim2.fromOffset(0,1196)
 -- Compact match controls in their own right-hand card.
 local macroTop=ui('MacroCard').Position.Y.Offset
 for _,child in ipairs(root:GetChildren()) do
  if child:IsA('GuiObject') then
   if child.Position.X.Offset>=450 then child.Position+=UDim2.fromOffset(0,306)
   elseif child.Position.Y.Offset>=macroTop then child.Position-=UDim2.fromOffset(0,142) end
  end
 end
 ui('DestinationCard').Size=UDim2.fromOffset(438,338)
 status.Position=UDim2.fromOffset(26,360)
 card('MatchControlsCard',462,8,438,294)
 label(root,'MatchControlsTitle','Match Controls',480,20,402,26,18,true)
 ui('AutoStart').Position=UDim2.fromOffset(480,54) ui('AutoStart').Title.Text='Auto Start Game'
 ui('AutoRetry').Position=UDim2.fromOffset(480,122) ui('AutoRetry').Title.Text='Auto Replay'
 ui('AutoNext').Position=UDim2.fromOffset(480,156) ui('AutoNext').Title.Text='Auto Next Story'
 switch('AutoSkipWave','Auto Skip Wave','',88,function() return cfg.AutoSkip end,function(v) cfg.AutoSkip=v end,480)
 switch('AutoNextRoom','Auto Next Room','',190,function() return cfg.AutoNextRoom end,function(v) cfg.AutoNextRoom=v end,480)
 switch('AutoNextPortal','Auto Next Portal','',224,function() return cfg.AutoNextPortal end,function(v) cfg.AutoNextPortal=v end,480)
 switch('AutoLeaveMatch','Auto Leave Match','',258,function() return cfg.AutoLeave end,function(v) cfg.AutoLeave=v local guard=env.FyrelithAutoLeaveGuard;if not v and guard then guard.Cancel()elseif v and api.MatchEnded and guard then guard.Arm()end end,480)
 ui('TeamNote').Visible=false
 local results=Loader.load_client_service(script,'GUIService').results_ui
 local ended=false local started=false local nextClicked=false
 local votes={Alive=true,Actions={},LastError=nil};api.MatchControls=votes
 function votes.NativeStartCallback(ui)
  if not ui or not ui.YesButton or type(getconnections)~='function'or not debug or type(debug.getupvalues)~='function'then return end
  local source=type(ui.init)=='function'and debug.info(ui.init,'s')
  if not source then return end
  local queue={};local seen={}
  for _,connection in ipairs(getconnections(ui.YesButton.Activated))do if type(connection.Function)=='function'then queue[#queue+1]={connection.Function,0}end end
  local cursor=1
  while cursor<=#queue and cursor<=64 do
   local item=queue[cursor];cursor+=1;local fn,depth=item[1],item[2]
   if not seen[fn]then
    seen[fn]=true;local values=debug.getupvalues(fn)
    if debug.info(fn,'s')==source then for _,value in pairs(values)do if value==ui then return fn end end end
    if depth<3 then for _,value in pairs(values)do if type(value)=='function'then queue[#queue+1]={value,depth+1}end end end
   end
  end
 end
 function votes.Step(name,enabled,open,key,confirmed)
  local ui,finished
  if name=='vote_start'then
   local data=workspace:FindFirstChild('_DATA');local start=data and data:FindFirstChild('VoteStart');finished=start and start:FindFirstChild('VotingFinished')
   local waves=workspace:FindFirstChild('_waves_started');local services=env.FyrelithGameReady and env.FyrelithGameReady.Services
   local G=services and services.GUIService;ui=G and(G.start_vote_ui or G.vote_start_ui)
   if finished then open=not Loader.IsLobby and not api.MatchEnded and finished.Value==false and not(waves and waves.Value==true);confirmed=false end
  end
  local state=votes.Actions[name]
  if not state then state={Next=-math.huge,Generation=0};votes.Actions[name]=state end
  if state.Key~=key or(open and state.Open==false)then
   state.Generation+=1;state.Key=key;state.Accepted=false;state.Submitted=false;state.StartConfirmed=false;state.Next=-math.huge
  end
  state.Open=open==true
  if name=='vote_start'and finished and finished.Value==true and state.Submitted then state.StartConfirmed=true end
  if not enabled or not open or confirmed or state.Accepted or state.Submitted or state.Pending or os.clock()<state.Next then return false end
  if name=='vote_start'and ui and ui.voted==true then state.Submitted=true;state.Via='Existing native vote';return false end
  state.Pending=true;state.Next=os.clock()+5;state.Requests=(state.Requests or 0)+1;state.LastSent=os.clock()
  local generation=state.Generation
  task.spawn(function()
   if not api.Alive then state.Pending=false;return end
   local callback=name=='vote_start'and votes.NativeStartCallback(ui)
   local ok,result
   if callback then state.Via='Native Yes';ok,result=pcall(callback)
   else state.Via='Endpoint';ok,result=pcall(EP.invoke_server,name)end
   state.Pending=false;state.LastReturned=os.clock();state.LastResponse=ok and tostring(result)or nil
   if state.Generation~=generation then return end
   state.Accepted=ok and result==true
   state.Submitted=ok and(callback and ui.voted==true or result==true)
   state.LastError=not ok and tostring(result)or result==false and'Vote declined; retrying'or nil
   votes.LastError=state.LastError
  end)
  return true
 end
 function votes.Reset()
  for _,state in pairs(votes.Actions)do state.Generation+=1;state.Accepted=false;state.Submitted=false;state.StartConfirmed=false;state.Key=nil;state.Open=nil;state.Next=-math.huge end
  local services=env.FyrelithGameReady and env.FyrelithGameReady.Services;local G=services and services.GUIService
  local ui=G and(G.start_vote_ui or G.vote_start_ui);if ui then ui.voted=false end
 end
 local function matchVoteOpen(name)
  local services=env.FyrelithGameReady.Services
  local guiService=services and services.GUIService
  local ui=guiService and (name=='vote_start'and(guiService.start_vote_ui or guiService.vote_start_ui)or guiService.vote_wave_ui)
  local screen=ui and ui.screenGUI or player.PlayerGui:FindFirstChild(name=='vote_start' and 'VoteStart' or 'VoteSkip')
  if name=='vote_start' then
   local data=workspace:FindFirstChild('_DATA');local vote=data and data:FindFirstChild('VoteStart')
   local finished=vote and vote:FindFirstChild('VotingFinished')
   if finished and finished.Value==true then return false,ui and ui.voted==true end
   if screen then return screen.Enabled==true,ui and ui.voted==true end
   return finished~=nil and finished.Value==false,false
  end
  return screen~=nil and screen.Enabled==true,false
 end


 local lastResultClick=-math.huge local lastFinalClick=-math.huge local lastSkip=-math.huge
 local function clickResult(button)
  if not button or not button.Visible or not button:IsA('GuiButton') or type(getconnections)~='function' then return false end
  local callbacks=getconnections(button.Activated) if #callbacks==0 then callbacks=getconnections(button.MouseButton1Click) end
  if #callbacks==0 then return false end
  for _,callback in ipairs(callbacks) do task.spawn(function() pcall(function() callback:Fire() end) end) end
  return true
 end
 local function anyAutomation()
  if env.FyrelithSummer and env.FyrelithSummer.WantsMatchControl()then return true end
  if env.FyrelithDungeon and env.FyrelithDungeon.Alive and env.FyrelithDungeon.Config.Enabled then return true end
  local autoPlay=env.FyrelithAutoPlay
  if autoPlay and autoPlay.Alive then local c=autoPlay.Config if c.Place or c.Upgrade or c.Abilities or c.Plan or c.Walk or c.Restore then return true end end
  if env.FyrelithAutoChallenge and env.FyrelithAutoChallenge.Enabled then return true end
  if api.Enabled or cfg.AutoStart or cfg.AutoNext or cfg.AutoRetry or cfg.AutoSkip or cfg.AutoNextRoom or cfg.AutoNextPortal or cfg.AutoLeave then return true end
  local macro=env.FyrelithMacro
  if macro and (macro.State~='Idle' or macro.Config.Auto) then return true end
  for _,key in ipairs({'FyrelithAutoSummon','FyrelithAutoTrait','FyrelithGoldShop','FyrelithAutoClaim','FyrelithRedeemCodes'}) do local feature=env[key] if feature and feature.Enabled then return true end end
  return false
 end
 local function finishRecording()
  local m=env.FyrelithMacro
  if m and (m.State=='Recording' or (m.State=='Paused' and m.BeforePause=='Recording')) then
   local token=m.Token m.State='Finishing' api.MatchEnded=true
   if m.RefreshActionsUI then m.RefreshActionsUI() end
   pcall(m.Save)
   local text=ui('MacroStatus') if text then text.Text='Match ended • recording stopped, saving final actions…' end
   task.delay(3.2,function()
    if not m.Alive or m.Token~=token or m.State~='Finishing' then return end
    m.Token=(m.Token or 0)+1 m.State='Idle'
    local ok,saved=pcall(m.Save)
    m.Message=ok and saved~=false and 'Match ended • recording saved' or ('Save failed • '..tostring(m.SaveError or saved))
    if text and text.Parent then text.Text=m.Message end
    if m.RefreshActionsUI then m.RefreshActionsUI() end
   end)
  end
 end
 local hookedResults,originalResults,wrappedResults,originalReplay,wrappedReplay
 local function installResultsHook()
  local current=env.FyrelithGameReady.Services.GUIService.results_ui
  if not current then return end results=current
  if hookedResults==current or type(current.show_results)~='function' then return end
  if api.RestoreResultHooks then api.RestoreResultHooks() end
  hookedResults=current originalResults=current.show_results
  wrappedResults=function(self,...)
   local leave=env.FyrelithAutoLeaveGuard;if leave then leave.Arm()end
   if api.Alive then api.MatchEnded=true finishRecording() local macro=env.FyrelithMacro if macro and macro.FinishPlayback then macro.FinishPlayback() end end
   local result=table.pack(originalResults(self,...))
   local webhook=env.FyrelithWebhook
   if webhook and webhook.Alive then webhook.OnResults(self)end
   return table.unpack(result,1,result.n)
  end
  current.show_results=wrappedResults
  originalReplay=current.on_replay_started
  if type(originalReplay)=='function' then
   wrappedReplay=function(self,...)
    votes.Reset();started=false;ended=false;api.MatchEnded=false;lastFinalClick=-math.huge;lastResultClick=-math.huge
    local leave=env.FyrelithAutoLeaveGuard;if leave and leave.OnReplay()then return originalReplay(self,...)end
    local macro=env.FyrelithMacro if api.Alive and macro and macro.RestartForReplay then task.defer(macro.RestartForReplay) end
    local black=env.FyrelithBlackScreen
    if api.Alive and black and black.Enabled and black.Reapply then
     task.delay(.15,function() black.Reapply() end)
     task.delay(1,function() black.Reapply() end)
    end
    return originalReplay(self,...)
   end
   current.on_replay_started=wrappedReplay
  end
  api.RestoreResultHooks=function()
   if hookedResults and hookedResults.show_results==wrappedResults then hookedResults.show_results=originalResults end
   if hookedResults and wrappedReplay and hookedResults.on_replay_started==wrappedReplay then hookedResults.on_replay_started=originalReplay end
  end
 end
 installResultsHook()
 task.spawn(function()
  while api.Alive do
   local iterationOK,iterationError=pcall(function()
   installResultsHook()
   local resultOpen=not Loader.IsLobby and results and results.screenGUI and results.screenGUI.Enabled
   local finished=resultOpen and results.Finished and results.Finished.Visible
   if resultOpen then ended=true api.MatchEnded=true finishRecording() local macro=env.FyrelithMacro if macro and macro.FinishPlayback then macro.FinishPlayback() end
   elseif ended then ended=false api.MatchEnded=false end
   local challenge=env.FyrelithAutoChallenge
   local smart=env.FyrelithAutoPlay
   local smartMatch=smart and smart.Alive and smart.WantsMatchControl and smart.WantsMatchControl()
   local startOpen,startConfirmed=matchVoteOpen('vote_start')
   local skipOpen=matchVoteOpen('vote_wave_skip')
   local canVote=not Loader.IsLobby and not resultOpen
   local wave=workspace:FindFirstChild('_wave_num')
   local waveKey=wave and wave.Value or 0
   votes.Step('vote_start',cfg.AutoStart or smartMatch or (env.FyrelithDungeon and env.FyrelithDungeon.WantsStart()) or (challenge and challenge.Enabled and challenge.InChallenge),canVote and startOpen,game.JobId,startConfirmed)
   votes.Step('vote_wave_skip',cfg.AutoSkip,canVote and skipOpen,waveKey,false)
   if anyAutomation() and resultOpen then
    if not finished then
     -- The first Next advances the XP/reward screen; it does not select a new stage.
     if os.clock()-lastResultClick>=1 then
      lastResultClick=os.clock()
      if results.Holder and results.Holder.Visible then
       clickResult(results.NextButton)
      else
       local summon=env.FyrelithAutoSummon
       if summon and summon.ClearSummonScreen then task.spawn(function() pcall(summon.ClearSummonScreen) end) end
      end
      local overview=env.FyrelithGameReady.Services.GUIService.unit_overview_ui
      if overview and type(overview.hide)=='function' then pcall(overview.hide,overview) end
     end
    elseif not (env.FyrelithSummer and env.FyrelithSummer.HandleResults(results)) and not (env.FyrelithDungeon and env.FyrelithDungeon.OwnsMatch()) and not (env.FyrelithMacro and env.FyrelithMacro.State=='Finishing') and os.clock()-lastFinalClick>=5 then
     local level=Loader.LevelData or {} local victory=results.settings and results.settings.victory
     local target=cfg.AutoLeave and results.ReturnLobby or nil
     local challenge=env.FyrelithAutoChallenge
     local challengeReturn=challenge and challenge.Priority
     if challengeReturn then target=results.ReturnLobby end
     if not target and cfg.AutoNext and level._is_actual_storymode and victory and results.NextLevelButton and results.NextLevelButton.Visible then target=results.NextLevelButton end
     if not target and not challengeReturn and cfg.AutoNextRoom and victory and (level._gamemode=='infinite_tower' or level._dungeon) then target=results.NextRetry end
     local portalSent=false
     if not target and not challengeReturn and cfg.AutoNextPortal and level._is_map_or_portal_level and (not level._owner_player_userid or level._owner_player_userid==player.UserId) then
      local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
      local C=Loader.load_core_service(script,'LevelServiceCore')
      local inventory=U.session.inventory.inventory_profile_data.unique_items or {}
      for _,item in pairs(inventory) do
       local uuid=item.uuid
       local valid,allowed=pcall(C.is_valid_replay_portal_item,U.session,uuid)
       if uuid and valid and allowed then
        lastFinalClick=os.clock() portalSent=true
        task.spawn(function() pcall(EP.invoke_server,'set_game_finished_vote','replay',{item_uuid=uuid}) end)
        break
       end
      end
     end
     if not target and not challengeReturn and not portalSent and (cfg.AutoRetry or smartMatch) then target=results.NextRetry end
     if not target and not portalSent and cfg.AutoLeave then target=results.ReturnLobby end
     if target and clickResult(target) then lastFinalClick=os.clock() nextClicked=true end
    end
   end
   end)
   if not iterationOK then votes.LastError=tostring(iterationError)end
   task.wait(.25)
  end
 end)
end

do
 local old=env.FyrelithAutoClaim if old and old.Stop then pcall(old.Stop) end
 local a={Alive=true,Enabled=false,Selected={},Attempted={}} env.FyrelithAutoClaim=a
 local file='FyrelithAutoClaim_'..player.UserId..'_'..game.GameId..'.json'
 local H=game:GetService('HttpService')
 pcall(function() local d=H:JSONDecode(readfile(file)) a.Enabled=d.Enabled==true a.Selected=type(d.Selected)=='table' and d.Selected or {} end)
 local definitions={
  {'login','Daily login','claim_daily_reward'},
  {'battlepass','Battle Pass','claim_battlepass_rewards'},
  {'tournament','Tournament rewards','claim_previous_tournament_rewards'},
  {'ranked','Ranked / bracket rewards','request_claim_bracket_rewards'},
  {'lottery','Event lottery rewards','request_claim_event_lottery_reward'},
  {'calendar','Event calendar','claim_christmas_calendar_reward'},
  {'daily','Daily quests'}, {'weekly','Weekly quests'}, {'story','Story quests'},
  {'event','Event quests'}, {'infinite','Infinite quests'}, {'other','Other completed quests'}, {'levels','Player level rewards'}
 }
 local function save() pcall(function() writefile(file,H:JSONEncode({Enabled=a.Enabled,Selected=a.Selected})) end) end
 local utility=main.Parent.Utilities
 local panel=card('AutoClaimCard',8,350,438,208) panel.Parent=utility
 label(panel,'Title','Auto Claim',18,12,840,26,19,true)
 local paints={}
 local function addSwitch(id,title,hint,x,y,get,set)
  local key='Claim_'..id
  local paint=switch(key,title,hint,0,get,set)
  local row=ui(key) row.Parent=panel row.Position=UDim2.fromOffset(x,y)
  table.insert(paints,paint) paint()
 end
 addSwitch('Enabled','Auto Claim','Claim selected reward types automatically.',18,46,function() return a.Enabled end,function(v) a.Enabled=v save() end)
 local choose=new('TextButton',{Name='ChooseClaimTypes',Text='Choose rewards…',Position=UDim2.fromOffset(18,100),Size=UDim2.fromOffset(402,36),BackgroundTransparency=.4,TextColor3=white,TextSize=13,Font=Enum.Font.Gotham,TextTruncate=Enum.TextTruncate.AtEnd,AutoButtonColor=false,ZIndex=3},panel)
 bind(choose,'BackgroundColor3','field') round(choose,8) border(choose)
 local menu=new('CanvasGroup',{Name='ClaimTypesMenu',Visible=false,Position=UDim2.fromOffset(18,142),Size=UDim2.fromOffset(402,246),BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=70},panel)
 bind(menu,'BackgroundColor3','card') round(menu,8) border(menu)
 local search=new('TextBox',{Name='Search',Text='',PlaceholderText='Search rewards…',ClearTextOnFocus=false,Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(386,30),TextColor3=white,TextSize=13,Font=Enum.Font.Gotham,BackgroundTransparency=.3,ZIndex=71},menu)
 bind(search,'BackgroundColor3','field') round(search,6)
 local list=new('ScrollingFrame',{Name='Options',Position=UDim2.fromOffset(6,44),Size=UDim2.fromOffset(390,196),CanvasSize=UDim2.new(),ScrollBarThickness=3,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=71},menu)
 local function summary()
  local names={} for _,d in ipairs(definitions) do if a.Selected[d[1]] then table.insert(names,d[2]) end end
  choose.Text=#names>0 and table.concat(names,', ') or 'Choose rewards…'
  selectionVisual(choose,#names>0)
 end
 local rows={}
 for i,d in ipairs(definitions) do
  local row=new('TextButton',{Name='ClaimOption_'..d[1],Text=d[2],Position=UDim2.fromOffset(2,(i-1)*34+2),Size=UDim2.new(1,-10,0,30),TextColor3=white,TextSize=13,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,BackgroundTransparency=.55,AutoButtonColor=false,ZIndex=72},list)
  bind(row,'BackgroundColor3','field') round(row,6) new('UIPadding',{PaddingLeft=UDim.new(0,10)},row)
  local function paint() row.TextColor3=a.Selected[d[1]] and white or muted selectionVisual(row,a.Selected[d[1]]==true) end
  rows[d[1]]=row table.insert(paints,paint) paint()
  connect(row.Activated,function() a.Selected[d[1]]=not a.Selected[d[1]] save() paint() summary() end)
 end
 list.CanvasSize=UDim2.fromOffset(0,#definitions*34+4)
 connect(search:GetPropertyChangedSignal('Text'),function()
  local count=0 for _,d in ipairs(definitions) do local row=rows[d[1]] local show=d[2]:lower():find(search.Text:lower(),1,true)~=nil row.Visible=show if show then row.Position=UDim2.fromOffset(2,count*34+2) count+=1 end end
  list.CanvasSize=UDim2.fromOffset(0,count*34+4) list.CanvasPosition=Vector2.zero
 end)
 local dismiss,scrollWatch,resizeWatch
 local function dismissClaimMenu(immediate)
  if dismiss then dismiss:Destroy() dismiss=nil end
  if scrollWatch then scrollWatch:Disconnect() scrollWatch=nil end
  if resizeWatch then resizeWatch:Disconnect() resizeWatch=nil end
  animateDropdown(menu,false,menu:GetAttribute('PopupHeight') or 246)
  if immediate then
   local animation=dropdownAnimations[menu] if animation then animation:Cancel() dropdownAnimations[menu]=nil end
   menu.Visible=false menu.GroupTransparency=1 menu:SetAttribute('Open',false)
   local owner=menu.Parent
   if owner and owner:IsA('GuiObject') then owner.ZIndex=owner:GetAttribute('DropdownBaseZ') or 1 end
  end
 end
 connect(choose.Activated,function()
  if menu:GetAttribute('Open') then dismissClaimMenu() return end
  local page=panel.Parent
  if not page:IsA('ScrollingFrame') then return end
  local popupLayer=main.Parent:FindFirstChild('ClaimPopupLayer')
  if not popupLayer then popupLayer=new('Frame',{Name='ClaimPopupLayer',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=200,Active=false},main.Parent) end
  local pageScale=math.max(.01,page.AbsoluteSize.X/page.Size.X.Offset)
  local viewTop=(page.AbsolutePosition.Y-popupLayer.AbsolutePosition.Y)/pageScale
  local viewHeight=page.AbsoluteWindowSize.Y/pageScale
  local viewBottom=viewTop+viewHeight
  local anchor=(choose.AbsolutePosition.Y-popupLayer.AbsolutePosition.Y)/pageScale
  local anchorX=(choose.AbsolutePosition.X-popupLayer.AbsolutePosition.X)/pageScale
  local below=anchor+choose.AbsoluteSize.Y/pageScale+6
  local down=math.max(0,viewBottom-below-8)
  local up=math.max(0,anchor-viewTop-8)
  local openAbove=down<246 and up>down
  local height=math.min(246,math.max(80,openAbove and up or down))
  local top=openAbove and anchor-height-6 or below
  top=math.clamp(top,viewTop+6,math.max(viewTop+6,viewBottom-height-6))
  menu.Parent=popupLayer
  menu:SetAttribute('ViewportPopup',true)
  menu.Position=UDim2.fromOffset(anchorX,top)
  menu:SetAttribute('RestY',top) menu:SetAttribute('PopupHeight',height)
  list.Size=UDim2.fromOffset(390,height-50)
  list.Active=true list.ScrollingEnabled=true list.ScrollingDirection=Enum.ScrollingDirection.Y
  list.CanvasPosition=Vector2.zero
  dismiss=new('TextButton',{Name='ClaimMenuDismiss',Text='',BackgroundTransparency=1,AutoButtonColor=false,Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),ZIndex=69},popupLayer)
  dismiss:SetAttribute('ViewportPopup',true)
  dismiss.Activated:Connect(function() dismissClaimMenu() end)
  animateDropdown(menu,true,height)
  scrollWatch=page:GetPropertyChangedSignal('CanvasPosition'):Connect(function() dismissClaimMenu(true) end)
  resizeWatch=page:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() dismissClaimMenu(true) end)
 end)
 for _,page in ipairs(main.Parent:GetChildren()) do
  if page:IsA('ScrollingFrame') then
   connect(page:GetPropertyChangedSignal('Visible'),function()
    if not panel.Parent.Visible then dismissClaimMenu(true) end
   end)
  end
 end
 connect(hostCanvas.Parent:GetPropertyChangedSignal('Visible'),function()
  if not hostCanvas.Parent.Visible then dismissClaimMenu(true) end
 end)
 summary()
 local status=label(panel,'Status','',18,164,402,24,12) status.TextColor3=muted
 local function paint() for _,f in ipairs(paints) do f() end end
 connect(appearance:GetPropertyChangedSignal('BackgroundColor3'),paint) connect(accentIcon:GetPropertyChangedSignal('ImageColor3'),paint)
 -- Attempts are session-only cooldowns, never permanent claim confirmations.
 local nextAttempt={}local failures={}local inFlight={}
 a.Pending=0 a.Attempts=0 a.Claimed=0
 local function profile()
  local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
  return U and U.session and U.session.profile_data
 end
 local function request(key,revision,endpoint,verify,...)
  if not a.Alive or not a.Enabled or not Loader.IsLobby then return false end
  local lock=endpoint..':'..tostring(key)
  local cooldown=lock..':'..tostring(revision)
  if inFlight[lock]or os.clock()<(nextAttempt[cooldown]or 0)or a.Pending>=4 or(a.ScheduledThisPass or 0)>=3 then return false end
  a.ScheduledThisPass=(a.ScheduledThisPass or 0)+1
  local delay=(a.ScheduledThisPass-1)*.15 local args=table.pack(...)
  inFlight[lock]=true a.Pending+=1 nextAttempt[cooldown]=os.clock()+15
  task.spawn(function()
   task.wait(delay)
   if not a.Alive or not a.Enabled then inFlight[lock]=nil a.Pending-=1 return end
   a.Attempts+=1
   local ok,res=pcall(EP.invoke_server,endpoint,table.unpack(args,1,args.n))
   local verified=false local deadline=os.clock()+2.5
   if ok then repeat
    if verify then local checked,value=pcall(verify)verified=checked and value==true end
    if verified or not a.Alive or not a.Enabled then break end
    task.wait(.1)
   until os.clock()>=deadline end
   inFlight[lock]=nil a.Pending-=1
   if not a.Alive then return end
   if verified or ok and res==true then
    failures[cooldown]=nil a.Claimed+=1 a.LastError=nil
    a.LastNotice='Claimed • '..tostring(key)
    nextAttempt[cooldown]=os.clock()+15
   elseif ok and res==nil then
    -- Several native claim endpoints acknowledge with nil; data is the proof.
    a.LastError=nil a.LastNotice='Waiting for reward state to refresh'
    nextAttempt[cooldown]=os.clock()+30
   else
    failures[cooldown]=math.min((failures[cooldown]or 0)+1,4)
    nextAttempt[cooldown]=os.clock()+math.min(60,5*2^failures[cooldown])
    a.LastError=not ok and tostring(res)or nil
    a.LastNotice=not ok and('Reward request failed • '..tostring(key))or('Reward unavailable • checking again later')
   end
   a.LastNoticeAt=os.clock()status.Text=a.LastNotice
  end)
  return true
 end
 a.Request=request

 local function ready(kind,p)
  local G=env.FyrelithGameReady.Services.GUIService
  if kind=='login' then
   local waitTime=tonumber(Loader.load_data(script,'GameplaySettings').DAILY_REWARD_WAIT)
   local last=tonumber(p.last_daily_reward_claimed_time) or 0
   return waitTime and os.time()-last>=waitTime,tostring(last)
  elseif kind=='battlepass' then
   local settings=Loader.load_data(script,'GameplaySettings')
   local id=settings.CURRENT_BATTLEPASS
   local definition=id and Loader.load_data(script,'BattlePass')[id]
   local data=id and (p.battlepass_data or {})[id]
   if definition and data then
    local claimed=data.claimed_tiers or {}
    for tier,reward in pairs(definition.tiers or {})do
     if (tonumber(reward.xp_required) or math.huge)<=(tonumber(data.xp) or 0) and (tonumber(reward._unlock_time) or 0)<=os.time() then
      local function has(track) local t=claimed[track] or {} return t[tostring(tier)] or t[tonumber(tier)] end
      if not has('normal') or (data.has_premium and not has('premium')) then return true,tostring(id) end
     end
    end
   end
  elseif kind=='ranked' then
   local core=Loader.load_core_service(script,'InfiniteTowerServiceCore')
   local season=core._PAST_SEASON
   local ranking=(p._legacy_infinity_castle_rankings or {})[season]
   return ranking and ranking._final_ranking~=nil and not ranking._claimed_rewards,tostring(season)
  elseif kind=='calendar' then
   local S=Loader.load_client_service(script,'SpecialEventServiceClient')
   local day=S and S.christmas_calendar_available_day
   local holiday=Loader.load_data(script,'HolidayRewards')
   local calendar=holiday._login_calendar_id and p.login_calendar and p.login_calendar[holiday._login_calendar_id]
   local claimed=calendar and calendar.days_claimed or p.christmas_calendar and p.christmas_calendar.days_claimed
   if day and (not claimed or (not claimed[tostring(day)] and not claimed[tonumber(day)])) then return true,tostring(holiday._login_calendar_id)..':'..tostring(day) end
  elseif kind=='tournament' then
   local service=Loader.load_client_service(script,'TournamentServiceClient')
   local previous=service and service._PREVIOUS_TOURNAMENT
   local scores=p.tournament_data and p.tournament_data.tournament_scores or {}
   local entry=previous and scores[previous.tournament_id]
   return entry and entry.final_ranking~=nil and not(entry.claimed_rewards or entry._claimed_rewards or entry.rewards_claimed),previous and tostring(previous.tournament_id)
  elseif kind=='lottery' then
   local service=Loader.load_client_service(script,'EventLotteryServiceClient')
   local data=p.event_lottery_data or {}
   local current=service and tonumber(service.current_interval)
   local bought=tonumber(data.ticket_bought_in_interval)
   return data.current_ticket~=nil and current~=nil and bought==current-1 and not(data.claimed_rewards or data._claimed_rewards or data.reward_claimed),tostring(bought)
  end
  return false
 end
 local function questCategory(t)
  t=tostring(t):lower()
  for _,kind in ipairs({'daily','weekly','story','event','infinite'}) do if t:find(kind,1,true) then return kind end end
  return 'other'
 end
 function a.IsQuestComplete(session,quest)
  local core=Loader.load_core_service(script,'QuestClassesCore')
  local ok,complete,progress,target=pcall(core.is_quest_complete,session,quest)
  if ok then return complete==true,progress,target end
  local info=quest.quest_info or{}local amount=info.quest_class and tonumber(info.quest_class.amount)
  local current=quest.quest_progress and tonumber(quest.quest_progress.amount)
  return amount~=nil and current~=nil and current>=amount,current,amount
 end
 local function protected(key,fn)
  local ok,err=pcall(fn)
  if not ok then a.LastError=tostring(err) status.Text='Waiting for '..key..' data…' end
 end
 function a.Check()
  if not Loader.IsLobby or not a.Alive or not a.Enabled then return end
  a.ScheduledThisPass=0
  local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
  local p=U.session and U.session.profile_data
  if type(p)~='table' then return end
  for _,d in ipairs(definitions) do
   if d[3] and a.Selected[d[1]] then protected(d[2],function()
    local canClaim,revision=ready(d[1],p)
    if canClaim then request(d[2],revision,d[3],function()
     local fresh=profile()if not fresh then return false end
     local stillReady=ready(d[1],fresh)return not stillReady
    end)end
   end) end
  end
  if a.Selected.levels then protected('level rewards',function()
   local C=Loader.load_core_service(script,'LevelServiceCore')
   local stats=player:FindFirstChild('_stats') local xp=stats and stats:FindFirstChild('player_xp')
   if not xp then return end
   local current=C.calculate_level(player,xp.Value)
   local claimed=p.level_rewards_claimed or {}
   for _,d in pairs(Loader.load_data(script,'PlayerLevelRewards')) do
    if type(d)=='table' then
     local level=tonumber(d.level)
     if level and level<=current and not claimed[tostring(level)] and not claimed[level] then
      request('Level '..level,tostring(level),'claim_player_level_rewards',function()
       local fresh=profile()local rewards=fresh and fresh.level_rewards_claimed or{}
       return rewards[tostring(level)]==true or rewards[level]==true
      end,d.level)
     end
    end
   end
  end) end
  -- Snapshot the queue: a successful redemption can replace the live quest table.
  local queue={}
  for id,q in pairs(p.quest_handler and p.quest_handler.quests or {}) do
   if type(q)=='table' then table.insert(queue,{Id=id,Quest=q}) end
  end
  for _,entry in ipairs(queue) do
   if not a.Enabled or not a.Alive or not Loader.IsLobby then break end
   protected('quest',function()
    local q=entry.Quest local info=q.quest_info or {}
    local complete,progress,target=a.IsQuestComplete(U.session,q)
    if a.Selected[questCategory(q.quest_type)]and complete then
     request(q.uuid or entry.Id,tostring(q.creation_time)..':'..tostring(info.quest_class and info.quest_class.class),'redeem_quest',function()
      local fresh=profile()local quests=fresh and fresh.quest_handler and fresh.quest_handler.quests
      if not quests then return false end
      for id,live in pairs(quests)do if id==entry.Id or live.uuid==(q.uuid or entry.Id)then return false end end
      return true
     end,q.uuid or entry.Id)
    end
   end)
  end
  if a.Pending>0 then status.Text='Claiming rewards • '..a.Pending..' pending'
  elseif not next(a.Selected)then status.Text='Select reward types first'
  elseif not a.LastNoticeAt or os.clock()-a.LastNoticeAt>5 then status.Text='No claimable rewards • checking automatically' end
 end
 a.Ready=ready
 function a.Stop() a.Alive=false save() panel:Destroy() end
 connect(gui.Destroying,a.Stop)
 utility.CanvasSize=UDim2.fromOffset(0,856)
 task.spawn(function()
  while a.Alive and gui.Parent do
   if a.Enabled and api.Ready then local ok,err=pcall(a.Check) if not ok then a.LastError=tostring(err)status.Text='Waiting for reward data…' end
   elseif not a.Enabled then status.Text='Auto Claim paused' end
   if a.Enabled and not Loader.IsLobby then status.Text='Waiting for lobby' end
   task.wait(2)
  end
 end)
end

task.spawn(function()
 local G=env.FyrelithGameReady.Services.GUIService
 while api.Alive and gui.Parent and Loader.IsLobby and (type(G.trait_reroll_ui)~='table' or type(G.collection_ui)~='table' or type(G.trait_reroll_ui.show)~='function' or type(G.collection_ui.select_unit)~='function') do task.wait(.1) end
 if not api.Alive or not gui.Parent then return end
 local old=env.FyrelithAutoTrait if old and old.Stop then pcall(old.Stop) end
 local G=env.FyrelithGameReady.Services.GUIService local UI=G.trait_reroll_ui or {}
 local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
 local Traits=Loader.load_data(script,'Traits') local Items=Loader.load_data(script,'Items') local Units=Loader.load_data(script,'Units')
 local Core=Loader.load_core_service(script,'UnitServiceCore') local H=game:GetService('HttpService')
 local a={Alive=true,Enabled=false,Config={Items={},Targets={}},Token=0,ConfirmedRolls=0} env.FyrelithAutoTrait=a
 local file='FyrelithTrait_'..player.UserId..'_'..game.GameId..'.json'
 pcall(function() local d=H:JSONDecode(readfile(file)) if type(d)=='table' then a.Config=d end end)
 local cfg=a.Config cfg.Items=cfg.Items or {} cfg.Targets=cfg.Targets or {}
 local function save() pcall(function() writefile(file,H:JSONEncode(cfg)) end) end
 local utility=main.Parent.Utilities local panel=card('AutoTraitCard',462,350,438,430) panel.Parent=utility
 local summonCard=utility:FindFirstChild('AutoSummon')
 if summonCard then panel.Position=UDim2.fromOffset(462,summonCard.Position.Y.Offset+summonCard.Size.Y.Offset+12) end
 label(panel,'Title','Auto Reroll Trait',18,12,850,28,19,true)
 local unitText=label(panel,'Unit','No unit selected',18,106,402,32,14,true)
 label(panel,'ItemTitle','Items',18,146,402,24,13,true)
 label(panel,'TargetTitle','Target traits',18,230,402,22,13,true)
 local status=label(panel,'Status','',18,380,402,32,12) status.TextColor3=muted
 local function report(text) a.Status=text status.Text=text end
 local paints={} local paintToggle=function() end
 local function unit() return cfg.Unit and U.session.collection:get_unit_by_uuid(cfg.Unit) end
 local function traitText(u)
  local names={} for _,t in ipairs(u and u.traits or {}) do local d=Traits[t.trait] if d then local tier=tostring(t.tier or '1') table.insert(names,d.name..(not d.singular and (' '..tier) or '')) end end
  return #names>0 and table.concat(names,' + ') or 'No trait'
 end
 local function targetFound(u)
  for _,t in ipairs(u and u.traits or {}) do if cfg.Targets[t.trait..':'..tostring(t.tier or '1')] then return true end end return false
 end
 local function refreshUnit()
  local u=unit() unitText.Text=u and ((Units[u.unit_id] and Units[u.unit_id].name or u.unit_id)..' · '..traitText(u)) or 'No unit selected'
 end
 local function makeButton(name,text,x,y,w,h,callback)
  local b=new('TextButton',{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=.4,TextColor3=white,TextSize=13,Font=Enum.Font.Gotham,AutoButtonColor=false,ZIndex=3},panel)
  bind(b,'BackgroundColor3','field') round(b,8) border(b) connect(b.Activated,callback) return b
 end
 local function stop(text) a.Enabled=false cfg.Enabled=false a.Token+=1 save() paintToggle() report(text or 'Stopped') end
 local choosing=false
 local wasOpen
 local function restorePickerWindow()
  choosing=false
  local restore=wasOpen wasOpen=nil
  local control=gui:FindFirstChild('SetWindowOpen')
  if restore==true and control then pcall(function() control:Invoke(true) end) end
 end
 local originalShow=UI.show or function() end
 local showHook
 showHook=function(self,uuid,...)
  if choosing and a.Alive then
   choosing=false
   local selected=U.session.collection:get_unit_by_uuid(uuid)
   if selected then cfg.Unit=uuid save() refreshUnit() report('Selected unit • '..traitText(selected)) end
   task.defer(restorePickerWindow)
   return
  end
  return originalShow(self,uuid,...)
 end
 UI.show=showHook
 local collection=G.collection_ui or {}
 local originalSelect=collection.select_unit or function() end
 local selectHook=function(self,frame,data,...)
  if choosing and a.Alive and self.mode=='unit_select_external' then
   local uuid=type(data)=='table' and data.uuid
   if not uuid and typeof(frame)=='Instance' then local value=frame:FindFirstChild('_uuid') uuid=value and value.Value end
   local selected=uuid and U.session.collection:get_unit_by_uuid(uuid)
   if selected then
    choosing=false cfg.Unit=uuid save() refreshUnit() report('Selected unit • '..traitText(selected))
    if self.IsOpen then pcall(self.toggle,self,true) end
    task.defer(restorePickerWindow)
    return
   end
  end
  return originalSelect(self,frame,data,...)
 end
 collection.select_unit=selectHook
 local originalChanged=UI.on_unit_traits_changed or function() end
 local changedHook=function(self,uuid,traits,...)
  if a.Alive and a.Enabled and uuid==cfg.Unit then
   a.ResultVersion=(a.ResultVersion or 0)+1 a.LatestTraits=traits
   return
  end
  return originalChanged(self,uuid,traits,...)
 end
 UI.on_unit_traits_changed=changedHook
 makeButton('SelectTraitUnit','Select unit from inventory',18,56,402,40,function()
  if not G.collection_ui then report('Unit selection is available in the lobby • saved selection is preserved') return end
  if choosing then return end
  stop('Choose a unit from your inventory') choosing=true
  local control=gui:FindFirstChild('SetWindowOpen')
  if control then wasOpen=control:Invoke(false) end
  local opened=pcall(function() G.collection_ui:toggle(false,'unit_select_external',{_unit_select_external_filter='none',_unit_select_external_ui='trait_reroll_ui'}) end)
  if not opened then restorePickerWindow() report('Could not open inventory') return end
  task.spawn(function()
   task.wait(.5)
   while a.Alive and choosing do
    if G.collection_ui.IsOpen==false then restorePickerWindow() break end
    task.wait(.1)
   end
  end)
 end)
 local itemButtons={}
 local closeTraitMenu=function() end
 local toggleItemMenu,closeItemMenu
 local itemMenu=new('CanvasGroup',{Name='TraitItemDropdown',Visible=false,Position=UDim2.fromOffset(18,220),Size=UDim2.fromOffset(402,180),BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=60},panel)
 bind(itemMenu,'BackgroundColor3','card') round(itemMenu,8) border(itemMenu)
 local itemChoice=makeButton('ChooseRerollItems','Choose items…',18,178,402,36,function()
  closeTraitMenu() toggleItemMenu()
 end)
 toggleItemMenu,closeItemMenu=viewportDropdown(itemMenu,itemChoice,nil,180)
 itemChoice.TextTruncate=Enum.TextTruncate.AtEnd
 do
  local state={Alive=true,Offset=0,Speed=28,Overflow=false}
  a.ItemMarquee=state
  local clip=new('Frame',{Name='ItemMarquee',BackgroundTransparency=1,Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-24,1,0),ClipsDescendants=true,Active=false,ZIndex=itemChoice.ZIndex+1},itemChoice)
  local labels={}
  for i=1,2 do labels[i]=new('TextLabel',{Name='Text'..i,Text='',BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.None,Active=false,ZIndex=clip.ZIndex+1},clip)end
  itemChoice.TextTransparency=1
  local width,viewport,cycle=0,1,1
  local function layout()
   viewport=math.max(1,itemChoice.Size.X.Offset-24)
   width=game:GetService('TextService'):GetTextSize(itemChoice.Text,itemChoice.TextSize,itemChoice.Font,Vector2.new(100000,1000)).X+2
   state.Overflow=width>viewport state.Offset=0 cycle=math.max(1,width+38)
   for _,text in ipairs(labels)do text.Text=itemChoice.Text text.TextColor3=itemChoice.TextColor3 text.FontFace=itemChoice.FontFace text.TextSize=itemChoice.TextSize text.Size=UDim2.new(0,width,1,0)end
  end
  for _,key in ipairs({'Text','TextSize','FontFace','TextColor3','Size'})do connect(itemChoice:GetPropertyChangedSignal(key),layout)end
  connect(itemChoice.Destroying,function()state.Alive=false end)
  local function visible()
   local node=itemChoice
   while node and node~=player.PlayerGui do
    if node:IsA('GuiObject')and not node.Visible then return false end
    if node:IsA('ScreenGui')and not node.Enabled then return false end
    if node:IsA('ScrollingFrame')then
     local y=itemChoice.AbsolutePosition.Y local h=itemChoice.AbsoluteSize.Y
     if y+h<node.AbsolutePosition.Y or y>node.AbsolutePosition.Y+node.AbsoluteWindowSize.Y then return false end
    end
    node=node.Parent
   end
   return true
  end
  layout()
  connect(game:GetService('RunService').Heartbeat,function(dt)
   if not state.Alive or not a.Alive or not itemChoice.Parent then return end
   local scroll=state.Overflow and motionEnabled()
   if scroll and visible()then state.Offset=(state.Offset+state.Speed*math.min(dt,.1))%cycle end
   if scroll then
    labels[1].Size=UDim2.new(0,width,1,0) labels[1].TextTruncate=Enum.TextTruncate.None
    labels[1].Position=UDim2.fromOffset(-state.Offset,0)labels[2].Position=UDim2.fromOffset(cycle-state.Offset,0)labels[2].Visible=true
   else
    labels[1].Position=UDim2.new()labels[1].Size=UDim2.new(1,0,1,0)labels[1].TextTruncate=Enum.TextTruncate.AtEnd labels[2].Visible=false
   end
  end)
 end

 local tokenId='__reroll_token'
 local function itemName(id) return id==tokenId and 'Reroll Token' or Items[id] and Items[id].name or id end
 local function ownedCount(id) if id==tokenId then return tonumber(U.session.profile_data.trait_reroll_tokens) or 0 end return U.session.inventory:get_number_of_owned_item(id) or 0 end
 local itemOrder={'star_remnant','star_remnant_limited','trait_reroll_legacy',tokenId}
 local function drawItems()
  local names={} for _,id in ipairs(cfg.Items) do if Items[id] or id==tokenId then table.insert(names,itemName(id)) end end
  itemChoice.Text=#names>0 and table.concat(names,' → ') or 'Choose items…'
  selectionVisual(itemChoice,#names>0)
  for _,id in ipairs(itemOrder) do local rank=table.find(cfg.Items,id) local count=ownedCount(id)
   local caption=itemButtons[id]:FindFirstChild('ItemName')
   if caption then caption.Text=itemName(id) caption.TextColor3=rank and white or muted caption.TextTransparency=rank and 0 or .22 end
   selectionVisual(itemButtons[id],rank~=nil)
  end
 end
 for i,id in ipairs(itemOrder) do
  itemButtons[id]=makeButton('TraitItem_'..id,'',18,178+(i-1)*42,402,36,function()
   if a.Enabled then stop('Stopped • item order changed') end
   local at=table.find(cfg.Items,id) if at then table.remove(cfg.Items,at) else table.insert(cfg.Items,id) end save() drawItems()
  end)
  itemButtons[id].Parent=itemMenu itemButtons[id].Position=UDim2.fromOffset(6,6+(i-1)*42) itemButtons[id].Size=UDim2.fromOffset(390,36) itemButtons[id].ZIndex=61
  itemButtons[id].Text=''
  label(itemButtons[id],'ItemName',itemName(id),44,0,334,36,13,false,62)
  local ok,frame=false,nil if id~=tokenId then ok,frame=pcall(G.make_item_frame,id) end
  if ok and frame then
   local image=frame:FindFirstChild('icon',true)
   local visual=image and image:IsA('ImageLabel') and image.Image~='' and image or frame:FindFirstChild('View',true)
   if visual and visual:IsA('GuiObject') then
    visual.Parent=itemButtons[id] visual.Name='ItemIcon' visual.AnchorPoint=Vector2.new(.5,.5)
    visual.Position=UDim2.fromOffset(21,18) visual.Size=UDim2.fromOffset(28,28)
    visual.BackgroundTransparency=1 visual.Visible=true visual.Active=false visual.ZIndex=62
    if visual:IsA('ImageLabel') then visual.ScaleType=Enum.ScaleType.Fit end
    if visual:IsA('ViewportFrame') then
     local made,model=pcall(G.make_item_model,id)
     if made and model then
      model.Parent=visual
      local cf,size
      if model:IsA('Model') then cf,size=model:GetBoundingBox() elseif model:IsA('BasePart') then cf,size=model.CFrame,model.Size end
      if cf then
       local camera=Instance.new('Camera') camera.FieldOfView=35
       local distance=math.max(size.X,size.Y,size.Z)*1.9
       camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(0,0,distance),cf.Position)
       camera.Parent=visual visual.CurrentCamera=camera
       visual.Ambient=Color3.fromRGB(230,230,230) visual.LightColor=Color3.new(1,1,1)
      end
     end
    end
   end
   frame:Destroy()
  end
 end
 local paintSummary=function() end
 local menu=new('CanvasGroup',{Name='TraitDropdown',Visible=false,Position=UDim2.fromOffset(18,300),Size=UDim2.fromOffset(402,246),BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=50},panel)
 bind(menu,'BackgroundColor3','card') round(menu,8) border(menu)
 local search=new('TextBox',{Name='Search',Text='',PlaceholderText='Search traits…',ClearTextOnFocus=false,Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(386,30),TextSize=13,Font=Enum.Font.Gotham,TextColor3=white,BackgroundTransparency=.3,ZIndex=51},menu)
 bind(search,'BackgroundColor3','field') round(search,6)
 local list=new('ScrollingFrame',{Name='TraitTargets',Position=UDim2.fromOffset(6,44),Size=UDim2.fromOffset(390,196),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),ClipsDescendants=true,ZIndex=51},menu)
 local all={} for id,d in pairs(Traits) do
  if d.name and d.tiers then for tier in pairs(d.tiers) do table.insert(all,{id=id,tier=tostring(tier),name=d.name..(not d.singular and (' '..tier) or ''),weight=tonumber(d.weight) or 0}) end
  elseif d.name then table.insert(all,{id=id,tier='1',name=d.name,weight=tonumber(d.weight) or 0}) end
 end
 table.sort(all,function(x,y) if x.weight~=y.weight then return x.weight<y.weight end if x.id~=y.id then return x.id<y.id end return x.tier<y.tier end)
 for i,d in ipairs(all) do
  local key=d.id..':'..d.tier
  local row=new('TextButton',{Name='Target_'..key,Text='',Position=UDim2.fromOffset(2,(i-1)*40+2),Size=UDim2.new(1,-10,0,36),BorderSizePixel=0,BorderSizePixel=0,BackgroundTransparency=.55,AutoButtonColor=false,ZIndex=52},list) round(row,7) bind(row,'BackgroundColor3','field')
  local text=label(row,'TraitName',d.name,44,0,302,36,13,false,53)
  local selected=label(row,'Selected','',356,0,30,36,16,true,53)
  local ok,icon=pcall(G.make_trait_icon,d.id,d.tier)
  if ok and icon then icon.Parent=row icon.AnchorPoint=Vector2.new(.5,.5) icon.Position=UDim2.fromOffset(21,18) icon.Size=UDim2.fromOffset(28,28) icon.Rotation=0 icon.ScaleType=Enum.ScaleType.Fit icon.ZIndex=53 end
  local function paint() selected.Text=cfg.Targets[key] and '✓' or '' selected.TextColor3=colors.accent text.TextColor3=cfg.Targets[key] and white or muted selectionVisual(row,cfg.Targets[key]==true) paintSummary() end
  table.insert(paints,paint) paint()
  connect(row.Activated,function() if a.Enabled then stop('Stopped • targets changed') end cfg.Targets[key]=not cfg.Targets[key] save() paint() end)
 end
 list.CanvasSize=UDim2.fromOffset(0,#all*40+4)
 local toggleTraitMenu
 local dropdownButton=makeButton('ChooseTraits','Choose traits…',18,258,402,36,function()
  closeItemMenu() toggleTraitMenu()
 end)
 toggleTraitMenu,closeTraitMenu=viewportDropdown(menu,dropdownButton,list,246)
 dropdownButton.TextTruncate=Enum.TextTruncate.AtEnd
 paintSummary=function()
  local names={} for _,d in ipairs(all) do if cfg.Targets[d.id..':'..d.tier] then table.insert(names,d.name) end end
  dropdownButton.Text=#names==0 and 'Choose target traits…' or table.concat(names,' → ')
  selectionVisual(dropdownButton,#names>0)
 end
 paintSummary()
 connect(search:GetPropertyChangedSignal('Text'),function()
  local count=0 local query=search.Text:lower()
  for _,d in ipairs(all) do
   local row=list:FindFirstChild('Target_'..d.id..':'..d.tier)
   local show=d.name:lower():find(query,1,true)~=nil
   row.Visible=show if show then row.Position=UDim2.fromOffset(2,count*40+2) count+=1 end
  end
  list.CanvasSize=UDim2.fromOffset(0,count*40) list.CanvasPosition=Vector2.zero
 end)
 local function run(token)
  while a.Alive and a.Enabled and token==a.Token do
   if not Loader.IsLobby then report('Auto Reroll active • waiting for lobby') task.wait(.25) continue end
   local current=unit() if not current then stop('Selected unit is unavailable') return end
   refreshUnit()
   if targetFound(current) then stop('Target found • '..traitText(current)) return end
   local item,required,before
   for _,id in ipairs(cfg.Items) do
    -- Follow the same Legacy restriction as the native item selector.
    if id==tokenId then
     local count=ownedCount(id) if count>=1 then item=id required=1 before=count break end
    elseif Items[id] and (id~='trait_reroll_legacy' or not Core.LEGACY_UNITS[current.unit_id]) then
     local ok,cost=pcall(UI._get_required_amount,UI,current,id)
     local count=ownedCount(id)
     if ok and type(cost)=='number' and cost>0 and count>=cost then item=id required=cost before=count break end
    end
   end
   if not item then stop('Selected reroll items are depleted or unavailable') return end
   if not a.Enabled or token~=a.Token then return end
   report('Rerolling • '..itemName(item)..' · '..traitText(current))
   local version=a.ResultVersion or 0
   local oldTraits=H:JSONEncode(current.traits or {})
   local success,response
   if item==tokenId then success,response=pcall(EP.invoke_server,'request_token_trait_reroll',cfg.Unit)
   else success,response=pcall(EP.invoke_server,'use_item',item,{unit_uuid=cfg.Unit}) end
   local deadline=os.clock()+5 local paid=false local received=false
   repeat
    if not a.Alive or not a.Enabled or token~=a.Token then return end
    local count=ownedCount(item)
    paid=count<=before-required
    local latest=unit()
    received=(a.ResultVersion or 0)>version or (latest and H:JSONEncode(latest.traits or {})~=oldTraits)
    if paid and received then break end task.wait(.05)
   until os.clock()>=deadline
   if not success or response==false or not paid or not received then stop('Reroll was not confirmed • stopped to prevent duplicate requests') return end
   a.ConfirmedRolls+=1 a.LastItem=item a.LastCost=required
   -- Let both inventory and trait replication finish before considering another roll.
   task.wait(.3)
   if not a.Alive or not a.Enabled or token~=a.Token then return end
   current=unit() if (a.ResultVersion or 0)>version and type(a.LatestTraits)=='table' then current={traits=a.LatestTraits} end refreshUnit() drawItems() report('Rolled • '..traitText(current))
   if targetFound(current) then stop('Target found • '..traitText(current)) return end
   task.wait(.2)
  end
 end
 local function setTraitEnabled(v)
  if not v then stop() return end
  if not cfg.Unit or (Loader.IsLobby and not unit()) then report('Select a unit first') return end
  if #cfg.Items==0 then report('Select one or more reroll items') return end
  local has=false for _,enabled in pairs(cfg.Targets) do if enabled then has=true break end end
  if not has then report('Select at least one target trait') return end
  if targetFound(unit()) then report('Unit already has a target trait • '..traitText(unit())) return end
  a.Token+=1 a.Enabled=true cfg.Enabled=true save() a.Runner=task.spawn(function() local ok=pcall(run,a.Token) if not ok and a.Alive then stop('Reroll stopped • waiting for valid unit / item data') end end)
 end
 function a.Start() setTraitEnabled(true) paintToggle() end
 paintToggle=switch('AutoTraitToggle','Auto Reroll Trait','Stop on a target trait or when items run out.',0,function() return a.Enabled end,setTraitEnabled)
 local toggle=ui('AutoTraitToggle') toggle.Parent=panel toggle.Position=UDim2.fromOffset(18,316)
 function a.Stop() a.Alive=false a.Enabled=false a.Token+=1 if UI.show==showHook then UI.show=originalShow end if collection.select_unit==selectHook then collection.select_unit=originalSelect end if UI.on_unit_traits_changed==changedHook then UI.on_unit_traits_changed=originalChanged end save() panel:Destroy() end
 connect(gui.Destroying,a.Stop)
 connect(appearance:GetPropertyChangedSignal('BackgroundColor3'),function() paintToggle() for _,f in ipairs(paints) do f() end end)
;(function()
 -- A fixed layout keeps names and counters stable while data updates.
 local controls=panel
 local panel=card('TraitStatusCard',462,320,438,382) panel.Parent=utility
 local title=label(panel,'Title','VOID / TRAIT LAB',18,12,260,28,19,true)
 local phase=label(panel,'TraitPhase','STANDBY',300,16,120,22,12,true)
 phase:SetAttribute('TypographyRole','Micro') phase.TextXAlignment=Enum.TextXAlignment.Right
 local hero=new('Frame',{Name='SelectedUnitHero',Position=UDim2.fromOffset(18,52),Size=UDim2.fromOffset(402,136),BackgroundTransparency=.18,BorderSizePixel=0},panel)
 bind(hero,'BackgroundColor3','field') round(hero,12) border(hero)
 local rail=new('Frame',{Name='OrbitLight',Size=UDim2.new(1,-24,0,1),Position=UDim2.fromOffset(12,0),BackgroundTransparency=.18,BorderSizePixel=0},hero)
 bind(rail,'BackgroundColor3','accent')
 local glow=new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.45,0),NumberSequenceKeypoint.new(.55,0),NumberSequenceKeypoint.new(1,1)})},rail)
 local portraitPlate=new('Frame',{Name='TraitPortraitOrbit',Position=UDim2.fromOffset(10,12),Size=UDim2.fromOffset(112,112),BackgroundTransparency=.36,BorderSizePixel=0},hero)
 bind(portraitPlate,'BackgroundColor3','card') round(portraitPlate,56)
 local rim=new('UIStroke',{Name='OrbitalRim',Thickness=1.5,Transparency=.34},portraitPlate) bind(rim,'Color','accent')
 new('UIGradient',{Rotation=35,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,.8)})},rim)
 local viewport=new('ViewportFrame',{Name='SelectedUnitPortrait',Position=UDim2.fromOffset(4,2),Size=UDim2.fromOffset(104,110),BackgroundTransparency=1,Ambient=Color3.fromRGB(230,230,240),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1),ZIndex=5},portraitPlate)
 local placeholder=label(portraitPlate,'PortraitPlaceholder','◇',0,0,112,112,40,true,6) placeholder.TextXAlignment=Enum.TextXAlignment.Center
 local nameText=label(hero,'SelectedUnitName','Select your unit',136,12,250,42,20,true,5) nameText.TextWrapped=true
 local metadata=label(hero,'SelectedUnitMetadata','INVENTORY LINK / OFFLINE',136,57,250,20,12,false,5) metadata:SetAttribute('TypographyRole','Micro') metadata.TextColor3=muted
 local traitIcons=new('Frame',{Name='CurrentTraitIcons',Position=UDim2.fromOffset(136,89),Size=UDim2.fromOffset(60,28),BackgroundTransparency=1,ZIndex=5},hero)
 local currentTrait=label(hero,'CurrentTrait','No trait',199,88,187,30,13,true,5) currentTrait.TextWrapped=true
 local detail=label(panel,'TraitLiveStatus','Ready when you are',18,192,402,24,12,false) detail.TextColor3=muted
 local section=label(panel,'TelemetryTitle','SESSION / REROLL TELEMETRY',18,216,402,18,11,true)
 section:SetAttribute('TypographyRole','Micro') section.TextColor3=muted
 local metricValues={}
 for index,entry in ipairs({{Key='Rolls',Title='CONFIRMED ROLLS'},{Key='Tokens',Title='REROLL TOKENS'},{Key='Stars',Title='STAR REMNANTS'},{Key='Limited',Title='LIMITED REMNANTS'}}) do
  local x=18+((index-1)%2)*206 local y=240+math.floor((index-1)/2)*64
  local cell=new('Frame',{Name='TraitMetric_'..entry.Key,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(196,56),BackgroundTransparency=.32,BorderSizePixel=0},panel)
  bind(cell,'BackgroundColor3','field') round(cell,9)
  local caption=label(cell,'Caption',entry.Title,12,6,172,16,11,true) caption:SetAttribute('TypographyRole','Micro') caption.TextColor3=muted
  metricValues[entry.Key]=label(cell,'Value','0',12,22,172,28,23,true)
 end
 local footer=label(panel,'TraitStatusFooter','LIVE INVENTORY  •  TARGET-AWARE STOP',18,366,402,14,11,false)
 footer:SetAttribute('TypographyRole','Micro') footer.TextColor3=muted
 local portraitKey local traitKey
 local targetSummaryKey
 local chevron=new('ImageLabel',{Name='TargetChevron',Image='rbxassetid://7733717447',Position=UDim2.fromOffset(378,11),Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,ImageColor3=muted,ZIndex=dropdownButton.ZIndex+2},dropdownButton)
 do
  local state={Alive=true,Offset=0,Speed=28,Overflow=false}
  a.TargetMarquee=state
  local clip=new('Frame',{Name='TargetMarquee',BackgroundTransparency=1,Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-46,1,0),ClipsDescendants=true,Active=false,ZIndex=dropdownButton.ZIndex+1},dropdownButton)
  local labels={}
  for i=1,2 do labels[i]=new('TextLabel',{Name='Text'..i,Text='',BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.None,Active=false,ZIndex=clip.ZIndex+1},clip)end
  dropdownButton.TextTransparency=1
  local width,viewport,cycle=0,1,1
  local function layout()
   viewport=math.max(1,dropdownButton.Size.X.Offset-46)
   width=game:GetService('TextService'):GetTextSize(dropdownButton.Text,dropdownButton.TextSize,dropdownButton.Font,Vector2.new(100000,1000)).X+2
   state.Overflow=width>viewport or dropdownButton.Text:find(' → ',1,true)~=nil state.Offset=0 cycle=math.max(1,width+38)
   for _,text in ipairs(labels)do text.Text=dropdownButton.Text text.TextColor3=dropdownButton.TextColor3 text.FontFace=dropdownButton.FontFace text.TextSize=dropdownButton.TextSize text.Size=UDim2.new(0,width,1,0)end
  end
  for _,key in ipairs({'Text','TextSize','FontFace','TextColor3','Size'})do connect(dropdownButton:GetPropertyChangedSignal(key),layout)end
  connect(dropdownButton.Destroying,function()state.Alive=false end)
  local function visible()
   local node=dropdownButton
   while node and node~=player.PlayerGui do
    if node:IsA('GuiObject')and not node.Visible then return false end
    if node:IsA('ScreenGui')and not node.Enabled then return false end
    if node:IsA('ScrollingFrame')then
     local y=dropdownButton.AbsolutePosition.Y local h=dropdownButton.AbsoluteSize.Y
     if y+h<node.AbsolutePosition.Y or y>node.AbsolutePosition.Y+node.AbsoluteWindowSize.Y then return false end
    end
    node=node.Parent
   end
   return true
  end
  layout()
  connect(game:GetService('RunService').Heartbeat,function(dt)
   if not state.Alive or not a.Alive or not dropdownButton.Parent then return end
   local scroll=state.Overflow and motionEnabled()
   if scroll and visible()then state.Offset=(state.Offset+state.Speed*math.min(dt,.1))%cycle end
   if scroll then
    labels[1].Size=UDim2.new(0,width,1,0) labels[1].TextTruncate=Enum.TextTruncate.None
    labels[1].Position=UDim2.fromOffset(-state.Offset,0)labels[2].Position=UDim2.fromOffset(cycle-state.Offset,0)labels[2].Visible=true
   else
    labels[1].Position=UDim2.new()labels[1].Size=UDim2.new(1,0,1,0)labels[1].TextTruncate=Enum.TextTruncate.AtEnd labels[2].Visible=false
   end
  end)
 end

 local function paintTargetChips(names)
  local key=table.concat(names,'|');if key==targetSummaryKey then return end;targetSummaryKey=key
  dropdownButton.Text=#names>0 and table.concat(names,' → ')or'Choose target traits…'
 end
 local function paintPortrait(u)
  local key=u and tostring(cfg.Unit)..':'..tostring(u.unit_id)..':'..tostring(u.shiny) or ''
  if key==portraitKey then return end portraitKey=key viewport:ClearAllChildren() placeholder.Visible=true
  if not u then placeholder.Text='+' return end;placeholder.Text=tostring(Units[u.unit_id]and Units[u.unit_id].name or 'U'):sub(1,1):upper()
  local ok,model=pcall(G.make_unit_gui_model,u.unit_id,nil)
  if not ok or not model or not model:IsA('Model') then return end
  -- These are accessories on the private portrait clone, never live units.
  if u.unit_id=='elyssia_evolved' or u.unit_id=='elyssia' then for _,name in ipairs({'trides','elyssia_eel'})do local accessory=model:FindFirstChild(name);if accessory then accessory:Destroy()end end end
  local world=Instance.new('WorldModel') world.Parent=viewport model.Parent=world
  local head=model:FindFirstChild('Head',true) local cf,size=model:GetBoundingBox()
  local target=head and head.Position or cf.Position
  local direction=head and head.CFrame.LookVector or Vector3.new(0,0,-1)
  local distance=head and math.max(3,head.Size.Y*3) or math.max(size.X,size.Y,size.Z)*1.35
  local camera=Instance.new('Camera') camera.FieldOfView=32
  camera.CFrame=CFrame.lookAt(target+direction*distance+Vector3.new(0,.1,0),target)
  camera.Parent=viewport viewport.CurrentCamera=camera placeholder.Visible=false
 end
 local function paintTraitIcons(u)
  local key=H:JSONEncode(u and u.traits or {}) if key==traitKey then return end traitKey=key traitIcons:ClearAllChildren()
  for index,t in ipairs(u and u.traits or {}) do if index>2 then break end
   local ok,icon=pcall(G.make_trait_icon,t.trait,tostring(t.tier or '1'))
   if ok and icon then icon.Parent=traitIcons icon.Position=UDim2.fromOffset((index-1)*28,1) icon.AnchorPoint=Vector2.zero icon.Size=UDim2.fromOffset(26,26) icon.Rotation=0 icon.ZIndex=6 end
  end
 end
 function a.GetStatusSnapshot()
  local u=unit() local definition=u and Units[u.unit_id]
  local targets={} for _,d in ipairs(all) do if cfg.Targets[d.id..':'..d.tier] then targets[#targets+1]=d.name end end
  return {Selected=cfg.Unit,UnitId=u and u.unit_id,Name=definition and definition.name or u and u.unit_id,CurrentTrait=traitText(u),Targets=targets,Rolls=a.ConfirmedRolls or 0,Tokens=ownedCount(tokenId),Stars=ownedCount('star_remnant'),Limited=ownedCount('star_remnant_limited'),Legacy=ownedCount('trait_reroll_legacy'),Running=a.Enabled,Status=a.Status}
 end
 function a.RefreshStatus()
  if not a.Alive or not panel.Parent then return end
  local u=unit() local definition=u and Units[u.unit_id] local snapshot=a.GetStatusSnapshot()
  nameText.Text=snapshot.Name or 'Select your unit'
  metadata.Text=u and (tostring(definition and definition.rarity or 'UNIT'):upper()..' / '..(u.shiny and 'SHINY' or 'STANDARD')) or 'CHOOSE FROM YOUR INVENTORY'
  currentTrait.Text=snapshot.CurrentTrait
  paintTargetChips(snapshot.Targets)
  detail.Text=snapshot.Status or (#snapshot.Targets>0 and 'Ready • stops when a selected target is found' or 'Choose target traits to get started')
  phase.Text=a.Enabled and '●  REROLLING' or targetFound(u) and '●  TARGET FOUND' or u and '●  READY' or 'STANDBY'
  phase.TextColor3=a.Enabled and colors.accent or targetFound(u) and Color3.fromRGB(102,222,169) or muted
  for key,value in pairs(metricValues) do value.Text=tostring(snapshot[key] or 0) end
  footer.Text=snapshot.Legacy>0 and ('LEGACY REMNANTS '..snapshot.Legacy..'  •  COUNTS VERIFIED LIVE') or 'LIVE INVENTORY  •  TARGET-AWARE STOP'
  paintPortrait(u) paintTraitIcons(u)
 end
-- A readable portrait, status ribbon and inventory tiles share one visual rhythm.
do
 panel.Size=UDim2.fromOffset(438,486)
 panel.BackgroundTransparency=.04
 local pc=panel:FindFirstChildWhichIsA('UICorner');if pc then pc.CornerRadius=UDim.new(0,18)end
 local trim=panel:FindFirstChildWhichIsA('UIStroke');if trim then trim.Transparency=.25 end
 local finish=new('UIGradient',{Rotation=115,Color=ColorSequence.new(Color3.fromRGB(255,249,255),Color3.fromRGB(127,135,160))},panel)
 title.Text='TRAIT LAB';title.Position=UDim2.fromOffset(20,14);title.Size=UDim2.fromOffset(230,30);title.TextSize=23
 local subtitle=label(panel,'LabSubtitle','REROLL / LIVE INVENTORY',20,44,280,20,15,false);subtitle.TextColor3=muted
 local badge=new('Frame',{Name='PhaseBadge',Position=UDim2.fromOffset(290,18),Size=UDim2.fromOffset(128,30),BackgroundTransparency=.64,BorderSizePixel=0},panel);bind(badge,'BackgroundColor3','accent');round(badge,15)
 local badgeStroke=new('UIStroke',{Transparency=.64,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},badge);bind(badgeStroke,'Color','accent')
 phase.Parent=badge;phase.Position=UDim2.fromOffset(6,0);phase.Size=UDim2.fromOffset(116,30);phase.TextXAlignment=Enum.TextXAlignment.Center
 phase.TextSize=16
 hero.Position=UDim2.fromOffset(16,76);hero.Size=UDim2.fromOffset(406,130);hero.BackgroundTransparency=.08
 new('UIGradient',{Rotation=125,Color=ColorSequence.new(Color3.fromRGB(229,224,255),Color3.fromRGB(110,126,155))},hero)
 portraitPlate.Position=UDim2.fromOffset(10,13);portraitPlate.Size=UDim2.fromOffset(104,104);portraitPlate.BackgroundTransparency=.1
 portraitPlate:FindFirstChildWhichIsA('UICorner').CornerRadius=UDim.new(0,52)
 rim.Transparency=.12;rim.Thickness=1.8
 local orbit=rim:FindFirstChildWhichIsA('UIGradient');orbit.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.8),NumberSequenceKeypoint.new(.4,.15),NumberSequenceKeypoint.new(.55,0),NumberSequenceKeypoint.new(1,.8)})
 viewport.Position=UDim2.fromOffset(2,2);viewport.Size=UDim2.fromOffset(100,100)
 placeholder.Size=UDim2.fromScale(1,1);placeholder.TextSize=36;placeholder.TextColor3=colors.accent
 nameText.Position=UDim2.fromOffset(130,12);nameText.Size=UDim2.fromOffset(260,44);nameText.TextSize=21
 metadata.Position=UDim2.fromOffset(130,58);metadata.Size=UDim2.fromOffset(260,22);metadata.TextSize=15
 local traitPill=new('Frame',{Name='CurrentTraitPill',Position=UDim2.fromOffset(128,87),Size=UDim2.fromOffset(260,32),BackgroundTransparency=.78,BorderSizePixel=0,ZIndex=3},hero);bind(traitPill,'BackgroundColor3','accent');round(traitPill,9)
 traitIcons.Position=UDim2.fromOffset(134,89);traitIcons.Size=UDim2.fromOffset(58,28)
 currentTrait.Position=UDim2.fromOffset(196,88);currentTrait.Size=UDim2.fromOffset(188,30);currentTrait.TextSize=17
 local statusRibbon=new('Frame',{Name='StatusRibbon',Position=UDim2.fromOffset(16,218),Size=UDim2.fromOffset(406,48),BackgroundTransparency=.45,BorderSizePixel=0},panel);bind(statusRibbon,'BackgroundColor3','field');round(statusRibbon,10)
 local statusRail=new('Frame',{Name='StatusRail',Position=UDim2.fromOffset(0,10),Size=UDim2.fromOffset(3,28),BorderSizePixel=0,BackgroundColor3=colors.accent},statusRibbon);round(statusRail,3)
 detail.Parent=statusRibbon;detail.Position=UDim2.fromOffset(14,4);detail.Size=UDim2.fromOffset(378,40);detail.TextSize=16;detail.TextWrapped=true;detail.TextTruncate=Enum.TextTruncate.None
 section.Text='REROLL INVENTORY';section.Position=UDim2.fromOffset(20,278);section.Size=UDim2.fromOffset(398,22);section.TextSize=16;section.TextColor3=white
 local tileColors={Rolls=Color3.fromRGB(176,158,255),Tokens=Color3.fromRGB(119,214,234),Stars=Color3.fromRGB(244,208,139),Limited=Color3.fromRGB(235,163,213)}
 local tileTitles={Rolls='CONFIRMED ROLLS',Tokens='REROLL TOKENS',Stars='STAR REMNANTS',Limited='LIMITED REMNANTS'}
 for index,key in ipairs({'Rolls','Tokens','Stars','Limited'})do
  local value=metricValues[key];local cell=value.Parent;cell.Position=UDim2.fromOffset(16+((index-1)%2)*208,308+math.floor((index-1)/2)*74);cell.Size=UDim2.fromOffset(198,66);cell.BackgroundTransparency=.12
  local corner=cell:FindFirstChildWhichIsA('UICorner');if corner then corner.CornerRadius=UDim.new(0,11)end
  local tint=tileColors[key]
  new('UIStroke',{Color=tint,Transparency=.82,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},cell)
  new('UIGradient',{Rotation=120,Color=ColorSequence.new(Color3.fromRGB(244,240,255),Color3.fromRGB(120,132,155))},cell)
  local dot=new('Frame',{Name='MetricAccent',Position=UDim2.fromOffset(12,13),Size=UDim2.fromOffset(4,12),BackgroundColor3=tint,BorderSizePixel=0},cell);round(dot,2)
  local caption=cell.Caption;caption.Text=tileTitles[key];caption.Position=UDim2.fromOffset(24,7);caption.Size=UDim2.fromOffset(164,22);caption.TextSize=15;caption.TextColor3=Color3.fromRGB(218,225,240)
  value.Position=UDim2.fromOffset(12,28);value.Size=UDim2.fromOffset(174,32);value.TextSize=27;value.TextColor3=tint
 end
 footer.Position=UDim2.fromOffset(20,459);footer.Size=UDim2.fromOffset(398,20);footer.TextSize=14;footer.TextColor3=muted
 -- A collectible-style finish: quiet metal, etched rules and angled light.
 local pearl=Color3.fromRGB(244,237,232)
 local metal=Color3.fromRGB(215,203,190)
 local violet=Color3.fromRGB(179,159,213)
 local soft=Color3.fromRGB(198,192,206)
 panel.Size=UDim2.fromOffset(438,438);panel.BackgroundColor3=Color3.fromRGB(20,18,25)
 finish.Color=ColorSequence.new(Color3.fromRGB(246,237,235),Color3.fromRGB(119,114,139))
 if trim then trim.Color=metal;trim.Transparency=.35 end
 local inner=new('Frame',{Name='PlatinumRim',Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),BackgroundTransparency=1,Active=false,ZIndex=2},panel);round(inner,15)
 local innerEdge=new('UIStroke',{Color=metal,Thickness=1,Transparency=.6,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},inner)
 local reflection=new('UIGradient',{Rotation=30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.95),NumberSequenceKeypoint.new(.4,.8),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.6,.8),NumberSequenceKeypoint.new(1,.95)})},innerEdge)
 title.Text='TRAIT LAB';title.Position=UDim2.fromOffset(20,27);title.TextSize=24;title.TextColor3=pearl
 subtitle.Text='F Y R E L I T H';subtitle.Position=UDim2.fromOffset(20,7);subtitle.TextColor3=metal
 badge.Position=UDim2.fromOffset(282,28);badge.BackgroundTransparency=1;badgeStroke.Transparency=1
 local function rule(parent,name,x,y,w,z)
  local f=new('Frame',{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,1),BackgroundColor3=metal,BackgroundTransparency=.5,BorderSizePixel=0,Active=false,ZIndex=z or 3},parent)
  new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(.4,0),NumberSequenceKeypoint.new(1,.6)})},f)
 end
 rule(panel,'HeaderRule',20,64,398)
 hero.Position=UDim2.fromOffset(16,74);hero.Size=UDim2.fromOffset(406,112);hero.BackgroundTransparency=1
 local heroEdge=hero:FindFirstChildWhichIsA('UIStroke');if heroEdge then heroEdge.Transparency=1 end
 rail.Visible=false
 portraitPlate.Position=UDim2.fromOffset(0,0);portraitPlate.Size=UDim2.fromOffset(108,112);portraitPlate.BackgroundColor3=Color3.fromRGB(44,36,54);portraitPlate.BackgroundTransparency=.56
 portraitPlate:FindFirstChildWhichIsA('UICorner').CornerRadius=UDim.new(0,14)
 rim.Color=metal;rim.Thickness=1;rim.Transparency=.48
 viewport.Position=UDim2.fromOffset(-6,-8);viewport.Size=UDim2.fromOffset(120,120);viewport.Ambient=Color3.fromRGB(231,222,238)
 nameText.Position=UDim2.fromOffset(124,0);nameText.Size=UDim2.fromOffset(270,44);nameText.TextSize=21;nameText.TextColor3=pearl
 metadata.Position=UDim2.fromOffset(124,44);metadata.Size=UDim2.fromOffset(270,24);metadata.TextColor3=soft
 traitPill.Position=UDim2.fromOffset(122,78);traitPill.Size=UDim2.fromOffset(272,30);traitPill.BackgroundColor3=Color3.fromRGB(52,39,65);traitPill.BackgroundTransparency=.08
 traitPill:FindFirstChildWhichIsA('UICorner').CornerRadius=UDim.new(0,6)
 new('UIStroke',{Color=violet,Thickness=1,Transparency=.45,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},traitPill)
 traitIcons.Position=UDim2.fromOffset(128,79);currentTrait.Position=UDim2.fromOffset(190,78);currentTrait.Size=UDim2.fromOffset(194,30)
 rule(panel,'PortraitRule',20,198,398)
 statusRibbon.Position=UDim2.fromOffset(20,208);statusRibbon.Size=UDim2.fromOffset(398,44);statusRibbon.BackgroundColor3=Color3.fromRGB(29,23,35);statusRibbon.BackgroundTransparency=.25
 detail.Size=UDim2.fromOffset(370,36);detail.TextColor3=soft
 section.Text='INVENTORY';section.Position=UDim2.fromOffset(20,262);section.Size=UDim2.fromOffset(150,22);section.TextColor3=metal
 rule(panel,'InventoryRule',174,274,244)
 local tiles={};local tweens={};local changes=0;local hovers=0
 local function ease(object,properties,duration)
  if tweens[object]then tweens[object]:Cancel()end
  if not motionEnabled()then for key,value in pairs(properties)do object[key]=value end;return end
  local t=game:GetService('TweenService'):Create(object,TweenInfo.new(duration or .25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),properties);tweens[object]=t;t:Play()
 end
 for index,key in ipairs({'Rolls','Tokens','Stars','Limited'})do
  local value=metricValues[key];local cell=value.Parent
  cell.Position=UDim2.fromOffset(20+((index-1)%2)*204,292+math.floor((index-1)/2)*56);cell.Size=UDim2.fromOffset(194,52)
  cell.BackgroundColor3=key=='Tokens'and Color3.fromRGB(43,33,54)or Color3.fromRGB(28,25,32)
  cell:FindFirstChildWhichIsA('UICorner').CornerRadius=UDim.new(0,5)
  local edge=cell:FindFirstChildWhichIsA('UIStroke');edge.Color=key=='Tokens'and violet or metal;edge.Transparency=.74
  local sheen=cell:FindFirstChildWhichIsA('UIGradient');sheen.Color=ColorSequence.new(Color3.fromRGB(246,235,255),Color3.fromRGB(122,116,139))
  cell.MetricAccent.Visible=false
  local caption=cell.Caption;caption.Text=({Rolls='Confirmed rolls',Tokens='Reroll tokens',Stars='Star remnants',Limited='Limited remnants'})[key];caption.Position=UDim2.fromOffset(12,3);caption.Size=UDim2.fromOffset(172,22);caption.TextColor3=soft
  value.Position=UDim2.fromOffset(12,25);value.Size=UDim2.fromOffset(170,26);value.TextColor3=pearl;value.TextSize=25
  local etch=new('Frame',{Name='EtchedCorner',AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-5,1,-5),Size=UDim2.fromOffset(12,1),BackgroundColor3=metal,BackgroundTransparency=.4,Rotation=-45,BorderSizePixel=0,Active=false,ZIndex=4},cell)
  local resting=cell.BackgroundColor3
  connect(cell.MouseEnter,function()hovers+=1;ease(edge,{Transparency=.22});ease(cell,{BackgroundColor3=resting:Lerp(violet,.12)});ease(sheen,{Offset=Vector2.new(.18,0)},.4)end)
  connect(cell.MouseLeave,function()ease(edge,{Transparency=.74});ease(cell,{BackgroundColor3=resting});ease(sheen,{Offset=Vector2.zero},.4)end)
  connect(value:GetPropertyChangedSignal('Text'),function()if not a.Alive or not cell.Parent then return end;changes+=1;value.TextColor3=violet;ease(value,{TextColor3=pearl},.65)end)
  tiles[key]={Cell=cell,Edge=edge,Sheen=sheen}
 end
 footer.Position=UDim2.fromOffset(20,412);footer.Size=UDim2.fromOffset(398,18);footer.TextColor3=soft
 local function paintState()
  local tint=a.Enabled and violet or(phase.Text:find('TARGET FOUND',1,true)and Color3.fromRGB(142,212,175)or metal)
  ease(statusRail,{BackgroundColor3=tint});ease(traitPill,{BackgroundColor3=a.Enabled and Color3.fromRGB(64,43,83)or Color3.fromRGB(52,39,65)})
 end
 connect(phase:GetPropertyChangedSignal('Text'),paintState);paintState()
 connect(panel.Destroying,function()for _,t in pairs(tweens)do t:Cancel()end;table.clear(tweens)end)
 local elapsed=0
 connect(game:GetService('RunService').Heartbeat,function(dt)
  if not a.Alive or not panel.Parent or not panel.Parent.Visible or not gui.Window.Visible or not motionEnabled()then return end
  local scroll=panel.Parent
  if scroll:IsA('ScrollingFrame')then local y=panel.AbsolutePosition.Y;if y>scroll.AbsolutePosition.Y+scroll.AbsoluteWindowSize.Y or y+panel.AbsoluteSize.Y<scroll.AbsolutePosition.Y then return end end
  elapsed+=math.min(dt,.1);orbit.Rotation=(elapsed*14)%360;reflection.Rotation=(elapsed*18+30)%360
 end)
 a.TraitLabDesign={Version=2,Panel=panel,Orbit=orbit,Reflection=reflection,Tiles=tiles}
end


 local oldRefresh=refreshUnit
 refreshUnit=function() oldRefresh() a.RefreshStatus() end
 local oldStop=a.Stop a.Stop=function() oldStop() if panel.Parent then panel:Destroy() end end
 local lastFrame=0 local clock=0
 connect(game:GetService('RunService').Heartbeat,function(dt)
  if not a.Alive or not panel.Parent then return end
  clock+=math.min(dt,.1)
  if motionEnabled() and gui.Window.Visible and panel.Visible and panel.Parent.Visible then glow.Offset=Vector2.new(math.sin(clock*.65)*.65,0) end
  if clock-lastFrame<.2 then return end lastFrame=clock
  local ok,err=pcall(a.RefreshStatus) if not ok then a.StatusError=tostring(err) end
 end)
end)()

 refreshUnit() drawItems() paintToggle()
 utility.CanvasSize=UDim2.fromOffset(0,912)
 task.spawn(function()
  while a.Alive and not api.Ready do task.wait(.1) end
  if a.Alive and cfg.Enabled==true then a.Start() end
 end)
end)

do
 local function repaintSelections() for row,on in pairs(selectionStates) do if row.Parent then selectionVisual(row,on) end end end
 connect(appearance:GetPropertyChangedSignal('BackgroundColor3'),repaintSelections)
 connect(accentIcon:GetPropertyChangedSignal('ImageColor3'),repaintSelections)
end

do
 local utility=main.Parent.Utilities
 local G=env.FyrelithGameReady.Services.GUIService
 local S=Loader.load_client_service(script,'SummonServiceClient')
 local Banners=Loader.load_data(script,'Banners') local Units=Loader.load_data(script,'Units')
 local Http=game:GetService('HttpService')
 local cacheFile='FyrelithBannerUnits_'..game.GameId..'.json'
 local cache={}
 pcall(function() local saved=Http:JSONDecode(readfile(cacheFile)) if type(saved)=='table' then cache=saved end end)
 local lastCache local probing=false local lastProbe=-math.huge
 local function saveBannerData(data)
  if type(data)~='table' or not next(data) then return end
  local ok,encoded=pcall(Http.JSONEncode,Http,data)
  if ok and encoded~=lastCache then
   cache={Units=data,Time=os.time()} lastCache=encoded
   pcall(function() writefile(cacheFile,Http:JSONEncode(cache)) end)
  end
 end
 local function bannerData()
  if type(S.BANNER_UNITS)=='table' and next(S.BANNER_UNITS) then saveBannerData(S.BANNER_UNITS) return S.BANNER_UNITS,false end
  if Loader.IsLobby and not probing and os.clock()-lastProbe>=30 then
   probing=true lastProbe=os.clock()
   task.spawn(function() local ok,data=pcall(EP.invoke_server,'get_hatch_setup_data') if ok then saveBannerData(data) end probing=false end)
  end
  return cache.Units,true
 end
 local names={Summer2026='Summer',EventClover='Special',Legacy='Legacy'}
 local order={'Summer2026','EventClover','Legacy'}
 local viewed=preferences and preferences:GetAttribute('BannerPreview') or 'Summer2026'
 if not Banners[viewed] then viewed='Summer2026' end
 local panel=card('BannerUnitPreview',8,570,438,300) panel.Parent=utility
 label(panel,'Title','Banner Units',18,12,402,28,19,true)
 local status=label(panel,'Status','',18,266,402,22,12) status.TextColor3=muted
 local choose=new('TextButton',{Name='ChooseBanner',Text=names[viewed] or viewed,Position=UDim2.fromOffset(18,52),Size=UDim2.fromOffset(402,36),BackgroundTransparency=.4,TextColor3=white,TextSize=14,Font=Enum.Font.Gotham,AutoButtonColor=false,BorderSizePixel=0,ZIndex=3},panel)
 bind(choose,'BackgroundColor3','field') round(choose,8) border(choose)
 local menu=new('CanvasGroup',{Name='BannerOptions',Visible=false,Position=UDim2.fromOffset(18,94),Size=UDim2.fromOffset(402,140),BackgroundTransparency=.03,BorderSizePixel=0,ZIndex=80},panel)
 bind(menu,'BackgroundColor3','card') round(menu,8) border(menu)
 local list=new('ScrollingFrame',{Name='Units',Position=UDim2.fromOffset(18,102),Size=UDim2.fromOffset(402,154),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),ZIndex=3},panel)
 local lastSignature
 local function portrait(parent,id)
  local view=new('ViewportFrame',{Name='Portrait',Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,0,102),BackgroundTransparency=1,Ambient=Color3.fromRGB(210,210,210),LightColor=Color3.new(1,1,1),ZIndex=4},parent)
  if not hasUnitPortrait(id) then
   local fallback=label(parent,'MissingPortrait','◇',6,4,120,102,28,true,4)
   fallback.TextColor3=muted fallback.TextXAlignment=Enum.TextXAlignment.Center
   return
  end
  local ok,model=pcall(G.make_unit_gui_model,id,nil)
  if ok and model then
   model.Parent=view
   local head=model:FindFirstChild('Head',true) local cf,size=model:GetBoundingBox()
   local target=head and head.Position or cf.Position local direction=head and head.CFrame.LookVector or Vector3.new(0,0,-1)
   local camera=Instance.new('Camera') camera.FieldOfView=35
   camera.CFrame=CFrame.lookAt(target+direction*(head and 3.5 or math.max(size.X,size.Y,size.Z)*1.4)+Vector3.new(0,.15,0),target)
   camera.Parent=view view.CurrentCamera=camera
  end
 end
 local function draw()
  local def=Banners[viewed] local current,cached=bannerData() local actual=current and current[viewed]
  local units={} local seen={}
  local function add(id)
   local d=type(id)=='string' and Units[id]
   if d and d.rarity~='Secret' and not seen[id] then seen[id]=true table.insert(units,id) end
  end
  for _,slot in ipairs(def.rateup_config_show_order or {}) do
   local config=def.rateup_units and def.rateup_units[slot]
   if config and config.rarity~='Secret' then
    local id=actual and actual.rateup_units and actual.rateup_units[slot]
    if id then add(id)
    elseif def._does_not_rotate and type(config.possible_units_set)=='table' then
     for candidate in pairs(config.possible_units_set) do add(candidate) end
    end
   end
  end
  if def.type=='standard' and actual then for _,id in pairs(actual.units or {}) do add(id) end end
  local signature=viewed..':'..table.concat(units,',')..':'..tostring(cached)
  if signature==lastSignature then return end lastSignature=signature list:ClearAllChildren()
  for i,id in ipairs(units) do
   local row=math.floor((i-1)/3) local col=(i-1)%3
   local tile=new('Frame',{Name='Unit_'..id,Position=UDim2.fromOffset(col*132,row*152),Size=UDim2.fromOffset(126,146),BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=3},list)
   bind(tile,'BackgroundColor3','field') round(tile,8)
   local text=label(tile,'Name',Units[id].name or id,6,108,114,32,12,true,4) text.TextWrapped=true
   portrait(tile,id)
  end
  list.CanvasSize=UDim2.fromOffset(0,math.ceil(#units/3)*152)
  status.Text=#units>0 and (cached and not def._does_not_rotate and 'Last lobby lineup • refreshes when you return to lobby' or 'Current featured units') or 'Open in lobby once to load this banner lineup'
 end
 local n=0
 for _,id in ipairs(order) do if Banners[id] and Banners[id].active then
  local row=new('TextButton',{Name='Banner_'..id,Text=names[id],Position=UDim2.fromOffset(6,6+n*32),Size=UDim2.fromOffset(390,30),BackgroundTransparency=.55,BorderSizePixel=0,TextColor3=white,TextSize=13,Font=Enum.Font.Gotham,AutoButtonColor=false,ZIndex=81},menu)
  bind(row,'BackgroundColor3','field') round(row,6)
  selectionVisual(row,id==viewed)
  connect(row.Activated,function()
   viewed=id choose.Text=names[id] if preferences then preferences:SetAttribute('BannerPreview',id) end
   for _,other in ipairs(menu:GetChildren()) do if other:IsA('TextButton') then selectionVisual(other,other==row) end end
   animateDropdown(menu,false,140) draw()
  end)
  n+=1
 end end
 connect(choose.Activated,function() animateDropdown(menu,not menu:GetAttribute('Open'),140) end)
 local alive=true connect(gui.Destroying,function() alive=false end)
 draw()
 task.spawn(function() while alive and gui.Parent do local ok=pcall(draw) if not ok then status.Text='Waiting for banner unit data…' end task.wait(5) end end)
end

do
 local descriptions={Hint=true,TeamNote=true,ModeNote=true}
 local function clean(item)
  if item:IsA('TextLabel') and (descriptions[item.Name] or item.Text=='Add your own controls here.') then item.Visible=false if item.Name=='ModeNote' then connect(item:GetPropertyChangedSignal('Visible'),function() if item.Visible then item.Visible=false end end) end end
 end
 for _,label in ipairs(gui:QueryDescendants('TextLabel')) do clean(label) end
 connect(gui.DescendantAdded,function(item) task.defer(function() if item.Parent then clean(item) end end) end)
end

-- Route existing controls without rebuilding their callbacks or saved state.
do
 local body=main.Parent
 local matchNames={MatchControlsCard=true,MatchControlsTitle=true,AutoStart=true,AutoRetry=true,AutoNext=true,AutoSkipWave=true,AutoNextRoom=true,AutoNextPortal=true,AutoLeaveMatch=true}
 local macroTop=ui('MacroCard').Position.Y.Offset
 for _,item in ipairs(root:GetChildren()) do
  if item:IsA('GuiObject') then
   local target,dx,dy
   if matchNames[item.Name] then target=root dx=0 dy=0
   elseif item.Position.X.Offset>=450 then target=body.Dungeon dx=-454 dy=-306
   elseif item.Position.Y.Offset>=macroTop then target=body.Macro dx=0 dy=8-macroTop end
   if target then item.Position+=UDim2.fromOffset(dx,dy) item.Parent=target end
  end
 end
 ui('MacroPreviewCard').Position=UDim2.fromOffset(462,8)
 ui('MacroPreviewTitle').Position=UDim2.fromOffset(480,20)
 ui('MacroPreview').Position=UDim2.fromOffset(480,54)
 -- Keep the same team editor instances and callbacks, below the destination card.
 for _,item in ipairs(body.Dungeon:GetChildren())do
  if item:IsA('GuiObject') and item.Position.X.Offset<450 then
   item.Position+=UDim2.fromOffset(0,400)
   item.Parent=root
  end
 end
 root.Size=UDim2.fromOffset(908,1064) main.CanvasSize=UDim2.fromOffset(0,1064)
 local routes={AutoRedeemCodes={'Misc',462,8},AutoBuyGoldShop={'Misc',8,8},AutoClaimCard={'Misc',8,266},BannerUnitPreview={'Summon',462,8},TraitStatusCard={'Summon',462,320},AutoSummon={'Summon',8,8},AutoTraitCard={'Summon',8,358}}
 local function route(item)
  local rule=routes[item.Name]
  if rule and item:IsA('GuiObject') then
   item.Position=UDim2.fromOffset(rule[2],rule[3]) item.Parent=body[rule[1]]
   if item.Name=='AutoTraitCard' then local summon=ui('AutoSummon') if summon then item.Position=UDim2.fromOffset(8,summon.Position.Y.Offset+summon.Size.Y.Offset+12) end end
  elseif item.Name=='GoldShopItemPicker' then
   item.Parent=body.Misc
   task.defer(function() local menu=item:FindFirstChild('Menu') if menu then menu.Position-=UDim2.fromOffset(0,84) end end)
  elseif item.Name=='SummonPicker' then item.Parent=body.Summon end
 end
 for _,item in ipairs(body.Utilities:GetChildren()) do route(item) end
 connect(body.Utilities.ChildAdded,function(item) task.defer(function() if item.Parent then route(item) end end) end)
 do
  local page=body.Macro local m=env.FyrelithMacro m.CleanLayout=true
  local function place(n,x,y,w,h)
   local v=ui(n) if v then v.Parent=page v.Position=UDim2.fromOffset(x,y) if w then v.Size=UDim2.fromOffset(w,h) end end return v
  end
  local function surface(n,x,y,h,title)
   local c=card(n,x,y,438,h) c.Parent=page c.BackgroundTransparency=.08
   local t=label(c,'Heading',title,16,10,406,28,15,true) bind(t,'TextColor3','accent')
   local line=new('Frame',{Position=UDim2.fromOffset(16,44),Size=UDim2.fromOffset(406,1),BorderSizePixel=0,BackgroundTransparency=.5},c) bind(line,'BackgroundColor3','line')
   return c
  end
  local recorder=place('MacroCard',8,8,438,398) recorder.BackgroundTransparency=.08
  place('MacroTitleCompact',24,18,406,28).Text='MACRO RECORDER'
  place('MacroNameLabel',24,62,130,36).Text='Macro Name'
  place('MacroName',170,62,260,36)
  place('TimingLabel',24,108,130,36)
  place('Select_Timing',170,108,260,36)
  local notice=label(page,'MacroNotice',m.Message or 'Ready',24,150,406,30,12) notice.TextWrapped=true notice.TextTruncate=Enum.TextTruncate.None bind(notice,'TextColor3','accent')
  place('MacroRecord',24,184,402,32)
  place('MacroPlay',24,226,402,32)
  place('MacroAuto',24,268,402,32)
  place('MacroSave',24,310,406,34).Text='Save Macro'
  local function action(n,title,x,y,w,fn)
   local b=button(n,title,x,y,w,fn) b.Parent=page b.Size=UDim2.fromOffset(w,34) return b
  end
  action('MacroClear','Clear Current Macro',24,352,406,function() m.ClearCurrent() end)
  surface('SavedMacrosCard',462,8,274,'SAVED MACROS')
  place('Saved macroLabel',478,62,406,22).Text='Select Saved Macro'
  place('Select_Saved macro',478,90,406,36)
  action('MacroLoad','Load Selected Macro',478,138,406,function() m.LoadSelected() end)
  place('MacroDelete',478,180,406,34).Text='Delete Selected Macro'
  action('MacroRefresh','Refresh Macros List',478,222,406,function() m.RefreshLibrary() end)
  surface('MacroProgressCard',8,410,230,'RECORDING PROGRESS')
  place('MacroPause',24,588,195,34) place('MacroStop',235,588,195,34)
  place('MacroStatus',24,518,406,56)
  local progress=label(page,'MacroProgress','',24,464,406,48,14,true) progress.TextWrapped=true
  surface('MacroWaveCard',462,294,250,'AUTO AT WAVE')
  local paint=switch('MacroWaveEnabled','Auto Action at Wave','',350,function() return m.Config.WaveActionEnabled==true end,function(v) m.Config.WaveActionEnabled=v m.SaveConfig() end,478)
  ui('MacroWaveEnabled').Parent=page
  label(page,'TargetWaveLabel','Target Wave',478,396,160,34,14,true)
  local input=new('TextBox',{Name='MacroTargetWave',Text=tostring(m.Config.TargetWave or 15),ClearTextOnFocus=false,Position=UDim2.fromOffset(674,396),Size=UDim2.fromOffset(210,34),TextSize=14,Font=Enum.Font.GothamBold,TextColor3=white,BorderSizePixel=0,BackgroundTransparency=.12},page)
  bind(input,'BackgroundColor3','field') round(input,8)
  connect(input.FocusLost,function() m.Config.TargetWave=math.clamp(math.floor(tonumber(input.Text) or 15),1,999) input.Text=tostring(m.Config.TargetWave) m.SaveConfig() end)
  picker('Wave Action',478,442,function() return entries({'Upgrade All','Sell Damage Only'}) end,function() return m.Config.WaveAction=='Sell All'and 'Sell Damage Only'or m.Config.WaveAction or 'Upgrade All' end,function(v) m.Config.WaveAction=v.id m.SaveConfig() end)
  place('Wave ActionLabel',478,440,406,24) place('Select_Wave Action',478,472,406,34)
  local waveStatus=label(page,'WaveActionStatus','Idle',478,510,406,24,13)
  place('MacroPreviewTitle',478,572,406,24).Text='LATEST ACTION'
  place('MacroPreview',478,604,406,104)
  ui('MacroPreviewCard').Visible=false
  task.spawn(function() while m.Alive and gui.Parent do
   progress.Text='State: '..m.State..'    Steps: '..#m.Steps..'\nPlayback: '..tostring(m.Index or 0)..' / '..#m.Steps
   waveStatus.Text=m.WaveActionStatus or 'Idle' paint() task.wait(.25)
  end end)
  m.RefreshActionsUI()
 end
 -- Shared visual treatment, applied once to existing and late-loading panels.
 do
  local panelNames={DestinationCard=true,MatchControlsCard=true,TeamSettingsCard=true,AutoRedeemCodes=true,AutoBuyGoldShop=true,AutoClaimCard=true,AutoSummon=true,AutoTraitCard=true,BannerUnitPreview=true,PlayerProfile=true,CurrentMap=true,FPSCard=true,PingCard=true}
  local function polish(item)
   if item:IsA('Frame') and (panelNames[item.Name] or item.Name:match('Card$') or item.Name=='AutoPlayControls' or item.Name=='AutoPlanControls' or item.Name=='SavedMacrosCard') then
    if item:FindFirstChild('SurfaceFinish') then return end
    item.BackgroundTransparency=.06
    local stroke=item:FindFirstChildOfClass('UIStroke') if stroke then stroke.Transparency=.66 stroke.Thickness=1 end
    local corner=item:FindFirstChildOfClass('UICorner') if corner then corner.CornerRadius=UDim.new(0,12) end
    new('UIGradient',{Name='SurfaceFinish',Rotation=115,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(185,185,185))})},item)
    local rail=new('Frame',{Name='AccentRail',Position=UDim2.fromOffset(16,0),Size=UDim2.new(1,-32,0,1),BorderSizePixel=0,BackgroundTransparency=.4,Active=false,ZIndex=item.ZIndex+1},item)
    bind(rail,'BackgroundColor3','accent')
    new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,.1),NumberSequenceKeypoint.new(.75,.1),NumberSequenceKeypoint.new(1,1)})},rail)
   elseif item:IsA('TextButton') and item:GetAttribute('Primary') then
    local gradient=item:FindFirstChild('ButtonFinish')
    if not gradient then new('UIGradient',{Name='ButtonFinish',Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(185,185,185))},item) end
   end
  end
  for _,item in ipairs(gui:QueryDescendants('Frame, TextButton')) do polish(item) end
  connect(gui.DescendantAdded,function(item) task.defer(function() if item.Parent then polish(item) end end) end)
 end
 local routed={'Auto Play','Dungeon','Macro','Summon','Event','Misc','Webhook'}
 local function sizePages()
  for _,name in ipairs(routed) do
   local page=body[name] local bottom=0
   for _,item in ipairs(page:GetChildren()) do
    if item:IsA('GuiObject') and item.Visible and not item:GetAttribute('ViewportPopup') and item.Name~='SelectionOverlay' and not item.Name:find('Picker') then bottom=math.max(bottom,item.Position.Y.Offset+item.Size.Y.Offset) end
   end
   page.CanvasSize=UDim2.fromOffset(0,bottom+16)
  end
 end
 local function typography(item)
  if item:IsA('TextLabel') or item:IsA('TextButton') or item:IsA('TextBox') then
   if item.Font==Enum.Font.Gotham then item.Font=Enum.Font.GothamMedium end
   local inEditor=item:FindFirstAncestor('TeamUnitEditor')~=nil
   local minimum=inEditor and 18 or 17
   local rowHeight=item.Size.Y.Offset
   if item.Size.Y.Scale==0 and rowHeight>0 then minimum=math.min(minimum,math.max(14,rowHeight-2))end
   if not item.TextScaled then item.TextSize=math.max(item.TextSize,minimum)end
   if item:IsA('TextBox')then item.PlaceholderColor3=Color3.fromRGB(187,197,215)end
   if item.TextTransparency>0 and item.TextTransparency<.8 then item.TextTransparency=0 end
   item.TextStrokeTransparency=1
  end
 end
 for _,item in ipairs(gui:QueryDescendants('TextLabel, TextButton, TextBox')) do typography(item) end
 connect(gui.DescendantAdded,function(item) task.defer(function() if item.Parent then typography(item) end end) end)
 sizePages()
 task.spawn(function() while api.Alive and gui.Parent do sizePages() task.wait(.5) end end)
end

do
 local previous=env.FyrelithRuntime
 if previous then previous.Alive=false if previous.Connection then previous.Connection:Disconnect() end if previous.PreferenceConnection then previous.PreferenceConnection:Disconnect() end end
 local runtime={Alive=true,AutoSave=false,AutoExec=false}
 env.FyrelithRuntime=runtime
 local Http=game:GetService('HttpService')
 local sessionFile='FyrelithSession_'..player.UserId..'_'..game.GameId..'.json'
 local function snapshot()
  local gold=env.FyrelithGoldShop local summon=env.FyrelithAutoSummon local redeem=env.FyrelithRedeemCodes
  return {Main={Config=cfg,Enabled=api.Enabled},Teams=api.TeamSettings,TeamEditor=api.TeamRuleEditor,UI=preferences and preferences:GetAttributes() or {},
   Gold=gold and {Enabled=gold.Enabled,Selected=gold.Selected},
   Summon=summon and {Enabled=summon.Enabled,Config=summon.Config,Count=summon.Count},
   Redeem=redeem and {Enabled=redeem.Enabled}}
 end
 local lastSaved
 function runtime.Save()
  local ok,encoded=pcall(function() return Http:JSONEncode(snapshot()) end)
  if not ok then runtime.SaveError=tostring(encoded) return end
  if encoded==lastSaved then return end
  if type(writefile)=='function' then
   local written,err=pcall(writefile,sessionFile,encoded)
   runtime.AutoSave=written runtime.SaveError=not written and tostring(err) or nil
   if written then lastSaved=encoded end
  end
 end
 -- Restore settings only after every module, including the team start hook,
 -- has been constructed. No Auto Join can race the team initialization.
 local saved=env.FyrelithLoadedSession
 if type(saved)=='table' then
  if type(saved.Main)=='table' then
   if type(saved.Main.Config)=='table' then for k in pairs(cfg) do local v=saved.Main.Config[k] if type(v)==type(cfg[k]) then cfg[k]=v end end
    cfg.World=saved.Main.Config.World cfg.Level=saved.Main.Config.Level
   end
   api.Enabled=saved.Main.Enabled==true
  end
  if api.TeamSettings and type(saved.Teams)=='table' then
   api.TeamSettings.Enabled=saved.Teams.Enabled==true
  end
  local gold=env.FyrelithGoldShop
  if gold and type(saved.Gold)=='table' then gold.Enabled=saved.Gold.Enabled==true if gold.RefreshUI then gold.RefreshUI() end end
  local summon=env.FyrelithAutoSummon
  if summon and type(saved.Summon)=='table' then
   local data=saved.Summon
   if type(data.Config)=='table' then
    for k,v in pairs(data.Config) do if type(v)==type(summon.Config[k]) then summon.Config[k]=v end end
   end
   summon.Count=math.max(0,tonumber(data.Count) or 0)
   summon.Enabled=data.Enabled==true summon.RefreshUI()
   if summon.Enabled then summon.Runner=task.spawn(summon.Run) end
  end
  local redeem=env.FyrelithRedeemCodes
  if redeem and saved.Redeem and saved.Redeem.Enabled then redeem.Enabled=true if redeem.RefreshUI then redeem.RefreshUI() end if Loader.IsLobby then task.spawn(redeem.Run) end end
 end
 if type(saved)=='table' and type(saved.TeamEditor)=='table' and api.TeamRuleEditor then
  for k,v in pairs(saved.TeamEditor) do if type(v)=='string' or type(v)=='number' then api.TeamRuleEditor[k]=v end end
 end
 api.Ready=true api.Refresh()
 for _,paint in ipairs(switchPainters)do paint()end
 if env.FyrelithMacro and env.FyrelithMacro.RefreshActionsUI then env.FyrelithMacro.RefreshActionsUI() end
 local source=env.FyrelithScriptSource
 if type(source)=='string' and type(writefile)=='function' then
  local ok,err=pcall(fySaveRuntimeBundle,source)
  runtime.ScriptSaved=ok runtime.ScriptError=not ok and tostring(err) or nil
 end
 local queue=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
 if type(queue)=='function' and runtime.ScriptSaved then
  if not env.FyrelithDefaultTeleportQueued then
   local ok,err=pcall(queue,[=[
local source=readfile('.FyrelithDefaultCache/FyrelithRuntime.luau')
getgenv().FyrelithScriptSource=source
local run,err=loadstring(source)
if run then run() else warn('Fyrelith: '..tostring(err)) end
]=])
   runtime.AutoExec=ok runtime.QueueError=not ok and tostring(err) or nil
   if ok then env.FyrelithDefaultTeleportQueued=true end
  else runtime.AutoExec=true end
 end
 runtime.Connection=player.OnTeleport:Connect(function() runtime.Save() end)
 if preferences then runtime.PreferenceConnection=preferences.AttributeChanged:Connect(function() if runtime.Alive then runtime.Save() end end) end
 runtime.Save()
 task.spawn(function() while runtime.Alive and gui.Parent do runtime.Save() task.wait(.5) end end)
end


















-- Black-screen observatory: native 2D resource icons remain visible with world rendering off.
do
 local previous=env.FyrelithBlackScreen
 if previous and previous.Stop then pcall(previous.Stop) end
 local run=game:GetService('RunService')
 local G=env.FyrelithGameReady.Services.GUIService
 local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
 local settings=Loader.load_data(script,'GameplaySettings')
 local feature={Alive=true,Enabled=false,RenderingOff=false,BootReady=true,Token=0,Tiles={},Baseline={},Started=os.clock(),Connections={}}
 env.FyrelithBlackScreen=feature
 local function on(signal,fn) local c=signal:Connect(fn) table.insert(feature.Connections,c) return c end
 local function anim(obj,goals,duration)
  if preferences and (preferences:GetAttribute('ReduceMotion') or preferences:GetAttribute('Smooth')==false) then for k,v in pairs(goals) do obj[k]=v end return end
  game:GetService('TweenService'):Create(obj,TweenInfo.new(duration or .28,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),goals):Play()
 end
 local function number(value)
  local n=math.floor(tonumber(value) or 0) local sign=n<0 and '-' or ''
  local text=tostring(math.abs(n)) local out=text:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
  return sign..out
 end
 local overlay=new('ScreenGui',{Name='FyrelithBlackScreen',Enabled=false,ResetOnSpawn=false,IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ClipToDeviceSafeArea=false,DisplayOrder=2147483646,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player.PlayerGui)
 local black=new('Frame',{Name='BlackBackdrop',Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=1,BorderSizePixel=0,Active=true},overlay)
 local board=new('CanvasGroup',{Name='Observatory',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(960,620),BackgroundTransparency=1,GroupTransparency=1,ZIndex=2},black)
 local iconSource=gui:FindFirstChild('EventHorizon',true)
 local emblem=new('ImageLabel',{Name='BlackHole',Size=UDim2.fromOffset(46,46),BackgroundTransparency=1,Image=iconSource and (iconSource:IsA('ImageLabel') or iconSource:IsA('ImageButton')) and iconSource.Image or '',ScaleType=Enum.ScaleType.Fit},board)
 local title=label(board,'Heading','VOID OBSERVATORY',58,2,550,34,26,true)
 title.TextScaled=true new('UITextSizeConstraint',{MinTextSize=14,MaxTextSize=26},title)
 local subtitle=label(board,'LiveSubtitle','3D PAUSED  /  LIVE BALANCES',58,38,550,22,11,true) subtitle.TextColor3=muted
 local live=new('Frame',{Position=UDim2.fromOffset(59,66),Size=UDim2.fromOffset(4,4),BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(103,225,172)},board) round(live,4)
 local session=label(board,'Session','SESSION 00:00',70,58,370,20,11) session.TextColor3=muted
 local function action(name,text,x,fn)
  local b=new('TextButton',{Name=name,Text=text,Position=UDim2.fromOffset(x,12),Size=UDim2.fromOffset(116,36),BackgroundColor3=Color3.fromRGB(19,22,32),BackgroundTransparency=.1,TextColor3=white,TextSize=13,Font=Enum.Font.GothamMedium,AutoButtonColor=false,BorderSizePixel=0},board) round(b,11)
  local edge=new('UIStroke',{Color=Color3.fromRGB(130,116,176),Transparency=.7,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
  on(b.MouseEnter,function() anim(b,{BackgroundColor3=Color3.fromRGB(42,36,63)},.2) anim(edge,{Transparency=.3},.2) end)
  on(b.MouseLeave,function() anim(b,{BackgroundColor3=Color3.fromRGB(19,22,32)},.25) anim(edge,{Transparency=.7},.25) end)
  on(b.Activated,fn) return b
 end
 local controls=action('Controls','Controls',704,function() local c=gui:FindFirstChild('SetWindowOpen') if c then c:Invoke(true) end end)
 local resume=action('Resume3D','Resume 3D',832,function() if feature.SetEnabled then feature.SetEnabled(false,true) end end)
 local divider=new('Frame',{Name='PhotonLine',Position=UDim2.fromOffset(0,88),Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.fromRGB(191,174,255),BorderSizePixel=0,BackgroundTransparency=.5},board)
 local glint=new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.4),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.7,.4),NumberSequenceKeypoint.new(1,1)})},divider)
 local cells=new('ScrollingFrame',{Name='Balances',Position=UDim2.fromOffset(0,104),Size=UDim2.new(1,0,1,-192),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=Color3.fromRGB(160,142,218),CanvasSize=UDim2.new(),ClipsDescendants=true,ScrollingDirection=Enum.ScrollingDirection.Y},board)
 local footer=new('Frame',{Name='LiveRound',Size=UDim2.new(1,0,0,76),BackgroundColor3=Color3.fromRGB(9,11,17),BorderSizePixel=0},board) round(footer,12)
 local roundText=label(footer,'Round','Waiting for round data',16,8,700,25,15,true)
 local automationText=label(footer,'Automation','',16,35,700,22,12) automationText.TextColor3=muted
 local afkText=label(footer,'AntiAFK','',16,56,700,16,10) afkText.TextColor3=Color3.fromRGB(103,225,172)
 local connectionText=label(footer,'Connection','',760,10,180,22,12) connectionText.TextXAlignment=Enum.TextXAlignment.Right connectionText.TextColor3=muted
 local entries={} local entryById={} local nativeIcons={}
 local resourceFolder=G.get_resource_folder('Gems').Parent
 local function resourceIcon(id)
  local folder=resourceFolder:FindFirstChild(id) local icon=folder and folder:FindFirstChild('Icon')
  return icon and icon:IsA('ImageLabel') and icon.Image~='' and icon or nil
 end
 local function add(id,name,icon,getter,primary)
  if entryById[id] or not icon then return end
  local entry={Id=id,Name=name,Icon=icon,Get=getter,Primary=primary}
  entryById[id]=entry table.insert(entries,entry)
 end
 local function profile() return U.session and U.session.profile_data end
 local function liveBalance(name,fallback)
  local stats=player:FindFirstChild('_stats') local value=stats and stats:FindFirstChild(name)
  if value and value:IsA('ValueBase') and tonumber(value.Value) then return tonumber(value.Value) end
  return fallback()
 end
 feature.ReadLiveBalance=liveBalance
 add('gems','Gems',resourceIcon('Gems'),function() return liveBalance('gem_amount',function() local p=profile() return p and tonumber(p.gem_amount) end) end,true)
 add('gold','Gold',resourceIcon('Gold'),function() return liveBalance('gold_amount',function() local p=profile() return p and tonumber(p.gold_amount) end) end,true)
 local names={GemsLegacy='Legacy Gems',AprilCoins='April Coins',HolidayStars='Holiday Stars',SummerPearls='Summer Pearls'}
 local function discover()
  local p=profile() local resources=p and p.resources or {}
  local candidates={}
  for id,value in pairs(resources) do if type(id)=='string' and id:sub(1,1)~='_' and (tonumber(value) or 0)>0 then candidates[id]=true end end
  for id,active in pairs(settings.ACTIVE_RESOURCES or {}) do if active and type(id)=='string' and id:sub(1,1)~='_' then candidates[id]=true end end
  local ids={} for id in pairs(candidates) do table.insert(ids,id) end table.sort(ids)
  for _,id in ipairs(ids) do
   add('resource:'..id,names[id] or id:gsub('(%l)(%u)','%1 %2'),resourceIcon(id),function() return liveBalance('_resource'..id,function() local p=profile() return p and p.resources and tonumber(p.resources[id] or 0) end) end)
  end
 end
 discover()
 add('rerolls','Reroll Tokens',resourceIcon('_Trait'),function() return liveBalance('trait_reroll_tokens',function() local p=profile() return p and tonumber(p.trait_reroll_tokens or 0) end) end)
 for _,d in ipairs({{'star_remnant','Star Remnant'},{'star_remnant_limited','Limited Remnant'}}) do
  local id,name=d[1],d[2]
  local ok,frame=pcall(G.make_item_frame,id)
  if ok and frame then
   local image=frame:FindFirstChild('star_remnant',true)
   if image and image:IsA('ImageLabel') and image.Image~='' then
    nativeIcons[id]=image:Clone() nativeIcons[id].Parent=nil
    if id=='star_remnant_limited' then local badge=frame:FindFirstChild('limited',true) if badge and badge:IsA('ImageLabel') then nativeIcons[id..':badge']=badge:Clone() nativeIcons[id..':badge'].Parent=nil end end
    add(id,name,nativeIcons[id],function() local inventory=U.session and U.session.inventory return inventory and inventory:get_number_of_owned_item(id) end)
   end
   frame:Destroy()
  end
 end
 local function tile(entry)
  local frame=new('Frame',{Name='Balance_'..entry.Id,BackgroundColor3=Color3.fromRGB(12,14,21),BackgroundTransparency=.03,BorderSizePixel=0},cells) round(frame,14)
  local edge=new('UIStroke',{Color=Color3.fromRGB(116,106,150),Transparency=.74,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},frame)
  new('UIGradient',{Rotation=115,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(170,176,194))},frame)
  local icon=entry.Icon:Clone() icon.Name='ItemIcon' icon.Parent=frame icon.Position=UDim2.fromOffset(16,17) icon.Size=UDim2.fromOffset(34,34) icon.AnchorPoint=Vector2.zero icon.Rotation=0 icon.BackgroundTransparency=1 icon.Visible=true icon.Active=false icon.ScaleType=Enum.ScaleType.Fit icon.ZIndex=2
  if nativeIcons[entry.Id..':badge'] then local badge=nativeIcons[entry.Id..':badge']:Clone() badge.Name='LimitedBadge' badge.Parent=frame badge.AnchorPoint=Vector2.zero badge.Position=icon.Position-UDim2.fromOffset(2,2) badge.Size=UDim2.fromOffset(12,12) badge.Rotation=0 badge.BackgroundTransparency=1 badge.Visible=true badge.Active=false badge.ScaleType=Enum.ScaleType.Fit badge.ZIndex=3 end
  local name=label(frame,'Name',entry.Name,64,16,200,20,13,true) name.TextColor3=muted
  local value=label(frame,'Amount','—',64,39,200,38,entry.Primary and 30 or 24,true) value.TextScaled=true new('UITextSizeConstraint',{MinTextSize=16,MaxTextSize=entry.Primary and 30 or 24},value)
  local count=new('NumberValue',{Value=0},frame)
  on(count.Changed,function(v) value.Text=number(v) end)
  feature.Tiles[entry.Id]={Frame=frame,Name=name,Value=value,Count=count,Edge=edge,Entry=entry}
 end
 local function layout(viewportOverride)
  if not feature.Alive then return end
  local viewport=typeof(viewportOverride)=='Vector2' and viewportOverride or overlay.AbsoluteSize
  local width=math.max(240,math.min(960,viewport.X-40))
  local compact=width<620 local header=compact and 128 or 96
  local columns=width>=820 and 3 or width>=520 and 2 or 1
  local primaryColumns=width>=520 and 2 or 1
  local primaryCount=0 for _,entry in ipairs(entries) do if entry.Primary then primaryCount+=1 end end
  local naturalHeight=header+116+math.ceil(primaryCount/primaryColumns)*128+math.ceil((#entries-primaryCount)/columns)*116
  local height=math.max(240,math.min(naturalHeight,viewport.Y-112))
  board.Size=UDim2.fromOffset(width,height)
  title.Size=UDim2.fromOffset(compact and width-58 or width-338,34) title.TextSize=compact and 20 or 26
  subtitle.Size=UDim2.fromOffset(compact and width-58 or width-338,20) subtitle.TextSize=compact and 10 or 11
  subtitle.Text=width<440 and '3D PAUSED  /  LIVE' or '3D PAUSED  /  LIVE BALANCES'
  controls.Position=UDim2.fromOffset(compact and 0 or width-248,compact and 85 or 12)
  resume.Position=UDim2.fromOffset(compact and (width+12)/2 or width-120,compact and 85 or 12)
  controls.Size=UDim2.fromOffset(compact and (width-12)/2 or 116,32) resume.Size=controls.Size
  divider.Position=UDim2.fromOffset(0,header)
  cells.Position=UDim2.fromOffset(0,header+16) cells.Size=UDim2.fromOffset(width,height-header-108)
  footer.Position=UDim2.fromOffset(0,height-76)
  roundText.Size=UDim2.fromOffset(math.max(100,width-(width<520 and 140 or 190)),25) roundText.TextSize=width<520 and 13 or 15
  automationText.Size=UDim2.fromOffset(width-32,22) afkText.Size=UDim2.fromOffset(width-32,16)
  connectionText.Position=UDim2.fromOffset(width-(width<520 and 116 or 170),10) connectionText.Size=UDim2.fromOffset(width<520 and 100 or 154,22)
  local y=4 local primary={}
  for _,entry in ipairs(entries) do if not feature.Tiles[entry.Id] then tile(entry) end if entry.Primary then table.insert(primary,entry) end end
  for i,entry in ipairs(primary) do
   local t=feature.Tiles[entry.Id] local w=(width-8-(primaryColumns-1)*12)/primaryColumns
   t.Frame.Position=UDim2.fromOffset(4+((i-1)%primaryColumns)*(w+12),y+math.floor((i-1)/primaryColumns)*128) t.Frame.Size=UDim2.fromOffset(w,116)
  end
  y+=math.ceil(#primary/primaryColumns)*128+4
  local index=0
  for _,entry in ipairs(entries) do
   local t=feature.Tiles[entry.Id]
   if not entry.Primary then
    local w=(width-8-(columns-1)*12)/columns
    t.Frame.Position=UDim2.fromOffset(4+(index%columns)*(w+12),y+math.floor(index/columns)*116) t.Frame.Size=UDim2.fromOffset(w,104) index+=1
   end
   t.Name.Size=UDim2.new(1,-78,0,20) t.Value.Size=UDim2.new(1,-78,0,38)
  end
  cells.CanvasSize=UDim2.fromOffset(0,y+math.ceil(index/columns)*116+4)
 end
 -- Keep the match stopwatch independent of showing/hiding the observatory.
 local timer=env.FyrelithRoundTimer
 if not timer or timer.Job~=game.JobId then
  local clock=env.FyrelithMatchClock
  timer={Job=game.JobId,Start=clock and clock.Known and clock.Start or nil}
  env.FyrelithRoundTimer=timer
 end
 feature.Timer=timer
 local function resetTimer() timer.Start=nil timer.Finished=nil timer.Final=nil timer.Unknown=false end
 local function startTimer()
  resetTimer() timer.Start=os.clock()
 end
 local started=workspace:FindFirstChild('_waves_started')
 if started then
  on(started.Changed,function(value) if value then startTimer() else resetTimer() end end)
  if not started.Value then resetTimer() elseif not timer.Start then timer.Unknown=true end
 end
 local dataFolder=workspace:FindFirstChild('_DATA')
 local ended=dataFolder and dataFolder:FindFirstChild('GameFinished')
 local function finishTimer()
  if timer.Finished then return end
  timer.Finished=os.clock()
  if timer.Start then timer.Final=math.max(0,timer.Finished-timer.Start) end
 end
 if ended then on(ended.Changed,function(value) if value then finishTimer() end end) if ended.Value then finishTimer() end end
 function feature.RoundElapsed()
  if Loader.IsLobby then return nil,'Lobby' end
  if ended and ended.Value then
   local results=G.results_ui local stats=results and results.settings and results.settings.stats
   if stats and tonumber(stats.time_taken) then timer.Final=math.max(0,tonumber(stats.time_taken)) end
   return timer.Final,'Finished'
  end
  if not started or not started.Value then return 0,'Waiting for Start' end
  if timer.Start then return math.max(0,os.clock()-timer.Start),'Playing' end
  return nil,'Start time unavailable'
 end
 local function refresh()
  if not feature.Alive then return end
  for _,entry in ipairs(entries) do
   local t=feature.Tiles[entry.Id] local ok,value=pcall(entry.Get)
   if t and ok and type(value)=='number' then
    if feature.Baseline[entry.Id]==nil then feature.Baseline[entry.Id]=value end
    if t.Last~=value then
     if t.Last==nil then t.Count.Value=value t.Value.Text=number(value) else anim(t.Count,{Value=value},.45) t.Edge.Transparency=.28 anim(t.Edge,{Transparency=.74},.7) end
     t.Last=value
    end
   elseif t then t.Value.Text='—' end
  end
  local elapsed,timerState=feature.RoundElapsed()
  if type(elapsed)=='number' then
   local seconds=math.floor(elapsed)
   local formatted=seconds>=3600 and string.format('%02d:%02d:%02d',math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60) or string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
   session.Text=(timerState=='Finished' and 'FINISHED  ' or 'MATCH TIME  ')..formatted
  else session.Text=timerState end
  if timerState=='Waiting for Start' then session.Text='WAITING FOR START  00:00' end
  local wave=workspace:FindFirstChild('_wave_num') local w=wave and tonumber(wave.Value) or 0
  local data=Loader.LevelData local id=type(data)=='table' and (data.id or data.level_id) or type(data)=='string' and data or ''
  roundText.Text=Loader.IsLobby and 'Lobby  ·  Ready' or ((Levels[id] and Levels[id].name or 'Match')..'  ·  Wave '..tostring(w))
  local macro=env.FyrelithMacro
  automationText.Text=macro and macro.State~='Idle' and ('Macro '..macro.State..'  ·  '..tostring(macro.Index or 0)..' / '..#(macro.Steps or {})..' actions') or ('Auto Join '..(api.Enabled and 'On' or 'Off')..'  ·  Macro '..(macro and macro.Config.PlayRequested and 'Armed' or 'Idle'))
  afkText.Text=env.FyrelithAntiAFK and env.FyrelithAntiAFK.Alive and (env.FyrelithAntiAFK.LastError and 'ANTI-AFK  ·  INPUT FAILED' or 'ANTI-AFK  ·  ACTIVE') or ''
  local ok,ping=pcall(function() return game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() end)
  connectionText.Text=ok and type(ping)=='number' and tostring(math.floor(ping+.5))..' ms  ·  LIVE' or 'LIVE DATA'
  local recovery=env.FyrelithIdleRecovery
  if recovery and recovery.Pending then
   automationText.Text='AFK recovery  ·  '..recovery.Status..'  ·  Attempt '..recovery.Attempts..' / 4'
   connectionText.Text='RECONNECTING'
  end
 end
 feature.Refresh=refresh
 local refreshQueued=false
 local function scheduleLiveRefresh()
  if not feature.Enabled or refreshQueued then return end refreshQueued=true
  task.defer(function()
   refreshQueued=false if not feature.Alive then return end
   local ok,err=pcall(refresh) feature.DataError=not ok and tostring(err) or nil
  end)
 end
 local watchedStats=setmetatable({},{__mode='k'})
 local function watchStats(stats)
  local function watch(value)
   if not value:IsA('ValueBase') or watchedStats[value] then return end
   if value.Name=='gem_amount' or value.Name=='gold_amount' or value.Name=='trait_reroll_tokens' or value.Name:sub(1,9)=='_resource' then
    watchedStats[value]=true on(value.Changed,scheduleLiveRefresh)
   end
  end
  for _,value in ipairs(stats:GetChildren()) do watch(value) end
  on(stats.ChildAdded,watch)
 end
 local stats=player:FindFirstChild('_stats') if stats then watchStats(stats) end
 on(player.ChildAdded,function(child) if child.Name=='_stats' then watchStats(child) end end)
;(function()
 local previous=env.FyrelithPrivacy
 if previous and previous.Stop then previous.Stop()end
 local feature={Alive=true,Enabled=false,Alias='Fyrelith',Watched={},Connections={}}
 env.FyrelithPrivacy=feature
 local H=game:GetService('HttpService')
 local file='FyrelithPrivacy_'..player.UserId..'_'..game.GameId..'.json'
 pcall(function()local saved=H:JSONDecode(readfile(file));feature.Enabled=saved.HideRealName==true end)
 local names={player.Name}
 if player.DisplayName~=player.Name then names[#names+1]=player.DisplayName end
 table.sort(names,function(a,b)return #a>#b end)
 function feature.Mask(text)
  -- Replace complete names only, preserving surrounding text and RichText tags.
  for _,name in ipairs(names)do
   if name~='' and name~=feature.Alias then
    local escaped=name:gsub('([^%w])','%%%1')
    text=text:gsub('%f[%w_]'..escaped..'%f[^%w_]',function()return feature.Alias end)
   end
  end
  return text
 end
 local function update(object,record)
  if not feature.Alive or not feature.Enabled or record.Writing or not object.Parent then return end
  local current=object[record.Property]
  local masked=feature.Mask(current)
  if masked~=current then
   record.Original=current;record.Masked=masked;record.Writing=true
   object[record.Property]=masked;record.Writing=false
  elseif current~=record.Masked then record.Original=nil;record.Masked=nil end
 end
 local function watch(object)
  if not feature.Enabled or feature.Watched[object]then return end
  local property
  if object:IsA('TextLabel')or object:IsA('TextButton')then property='Text'
  elseif object:IsA('Humanoid')and player.Character and object:IsDescendantOf(player.Character)then property='DisplayName' end
  if not property then return end
  local record={Property=property}
  feature.Watched[object]=record
  record.Changed=object:GetPropertyChangedSignal(property):Connect(function()update(object,record)end)
  record.Destroyed=object.Destroying:Connect(function()
   record.Changed:Disconnect();record.Destroyed:Disconnect();feature.Watched[object]=nil
  end)
  update(object,record)
 end
 local function restore()
  for object,record in pairs(feature.Watched)do
   record.Changed:Disconnect();record.Destroyed:Disconnect()
   pcall(function()if object.Parent and record.Original and object[record.Property]==record.Masked then object[record.Property]=record.Original end end)
  end
  table.clear(feature.Watched)
  for _,connection in ipairs(feature.Connections)do connection:Disconnect()end
  table.clear(feature.Connections)
 end
 local function start()
  for _,container in ipairs({player.PlayerGui,game:GetService('CoreGui'),workspace})do
   pcall(function()
    feature.Connections[#feature.Connections+1]=container.DescendantAdded:Connect(watch)
    for _,class in ipairs({'TextLabel','TextButton'})do for _,object in ipairs(container:QueryDescendants(class))do watch(object)end end
   end)
  end
  local humanoid=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  if humanoid then watch(humanoid)end
  -- Character parenting can precede LocalPlayer.Character on a server transfer.
  local function characterReady(character)
   task.spawn(function()
    local h=character:WaitForChild('Humanoid',15)
    if feature.Enabled and feature.Alive and h and player.Character==character then watch(h);local record=feature.Watched[h];if record then update(h,record)end end
   end)
  end
  feature.Connections[#feature.Connections+1]=player.CharacterAdded:Connect(characterReady)
  if player.Character then characterReady(player.Character)end
  local token={};feature.StartToken=token
  task.spawn(function()
   -- Native chat, player lists and account panels may rebuild after profile load.
   for _,delay in ipairs({1,2,5,8})do
    task.wait(delay)
    if not feature.Alive or not feature.Enabled or feature.StartToken~=token then return end
    for _,container in ipairs({player.PlayerGui,game:GetService('CoreGui'),workspace})do
     pcall(function()for _,class in ipairs({'TextLabel','TextButton'})do for _,object in ipairs(container:QueryDescendants(class))do watch(object)end end end)
    end
    for object,record in pairs(feature.Watched)do update(object,record)end
    if player.Character then characterReady(player.Character)end
   end
  end)
 end
 function feature.SetEnabled(value,persist)
  feature.Enabled=value==true
  restore()
  if feature.Enabled then start()end
  if persist~=false then pcall(function()writefile(file,H:JSONEncode({HideRealName=feature.Enabled}))end)end
 end
 function feature.Stop()
  feature.Enabled=false;restore();feature.Alive=false
 end
 local panel=card('PrivacyCard',462,246,438,102);panel.Parent=main.Parent.Misc
 label(panel,'Title','Privacy',18,12,402,28,18,true)
 switch('HideRealName','Hide Real Name','',0,function()return feature.Enabled end,function(value)feature.SetEnabled(value)end)
 local toggle=ui('HideRealName');toggle.Parent=panel;toggle.Position=UDim2.fromOffset(18,55)
 task.defer(function()
  if not panel.Parent then return end
  local bottom=234
  for _,item in ipairs(panel.Parent:GetChildren())do
   if item~=panel and item:IsA('GuiObject')and item.Position.X.Offset>=450 then bottom=math.max(bottom,item.Position.Y.Offset+item.Size.Y.Offset)end
  end
  panel.Position=UDim2.fromOffset(462,bottom+12)
  local height=panel.Position.Y.Offset+panel.Size.Y.Offset+16
  panel.Parent.CanvasSize=UDim2.fromOffset(0,math.max(panel.Parent.CanvasSize.Y.Offset,height))
 end)
 connect(gui.Destroying,feature.Stop)
 feature.SetEnabled(feature.Enabled,false)
end)()

 local panel=card('BlackScreenCard',462,92,438,142) panel.Parent=main.Parent.Misc
 label(panel,'Title','Black Screen',18,12,402,28,18,true)
 local status=label(panel,'Status','3D rendering is on',18,101,402,24,12) status.TextColor3=muted
 local paint=switch('Disable3DRendering','Disable 3D Rendering','',0,function() return feature.Enabled end,function(value) feature.SetEnabled(value) end)
 local toggle=ui('Disable3DRendering') toggle.Parent=panel toggle.Position=UDim2.fromOffset(18,55)
 function feature.Reapply()
  if not feature.Alive or not feature.Enabled then return false end
  local ok,err=pcall(function() run:Set3dRenderingEnabled(false) end)
  if ok then
   feature.RenderingOff=true feature.LastRenderSync=os.clock() feature.ReapplyCount=(feature.ReapplyCount or 0)+1 feature.RenderError=nil
   overlay.Enabled=true
  else feature.RenderError=tostring(err) end
  return ok
 end
 function feature.SetEnabled(value,keepControls)
  if not feature.Alive then return false end
  value=value==true feature.Token+=1 local token=feature.Token
  if value then
   feature.Enabled=true feature.Baseline={} feature.Started=os.clock()
   layout() refresh() overlay.Enabled=true
   anim(black,{BackgroundTransparency=0},.22) anim(board,{GroupTransparency=0},.32)
   task.delay(.23,function()
    if not feature.Alive or token~=feature.Token then return end
    local ok,err=pcall(function() run:Set3dRenderingEnabled(false) end)
    if not ok then
     feature.Error=tostring(err)
     local boot=env.FyrelithRenderBootstrap if boot and boot.Active then boot.Finish() end
     pcall(function() run:Set3dRenderingEnabled(true) end)
     feature.Enabled=false feature.RenderingOff=false overlay.Enabled=false black.BackgroundTransparency=1 board.GroupTransparency=1
     paint()
     if preferences then preferences:SetAttribute('RenderingDisabled',false) end
     status.Text='3D control unavailable in this executor'
     return
    end
    feature.RenderingOff=true feature.LastRenderSync=os.clock() status.Text='3D off  ·  Live balances active'
    if not keepControls then local control=gui:FindFirstChild('SetWindowOpen') if control then control:Invoke(false) end end
   end)
  else
   local boot=env.FyrelithRenderBootstrap if boot and boot.Active then boot.Finish() end
   local ok,err=pcall(function() run:Set3dRenderingEnabled(true) end)
   if not ok then feature.Error=tostring(err) status.Text='Could not resume 3D rendering' return false end
   feature.Enabled=false feature.RenderingOff=false
   anim(black,{BackgroundTransparency=1},.2) anim(board,{GroupTransparency=1},.16)
   task.delay(.22,function() if feature.Alive and token==feature.Token then overlay.Enabled=false end end)
   status.Text='3D rendering is on'
  end
  paint()
  if preferences then preferences:SetAttribute('RenderingDisabled',value) end
  local runtime=env.FyrelithRuntime if runtime and runtime.Save then runtime.Save() end
  return true
 end
 function feature.Stop()
  if not feature.Alive then return end
  feature.Alive=false feature.Enabled=false feature.RenderingOff=false feature.Token+=1
  local boot=env.FyrelithRenderBootstrap
  if not (boot and boot.Active) then pcall(function() run:Set3dRenderingEnabled(true) end) end
  for _,c in ipairs(feature.Connections) do c:Disconnect() end
  for _,icon in pairs(nativeIcons) do icon:Destroy() end
  overlay:Destroy() panel:Destroy()
 end
 on(overlay:GetPropertyChangedSignal('AbsoluteSize'),layout)
 on(gui.Destroying,feature.Stop)
 local clock=0
 on(run.RenderStepped,function(dt)
  if not feature.Enabled or (preferences and (preferences:GetAttribute('ReduceMotion') or preferences:GetAttribute('Smooth')==false)) then return end
  clock+=math.min(dt,.05) glint.Rotation=math.sin(clock*.18)*10 live.BackgroundTransparency=.12+math.sin(clock*1.6)*.1
 end)
 layout()
 task.spawn(function()
  local tick=0
  while feature.Alive and gui.Parent do
   if feature.Enabled then
    if feature.RenderingOff and os.clock()-(feature.LastRenderSync or 0)>=2 then feature.Reapply() end
    local ok,err=pcall(function() tick+=1 if tick%5==0 then local count=#entries discover() if #entries~=count then layout() end end refresh() end)
    feature.DataError=not ok and tostring(err) or nil
   end
   task.wait(1)
  end
 end)
 if (preferences and preferences:GetAttribute('RenderingDisabled')==true) or (env.FyrelithRenderBootstrap and env.FyrelithRenderBootstrap.Active) then feature.SetEnabled(true) end
end



-- Hourly challenge priority. Rotation identity comes from the server, never a local clock bucket.
do
 local a={Alive=true,Enabled=false,Priority=false,Joining=false,State='Disabled'}
 local previous=env.FyrelithAutoChallenge
 if previous then previous.Alive=false if previous.RestoreCountdown then previous.RestoreCountdown() end end
 env.FyrelithAutoChallenge=a
 local H=game:GetService('HttpService')
 local file='FyrelithChallenge_'..player.UserId..'_'..game.GameId..'.json'
 local store={Enabled=false,Mode='Challenge',Rounds={}}
 pcall(function()
  local d=H:JSONDecode(readfile(file))
  if type(d)=='table' then
   if type(d.Rounds)~='table' then d.Rounds={Challenge={Round=d.Round,Attempts=d.Attempts,CheckAt=d.CheckAt,BattleJob=d.BattleJob,JoinedFrom=d.JoinedFrom}} end
   store=d
  end
 end)
 a.Mode=store.Mode=='Daily Challenge' and 'Daily Challenge' or 'Challenge'
 if type(store.EnabledModes)~='table' then store.EnabledModes={[a.Mode]=store.Enabled==true} end
 a.EnabledModes={Challenge=store.EnabledModes.Challenge==true,['Daily Challenge']=store.EnabledModes['Daily Challenge']==true}
 a.Enabled=a.EnabledModes.Challenge or a.EnabledModes['Daily Challenge']
 local data
 local function selectState()
  store.Rounds=store.Rounds or {}
  if type(store.Rounds[a.Mode])~='table' then store.Rounds[a.Mode]={Attempts=0} end
  data=store.Rounds[a.Mode]
 end
 selectState()
 local busy=false local lastPoll=-math.huge local lastJoin=-math.huge local lastDeparture=-math.huge
 local modes={
  Challenge={Endpoint='get_normal_challenge',Completed='last_completed_challenge_uuid',Countdown='on_normal_challenge_remaining_time_changed',Duration='CHALLENGE_DURATION',Rooms='Challenges'},
  ['Daily Challenge']={Endpoint='get_daily_challenge',Completed='last_completed_daily_challenge_uuid',Countdown='on_daily_challenge_remaining_time_changed',Duration='DAILY_CHALLENGE_DURATION',Rooms='DailyChallenge'},
 }
 a.Modes=modes
 local function save()
  store.Enabled=a.Enabled store.Mode=a.Mode store.EnabledModes=a.EnabledModes
  local ok,err=pcall(function() writefile(file,H:JSONEncode(store)) end)
  a.SaveError=not ok and tostring(err) or nil
  return ok
 end
 a.Save=save
 a.EntryMode=store.EntryMode=='Matchmaking' and 'Matchmaking' or 'Solo'
 a.QueueGeneration=0
 function a.SetEntryMode(value)
  if value~='Solo' and value~='Matchmaking' then return false end
  a.EntryMode=value;store.EntryMode=value
  a.QueueGeneration+=1;a.QueuePrompt=false;a.Queued=false;a.QueueAt=nil
  lastPoll=-math.huge
  save();return true
 end
 function a.RequestMatchmaking(current,selectedMode)
  local key=selectedMode..':'..tostring(current.current_uuid)
  if a.QueueKey~=key then
   a.QueueGeneration+=1;a.QueueKey=key;a.QueuePrompt=false;a.Queued=false;a.QueueAt=nil
  end
  if a.Queued then a.State='Challenge matchmaking • waiting for teleport';return end
  if a.QueuePrompt then a.State='Complete the game matchmaking confirmation';return end
  if a.QueueAt and os.clock()-a.QueueAt<15 then return end
  local services=env.FyrelithGameReady and env.FyrelithGameReady.Services
  local notifications=services and services.GUIService and services.GUIService.notification_windows_ui
  if not notifications or notifications.HAS_MATCHMAKING_PROMPT then a.State='Waiting for matchmaking confirmation';return end
  local generation=a.QueueGeneration
  a.QueuePrompt=true;a.QueueAt=os.clock()
  local ok,err=pcall(function()
   notifications:show_matchmaking_popup({_SkipFirst=true,
    OnMatchmaking=function()
     if not a.Alive or not api.Alive or not Loader.IsLobby or not a.EnabledModes[selectedMode]
      or a.EntryMode~='Matchmaking' or a.QueueGeneration~=generation or a.Queued then return end
     a.QueuePrompt=false
     local fresh=a.NormalizeCurrent(EP.invoke_server(modes[selectedMode].Endpoint),selectedMode)
     if not fresh or tostring(fresh.current_uuid)~=tostring(current.current_uuid) then
      a.State='Challenge rotated • checking again';lastPoll=-math.huge;return
     end
     if not a.Alive or not a.EnabledModes[selectedMode] or a.EntryMode~='Matchmaking' or a.QueueGeneration~=generation then return end
     if api.ApplyTeam then
      local teamOK,teamError=api.ApplyTeam(current.current_level_id,selectedMode)
      if not teamOK then a.State=tostring(teamError);return end
     end
     data.JoinedFrom=game.JobId
     if not save() then a.State='Cannot save challenge state • queue paused';return end
     a.Queued=true
     local joined,result=pcall(invoke,'request_matchmaking',selectedMode=='Daily Challenge' and '__DAILY_CHALLENGE' or '__NORMAL_CHALLENGE')
     if generation~=a.QueueGeneration then return end
     if not joined or result==false then a.Queued=false;a.State='Matchmaking failed • retrying';a.LastError=tostring(result)
     else a.State='Challenge matchmaking • waiting for teleport' end
    end,
    OnFinish=function()if a.QueueGeneration==generation then a.QueuePrompt=false end end,
   })
  end)
  if not ok then a.QueuePrompt=false;a.State='Matchmaking prompt failed • retrying';a.LastError=tostring(err) end
 end

 function a.SetEnabled(mode,value)
  if not modes[mode] then return false end
  a.EnabledModes[mode]=value==true
  a.QueueGeneration+=1;a.QueuePrompt=false;a.Queued=false;a.QueueAt=nil
  a.Enabled=a.EnabledModes.Challenge or a.EnabledModes['Daily Challenge']
  if not busy then a.Priority=false a.InChallenge=false end
  lastPoll=-math.huge
  a.State=a.Enabled and 'Checking enabled challenges…' or 'Disabled'
  save() return true
 end
 card('AutoChallengeCard',462,314,438,218)
 label(root,'AutoChallengeTitle','Challenge',480,326,402,24,18,true)
 local note=label(root,'AutoChallengeStatus','Disabled',480,492,402,24,13)
 local paint=switch('AutoChallenge','Auto Challenge','',356,function() return a.EnabledModes.Challenge end,function(v) a.SetEnabled('Challenge',v) end,480)
 local paintDaily=switch('AutoDailyChallenge','Auto Daily Challenge','',400,function() return a.EnabledModes['Daily Challenge'] end,function(v) a.SetEnabled('Daily Challenge',v) end,480)
 local entryPicker;entryPicker=picker('Challenge Entry',480,448,function()return {{id='Solo',name='Solo'},{id='Matchmaking',name='Matchmaking'}}end,function()return a.EntryMode end,function(entry)if a.SetEntryMode(entry.id) then entryPicker.Set(a.EntryMode) end end)
 root.Size=UDim2.fromOffset(908,544) main.CanvasSize=UDim2.fromOffset(0,544)
 local teleport=game:GetService('TeleportService')
 local settings=Loader.load_data(script,'GameplaySettings')
 local function duration(mode) return math.max(60,tonumber(settings[modes[mode].Duration]) or (mode=='Daily Challenge' and 86400 or 3600)) end
 local function now() return workspace:GetServerTimeNow() end
 -- Lobby countdown supplies a server deadline that survives teleports.
 if Loader.IsLobby then
  local client=Loader.load_client_service(script,'ChallengeServiceClient')
  local restores={}
  for mode,definition in pairs(modes) do
   local field=definition.Countdown local original=client and client[field]
   if type(original)=='function' then
   local wrapped
   wrapped=function(seconds,...)
    if a.Alive and type(seconds)=='number' and seconds>=0 and seconds<=duration(mode)+5 then
     local deadline=now()+seconds
     store.Rounds[mode]=store.Rounds[mode] or {Attempts=0} local target=store.Rounds[mode]
     if not target.CheckAt or math.abs(target.CheckAt-deadline)>3 then target.CheckAt=deadline save() end
    end
    return original(seconds,...)
   end
   client[field]=wrapped
   restores[#restores+1]=function() if client[field]==wrapped then client[field]=original end end
   end
  end
  a.RestoreCountdown=function() for _,restore in ipairs(restores) do restore() end end
  connect(gui.Destroying,a.RestoreCountdown)
 end
 local function profile()
  local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
  return U and U.session and U.session.profile_data
 end
 function a.Decide(enabled,current,completed,attempts)
  if not enabled then return 'disabled' end
  if type(current)~='table' or current.current_uuid==nil or type(current.current_level_id)~='string' then return 'unavailable' end
  if tostring(current.current_uuid)==tostring(completed) then return 'completed' end
  if (tonumber(attempts) or 0)>=3 then return 'exhausted' end
  return 'pending'
 end
 function a.IsSelectedChallenge(level,mode)
  if type(level)~='table' or level._gamemode~='challenge' or level._challenge_uuid==nil then return false end
  local daily=level._is_daily_challenge==true or level.id=='__DAILY_CHALLENGE'
  return (mode or 'Challenge')=='Daily Challenge' and daily or (mode or 'Challenge')=='Challenge' and not daily
 end
 function a.ChooseMode(enabled,rounds,p,timeNow,level)
  local first
  for _,mode in ipairs({'Challenge','Daily Challenge'}) do
   if enabled[mode] then
    first=first or mode
    if a.IsSelectedChallenge(level,mode) then return mode end
   end
  end
  for _,mode in ipairs({'Challenge','Daily Challenge'}) do if enabled[mode] then
   local state=rounds[mode] or {}
   local complete=state.Round~=nil and tostring(state.Round)==tostring(p[modes[mode].Completed])
   local waiting=(complete or (tonumber(state.Attempts) or 0)>=3) and type(state.CheckAt)=='number' and timeNow<state.CheckAt
   if not waiting then return mode end
  end end
  return first
 end
 function a.NormalizeCurrent(current,mode)
  if type(current)~='table' or current.current_uuid==nil then return end
  local level=current.current_level_id
  if mode=='Daily Challenge' then level='__DAILY_CHALLENGE' end
  if type(level)~='string' then return end
  return {current_uuid=current.current_uuid,current_level_id=level,current_challenge=current.current_challenge}
 end
 function a.DecideBattle(enabled,level,completed,round,attempts,deadline,timeNow,ended,mode)
  if not enabled then return 'disabled' end
  local challenge=a.IsSelectedChallenge(level,mode)
  if challenge and (ended or tostring(level._challenge_uuid)==tostring(completed)) then return 'return' end
  if type(deadline)=='number' and timeNow>=deadline then return 'return' end
  if challenge then return 'playing' end
  if round==nil or type(deadline)~='number' then return 'return' end
  if tostring(round)==tostring(completed) or (tonumber(attempts) or 0)>=3 then return 'waiting' end
  return 'return'
 end
 local function depart()
  if os.clock()-lastDeparture<60 then return end
  local m=env.FyrelithMacro
  if m and m.State=='Finishing' then a.State='Waiting for macro save…' return end
  if m and (m.State=='Recording' or (m.State=='Paused' and m.BeforePause=='Recording')) then
   local ok,result=pcall(m.Save)
   if not ok or result==false then a.State='Macro save failed • departure paused' return end
   m.Token=(m.Token or 0)+1 m.State='Idle'
   if m.RefreshActionsUI then m.RefreshActionsUI() end
  end
  if m and m.FinishPlayback then m.FinishPlayback() end
  local settings=Loader.load_data(script,'GameplaySettings')
  local destination=tonumber(settings.LOBBY_PLACE_ID)
  if not destination then a.State='Lobby destination unavailable' return end
  if not save() then a.State='Cannot save challenge state • departure paused' return end
  local runtime=env.FyrelithRuntime
  if runtime and runtime.Save then runtime.Save() end
  lastDeparture=os.clock() a.State='Returning to lobby for '..a.Mode..'…'
  local ok,err=pcall(teleport.Teleport,teleport,destination,player)
  if not ok then a.State='Return failed • retrying in 60s' a.LastError=tostring(err) end
 end
 local function poll()
  if not a.Enabled or not api.Ready then a.Priority=false return end
  -- A hanging request owns this worker until it returns; never pile up remote calls.
  if busy then return end busy=true
  task.spawn(function()
   local ok,err=pcall(function()
    local p=profile() if not p then a.State='Waiting for player data…' return end
    local nextMode=a.ChooseMode(a.EnabledModes,store.Rounds,p,now(),not Loader.IsLobby and Loader.LevelData or nil)
    if not nextMode then return end
    a.Mode=nextMode selectState()
    local selectedMode=a.Mode local definition=modes[selectedMode]
    if not Loader.IsLobby then
     local p=profile() if not p then a.State='Waiting for player data…' return end
     local level=Loader.LevelData
     local decision=a.DecideBattle(a.Enabled,level,p[definition.Completed],data.Round,data.Attempts,data.CheckAt,now(),api.MatchEnded,selectedMode)
     a.InChallenge=a.IsSelectedChallenge(level,selectedMode)
     if a.InChallenge and data.BattleJob~=game.JobId then
      local id=tostring(level._challenge_uuid)
      if data.Round~=id then data.Round=id data.Attempts=0 end
      data.BattleJob=game.JobId data.Attempts=(tonumber(data.Attempts) or 0)+1 save()
     end
     if decision=='return' then a.Priority=true depart()
     elseif decision=='playing' then a.Priority=true a.State=selectedMode..' • attempt '..tostring(data.Attempts)..'/3'
     else a.Priority=false a.State='Completed • waiting for the next server rotation' end
     return
    end
    a.InChallenge=false
    local current=a.NormalizeCurrent(EP.invoke_server(definition.Endpoint),selectedMode)
    if not a.Alive or not api.Alive or not a.EnabledModes[selectedMode] or a.Mode~=selectedMode then return end
    if type(current)~='table' or current.current_uuid==nil or type(current.current_level_id)~='string' then
     a.State='Waiting for server challenge data…' return
    end
    a.Current=current
    local id=tostring(current.current_uuid)
    if data.Round~=id then
     data.Round=id data.Attempts=0 data.BattleJob=nil data.JoinedFrom=nil
     if not data.CheckAt or data.CheckAt<=now()+5 then data.CheckAt=now()+duration(selectedMode) end
     save()
    end
    data.Current={current_uuid=current.current_uuid,current_level_id=current.current_level_id,current_challenge=current.current_challenge}
    if not data.CheckAt or data.CheckAt<=now() then data.CheckAt=now()+duration(selectedMode) end
    save()
    local p=profile()
    if not p then a.State='Waiting for player data…' return end
    local decision=a.Decide(a.Enabled,current,p[definition.Completed],data.Attempts)
    if decision=='completed' then
     a.Priority=false a.State='Completed • waiting for a new rotation' return
    end
    if decision=='exhausted' then a.Priority=false a.State='3 attempts used • waiting for a new rotation' return end
    a.Priority=true
    if a.EntryMode=='Matchmaking' then
     if api.Busy or (api.PendingRequest and not api.PendingRequest.Done) then return end
     for _,path in pairs(paths) do
      local parent=workspace:FindFirstChild(path[1]);local group=parent and parent:FindFirstChild(path[2])
      if group then for _,room in ipairs(group:GetChildren()) do
       if member(room) then a.State='Leave the current room before matchmaking';return end
      end end
     end
     a.RequestMatchmaking(current,selectedMode);return
    end
    local area=workspace:FindFirstChild('_CHALLENGES')
    local rooms=area and area:FindFirstChild(definition.Rooms)
    if not rooms then a.State='Waiting for challenge lobbies…' return end
    -- Verify that the lobby assignment has caught up with the rotation response.
    local matching=false
    for _,room in ipairs(rooms:GetChildren()) do
     local lv=room:FindFirstChild('Level') local mod=room:FindFirstChild('Challenge')
     if lv and lv.Value==current.current_level_id and mod and mod.Value==current.current_challenge then matching=true break end
    end
    if not matching then a.State='Waiting for the new lobby assignment…' return end
    if api.Busy or (api.PendingRequest and not api.PendingRequest.Done) or os.clock()-lastJoin<12 then return end
    -- Another lobby membership must be cleared before requesting a different room.
    for mode,path in pairs(paths) do
     if mode~=selectedMode then
      local parent=workspace:FindFirstChild(path[1]) local group=parent and parent:FindFirstChild(path[2])
      if group then for _,r in ipairs(group:GetChildren()) do if member(r) then depart() return end end end
     end
    end
    data.JoinedFrom=game.JobId
    if not save() then a.State='Cannot save challenge state • join paused' return end
    lastJoin=os.clock()
    a.Joining=true
    local joined,joinError=pcall(api.Join,selectedMode,current)
    a.Joining=false
    a.State=joined and status.Text or ('Join failed • '..tostring(joinError))
   end)
   busy=false
   if not ok then a.Joining=false a.State='Challenge check failed • retrying' a.LastError=tostring(err) end
  end)
 end
 task.spawn(function()
  while api.Alive and a.Alive and gui.Parent do
   if not a.Enabled then a.Priority=false a.InChallenge=false a.State='Disabled'
   elseif os.clock()-lastPoll>=10 then lastPoll=os.clock() poll() end
   note.Text=a.State paint() paintDaily()
   task.wait(.5)
  end
  a.Alive=false a.Priority=false
  if a.RestoreCountdown then a.RestoreCountdown() end
 end)
end


do
 local previous=env.FyrelithAutoBuff if previous then previous.Alive=false end
 local a={Alive=true,Enabled={},States={},Pending={},History={},Lead=.18,Latency={},NextAttempt={},Holds=setmetatable({},{__mode='k'}),RequestThreads=setmetatable({},{__mode='k'})} env.FyrelithAutoBuff=a
 local H=game:GetService('HttpService')
 local file='FyrelithBuff_'..player.UserId..'_'..game.GameId..'.json'
 pcall(function() local d=H:JSONDecode(readfile(file)) if type(d)=='table' then a.Enabled=d end end)
 function a.Save() return pcall(function() writefile(file,H:JSONEncode(a.Enabled)) end) end
 local attacks=Loader.load_data(script,'Attacks')
 local units=Loader.load_data(script,'Units')
 local replication=Loader.load_client_service(script,'AttacksReplicate')
 local definitions={}
 -- Only explicitly marked support units with timed ally buffs qualify.
 for id,u in pairs(units) do
  if type(u)=='table' and u._show_as_buff_unit and type(u.active_attack)=='string' then
   local attack=attacks[u.active_attack] local duration
   if attack and not attack.custom_attack then
    for _,aoe in pairs(attack.aoe or {}) do
     if aoe.hit_allies=='allies' then
      for _,buff in pairs(aoe.hit and aoe.hit.buffs or {}) do
       if tonumber(buff.time) and buff.time>0 then duration=duration and math.min(duration,buff.time) or buff.time end
      end
     end
    end
   end
   if duration then definitions[#definitions+1]={Id=id,Name=u.name or id,Attack=u.active_attack,Duration=duration} end
  end
 end
 table.sort(definitions,function(x,y) return x.Name<y.Name end)
 a.Definitions=definitions
 local height=54+#definitions*66
 card('AutoBuffCard',462,492,438,height)
 label(root,'AutoBuffTitle','Auto Buff 100%',480,504,402,26,18,true)
 for index,d in ipairs(definitions) do
  local id=d.Id
  local y=538+(index-1)*66
  local state=label(root,'AutoBuffState_'..id,'Disabled',480,y+32,402,24,13)
  local paint=switch('AutoBuff_'..id,'Auto Buff '..d.Name,'',y,function() return a.Enabled[id]==true end,function(value)
   a.Enabled[id]=value a.Save()
  end,480)
  d.Label=state d.Paint=paint
 end
 local bottom=492+height+16
 root.Size=UDim2.fromOffset(908,math.max(root.Size.Y.Offset,bottom))
 main.CanvasSize=UDim2.fromOffset(0,root.Size.Y.Offset)
 local function value(s,n)
  local x=s and s:FindFirstChild(n)
  return x and x:IsA('ValueBase') and x.Value
 end
 function a.IsReady(remaining,ready)
  return ready==true and (remaining==nil or (type(remaining)=='number' and remaining<=0))
 end
 function a.ReadCooldown(unit,attack)
  local ok,queued,ready,_,remaining=pcall(replication.get_current_active_attack_cooldown,unit,attack)
  return ok and a.CooldownReady(queued,ready,remaining),remaining,queued,ok
 end
 function a.CooldownReady(queued,ready,remaining) return queued~=true and a.IsReady(remaining,ready) end
 function a.HasCastChanged(before,after)
  return type(after)=='number' and after>0 and (type(before)~='number' or after>before)
 end
 function a.IsOwnedCaster(unit)
  local s=unit and unit:FindFirstChild('_stats')
  return unit~=nil and unit.Parent~=nil and value(s,'player')==player and not value(s,'parent_unit') and value(s,'state')~='dead' and not game:GetService('CollectionService'):HasTag(unit,'dying_units')
 end
 function a.CastLead(id)
  local sample=a.Latency[id]
  return sample and math.clamp(math.max(sample.Mean+sample.Jitter*3+.12,(sample.Peak or sample.Mean)+.12),.45,1.1) or .45
 end
 function a.RecordLatency(id,elapsed)
  elapsed=math.clamp(elapsed,.01,2)
  local sample=a.Latency[id]
  if not sample then sample={Mean=elapsed,Jitter=0,Peak=elapsed} a.Latency[id]=sample
  else sample.Jitter=sample.Jitter*.75+math.abs(elapsed-sample.Mean)*.25 sample.Mean=sample.Mean*.75+elapsed*.25 sample.Peak=math.max(elapsed,(sample.Peak or elapsed)*.995) end
 end
 local function ownedTowers()
  local f=workspace:FindFirstChild('_UNITS') local out={}
  if f then for _,u in ipairs(f:GetChildren()) do
   local s=u:FindFirstChild('_stats')
   if a.IsOwnedCaster(u) then
    local ok,p=pcall(u.GetPivot,u)
    if ok then out[#out+1]={Unit=u,Stats=s,Id=value(s,'id'),Position=p.Position} end
   end
  end end
  return out
 end
 a.Rotations=previous and previous.Rotations or {}
 -- Preserve the active quartet when extra supports arrive or scan order changes.
 function a.SelectQuartet(id,available)
  local prior=a.Rotations[id]
  local present={};for _,caster in ipairs(available)do present[caster.Unit]=caster end
  local selected={};local members={}
  if prior then
   for _,unit in ipairs(prior.Order or {})do
    if present[unit] and #selected<4 then selected[#selected+1]=present[unit];members[unit]=true end
   end
  end
  for _,caster in ipairs(available)do
   if #selected>=4 then break end
   if not members[caster.Unit]then selected[#selected+1]=caster;members[caster.Unit]=true end
  end
  local changed=not prior or prior.Count~=#selected
  if not changed then for unit in pairs(members)do if not prior.Members[unit]then changed=true;break end end end
  if changed then
   prior={Count=#selected,Members=members,Order={},Armed=#selected<4}
   for _,caster in ipairs(selected)do prior.Order[#prior.Order+1]=caster.Unit end
   a.Rotations[id]=prior
  end
  return selected,prior
 end

 local function scan(d,towers)
  local supports={}
  for _,t in ipairs(towers) do
   if a.IsOwnedCaster(t.Unit) and t.Id==d.Id and value(t.Stats,'active_attack')==d.Attack then supports[#supports+1]=t
   end
  end
  if #supports==0 then a.Rotations[d.Id]=nil return nil,'Waiting for '..d.Name end
  local allSupports=supports
  local rotation
  supports,rotation=a.SelectQuartet(d.Id,supports)
  if not rotation.Armed then
   local available=0
   for _,caster in ipairs(supports)do
    local ready,remaining,queued,ok=a.ReadCooldown(caster.Unit,d.Attack)
    if ok and a.IsReady(remaining,ready) and queued~=true and os.clock()>=(a.Holds[caster.Unit]or 0) and not caster.Unit:GetAttribute('_auto_active')then available+=1 end
   end
   if available<#supports then return nil,'Synchronizing cooldowns • '..available..' / '..#supports..' ready' end
   rotation.Armed=true
  end
  local now=tick() local best local expiry=0
  -- One rotation per support type, independent of damage towers and placement.
  for _,caster in ipairs(supports) do
   expiry=math.max(expiry,(tonumber(value(caster.Stats,'last_active_cast')) or -1e8)+d.Duration)
  end
  if expiry>now+a.CastLead(d.Id) then return nil,'Buff active • '..math.ceil(expiry-now)..'s' end
  for _,caster in ipairs(supports) do
   local ready,remaining,queued,ok=a.ReadCooldown(caster.Unit,d.Attack)
   if ok and ready and os.clock()>=(a.Holds[caster.Unit] or 0) and not caster.Unit:GetAttribute('_auto_active') then
   local last=tonumber(value(caster.Stats,'last_active_cast')) or -1e8
   local bestLast=best and (tonumber(value(best.Stats,'last_active_cast')) or -1e8) or math.huge
   if last<bestLast then best=caster end
   end
  end
  if best then return best end
  return nil,'Waiting for cooldown • '..#supports..' placed'
 end
 a.Plan=scan a.GetOwnedTowers=ownedTowers
 local function step(d,towers)
  local id=d.Id
  local pending=a.Pending[id]
  if pending then
   if not pending.Unit.Parent then a.Pending[id]=nil
   elseif a.HasCastChanged(pending.Before,value(pending.Unit:FindFirstChild('_stats'),'last_active_cast')) then
    local last=tonumber(value(pending.Unit:FindFirstChild('_stats'),'last_active_cast'))
    local elapsed=os.clock()-pending.Sent
    a.RecordLatency(id,elapsed)
    a.History[#a.History+1]={Id=id,Unit=pending.Unit,Cast=last,ConfirmedAfter=elapsed}
    if #a.History>24 then table.remove(a.History,1) end
    a.Pending[id]=nil a.States[id]='Buff confirmed'
   elseif pending.Declined then
    a.Holds[pending.Unit]=os.clock()+1.5 a.NextAttempt[id]=os.clock()+.25 a.Pending[id]=nil a.States[id]='Skill declined • checking another ready caster'
   elseif os.clock()-pending.Sent<(pending.Error and 5 or 2) then a.States[id]='Confirming skill…' return
   else
    local ready,remaining,queued,known=a.ReadCooldown(pending.Unit,d.Attack)
    if not pending.Returned or not known or queued==true or not ready then a.States[id]='Waiting for skill confirmation…' return end
    -- The server returned, the unit is still ready and no cast was observed.
    -- Briefly hold this unit and allow another ready caster instead of a 65s gap.
    a.Holds[pending.Unit]=os.clock()+3 a.Pending[id]=nil
   end
  end
  if os.clock()<(a.NextAttempt[id] or 0) then return end
  local caster,message=scan(d,towers)
  if not caster then a.States[id]=message return end
  local request={Unit=caster.Unit,Before=value(caster.Stats,'last_active_cast'),Sent=os.clock()}
  a.Pending[id]=request a.States[id]='Casting '..d.Name..'…'
  task.spawn(function()
   if not api.Alive or not a.Alive or not a.Enabled[id] or not a.IsOwnedCaster(caster.Unit) then a.Pending[id]=nil return end
   -- Same endpoint and owned model argument used by the native active button.
   local thread=coroutine.running() a.RequestThreads[thread]=true
   local ok,result=pcall(EP.invoke_server,'use_active_attack',caster.Unit)
   a.RequestThreads[thread]=nil
   if a.Pending[id]~=request then return end
   request.Returned=true request.Declined=ok and result==false
   request.Error=not ok and tostring(result) or nil
  end)
 end
 a.Step=step
 local nextScan=0 local cachedTowers={}
 task.spawn(function()
  while api.Alive and a.Alive and gui.Parent do
   local ok,err=pcall(function()
    if os.clock()>=nextScan then cachedTowers=not Loader.IsLobby and ownedTowers() or {} nextScan=os.clock()+.12 end
    local towers=cachedTowers
    for _,d in ipairs(definitions) do
     if not a.Enabled[d.Id] then a.Rotations[d.Id]=nil;a.States[d.Id]='Disabled'
     elseif Loader.IsLobby then a.Rotations[d.Id]=nil;a.States[d.Id]='Waiting for match'
     elseif api.MatchEnded then a.Rotations[d.Id]=nil;a.States[d.Id]='Waiting for next match'
     else step(d,towers) end
     local message=a.States[d.Id] or 'Waiting…'
     if d.Label.Text~=message then d.Label.Text=message end
     local enabled=a.Enabled[d.Id]==true if d.LastPaint~=enabled then d.LastPaint=enabled d.Paint() end
    end
   end)
   if not ok then a.LastError=tostring(err) end
   task.wait(.03)
  end
  a.Alive=false
 end)
end



do
 local old=env.FyrelithAutoPlay if old and old.Stop then old.Stop() end
 local a={Alive=true,Version='2026-10-26-recovery-1',Config={ShowAreas=false,SellFinalFarm=false,Restore=false,Place=false,Path=25,UsePathPosition=true,Upgrade=false,FarmsFirst=false,Abilities=false,Walk=false,Plan=false,AfterPlan=false,Smart=false,SmartMatch=false,Radius=36,Name='Plan 1'},Plans={},Areas={},Index=1,Status='Idle',Capture=false,Pending=nil}
 env.FyrelithAutoPlay=a
 local H=game:GetService('HttpService')
 local file='FyrelithAutoPlay_'..player.UserId..'_'..game.GameId..'.json'
 local savedProgress
 pcall(function()
  local saved=H:JSONDecode(readfile(file))
  if type(saved.Plans)=='table' then a.Plans=saved.Plans end
  if type(saved.Areas)=='table' then a.Areas=saved.Areas end
  if type(saved.SmartRestore)=='table' then a.SmartRestore=saved.SmartRestore end
  savedProgress=saved.Progress
  for k,v in pairs(saved.Config or {}) do if type(v)==type(a.Config[k]) then a.Config[k]=v end end
 end)
 -- Unconfirmed actions from an interrupted capture are never replayed as confirmed steps.
 for name,p in pairs(a.Plans) do
  if type(p)~='table' or type(p.Steps)~='table' then a.Plans[name]=nil
  else for i=#p.Steps,1,-1 do
   local step=p.Steps[i]
   if type(step)~='table' or step.Confirming or type(step.CF)~='table' or #step.CF~=12 or type(step.UUID)~='string' then table.remove(p.Steps,i) end
  end end
 end
 local C=a.Config
 C.Path=math.clamp(math.floor((tonumber(C.Path) or 25)+.5),0,100)
 function a.SetPathPercent(value,commit)
  local cleaned=tostring(value):gsub('%%','')
  local parsed=tonumber(cleaned)
  if not parsed or parsed~=parsed then parsed=C.Path end
  C.Path=math.clamp(math.floor(parsed+.5),0,100)
  C.UsePathPosition=true
  if a.Smart then a.Smart.LastAnalysis=-math.huge a.Smart.Context=nil a.Smart.Candidates=nil end
  if commit~=false then a.Save() end
  return C.Path
 end
 C.ShowAreas=C.ShowAreas==true
 local U=env.FyrelithGameReady.Services.UnitCollectionServiceClient
 local Units=Loader.load_data(script,'Units')
 local Attacks=Loader.load_data(script,'Attacks')
 local Core=Loader.load_core_service(script,'UnitServiceCore')
 local Placement=Loader.load_core_service(script,'PlacementCore')
 local Replication=Loader.load_client_service(script,'AttacksReplicate')
 local page=main.Parent:FindFirstChild('Auto Play')
 if not page then return end
 function a.Save()
  local waves=workspace:FindFirstChild('_wave_num')
  local progress={Job=game.JobId,Name=C.Name,Index=a.Index,Completed=a.Completed==true,Wave=waves and waves.Value or 0}
  local ok,err=pcall(function() writefile(file,H:JSONEncode({Config=C,Plans=a.Plans,Areas=a.Areas,SmartRestore=a.SmartRestore,Progress=progress})) end)
  a.SaveError=not ok and tostring(err) or nil
  return ok
 end
 local function val(s,n) local v=s and s:FindFirstChild(n) return v and v:IsA('ValueBase') and v.Value end
 local function levelId() local l=Loader.LevelData return type(l)=='table' and (l.id or l.level_id) or l end
 local function wave() return tonumber(val(workspace,'_wave_num')) or 0 end
 local function cash() return tonumber(val(player:FindFirstChild('_stats'),'resource')) or 0 end
 local function flat(v) return Vector3.new(v.X,0,v.Z) end
 local function cfData(cf) return {cf:GetComponents()} end
 local function towers()
  local out={} local f=workspace:FindFirstChild('_UNITS')
  if f then for _,u in ipairs(f:GetChildren()) do
   local s=u:FindFirstChild('_stats')
   if u:IsA('Model') and val(s,'player')==player and game:GetService('CollectionService'):HasTag(u,'nonminion_units') and not val(s,'parent_unit') and val(s,'state')~='dead' and not game:GetService('CollectionService'):HasTag(u,'dying_units') then
    out[#out+1]={Unit=u,Stats=s,Id=val(s,'id'),UUID=val(s,'uuid'),CF=u:GetPivot(),Upgrade=tonumber(val(s,'upgrade')) or 0}
   end
  end end
  return out
 end
 local function equipped(includeRejected)
  local out={}
  for i,uuid in pairs(U.get_equipped_units()) do
   local unit=U.get_equipped_unit_by_uuid(uuid)
   if type(unit)=='table' and Units[unit.unit_id] then out[#out+1]={UUID=uuid,Id=unit.unit_id,Data=Units[unit.unit_id],Slot=tonumber(i) or 99} end
  end
  table.sort(out,function(x,y)return x.Slot<y.Slot end)
  return out
 end
 a.GetTowers=towers a.GetEquipped=equipped
 local function farm(id) local d=Units[id] return d and ((tonumber(d.farm_amount) or 0)>0 or d.farm_unit==true) end
 function a.CanAutoSell(id,unit)
  local d=id and Units[id];if not d or farm(id)then return false end
  if unit and(tonumber(val(unit:FindFirstChild('_stats'),'farm_amount'))or 0)>0 then return false end
  if d._show_as_buff_unit or(d.active_attack and tostring(d.active_attack):find('buff'))or(a.SmartRole and a.SmartRole(id)=='buff')then return false end
  local buffs=env.FyrelithAutoBuff
  for _,definition in ipairs(buffs and buffs.Definitions or{})do if definition.Id==id then return false end end
  return true
 end
 local function plan() return a.Plans[C.Name] end
 local function matchTower(step,all)
  if type(step.CF)~='table' or #step.CF~=12 then return end
  local p=CFrame.new(unpack(step.CF)).Position
  for _,t in ipairs(all) do if t.UUID==step.UUID and (flat(t.CF.Position)-flat(p)).Magnitude<1.5 then return t end end
 end
 local function macroBusy()
  local m=env.FyrelithMacro
  return m and m.Alive and m.State~='Idle'
 end
 local function panel(name,x,y,h,title)
  local p=card(name,x,y,438,h) p=p or root:FindFirstChild(name) p.Parent=page
  label(page,name..'Title',title,x+18,y+12,402,28,18,true)
 end
 local paints={}
 local function toggle(key,title,x,y)
  paints[#paints+1]=switch('Play_'..key,title,'',y,function() return C[key] end,function(v)
   if v and(key=='Place'or key=='Upgrade'or key=='Abilities')and a.PrepareManualPlay then a.PrepareManualPlay(key)end
   C[key]=v
   if key=='Plan' then a.Index=1 a.Completed=false a.Pending=nil end
   a.Save()
  end,x)
  root:FindFirstChild('Play_'..key).Parent=page
 end
 local function action(name,title,x,y,w,callback)
  local b=button(name,title,x,y,w,callback) b.Parent=page b.Size=UDim2.fromOffset(w,34) return b
 end
 local function input(name,text,x,y,w)
  local b=new('TextBox',{Name=name,Text=text,ClearTextOnFocus=false,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,32),BackgroundColor3=colors.field,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=14,BorderSizePixel=0},page)
  round(b,8) bind(b,'BackgroundColor3','field') return b
 end
 local activeMenuCloser
 local function playPicker(title,x,y,options,current,choose)
  local caption=label(page,'PlayPickerLabel_'..title,title,x,y,140,34,14,true)
  local anchor=new('TextButton',{Name='PlayPicker_'..title,Text=tostring(current()),Position=UDim2.fromOffset(x+144,y),Size=UDim2.fromOffset(258,34),BackgroundColor3=colors.field,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=14,BorderSizePixel=0,ZIndex=4},page)
  round(anchor,8) border(anchor) bind(anchor,'BackgroundColor3','field')
  local menu=new('CanvasGroup',{Name='PlayPickerMenu_'..title,Visible=false,GroupTransparency=1,Size=UDim2.fromOffset(258,246),BackgroundColor3=colors.card,BorderSizePixel=0,ZIndex=105},page)
  round(menu,8) border(menu) bind(menu,'BackgroundColor3','card')
  local search=new('TextBox',{Name='Search',Text='',PlaceholderText='Search…',ClearTextOnFocus=false,Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,0,30),BackgroundColor3=colors.field,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=13,BorderSizePixel=0,ZIndex=106},menu) round(search,6)
  local list=new('ScrollingFrame',{Name='Options',Position=UDim2.fromOffset(6,42),Size=UDim2.new(1,-12,0,198),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),ZIndex=106},menu)
  local toggleMenu,closeMenu=viewportDropdown(menu,anchor,list,246)
  local function draw()
   for _,v in ipairs(list:GetChildren()) do v:Destroy() end
   local count=0 local text=search.Text:lower()
   for _,item in ipairs(options()) do if text=='' or item.name:lower():find(text,1,true) then
    local row=new('TextButton',{Name='Option_'..tostring(item.id),Text=item.name,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Position=UDim2.fromOffset(0,count*34),Size=UDim2.new(1,-5,0,32),BackgroundColor3=colors.field,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=13,BorderSizePixel=0,ZIndex=107},list)
    round(row,6) new('UIPadding',{PaddingLeft=UDim.new(0,8)},row)
    row.Activated:Connect(function() choose(item) anchor.Text=tostring(current()) closeMenu() end)
    count+=1
   end end
   list.CanvasSize=UDim2.fromOffset(0,count*34)
  end
  connect(search:GetPropertyChangedSignal('Text'),draw)
  connect(anchor.Activated,function()
   if activeMenuCloser and activeMenuCloser~=closeMenu then activeMenuCloser(true) end
   activeMenuCloser=closeMenu draw() toggleMenu()
  end)
  return {Button=anchor,Label=caption,Set=function(text) anchor.Text=tostring(text) end}
 end
 panel('AutoPlayControls',8,8,372,'Auto Play')
 toggle('Place','Auto Place Units',26,56)
 label(page,'AutoPathLabel','Auto Place Path (%)',26,96,260,26,14,true)
 local pathInput=input('AutoPathPercent',tostring(C.Path),328,94,100)
 local pathTrack=new('TextButton',{Name='AutoPathTrack',Text='',Position=UDim2.fromOffset(26,128),Size=UDim2.fromOffset(402,5),BackgroundColor3=colors.line,BorderSizePixel=0,AutoButtonColor=false},page) round(pathTrack,4);bind(pathTrack,'BackgroundColor3','field')
 local pathFill=new('Frame',{Size=UDim2.fromScale(C.Path/100,1),BackgroundColor3=colors.accent,BorderSizePixel=0},pathTrack) round(pathFill,4) bind(pathFill,'BackgroundColor3','accent')
 local pathKnob=new('Frame',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(C.Path/100,.5),Size=UDim2.fromOffset(13,13),BackgroundColor3=white,BorderSizePixel=0},pathTrack) round(pathKnob,7);bind(pathKnob,'BackgroundColor3','accent')
 local dragging=false local UIS=game:GetService('UserInputService')
 local function setPath(x)
  a.SetPathPercent((x-pathTrack.AbsolutePosition.X)/math.max(pathTrack.AbsoluteSize.X,1)*100,false)
  pathInput.Text=tostring(C.Path) pathFill.Size=UDim2.fromScale(C.Path/100,1) pathKnob.Position=UDim2.fromScale(C.Path/100,.5)
 end
 connect(pathTrack.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true setPath(i.Position.X) end end)
 connect(UIS.InputChanged,function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setPath(i.Position.X) end end)
 connect(UIS.InputEnded,function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then dragging=false a.Save() end end)
 connect(pathInput.FocusLost,function() a.SetPathPercent(pathInput.Text) pathInput.Text=tostring(C.Path) end)
 toggle('Upgrade','Auto Upgrade Units',26,140)
 toggle('FarmsFirst','Upgrade Farms First',26,184)
 toggle('Abilities','Auto Use Abilities',26,228)
 toggle('Walk','Auto Walk (Anti AFK)',26,272)
 local state=label(page,'AutoPlayState','Idle',26,318,402,48,13)
 state.TextWrapped=true
 panel('AutoPlanControls',462,8,372,'Auto Play Plan')
 toggle('Plan','Auto Play Plan',480,56)
 toggle('AfterPlan','Auto Play After Plan',480,100)
 label(page,'AutoPlanNameLabel','Plan Name',480,148,140,28,14,true)
 local nameInput=input('AutoPlanName',C.Name,624,146,258)
 local function chooseName(text) C.Name=text a.SelectedStep=1 a.Index=1 a.Completed=false a.Pending=nil nameInput.Text=text a.Save() end
 connect(nameInput.FocusLost,function() if #nameInput.Text>0 and #nameInput.Text<=60 then chooseName(nameInput.Text) else nameInput.Text=C.Name end end)
 local selected=playPicker('Saved Plans',480,190,function()
  local list={} for name,p in pairs(a.Plans) do list[#list+1]={id=name,name=name..' • '..#(p.Steps or {})..' steps'} end
  table.sort(list,function(x,y) return x.id<y.id end) return list
 end,function() return C.Name end,function(v) chooseName(v.id) end)
 for _,v in ipairs({selected.Button,selected.Label}) do v.Parent=page end
 selected.Button.Size=UDim2.fromOffset(258,34)
 local capturePaint
 local function captureOff() a.Capture=false if capturePaint then capturePaint() end end
 function a.PrepareManualPlay(key)
  if a.Capture then captureOff() end
  C.Plan=false
  if key=='Place' or key=='Upgrade' then
   C.Smart=false
   a.SmartRestore=nil
   a.InvestmentReserve=nil
   if a.Smart then a.Smart.LastAnalysis=-math.huge end
  end
  return a.Save()
 end
 local function savePlan()
  captureOff()
  for _,s in ipairs(plan() and plan().Steps or {}) do if s.Confirming then a.Status='Finishing action confirmation • saving automatically' return end end
  if a.Save() then a.Status='Plan saved • '..C.Name else a.Status='Save failed • '..tostring(a.SaveError) end
 end
 local function addTower(p,t)
  for _,s in ipairs(p.Steps) do if s.Action=='Place' and s.UUID==t.UUID and (flat(CFrame.new(unpack(s.CF)).Position)-flat(t.CF.Position)).Magnitude<1 then return s end end
  local s={Action='Place',UUID=t.UUID,UnitId=t.Id,CF=cfData(t.CF),Wave=0}
  p.Steps[#p.Steps+1]=s return s
 end
 local function snapshot()
  if Loader.IsLobby then a.Status='Create Plan inside a match' return end
  if macroBusy() then a.Status='Stop Macro before creating a plan' return end
  if a.Plans[C.Name] then a.Status='Name already exists • use Edit Plan or a new name' return end
  C.Plan=false a.Pending=nil a.Index=1 a.Completed=false
  local p={Level=levelId(),Steps={}} a.Plans[C.Name]=p
  local all=towers()
  table.sort(all,function(x,y) if x.UUID~=y.UUID then return x.UUID<y.UUID end return x.CF.X<y.CF.X end)
  for _,t in ipairs(all) do
   local s=addTower(p,t)
   for n=1,t.Upgrade do p.Steps[#p.Steps+1]={Action='Upgrade',UUID=s.UUID,UnitId=s.UnitId,CF=s.CF,Target=n,Wave=0} end
  end
  a.Capture=true a.Status='Capturing • place, upgrade or sell units; then Save Plan' a.Save()
  if capturePaint then capturePaint() end
 end
 action('CreateAutoPlan','Create Plan',480,246,194,snapshot)
 action('EditAutoPlan','Edit Plan',688,246,194,function()
  if not plan() then a.Status='Select a saved plan first' return end
  C.Plan=false a.Pending=nil a.SelectedStep=1 a.Status='Edit steps below • enable Capture to append actions' a.Save()
 end)
 local deleteTime=0 local deleteName
 action('DeleteAutoPlan','Delete Plan',480,290,402,function()
  if deleteName~=C.Name or os.clock()-deleteTime>3 then deleteName=C.Name deleteTime=os.clock() a.Status='Press Delete Plan again within 3s to confirm' return end
  C.Plan=false captureOff() a.Plans[C.Name]=nil a.Pending=nil a.Save() a.Status='Plan deleted'
 end)
 local planState=label(page,'AutoPlanState','No plan selected',480,334,402,32,13)
 panel('AutoPlanEditor',8,398,454,'Plan Editor')
 capturePaint=switch('AutoPlanCapture','Capture Actions','',444,function() return a.Capture end,function(v)
  if v and (not plan() or Loader.IsLobby or plan().Level~=levelId() or macroBusy()) then a.Status='Open a matching plan in its match first' return end
  if v then C.Plan=false a.Pending=nil end
  a.Capture=v a.Save()
 end,26)
 root:FindFirstChild('AutoPlanCapture').Parent=page
 local stepPicker=playPicker('Selected Step',26,484,function()
  local list={} for i,s in ipairs(plan() and plan().Steps or {}) do list[#list+1]={id=i,name=i..'. '..s.Action..' • '..(Units[s.UnitId] and Units[s.UnitId].name or s.UnitId or '?')} end return list
 end,function() return a.SelectedStep or 1 end,function(v) a.SelectedStep=v.id end)
 for _,v in ipairs({stepPicker.Button,stepPicker.Label}) do v.Parent=page end
 local function edit(change)
  if C.Plan or a.Pending then a.Status='Turn Auto Play Plan off before editing' return end
  local p=plan() local index=a.SelectedStep or 1
  if not p or not p.Steps[index] then return end
  change(p,index) a.Save()
 end
 action('AutoPlanStepUp','Move Up',26,542,124,function() edit(function(p,i) if i>1 then p.Steps[i],p.Steps[i-1]=p.Steps[i-1],p.Steps[i] a.SelectedStep=i-1 end end) end)
 action('AutoPlanStepDown','Move Down',164,542,124,function() edit(function(p,i) if i<#p.Steps then p.Steps[i],p.Steps[i+1]=p.Steps[i+1],p.Steps[i] a.SelectedStep=i+1 end end) end)
 action('AutoPlanStepRemove','Remove',302,542,126,function() edit(function(p,i) table.remove(p.Steps,i) a.SelectedStep=math.max(1,i-1) end) end)
 label(page,'PlanWaveLabel','Wait for Wave',26,590,240,28,14,true)
 local waveInput=input('PlanWaveInput','0',292,588,136)
 connect(waveInput.FocusLost,function() edit(function(p,i) p.Steps[i].Wave=math.clamp(math.floor(tonumber(waveInput.Text) or 0),0,999) end) end)
 label(page,'PlanUpgradeLabel','Upgrade Target',26,634,240,28,14,true)
 local upgradeInput=input('PlanUpgradeInput','1',292,632,136)
 connect(upgradeInput.FocusLost,function() edit(function(p,i) if p.Steps[i].Action=='Upgrade' then p.Steps[i].Target=math.clamp(math.floor(tonumber(upgradeInput.Text) or 1),1,99) end end) end)
 action('SaveAutoPlan','Save Plan',26,680,402,savePlan)
 local preview=label(page,'AutoPlanPreview','',26,728,402,110,13)
 preview.TextWrapped=true preview.TextYAlignment=Enum.TextYAlignment.Top
 page.CanvasSize=UDim2.fromOffset(0,868)
 -- Confirm state before recording or advancing a step; requests are serialized.
 local original=EP.invoke_server
 local ownThreads=setmetatable({},{__mode='k'})
 local function request(endpoint,...)
  local thread=coroutine.running() ownThreads[thread]=true
  local packed=table.pack(pcall(original,endpoint,...)) ownThreads[thread]=nil
  return table.unpack(packed,1,packed.n)
 end
 local hook
 hook=function(endpoint,...)
  local args=table.pack(...)
  local p=a.Capture and plan()
  local entry,before
  if a.Alive and p and not ownThreads[coroutine.running()] and p.Level==levelId() then
   if endpoint=='spawn_unit' and type(args[1])=='string' and typeof(args[2])=='CFrame' then
    local unit=U.get_equipped_unit_by_uuid(args[1])
    if unit then entry={Action='Place',UUID=args[1],UnitId=unit.unit_id,CF=cfData(args[2]),Wave=0} end
   elseif (endpoint=='upgrade_unit_ingame' or endpoint=='sell_unit_ingame') and typeof(args[1])=='Instance' then
    for _,t in ipairs(towers()) do if t.Unit==args[1] then
     local s=addTower(p,t)
     before=t.Upgrade entry={Action=endpoint=='sell_unit_ingame' and 'Sell' or 'Upgrade',UUID=s.UUID,UnitId=s.UnitId,CF=s.CF,Target=before+1,Wave=0}
     break
    end end
   end
  end
  if entry then p.Steps[#p.Steps+1]=entry entry.Confirming=true end
  local result=table.pack(pcall(original,endpoint,table.unpack(args,1,args.n)))
  if entry then
   task.spawn(function()
    local deadline=os.clock()+5 local confirmed=false
    repeat
     local t=matchTower(entry,towers())
     confirmed=(entry.Action=='Place' and t~=nil) or (entry.Action=='Upgrade' and t and t.Upgrade>=entry.Target) or (entry.Action=='Sell' and t==nil)
     if confirmed then break end task.wait(.05)
    until not a.Alive or os.clock()>=deadline
    entry.Confirming=nil
    if not confirmed then for i,s in ipairs(p.Steps) do if s==entry then table.remove(p.Steps,i) break end end a.Status='Action not confirmed • not recorded' end
    a.Save()
   end)
  end
  if not result[1] then error(result[2],0) end
  return table.unpack(result,2,result.n)
 end
 EP.invoke_server=hook
 local function reset()
  a.Index=1 a.Completed=false a.Pending=nil a.MatchSerial=(a.MatchSerial or 0)+1
  if a.ResetRecovery then a.ResetRecovery() end
  if a.NewInvestmentBudget and a.Smart then a.Smart.Budget=a.NewInvestmentBudget() a.Smart.Context=nil end
  a.Save()
 end
 local waves=workspace:FindFirstChild('_waves_started')
 if waves then connect(waves.Changed,function(v) if not v then reset() end end) end
 local lastWave=wave()
 if type(savedProgress)=='table' and savedProgress.Job==game.JobId and savedProgress.Name==C.Name and (tonumber(savedProgress.Wave) or 0)<=lastWave then
  a.Index=math.max(1,math.floor(tonumber(savedProgress.Index) or 1)) a.Completed=savedProgress.Completed==true
 end
 local function confirmed(pending)
  if pending.Step.Action=='Upgrade' and pending.Unit then
   local stats=pending.Unit:FindFirstChild('_stats')
   return val(stats,'player')==player and (tonumber(val(stats,'upgrade')) or -1)>=pending.Step.Target
  end
  if pending.Step.Action=='Place' and pending.Kind=='restore' and a.ConfirmRecoveryPlace then return a.ConfirmRecoveryPlace(pending) end
  local t=matchTower(pending.Step,towers())
  if pending.Step.Action=='Place' then return t~=nil end
  if pending.Step.Action=='Upgrade' then return t and t.Upgrade>=pending.Step.Target end
  return pending.Unit and t==nil
 end
 local nextRequest=0 local rejected={}
 local upgradeHolds=setmetatable({},{__mode='k'}) a.UpgradeHolds=upgradeHolds
 function a.CanUpgrade(unit)
  local stats=unit and unit:FindFirstChild('_stats');local id=stats and stats:FindFirstChild('id');if id and id.Value~='aqua_evolved'and a.IsLimitedBuff and a.IsLimitedBuff(id.Value)then return false end
  local hold=upgradeHolds[unit] if not hold then return true end
  if val(unit:FindFirstChild('_stats'),'upgrade')~=hold.Before or os.clock()>=hold.Until then upgradeHolds[unit]=nil return true end
  return false
 end
 function a.IsLimitedBuff(id)
  local definition=Units[id]
  if definition and definition._show_as_buff_unit then return true end
  local autoBuff=env.FyrelithAutoBuff
  for _,entry in ipairs(autoBuff and autoBuff.Definitions or {})do if entry.Id==id then return true end end
  return a.SmartRole and a.SmartRole(id)=='buff' or false
 end
 function a.BuffPlacementAllowed(id,all)
  if not a.IsLimitedBuff(id) then return true end
  local count=0
  for _,tower in ipairs(all)do if tower.Id==id then count+=1 end end
  local data=Units[id]or{}
  local cap=a.PlacementCap and a.PlacementCap(id,data)or tonumber(data.spawn_cap)or 1
  if a.TeamPolicy then cap=math.min(cap,a.TeamPolicy.Get(id).MaxPlaced)end
  return count<math.min(4,cap)
 end
 function a.ValidateAutoAction(step,unit,kind)
  if step.Action=='Upgrade'and(kind=='smart'or kind=='auto')and step.UnitId~='aqua_evolved'and a.IsLimitedBuff(step.UnitId)then return false,'Buff rotation units are not automatically upgraded'end
  if step.Action=='Place' then
   local all=towers()
   if not a.BuffPlacementAllowed(step.UnitId,all)then return false,'Buff placement limit reached for this unit' end
   if a.BuffPositionAllowed then
    local valid,reason=a.BuffPositionAllowed(step.UnitId,CFrame.new(unpack(step.CF)).Position,all)
    if not valid then return false,reason end
   end
  end
  if step.Action=='Sell'then
   local id=unit and val(unit:FindFirstChild('_stats'),'id')or step.UnitId
   local finalFarm=kind=='farm-sale'and a.CanSellFinalFarm and a.CanSellFinalFarm(id,unit)
   if not finalFarm and not a.CanAutoSell(id,unit)then return false,'Protected unit · farm sale requires final-wave payout; buffs cannot be sold' end
  end
  if step.Action=='Place'and(C.Smart or kind=='smart')then
   local position=CFrame.new(unpack(step.CF)).Position
   if farm(step.UnitId)and a.IsFarmAwayFromPaths and not a.IsFarmAwayFromPaths(position,a.GetSmartPaths(),a.GetSmartPlacementMargin(step.UnitId))then return false,'Farm placement too close to enemy path • move or enlarge its circle' end
   if not a.IsWithinSmartAreas or not a.IsWithinSmartAreas(position,nil,a.GetSmartPlacementMargin(step.UnitId))then return false,'Placement cancelled · unit footprint outside Smart circles' end
  end
  return true
 end
 local function send(step,unit,kind)
  if a.Pending or os.clock()<nextRequest then return end
  local allowed,blocked=a.ValidateAutoAction(step,unit,kind)
  if not allowed then a.Status=blocked return end
  if step.Action=='Place' and (kind~='plan'or C.Smart) and a.CheckPlacementRequest then
   local valid,reason=a.CheckPlacementRequest(step)
   if not valid then a.Status=reason return end
  end
  nextRequest=os.clock()+(step.Action=='Upgrade' and .15 or .8)
  local pending={Step=step,Unit=unit,Sent=os.clock(),Kind=kind}
  a.Pending=pending
  task.spawn(function()
   if not a.Alive or a.Pending~=pending then return end
   if Loader.IsLobby or api.MatchEnded then a.Pending=nil return end
   local allowed,blocked=a.ValidateAutoAction(step,unit,kind)
   if not allowed then a.Pending=nil a.Status=blocked return end
   local endpoint=step.Action=='Place' and 'spawn_unit' or step.Action=='Upgrade' and 'upgrade_unit_ingame' or 'sell_unit_ingame'
   local ok,result
   if step.Action=='Place' then
    a.PlacementAudit=a.PlacementAudit or {}
    local position=CFrame.new(unpack(step.CF)).Position
    local padding=a.GetSmartPlacementMargin and a.GetSmartPlacementMargin(step.UnitId)or 0
    a.PlacementAudit[#a.PlacementAudit+1]={Id=step.UnitId,Kind=kind,Position=position,Smart=C.Smart,Padding=padding,Inside=a.IsWithinSmartAreas and a.IsWithinSmartAreas(position,nil,padding),At=os.clock()}
    if #a.PlacementAudit>24 then table.remove(a.PlacementAudit,1) end
    ok,result=request(endpoint,step.UUID,CFrame.new(unpack(step.CF)))
   else ok,result=request(endpoint,unit) end
   pending.Accepted=ok and result==true pending.Returned=true pending.Declined=ok and(result==false or step.Action=='Place'and result==nil) pending.Error=not ok and tostring(result) or nil
  end)
 end
 local function tickPending()
  local p=a.Pending if not p then return false end
  if confirmed(p) then
   if p.Step.Action=='Place'then a.LastPlacementIssue=nil end
   if p.Kind=='plan' then a.Index+=1 a.Save() end
   if a.RecordInvestment then a.RecordInvestment(p) end
   if a.RecoveryConfirmed then a.RecoveryConfirmed(p) end
   if p.Unit then upgradeHolds[p.Unit]=nil end
   a.Pending=nil a.Status='Confirmed • '..p.Step.Action return true
  end
  if p.Declined then
   if p.Step.Action=='Place'then a.LastPlacementIssue='Game declined placement • retrying another free position' end
   if a.RecoveryDeclined then a.RecoveryDeclined(p) end
   if p.PlacementKey then rejected[p.PlacementKey]=os.clock() end
   if p.Step.Action=='Upgrade' and p.Unit then upgradeHolds[p.Unit]={Before=p.Step.Target-1,Until=os.clock()+1} end
   if p.Step.Action=='Place' and a.Smart then a.Smart.PositionFailures={} a.Smart.LastAnalysis=-math.huge end
   a.Pending=nil nextRequest=os.clock()+.2 a.Status=p.Step.Action=='Place' and 'Placement declined • checking free positions and shared unit limits' or 'Waiting for cash / valid placement' return true
  end
  if p.Step.Action=='Upgrade' and (p.Kind=='auto' or p.Kind=='smart' or p.Kind=='restore') and p.Returned and os.clock()-p.Sent>3 then
   if p.Unit then upgradeHolds[p.Unit]={Before=p.Step.Target-1,Until=os.clock()+6} end
   a.LastUpgradeIssue=p.Error or 'Upgrade not confirmed • checking other units'
   a.Pending=nil a.Status='Checking other units • upgrade response delayed' return true
  end
  if p.Kind=='farm-sale' and p.Returned and os.clock()-p.Sent>3 then a.Pending=nil a.Status='Farm sale not confirmed • checking owned farms again' return true end
  if os.clock()-p.Sent>6 then a.Status='Action unconfirmed • waiting; no duplicate request' else a.Status='Confirming '..p.Step.Action..'…' end
  return true
 end
 local function price(t,target)
  local d=Units[t.Id] local upgrade=d and d.upgrade and d.upgrade[target]
  if not upgrade and target==t.Upgrade+1 and a.NativeUpgradeInfo then upgrade=a.NativeUpgradeInfo(t)end
  local cost=upgrade and tonumber(upgrade.cost)
  if not cost then return end
  local ok,multiplier=pcall(Core.calculate_upgrade_cost_multiplier,t.Unit,U.session)
  return math.ceil(cost*(ok and tonumber(multiplier) or 1))
 end
 local function spawnPrice(data)
  local ok,multiplier=pcall(Core.calculate_spawn_cost_multiplier,U.session)
  return math.ceil((tonumber(data.cost) or math.huge)*(ok and tonumber(multiplier) or 1))
 end
 local function playPlan()
  local p=plan()
  if not p or type(p.Steps)~='table' or #p.Steps==0 then a.Status='Select a non-empty saved plan' return end
  if p.Level~=levelId() then a.Status='Waiting for plan map • '..tostring(p.Level) return end
  local step=p.Steps[a.Index]
  if not step then a.Completed=true a.Save() a.Status='Plan completed' return end
  if step.Action=='Sell'and not a.CanAutoSell(step.UnitId)then a.Index+=1;a.Save();a.Status='Skipped protected farm / buff sale';return end
  if step.Confirming then a.Status='Save the plan before playing' return end
  if wave()<(tonumber(step.Wave) or 0) then a.Status='Waiting for wave '..step.Wave return end
  local t=matchTower(step,towers())
  if step.Action=='Place' and t then a.Index+=1 return end
  if step.Action=='Sell' and not t then a.Index+=1 return end
  if step.Action=='Upgrade' and t and t.Upgrade>=step.Target then a.Index+=1 return end
  if step.Action~='Place' and not t then a.Status='Step '..a.Index..' • target missing; check step order' return end
  local unit=Units[step.UnitId]
  if step.Action=='Place' then
   local available=false for _,u in ipairs(equipped()) do if u.UUID==step.UUID then available=true break end end
   if not available then a.Status='Equip the plan unit before playing • '..tostring(step.UnitId) return end
  end
  local cost=step.Action=='Place' and unit and spawnPrice(unit) or step.Action=='Upgrade' and price(t, t.Upgrade+1) or 0
  if not cost then a.Status='Unit / upgrade unavailable' return end
  if cash()<cost then a.Status='Step '..a.Index..' • waiting for cash' return end
  local single=table.clone(step)
  if step.Action=='Upgrade' then single.Target=t.Upgrade+1 end
  send(single,t and t.Unit,'plan')
  if step.Action=='Upgrade' and single.Target<step.Target and a.Pending then a.Pending.Kind='plan-partial' end
 end
 -- Placement follows actual enemy lane distance, then searches valid native ground nearby.
 function a.PathPoint(percent)
  local bases=workspace:FindFirstChild('_BASES') local pve=bases and bases:FindFirstChild('pve')
  local lanes=pve and pve:FindFirstChild('LANES') local lane=lanes and lanes:FindFirstChild('1')
  if not lane then return end
  local points={} local start=lane:FindFirstChild('spawn') local finish=lane:FindFirstChild('final')
  if not start or not finish then return end points[1]=start.Position
  local sorted={} for _,v in ipairs(lane:GetChildren()) do if v:IsA('BasePart') and tonumber(v.Name) then sorted[#sorted+1]=v end end
  table.sort(sorted,function(x,y) return tonumber(x.Name)<tonumber(y.Name) end)
  for _,v in ipairs(sorted) do points[#points+1]=v.Position end points[#points+1]=finish.Position
  local length=0 for i=2,#points do length+=(points[i]-points[i-1]).Magnitude end
  local remaining=length*math.clamp(percent,0,100)/100
  for i=2,#points do local distance=(points[i]-points[i-1]).Magnitude
   if remaining<=distance then return points[i-1]:Lerp(points[i],distance>0 and remaining/distance or 0) end remaining-=distance
  end return finish.Position
 end
 function a.FindPosition(unit,all)
  local placementSnapshot=a.PlacementSnapshot and a.PlacementSnapshot(unit,all)
  local anchor=a.PathPoint(C.Path) if not anchor then return nil,'Enemy path unavailable on this map' end
  if type(Loader.LevelData)=='table'and Loader.LevelData.id=='summer2_event'and placementSnapshot then
   -- Search the gaps in the formation, rather than only points on twelve rays.
   for ring=0,8 do for x=-ring,ring do for z=-ring,ring do if math.max(math.abs(x),math.abs(z))==ring then
    local hit=Placement.raycast(anchor+Vector3.new(x*4,80,z*4),Vector3.new(0,-180,0))
    if hit and Placement.is_valid_raycast_hit(hit.Instance,unit.Data)then
     local position=hit.Position;local key=string.format('%s:%.1f:%.1f',unit.Id,position.X,position.Z)
     if(not rejected[key]or os.clock()-rejected[key]>=60)and a.PlacementIsClear(position,placementSnapshot)then return CFrame.new(position),key end
    end
   end end end end
  end
  for ring=1,10 do for angle=0,11 do
   local theta=angle*math.pi/6 local offset=Vector3.new(math.cos(theta)*ring*4,0,math.sin(theta)*ring*4)
   local hit=Placement.raycast(anchor+offset+Vector3.new(0,80,0),Vector3.new(0,-180,0))
   if hit and Placement.is_valid_raycast_hit(hit.Instance,unit.Data) then
    local position=hit.Position local clear=true
    local key=string.format('%s:%.1f:%.1f',unit.Id,position.X,position.Z)
    if rejected[key] and os.clock()-rejected[key]<60 then clear=false end
    for _,t in ipairs(all) do if (flat(t.CF.Position)-flat(position)).Magnitude<4.5 then clear=false break end end
    if clear and placementSnapshot and not a.PlacementIsClear(position,placementSnapshot)then clear=false end
    if clear and a.BuffPositionAllowed then clear=a.BuffPositionAllowed(unit.Id,position,all)end
    if clear then return CFrame.new(position),key end
   end
  end end
  return nil,'No free placement found near selected path point'
 end
 local function autoPlace()
  if os.clock()<nextRequest and a.LastPlacementIssue then a.Status=a.LastPlacementIssue return end
  local all=towers() local list=equipped() local hasAttacker=false
  for _,t in ipairs(all) do if not farm(t.Id) and not (Units[t.Id] and Units[t.Id]._show_as_buff_unit) then hasAttacker=true end end
  if C.FarmsFirst and C.Upgrade and hasAttacker and not a.BalancedUpgrade then
   for _,t in ipairs(all) do if farm(t.Id) and price(t,t.Upgrade+1) then a.Status='Upgrade Farms First • saving for farms' return end end
  end
  table.sort(list,function(x,y)
   local function rank(u) if C.FarmsFirst then if not hasAttacker and not farm(u.Id) and not u.Data._show_as_buff_unit then return 0 elseif farm(u.Id) then return 1 end end return 2 end
   local rx,ry=rank(x),rank(y) if rx~=ry then return rx<ry end if a.TeamPolicy then local px,py=a.TeamPolicy.Get(x.Id).Priority,a.TeamPolicy.Get(y.Id).Priority;if px~=py then return px<py end end return x.Slot<y.Slot
  end)
  for _,u in ipairs(list) do
   local count=0 for _,t in ipairs(all) do if t.Id==u.Id then count+=1 end end
   local reserved=a.RecoveryReservations and a.RecoveryReservations(u.Id) or 0
   count+=reserved
   local cap=a.PlacementCap and a.PlacementCap(u.Id,u.Data)or tonumber(u.Data.spawn_cap)or 1
   if a.TeamPolicy then local p=a.TeamPolicy.Get(u.Id);cap=p.Place and math.min(cap,p.MaxPlaced)or 0 end
   if a.IsLimitedBuff(u.Id)then cap=math.min(cap,4)end
   local global=0 local folder=workspace:FindFirstChild('_UNITS')
   if folder then for _,model in ipairs(folder:GetChildren()) do local s=model:FindFirstChild('_stats') if val(s,'id')==u.Id and not val(s,'parent_unit') then global+=1 end end end
   local globalCap=tonumber(u.Data.global_spawn_cap) or math.huge
   if not (a.FarmClosing and farm(u.Id)) and count<cap and global+reserved<globalCap and cash()-(a.RecoveryReserveCash or 0)>=spawnPrice(u.Data) then
    local cf,key=a.FindPosition(u,all)
    if cf then
     local step={Action='Place',UUID=u.UUID,UnitId=u.Id,CF=cfData(cf)}
     send(step,nil,'auto')
     if a.Pending then a.Pending.PlacementKey=key end
     return
    else a.Status=key end
   end
  end
 end
 local function autoUpgrade()
  a.InvestmentReserve=nil
  local all=towers() local candidates={} local farmsRemain=false
  for _,t in ipairs(all) do if not (a.FarmClosing and farm(t.Id)) and a.CanUpgrade(t.Unit) and price(t,t.Upgrade+1) then candidates[#candidates+1]=t if farm(t.Id) then farmsRemain=true end end end
  table.sort(candidates,function(x,y) if a.TeamPolicy then local px,py=a.TeamPolicy.Get(x.Id).Priority,a.TeamPolicy.Get(y.Id).Priority;if px~=py then return px<py end end return price(x,x.Upgrade+1)<price(y,y.Upgrade+1) end)
  for _,t in ipairs(candidates) do if not C.FarmsFirst or not farmsRemain or farm(t.Id) then
   local cost=price(t,t.Upgrade+1)
   if cash()-(a.RecoveryReserveCash or 0)>=cost then send({Action='Upgrade',UUID=t.UUID,UnitId=t.Id,CF=cfData(t.CF),Target=t.Upgrade+1},t.Unit,'auto') return end
  end end
 end
 local abilityPending=setmetatable({},{__mode='k'})
 local function autoAbilities()
  local eligible=0
  for _,t in ipairs(towers()) do
   local active=val(t.Stats,'active_attack') local d=Units[t.Id]
   if active and active~='nil' and Attacks[active] and(not a.TeamPolicy or a.TeamPolicy.AllowsSkill(t.Id))and not (d and d._show_as_buff_unit) and not t.Unit:GetAttribute('_auto_active') then
    eligible+=1
    local last=val(t.Stats,'last_active_cast') local pending=abilityPending[t.Unit]
    if pending and (last~=pending.Last or os.clock()-pending.Time>65) then abilityPending[t.Unit]=nil pending=nil end
    local _,ready=Replication.get_current_active_attack_cooldown(t.Unit)
    if ready and not pending then
     abilityPending[t.Unit]={Last=last,Time=os.clock()}
     a.Status='Using ability • '..tostring(d and d.name or t.Id)
     task.spawn(request,'use_active_attack',t.Unit)
     return
    end
   end
  end
  if eligible==0 and not C.Place and not C.Upgrade then a.Status='No active skills • support buffs are in Main' end
 end
 local walkBusy=false local lastWalk=-math.huge local walkLastInput=os.clock()
 local function walk()
  local anti=env.FyrelithAntiAFK local lastInput=anti and anti.LastInput or walkLastInput
  if walkBusy or os.clock()-lastInput<90 or os.clock()-lastWalk<90 then return end
  local char=player.Character local humanoid=char and char:FindFirstChildOfClass('Humanoid') local hrp=char and char:FindFirstChild('HumanoidRootPart')
  if not humanoid or not hrp or humanoid.Health<=0 or humanoid.Sit or hrp.Anchored then return end
  local origin=hrp.Position local target=origin+hrp.CFrame.RightVector
  local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances={char,workspace:FindFirstChild('_UNITS') or char}
  local floor=workspace:Raycast(target+Vector3.new(0,1,0),Vector3.new(0,-7,0),params)
  if not floor or floor.Normal.Y<.7 or workspace:Raycast(origin,target-origin,params) then return end
  walkBusy=true lastWalk=os.clock()
  a.WalkCount=(a.WalkCount or 0)+1 a.LastWalkOrigin=origin
  task.spawn(function()
   local ok,err=pcall(function()
    humanoid:MoveTo(target) task.wait(.35)
    local currentInput=anti and anti.LastInput or walkLastInput
    if a.Alive and C.Walk and currentInput==lastInput and char==player.Character and humanoid.Health>0 then humanoid:MoveTo(origin) end
   end)
   walkBusy=false
   a.LastWalkError=not ok and tostring(err) or nil
  end)
 end
 a.Walk=walk

 -- Smart Play uses a bounded, deterministic placement search; it never changes game stats.
 local smart={LastAnalysis=-math.huge,Reason='Choose an area',Risk=false}
 a.Smart=smart
 local PathService=Loader.load_core_service(script,'PathService')
 function a.GetSmartPaths()
  local result={}
  local cache=PathService and PathService.PATH_CACHE
  if type(cache)=='table' then
   for base,lanes in pairs(cache) do if tostring(base):lower()~='player' and type(lanes)=='table' then
    for id,lane in pairs(lanes) do if type(lane)=='table' and type(lane.points)=='table' then
     local points={} for _,point in ipairs(lane.points) do if typeof(point.position)=='Vector3' then points[#points+1]=point.position end end
     if #points>=2 then result[#result+1]={Id=tostring(id),Base=tostring(base),Points=points,Length=tonumber(lane.total_distance) or 0} end
    end end
   end end
  end
  if #result==0 then
   local bases=workspace:FindFirstChild('_BASES')
   if bases then for _,base in ipairs(bases:GetChildren()) do if base.Name:lower()~='player' then
    local lanes=base:FindFirstChild('LANES')
    if lanes then for _,lane in ipairs(lanes:GetChildren()) do
     local first=lane:FindFirstChild('spawn') local last=lane:FindFirstChild('final')
     if first and last and first:IsA('BasePart') and last:IsA('BasePart') then
      local sorted={} for _,point in ipairs(lane:GetChildren()) do if point:IsA('BasePart') and tonumber(point.Name) then sorted[#sorted+1]=point end end
      table.sort(sorted,function(x,y) return tonumber(x.Name)<tonumber(y.Name) end)
      local points={first.Position} for _,point in ipairs(sorted) do points[#points+1]=point.Position end points[#points+1]=last.Position
      result[#result+1]={Id=lane.Name,Base=base.Name,Points=points}
     end
    end end
   end end end
  end
  table.sort(result,function(x,y) return x.Base..':'..x.Id<y.Base..':'..y.Id end)
  for _,path in ipairs(result) do
   if not path.Length or path.Length<=0 then path.Length=0 for i=2,#path.Points do path.Length+=(path.Points[i]-path.Points[i-1]).Magnitude end end
  end
  return result
 end
 local function pointOnPath(path,percent)
  local points=path and path.Points
  if type(points)~='table' or #points<2 then return end
  -- Use traveled distance around bends, with spawn=0 and our base=100.
  local length=0
  for i=2,#points do length+=(points[i]-points[i-1]).Magnitude end
  local remaining=length*math.clamp(tonumber(percent) or 0,0,100)/100
  for i=2,#points do local distance=(points[i]-points[i-1]).Magnitude
   if remaining<=distance then return points[i-1]:Lerp(points[i],distance>0 and remaining/distance or 0) end
   remaining-=distance
  end
  return points[#points]
 end
 a.PointOnPath=pointOnPath
 local oldPathPoint=a.PathPoint
 function a.PathPoint(percent,laneIndex)
  local paths=a.GetSmartPaths() local path=paths[laneIndex or 1]
  return path and pointOnPath(path,percent) or oldPathPoint(percent)
 end
 local function areaKey()
  local level=Loader.LevelData
  local map=type(level)=='table' and level.map or levelId()
  local signature=''
  for _,path in ipairs(a.GetSmartPaths()) do
   signature..='|'..path.Base..':'..path.Id
   for _,point in ipairs(path.Points) do signature..=string.format(':%.0f,%.0f,%.0f',point.X,point.Y,point.Z) end
  end
  return tostring(map)..signature
 end
 local function savedCircleList()
  local v=a.Areas[areaKey()]
  if type(v)~='table' then return {},1 end
  if not v.Circles and type(v.Center)=='table' then v={Circles={{Center=v.Center,Radius=v.Radius}},Selected=1} a.Areas[areaKey()]=v end
  if type(v.Circles)~='table' then return {},1 end
  return v.Circles,math.clamp(tonumber(v.Selected) or 1,1,math.max(1,#v.Circles))
 end
 -- TWO_LANE_CENTER_V1
 a.FindTwoLaneCenter=(function()
-- Find a real crossing, not an average floating between two monster paths.
return function(paths,radius)
 if type(paths)~='table'or #paths~=2 then return end
 local p,q=paths[1].Points,paths[2].Points
 if type(p)~='table'or type(q)~='table'or #p<2 or #q<2 then return end
 local function flat(v)return Vector3.new(v.X,0,v.Z)end
 local function cross(a,b)return a.X*b.Z-a.Z*b.X end
 local minimum=Vector3.new(math.huge,0,math.huge);local maximum=-minimum
 for _,list in ipairs({p,q})do for _,v in ipairs(list)do minimum=Vector3.new(math.min(minimum.X,v.X),0,math.min(minimum.Z,v.Z));maximum=Vector3.new(math.max(maximum.X,v.X),0,math.max(maximum.Z,v.Z))end end
 local middle=(minimum+maximum)/2
 local function lengths(list)local sum={0};for i=2,#list do sum[i]=sum[i-1]+(flat(list[i])-flat(list[i-1])).Magnitude end;return sum end
 local lp,lq=lengths(p),lengths(q)
 local ip,iq=#p,#q
 while ip>1 and iq>1 and(flat(p[ip])-flat(q[iq])).Magnitude<1 do ip-=1;iq-=1 end
 local tailP=ip<#p and lp[ip+1]or lp[#p];local tailQ=iq<#q and lq[iq+1]or lq[#q]
 local best,bestScore,bestProgress
 local function offer(point,progressP,progressQ,distance)
  if progressP<.05 or progressQ<.05 or progressP>.92 or progressQ>.92 then return end
  local score=(flat(point)-middle).Magnitude+(distance or 0)*4
  if not bestScore or score<bestScore then best=point;bestScore=score;bestProgress={progressP,progressQ}end
 end
 for i=2,#p do for j=2,#q do
  local a,b,c,d=flat(p[i-1]),flat(p[i]),flat(q[j-1]),flat(q[j]);local r,s=b-a,d-c;local denominator=cross(r,s)
  if math.abs(denominator)>1e-6 then
   local t,u=cross(c-a,s)/denominator,cross(c-a,r)/denominator
   if t>=0 and t<=1 and u>=0 and u<=1 then
    local dp=lp[i-1]+r.Magnitude*t;local dq=lq[j-1]+s.Magnitude*u
    local y1=p[i-1].Y+(p[i].Y-p[i-1].Y)*t;local y2=q[j-1].Y+(q[j].Y-q[j-1].Y)*u
    if dp<tailP-1 and dq<tailQ-1 and math.abs(y1-y2)<3 then local at=a+r*t;offer(Vector3.new(at.X,(y1+y2)/2,at.Z),dp/lp[#p],dq/lq[#q],0)end
   end
  end
 end end
 if best then return best,{Kind='Crossing',Progress=bestProgress}end
 -- Parallel routes can share one circle only when both are close enough.
 local reach=math.max(2,(tonumber(radius)or 12)*.6)
 for i=2,#p do local a,b=p[i-1],p[i];local span=(flat(b)-flat(a)).Magnitude
  local steps=math.max(1,math.ceil(span/2))
  for n=0,steps do local t=n/steps;local point=a:Lerp(b,t);local dp=lp[i-1]+span*t
   if dp<tailP-1 then for j=2,#q do local c,d=q[j-1],q[j];local segment=flat(d)-flat(c);local size=segment:Dot(segment)
    local u=size>0 and math.clamp((flat(point)-flat(c)):Dot(segment)/size,0,1)or 0
    local other=c:Lerp(d,u);local distance=(flat(point)-flat(other)).Magnitude;local dq=lq[j-1]+segment.Magnitude*u
    if distance<=reach and dq<tailQ-1 and math.abs(point.Y-other.Y)<3 then offer(point,dp/lp[#p],dq/lq[#q],distance)end
   end end
  end
 end
 if best then return best,{Kind='Shared coverage',Progress=bestProgress}end
end

end)()
 local function circleList()
  if not C.UsePathPosition then return savedCircleList() end
  local circles={}
  local saved=a.Areas[areaKey()]
  local hidden=type(saved)=='table' and saved.HiddenPaths or {}
  local paths=a.GetSmartPaths()
  if #paths==2 then
   local point=a.FindTwoLaneCenter(paths,C.Radius)
   if point then
    local pathKey='two-lane-center'
    if hidden and hidden[pathKey]then return {},1 end
    return {{Center={point.X,point.Y,point.Z},Radius=C.Radius,PathId='1+2',PathKey=pathKey}},1
   end
  end
  for _,path in ipairs(paths)do
   local point=pointOnPath(path,C.Path)
   local pathKey=tostring(C.Path)..':'..tostring(path.Base)..':'..path.Id
   if point and not (hidden and hidden[pathKey]) then circles[#circles+1]={Center={point.X,point.Y,point.Z},Radius=C.Radius,PathId=path.Id,Percent=C.Path,PathKey=pathKey}end
  end
  return circles,1
 end
 a.GetSmartCircles=circleList
 local function area()
  local circles,index=circleList() local v=circles[index]
  if not v or type(v.Center)~='table' or #v.Center~=3 then return end
  local center=Vector3.new(unpack(v.Center)) local radius=math.clamp(tonumber(v.Radius) or 36,8,80)
  return center,radius
 end
 a.GetSmartArea=area
 function a.SetSmartArea(center,radius,append)
  if typeof(center)~='Vector3' or Loader.IsLobby or #a.GetSmartPaths()==0 then return false end
  radius=math.clamp(tonumber(radius) or 36,8,80)
  local circles,index=savedCircleList()
  C.UsePathPosition=false
  if append==true then if #circles>=8 then a.Status='Maximum 8 circles per map' return false end index=#circles+1 end
  circles[index]={Center={center.X,center.Y,center.Z},Radius=radius}
  a.Areas[areaKey()]={Circles=circles,Selected=index}
  C.Radius=radius smart.LastAnalysis=-math.huge smart.Candidates=nil
  return a.Save()
 end
(function()

 panel('SmartPlayCard',462,398,452,'Smart Play')
 paints[#paints+1]=switch('Play_Smart','Smart Play','',442,function() return C.Smart end,function(v)
  if v and not area() and not (C.UsePathPosition and Loader.IsLobby) then a.Status='Waiting for map paths / choose a custom circle' return end
  if v and a.Capture then a.PrepareManualPlay()end
  if v and not C.Smart then
   a.SmartRestore={Place=C.Place,Upgrade=C.Upgrade,FarmsFirst=C.FarmsFirst,Abilities=C.Abilities,Plan=C.Plan,Buffs={}}
   local buffs=env.FyrelithAutoBuff if buffs then for _,d in ipairs(buffs.Definitions) do a.SmartRestore.Buffs[d.Id]=buffs.Enabled[d.Id]==true end end
   C.Plan=false C.Place=true C.Upgrade=true C.FarmsFirst=true C.Abilities=true
  elseif not v and a.SmartRestore then
   for _,k in ipairs({'Place','Upgrade','FarmsFirst','Abilities','Plan'}) do C[k]=a.SmartRestore[k]==true end
   local buffs=env.FyrelithAutoBuff if buffs then for id,value in pairs(a.SmartRestore.Buffs or {}) do buffs.Enabled[id]=value end buffs.Save() end
   a.SmartRestore=nil
  end
  C.Smart=v smart.LastAnalysis=-math.huge smart.ArmedBuffs=false a.Save()
 end,480)
 root:FindFirstChild('Play_Smart').Parent=page
 toggle('SmartMatch','Auto Start & Replay',480,486)
 label(page,'SmartRadiusLabel','Area Radius • drag to adjust',480,530,320,26,13,true)
 local radiusInput=input('SmartRadius',tostring(C.Radius),814,528,68)
 local radiusTrack=new('TextButton',{Name='SmartRadiusSlider',Text='',Position=UDim2.fromOffset(480,568),Size=UDim2.fromOffset(402,6),BackgroundColor3=colors.line,BorderSizePixel=0,AutoButtonColor=false},page) round(radiusTrack,4)
 local radiusFill=new('Frame',{Size=UDim2.fromScale((C.Radius-8)/72,1),BackgroundColor3=colors.accent,BorderSizePixel=0},radiusTrack) round(radiusFill,4) bind(radiusFill,'BackgroundColor3','accent')
 local radiusKnob=new('Frame',{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale((C.Radius-8)/72,.5),Size=UDim2.fromOffset(15,15),BackgroundColor3=white,BorderSizePixel=0},radiusTrack) round(radiusKnob,8)
 local previewModel local rings={} local selectionHUD local selectionInput local selectionFrame
 local selectionCenter local adding=false local restoreBlack=false local priorRadius local locked=false
 local radiusDragging=false local hudDragging=false local hudTrack local hudFill local hudKnob local hudRadius local hudInstruction
 local radiusDragInput local hudDragInput
 local saveToken=0 local previewToken=0
 local compactHUD=false
 function a.GetAreaPickerLayout(viewport,touch,inset)
  local compact=touch or viewport.X<760 or viewport.Y<500
  local margin=compact and 8 or 12
  local available=math.max(1,viewport.X-margin*2)
  return {Compact=compact,Width=math.min(available,compact and math.clamp(viewport.X*.48,240,340) or 480),Height=compact and 104 or 148,Top=math.max(margin,(inset and inset.Y or 0)+margin)}
 end
 a.PreviewStats={Created=0,Updates=0,Raycasts=0,Animated=0}
 function a.GetAreaVisualQuality(viewport,touch)
  local compact=touch==true or viewport.X<760 or viewport.Y<500
  return {Name=compact and 'Compact'or 'Full',Compact=compact,Segments=compact and 64 or 96,Ticks=compact and 16 or 24,Trail=compact and 3 or 7,FPS=compact and 30 or 60}
 end
 local function visualQuality()
  local camera=workspace.CurrentCamera
  return a.GetAreaVisualQuality(camera and camera.ViewportSize or Vector2.new(1280,720),UIS.TouchEnabled)
 end
 local function clearPreview()
  if previewModel then previewModel:Destroy();previewModel=nil end;rings={}
 end
 local function part(model,name,color,alpha,neon)
  local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=neon and Enum.Material.Neon or Enum.Material.SmoothPlastic;p.Color=color;p.Transparency=alpha;p.Parent=model
  a.PreviewStats.Created+=1;return p
 end
 local function line(p,from,to,width,height)
  p.Size=Vector3.new(width,height or .065,math.max(.005,(to-from).Magnitude));p.CFrame=CFrame.lookAt((from+to)/2,to)
 end
 local function radial(center,radius,theta,y)
  return center+Vector3.new(math.cos(theta)*radius,y or .24,math.sin(theta)*radius)
 end
 local function buildRing(key,quality)
  local model=Instance.new('Model');model.Name='EclipseGateArea'..key;model:SetAttribute('AreaIndex',key);model:SetAttribute('VisualStyle','Fyrelith Eclipse Crown');model.Parent=previewModel
  local tint=colors.accent
  local ring={Model=model,Quality=quality,Boundary={},Shadow={},Ticks={},Etching={},CenterLines={},Trail={},ProjectedTicks={},ProjectedTrail={}}
  ring.Pin=part(model,'AreaCenter',tint,1,false);ring.Pin.Size=Vector3.new(.1,.1,.1)
  ring.Plane=part(model,'EclipseProjection',tint,1,false)
  local surface=new('SurfaceGui',{Name='BoundaryProjection',Adornee=ring.Plane,Face=Enum.NormalId.Top,CanvasSize=Vector2.new(1024,1024),SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,AlwaysOnTop=true,LightInfluence=0,MaxDistance=2000},ring.Plane)
  local art=new('Frame',{Name='FyrelithEclipseCrown',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false},surface)
  ring.Astral={Root=art,Strokes={},Tints={},Sparks={},Color=nil,Groups={}}
  local style=ring.Astral
  local function colored(object,property)
   object[property]=tint;style.Tints[#style.Tints+1]={Object=object,Property=property};return object
  end
  local function group(name,speed)
   local f=new('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false},art)
   style.Groups[#style.Groups+1]={Object=f,Speed=speed};return f
  end
  local function circle(parent,name,diameter,width,alpha)
   local f=new('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(diameter,diameter),BackgroundTransparency=1,Active=false},parent);round(f,1024)
   local edge=new('UIStroke',{Thickness=width,Transparency=alpha,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f);colored(edge,'Color');style.Strokes[#style.Strokes+1]=edge
   return f,edge
  end
  local function polar(radius,angle)return Vector2.new(.5+math.cos(angle)*radius,.5+math.sin(angle)*radius)end
  local function stroke(parent,name,from,to,width,alpha)
   local delta=to-from
   local f=new('Frame',{Name=name,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale((from.X+to.X)/2,(from.Y+to.Y)/2),Size=UDim2.fromOffset(math.max(.5,delta.Magnitude*1024),width),Rotation=math.deg(math.atan2(delta.Y,delta.X)),BackgroundTransparency=alpha or .2,BorderSizePixel=0,Active=false},parent);colored(f,'BackgroundColor3');round(f,2);return f
  end
  local _,edge=circle(art,'TruePlacementBoundary',1,1.8,.18);ring.ProjectedEdge=edge
  local _,shadow=circle(art,'BoundaryContrast',1,4,.64);shadow.Color=Color3.fromRGB(8,12,19);style.Tints[#style.Tints]=nil;ring.ProjectedShadow=shadow
  circle(art,'InnerSeal',.805,2.2,.18)
  circle(art,'InnerEcho',.772,1.5,.35)
  model.Name='AstralSigilArea'..key;model:SetAttribute('VisualStyle','Fyrelith Astral Sigil');art.Name='FyrelithAstralSigil'
  ring.ProjectedEdge.Thickness=6.5;ring.ProjectedEdge.Transparency=0
  ring.ProjectedEdge.Parent.ZIndex=5;ring.ProjectedShadow.Parent.ZIndex=1
  circle(art,'BoundaryAura',.996,15,.55)
  circle(art,'SigilInnerRing',.82,4,.04)
  circle(art,'SigilInnerHairline',.73,3,.16)
  local ticks=group('AstralSurveyMarks',3.15)
  local runes=group('CounterRotatingRunes',-4)
  local seal=group('TwinTriangleSeal',2)
  local orbit=group('ThreeOrbitComets',24)
  local count=quality.Compact and 32 or 64
  for i=0,count-1 do
   local a=i*math.pi*2/count
   stroke(ticks,'BoundaryMark',polar(i%4==0 and .472 or .483,a),polar(.495,a),i%4==0 and 4.5 or 3.2,.04)
  end
  local runeCount=quality.Compact and 16 or 24
  for i=0,runeCount-1 do
   local a=i*math.pi*2/runeCount
   local function rp(x,y)
    local anchor=polar(.449,a)
    return anchor+Vector2.new(math.cos(a)*y-math.sin(a)*x,math.sin(a)*y+math.cos(a)*x)
   end
   stroke(runes,'AstralRune',rp(-.005,-.009),rp(-.005,.009),4,.02)
   stroke(runes,'AstralRune',rp(-.005,-.009),rp(.005,i%2==0 and .002 or -.003),4,.02)
   stroke(runes,'AstralRune',rp(-.005,0),rp(.006,.008),4,.02)
   if i%3==0 then stroke(runes,'RuneFoot',rp(-.008,-.011),rp(.008,-.011),2.6,.16)end
  end
  for triangle=0,1 do for i=0,2 do
   local a=i*math.pi*2/3+triangle*math.pi
   stroke(seal,'SixPointSeal',polar(.345,a),polar(.345,a+math.pi*2/3),2.5,.36)
  end end
  for i=0,7 do
   local a=i*math.pi/4;local p=polar(.365,a);local d=.006
   stroke(seal,'SealDiamond',p+Vector2.new(0,-d),p+Vector2.new(d*.65,0),2.8,.12)
   stroke(seal,'SealDiamond',p+Vector2.new(d*.65,0),p+Vector2.new(0,d),2.8,.12)
   stroke(seal,'SealDiamond',p+Vector2.new(0,d),p+Vector2.new(-d*.65,0),2.8,.12)
   stroke(seal,'SealDiamond',p+Vector2.new(-d*.65,0),p+Vector2.new(0,-d),2.8,.12)
  end
  for i=0,2 do
   local a=i*math.pi*2/3
   for j=0,10 do stroke(orbit,'OrbitCometArc',polar(.49,a+j*.023),polar(.49,a+(j+1)*.023),4.5,.04+j*.035)end
   local p=polar(.49,a)
   stroke(orbit,'CometFlare',p+Vector2.new(-.009,0),p+Vector2.new(.009,0),3,.02)
   stroke(orbit,'CometFlare',p+Vector2.new(0,-.012),p+Vector2.new(0,.012),3,.02)
  end


  style.PulseFrame,style.Pulse=circle(art,'EclipseWave',.81,1.2,.85)
  ring.Aperture,ring.ApertureEdge=circle(art,'CenterCompass',.047,1.2,.42)
  ring.ApertureGradient=new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.4,1),NumberSequenceKeypoint.new(.6,1),NumberSequenceKeypoint.new(1,.1)}),Rotation=45},ring.ApertureEdge)
  for i=0,3 do
   local a=i*math.pi/2
   stroke(art,'CompassPoint',polar(.027,a),polar(.035,a),1.5,.36)
  end
  for i=1,(quality.Compact and 4 or 7)do
   local dot=new('Frame',{Name='EclipseStar',AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(i<=2 and 6 or 3,i<=2 and 6 or 3),Rotation=45,BorderSizePixel=0,Active=false,ZIndex=6},art);colored(dot,'BackgroundColor3')
   local halo=new('ImageLabel',{Name='StarGlow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(i<=2 and 30 or 17,i<=2 and 30 or 17),BackgroundTransparency=1,Image='rbxassetid://6772783963',ImageTransparency=.74,Active=false,ZIndex=5},dot);colored(halo,'ImageColor3')
   style.Sparks[i]={Object=dot,Halo=halo,Phase=i*2.399,Speed=i%2==0 and -.12 or .15,Radius=i<=2 and .482 or .416}
  end
  ring.CometHalo=new('Frame',{Name='UnusedComet',Visible=false,BackgroundTransparency=1},art)
  local highlight=Instance.new('Highlight');highlight.Name='EclipseVisibility';highlight.Adornee=model;highlight.FillTransparency=1;highlight.OutlineTransparency=1;highlight.Enabled=false;highlight.Parent=model;ring.Highlight=highlight
  local badge=new('BillboardGui',{Name='CircleNumber',Adornee=ring.Pin,AlwaysOnTop=true,Size=UDim2.fromOffset(quality.Compact and 126 or 150,40),StudsOffsetWorldSpace=Vector3.new(0,2,0),MaxDistance=2000},ring.Pin)
  local plate=new('Frame',{Name='EclipseBadge',Size=UDim2.fromScale(1,1),BackgroundColor3=colors.card,BackgroundTransparency=.08,BorderSizePixel=0,Active=false},badge);round(plate,10);style.Badge=plate
  local outline=new('UIStroke',{Thickness=1,Transparency=.45,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},plate);colored(outline,'Color')
  ring.Symbol=new('Frame',{Name='Symbol',Position=UDim2.fromOffset(13,14),Size=UDim2.fromOffset(10,10),Rotation=45,BackgroundTransparency=.75,BorderSizePixel=0},plate);colored(ring.Symbol,'BackgroundColor3')
  local symbolEdge=new('UIStroke',{Thickness=1,Transparency=.2},ring.Symbol);colored(symbolEdge,'Color')
  ring.Text=new('TextLabel',{Name='AreaTitle',Text=string.format('ASTRAL %02d',key),Position=UDim2.fromOffset(34,3),Size=UDim2.new(1,-40,0,18),BackgroundTransparency=1,TextColor3=white,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},plate)
  ring.RadiusText=new('TextLabel',{Name='Radius',Text='',Position=UDim2.fromOffset(34,21),Size=UDim2.new(1,-40,0,15),BackgroundTransparency=1,TextColor3=muted,TextSize=10,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left},plate)
  return ring
 end

 local function placeTrail(ring,phase)
  local count=#ring.Trail
  for i,p in ipairs(ring.Trail)do
   local theta=phase-(i-1)*.032
   line(p,radial(ring.Center,ring.Radius,theta,.31),radial(ring.Center,ring.Radius,theta+.025,.31),i==1 and .12 or .085,.07)
   p.Color=ring.Color:Lerp(Color3.new(1,1,1),i==1 and .55 or .2)
   p.Transparency=ring.Selected and(.16+(i-1)/math.max(1,count)*.72)or 1
   local dot=ring.ProjectedTrail[i];dot.Position=UDim2.fromScale(.5+math.cos(theta)*.5,.5+math.sin(theta)*.5);dot.Visible=ring.Selected
   if i==1 then ring.CometHalo.Position=dot.Position;ring.CometHalo.Visible=ring.Selected end
  end
 end
 local function animateAstral(ring,time)
  local art=ring.Astral;if not art then return end
  local tint=ring.Color or colors.accent
  if art.Color~=tint then
   art.Color=tint
   for _,entry in ipairs(art.Tints)do entry.Object[entry.Property]=tint end
   art.Badge.BackgroundColor3=colors.card
  end
  local moving=motionEnabled();local clock=moving and time or 0
  for _,group in ipairs(art.Groups)do group.Object.Rotation=(clock*group.Speed)%360 end
  if art.Texture then art.Texture.ImageTransparency=ring.Selected and .04 or .28;art.TextureEcho.ImageTransparency=ring.Selected and .76 or .9;art.Sweep.Rotation=(clock*23)%360 end
  local phase=(clock*.18)%1
  art.PulseFrame.Size=UDim2.fromScale(.81+phase*.15,.81+phase*.15)
  art.Pulse.Transparency=ring.Selected and(.72+phase*.28)or .95
  for _,spark in ipairs(art.Sparks)do
   local theta=clock*spark.Speed+spark.Phase
   spark.Object.Position=UDim2.fromScale(.5+math.cos(theta)*spark.Radius,.5+math.sin(theta)*spark.Radius)
   spark.Object.BackgroundTransparency=ring.Selected and(.18+.14*(1+math.sin(clock*1.3+spark.Phase)))or .72
   spark.Halo.ImageTransparency=ring.Selected and .72 or .94
  end
  ring.Pin.Transparency=1;ring.Highlight.Enabled=false
 end

 local function drawCircle(center,radius)
  if not C.Smart and not a.SelectingArea then clearPreview() return end
  local quality=visualQuality()
  if not previewModel then previewModel=Instance.new('Model');previewModel.Name='FyrelithSmartArea';previewModel.Parent=workspace end
  local circles,index=circleList();local draw={}
  for i,v in ipairs(circles)do if not a.SelectingArea or adding or i~=index then draw[#draw+1]={Center=Vector3.new(unpack(v.Center)),Radius=v.Radius,Index=i,Selected=i==index and not adding}end end
  if a.SelectingArea and center then draw[#draw+1]={Center=center,Radius=radius,Index=adding and #circles+1 or index,Selected=true}end
  local used={}
  for _,v in ipairs(draw)do
   local key=v.Index;used[key]=true;local ring=rings[key]
   if ring and ring.Quality.Name~=quality.Name then ring.Model:Destroy();rings[key]=nil;ring=nil end
   if not ring then ring=buildRing(key,quality);rings[key]=ring end
   local tint=colors.accent:Lerp(Color3.new(1,1,1),v.Selected and .18 or .05)
   if ring.Center~=v.Center or ring.Radius~=v.Radius or ring.Color~=tint or ring.Selected~=v.Selected then
    ring.Center=v.Center;ring.Radius=math.clamp(tonumber(v.Radius)or 36,8,80);ring.Color=tint;ring.Selected=v.Selected
    local r=ring.Radius;local n=quality.Segments
    for i,p in ipairs(ring.Boundary)do
     local theta=(i-1)*math.pi*2/n;local nextTheta=i*math.pi*2/n
     p.Color=tint:Lerp(Color3.fromRGB(222,213,255),.14+.12*math.sin(theta));p.Transparency=v.Selected and .33 or .65
     line(p,radial(v.Center,r,theta),radial(v.Center,r,nextTheta),quality.Compact and .09 or .075)
     local shadow=ring.Shadow[i];if shadow then line(shadow,radial(v.Center,r,theta,.22),radial(v.Center,r,nextTheta,.22),.25,.045)end
    end
    for i,p in ipairs(ring.Ticks)do
     local theta=(i-1)*math.pi*2/#ring.Ticks;local major=(i-1)%(#ring.Ticks/4)==0
     line(p,radial(v.Center,r-.15,theta,.28),radial(v.Center,r-(major and 1.6 or .65),theta,.28),major and .12 or .065)
     p.Color=major and tint:Lerp(Color3.new(1,1,1),.3)or tint;p.Transparency=v.Selected and(major and .25 or .58)or .78
    end
    for i,p in ipairs(ring.Etching)do
     local theta=(i-1)*math.pi/6;local length=math.pi/36
     line(p,radial(v.Center,r*.935,theta),radial(v.Center,r*.935,theta+length),.045,.04);p.Color=tint;p.Transparency=v.Selected and .78 or .92
    end
    for i,p in ipairs(ring.CenterLines)do
     local theta=(i-1)*math.pi/6;line(p,radial(v.Center,1.15,theta,.3),radial(v.Center,1.15,theta+math.pi/14,.3),.08,.065);p.Color=tint
    end
    ring.Plane.Size=Vector3.new(r*2,.025,r*2);ring.Plane.CFrame=CFrame.new(v.Center+Vector3.new(0,.27,0))
    ring.ProjectedEdge.Color=tint;ring.ProjectedEdge.Transparency=v.Selected and 0 or .14;ring.ProjectedShadow.Transparency=v.Selected and .28 or .65
    ring.Aperture:FindFirstChildOfClass('UIStroke').Color=tint;ring.CometHalo.BackgroundColor3=tint
    for _,marker in ipairs(ring.Aperture:GetChildren())do if marker:IsA('Frame')then marker.BackgroundColor3=tint end end
    for _,dot in ipairs(ring.ProjectedTrail)do dot.BackgroundColor3=tint:Lerp(Color3.new(1,1,1),.4)end
    for _,tickMark in ipairs(ring.ProjectedTicks)do tickMark.BackgroundColor3=tint;tickMark.BackgroundTransparency=v.Selected and .3 or .76 end
    ring.Pin.Position=v.Center+Vector3.new(0,.32,0);ring.Symbol.BackgroundColor3=tint;ring.Symbol:FindFirstChildOfClass('UIStroke').Color=tint;ring.RadiusText.Text='RADIUS  '..tostring(math.floor(r+.5))
    ring.Highlight.FillColor=tint;ring.Highlight.Enabled=v.Selected
    ring.Model:SetAttribute('Radius',r);ring.Model:SetAttribute('Center',v.Center);ring.Model:SetAttribute('Selected',v.Selected)
    placeTrail(ring,0);animateAstral(ring,0);a.PreviewStats.Updates+=1
   end
  end
  for key,ring in pairs(rings)do if not used[key]then ring.Model:Destroy();rings[key]=nil end end
 end
 a.DrawSmartPreview=drawCircle
 local visualTime=0;local visualTick=0
 connect(game:GetService('RunService').RenderStepped,function(dt)
  if not a.Alive or not api.Alive or not previewModel or not motionEnabled()then return end
  local black=env.FyrelithBlackScreen;if black and(black.Enabled or black.RenderingOff)then return end
  local quality=visualQuality();visualTick+=dt;if quality.Compact and visualTick<1/quality.FPS then return end
  visualTime+=math.min(visualTick,.12);visualTick=0
  for _,ring in pairs(rings)do if ring.Model.Parent then animateAstral(ring,visualTime);if ring.Selected then placeTrail(ring,visualTime*.28);ring.Pin.Transparency=1;ring.ApertureGradient.Rotation=45+visualTime*16 end;a.PreviewStats.Animated+=1 end end
 end)

 local function paintRadius()
  local alpha=(C.Radius-8)/72 radiusInput.Text=tostring(C.Radius)
  radiusFill.Size=UDim2.fromScale(alpha,1) radiusKnob.Position=UDim2.fromScale(alpha,.5)
  if hudTrack then hudFill.Size=UDim2.fromScale(alpha,1) hudKnob.Position=UDim2.fromScale(alpha,.5) hudRadius.Text='Radius '..C.Radius..' • drag to resize' end
 end
 local function setRadius(value,commit)
  C.Radius=math.clamp(math.floor((tonumber(value) or 36)+.5),8,80) paintRadius()
  if a.SelectingArea then if selectionCenter then drawCircle(selectionCenter,C.Radius) end return end
  local circles,index=circleList()
  if circles[index] then
   circles[index].Radius=C.Radius smart.LastAnalysis=-math.huge
   local black=env.FyrelithBlackScreen
   if not (black and black.Enabled) then
    drawCircle(area(),C.Radius) previewToken+=1 local token=previewToken
    task.delay(3,function() if token==previewToken and not C.ShowAreas and not a.SelectingArea and not a.EditingRadius then clearPreview() end end)
   end
  end
  if commit then a.Save() else
   saveToken+=1 local token=saveToken
   task.delay(.3,function() if a.Alive and token==saveToken and not a.SelectingArea and not radiusDragging then a.Save() end end)
  end
 end
 a.SetSmartRadius=setRadius
 radiusInput.TextEditable=false radiusInput.Active=false
 local function dragRadius(track,x) setRadius(8+math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)*72,false) end
 connect(radiusTrack.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then radiusDragging=true radiusDragInput=i a.EditingRadius=true dragRadius(radiusTrack,i.Position.X) end end)
 connect(UIS.InputChanged,function(i)
  if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
   if radiusDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i==radiusDragInput) then dragRadius(radiusTrack,i.Position.X)
   elseif hudDragging and hudTrack and (i.UserInputType==Enum.UserInputType.MouseMovement or i==hudDragInput) then dragRadius(hudTrack,i.Position.X) end
  end
 end)
 connect(UIS.InputEnded,function(i)
  if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
   if radiusDragging and (i.UserInputType==Enum.UserInputType.MouseButton1 or i==radiusDragInput) then radiusDragging=false radiusDragInput=nil a.EditingRadius=false a.Save() end
   if i.UserInputType==Enum.UserInputType.MouseButton1 or i==hudDragInput then hudDragging=false hudDragInput=nil end
  end
 end)
 local circlePicker=playPicker('Selected Circle',480,590,function()
  local choices={} for i,v in ipairs(circleList()) do choices[#choices+1]={id=i,name='Circle '..i..' • radius '..tostring(v.Radius)} end return choices
 end,function() local _,i=circleList() return i end,function(v)
  local entry=a.Areas[areaKey()] if entry then entry.Selected=v.id local _,radius=area() C.Radius=radius paintRadius() a.Save() end
 end)
 local areaState=label(page,'SmartAreaStatus','Choose an area inside the current map',480,630,402,34,13,true) areaState.TextWrapped=true
 local insight=label(page,'SmartInsight','Farms: edge • Buffs: 4 each • Damage: path / threats',480,762,402,66,13,true) insight.TextWrapped=true a.SmartInsight=insight
 function a.UpdateSmartUI()
  if not C.Smart and not a.SelectingArea then
   clearPreview()
   circlePicker.Set('Smart Play off')
   areaState.Text='Auto Place uses Path % without circles. Enable Smart Play to use circle areas.'
   if not radiusDragging and not hudDragging then paintRadius() end
   return
  end
  local center=area() local circles,index=circleList()
  circlePicker.Set(#circles>0 and ('Circle '..index..' / '..#circles) or 'No circles')
  areaState.Text=C.UsePathPosition and ('Path '..C.Path..'% • '..(#circles>0 and (#circles..' route(s) • radius '..C.Radius) or 'waiting for map')) or (center and (#circles..' circle(s) saved • '..tostring(type(Loader.LevelData)=='table' and Loader.LevelData._location_name or 'Current map')) or 'Select Circle Area before enabling Smart Play')
  if not radiusDragging and not hudDragging then paintRadius() end
  local show=page:FindFirstChild('PreviewSmartArea') if show then show.Text=C.ShowAreas and 'Hide All Circles' or 'Show All Circles' end
  if not a.SelectingArea and not a.EditingRadius then
   local black=env.FyrelithBlackScreen
   if C.Smart and C.ShowAreas and center and not Loader.IsLobby and not (black and black.Enabled) then drawCircle(center,C.Radius)
   elseif previewModel then clearPreview() end
  end
 end
 function a.WantsMatchControl() return C.Smart and C.SmartMatch and not a.SelectingArea and not a.EditingRadius and not a.Capture and not macroBusy() and area()~=nil end
 local function finishSelection(saveArea)
  if saveArea and selectionCenter then a.SetSmartArea(selectionCenter,C.Radius,adding) elseif priorRadius then C.Radius=priorRadius end
  a.SelectingArea=false a.EditingRadius=false hudDragging=false hudDragInput=nil
  if selectionInput then selectionInput:Disconnect() selectionInput=nil end
  if selectionFrame then selectionFrame:Disconnect() selectionFrame=nil end
  if selectionHUD then selectionHUD:Destroy() selectionHUD=nil end
  hudTrack=nil hudFill=nil hudKnob=nil hudRadius=nil hudInstruction=nil clearPreview() paintRadius()
  if restoreBlack then local black=env.FyrelithBlackScreen if black and black.Alive then black.SetEnabled(true,true) end end restoreBlack=false
  a.Status=saveArea and 'Smart area saved • enable Smart Play when ready' or 'Area selection cancelled'
  if gui.Parent and api.Alive then local setter=gui:FindFirstChild('SetWindowOpen') if setter then setter:Invoke(true) end end
 end
 function a.UpdateAreaPoint(screenPoint)
  if not a.SelectingArea or not workspace.CurrentCamera then return end
  local ray=workspace.CurrentCamera:ScreenPointToRay(screenPoint.X,screenPoint.Y)
  a.PreviewStats.Raycasts+=1
  local hit=Placement.raycast(ray.Origin,ray.Direction*1000)
  if not hit then return false end
  selectionCenter=hit.Position drawCircle(selectionCenter,C.Radius) return true,selectionCenter
 end
 function a.BeginAreaSelection(append)
  if Loader.IsLobby then a.Status='Choose a Smart area inside a match' return false end
  if #a.GetSmartPaths()==0 then a.Status='Waiting for map paths to load' return false end
  if macroBusy()then a.Status='Stop Macro before selecting a Smart area' return false end
  if a.Capture then captureOff();a.Save()end
  if a.SelectingArea then return false end
  local circles=circleList() if append==true and #circles>=8 then a.Status='Maximum 8 circles per map' return false end
  a.SelectingArea=true adding=append==true selectionCenter=not adding and area() or nil priorRadius=C.Radius locked=false
  local black=env.FyrelithBlackScreen restoreBlack=black and black.Enabled or false if restoreBlack then black.SetEnabled(false,true) end
  local setter=gui:FindFirstChild('SetWindowOpen') if setter then setter:Invoke(false) end
  selectionHUD=new('ScreenGui',{Name='FyrelithSmartAreaPicker',IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=2147483647},player.PlayerGui)
  local width=480
  local holder=new('Frame',{Name='AreaPickerPanel',AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,18),Size=UDim2.fromOffset(width,148),BackgroundColor3=colors.card,BackgroundTransparency=.05,BorderSizePixel=0},selectionHUD) round(holder,12) border(holder)
  hudInstruction=label(holder,'Instruction','Move mouse • drag radius slider • click to lock',16,8,width-32,28,14,true)
  hudRadius=label(holder,'Radius','',16,38,width-32,24,13,true)
  hudTrack=new('TextButton',{Name='RadiusSlider',Text='',Position=UDim2.fromOffset(16,68),Size=UDim2.fromOffset(width-32,28),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false},holder)
  local rail=new('Frame',{Name='Rail',Position=UDim2.new(0,0,.5,-3),Size=UDim2.new(1,0,0,6),BackgroundColor3=colors.line,BorderSizePixel=0},hudTrack) round(rail,4)
  hudFill=new('Frame',{Size=UDim2.fromScale(0,1),BackgroundColor3=colors.accent,BorderSizePixel=0},rail) round(hudFill,4)
  hudKnob=new('Frame',{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(18,18),BackgroundColor3=white,BorderSizePixel=0},rail) round(hudKnob,9)
  hudTrack.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hudDragging=true hudDragInput=i dragRadius(hudTrack,i.Position.X) end end)
  local function hudButton(text,x,callback)
   local b=new('TextButton',{Name=text,Text=text,Position=UDim2.fromOffset(x,104),Size=UDim2.fromOffset((width-44)/2,32),BackgroundColor3=colors.field,TextColor3=white,Font=Enum.Font.GothamBold,TextSize=13,BorderSizePixel=0},holder) round(b,8) b.Activated:Connect(callback) return b
  end
  local confirm=hudButton('Confirm',16,function() if selectionCenter then finishSelection(true) end end)
  local cancel=hudButton('Cancel',28+(width-44)/2,function() finishSelection(false) end)
  local lastViewport local lastTouch
  local function layoutHUD()
   local camera=workspace.CurrentCamera if not camera then return end
   local viewport=camera.ViewportSize local touch=UIS.TouchEnabled
   if viewport==lastViewport and touch==lastTouch then return end lastViewport=viewport lastTouch=touch
   local inset=game:GetService('GuiService'):GetGuiInset()
   local layout=a.GetAreaPickerLayout(viewport,touch,inset) compactHUD=layout.Compact width=layout.Width
   holder.Size=UDim2.fromOffset(width,layout.Height) holder.Position=UDim2.new(.5,0,0,layout.Top)
   local pad=compactHUD and 12 or 16
   hudInstruction.Position=UDim2.fromOffset(pad,compactHUD and 4 or 8) hudInstruction.Size=UDim2.fromOffset(width-pad*2,24) hudInstruction.TextSize=compactHUD and 12 or 14
   hudInstruction.Text=locked and 'Position set • Confirm to save' or touch and 'Tap map to set position' or 'Move mouse • click map to lock'
   hudRadius.Position=UDim2.fromOffset(pad,compactHUD and 26 or 38) hudRadius.Size=UDim2.fromOffset(width-pad*2,20) hudRadius.TextSize=compactHUD and 12 or 13
   hudTrack.Position=UDim2.fromOffset(pad,compactHUD and 42 or 68) hudTrack.Size=UDim2.fromOffset(width-pad*2,28)
   local buttonWidth=(width-pad*2-8)/2
   confirm.Position=UDim2.fromOffset(pad,compactHUD and 72 or 104) cancel.Position=UDim2.fromOffset(pad+buttonWidth+8,compactHUD and 72 or 104)
   confirm.Size=UDim2.fromOffset(buttonWidth,compactHUD and 28 or 32) cancel.Size=confirm.Size
  end
  layoutHUD()
  paintRadius() if selectionCenter then drawCircle(selectionCenter,C.Radius) end
  a.AreaInput=function(i,processed)
   if i.KeyCode==Enum.KeyCode.Escape then finishSelection(false) return end
   if processed or (i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch) then return end
   local p=i.UserInputType==Enum.UserInputType.Touch and i.Position or UIS:GetMouseLocation()
   local localP=Vector2.new(p.X,p.Y)-holder.AbsolutePosition
   if localP.X>=0 and localP.Y>=0 and localP.X<=holder.AbsoluteSize.X and localP.Y<=holder.AbsoluteSize.Y then return end
   if a.UpdateAreaPoint(p) then locked=true hudInstruction.Text='Position set • Confirm to save' end
  end
  selectionInput=UIS.InputBegan:Connect(a.AreaInput)
  local lastPointer local lastCamera
  selectionFrame=game:GetService('RunService').RenderStepped:Connect(function()
   if not a.Alive or not api.Alive then finishSelection(false) return end
   layoutHUD()
   if locked or hudDragging then return end
   if UIS.TouchEnabled and UIS:GetLastInputType()==Enum.UserInputType.Touch then return end
   local p=UIS:GetMouseLocation() local camera=workspace.CurrentCamera
   if not camera then return end
   if p==lastPointer and camera.CFrame==lastCamera then return end lastPointer=p lastCamera=camera.CFrame
   local localP=p-holder.AbsolutePosition
   if localP.X>=0 and localP.Y>=0 and localP.X<=holder.AbsoluteSize.X and localP.Y<=holder.AbsoluteSize.Y then return end
   a.UpdateAreaPoint(p)
  end)
  return true
 end
 action('SelectSmartArea','Select / Edit Circle',480,672,194,function() a.BeginAreaSelection(false) end)
 action('PreviewSmartArea','Show All Circles',688,672,194,function()
  a.SetShowSmartAreas(not C.ShowAreas)
 end)
 action('AddSmartCircle','Add Circle',480,716,194,function() a.BeginAreaSelection(true) end)
 local deleteKey local deleteAt=0
 function a.DeleteSmartCircle()
  if a.SelectingArea then a.Status='Finish area selection first' return false end
  local circles,index=circleList()
  if not circles[index] then deleteKey=nil a.Status='No circles to delete' return false end
  local mapKey=areaKey()
  local key=mapKey..':'..(C.UsePathPosition and circles[index].PathKey or ('custom:'..index))
  if deleteKey~=key or os.clock()-deleteAt>3 then deleteKey=key deleteAt=os.clock() a.Status='Press Delete Circle again within 3s to confirm' return end
  if C.UsePathPosition then
   local entry=a.Areas[mapKey] or {Circles={},Selected=1}
   entry.HiddenPaths=entry.HiddenPaths or {}
   entry.HiddenPaths[circles[index].PathKey]=true
   a.Areas[mapKey]=entry
  else
   table.remove(circles,index)
   local entry=a.Areas[mapKey] or {}
   entry.Circles=circles entry.Selected=math.max(1,index-1)
   a.Areas[mapKey]=entry
  end
  deleteKey=nil
  clearPreview() smart.LastAnalysis=-math.huge smart.Context=nil smart.Candidates=nil
  a.Save() a.UpdateSmartUI() a.Status='Circle deleted'
  return true
 end
 action('DeleteSmartCircle','Delete Circle',688,716,194,a.DeleteSmartCircle)
 function a.SetShowSmartAreas(value)
  C.ShowAreas=value==true previewToken+=1
  if not C.ShowAreas and not a.SelectingArea and not a.EditingRadius then clearPreview() end
  a.UpdateSmartUI() a.Save()
 end
 page.CanvasSize=UDim2.fromOffset(0,1134)
 a.CleanupSmart=function()
  saveToken+=1 previewToken+=1 radiusDragging=false a.EditingRadius=false
  if a.SelectingArea then finishSelection(false) else clearPreview() end
 end


end)()



 local function role(id)
  local d=Units[id] or {}
  if farm(id) then return 'farm' end
  if d._show_as_buff_unit or (d.active_attack and tostring(d.active_attack):find('buff')) then return 'buff' end
  if d._NO_ATTACKS_UNIT and (tonumber(d.damage) or 0)==0 then return 'utility' end
  return 'damage'
 end
 a.SmartRole=role
 local function damageType(id) local d=Units[id] or {} return d.base_damage_type or d._base_damage_type or 'physical' end
 local function supportsType(buffId,id)
  if buffId=='erwin' then return damageType(id)=='physical' end
  if buffId=='wendy' then return damageType(id)=='magic' end
  return true
 end
 local function dps(t)
  return math.max(0,tonumber(val(t.Stats,'damage')) or 0)/math.max(.3,tonumber(val(t.Stats,'attack_cooldown')) or 1)
 end
 local function hitsFlying(id,upgrade)
  local data=Units[id] or {} local active=data.primary_attack_no_upgrades or data.primary_attack
  for i=1,upgrade or 0 do local stage=data.upgrade and data.upgrade[i] if stage and stage.primary_attack then active=stage.primary_attack end end
  local attack=active and Attacks[active]
  return attack and attack.targets_flying==true or false
 end
 local function enemyContext()
  local samples={} local progresses={} local sampleRoutes={} local routeSamples={}
  local paths=a.GetSmartPaths()
  for route,path in ipairs(paths) do
   routeSamples[route]={}
   for i=0,48 do local point=pointOnPath(path,i/48*100)
    samples[#samples+1]=point progresses[#samples]=i/48 sampleRoutes[#samples]=route
    routeSamples[route][#routeSamples[route]+1]=point
   end
  end
  if #samples<2 then return {Samples={},Enemies={},Risk=false,Pressure=0} end
  local enemies={} local risk=false local highest=0 local pressure=0 local airRisk=false
  local defenders=a.GetDefenseTowers and a.GetDefenseTowers() or towers()
  -- Measure travel along the lane, not straight-line distance across bends.
  local circles=circleList() local approach={}
  local planningRange=0
  for _,u in ipairs(equipped()) do if role(u.Id)=='damage' then planningRange=math.max(planningRange,tonumber(u.Data.range) or 0) end end
  for route,points in ipairs(routeSamples) do
   for i,p in ipairs(points) do
    local covered=false
    for _,v in ipairs(circles) do if type(v.Center)=='table' and #v.Center==3 then
     if (flat(p)-flat(Vector3.new(unpack(v.Center)))).Magnitude<=math.clamp(tonumber(v.Radius) or 36,8,80)+planningRange then covered=true break end
    end end
    for _,t in ipairs(defenders) do if role(t.Id)=='damage' and (flat(p)-flat(t.CF.Position)).Magnitude<=(tonumber(val(t.Stats,'range')) or 0) then covered=true break end end
    if covered then approach[route]=math.min(approach[route] or 1,(i-1)/48) end
   end
  end
  local defense={} local routeCovered={} local values={} local towerCoverage={}
  for _,t in ipairs(defenders) do if role(t.Id)=='damage' then
   local range=tonumber(val(t.Stats,'range')) or 0
   local coverage={Routes={},Next={},Shared=0,DPS=dps(t)} towerCoverage[t.Unit]=coverage
   for route,points in ipairs(routeSamples) do
    local remaining={} local upcoming={} local nextCovered local count=0
    for i=#points,1,-1 do
     if (flat(points[i])-flat(t.CF.Position)).Magnitude<=range then count+=1;nextCovered=i end
     remaining[i]=count;upcoming[i]=nextCovered
    end
    coverage.Routes[route]=remaining;coverage.Next[route]=upcoming;if count>0 then coverage.Shared+=1 end
   end
  end end
  for _,t in ipairs(defenders) do if role(t.Id)=='damage' and dps(t)>0 then values[#values+1]=dps(t) end end
  table.sort(values) local reference=values[math.max(1,math.ceil(#values/2))] or 1
  for i,p in ipairs(samples) do
   local power=0
   for _,t in ipairs(defenders) do if role(t.Id)=='damage' and (flat(t.CF.Position)-flat(p)).Magnitude<=(tonumber(val(t.Stats,'range')) or 0) then power+=dps(t) end end
   defense[i]=1/(1+power/math.max(1,reference))
   if power>0 then local route=sampleRoutes[i] routeCovered[route]=(routeCovered[route] or 0)+1 end
  end
  local uncovered=0 local weakRoutes={}
  for i in ipairs(paths) do if (routeCovered[i] or 0)<2 then uncovered+=1 weakRoutes[i]=true end end
  for _,model in ipairs(game:GetService('CollectionService'):GetTagged('pve_units')) do
   local s=model:FindFirstChild('_stats') local hp=tonumber(val(s,'health')) or 0
   if model:IsA('Model') and model.Parent and hp>0 and val(s,'state')~='dead' and not game:GetService('CollectionService'):HasTag(model,'dying_units') then
    local position=model:GetPivot().Position local nearest,best=1,math.huge
    local lane=val(s,'lane') local laneId=typeof(lane)=='Instance' and lane.Name or tostring(lane)
    local laneExists=false for _,path in ipairs(paths) do if path.Id==laneId then laneExists=true break end end
    for i,p in ipairs(samples) do
     if not laneExists or paths[sampleRoutes[i]].Id==laneId then
      local distance=(flat(p)-flat(position)).Magnitude if distance<best then best=distance nearest=i end
     end
    end
    local progress=progresses[nearest]
    local route=sampleRoutes[nearest] local routePoints=routeSamples[route]
    local flying=(tonumber(val(s,'Flying')) or 0)>0
    local futureDamage=0;local strongestShot=0;local defenseArrival=math.huge
    local stepLength=paths[route].Length/48
    for _,t in ipairs(defenders) do if role(t.Id)=='damage' and (not flying or hitsFlying(t.Id,t.Upgrade)) then
     local coverage=towerCoverage[t.Unit]
     local covered=coverage and coverage.Routes[route][math.floor(progress*48)+1] or 0
     local nextCovered=coverage and coverage.Next[route][math.floor(progress*48)+1]
     if nextCovered then defenseArrival=math.min(defenseArrival,math.max(0,(nextCovered-1)/48-progress)*paths[route].Length/math.max(1,tonumber(val(s,'speed'))or 1))end
     local exposure=covered*stepLength/math.max(1,tonumber(val(s,'speed'))or 1)/math.max(1,coverage and coverage.Shared or 1)
     futureDamage+=(coverage and coverage.DPS or 0)*exposure
     if exposure>=math.max(.3,tonumber(val(t.Stats,'attack_cooldown'))or 1)*2 then strongestShot=math.max(strongestShot,tonumber(val(t.Stats,'damage'))or 0)end
    end end
    local speed=tonumber(val(s,'speed'))
    local remaining=(1-progress)*paths[route].Length/math.max(1,speed or 1)
    local approachSeconds=approach[route] and math.max(0,approach[route]-progress)*paths[route].Length/math.max(1,speed or 1) or nil
    local distant=a.HasEconomyWindow(approachSeconds,remaining,speed)
    local vulnerable=futureDamage<hp*1.5
    local dangerous=not distant and (progress>.65 or vulnerable)
    enemies[#enemies+1]={Position=position,Progress=progress,HP=hp,Flying=flying,Dangerous=dangerous,Lane=paths[route].Id,Route=route,
     PredictedDamage=futureDamage,StrongestShot=strongestShot,DefenseArrivalSeconds=defenseArrival~=math.huge and defenseArrival or nil,RemainingSeconds=remaining,ApproachSeconds=approachSeconds,EconomyWindow=distant==true}
    highest=math.max(highest,progress)
    if dangerous then risk=true pressure+=hp if flying then airRisk=true end end
    if #enemies>=160 then break end
   end
  end
  return {Samples=samples,SampleProgress=progresses,SampleRoutes=sampleRoutes,DefenseWeights=defense,WeakRoutes=weakRoutes,UncoveredLanes=uncovered,Paths=paths,Enemies=enemies,Risk=risk,AirRisk=airRisk,Pressure=pressure,Highest=highest}
 end
 a.AnalyzeEnemies=enemyContext
 local function pathScore(position,range,context)
  local score=0
  for i,p in ipairs(context.Samples) do
   if (flat(p)-flat(position)).Magnitude<=range then
    local progress=context.SampleProgress and context.SampleProgress[i] or (i-1)/math.max(1,#context.Samples-1)
    local need=context.DefenseWeights and context.DefenseWeights[i] or 1
    score+=(context.Risk and (1+progress*2) or (1.5-progress*.8))*(.15+need)
   end
  end
  return score
 end
(function()
 local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
 function a.IsWithinSmartAreas(position,circles,padding)
  if typeof(position)~='Vector3' or not finite(position.X)or not finite(position.Y)or not finite(position.Z)then return false end
  padding=tonumber(padding)or 0;if not finite(padding)or padding<0 then return false end
  for _,circle in ipairs(circles or a.GetSmartCircles()) do
   local c=circle.Center local radius=tonumber(circle.Radius)or 36
   if finite(radius)and type(c)=='table'and finite(c[1])and finite(c[2])and finite(c[3])then
    radius=math.clamp(radius,8,80)-padding
    local dx,dz=position.X-c[1],position.Z-c[3]
    if radius>=0 and dx*dx+dz*dz<=radius*radius+.0001 and math.abs(position.Y-c[2])<=40 then return true end
   end
  end
  return false
 end
 local placementMargins={}
 function a.RaycastSmartGround(point,data)
  -- Probe from the selected floor first, so ceilings cannot mask valid ground.
  for _,height in ipairs({6,20,39})do
   local hit=Placement.raycast(point+Vector3.new(0,height,0),Vector3.new(0,-height-40,0))
   if hit and math.abs(hit.Position.Y-point.Y)<=40 and Placement.is_valid_raycast_hit(hit.Instance,data)then return hit end
  end
 end
 function a.GetSmartPlacementMargin(id)
  if placementMargins[id]then return placementMargins[id]end
  local data=Units[id]or{}local radius=tonumber(data.override_hitbox_radius)
  if not finite(radius)or radius<=0 then
   radius=2
   pcall(function()
    local model=Core.get_unit_model_by_name(id)
    if model then local _,size=Core.get_bounding_box(model,id);if size and finite(size.X)and finite(size.Z)then radius=math.max(2,size.X/2,size.Z/2)end end
   end)
  end
  placementMargins[id]=radius+.35
  return placementMargins[id]
 end
 function a.GetDefenseTowers()
  local own=towers() local known={}
  for _,t in ipairs(own) do known[t.Unit]=true end
  local collection=game:GetService('CollectionService')
  for _,model in ipairs(collection:GetTagged('nonminion_units')) do
   local stats=model:FindFirstChild('_stats')
   if not known[model] and model:IsA('Model') and model.Parent and collection:HasTag(model,'player_units') and val(stats,'player')
    and not val(stats,'parent_unit') and val(stats,'state')~='dead' and not collection:HasTag(model,'dying_units') then
    own[#own+1]={Unit=model,Stats=stats,Id=val(stats,'id'),UUID=val(stats,'uuid'),CF=model:GetPivot(),Upgrade=tonumber(val(stats,'upgrade')) or 0,Teammate=true}
   end
  end
  return own
 end
 function a.PlacementSnapshot(unit,all)
  local snapshot={Items={},ByModel={},Height=2.66,Padding=a.GetSmartPlacementMargin(unit.Id)}
  for _,t in ipairs(all) do if t.Id==unit.Id then
   local hitbox=t.Unit:FindFirstChild('_hitbox')
   if hitbox and hitbox:IsA('Part') then snapshot.Height=hitbox.Shape==Enum.PartType.Cylinder and hitbox.Size.X or hitbox.Size.Y break end
  end end
  if snapshot.Height==2.66 then
   pcall(function()
    local model=Core.get_unit_model_by_name(unit.Id)
    if model then local _,size=Core.get_bounding_box(model,unit.Id) snapshot.Height=size.Y+.5 end
   end)
  end
  for _,hitbox in ipairs(game:GetService('CollectionService'):GetTagged('player_unit_hitboxes')) do
   if hitbox:IsA('Part') and hitbox.Parent and game:GetService('CollectionService'):HasTag(hitbox.Parent,'player_units') then
    local cf=hitbox.CFrame local size=hitbox.Size
    local height=math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z
    local radius=hitbox.Shape==Enum.PartType.Cylinder and math.max(size.Y,size.Z)/2 or math.max(size.X,size.Z)/2
    local record={CF=cf,Size=size,Height=height,Radius=radius,Shape=hitbox.Shape,Model=hitbox.Parent}
    snapshot.Items[#snapshot.Items+1]=record snapshot.ByModel[hitbox.Parent]=record
   end
  end
  return snapshot
 end
 function a.PlacementIsClear(point,snapshot)
  local centerY=point.Y+snapshot.Height/2+.05
  for _,item in ipairs(snapshot.Items) do
   if math.abs(centerY-item.CF.Y)<(snapshot.Height+item.Height)/2+.05 then
    local p=item.CF:PointToObjectSpace(Vector3.new(point.X,item.CF.Y,point.Z))
    if item.Shape==Enum.PartType.Cylinder then
     if (p.Y/(item.Size.Y/2+.1))^2+(p.Z/(item.Size.Z/2+.1))^2<=1 then return false end
    elseif item.Shape==Enum.PartType.Ball then
     if (Vector2.new(point.X,point.Z)-Vector2.new(item.CF.X,item.CF.Z)).Magnitude<item.Radius+.1 then return false end
    elseif math.abs(p.X)<item.Size.X/2+.1 and math.abs(p.Z)<item.Size.Z/2+.1 then return false end
   end
  end
  return true
 end
 function a.PlacementNeighbor(t,snapshot)
  local item=snapshot.ByModel[t.Unit]
  return item and item.CF.Position or t.CF.Position,item and item.Radius+.2 or 2.2
 end
 function a.CheckPlacementRequest(step)
  local data=Units[step.UnitId] if not data then return false,'Unit data unavailable' end
  local ownCount=0 local totalCount=0 local collection=game:GetService('CollectionService')
  for _,model in ipairs(collection:GetTagged('player_units')) do
   local stats=model:FindFirstChild('_stats')
   if val(stats,'id')==step.UnitId and not val(stats,'parent_unit') and val(stats,'state')~='dead' and not collection:HasTag(model,'dying_units') then
    totalCount+=1 if val(stats,'player')==player then ownCount+=1 end
   end
  end
  local reserved=not step.Recovery and a.RecoveryReservations and a.RecoveryReservations(step.UnitId) or 0
  if ownCount+reserved>=(a.PlacementCap and a.PlacementCap(step.UnitId,data)or tonumber(data.spawn_cap)or 1) or totalCount+reserved>=(tonumber(data.global_spawn_cap) or math.huge) then return false,'Unit limit changed • checking another unit' end
  local position=CFrame.new(unpack(step.CF)).Position
  if C.Smart and not a.IsWithinSmartAreas(position,nil,a.GetSmartPlacementMargin(step.UnitId)) then return false,'Smart Play · unit footprint outside saved circles / map still loading' end
  local snapshot=a.PlacementSnapshot({Id=step.UnitId,Data=data},towers())
  if not a.PlacementIsClear(position,snapshot) then return false,'Position now occupied • finding another position' end
  return true
 end
 local collection=game:GetService('CollectionService')
 local function invalidatePlacement()
  smart.PositionFailures={} smart.Context=nil smart.LastAnalysis=-math.huge
 end
 connect(collection:GetInstanceAddedSignal('player_unit_hitboxes'),invalidatePlacement)
 connect(collection:GetInstanceRemovedSignal('player_unit_hitboxes'),invalidatePlacement)
end)()

 -- Keep each rotation group in one area, anchored by its existing supports.
 function a.BuffPositionAllowed(id,position,all)
  if not a.IsLimitedBuff(id)then return true end
  local range=tonumber(Units[id]and Units[id].range)or 0
  if range<=0 then return false,'Buff range unavailable'end
  for _,target in ipairs(all)do
   if role(target.Id)=='damage'and supportsType(id,target.Id)and(target.CF.Position-position).Magnitude<=math.max(0,range-1)then return true end
  end
  return false,'Buff needs a compatible damage target in range'
 end
 function a.PathSegmentDistance(position,first,last)
  local delta=Vector3.new(last.X-first.X,0,last.Z-first.Z)
  local point=Vector3.new(position.X-first.X,0,position.Z-first.Z)
  local length=delta:Dot(delta)
  local alpha=length>0 and math.clamp(point:Dot(delta)/length,0,1)or 0
  return(point-delta*alpha).Magnitude
 end
 function a.IsFarmAwayFromPaths(position,paths,padding)
  local distance=math.huge;local known=false
  for _,path in ipairs(paths or {})do
   for i=2,#path.Points do
    known=true;distance=math.min(distance,a.PathSegmentDistance(position,path.Points[i-1],path.Points[i]))
   end
  end
  -- Keep the farm footprint clear of the road plus a real edge buffer.
  -- A fixed extra 12 studs made narrow maps reject every valid farm position.
  return known and distance>=math.max(6,math.max(0,tonumber(padding)or 0)+2),distance
 end
 function a.DungeonElementWeight(id,level)
  level=level or Loader.LevelData
  if type(level)~='table'or type(level._dungeon)~='table'then return 1 end
  local definition=Units[id]or{}
  local types={[definition._base_damage_type or definition.base_damage_type or 'physical']=true}
  for damageType,enabled in pairs(definition._secondary_damage_types or {})do if enabled then types[damageType]=true end end
  local amplification,resistance=0,0
  for _,effect in pairs(level._weak_against or {})do
   if types[effect.damage_type]then amplification=math.max(amplification,tonumber(effect.amplification)or 0)end
  end
  for _,effect in pairs(level._strong_against or {})do
   if types[effect.damage_type]then resistance=math.max(resistance,tonumber(effect.resistance)or 0)end
  end
  return math.max(.05,(1+amplification)*(1-math.clamp(resistance,0,1)))
 end

 function a.GetBuffCircle(unit,all,circles)
  local bestIndex,bestScore
  for index,circle in ipairs(circles) do
   local center=Vector3.new(unpack(circle.Center)) local radius=tonumber(circle.Radius) or 36
   local members=0 local damage=0
   for _,t in ipairs(all) do
    if (flat(t.CF.Position)-flat(center)).Magnitude<=radius+.01 then
     if t.Id==unit.Id then members+=1
     elseif role(t.Id)=='damage' then damage+=math.log(1+math.max(0,dps(t)))*(supportsType(unit.Id,t.Id) and 1 or .2) end
    end
   end
   local score=members*1000000+damage
   if not bestScore or score>bestScore then bestIndex=index bestScore=score end
  end
  return bestIndex
 end
 function a.FrontlinePositionScore(position,range,context)
  if context.FrontlineSafe~=true then return 0 end
  local score=0
  for i,point in ipairs(context.Samples or{})do
   local progress=context.SampleProgress and context.SampleProgress[i]
   if type(progress)=='number'and progress<=.4 then
    local delta=Vector3.new(point.X-position.X,0,point.Z-position.Z)
    if delta.Magnitude<=range then score+=(1-progress/.4)*12 end
   end
  end
  return score
 end

 function a.SmartPosition(unit,all,context)
  local center,radius=area() if not center then return nil,'Choose a circle area for this map first' end
  local circles=circleList()
  context=context or enemyContext()
  if #context.Samples<2 then return nil,'This map has no supported enemy path' end
  local unitRole=role(unit.Id) local range=tonumber(unit.Data.range) or 10
  local farmPaths=unitRole=='farm'and a.GetSmartPaths()or nil
  local padding=a.GetSmartPlacementMargin(unit.Id)
  local geometry=a.PlacementSnapshot(unit,all)
  smart.PositionFailures=smart.PositionFailures or {} smart.PositionDiagnostics=smart.PositionDiagnostics or {}
  local signature=''
  for _,circle in ipairs(circles) do signature..=table.concat(circle.Center,',')..':'..tostring(circle.Radius)..';' end
  for _,t in ipairs(all) do signature..=t.Id..':'..tostring(t.CF.Position)..':'..tostring(t.Upgrade)..';' end
  for _,item in ipairs(geometry.Items) do signature..=tostring(item.CF.Position)..';' end
  local failure=smart.PositionFailures[unit.Id]
  if failure and failure.Signature==signature and os.clock()<failure.Until then return nil,failure.Reason end
  local diagnostics={Candidates=0,ValidGround=0,Free=0,Covered=0,Targets=0}
  local candidates={} local best,bestScore,bestKey=nil,-math.huge,nil
  local buffCircle=unitRole=='buff' and a.GetBuffCircle(unit,all,circles) or nil
  for circleIndex,circle in ipairs(circles) do
   if buffCircle and circleIndex~=buffCircle then continue end
   local c=Vector3.new(unpack(circle.Center)) local limit=math.max(0,math.clamp(tonumber(circle.Radius) or 36,8,80)-padding)
   if limit<=0 then continue end
   for ring=0,6 do for angle=0,(ring==0 and 0 or 19) do
    local r=limit*ring/6 local theta=angle*math.pi/10
    local sample=c+Vector3.new(math.cos(theta)*r,0,math.sin(theta)*r)
    candidates[#candidates+1]={Point=sample,Edge=r/limit,Center=c,Radius=limit}
   end end
  end
  -- Sample tightly around existing farms instead of scattering along the edge.
  if unitRole=='farm' then
   for _,t in ipairs(all) do if role(t.Id)=='farm' then
    local anchor,distance=a.PlacementNeighbor(t,geometry)
    for angle=0,23 do
     local theta=angle*math.pi/12 local point=anchor+Vector3.new(math.cos(theta)*distance,0,math.sin(theta)*distance)
     for _,circle in ipairs(circles) do
      local c=Vector3.new(unpack(circle.Center)) local limit=math.clamp(tonumber(circle.Radius) or 36,8,80)-padding
      if limit<=0 then continue end
      local edge=(flat(point)-flat(c)).Magnitude/limit
      if edge<=1 then candidates[#candidates+1]={Point=point,Edge=edge,Center=c,Radius=limit} break end
     end
    end
   end end
  end
  if unitRole~='farm' then
   -- Fill narrow gaps beside placed units that the coarse radial grid can miss.
   for _,t in ipairs(all) do
    local anchor,spacing=a.PlacementNeighbor(t,geometry)
    for angle=0,15 do
     local theta=angle*math.pi/8 local point=anchor+Vector3.new(math.cos(theta)*spacing,0,math.sin(theta)*spacing)
     for index,circle in ipairs(circles) do if not buffCircle or index==buffCircle then
      local c=Vector3.new(unpack(circle.Center)) local limit=math.clamp(tonumber(circle.Radius) or 36,8,80)-padding
      if limit<=0 then continue end
      if (flat(point)-flat(c)).Magnitude<=limit then candidates[#candidates+1]={Point=point,Edge=(flat(point)-flat(c)).Magnitude/limit,Center=c,Radius=limit} break end
     end end
    end
   end
  end
  if unitRole=='buff' or unitRole=='utility' then
   local targets={} local average=Vector3.zero
   for _,t in ipairs(all) do if role(t.Id)=='damage' and supportsType(unit.Id,t.Id) then targets[#targets+1]=t.CF.Position average+=t.CF.Position end end
   if #targets==0 and unitRole~='buff' then for _,t in ipairs(all) do if role(t.Id)=='damage' then targets[#targets+1]=t.CF.Position average+=t.CF.Position end end end
   local function offer(point)
    for index,circle in ipairs(circles) do if not buffCircle or index==buffCircle then
     local c=Vector3.new(unpack(circle.Center)) local limit=math.clamp(tonumber(circle.Radius) or 36,8,80)-padding
     if limit<=0 then continue end
     if (flat(point)-flat(c)).Magnitude<=limit then candidates[#candidates+1]={Point=point,Edge=(flat(point)-flat(c)).Magnitude/limit,Center=c,Radius=limit} break end
    end end
   end
   if #targets>0 then
    average/=#targets offer(average)
    for i=0,15 do offer(average+Vector3.new(math.cos(i*math.pi/8)*2.2,0,math.sin(i*math.pi/8)*2.2)) end
    for i=1,#targets do for j=i+1,#targets do offer((targets[i]+targets[j])/2) end end
   end
  end
  diagnostics.Candidates=#candidates
  for _,candidate in ipairs(candidates) do
   local hit=a.RaycastSmartGround(candidate.Point,unit.Data)
   if hit and Placement.is_valid_raycast_hit(hit.Instance,unit.Data) and (flat(hit.Position)-flat(candidate.Center)).Magnitude<=candidate.Radius and a.IsWithinSmartAreas(hit.Position,circles,padding) then
    diagnostics.ValidGround+=1
    local position=hit.Position local clear=a.PlacementIsClear(hit.Position,geometry)
    if clear and unitRole=='farm'then clear=a.IsFarmAwayFromPaths(position,farmPaths,padding)end
    if clear and a.BuffPositionAllowed then clear=a.BuffPositionAllowed(unit.Id,position,all)end
    local key=string.format('%s:%.1f:%.1f',unit.Id,position.X,position.Z)
    if rejected[key] and os.clock()-rejected[key]<60 then clear=false end
    if clear then
     diagnostics.Free+=1
     local score=0 local coveredTargets=0 local totalTargets=0
     if unitRole=='farm' then
      local _,roadDistance=a.IsFarmAwayFromPaths(position,farmPaths,padding)
      score=candidate.Edge*40+math.min(roadDistance,60)*2
      local nearest=math.huge
      for _,t in ipairs(all) do if role(t.Id)=='farm' then nearest=math.min(nearest,(flat(t.CF.Position)-flat(position)).Magnitude) end end
      if nearest<math.huge then score+=200/(1+nearest) end
     elseif unitRole=='buff' or unitRole=='utility' then
      local targets={} local coverage=0 local coveredDps=0 local distanceSum=0
      for _,t in ipairs(all) do if role(t.Id)=='damage' and supportsType(unit.Id,t.Id) then targets[#targets+1]=t end end
      for _,t in ipairs(targets) do
       local distance=(flat(t.CF.Position)-flat(position)).Magnitude distanceSum+=distance
       if distance<=range then coverage+=1 coveredDps+=dps(t) end
      end
      coveredTargets=coverage totalTargets=#targets
      if coverage==0 then clear=false
      else score=coverage*10000+math.log(1+coveredDps)*10-distanceSum/math.max(1,#targets)+pathScore(position,range,context)*.2 end
     else
      local coverage=pathScore(position,range,context)
      if coverage<=0 then clear=false end
      if (context.UncoveredLanes or 0)>0 and context.SampleRoutes then
       local coversWeak=false
       for i,p in ipairs(context.Samples) do if context.WeakRoutes[context.SampleRoutes[i]] and (flat(p)-flat(position)).Magnitude<=range then coversWeak=true break end end
       if not coversWeak then clear=false end
      end
      score=coverage*3+a.FrontlinePositionScore(position,range,context)
      for _,enemy in ipairs(context.Enemies) do
       if (not enemy.Flying or hitsFlying(unit.Id,0)) and (flat(enemy.Position)-flat(position)).Magnitude<=range then score+=(enemy.Dangerous and 14 or 2)+enemy.Progress*8 end
      end
      local supports=0 local coveredSupports=0
      for _,t in ipairs(all) do if role(t.Id)=='buff' and supportsType(t.Id,unit.Id) then
       supports+=1 if (flat(t.CF.Position)-flat(position)).Magnitude<=(tonumber(val(t.Stats,'range')) or 0) then coveredSupports+=1 end
      end end
      if supports>0 then local weight=context.FrontlineSafe and .2 or 1;score+=coveredSupports/supports*50*weight;if coveredSupports==supports then score+=50*weight end end
     end
     if clear and score>bestScore then best=CFrame.new(position) bestScore=score bestKey=key diagnostics.Covered=coveredTargets diagnostics.Targets=totalTargets end
    end
   end
  end
  smart.PositionDiagnostics[unit.Id]=diagnostics
  if best then smart.PositionFailures[unit.Id]=nil return best,bestKey,bestScore end
  local reason=unitRole=='buff' and 'Buff group circle has no valid free space • enlarge its circle' or unitRole=='farm' and 'No farm space away from enemy paths • move or enlarge the circle' or 'No valid free damage position • enlarge / add a circle on valid ground or hill'
  smart.PositionFailures[unit.Id]={Signature=signature,Until=os.clock()+2,Reason=reason}
  return nil,reason
 end
 local function countAllowed(unit,all)
  if a.TeamPolicy and not a.TeamPolicy.AllowsPlace(unit.Id,all)then return false end
  local own=0 for _,t in ipairs(all) do if t.Id==unit.Id then own+=1 end end
  local reserved=a.RecoveryReservations and a.RecoveryReservations(unit.Id) or 0
  if own+reserved>=(a.PlacementCap and a.PlacementCap(unit.Id,unit.Data)or tonumber(unit.Data.spawn_cap)or 1) then return false end
  local count=0 for _,u in ipairs(game:GetService('CollectionService'):GetTagged('player_units')) do local s=u:FindFirstChild('_stats') if val(s,'id')==unit.Id and not val(s,'parent_unit') and val(s,'state')~='dead' and not game:GetService('CollectionService'):HasTag(u,'dying_units') then count+=1 end end
  return count+reserved<(tonumber(unit.Data.global_spawn_cap) or math.huge)
 end
 local function upgradeValue(t,context)
  if a.FarmClosing and farm(t.Id) then return end
  if not a.CanUpgrade(t.Unit) then return end
  local data=Units[t.Id] local nextUpgrade=data and data.upgrade and data.upgrade[t.Upgrade+1]
  if not nextUpgrade and a.NativeUpgradeInfo then nextUpgrade=a.NativeUpgradeInfo(t)end
  local cost=nextUpgrade and price(t,t.Upgrade+1)
  if not cost then return end local divisor=math.max(1,cost)
  local unitRole=t.Id=='aqua_evolved'and'damage'or role(t.Id)
  if unitRole=='farm' then
   local now=tonumber(val(t.Stats,'farm_amount')) or 0
   local income=tonumber(nextUpgrade.farm_amount) or now
   return {Score=math.max(.001,income-now)/divisor*1000,Role=unitRole,Cost=cost,Tower=t}
  end
  if unitRole=='buff' or unitRole=='utility' then
   local oldRange=tonumber(val(t.Stats,'range')) or 0 local newRange=tonumber(nextUpgrade.range) or oldRange
   local gain=0 for _,other in ipairs(towers()) do if role(other.Id)=='damage' then local distance=(flat(other.CF.Position)-flat(t.CF.Position)).Magnitude if distance>oldRange and distance<=newRange then gain+=1 end end end
   return {Score=(gain*2+.2)/(cost/1000+1),Role=unitRole,Cost=cost,Tower=t}
  end
  local previous=data.upgrade and data.upgrade[t.Upgrade] or data
  local base=tonumber(previous.damage) or tonumber(data.damage) or 1
  local nextDamage=tonumber(nextUpgrade.damage) or base
  local currentDps=dps(t)
  local oldCooldown=tonumber(val(t.Stats,'attack_cooldown')) or tonumber(previous.attack_cooldown) or 1
  local nextCooldown=tonumber(nextUpgrade.attack_cooldown) or oldCooldown
  local gain=math.max(.01,currentDps*(nextDamage/math.max(1,base))*oldCooldown/math.max(.3,nextCooldown)-currentDps)
  local range=tonumber(nextUpgrade.range) or tonumber(val(t.Stats,'range')) or 10
  local coverage=pathScore(t.CF.Position,range,context)
  local score=math.log(1+gain)/(cost/1000+1)*(1+coverage*.04)
  for _,enemy in ipairs(context.Enemies) do if enemy.Dangerous and (not enemy.Flying or hitsFlying(t.Id,t.Upgrade+1)) and (flat(enemy.Position)-flat(t.CF.Position)).Magnitude<=range then score+=8 end end
  if context.AirRisk then score*=a.AirInvestmentWeight(t.Id,t.Upgrade+1) end
  score*=a.DungeonElementWeight(t.Id)
  return {Score=score,Role=unitRole,Cost=cost,Tower=t}
 end
 -- Re-evaluate concentration versus deployment from live HP, routes and upgrades.
 function a.GetCombatPlan(all,context)
  local attackers=0 local strongest=0 local upgradeable=false local capacity=0 local maxHP=0 local totalHP=0 local urgent=false
  for _,enemy in ipairs(context.Enemies or {}) do
   local hp=tonumber(enemy.HP) or 0 maxHP=math.max(maxHP,hp) totalHP+=hp
   if (enemy.Progress or 0)>.7 then urgent=true end
  end
  for _,t in ipairs(all) do if role(t.Id)=='damage' then
   attackers+=1 strongest=math.max(strongest,dps(t))
   if price(t,t.Upgrade+1) then upgradeable=true end
  end end
  for _,u in ipairs(equipped()) do if role(u.Id)=='damage' then
   local own=0 for _,t in ipairs(all) do if t.Id==u.Id then own+=1 end end
   capacity+=countAllowed(u,all) and (a.PlacementCap and a.PlacementCap(u.Id,u.Data)or tonumber(u.Data.spawn_cap)or 1) or own
   if attackers==0 then strongest=math.max(strongest,(tonumber(u.Data.damage) or 0)/math.max(.3,tonumber(u.Data.attack_cooldown) or 1)) end
  end end
  local heavy=strongest>0 and (maxHP>strongest*10 or totalHP>strongest*25)
  local lanes=math.max(1,#(context.Paths or {}))
  local target=heavy and upgradeable and math.min(capacity,lanes) or capacity
  local defense=a.AssessDefense(context,attackers)
  if heavy and defense.Mode=='Safe' and not defense.EconomyWindow then defense.Mode='Caution' end
  return {Defense=defense,Mode=defense.Mode,Heavy=heavy,Focus=heavy and upgradeable and attackers>=target and (context.UncoveredLanes or 0)==0,
   Target=target,Attackers=attackers,DeploymentComplete=not C.Place or (attackers>=capacity and (context.UncoveredLanes or 0)==0),Urgent=defense.Urgent,MaxHP=maxHP}
 end
 -- Separate event policy, selected by the existing Smart Play switch.
 function a.EarlyFarmWindow(combat,context,currentWave)
  local defense=combat.Defense or {}
  if currentWave<0 or (combat.Attackers or 0)<1 or combat.Urgent or context.AirRisk then return false end
  local enemies=context.Enemies or {}
  if #enemies==0 then return not context.Risk and (context.UncoveredLanes or 0)==0 end
  for _,enemy in ipairs(enemies)do
   if (tonumber(enemy.RemainingSeconds) or 0)<30 or(tonumber(enemy.DefenseArrivalSeconds)or 0)<=20 then return false end
  end
  return true
 end

 function a.ConfigureInvestmentProfile(combat,context,level)
  combat.Profile=type(level)=='table' and level.id=='summer2_event' and 'Summer' or 'Standard'
  if combat.Profile~='Summer' then
   local defense=combat.Defense or {}
   local covered=(context.UncoveredLanes or 0)==0 and not context.AirRisk
   local holding=(combat.Attackers or 0)>0 and covered and not combat.Urgent
    and defense.CompleteForecast==true and (defense.CoverageRatio or 0)>=1.25
   local quiet=(combat.Attackers or 0)>0 and covered and not context.Risk and #(context.Enemies or {})==0
   combat.EarlyFarmWindow=a.EarlyFarmWindow(combat,context,wave())
   combat.MaxFarmsFirst=holding or quiet or combat.EarlyFarmWindow or (covered and not combat.Urgent and defense.EconomyWindow==true)
   if combat.MaxFarmsFirst then combat.Mode='Safe';combat.FarmFocus=true end
   combat.NeedsDamagePlacement=not covered or (combat.Attackers or 0)==0
   return
  end
  -- A low damage forecast alone must not lock the event economy for minutes.
  local runway=(combat.Attackers or 0)>0 and not combat.Urgent
  for _,enemy in ipairs(context.Enemies or {})do
   if (enemy.Progress or 1)>=.65 or (tonumber(enemy.RemainingSeconds) or 0)<=60 then runway=false break end
  end
  combat.SummerFarmWindow=runway
  combat.NeedsDamagePlacement=(combat.Attackers or 0)<1 or combat.Mode=='Defense' or combat.Urgent==true or context.AirRisk==true or (context.UncoveredLanes or 0)>0
  combat.DeploymentComplete=not combat.NeedsDamagePlacement
 end
 function a.SummerFarmInvestment(farms,combat,cashNow,reserve)
  if combat.Profile~='Summer' or (combat.Mode=='Defense' and not combat.SummerFarmWindow) or combat.Urgent or #farms==0 then return nil,nil,false end
  local available=math.max(0,cashNow)
  if not(combat.SummerFarmWindow or combat.MaxFarmsFirst or combat.FarmRush or combat.Defense and combat.Defense.EconomyWindow) then available=math.max(0,available-reserve) end
  local best,placement
  for _,choice in ipairs(farms)do
   if choice.Ready~=false and choice.Cost<=available and (not best or choice.Score>best.Score or choice.Score==best.Score and choice.Cost<best.Cost)then best=choice end
   if choice.Kind=='Place' and choice.Ready~=false and choice.Cost<=available and(not placement or choice.Score>placement.Score or choice.Score==placement.Score and choice.Cost<placement.Cost)then placement=choice end
  end
  if placement then return placement,'Summer · place available farm from equipped slots',true end
  if best then return best,'Summer · spare cash to farms / income upgrades',true end
  if combat.Mode=='Defense' then return nil,nil,false end
  return nil,'Summer · saving for farm / damage reserve retained',true
 end

(function()
 function a.HasEconomyWindow(approachSeconds,remainingSeconds,speed)
  return type(speed)=='number' and speed>0 and type(approachSeconds)=='number' and approachSeconds>25 and type(remainingSeconds)=='number' and remainingSeconds>35
 end
 function a.HasFarmRushWindow(enemy)
  return enemy.EconomyWindow==true and type(enemy.ApproachSeconds)=='number' and enemy.ApproachSeconds>45 and type(enemy.RemainingSeconds)=='number' and enemy.RemainingSeconds>55
 end
 function a.AirInvestmentWeight(id,stage)
  if hitsFlying(id,stage) then return 2 end
  local data=Units[id]
  for nextStage=stage+1,#(data and data.upgrade or {}) do
   if hitsFlying(id,nextStage) then return 1/(nextStage-stage+1) end
  end
  -- Ground defense still progresses; an air threat must not erase every action.
  return .15
 end
 -- Forecast uses remaining lane time; clustered enemies share the same damage budget.
 function a.AssessDefense(context,attackers)
  local groups={} local ratio=math.huge local known=false local completeForecast=true local urgent=false local enemies=context.Enemies or {}
  local economyWindow=#enemies>0
  for _,enemy in ipairs(enemies) do if enemy.EconomyWindow~=true then economyWindow=false break end end
  local farmRush=economyWindow
  for _,enemy in ipairs(enemies) do if not a.HasFarmRushWindow(enemy) then farmRush=false break end end
  for _,enemy in ipairs(enemies) do
   local hp=math.max(0,tonumber(enemy.HP) or 0)
   local damage=tonumber(enemy.PredictedDamage)
   if hp>0 and damage then
    known=true ratio=math.min(ratio,damage/hp)
    local key=tostring(enemy.Route or enemy.Lane or '1')
    local group=groups[key] or {HP=0,Capacity=0} groups[key]=group
    group.HP+=hp group.Capacity=math.max(group.Capacity,damage)
    if ((enemy.Progress or 0)>.7 or (enemy.RemainingSeconds or math.huge)<8) and damage<hp*2 then urgent=true end
   elseif hp>0 then completeForecast=false if (enemy.Progress or 0)>.7 then urgent=true end end
  end
  for _,group in pairs(groups) do ratio=math.min(ratio,group.Capacity/math.max(1,group.HP)) end
  local mode='Safe'
  if economyWindow then mode='Safe'
  elseif attackers==0 or (context.UncoveredLanes or 0)>0 or context.AirRisk or urgent or (known and ratio<1.5) or (not known and context.Risk) then mode='Defense'
  elseif known and ratio<2.5 then mode='Caution' end
  local holding=attackers>0 and known and completeForecast and ratio>=1.5 and not urgent and not context.AirRisk and (context.UncoveredLanes or 0)==0
  return {Mode=mode,CoverageRatio=known and ratio or nil,ForecastKnown=known,CompleteForecast=completeForecast,Urgent=urgent and not economyWindow,Enemies=#enemies,EconomyWindow=economyWindow,FarmRush=farmRush,FarmFocus=economyWindow or holding,ClearComfortably=holding and ratio>=2.5}
 end
 function a.NewInvestmentBudget()
  return {FarmSpent=0,DamageSpent=0,FarmStreak=0,DamageStreak=0,PrimarySinceSupport=0,DamageUpgradesSincePlacement=0,Confirmed=0}
 end
 smart.Budget=a.NewInvestmentBudget()
 function a.RecordInvestment(pending)
  if not pending.Investment or pending.InvestmentRecorded then return end
  pending.InvestmentRecorded=true
  local item=pending.Investment local budget=smart.Budget
  budget.Confirmed+=1
  if item.Role=='farm' or item.Role=='damage' then
   -- Keep recent spending relevant as wave prices and danger change.
   budget.FarmSpent*=.85 budget.DamageSpent*=.85
   if item.Role=='farm' then budget.FarmSpent+=item.Cost budget.FarmStreak+=1 budget.DamageStreak=0
   else budget.DamageSpent+=item.Cost budget.DamageStreak+=1 budget.FarmStreak=0 end
   budget.PrimarySinceSupport+=1
   if item.Role=='damage' then
    if item.Kind=='Place' then
     budget.DamageUpgradesSincePlacement=0
     local placed=matchTower(pending.Step or {},towers())
     budget.DamageCore=placed and placed.Unit or nil
    else
     budget.DamageUpgradesSincePlacement=(budget.DamageUpgradesSincePlacement or 0)+1
     budget.DamageCore=pending.Unit or budget.DamageCore
    end
   end
  elseif item.Kind=='Place' then budget.PrimarySinceSupport=0 end
  smart.Context=nil smart.ContextAt=nil smart.LastAnalysis=-math.huge
 end
 function a.AttachInvestment(choice)
  if a.Pending then a.Pending.Investment={Role=choice.Role,Cost=choice.Cost,Kind=choice.Kind or (choice.Tower and 'Upgrade' or 'Place')} end
 end
 -- Pure allocation policy: affordability cannot silently promote a buff upgrade.
 function a.ShouldHoldDamage(combat,context)
  local defense=combat.Defense or{}
  if (combat.Attackers or 0)<1 or combat.Urgent or context.AirRisk or(context.UncoveredLanes or 0)>0 then return false end
  local enemies=context.Enemies or{}
  if #enemies==0 then return combat.Mode=='Safe'and not context.Risk end
  if defense.CompleteForecast~=true or(defense.CoverageRatio or 0)<1.5 then return false end
  for _,enemy in ipairs(enemies)do
   local hp=tonumber(enemy.HP)or 0
   if hp<=0 or(tonumber(enemy.PredictedDamage)or 0)<hp*1.5 then return false end
  end
  return true
 end

 function a.ConfigureArrivalBudget(combat,context)
  combat.FarmUpgradeDeadline=false;combat.UpgradeBuffer=20
  if combat.Profile=='Summer'then return end
  local arrival=math.huge
  for _,enemy in ipairs(context.Enemies or{})do
   if type(enemy.DefenseArrivalSeconds)=='number'then arrival=math.min(arrival,enemy.DefenseArrivalSeconds)end
  end
  combat.DefenseArrivalSeconds=arrival~=math.huge and arrival or nil
  if (combat.Attackers or 0)>0 and arrival<=combat.UpgradeBuffer then
   combat.FarmUpgradeDeadline=true;combat.MaxFarmsFirst=false;combat.FarmFocus=false;combat.FarmRush=false;combat.EarlyFarmWindow=false
  end
 end

 function a.SelectInvestment(candidates,combat,cashNow,budget,buffBlocked)
  budget=budget or a.NewInvestmentBudget()
  local groups={farm={},damage={},supportPlace={},supportUpgrade={}}
  for _,choice in ipairs(candidates) do
   if not choice.Excluded and (choice.Score or 0)>0 and not(combat.HoldDamage and choice.Role=='damage'and choice.Kind=='Place')then
    local key=choice.Role=='farm' and 'farm' or choice.Role=='damage' and 'damage' or choice.Kind=='Place' and 'supportPlace' or 'supportUpgrade'
    groups[key][#groups[key]+1]=choice
   end
  end
  local function best(group,affordable)
   local selected
   for _,choice in ipairs(group) do
    if choice.Ready~=false and (not affordable or choice.Cost<=cashNow) and (not selected or choice.Score>selected.Score or (choice.Score==selected.Score and choice.Cost<selected.Cost)) then selected=choice end
   end
   return selected
  end
  local farmChoice=best(groups.farm,true) local damageChoice=best(groups.damage,true)
  local hasFarm=#groups.farm>0 local hasDamage=#groups.damage>0
  local upgrades={} local core
  for _,candidate in ipairs(groups.damage) do if candidate.Kind~='Place' then
   upgrades[#upgrades+1]=candidate
   if candidate.Tower and candidate.Tower.Unit==budget.DamageCore and budget.DamageCore~=nil then core=candidate end
  end end
  if combat.Profile~='Summer'then
   -- Finish the current core before splitting spending across fresh defenders.
   local focus=core or best(upgrades,false)
   if focus and not combat.Urgent and not combat.NeedsDamagePlacement then
    damageChoice=focus.Ready~=false and focus.Cost<=cashNow and focus or nil
   end
  else
   if not combat.Urgent and #upgrades>0 then
    local focus=core or best(upgrades,false)
    if focus then damageChoice=focus.Ready~=false and focus.Cost<=cashNow and focus or nil end
   end
  end

  if combat.Profile=='Summer' then
   local preferred
   for _,candidate in ipairs(groups.damage)do
    if candidate.Kind=='Place' and candidate.PreferredArrival and candidate.Ready~=false and candidate.Cost<=cashNow and(not preferred or candidate.Score>preferred.Score)then preferred=candidate end
   end
   if preferred then damageChoice=preferred end
  end
  local reserve=math.huge
  for _,choice in ipairs(groups.damage) do if choice.Ready~=false then reserve=math.min(reserve,choice.Cost) end end
  if reserve==math.huge then reserve=0 end
  if combat.InitialPriorityDefense then
   if damageChoice then return damageChoice,'Summer · establish temporary / preferred defense first' end
   if hasDamage then return nil,'Summer · saving for the first available defender' end
  end
  if combat.FarmUpgradeDeadline then
   if damageChoice then return damageChoice,'upgrade core before enemy contact • 20s buffer' end
   if hasDamage then return nil,'saving for core upgrade before enemy contact' end
  end
  local summerChoice,summerReason,summerHandled=a.SummerFarmInvestment(groups.farm,combat,cashNow,reserve)
  if summerHandled then return summerChoice,summerReason end
  if combat.Mode=='Defense' then
   local emergencyBuff
   for _,candidate in ipairs(groups.supportPlace) do
    if candidate.Role=='buff' and candidate.EmergencyUseful==true and candidate.Ready~=false and candidate.Cost<=cashNow
     and (not emergencyBuff or candidate.Score>emergencyBuff.Score) then emergencyBuff=candidate end
   end
   -- Complete a useful rotation without consuming the next damage action's
   -- budget. An imminent leak keeps the available damage action first.
   if emergencyBuff and (not combat.Urgent or not damageChoice) and cashNow-emergencyBuff.Cost>=reserve then
    return emergencyBuff,'emergency buff • complete rotation with damage reserve'
   end
   if damageChoice then return damageChoice,'damage • unsafe lane / insufficient damage margin' end
   return nil,hasDamage and 'saving for damage • economy and buff spending paused' or 'no viable damage action • check team and circle coverage'
  end
  if combat.MaxFarmsFirst and hasFarm then
   local farmUpgrades={}
   for _,candidate in ipairs(groups.farm) do if candidate.Kind~='Place' then farmUpgrades[#farmUpgrades+1]=candidate end end
   local target=#farmUpgrades>0 and best(farmUpgrades,false) or best(groups.farm,false)
   if combat.EarlyFarmWindow then
    local placements={} for _,candidate in ipairs(groups.farm)do if candidate.Kind=='Place'then placements[#placements+1]=candidate end end
    target=best(placements,true) or best(groups.farm,true) or target
   end
   if target and target.Cost<=cashNow then return target,'max farms first • wave comfortably covered' end
   return nil,'saving to max farms • wave comfortably covered'
  end
  -- Re-evaluated every action: finish all available farm work while the entire
  -- map still has a long approach window, regardless of recent spending streak.
  if combat.FarmRush and hasFarm then
   if farmChoice then return farmChoice,'farm rush • complete farms before other units' end
   return nil,'saving for farm • long safe approach window'
  end
  -- Favor income while live defenses can still clear the wave. Keep the next
  -- damage action funded when enemies are no longer in the long travel window.
  if combat.FarmFocus and hasFarm then
   if farmChoice and cashNow-farmChoice.Cost>=reserve then return farmChoice,'farm focus • defenses holding / damage reserve retained' end
   if not farmChoice and cashNow>=reserve then return nil,'saving for farm • defenses holding / damage reserve retained' end
  end
  -- Buff placement is staggered between primary investments; upgrades remain last.
  if combat.Mode=='Safe' and (budget.PrimarySinceSupport or 0)>=3 then
   local support=best(groups.supportPlace,true)
   if support and cashNow-support.Cost>=reserve then return support,'place support group • damage reserve retained' end
  end
  local farmShare=combat.Mode=='Caution' and .3 or .65
  local total=(budget.FarmSpent or 0)+(budget.DamageSpent or 0)
  local preferFarm=not hasDamage or (hasFarm and (total==0 and combat.Mode=='Safe' or total>0 and (budget.FarmSpent or 0)/total<farmShare))
  if hasFarm and hasDamage then
   if (budget.FarmStreak or 0)>=2 then preferFarm=false end
   if (budget.DamageStreak or 0)>=2 then preferFarm=true end
  end
  if combat.Mode=='Caution' and farmChoice and hasDamage and cashNow-farmChoice.Cost<reserve then preferFarm=false farmChoice=nil end
  if preferFarm then
   if farmChoice then return farmChoice,'farm income • balanced recent spending' end
   if damageChoice then return damageChoice,'damage • farm step currently unaffordable' end
  else
   if damageChoice then return damageChoice,'damage • balanced with farm income' end
   if farmChoice and (combat.Mode=='Safe' or not hasDamage or cashNow-farmChoice.Cost>=reserve) then return farmChoice,'farm income • damage reserve retained' end
  end
  if combat.HoldDamage and not hasFarm and not hasDamage then return nil,'defense sufficient • no extra placement needed' end
  if hasFarm or hasDamage or buffBlocked then return nil,'saving for farm / damage • buff upgrades wait' end
  local support=best(groups.supportPlace,true) if support then return support,'complete support group' end
  if not buffBlocked then
   local upgrade=best(groups.supportUpgrade,true) if upgrade then return upgrade,'buff upgrade • farm and damage work completed' end
  end
  return nil,'waiting for cash / available upgrades'
 end
 -- Upgrade Farms First outside Smart uses the same adaptive allocator.
 function a.BalancedUpgrade()
  local all=towers() local context=enemyContext() local combat=a.GetCombatPlan(all,context)
  local candidates={} local blocked=false
  for _,t in ipairs(all) do
   local r=role(t.Id)
   if (r=='farm' or r=='damage') and price(t,t.Upgrade+1) then blocked=true end
   local choice=upgradeValue(t,context)
   if choice then choice.Kind='Upgrade' candidates[#candidates+1]=choice end
  end
  local choice,reason=a.SelectInvestment(candidates,combat,math.max(0,cash()-(a.RecoveryReserveCash or 0)),smart.Budget,blocked)
  a.Status='Auto Upgrade • '..tostring(reason)
  a.InvestmentReserve=not choice and tostring(reason):sub(1,6)=='saving'
  if not choice then return end
  local t=choice.Tower
  send({Action='Upgrade',UUID=t.UUID,UnitId=t.Id,CF=cfData(t.CF),Target=t.Upgrade+1},t.Unit,'auto')
  a.AttachInvestment(choice)
 end
end)()

 function a.SmartStep(contextOverride)
  local center,radius=area()
  a.UpdateSmartUI()
  if not center then a.Status=C.UsePathPosition and 'Smart Play • waiting for map paths' or 'Smart Play • choose a circle area first' return end
  local now=os.clock()
  if now-smart.LastAnalysis<.12 then return end smart.LastAnalysis=now
  local all=towers() local context=contextOverride
  if not context then
   if smart.Context and now-(smart.ContextAt or -math.huge)<.6 then context=smart.Context
   else context=enemyContext() smart.ContextAt=now end
  end
  smart.Risk=context.Risk smart.Context=context
  if #context.Samples<2 then a.Status='Smart Play • unsupported path on this map' return end
  local buffs=env.FyrelithAutoBuff
  if buffs and not smart.ArmedBuffs and not a.SmartDryRun then
   for _,d in ipairs(buffs.Definitions) do for _,u in ipairs(equipped()) do if u.Id==d.Id then buffs.Enabled[d.Id]=true end end end
   buffs.Save() smart.ArmedBuffs=true
  end
  local attackers=0
  for _,t in ipairs(all) do if role(t.Id)=='damage' then attackers+=1 end end
  local combat=a.GetCombatPlan(all,context) smart.CombatPlan=combat
  combat.FarmRush=combat.Defense.FarmRush==true
  combat.FarmFocus=combat.Defense.FarmFocus==true
  combat.MaxFarmsFirst=combat.Defense.ClearComfortably==true
  a.ConfigureInvestmentProfile(combat,context,Loader.LevelData)
  context.FrontlineSafe=combat.Mode~='Defense'and not combat.Urgent and not context.AirRisk
  combat.HoldDamage=a.ShouldHoldDamage(combat,context)
  a.ConfigureArrivalBudget(combat,context)
  combat.InitialPriorityDefense=false
  local cashNow=math.max(0,cash()-(a.RecoveryReserveCash or 0)) local choices={} local buffBlocked=false
  if C.Upgrade then for _,t in ipairs(all) do
   local r=role(t.Id)
   if (r=='farm' or r=='damage') and price(t,t.Upgrade+1) then buffBlocked=true end
   local choice=upgradeValue(t,context)
   if choice then
    choice.Kind='Upgrade'
    choices[#choices+1]=choice
   end
  end end
  if C.Place then for _,u in ipairs(equipped()) do if countAllowed(u,all) and not (a.FarmClosing and farm(u.Id)) then
   local r=role(u.Id) local own=0 for _,t in ipairs(all) do if t.Id==u.Id then own+=1 end end
   local preferredArrival=false
   local cost=spawnPrice(u.Data) local score=0
   if r=='damage' then
    if combat.Profile=='Summer' and not combat.NeedsDamagePlacement and not preferredArrival then continue end
    local raw=(tonumber(u.Data.damage) or 0)/math.max(.3,tonumber(u.Data.attack_cooldown) or 1)
    score=math.log(1+raw)/(cost/1000+1)
    if attackers==0 then score+=50 end
    if (context.UncoveredLanes or 0)>0 then score+=25 end
    if context.AirRisk then score*=a.AirInvestmentWeight(u.Id,0) end
    if C.Upgrade and combat.Focus and combat.Mode~='Defense' and not combat.Urgent and not context.AirRisk then score*=.3 end
    score*=a.DungeonElementWeight(u.Id)
   elseif r=='farm' and (combat.Profile=='Summer' or attackers>0 or combat.Defense.EconomyWindow) then
    score=math.max(.001,tonumber(u.Data.farm_amount) or 0)/math.max(1,cost)*1000
   elseif r=='buff' then
    local cap=a.PlacementCap and a.PlacementCap(u.Id,u.Data)or tonumber(u.Data.spawn_cap)or 1
    if attackers>0 and own<cap then score=cap-own end
   end
   local useful=false
   if r=='buff' then for _,t in ipairs(all) do if role(t.Id)=='damage' and supportsType(u.Id,t.Id) then useful=true break end end end
   if score>0 then choices[#choices+1]={Kind='Place',Unit=u,Role=r,Score=score,Cost=cost,EmergencyUseful=useful,PreferredArrival=preferredArrival} end
  end end end
  if a.TeamPolicy then for _,choice in ipairs(choices)do local id=choice.Tower and choice.Tower.Id or choice.Unit and choice.Unit.Id;if id then choice.Score=choice.Score*(7-a.TeamPolicy.Get(id).Priority)end end end
  local choice,decision,positionFailure
  -- A rejected / full placement must not block every other affordable action.
  for attempt=1,#choices+1 do
   choice,decision=a.SelectInvestment(choices,combat,cashNow,smart.Budget,buffBlocked)
   if not choice or choice.Tower then break end
   local cf,key=a.SmartPosition(choice.Unit,all,context)
   if cf then
    local allowed,reason=a.ValidateAutoAction({Action='Place',UUID=choice.Unit.UUID,UnitId=choice.Unit.Id,CF=cfData(cf)},nil,'smart')
    if allowed and a.CheckPlacementRequest then allowed,reason=a.CheckPlacementRequest({Action='Place',UUID=choice.Unit.UUID,UnitId=choice.Unit.Id,CF=cfData(cf)})end
    if allowed then choice.CF=cf choice.Key=key break end
    key=reason or 'Placement currently unavailable'
   end
   choice.Excluded=true smart.Reason=key positionFailure=key choice=nil
  end
  if not choice and positionFailure then decision=positionFailure end
  smart.InvestmentDecision=decision
  a.SmartInsight.Text=(combat.Profile=='Summer' and 'SUMMER SMART • ' or '')..(combat.Mode=='Defense' and 'DEFENSE FIRST' or combat.MaxFarmsFirst and 'MAX FARMS FIRST • wave covered' or combat.FarmRush and 'FARM FIRST • long safe window' or combat.FarmFocus and 'FARM FOCUS • defenses holding' or combat.Mode=='Caution' and 'BALANCED • damage reserve' or 'ECONOMY • farm > damage > buff')..' • '..tostring(decision or '')
  smart.LastChoice=choice and choice.Score>0 and {Role=choice.Role,Score=choice.Score,Id=choice.Tower and choice.Tower.Id or choice.Unit.Id,Kind=choice.Tower and 'Upgrade' or 'Place',Position=choice.CF and choice.CF.Position} or nil
  if a.SmartDryRun then return smart.LastChoice end
  if not choice or choice.Score<=0 then a.Status='Smart Play • '..(decision or smart.Reason or 'waiting for cash / available upgrades') return end
  local target=choice.Tower
  if target then
   smart.Reason='Upgrade '..tostring(Units[target.Id].name or target.Id)
   send({Action='Upgrade',UUID=target.UUID,UnitId=target.Id,CF=cfData(target.CF),Target=target.Upgrade+1},target.Unit,'smart')
  else
   local u=choice.Unit smart.Reason='Place '..tostring(u.Data.name or u.Id)
   send({Action='Place',UUID=u.UUID,UnitId=u.Id,CF=cfData(choice.CF)},nil,'smart')
   if a.Pending then a.Pending.PlacementKey=choice.Key end
  end
  a.AttachInvestment(choice)
  a.Status='Smart Play • '..smart.Reason
 end



(function()
 function a.NewRecoveryState() return {Records={},ByModel={},NextId=0,Enabled=false,Status='Off',Job=game.JobId,NextScan=0} end
 a.Recovery=a.NewRecoveryState()
 -- Reconcile identities before marking losses: a replacement can arrive in the same frame.
 function a.SyncRecovery(state,live,now)
  local seen={} for _,t in ipairs(live) do seen[t.Unit]=true end
  for _,t in ipairs(live) do
   local record=state.ByModel[t.Unit]
   if not record then
    local nearest=1.25
    for _,candidate in ipairs(state.Records) do
     if candidate.Model==t.Unit then record=candidate break end
     if candidate.UUID==t.UUID and not seen[candidate.Model] then
      local distance=(flat(CFrame.new(unpack(candidate.CF)).Position)-flat(t.CF.Position)).Magnitude
      if distance<nearest then record=candidate nearest=distance end
     end
    end
    if record then
     state.ByModel[record.Model]=nil record.Model=t.Unit record.Recovering=true record.NextTry=0
    else
     state.NextId+=1 record={Id=t.Id,UUID=t.UUID,CF=cfData(t.CF),Target=t.Upgrade,Model=t.Unit,Serial=state.NextId}
     state.Records[#state.Records+1]=record
    end
    state.ByModel[t.Unit]=record
   end
   record.Target=math.max(record.Target or 0,t.Upgrade or 0) record.Current=t.Upgrade
   record.Missing=false record.MissingAt=nil record.LastSeen=now
   if record.Recovering and record.Current>=record.Target then record.Recovering=false record.Completed=(record.Completed or 0)+1 end
  end
  for _,record in ipairs(state.Records) do
   if not seen[record.Model] then record.Missing=true record.MissingAt=record.MissingAt or now end
  end
  return state
 end
 function a.RecoveryBaseCF(t)
  local hitbox=t.Unit:FindFirstChild('_hitbox') local position=t.CF.Position
  if hitbox and hitbox:IsA('BasePart') then position=hitbox.Position end
  local hit
  if C.Smart and a.RaycastSmartGround then hit=a.RaycastSmartGround(position,Units[t.Id])
  else hit=Placement.raycast(position+Vector3.new(0,100,0),Vector3.new(0,-220,0))end
  if hit and Placement.is_valid_raycast_hit(hit.Instance,Units[t.Id]) then position=hit.Position
  elseif hitbox and hitbox:IsA('Part') then
   local height=hitbox.Shape==Enum.PartType.Cylinder and hitbox.Size.X or hitbox.Size.Y
   position=hitbox.Position-Vector3.new(0,height/2-.05,0)
  end
  local goal=t.Stats:FindFirstChild('formation_goal')
  local rotation=goal and goal:IsA('BasePart') and goal.CFrame.Rotation or t.CF.Rotation
  return CFrame.new(position)*rotation
 end
 function a.ResetRecovery()
  a.Recovery=a.NewRecoveryState() a.RecoveryReserveCash=0
 end
 function a.ObserveRecovery(force)
  local state=a.Recovery local now=os.clock()
  if not C.Restore then if state.Enabled then a.ResetRecovery() end return end
  local started=workspace:FindFirstChild('_waves_started')
  local paused=macroBusy() or a.Capture or (C.Plan and not a.Completed)
  if Loader.IsLobby or api.MatchEnded or (started and not started.Value) or paused then
   if state.Enabled or #state.Records>0 then a.ResetRecovery() state=a.Recovery end
   state.Status=paused and 'Paused for Plan / Macro / Capture' or 'Waiting for active match' return
  end
  if not force and now<state.NextScan then return end state.NextScan=now+.2 state.Enabled=true
  for i=#state.Records,1,-1 do local record=state.Records[i]
   if a.IsIntentionalFarmSale and a.IsIntentionalFarmSale(record.Model) then state.ByModel[record.Model]=nil table.remove(state.Records,i) end
  end
  local live={}
  for _,t in ipairs(towers()) do if not (a.IsIntentionalFarmSale and a.IsIntentionalFarmSale(t.Unit)) then
   local record=state.ByModel[t.Unit]
   live[#live+1]={Unit=t.Unit,Id=t.Id,UUID=t.UUID,Upgrade=t.Upgrade,CF=record and CFrame.new(unpack(record.CF)) or a.RecoveryBaseCF(t)}
  end end
  a.SyncRecovery(state,live,now)
  local missing=0 local upgrading=0
  for _,record in ipairs(state.Records) do if record.Missing then missing+=1 elseif record.Recovering then upgrading+=1 end end
  state.Status=missing>0 and ('Missing '..missing..' • waiting to restore') or upgrading>0 and ('Restoring upgrades • '..upgrading..' unit(s)') or ('Watching '..#state.Records..' units')
 end
 function a.RecoveryReservations(id)
  if a.FarmClosing and farm(id) then return 0 end
  if not C.Restore or not a.Recovery.Enabled then return 0 end
  local count=0 local collection=game:GetService('CollectionService')
  for _,record in ipairs(a.Recovery.Records) do if record.Id==id then
   local missing=record.Missing
   if typeof(record.Model)=='Instance' then
    local stats=record.Model:FindFirstChild('_stats')
    missing=val(stats,'player')~=player or val(stats,'parent_unit')~=nil or record.Model.Parent~=workspace:FindFirstChild('_UNITS') or not collection:HasTag(record.Model,'nonminion_units') or val(stats,'state')=='dead' or collection:HasTag(record.Model,'dying_units')
   end
   if missing then
    record.Missing=true record.MissingAt=record.MissingAt or os.clock() a.Recovery.NextScan=0 count+=1
   end
  end end
  return count
 end
 function a.ConfirmRecoveryPlace(pending)
  local record=pending.RecoveryRecord if not record then return false end
  for _,t in ipairs(towers()) do if t.UUID==record.UUID then
   local position=a.RecoveryBaseCF(t).Position
   if (flat(position)-flat(CFrame.new(unpack(record.CF)).Position)).Magnitude<1.25 then
    local previous=record.Model
    if a.Recovery.ByModel[previous]==record then a.Recovery.ByModel[previous]=nil a.Recovery.ByModel[t.Unit]=record end
    record.Model=t.Unit record.Missing=false record.Current=t.Upgrade return true
   end
  end end
  return false
 end
 function a.RecoveryConfirmed(pending)
  local record=pending.RecoveryRecord if not record then return end
  record.NextTry=0 a.Recovery.NextScan=0
 end
 function a.RecoveryDeclined(pending)
  local record=pending.RecoveryRecord if record then record.NextTry=os.clock()+1 a.Recovery.Status='Waiting for original position / unit limit' end
 end
 function a.RestoreStep()
  a.RecoveryReserveCash=0
  if not C.Restore or not a.Recovery.Enabled or a.Pending then return false end
  local all=towers() local byModel={} for _,t in ipairs(all) do byModel[t.Unit]=t end
  local context=enemyContext() local combat=a.GetCombatPlan(all,context)
  local now=os.clock() local candidates={} local blocked=false local equippedByUUID={}
  for _,u in ipairs(equipped()) do equippedByUUID[u.UUID]=u end
  if C.Upgrade then for _,t in ipairs(all) do local r=role(t.Id) if (r=='farm' or r=='damage') and price(t,t.Upgrade+1) then blocked=true end end end
  for _,record in ipairs(a.Recovery.Records) do
   local r=role(record.Id) local t=byModel[record.Model]
   local needs=not (a.FarmClosing and r=='farm') and (record.Missing or record.Recovering and t and t.Upgrade<record.Target)
   if needs and a.TeamPolicy then
    if record.Missing then needs=a.TeamPolicy.AllowsPlace(record.Id,all,true)
    elseif t then needs=a.TeamPolicy.AllowsUpgrade(record.Id,t.Upgrade)end
   end
   if needs and (r=='farm' or r=='damage') then blocked=true end
   if needs and now>=(record.NextTry or 0) then
    if record.Missing and now-(record.MissingAt or now)>=1.5 then
     local u=equippedByUUID[record.UUID]
     if not u then a.Recovery.Status='Equip original unit to restore • '..tostring(record.Id)
     else
      local step={Action='Place',UUID=record.UUID,UnitId=record.Id,CF=record.CF,Recovery=true}
      local valid,reason=a.CheckPlacementRequest(step)
      if valid then candidates[#candidates+1]={Role=r,Kind='Place',Score=10,Cost=spawnPrice(u.Data),Unit=u,Record=record,Step=step}
      else a.Recovery.Status=reason record.NextTry=now+.75 end
     end
    elseif t and record.Recovering and a.CanUpgrade(t.Unit) then
     local cost=price(t,t.Upgrade+1)
     if cost then candidates[#candidates+1]={Role=r,Kind='Upgrade',Score=10,Cost=cost,Tower=t,Record=record,
      Step={Action='Upgrade',UUID=record.UUID,UnitId=record.Id,CF=record.CF,Target=t.Upgrade+1,Recovery=true}} end
    end
   end
  end
  local choice,reason=a.SelectInvestment(candidates,combat,cash(),smart.Budget,blocked)
  if not choice then
   local reserve=math.huge
   for _,candidate in ipairs(candidates) do
    local eligible=combat.Mode=='Defense' and candidate.Role=='damage' or combat.Mode~='Defense' and ((candidate.Role=='farm' or candidate.Role=='damage') or not blocked)
    if eligible then reserve=math.min(reserve,candidate.Cost) end
   end
   if reserve<math.huge then a.RecoveryReserveCash=reserve a.Recovery.Status='Saving for recovery • '..math.ceil(reserve) end
   return false
  end
  send(choice.Step,choice.Tower and choice.Tower.Unit,'restore')
  if a.Pending then
   a.Pending.RecoveryRecord=choice.Record a.AttachInvestment(choice)
   a.Recovery.Status=choice.Kind=='Place' and 'Replacing unit at original position' or ('Restoring upgrade '..choice.Step.Target..' / '..choice.Record.Target)
   a.Status=a.Recovery.Status return true
  end
  return false
 end
 -- Keep recovery alongside the existing Auto Play switches.
 for _,item in ipairs(page:GetChildren()) do
  if item:IsA('GuiObject') and item.Position.Y.Offset>=398 then item.Position+=UDim2.fromOffset(0,44) end
 end
 for _,name in ipairs({'AutoPlayControls','AutoPlanControls'}) do local item=page:FindFirstChild(name) if item then item.Size+=UDim2.fromOffset(0,44) end end
 state.Position+=UDim2.fromOffset(0,44)
 paints[#paints+1]=switch('Play_Restore','Restore Sold / Removed Units','',316,function() return C.Restore end,function(value)
  C.Restore=value a.ResetRecovery() a.ObserveRecovery(true) a.Save()
 end,26)
 root:FindFirstChild('Play_Restore').Parent=page
 page.CanvasSize=UDim2.fromOffset(0,1178)
 a.PaintRecovery=function() if C.Restore then state.Text..='\n'..a.Recovery.Status end end
end)()


;(function()
 local sale={Paid={},Intentional=setmetatable({},{__mode='k'}),LastWave=wave(),Entered=os.clock(),Retry=setmetatable({},{__mode='k'})}
 a.FarmSale=sale
 local waveData=Loader.load_data(script,'Waves')
 function a.ResolveFinalFarmWave(level,data,current,lastWave)
  if lastWave==true and type(current)=='number'and current>0 then return current end
  if type(level)~='table' then return end
  local bound=tonumber(level._override_infinite_bound_waves)
  if bound and bound>0 then return bound end
  local config=level._override_waves or(data or{})[level.waves or level.id]
  if type(config)~='table'or config.infinite then return end
  if type(config.waves)=='table'and #config.waves>0 then return #config.waves end
 end
 function a.FinalFarmWave(level,data)
  local native=workspace:FindFirstChild('_is_last_wave')
  return a.ResolveFinalFarmWave(level,data,not Loader.IsLobby and wave()or 0,native and native:IsA('BoolValue')and native.Value==true)
 end

 function a.IsIntentionalFarmSale(model)return sale.Intentional[model]==true end
 function a.FarmPayoutReady(paid,current,final,entered,now)
  return type(final)=='number' and current==final and type(paid)=='table' and paid.Time>=entered-2 and now-paid.Time>=.4 and(paid.Wave==final or paid.Wave==final-1)
 end
 function a.ObserveFarmPayout(...)
  if not a.Alive then return end
  local args={...}
  local function isPayout(item,depth)
   if item=='farm_money'or item=='farm_resource_generated'then return true end
   if type(item)~='table'or depth>4 then return false end
   local count=0
   for _,child in pairs(item)do count+=1;if count>64 then break end;if isPayout(child,depth+1)then return true end end
   return false
  end
  if not isPayout(args,0)then return end
  local visited={}
  local function findUnit(item,depth)
   if typeof(item)=='Instance' then
    local model=item:IsA('Model')and item or item:FindFirstAncestorOfClass('Model')
    local stats=model and model:FindFirstChild('_stats')
    if model and val(stats,'player')==player and farm(val(stats,'id'))then sale.Paid[model]={Wave=wave(),Time=os.clock()}end
   elseif type(item)=='table'and depth<4 and not visited[item]then
    visited[item]=true;local count=0;for _,child in pairs(item)do count+=1;if count>24 then break end;findUnit(child,depth+1)end
   end
  end
  findUnit(args,0)
 end
 local events=game.ReplicatedStorage:FindFirstChild('endpoints');events=events and events:FindFirstChild('server_to_client')
 if events then for _,name in ipairs({'fx_start','fx_start__unreliable'})do local event=events:FindFirstChild(name);if event and event:IsA('RemoteEvent')then connect(event.OnClientEvent,a.ObserveFarmPayout)end end end
 for _,item in ipairs(page:GetChildren())do if item:IsA('GuiObject')and item.Position.X.Offset<450 and item.Position.Y.Offset>=354 then item.Position+=UDim2.fromOffset(0,44)end end
 local controls=page:FindFirstChild('AutoPlayControls');if controls then controls.Size+=UDim2.fromOffset(0,44)end
 toggle('SellFinalFarm','Auto Sell Farm • Final Payout',26,360)
 function a.UpdateFarmSale()
  local current=wave()
  if Loader.IsLobby or current<sale.LastWave or(sale.Ended and not api.MatchEnded)then
   sale.Paid={};sale.Intentional=setmetatable({},{__mode='k'});sale.Retry=setmetatable({},{__mode='k'})
  end
  if current~=sale.LastWave then sale.Entered=os.clock()end
  sale.LastWave=current;sale.Ended=api.MatchEnded;sale.Final=a.FinalFarmWave(Loader.LevelData,waveData)
  a.FarmClosing=C.SellFinalFarm and not Loader.IsLobby and sale.Final~=nil and current==sale.Final
 end
 function a.CanSellFinalFarm(id,unit)
  if not C.SellFinalFarm or Loader.IsLobby or api.MatchEnded or not unit or not unit.Parent then return false end
  local stats=unit:FindFirstChild('_stats');local actual=val(stats,'id')
  if actual~=id or val(stats,'player')~=player or val(stats,'state')=='dead' or not farm(actual)or(Units[actual]or{}).unsellable then return false end
  if role(actual)=='buff'then return false end
  local final=a.FinalFarmWave(Loader.LevelData,waveData)
  return a.FarmPayoutReady(sale.Paid[unit],wave(),final,sale.Entered,os.clock())
 end
 function a.SellFinalFarmStep()
  if not C.SellFinalFarm or not a.FarmClosing or a.Pending or C.Plan and not a.Completed then return false end
  for _,t in ipairs(towers())do if os.clock()>=(sale.Retry[t.Unit]or 0)and a.CanSellFinalFarm(t.Id,t.Unit)then
   sale.Retry[t.Unit]=os.clock()+3
   send({Action='Sell',UUID=t.UUID,UnitId=t.Id,CF=cfData(t.CF)},t.Unit,'farm-sale')
   if a.Pending and a.Pending.Kind=='farm-sale'and a.Pending.Unit==t.Unit then sale.Intentional[t.Unit]=true end
   a.Status='Selling farm • final payout confirmed';return a.Pending~=nil
  end end
  return false
 end
end)()

-- Mode-specific team policy and six-slot editor.
;(function()
 local prior=env.FyrelithTeamControl if prior and prior.Stop then prior.Stop()end
 local T={Alive=true,Mode='Story',Profiles={},Version=2};env.FyrelithTeamControl=T
 -- Instance-owned signals disconnect when their UI is destroyed. Do not retain
 -- every rebuilt card/slider connection in the main window's connection list.
 local function connect(signal,callback)return signal:Connect(callback)end
 local file='FyrelithTeamControl_'..player.UserId..'_'..game.GameId..'.json'
 local modeList={'Story','Infinite','Legend Stage','Raid','Challenge','Daily Challenge','Event','Summer Hunt','Maps / Items','Dungeon','Portal','Infinity Mansion','Tournament'}
 pcall(function()local d=H:JSONDecode(readfile(file));if type(d.Profiles)=='table'then T.Profiles=d.Profiles end;if table.find(modeList,d.Mode)then T.Mode=d.Mode end end)
 function T.Save()local ok,e=pcall(function()writefile(file,H:JSONEncode({Version=2,Mode=T.Mode,Profiles=T.Profiles}))end);T.SaveError=not ok and tostring(e)or nil;return ok end
 function T.Number(n,fallback,lo,hi)
  n=tonumber(n);if not n or n~=n or n==math.huge or n==-math.huge then n=fallback end
  return math.clamp(math.floor(n+.5),lo,hi)
 end
 function T.Limits(id,uuid)
  local d=Units[id]or{};local upgrades=type(d.upgrade)=='table'and #d.upgrade or 0
  local extra=0
  if id=='gojo_evolved' and upgrades>0 then
   local function inspect(key)
    local unit=key and U.session.collection:get_unit_by_uuid(key)
    if unit and unit.unit_id==id then
     extra=math.max(extra,math.max(0,math.floor(tonumber(unit._unique_data and unit._unique_data.gojo_unlimited_upgrades)or 0)))
    end
   end
   if uuid then inspect(uuid)
   else for _,unit in ipairs(equipped(true))do if unit.Id==id then inspect(unit.UUID)end end end
  end
  return math.min(a.IsLimitedBuff(id)and 4 or math.huge,math.max(1,tonumber(d.spawn_cap)or 1)),upgrades+extra
 end
 function T.ActiveMode()
  local l=Loader.LevelData;if type(l)=='table'and l.id=='summer2_event'then return 'Summer Hunt'end
  return api.DetectTeamMode and api.DetectTeamMode(type(l)=='table'and l.id or l)or 'Story'
 end
 if not Loader.IsLobby then T.Mode=T.ActiveMode()end
 function T.RuntimeCap(id,data)
  return math.min(a.IsLimitedBuff(id)and 4 or math.huge,tonumber(data and data.spawn_cap)or 1)
 end
 a.PlacementCap=T.RuntimeCap
 function a.NativeUpgradeInfo(t)
  if not t or not t.Unit or not t.Unit.Parent then return end
  local max=tonumber(val(t.Stats,'max_upgrade'))
  if max and t.Upgrade>=max then return end
  local g=env.FyrelithGameReady.Services.GUIService
  local collectionUnit=U.get_equipped_unit_by_uuid(t.UUID)
  local ok,info,reached=pcall(g.get_next_upgrade_info,t.Unit,collectionUnit or{})
  if not ok then ok,info,reached=pcall(g.get_next_upgrade_info,t.Unit,U.session)end
  if ok and type(info)=='table'and type(info.cost)=='number'and not reached then return info end
  a.UpgradePricingError=not ok and tostring(info)or'Native upgrade price unavailable'
 end
 function T.Get(id,mode)
  if type(id)~='string'then return {Place=false,MaxPlaced=0,UpgradeTo=0,Priority=6,AutoSkill=false,FromWave=1,BossOnly=false}end
  mode=mode or T.ActiveMode();local p=T.Profiles[mode];if type(p)~='table'then p={} T.Profiles[mode]=p end
  local cap,upgrades=T.Limits(id);local defaultCap=T.Number((Units[id]or{}).spawn_cap,6,1,30)
  local c=p[id];if type(c)~='table'then c={Place=true,MaxPlaced=defaultCap,UpgradeTo=(a.IsLimitedBuff(id)and id~='aqua_evolved')and 0 or upgrades,Priority=1,AutoSkill=false,FromWave=1,BossOnly=false};p[id]=c end
  c.Place=c.Place~=false;c.AutoSkill=c.AutoSkill==true;c.BossOnly=c.BossOnly==true
  c.MaxPlaced=T.Number(c.MaxPlaced,cap,0,cap)
  if c.UpgradeTo==nil then c.UpgradeTo=(a.IsLimitedBuff(id)and id~='aqua_evolved')and 0 or upgrades end
  c.Priority=T.Number(c.Priority,1,1,6);c.FromWave=T.Number(c.FromWave,1,1,999)
  return c
 end
 function T.AllowsPlace(id,all,recovery)
  local c=T.Get(id);if not c.Place then return false end
  all=all or towers()
  local n=0;for _,t in ipairs(all)do if t.Id==id then n+=1 end end
  local reserved=a.RecoveryReservations and a.RecoveryReservations(id)or 0
  -- A replacement consumes its existing reservation instead of reserving twice.
  if recovery then reserved=math.max(0,reserved-1)end
  return n+reserved<c.MaxPlaced
 end
 function T.AllowsUpgrade(id,level)return level<T.Get(id).UpgradeTo end
 function T.SetUpgradeTarget(id,target,mode,uuid)
  local c=T.Get(id,mode);local _,maximum=T.Limits(id,uuid)
  c.UpgradeTo=T.Number(target,c.UpgradeTo,0,maximum)
  return c.UpgradeTo
 end
 function T.HasBoss()
  local f=workspace:FindFirstChild('_UNITS');if not f then return false end
  for _,m in ipairs(f:GetChildren())do local s=m:FindFirstChild('_stats');if s and val(s,'player')~=player and (val(s,'is_boss')==true or m:GetAttribute('is_boss')==true or game:GetService('CollectionService'):HasTag(m,'boss_units')) and val(s,'state')~='dead'then return true end end
  return false
 end
 function T.HasAutoSkills()for _,u in ipairs(equipped(true))do if T.Get(u.Id).AutoSkill then return true end end return false end
 function T.AllowsSkill(id)local c=T.Get(id);return c.AutoSkill and wave()>=c.FromWave and(not c.BossOnly or T.HasBoss())end
 local validate=a.ValidateAutoAction
 function a.ValidateAutoAction(step,unit,kind)
  if step.Action=='Upgrade'and(kind=='smart'or kind=='auto')and step.UnitId~='aqua_evolved'and a.IsLimitedBuff(step.UnitId)then return false,'Buff rotation units are not automatically upgraded'end
  if step.Action=='Upgrade' then
   local stats=unit and unit:FindFirstChild('_stats')
   local id=step.UnitId or val(stats,'id')
   local current=tonumber(val(stats,'upgrade'))or 0
   if not T.AllowsUpgrade(id,current)or(tonumber(step.Target)or(current+1))>T.Get(id).UpgradeTo then
    return false,'Team • selected upgrade step reached'
   end
  end
  -- Recorded plans retain their own explicit placement and upgrade instructions.
  if kind~='plan'then
   if step.Action=='Place'and not T.AllowsPlace(step.UnitId,nil,step.Recovery==true)then return false,'Team • placement limit / disabled'end
  end
  return validate(step,unit,kind)
 end
 local can=a.CanUpgrade
 function a.CanUpgrade(unit)local s=unit and unit:FindFirstChild('_stats');return T.AllowsUpgrade(val(s,'id'),tonumber(val(s,'upgrade'))or 0)and can(unit)end
 a.TeamPolicy=T
 local ink=Color3.fromRGB(15,18,25);local field=Color3.fromRGB(27,31,41);local edge=Color3.fromRGB(55,64,81)
 local function box(parent,name,x,y,w,h)
  local f=new('Frame',{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=ink,BorderSizePixel=0,ZIndex=5},parent);round(f,12);new('UIStroke',{Color=edge,Transparency=.35,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f);return f
 end
 local function text(parent,name,value,x,y,w,h,size,bold)local t=label(parent,name,value,x,y,w,h,size or 13,bold or false,parent.ZIndex+2);t.TextColor3=white;return t end
 local function btn(parent,name,value,x,y,w,h,fn)
  local b=new('TextButton',{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=field,BorderSizePixel=0,TextColor3=white,TextSize=12,Font=Enum.Font.GothamMedium,ZIndex=parent.ZIndex+3},parent);round(b,8);connect(b.Activated,fn);return b
 end
 -- Insert Team directly after Auto Play in the left column.
 local controls=page:FindFirstChild('AutoPlayControls')
 local teamY=controls and(controls.Position.Y.Offset+controls.Size.Y.Offset+18)or 8
 local bottom=teamY+453
 for _,f in ipairs(page:GetChildren())do if f:IsA('GuiObject')then
  if f.Position.X.Scale==0 and f.Position.X.Offset<454 and f.Position.Y.Offset>=teamY and not f:GetAttribute('ViewportPopup')then f.Position+=UDim2.fromOffset(0,471)end
  if f.Visible and not f:GetAttribute('ViewportPopup')then bottom=math.max(bottom,f.Position.Y.Offset+f.Size.Y.Offset)end
 end end
 local panel=box(page,'TeamControl',8,teamY,438,453);T.Panel=panel
 text(panel,'Title','TEAM',18,12,300,26,16,true)
 local accent=new('Frame',{Position=UDim2.fromOffset(8,17),Size=UDim2.fromOffset(3,16),BorderSizePixel=0,BackgroundColor3=colors.accent,ZIndex=7},panel);round(accent,2)
 text(panel,'ModeLabel','Mode',18,53,100,28)
 local modeButton;local menu;local modeArrow
 local function closeModeMenu()if menu then menu:Destroy();menu=nil end;if modeArrow then modeArrow.Rotation=0 end end
 local redraw,openUnit
 modeButton=btn(panel,'Mode','Story',200,51,220,30,function()
  if menu then closeModeMenu();return end
  menu=new('ScrollingFrame',{Name='TeamModeMenu',Position=UDim2.fromOffset(160,85),Size=UDim2.fromOffset(260,240),BackgroundColor3=ink,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,#modeList*32+8),ZIndex=40},panel);round(menu,9)
  modeArrow.Rotation=180
  for i,m in ipairs(modeList)do btn(menu,'Mode'..i,m,4,4+(i-1)*32,242,29,function()T.Mode=m;T.Save();closeModeMenu();redraw();if T.Reopen then T.Reopen()end end)end
 end)
 modeButton.TextXAlignment=Enum.TextXAlignment.Left
 new('UIPadding',{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,32)},modeButton)
 modeArrow=new('ImageLabel',{Name='Chevron',BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,20,.5,0),Size=UDim2.fromOffset(12,12),Image='rbxassetid://7733717447',ImageColor3=muted,ZIndex=modeButton.ZIndex+2,Active=false},modeButton)
 local status=text(panel,'Status','',18,88,402,20,11)
 status.TextTruncate=Enum.TextTruncate.AtEnd
 text(panel,'CopyLabel','Copy settings from Story',18,116,285,30,12)
 btn(panel,'CopyFromStory','Copy',342,116,78,30,function()
  if T.Mode=='Story'then status.Text='Story is already selected';return end
  T.Profiles[T.Mode]=H:JSONDecode(H:JSONEncode(T.Profiles.Story or{}));T.Save();redraw();status.Text='Copied Story settings to '..T.Mode
 end)
 local G=Loader.load_client_service(script,'GUIService')
 local function portrait(parent,id,w,h)
  local v=new('ViewportFrame',{Name='Portrait',Position=UDim2.fromOffset(5,5),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Ambient=Color3.fromRGB(225,230,240),LightColor=Color3.new(1,1,1),ZIndex=parent.ZIndex+1},parent)
  task.defer(function()
   local ok,m=pcall(G.make_unit_gui_model,id,nil);if not ok or not m or not m:IsA('Model')then return end;if not v.Parent then m:Destroy();return end
   if tostring(id):lower():find('elyssia',1,true)then for _,child in ipairs(m:GetChildren())do if child.Name=='trides'or child.Name=='elyssia_eel'then child:Destroy()end end end;local world=Instance.new('WorldModel');world.Parent=v;m.Parent=world
   local head=m:FindFirstChild('Head',true);local cf,size=m:GetBoundingBox();local target=head and head.Position or cf.Position;local look=head and head.CFrame.LookVector or Vector3.new(0,0,-1)
   local camera=Instance.new('Camera');camera.FieldOfView=34;camera.CFrame=CFrame.lookAt(target+look*(head and math.max(4,head.Size.Y*4)or size.Magnitude),target);camera.Parent=v;v.CurrentCamera=camera
  end)
 end
 local cards={};local signature;local cardSignature
 redraw=function()
  modeButton.Text=T.Mode;status.Text=Loader.IsLobby and 'In lobby • settings apply with Auto Play' or 'Playing: '..T.ActiveMode()..(T.Mode~=T.ActiveMode()and' • editing a different mode'or' • current team settings')
  local slots={};for _,u in ipairs(equipped(true))do slots[u.Slot]=u end
  local nextSignature='';for i=1,6 do local u=slots[i];nextSignature..=i..':'..(u and u.UUID or '')..';'end
  if nextSignature==cardSignature then
   for i,b in ipairs(cards)do local u=slots[i];local d=u and T.Get(u.Id,T.Mode);b.Details.Text=d and('P'..d.Priority..' · x'..d.MaxPlaced..' · Up '..d.UpgradeTo)or'Empty'end
   return
  end
  cardSignature=nextSignature
  for _,c in ipairs(cards)do c:Destroy()end;table.clear(cards)
  for i=1,6 do
   local u=slots[i];local x=14+((i-1)%3)*138;local y=158+math.floor((i-1)/3)*142
   local b=btn(panel,'Slot'..i,'',x,y,130,132,function()if u then openUnit(u)end end);b.ZIndex=8;b:SetAttribute('AtelierOwned',true);b:SetAttribute('UnitUUID',u and u.UUID or '');cards[#cards+1]=b
   if u then portrait(b,u.Id,120,82)else text(b,'Empty',tostring(i),10,25,110,55,26,true).TextXAlignment=Enum.TextXAlignment.Center end
   local badge=text(b,'Slot',tostring(i),7,5,22,20,11,true);badge.BackgroundColor3=ink;badge.BackgroundTransparency=.08;badge.ZIndex=14;round(badge,5);badge.TextXAlignment=Enum.TextXAlignment.Center
   local d=u and T.Get(u.Id,T.Mode)
   local n=text(b,'UnitName',u and(u.Data.name or u.Id)or'Slot '..i,9,91,112,18,11,true);n.TextTruncate=Enum.TextTruncate.AtEnd
   text(b,'Details',d and('P'..d.Priority..' · x'..d.MaxPlaced..' · Up '..d.UpgradeTo)or'Empty',9,111,112,16,10).TextColor3=muted
  end
 end
 local overlay,drag,connections=nil,nil,{}
 local selectedUnit,advanced=false,false
 local automation,right,advancedButton
 local archived={}
 local cardHover=setmetatable({},{__mode='k'})
 function T.ClearCardHover()
  table.clear(cardHover)
  if T.PaintCards then T.PaintCards()end
 end
 local inlineBindings={}
 local sliderTargets={}
 local function bind(obj,property,role)
  local props=inlineBindings[obj]or{};inlineBindings[obj]=props;props[property]=role;obj[property]=colors[role]
 end
 local function finishDrag()
  if not drag then return end
  page.ScrollingEnabled=true;drag=nil;T.Save();redraw()
 end
 T.EndSliderDrag=finishDrag
 function T.BeginSliderAt(input)
  if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return false end
  if not overlay or not overlay.Visible or not page.Visible or not gui.Window.Visible then return false end
  local position=input.Position
  local p,s=page.AbsolutePosition,page.AbsoluteSize
  if position.X<p.X or position.X>p.X+s.X or position.Y<p.Y or position.Y>p.Y+s.Y then return false end
  for _,target in ipairs(sliderTargets)do
   local hit=target.Hit;local origin,size=hit.AbsolutePosition,hit.AbsoluteSize
   if hit.Parent and position.X>=origin.X and position.X<=origin.X+size.X and position.Y>=origin.Y and position.Y<=origin.Y+size.Y then
    return target.Start(input)
   end
  end
  return false
 end
 -- Sliders receive input from their own hit area; global input also fired through overlapping toggles.
 local function close()
  table.clear(sliderTargets)
  finishDrag();if overlay then overlay:Destroy();overlay=nil end
  for obj in pairs(inlineBindings)do if not obj.Parent then inlineBindings[obj]=nil end end
  T.Editor=nil;T.SelectedUUID=nil;T.PaintEditor=nil
 end
 local function themedBox(parent,name,x,y,w,h)
  local f=box(parent,name,x,y,w,h);f.ZIndex=math.max(8,parent.ZIndex+1);f.BackgroundColor3=colors.card;bind(f,'BackgroundColor3','card')
  local edge=f:FindFirstChildOfClass('UIStroke');if edge then bind(edge,'Color','line')end
  return f
 end
 -- Lucide assets: frappedevs/lucideblox and latte-soft/lucide-roblox (MIT/ISC).
 -- Static sprite coordinates only; no remote scripts are loaded.
 local glyphs={Gear={7734053495},Cube={7733917120},Upgrade={7733671663},Team={7743876054},Boss={7734058599},Sliders={7734058803},Brain={16898616757,0,257},Skill={16898735175,514,514}}
 local function glyph(parent,kind,x,y,size)
  local d=glyphs[kind]
  local img=new('ImageLabel',{Name='Glyph'..kind,Image='rbxassetid://'..d[1],BackgroundTransparency=1,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),ImageColor3=colors.accent,ZIndex=parent.ZIndex+2,Active=false,ScaleType=Enum.ScaleType.Fit},parent)
  if d[2]then img.ImageRectOffset=Vector2.new(d[2],d[3]);img.ImageRectSize=Vector2.new(256,256)end
  bind(img,'ImageColor3','accent');return img
 end
 local function toggle(parent,key,title,y,get,set)
  local row=btn(parent,key,'',14,y,410,54,function()end);row.BackgroundColor3=colors.field;row.BackgroundTransparency=.40;bind(row,'BackgroundColor3','field')
  local caption=text(row,'Caption',title,56,0,238,54,19);caption.TextSize=19
  glyph(row,({MasterPlace='Cube',Place='Cube',MasterUpgrade='Upgrade',MasterAbilities='Skill',AutoSkill='Skill',MasterSmart='Brain',BossOnly='Boss'})[key]or'Gear',17,15,25)
  local track=new('Frame',{Name='Track',Position=UDim2.fromOffset(304,9),Size=UDim2.fromOffset(92,36),BorderSizePixel=0,ZIndex=12},row);round(track,18)
  local knob=new('Frame',{Name='Knob',Size=UDim2.fromOffset(28,28),BackgroundColor3=white,BorderSizePixel=0,ZIndex=14},track);round(knob,16)
  local state=text(track,'State','',10,0,42,36,14,true);state.ZIndex=15;state.TextSize=14
  local function paint()
   local enabled=get()==true;row:SetAttribute('Enabled',enabled)
   local target=enabled and colors.accent or colors.line
   local position=UDim2.fromOffset(enabled and 60 or 4,4)
   if row:GetAttribute('PaintedState')==nil then track.BackgroundColor3=target;knob.Position=position
   else tween(track,{BackgroundColor3=target});tween(knob,{Position=position})end
   row:SetAttribute('PaintedState',enabled)
   state.Position=UDim2.fromOffset(enabled and 10 or 40,0);state.Text=enabled and 'ON'or'OFF'
  end
  connect(row.Activated,function()set(not get());paint()end);paint();return paint
 end
 openUnit=function(u)
  close();selectedUnit=u;T.SelectedUUID=u.UUID
  local c=T.Get(u.Id,T.Mode);local cap,upgrades=T.Limits(u.Id,u.UUID)
  local togglePainters={}
  overlay=new('Frame',{Name='TeamUnitEditor',Position=UDim2.fromOffset(462,0),Size=UDim2.fromOffset(438,738),BackgroundTransparency=1,ZIndex=8},page);T.Editor=overlay
  local modal=themedBox(overlay,'Modal',0,0,438,738)
  glyph(modal,'Sliders',20,17,25)
  text(modal,'Heading','UNIT SETTINGS',58,12,358,32,21,true).TextSize=21
  local hero=themedBox(modal,'UnitHero',14,58,410,102)
  portrait(hero,u.Id,88,88)
  text(hero,'UnitName',u.Data.name or u.Id,108,14,288,30,22,true).TextSize=22
  text(hero,'Info','Slot '..u.Slot..' / '..T.Mode,108,51,288,26,16).TextColor3=muted
  local function saved()T.Save();redraw()end
  togglePainters[#togglePainters+1]=toggle(modal,'Place','Place this unit',170,function()return c.Place end,function(v)c.Place=v;saved()end)
  local function slider(key,title,y,lo,hi)
   local card=themedBox(modal,key..'Card',14,y,410,84)
   card:SetAttribute('Minimum',lo);card:SetAttribute('Maximum',hi)
   text(card,'Caption',title,16,6,280,28,19).TextSize=19
   local value=new('TextBox',{Name=key..'Value',Position=UDim2.fromOffset(334,29),Size=UDim2.fromOffset(60,40),TextColor3=white,BackgroundColor3=colors.field,TextSize=19,Font=Enum.Font.GothamMedium,ClearTextOnFocus=false,BorderSizePixel=0,ZIndex=14},card);round(value,8);bind(value,'BackgroundColor3','field')
   value.TextEditable=hi>lo
   local hit=btn(card,key..'Slider','',18,36,296,38,function()end);hit.BackgroundTransparency=1
   local track=new('Frame',{Name='Rail',Position=UDim2.fromOffset(0,15),Size=UDim2.new(1,0,0,8),BorderSizePixel=0,BackgroundColor3=colors.line,ZIndex=12},hit);round(track,5);bind(track,'BackgroundColor3','line')
   local fill=new('Frame',{Name='Fill',Size=UDim2.fromScale(0,1),BackgroundColor3=colors.accent,BorderSizePixel=0,ZIndex=13},track);round(fill,5);bind(fill,'BackgroundColor3','accent')
   local knob=new('Frame',{Name='Knob',AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(20,20),BackgroundColor3=white,BorderSizePixel=0,ZIndex=15},track);round(knob,12)
   local function paint()local alpha=hi>lo and(c[key]-lo)/(hi-lo)or 0;fill.Size=UDim2.fromScale(alpha,1);knob.Position=UDim2.fromScale(alpha,.5);value.Text=tostring(c[key])end
   local function set(n)
    if key=='UpgradeTo'then c[key]=T.SetUpgradeTarget(u.Id,n,T.Mode,u.UUID)
    else c[key]=T.Number(n,c[key],lo,hi)end
    paint()
   end
   connect(value.FocusLost,function()set(tonumber(value.Text)or c[key]);saved()end)
   local function begin(input)
    if hi<=lo then return false end
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return false end
    if drag and drag.Input==input then return true end
    finishDrag();page.ScrollingEnabled=false
    drag={Input=input,Set=function(x)set(lo+(hi-lo)*math.clamp((x-hit.AbsolutePosition.X)/math.max(1,hit.AbsoluteSize.X),0,1))end};drag.Set(input.Position.X)
    return true
   end
   sliderTargets[#sliderTargets+1]={Hit=hit,Start=begin}
   connect(hit.InputBegan,begin);paint()
  end
  slider('MaxPlaced','Max placed',234,0,cap)
  slider('UpgradeTo','Upgrade to · Max '..upgrades,326,0,upgrades)
  slider('Priority','Priority',418,1,6)
  slider('FromWave','From wave',510,1,999)
  togglePainters[#togglePainters+1]=toggle(modal,'AutoSkill','Auto skill',612,function()return c.AutoSkill end,function(v)c.AutoSkill=v;saved()end)
  togglePainters[#togglePainters+1]=toggle(modal,'BossOnly','Boss only',674,function()return c.BossOnly end,function(v)c.BossOnly=v;saved()end)
  T.PaintEditor=function()for _,paint in ipairs(togglePainters)do paint()end end
  if advanced then overlay.Visible=false end
  if right then right.Visible=false end
  if T.PaintCards then T.PaintCards()end
 end
 local function ensureSelection()
  if not automation or advanced or not page.Visible or not gui.Window.Visible then return end
  if selectedUnit then
   for _,u in ipairs(equipped(true))do if u.UUID==selectedUnit.UUID then if not overlay then openUnit(u)end;return end end
  end
  selectedUnit=nil
  local slots=equipped(true);table.sort(slots,function(x,y)return x.Slot<y.Slot end)
  if slots[1]then openUnit(slots[1])
  elseif right then right.Visible=true end
 end
 T.Reopen=function()if selectedUnit then openUnit(selectedUnit)end end
 T.EnsureSelection=ensureSelection
 T.SetAdvanced=function(value)
  finishDrag();advanced=false
  page.CanvasPosition=Vector2.new(0,value and 908 or 0)
  ensureSelection()
 end
 task.defer(function()
  if not T.Alive or not page.Parent then return end
  local legacyBottom=948
  for _,obj in ipairs(page:GetChildren())do if obj:IsA('GuiObject')and obj~=panel then
   archived[obj]=obj.Visible;obj.Position+=UDim2.fromOffset(0,948)
   if obj.Visible and not obj:GetAttribute('ViewportPopup')then legacyBottom=math.max(legacyBottom,obj.Position.Y.Offset+obj.Size.Y.Offset)end
  end end
  automation=themedBox(page,'ReferenceAutomation',8,0,438,452)
  glyph(automation,'Gear',20,17,26)
  text(automation,'Title','AUTOMATION',58,12,358,32,21,true).TextSize=21
  local notice=text(automation,'Notice','',16,436,406,16,12);notice.TextSize=12;notice.TextColor3=muted
  local painters={}
  for i,entry in ipairs({{'Place','Auto place'},{'Upgrade','Auto upgrade'},{'Abilities','Auto skill'},{'Smart','Smart play'}})do
   local key=entry[1];painters[#painters+1]=toggle(automation,'Master'..key,entry[2],60+(i-1)*64,function()return C[key]end,function(v)
    local native=page:FindFirstChild('Play_'..key)
    if native and type(getconnections)=='function'then
     for _,connection in ipairs(getconnections(native.Activated))do if connection.Function then connection.Function()end end
    else if v and a.PrepareManualPlay and key~='Smart'then a.PrepareManualPlay(key)end;C[key]=v;a.Save()end
    notice.Text=(C[key]==true)~=v and tostring(a.Status or 'Open Advanced to configure this feature')or''
    if T.PaintAutomation then T.PaintAutomation()end
   end)
  end
  local pathCard=themedBox(automation,'PathPositionControl',14,316,410,112)
  text(pathCard,'Caption','Place along path',12,4,272,28,16,true)
  local value=new('TextBox',{Name='PathPercentValue',Position=UDim2.fromOffset(316,4),Size=UDim2.fromOffset(82,30),Text=tostring(C.Path),TextColor3=white,BackgroundColor3=colors.field,TextSize=17,Font=Enum.Font.GothamMedium,ClearTextOnFocus=false,BorderSizePixel=0,ZIndex=16},pathCard)
  round(value,8);bind(value,'BackgroundColor3','field')
  local hit=btn(pathCard,'PathPercentSlider','',14,36,382,28,function()end);hit.BackgroundTransparency=1
  local rail=new('Frame',{Name='Rail',Position=UDim2.fromOffset(0,10),Size=UDim2.new(1,0,0,8),BackgroundColor3=colors.line,BorderSizePixel=0,ZIndex=12},hit);round(rail,4);bind(rail,'BackgroundColor3','line')
  local fill=new('Frame',{Name='Fill',Size=UDim2.fromScale(C.Path/100,1),BackgroundColor3=colors.accent,BorderSizePixel=0,ZIndex=13},rail);round(fill,4);bind(fill,'BackgroundColor3','accent')
  local knob=new('Frame',{Name='Knob',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(C.Path/100,.5),Size=UDim2.fromOffset(20,20),BackgroundColor3=white,BorderSizePixel=0,ZIndex=15},rail);round(knob,10)
  text(pathCard,'Legend','0% Spawn       50% Middle       100% Your base',14,64,382,20,12)
  local mode=btn(pathCard,'PathPlacementMode','',12,86,386,22,function()
   C.UsePathPosition=not C.UsePathPosition
   if a.Smart then a.Smart.LastAnalysis=-math.huge a.Smart.Context=nil end
   a.Save()
  end);mode.TextSize=12;mode.BackgroundTransparency=1
  local function paintPath()
   if not value:IsFocused() then value.Text=tostring(C.Path)..'%' end
   fill.Size=UDim2.fromScale(C.Path/100,1);knob.Position=UDim2.fromScale(C.Path/100,.5)
   mode.Visible=C.Smart
   mode.Text=C.UsePathPosition and 'Smart area: Path %  ·  click for custom circles' or 'Smart area: Custom circles  ·  click for Path %'
  end
  local pathDrag
  local function movePath(x)
   a.SetPathPercent((x-rail.AbsolutePosition.X)/math.max(1,rail.AbsoluteSize.X)*100,false);paintPath()
  end
  connect(hit.InputBegan,function(input)
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then pathDrag=input;movePath(input.Position.X)end
  end)
  connect(UIS.InputChanged,function(input)
   if pathDrag and (input==pathDrag or pathDrag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then movePath(input.Position.X)end
  end)
  connect(UIS.InputEnded,function(input)
   if pathDrag and (input==pathDrag or pathDrag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1) then pathDrag=nil;a.Save()end
  end)
  connect(UIS.WindowFocusReleased,function()if pathDrag then pathDrag=nil;a.Save()end end)
  connect(value.Focused,function()value.Text=tostring(C.Path)end)
  connect(value.FocusLost,function()a.SetPathPercent(value.Text);paintPath()end)
  painters[#painters+1]=paintPath;paintPath()
  T.PaintAutomation=function()
   for obj,props in pairs(inlineBindings)do if obj.Parent then for property,role in pairs(props)do obj[property]=colors[role]end else inlineBindings[obj]=nil end end
   for _,paint in ipairs(painters)do paint()end
   if T.PaintEditor then T.PaintEditor()end
   if T.PaintCards then T.PaintCards()end
  end
  panel.Position=UDim2.fromOffset(8,466);panel.Size=UDim2.fromOffset(438,400);panel.BackgroundColor3=colors.card;bind(panel,'BackgroundColor3','card')
  panel.Title.TextSize=21;panel.Title.Position=UDim2.fromOffset(58,10);panel.Title.Size=UDim2.fromOffset(350,30)
  glyph(panel,'Team',20,14,26)
  local oldAccent=panel:FindFirstChildWhichIsA('Frame');if oldAccent and oldAccent.Size.X.Offset==3 then oldAccent.Visible=false end
  local modeField=themedBox(panel,'ModeField',14,50,410,42)
  panel.ModeLabel.Parent=modeField
  modeField.ModeLabel.Position=UDim2.fromOffset(12,0);modeField.ModeLabel.Size=UDim2.fromOffset(70,42);modeField.ModeLabel.TextSize=18
  local separator=new('Frame',{Name='Separator',Position=UDim2.fromOffset(84,1),Size=UDim2.new(0,1,1,-2),BackgroundColor3=colors.line,BorderSizePixel=0,ZIndex=modeField.ZIndex+1},modeField);bind(separator,'BackgroundColor3','line')
  modeButton.Parent=modeField;modeButton.Position=UDim2.fromOffset(85,0);modeButton.Size=UDim2.fromOffset(325,42);modeButton.TextSize=19;modeButton.BackgroundTransparency=1;modeButton.ZIndex=modeField.ZIndex+2
  for _,edge in ipairs(modeButton:GetChildren())do if edge:IsA('UIStroke')then edge.Transparency=1 elseif edge:IsA('ImageLabel')then edge.ZIndex=modeButton.ZIndex+2 end end
  status.Visible=false;panel.CopyLabel.Visible=false;panel.CopyFromStory.Visible=false
  local function formatCards()
   for i,b in ipairs(cards)do
    b.Position=UDim2.fromOffset(14+((i-1)%3)*138,104+math.floor((i-1)/3)*140);b.Size=UDim2.fromOffset(130,130)
    b.BackgroundColor3=cardHover[b]and colors.card:Lerp(colors.accent,.16)or colors.card;b.BackgroundTransparency=.12;b.ClipsDescendants=true
    if not b:GetAttribute('TeamHoverBound')then
     b:SetAttribute('TeamHoverBound',true)
     connect(b.MouseEnter,function()cardHover[b]=true;if T.PaintCards then T.PaintCards()end end)
     connect(b.MouseLeave,function()cardHover[b]=nil;if T.PaintCards then T.PaintCards()end end)
    end
    local active=selectedUnit and b:GetAttribute('UnitUUID')==selectedUnit.UUID
    b:SetAttribute('Selected',active==true)
    local rim=b:FindFirstChild('TeamCardRim')
    if not rim then rim=new('UIStroke',{Name='TeamCardRim',ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)end
    rim.Color=active and colors.accent or colors.line;rim.Thickness=active and 1.8 or 1;rim.Transparency=active and .05 or .3
    b.Details.Visible=false;b.Slot.Visible=false;b.UnitName.Position=UDim2.fromOffset(8,99);b.UnitName.Size=UDim2.fromOffset(114,26);b.UnitName.TextSize=16;b.UnitName.TextXAlignment=Enum.TextXAlignment.Center
    local portrait=b:FindFirstChild('Portrait')
    if portrait then
     portrait.Position=UDim2.fromOffset(5,4);portrait.Size=UDim2.fromOffset(120,98)
     local lip=b:FindFirstChild('NameStrip')
     if not lip then lip=new('Frame',{Name='NameStrip',Position=UDim2.fromOffset(1,98),Size=UDim2.new(1,-2,0,31),BackgroundColor3=colors.card,BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=b.ZIndex+1,Active=false},b)end
     lip.BackgroundColor3=colors.card
     b.UnitName.ZIndex=b.ZIndex+3
    elseif b:FindFirstChild('Empty')or b:FindFirstChild('EmptyRing')then
     local ring=b:FindFirstChild('EmptyRing')
     if not ring then
      ring=new('Frame',{Name='EmptyRing',Position=UDim2.fromOffset(43,30),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=b.ZIndex+1,Active=false},b);round(ring,24)
      new('UIStroke',{Color=colors.line,Transparency=.35,Thickness=1},ring)
      local plus=b.Empty;plus.Parent=ring;plus.Name='Plus';plus.Text='+';plus.TextSize=26;plus.Position=UDim2.fromOffset(0,-1);plus.Size=UDim2.fromScale(1,1);plus.TextColor3=muted
     end
     local edge=ring:FindFirstChildOfClass('UIStroke');if edge then edge.Color=colors.line end
     b.UnitName.Text='Empty';b.UnitName.TextColor3=muted;b.UnitName.Position=UDim2.fromOffset(8,88)
    end
   end
  end
  T.PaintCards=formatCards
  connections[5]=UIS.WindowFocusReleased:Connect(T.ClearCardHover)
  connections[6]=page:GetPropertyChangedSignal('CanvasPosition'):Connect(T.ClearCardHover)
  connections[7]=page:GetPropertyChangedSignal('Visible'):Connect(T.ClearCardHover)
  connections[8]=gui.Window:GetPropertyChangedSignal('Visible'):Connect(T.ClearCardHover)
  local old=redraw;redraw=function()old();formatCards()end;T.Refresh=redraw;redraw()
  right=themedBox(page,'EmptyUnitSettings',462,0,438,866)
  text(right,'Heading','UNIT SETTINGS',20,12,398,32,21,true)
  text(right,'Empty','Equip a unit to edit its settings.',24,300,390,80,19).TextWrapped=true
  advancedButton=btn(page,'TeamAdvanced','More controls',286,8,145,32,function()T.SetAdvanced(true)end);advancedButton.ZIndex=30;advancedButton.TextSize=14;advancedButton.BackgroundTransparency=1
  local legacyHeader=themedBox(page,'LegacyAutoPlayHeader',8,900,892,42)
  local legacyTitle=text(legacyHeader,'Title','MORE AUTO PLAY CONTROLS',16,0,640,42,18,true);bind(legacyTitle,'TextColor3','accent')
  local backToTeam=btn(legacyHeader,'BackToTeam','Back to team',720,4,156,34,function()T.SetAdvanced(false)end);backToTeam.TextSize=15;bind(backToTeam,'BackgroundColor3','field')
  -- The team grid is now above the legacy controls; close its former spacer.
  local editor=page:FindFirstChild('AutoPlanEditor')
  local controls=page:FindFirstChild('AutoPlayControls')
  if editor and controls then
   local oldY=editor.Position.Y.Offset
   local target=controls.Position.Y.Offset+controls.Size.Y.Offset+18
   local delta=target-oldY
   for _,obj in ipairs(page:GetChildren())do
    if obj:IsA('GuiObject')and obj.Position.X.Scale==0 and obj.Position.X.Offset<454 and obj.Position.Y.Offset>=oldY and not obj:GetAttribute('ViewportPopup')then obj.Position+=UDim2.fromOffset(0,delta)end
   end
  end
  local buff=root:FindFirstChild('AutoBuffCard')
  if buff then
   local bottom=820
   for _,obj in ipairs(page:GetChildren())do
    if obj:IsA('Frame')and obj.Visible and obj.Position.X.Offset>=454 and not obj:GetAttribute('ViewportPopup')then bottom=math.max(bottom,obj.Position.Y.Offset+obj.Size.Y.Offset)end
   end
   local delta=bottom+18-buff.Position.Y.Offset
   for _,obj in ipairs(root:GetChildren())do
    if obj:IsA('GuiObject')and obj.Name:sub(1,8)=='AutoBuff'then obj.Parent=page;obj.Position+=UDim2.fromOffset(0,delta)end
   end
   local mainBottom=0
   for _,obj in ipairs(root:GetChildren())do if obj:IsA('GuiObject')and obj.Visible and not obj:GetAttribute('ViewportPopup')then mainBottom=math.max(mainBottom,obj.Position.Y.Offset+obj.Size.Y.Offset)end end
   root.Size=UDim2.fromOffset(908,mainBottom+16);main.CanvasSize=UDim2.fromOffset(0,mainBottom+16)
  end
  legacyBottom=0
  for _,obj in ipairs(page:GetChildren())do if obj:IsA('GuiObject')and obj.Visible and not obj:GetAttribute('ViewportPopup')then legacyBottom=math.max(legacyBottom,obj.Position.Y.Offset+obj.Size.Y.Offset)end end
  page.CanvasSize=UDim2.fromOffset(0,legacyBottom+24);page.CanvasPosition=Vector2.zero
  ensureSelection()
 end)

 connections[1]=UIS.InputChanged:Connect(function(input)if drag and(input==drag.Input or drag.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)then drag.Set(input.Position.X)end end)
 connections[2]=UIS.InputEnded:Connect(function(input)if drag and(input==drag.Input or drag.Input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)then finishDrag()end end)
 local firstVisit=true
 connections[3]=page:GetPropertyChangedSignal('Visible'):Connect(function()
  if not page.Visible then close();closeModeMenu()
  else if firstVisit then firstVisit=false;page.CanvasPosition=Vector2.zero end;task.defer(ensureSelection)end
 end)
 connections[4]=gui.Window:GetPropertyChangedSignal('Visible'):Connect(function()if not gui.Window.Visible then close();closeModeMenu()else task.defer(ensureSelection)end end)
 T.Refresh=redraw
 function T.Stop()T.Alive=false;close();closeModeMenu();for _,c in ipairs(connections)do c:Disconnect()end;if panel then panel:Destroy()end end
 redraw();page.CanvasSize=UDim2.fromOffset(0,bottom+16);page.CanvasPosition=Vector2.zero
 task.spawn(function()while T.Alive and a.Alive and api.Alive do
  local s='';local selectedFound=false;for _,u in ipairs(equipped(true))do s..=u.Slot..':'..u.UUID..';';if u.UUID==T.SelectedUUID then selectedFound=true end end
  if T.SelectedUUID and not selectedFound then close()end
  if s~=signature then signature=s;redraw()end;if T.PaintAutomation then T.PaintAutomation()end;ensureSelection();task.wait(2)
 end;if T.Alive then T.Stop()end end)
end)()







 function a.Stop()
  if a.TeamPolicy and a.TeamPolicy.Stop then a.TeamPolicy.Stop()end
  if a.CleanupSmart then a.CleanupSmart() end
  a.Alive=false a.Capture=false a.Save()
  if EP.invoke_server==hook then EP.invoke_server=original end
 end
 local wasEnded=api.MatchEnded local shownStep
 for _,item in ipairs(page:QueryDescendants('TextLabel, TextButton, TextBox')) do item.Font=Enum.Font.GothamBold end
 task.spawn(function()
  while a.Alive and api.Alive and page.Parent do
   local ok,err=pcall(function()
    local currentWave=wave()
    if currentWave<lastWave or (wasEnded and not api.MatchEnded) then reset() end lastWave=currentWave wasEnded=api.MatchEnded
    if a.Capture and api.MatchEnded then savePlan() end
    if a.UpdateFarmSale then a.UpdateFarmSale() end
    if a.ObserveRecovery then a.ObserveRecovery() end
    if C.Walk then walk() end
    if not Loader.IsLobby and not api.MatchEnded then
     local challenge=env.FyrelithAutoChallenge
     if a.SelectingArea or a.EditingRadius then if a.Pending then tickPending()end;a.Status='Adjusting Smart Play area'
     elseif challenge and challenge.Priority and not challenge.InChallenge then a.Status='Waiting for Auto Challenge'
     elseif macroBusy() then a.Status='Waiting for Macro'
     elseif a.Capture then a.Status='Capturing • '..#(plan() and plan().Steps or {})..' steps'
     elseif tickPending() then
     elseif a.SellFinalFarmStep and a.SellFinalFarmStep() then
     elseif a.RestoreStep and a.RestoreStep() then
     elseif C.Plan and not a.Completed then playPlan()
     elseif not C.Plan or (a.Completed and C.AfterPlan) then
      a.Status='Auto Play • watching units and cash'
      if C.Smart then a.SmartStep()
      else
       if C.Upgrade and(C.FarmsFirst or(a.TeamPolicy and a.TeamPolicy.ActiveMode()=='Summer Hunt'))then autoUpgrade() end
       if C.Place and not a.Pending and not (C.FarmsFirst and C.Upgrade and a.InvestmentReserve) then autoPlace() end
       if C.Upgrade and not a.Pending then autoUpgrade() end
      end
      if C.Abilities or(a.TeamPolicy and a.TeamPolicy.HasAutoSkills())then autoAbilities() end
     else a.Status='Plan completed • enable Auto Play After Plan to continue'
     end
    elseif Loader.IsLobby then a.Status='Waiting for match' else a.Status='Match ended • waiting for retry' end
    if a.Pending and a.Pending.Declined and a.Pending.PlacementKey then rejected[a.Pending.PlacementKey]=os.clock() end
    state.Text=a.Status planState.Text=(C.Plan and (a.Completed and 'Completed' or 'Step '..a.Index) or 'Stopped')..' • '..C.Name
    if a.UpdateSmartUI then a.UpdateSmartUI() end
    if a.PaintRecovery then a.PaintRecovery() end
    pathFill.Size=UDim2.fromScale(C.Path/100,1) pathKnob.Position=UDim2.fromScale(C.Path/100,.5)
    selected.Set(C.Name)
    local p=plan() local index=a.SelectedStep or 1 local step=p and p.Steps[index]
    stepPicker.Set(step and (index..'. '..step.Action) or 'No steps')
    if shownStep~=step then shownStep=step waveInput.Text=tostring(step and step.Wave or 0) upgradeInput.Text=tostring(step and step.Target or 1) end
    preview.Text=step and (index..' / '..#p.Steps..' • '..step.Action..'\n'..tostring(Units[step.UnitId] and Units[step.UnitId].name or step.UnitId)..'\nMap: '..tostring(p.Level)..'\nWave: '..tostring(step.Wave or 0)..'  Upgrade: '..tostring(step.Target or '—')) or 'No steps. Create a plan or select a saved plan.'
    for _,paint in ipairs(paints) do paint() end capturePaint()
   end)
   if not ok then a.LastError=tostring(err) a.Status='Waiting • '..tostring(err) end
   task.wait(a.Pending and .05 or C.Smart and .12 or .2)
  end
  a.Stop()
 end)
end




-- Selected travelling-merchant purchases, independently saved in Misc.
;(function()
 local previous=env.FyrelithMerchant if previous and previous.Stop then previous.Stop()end
 local a={Alive=true,Enabled=false,Selected={},Confirmed={},RetryAt={},Failures={},Busy=false,Purchases=0,Rows={}}
 env.FyrelithMerchant=a
 local H=game:GetService('HttpService')local file='FyrelithMerchant_'..player.UserId..'_'..game.GameId..'.json'
 local Items=Loader.load_data(script,'Items')local catalogue=Loader.load_data(script,'ItemsForSale')
 local S
 if Loader.IsLobby then local ok,value=pcall(Loader.load_client_service,script,'TravellingMerchantServiceClient')if ok then S=value end end
 pcall(function()local d=H:JSONDecode(readfile(file))a.Enabled=d.Enabled==true if type(d.Selected)=='table'then for id,on in pairs(d.Selected)do if type(id)=='string'and on==true then a.Selected[id]=true end end end end)
 function a.Save()local ok,err=pcall(function()writefile(file,H:JSONEncode({Enabled=a.Enabled,Selected=a.Selected}))end)a.SaveError=not ok and tostring(err)or nil return ok end
 local page=main.Parent:FindFirstChild('Misc')if not page then return end
 local panel=card('TravellingMerchantCard',462,246,438,442)panel.Parent=page a.Panel=panel
 function a.Layout()
  if not a.Alive or not page.Parent then return end
  local y=8
  for _,name in ipairs({'AutoRedeemCodes','BlackScreenCard','TravellingMerchantCard','PrivacyCard'})do
   local item=page:FindFirstChild(name)
   if item and item:IsA('GuiObject')and item.Visible then item.Position=UDim2.fromOffset(462,y)y+=item.Size.Y.Offset+12 end
  end
  local bottom=y
  for _,item in ipairs(page:GetChildren())do if item:IsA('GuiObject')and item.Visible and not item:GetAttribute('ViewportPopup')then bottom=math.max(bottom,item.Position.Y.Offset+item.Size.Y.Offset+16)end end
  page.CanvasSize=UDim2.fromOffset(0,bottom)
 end
 task.defer(a.Layout)
 connect(page.ChildAdded,function()task.defer(a.Layout)end)
 label(panel,'Heading','Travelling Merchant',18,12,402,28,19,true)
 local subtitle=label(panel,'Hint','Buy only the items you select below.',18,42,402,20,12)subtitle.TextColor3=muted
 local paint=switch('MerchantEnabled','Auto Buy Selected Items','',0,function()return a.Enabled end,function(v)a.Enabled=v;a.RetryAt={};a.Save()end)
 local toggle=root:FindFirstChild('MerchantEnabled')toggle.Parent=panel toggle.Position=UDim2.fromOffset(18,70)
 local search=new('TextBox',{Name='MerchantSearch',Text='',PlaceholderText='Search merchant items…',ClearTextOnFocus=false,Position=UDim2.fromOffset(18,122),Size=UDim2.fromOffset(402,32),BackgroundColor3=colors.field,TextColor3=white,PlaceholderColor3=muted,Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0},panel)round(search,7)bind(search,'BackgroundColor3','field')
 new('UIPadding',{PaddingLeft=UDim.new(0,10)},search)
 local selectedLabel=label(panel,'SelectedCount','0 selected',18,162,194,24,12,true)bind(selectedLabel,'TextColor3','accent')
 local function small(name,text,x,fn)local b=new('TextButton',{Name=name,Text=text,Position=UDim2.fromOffset(x,160),Size=UDim2.fromOffset(94,28),BackgroundColor3=colors.field,TextColor3=white,TextSize=12,Font=Enum.Font.GothamMedium,BorderSizePixel=0},panel)round(b,7)bind(b,'BackgroundColor3','field')connect(b.Activated,fn)return b end
 local list=new('ScrollingFrame',{Name='MerchantItems',Position=UDim2.fromOffset(18,198),Size=UDim2.fromOffset(402,174),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=colors.accent},panel)
 local status=label(panel,'MerchantStatus','Choose items, then enable Auto Buy.',18,386,402,42,12)status.TextWrapped=true status.TextColor3=muted
 local function name(id)return Items[id]and Items[id].name or id end
 local function price(d)
  if d.gold_cost~=nil then return tonumber(d.gold_cost),'Gold','gold_amount'end
  if d.gem_cost~=nil then return tonumber(d.gem_cost),'Gems','gem_amount'end
  return nil,'Unknown currency'
 end
 function a.PlanPurchase(items,bought,confirmed,selected,wallet,now,retryAt)
  local keys={}for uuid,d in pairs(items or{})do if selected[d.id]then keys[#keys+1]=uuid end end table.sort(keys)
  local pending=false local poor=false local unknown=false
  for _,uuid in ipairs(keys)do local d=items[uuid]
   if not bought[uuid]and not confirmed[uuid]then
    pending=true
    local cost,currency,key=price(d)
    if not cost or cost<0 then unknown=true
    elseif(wallet[key]or 0)<cost then poor=true
    elseif now>=(retryAt[uuid]or 0)then return {UUID=uuid,Data=d,Cost=cost,Currency=currency}end
   end
  end
  return nil,not pending and'All selected offers are bought / out of stock'or unknown and'Waiting for supported currency data'or poor and'Not enough Gold / Gems for selected offers'or'Waiting for purchase retry cooldown'
 end
 local function serviceData()
  return S and S.session and S.session.profile_data
 end
 local function isOpen()return S and S.is_open and S.is_open.Value==true end
 local function offerFor(id)
  local chosen
  for uuid,d in pairs(S and S.SELLING_ITEMS or{})do if d.id==id then
   local p=serviceData()local bought=p and p.bought_items or{}
   local offer={UUID=uuid,Data=d,Bought=bought[uuid]or a.Confirmed[uuid]}
   if not offer.Bought then return offer end chosen=offer
  end end
  return chosen
 end
 local function redraw()
  local query=search.Text:lower()local count=0 local selected=0
  for _,row in ipairs(a.Rows)do
   local id=row.Id local picked=a.Selected[id]==true if picked then selected+=1 end
   row.Button.Visible=(name(id)..' '..id):lower():find(query,1,true)~=nil
   if row.Button.Visible then row.Button.Position=UDim2.fromOffset(0,count*44)count+=1 end
   row.Check.Text=picked and'✓'or''row.Check.BackgroundColor3=picked and colors.accent or colors.line
   local offer=offerFor(id)local d=offer and offer.Data or row.Definition local cost,currency=price(d)
   row.Price.Text=cost and(tostring(cost)..' '..currency)or'—'
   row.State.Text=not isOpen()and'Waiting for merchant'or not offer and'Not in stock'or offer.Bought and'Bought'or'Available'
   row.State.TextColor3=offer and not offer.Bought and isOpen()and Color3.fromRGB(115,213,164)or muted
  end
  selectedLabel.Text=selected..' selected'list.CanvasSize=UDim2.fromOffset(0,count*44)paint()
 end
 a.RefreshUI=redraw
 local function buildRows()
  local all={}
  for _,d in pairs(catalogue)do if type(d)=='table'and type(d.id)=='string'then all[d.id]=d end end
  for _,d in pairs(S and S.SELLING_ITEMS or{})do all[d.id]=d end
  for id in pairs(a.Selected)do if not all[id]then all[id]={id=id}end end
  local ids={}for id in pairs(all)do ids[#ids+1]=id end table.sort(ids,function(x,y)return name(x)<name(y)end)
  for _,id in ipairs(ids)do local itemId=id
   local b=new('TextButton',{Name='MerchantItem_'..id,Text='',Size=UDim2.new(1,-7,0,40),BackgroundColor3=colors.field,BackgroundTransparency=.25,AutoButtonColor=false,BorderSizePixel=0},list)round(b,7)bind(b,'BackgroundColor3','field')
   local check=label(b,'Selected','',8,9,22,22,13,true)check.BackgroundTransparency=0 round(check,6)
   label(b,'ItemName',name(id),40,1,223,23,13,true)
   local state=label(b,'Stock','',40,22,223,15,10)
   local cost=label(b,'Price','',268,0,116,40,12)cost.TextXAlignment=Enum.TextXAlignment.Right
   a.Rows[#a.Rows+1]={Id=id,Definition=all[id],Button=b,Check=check,Price=cost,State=state}
   connect(b.Activated,function()a.Selected[itemId]=not a.Selected[itemId]or nil;a.Save();redraw()end)
  end
  redraw()
 end
 small('SelectAllMerchant','Select all',220,function()for _,row in ipairs(a.Rows)do a.Selected[row.Id]=true end;a.Save();redraw()end)
 small('ClearMerchant','Clear',324,function()a.Selected={};a.Save();redraw()end)
 connect(search:GetPropertyChangedSignal('Text'),redraw)
 function a.Check()
  if not a.Alive or a.Busy then return end
  a.Layout()
  redraw()
  if not a.Enabled then status.Text='Auto Buy paused · selections are saved' return end
  if not next(a.Selected)then status.Text='Choose at least one item first' return end
  if not Loader.IsLobby then status.Text='Waiting for lobby' return end
  if not isOpen()then status.Text='Waiting for Travelling Merchant to arrive' return end
  local p=serviceData()if not p then status.Text='Waiting for merchant data' return end
  local offer,message=a.PlanPurchase(S.SELLING_ITEMS,p.bought_items or{},a.Confirmed,a.Selected,{gold_amount=tonumber(p.gold_amount)or 0,gem_amount=tonumber(p.gem_amount)or 0},os.clock(),a.RetryAt)
  if not offer then status.Text=message return end
  a.Busy=true status.Text='Buying '..name(offer.Data.id)..' · '..offer.Cost..' '..offer.Currency
  task.spawn(function()
   if not a.Alive or not a.Enabled or not a.Selected[offer.Data.id]or not isOpen()then a.Busy=false return end
   local current=serviceData()if not current or(current.bought_items or{})[offer.UUID]then a.Busy=false return end
   local ok,result=pcall(EP.invoke_server,'buy_travelling_merchant_item',offer.UUID,'1')
   local deadline=os.clock()+3 local observed=false
   repeat
    local fresh=serviceData()observed=fresh and(fresh.bought_items or{})[offer.UUID]or false
    if observed or not a.Alive then break end task.wait(.1)
   until os.clock()>=deadline
   if observed or ok and result==true then
    a.Confirmed[offer.UUID]=true a.Purchases+=1 a.Failures[offer.UUID]=nil
    if a.Alive then status.Text='Purchased '..name(offer.Data.id)end
   else
    a.Failures[offer.UUID]=math.min((a.Failures[offer.UUID]or 0)+1,4)
    a.RetryAt[offer.UUID]=os.clock()+math.min(60,10*2^(a.Failures[offer.UUID]-1))
    a.LastError=tostring(result)if a.Alive then status.Text='Purchase not confirmed · retrying after cooldown'end
   end
   a.Busy=false
  end)
 end
 function a.Stop()a.Alive=false;a.Save();panel:Destroy()end
 connect(gui.Destroying,a.Stop)
 buildRows()
 task.spawn(function()while a.Alive and gui.Parent do local ok,err=pcall(a.Check)if not ok then a.LastError=tostring(err)status.Text='Waiting for merchant data…'end task.wait(2)end end)
end)()


;(function()
 local previous=env.FyrelithWebhook;if previous and previous.Stop then previous.Stop()end
 local Http=game:GetService('HttpService')
 local feature={Alive=true,Config={Enabled=false,URL='',AvatarRevision='',Victory=false,Defeat=false,Rewards=false},Queue={},Queued={},Sent={},Round=0,ResultOpen=api.MatchEnded==true,Status='Add a webhook URL to begin',Count=0}
 env.FyrelithWebhook=feature
 local file='FyrelithWebhook_'..player.UserId..'_'..game.GameId..'.json'
 pcall(function()
  local saved=Http:JSONDecode(readfile(file))
  for k,v in pairs(feature.Config)do if type(saved[k])==type(v)then feature.Config[k]=saved[k]end end
 end)
 local C=feature.Config
 feature.Transport=request or http_request or (syn and syn.request)or(http and http.request)
 local function clean(text,maximum)
  text=tostring(text or ''):gsub('<[^>]->',''):gsub('[\r\n]+',' '):gsub('^%s+',''):gsub('%s+$','')
  if #text>(maximum or 1000)then local limit=(maximum or 1000)-3;local ok,cut=pcall(utf8.offset,text,0,limit);text=text:sub(1,ok and cut and cut-1 or limit)..'...'end
  return text
 end
 function feature.ValidateURL(url)
  if type(url)~='string'or #url>2048 then return nil end
  url=url:match('^%s*(.-)%s*$'):match('^([^?]+)')or ''
  local host,tail=url:match('^https://([^/]+)/api/webhooks/(.+)$')
  local allowed=host=='discord.com'or host=='discordapp.com'or host=='canary.discord.com'or host=='ptb.discord.com'
  if not allowed or not tail or not tail:match('^%d+/[%w_%-]+$')then return nil end
  return url
 end
 local function save()pcall(function()writefile(file,Http:JSONEncode(C))end)end
 -- Original user-supplied PNG, embedded without a public image host.
 local avatarRevision='258F87EAB02E4E0E512A6C92D0B181DE0FE3897F153F971EA6E18E3AFE7EDD2E'
 
 feature.AvatarRevision=avatarRevision
 function feature.SyncAvatar()
  local url=feature.ValidateURL(C.URL)
  if not feature.Alive or not url or type(feature.Transport)~='function'then return false end
  if C.AvatarRevision==avatarRevision then return true end
  if feature.AvatarBusy then return false end
  feature.AvatarBusy=true
  local avatarData=fyAssetDataUri('FyrelithWebhookAvatar.blackhole.png')
  if not avatarData then feature.AvatarBusy=false;feature.AvatarStatus='Avatar image unavailable';return false end
  local body=Http:JSONEncode({avatar=avatarData})
  local updated=false
  for attempt=1,3 do
   if not feature.Alive or C.URL~=url then break end
   local ok,response=pcall(feature.Transport,{Url=url,Method='PATCH',Headers={['Content-Type']='application/json'},Body=body})
   local code=ok and type(response)=='table'and tonumber(response.StatusCode or response.Status)or nil
   if code and code>=200 and code<300 then
    if C.URL==url then C.AvatarRevision=avatarRevision;save();feature.AvatarStatus='Updated' end
    updated=true;break
   elseif code==429 and attempt<3 then
    local delay=2;pcall(function()delay=tonumber(Http:JSONDecode(response.Body or '{}').retry_after)or 2 end)
    task.wait(math.clamp(delay,.5,30))
   elseif code and code>=500 and attempt<3 then task.wait(attempt*2)
   else feature.AvatarStatus=code and ('Avatar update failed • HTTP '..code)or'Avatar update failed';break end
  end
  feature.AvatarBusy=false
  return updated
 end

 function feature.SetURL(url)
  if url==''then C.URL='';save();feature.Status='Webhook URL cleared';return true end
  local valid=feature.ValidateURL(url)
  if not valid then feature.Status='Enter a valid Discord webhook URL';return false end
  if C.URL~=valid then C.AvatarRevision=''end;C.URL=valid;save();feature.Status='Webhook URL saved';task.defer(feature.SyncAvatar);return true
 end
 local function uiText(parent,name)
  local value=parent and parent:FindFirstChild(name)
  return value and value:IsA('TextLabel')and clean(value.Text)or nil
 end
 function feature.ReadInventory()
  local ready=env.FyrelithGameReady
  local U=ready and ready.Services.UnitCollectionServiceClient
  local session=U and U.session
  local profile=session and session.profile_data
  local inventory=session and session.inventory
  local stats=player:FindFirstChild('_stats')
  local snapshot={Currencies={},Rerolls={}}
  local function balance(key,fallback)
   local value=stats and stats:FindFirstChild(key)
   local live=value and value:IsA('ValueBase')and tonumber(value.Value)
   if live~=nil then return live end
   return tonumber(fallback)
  end
  local function add(list,name,amount)
   if type(amount)=='number'and amount==amount and math.abs(amount)~=math.huge then list[#list+1]={Name=name,Amount=math.max(0,math.floor(amount))}end
  end
  add(snapshot.Currencies,'Gold',balance('gold_amount',profile and profile.gold_amount))
  add(snapshot.Currencies,'Gems',balance('gem_amount',profile and profile.gem_amount))
  local resources=profile and profile.resources or {}
  local candidates={};for id in pairs(resources)do if type(id)=='string'and id:sub(1,1)~='_'then candidates[id]=true end end
  local ok,settings=pcall(Loader.load_data,script,'GameplaySettings')
  if ok and type(settings)=='table'then for id,active in pairs(settings.ACTIVE_RESOURCES or {})do if active and type(id)=='string'and id:sub(1,1)~='_'then candidates[id]=true end end end
  local resourceNames={GemsLegacy='Legacy Gems',AprilCoins='April Coins',HolidayStars='Holiday Stars',SummerPearls='Summer Pearls'}
  local ids={};for id in pairs(candidates)do ids[#ids+1]=id end
  table.sort(ids,function(a,b)if a=='AprilCoins'then return b~='AprilCoins'elseif b=='AprilCoins'then return false end return a<b end)
  for _,id in ipairs(ids)do add(snapshot.Currencies,resourceNames[id]or id:gsub('(%l)(%u)','%1 %2'),balance('_resource'..id,resources[id]or 0))end
  add(snapshot.Rerolls,'Reroll Tokens',balance('trait_reroll_tokens',profile and profile.trait_reroll_tokens))
  local itemNames={star_remnant='Star Remnant',star_remnant_limited='Limited Remnant',trait_reroll_legacy='Legacy Trait Reroll',reroll_stat_all='Stat Cube',reroll_stat_specific='Perfect Stat Cube'}
  local itemIds={'star_remnant','star_remnant_limited','trait_reroll_legacy','reroll_stat_all','reroll_stat_specific'}
  local found,items=pcall(Loader.load_data,script,'Items')
  if found and type(items)=='table'then for id,data in pairs(items)do
   if type(id)=='string'and type(data)=='table'and not itemNames[id]and id:find('reroll',1,true)then itemNames[id]=data.name or id;itemIds[#itemIds+1]=id end
  end end
  if inventory and type(inventory.get_number_of_owned_item)=='function'then
   for _,id in ipairs(itemIds)do
    local success,count=pcall(inventory.get_number_of_owned_item,inventory,id)
    if success and tonumber(count)~=nil and (itemNames[id]and (tonumber(count)>0 or id=='star_remnant'or id=='star_remnant_limited'or id=='trait_reroll_legacy'or id=='reroll_stat_all'or id=='reroll_stat_specific'))then add(snapshot.Rerolls,itemNames[id],tonumber(count))end
   end
  end
  return snapshot
 end
 function feature.ReadResults(native)
  local screen=native and native.screenGUI or player.PlayerGui:FindFirstChild('ResultsUI')
  local holder=screen and screen:FindFirstChild('Holder')
  local middle=holder and holder:FindFirstChild('Middle')
  local stats=native and native.settings and native.settings.stats
  local level=Loader.LevelData or {}
  local snapshot={Result=uiText(holder,'Title')or 'Match complete',Level=uiText(holder,'LevelName')or level.name or level.id or 'Unknown map',Mode=level.id=='summer2_event'and'Summer Hunt'or level._gamemode or level.gamemode,Difficulty=uiText(holder,'Difficulty')or level._difficulty,Wave=uiText(middle,'WavesCompleted'),Time=uiText(middle,'Timer'),Rewards={}}
  if not snapshot.Time and type(stats)=='table'and tonumber(stats.time_taken)then snapshot.Time=string.format('%dm %02ds',math.floor(stats.time_taken/60),math.floor(stats.time_taken%60))end
  if not snapshot.Wave then local wave=workspace:FindFirstChild('_wave_num');snapshot.Wave=wave and tostring(wave.Value)or 'Unknown' end
  local rewards=holder and holder:FindFirstChild('LevelRewards');rewards=rewards and rewards:FindFirstChild('ScrollingFrame')
  local names={XPReward='XP',GoldReward='Gold',GemReward='Gems',AprilCoinsReward='April Coins',AprilCoinReward='April Coins'}
  local resourceNames={AprilCoins='April Coins',GemsLegacy='Legacy Gems',HolidayStars='Holiday Stars',SummerPearls='Summer Pearls'}
  local resourceId=level.roguelike_multiplier_resource or level._event_resource or level.event_resource
  if type(resourceId)=='string'and resourceId~=''then
   local name=resourceNames[resourceId]or resourceId:gsub('(%l)(%u)','%1 %2'):gsub('_',' ')
   names.ResourceReward=name;names.EventResourceReward=name;names.EventCurrencyReward=name
  end
  if rewards then for _,item in ipairs(rewards:GetChildren())do if item:IsA('GuiObject')and item.Visible then
   local parts={};local seen={}
   for _,label in ipairs(item:QueryDescendants('TextLabel'))do
    local text=clean(label.Text,200):gsub('([%+%-])(%d+)',function(sign,number)return sign..number:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')end)
    if label.Visible and text~=''and not seen[text]then parts[#parts+1]=text;seen[text]=true end
   end
   if #parts>0 then
    local name=names[item.Name]or item.Name:match('^(%a+)Reward$')
    if name then name=name:gsub('(%l)(%u)','%1 %2')end
    if names[item.Name]and item.Name:lower():find('resource',1,true)then for i,text in ipairs(parts)do parts[i]=text:gsub('^[Rr]esource%s*',function()return name..' 'end)end end
    if name and not table.concat(parts,' '):lower():find(name:lower(),1,true)then table.insert(parts,1,name)end
    snapshot.Rewards[#snapshot.Rewards+1]=table.concat(parts,' ')
   end
   if #snapshot.Rewards>=25 then break end
  end end end
  snapshot.Inventory=feature.ReadInventory()
  return snapshot
 end
 function feature.BuildPayload(snapshot,isTest)
  local privacy=env.FyrelithPrivacy
  local identity=privacy and privacy.Enabled and 'Fyrelith'or player.DisplayName
  local result=clean(snapshot.Result,100)
  local function code(value,maximum)
   local text=clean(value,maximum):gsub('`','')
   return '`'..(text~=''and text or '—')..'`'
  end
  local fields={{name='Player',value=code(identity,100),inline=false}}
  local wave=clean(snapshot.Wave or '—',100):gsub('^[Ww]aves?%s*[Cc]ompleted%s*:%s*','')
  local duration=clean(snapshot.Time or '—',100):gsub('^[Tt]otal%s+[Tt]ime%s*:%s*','')
  local mode=clean(snapshot.Mode or 'Match',100):gsub('_',' '):gsub('^%l',string.upper)
  fields[#fields+1]={name='Waves',value=code(wave,100),inline=true}
  fields[#fields+1]={name='Time',value=code(duration,100),inline=true}
  fields[#fields+1]={name='Mode',value=code(mode,100),inline=true}
  if C.Rewards then
   local lines={};local size=0
   for i,reward in ipairs(snapshot.Rewards or {})do
    local line='✧ '..code(reward,130)
    if size+#line+1>980 then lines[#lines+1]='… more rewards';break end
    lines[#lines+1]=line;size+=#line+1
   end
   fields[#fields+1]={name='Rewards',value=#lines>0 and table.concat(lines,'\n')or 'No rewards shown',inline=false}
  end
  local owned=snapshot.Inventory or feature.ReadInventory()
  local function inventoryLines(entries)
   local lines={};local size=0
   for _,entry in ipairs(entries or {})do
    local n=string.format('%.0f',entry.Amount)
    local reversed=n:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
    local line=clean(entry.Name,80)..'  '..code(reversed,40)
    if size+#line+1>980 then lines[#lines+1]='… more items';break end
    lines[#lines+1]=line;size+=#line+1
   end
   return #lines>0 and table.concat(lines,'\n')or 'Inventory not available yet'
  end
  fields[#fields+1]={name='Your Wallet',value=inventoryLines(owned.Currencies),inline=true}
  fields[#fields+1]={name='Rerolls • Owned',value=inventoryLines(owned.Rerolls),inline=true}
  local description='**'..clean(snapshot.Level,500)..'**'
  if snapshot.Difficulty then description..='\n'..code(snapshot.Difficulty,100)end
  return {username='Fyrelith',allowed_mentions={parse={}},embeds={{author={name='FYRELITH  /  MATCH REPORT'},title=isTest and '✦  WEBHOOK TEST'or '✦  '..result,description=description,color=0xB49AEF,fields=fields,image={url='https://i.pinimg.com/originals/f8/fb/90/f8fb90452d47c229d2dbaaabaa0aa764.gif'},footer={text='Made by Feng'},timestamp=DateTime.now():ToIsoDate()}}}
 end
 local function status(text)feature.Status=text end
 local function worker()
  if feature.Working then return end;feature.Working=true
  task.spawn(function()
   while feature.Alive and #feature.Queue>0 do
    local entry=table.remove(feature.Queue,1)
    local avatarWait=os.clock()+10;while feature.AvatarBusy and feature.Alive and os.clock()<avatarWait do task.wait(.05)end
    feature.SyncAvatar()
    local delivered=false
    for attempt=1,3 do
     if not feature.Alive or (not entry.Test and not C.Enabled)or C.URL~=entry.URL then break end
     local ok,response=pcall(feature.Transport,{Url=entry.URL,Method='POST',Headers={['Content-Type']='application/json'},Body=entry.Body})
     local code=ok and type(response)=='table'and tonumber(response.StatusCode or response.Status)or nil
     if code and code>=200 and code<300 then
      delivered=true;feature.Count+=1;feature.LastSent=os.clock();status(entry.Test and 'Test message sent'or 'Match results sent');break
     elseif code==429 and attempt<3 then
      local delay=2
      pcall(function()delay=tonumber(Http:JSONDecode(response.Body or '{}').retry_after)or 2 end)
      status('Rate limited • retrying');task.wait(math.clamp(delay,.5,30))
     elseif code and code>=500 and attempt<3 then task.wait(attempt*2)
     else
      status(code==404 and 'Webhook not found • check the URL'or (code==401 or code==403)and 'Webhook access denied'or code and 'Discord error '..code or 'Request failed • check executor HTTP support')
      break
     end
    end
    if not delivered and feature.Alive and feature.Status=='Rate limited • retrying'then status('Discord busy • please try again')end
    feature.Queued[entry.Key]=nil
    if delivered then feature.Sent[entry.Key]=true end
    if #feature.Queue>0 then task.wait(1)end
   end
   feature.Working=false
  end)
 end
 function feature.Send(payload,key,isTest)
  if not feature.Alive or (not isTest and not C.Enabled)then return false end
  if feature.Queued[key]or feature.Sent[key]then return false end
  local url=feature.ValidateURL(C.URL)
  if not url then status('Add a valid Discord webhook URL');return false end
  if type(feature.Transport)~='function'then status('Executor HTTP requests are unavailable');return false end
  if #feature.Queue>=10 then status('Notification queue full');return false end
  local valid,body=pcall(Http.JSONEncode,Http,payload)
  if not valid then status('Unable to prepare notification');return false end
  feature.Queued[key]=true;feature.Queue[#feature.Queue+1]={URL=url,Body=body,Key=key,Test=isTest}
  status('Sending...');worker();return true
 end
 function feature.OnResults(native)
  if not feature.Alive or not C.Enabled then return end
  if not feature.ResultOpen then feature.Round+=1;feature.ResultOpen=true end
  if feature.Round==0 then return end
  local key=game.JobId..':'..feature.Round
  if feature.Queued[key]or feature.Sent[key]or feature.PendingKey==key then return end
  feature.PendingKey=key
  task.spawn(function()
   local deadline=os.clock()+8
   while feature.Alive and os.clock()<deadline do
    local screen=native and native.screenGUI
    local finished=screen and screen:FindFirstChild('Finished')
    if screen and screen.Enabled and finished and finished.Visible then break end
    task.wait(.1)
   end
   if not feature.Alive then return end
   task.wait(.15)
   local snapshot=feature.ReadResults(native);local lower=snapshot.Result:lower()
   local victory=lower:find('victor',1,true)or lower:find('win',1,true)
   local defeat=lower:find('defeat',1,true)or lower:find('lose',1,true)or lower:find('loss',1,true)
   feature.PendingKey=nil
   if (victory and not C.Victory)or(defeat and not C.Defeat)then return end
   feature.Send(feature.BuildPayload(snapshot),key,false)
  end)
 end
 local page=main.Parent.Webhook
 local panel=card('WebhookSettingsCard',8,8,438,334);panel.Parent=page
 label(panel,'Title','DISCORD WEBHOOK',18,12,402,28,18,true)
 switch('WebhookEnabled','Enable Webhook','',0,function()return C.Enabled end,function(value)C.Enabled=value;save();status(value and 'Waiting for match results'or 'Webhook disabled')end)
 local enable=ui('WebhookEnabled');enable.Parent=panel;enable.Position=UDim2.fromOffset(18,52)
 label(panel,'URLLabel','Webhook URL',18,100,300,24,14,true)
 local box=new('TextBox',{Name='WebhookURL',Text='',PlaceholderText='Paste your Discord webhook URL',ClearTextOnFocus=false,Position=UDim2.fromOffset(18,134),Size=UDim2.fromOffset(402,38),TextColor3=white,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0},panel)
 bind(box,'BackgroundColor3','field');round(box,8);new('UIPadding',{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},box)
 local function mask()box.Text=C.URL~=''and 'Saved webhook URL (click to edit)'or ''end
 connect(box.Focused,function()box.Text=C.URL end)
 connect(box.FocusLost,function()feature.SetURL(box.Text);mask()end)
 local test=button('WebhookTest','Send Test',18,190,402,function()
  feature.Send(feature.BuildPayload({Result='Test',Level='Webhook connection test',Wave='Example',Time='00:00',Rewards={'Test message • no match reward'}},true),'test:'..tostring(os.clock()),true)
 end);test.Parent=panel
 local stateLabel=label(panel,'WebhookStatus','',18,244,402,64,13);stateLabel.TextWrapped=true;stateLabel.TextTruncate=Enum.TextTruncate.None;stateLabel.TextColor3=muted
 local filters=card('WebhookNotifications',462,8,438,224);filters.Parent=page
 label(filters,'Title','NOTIFICATIONS',18,12,402,28,18,true)
 for i,entry in ipairs({{'Victory','Victory'},{'Defeat','Defeat'},{'Rewards','Include Rewards'}})do
  local key,title=entry[1],entry[2]
  switch('Webhook'..key,title,'',0,function()return C[key]end,function(value)C[key]=value;save()end)
  local row=ui('Webhook'..key);row.Parent=filters;row.Position=UDim2.fromOffset(18,52+(i-1)*50)
 end
 local guide=card('WebhookGuide',462,246,438,88);guide.Parent=page
 label(guide,'Title','MATCH SUMMARY',18,10,402,24,15,true)
 label(guide,'Details','Map • Result • Waves • Time • Rewards',18,42,402,26,13).TextColor3=muted
 page.CanvasSize=UDim2.fromOffset(0,358)
 function feature.Stop()feature.Alive=false;table.clear(feature.Queue)end
 connect(gui.Destroying,feature.Stop)
 mask();if C.URL~=''then status(C.Enabled and 'Waiting for match results'or 'Webhook disabled');task.defer(feature.SyncAvatar)end
 task.spawn(function()
  while feature.Alive and gui.Parent do
   local ended=api.MatchEnded==true
   local G=env.FyrelithGameReady and env.FyrelithGameReady.Services.GUIService
   local native=G and G.results_ui
   if not ended then feature.ResultOpen=false
   elseif not feature.ResultOpen then feature.OnResults(native)end
   stateLabel.Text=feature.Status
   task.wait(.3)
  end
 end)
end)()

;(function()
 local prior=env.FyrelithAutoLeaveGuard;if prior and prior.Stop then prior.Stop()end
 local router=env.FyrelithDefaultLeaveRouter
 if not router then return end
 local guard={Alive=true};env.FyrelithAutoLeaveGuard=guard
 function guard.Arm()
  if env.FyrelithDungeon and env.FyrelithDungeon.OwnsMatch()then return false end
  if not guard.Alive or not cfg.AutoLeave or Loader.IsLobby then return false end
  local intent=router.Read()
  if router.Decide(intent,game.GameId,game.PlaceId,game.JobId,DateTime.now().UnixTimestampMillis)=='Same match'then return true end
  local ok,settings=pcall(Loader.load_data,script,'GameplaySettings')
  local lobby=ok and type(settings)=='table'and tonumber(settings.LOBBY_PLACE_ID)
  if not lobby then return false end
  local written=pcall(game:GetService('TeleportService').SetTeleportSetting,game:GetService('TeleportService'),router.Key,{Experience=game.GameId,LobbyPlaceId=lobby,SourceJob=game.JobId,Issued=DateTime.now().UnixTimestampMillis})
  guard.Pending=written;return written
 end
 function guard.OnReplay()
  if not guard.Alive or not cfg.AutoLeave then return false end
  local intent=router.Read()
  local action=router.Decide(intent,game.GameId,game.PlaceId,game.JobId,DateTime.now().UnixTimestampMillis)
  if action~='Same match'and action~='Redirect'then return false end
  return router.Redirect(intent)
 end
 function guard.Cancel()guard.Pending=false;router.Clear()end
 function guard.Stop()guard.Alive=false end
 connect(gui.Destroying,guard.Stop)
 local seen=api.MatchEnded==true
 task.spawn(function()
  while guard.Alive and api.Alive and gui.Parent do
   if cfg.AutoLeave and not Loader.IsLobby and api.MatchEnded then guard.Arm();seen=true
   elseif not cfg.AutoLeave and seen then guard.Cancel();seen=false end
   task.wait(.2)
  end
 end)
end)()

do
 local previous=env.FyrelithEventHorizon if previous then previous.Alive=false end
 local style={Alive=true,Version='Event Horizon',Panels=0,Buttons=0,Fields=0,Switches=0}
 env.FyrelithEventHorizon=style
 local decorated=setmetatable({},{__mode='k'}) local gradients=setmetatable({},{__mode='k'})
 local panelNames={AutoPlayControls=true,AutoPlanControls=true,PlayerProfile=true,CurrentMap=true,AutoSummon=true,AutoRedeemCodes=true,AutoBuyGoldShop=true,BannerUnitPreview=true,SavedMacrosCard=true}
 local function stroke(parent,name,transparency,color)
  local edge=new('UIStroke',{Name=name,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Transparency=transparency},parent)
  bind(edge,'Color',color or 'line') return edge
 end
 local function gradient(parent,name,rotation,first,last)
  return new('UIGradient',{Name=name,Rotation=rotation,Color=ColorSequence.new(first,last)},parent)
 end
 local function polishPanel(item)
  if decorated[item] then return end decorated[item]=true style.Panels+=1
  item:SetAttribute('VisualStyle','Event Horizon')
  local function tintPanel()
   if not style.Alive or not item.Parent then return end
   local tint=colors.card:Lerp(colors.accent,.105)
   if item.BackgroundColor3~=tint then item.BackgroundColor3=tint end
  end
  tintPanel()
  connect(item:GetPropertyChangedSignal('BackgroundColor3'),tintPanel)
  connect(accentIcon:GetPropertyChangedSignal('ImageColor3'),tintPanel)
  local finish=item:FindFirstChild('SurfaceFinish')
  if finish then finish.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(185,185,185)) finish.Rotation=115
  else gradient(item,'EHSurface',115,Color3.new(1,1,1),Color3.fromRGB(185,185,185)) end
  local corner=item:FindFirstChildOfClass('UICorner') if corner then corner.CornerRadius=UDim.new(0,14) end
  local edge=item:FindFirstChildOfClass('UIStroke') if edge then edge.Transparency=.4 end
  local inner=new('Frame',{Name='EHInnerRim',Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-3),BackgroundTransparency=1,BorderSizePixel=0,Active=false,ZIndex=item.ZIndex},item)
  round(inner,13) local rim=stroke(inner,'Rim',.88,'accent')
  new('UIGradient',{Rotation=100,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.5,.7),NumberSequenceKeypoint.new(1,1)})},rim)
  local lip=new('Frame',{Name='EHDepthLip',Position=UDim2.new(0,10,1,-3),Size=UDim2.new(1,-20,0,3),BackgroundColor3=Color3.fromRGB(4,5,10),BackgroundTransparency=.18,BorderSizePixel=0,Active=false,ZIndex=item.ZIndex+1},item) round(lip,3)
  gradient(lip,'DepthFalloff',90,Color3.fromRGB(89,85,112),Color3.fromRGB(8,9,16))
  local rail=item:FindFirstChild('AccentRail')
  if not rail then rail=new('Frame',{Name='AccentRail',Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-36,0,1),BackgroundTransparency=.22,BorderSizePixel=0,Active=false,ZIndex=item.ZIndex+1},item) bind(rail,'BackgroundColor3','accent') end
  local shine=rail:FindFirstChildOfClass('UIGradient')
  if not shine then shine=new('UIGradient',{},rail) end
  shine.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.1),NumberSequenceKeypoint.new(.6,.1),NumberSequenceKeypoint.new(1,1)})
  gradients[item]=shine
 end
 local function polishButton(item)
  if decorated[item] or item.Size.Y.Offset<28 or item.Size.X.Offset<70 or item.BackgroundTransparency>=.95 or item.Name:find('Track') or item.Name:find('Slider') then return end
  decorated[item]=true style.Buttons+=1 item:SetAttribute('VisualStyle','Event Horizon')
  local mainAction=item.Name=='MacroPause' or item:GetAttribute('Primary')==true
  local function tintButton(hover)
   if not item.Parent then return end
   if mainAction then item.BackgroundColor3=colors.accent:Lerp(Color3.new(1,1,1),hover and .44 or .3) item.TextColor3=Color3.fromRGB(255,240,245)
   elseif not item:GetAttribute('Selected') then item.BackgroundColor3=colors.field:Lerp(colors.accent,hover and .18 or .105) end
  end
  tintButton(false)
  local corner=item:FindFirstChildOfClass('UICorner') if corner then corner.CornerRadius=UDim.new(0,10) end
  if not item:FindFirstChildOfClass('UIGradient') then gradient(item,'EHButtonSurface',90,Color3.fromRGB(255,249,255),Color3.fromRGB(185,185,185)) end
  local bevel=new('Frame',{Name='EHButtonBevel',Position=UDim2.new(0,7,1,-2),Size=UDim2.new(1,-14,0,2),BackgroundColor3=Color3.fromRGB(6,6,12),BackgroundTransparency=.22,BorderSizePixel=0,Active=false,ZIndex=item.ZIndex+1},item) round(bevel,2)
  local top=new('Frame',{Name='EHButtonHighlight',Position=UDim2.fromOffset(8,1),Size=UDim2.new(1,-16,0,1),BackgroundColor3=Color3.fromRGB(238,222,255),BackgroundTransparency=.85,BorderSizePixel=0,Active=false,ZIndex=item.ZIndex+1},item)
  new('UIGradient',{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,0),NumberSequenceKeypoint.new(.6,0),NumberSequenceKeypoint.new(1,1)})},top)
  local hovering=false
  connect(item.MouseEnter,function() hovering=true tintButton(true) tween(top,{BackgroundTransparency=.38}) end)
  connect(item.MouseLeave,function() hovering=false tintButton(false) tween(top,{BackgroundTransparency=.74}) tween(bevel,{BackgroundTransparency=.22}) end)
  connect(item.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then tween(top,{BackgroundTransparency=.96}) tween(bevel,{BackgroundTransparency=.8}) end end)
  connect(item.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then tween(top,{BackgroundTransparency=hovering and .48 or .85}) tween(bevel,{BackgroundTransparency=.22}) end end)
 end
 local function polishField(item)
  if decorated[item] or item.BackgroundTransparency>=.95 then return end decorated[item]=true style.Fields+=1
  item:SetAttribute('VisualStyle','Event Horizon')
  if not item:FindFirstChildOfClass('UIGradient') then gradient(item,'EHInsetSurface',90,Color3.fromRGB(129,124,150),Color3.fromRGB(243,239,255)) end
  local edge=stroke(item,'EHFocus',1,'accent')
  connect(item.Focused,function() tween(edge,{Transparency=.2}) end)
  connect(item.FocusLost,function() tween(edge,{Transparency=1}) end)
 end
 local function polishSwitch(item)
  if decorated[item] or item.Name~='Track' or item.Size.X.Offset>70 or item.Size.Y.Offset<18 then return end
  local knob=item:FindFirstChild('Knob') if not knob or not knob:IsA('Frame') then return end
  decorated[item]=true style.Switches+=1 item:SetAttribute('VisualStyle','Event Horizon')
  gradient(item,'EHSocket',90,Color3.fromRGB(185,185,185),Color3.fromRGB(247,236,255))
  stroke(item,'EHSocketRim',.79,'line')
  gradient(knob,'EHKnobLight',120,Color3.new(1,1,1),Color3.fromRGB(148,145,171))
  local edge=new('UIStroke',{Name='EHKnobRim',Color=Color3.fromRGB(229,217,249),Transparency=.65,Thickness=1},knob)
 end
 local function apply(item)
  if item:GetAttribute('AtelierOwned')then return end
  if item:IsA('Frame') then
   if item.Name:match('Card$') or panelNames[item.Name] then polishPanel(item) else polishSwitch(item) end
  elseif item:IsA('TextButton') then polishButton(item)
  elseif item:IsA('TextBox') then polishField(item) end
 end
 for _,item in ipairs(gui:QueryDescendants('Frame, TextButton, TextBox')) do apply(item) end
 connect(gui.DescendantAdded,function(item) if item:IsA('Frame') or item:IsA('TextButton') or item:IsA('TextBox') then task.defer(function() if style.Alive and item.Parent then apply(item) end end) end end)
 connect(gui.Destroying,function() style.Alive=false end)
 -- A single shared clock; no idle animation loop or per-widget frame callbacks.
 local clock=0 local pointer=game:GetService('UserInputService')
 connect(game:GetService('RunService').RenderStepped,function(dt)
  if not style.Alive or not gui.Window.Visible or not motionEnabled() then return end
  clock+=math.min(dt,.05)
  local position=pointer:GetMouseLocation()
  for panel,shine in pairs(gradients) do if panel.Parent and panel.Visible and panel.Parent:IsA('GuiObject') and panel.Parent.Visible then
   local localPoint=position-panel.AbsolutePosition
   if localPoint.X>=0 and localPoint.Y>=0 and localPoint.X<=panel.AbsoluteSize.X and localPoint.Y<=panel.AbsoluteSize.Y then
    shine.Offset=Vector2.new(math.clamp(localPoint.X/math.max(1,panel.AbsoluteSize.X)-.5,-.5,.5),0)
   elseif shine.Offset~=Vector2.zero then shine.Offset=Vector2.zero end
  end end
 end)
end

do
 local previous=env.FyrelithDungeon;if previous then previous.Alive=false end
 local D={Alive=true,Config={Enabled=false,Start=false,Next=false,Chests=false,Shop=false,Death=false,Finish=false,Priority='Balanced',Shrine='Manual',AutoBuy=false,ShopPriority={},UseCursePriority=false,CursePriority={}},Status='Disabled'}
 env.FyrelithDungeon=D
 local Http=game:GetService('HttpService')
 local file='FyrelithDungeon_'..player.UserId..'_'..game.GameId..'.json'
 pcall(function()local saved=Http:JSONDecode(readfile(file));for k,v in pairs(saved)do if type(v)==type(D.Config[k])then D.Config[k]=v end end end)
 local C=D.Config
 local core=Loader.load_core_service(script,'DungeonServiceCore')
 local types=core.TYPES
 function D.Save()local ok,err=pcall(writefile,file,Http:JSONEncode(C));D.SaveError=not ok and tostring(err)or nil;return ok end
 local function data()
  local service=env.FyrelithGameReady.Services.UnitCollectionServiceClient
  return service and service.session and service.session.profile_data.dungeon_data
 end
 function D.InDungeon()return type(Loader.LevelData)=='table'and type(Loader.LevelData._dungeon)=='table'end
 function D.OwnsMatch()return D.Alive and C.Enabled and D.InDungeon()end
 function D.WantsStart()return D.Alive and C.Enabled and C.Start and D.InDungeon()end
 do
 local function isCurse(item)return item and(item.curse_chance~=nil or item.curse_super_chance~=nil)end
 D.IsCurse=isCurse
 for _,key in ipairs({'ShopPriority','CursePriority'})do
  local clean,seen={},{}
  for _,id in ipairs(C[key]or{})do if type(id)=='string'and core.ITEMS[id]and not seen[id]then clean[#clean+1]=id;seen[id]=true end end
  C[key]=clean
 end
 D.BoughtOffers={}
 function D.ShopPrice(id,state)
  local definition=core.ITEMS[id];if not definition or not tonumber(definition.cost)then return nil end
  local ok,adjustment=pcall(core.sum_item_values,state or {},'shop_prices')
  return math.ceil(definition.cost*math.max(0,1+(ok and tonumber(adjustment)or 0)))
 end
 function D.ShopOfferKey(state,index,id)
  local level=Loader.LevelData;local depth=type(level)=='table'and type(level._dungeon)=='table'and level._dungeon.depth or state.next and state.next['1']and state.next['1']._d or 0
  return game.JobId..':'..tostring(depth)..':'..tostring(index)..':'..id
 end
 function D.SelectShopPurchase(state,config,bought)
  local shop=state.current_shops and state.current_shops[1]
  if not shop or shop._t~=types.SHOP then return nil end
  local coins=tonumber(state._resources and state._resources.money)or 0
  for _,id in ipairs(config.ShopPriority or {})do
   for index,offer in pairs(shop.data or {})do
    local key=D.ShopOfferKey(state,index,id)
    if offer.id==id and not bought[key]then
     local cost=D.ShopPrice(id,state)
     if cost and cost<=coins then return {Endpoint='dungeon_buy_shop',Args={index},ItemId=id,OfferKey=key,Cost=cost}end
    end
   end
  end
  return nil
 end
 function D.ConfirmShopPurchase(state)
  local purchase=D.PendingShopPurchase;if not purchase then return true end
  local shop=state.current_shops and state.current_shops[1]
  local offer=shop and shop.data and shop.data[purchase.Index]
  local money=tonumber(state._resources and state._resources.money)or 0
  if money<purchase.BeforeMoney or not offer or offer.id~=purchase.ItemId or(purchase.Accepted and purchase.Cost==0)then
   if D.LastPurchase then D.LastPurchase.Confirmed=true;D.LastPurchase.AfterMoney=money end
   D.BoughtOffers[purchase.OfferKey]=true;D.PendingShopPurchase=nil;return true
  end
  if os.clock()>=(purchase.Deadline or math.huge) then
   -- An ambiguous purchase may already have charged: skip this offer for this
   -- room instead of blocking all progression or buying a duplicate.
   D.BoughtOffers[purchase.OfferKey]=true
   D.PendingShopPurchase=nil
   if D.LastPurchase then D.LastPurchase.Unverified=true end
   D.LastError='Purchase confirmation timed out; offer skipped for this room'
   D.Status='Purchase update delayed • continuing without a duplicate purchase'
   return true
  end
  return false
 end
 local catalog={};for id,item in pairs(core.ITEMS)do
  if type(item)=='table'and(isCurse(item)or tonumber(item.cost))then catalog[#catalog+1]={Id=id,Data=item}end
 end
 table.sort(catalog,function(a,b)return tostring(a.Data.name or a.Id)<tostring(b.Data.name or b.Id)end)
 local assets=Loader.get_assets_path().gui.DungeonItems
 local shopPanel=card('DungeonShopCard',8,1280,892,706)
 label(shopPanel,'Heading','DUNGEON • ITEMS & CURSES',18,12,410,30,18,true)
 local buyPaint=switch('Dungeon_AutoBuy','Auto Buy Selected Items','',1292,function()return C.AutoBuy end,function(v)C.AutoBuy=v;D.Save()end,480)
 local cursePaint=switch('Dungeon_UseCursePriority','Use Curse Priority','',1334,function()return C.UseCursePriority end,function(v)C.UseCursePriority=v;D.Save()end,480)
 local active='ShopPriority';local redraw
 local shopTab=button('DungeonShopTab','Shop Items',26,1336,192,function()active='ShopPriority';redraw()end)
 local curseTab=button('DungeonCurseTab','Curse Cards',226,1336,192,function()active='CursePriority';redraw()end)
 local hint=label(shopPanel,'Hint','',18,102,420,40,12);hint.TextWrapped=true
 local search=new('TextBox',{Name='DungeonItemSearch',PlaceholderText='Search items / description',Text='',ClearTextOnFocus=false,Position=UDim2.fromOffset(462,104),Size=UDim2.fromOffset(410,36),BackgroundColor3=colors.field,TextColor3=white,PlaceholderColor3=muted,Font=Enum.Font.Gotham,TextSize=14,BorderSizePixel=0},shopPanel);round(search,8)
 bind(search,'BackgroundColor3','field')
 local priorityTitle=label(shopPanel,'PriorityTitle','YOUR PRIORITY',18,144,420,22,12,true)
 local catalogTitle=label(shopPanel,'CatalogTitle','AVAILABLE ITEMS',462,144,410,22,12,true)
 bind(priorityTitle,'TextColor3','accent');bind(catalogTitle,'TextColor3','accent')
 local selected=new('ScrollingFrame',{Name='DungeonItemPriority',Position=UDim2.fromOffset(18,176),Size=UDim2.fromOffset(420,464),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new()},shopPanel)
 local available=new('ScrollingFrame',{Name='DungeonItemCatalog',Position=UDim2.fromOffset(462,176),Size=UDim2.fromOffset(410,464),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new()},shopPanel)
 local summary=label(shopPanel,'ShopSummary','',18,658,850,32,13);summary.TextWrapped=true
 local rowCache={[selected]={},[available]={}}
 local rowStyles={}
 local rowMoves=setmetatable({},{__mode='k'})
 local function moveRow(row,y)
  local goal=UDim2.fromOffset(0,y)
  local previous=rowMoves[row];if previous then previous:Cancel();rowMoves[row]=nil end
  if preferences and(preferences:GetAttribute('ReduceMotion')or preferences:GetAttribute('Smooth')==false)then row.Position=goal;return end
  if row.Position==goal then return end
  -- Layout motion has its own channel: hover/scroll events must not cancel it.
  local animation=game:GetService('TweenService'):Create(row,TweenInfo.new(.22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=goal})
  rowMoves[row]=animation
  animation.Completed:Once(function()if rowMoves[row]==animation then rowMoves[row]=nil end end)
  animation:Play()
 end
 local function localTheme(object,property,role)
  object[property]=colors[role]
  local entry={Object=object,Property=property,Role=role};rowStyles[object]=rowStyles[object]or{};table.insert(rowStyles[object],entry)
  if #rowStyles[object]==1 then object.Destroying:Once(function()rowStyles[object]=nil end)end
 end
 local function repaintRows()
  for object,entries in pairs(rowStyles)do if object.Parent then for _,entry in ipairs(entries)do object[entry.Property]=colors[entry.Role]end end end
 end
 connect(gui:GetAttributeChangedSignal('PaletteRevision'),function()task.defer(repaintRows)end)
 if preferences then connect(preferences.AttributeChanged,function()task.defer(repaintRows)end)end
 local function icon(parent,id)
  local original=assets:FindFirstChild(id)
  if original and(original:IsA('ImageLabel')or original:IsA('ImageButton'))then
   new('ImageLabel',{Name='ItemIcon',Position=UDim2.fromOffset(44,18),Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,Image=original.Image,ImageRectOffset=original.ImageRectOffset,ImageRectSize=original.ImageRectSize,ScaleType=Enum.ScaleType.Fit,ZIndex=5},parent)
  end
 end
 local function itemRow(parent,id,index,y)
  local cached=rowCache[parent][id]
  if cached then
   cached.Visible=true;cached:SetAttribute('Wanted',true);cached:SetAttribute('PriorityIndex',index);cached:SetAttribute('PriorityKey',active)
   cached.Rank.Text=index and string.format('%02d',index)or'+'
   cached.Price.Text=isCurse(core.ITEMS[id])and'CURSE'or(tostring(D.ShopPrice(id,data())or'?')..' coins')
   moveRow(cached,y)
   return cached,cached.Size.Y.Offset,false
  end
  local definition=core.ITEMS[id]
  local bounds=game:GetService('TextService'):GetTextSize(definition.description or '',17,Enum.Font.GothamMedium,Vector2.new(270,1000))
  local descriptionHeight=math.max(42,math.ceil(bounds.Y)+6)
  local footerY=40+descriptionHeight+8;local height=footerY+38
  local row=new('TextButton',{Name='DungeonItem_'..id,Text='',Size=UDim2.new(1,-8,0,height),Position=UDim2.fromOffset(0,y+10),BackgroundColor3=colors.card,BackgroundTransparency=.08,BorderSizePixel=0,AutoButtonColor=false},parent);round(row,12)
  localTheme(row,'BackgroundColor3','card')
  local outline=new('UIStroke',{Color=colors.line,Transparency=.72,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},row);localTheme(outline,'Color','line')
  local rail=new('Frame',{Name='AccentRail',Position=UDim2.fromOffset(0,14),Size=UDim2.new(0,3,1,-28),BorderSizePixel=0,BackgroundColor3=colors.accent,BackgroundTransparency=.35},row);round(rail,3);localTheme(rail,'BackgroundColor3','accent')
  local rank=label(row,'Rank',index and string.format('%02d',index)or'+',8,19,28,26,13,true);rank.TextXAlignment=Enum.TextXAlignment.Center;localTheme(rank,'TextColor3','accent')
  local well=new('Frame',{Name='IconWell',Position=UDim2.fromOffset(40,14),Size=UDim2.fromOffset(52,52),BackgroundColor3=colors.field,BackgroundTransparency=.15,BorderSizePixel=0},row);round(well,12);localTheme(well,'BackgroundColor3','field')
  icon(row,id)
  label(row,'ItemName',definition.name or id,104,12,278,25,17,true)
  local description=label(row,'Description',definition.description or '',104,40,270,descriptionHeight,15);description.TextWrapped=true;description.TextTruncate=Enum.TextTruncate.None;description.TextYAlignment=Enum.TextYAlignment.Top;description.TextColor3=muted
  local price=label(row,'Price',isCurse(definition)and'CURSE'or(tostring(D.ShopPrice(id,data())or'?')..' coins'),104,footerY,148,24,14,true);localTheme(price,'TextColor3','accent')
  local scale=new('UIScale',{Name='InteractionScale'},row)
  row.MouseEnter:Connect(function()tween(outline,{Transparency=.16});tween(row,{BackgroundTransparency=0})end)
  row.MouseLeave:Connect(function()tween(outline,{Transparency=.72});tween(row,{BackgroundTransparency=.08});tween(scale,{Scale=1})end)
  row.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tween(scale,{Scale=.985})end end)
  row.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tween(scale,{Scale=1})end end)
  rowCache[parent][id]=row;row:SetAttribute('Wanted',true);row:SetAttribute('PriorityIndex',index);row:SetAttribute('PriorityKey',active)
  moveRow(row,y)
  return row,height,true
 end
 local function smallButton(parent,name,x,callback,enabled)
  enabled=enabled~=false
  local b=new('TextButton',{Name=name,Text='',Position=UDim2.new(0,x,1,-38),Size=UDim2.fromOffset(32,30),BackgroundColor3=colors.card,BackgroundTransparency=.22,Active=enabled,AutoButtonColor=false,BorderSizePixel=0,ZIndex=7},parent);round(b,9)
  localTheme(b,'BackgroundColor3','field')
  local edge=new('UIStroke',{Color=colors.line,Transparency=enabled and .38 or .8,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b);localTheme(edge,'Color','line')
  local scale=new('UIScale',{Scale=1},b)
  local tint=colors.accent
  if name=='Remove'then
   for _,rotation in ipairs({45,-45})do
    local line=new('Frame',{Name='CloseStroke',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(14,2),Rotation=rotation,BackgroundColor3=tint,BackgroundTransparency=enabled and 0 or .6,BorderSizePixel=0,Active=false,ZIndex=8},b);round(line,2);localTheme(line,'BackgroundColor3','accent')
   end
  else
   local image=new('ImageLabel',{Name='ArrowIcon',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(15,15),BackgroundTransparency=1,Image='rbxassetid://7733717447',Rotation=name=='Up'and 180 or 0,ImageColor3=tint,ImageTransparency=enabled and 0 or .65,Active=false,ZIndex=8},b);localTheme(image,'ImageColor3','accent')
  end
  connect(b.MouseEnter,function()if b.Active then tween(b,{BackgroundColor3=colors.field:Lerp(colors.accent,.18),BackgroundTransparency=0});tween(edge,{Transparency=.05});tween(scale,{Scale=1.06})end end)
  connect(b.MouseLeave,function()tween(b,{BackgroundColor3=colors.field,BackgroundTransparency=.22});tween(edge,{Transparency=b.Active and .38 or .8});tween(scale,{Scale=1})end)
  connect(b.InputBegan,function(input)if b.Active and(input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch)then tween(scale,{Scale=.92})end end)
  connect(b.InputEnded,function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tween(scale,{Scale=1})end end)
  connect(b.Activated,function()if b.Active then callback()end end)
 end
 redraw=function()
  local leftPosition,rightPosition=selected.CanvasPosition,available.CanvasPosition
  for _,cache in pairs(rowCache)do for _,row in pairs(cache)do row:SetAttribute('Wanted',false)end end
  local empty=selected:FindFirstChild('Empty');if empty then empty:Destroy()end
  local priority=C[active];local selectedSet={}
  hint.Text=active=='ShopPriority'and'Buy in this order when in stock and affordable.'or'Prefer these Curse rooms in this order when enabled.'
  shopTab.BackgroundTransparency=active=='ShopPriority'and .1 or .5;curseTab.BackgroundTransparency=active=='CursePriority'and .1 or .5
  priorityTitle.Text='YOUR PRIORITY  /  '..#priority
  if #priority==0 then local empty=label(selected,'Empty','Build your priority\nTap an item on the right to add it here.',16,20,374,80,16,true);empty.TextWrapped=true;empty.TextColor3=muted end
  local leftY=0
  for rank,id in ipairs(priority)do
   selectedSet[id]=true
   local row,height,fresh=itemRow(selected,id,rank,leftY);leftY+=height+12
   local function move(offset)
    local list=C[row:GetAttribute('PriorityKey')];local current=table.find(list,id);if not current then return end
    local target=current+offset;if target<1 or target>#list then return end
    list[current],list[target]=list[target],list[current];D.Save();redraw()
   end
   if fresh then
    smallButton(row,'Up',278,function()move(-1)end,rank>1)
    smallButton(row,'Down',318,function()move(1)end,rank<#priority)
    smallButton(row,'Remove',358,function()
     if row:GetAttribute('Removing')then return end;row:SetAttribute('Removing',true)
     local key=row:GetAttribute('PriorityKey');tween(row.InteractionScale,{Scale=.94});tween(row,{BackgroundTransparency=1})
     local delay=preferences and(preferences:GetAttribute('ReduceMotion')or preferences:GetAttribute('Smooth')==false)and 0 or .14
     task.delay(delay,function()if not row.Parent then return end;local current=table.find(C[key],id);if current then table.remove(C[key],current);D.Save()end;row:SetAttribute('Removing',false);row.InteractionScale.Scale=1;row.BackgroundTransparency=.08;redraw()end)
    end)
   end
   for name,enabled in pairs({Up=rank>1,Down=rank<#priority})do local control=row:FindFirstChild(name);control.Active=enabled;control.ArrowIcon.ImageTransparency=enabled and 0 or .65 end
  end
  local count=0;local rightY=0;local query=search.Text:lower()
  for _,entry in ipairs(catalog)do
   local curse=isCurse(entry.Data)
   if (active=='CursePriority')==(not not curse)and not selectedSet[entry.Id]and(tostring(entry.Data.name or entry.Id)..' '..tostring(entry.Data.description or '')):lower():find(query,1,true)then
    local row,height,fresh=itemRow(available,entry.Id,nil,rightY);count+=1;rightY+=height+12
    if fresh then row.Activated:Connect(function()local list=C[row:GetAttribute('PriorityKey')];if not table.find(list,entry.Id)then list[#list+1]=entry.Id;D.Save();redraw()end end)end
   end
  end
  catalogTitle.Text=(active=='CursePriority'and'CURSE CARDS' or'AVAILABLE ITEMS')..'  /  '..count
  for _,cache in pairs(rowCache)do for _,row in pairs(cache)do if not row:GetAttribute('Wanted')then row.Visible=false end end end
  selected.CanvasSize=UDim2.fromOffset(0,math.max(80,leftY));available.CanvasSize=UDim2.fromOffset(0,rightY)
  selected.CanvasPosition=leftPosition;available.CanvasPosition=rightPosition
 end
 connect(search:GetPropertyChangedSignal('Text'),function()redraw()end)
 local lastPriceVersion
 D.RefreshShopUI=function()
  local state=data();local resources=state and state._resources or {}
  local ok,adjustment=pcall(core.sum_item_values,state or {},'shop_prices');local priceVersion=tostring(ok and adjustment or 0)
  if lastPriceVersion~=priceVersion then lastPriceVersion=priceVersion;redraw()end
  summary.Text='Dungeon coins: '..tostring(resources.money or 0)..'   •   Selected items: '..#C.ShopPriority..'   •   Curse cards: '..#C.CursePriority
  buyPaint();cursePaint()
 end
 redraw();D.RefreshShopUI()
 root.Size=UDim2.fromOffset(908,math.max(root.Size.Y.Offset,2002));main.CanvasSize=UDim2.fromOffset(0,root.Size.Y.Offset)
end

 function D.ChooseRoom(state,priority,config)
  local selected=state.selected_next and state.selected_next.choice_str
  local best,bestScore
  for i=1,3 do local key=tostring(i);local room=state.next and state.next[key]
   if type(room)=='table'and(not selected or selected==key)then
    local tags=room._t or {};local level=room._l or {};local difficulty=tonumber(level._lobby_difficulty_scale)or 1
    local score=-difficulty*10
    if priority=='Treasure'then score+=tags[types.TREASURE_GOLD]and 1000 or tags[types.TREASURE]and 500 or tags[types.OPEN_CHEST]and 300 or 0
    elseif priority=='Money'then score+=tags[types.MONEY]and 1000 or 0
    elseif priority=='Balanced'or priority=='Treasure + Money'then score+=tags[types.TREASURE_GOLD]and 160 or tags[types.TREASURE]and 100 or tags[types.MONEY]and 60 or 0 end
    if (priority=='Treasure'or priority=='Money'or priority=='Treasure + Money')and tags[types.MONEY]and(tags[types.TREASURE]or tags[types.TREASURE_GOLD])then score+=1000000 end
    if tags[types.CURSE]then score-=priority=='Safest'and 10000 or 80 end
    local policy=config or C or {}
    if policy.UseCursePriority and tags[types.CURSE]then
     local curse=tags[types.CURSE];local id=type(curse)=='table'and curse.id
     local rank=id and table.find(policy.CursePriority or {},id)
     score+=rank and(100000-rank*100)or -100000
    end
    if not bestScore or score>bestScore then best,bestScore={Key=key,Room=room},score end
   end
  end
  return best
 end
 function D.Decide(state,config)
  if type(state)~='table'then return nil,'Waiting for dungeon data' end
  if state._dead then return config.Death and {Endpoint='dungeon_continue_death'}or nil,'Dungeon run ended' end
  local resources=state._resources or {}
  local shop=state.current_shops and state.current_shops[1]
  if shop then
   if shop._t==types.OPEN_CHEST then
    if config.Chests and(tonumber(resources.treasure_gold)or 0)>0 then return {Endpoint='dungeon_open_chest',Args={true}},'Opening rare chest' end
    if config.Chests and(tonumber(resources.treasure)or 0)>0 then return {Endpoint='dungeon_open_chest'},'Opening chest' end
    if (tonumber(resources.treasure_gold)or 0)+(tonumber(resources.treasure)or 0)>0 then return nil,'Chests available • open them before continuing' end
    if state._finished and not config.Finish then return nil,'Dungeon complete • waiting for Finish' end
    return (state._finished and config.Finish or not state._finished and config.Next) and {Endpoint='dungeon_continue_shop'}or nil,state._finished and 'Finishing dungeon' or 'Continuing after chests'
   elseif shop._t==types.SHOP then
    if config.AutoBuy then
     if #(config.ShopPriority or{})==0 then return nil,'Choose items in the Dungeon shop priority list' end
     local purchase=D.SelectShopPurchase(state,config,D.BoughtOffers)
     if purchase then return purchase,'Buying '..tostring(core.ITEMS[purchase.ItemId].name or purchase.ItemId)end
    end
    return config.Shop and {Endpoint='dungeon_continue_shop'}or nil,'Shop • no selected affordable items remaining'
   elseif shop._t==types.SHRINE then
    if config.Shrine=='Accept'then return {Endpoint='dungeon_shrine_accept'},'Accepting shrine offer'
    elseif config.Shrine=='Skip'then return {Endpoint='dungeon_continue_shop'},'Skipping shrine offer' end
    return nil,'Shrine • choose the offer in the game'
   end
   return nil,'Waiting for dungeon room update'
  end
  if not state._started then return config.Start and {Endpoint='dungeon_start'}or nil,'Ready to start dungeon' end
  if state._finished then return nil,'Dungeon complete' end
  if not config.Next then return nil,'Choose the next dungeon room in the game' end
  local choice=D.ChooseRoom(state,config.Priority,config)
  if not choice then return nil,'Waiting for available dungeon rooms' end
  return {Endpoint='dungeon_enter_room',Args={choice.Key},Depth=choice.Room._d},'Entering room '..tostring(choice.Room._d or '?')..' • path '..choice.Key
 end
 local pending=false;local lastRequest=-math.huge;local accepted
 function D.CanAct(inLobby,inDungeon,matchEnded,finished,nativeOpen,intermission)
  if inLobby then return true end
  if not inDungeon then return false end
  return nativeOpen and intermission or matchEnded and(finished or nativeOpen)
 end
 function D.Tick()
  if not D.Alive or not api.Alive then return end
  if not C.Enabled then D.Status='Disabled';return end
  local state=data();if not state then D.Status='Waiting for dungeon data';return end
  local challenge=env.FyrelithAutoChallenge
  if challenge and challenge.Priority then D.Status='Waiting for Auto Challenge';return end
  local event=env.FyrelithSummer
  if Loader.IsLobby and ((api.Enabled and cfg.Mode~='Dungeon')or(event and event.Enabled))then
   D.Status='Pause other Auto Join modes before starting Dungeon';return
  end
  local results=env.FyrelithGameReady.Services.GUIService.results_ui
  local native=env.FyrelithGameReady.Services.GUIService.dungeon_ui
  local nativeOpen=native and native.screenGUI and native.screenGUI.Enabled and native.IsOpen==true
  local currentShop=state.current_shops and state.current_shops[1]
  local intermission=native and((currentShop and((currentShop._t==types.SHOP and native.ShopSelection.Visible)or(currentShop._t==types.OPEN_CHEST and native.OpenTreasure.Visible)or(currentShop._t==types.SHRINE and native.ShrineRoom.Visible)))or(state._dead and native.YouDied.Visible))
  local ready=D.CanAct(Loader.IsLobby,D.InDungeon(),api.MatchEnded,results and results.Finished and results.Finished.Visible,nativeOpen,intermission)
  if not ready then D.Status=D.InDungeon()and 'Playing dungeon room' or 'Return to lobby to start Dungeon';return end
  if not currentShop or currentShop._t~=types.SHOP then D.BoughtOffers={};D.PendingShopPurchase=nil end
  if D.PendingShopPurchase and not D.ConfirmShopPurchase(state)then D.Status='Waiting for shop purchase confirmation';return end
  local action,message=D.Decide(state,C);D.Status=message
  if not action or pending or os.clock()-lastRequest<3 then return end
  local resources=state._resources or {};local shop=state.current_shops and state.current_shops[1]
  local signature=table.concat({tostring(state._started),tostring(state._finished),tostring(state._dead),tostring(shop),tostring(shop and shop._t),tostring(resources.treasure),tostring(resources.treasure_gold),tostring(action.Depth),action.Endpoint,tostring(action.Args and action.Args[1])},':')
  if accepted==signature then return end
  pending=true;lastRequest=os.clock()
  task.spawn(function()
   local ok,result=pcall(function()
    if not D.Alive or not C.Enabled then return false end
    if Loader.IsLobby and(action.Endpoint=='dungeon_start'or action.Endpoint=='dungeon_enter_room')and api.ApplyTeam then
     local equipped,err=api.ApplyTeam('__DUNGEON','Dungeon');if not equipped then error(err,0)end
    end
    if action.Endpoint=='dungeon_buy_shop'then
     local fresh=data();local nextPurchase=C.AutoBuy and D.SelectShopPurchase(fresh,C,D.BoughtOffers)
     if not nextPurchase or nextPurchase.OfferKey~=action.OfferKey then return false end
     D.PendingShopPurchase={Index=action.Args[1],ItemId=action.ItemId,OfferKey=action.OfferKey,Cost=action.Cost,BeforeMoney=tonumber(fresh._resources and fresh._resources.money)or 0,Deadline=os.clock()+15}
     D.LastPurchase={ItemId=action.ItemId,Cost=action.Cost,BeforeMoney=D.PendingShopPurchase.BeforeMoney,Confirmed=false}
    end
    local result=EP.invoke_server(action.Endpoint,table.unpack(action.Args or {}))
    if action.Endpoint=='dungeon_buy_shop'and D.PendingShopPurchase then
     D.PendingShopPurchase.Accepted=result==true
     if result==true then D.BoughtOffers[action.OfferKey]=true
     elseif result==false then D.PendingShopPurchase=nil end
    end
    return result
   end)
   pending=false
   if not D.Alive then return end
   if ok and result==true then accepted=signature
   elseif not ok or result==false then
    if action.Endpoint=='dungeon_buy_shop'then D.PendingShopPurchase=nil end
    D.LastError=tostring(result);D.Status='Dungeon request failed • retrying'
   end
  end)
 end
 local panel=card('DungeonAutomationCard',462,550,438,696)
 label(root,'DungeonHeading','DUNGEON',480,564,402,28,18,true)
 local paints={}
 for i,entry in ipairs({{'Enabled','Auto Dungeon'},{'Start','Auto Start Dungeon'},{'Next','Auto Next Room'},{'Chests','Open Collected Chests'},{'Shop','Continue Past Shop'},{'Death','Continue After Defeat'},{'Finish','Finish After Opening Chests'}})do
  local key=entry[1]
  paints[#paints+1]=switch('Dungeon_'..key,entry[2],'',604+(i-1)*42,function()return C[key]end,function(v)
   C[key]=v;accepted=nil
   if key=='Enabled'and v then local guard=env.FyrelithAutoLeaveGuard;if guard and guard.Cancel then guard.Cancel()end end
   D.Save()
  end,480)
 end
 picker('Dungeon Route',480,910,function()return entries({'Balanced','Treasure','Money','Treasure + Money','Safest'})end,function()return C.Priority end,function(v)C.Priority=v.id;accepted=nil;D.Save();ui('Select_Dungeon Route').Value.Text=v.name end)
 picker('Shrine Offer',480,958,function()return entries({'Manual','Skip','Accept'})end,function()return C.Shrine end,function(v)C.Shrine=v.id;D.Save();ui('Select_Shrine Offer').Value.Text=v.name end)
 local status=label(root,'DungeonStatus','Disabled',480,1014,402,64,14,true);status.TextWrapped=true
 local inventory=label(root,'DungeonResources','',480,1080,402,56,13);inventory.TextWrapped=true
 local open=button('OpenDungeonMap','Open Dungeon Map',480,1150,402,function()
  local gui=env.FyrelithGameReady.Services.GUIService.dungeon_ui
  if gui and gui.toggle then gui:toggle(true)end
 end)
 root.Size=UDim2.fromOffset(908,math.max(root.Size.Y.Offset,1262));main.CanvasSize=UDim2.fromOffset(0,root.Size.Y.Offset)
 task.spawn(function()while api.Alive and D.Alive and gui.Parent do
  local ok,err=pcall(D.Tick);if not ok then D.LastError=tostring(err);D.Status='Dungeon check failed • retrying' end
  local current=data();local resources=current and current._resources or {};local level=Loader.LevelData
  status.Text=D.Status
  inventory.Text='Depth '..tostring(type(level)=='table'and type(level._dungeon)=='table'and level._dungeon.depth or '—')..' / '..tostring(core.NUM_ROOMS)..'\nCoins: '..tostring(resources.money or 0)..'   Chests: '..tostring(resources.treasure or 0)..'   Rare: '..tostring(resources.treasure_gold or 0)
  for _,paint in ipairs(paints)do paint()end
  if D.RefreshShopUI then local refreshed,refreshError=pcall(D.RefreshShopUI);if not refreshed then D.LastError=tostring(refreshError)end end
  task.wait(.75)
 end;D.Alive=false end)
end

do
 local target=main.Parent:FindFirstChild('Dungeon')
 assert(target,'Dungeon page unavailable')
 -- Reparent existing controls; their callbacks and saved settings remain attached.
 for _,item in ipairs(target:GetChildren())do if item:IsA('GuiObject')then item.Visible=false end end
 local switches={Enabled=true,Start=true,Next=true,Chests=true,Shop=true,Death=true,Finish=true}
 for _,item in ipairs(root:GetChildren())do if item:IsA('GuiObject')then
  local name=item.Name;local move=false
  if name=='DungeonAutomationCard'then
   item.Position=UDim2.fromOffset(8,8);item.Size=UDim2.fromOffset(892,374);move=true
  elseif name=='DungeonHeading'then item.Position=UDim2.fromOffset(26,20);move=true
  elseif name=='DungeonShopCard'or name=='DungeonShopTab'or name=='DungeonCurseTab'or name=='Dungeon_AutoBuy'or name=='Dungeon_UseCursePriority'then
   item.Position-=UDim2.fromOffset(0,882);move=true
  elseif name:sub(1,8)=='Dungeon_'and switches[name:sub(9)]then
   item.Position=UDim2.fromOffset(26,item.Position.Y.Offset-540);move=true
  elseif name=='Dungeon RouteLabel'or name=='Select_Dungeon Route'or name=='Shrine OfferLabel'or name=='Select_Shrine Offer'then
   item.Position-=UDim2.fromOffset(0,846);move=true
  elseif name=='DungeonStatus'then item.Position=UDim2.fromOffset(480,166);move=true
  elseif name=='DungeonResources'then item.Position=UDim2.fromOffset(480,238);move=true
  elseif name=='OpenDungeonMap'then item.Position=UDim2.fromOffset(480,310);move=true end
  if move then item.Parent=target end
 end end
 target.CanvasSize=UDim2.fromOffset(0,1120)
 local bottom=0
 for _,item in ipairs(root:GetChildren())do
  if item:IsA('GuiObject')and item.Visible and not item:GetAttribute('ViewportPopup')then bottom=math.max(bottom,item.Position.Y.Offset+item.Size.Y.Offset)end
 end
 root.Size=UDim2.fromOffset(908,bottom+16);main.CanvasSize=UDim2.fromOffset(0,bottom+16)
end

end
createAutoJoin()
if not fyOwnsExecution() then return end
fyExecution.Gui=playerGui:FindFirstChild('FyrelithUIOnly')
assert(fyExecution.Gui,'Fyrelith UI was not created')
-- FYRELITH_DUNGEON_EXTRAS_V1
assert(loadstring([=================[
-- Dungeon life guard and conditional Shrine policies. No dungeon_quit requests.
local E=getgenv()
local D=assert(E.FyrelithDungeon,'Dungeon automation is not ready')
local execution=assert(E.FyrelithExecutionState)
local gui=assert(execution.Gui)
local page=assert(gui:FindFirstChild('Dungeon',true))
local old=E.FyrelithDungeonExtras
if old and old.Close then old.Close()end
local X={Alive=true,Connections={},Objects={},Hidden={},OriginalTick=D.Tick,OriginalDecide=D.Decide,OriginalSave=D.Save}
E.FyrelithDungeonExtras=X
local L=require(game.ReplicatedStorage.src.Loader)
local core=L.load_core_service(script,'DungeonServiceCore')
local U=L.load_client_service(script,'UnitCollectionServiceClient')
local T=game:GetService('TeleportService')
local P=game:GetService('Players').LocalPlayer
local H=game:GetService('HttpService')
local storage=E.FyrelithDefaultLoaderStorage or E.FyrelithLoaderStorage
local read=storage and storage.Read or readfile
local C=D.Config
local settingsFile='FyrelithDungeon_'..P.UserId..'_'..game.GameId..'.json'
local saved={}
pcall(function()saved=H:JSONDecode(read(settingsFile))end)
if C.LeaveAtOneLife==nil then C.LeaveAtOneLife=type(saved.LeaveAtOneLife)=='boolean'and saved.LeaveAtOneLife or saved.LeaveAtOneLife==nil end
if type(C.ShrineRewards)~='table'then C.ShrineRewards=type(saved.ShrineRewards)=='table'and saved.ShrineRewards or {}end
local function on(signal,fn)X.Connections[#X.Connections+1]=signal:Connect(fn)end
local function data()return U.session and U.session.profile_data and U.session.profile_data.dungeon_data end
function X.Lives(state)
 local n=type(state)=='table'and type(state.selected_next)=='table'and tonumber(state.selected_next.lives)
 if n and n==n and n>=0 and n<=5 then return math.floor(n)end
end
function X.ShouldStop(state,config)
 local lives=X.Lives(state)
 return config.LeaveAtOneLife==true and type(state)=='table'and state._started==true and not state._dead and not state._finished and lives~=nil and lives<=1
end
local modes={
 {'Accept','Accept all'},
 {'Skip','Skip all'},
 {'Selected rewards','Selected rewards'},
 {'No curses','No curses'},
 {'Selected + no curses','Selected + no curses'},
}
X.Modes=modes
local supported={}
for _,mode in ipairs(modes)do supported[mode[1]]=true end
if not supported[C.Shrine]then
 if C.Shrine=='Manual'then C.Shrine='Skip'
 elseif C.Shrine=='Selected rewards + curses'then C.Shrine='Selected + no curses'
 else C.Shrine='No curses'end
end
local function isCurse(item)return item and(item.curse_chance~=nil or item.curse_super_chance~=nil)end
function X.ShrineDecision(state,config)
 local shop=state.current_shops and state.current_shops[1]
 if not shop or shop._t~=core.TYPES.SHRINE then return nil,'No shrine offer'end
 local mode=config.Shrine
 if mode=='Skip'then return {Endpoint='dungeon_continue_shop'},'Skipping shrine offer'end
 if mode=='Accept'then return {Endpoint='dungeon_shrine_accept'},'Accepting entire shrine offer'end
 local rewards,curses={},{}
 local unknown=false
 for _,entry in pairs(shop.data or {})do
  if type(entry)=='table'and entry._t=='Item'and core.ITEMS[entry.id]then
   local item=core.ITEMS[entry.id]
   if isCurse(item)then curses[#curses+1]={Id=entry.id,Data=item}else rewards[#rewards+1]={Id=entry.id,Data=item}end
  else unknown=true end
 end
 if unknown or #rewards+#curses==0 then return nil,'Shrine: waiting for a complete known offer'end
 local hasReward=false
 for _,reward in ipairs(rewards)do
  if config.ShrineRewards and config.ShrineRewards[reward.Id]==true then hasReward=true end
 end
 local accept=false
 if mode=='No curses'then accept=#curses==0
 elseif mode=='Selected rewards'then accept=hasReward
 elseif mode=='Selected + no curses'then accept=hasReward and #curses==0
 else return nil,'Shrine: choose a supported policy'end
 return {Endpoint=accept and 'dungeon_shrine_accept'or'dungeon_continue_shop'},accept and 'Accepting matching shrine offer'or'Skipping non-matching shrine offer'
end
local patchedDecide
patchedDecide=function(state,config)
 if X.ShouldStop(state,config)then return nil,'Stopped: only 1 dungeon life remains'end
 local shop=type(state)=='table'and state.current_shops and state.current_shops[1]
 if shop and shop._t==core.TYPES.SHRINE then return X.ShrineDecision(state,config)end
 return X.OriginalDecide(state,config)
end
D.Decide=patchedDecide
local function save()
 local ok,result=pcall(X.OriginalSave)
 return ok and result==true
end
local function returnToLobby()
 if L.IsLobby then X.PendingReturn=false;return end
 if not X.PendingReturn or os.clock()<(X.NextReturn or 0)then return end
 if (X.ReturnAttempts or 0)>=3 then D.Status='Auto Dungeon stopped; return to lobby manually';return end
 local macro=E.FyrelithMacro
 if macro and macro.State=='Finishing'then D.Status='Saving macro before returning to lobby';return end
 if macro and (macro.State=='Recording'or macro.State=='Paused'and macro.BeforePause=='Recording')then
  local ok,result=pcall(macro.Save)
  if not ok or result==false then D.Status='Macro save failed; return paused';return end
  macro.Token=(macro.Token or 0)+1;macro.State='Idle'
 end
 if not save()then D.Status='Cannot save stopped Dungeon setting; return paused';return end
 local runtime=E.FyrelithRuntime
 if runtime and runtime.Save then
  local ok,result=pcall(runtime.Save)
  if not ok or result==false then D.Status='Runtime save failed; return paused';return end
 end
 local settings=L.load_data(script,'GameplaySettings')
 local lobby=tonumber(settings.LOBBY_PLACE_ID)
 if not lobby then D.Status='Lobby destination unavailable';return end
 X.NextReturn=os.clock()+20;X.ReturnAttempts=(X.ReturnAttempts or 0)+1
 D.Status='1 life remaining: returning to lobby; Auto Dungeon is OFF'
 local ok,err=pcall(T.Teleport,T,lobby,P)
 if not ok then X.LastError=tostring(err);D.Status='Lobby return failed; retrying'end
end
local patchedTick
patchedTick=function()
 if not X.Alive then return end
 if X.PendingReturn then returnToLobby();return end
 local state=data()
 if C.Enabled and (L.IsLobby or D.InDungeon())and X.ShouldStop(state,C)then
  C.Enabled=false;X.StoppedAtOneLife=true;X.PendingReturn=not L.IsLobby
  D.Status='Stopped at 1 life; Auto Dungeon is OFF'
  save();returnToLobby();return
 end
 X.OriginalTick()
 if X.StoppedAtOneLife and not C.Enabled then D.Status='Stopped at 1 life; Auto Dungeon is OFF'end
end
D.Tick=patchedTick
on(T.TeleportInitFailed,function(player,_,message)
 if player==P and X.PendingReturn then X.LastError=tostring(message);X.NextReturn=os.clock()+15 end
end)
-- Reuse the script's existing surfaces and leave all other Dungeon controls intact.
local colors={BackgroundColor3=Color3.fromRGB(22,20,32),TextColor3=Color3.fromRGB(239,232,250)}
local function make(class,props,parent)
 local object=Instance.new(class)
 for key,value in pairs(props or {})do object[key]=value end
 object.Parent=parent;return object
end
local function round(object,r)make('UICorner',{CornerRadius=UDim.new(0,r or 9)},object)end
local function text(parent,name,value,x,y,w,h,size)
 return make('TextLabel',{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=colors.TextColor3,TextSize=size or 14,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left},parent)
end
local function button(parent,name,value,x,y,w,h)
 local object=make('TextButton',{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=colors.BackgroundColor3,TextColor3=colors.TextColor3,TextSize=14,Font=Enum.Font.GothamMedium,BorderSizePixel=0},parent)
 round(object);return object
end
local automation=page:FindFirstChild('DungeonAutomationCard')
local shifted={}
for _,object in ipairs(page:GetChildren())do
 if object:IsA('GuiObject')and object.Position.Y.Offset>=398 then shifted[object]=object.Position;object.Position+=UDim2.fromOffset(0,54)end
end
X.Shifted=shifted
if automation then X.OldAutomationSize=automation.Size;automation.Size+=UDim2.fromOffset(0,54)end
local lifeRow=make('Frame',{Name='DungeonLifeGuard',Position=UDim2.fromOffset(26,360),Size=UDim2.fromOffset(402,42),BackgroundTransparency=1},page)
X.Objects[#X.Objects+1]=lifeRow
text(lifeRow,'Title','Leave at 1 heart',0,0,300,42,16)
local lifeButton=button(lifeRow,'Toggle','',0,0,402,42)
lifeButton.BackgroundTransparency=1;lifeButton.AutoButtonColor=false
local reference=page:FindFirstChild('Dungeon_Finish')
local nativeTrack=reference and reference:FindFirstChild('Track')
local track=nativeTrack and nativeTrack:Clone()or make('Frame',{Size=UDim2.fromOffset(54,29),BorderSizePixel=0})
track.Name='Track';track.Position=UDim2.fromOffset(346,6);track.Parent=lifeButton
if not track:FindFirstChildOfClass('UICorner')then round(track,15)end
local knob=track:FindFirstChild('Knob')or make('Frame',{Name='Knob',Size=UDim2.fromOffset(21,21),BackgroundColor3=Color3.fromRGB(240,243,249),BorderSizePixel=0},track)
if not knob:FindFirstChildOfClass('UICorner')then round(knob,11)end
local offColor=nativeTrack and nativeTrack.BackgroundColor3 or Color3.fromRGB(75,55,68)
local function accent()
 for _,row in ipairs(gui:QueryDescendants('TextButton'))do
  local other=row:FindFirstChild('Track')
  if other and other~=track and row:GetAttribute('Enabled')==true then return other.BackgroundColor3 end
 end
 return Color3.fromRGB(220,146,172)
end
local function paintLife(animate)
 lifeButton.Text='';lifeButton:SetAttribute('Enabled',C.LeaveAtOneLife)
 local color=C.LeaveAtOneLife and accent()or offColor
 local position=UDim2.fromOffset(C.LeaveAtOneLife and 29 or 4,4)
 if animate then
  local tween=game:GetService('TweenService')
  tween:Create(track,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=color}):Play()
  tween:Create(knob,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=position}):Play()
 else track.BackgroundColor3=color;knob.Position=position end
end
on(lifeButton.Activated,function()C.LeaveAtOneLife=not C.LeaveAtOneLife;save();paintLife(true)end)
paintLife(false)

local picker=assert(page:FindFirstChild('Select_Shrine Offer'),'Native Shrine picker is missing')
picker.Visible=true
local refreshPolicyUI
local function paintMode()
 local title=C.Shrine
 for _,mode in ipairs(modes)do if mode[1]==C.Shrine then title=mode[2];break end end
 picker.Value.Text=title
 if refreshPolicyUI then refreshPolicyUI()end
end
local rebound=false
for _,connection in ipairs(getconnections(picker.Activated))do
 local callback=connection.Function
 if type(callback)=='function'then
  local values=debug.getupvalues(callback)
  if values[1]==picker and type(values[4])=='function'and values[15]==picker:FindFirstChild('Value')and type(values[17])=='function'then
   local originalOptions,originalSelected=values[4],values[17]
   local options=function()
    local all={}
    for _,mode in ipairs(modes)do all[#all+1]={id=mode[1],name=mode[2]}end
    return all
   end
   local selected=function(entry)originalSelected(entry);paintMode()end
   debug.setupvalue(callback,4,options)
   debug.setupvalue(callback,17,selected)
   X.RestorePicker=function()
    local current=debug.getupvalues(callback)
    if current[4]==options then debug.setupvalue(callback,4,originalOptions)end
    if current[17]==selected then debug.setupvalue(callback,17,originalSelected)end
    if type(values[3])=='function'then values[3]()end
   end
   rebound=true;break
  end
 end
end
assert(rebound,'Could not update native Shrine picker callbacks')
X.NativePicker=picker
paintMode()

local panel=make('Frame',{Name='ShrineRewardSettings',Position=UDim2.fromOffset(8,1176),Size=UDim2.fromOffset(892,526),BackgroundColor3=colors.BackgroundColor3,BackgroundTransparency=.08,BorderSizePixel=0},page)
round(panel,12);X.Objects[#X.Objects+1]=panel
text(panel,'Title','SHRINE • REWARD FILTER',18,12,840,28,18)
local note=text(panel,'Note','Choose any reward below. The game accepts the entire offer together.',18,48,850,44,13);note.TextWrapped=true
local selectedNote=text(panel,'Selected','',18,98,460,26,14)
local clear=button(panel,'Clear','Clear selections',650,96,220,30)
local search=make('TextBox',{Name='Search',PlaceholderText='Search rewards / description',Text='',ClearTextOnFocus=false,Position=UDim2.fromOffset(18,136),Size=UDim2.fromOffset(852,36),BackgroundColor3=Color3.fromRGB(14,13,23),TextColor3=colors.TextColor3,TextSize=14,Font=Enum.Font.Gotham,BorderSizePixel=0},panel);round(search)
local list=make('ScrollingFrame',{Name='Rewards',Position=UDim2.fromOffset(18,184),Size=UDim2.fromOffset(852,324),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new()},panel)
local rewards={}
for id,item in pairs(core.ITEMS)do if type(item)=='table'and not isCurse(item)then rewards[#rewards+1]={Id=id,Data=item}end end
table.sort(rewards,function(a,b)return tostring(a.Data.name or a.Id)<tostring(b.Data.name or b.Id)end)
local rows={}
local function draw()
 local y=0;local query=search.Text:lower();local count=0
 for _,item in ipairs(rewards)do
  local row=rows[item.Id]
  if C.ShrineRewards[item.Id]then count+=1 end
  local show=(tostring(item.Data.name or item.Id)..' '..tostring(item.Data.description or '')):lower():find(query,1,true)~=nil
  row.Visible=show
  row.Text=(C.ShrineRewards[item.Id]and '✓  'or'○  ')..tostring(item.Data.name or item.Id)..'  •  '..tostring(item.Data.description or '')
  row.BackgroundColor3=C.ShrineRewards[item.Id]and Color3.fromRGB(72,51,101)or Color3.fromRGB(30,27,43)
  if show then row.Position=UDim2.fromOffset(0,y);y+=44 end
 end
 selectedNote.Text=tostring(count)..' selected rewards';list.CanvasSize=UDim2.fromOffset(0,y)
end
for index,item in ipairs(rewards)do
 local row=button(list,'Reward_'..item.Id,'',0,(index-1)*44,836,38);row.TextSize=13;row.TextXAlignment=Enum.TextXAlignment.Left;row.TextTruncate=Enum.TextTruncate.AtEnd
 make('UIPadding',{PaddingLeft=UDim.new(0,12)},row);rows[item.Id]=row
 on(row.Activated,function()C.ShrineRewards[item.Id]=not C.ShrineRewards[item.Id]or nil;save();draw()end)
end
on(search:GetPropertyChangedSignal('Text'),draw)
on(clear.Activated,function()table.clear(C.ShrineRewards);save();draw()end)
refreshPolicyUI=function()
 local selected=C.Shrine=='Selected rewards'or C.Shrine=='Selected + no curses'
 panel.Visible=selected
 note.Text=C.Shrine=='Selected + no curses'and 'Accept only when an offer contains a selected reward and has no curses.'or 'Accept when any selected reward is offered. Curses in the same offer are accepted too.'
 page.CanvasSize=UDim2.fromOffset(0,selected and 1720 or 1176)
end
draw();refreshPolicyUI()
function X.Close()
 if not X.Alive then return end;X.Alive=false
 if D.Tick==patchedTick then D.Tick=X.OriginalTick end
 if D.Decide==patchedDecide then D.Decide=X.OriginalDecide end
 if X.RestorePicker then X.RestorePicker()end
 for _,connection in ipairs(X.Connections)do connection:Disconnect()end
 for _,object in ipairs(X.Objects)do object:Destroy()end
 for object,visible in pairs(X.Hidden)do if object.Parent then object.Visible=visible end end
 for object,position in pairs(X.Shifted)do if object.Parent then object.Position=position end end
 if automation and automation.Parent and X.OldAutomationSize then automation.Size=X.OldAutomationSize end
end
on(gui.Destroying,X.Close)
X.Installed=true
save()

]=================], 'Fyrelith Dungeon Extras'))()

-- FYRELITH_SMART_FARM_POLICY_V1
assert(loadstring([===================[
-- Smart Play in every mode: cap damage at 4 only until the farm economy is complete.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay,'Auto Play is not ready')
local old=E.FyrelithSmartFarmPolicy
if old and old.Close then old.Close()end
local X={Alive=true,DamageUpgradeCap=4,FarmTarget=3,SafeProgress=.10,OriginalPlan=A.GetCombatPlan,OriginalSelect=A.SelectInvestment,OriginalProfile=A.ConfigureInvestmentProfile}
E.FyrelithSmartFarmPolicy=X
local Loader=require(game.ReplicatedStorage.src.Loader)
local function role(id)return A.SmartRole(id)end
function X.Analyze(all,context,equipped)
 local policy={FarmCount=0,FarmUpgraded=0,FarmUnfinished=false,FarmTargets={},FarmCounts={},FarmMissing=0,Attackers=0,CoreAtFour=false,Highest=0,ProgressKnown=true}
 policy.Dungeon=type(Loader.LevelData)=='table'and type(Loader.LevelData._dungeon)=='table'
 policy.DamageTypes={}
 local definitions={}
 local capacity=0
 for _,unit in ipairs(equipped or {})do
  definitions[unit.Id]=unit.Data
  if role(unit.Id)=='farm'then
   local cap=A.PlacementCap and A.PlacementCap(unit.Id,unit.Data)or tonumber(unit.Data.spawn_cap)or 1
   if A.TeamPolicy then local setting=A.TeamPolicy.Get(unit.Id);cap=setting.Place and math.min(cap,setting.MaxPlaced)or 0 end
   policy.FarmTargets[unit.Id]=math.max(policy.FarmTargets[unit.Id]or 0,math.max(0,cap))
  end
 end
 for _,tower in ipairs(all)do
  local kind=role(tower.Id)
  if kind=='farm'then
   policy.FarmCount+=1
   policy.FarmCounts[tower.Id]=(policy.FarmCounts[tower.Id]or 0)+1
   if (tonumber(tower.Upgrade)or 0)>=1 then policy.FarmUpgraded+=1 end
   local definition=definitions[tower.Id]
   local nextUpgrade=definition and definition.upgrade and definition.upgrade[(tower.Upgrade or 0)+1]
   if not nextUpgrade and A.NativeUpgradeInfo then nextUpgrade=A.NativeUpgradeInfo(tower)end
   if nextUpgrade then policy.FarmUnfinished=true end
  elseif kind=='damage'then
   policy.DamageTypes[tower.Id]=true
   policy.Attackers+=1
   if (tonumber(tower.Upgrade)or 0)>=X.DamageUpgradeCap then policy.CoreAtFour=true end
  end
 end
 for id,target in pairs(policy.FarmTargets)do capacity+=target;policy.FarmMissing+=math.max(0,target-(policy.FarmCounts[id]or 0))end
 policy.FarmTarget=capacity
 for _,enemy in ipairs(context.Enemies or {})do
  if enemy.HP==nil or (tonumber(enemy.HP)or 0)>0 then
   local progress=tonumber(enemy.Progress)
   if progress and progress==progress and progress>=0 and progress<=1 then policy.Highest=math.max(policy.Highest,progress)
   else policy.ProgressKnown=false end
  end
 end
 policy.Safe=policy.Attackers>0 and policy.ProgressKnown and policy.Highest<=X.SafeProgress
 if A.FarmClosing then policy.FarmTarget=0;policy.FarmMissing=0;policy.FarmUnfinished=false end
 return policy
end
function X.FarmsComplete(policy)
 return policy~=nil and ((policy.FarmTarget or 0)<1 or policy.FarmCount>=policy.FarmTarget and (policy.FarmMissing or 0)==0 and not policy.FarmUnfinished)
end
function X.CanDamageUpgrade(choice,policy)
 if choice.Role~='damage'or choice.Kind=='Place'then return true end
 if not policy or X.FarmsComplete(policy)then return true end
 local target=choice.Tower and (tonumber(choice.Tower.Upgrade)or 0)+1
 return target~=nil and target<=X.DamageUpgradeCap
end
function X.Filter(candidates,policy)
 local filtered={}
 for _,choice in ipairs(candidates)do


  local overCap=not X.CanDamageUpgrade(choice,policy)
  local extraFarm=false
  if choice.Role=='farm'and choice.Kind=='Place'and policy then
   local id=choice.Unit and choice.Unit.Id
   if id and policy.FarmTargets then extraFarm=(policy.FarmCounts[id]or 0)>=(policy.FarmTargets[id]or 0)
   else extraFarm=policy.FarmTarget>0 and policy.FarmCount>=policy.FarmTarget end
  end
  if not overCap and not extraFarm then filtered[#filtered+1]=choice end
 end
 return filtered
end
-- A handled nil means save money for the required step, never spend it on damage instead.
function X.PostFarmDamage(groups,p,cash,budget,combat)
 if p.Dungeon or not X.FarmsComplete(p)then return nil,nil,false end
 local bestNew,best,buff
 local function better(a,b)return not b or (a.Score or 0)>(b.Score or 0)or a.Score==b.Score and a.Cost<b.Cost end
 for _,choice in ipairs(groups.buffPlace or{})do if choice.Cost<=cash and better(choice,buff)then buff=choice end end
 if buff and(not combat or not combat.Urgent)and(budget and(tonumber(budget.PrimarySinceSupport)or 0)>=3)then return buff,'place the next useful buff unit between damage investments',true end
 for _,choice in ipairs(groups.damagePlace)do
  if choice.Cost<=cash then
   local id=choice.Unit and choice.Unit.Id
   if id and not (p.DamageTypes and p.DamageTypes[id])and better(choice,bestNew)then bestNew=choice end
   if better(choice,best)then best=choice end
  end
 end
 if bestNew then return bestNew,'farms complete: deploy another equipped damage type',true end
 for _,choice in ipairs(groups.damageUpgrade)do if choice.Cost<=cash and better(choice,best)then best=choice end end
 if best then return best,'farms complete: invest available cash in damage',true end
 if buff then return buff,'place useful buff while the next damage investment is unaffordable',true end
 if #groups.damagePlace+#groups.damageUpgrade>0 then return nil,'saving for the next available damage action',true end
 return nil,nil,false
end

function X.Choose(candidates,combat,cash,budget)
 local p=combat.FarmPolicy
 if not p then return nil,nil,false end
 local groups={farmPlace={},farmUpgrade={},farmFirstUpgrade={},damagePlace={},damageUpgrade={},buffPlace={}}
 for _,choice in ipairs(candidates)do
  if not choice.Excluded and choice.Ready~=false and (choice.Score or 0)>0 then
   if choice.Role=='farm'then
    if choice.Kind=='Place'then groups.farmPlace[#groups.farmPlace+1]=choice
    else
     groups.farmUpgrade[#groups.farmUpgrade+1]=choice
     if choice.Tower and (tonumber(choice.Tower.Upgrade)or 0)<1 then groups.farmFirstUpgrade[#groups.farmFirstUpgrade+1]=choice end
    end
   elseif choice.Role=='damage'then
    local list=choice.Kind=='Place'and groups.damagePlace or groups.damageUpgrade
    list[#list+1]=choice
   elseif choice.Role=='buff'and choice.Kind=='Place'then
    groups.buffPlace[#groups.buffPlace+1]=choice
   end
  end
 end
 local function best(list,concentrate)
  local selected
  for _,choice in ipairs(list)do
   if choice.Cost<=cash then
    local better=not selected
    if selected then
     local level=concentrate and choice.Tower and choice.Tower.Upgrade or 0
     local other=concentrate and selected.Tower and selected.Tower.Upgrade or 0
     better=level>other or level==other and ((choice.Score or 0)>(selected.Score or 0)or choice.Score==selected.Score and choice.Cost<selected.Cost)
    end
    if better then selected=choice end
   end
  end
  return selected
 end
 if p.Attackers<1 then
  return best(groups.damagePlace),'place the first defender before building the farm economy',true
 end
 local post,postReason,postHandled=X.PostFarmDamage(groups,p,cash,budget,combat)
 if postHandled then return post,postReason,true end
 if p.FarmTarget<1 then return nil,nil,false end
 if p.FarmCount<p.FarmTarget or(p.FarmMissing or 0)>0 then
  local placement=best(groups.farmPlace)
  if placement then return placement,'place farms first ('..p.FarmCount..'/'..p.FarmTarget..') before damage upgrades',true end
  if #groups.farmPlace==0 then
   local first=best(groups.farmFirstUpgrade)
   if first then return first,'farm position unavailable: upgrade existing farms while retrying placement',true end
   if not p.Safe then local defense=best(groups.damagePlace)or best(groups.damageUpgrade,true);if defense then return defense,'farm position unavailable: keep defense progressing while retrying',true end end
   local income=best(groups.farmUpgrade)
   if income then return income,'farm position unavailable: improve existing income while retrying',true end
  end
  return nil,'place farms first ('..p.FarmCount..'/'..p.FarmTarget..') before damage upgrades',true
 end
 if p.FarmUpgraded<p.FarmTarget then
  return best(groups.farmFirstUpgrade),'upgrade every farm to at least 1 before damage upgrades',true
 end
 if p.FarmUnfinished and (p.Safe or p.CoreAtFour)then
  return best(groups.farmUpgrade),p.Safe and 'max farms first: enemies have not passed 10% of the path'or'max farms first: damage core reached upgrade 4',true
 end
 if p.FarmUnfinished then
  if combat.Defense and combat.Defense.Mode=='Defense' then
   local placement=best(groups.damagePlace)
   if placement then return placement,'cover the lane with an affordable defender before saving for an expensive upgrade',true end
  end
  local damage=best(groups.damageUpgrade,true)
  if damage then return damage,'enemy passed 10%: strengthen defense, up to upgrade 4',true end
  local placement=best(groups.damagePlace)
  if placement then return placement,'deploy affordable damage while the next upgrade is too expensive',true end
  if not combat.Urgent then local income=best(groups.farmUpgrade);if income then return income,'increase farm income while the defense upgrade is unaffordable',true end end
  if #groups.damageUpgrade>0 then return nil,'saving for defense upgrade (maximum 4)',true end
  return best(groups.farmUpgrade),'damage upgrade cap reached: finish farm upgrades',true
 end
 return nil,nil,false
end
local patchedPlan
patchedPlan=function(all,context)
 local combat=X.OriginalPlan(all,context)
 if A.Config.Smart then combat.FarmPolicy=X.Analyze(all,context,A.GetEquipped())end
 X.LastAnalysis=combat.FarmPolicy
 return combat
end
local patchedSelect
patchedSelect=function(candidates,combat,cash,budget,blocked)
 if not A.Config.Smart then return X.OriginalSelect(candidates,combat,cash,budget,blocked)end
 for _,choice in ipairs(candidates)do
  if choice.Kind=='Upgrade'and choice.Tower and choice.Tower.Id=='aqua_evolved'then choice.Role='damage'end
 end
 local filtered=X.Filter(candidates,combat.FarmPolicy)
 local choice,reason,handled=X.Choose(filtered,combat,cash,budget)
 if handled then X.LastReason=reason;return choice,reason end
 return X.OriginalSelect(filtered,combat,cash,budget,blocked)
end
local patchedProfile
patchedProfile=function(combat,context,level)
 X.OriginalProfile(combat,context,level)
 local p=combat.FarmPolicy
 if A.Config.Smart and p and not p.Dungeon and(X.FarmsComplete(p)or not p.Safe and p.FarmCount>=p.FarmTarget and p.FarmUpgraded>=p.FarmTarget)then
  combat.NeedsDamagePlacement=true
 end
end
A.ConfigureInvestmentProfile=patchedProfile
A.GetCombatPlan=patchedPlan
A.SelectInvestment=patchedSelect
function X.Close()
 X.Alive=false
 if A.GetCombatPlan==patchedPlan then A.GetCombatPlan=X.OriginalPlan end
 if A.ConfigureInvestmentProfile==patchedProfile then A.ConfigureInvestmentProfile=X.OriginalProfile end
 if A.SelectInvestment==patchedSelect then A.SelectInvestment=X.OriginalSelect end
end
X.Installed=true

]===================], 'Fyrelith Smart Farm Policy'))()
-- FYRELITH_SMART_DUNGEON_ELEMENTS_V1
assert(loadstring([=====================[
-- Smart Play only: prefer equipped damage units that match Dungeon amplification.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay,'Auto Play is not ready')
local prior=E.FyrelithSmartDungeonElements
if prior and prior.Close then prior.Close()end
local L=require(game.ReplicatedStorage.src.Loader)
local X={Alive=true,OriginalSelect=A.SelectInvestment,OriginalPosition=A.SmartPosition}
E.FyrelithSmartDungeonElements=X
function X.Match(definition,effects)
 if type(definition)~='table'then return 0 end
 local types={[definition._base_damage_type or definition.base_damage_type or 'physical']=true}
 for kind,enabled in pairs(definition._secondary_damage_types or {})do if enabled then types[kind]=true end end
 local amplification=0
 for _,effect in pairs(effects or {})do
  if type(effect)=='table'and types[effect.damage_type]then amplification=math.max(amplification,tonumber(effect.amplification)or 0)end
 end
 return amplification
end
function X.Preferred(equipped,level)
 local preferred={}
 if type(level)~='table'or type(level._dungeon)~='table'then return preferred end
 for _,unit in ipairs(equipped or {})do
  local kind=unit.Role or A.SmartRole(unit.Id)
  if kind=='damage'then
   local strength=X.Match(unit.Data,level._weak_against)
   if strength>0 then preferred[unit.Id]=strength end
  end
 end
 return preferred
end
function X.Prioritize(candidates,preferred,policy)
 local eligible=false
 for _,choice in ipairs(candidates)do
  local id=choice.Tower and choice.Tower.Id or choice.Unit and choice.Unit.Id
  local withinCap=not E.FyrelithSmartFarmPolicy or E.FyrelithSmartFarmPolicy.CanDamageUpgrade(choice,policy)
  if choice.Role=='damage'and preferred[id]and withinCap and not choice.Excluded and choice.Ready~=false and (choice.Score or 0)>0 then eligible=true;break end
 end
 if not eligible then return candidates,false end
 local result={}
 for _,choice in ipairs(candidates)do
  local id=choice.Tower and choice.Tower.Id or choice.Unit and choice.Unit.Id
  if choice.Role~='damage'or preferred[id]then result[#result+1]=choice end
 end
 return result,true
end

local positionUpvalues=debug.getupvalues(X.OriginalPosition)
local enemyContext=positionUpvalues[3]
local pathScore=positionUpvalues[12]
local hitsFlying=positionUpvalues[13]
local rejected=positionUpvalues[10]
local Placement=L.load_core_service(script,'PlacementCore')
function X.HillEdgePosition(unit,all,context)
 local preferred=X.Preferred(A.GetEquipped(),L.LevelData)
 if not A.Config.Smart or not preferred[unit.Id]or unit.Data.hill_unit~=true then return end
 context=context or enemyContext()
 local circles=A.GetSmartCircles()
 local padding=A.GetSmartPlacementMargin(unit.Id)
 local snapshot=A.PlacementSnapshot(unit,all)
 local root=Placement.HillRaycastParts
 if typeof(root)~='Instance'then return end
 local parts=root:QueryDescendants('BasePart')
 if root:IsA('BasePart')then parts[#parts+1]=root end
 local range=tonumber(unit.Data.range)or 10
 local best,bestKey,bestScore=nil,nil,-math.huge
 local tested,valid=0,0
 local seen={}
 for _,circle in ipairs(circles)do
  local center=Vector3.new(unpack(circle.Center))
  local radius=math.clamp(tonumber(circle.Radius)or 36,8,80)-padding
  if radius<=0 then continue end
  for _,part in ipairs(parts)do
   if part.Name=='_donotplace'then continue end
   local minX,minZ,maxX,maxZ=math.huge,math.huge,-math.huge,-math.huge
   for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
    local p=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X*sx/2,part.Size.Y/2,part.Size.Z*sz/2))
    minX=math.min(minX,p.X);maxX=math.max(maxX,p.X);minZ=math.min(minZ,p.Z);maxZ=math.max(maxZ,p.Z)
   end end
   minX=math.max(minX,center.X-radius);maxX=math.min(maxX,center.X+radius)
   minZ=math.max(minZ,center.Z-radius);maxZ=math.min(maxZ,center.Z+radius)
   if minX>maxX or minZ>maxZ then continue end
   for x=minX,maxX,.75 do for z=minZ,maxZ,.75 do
    if (x-center.X)^2+(z-center.Z)^2>radius^2 then continue end
    local gridKey=string.format('%.2f:%.2f',x,z)
    if seen[gridKey]then continue end;seen[gridKey]=true
    tested+=1
    if tested>2400 then break end
    local hit=A.RaycastSmartGround(Vector3.new(x,center.Y,z),unit.Data)
    if not hit or not Placement.is_valid_raycast_hit(hit.Instance,unit.Data)or not A.IsWithinSmartAreas(hit.Position,circles,padding)then continue end
    local key=string.format('%s:%.1f:%.1f',unit.Id,hit.Position.X,hit.Position.Z)
    if type(rejected)=='table'and rejected[key]and os.clock()-rejected[key]<60 then continue end
    if not A.PlacementIsClear(hit.Position,snapshot)then continue end
    if A.BuffPositionAllowed and not A.BuffPositionAllowed(unit.Id,hit.Position,all)then continue end
    local coverage=pathScore(hit.Position,range,context)
    if coverage<=0 then continue end
    if (context.UncoveredLanes or 0)>0 and context.SampleRoutes then
     local coversWeak=false
     for index,p in ipairs(context.Samples)do
      local delta=p-hit.Position
      if context.WeakRoutes[context.SampleRoutes[index]]and Vector3.new(delta.X,0,delta.Z).Magnitude<=range then coversWeak=true;break end
     end
     if not coversWeak then continue end
    end
    valid+=1
    local score=coverage*3+A.FrontlinePositionScore(hit.Position,range,context)
    for _,enemy in ipairs(context.Enemies or {})do
     local delta=enemy.Position-hit.Position
     if (not enemy.Flying or hitsFlying(unit.Id,0))and Vector3.new(delta.X,0,delta.Z).Magnitude<=range then score+=(enemy.Dangerous and 14 or 2)+(enemy.Progress or 0)*8 end
    end
    if score>bestScore then best=CFrame.new(hit.Position);bestScore=score;bestKey=key end
   end;if tested>2400 then break end end
   if tested>2400 then break end
  end
  if tested>2400 then break end
 end
 X.HillDiagnostics={Unit=unit.Id,Tested=tested,Valid=valid,Found=best~=nil}
 return best,bestKey,bestScore
end
local patchedPosition
patchedPosition=function(unit,all,context)
 local position,key,score=X.OriginalPosition(unit,all,context)
 if position then return position,key,score end
 local fallback,fallbackKey,fallbackScore=X.HillEdgePosition(unit,all,context)
 if fallback then return fallback,fallbackKey,fallbackScore end
 return nil,key,score
end
A.SmartPosition=patchedPosition

local patchedSelect
patchedSelect=function(candidates,combat,cash,budget,blocked)
 if not A.Config.Smart then return X.OriginalSelect(candidates,combat,cash,budget,blocked)end
 local preferred=X.Preferred(A.GetEquipped(),L.LevelData)
 local filtered,focused=X.Prioritize(candidates,preferred,combat.FarmPolicy)
 X.LastPreferred=preferred;X.Focused=focused
 local invested=false
 for _,tower in ipairs(A.GetTowers())do if preferred[tower.Id]and A.SmartRole(tower.Id)=='damage'then invested=true;break end end
 local farm=combat.FarmPolicy
 local initialPreferred=focused and not invested and (not farm or farm.Attackers<1 or not farm.FarmUnfinished or not farm.Safe and farm.FarmCount>=farm.FarmTarget and farm.FarmUpgraded>=farm.FarmTarget)
 local decisionCombat=combat
 if initialPreferred and combat.HoldDamage then decisionCombat=table.clone(combat);decisionCombat.HoldDamage=false end
 local choice,reason=X.OriginalSelect(filtered,decisionCombat,cash,budget,blocked)
 if focused and choice and choice.Role=='damage'then
  local id=choice.Tower and choice.Tower.Id or choice.Unit and choice.Unit.Id
  X.LastBuffPercent=(preferred[id]or 0)*100
  reason='Buffed defense: '..tostring(id)..' • '..tostring(reason or 'damage investment')
 end
 X.LastChoice=choice and {Role=choice.Role,Id=choice.Tower and choice.Tower.Id or choice.Unit and choice.Unit.Id,Kind=choice.Kind}or nil
 return choice,reason
end
A.SelectInvestment=patchedSelect
function X.Close()
 X.Alive=false
 if A.SelectInvestment==patchedSelect then A.SelectInvestment=X.OriginalSelect end
 if A.SmartPosition==patchedPosition then A.SmartPosition=X.OriginalPosition end
end
X.Installed=true

]=====================], 'Fyrelith Smart Dungeon Elements'))()
-- FYRELITH_SMART_AREA_VISUALS_V1
assert(loadstring([=======================[
-- AREA labels, a clear center, and brighter violet/pink perimeter glow.
local E=getgenv()
local prior=E.FyrelithSmartAreaVisuals
if prior and prior.Close then prior.Close()end
local X={Connections={},Seen=setmetatable({},{__mode='k'}),Roots=setmetatable({},{__mode='k'})}
E.FyrelithSmartAreaVisuals=X
local function on(signal,callback)X.Connections[#X.Connections+1]=signal:Connect(callback)end
local function vivid(color)
 local h,s=color:ToHSV()
 return Color3.fromHSV(h,math.max(.85,s),1)
end
local concealed={TwinTriangleSeal=true,CenterCompass=true,CompassPoint=true,AstralSurveyMarks=true,CounterRotatingRunes=true,ThreeOrbitComets=true,InnerSeal=true,InnerEcho=true,SigilInnerRing=true,SigilInnerHairline=true,EclipseWave=true,EclipseStar=true}
X.Decorations=setmetatable({},{__mode='k'})
local function ornament(art)
 if X.Decorations[art]then return end
 local previous=art:FindFirstChild('AreaPrecisionOrnament')
 if previous then previous:Destroy()end
 local group=Instance.new('Frame');group.Name='AreaPrecisionOrnament';group.Size=UDim2.fromScale(1,1);group.BackgroundTransparency=1;group.Active=false;group.ZIndex=4
 local tinted={}
 local function polar(radius,angle)return Vector2.new(.5+math.cos(angle)*radius,.5+math.sin(angle)*radius)end
 local function line(name,from,to,width,alpha,mix)
  local delta=to-from
  local f=Instance.new('Frame');f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale((from.X+to.X)/2,(from.Y+to.Y)/2)
  f.Size=UDim2.fromOffset(math.max(.5,delta.Magnitude*1024+.25),width);f.Rotation=math.deg(math.atan2(delta.Y,delta.X));f.BackgroundTransparency=alpha;f.BorderSizePixel=0;f.Active=false;f.ZIndex=4
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=f
  f.Parent=group;tinted[#tinted+1]={Object=f,Mix=mix or 0};return f
 end
 local function arc(radius,startAngle,endAngle,width,alpha,mix)
  local steps=math.ceil((endAngle-startAngle)/math.rad(2))
  for i=0,steps-1 do line('PrecisionArc',polar(radius,startAngle+(endAngle-startAngle)*i/steps),polar(radius,startAngle+(endAngle-startAngle)*(i+1)/steps),width,alpha,mix)end
 end
 for quadrant=0,3 do
  local a=quadrant*math.pi/2
  -- Paired concentric arcs have matching gaps around the four cardinal inlays.
  arc(.438,a+math.rad(12),a+math.rad(78),2.6,.09,.12)
  arc(.420,a+math.rad(16),a+math.rad(74),1,.52,.28)
  for i=-2,2 do
   local t=a+i*math.rad(2.7)
   line('CardinalIndex',polar(i==0 and .452 or .463,t),polar(.480,t),i==0 and 3.8 or 1.6,i==0 and .03 or .38,i==0 and .42 or .08)
  end
  -- A small faceted inlay replaces the old hand-drawn rune clusters.
  local c=polar(.438,a);local radial=Vector2.new(math.cos(a),math.sin(a));local tangent=Vector2.new(-math.sin(a),math.cos(a))
  local top=c+radial*.010;local bottom=c-radial*.010;local left=c+tangent*.006;local right=c-tangent*.006
  line('Inlay',top,left,1.8,.08,.4);line('Inlay',left,bottom,1.8,.08,.4)
  line('Inlay',bottom,right,1.8,.08,.4);line('Inlay',right,top,1.8,.08,.4)
  local between=a+math.pi/4
  line('ArcSeparator',polar(.428,between),polar(.448,between),2,.22,.25)
 end
 group.Parent=art
 local function tint(color)
  color=vivid(color)
  for _,entry in ipairs(tinted)do if entry.Object.Parent then entry.Object.BackgroundColor3=color:Lerp(Color3.new(1,1,1),entry.Mix)end end
 end
 X.Decorations[art]={Group=group,Tint=tint}
 local boundary=art:FindFirstChild('TruePlacementBoundary')
 local stroke=boundary and boundary:FindFirstChildOfClass('UIStroke')
 tint(stroke and stroke.Color or Color3.fromRGB(225,100,216))
end

local function style(object)
 if X.Seen[object]then return end;X.Seen[object]=true
 if object:IsA('Frame')and (object.Name=='FyrelithAstralSigil'or object.Name=='FyrelithEclipseCrown')then
  ornament(object)
 elseif object:IsA('GuiObject')and concealed[object.Name]then
  object.Visible=false
 elseif object:IsA('TextLabel')and object.Name=='AreaTitle'then
  local function rename()
   local index=object.Text:match('(%d+)$')or '01'
   local title='AREA '..index
   if object.Text~=title then object.Text=title end
  end
  rename();on(object:GetPropertyChangedSignal('Text'),rename)
 elseif object:IsA('UIStroke')and object.Parent and object.Parent.Name~='BoundaryContrast'then
  local function paint()
   if not object.Parent then return end
   local color=vivid(object.Color)
   if math.abs(object.Color.R-color.R)+math.abs(object.Color.G-color.G)+math.abs(object.Color.B-color.B)>.0001 then object.Color=color end
  end
  paint();on(object:GetPropertyChangedSignal('Color'),paint)
  if object.Parent.Name=='BoundaryAura'then object.Thickness=20;object.Transparency=.36 end
  if object.Parent.Name=='TruePlacementBoundary'then
   object.Thickness=7
   local art=object.Parent.Parent
   if art then
    ornament(art)
    local decoration=X.Decorations[art]
    if decoration then decoration.Tint(object.Color);on(object:GetPropertyChangedSignal('Color'),function()if art.Parent then decoration.Tint(object.Color)end end)end
   end
   local parent=object.Parent.Parent
   if parent and not parent:FindFirstChild('AreaOuterGlow')then
    for index,layer in ipairs({{Name='AreaOuterGlow',Width=34,Alpha=.78},{Name='AreaInnerGlow',Width=20,Alpha=.56}})do
     local frame=Instance.new('Frame');frame.Name=layer.Name;frame.AnchorPoint=Vector2.new(.5,.5);frame.Position=UDim2.fromScale(.5,.5);frame.Size=UDim2.fromScale(1,1);frame.BackgroundTransparency=1;frame.Active=false;frame.ZIndex=2
     local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=frame
     local stroke=Instance.new('UIStroke');stroke.Name='AreaGlowStroke';stroke.Thickness=layer.Width;stroke.Transparency=layer.Alpha;stroke.Color=vivid(object.Color);stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=frame
     frame.Parent=parent
     on(object:GetPropertyChangedSignal('Color'),function()if stroke.Parent then stroke.Color=vivid(object.Color)end end)
    end
   end
  end
 end
end
local function attach(root)
 if root.Name~='FyrelithSmartArea'or X.Roots[root]then return end
 X.Roots[root]=true
 on(root.DescendantAdded,style)
 for _,object in ipairs(root:QueryDescendants('Frame, UIStroke, TextLabel'))do style(object)end
end
on(workspace.ChildAdded,attach)
local root=workspace:FindFirstChild('FyrelithSmartArea')
if root then attach(root)end
function X.Close()for _,connection in ipairs(X.Connections)do connection:Disconnect()end end
X.Installed=true

]=======================], 'Fyrelith AREA Visuals'))()
-- FYRELITH_SMART_FARM_PLACEMENT_V1
assert(loadstring([=========================[
-- Select farm positions by maximum distance from every monster path, inside saved areas.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay)
local previous=E.FyrelithSmartFarmPlacement
if previous and previous.Close then previous.Close()end
local X={OriginalPosition=A.SmartPosition,Alive=true}
E.FyrelithSmartFarmPlacement=X
local native=E.FyrelithSmartDungeonElements and E.FyrelithSmartDungeonElements.OriginalPosition or X.OriginalPosition
local rejected=debug.getupvalues(native)[10]
local L=require(game.ReplicatedStorage.src.Loader)
local Placement=L.load_core_service(script,'PlacementCore')
local function flatDistance(a,b)local d=a-b;return Vector3.new(d.X,0,d.Z).Magnitude end
function X.Find(unit,all)
 local circles=A.GetSmartCircles()
 local paths=A.GetSmartPaths()
 if #circles==0 or #paths==0 then return nil,'Waiting for Smart area / map paths'end
 local padding=A.GetSmartPlacementMargin(unit.Id)
 local snapshot=A.PlacementSnapshot(unit,all)
 local best,bestKey,bestDistance,bestNeighbor=nil,nil,-math.huge,math.huge
 local tested,valid=0,0
 local visited={}
 local function offer(point)
  local grid=string.format('%.2f:%.2f:%.2f',point.X,point.Y,point.Z)
  if visited[grid]then return end;visited[grid]=true;tested+=1
  local hit=A.RaycastSmartGround(point,unit.Data)
  if not hit or not Placement.is_valid_raycast_hit(hit.Instance,unit.Data)then return end
  if not A.IsWithinSmartAreas(hit.Position,circles,padding)or not A.PlacementIsClear(hit.Position,snapshot)then return end
  local away,distance=A.IsFarmAwayFromPaths(hit.Position,paths,padding)
  if not away then return end
  local key=string.format('%s:%.1f:%.1f',unit.Id,hit.Position.X,hit.Position.Z)
  if type(rejected)=='table'and rejected[key]and os.clock()-rejected[key]<60 then return end
  valid+=1
  local neighbor=math.huge
  for _,tower in ipairs(all)do if A.SmartRole(tower.Id)=='farm'then neighbor=math.min(neighbor,flatDistance(hit.Position,tower.CF.Position))end end
  -- Grouping is only a tie-breaker; it must never pull a farm closer to the road.
  if distance>bestDistance+.01 or math.abs(distance-bestDistance)<=.01 and neighbor<bestNeighbor then
   best=CFrame.new(hit.Position);bestKey=key;bestDistance=distance;bestNeighbor=neighbor
  end
 end
 local baseline=X.OriginalPosition(unit,all)
 if baseline then offer(baseline.Position)end
 for _,circle in ipairs(circles)do
  local center=Vector3.new(unpack(circle.Center))
  local radius=math.clamp(tonumber(circle.Radius)or 36,8,80)-padding
  if radius<=0 then continue end
  offer(center)
  for ring=1,3 do
   local r=radius*(ring==1 and 1 or ring==2 and .96 or .90)
   for index=0,127 do local angle=index*math.pi/64;offer(center+Vector3.new(math.cos(angle)*r,0,math.sin(angle)*r))end
  end
  local step=math.max(1.25,radius/14)
  for x=-radius,radius,step do for z=-radius,radius,step do
   if x*x+z*z<=radius*radius then offer(center+Vector3.new(x,0,z))end
  end end
 end
 if best then
  for _,step in ipairs({.75,.25})do
   local anchor=best.Position
   for x=-2,2 do for z=-2,2 do offer(anchor+Vector3.new(x*step,0,z*step))end end
  end
 end
 X.LastSearch={Unit=unit.Id,Tested=tested,Valid=valid,PathDistance=best and bestDistance or nil,Position=best and {best.X,best.Y,best.Z}or nil}
 if best then return best,bestKey,bestDistance end
 return nil,'No free farm location safely away from monster paths inside the saved areas'
end
local patched
patched=function(unit,all,context)
 if A.Config.Smart and A.SmartRole(unit.Id)=='farm'then return X.Find(unit,all)end
 return X.OriginalPosition(unit,all,context)
end
A.SmartPosition=patched
function X.Close()X.Alive=false;if A.SmartPosition==patched then A.SmartPosition=X.OriginalPosition end end
X.Installed=true

]=========================], 'Fyrelith Farm Placement'))()
-- FYRELITH_SMART_REQUEST_RECOVERY_V1
assert(loadstring([===========================[
-- Recover completed failed placement requests; never resend an in-flight request.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay)
local previous=E.FyrelithPlacementRecovery
if previous and previous.Close then previous.Close()end
local X={Alive=true,Blocked={},OriginalSelect=A.SelectInvestment,Released=0}
E.FyrelithPlacementRecovery=X
function X.ShouldRelease(pending,now,replicated)
 return type(pending)=='table'and pending.Step and pending.Step.Action=='Place'
  and pending.Returned==true and pending.Accepted~=true and pending.Declined~=true
  and type(pending.Error)=='string'and pending.Error~=''
  and now-(tonumber(pending.Sent)or now)>=3 and not replicated
end
local patchedSelect
patchedSelect=function(candidates,combat,cash,budget,blocked)
 local filtered={}
 for _,choice in ipairs(candidates)do
  local id=choice.Unit and choice.Unit.Id
  if choice.Kind~='Place'or not id or os.clock()>=(X.Blocked[id]or 0)then filtered[#filtered+1]=choice end
 end
 return X.OriginalSelect(filtered,combat,cash,budget,blocked)
end
A.SelectInvestment=patchedSelect
local elapsed=0
X.Connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.25 then return end;elapsed=0
 if not X.Alive or not A.Alive then return end
 local pending=A.Pending
 if not pending or not pending.Step or pending.Step.Action~='Place'or not pending.Returned or not pending.Error then return end
 local replicated=false
 for _,tower in ipairs(A.GetTowers())do
  if tower.UUID==pending.Step.UUID then replicated=true;break end
 end
 if X.ShouldRelease(pending,os.clock(),replicated)and A.Pending==pending then
  -- Let the native pending handler apply its usual rejected-position bookkeeping.
  X.Blocked[pending.Step.UnitId]=os.clock()+15
  X.LastError=pending.Error;X.LastUnit=pending.Step.UnitId;X.Released+=1
  pending.Declined=true
  A.LastPlacementIssue='Server rejected this unit; testing other units while it cools down'
 end
end)
function X.Close()
 X.Alive=false;if X.Connection then X.Connection:Disconnect()end
 if A.SelectInvestment==patchedSelect then A.SelectInvestment=X.OriginalSelect end
end
local gui=E.FyrelithExecutionState and E.FyrelithExecutionState.Gui
if gui then X.Destroying=gui.Destroying:Connect(function()X.Close();if X.Destroying then X.Destroying:Disconnect()end end)end
X.Installed=true

]===========================], 'Fyrelith Request Recovery'))()
-- FYRELITH_DUNGEON_TEAM_BUFF_ROUTE_V1
assert(loadstring([=============================[
-- When no next room offers coins/chests, pick the strongest buff for equipped damage units.
local E=getgenv()
local D=assert(E.FyrelithDungeon)
local A=assert(E.FyrelithAutoPlay)
local previous=E.FyrelithDungeonTeamBuffRoute
if previous and previous.Close then previous.Close()end
local L=require(game.ReplicatedStorage.src.Loader)
local types=L.load_core_service(script,'DungeonServiceCore').TYPES
local X={OriginalChoose=D.ChooseRoom,Alive=true}
E.FyrelithDungeonTeamBuffRoute=X
function X.HasReward(room)
 local tags=room and room._t or {}
 return not not(tags[types.MONEY]or tags[types.TREASURE]or tags[types.TREASURE_GOLD]or tags[types.OPEN_CHEST])
end
function X.Score(room,units)
 local level=room._l or {}
 local score=0
 for _,unit in ipairs(units or {})do
  if (unit.Role or A.SmartRole(unit.Id))=='damage'then
   local definition=unit.Data or {}
   local matches={[definition._base_damage_type or definition.base_damage_type or 'physical']=true}
   for kind,on in pairs(definition._secondary_damage_types or {})do if on then matches[kind]=true end end
   local gain,resistance=0,0
   for _,effect in pairs(level._weak_against or {})do if matches[effect.damage_type]then gain=math.max(gain,tonumber(effect.amplification)or 0)end end
   for _,effect in pairs(level._strong_against or {})do if matches[effect.damage_type]then resistance=math.max(resistance,tonumber(effect.resistance)or 0)end end
   score+=(1+gain)*(1-math.clamp(resistance,0,1))-1
  end
 end
 return score
end
function X.Choose(state,priority,config,units)
 if type(state)~='table'or state.selected_next and state.selected_next.choice_str then return X.OriginalChoose(state,priority,config)end
 local rooms={}
 for i=1,3 do
  local key=tostring(i);local room=state.next and state.next[key]
  if type(room)=='table'then
   if X.HasReward(room)then X.LastReason='Reward rooms available: using Dungeon Route';return X.OriginalChoose(state,priority,config)end
   rooms[#rooms+1]={Key=key,Room=room,Score=X.Score(room,units)}
  end
 end
 if #rooms==0 then return X.OriginalChoose(state,priority,config)end
 local best=-math.huge
 for _,entry in ipairs(rooms)do best=math.max(best,entry.Score)end
 local filtered=table.clone(state);filtered.next=table.clone(state.next or {})
 for _,entry in ipairs(rooms)do if entry.Score<best-.000001 then filtered.next[entry.Key]=nil end end
 -- Preserve the existing route's difficulty/curse preferences when buff scores tie.
 local result=X.OriginalChoose(filtered,priority,config)
 X.LastScores={}
 for _,entry in ipairs(rooms)do X.LastScores[entry.Key]=entry.Score end
 X.LastChoice=result and result.Key;X.LastReason='No room rewards: maximize equipped damage team buffs'
 return result
end
local patched
patched=function(state,priority,config)return X.Choose(state,priority,config,A.GetEquipped())end
D.ChooseRoom=patched
function X.Close()X.Alive=false;if D.ChooseRoom==patched then D.ChooseRoom=X.OriginalChoose end end
X.Installed=true

]=============================], 'Fyrelith Team Buff Route'))()
-- FYRELITH_FINAL_FARM_PAYOUT_FIX_V1
assert(loadstring([===============================[
-- Farm payout FX can arrive during the intermission before the wave counter increments.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay)
local prior=E.FyrelithFinalFarmPayoutFix
if prior and prior.Close then prior.Close()end
local X={OriginalReady=A.FarmPayoutReady,TransitionGrace=15}
E.FyrelithFinalFarmPayoutFix=X
local ready
ready=function(paid,current,final,entered,now)
 if type(final)~='number'or current~=final or type(paid)~='table'or type(paid.Time)~='number'or type(entered)~='number'or type(now)~='number'then return false end
 if paid.Time>now or now-paid.Time<.4 then return false end
 if paid.Wave==final then return paid.Time>=entered-2 end
 -- Only a fresh payout from the directly preceding wave qualifies; old income does not.
 if paid.Wave==final-1 then return paid.Time>=entered-X.TransitionGrace and paid.Time<=entered+1 end
 return false
end
A.FarmPayoutReady=ready
X.Ready=ready
function X.Close()if A.FarmPayoutReady==ready then A.FarmPayoutReady=X.OriginalReady end end
X.Installed=true

]===============================], 'Fyrelith Final Farm Payout'))()
-- FYRELITH_FARM_SALE_AUDIT_V1
assert(loadstring([=================================[
-- Evidence for automatic sales: track native farm-sale requests and server acknowledgements.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay)
local old=E.FyrelithFarmSaleAudit
if old and old.Close then old.Close()end
local X={OriginalStep=A.SellFinalFarmStep,Issued={},Scheduled=0,Requests=0,Confirmed=0,Failed=0,Unverified=0}
E.FyrelithFarmSaleAudit=X
local H=game:GetService('HttpService')
local storage=E.FyrelithDefaultLoaderStorage or E.FyrelithLoaderStorage
local read=storage and storage.Read or readfile
local write=storage and storage.Write or writefile
local file='FyrelithFarmSellAudit_'..game.Players.LocalPlayer.UserId..'_'..game.GameId..'.json'
local history={}
pcall(function()history=H:JSONDecode(read(file)).History or {}end)
local report={Job=game.JobId,Started=os.time()}
history[#history+1]=report
while #history>8 do table.remove(history,1)end
function X.Publish()
 report.Scheduled=X.Scheduled;report.Requests=X.Requests;report.Confirmed=X.Confirmed;report.Failed=X.Failed;report.Unverified=X.Unverified
 report.LastCheck=X.LastCheck;report.LastError=X.LastError;report.Updated=os.time()
 local wave=workspace:FindFirstChild('_wave_num');report.Wave=wave and wave.Value
 pcall(write,file,H:JSONEncode({History=history}))
end
local step
step=function()
 if A.FarmClosing then
  X.LastCheck={Time=os.clock(),Enabled=A.Config.SellFinalFarm,Plan=A.Config.Plan,Completed=A.Completed,Pending=A.Pending and A.Pending.Kind,Eligible=0,Farms=0}
  for _,t in ipairs(A.GetTowers())do if A.SmartRole(t.Id)=='farm'then X.LastCheck.Farms+=1;if A.CanSellFinalFarm(t.Id,t.Unit)then X.LastCheck.Eligible+=1 end end end
 end
 local result=X.OriginalStep()
 local p=A.Pending
 if p and p.Kind=='farm-sale'and p.Unit and not X.Issued[p.Unit]then
  X.Issued[p.Unit]={Pending=p,At=os.clock()};X.Scheduled+=1;X.Publish()
 end
 if A.FarmClosing and os.clock()-(X.LastWrite or 0)>3 then X.LastWrite=os.clock();X.Publish()end
 return result
end
A.SellFinalFarmStep=step
X.Connection=game:GetService('RunService').Heartbeat:Connect(function()
 for model,record in pairs(X.Issued)do
  if not record.Done then
   local p=record.Pending
   if p.Returned and not record.Returned then record.Returned=true;X.Requests+=1;X.Publish()end
   if p.Returned and p.Accepted==true and not model.Parent then record.Done=true;record.Confirmed=true;X.Confirmed+=1;X.Publish()
   elseif p.Returned and (p.Error or p.Declined)then record.Done=true;record.Error=p.Error or 'Declined';X.Failed+=1;X.LastError=record.Error;X.Publish()
   elseif p.Returned and not model.Parent then record.Done=true;X.Unverified+=1;X.Publish()end
  end
 end
end)
function X.Close()
 if X.Connection then X.Connection:Disconnect()end
 if A.SellFinalFarmStep==step then A.SellFinalFarmStep=X.OriginalStep end
end
X.Installed=true
X.Publish()

]=================================], 'Fyrelith Farm Sale Audit'))()
-- FYRELITH_FAST_FARM_SALE_V1
assert(loadstring([===================================[
-- Advance to the next farm after server acceptance, without waiting for the despawn animation.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay)
local previous=E.FyrelithFastFarmSale
if previous and previous.Close then previous.Close()end
local X={OriginalCanSell=A.CanSellFinalFarm,Acknowledged=setmetatable({},{__mode='k'}),Released=0}
E.FyrelithFastFarmSale=X
local nativeStep=E.FyrelithFarmSaleAudit and E.FyrelithFarmSaleAudit.OriginalStep or A.SellFinalFarmStep
local send
for _,value in pairs(debug.getupvalues(nativeStep))do if type(value)=='function'and debug.info(value,'n')=='send'then send=value;break end end
local canSell
canSell=function(id,unit)
 if unit and X.Acknowledged[unit]then return false end
 return X.OriginalCanSell(id,unit)
end
A.CanSellFinalFarm=canSell
function X.Ready(pending,now)
 return type(pending)=='table'and pending.Kind=='farm-sale'and pending.Unit~=nil
  and pending.Returned==true and pending.Accepted==true
  and now-(tonumber(pending.Sent)or now)>=.12
end
local elapsed=0
X.Connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.04 then return end;elapsed=0
 local pending=A.Pending
 if not X.Ready(pending,os.clock())or A.Pending~=pending then return end
 X.Acknowledged[pending.Unit]=true
 A.FarmSale.Intentional[pending.Unit]=true
 -- This response is complete; preserve its record for the sale audit while advancing the queue.
 A.Pending=nil;X.Released+=1;X.LastAcknowledgedAt=os.clock()
 if send then
  local values=debug.getupvalues(send)
  if type(values[2])=='number'then debug.setupvalue(send,2,math.min(values[2],os.clock()))end
 end
 A.Status='Farm sale accepted • selling next farm'
end)
function X.Close()
 if X.Connection then X.Connection:Disconnect()end
 if A.CanSellFinalFarm==canSell then A.CanSellFinalFarm=X.OriginalCanSell end
end
X.Installed=true

]===================================], 'Fyrelith Fast Farm Sale'))()
-- FYRELITH_COMPACT_FARM_V1
assert(loadstring([=====================================[
-- Small Smart areas: allow close roadside farm spots while retaining footprint and collision checks.
local E=getgenv()
local A=assert(E.FyrelithAutoPlay)
local old=E.FyrelithCompactFarm
if old and old.Close then old.Close()end
local X={OriginalAway=A.IsFarmAwayFromPaths}
E.FyrelithCompactFarm=X
local away
away=function(position,paths,padding)
 local clear,distance=X.OriginalAway(position,paths,padding)
 if clear or not A.Config.Smart then return clear,distance end
 local required=0
 -- Do not reserve the old extra 2-6 stud road buffer in a compact area.
 -- The actual placement raycast, saved-area boundary, and unit hitboxes still apply.
 if type(distance)=='number'and distance<math.huge and distance>=required then return true,distance end
 return false,distance
end
A.IsFarmAwayFromPaths=away
function X.Close()if A.IsFarmAwayFromPaths==away then A.IsFarmAwayFromPaths=X.OriginalAway end end
X.Installed=true

]=====================================], 'Fyrelith Compact Farm'))()
-- FYRELITH_CHALLENGE_INTERRUPT_V1
assert(loadstring([=======================================[
-- Challenge reset has priority over every current game mode; return without waiting for match end.
local E=getgenv()
local C=assert(E.FyrelithAutoChallenge)
local old=E.FyrelithChallengeInterrupt
if old and old.Close then old.Close()end
local L=require(game.ReplicatedStorage.src.Loader)
local T=game:GetService('TeleportService')
local player=game:GetService('Players').LocalPlayer
local EP=L.load_client_service(script,'EndpointsClient')
local U=L.load_client_service(script,'UnitCollectionServiceClient')
local store
for _,value in pairs(debug.getupvalues(C.Save))do if type(value)=='table'and type(value.Rounds)=='table'then store=value;break end end
assert(store,'Challenge rotation state unavailable')
local X={Alive=true,OriginalDecide=C.DecideBattle,LastProbe=-math.huge,Attempts=0}
E.FyrelithChallengeInterrupt=X
local ticketKey='FyrelithChallengeInterruptTicket'
pcall(function()X.Ticket=T:GetTeleportSetting(ticketKey)end)
function X.ResetDue(enabled,round,timeNow)
 return enabled==true and type(round)=='table'and type(round.CheckAt)=='number'and timeNow>=round.CheckAt
end
function X.NewRound(enabled,known,current)
 return enabled==true and current~=nil and known~=nil and tostring(current)~=tostring(known)
end
local function profile()return U.session and U.session.profile_data end
local function validTicket(ticket)
 return type(ticket)=='table'and C.EnabledModes[ticket.Mode]==true and type(ticket.At)=='number'and workspace:GetServerTimeNow()-ticket.At<600
end
local function depart(mode,reason)
 if X.Returning then return end
 local settings=L.load_data(script,'GameplaySettings')
 local lobby=tonumber(settings.LOBBY_PLACE_ID)
 if not lobby then X.Error='Lobby destination unavailable';return end
 X.Returning=true;X.Mode=mode;X.Reason=reason
 X.Ticket={Mode=mode,At=workspace:GetServerTimeNow(),Round=(store.Rounds[mode]or{}).Round,Reason=reason}
 pcall(function()T:SetTeleportSetting(ticketKey,X.Ticket)end)
 C.Mode=mode;C.Priority=true;C.InChallenge=false
 C.State=mode..' reset: returning to lobby immediately'
 -- Preserve capture data, but never wait for the current battle to finish.
 local macro=E.FyrelithMacro
 if macro and macro.Save and (macro.State=='Recording'or macro.State=='Paused')then pcall(macro.Save);macro.Token=(macro.Token or 0)+1;macro.State='Idle'end
 if macro and macro.FinishPlayback then pcall(macro.FinishPlayback)end
 pcall(C.Save)
 local runtime=E.FyrelithRuntime;if runtime and runtime.Save then pcall(runtime.Save)end
 X.Attempts+=1;X.LastDeparture=os.clock()
 local ok,err=pcall(T.Teleport,T,lobby,player)
 if not ok then X.Error=tostring(err);X.Returning=false;X.RetryAt=os.clock()+10 end
end
local decision
decision=function(...)
 if X.Returning then return 'playing'end -- The independent return already owns the teleport.
 return X.OriginalDecide(...)
end
C.DecideBattle=decision
X.Failed=T.TeleportInitFailed:Connect(function(who,_,message)
 if who==player and X.Returning then X.Error=tostring(message);X.Returning=false;X.RetryAt=os.clock()+10 end
end)
local function step()
 if not X.Alive or not C.Alive or not C.Enabled then return end
 local level=L.LevelData
 local p=profile();if not p then return end
 local timeNow=workspace:GetServerTimeNow()
 if L.IsLobby then
  if validTicket(X.Ticket)then C.Mode=X.Ticket.Mode;C.Priority=true end
  return
 end
 if X.Ticket and C.IsSelectedChallenge(level,X.Ticket.Mode)and not X.ResetDue(C.EnabledModes[X.Ticket.Mode],store.Rounds[X.Ticket.Mode],timeNow)then
  pcall(function()T:SetTeleportSetting(ticketKey,nil)end);X.Ticket=nil
 end
 if X.Returning or os.clock()<(X.RetryAt or 0)then return end
 for _,mode in ipairs({'Challenge','Daily Challenge'})do
  if X.ResetDue(C.EnabledModes[mode],store.Rounds[mode],timeNow)then depart(mode,'server rotation deadline reached');return end
 end
 -- A fresh server UUID also detects a reset when no lobby countdown was captured.
 if X.Probing or os.clock()-X.LastProbe<5 then return end
 X.LastProbe=os.clock();X.Probing=true
 task.spawn(function()
  local ok,err=pcall(function()
   for _,mode in ipairs({'Challenge','Daily Challenge'})do if C.EnabledModes[mode]then
    local definition=C.Modes[mode]
    local current=C.NormalizeCurrent(EP.invoke_server(definition.Endpoint),mode)
    if not X.Alive or X.Returning then return end
    local known=store.Rounds[mode]or{}
    if current and X.NewRound(true,known.Round,current.current_uuid)and tostring(current.current_uuid)~=tostring(p[definition.Completed])then
     depart(mode,'new server challenge UUID');return
    end
   end end
  end)
  X.Probing=false;if not ok then X.ProbeError=tostring(err)end
 end)
end
local elapsed=0
X.Connection=game:GetService('RunService').Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.25 then return end;elapsed=0
 local ok,err=pcall(step);if not ok then X.Error=tostring(err)end
end)
function X.Close()
 X.Alive=false
 if X.Connection then X.Connection:Disconnect()end
 if X.Failed then X.Failed:Disconnect()end
 if C.DecideBattle==decision then C.DecideBattle=X.OriginalDecide end
end
local gui=E.FyrelithExecutionState and E.FyrelithExecutionState.Gui
if gui then X.Destroying=gui.Destroying:Connect(function()X.Close();if X.Destroying then X.Destroying:Disconnect()end end)end
X.Installed=true

]=======================================], 'Fyrelith Challenge Interrupt'))()
-- FYRELITH_LIFE_SWITCH_THEME_V1
assert(loadstring([=========================================[
-- Bind the life guard to the same live palette as the native Dungeon switches.
local E=getgenv()
local gui=assert(E.FyrelithExecutionState.Gui)
local page=assert(gui:FindFirstChild('Dungeon',true))
local button=assert(page:FindFirstChild('DungeonLifeGuard')).Toggle
local track=assert(button:FindFirstChild('Track'))
local reference=assert(page:FindFirstChild('Dungeon_Finish'))
local old=E.FyrelithLifeSwitchTheme
if old and old.Close then old.Close()end
local X={Connections={}}
E.FyrelithLifeSwitchTheme=X
local function palette()
 for _,connection in ipairs(getconnections(reference.Activated))do
  if type(connection.Function)=='function'then
   for _,value in pairs(debug.getupvalues(connection.Function))do
    if type(value)=='function'and debug.info(value,'n')=='paint'then
     for _,color in pairs(debug.getupvalues(value))do
      if type(color)=='table'and typeof(color.accent)=='Color3'and typeof(color.line)=='Color3'then return color end
     end
    end
   end
  end
 end
end
local painting=false
local function sync()
 if painting or not track.Parent then return end
 local colors=palette();if not colors then return end
 local target=E.FyrelithDungeon.Config.LeaveAtOneLife and colors.accent or colors.line
 painting=true
 track.BackgroundColor3=target
 painting=false
 X.MatchesPalette=track.BackgroundColor3==target
end
X.Connections[#X.Connections+1]=track:GetPropertyChangedSignal('BackgroundColor3'):Connect(sync)
X.Connections[#X.Connections+1]=button:GetAttributeChangedSignal('Enabled'):Connect(function()task.defer(sync)end)
X.Connections[#X.Connections+1]=gui:GetAttributeChangedSignal('PaletteRevision'):Connect(function()task.defer(sync)end)
function X.Close()for _,connection in ipairs(X.Connections)do connection:Disconnect()end end
X.Connections[#X.Connections+1]=gui.Destroying:Connect(X.Close)
sync();X.Installed=true

]=========================================], 'Fyrelith Life Switch Theme'))()
-- FYRELITH_SUMMER_21_V1
assert(loadstring([================================================[
-- Summer 21 controller. Native endpoints and UI state are observed before acting.
local E=getgenv()
local execution=assert(E.FyrelithExecutionState)
local gui=assert(execution.Gui)
local L=require(game.ReplicatedStorage.src.Loader)
local player=game:GetService('Players').LocalPlayer
local H=game:GetService('HttpService')
local storage=assert(E.FyrelithDefaultLoaderStorage)
local epoch=storage.Epoch or 0
local function service(name)return L.load_client_service(script,name)end
local U=service('UnitCollectionServiceClient')
local G=service('GUIService')
local EP=service('EndpointsClient')
local Challenge=service('ChallengeServiceClient')
local Merchant=service('BSDShopServiceClient')
local Weather=service('WeatherServiceClient')
local Items=L.load_data(script,'Items')
local Units=L.load_data(script,'Units')
local Maps=L.load_data(script,'Maps')
local WeatherData=L.load_data(script,'Weather')
local Sale=L.load_data(script,'ItemsForSaleEvent')
local Quests=L.load_data(script,'QuestsEvent')
local NPC=L.load_data(script,'NPC')
local QuestCore=L.load_core_service(script,'QuestClassesCore')
local old=E.FyrelithSummer;if old and old.Stop then old.Stop()end
for _,key in ipairs({'FyrelithAutoEvent','FyrelithEventSpells','FyrelithAprilUnits'})do local legacy=E[key];if legacy and legacy.Stop then pcall(legacy.Stop)end;E[key]=nil end
local S={Alive=true,Enabled=false,Connections={},Status='Summer automation is off',Audit={},Version=1}
E.FyrelithSummer=S
local P=(function()
-- Pure Summer policy: no game requests or persistent state.
local P={}
function P.CurrencyBonus(choice)
 local total=0
 for _,effect in pairs(type(choice)=='table'and choice.effects or{})do
  local amount
  if effect.type=='candy_multiplier'then amount=tonumber(effect.amount)
  elseif effect.type=='ui_evidence'and effect.preference=='@pearls'then amount=(tonumber(effect.score)or 0)/100 end
  if amount and amount==amount and math.abs(amount)<math.huge then total+=amount end
 end
 return total
end
function P.PriorityRank(choice,order)
 local title=tostring(choice.title or''):lower()
 for rank,key in ipairs(order or{})do
  if key==title then return rank end
  for _,e in pairs(choice.effects or{})do
   local n=tonumber(e.amount)or 0;local kind=e.type;local stat=e.stat
   local statEffect=kind=='stat_mul'or kind=='stat_add'or kind=='stat_attr_add'or kind=='stat_mul_real'
   local delta=kind=='stat_mul_real'and n-1 or n
   if e.preference==key and(tonumber(e.score)or 0)>0
    or key=='@pearls'and kind=='candy_multiplier'and n>0
    or key=='@secret'and kind=='secret_drop'and n>0
    or key=='@damage'and statEffect and stat=='damage'and delta>0
    or key=='@range'and statEffect and stat=='range'and delta>0
    or key=='@cooldown'and statEffect and(stat=='spa'or stat=='attack_cooldown')and delta<0
    or key=='@ability'and statEffect and stat=='active_attack_cooldown'and delta<0
    or key=='@cash'and kind=='resource_gain'and n>0
    or key=='@discount'and kind=='unit_cost'and n<0
    or key=='@boss'and kind=='boss_damage'and n>0 then return rank end
  end
 end
 return math.huge
end
function P.Limit(config,pearls,runs)
 if (tonumber(config.StopPearls)or 0)>0 and pearls>=config.StopPearls then return 'Pearl target reached' end
 if (tonumber(config.StopRuns)or 0)>0 and runs>=config.StopRuns then return 'Run target reached' end
end
function P.Portal(item,config)
 if type(item)~='table'or type(item.uuid)~='string'then return false end
 local id=item.item_id
 if id=='portal_item__enel'or id=='portal_summer2_secret'then
  return config.UseSecrets==true and (config.PortalKind=='All'or config.PortalKind==(id=='portal_item__enel'and 'Sky God'or 'Explosion Mage'))
 end
 if id~='portal_item__skypiea'or (config.PortalKind~='Sky'and config.PortalKind~='All')then return false end
 local data=item._unique_item_data or item.unique_item_data or item
 local portal=data._unique_portal_data or item._unique_portal_data
 local tier=portal and tonumber(portal.portal_depth)
 -- Unknown tiers are never silently consumed.
 return tier~=nil and tier>=(config.MinTier or 1)and tier<=(config.MaxTier or 12),tier
end
function P.Affordable(definition,pearls,reserve,budget,spent)
 local cost=definition and definition.resource_cost
 if not cost or cost.id~='SummerPearls'or definition.robux or definition.gem_cost then return false end
 local amount=tonumber(cost.amount)
 return amount~=nil and amount>0 and pearls-amount>=reserve and budget>0 and spent+amount<=budget,amount
end
function P.WeatherWeight(weather,definition)
 definition=definition or{}
 local types={[definition._base_damage_type or definition.base_damage_type or 'physical']=true}
 for kind,on in pairs(definition._secondary_damage_types or{})do if on then types[kind]=true end end
 if weather=='mana'then return types.magic and 1.25 or types.physical and .25 or 1 end
 if weather=='sandstorm'then return types.physical and 1.25 or types.magic and .4 or 1 end
 if weather=='snow'then return types.fire_damage and 1.5 or .65 end
 return 1
end
function P.CardScore(choice,mode,danger,selected,avoided,weatherRank,weatherWeight)
 if type(choice)~='table'then return nil end
 local title=tostring(choice.title or''):lower()
 if avoided and avoided[title]then return nil end
 if mode=='Selected only'and not(selected and selected[title])and not(choice.weather and weatherRank and weatherRank[choice.weather])then return nil end
 local good,bad,reward=0,0,0
 for _,e in pairs(choice.effects or{})do
  local n=tonumber(e.amount)or 0;local kind=e.type;local stat=e.stat
  local value=0
  if kind=='candy_multiplier'or kind=='secret_drop'then reward+=math.max(0,n)*100
  elseif kind=='resource_gain'then good+=math.max(0,n)/100
  elseif kind=='stat_mul'or kind=='stat_add'or kind=='stat_attr_add'or kind=='stat_mul_real'then
   if kind=='stat_mul_real'then n-=1 end
   value=n*((stat=='attack_cooldown'or stat=='spa'or stat=='active_attack_cooldown'or stat=='cost')and -100 or 100)
  elseif kind=='unit_cost'then value=-n*100
  elseif kind=='boss_damage'then value=n*90
  elseif kind=='enemy_amp_specific'then value=n*80
  elseif kind=='new_path'then value=-150*#(e.new_lanes or{})
  elseif kind=='random_effects'then value=(e._type=='Good'and 12 or -35)*math.abs(n)*math.max(1,tonumber(e.tier)or 1)
  elseif kind=='add_reward'then reward+=20
  elseif kind=='enemy_regen'then value=-n*500
  elseif kind=='enemy_shield'then value=-n*30
  elseif kind=='enemy_resistance_specific'then value=-n*2
  elseif kind=='enemy_bomb'then value=-n*8
  elseif kind=='enemy_stat_mul'or kind=='enemy_speedup'or kind=='weather_flying_chance'or kind=='weather_soaring_share'then value=-n*120
  elseif kind=='ui_evidence'then value=tonumber(e.score)or -5
  else value=-10 end
  if value>=0 then good+=value else bad-=value end
 end
 if choice.option_type=='Bad'and bad==0 then bad=20 end
 if mode=='Safe'and (bad>0 or choice.option_type=='Bad')then return nil end
 local score=good-bad*(danger and 4 or mode=='Rewards'and .35 or 1.5)+reward*(danger and .2 or mode=='Rewards'and 3 or 1)
 if selected and selected[title]then score+=1000 end
 if choice.weather then
  score+=(weatherWeight or 1)*40
  if weatherRank and weatherRank[choice.weather]then score+=500-weatherRank[choice.weather]*10 end
 end
 return score
end
return P

end)()
S.Policy=P
local defaults={JoinMode='Off',JoinEnabled=false,EntryMode='Solo',Cards=false,CardPolicy='Balanced',Fallback=true,SelectedCards={},AvoidCards={},CardOrder={},KnownCards={},WeatherOrder={},
 WeatherSmart=false,AutoPortal=false,PortalKind='Sky',MinTier=1,MaxTier=12,PortalOrder='Lowest first',UseSecrets=false,PortalWait=10,
 PortalFallback=false,StopPearls=0,StopRuns=0,Runs=0,AutoQuests=false,AcceptQuests=false,Bingo=false,
 AutoShop=false,ShopSelected={},ShopTargets={},Reserve=0,Budget=0,SpendDay='',Spent=0,Notify=false,Webhook=false}
local C=table.clone(defaults)
for key,value in pairs(C)do if type(value)=='table'then C[key]={}end end
local file='FyrelithSummer_'..player.UserId..'_'..game.GameId..'.json'
pcall(function()
 local data=H:JSONDecode(storage.Read(file))
 if type(data.JoinEnabled)~='boolean'then C.JoinEnabled=data.JoinMode=='Solo'or data.JoinMode=='Matchmaking'end
 if type(data.EntryMode)~='string'and(data.JoinMode=='Solo'or data.JoinMode=='Matchmaking')then C.EntryMode=data.JoinMode end
 for key,value in pairs(defaults)do if type(data[key])==type(value)then
  if type(value)=='table'then
   local safe={};local count=0
   for k,v in pairs(data[key])do if count<300 and(type(k)=='string'or type(k)=='number')and(type(v)=='string'or type(v)=='number'or type(v)=='boolean')then safe[k]=v;count+=1 end end
   C[key]=safe
  else C[key]=data[key]end
 end end
end)
local function enum(key,values)if not table.find(values,C[key])then C[key]=defaults[key]end end
enum('JoinMode',{'Off','Solo','Matchmaking'});enum('CardPolicy',{'Balanced','Safe','Rewards','Selected only'})
enum('EntryMode',{'Solo','Matchmaking'});C.JoinMode=C.JoinEnabled and C.EntryMode or'Off'
enum('PortalKind',{'Sky','Sky God','Explosion Mage','All'});enum('PortalOrder',{'Lowest first','Highest first'})
local function finite(value,fallback,low,high)
 local n=tonumber(value);if not n or n~=n or math.abs(n)==math.huge then n=fallback end
 return math.clamp(math.floor(n),low,high)
end
for _,key in ipairs({'StopPearls','StopRuns','Runs','Reserve','Budget','Spent'})do C[key]=finite(C[key],0,0,1000000000)end
C.StopPearls=0;C.StopRuns=0
C.MinTier=finite(C.MinTier,1,1,12);C.MaxTier=finite(C.MaxTier,12,C.MinTier,12);C.PortalWait=finite(C.PortalWait,10,0,120)
do
 local order,seen={},{}
 for _,key in ipairs(C.CardOrder)do if type(key)=='string'and not seen[key]then order[#order+1]=key;seen[key]=true end end
 local legacy={};for key,on in pairs(C.SelectedCards)do if on and type(key)=='string'and not seen[key]then legacy[#legacy+1]=key end end;table.sort(legacy)
 for _,key in ipairs(legacy)do order[#order+1]=key end
 C.CardOrder=order
end
for id,target in pairs(C.ShopTargets)do C.ShopTargets[id]=finite(target,1,1,9999)end
S.Config=C
function S.Save()
 if (storage.Epoch or 0)~=epoch then return false end
 local ok,err=pcall(storage.Write,file,H:JSONEncode(C));S.SaveError=not ok and tostring(err)or nil;return ok
end
local function active()return S.Alive and execution.Ready~=false and gui.Parent~=nil end
local function profile()return U.session and U.session.profile_data or{}end
local function pearls()return tonumber((profile().resources or{}).SummerPearls)or 0 end
local function dataLevel()return type(L.LevelData)=='table'and L.LevelData or{}end
local function hunt()return not L.IsLobby and dataLevel().id=='summer2_event'end
local function sky()
 local d=dataLevel();return not L.IsLobby and(d.portal_group=='summer2'or d.id=='skypiea_portal'or d.id=='skypiea_portal_final'or d.id=='summer2_portal_final')
end
local function challengePriority()local a=E.FyrelithAutoChallenge;local x=E.FyrelithChallengeInterrupt;return a and a.Priority or x and x.Returning end
function S.WantsMatchControl()return active()and((hunt()and(C.JoinMode~='Off'or C.AutoPortal and C.PortalFallback))or(sky()and C.AutoPortal)or S.ReturningResult==true)and not challengePriority()end
local function note(message)S.Status=message end
local function audit(endpoint,accepted,err)
 S.Audit[#S.Audit+1]={Endpoint=endpoint,Accepted=accepted,Error=err,At=os.time()}
 if #S.Audit>25 then table.remove(S.Audit,1)end
end
local nextCall=0;local retry={}
local captchaAttempts=setmetatable({},{__mode='k'})
function S.SubmitCaptchaWindow(window)
 if not active()or not L.IsLobby or C.JoinMode~='Matchmaking'or not S.Prompted or S.QueueRequested or challengePriority()then return false end
 if not window or window.Name~='CaptchaWindow'or not window.Parent or window.Parent.Name=='PopupTemplate'or not window.Visible then return false end
 local label=window:FindFirstChild('Captcha');local box=window:FindFirstChild('TypeBox')
 local holder=window:FindFirstChild('ButtonHolder');local yes=holder and holder:FindFirstChild('Yes')
 if not label or not box or not box:IsA('TextBox')or not yes or not yes:IsA('GuiButton')then return false end
 local code=tostring(label.Text or''):match('^%s*(%d+)%s*$')
 if not code or #code<5 or #code>7 or captchaAttempts[window]==code then return false end
 captchaAttempts[window]=code;box.Text=code
 note('Submitting Summer matchmaking verification')
 task.spawn(function()
  task.wait(.1)
  if not active()or not L.IsLobby or C.JoinMode~='Matchmaking'or not S.Prompted or challengePriority()or not window.Parent or label.Text:match('^%s*(%d+)%s*$')~=code then return end
  local submitted=false
  if type(firesignal)=='function'then submitted=pcall(firesignal,yes.Activated)
  elseif type(getconnections)=='function'then
   for _,connection in ipairs(getconnections(yes.Activated))do
    if type(connection.Function)=='function'then submitted=pcall(connection.Function);if submitted then break end end
   end
  end
  S.CaptchaAttempts=(S.CaptchaAttempts or 0)+1;S.CaptchaSubmitted=submitted
  if not submitted then captchaAttempts[window]=nil;note('Verification is ready · press Submit in the game window')end
 end)
 return true
end
function S.SolveCaptcha()
 local N=G.notification_windows_ui;local popups=N and N.Popups
 if not popups then local playerGui=player:FindFirstChild('PlayerGui');local root=playerGui and playerGui:FindFirstChild('NotificationWindows');popups=root and root:FindFirstChild('Popups')end
 return popups and S.SubmitCaptchaWindow(popups:FindFirstChild('CaptchaWindow'))or false
end
-- One outstanding request per controller; unknown responses back off instead of spamming.
local function call(endpoint,key,...)
 if not active()or S.Pending or os.clock()<nextCall or os.clock()<(retry[key]or 0)then return false end
 local args=table.pack(...);local token={Endpoint=endpoint,Key=key,At=os.clock()}
 S.Pending=token;nextCall=os.clock()+1
 task.spawn(function()
  if not active()or S.Pending~=token then return end
  local ok,result=pcall(EP.invoke_server,endpoint,table.unpack(args,1,args.n))
  if not S.Alive then return end
  token.Returned=true;token.Accepted=ok and result==true;token.Error=not ok and tostring(result)or result==false and 'Server declined'or nil
  audit(endpoint,token.Accepted,token.Error)
  retry[key]=os.clock()+(token.Accepted and 3 or 15)
  if S.Pending==token then S.Pending=nil end
  if token.Error then note('Waiting after '..endpoint..': '..token.Error)end
 end)
 return true,token
end
local function currentEvent()return (Challenge._CURRENT_EVENT_CHALLENGES or{}).summer2_event end
local function weatherId()
 local d=dataLevel();local current=currentEvent()
 if not L.IsLobby then return Weather.current_weather or d._weather end
 return current and current.current_weather
end
local function weatherName(id)return WeatherData[id or'']and WeatherData[id].name or tostring(id or'Unknown')end
local function stopAtLimit()
 local reason=P.Limit(C,pearls(),C.Runs)
 if reason then C.JoinMode='Off';C.JoinEnabled=false;C.AutoPortal=false;S.Enabled=false;S.Save();note(reason);return reason end
end
function S.SetJoinMode(mode)
 if not table.find({'Off','Solo','Matchmaking'},mode)then return end
 local notifications=G.notification_windows_ui
 if S.Prompted and notifications and notifications.close_matchmaking_popup then pcall(notifications.close_matchmaking_popup,notifications)end
 C.JoinEnabled=mode~='Off';if mode~='Off'then C.EntryMode=mode end
 C.JoinMode=mode;S.Enabled=mode~='Off'or C.AutoPortal;S.QueueRequested=false;S.Prompted=false;S.MatchmakingPaused=false
 if mode~='Off'then
  local A=E.FyrelithAutoJoin;if A then A.Enabled=false;if A.Config then A.Config.ContractEnabled=false end end
  local D=E.FyrelithDungeon;if D and D.Config then D.Config.Enabled=false;if D.Save then D.Save()end end
 end
 S.Save()
end
function S.SetJoinEnabled(value)S.SetJoinMode(value and C.EntryMode or'Off')end
function S.SetEntryMode(mode)
 if mode~='Solo'and mode~='Matchmaking'then return end
 C.EntryMode=mode
 if C.JoinEnabled then S.SetJoinMode(mode)else S.Save()end
end
local function invCount(id)
 local inv=U.session and U.session.inventory
 if inv and type(inv.get_number_of_owned_item)=='function'then local ok,n=pcall(inv.get_number_of_owned_item,inv,id);if ok then return tonumber(n)or 0 end end
 return 0
end
function S.PortalChoices()
 local out={};local inventory=U.session and U.session.inventory.inventory_profile_data or{}
 for _,item in pairs(inventory.unique_items or{})do
  local allowed,tier=P.Portal(item,C)
  if allowed then out[#out+1]={UUID=item.uuid,Id=item.item_id,Tier=tier or 99}end
 end
 table.sort(out,function(a,b)if a.Tier==b.Tier then return a.UUID<b.UUID end;return C.PortalOrder=='Highest first'and a.Tier>b.Tier or C.PortalOrder~='Highest first'and a.Tier<b.Tier end)
 return out
end
local function mine(value)return value==player or value==player.Name or value==player.UserId or value==tostring(player.UserId)end
local function ownPortal()
 local root=workspace:FindFirstChild('_PORTALS');local folder=root and root:FindFirstChild('Lobbies')
 if not folder then return end
 for _,room in ipairs(folder:GetChildren())do local owner=room:FindFirstChild('Owner');local level=room:FindFirstChild('Level')
  if owner and mine(owner.Value)and level then
   local id=level.Value
   if id=='skypiea_portal'or id=='skypiea_portal_final'or id=='summer2_portal_final'then return room end
  end
 end
end
local function portalTick()
 if not C.AutoPortal then return false end
 local room=ownPortal()
 if room then
  S.Opening=nil;S.PortalRoomAt=S.PortalRoomAt or os.clock()
  local tp=room:FindFirstChild('Teleporting');if tp and tp.Value then note('Sky Portal is starting');return true end
  note('Sky Portal lobby · starting in '..math.max(0,math.ceil(C.PortalWait-(os.clock()-S.PortalRoomAt)))..'s')
  if os.clock()-S.PortalRoomAt>=C.PortalWait then call('request_start_game','start:'..room.Name,room.Name)end
  return true
 end
 S.PortalRoomAt=nil
 if S.Opening then
  note('Waiting for opened Sky Portal lobby')
  if os.clock()-S.Opening.At>45 then S.Opening=nil;S.PortalPaused=true;note('Portal not confirmed · press Retry queue')end
  return true
 end
 if S.PortalPaused then note('Portal paused · press Retry queue');return true end
 local choice=S.PortalChoices()[1]
 if choice then
  local sent=call('use_portal','open:'..choice.UUID,choice.UUID)
  if sent then S.Opening={At=os.clock(),UUID=choice.UUID};note('Opening '..tostring(Items[choice.Id]and Items[choice.Id].name or choice.Id)..' · T'..choice.Tier)end
  return true
 end
 if not C.PortalFallback then note('No portal matches your filters · waiting');return true end
 return false
end
local function lobbyTick()
 S.Enabled=C.JoinMode~='Off'or C.AutoPortal
 if not S.Enabled or not L.IsLobby or stopAtLimit()then return end
 if challengePriority()then note('Waiting for Auto Challenge');return end
 local A=E.FyrelithAutoJoin
 if not A or not A.Ready or A.Busy then return end
 if A.Config.ContractEnabled or A.Enabled then note('Pause other Auto Join modes first');return end
 local D=E.FyrelithDungeon;if D and D.Config.Enabled then note('Pause Auto Dungeon first');return end
 if portalTick()then return end
 local joinMode=C.JoinMode
 if joinMode=='Off'and C.AutoPortal and C.PortalFallback then joinMode='Solo'end
 if joinMode=='Off'then return end
 local event=currentEvent();if not event then note('Waiting for Summer event data');return end
 if joinMode=='Solo'then
  A.EventLevel='summer2_event';A.EventSolo=true;note('Joining Summer Hunt · Solo')
  task.spawn(function()A.Join('Event')end)
 elseif not S.QueueRequested then
  if S.MatchmakingPaused then note('Matchmaking cancelled · press Retry queue');return end
  local N=G.notification_windows_ui
  if N and not N.HAS_MATCHMAKING_PROMPT and not S.Prompted then
   S.Prompted=true;note('Preparing Summer matchmaking verification')
   N:show_matchmaking_popup({_SkipFirst=true,OnMatchmaking=function()
    if not active()or C.JoinMode~='Matchmaking'or not L.IsLobby or challengePriority()then return end
    local sent=call('request_matchmaking','summer-matchmaking','summer2_event')
    S.QueueRequested=sent==true;S.Prompted=false
   end,OnFinish=function()S.Prompted=false;S.MatchmakingPaused=not S.QueueRequested end})
  end
 else note('Summer matchmaking requested · waiting for teleport')end
end
local resultToken;local resultHandled=false;local lastResult=0
function S.HandleResults(results)
 if not S.WantsMatchControl()then return false end
 if challengePriority()then return false end
 local token=tostring(results.settings or results)
 if resultToken~=token then resultToken=token;resultHandled=false end
 if not resultHandled then C.Runs+=1;S.Save();resultHandled=true end
 local limit=stopAtLimit()
 -- Entry automation does not own Replay/Leave switches. Only an explicit
 -- Summer stop target overrides the shared Match Controls decision.
 if not limit and not S.ReturningResult then return false end
 if os.clock()-lastResult<5 then return true end
 S.ReturningResult=true
 if call('teleport_back_to_lobby','summer-result-return')then lastResult=os.clock()end
 return true
end
local options,nativeUI,originalShow,wrappedShow,frames,voted
local catalog=table.clone(C.KnownCards)
local cardCategories={{'@pearls','Summer Pearls bonus'},{'@secret','Secret / Portal drop bonus'},{'@damage','Unit damage'},{'@cooldown','Faster attack speed'},{'@range','Unit range'},{'@cash','Cash / Yen gain'},{'@discount','Placement / upgrade discount'},{'@ability','Ability cooldown'},{'@boss','Boss damage'}}
for _,entry in ipairs(cardCategories)do catalog[entry[1]]=entry[2]end
function S.AddCard(key)
 if type(key)~='string'or not catalog[key]then return end
 if not table.find(C.CardOrder,key)then C.CardOrder[#C.CardOrder+1]=key end
 C.SelectedCards[key]=true;C.AvoidCards[key]=nil;S.Save();if S.RefreshUI then S.RefreshUI()end
end
function S.RemoveCard(key)
 local index=table.find(C.CardOrder,key);if index then table.remove(C.CardOrder,index)end
 C.SelectedCards[key]=nil;S.Save();if S.RefreshUI then S.RefreshUI()end
end
function S.MoveCard(key,delta)
 local index=table.find(C.CardOrder,key);local target=index and index+delta
 if target and target>=1 and target<=#C.CardOrder then C.CardOrder[index],C.CardOrder[target]=C.CardOrder[target],C.CardOrder[index];S.Save();if S.RefreshUI then S.RefreshUI()end end
end
local function learn(choices)
 local changed=false
 for _,choice in pairs(choices or{})do if type(choice)=='table'and type(choice.title)=='string'then local key=choice.title:lower();catalog[key]=choice.title;if C.KnownCards[key]~=choice.title then C.KnownCards[key]=choice.title;changed=true end end end
 if changed then S.Save()end
end
local function hookCards()
 local native=G.roguelike_select_ui
 if native==nativeUI or not native or type(native.show_options)~='function'then return end
 if nativeUI and nativeUI.show_options==wrappedShow then nativeUI.show_options=originalShow end
 nativeUI=native;originalShow=native.show_options
 wrappedShow=function(self,time,choices,...)
  if hunt()or sky()then options=choices;learn(choices);voted=nil end
  local out=table.pack(originalShow(self,time,choices,...));frames=self.option_frames
  return table.unpack(out,1,out.n)
 end
 native.show_options=wrappedShow
end
local function recoverCards()
 local out={}
 for key,frame in pairs(nativeUI and nativeUI.option_frames or{})do
  local inner=frame:FindFirstChild('inner');local main=inner and inner:FindFirstChild('Main')
  local info=main and main:FindFirstChild('InfoFrame');info=info and info:FindFirstChild('inner')
  local header=info and info:FindFirstChild('Header');local title=header and header:FindFirstChild('QuirkTitle')
  local scroll=info and info:FindFirstChild('infoscroll')
  if title and scroll then
   local choice={title=title.Text,effects={}}
   for _,label in ipairs(scroll:GetChildren())do if label:IsA('TextLabel')then
    local color=label.TextColor3;local text=label.Text:lower();local amount=math.abs(tonumber(text:match('([%d%.]+)'))or 10)
    local value=color.R>.7 and color.G<.35 and -amount or color.G>.7 and color.R<.4 and amount or color.R>.7 and color.G>.45 and amount or 0
    local preference
    if text:find('pearl',1,true)or text:find('reward currency',1,true)then preference='@pearls'
    elseif text:find('secret',1,true)then preference='@secret'
    elseif text:find('enemy',1,true)then preference=nil
    elseif text:find('cost',1,true)then preference='@discount'
    elseif text:find('cooldown',1,true)then preference=text:find('active',1,true)and'@ability'or'@cooldown'
    elseif text:find('boss',1,true)then preference='@boss'
    elseif text:find('damage',1,true)then preference='@damage'
    elseif text:find('range',1,true)then preference='@range'
    elseif text:find('yen',1,true)or text:find('¥',1,true)then preference='@cash'end
    choice.effects[#choice.effects+1]={type='ui_evidence',score=value,preference=preference}
   end end
   -- Weather cards can be identified exactly from their localized native name.
   for id,d in pairs(WeatherData)do if title.Text:lower():find(d.name:lower(),1,true)then choice.weather=id end end
   out[key]=choice
  end
 end
 return out
end
local function teamWeatherWeight(id)
 local total,count=0,0;local A=E.FyrelithAutoPlay
 if A and A.GetEquipped then for _,unit in ipairs(A.GetEquipped())do if A.SmartRole(unit.Id)=='damage'then total+=P.WeatherWeight(id,unit.Data);count+=1 end end end
 return count>0 and total/count or 1
end
local function cardTick()
 hookCards()
 if not C.Cards or not(hunt()or sky())or not nativeUI or not nativeUI.screenGUI.Enabled then return end
 local data=workspace:FindFirstChild('_DATA');local rogue=data and data:FindFirstChild('Roguelike');local waiting=rogue and rogue:FindFirstChild('WaitingForRoguelikeChoice')
 if not waiting or not waiting.Value then return end
 if frames~=nativeUI.option_frames then options=recoverCards();frames=nativeUI.option_frames;voted=nil;learn(options)end
 if voted or nativeUI.voted_option then return end
 if not options then options=recoverCards();learn(options)end
 local danger=false;local A=E.FyrelithAutoPlay
 if A and A.AnalyzeEnemies then local ok,context=pcall(A.AnalyzeEnemies);danger=ok and(context.Risk or context.AirRisk)or false end
 local ranks={};for i,id in ipairs(C.WeatherOrder)do ranks[id]=i end
 local best,bestScore,bestRank,bestCurrency=nil,nil,math.huge,-math.huge
 local function choose(mode)
  local keys={};for key in pairs(options or{})do keys[#keys+1]=key end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,key in ipairs(keys)do local choice=options[key];local score=P.CardScore(choice,mode,danger,C.SelectedCards,C.AvoidCards,ranks,choice.weather and teamWeatherWeight(choice.weather))
   local rank=P.PriorityRank(choice,C.CardOrder)
   if mode=='Selected only'and rank<math.huge and not C.AvoidCards[tostring(choice.title or''):lower()]then score=P.CardScore(choice,'Balanced',danger,C.SelectedCards,C.AvoidCards,ranks,choice.weather and teamWeatherWeight(choice.weather))end
   local currency=P.CurrencyBonus(choice)
   local wins=not best or rank<bestRank or rank==bestRank and score and score>bestScore
   if mode=='Rewards'then wins=not best or currency>bestCurrency or currency==bestCurrency and wins end
   if score and(mode=='Rewards'or rank<math.huge or C.Fallback or #C.CardOrder==0)and wins and nativeUI.option_frames[key]then best=key;bestScore=score;bestRank=rank;bestCurrency=currency end
  end
 end
 choose(C.CardPolicy)
 if not best and C.Fallback then choose('Balanced')end
 if best then
  local sent=call('select_roguelike_option','card:'..tostring(frames)..':'..tostring(best),best)
  if sent then voted=best;S.LastCard=options[best].title;note('Voted: '..S.LastCard)end
 else note('No card matches filters · manual choice available')end
end
local npcQuests={}
for _,npc in pairs(NPC)do for _,entry in pairs(type(npc)=='table'and npc.quests or{})do if type(entry)=='table'and tostring(entry.quest_id):find('summer2_',1,true)==1 then npcQuests[entry.quest_id]=true end end end
-- The NPC registry calls this list quest_data on some versions.
for _,npc in pairs(NPC)do if type(npc)=='table'then for _,value in pairs(npc)do if type(value)=='table'then for _,entry in pairs(value)do if type(entry)=='table'and tostring(entry.quest_id):find('summer2_',1,true)==1 then npcQuests[entry.quest_id]=true end end end end end end
local function rewardsTick()
 if not L.IsLobby then return end
 local session=U.session;local p=profile();local owned={}
 for key,q in pairs(p.quest_handler and p.quest_handler.quests or{})do
  local id=q.quest_info and q.quest_info.id
  if type(id)=='string'and id:find('summer2_',1,true)==1 then
   owned[id]=true
   if C.AutoQuests then
    local ok,complete=pcall(QuestCore.is_quest_complete,session,q)
    local requestKey='quest:'..tostring(q.uuid or key)
    if ok and complete and os.clock()>=(retry[requestKey]or 0)then
     if call('redeem_quest',requestKey,q.uuid or key)then note('Claiming '..tostring(Quests[id]and Quests[id].quest_name or id));return end
    end
   end
  end
 end
 if C.AcceptQuests then for id in pairs(npcQuests)do if not owned[id]then
  local ok,completed=pcall(QuestCore.is_unique_quest_complete_by_id,session,id)
  if ok and not completed and os.clock()>=(retry['accept:'..id]or 0)then if call('accept_npc_quest','accept:'..id,id)then note('Accepting Summer quest')end;return end
 end end end
 local bingo=G.summer2_hunt_maps_ui
 if C.Bingo and bingo then
  pcall(bingo.refresh,bingo)
  if(tonumber(bingo.ready_count)or 0)>0 then if call('claim_summer2_map_board_lines','bingo')then note('Claiming completed Summer Bingo lines')end end
 end
end
local function shopDefinitions()
 local out={}
 for id,d in pairs(Sale)do if d.resource_cost and d.resource_cost.id=='SummerPearls'then out['event:'..id]={Id=id,Data=d,Name=Items[d.item_id or id]and Items[d.item_id or id].name or id,Kind='event'}end end
 for id,d in pairs(Merchant.shop_items_for_sale or{})do if d.resource_cost and d.resource_cost.id=='SummerPearls'then out['daily:'..id]={Id=id,Data=d,Name=Items[d.item_id or id]and Items[d.item_id or id].name or id,Kind='daily'}end end
 return out
end
S.ShopDefinitions=shopDefinitions
local purchase
local function shopTick()
 if not C.AutoShop or not L.IsLobby then return end
 local day=os.date('!%Y-%m-%d',os.time()+7*3600);if C.SpendDay~=day then C.SpendDay=day;C.Spent=0;S.Save()end
 if purchase then
  local newCount=invCount(purchase.ItemId)
  if newCount>purchase.Before then
   S.LastPurchase={Id=purchase.ItemId,Confirmed=true};purchase=nil;S.ShopPaused=false
  elseif os.clock()-purchase.At>20 then
   -- Reservation remains charged against budget after an ambiguous request.
   S.ShopPaused=true;note('Purchase not confirmed · Retry queue to resume shop');return
  else return end
 end
 if S.ShopPaused then return end
 local defs=shopDefinitions();local keys={};for key,on in pairs(C.ShopSelected)do if on and defs[key]then keys[#keys+1]=key end end;table.sort(keys)
 for _,key in ipairs(keys)do
  local entry=defs[key];local d=entry.Data;local itemId=d.item_id or entry.Id
  local count=invCount(itemId);local target=finite(C.ShopTargets[key],1,1,9999)
  local stock=true
  if entry.Kind=='daily'then
   local native=G.bsd_shop_ui;local ok,n=pcall(function()return native:get_available(entry.Id)end)
   stock=ok and(n=='inf'or(tonumber(n)or 0)>0)
  end
  local allowed,cost=P.Affordable(d,pearls(),C.Reserve,C.Budget,C.Spent)
  if count<target and stock and allowed and os.clock()>=(retry['buy:'..key]or 0)then
   local before=pearls();local sent
   -- Reserve and persist before sending: reloads cannot reset the spending cap.
   C.Spent+=cost
   if not S.Save()then C.Spent-=cost;note('Shop paused · settings could not be saved');return end
   if entry.Kind=='daily'then sent=call('buy_bsd_shop_item','buy:'..key,entry.Id)
   else sent=call('buy_item_generic','buy:'..key,entry.Id,'event','event_shop',nil)end
   if sent then purchase={ItemId=itemId,Before=count,Pearls=before,Cost=cost,At=os.clock()};note('Buying '..entry.Name)
   else C.Spent-=cost;S.Save()end
   return
  end
 end
end
local notified={}
local function notificationTick()
 if not C.Notify then return end
 local current=currentEvent();local id=weatherId()
 local forecast=current and current.forecast
 if id~='meteor_shower'and not(forecast and forecast.weather=='meteor_shower')then S.Notice=nil;return end
 local key=tostring(math.floor(workspace:GetServerTimeNow()/3600))..':'..tostring(id=='meteor_shower'and'now'or'next')
 local message=id=='meteor_shower'and'Starfall is active · Summer Hunt'or'Starfall is in the next Summer forecast'
 S.Notice=message
 if notified[key]then return end
 notified[key]=true
 if G.message_ui and G.message_ui.show_message then pcall(G.message_ui.show_message,G.message_ui,message,'Success')end
 if C.Webhook then
  local W=E.FyrelithWebhook
  if W and W.Send then W.Send({embeds={{title='Fyrelith · Summer forecast',description=message,color=12493055}}},'summer-starfall:'..key,false)end
 end
end
-- Keep the existing economy gates and Dungeon policy; only Summer gains weather weighting.
local A=E.FyrelithAutoPlay
local originalWeight,weightWrapper,originalClear,clearWrapper,originalValidate,validateWrapper
function S.FireBlocked(position,padding)
 if not C.WeatherSmart or not(hunt()or sky())or weatherId()~='fire'then return false end
 local data=workspace:FindFirstChild('_DATA');if not data then return false end
 local radius=tonumber(data:GetAttribute('weather_fire_radius'))or 10
 for i=1,finite(data:GetAttribute('weather_fire_count'),0,0,300)do local point=data:GetAttribute('weather_fire_patch_'..i)
  if typeof(point)=='Vector3'and math.abs(position.Y-point.Y)<6 and(Vector2.new(point.X,point.Z)-Vector2.new(position.X,position.Z)).Magnitude<radius+(padding or 0)then return true end
 end
 return false
end
if A then
 originalWeight=A.DungeonElementWeight
 weightWrapper=function(id,...)
  local value=originalWeight(id,...)
  if C.WeatherSmart and(hunt()or sky())and A.SmartRole(id)=='damage'then
   local weather=weatherId();value*=P.WeatherWeight(weather,Units[id])
   if weather=='windy'and A.AirInvestmentWeight then value*=.65+.35*math.clamp(A.AirInvestmentWeight(id,0),0,2)end
  end
  return value
 end
 A.DungeonElementWeight=weightWrapper
 originalClear=A.PlacementIsClear
 clearWrapper=function(point,snapshot,...)
  if S.FireBlocked(point,snapshot and snapshot.Padding or 1)then return false end
  return originalClear(point,snapshot,...)
 end
 A.PlacementIsClear=clearWrapper
 originalValidate=A.ValidateAutoAction
 validateWrapper=function(step,...)
  if step.Action=='Place'and step.CF and S.FireBlocked(CFrame.new(table.unpack(step.CF)).Position,A.GetSmartPlacementMargin(step.UnitId))then return false,'Inferno fire zone · choosing another position'end
  return originalValidate(step,...)
 end
 A.ValidateAutoAction=validateWrapper
end
local page=assert(gui:FindFirstChild('Event',true),'Event page missing')
for _,child in ipairs(page:GetChildren())do if child:IsA('GuiObject')then child:Destroy()end end
local bindings={};local painters={}
local function color(role,fallback)return gui:GetAttribute('Palette_'..role)or fallback end
local function paintProperty(object,property,role,fallback)object[property]=color(role,fallback);bindings[#bindings+1]={object,property,role,fallback}end
local function new(class,properties,parent)local object=Instance.new(class);for k,v in pairs(properties)do object[k]=v end;object.Parent=parent;return object end
local function round(object,r)new('UICorner',{CornerRadius=UDim.new(0,r or 10)},object)end
local function text(parent,name,value,height,size,bold)
 local label=new('TextLabel',{Name=name,Text=value,Size=UDim2.new(1,0,0,height or 24),BackgroundTransparency=1,TextColor3=Color3.fromRGB(239,240,249),TextSize=size or 13,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y},parent)
 return label
end
local host=new('Frame',{Name='SummerDashboard',Size=UDim2.new(1,-16,0,0),Position=UDim2.fromOffset(8,8),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},page)
local dashboardLayout=new('UIListLayout',{Name='ResponsiveColumns',FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,16),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Top},host)
page.AutomaticCanvasSize=Enum.AutomaticSize.Y
page.CanvasSize=UDim2.new()
local columns={}
for i=1,2 do
 local column=new('Frame',{Name='Column'..i,LayoutOrder=i,Size=UDim2.new(.5,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},host)
 new('UIListLayout',{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},column);columns[i]=column
end
local function card(column,title,order)
 local panel=new('Frame',{Name='Summer'..title:gsub('%W',''),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0,LayoutOrder=order,BackgroundTransparency=.06},columns[column]);round(panel,12)
 paintProperty(panel,'BackgroundColor3','card',Color3.fromRGB(25,25,37))
 new('UIPadding',{PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)},panel)
 new('UIListLayout',{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},panel)
 local stroke=new('UIStroke',{Thickness=1,Transparency=.65},panel);paintProperty(stroke,'Color','line',Color3.fromRGB(71,65,90))
 local label=text(panel,'Title',title,26,17,true);label.LayoutOrder=-100
 return panel
end
local function button(parent,name,caption,fn)
 local b=new('TextButton',{Name=name,Text=caption,Size=UDim2.new(1,0,0,34),TextColor3=Color3.fromRGB(239,240,249),TextSize=12,Font=Enum.Font.GothamMedium,BorderSizePixel=0,AutoButtonColor=false},parent);round(b,8);paintProperty(b,'BackgroundColor3','field',Color3.fromRGB(38,34,51))
 S.Connections[#S.Connections+1]=b.Activated:Connect(fn);return b
end
local function toggle(parent,key,title,callback)
 local row=button(parent,key,'',function()C[key]=not C[key];if callback then callback(C[key])end;S.Save();for _,paint in ipairs(painters)do paint()end end)
 local label=text(row,'Caption',title,32,12);label.Size=UDim2.new(1,-70,1,0);label.Position=UDim2.fromOffset(8,0);label.AutomaticSize=Enum.AutomaticSize.None
 local track=new('Frame',{Name='Track',Position=UDim2.new(1,-59,.5,-13),Size=UDim2.fromOffset(50,26),BorderSizePixel=0},row);round(track,14)
 local knob=new('Frame',{Name='Knob',Size=UDim2.fromOffset(20,20),BackgroundColor3=Color3.fromRGB(244,243,255),BorderSizePixel=0},track);round(knob,12)
 local function paint()local on=C[key]==true;track.BackgroundColor3=color(on and'accent'or'line',Color3.fromRGB(80,74,104));knob.Position=UDim2.fromOffset(on and 27 or 3,3);row:SetAttribute('Enabled',on)end
 painters[#painters+1]=paint;paint();return row
end
local function cycle(parent,key,title,values,callback)
 local b;local function paint()b.Text=title..'   ·   '..tostring(C[key])end
 b=button(parent,key,'',function()local i=table.find(values,C[key])or 0;C[key]=values[i%#values+1];if callback then callback(C[key])end;S.Save();paint()end)
 painters[#painters+1]=paint;paint();return b
end
local function number(parent,key,title,lo,hi)
 local row=new('Frame',{Name=key..'Row',Size=UDim2.new(1,0,0,34),BackgroundTransparency=1},parent)
 local label=text(row,'Caption',title,34,12);label.AutomaticSize=Enum.AutomaticSize.None;label.Size=UDim2.new(1,-94,1,0)
 local box=new('TextBox',{Name=key,Text=tostring(C[key]),PlaceholderText='0',Size=UDim2.fromOffset(84,32),Position=UDim2.new(1,-84,0,0),ClearTextOnFocus=false,TextColor3=Color3.fromRGB(239,240,249),TextSize=13,Font=Enum.Font.Gotham,BorderSizePixel=0},row);round(box,8);paintProperty(box,'BackgroundColor3','field',Color3.fromRGB(38,34,51))
 S.Connections[#S.Connections+1]=box.FocusLost:Connect(function()C[key]=finite(box.Text,defaults[key]or 0,lo,hi);if key=='MinTier'then C.MaxTier=math.max(C.MaxTier,C.MinTier)elseif key=='MaxTier'then C.MinTier=math.min(C.MinTier,C.MaxTier)end;S.Save();for _,paint in ipairs(painters)do paint()end end)
 painters[#painters+1]=function()if not box:IsFocused()then box.Text=tostring(C[key])end end
 return box
end
local join=card(1,'SUMMER HUNT',1)
local liveText=text(join,'LiveForecast','Reading current map and weather...',48,12)
toggle(join,'JoinEnabled','Auto Join · Summer Hunt',S.SetJoinEnabled)
local entryPicker;local entryMenu
entryPicker=button(join,'SummerEntryMode','',function()entryMenu.Visible=not entryMenu.Visible end)
entryMenu=new('Frame',{Name='SummerEntryOptions',Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false},join)
new('UIListLayout',{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},entryMenu)
for i,mode in ipairs({'Solo','Matchmaking'})do
 local value=mode;local option=button(entryMenu,'Choose'..mode,mode,function()S.SetEntryMode(value);entryMenu.Visible=false;S.RefreshUI()end);option.LayoutOrder=i
end
painters[#painters+1]=function()entryPicker.Text='Join mode   ·   '..C.EntryMode end
local countText=text(join,'RunCount','Summer Pearls: 0',22,12)
local statusText=text(join,'Status',S.Status,44,12)
local cards=card(1,'CHALLENGE CARDS',2)
toggle(cards,'Cards','Auto select cards')
cycle(cards,'CardPolicy','Selection',{'Balanced','Safe','Rewards','Selected only'})
toggle(cards,'Fallback','Use Balanced if no choice matches')
text(cards,'Hint','Pick priorities below. 1 is first, then 2, then 3 when offered. Use arrows to reorder. Specific cards are added automatically as they appear.',52,11)
local cardSummary=text(cards,'PrioritySummary','No priorities · automatic selection',24,11)
local cardList=new('Frame',{Name='CardPriorityList',Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},cards)
new('UIListLayout',{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},cardList)
local chooseCards
local cardMenu=new('Frame',{Name='CardCatalog',Size=UDim2.new(1,0,0,254),BackgroundTransparency=1,Visible=false},cards)
local cardSearch=new('TextBox',{Name='SearchCards',Text='',PlaceholderText='Search cards / bonuses...',ClearTextOnFocus=false,Size=UDim2.new(1,0,0,32),TextColor3=Color3.fromRGB(239,240,249),TextSize=12,Font=Enum.Font.Gotham,BorderSizePixel=0},cardMenu);round(cardSearch,8);paintProperty(cardSearch,'BackgroundColor3','field',Color3.fromRGB(38,34,51))
local availableCards=new('ScrollingFrame',{Name='AvailableCards',Size=UDim2.new(1,0,1,-40),Position=UDim2.fromOffset(0,40),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},cardMenu)
new('UIListLayout',{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},availableCards)
chooseCards=button(cards,'ChooseCardPriorities','+ Choose cards / bonuses',function()cardMenu.Visible=not cardMenu.Visible;chooseCards.Text=cardMenu.Visible and'Close card list'or'+ Choose cards / bonuses'end)
chooseCards.LayoutOrder=3;cardMenu.LayoutOrder=4
cardList.LayoutOrder=2;cardSummary.LayoutOrder=1
button(cards,'ClearCardPriorities','Clear priorities',function()C.CardOrder={};C.SelectedCards={};S.Save();S.RefreshUI()end).LayoutOrder=5
S.Connections[#S.Connections+1]=cardSearch:GetPropertyChangedSignal('Text'):Connect(function()if S.RefreshUI then S.RefreshUI()end end)
local weatherPanel=card(1,'WEATHER & SMART PLAY',3)
toggle(weatherPanel,'WeatherSmart','Smart Play · adapt to Summer weather')
text(weatherPanel,'WeatherHint','Uses your existing placement areas and farm policy. Inferno fire zones are excluded; Blizzard, Magical and Sandstorm adjust damage value.',55,11)
local orderText=text(weatherPanel,'WeatherOrder','Weather preference: Auto',38,11)
for _,id in ipairs({'meteor_shower','rain','windy','snow','fire','sandstorm','mana','underwater','downpour'})do
 button(weatherPanel,'Weather_'..id,weatherName(id),function()local index=table.find(C.WeatherOrder,id);if index then table.remove(C.WeatherOrder,index)else C.WeatherOrder[#C.WeatherOrder+1]=id end;S.Save()end)
end
button(weatherPanel,'ClearWeather','Clear weather priority',function()C.WeatherOrder={};S.Save()end)
local portals=card(2,'SKY PORTALS',1)
toggle(portals,'AutoPortal','Auto open and play selected portals',function(value)if value then local A=E.FyrelithAutoJoin;if A then A.Enabled=false;A.Config.ContractEnabled=false end;local D=E.FyrelithDungeon;if D and D.Config then D.Config.Enabled=false;if D.Save then D.Save()end end end end)
cycle(portals,'PortalKind','Portal kind',{'Sky','Sky God','Explosion Mage','All'})
number(portals,'MinTier','Minimum Sky tier',1,12);number(portals,'MaxTier','Maximum Sky tier',1,12)
cycle(portals,'PortalOrder','Use order',{'Lowest first','Highest first'})
toggle(portals,'UseSecrets','Allow consuming Secret portals')
number(portals,'PortalWait','Wait in portal lobby · seconds',0,120)
toggle(portals,'PortalFallback','Run Hunt when no matching portal')
text(portals,'PortalHint','Secret portals stay untouched unless enabled above. When filters match no portal, wait or use Hunt fallback. Returns to lobby to choose the next portal.',58,11)
local portalText=text(portals,'PortalInventory','Matching portals: 0',22,12)
local rewards=card(2,'SUMMER QUESTS & BINGO',2)
toggle(rewards,'AcceptQuests','Accept Summer crew quests')
toggle(rewards,'AutoQuests','Claim completed Summer quests')
toggle(rewards,'Bingo','Claim completed Bingo lines')
button(rewards,'OpenBingo','Open native Summer Bingo',function()local b=G.summer2_hunt_maps_ui;if b and b.toggle then b:toggle()end end)
local questText=text(rewards,'Progress','Waiting for quest progress...',44,11)
local shop=card(2,'SUMMER SHOP',3)
toggle(shop,'AutoShop','Auto buy selected items')
number(shop,'Reserve','Keep at least Pearls',0,1000000000)
number(shop,'Budget','Daily Pearl budget · 0 disables buying',0,1000000000)
local spendText=text(shop,'Spend','Spent today: 0',22,11)
text(shop,'ShopHint','Set target inventory quantity per selected item. Includes the Summer merchant daily stock. Only Summer Pearls are spent.',45,11)
local shopList=new('Frame',{Name='ShopItems',Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},shop);new('UIListLayout',{Padding=UDim.new(0,6)},shopList)
local notify=card(2,'STARFALL ALERTS',4)
toggle(notify,'Notify','Show current / upcoming Starfall')
toggle(notify,'Webhook','Also send to saved webhook')
text(notify,'WebhookHint','Uses the Webhook tab settings. Enable Webhook there to receive alerts.',38,11)
local noticeText=text(notify,'Notice','No Starfall alert',32,12)
local cardRows={};local availableRows={};local shopRows={}
local function refreshLists()
 for key in pairs(C.SelectedCards)do if not catalog[key]then catalog[key]=key end end
 local ranks={};for rank,key in ipairs(C.CardOrder)do ranks[key]=rank end
 for key,row in pairs(cardRows)do row.Frame.Visible=ranks[key]~=nil end
 for rank,key in ipairs(C.CardOrder)do
  local row=cardRows[key]
  if not row then
   local k=key;local frame=new('Frame',{Name='PriorityCard',Size=UDim2.new(1,0,0,48),BackgroundTransparency=1},cardList)
   local caption=text(frame,'Caption','',48,12);caption.AutomaticSize=Enum.AutomaticSize.None;caption.Size=UDim2.new(1,-112,1,0)
   local up=button(frame,'Up','↑',function()S.MoveCard(k,-1)end);up.Size=UDim2.fromOffset(30,32);up.Position=UDim2.new(1,-106,.5,-16)
   local down=button(frame,'Down','↓',function()S.MoveCard(k,1)end);down.Size=UDim2.fromOffset(30,32);down.Position=UDim2.new(1,-70,.5,-16)
   local remove=button(frame,'Remove','×',function()S.RemoveCard(k)end);remove.Size=UDim2.fromOffset(30,32);remove.Position=UDim2.new(1,-34,.5,-16)
   row={Frame=frame,Caption=caption};cardRows[key]=row
  end
  row.Frame.Visible=true;row.Frame.LayoutOrder=rank;row.Caption.Text=rank..'. '..tostring(catalog[key]or key)
 end
 local keys={};for key in pairs(catalog)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)if a:sub(1,1)=='@'and b:sub(1,1)~='@'then return true elseif b:sub(1,1)=='@'and a:sub(1,1)~='@'then return false end;return tostring(catalog[a])<tostring(catalog[b])end)
 local query=cardSearch.Text:lower();local shown=0
 for _,key in ipairs(keys)do
  local b=availableRows[key]
  if not b then local k=key;b=button(availableCards,'AvailableCard','',function()S.AddCard(k)end);b.Size=UDim2.new(1,-6,0,34);availableRows[key]=b end
  local visible=not ranks[key]and tostring(catalog[key]):lower():find(query,1,true)~=nil
  b.Visible=visible==true;b.Text='+ '..tostring(catalog[key]);if visible then shown+=1;b.LayoutOrder=shown end
 end
 cardSummary.Text=#C.CardOrder>0 and('Selected priorities: '..#C.CardOrder..' · first available wins')or'No priorities · automatic selection'
 local defs=shopDefinitions();local ordered={};for key in pairs(defs)do ordered[#ordered+1]=key end;table.sort(ordered)
 for i,key in ipairs(ordered)do local d=defs[key];local row=shopRows[key]
  if not row then
   local k=key
   local frame=new('Frame',{Name='ShopItem',Size=UDim2.new(1,0,0,64),BackgroundTransparency=1},shopList)
   local b=button(frame,'Select','',function()C.ShopSelected[k]=not C.ShopSelected[k]or nil;S.Save()end);b.Size=UDim2.new(1,-65,0,34)
   local target=new('TextBox',{Name='TargetQuantity',Text=tostring(C.ShopTargets[k]or 1),PlaceholderText='Qty',ClearTextOnFocus=false,Size=UDim2.fromOffset(58,34),Position=UDim2.new(1,-58,0,0),TextColor3=Color3.fromRGB(239,240,249),Font=Enum.Font.Gotham,TextSize=12,BorderSizePixel=0},frame);round(target,7);paintProperty(target,'BackgroundColor3','field',Color3.fromRGB(38,34,51))
   local detail=text(frame,'Detail','',25,10);detail.Position=UDim2.fromOffset(0,37);detail.AutomaticSize=Enum.AutomaticSize.None
   S.Connections[#S.Connections+1]=target.FocusLost:Connect(function()C.ShopTargets[k]=finite(target.Text,1,1,9999);target.Text=tostring(C.ShopTargets[k]);S.Save()end)
   row={Frame=frame,Button=b,Target=target,Detail=detail};shopRows[k]=row
  end
  row.Frame.LayoutOrder=i;row.Button.Text=(C.ShopSelected[key]and'✓ 'or'')..d.Name
  row.Detail.Text=(d.Kind=='daily'and'Daily merchant'or'Summer market')..' · '..tostring(d.Data.resource_cost.amount)..' Pearls · owned '..invCount(d.Data.item_id or d.Id)
 end
end
function S.RefreshUI()
 local current=currentEvent();local level=current and current.current_level_data
 local map=level and level.map;local forecast=current and current.forecast
 liveText.Text='Now: '..tostring(Maps[map or'']and Maps[map].name or map or'Unknown')..' · '..weatherName(weatherId())..'\nNext: '..weatherName(forecast and forecast.weather)
 countText.Text='Summer Pearls: '..pearls();statusText.Text=S.Status
 portalText.Text='Matching portals: '..#S.PortalChoices();spendText.Text='Reserved / spent today: '..C.Spent..' / '..C.Budget
 noticeText.Text=C.Notify and(S.Notice or'Watching the forecast')or'Alerts are off'
 local names={};for _,id in ipairs(C.WeatherOrder)do names[#names+1]=weatherName(id)end;orderText.Text='Weather priority: '..(#names>0 and table.concat(names,' > ')or'Auto · best for team')
 local completed,total=0,0
 for _,q in pairs(profile().quest_handler and profile().quest_handler.quests or{})do local id=q.quest_info and q.quest_info.id;if type(id)=='string'and id:find('summer2_',1,true)==1 then total+=1;local ok,ready=pcall(QuestCore.is_quest_complete,U.session,q);if ok and ready then completed+=1 end end end
 questText.Text='Summer quests: '..completed..' ready / '..total..' active\nBingo: '..tostring(G.summer2_hunt_maps_ui and G.summer2_hunt_maps_ui.ready_count or 0)..' claimable lines'
 refreshLists();for _,paint in ipairs(painters)do paint()end
 dashboardLayout.FillDirection=Enum.FillDirection.Horizontal
 columns[1].Size=UDim2.new(.5,-8,0,0)
 columns[2].Size=columns[1].Size
end
S.Connections[#S.Connections+1]=gui:GetAttributeChangedSignal('PaletteRevision'):Connect(function()
 for _,binding in ipairs(bindings)do if binding[1].Parent then binding[1][binding[2]]=color(binding[3],binding[4])end end
 for _,paint in ipairs(painters)do paint()end
end)
S.Connections[#S.Connections+1]=player.OnTeleport:Connect(function()S.Save()end)
S.Connections[#S.Connections+1]=game:GetService('TeleportService').TeleportInitFailed:Connect(function(who)if who==player then S.QueueRequested=false;S.Prompted=false;retry['summer-matchmaking']=os.clock()+15 end end)
function S.Stop()
 if not S.Alive then return end
 local notifications=G.notification_windows_ui
 if S.Prompted and notifications and notifications.close_matchmaking_popup then pcall(notifications.close_matchmaking_popup,notifications)end
 S.Save();S.Alive=false
 if nativeUI and nativeUI.show_options==wrappedShow then nativeUI.show_options=originalShow end
 if A then
  if A.DungeonElementWeight==weightWrapper then A.DungeonElementWeight=originalWeight end
  if A.PlacementIsClear==clearWrapper then A.PlacementIsClear=originalClear end
  if A.ValidateAutoAction==validateWrapper then A.ValidateAutoAction=originalValidate end
 end
 for _,connection in ipairs(S.Connections)do connection:Disconnect()end
 if host.Parent then host:Destroy()end
end
S.Close=S.Stop
S.Connections[#S.Connections+1]=gui.Destroying:Connect(S.Stop)
S.RefreshUI()
function S.Tick()
 if not active()then return end
 if not L.IsLobby then S.QueueRequested=false;S.Prompted=false;S.Opening=nil;S.PortalRoomAt=nil else S.ReturningResult=false end
 if not(E.FyrelithAutoJoin and E.FyrelithAutoJoin.MatchEnded)then resultToken=nil;resultHandled=false end
 cardTick();notificationTick();S.SolveCaptcha()
 if not S.Pending then rewardsTick()end
 if not S.Pending then shopTick()end
 if not S.Pending then lobbyTick()end
 S.RefreshUI()
end
task.spawn(function()
 while S.Alive and gui.Parent do
  if execution.Ready then
   local ok,err=pcall(S.Tick)
   if not ok then S.Error=tostring(err);note('Summer waiting: '..S.Error)end
  end
  task.wait(1)
 end
end)
S.Installed=true

]================================================], 'Fyrelith Summer 21'))()
-- FYRELITH_RESET_ALL_SETTINGS_V1
assert(loadstring([===========================================[
-- Reset every settings category, retaining recorded macros and cached map geometry.
local E=getgenv()
local player=game:GetService('Players').LocalPlayer
local gui=assert(E.FyrelithExecutionState and E.FyrelithExecutionState.Gui,'Fyrelith UI is not ready')
local storage=assert(E.FyrelithDefaultLoaderStorage or E.FyrelithLoaderStorage)
local H=game:GetService('HttpService')
local old=E.FyrelithFactoryReset
if old and old.Connection then old.Connection:Disconnect()end
local X={Busy=false}
E.FyrelithFactoryReset=X
local suffix='_'..player.UserId..'_'..game.GameId..'.json'
local categories={'Session','TeamSettings','GoldShop','Summon','AutoClaim','Trait','Privacy','Challenge','Buff','TeamControl','Merchant','Webhook','Event','EventSpells','AprilUnits','Summer','Dungeon','AutoPlay','Macros'}
function X.DefaultDocument(category,document)
 document=type(document)=='table'and document or {}
 if category=='Macros'then return {Library=type(document.Library)=='table'and document.Library or {},Config={Name='My macro',Timing='Hybrid',Auto=false,Wait=60}}end
 if category=='AutoPlay'then return {Plans=type(document.Plans)=='table'and document.Plans or {},Areas={}}end
 return {}
end
function X.Run()
 if X.Busy then return false end;X.Busy=true
 local source=E.FyrelithScriptSource
 local compiled,compileError=type(source)=='string'and loadstring(source)
 if not compiled then X.Busy=false;X.Error=tostring(compileError or 'Script source unavailable');return false end
 -- Flush the current values before backing up. No game requests are issued by this reset.
 local controllers={}
 for key,value in pairs(E)do if type(key)=='string'and key:match('^Fyrelith')and type(value)=='table'and value~=X then controllers[#controllers+1]=value end end
 for _,value in ipairs(controllers)do if type(value.Save)=='function'then pcall(value.Save)end end
 local backup,replacements={},{}
 local prepared,prepareError=pcall(function()
  for _,category in ipairs(categories)do
   local name='Fyrelith'..category..suffix
   local raw,document
   if storage.Exists(name)then raw=storage.Read(name);pcall(function()document=H:JSONDecode(raw)end)end
   backup[name]=raw or false
   replacements[name]=H:JSONEncode(X.DefaultDocument(category,document))
  end
  X.BackupFile='FyrelithResetBackup_'..player.UserId..'_'..game.GameId..'_'..DateTime.now().UnixTimestampMillis..'.json'
  local encoded=H:JSONEncode({Version=1,At=os.time(),Files=backup})
  storage.Write(X.BackupFile,encoded);assert(storage.Read(X.BackupFile)==encoded,'Reset backup verification failed')
 end)
 if not prepared then X.Busy=false;X.Error=tostring(prepareError);warn('Fyrelith reset: '..X.Error);return false end
 -- Old save callbacks must not write their captured values over the fresh defaults.
 storage.Epoch=(storage.Epoch or 0)+1
 local execution=E.FyrelithExecutionState
 if execution then execution.Cancelled=true;execution.Ready=false end
 for _,value in ipairs(controllers)do
  if type(value.Enabled)=='boolean'then value.Enabled=false end
  if type(value.Config)=='table'then for key,enabled in pairs(value.Config)do if type(enabled)=='boolean'then value.Config[key]=false end end end
 end
 for _,value in ipairs(controllers)do if type(value.Close)=='function'then pcall(value.Close)end end
 for _,value in ipairs(controllers)do if type(value.Stop)=='function'then pcall(value.Stop)end end
 for _,value in ipairs(controllers)do
  if value.Alive~=nil then value.Alive=false end
  if typeof(value.Connection)=='RBXScriptConnection'then value.Connection:Disconnect()end
  if type(value.Connections)=='table'then for _,connection in pairs(value.Connections)do if typeof(connection)=='RBXScriptConnection'then connection:Disconnect()end end end
 end
 if gui.Parent then gui:Destroy()end
 local runtime=E.FyrelithRuntime
 if runtime then
  runtime.Alive=false
  if runtime.Connection then runtime.Connection:Disconnect()end
  if runtime.PreferenceConnection then runtime.PreferenceConnection:Disconnect()end
 end
 local written,writeError=pcall(function()
  for name,encoded in pairs(replacements)do storage.Write(name,encoded);assert(storage.Read(name)==encoded,'Default settings verification failed: '..name)end
 end)
 if not written then
  for name,raw in pairs(backup)do if type(raw)=='string'then pcall(storage.Write,name,raw)end end
  X.Error=tostring(writeError);warn('Fyrelith reset failed; settings backup restored: '..X.Error)
 end
 local preferences=player.PlayerGui:FindFirstChild('FyrelithDefaultPreferences')
 if preferences then preferences:Destroy()end
 E.FyrelithLoadedSession=nil
 E.FyrelithLoadDelaySeenGame=nil;E.FyrelithDefaultLoadDelaySeenGame=nil
 E.FyrelithReturnLobbyInProgress=false
 E.FyrelithDefaultLeaveRouter=nil
 E.FyrelithRenderBootstrap=nil
 E.FyrelithMatchClock=nil
 for _,name in ipairs({'FyrelithChallengeInterruptTicket','FyrelithDefaultLoaderDelayConfig','FyrelithDefaultPendingAutoLeave'})do pcall(function()game:GetService('TeleportService'):SetTeleportSetting(name,nil)end)end
 pcall(function()game:GetService('RunService'):Set3dRenderingEnabled(true)end)
 X.Completed=written
 E.FyrelithLastReset={Completed=written,BackupFile=X.BackupFile,Error=X.Error}
 task.defer(compiled)
 return written
end
local button=assert(gui:FindFirstChild('ResetPreferences',true),'Reset settings button missing')
for _,connection in ipairs(getconnections(button.Activated))do connection:Disconnect()end
X.Connection=button.Activated:Connect(X.Run)
X.Installed=true

]===========================================], 'Fyrelith Reset All Settings'))()
fyExecution.Starting=false fyExecution.Ready=true fyExecution.CompletedAt=os.clock()
fyExecution.Gui.Destroying:Connect(function()if fyOwnsExecution()then fyExecution.Ready=false end end)
end,debug.traceback)
if not startupOK then C.Report('startup',startupError)end
if not startupOK and fyOwnsExecution()then fyExecution.Starting=false fyExecution.Ready=false fyExecution.Error=startupError getgenv().FyrelithStartupError=startupError warn(startupError)end
end)
]=======]
getgenv().FyrelithScriptSource=source
local run,err=loadstring(source)
assert(run,err)
run()

