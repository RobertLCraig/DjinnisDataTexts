-- Checks the SimC gear-line builder in Modules/ItemLevel.lua against real lines
-- from docs/spec/simc-export-example.txt. The offset arithmetic is the risky part:
-- bonus ids, modifier pairs and gem bonuses sit at positions that depend on the
-- counts before them, so an off-by-one produces a plausible line that is wrong.
--
-- Run it with any Lua 5.1+ from the repo root. No framework, no dependencies:
--
--     lua docs/spec/test-simc-item-line.lua
--
-- It loads only the block between the [simc-parser:begin] and [simc-parser:end]
-- markers in ItemLevel.lua, which is pure Lua and touches no WoW state.

local SOURCE = "Modules/ItemLevel.lua"

-- WoW's strsplit, which is the one game global the parser block uses.
function strsplit(sep, str)
    local out = {}
    for field in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
        out[#out + 1] = field
    end
    return (table.unpack or unpack)(out)
end

-- Crafted quality is looked up through the trade skill API. Report none, so the
-- expectations below stay about the parsing rather than about game data.
C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function() return nil end }

local f = assert(io.open(SOURCE, "r"), "cannot open " .. SOURCE .. " (run me from the repo root)")
local whole = f:read("*a")
f:close()

-- Capture from the newline after the begin marker, so the rest of that comment
-- line is not dragged in without its leading dashes.
local block = whole:match("%-%- %[simc%-parser:begin%][^\n]*\n(.-)%-%- %[simc%-parser:end%]")
assert(block, "markers [simc-parser:begin] / [simc-parser:end] not found in " .. SOURCE)

-- Re-export the file-local we want to reach, then load the block on its own.
local chunk = assert((loadstring or load)(block .. "\nreturn SimCItemLine"))
local SimCItemLine = chunk()
assert(type(SimCItemLine) == "function", "SimCItemLine did not come back from the parser block")

-- Each case is a hand-built item string plus the exact line the real addon emitted
-- for that item. Positions: 1 id, 2 enchant, 3-6 gems, 7-12 suffix/unique/level/
-- spec/flags/context, 13 numBonusIDs, then bonuses, then numPairs, then pairs.
local CASES = {
    {
        name = "enchant, one gem and six bonus ids, no modifiers",
        link = "|cff0070dd|Hitem:250024:7961:240895:0:0:0:0:0:90:102:0:0:6:13338:13440:6652:13575:12806:13534:0|h[Branches of the Luminous Bloom]|h|r",
        slot = "head",
        want = "head=,id=250024,enchant_id=7961,gem_id=240895,bonus_id=13338/13440/6652/13575/12806/13534",
    },
    {
        name = "bonus ids then a content_tuning modifier pair",
        link = "|cffa335ee|Hitem:273774:0:0:0:0:0:0:0:90:102:0:0:5:13440:6652:13662:12699:12842:1:28:1279|h[Snakeskin Spaulders]|h|r",
        slot = "shoulder",
        want = "shoulder=,id=273774,bonus_id=13440/6652/13662/12699/12842,content_tuning=1279",
    },
    {
        name = "no enchant and no gems, so neither key is emitted",
        link = "|cffa335ee|Hitem:268249:0:0:0:0:0:0:0:90:102:0:0:4:6652:13668:13333:12841:0|h[Vile Alchemist's Band]|h|r",
        slot = "finger2",
        want = "finger2=,id=268249,bonus_id=6652/13668/13333/12841",
    },
    {
        name = "two crafted-stat pairs collapse into one crafted_stats key",
        link = "|cffa335ee|Hitem:222446:0:0:0:0:0:0:0:90:102:0:0:2:6652:12699:2:29:40:30:36|h[A Crafted Thing]|h|r",
        slot = "chest",
        want = "chest=,id=222446,bonus_id=6652/12699,crafted_stats=40/36",
    },
    {
        name = "gem bonus ids, which sit two fields past the last modifier pair",
        link = "|cffa335ee|Hitem:251217:7967:240895:0:0:0:0:0:90:102:0:0:2:13440:6652:1:28:1279:0:2:9999:8888|h[Occlusion of Void]|h|r",
        slot = "finger1",
        want = "finger1=,id=251217,enchant_id=7967,gem_id=240895,bonus_id=13440/6652,content_tuning=1279,gem_bonus_id=9999/8888",
    },
    {
        name = "trailing empty gem sockets are trimmed, an inner one is kept",
        link = "|cffa335ee|Hitem:50228:0:240894:0:240983:0:0:0:90:102:0:0:2:13440:6652:0|h[Barbed Ymirheim Choker]|h|r",
        slot = "neck",
        want = "neck=,id=50228,gem_id=240894/0/240983,bonus_id=13440/6652",
    },
    {
        name = "a bare item link with no bonus ids at all",
        link = "|cff1eff00|Hitem:65360:0:0:0:0:0:0:0:90:102:0:0:0:0|h[Cloak of Coordination]|h|r",
        slot = "back",
        want = "back=,id=65360",
    },
}

local failures = 0
for _, case in ipairs(CASES) do
    local got = SimCItemLine(case.slot, case.link)
    if got == case.want then
        print("  ok   " .. case.name)
    else
        failures = failures + 1
        print("  FAIL " .. case.name)
        print("       want: " .. tostring(case.want))
        print("       got:  " .. tostring(got))
    end
end

-- A link with no item string at all must return nil rather than a broken line.
if SimCItemLine("head", "|cffffffff|Hspell:12345|h[Not An Item]|h|r") ~= nil then
    failures = failures + 1
    print("  FAIL a non-item link should return nil")
else
    print("  ok   a non-item link returns nil")
end

if failures > 0 then
    print(failures .. " failed")
    os.exit(1)
end
print("all passed")
