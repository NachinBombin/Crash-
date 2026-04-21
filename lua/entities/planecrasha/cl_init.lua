include("shared.lua")

local TEX_FIRE  = "effects/fire_cloud1"
local TEX_SMOKE = "particle/particle_smokegrenade"
local TEX_SPARK = "effects/spark"

-- crashPos = spawnpos + fwdFlat * FLIGHT_DIST
-- Calibrated from observed crash vs fire placement (error was ~134 units short)
local FLIGHT_DIST  = 1530
local IMPACT_DELAY = 8.5

-- -------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------

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
    local tname = "PlaneFire_" .. math.random(1,999999)
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
            ps:SetStartAlpha( 130 ) ps:SetEndAlpha( 0 )
            ps:SetStartSize( math.random(30,60)*size ) ps:SetEndSize( math.random(120,240)*size )
            ps:SetColor( 30, 26, 22 )
            ps:SetGravity( Vector(0,0,6) ) ps:SetCollide( false )
        end
    end )
end

local function StartThinSmokeAt( pos, duration, size )
    size = size or 1
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneThinSmoke_" .. math.random(1,999999)
    timer.Create( tname, 0.07, 0, function()
        if not IsValid( emitter ) or CurTime() > endTime then
            if IsValid( emitter ) then emitter:Finish() end
            timer.Remove( tname )
            return
        end
        local p = emitter:Add( TEX_SMOKE,
            pos + Vector( math.random(-8,8)*size, math.random(-8,8)*size, 0 ) )
        if p then
            p:SetVelocity( Vector( math.random(-10,10), math.random(-10,10), math.random(30,80)*size ) )
            p:SetDieTime( math.random(3,6) )
            p:SetStartAlpha( 80 ) p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(8,20)*size ) p:SetEndSize( math.random(60,140)*size )
            p:SetColor( 55, 50, 44 )
            p:SetGravity( Vector(0,0,4) ) p:SetCollide( false )
        end
    end )
end

local function StartSmokeColumnAt( pos, duration, size )
    size = size or 1
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneSmoke_" .. math.random(1,999999)
    timer.Create( tname, 0.05, 0, function()
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
            p:SetStartAlpha( 200 ) p:SetEndAlpha( 0 )
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
    local tname = "PlaneSpark_" .. math.random(1,999999)
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

-- Scatter helpers
local function ScatterFire( centre, count, radius, duration, sizeMin, sizeMax )
    for i = 1, count do
        local off = Vector( math.random(-radius,radius), math.random(-radius,radius), math.random(0,20) )
        timer.Simple( math.random(0,20)/10, function()
            StartFireAt( centre + off, duration, math.Rand(sizeMin,sizeMax) )
        end )
    end
end

local function ScatterSparks( centre, count, radius, duration )
    for i = 1, count do
        local off = Vector( math.random(-radius,radius), math.random(-radius,radius), math.random(0,10) )
        timer.Simple( math.random(0,12)/10, function()
            StartSparkStream( centre + off, duration )
            DoBurstSparks( centre + off, math.random(1,3) )
        end )
    end
end

local function ScatterThinSmoke( centre, count, radius, duration )
    for i = 1, count do
        local off = Vector( math.random(-radius,radius), math.random(-radius,radius), math.random(0,10) )
        timer.Simple( math.random(0,30)/10, function()
            StartThinSmokeAt( centre + off, duration, math.Rand(0.5,1.4) )
        end )
    end
end

-- -------------------------------------------------------------------
-- Main net receiver
-- -------------------------------------------------------------------

net.Receive( "PlaneCrashEffects", function()
    local org = net.ReadVector()
    local fwd = net.ReadVector()

    local fwdFlat = Vector( fwd.x, fwd.y, 0 )
    fwdFlat:Normalize()
    local crashPos = org + fwdFlat * FLIGHT_DIST

    print( "[PLANECRASH CLIENT] spawnpos  = " .. tostring(org) )
    print( "[PLANECRASH CLIENT] fwd flat  = " .. tostring(fwdFlat) )
    print( "[PLANECRASH CLIENT] crashPos  = " .. tostring(crashPos) )
    print( "[PLANECRASH CLIENT] Waiting " .. IMPACT_DELAY .. "s..." )

    timer.Simple( IMPACT_DELAY, function()
        print( "[PLANECRASH CLIENT] IMPACT at " .. tostring(crashPos) )

        -- Immediate large explosions at impact core
        DoExplosion( crashPos,                             3.0 )
        DoExplosion( crashPos + Vector(  100,  60, 20 ),   2.2 )
        DoExplosion( crashPos + Vector( -110,  40, 15 ),   2.0 )
        DoExplosion( crashPos + Vector(  200,   0, 10 ),   1.8 )
        DoExplosion( crashPos + Vector( -200,   0, 10 ),   1.8 )

        -- Sparks: dense near core, spread wide across full debris field
        ScatterSparks( crashPos,                          10, 150, 4.0 )  -- core
        ScatterSparks( crashPos,                           8, 500, 2.5 )  -- mid debris
        ScatterSparks( crashPos,                           6, 900, 1.5 )  -- far debris
        ScatterSparks( crashPos + fwdFlat *  300,          5, 200, 2.0 )  -- nose slide
        ScatterSparks( crashPos - fwdFlat *  250,          5, 200, 2.0 )  -- tail
        ScatterSparks( crashPos + fwdFlat *  600,          3, 150, 1.5 )  -- furthest nose

        -- Fire: anchored wing/nose/tail + heavy scatter across 1000 unit radius
        local fd = 240
        StartFireAt( crashPos,                            fd, 2.2 )
        StartFireAt( crashPos + Vector(  30,  25, 0 ),    fd, 1.8 )
        StartFireAt( crashPos + Vector( -25, -30, 0 ),    fd, 1.6 )
        StartFireAt( crashPos + Vector(  250,  90, 0 ),   fd, 1.5 )  -- left wing
        StartFireAt( crashPos + Vector( -270, -70, 0 ),   fd, 1.5 )  -- right wing
        StartFireAt( crashPos + fwdFlat * 280,            fd, 1.3 )  -- nose
        StartFireAt( crashPos - fwdFlat * 220,            fd, 1.1 )  -- tail
        -- Dense scatter near core
        ScatterFire( crashPos,  10, 200, fd, 0.8, 2.0 )
        -- Mid-range debris fires
        ScatterFire( crashPos,  12, 550, fd, 0.5, 1.4 )
        -- Far scattered small fires from debris throw
        ScatterFire( crashPos,   8, 900, fd, 0.3, 0.9 )

        -- Smoke: heavy columns at core + thin wisps spread to 1000 units
        StartSmokeColumnAt( crashPos,                           fd, 2.2 )
        StartSmokeColumnAt( crashPos + Vector(  150,  100, 120), fd, 1.7 )
        StartSmokeColumnAt( crashPos + Vector( -170,  -90,  90), fd, 1.5 )
        StartSmokeColumnAt( crashPos + fwdFlat * 250,           fd, 1.3 )
        StartSmokeColumnAt( crashPos - fwdFlat * 200,           fd, 1.1 )
        -- Wispy debris smoke spread across full 1000u field
        ScatterThinSmoke( crashPos, 10, 300, fd )
        ScatterThinSmoke( crashPos, 12, 700, fd )
        ScatterThinSmoke( crashPos,  8, 1000, fd )

        -- Rolling secondary blasts
        timer.Simple( 0.4, function()
            DoExplosion( crashPos + Vector( math.random(-100,100), math.random(-100,100), 12 ), 2.5 )
            ScatterSparks( crashPos, 4, 120, 1.5 )
        end )
        timer.Simple( 0.9,  function() DoExplosion( crashPos + Vector(  90, 0, 8 ), 1.8 ) end )
        timer.Simple( 1.4,  function() DoExplosion( crashPos + Vector( -70, 0, 8 ), 1.6 ) end )
        timer.Simple( 2.1,  function()
            DoExplosion( crashPos + Vector( -130, 0, 10 ), 2.0 )
            DoBurstSparks( crashPos + Vector(-130,0,10), 4 )
        end )

        -- Synced with ScreenShake beats
        timer.Simple( 6.05, function()
            DoExplosion( crashPos + Vector( math.random(-90,90), math.random(-90,90), 10 ), 2.5 )
            ScatterSparks( crashPos, 3, 80, 1.2 )
        end )
        timer.Simple( 8.55, function()
            DoExplosion( crashPos + Vector( math.random(-70,70), math.random(-70,70),  8 ), 2.0 )
            DoBurstSparks( crashPos + Vector(50,30,0), 3 )
        end )
        timer.Simple( 9.55, function()
            DoExplosion( crashPos + Vector( math.random(-60,60), math.random(-60,60),  6 ), 1.8 )
        end )
        timer.Simple( 11.55, function()
            DoExplosion( crashPos + Vector( math.random(-50,50), math.random(-50,50),  6 ), 1.5 )
            DoBurstSparks( crashPos + Vector(-40,20,0), 2 )
        end )

        -- Late cooling-metal sparks
        timer.Simple( 30, function()
            DoBurstSparks( crashPos, 2 )
            DoBurstSparks( crashPos + Vector(  90,  40, 0 ), 1 )
            DoBurstSparks( crashPos + Vector( -80, -30, 0 ), 1 )
        end )
    end )  -- end IMPACT_DELAY
end )

net.Receive( "PlaneCrashDebug", function()
    local t   = net.ReadFloat()
    local pos = net.ReadVector()
    print( "[PLANECRASH CLIENT DEBUG t=" .. t .. "] fuseA:GetPos() = " .. tostring( pos ) )
end )

function ENT:Draw()
    self:DrawModel()
end

function ENT:Think()
    self:NextThink( CurTime() )
    return true
end
