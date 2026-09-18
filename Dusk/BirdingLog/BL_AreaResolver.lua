-- BirdingLog FR7.25 - pure outdoor sub-area learning state.
-- No Turbine dependency: kept separate so the risky learning logic can be unit-tested.

BL_AreaResolver = BL_AreaResolver or {}
local R = BL_AreaResolver

local function CopySet(source)
    local out={}
    for key,value in pairs(source or {}) do
        if value then out[key]=true end
    end
    return out
end

local function IsFresh(state,context,now)
    if type(context)~="table" then return false end
    if type(now)~="number" or type(context.startedAt)~="number" then return true end
    if now<context.startedAt then return false end
    return (now-context.startedAt)<=state.ttl
end

function R.New(aliases,ttl)
    return {
        aliases=type(aliases)=="table" and aliases or {},
        ttl=tonumber(ttl) or 300,
        current=nil,
        pending=nil,
    }
end

function R.Begin(state,context)
    if type(state)~="table" or type(context)~="table" then return nil end
    context.sightings={}
    context.evidence=nil
    state.current=context
    state.pending=context.source=="unknown" and context or nil
    return context
end

function R.Current(state,now)
    if not state or not IsFresh(state,state.current,now) then
        if state then
            if state.pending==state.current then state.pending=nil end
            state.current=nil
        end
        return nil
    end
    return state.current
end

function R.Pending(state,now)
    if not state or not IsFresh(state,state.pending,now) then
        if state then state.pending=nil end
        return nil
    end
    return state.pending
end

function R.GetTeachable(state,now)
    local pending=R.Pending(state,now)
    if pending then return pending end
    local current=R.Current(state,now)
    if current and (current.source=="unknown" or current.source=="alias") then
        return current
    end
    return nil
end

function R.Buffer(state,id,now)
    local context=R.Pending(state,now)
    if not context or type(id)~="string" or id=="" then return false end
    context.sightings=context.sightings or {}
    context.sightings[id]=(tonumber(context.sightings[id]) or 0)+1
    return true
end

function R.AddEvidence(state,candidates,now)
    local context=R.Pending(state,now)
    if not context then return nil,"expired",nil end

    local nextSet=CopySet(candidates)
    local any=false
    for _ in pairs(nextSet) do any=true break end
    if not any then return nil,"empty",context end

    if context.evidence then
        local intersection={}
        for code in pairs(context.evidence) do
            if nextSet[code] then intersection[code]=true end
        end
        nextSet=intersection
        any=false
        for _ in pairs(nextSet) do any=true break end
        if not any then
            -- Contradictory sightings usually mean the player moved after ;loc.
            -- Drop the pending context rather than teaching a stale location.
            state.pending=nil
            return nil,"conflict",context
        end
    end

    context.evidence=nextSet
    local count,last=0,nil
    for code in pairs(nextSet) do
        count=count+1
        last=code
    end
    if count==1 then return last,nil,context end
    return nil,"ambiguous",context
end

function R.Remember(state,context,code)
    if not state or type(context)~="table" or type(context.key)~="string" or
        context.key=="" or type(code)~="string" or code=="" then
        return false,false
    end

    local changed=state.aliases[context.key]~=code
    state.aliases[context.key]=code
    context.source="alias"
    state.current=context
    if state.pending==context then state.pending=nil end
    return true,changed
end

function R.ForgetCurrent(state,now)
    local context=R.Current(state,now)
    if not context or not context.key then return false,nil,nil end
    local old=state.aliases[context.key]
    if not old then return false,nil,context end

    state.aliases[context.key]=nil
    context.source="unknown"
    context.startedAt=now
    context.sightings={}
    context.evidence=nil
    state.current=context
    state.pending=context
    return true,old,context
end

function R.ClearPending(state)
    if not state then return end
    state.pending=nil
end
