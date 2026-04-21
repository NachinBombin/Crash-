include("shared.lua")

local TEX_FIRE  = "effects/fire_cloud1"
local TEX_SMOKE = "particle/particle_smokegrenade"
local TEX_SPARK = "effects/spark"

-- ─── Helpers ────────────────────────────────────────────────────

local function DoBurstSparks( pos, count )
    local ed = EffectData()
    ed:SetOrigin( pos )
    ed:SetNormal( Vector(0,0,1) )
    ed:SetMagnitude( count or 2 )
    ed:SetScale( 3 )
    ed:SetRadius( 64 )
    util.Effect( "Sparks", ed )
    util.Effect( "MetalSparks", ed )
end

local function DoExplosion( pos, scale )
    local ed = EffectData()
    ed:SetOrigin( pos )
    ed:SetScale( scale or 1 )
    ed:SetRadius( ( scale or 1 ) * 80 )
    ed:SetMagnitude( scale or 1 )
    util.Effect( "Explosion", ed )
    DoBurstSparks( pos, 4 )
end

local function StartFireAt( pos, duration, size )
    size = size or 1
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneFire_" .. tostring(pos) .. math.random(1,999999)
    timer.Create( tname, 0.04, 0, function()
        if not IsValid( emitter ) or CurTime() > endTime then
            if IsValid( emitter ) then emitter:Finish() end
            timer.Remove( tname )
            return
        end
        local p = emitter:Add( TEX_FIRE,
            pos + Vector( math.random(-12,12)*size, math.random(-12,12)*size, math.random(0,20)*size ) )
        if p then
            p:SetVelocity( Vector( math.random(-15,15), math.random(-15,15), math.random(70,180)*size ) )
            p:SetDieTime( math.random(10,25)/10 )
            p:SetStartAlpha( 255 ) p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(20,45)*size ) p:SetEndSize( math.random(5,12)*size )
            p:SetRoll( math.Rand(0,360) ) p:SetRollDelta( math.Rand(-1.5,1.5) )
            p:SetColor( 255, math.random(80,160), 0 )
            p:SetGravity( Vector(0,0,18) ) p:SetCollide( false )
        end
        local ps = emitter:Add( TEX_SMOKE,
            pos + Vector( math.random(-20,20)*size, math.random(-20,20)*size, math.random(30,60)*size ) )
        if ps then
            ps:SetVelocity( Vector( math.random(-20,20), math.random(-20,20), math.random(50,120)*size ) )
            ps:SetDieTime( math.random(4,8) )
            ps:SetStartAlpha( 120 ) ps:SetEndAlpha( 0 )
            ps:SetStartSize( math.random(30,60)*size ) ps:SetEndSize( math.random(120,240)*size )
            ps:SetColor( 30, 26, 22 )
            ps:SetGravity( Vector(0,0,6) ) ps:SetCollide( false )
        end
    end )
end

local function StartSmokeColumnAt( pos, duration, size )
    size = size or 1
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneSmoke_" .. tostring(pos) .. math.random(1,999999)
    timer.Create( tname, 0.06, 0, function()
        if not IsValid( emitter ) or CurTime() > endTime then
            if IsValid( emitter ) then emitter:Finish() end
            timer.Remove( tname )
            return
        end
        local p = emitter:Add( TEX_SMOKE,
            pos + Vector( math.random(-25,25)*size, math.random(-25,25)*size, math.random(0,15) ) )
        if p then
            p:SetVelocity( Vector( math.random(-25,25), math.random(-25,25), math.random(90,240)*size ) )
            p:SetDieTime( math.random(6,12) )
            p:SetStartAlpha( 180 ) p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(40,80)*size ) p:SetEndSize( math.random(200,420)*size )
            p:SetRoll( math.Rand(0,360) ) p:SetRollDelta( math.Rand(-0.8,0.8) )
            p:SetColor( 22, 19, 16 )
            p:SetGravity( Vector(0,0,10) ) p:SetCollide( false )
        end
    end )
end

local function StartSparkStream( pos, duration )
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneSpark_" .. tostring(pos) .. math.random(1,999999)
    timer.Create( tname, 0.03, 0, function()
        if not IsValid( emitter ) or CurTime() > endTime then
            if IsValid( emitter ) then emitter:Finish() end
            timer.Remove( tname )
            return
        end
        local p = emitter:Add( TEX_SPARK,
            pos + Vector( math.random(-30,30), math.random(-30,30), math.random(0,10) ) )
        if p then
            p:SetVelocity( Vector( math.random(-200,200), math.random(-200,200), math.random(100,350) ) )
            p:SetDieTime( math.random(3,8)/10 )
            p:SetStartAlpha( 255 ) p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(2,5) ) p:SetEndSize( 0 )
            p:SetColor( 255, math.random(180,255), math.random(50,120) )
            p:SetGravity( Vector(0,0,-300) )
            p:SetBounce( 0.4 ) p:SetCollide( true )
        end
    end )
end

-- Draws a glowing 3D cross at pos for N seconds -- visible in-world for calibration
local function Draw3DMarker( pos, label, duration )
    local endTime = CurTime() + ( duration or 20 )
    local tname = "PlaneMarker_" .. label .. math.random(1,9999)
    hook.Add( "PostDrawOpaqueRenderables", tname, function()
        if CurTime() > endTime then
            hook.Remove( "PostDrawOpaqueRenderables", tname )
            return
        end
        render.SetColorMaterial()
        render.DrawSphere( pos, 12, 8, 8, Color(255,50,0,255) )
        render.DrawLine( pos - Vector(60,0,0), pos + Vector(60,0,0), Color(255,255,0), true )
        render.DrawLine( pos - Vector(0,60,0), pos + Vector(0,60,0), Color(255,255,0), true )
        render.DrawLine( pos - Vector(0,0,60), pos + Vector(0,0,60), Color(0,200,255), true )
        -- label in 3D
        local ang = LocalPlayer():EyeAngles()
        ang:RotateAroundAxis( ang:Forward(), 90 )
        ang:RotateAroundAxis( ang:Right(), 90 )
        cam.Start3D2D( pos + Vector(0,0,30), ang, 0.15 )
            draw.SimpleText( label, "DermaDefaultBold", 0, 0, Color(255,255,0), TEXT_ALIGN_CENTER )
        cam.End3D2D()
    end )
end

-- ─── Main effects trigger ─────────────────────────────────────────────

net.Receive( "PlaneCrashEffects", function()
    local org     = net.ReadVector()
    local fwd     = net.ReadVector()

    print( "[PLANECRASH CLIENT] PlaneCrashEffects received!" )
    print( "[PLANECRASH CLIENT] org (spawnpos) = " .. tostring( org ) )
    print( "[PLANECRASH CLIENT] forward dir   = " .. tostring( fwd ) )

    -- Draw in-world marker at spawnpos so you can see exactly where it is
    Draw3DMarker( org, "SPAWNPOS", 30 )

    -- Spawn effects at org (= spawnpos for now).
    -- Once you tell us the offset from spawnpos to the visual crash site
    -- (read from the console prints + in-world marker), we replace org here
    -- with the calibrated position.
    local crashPos = org  -- <-- CALIBRATION POINT: adjust this after reading debug output

    print( "[PLANECRASH CLIENT] Spawning effects at crashPos = " .. tostring( crashPos ) )

    DoExplosion( crashPos, 3 )
    DoExplosion( crashPos + Vector(  80,  60, 20 ), 2 )
    DoExplosion( crashPos + Vector( -90,  40, 15 ), 2 )
    DoBurstSparks( crashPos, 6 )

    StartSparkStream( crashPos,                          3.0 )
    StartSparkStream( crashPos + Vector( 120,  80, 0 ),  2.5 )
    StartSparkStream( crashPos + Vector(-100,  60, 0 ),  2.0 )

    timer.Simple( 0.3, function()
        DoExplosion( crashPos + Vector( 200,  0, 10 ), 2.2 )
        DoExplosion( crashPos + Vector(-200,  0, 10 ), 2.2 )
        DoBurstSparks( crashPos + Vector( 200, 0, 10 ), 4 )
        DoBurstSparks( crashPos + Vector(-200, 0, 10 ), 4 )
    end )
    timer.Simple( 0.7, function() DoExplosion( crashPos + Vector( 80, 0, 5 ), 1.8 ) end )
    timer.Simple( 1.1, function() DoExplosion( crashPos + Vector(  0, 0, 5 ), 2.0 ) end )
    timer.Simple( 1.5, function() DoExplosion( crashPos + Vector(-60, 0, 5 ), 1.5 ) end )
    timer.Simple( 2.0, function()
        DoExplosion( crashPos + Vector(-120, 0, 8 ), 1.8 )
        DoBurstSparks( crashPos + Vector(-120, 0, 8), 3 )
    end )

    local fireDuration = 240
    StartFireAt( crashPos,                           fireDuration, 2.0 )
    StartFireAt( crashPos + Vector(  90,  50, 0 ),   fireDuration, 1.6 )
    StartFireAt( crashPos + Vector( -80, -40, 0 ),   fireDuration, 1.4 )
    StartFireAt( crashPos + Vector( 160,   0, 0 ),   fireDuration, 1.2 )
    StartFireAt( crashPos + Vector(-160,   0, 0 ),   fireDuration, 1.2 )
    StartFireAt( crashPos + Vector(   0, 160, 0 ),   fireDuration, 1.0 )

    StartSmokeColumnAt( crashPos,                           fireDuration, 2.0 )
    StartSmokeColumnAt( crashPos + Vector( 100,  80, 80 ),  fireDuration, 1.5 )
    StartSmokeColumnAt( crashPos + Vector(-120, -60, 60 ),  fireDuration, 1.2 )

    -- Secondary blasts synced to ScreenShake (t=20.5,23,24,26 from ENT spawn)
    -- Net fires at t=14.95, so offsets are: 5.55, 8.05, 9.05, 11.05
    timer.Simple( 5.55, function()
        DoExplosion( crashPos + Vector( math.random(-80,80), math.random(-80,80), 10 ), 2.5 )
        DoBurstSparks( crashPos, 5 )
        print( "[PLANECRASH CLIENT] Secondary explosion 1 fired" )
    end )
    timer.Simple( 8.05, function()
        DoExplosion( crashPos + Vector( math.random(-60,60), math.random(-60,60),  8 ), 2.0 )
        DoBurstSparks( crashPos + Vector(50,30,0), 3 )
        print( "[PLANECRASH CLIENT] Secondary explosion 2 fired" )
    end )
    timer.Simple( 9.05, function()
        DoExplosion( crashPos + Vector( math.random(-50,50), math.random(-50,50),  5 ), 1.8 )
        print( "[PLANECRASH CLIENT] Secondary explosion 3 fired" )
    end )
    timer.Simple( 11.05, function()
        DoExplosion( crashPos + Vector( math.random(-40,40), math.random(-40,40),  5 ), 1.5 )
        DoBurstSparks( crashPos + Vector(-40,20,0), 2 )
        print( "[PLANECRASH CLIENT] Secondary explosion 4 fired" )
    end )

    timer.Simple( 30, function()
        DoBurstSparks( crashPos, 2 )
        DoBurstSparks( crashPos + Vector(80,40,0), 1 )
    end )
end )

-- ─── Debug position receiver ────────────────────────────────────────────
-- Receives fuseA:GetPos() snapshots from the server at t=17, 20, 23
-- and draws in-world markers + console prints for calibration.

net.Receive( "PlaneCrashDebug", function()
    local t   = net.ReadFloat()
    local pos = net.ReadVector()
    print( "[PLANECRASH CLIENT DEBUG t=" .. t .. "] fuseA:GetPos() = " .. tostring( pos ) )
    Draw3DMarker( pos, "fuseA t=" .. t, 40 )
end )

-- ─── Entity callbacks ─────────────────────────────────────────────────

function ENT:Draw()
    self:DrawModel()
end

function ENT:Think()
    self:NextThink( CurTime() )
    return true
end
