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
    -- WoW character friends — #Raid group
    { name="Arathos",     level=80, classFile="WARRIOR",     area="Dornogal",           connected=true,  afk=true,  dnd=false, notes="#Raid #Tank",       isBNet=false, fullName="Arathos" },
    { name="Sylvara",     level=80, classFile="PRIEST",      area="Hallowfall",         connected=true,  afk=false, dnd=false, notes="#Raid #Healer",     isBNet=false, fullName="Sylvara" },
    { name="Korvash",     level=80, classFile="DEATHKNIGHT", area="The Ringing Deeps",  connected=true,  afk=false, dnd=true,  notes="#Raid #Tank",       isBNet=false, fullName="Korvash" },
    { name="Mirela",      level=80, classFile="MAGE",        area="Azj-Kahet",          connected=true,  afk=false, dnd=false, notes="#Raid",             isBNet=false, fullName="Mirela" },
    { name="Thundrik",    level=80, classFile="SHAMAN",      area="Isle of Dorn",       connected=true,  afk=false, dnd=false, notes="#Raid #Healer",     isBNet=false, fullName="Thundrik" },
    { name="Vexholm",     level=80, classFile="ROGUE",       area="The Ringing Deeps",  connected=true,  afk=false, dnd=false, notes="#Raid",             isBNet=false, fullName="Vexholm" },
    { name="Dreadfang",   level=80, classFile="WARLOCK",     area="Nerub-ar Palace",    connected=true,  afk=false, dnd=true,  notes="#Raid",             isBNet=false, fullName="Dreadfang" },
    { name="Lunaspire",   level=80, classFile="DRUID",       area="Nerub-ar Palace",    connected=true,  afk=false, dnd=true,  notes="#Raid #Healer",     isBNet=false, fullName="Lunaspire" },
    { name="Ashveil",     level=80, classFile="HUNTER",      area="Dornogal",           connected=true,  afk=false, dnd=false, notes="#Raid",             isBNet=false, fullName="Ashveil" },
    { name="Stormcrest",  level=80, classFile="EVOKER",      area="Dornogal",           connected=true,  afk=false, dnd=false, notes="#Raid #Healer",     isBNet=false, fullName="Stormcrest" },
    -- WoW character friends — #Mythic+ group
    { name="Pelindra",    level=80, classFile="DRUID",       area="The Ringing Deeps",  connected=true,  afk=false, dnd=false, notes="#Mythic+",          isBNet=false, fullName="Pelindra" },
    { name="Kaelthorn",   level=80, classFile="PALADIN",     area="Isle of Dorn",       connected=true,  afk=false, dnd=false, notes="#Mythic+ #Tank",    isBNet=false, fullName="Kaelthorn" },
    { name="Swiftclaw",   level=80, classFile="MONK",        area="Hallowfall",         connected=true,  afk=false, dnd=false, notes="#Mythic+",          isBNet=false, fullName="Swiftclaw" },
    { name="Frostbloom",  level=80, classFile="MAGE",        area="Azj-Kahet",          connected=true,  afk=false, dnd=false, notes="#Mythic+",          isBNet=false, fullName="Frostbloom" },
    { name="Hexara",      level=80, classFile="DEMONHUNTER", area="Dornogal",           connected=true,  afk=false, dnd=false, notes="#Mythic+ #Tank",    isBNet=false, fullName="Hexara" },
    -- WoW character friends — #PvP group
    { name="Bladesurge",  level=80, classFile="WARRIOR",     area="Dornogal",           connected=true,  afk=false, dnd=false, notes="#PvP",              isBNet=false, fullName="Bladesurge" },
    { name="Curseweave",  level=80, classFile="WARLOCK",     area="Isle of Dorn",       connected=true,  afk=false, dnd=false, notes="#PvP",              isBNet=false, fullName="Curseweave" },
    { name="Spectral",    level=80, classFile="ROGUE",       area="Dornogal",           connected=true,  afk=false, dnd=false, notes="#PvP #Arena",       isBNet=false, fullName="Spectral" },
    { name="Ironcleave",  level=80, classFile="DEATHKNIGHT", area="The Ringing Deeps",  connected=true,  afk=false, dnd=false, notes="#PvP",              isBNet=false, fullName="Ironcleave" },
    -- WoW character friends — #Casual / no tag
    { name="Maplewood",   level=80, classFile="DRUID",       area="Hallowfall",         connected=true,  afk=false, dnd=false, notes="#Casual",           isBNet=false, fullName="Maplewood" },
    { name="Greymantle",  level=80, classFile="HUNTER",      area="Isle of Dorn",       connected=true,  afk=true,  dnd=false, notes="#Casual",           isBNet=false, fullName="Greymantle" },
    { name="Cinderveil",  level=80, classFile="PRIEST",      area="Azj-Kahet",          connected=true,  afk=false, dnd=false, notes="#Casual",           isBNet=false, fullName="Cinderveil" },
    { name="Bramblethatch",level=76, classFile="SHAMAN",     area="The Ringing Deeps",  connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Bramblethatch" },
    { name="Goldvein",    level=72, classFile="PALADIN",     area="Khaz Algar",         connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Goldvein" },
    { name="Thistlewick", level=65, classFile="MONK",        area="Isle of Dorn",       connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Thistlewick" },
    { name="Rivenmoor",   level=80, classFile="EVOKER",      area="Dornogal",           connected=true,  afk=false, dnd=false, notes="",                  isBNet=false, fullName="Rivenmoor" },
    -- BNet friends
    { name="Fenwick",     level=80, classFile="HUNTER",      area="Dornogal",           connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Fenwick-Kaelthas",    accountName="Fen#1482",   battleTag="Fen#1482",   realmName="Kaelthas",   gameAccountID=10001 },
    { name="Zyara",       level=80, classFile="WARLOCK",     area="The Ringing Deeps",  connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Zyara-Area 52",       accountName="Zy#2204",    battleTag="Zy#2204",    realmName="Area 52",    gameAccountID=10002 },
    { name="Torvald",     level=80, classFile="PALADIN",     area="Hallowfall",         connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Torvald-Illidan",     accountName="Torv#9911",  battleTag="Torv#9911",  realmName="Illidan",    gameAccountID=10003 },
    { name="Duskweave",   level=80, classFile="DRUID",       area="Dornogal",           connected=true,  afk=true,  dnd=false, notes="",                  isBNet=true, fullName="Duskweave-Stormrage", accountName="Dusk#3374",  battleTag="Dusk#3374",  realmName="Stormrage",  gameAccountID=10004 },
    { name="Nythara",     level=80, classFile="ROGUE",       area="Azj-Kahet",          connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Nythara-Proudmoore",  accountName="Nyth#7623",  battleTag="Nyth#7623",  realmName="Proudmoore", gameAccountID=10005 },
    { name="Valdris",     level=80, classFile="WARRIOR",     area="Dornogal",           connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Valdris-Thrall",      accountName="Val#5501",   battleTag="Val#5501",   realmName="Thrall",     gameAccountID=10006 },
    { name="Ashenmere",   level=80, classFile="MAGE",        area="Isle of Dorn",       connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Ashenmere-Frostmourne",accountName="Ash#8812",  battleTag="Ash#8812",   realmName="Frostmourne",gameAccountID=10007 },
    { name="Prixanna",    level=80, classFile="PRIEST",      area="The Ringing Deeps",  connected=true,  afk=false, dnd=true,  notes="",                  isBNet=true, fullName="Prixanna-Saurfang",   accountName="Prix#3390",  battleTag="Prix#3390",  realmName="Saurfang",   gameAccountID=10008 },
    { name="Gloomhaven",  level=80, classFile="DEATHKNIGHT", area="Hallowfall",         connected=true,  afk=false, dnd=false, notes="",                  isBNet=true, fullName="Gloomhaven-Barth'ilas",accountName="Gloom#6614",battleTag="Gloom#6614", realmName="Barth'ilas", gameAccountID=10009 },
    { name="Coppercog",   level=80, classFile="SHAMAN",      area="Azj-Kahet",          connected=true,  afk=true,  dnd=false, notes="",                  isBNet=true, fullName="Coppercog-Khaz Modan", accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Khaz Modan", gameAccountID=10010 },
    -- Multiple friends from same battleTag (Cop#2277)
    { name="Ironrust",    level=80, classFile="WARRIOR",     area="Dornogal",           connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Ironrust-Khaz Modan",    accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Khaz Modan", gameAccountID=10011 },
    { name="Crystalpeak", level=75, classFile="MAGE",        area="Isle of Dorn",       connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Crystalpeak-Area 52",     accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Area 52",    gameAccountID=10012 },
    { name="Swiftmend",   level=78, classFile="DRUID",       area="Hallowfall",         connected=true,  afk=true,  dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Swiftmend-Stormrage",    accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Stormrage",  gameAccountID=10013 },
    { name="Shadowbolt",  level=72, classFile="WARLOCK",     area="The Ringing Deeps",  connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Shadowbolt-Illidan",     accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Illidan",    gameAccountID=10014 },
    { name="Frostmace",   level=80, classFile="PALADIN",     area="Dornogal",           connected=true,  afk=false, dnd=true,  notes="#Golddigger",                  isBNet=true, fullName="Frostmace-Proudmoore",   accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Proudmoore", gameAccountID=10015 },
    { name="Voidstrike",  level=76, classFile="ROGUE",       area="Azj-Kahet",          connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Voidstrike-Thrall",      accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Thrall",     gameAccountID=10016 },
    { name="Duskfeather", level=74, classFile="HUNTER",      area="Hallowfall",         connected=true,  afk=false, dnd=false, notes="#Golddigger",                  isBNet=true, fullName="Duskfeather-Frostmourne",accountName="Cop#2277",  battleTag="Cop#2277",   realmName="Frostmourne",gameAccountID=10017 },
}

local DEMO_GUILD_NAME = "Eternal Vigil"
local DEMO_GUILD_TOTAL = 178

local DEMO_GUILD = {
    -- Guild Master
    { name="Sarveth",      level=80, classFile="WARLOCK",     area="Dornogal",           rank="Guild Master", rankIndex=0, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Sarveth" },
    -- Officers
    { name="Lyrandel",     level=80, classFile="DRUID",       area="Hallowfall",         rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Raid Lead",       fullName="Lyrandel" },
    { name="Kharsus",      level=80, classFile="DEATHKNIGHT", area="The Ringing Deeps",  rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Main Tank",       fullName="Kharsus" },
    { name="Embervane",    level=80, classFile="PRIEST",      area="Dornogal",           rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Healing Lead",    fullName="Embervane" },
    { name="Stonebark",    level=80, classFile="WARRIOR",     area="Azj-Kahet",          rank="Officer",      rankIndex=1, connected=true,  isMobile=false, status=2, afk=false, dnd=true,  notes="",                  officerNote="M+ Lead",         fullName="Stonebark" },
    -- Veterans
    { name="Brightmoon",   level=80, classFile="PALADIN",     area="Dornogal",           rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="For the Light!",    officerNote="",                fullName="Brightmoon" },
    { name="Zephran",      level=80, classFile="MONK",        area="Azj-Kahet",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Zephran" },
    { name="Anella",       level=80, classFile="PRIEST",      area="Isle of Dorn",       rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",                  officerNote="Backup Healer",   fullName="Anella" },
    { name="Flamecrest",   level=80, classFile="MAGE",        area="Hallowfall",         rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Flamecrest" },
    { name="Wolfthorn",    level=80, classFile="HUNTER",      area="The Ringing Deeps",  rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Sniper main",       officerNote="",                fullName="Wolfthorn" },
    { name="Shadowmend",   level=80, classFile="PRIEST",      area="Dornogal",           rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Shadowmend" },
    { name="Galefrost",    level=80, classFile="EVOKER",      area="Dornogal",           rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Aug main",        fullName="Galefrost" },
    { name="Ironmantle",   level=80, classFile="WARRIOR",     area="Isle of Dorn",       rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ironmantle" },
    { name="Cinderpaw",    level=80, classFile="DRUID",       area="Azj-Kahet",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Cinderpaw" },
    -- Members
    { name="Duskwarden",   level=80, classFile="HUNTER",      area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Duskwarden" },
    { name="Ironveil",     level=80, classFile="WARRIOR",     area="The Ringing Deeps",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=2, afk=false, dnd=true,  notes="",                  officerNote="",                fullName="Ironveil" },
    { name="Crystalsong",  level=80, classFile="MAGE",        area="Hallowfall",         rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Crystalsong" },
    { name="Wavestrider",  level=80, classFile="SHAMAN",      area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Wavestrider" },
    { name="Dreadspire",   level=80, classFile="WARLOCK",     area="Azj-Kahet",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Dreadspire" },
    { name="Petalstorm",   level=80, classFile="DRUID",       area="Isle of Dorn",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Petalstorm" },
    { name="Frostbane",    level=80, classFile="DEATHKNIGHT", area="The Ringing Deeps",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",                  officerNote="",                fullName="Frostbane" },
    { name="Swiftarrow",   level=80, classFile="HUNTER",      area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Swiftarrow" },
    { name="Ashveil",      level=80, classFile="ROGUE",       area="Azj-Kahet",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ashveil" },
    { name="Gloomthorn",   level=80, classFile="DEMONHUNTER", area="Hallowfall",         rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Gloomthorn" },
    { name="Lunaveil",     level=80, classFile="MONK",        area="Isle of Dorn",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Lunaveil" },
    { name="Stoneveil",    level=80, classFile="PALADIN",     area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Stoneveil" },
    { name="Emberfall",    level=80, classFile="EVOKER",      area="The Ringing Deeps",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Emberfall" },
    { name="Rivenshard",   level=80, classFile="WARRIOR",     area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=true,  status=0, afk=false, dnd=false, notes="Mobile",            officerNote="",                fullName="Rivenshard" },
    { name="Moonwhisper",  level=80, classFile="DRUID",       area="Hallowfall",         rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Moonwhisper" },
    { name="Blazemantle",  level=80, classFile="SHAMAN",      area="Azj-Kahet",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Blazemantle" },
    { name="Thornwick",    level=80, classFile="ROGUE",       area="The Ringing Deeps",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Thornwick" },
    { name="Coldvein",     level=80, classFile="MAGE",        area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Coldvein" },
    { name="Dawnbreaker",  level=80, classFile="PALADIN",     area="Isle of Dorn",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Dawnbreaker" },
    { name="Runicbrand",   level=80, classFile="DEATHKNIGHT", area="Azj-Kahet",          rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Runicbrand" },
    { name="Siltbreeze",   level=80, classFile="PRIEST",      area="Hallowfall",         rank="Member",       rankIndex=3, connected=true,  isMobile=true,  status=0, afk=false, dnd=false, notes="Mobile",            officerNote="",                fullName="Siltbreeze" },
    { name="Ashmantle",    level=80, classFile="WARLOCK",     area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ashmantle" },
    -- Recruits (some leveling, some max)
    { name="Emberveil",    level=80, classFile="DEMONHUNTER", area="Azj-Kahet",          rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="New member!",       officerNote="",                fullName="Emberveil" },
    { name="Nightblossom", level=78, classFile="DRUID",       area="Isle of Dorn",       rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Leveling",          officerNote="",                fullName="Nightblossom" },
    { name="Sparkpetal",   level=75, classFile="MONK",        area="Khaz Algar",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Sparkpetal" },
    { name="Ravenquill",   level=72, classFile="HUNTER",      area="Isle of Dorn",       rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Ravenquill" },
    { name="Hailcrest",    level=68, classFile="PALADIN",     area="Khaz Algar",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Hailcrest" },
    { name="Cindersoot",   level=65, classFile="ROGUE",       area="Khaz Algar",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Cindersoot" },
    { name="Mirefoot",     level=61, classFile="SHAMAN",      area="Khaz Algar",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Mirefoot" },
    { name="Pebblestrike", level=55, classFile="WARRIOR",     area="Khaz Algar",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="",                fullName="Pebblestrike" },
    { name="Dewcatcher",   level=80, classFile="EVOKER",      area="Dornogal",           rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Trial raider",      officerNote="Trial - 2 weeks", fullName="Dewcatcher" },
    { name="Voidspire",    level=80, classFile="WARLOCK",     area="Azj-Kahet",          rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="",                  officerNote="Trial - 1 week",  fullName="Voidspire" },
    { name="Galestone",    level=80, classFile="MAGE",        area="Dornogal",           rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=1, afk=true,  dnd=false, notes="",                  officerNote="",                fullName="Galestone" },
    { name="Thornmantle",  level=80, classFile="PRIEST",      area="Hallowfall",         rank="Recruit",      rankIndex=4, connected=true,  isMobile=true,  status=0, afk=false, dnd=false, notes="Mobile",            officerNote="",                fullName="Thornmantle" },
    -- Guildies with both public and officer notes
    { name="Firebrand",    level=80, classFile="MAGE",        area="Dornogal",           rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="PvP enthusiast",      officerNote="Strong DPS, needs gear",  fullName="Firebrand" },
    { name="Shieldwall",   level=80, classFile="WARRIOR",     area="Azj-Kahet",          rank="Veteran",      rankIndex=2, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Always helps new players", officerNote="Potential raid officer", fullName="Shieldwall" },
    { name="Starwhisper",  level=80, classFile="PRIEST",      area="Isle of Dorn",       rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Healer main, funny person", officerNote="Consider for healing lead", fullName="Starwhisper" },
    { name="Venomfang",    level=80, classFile="ROGUE",       area="The Ringing Deeps",  rank="Member",       rankIndex=3, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="AFK usually after 11pm", officerNote="Reliable member, sometimes late", fullName="Venomfang" },
    { name="Stormcaller",  level=80, classFile="SHAMAN",      area="Dornogal",           rank="Recruit",      rankIndex=4, connected=true,  isMobile=false, status=0, afk=false, dnd=false, notes="Trial period", officerNote="Trial - DPS test passed", fullName="Stormcaller" },
}

local DEMO_CLUBS = {
    [1001] = {
        info = { clubId=1001, name="TWW Mythic+ Club", clubType=1 },
        members = {
            { name="Karanex",     level=80, classFile="DEATHKNIGHT", area="The Ringing Deeps", afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Karanex",     clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Solaris",     level=80, classFile="PALADIN",     area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Solaris",     clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Vexara",      level=80, classFile="WARLOCK",     area="Azj-Kahet",          afk=true,  dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Vexara",      clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Runethane",   level=80, classFile="MAGE",        area="Hallowfall",         afk=false, dnd=false, isMobile=false, isSelf=false, notes="M+ carry",    fullName="Runethane",   clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Galebreaker", level=80, classFile="SHAMAN",      area="Isle of Dorn",       afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Galebreaker", clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Thornspire",  level=80, classFile="HUNTER",      area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Thornspire",  clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Hexbolt",     level=80, classFile="DEMONHUNTER", area="Azj-Kahet",          afk=false, dnd=false, isMobile=false, isSelf=false, notes="Tank",        fullName="Hexbolt",     clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Coldweave",   level=80, classFile="MAGE",        area="The Ringing Deeps",  afk=false, dnd=true,  isMobile=false, isSelf=false, notes="",            fullName="Coldweave",   clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Ironpetal",   level=80, classFile="DRUID",       area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="Bear",        fullName="Ironpetal",   clubId=1001, clubName="TWW Mythic+ Club" },
            { name="Swiftstrike", level=80, classFile="MONK",        area="Hallowfall",         afk=false, dnd=false, isMobile=false, isSelf=true,  notes="",            fullName="Swiftstrike", clubId=1001, clubName="TWW Mythic+ Club" },
        },
    },
    [1002] = {
        info = { clubId=1002, name="Realm Social", clubType=1 },
        members = {
            { name="Dawnseeker",  level=80, classFile="PRIEST",      area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Dawnseeker",  clubId=1002, clubName="Realm Social" },
            { name="Iceveil",     level=80, classFile="MAGE",        area="The Ringing Deeps",  afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Iceveil",     clubId=1002, clubName="Realm Social" },
            { name="Blazefury",   level=80, classFile="WARRIOR",     area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Blazefury",   clubId=1002, clubName="Realm Social" },
            { name="Silksong",    level=80, classFile="ROGUE",       area="Hallowfall",         afk=false, dnd=true,  isMobile=false, isSelf=false, notes="Busy raiding",fullName="Silksong",    clubId=1002, clubName="Realm Social" },
            { name="Goldenleaf",  level=72, classFile="DRUID",       area="Khaz Algar",         afk=false, dnd=false, isMobile=false, isSelf=false, notes="Leveling",    fullName="Goldenleaf",  clubId=1002, clubName="Realm Social" },
            { name="Mistwalker",  level=80, classFile="MONK",        area="Azj-Kahet",          afk=true,  dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Mistwalker",  clubId=1002, clubName="Realm Social" },
            { name="Stonehide",   level=80, classFile="PALADIN",     area="Isle of Dorn",       afk=false, dnd=false, isMobile=true,  isSelf=false, notes="Mobile",      fullName="Stonehide",   clubId=1002, clubName="Realm Social" },
        },
    },
    [1003] = {
        info = { clubId=1003, name="Classic Raiders", clubType=1 },
        members = {
            { name="Ashvane",     level=80, classFile="WARRIOR",     area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Ashvane",     clubId=1003, clubName="Classic Raiders" },
            { name="Cindra",      level=80, classFile="PRIEST",      area="Hallowfall",         afk=false, dnd=false, isMobile=false, isSelf=false, notes="Holy",         fullName="Cindra",      clubId=1003, clubName="Classic Raiders" },
            { name="Bronzewing",  level=80, classFile="EVOKER",      area="Dornogal",           afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Bronzewing",  clubId=1003, clubName="Classic Raiders" },
            { name="Thornhelm",   level=80, classFile="PALADIN",     area="The Ringing Deeps",  afk=false, dnd=false, isMobile=false, isSelf=false, notes="",            fullName="Thornhelm",   clubId=1003, clubName="Classic Raiders" },
            { name="Vexstone",    level=80, classFile="WARLOCK",     area="Azj-Kahet",          afk=false, dnd=true,  isMobile=false, isSelf=false, notes="Raiding",     fullName="Vexstone",    clubId=1003, clubName="Classic Raiders" },
        },
    },
}

---------------------------------------------------------------------------
-- Demo injection
---------------------------------------------------------------------------

local demoActive = false

local function InjectDemoData()
    local FB = ns.FriendsBroker
    local GB = ns.GuildBroker
    local CB = ns.CommunitiesBroker

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
end

local function FreezeUpdates()
    -- Replace UpdateData with no-ops while demo is active
    ns.FriendsBroker.UpdateData = function() end
    ns.GuildBroker.UpdateData   = function() end
    ns.CommunitiesBroker.UpdateData = function() end
end

local originalFBUpdate, originalGBUpdate, originalCBUpdate

local function EnableDemo()
    originalFBUpdate = ns.FriendsBroker.UpdateData
    originalGBUpdate = ns.GuildBroker.UpdateData
    originalCBUpdate = ns.CommunitiesBroker.UpdateData
    FreezeUpdates()
    InjectDemoData()
    demoActive = true
    DDT:Print("|cff00ff00Demo mode ON|r — fake data injected. /reload or /ddt demo to toggle.")
end

local function DisableDemo()
    -- Restore original UpdateData functions
    if originalFBUpdate then ns.FriendsBroker.UpdateData   = originalFBUpdate end
    if originalGBUpdate then ns.GuildBroker.UpdateData     = originalGBUpdate end
    if originalCBUpdate then ns.CommunitiesBroker.UpdateData = originalCBUpdate end
    -- Trigger real refresh
    ns.FriendsBroker:UpdateData()
    ns.GuildBroker:UpdateData()
    ns.CommunitiesBroker:UpdateData()
    demoActive = false
    DDT:Print("|cffff4444Demo mode OFF|r — live data restored.")
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
