local _, STEP = ...

local SoundRegistry = {}
STEP.SoundRegistry = SoundRegistry

local WA_PATH = "Interface\\AddOns\\WeakAuras\\Media\\Sounds\\"
local WA_POWER_AURAS_PATH = "Interface\\AddOns\\WeakAuras\\PowerAurasMedia\\Sounds\\"

local sounds = {
    { key = "none", labelKey = "OPTION_SOUND_NONE" },
    { key = "decursive_affliction", label = "Decursive: Affliction", file = "Interface\\AddOns\\Decursive\\Sounds\\AfflictionAlert.ogg", decursive = true, fallbackKit = "RAID_WARNING" },
    { key = "raid", labelKey = "OPTION_SOUND_RAID", kit = "RAID_WARNING", fallback = 895 },
    { key = "ready", labelKey = "OPTION_SOUND_READY", kit = "READY_CHECK", fallback = 896 },
    { key = "decursive_deadly", label = "Decursive: Deadly", file = "Interface\\AddOns\\Decursive\\Sounds\\G_NecropolisWound-fast.ogg", decursive = true, fallbackKit = "RAID_WARNING" },
    { key = "bell", labelKey = "OPTION_SOUND_BELL", file = "Sound\\Doodad\\BellTollAlliance.ogg", fallbackKit = "IG_MAINMENU_OPTION_CHECKBOX_ON" },
    { key = "wa_heartbeat_single", label = "WA: Heartbeat Single", file = WA_PATH .. "HeartbeatSingle.ogg", weakAuras = true },
    { key = "wa_batman_punch", label = "WA: Batman Punch", file = WA_PATH .. "BatmanPunch.ogg", weakAuras = true },
    { key = "wa_bike_horn", label = "WA: Bike Horn", file = WA_PATH .. "BikeHorn.ogg", weakAuras = true },
    { key = "wa_boxing_arena_gong", label = "WA: Boxing Arena Gong", file = WA_PATH .. "BoxingArenaSound.ogg", weakAuras = true },
    { key = "wa_bleat", label = "WA: Bleat", file = WA_PATH .. "Bleat.ogg", weakAuras = true },
    { key = "wa_cartoon_hop", label = "WA: Cartoon Hop", file = WA_PATH .. "CartoonHop.ogg", weakAuras = true },
    { key = "wa_cat_meow", label = "WA: Cat Meow", file = WA_PATH .. "CatMeow2.ogg", weakAuras = true },
    { key = "wa_kitten_meow", label = "WA: Kitten Meow", file = WA_PATH .. "KittenMeow.ogg", weakAuras = true },
    { key = "wa_robot_blip", label = "WA: Robot Blip", file = WA_PATH .. "RobotBlip.ogg", weakAuras = true },
    { key = "wa_sharp_punch", label = "WA: Sharp Punch", file = WA_PATH .. "SharpPunch.ogg", weakAuras = true },
    { key = "wa_water_drop", label = "WA: Water Drop", file = WA_PATH .. "WaterDrop.ogg", weakAuras = true },
    { key = "wa_air_horn", label = "WA: Air Horn", file = WA_PATH .. "AirHorn.ogg", weakAuras = true },
    { key = "wa_applause", label = "WA: Applause", file = WA_PATH .. "Applause.ogg", weakAuras = true },
    { key = "wa_banana_peel_slip", label = "WA: Banana Peel Slip", file = WA_PATH .. "BananaPeelSlip.ogg", weakAuras = true },
    { key = "wa_blast", label = "WA: Blast", file = WA_PATH .. "Blast.ogg", weakAuras = true },
    { key = "wa_cartoon_voice_baritone", label = "WA: Cartoon Voice Baritone", file = WA_PATH .. "CartoonVoiceBaritone.ogg", weakAuras = true },
    { key = "wa_cartoon_walking", label = "WA: Cartoon Walking", file = WA_PATH .. "CartoonWalking.ogg", weakAuras = true },
    { key = "wa_cow_mooing", label = "WA: Cow Mooing", file = WA_PATH .. "CowMooing.ogg", weakAuras = true },
    { key = "wa_ringing_phone", label = "WA: Ringing Phone", file = WA_PATH .. "RingingPhone.ogg", weakAuras = true },
    { key = "wa_roaring_lion", label = "WA: Roaring Lion", file = WA_PATH .. "RoaringLion.ogg", weakAuras = true },
    { key = "wa_shotgun", label = "WA: Shotgun", file = WA_PATH .. "Shotgun.ogg", weakAuras = true },
    { key = "wa_squish_fart", label = "WA: Squish Fart", file = WA_PATH .. "SquishFart.ogg", weakAuras = true },
    { key = "wa_temple_bell", label = "WA: Temple Bell", file = WA_PATH .. "TempleBellHuge.ogg", weakAuras = true },
    { key = "wa_torch", label = "WA: Torch", file = WA_PATH .. "Torch.ogg", weakAuras = true },
    { key = "wa_warning_siren", label = "WA: Warning Siren", file = WA_PATH .. "WarningSiren.ogg", weakAuras = true },
    { key = "wa_lich_king_apocalypse", label = "WA: Lich King Apocalypse", kit = 554003, weakAuras = true },
    { key = "wa_sheep_blerping", label = "WA: Sheep Blerping", file = WA_PATH .. "SheepBleat.ogg", weakAuras = true },
    { key = "wa_rooster_chicken_call", label = "WA: Rooster Chicken Call", file = WA_PATH .. "RoosterChickenCalls.ogg", weakAuras = true },
    { key = "wa_goat_bleeting", label = "WA: Goat Bleeting", file = WA_PATH .. "GoatBleating.ogg", weakAuras = true },
    { key = "wa_acoustic_guitar", label = "WA: Acoustic Guitar", file = WA_PATH .. "AcousticGuitar.ogg", weakAuras = true },
    { key = "wa_synth_chord", label = "WA: Synth Chord", file = WA_PATH .. "SynthChord.ogg", weakAuras = true },
    { key = "wa_chicken_alarm", label = "WA: Chicken Alarm", file = WA_PATH .. "ChickenAlarm.ogg", weakAuras = true },
    { key = "wa_xylophone", label = "WA: Xylophone", file = WA_PATH .. "Xylophone.ogg", weakAuras = true },
    { key = "wa_drums", label = "WA: Drums", file = WA_PATH .. "Drums.ogg", weakAuras = true },
    { key = "wa_tada_fanfare", label = "WA: Tada Fanfare", file = WA_PATH .. "TadaFanfare.ogg", weakAuras = true },
    { key = "wa_squeaky_toy_short", label = "WA: Squeaky Toy Short", file = WA_PATH .. "SqueakyToyShort.ogg", weakAuras = true },
    { key = "wa_error_beep", label = "WA: Error Beep", file = WA_PATH .. "ErrorBeep.ogg", weakAuras = true },
    { key = "wa_oh_no", label = "WA: Oh No", file = WA_PATH .. "OhNo.ogg", weakAuras = true },
    { key = "wa_double_whoosh", label = "WA: Double Whoosh", file = WA_PATH .. "DoubleWhoosh.ogg", weakAuras = true },
    { key = "wa_brass", label = "WA: Brass", file = WA_PATH .. "Brass.mp3", weakAuras = true },
    { key = "wa_glass", label = "WA: Glass", file = WA_PATH .. "Glass.mp3", weakAuras = true },
    { key = "wa_voice_adds", label = "WA: Voice: Adds", file = WA_PATH .. "Adds.ogg", weakAuras = true },
    { key = "wa_voice_boss", label = "WA: Voice: Boss", file = WA_PATH .. "Boss.ogg", weakAuras = true },
    { key = "wa_voice_circle", label = "WA: Voice: Circle", file = WA_PATH .. "Circle.ogg", weakAuras = true },
    { key = "wa_voice_cross", label = "WA: Voice: Cross", file = WA_PATH .. "Cross.ogg", weakAuras = true },
    { key = "wa_voice_diamond", label = "WA: Voice: Diamond", file = WA_PATH .. "Diamond.ogg", weakAuras = true },
    { key = "wa_voice_don_t_release", label = "WA: Voice: Don't Release", file = WA_PATH .. "DontRelease.ogg", weakAuras = true },
    { key = "wa_voice_empowered", label = "WA: Voice: Empowered", file = WA_PATH .. "Empowered.ogg", weakAuras = true },
    { key = "wa_voice_focus", label = "WA: Voice: Focus", file = WA_PATH .. "Focus.ogg", weakAuras = true },
    { key = "wa_voice_idiot", label = "WA: Voice: Idiot", file = WA_PATH .. "Idiot.ogg", weakAuras = true },
    { key = "wa_voice_left", label = "WA: Voice: Left", file = WA_PATH .. "Left.ogg", weakAuras = true },
    { key = "wa_voice_moon", label = "WA: Voice: Moon", file = WA_PATH .. "Moon.ogg", weakAuras = true },
    { key = "wa_voice_next", label = "WA: Voice: Next", file = WA_PATH .. "Next.ogg", weakAuras = true },
    { key = "wa_voice_portal", label = "WA: Voice: Portal", file = WA_PATH .. "Portal.ogg", weakAuras = true },
    { key = "wa_voice_protected", label = "WA: Voice: Protected", file = WA_PATH .. "Protected.ogg", weakAuras = true },
    { key = "wa_voice_release", label = "WA: Voice: Release", file = WA_PATH .. "Release.ogg", weakAuras = true },
    { key = "wa_voice_right", label = "WA: Voice: Right", file = WA_PATH .. "Right.ogg", weakAuras = true },
    { key = "wa_voice_run_away", label = "WA: Voice: Run Away", file = WA_PATH .. "RunAway.ogg", weakAuras = true },
    { key = "wa_voice_skull", label = "WA: Voice: Skull", file = WA_PATH .. "Skull.ogg", weakAuras = true },
    { key = "wa_voice_spread", label = "WA: Voice: Spread", file = WA_PATH .. "Spread.ogg", weakAuras = true },
    { key = "wa_voice_square", label = "WA: Voice: Square", file = WA_PATH .. "Square.ogg", weakAuras = true },
    { key = "wa_voice_stack", label = "WA: Voice: Stack", file = WA_PATH .. "Stack.ogg", weakAuras = true },
    { key = "wa_voice_star", label = "WA: Voice: Star", file = WA_PATH .. "Star.ogg", weakAuras = true },
    { key = "wa_voice_switch", label = "WA: Voice: Switch", file = WA_PATH .. "Switch.ogg", weakAuras = true },
    { key = "wa_voice_taunt", label = "WA: Voice: Taunt", file = WA_PATH .. "Taunt.ogg", weakAuras = true },
    { key = "wa_voice_triangle", label = "WA: Voice: Triangle", file = WA_PATH .. "Triangle.ogg", weakAuras = true },
    { key = "wa_pa_aggro", label = "WA: Aggro", file = WA_POWER_AURAS_PATH .. "aggro.ogg", weakAuras = true },
    { key = "wa_pa_arrow_swoosh", label = "WA: Arrow Swoosh", file = WA_POWER_AURAS_PATH .. "Arrow_swoosh.ogg", weakAuras = true },
    { key = "wa_pa_bam", label = "WA: Bam", file = WA_POWER_AURAS_PATH .. "bam.ogg", weakAuras = true },
    { key = "wa_pa_polar_bear", label = "WA: Polar Bear", file = WA_POWER_AURAS_PATH .. "bear_polar.ogg", weakAuras = true },
    { key = "wa_pa_big_kiss", label = "WA: Big Kiss", file = WA_POWER_AURAS_PATH .. "bigkiss.ogg", weakAuras = true },
    { key = "wa_pa_bite", label = "WA: Bite", file = WA_POWER_AURAS_PATH .. "BITE.ogg", weakAuras = true },
    { key = "wa_pa_burp", label = "WA: Burp", file = WA_POWER_AURAS_PATH .. "burp4.ogg", weakAuras = true },
    { key = "wa_pa_cat", label = "WA: Cat", file = WA_POWER_AURAS_PATH .. "cat2.ogg", weakAuras = true },
    { key = "wa_pa_chant_major_2nd", label = "WA: Chant Major 2nd", file = WA_POWER_AURAS_PATH .. "chant2.ogg", weakAuras = true },
    { key = "wa_pa_chant_minor_3rd", label = "WA: Chant Minor 3rd", file = WA_POWER_AURAS_PATH .. "chant4.ogg", weakAuras = true },
    { key = "wa_pa_chimes", label = "WA: Chimes", file = WA_POWER_AURAS_PATH .. "chimes.ogg", weakAuras = true },
    { key = "wa_pa_cookie_monster", label = "WA: Cookie Monster", file = WA_POWER_AURAS_PATH .. "cookie.ogg", weakAuras = true },
    { key = "wa_pa_electrical_spark", label = "WA: Electrical Spark", file = WA_POWER_AURAS_PATH .. "ESPARK1.ogg", weakAuras = true },
    { key = "wa_pa_fireball", label = "WA: Fireball", file = WA_POWER_AURAS_PATH .. "Fireball.ogg", weakAuras = true },
    { key = "wa_pa_gasp", label = "WA: Gasp", file = WA_POWER_AURAS_PATH .. "Gasp.ogg", weakAuras = true },
    { key = "wa_pa_heartbeat", label = "WA: Heartbeat", file = WA_POWER_AURAS_PATH .. "heartbeat.ogg", weakAuras = true },
    { key = "wa_pa_hiccup", label = "WA: Hiccup", file = WA_POWER_AURAS_PATH .. "hic3.ogg", weakAuras = true },
    { key = "wa_pa_huh", label = "WA: Huh?", file = WA_POWER_AURAS_PATH .. "huh_1.ogg", weakAuras = true },
    { key = "wa_pa_hurricane", label = "WA: Hurricane", file = WA_POWER_AURAS_PATH .. "hurricane.ogg", weakAuras = true },
    { key = "wa_pa_hyena", label = "WA: Hyena", file = WA_POWER_AURAS_PATH .. "hyena.ogg", weakAuras = true },
    { key = "wa_pa_kaching", label = "WA: Kaching", file = WA_POWER_AURAS_PATH .. "kaching.ogg", weakAuras = true },
    { key = "wa_pa_moan", label = "WA: Moan", file = WA_POWER_AURAS_PATH .. "moan.ogg", weakAuras = true },
    { key = "wa_pa_panther", label = "WA: Panther", file = WA_POWER_AURAS_PATH .. "panther1.ogg", weakAuras = true },
    { key = "wa_pa_phone", label = "WA: Phone", file = WA_POWER_AURAS_PATH .. "phone.ogg", weakAuras = true },
    { key = "wa_pa_punch", label = "WA: Punch", file = WA_POWER_AURAS_PATH .. "PUNCH.ogg", weakAuras = true },
    { key = "wa_pa_rain", label = "WA: Rain", file = WA_POWER_AURAS_PATH .. "rainroof.ogg", weakAuras = true },
    { key = "wa_pa_rocket", label = "WA: Rocket", file = WA_POWER_AURAS_PATH .. "rocket.ogg", weakAuras = true },
    { key = "wa_pa_ship_s_whistle", label = "WA: Ship's Whistle", file = WA_POWER_AURAS_PATH .. "shipswhistle.ogg", weakAuras = true },
    { key = "wa_pa_gunshot", label = "WA: Gunshot", file = WA_POWER_AURAS_PATH .. "shot.ogg", weakAuras = true },
    { key = "wa_pa_snake_attack", label = "WA: Snake Attack", file = WA_POWER_AURAS_PATH .. "snakeatt.ogg", weakAuras = true },
    { key = "wa_pa_sneeze", label = "WA: Sneeze", file = WA_POWER_AURAS_PATH .. "sneeze.ogg", weakAuras = true },
    { key = "wa_pa_sonar", label = "WA: Sonar", file = WA_POWER_AURAS_PATH .. "sonar.ogg", weakAuras = true },
    { key = "wa_pa_splash", label = "WA: Splash", file = WA_POWER_AURAS_PATH .. "splash.ogg", weakAuras = true },
    { key = "wa_pa_squeaky_toy", label = "WA: Squeaky Toy", file = WA_POWER_AURAS_PATH .. "Squeakypig.ogg", weakAuras = true },
    { key = "wa_pa_sword_ring", label = "WA: Sword Ring", file = WA_POWER_AURAS_PATH .. "swordecho.ogg", weakAuras = true },
    { key = "wa_pa_throwing_knife", label = "WA: Throwing Knife", file = WA_POWER_AURAS_PATH .. "throwknife.ogg", weakAuras = true },
    { key = "wa_pa_thunder", label = "WA: Thunder", file = WA_POWER_AURAS_PATH .. "thunder.ogg", weakAuras = true },
    { key = "wa_pa_wicked_male_laugh", label = "WA: Wicked Male Laugh", file = WA_POWER_AURAS_PATH .. "wickedmalelaugh1.ogg", weakAuras = true },
    { key = "wa_pa_wilhelm_scream", label = "WA: Wilhelm Scream", file = WA_POWER_AURAS_PATH .. "wilhelm.ogg", weakAuras = true },
    { key = "wa_pa_wicked_female_laugh", label = "WA: Wicked Female Laugh", file = WA_POWER_AURAS_PATH .. "wlaugh.ogg", weakAuras = true },
    { key = "wa_pa_wolf_howl", label = "WA: Wolf Howl", file = WA_POWER_AURAS_PATH .. "wolf5.ogg", weakAuras = true },
    { key = "wa_pa_yeehaw", label = "WA: Yeehaw", file = WA_POWER_AURAS_PATH .. "yeehaw.ogg", weakAuras = true },
}

local aliases = {
    wa_heartbeat = "wa_heartbeat_single",
    wa_tada = "wa_tada_fanfare",
}

local byKey = {}
for index = 1, #sounds do
    byKey[sounds[index].key] = sounds[index]
end

local function HasAddon(addonName)
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        return C_AddOns.GetAddOnInfo(addonName) ~= nil
    end
    if type(GetAddOnInfo) == "function" then
        return GetAddOnInfo(addonName) ~= nil
    end
    return false
end

local function ResolveKit(name, fallback)
    if SOUNDKIT and name and SOUNDKIT[name] then
        return SOUNDKIT[name]
    end
    return fallback
end

function SoundRegistry:IsValid(key)
    return type(key) == "string" and (byKey[key] ~= nil or aliases[key] ~= nil)
end

function SoundRegistry:GetValues()
    local values = {}
    local hasWeakAuras = HasAddon("WeakAuras")
    local hasDecursive = HasAddon("Decursive")
    for index = 1, #sounds do
        if (not sounds[index].weakAuras or hasWeakAuras)
            and (not sounds[index].decursive or hasDecursive) then
            values[#values + 1] = sounds[index].key
        end
    end
    return values
end

function SoundRegistry:GetLabel(key)
    local sound = byKey[aliases[key] or key] or byKey.none
    return sound.labelKey and STEP:GetText(sound.labelKey) or sound.label
end

function SoundRegistry:Play(key, channel)
    local sound = byKey[aliases[key] or key] or byKey.none
    if sound.key == "none" then
        return false
    end
    channel = channel or "Master"
    if sound.file and type(PlaySoundFile) == "function" then
        local ok, played = pcall(PlaySoundFile, sound.file, channel)
        if ok and played then
            return true
        end
    end
    local kit = ResolveKit(sound.kit or sound.fallbackKit or "IG_MAINMENU_OPTION_CHECKBOX_ON", sound.fallback or 856)
    if kit and type(PlaySound) == "function" then
        return pcall(PlaySound, kit, channel) == true
    end
    return false
end
