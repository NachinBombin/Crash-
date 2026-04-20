include("shared.lua")

-- ─── Particle helpers ──────────────────────────────────────────────────

-- Verified working GMod particle textures (no black square)
local TEX_FIRE  = "effects/fire_cloud1"
local TEX_SMOKE = "particle/particle_smokegrenade"
local TEX_SPARK = "effects/spark"

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
            p:SetStartAlpha( 255 )
            p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(20,45)*size )
            p:SetEndSize( math.random(5,12)*size )
            p:SetRoll( math.Rand(0,360) )
            p:SetRollDelta( math.Rand(-1.5,1.5) )
            p:SetColor( 255, math.random(80,160), 0 )
            p:SetGravity( Vector(0,0,18) )
            p:SetCollide( false )
        end

        local ps = emitter:Add( TEX_SMOKE,
            pos + Vector( math.random(-20,20)*size, math.random(-20,20)*size, math.random(30,60)*size ) )
        if ps then
            ps:SetVelocity( Vector( math.random(-20,20), math.random(-20,20), math.random(50,120)*size ) )
            ps:SetDieTime( math.random(4,8) )
            ps:SetStartAlpha( 120 )
            ps:SetEndAlpha( 0 )
            ps:SetStartSize( math.random(30,60)*size )
            ps:SetEndSize( math.random(120,240)*size )
            ps:SetColor( 30, 26, 22 )
            ps:SetGravity( Vector(0,0,6) )
            ps:SetCollide( false )
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
            p:SetStartAlpha( 180 )
            p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(40,80)*size )
            p:SetEndSize( math.random(200,420)*size )
            p:SetRoll( math.Rand(0,360) )
            p:SetRollDelta( math.Rand(-0.8,0.8) )
            p:SetColor( 22, 19, 16 )
            p:SetGravity( Vector(0,0,10) )
            p:SetCollide( false )
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
            p:SetStartAlpha( 255 )
            p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(2,5) )
            p:SetEndSize( 0 )
            p:SetColor( 255, math.random(180,255), math.random(50,120) )
            p:SetGravity( Vector(0,0,-300) )
            p:SetBounce( 0.4 )
            p:SetCollide( true )
        end
    end )
end

-- ─── Net receiver ──────────────────────────────────────────────────
-- Server sends the position of fuseA AFTER it has spawned and settled
-- (t=14.96 + 0.15s buffer = t=15.1). This is the true ground impact point,
-- not the animated entity's starting origin which is far away.

net.Receive( "PlaneCrashEffects", function()
    local org = net.ReadVector()

    -- Impact moment
    DoExplosion( org, 3 )
    DoExplosion( org + Vector(  80,  60, 20 ), 2 )
    DoExplosion( org + Vector( -90,  40, 15 ), 2 )
    DoBurstSparks( org, 6 )

    StartSparkStream( org,                         3.0 )
    StartSparkStream( org + Vector( 120,  80, 0 ), 2.5 )
    StartSparkStream( org + Vector(-100,  60, 0 ), 2.0 )

    -- Wing shear explosions
    timer.Simple( 0.3, function()
        DoExplosion( org + Vector( 200,  0, 10 ), 2.2 )
        DoExplosion( org + Vector(-200,  0, 10 ), 2.2 )
        DoBurstSparks( org + Vector( 200, 0, 10 ), 4 )
        DoBurstSparks( org + Vector(-200, 0, 10 ), 4 )
    end )

    -- Cascading fuselage explosions
    timer.Simple( 0.7, function() DoExplosion( org + Vector( 80, 0, 5 ), 1.8 ) end )
    timer.Simple( 1.1, function() DoExplosion( org + Vector(  0, 0, 5 ), 2.0 ) end )
    timer.Simple( 1.5, function() DoExplosion( org + Vector(-60, 0, 5 ), 1.5 ) end )
    timer.Simple( 2.0, function()
        DoExplosion( org + Vector(-120, 0, 8 ), 1.8 )
        DoBurstSparks( org + Vector(-120, 0, 8), 3 )
    end )

    -- Fire (4 minutes)
    local fireDuration = 240
    StartFireAt( org,                          fireDuration, 2.0 )
    StartFireAt( org + Vector(  90,  50, 0 ),  fireDuration, 1.6 )
    StartFireAt( org + Vector( -80, -40, 0 ),  fireDuration, 1.4 )
    StartFireAt( org + Vector( 160,   0, 0 ),  fireDuration, 1.2 )
    StartFireAt( org + Vector(-160,   0, 0 ),  fireDuration, 1.2 )
    StartFireAt( org + Vector(   0, 160, 0 ),  fireDuration, 1.0 )

    -- Smoke columns
    StartSmokeColumnAt( org,                          fireDuration, 2.0 )
    StartSmokeColumnAt( org + Vector( 100,  80, 80 ), fireDuration, 1.5 )
    StartSmokeColumnAt( org + Vector(-120, -60, 60 ), fireDuration, 1.2 )

    -- Secondary blasts synced to existing ScreenShake calls
    -- Server shakes at t=20.5,23,24,26 from ENT spawn; debris at t=14.95
    -- Offsets here: 20.5-14.95=5.55, 23-14.95=8.05, 24-14.95=9.05, 26-14.95=11.05
    timer.Simple( 5.55, function()
        DoExplosion( org + Vector( math.random(-80,80), math.random(-80,80), 10 ), 2.5 )
        DoBurstSparks( org, 5 )
    end )
    timer.Simple( 8.05, function()
        DoExplosion( org + Vector( math.random(-60,60), math.random(-60,60),  8 ), 2.0 )
        DoBurstSparks( org + Vector(50,30,0), 3 )
    end )
    timer.Simple( 9.05, function()
        DoExplosion( org + Vector( math.random(-50,50), math.random(-50,50),  5 ), 1.8 )
    end )
    timer.Simple( 11.05, function()
        DoExplosion( org + Vector( math.random(-40,40), math.random(-40,40),  5 ), 1.5 )
        DoBurstSparks( org + Vector(-40,20,0), 2 )
    end )

    -- Dying embers
    timer.Simple( 30, function()
        DoBurstSparks( org, 2 )
        DoBurstSparks( org + Vector(80,40,0), 1 )
    end )
end )

-- ─── Entity callbacks ──────────────────────────────────────────────────

function ENT:Draw()
    self:DrawModel()
end

function ENT:Think()
    self:NextThink( CurTime() )
    return true
end
