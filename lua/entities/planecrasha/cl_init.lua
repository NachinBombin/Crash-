include("shared.lua")

local TEX_FIRE  = "effects/fire_cloud1"
local TEX_SMOKE = "particle/particle_smokegrenade"
local TEX_SPARK = "effects/spark"

local FLIGHT_DIST    = 1389
local LATERAL_OFFSET = -798
local IMPACT_DELAY   = 8.5

-- -------------------------------------------------------------------
-- Particle helpers
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

-- Fire emitter: duration is staggered per call site so they don't all die together
local function StartFireAt( pos, duration, size )
    size = size or 1
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneFire_" .. math.random(1,999999)
    timer.Create( tname, 0.05, 0, function()  -- 0.05 tick (was 0.04) saves ~20% emit calls
        if not IsValid( emitter ) or CurTime() > endTime then
            if IsValid( emitter ) then emitter:Finish() end
            timer.Remove( tname )
            return
        end
        local p = emitter:Add( TEX_FIRE,
            pos + Vector( math.random(-12,12)*size, math.random(-12,12)*size, math.random(0,20)*size ) )
        if p then
            p:SetVelocity( Vector( math.random(-15,15), math.random(-15,15), math.random(70,180)*size ) )
            p:SetDieTime( math.random(10,22)/10 )
            p:SetStartAlpha( 255 ) p:SetEndAlpha( 0 )
            p:SetStartSize( math.random(20,45)*size ) p:SetEndSize( math.random(5,12)*size )
            p:SetRoll( math.Rand(0,360) ) p:SetRollDelta( math.Rand(-1.5,1.5) )
            p:SetColor( 255, math.random(80,160), 0 )
            p:SetGravity( Vector(0,0,18) ) p:SetCollide( false )
        end
        -- smoke co-emitted only 1-in-3 ticks to reduce particle count
        if math.random(3) == 1 then
            local ps = emitter:Add( TEX_SMOKE,
                pos + Vector( math.random(-20,20)*size, math.random(-20,20)*size, math.random(30,60)*size ) )
            if ps then
                ps:SetVelocity( Vector( math.random(-20,20), math.random(-20,20), math.random(50,120)*size ) )
                ps:SetDieTime( math.random(4,7) )
                ps:SetStartAlpha( 120 ) ps:SetEndAlpha( 0 )
                ps:SetStartSize( math.random(30,55)*size ) ps:SetEndSize( math.random(100,200)*size )
                ps:SetColor( 30, 26, 22 )
                ps:SetGravity( Vector(0,0,6) ) ps:SetCollide( false )
            end
        end
    end )
end

-- Smoke column (standalone, used for the main pillars only)
local function StartSmokeColumnAt( pos, duration, size )
    size = size or 1
    local endTime = CurTime() + duration
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local tname = "PlaneSmoke_" .. math.random(1,999999)
    timer.Create( tname, 0.08, 0, function()  -- slower tick = fewer particles
        if not IsValid( emitter ) or CurTime() > endTime then
            if IsValid( emitter ) then emitter:Finish() end
            timer.Remove( tname )
            return
        end
        local p = emitter:Add( TEX_SMOKE,
            pos + Vector( math.random(-25,25)*size, math.random(-25,25)*size, math.random(0,15) ) )
        if p then
            p:SetVelocity( Vector( math.random(-25,25), math.random(-25,25), math.random(90,240)*size ) )
            p:SetDieTime( math.random(6,11) )
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

-- Circular scatter helpers
local function CircularScatterFire( centre, count, rMin, rMax, duration, sizeMin, sizeMax, timeSpread )
    for i = 1, count do
        local a = math.Rand(0, 2*math.pi)
        local r = math.Rand(rMin, rMax)
        local off = Vector( math.cos(a)*r, math.sin(a)*r, 0 )
        -- stagger duration so each emitter dies at a slightly different time
        local dur = duration + math.Rand(-8, 8)
        timer.Simple( math.Rand(0, timeSpread or 2), function()
            StartFireAt( centre + off, dur, math.Rand(sizeMin, sizeMax) )
        end )
    end
end

local function CircularScatterSparks( centre, count, rMin, rMax, duration, timeSpread )
    for i = 1, count do
        local a = math.Rand(0, 2*math.pi)
        local r = math.Rand(rMin, rMax)
        local off = Vector( math.cos(a)*r, math.sin(a)*r, 0 )
        timer.Simple( math.Rand(0, timeSpread or 1.5), function()
            StartSparkStream( centre + off, duration )
            DoBurstSparks( centre + off, math.random(1,3) )
        end )
    end
end

-- -------------------------------------------------------------------
-- Main net receiver
-- -------------------------------------------------------------------

net.Receive( "PlaneCrashEffects", function()
    local org = net.ReadVector()
    local fwd = net.ReadVector()

    -- TNT sub-event: fwd marker is (0,0,-9999)
    if fwd.z == -9999 then
        -- org is the blast position
        DoExplosion( org, math.Rand(1.5, 3.0) )
        util.ScreenShake( org, 3, 80, 0.6, 2000 )
        return
    end

    -- Initial crash event
    local fwdFlat = Vector( fwd.x, fwd.y, 0 )
    fwdFlat:Normalize()
    local rightFlat = Vector( fwdFlat.y, -fwdFlat.x, 0 )
    local crashPos = org + fwdFlat * FLIGHT_DIST + rightFlat * LATERAL_OFFSET

    print( "[PLANECRASH CLIENT] spawnpos = " .. tostring(org) )
    print( "[PLANECRASH CLIENT] crashPos = " .. tostring(crashPos) )

    timer.Simple( IMPACT_DELAY, function()
        print( "[PLANECRASH CLIENT] IMPACT at " .. tostring(crashPos) )

        -- Immediate explosions
        DoExplosion( crashPos,                             3.0 )
        DoExplosion( crashPos + Vector(  100,  60, 20 ),   2.2 )
        DoExplosion( crashPos + Vector( -110,  40, 15 ),   2.0 )
        DoExplosion( crashPos + fwdFlat   * 200,           1.8 )
        DoExplosion( crashPos - fwdFlat   * 180,           1.8 )
        DoExplosion( crashPos + rightFlat * 220,           1.6 )
        DoExplosion( crashPos - rightFlat * 200,           1.6 )

        -- Sparks (reduced outer rings)
        CircularScatterSparks( crashPos, 10,   0, 150, 3.5, 1.0 )
        CircularScatterSparks( crashPos,  8, 150, 450, 2.0, 2.0 )
        CircularScatterSparks( crashPos,  5, 450, 800, 1.2, 3.0 )

        -- Fire rings — each with individual randomised duration (+/- handled in helper)
        -- Core fires (immediate, anchor the scene visually)
        local fd = 55  -- base fire duration in seconds (reduced from 240)
        StartFireAt( crashPos,                   fd + math.Rand(0,15), 2.2 )
        StartFireAt( crashPos + Vector(30,25,0),  fd + math.Rand(0,12), 1.9 )
        StartFireAt( crashPos + Vector(-30,-25,0),fd + math.Rand(0,10), 1.7 )
        StartFireAt( crashPos + fwdFlat * 220,    fd + math.Rand(0,20), 1.4 )
        StartFireAt( crashPos - fwdFlat * 180,    fd + math.Rand(0,18), 1.2 )
        StartFireAt( crashPos + rightFlat * 250,  fd + math.Rand(0,15), 1.5 )
        StartFireAt( crashPos - rightFlat * 230,  fd + math.Rand(0,15), 1.5 )

        -- Reduced ring counts (was 16/18/14/10)
        CircularScatterFire( crashPos, 10,   0, 200, fd,       0.8, 2.0,  3.0 )
        CircularScatterFire( crashPos, 10, 200, 500, fd - 10,  0.5, 1.4,  5.0 )
        CircularScatterFire( crashPos,  7, 500, 850, fd - 20,  0.3, 1.0,  8.0 )
        CircularScatterFire( crashPos,  5, 850,1100, fd - 30,  0.2, 0.7, 10.0 )

        -- Smoke: ONLY 3 main columns (down from 5 + 3 scatter rings)
        -- Columns get individual durations so they die at different times
        StartSmokeColumnAt( crashPos,                            fd + 25, 2.2 )
        StartSmokeColumnAt( crashPos + fwdFlat  * 200 + Vector(0,0,80), fd + 10, 1.6 )
        StartSmokeColumnAt( crashPos - rightFlat * 180 + Vector(0,0,60), fd +  5, 1.3 )

        -- Rolling secondary blasts
        timer.Simple( 0.4, function()
            DoExplosion( crashPos + Vector( math.random(-100,100), math.random(-100,100), 12 ), 2.5 )
            CircularScatterSparks( crashPos, 3, 0, 100, 1.2, 0.5 )
        end )
        timer.Simple( 0.9, function() DoExplosion( crashPos + fwdFlat * 120 + Vector(0,0,8), 1.8 ) end )
        timer.Simple( 1.4, function() DoExplosion( crashPos - fwdFlat * 100 + Vector(0,0,8), 1.6 ) end )
        timer.Simple( 2.1, function()
            DoExplosion( crashPos + rightFlat * 180 + Vector(0,0,10), 2.0 )
            DoBurstSparks( crashPos + rightFlat * 180, 4 )
        end )
        timer.Simple( 3.0, function() DoExplosion( crashPos - rightFlat * 160 + Vector(0,0,8), 1.7 ) end )

        timer.Simple( 6.05, function()
            DoExplosion( crashPos + Vector( math.random(-90,90), math.random(-90,90), 10 ), 2.5 )
            CircularScatterSparks( crashPos, 3, 0, 80, 1.2, 0.3 )
        end )
        timer.Simple( 8.55, function()
            DoExplosion( crashPos + Vector( math.random(-70,70), math.random(-70,70), 8 ), 2.0 )
            DoBurstSparks( crashPos + fwdFlat * 80, 3 )
        end )
        timer.Simple( 9.55, function() DoExplosion( crashPos + Vector( math.random(-60,60), math.random(-60,60), 6 ), 1.8 ) end )
        timer.Simple( 11.55, function()
            DoExplosion( crashPos + Vector( math.random(-50,50), math.random(-50,50), 6 ), 1.5 )
            DoBurstSparks( crashPos - rightFlat * 60, 2 )
        end )

        -- Late cooling sparks
        timer.Simple( 25, function()
            CircularScatterSparks( crashPos, 3, 0, 200, 0.8, 1.0 )
        end )
    end )
end )

net.Receive( "PlaneCrashDebug", function()
    local t   = net.ReadFloat()
    local pos = net.ReadVector()
    print( "[PLANECRASH CLIENT DEBUG t=" .. t .. "] fuseA:GetPos() = " .. tostring(pos) )
end )

function ENT:Draw()  self:DrawModel() end
function ENT:Think() self:NextThink( CurTime() ) return true end
