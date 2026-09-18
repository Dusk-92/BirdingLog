-- BirdingLog persistence regression tests.
local function fail(message) error("test_persistence: "..tostring(message),2) end
local function assertEq(actual,expected,message)
    if actual~=expected then
        fail((message or "values differ")..": got "..tostring(actual)..", expected "..tostring(expected))
    end
end

local function legacyEncode(obj)
    if type(obj)=="number" then return "#"..tostring(obj)
    elseif type(obj)=="string" then return "$"..obj
    elseif type(obj)=="table" then
        local out={}
        for k,v in pairs(obj) do out[legacyEncode(k)]=legacyEncode(v) end
        return out
    end
    return obj
end

local function makeEnvironment(language)
    local store={}
    _G.PluginDataLoadChecked=nil
    _G.PluginDataLoad=nil
    _G.PluginDataSave=nil
    _G.PluginDataDecodeLegacy=nil
    _G.import=function() end
    _G.Turbine={
        Language={English=1,French=2,German=3},
        Engine={GetLanguage=function() return language end},
        Shell={IsCommand=function(name)
            return (language==2 and name=="aide") or (language==3 and name=="zusatzmodule")
        end},
        PluginData={
            Load=function(scope,key,callback)
                if key=="explode" then error("simulated read failure") end
                local value=store[key]
                if callback then callback(value) end
                return value
            end,
            Save=function(scope,key,value,callback)
                store[key]=value
                if callback then callback(true,nil) end
                return true
            end,
        },
    }
    dofile("Dusk/Common/__init__.lua")
    return store
end

local store=makeEnvironment(1)
store.single=legacyEncode({fp=28,name="bird"})
local single,ok=PluginDataLoadChecked(1,"single")
assertEq(ok,true,"single encoded read")
assertEq(single.fp,28,"single encoded number")
assertEq(single.name,"bird","single encoded string")

store.double=legacyEncode(legacyEncode({fp=31,name="owl"}))
local double,doubleOK=PluginDataLoadChecked(1,"double")
assertEq(doubleOK,true,"double encoded read")
assertEq(double.fp,31,"double encoded number")
assertEq(double.name,"owl","double encoded string")

store.literal={name="$literal",count="#not-a-number"}
local literal,literalOK=PluginDataLoadChecked(1,"literal")
assertEq(literalOK,true,"literal read")
assertEq(literal.name,"$literal","literal dollar value")
assertEq(literal.count,"#not-a-number","literal hash value")

local bad,badOK=PluginDataLoadChecked(1,"explode")
assertEq(bad,nil,"failed read value")
assertEq(badOK,false,"failed read status")

PluginDataSave(1,"plainSave",{fp=42})
assertEq(store.plainSave.fp,42,"plain EN save")

store=makeEnvironment(2)
local callbackOK=false
PluginDataSave(1,"frSave",{fp=50,name="oiseau"},function(success)
    callbackOK=success==true
end)
assertEq(callbackOK,true,"save completion callback")
assertEq(store.frSave["$fp"],"#50","FR encoded numeric field")
assertEq(store.frSave["$name"],"$oiseau","FR encoded string field")
local frRead,frReadOK=PluginDataLoadChecked(1,"frSave")
assertEq(frReadOK,true,"FR roundtrip status")
assertEq(frRead.fp,50,"FR roundtrip number")
assertEq(frRead.name,"oiseau","FR roundtrip string")

print("BirdingLog persistence regression tests OK")
