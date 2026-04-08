-- DemoMode.lua - Djinni's Data Texts
-- Injects realistic fake data for screenshots and UI demos.
--
-- ENABLE:  Uncomment "DemoMode.lua" in DjinnisDataTexts.toc, then /reload
-- DISABLE: Comment it out again and /reload
--
-- While active, real friend/guild/community data is replaced with demo data.
-- Use /ddt demo to toggle the fake data on/off mid-session.
---------------------------------------------------------------------------

local addonName, ns = ...
local DDT = ns.addon

---------------------------------------------------------------------------
-- Demo datasets
---------------------------------------------------------------------------

local DEMO_FRIENDS = {
    -- WoW character friends - #Raid group
    { name="Arathos",     level=90, classFile="WARRIOR",     area="Silvermoon City",           connected=true,  afk=true,  dnd=false, notes="#Raid #Tank",       isBNet=false, fullName="Arathos" },
    { name="Sylvara",     level=90, classFile="PRIEST",      area="Eversong Woods",         connected=true,  afk=false, dnd=false, notes="#Raid #Healer",     isBNet=false, fullName="Sylvara" },
    { name="Korvash",     level=90, classFile="DEATHKNIGHT", area="Ghostlands",  connected=true,  afk=false, dnd=true,  notes="#Raid #Tank",       isBNet=false, fullName="Korvash" },
    { name="Mirela",      level=90, classFile="MAGE",        area="The Dead Scar",          connected=true,  afk=false, dnd=false, notes="#Raid",             isBNet=false, fullName="Mirela" },
    { name="Thundrik",    level=90, classFile="SHAMAN",      area="Sunstrider Isle",       connected=true,  afk=false, dnd=false, notes="#Raid #Healer",     isBNet=false, fullName="Thundrik" },
    { name="Vexholm",     level=90, classFile="ROGUE",       area="Ghostlands",  connected=true,  afk=false, dnd=false, notes="#Raid",             isBNet=false, fullName="Vexholm" },
    { name="Dreadfang",   level=90, classFile="WARLOCK",     area="The Sunwell",    connected=true,  afk=false, dnd=true,  notes="#Raid",             isBNet=false, fullName="Dreadfang" },
    { name="Lunaspire",   level=90, classFile="DRUID",       area="The Sunwell",    connected=true,  afk=false, dnd=true,  notes="#Raid #Healer",     isBNet=false, fullName="Lunaspire" },
    { name="Ashveil",     level=90, classFile="HUNTER",      area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="#Raid",             isBNet=false, fullName="Ashveil" },
    { name="Stormcrest",  level=90, classFile="EVOKER",      area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="#Raid #Healer",     isBNet=false, fullName="Stormcrest" },
    -- WoW character friends - #Mythic+ group
    { name="Pelindra",    level=90, classFile="DRUID",       area="Ghostlands",  connected=true,  afk=false, dnd=false, notes="#Mythic+",          isBNet=false, fullName="Pelindra" },
    { name="Kaelthorn",   level=90, classFile="PALADIN",     area="Sunstrider Isle",       connected=true,  afk=false, dnd=false, notes="#Mythic+ #Tank",    isBNet=false, fullName="Kaelthorn" },
    { name="Swiftclaw",   level=90, classFile="MONK",        area="Eversong Woods",         connected=true,  afk=false, dnd=false, notes="#Mythic+",          isBNet=false, fullName="Swiftclaw" },
    { name="Frostbloom",  level=90, classFile="MAGE",        area="The Dead Scar",          connected=true,  afk=false, dnd=false, notes="#Mythic+",          isBNet=false, fullName="Frostbloom" },
    { name="Hexara",      level=90, classFile="DEMONHUNTER", area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="#Mythic+ #Tank",    isBNet=false, fullName="Hexara" },
    -- WoW character friends - #PvP group
    { name="Bladesurge",  level=90, classFile="WARRIOR",     area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="#PvP",              isBNet=false, fullName="Bladesurge" },
    { name="Curseweave",  level=90, classFile="WARLOCK",     area="Sunstrider Isle",       connected=true,  afk=false, dnd=false, notes="#PvP",              isBNet=false, fullName="Curseweave" },
    { name="Spectral",    level=90, classFile="ROGUE",       area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="#PvP #Arena",       isBNet=false, fullName="Spectral" },
    { name="Ironcleave",  level=90, classFile="DEATHKNIGHT", area="Ghostlands",  connected=true,  afk=false, dnd=false, notes="#PvP",              isBNet=false, fullName="Ironcleave" },
    -- WoW character friends - #Casual / no tag
    { name="Maplewood",   level=90, classFile="DRUID",       area="Eversong Woods",         connected=true,  afk=false, dnd=false, notes="#Casual",           isBNet=false, fullName="Maplewood" },
    { name="Greymantle",  level=90, classFile="HUNTER",      area="Sunstrider Isle",       connected=true,  afk=true,  dnd=false, notes="#Casual",           isBNet=false, fullName="Greymantle" },
    { name="Cinderveil",  level=90, classFile="PRIEST",      area="The Dead Scar",          connected=true,  afk=false, dnd=false, notes="#Casual",           isBNet=false, fullName="Cinderveil" },
    { name="Bramblethatch",level=86, classFile="SHAMAN",     area="Ghostlands",  connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Bramblethatch" },
    { name="Goldvein",    level=82, classFile="PALADIN",     area="Quel'Thalas",         connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Goldvein" },
    { name="Thistlewick", level=75, classFile="MONK",        area="Sunstrider Isle",       connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Thistlewick" },
    { name="Rivenmoor",   level=90, classFile="EVOKER",      area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Rivenmoor" },
    -- BNet friends
    { name="Fenwick",     level=90, classFile="HUNTER",      area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Fenwick-Kaelthas",    accountName="Fen#1482",   battleTag="Fen#1482",   realmName="Kaelthas",   gameAccountID=10001 },
    { name="Zyara",       level=90, classFile="WARLOCK",     area="Ghostlands",  connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Zyara-Area 52",       accountName="Zy#2204",    battleTag="Zy#2204",    realmName="Area 52",    gameAccountID=10002 },
    { name="Torvald",     level=90, classFile="PALADIN",     area="Eversong Woods",         connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Torvald-Illidan",     accountName="Torv#9911",  battleTag="Torv#9911",  realmName="Illidan",    gameAccountID=10003 },
    { name="Duskweave",   level=90, classFile="DRUID",       area="Silvermoon City",           connected=true,  afk=true,  dnd=false, notes="",                  isBNet=true, fullName="Duskweave-Stormrage", accountName="Dusk#3374",  battleTag="Dusk#3374",  realmName="Stormrage",  gameAccountID=10004 },
    { name="Nythara",     level=90, classFile="ROGUE",       area="The Dead Scar",          connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Nythara-Proudmoore",  accountName="Nyth#7623",  battleTag="Nyth#7623",  realmName="Proudmoore", gameAccountID=10005 },
    { name="Valdris",     level=90, classFile="WARRIOR",     area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Valdris-Thrall",      accountName="Val#5501",   battleTag="Val#5501",   realmName="Thrall",     gameAccountID=10006 },
    { name="Ashenmere",   level=90, classFile="MAGE",        area="Sunstrider Isle",       connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Ashenmere-Frostmourne",accountName="Ash#8812",  battleTag="Ash#8812",   realmName="Frostmourne",gameAccountID=10007 },
    { name="Prixanna",    level=90, classFile="PRIEST",      area="Ghostlands",  connected=true,  afk=false, dnd=true,  notes="",                  isBNet=true, fullName="Prixanna-Saurfang",   accountName="Prix#3390",  battleTag="Prix#3390",  realmName="Saurfang",   gameAccountID=10008 },
    { name="Gloomhaven",  level=90, classFile="DEATHKNIGHT", area="Eversong Woods",         connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Gloomhaven-Barth'ilas",accountName="Gloom#6614",battleTag="Gloom#6614", realmName="Barth'ilas", gameAccountID=10009 },
    { name="Coppercog",   level=90, classFile="SHAMAN",      area="The Dead Scar",          connected=true,  afk=true,  dnd=false, notes="",                  isBNet=true, fullName="Coppercog-Khaz Modan", accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Khaz Modan", gameAccountID=10010 },
    -- Multiple friends from same battleTag (Cop#2277)
    { name="Ironrust",    level=90, classFile="WARRIOR",     area="Silvermoon City",           connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Ironrust-Khaz Modan",    accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Khaz Modan", gameAccountID=10011 },
    { name="Crystalpeak", level=85, classFile="MAGE",        area="Sunstrider Isle",       connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Crystalpeak-Area 52",     accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Area 52",    gameAccountID=10012 },
    { name="Swiftmend",   level=88, classFile="DRUID",       area="Eversong Woods",         connected=true,  afk=true,  dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Swiftmend-Stormrage",    accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Stormrage",  gameAccountID=10013 },
    { name="Shadowbolt",  level=82, classFile="WARLOCK",     area="Ghostlands",  connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Shadowbolt-Illidan",     accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Illidan",    gameAccountID=10014 },
    { name="Frostmace",   level=90, classFile="PALADIN",     area="Silvermoon City",           connected=true,  afk=false, dnd=true,  notes="#Golddigger",                  isBNet=true, fullName="Frostmace-Proudmoore",   accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Proudmoore", gameAccountID=10015 },
    { name="Voidstrike",  level=86, classFile="ROGUE",       area="The Dead Scar",          connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Voidstrike-Thrall",      accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Thrall",     gameAccountID=10016 },
    { name="Duskfeather", level=74, classFile="HUNTER",      area="Eversong Woods",         connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Duskfeather-Frostmourne",accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Frostmourne",gameAccountID=10017 },
}

local DEMO_GUILD_NAME = "Eternal Vigil"
local DEMO_GUILD_TOTAL = 178

local DEMO_GUILD = {
    -- Guild Master
    { name="Sarveth",      level=90, classFile="WARLOCK",     area="Silvermoon City",           rank="Guild Master", rankIndex=0, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Sarveth" },
    -- Officers
    { name="Lyrandel",     level=90, classFile="DRUID",       area="Eversong Woods",         rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Raid Lead",       fullName="Lyrandel" },
    { name="Kharsus",      level=90, classFile="DEATHKNIGHT", area="Ghostlands",  rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Main Tank",       fullName="Kharsus" },
    { name="Embervane",    level=90, classFile="PRIEST",      area="Silvermoon City",           rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Healing Lead",    fullName="Embervane" },
    { name="Stonebark",    level=90, classFile="WARRIOR",     area="The Dead Scar",          rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=2, afk=false, dnd=true,  notes="",                  officerNote="M+ Lead",         fullName="Stonebark" },
    -- Veterans
    { name="Brightmoon",   level=90, classFile="PALADIN",     area="Silvermoon City",           rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="For the Light!",    officerNote="",                fullName="Brightmoon" },
    { name="Zephran",      level=90, classFile="MONK",        area="The Dead Scar",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Zephran" },
    { name="Anella",       level=90, classFile="PRIEST",      area="Sunstrider Isle",       rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",                  officerNote="Backup Healer",   fullName="Anella" },
    { name="Flamecrest",   level=90, classFile="MAGE",        area="Eversong Woods",         rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Flamecrest" },
    { name="Wolfthorn",    level=90, classFile="HUNTER",      area="Ghostlands",  rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Sniper main",       officerNote="",                fullName="Wolfthorn" },
    { name="Shadowmend",   level=90, classFile="PRIEST",      area="Silvermoon City",           rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Shadowmend" },
    { name="Galefrost",    level=90, classFile="EVOKER",      area="Silvermoon City",           rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Aug main",        fullName="Galefrost" },
    { name="Ironmantle",   level=90, classFile="WARRIOR",     area="Sunstrider Isle",       rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ironmantle" },
    { name="Cinderpaw",    level=90, classFile="DRUID",       area="The Dead Scar",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Cinderpaw" },
    -- Members
    { name="Duskwarden",   level=90, classFile="HUNTER",      area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Duskwarden" },
    { name="Ironveil",     level=90, classFile="WARRIOR",     area="Ghostlands",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=2, afk=false, dnd=true,  notes="",                  officerNote="",                fullName="Ironveil" },
    { name="Crystalsong",  level=90, classFile="MAGE",        area="Eversong Woods",         rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Crystalsong" },
    { name="Wavestrider",  level=90, classFile="SHAMAN",      area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Wavestrider" },
    { name="Dreadspire",   level=90, classFile="WARLOCK",     area="The Dead Scar",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Dreadspire" },
    { name="Petalstorm",   level=90, classFile="DRUID",       area="Sunstrider Isle",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Petalstorm" },
    { name="Frostbane",    level=90, classFile="DEATHKNIGHT", area="Ghostlands",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",                  officerNote="",                fullName="Frostbane" },
    { name="Swiftarrow",   level=90, classFile="HUNTER",      area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Swiftarrow" },
    { name="Ashveil",      level=90, classFile="ROGUE",       area="The Dead Scar",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ashveil" },
    { name="Gloomthorn",   level=90, classFile="DEMONHUNTER", area="Eversong Woods",         rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Gloomthorn" },
    { name="Lunaveil",     level=90, classFile="MONK",        area="Sunstrider Isle",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Lunaveil" },
    { name="Stoneveil",    level=90, classFile="PALADIN",     area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Stoneveil" },
    { name="Emberfall",    level=90, classFile="EVOKER",      area="Ghostlands",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Emberfall" },
    { name="Rivenshard",   level=90, classFile="WARRIOR",     area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=true,  status=0, afk=false, dnd=false, notes="Mobile",            officerNote="",                fullName="Rivenshard" },
    { name="Moonwhisper",  level=90, classFile="DRUID",       area="Eversong Woods",         rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Moonwhisper" },
    { name="Blazemantle",  level=90, classFile="SHAMAN",      area="The Dead Scar",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Blazemantle" },
    { name="Thornwick",    level=90, classFile="ROGUE",       area="Ghostlands",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Thornwick" },
    { name="Coldvein",     level=90, classFile="MAGE",        area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Coldvein" },
    { name="Dawnbreaker",  level=90, classFile="PALADIN",     area="Sunstrider Isle",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Dawnbreaker" },
    { name="Runicbrand",   level=90, classFile="DEATHKNIGHT", area="The Dead Scar",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Runicbrand" },
    { name="Siltbreeze",   level=90, classFile="PRIEST",      area="Eversong Woods",         rank="Member",       rankIndex=3, connected=true,  isMobile=true,  status=0, afk=false, dnd=false, notes="Mobile",            officerNote="",                fullName="Siltbreeze" },
    { name="Ashmantle",    level=90, classFile="WARLOCK",     area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ashmantle" },
    -- Recruits (some leveling, some max)
    { name="Emberveil",    level=90, classFile="DEMONHUNTER", area="The Dead Scar",          rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="New member!",       officerNote="",                fullName="Emberveil" },
    { name="Nightblossom", level=88, classFile="DRUID",       area="Sunstrider Isle",       rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Leveling",          officerNote="",                fullName="Nightblossom" },
    { name="Sparkpetal",   level=85, classFile="MONK",        area="Quel'Thalas",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Sparkpetal" },
    { name="Ravenquill",   level=82, classFile="HUNTER",      area="Sunstrider Isle",       rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ravenquill" },
    { name="Hailcrest",    level=78, classFile="PALADIN",     area="Quel'Thalas",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Hailcrest" },
    { name="Cindersoot",   level=75, classFile="ROGUE",       area="Quel'Thalas",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Cindersoot" },
    { name="Mirefoot",     level=71, classFile="SHAMAN",      area="Quel'Thalas",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Mirefoot" },
    { name="Pebblestrike", level=65, classFile="WARRIOR",     area="Quel'Thalas",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Pebblestrike" },
    { name="Dewcatcher",   level=90, classFile="EVOKER",      area="Silvermoon City",           rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Trial raider",      officerNote="Trial - 2 weeks", fullName="Dewcatcher" },
    { name="Voidspire",    level=90, classFile="WARLOCK",     area="The Dead Scar",          rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Trial - 1 week",  fullName="Voidspire" },
    { name="Galestone",    level=90, classFile="MAGE",        area="Silvermoon City",           rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",                  officerNote="",                fullName="Galestone" },
    { name="Thornmantle",  level=90, classFile="PRIEST",      area="Eversong Woods",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=true,  status=0, afk=false, dnd=false, notes="Mobile",            officerNote="",                fullName="Thornmantle" },
    -- Guildies with both public and officer notes
    { name="Firebrand",    level=90, classFile="MAGE",        area="Silvermoon City",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="PvP enthusiast",      officerNote="Strong DPS, needs gear",  fullName="Firebrand" },
    { name="Shieldwall",   level=90, classFile="WARRIOR",     area="The Dead Scar",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Always helps new players", officerNote="Potential raid officer", fullName="Shieldwall" },
    { name="Starwhisper",  level=90, classFile="PRIEST",      area="Sunstrider Isle",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Healer main, funny person", officerNote="Consider for healing lead", fullName="Starwhisper" },
    { name="Venomfang",    level=90, classFile="ROGUE",       area="Ghostlands",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="AFK usually after 11pm", officerNote="Reliable member, sometimes late", fullName="Venomfang" },
    { name="Stormcaller",  level=90, classFile="SHAMAN",      area="Silvermoon City",           rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Trial period", officerNote="Trial - DPS test passed", fullName="Stormcaller" },
}

local DEMO_CLUBS = {
    [1001] = {
        info = { clubId=1001, name="Midnight Mythic+ Club", clubType=1 },
        members = {
            { name="Karanex",     level=90, classFile="DEATHKNIGHT", area="Ghostlands",      afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Karanex",     clubId=1001, clubName="Midnight Mythic+ Club", role=1, dungeonScore=2680 },
            { name="Solaris",     level=90, classFile="PALADIN",     area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Solaris",     clubId=1001, clubName="Midnight Mythic+ Club", role=2, dungeonScore=2450 },
            { name="Vexara",      level=90, classFile="WARLOCK",     area="The Dead Scar",    afk=true,  dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Vexara",      clubId=1001, clubName="Midnight Mythic+ Club", role=4, dungeonScore=2210 },
            { name="Runethane",   level=90, classFile="MAGE",        area="Eversong Woods",   afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="M+ carry", fullName="Runethane",   clubId=1001, clubName="Midnight Mythic+ Club", role=3, dungeonScore=2890 },
            { name="Galebreaker", level=90, classFile="SHAMAN",      area="Sunstrider Isle",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Galebreaker", clubId=1001, clubName="Midnight Mythic+ Club", role=4, dungeonScore=1950 },
            { name="Thornspire",  level=90, classFile="HUNTER",      area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Thornspire",  clubId=1001, clubName="Midnight Mythic+ Club", role=4, dungeonScore=1720 },
            { name="Hexbolt",     level=90, classFile="DEMONHUNTER", area="The Dead Scar",    afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="Tank",     fullName="Hexbolt",     clubId=1001, clubName="Midnight Mythic+ Club", role=3, dungeonScore=2560 },
            { name="Coldweave",   level=90, classFile="MAGE",        area="Ghostlands",       afk=false, dnd=true,  isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Coldweave",   clubId=1001, clubName="Midnight Mythic+ Club", role=4, dungeonScore=1480 },
            { name="Ironpetal",   level=90, classFile="DRUID",       area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="Bear",     fullName="Ironpetal",   clubId=1001, clubName="Midnight Mythic+ Club", role=4, dungeonScore=2100 },
            { name="Swiftstrike", level=90, classFile="MONK",        area="Eversong Woods",   afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=true,  notes="",         fullName="Swiftstrike", clubId=1001, clubName="Midnight Mythic+ Club", role=4, dungeonScore=1870 },
        },
    },
    [1002] = {
        info = { clubId=1002, name="Realm Social", clubType=1 },
        members = {
            { name="Dawnseeker",  level=90, classFile="PRIEST",  area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",            fullName="Dawnseeker",  clubId=1002, clubName="Realm Social", role=1, dungeonScore=0 },
            { name="Iceveil",     level=90, classFile="MAGE",    area="Ghostlands",       afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",            fullName="Iceveil",     clubId=1002, clubName="Realm Social", role=3, dungeonScore=0 },
            { name="Blazefury",   level=90, classFile="WARRIOR", area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",            fullName="Blazefury",   clubId=1002, clubName="Realm Social", role=4, dungeonScore=0 },
            { name="Silksong",    level=90, classFile="ROGUE",   area="Eversong Woods",   afk=false, dnd=true,  isMobile=false, isRemoteChat=false, isSelf=false, notes="Busy raiding",fullName="Silksong",    clubId=1002, clubName="Realm Social", role=4, dungeonScore=0 },
            { name="Goldenleaf",  level=82, classFile="DRUID",   area="Quel'Thalas",      afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="Leveling",    fullName="Goldenleaf",  clubId=1002, clubName="Realm Social", role=4, dungeonScore=0 },
            { name="Mistwalker",  level=90, classFile="MONK",    area="The Dead Scar",    afk=true,  dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",            fullName="Mistwalker",  clubId=1002, clubName="Realm Social", role=4, dungeonScore=0 },
            { name="Stonehide",   level=90, classFile="PALADIN", area="Sunstrider Isle",  afk=false, dnd=false, isMobile=true,  isRemoteChat=false, isSelf=false, notes="Mobile",      fullName="Stonehide",   clubId=1002, clubName="Realm Social", role=4, dungeonScore=0 },
        },
    },
    [1003] = {
        info = { clubId=1003, name="Classic Raiders", clubType=1 },
        members = {
            { name="Ashvane",     level=90, classFile="WARRIOR", area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",        fullName="Ashvane",    clubId=1003, clubName="Classic Raiders", role=1, dungeonScore=0 },
            { name="Cindra",      level=90, classFile="PRIEST",  area="Eversong Woods",   afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="Holy",     fullName="Cindra",     clubId=1003, clubName="Classic Raiders", role=3, dungeonScore=0 },
            { name="Bronzewing",  level=90, classFile="EVOKER",  area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Bronzewing", clubId=1003, clubName="Classic Raiders", role=4, dungeonScore=0 },
            { name="Thornhelm",   level=90, classFile="PALADIN", area="Ghostlands",       afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",         fullName="Thornhelm",  clubId=1003, clubName="Classic Raiders", role=4, dungeonScore=0 },
            { name="Vexstone",    level=90, classFile="WARLOCK", area="The Dead Scar",    afk=false, dnd=true,  isMobile=false, isRemoteChat=false, isSelf=false, notes="Raiding",  fullName="Vexstone",   clubId=1003, clubName="Classic Raiders", role=4, dungeonScore=0 },
        },
    },
    [1004] = {
        info = { clubId=1004, name="BNet Gaming Group", clubType=0 },
        members = {
            -- In WoW
            { name="Valorshield",  level=90, classFile="PALADIN",     area="Silvermoon City",  afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",      fullName="Valorshield",  clubId=1004, clubName="BNet Gaming Group", role=1, dungeonScore=2340 },
            { name="Nightwhisper", level=90, classFile="ROGUE",       area="The Dead Scar",    afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",      fullName="Nightwhisper", clubId=1004, clubName="BNet Gaming Group", role=4, dungeonScore=1850 },
            { name="Emberdawn",    level=90, classFile="MAGE",        area="Eversong Woods",   afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",      fullName="Emberdawn",    clubId=1004, clubName="BNet Gaming Group", role=3, dungeonScore=2050 },
            { name="Frostbinder",  level=85, classFile="SHAMAN",      area="Quel'Thalas",      afk=false, dnd=false, isMobile=false, isRemoteChat=false, isSelf=false, notes="",      fullName="Frostbinder",  clubId=1004, clubName="BNet Gaming Group", role=4, dungeonScore=0 },
            -- On BNet App (not in WoW)
            { name="Tyler",        level=0,  classFile=nil,           area="",                 afk=false, dnd=false, isMobile=false, isRemoteChat=true,  isSelf=false, notes="",      fullName="Tyler",        clubId=1004, clubName="BNet Gaming Group", role=2, dungeonScore=0 },
            { name="Sarah",        level=0,  classFile=nil,           area="",                 afk=false, dnd=false, isMobile=true,  isRemoteChat=true,  isSelf=false, notes="",      fullName="Sarah",        clubId=1004, clubName="BNet Gaming Group", role=4, dungeonScore=0 },
            { name="Jake",         level=0,  classFile=nil,           area="",                 afk=true,  dnd=false, isMobile=false, isRemoteChat=true,  isSelf=false, notes="",      fullName="Jake",         clubId=1004, clubName="BNet Gaming Group", role=4, dungeonScore=0 },
        },
    },
}

---------------------------------------------------------------------------
-- SpecSwitch demo data (Druid - 4 specs, multiple loadouts)
---------------------------------------------------------------------------

local DEMO_SPEC_CACHE = {
    [1] = { id = 102, name = "Balance",      icon = "Interface\\Icons\\Spell_Nature_StarFall",       role = "DAMAGER" },
    [2] = { id = 103, name = "Feral",        icon = "Interface\\Icons\\Ability_Druid_CatForm",       role = "DAMAGER" },
    [3] = { id = 104, name = "Guardian",     icon = "Interface\\Icons\\Ability_Racial_BearForm",     role = "TANK" },
    [4] = { id = 105, name = "Restoration",  icon = "Interface\\Icons\\Spell_Nature_HealingTouch",   role = "HEALER" },
}

local DEMO_LOADOUT_CACHE = {
    [102] = {
        { configID = 9001, name = "ST Boomkin" },
        { configID = 9002, name = "AoE Boomkin" },
        { configID = 9003, name = "M+ Balance" },
    },
    [103] = {
        { configID = 9010, name = "Raid Feral" },
        { configID = 9011, name = "M+ Feral" },
    },
    [104] = {
        { configID = 9020, name = "Raid Tank" },
        { configID = 9021, name = "M+ Bear" },
        { configID = 9022, name = "Solo Bear" },
    },
    [105] = {
        { configID = 9030, name = "Raid Resto" },
        { configID = 9031, name = "M+ Resto" },
    },
}

local DEMO_SPEC_INDEX   = 3    -- Guardian is active
local DEMO_SPEC_ID      = 104
local DEMO_SPEC_NAME    = "Guardian"
local DEMO_SPEC_ICON    = "Interface\\Icons\\Ability_Racial_BearForm"
local DEMO_SPEC_ROLE    = "TANK"
local DEMO_LOOT_SPEC_ID = 0     -- Current Spec (Default)
local DEMO_LOADOUT_ID   = 9021  -- M+ Bear
local DEMO_LOADOUT_NAME = "M+ Bear"

---------------------------------------------------------------------------
-- Demo injection
---------------------------------------------------------------------------

local demoActive = false

local function InjectDemoData()
    local FB = ns.FriendsBroker
    local GB = ns.GuildBroker
    local CB = ns.CommunitiesBroker
    local SS = ns.SpecSwitch

    -- Friends
    FB.friendsCache = DEMO_FRIENDS
    FB.onlineCount = #DEMO_FRIENDS
    FB.totalCount = 58
    FB.dataobj.text = DDT:FormatLabel(ns.db.friends.labelFormat, FB.onlineCount, FB.totalCount)

    -- Guild
    GB.guildCache = DEMO_GUILD
    GB.onlineCount = #DEMO_GUILD
    GB.totalCount = DEMO_GUILD_TOTAL
    GB.guildName = DEMO_GUILD_NAME
    GB.dataobj.text = DDT:FormatLabel(ns.db.guild.labelFormat, GB.onlineCount, GB.totalCount, { guildname = DEMO_GUILD_NAME })

    -- Communities
    local communityOnline = 0
    for _, club in pairs(DEMO_CLUBS) do
        communityOnline = communityOnline + #club.members
    end
    CB.clubsCache = DEMO_CLUBS
    CB.totalOnline = communityOnline
    CB.dataobj.text = DDT:FormatLabel(ns.db.communities.labelFormat, communityOnline, communityOnline)

    -- SpecSwitch
    SS.specCache        = DEMO_SPEC_CACHE
    SS.loadoutCache     = DEMO_LOADOUT_CACHE
    SS.currentSpecIndex = DEMO_SPEC_INDEX
    SS.currentSpecID    = DEMO_SPEC_ID
    SS.currentSpecName  = DEMO_SPEC_NAME
    SS.currentSpecIcon  = DEMO_SPEC_ICON
    SS.currentRole      = DEMO_SPEC_ROLE
    SS.lootSpecID       = DEMO_LOOT_SPEC_ID
    SS.activeLoadoutID  = DEMO_LOADOUT_ID
    SS.activeLoadoutName = DEMO_LOADOUT_NAME

    local db = ns.db and ns.db.specswitch
    local template = db and db.labelTemplate or "<spec>"
    SS.dataobj.text = SS.ExpandLabel(template)
    SS.dataobj.icon = DEMO_SPEC_ICON
end

local function FreezeUpdates()
    -- Replace UpdateData with no-ops while demo is active
    ns.FriendsBroker.UpdateData    = function() end
    ns.GuildBroker.UpdateData      = function() end
    ns.CommunitiesBroker.UpdateData = function() end
    ns.SpecSwitch.UpdateData       = function() end
end

local originalFBUpdate, originalGBUpdate, originalCBUpdate, originalSSUpdate

local function EnableDemo()
    originalFBUpdate = ns.FriendsBroker.UpdateData
    originalGBUpdate = ns.GuildBroker.UpdateData
    originalCBUpdate = ns.CommunitiesBroker.UpdateData
    originalSSUpdate = ns.SpecSwitch.UpdateData
    FreezeUpdates()
    InjectDemoData()
    ns.SpecSwitch.demoMode = true
    demoActive = true
    DDT:Print("|cff00ff00Demo mode ON|r - fake data injected. /reload or /ddt demo to toggle.")
end

local function DisableDemo()
    -- Restore original UpdateData functions
    if originalFBUpdate then ns.FriendsBroker.UpdateData    = originalFBUpdate end
    if originalGBUpdate then ns.GuildBroker.UpdateData      = originalGBUpdate end
    if originalCBUpdate then ns.CommunitiesBroker.UpdateData = originalCBUpdate end
    if originalSSUpdate then ns.SpecSwitch.UpdateData       = originalSSUpdate end
    ns.SpecSwitch.demoMode = false
    -- Trigger real refresh
    ns.FriendsBroker:UpdateData()
    ns.GuildBroker:UpdateData()
    ns.CommunitiesBroker:UpdateData()
    ns.SpecSwitch:UpdateData()
    demoActive = false
    DDT:Print("|cffff4444Demo mode OFF|r - live data restored.")
end

---------------------------------------------------------------------------
-- Hook into addon load and slash command
---------------------------------------------------------------------------

local demoFrame = CreateFrame("Frame")
demoFrame:RegisterEvent("ADDON_LOADED")
demoFrame:SetScript("OnEvent", function(_, event, name)
    if name ~= addonName then return end
    -- Wait one frame so all brokers have run Init()
    C_Timer.After(0.5, function()
        EnableDemo()
    end)
end)

-- Extend /ddt to support "demo" argument
local existingSlash = SlashCmdList["DDT"]
SlashCmdList["DDT"] = function(msg)
    local arg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
    if arg == "demo" then
        if demoActive then
            DisableDemo()
        else
            EnableDemo()
        end
    elseif existingSlash then
        existingSlash(msg)
    end
end
