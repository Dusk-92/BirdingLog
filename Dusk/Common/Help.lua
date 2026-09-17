-- Common Help function for plugins by David Down
-- coding: utf-8
import "Dusk.Common.Sort"
local pp
local function print(text) Turbine.Shell.WriteLine(pp..text) end
local function printh(text) print("<rgb=#00FF00>"..text.."</rgb>") end
local function IsFR() return BL_Lang=="FR" or FL_Lang=="FR" end
local function L(fr,en) if IsFR() then return fr else return en end end

function Help(help,arg)
    pp = "<rgb=#00FFFF>"..help.pre:upper()..":</rgb> "
    local pre = '/'..help.pre
    if not arg then
        print(help.help)
    elseif arg=='?' then
        printh(L("Arguments de commande possibles :","Possible command arguments:"))
        for name,desc in Sort(help.arg) do
            if #name>0 then print(name..' - '..desc) end
        end
    elseif arg=='??' then
        printh(L("Commandes possibles :","Possible commands:"))
        local str = help.arg[''] or help.arg[' ']
        if str then print(pre..' - '..str) end
        for name,desc in Sort(help.cmd) do
            local str,text = name,desc
            if type(text)=="table" then
                str = str.." ?"
                text = text[" "]
            end
            print('/'..str..' - '..text)
        end
    elseif help.cmd and help.cmd[arg] then
        local text = help.cmd[arg]
        if type(text) == "table" then
            printh(L("Arguments possibles pour '/"..arg.."' :","Possible '/"..arg.."' arguments:"))
            for name,desc in Sort(text) do
                print(name..' - '..desc)
            end
        else print(arg..' - '..text) end
    else
        if IsFR() then
            print("Entrez '"..pre.." ?' pour les arguments, ou '"..pre.."?' pour les commandes.")
        else
            print("Enter '"..pre.." ?' for arguments, '"..pre.."?' for commands")
        end
    end
end

function HelpCmd(cmd,args,help)
    local pre = help.pre
    if cmd==pre and (args=="help" or args=="aide" or args=="?" or args=="??") then
        Help(help,args=="aide" and "?" or args)
        return true
    end
    if cmd==pre..'?' then
        Help(help,"??")
        return true
    end
    if args=="?" then
        Help(help,cmd)
        return true
    end
end
