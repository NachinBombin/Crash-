AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString( "PlaneCrashEffects" )
util.AddNetworkString( "PlaneCrashDebug" )

-- -------------------------------------------------------------------
-- Debris prop definitions
-- { model, count, speed, arc (upward vel), onFire, originRadius }
-- arc   = Z velocity added on launch
-- speed = horizontal fling speed
-- onFire = true -> prop:Ignite()
-- -------------------------------------------------------------------
local DEBRIS_PROPS = {
    { mdl="models/props_junk/propane_tank001a.mdl",       count=10, speed=900,  arc=600,  fire=true  },
    { mdl="models/props_junk/wood_crate001a_damaged.mdl", count=4,  speed=600,  arc=450,  fire=true  },
    { mdl="models/props_debris/metal_panel01a.mdl",       count=4,  speed=700,  arc=500,  fire=true  },
    { mdl="models/xqm/jetenginelarge.mdl",                count=2,  speed=800,  arc=550,  fire=true  },
    { mdl="models/xqm/deg90.mdl",                         count=3,  speed=650,  arc=480,  fire=true  },
    { mdl="models/props_phx/carseat3.mdl",                count=8,  speed=750,  arc=520,  fire=false },
    { mdl="models/props_phx/mk-82.mdl",                   count=6,  speed=1800, arc=700,  fire=true  },
    { mdl="models/props_c17/doll01.mdl",                  count=1,  speed=500,  arc=400,  fire=false },
    { mdl="models/props_c17/SuitCase001a.mdl",            count=2,  speed=550,  arc=380,  fire=false },
    { mdl="models/props_c17/BriefCase001a.mdl",           count=2,  speed=600,  arc=420,  fire=true  },
}

-- TNT blast schedule: { delay, radius, damage }
-- First blasts are enormous (4000u radius), shrinking over time
local TNT_BLASTS = {
    { t=0.0,  dmg=2000, radius=4000 },
    { t=0.3,  dmg=1800, radius=3600 },
    { t=0.8,  dmg=1600, radius=3200 },
    { t=1.5,  dmg=1400, radius=2800 },
    { t=2.5,  dmg=1200, radius=2400 },
    { t=3.8,  dmg=1000, radius=2000 },
    { t=5.5,  dmg=800,  radius=1600 },
    { t=7.5,  dmg=600,  radius=1200 },
    { t=10.0, dmg=400,  radius=800  },
    { t=13.0, dmg=250,  radius=500  },
    { t=16.5, dmg=150,  radius=300  },
    { t=20.0, dmg=80,   radius=180  },
    { t=24.0, dmg=40,   radius=100  },
}

local function LaunchDebris( crashPos, spawnAngles )
    local spawnAng = spawnAngles

    for _, def in ipairs( DEBRIS_PROPS ) do
        for i = 1, def.count do
            -- stagger spawns slightly so they don't all pop at once
            timer.Simple( math.Rand(0, 2.5), function()
                local prop = ents.Create("prop_physics")
                if not IsValid(prop) then return end

                prop:SetModel( def.mdl )

                -- random origin within 300u of crash centre
                local ox = math.Rand(-300, 300)
                local oy = math.Rand(-300, 300)
                prop:SetPos( crashPos + Vector(ox, oy, 80) )
                prop:SetAngles( Angle( math.Rand(0,360), math.Rand(0,360), math.Rand(0,360) ) )
                prop:Spawn()
                prop:Activate()

                -- launch in random direction with arc
                local phys = prop:GetPhysicsObject()
                if IsValid(phys) then
                    local angle  = math.Rand(0, 2*math.pi)
                    local hspeed = math.Rand( def.speed * 0.6, def.speed * 1.4 )
                    local vspeed = math.Rand( def.arc   * 0.7, def.arc   * 1.3 )
                    local vel = Vector(
                        math.cos(angle) * hspeed,
                        math.sin(angle) * hspeed,
                        vspeed
                    )
                    phys:SetVelocity( vel )
                    phys:SetAngleVelocity( Vector( math.Rand(-200,200), math.Rand(-200,200), math.Rand(-200,200) ) )
                    phys:Wake()
                end

                -- ignite if flagged
                if def.fire then
                    prop:Ignite( 240, 0 )
                end

                -- fire damage aura: deal burn damage to nearby players while prop is on fire
                if def.fire then
                    local dmgTimer = "PropFireDmg_" .. prop:EntIndex()
                    timer.Create( dmgTimer, 0.5, 480, function()
                        if not IsValid(prop) then timer.Remove(dmgTimer) return end
                        for _, ply in ipairs( player.GetAll() ) do
                            if IsValid(ply) and ply:GetPos():Distance(prop:GetPos()) < 120 then
                                ply:TakeDamage( 8, prop, prop )
                            end
                        end
                    end )
                end

                -- remove after 90 seconds
                timer.Simple( 90, function()
                    if IsValid(prop) then prop:Remove() end
                end )
            end )
        end
    end
end

local function ScheduleTNTBlasts( crashPos )
    for _, blast in ipairs( TNT_BLASTS ) do
        timer.Simple( blast.t, function()
            -- random position within 200u of crash centre for variety
            local bpos = crashPos + Vector(
                math.Rand(-200,200),
                math.Rand(-200,200),
                math.Rand(0,80)
            )
            util.BlastDamage( NULL, NULL, bpos, blast.radius, blast.dmg )
            -- visual + sound broadcast
            net.Start("PlaneCrashEffects")
                -- reuse the channel to send a TNT_BLAST sub-event
                -- We send a special marker vector (0,0,-9999) as org
                -- so cl_init knows this is a TNT event not the initial crash
                net.WriteVector( bpos )
                net.WriteVector( Vector(0,0,-9999) )  -- TNT marker
            net.Broadcast()

            sound.Play( "ambient/explosions/explode_" .. math.random(1,9) .. ".wav",
                bpos, 160, math.Rand(60,90), 1 )
        end )
    end
end

-- Fire damage from the crash fire zones (server-side, area burn)
local function StartFireDamageZone( crashPos )
    local tname = "CrashFireDmg"
    timer.Create( tname, 1.0, 240, function()
        for _, ply in ipairs( player.GetAll() ) do
            if not IsValid(ply) then continue end
            local dist = ply:GetPos():Distance(crashPos)
            if dist < 200 then
                ply:TakeDamage( 25, NULL, NULL )  -- inside core inferno
            elseif dist < 500 then
                ply:TakeDamage( 10, NULL, NULL )  -- edge of fire
            end
        end
    end )
end

function ENT:Initialize()
    local gonetimer  = cvars.Number( "l4dplanecrash_gonetime", -1 )
    local planesound = cvars.String( "l4dplanecrash_sound", "animation/airport_rough_crash_seq.wav" )
    local startmap   = game.GetMap()

    self:SetModel("models/hybridphysx/precrash_airliner.mdl")
    if startmap == "c11m5_runway" then
        self:SetPos( Vector( -5136, 10060, -192 ) )
        self:SetAngles( Angle( 0, 180, 0 ) )
    end
    if startmap == "c11m5_runway_ep2" then
        self:SetPos( Vector( -3181, 3404, -192 ) )
        self:SetAngles( Angle( 0, 180, 0 ) )
    end
    timer.Simple( 0.01, function() self:SetSequence("approach") end )
    self:ResetSequence("approach")
    self:EmitSound( planesound, 0, 100, 1, CHAN_AUTO )

    local spawnangles = self:GetAngles()
    self:SetAngles( spawnangles - Angle(0,180,0) )
    spawnangles = self:GetAngles()
    local spawnpos = self:GetPos()

    print( "[PLANECRASH] ENT spawned. spawnpos = " .. tostring(spawnpos) )
    print( "[PLANECRASH] spawnangles = " .. tostring(spawnangles) )
    print( "[PLANECRASH] map = " .. startmap )

    -- Compute crash position (mirrors cl_init logic)
    local fwdFlat = spawnangles:Forward()
    fwdFlat.z = 0
    fwdFlat:Normalize()
    local rightFlat = Vector( fwdFlat.y, -fwdFlat.x, 0 )
    local crashPos = spawnpos + fwdFlat * 1389 + rightFlat * (-798)

    local fuseA  = ents.Create("prop_dynamic_override")
    local fuseB  = ents.Create("prop_dynamic_override")
    local fuseC  = ents.Create("prop_dynamic_override")
    local fuseD  = ents.Create("prop_dynamic_override")
    local fuseE  = ents.Create("prop_dynamic_override")
    local fuseF  = ents.Create("prop_dynamic_override")
    local fuseG  = ents.Create("prop_dynamic_override")
    local fuseH  = ents.Create("prop_dynamic_override")
    local fuseI  = ents.Create("prop_dynamic_override")
    local fuseJ  = ents.Create("prop_dynamic_override")
    local fuseK  = ents.Create("prop_dynamic_override")
    local fuseL  = ents.Create("prop_dynamic_override")

    local function SetupFuse(ent, mdl)
        timer.Simple(14.95, function() ent:SetModel(mdl) end)
        timer.Simple(14.95, function() ent:SetPos(spawnpos) end)
        timer.Simple(14.95, function() ent:SetAngles(spawnangles) end)
        timer.Simple(14.95, function() ent:Spawn() end)
        timer.Simple(14.96, function() ent:SetSequence("boom") end)
        timer.Simple(14.96, function() ent:ResetSequence("boom") end)
    end

    SetupFuse(fuseA, "models/hybridphysx/airliner_primary_debris_1.mdl")
    SetupFuse(fuseB, "models/hybridphysx/airliner_primary_debris_2.mdl")
    SetupFuse(fuseC, "models/hybridphysx/airliner_primary_debris_3.mdl")
    SetupFuse(fuseD, "models/hybridphysx/airliner_primary_debris_4.mdl")
    SetupFuse(fuseE, "models/hybridphysx/airliner_fuselage_secondary_1.mdl")
    SetupFuse(fuseF, "models/hybridphysx/airliner_fuselage_secondary_2.mdl")
    SetupFuse(fuseG, "models/hybridphysx/airliner_fuselage_secondary_3.mdl")
    SetupFuse(fuseH, "models/hybridphysx/airliner_fuselage_secondary_4.mdl")
    SetupFuse(fuseI, "models/hybridphysx/airliner_left_wing_secondary.mdl")
    SetupFuse(fuseJ, "models/hybridphysx/airliner_right_wing_secondary_1.mdl")
    SetupFuse(fuseK, "models/hybridphysx/airliner_right_wing_secondary_2.mdl")
    SetupFuse(fuseL, "models/hybridphysx/airliner_tail_secondary.mdl")

    -- Broadcast visual effects trigger
    timer.Simple(14.95, function()
        print("[PLANECRASH] Broadcasting PlaneCrashEffects. spawnpos = " .. tostring(spawnpos))
        net.Start("PlaneCrashEffects")
            net.WriteVector(spawnpos)
            net.WriteVector(spawnangles:Forward())
        net.Broadcast()
    end)

    -- After IMPACT_DELAY (8.5s from broadcast = t~23.45 absolute):
    -- fire damage zone, TNT blasts, and debris launch
    timer.Simple(14.95 + 8.5, function()
        StartFireDamageZone(crashPos)
        ScheduleTNTBlasts(crashPos)
        LaunchDebris(crashPos, spawnangles)
    end)

    -- Debug position snaps
    timer.Simple(17.0, function()
        if not IsValid(fuseA) then print("[PLANECRASH DEBUG t=17] fuseA INVALID") return end
        local p = fuseA:GetPos()
        print("[PLANECRASH DEBUG t=17] fuseA:GetPos() = " .. tostring(p))
        net.Start("PlaneCrashDebug") net.WriteFloat(17) net.WriteVector(p) net.Broadcast()
    end)
    timer.Simple(20.0, function()
        if not IsValid(fuseA) then print("[PLANECRASH DEBUG t=20] fuseA INVALID") return end
        local p = fuseA:GetPos()
        print("[PLANECRASH DEBUG t=20] fuseA:GetPos() = " .. tostring(p))
        net.Start("PlaneCrashDebug") net.WriteFloat(20) net.WriteVector(p) net.Broadcast()
    end)
    timer.Simple(23.0, function()
        if not IsValid(fuseA) then print("[PLANECRASH DEBUG t=23] fuseA INVALID") return end
        local p = fuseA:GetPos()
        print("[PLANECRASH DEBUG t=23] fuseA:GetPos() = " .. tostring(p))
        net.Start("PlaneCrashDebug") net.WriteFloat(23) net.WriteVector(p) net.Broadcast()
    end)

    timer.Simple(20.5, function() util.ScreenShake(spawnpos, 4, 100, 4, 16000) end)
    timer.Simple(23.0, function() util.ScreenShake(spawnpos, 4, 100, 4, 16000) end)
    timer.Simple(24.0, function() util.ScreenShake(spawnpos, 4, 100, 4, 16000) end)
    timer.Simple(26.0, function() util.ScreenShake(spawnpos, 4, 100, 4, 16000) end)

    timer.Simple(14.96, function() self:Remove() end)

    local fuses = {fuseA,fuseB,fuseC,fuseD,fuseE,fuseF,fuseG,fuseH,fuseI,fuseJ,fuseK,fuseL}
    for _, f in ipairs(fuses) do
        timer.Simple(gonetimer, function() if IsValid(f) then f:Remove() end end)
    end
end

function ENT:Think()
    self:NextThink(CurTime())
    return true
end
