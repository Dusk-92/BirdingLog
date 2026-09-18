-- BirdingLog FR7.25 outdoor-area resolver regression tests.
_G.BL_AreaResolver=nil
dofile("Dusk/BirdingLog/BL_AreaResolver.lua")
local R=BL_AreaResolver

local function fail(message) error("test_area_resolver: "..tostring(message),2) end
local function assertEq(actual,expected,message)
    if actual~=expected then
        fail((message or "values differ")..": got "..tostring(actual)..", expected "..tostring(expected))
    end
end
local function assertTrue(value,message)
    if not value then fail(message or "expected true") end
end

local aliases={}
local state=R.New(aliases,300)

-- Unknown place: sightings are buffered and evidence narrows progressively.
local context=R.Begin(state,{
    key="eriador|bail avarc",
    region="Eriador",
    area="Bail Avarc",
    regionIndex=1,
    source="unknown",
    startedAt=100,
})
assertTrue(R.Buffer(state,"A0001",110),"first sighting should buffer")
local code,reason=R.AddEvidence(state,{An=true,Fo=true},110)
assertEq(code,nil,"first ambiguous sighting must not teach")
assertEq(reason,"ambiguous","first evidence state")

assertTrue(R.Buffer(state,"A0002",120),"second sighting should buffer")
code,reason,context=R.AddEvidence(state,{An=true,Br=true},120)
assertEq(code,"An","evidence intersection should identify Angmar")
assertEq(reason,nil,"unique evidence must have no error")
assertEq(context.sightings.A0001,1,"first buffered sighting preserved")
assertEq(context.sightings.A0002,1,"second buffered sighting preserved")

local ok,changed=R.Remember(state,context,"An")
assertTrue(ok,"remember should succeed")
assertTrue(changed,"first alias should be a change")
assertEq(aliases["eriador|bail avarc"],"An","alias persisted in supplied table")
assertEq(R.Pending(state,121),nil,"learning clears pending state")

-- A recently detected alias can be corrected manually.
context=R.Begin(state,{
    key="eriador|bail avarc",
    regionIndex=1,
    area="Bail Avarc",
    source="alias",
    startedAt=200,
})
assertEq(R.GetTeachable(state,210),context,"recent alias must be teachable")
ok,changed=R.Remember(state,context,"Fo")
assertTrue(ok and changed,"manual correction must overwrite an alias")
assertEq(aliases["eriador|bail avarc"],"Fo","corrected alias stored")

-- Forgetting an alias reopens the same location for fresh learning.
local forgotten,old,newContext=R.ForgetCurrent(state,220)
assertTrue(forgotten,"forget current alias")
assertEq(old,"Fo","forgotten alias returned")
assertEq(aliases["eriador|bail avarc"],nil,"alias removed")
assertEq(newContext.source,"unknown","forgotten place becomes unknown again")
assertEq(R.Pending(state,221),newContext,"forgotten place becomes pending")

-- Pending learning expires; stale sightings cannot teach a place after movement.
state=R.New({},300)
R.Begin(state,{
    key="eriador|old place",
    regionIndex=1,
    area="Old Place",
    source="unknown",
    startedAt=1000,
})
assertTrue(R.Buffer(state,"A0003",1010),"fresh sighting buffers")
assertEq(R.Pending(state,1301),nil,"pending place must expire after TTL")
assertEq(R.Buffer(state,"A0004",1301),false,"expired place must not accept new sightings")
code,reason=R.AddEvidence(state,{An=true},1301)
assertEq(code,nil,"expired place must never learn")
assertEq(reason,"expired","expired evidence state")

-- Contradictory observations cancel the pending context instead of teaching stale data.
state=R.New({},300)
R.Begin(state,{
    key="eriador|moving player",
    regionIndex=1,
    area="Moving Player",
    source="unknown",
    startedAt=2000,
})
R.AddEvidence(state,{An=true,Fo=true},2010)
code,reason=R.AddEvidence(state,{Br=true,Sh=true},2020)
assertEq(code,nil,"conflicting evidence must not learn")
assertEq(reason,"conflict","conflicting evidence state")
assertEq(R.Pending(state,2021),nil,"conflict clears pending context")

print("BirdingLog area resolver regression tests OK")
