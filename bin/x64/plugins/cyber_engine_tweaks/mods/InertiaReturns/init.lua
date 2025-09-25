--------------------------------------------------------
-- CopyRight (C) 2025, tidusmd. All rights reserved.
-- This mod is under the MIT License.
-- https://opensource.org/licenses/mit-license.php
--------------------------------------------------------

AIR = {
	description = "The Air's Inertia Returns",
	version = "1.2.0",
    -- version check
    cet_required_version = 36.0, -- 1.36.0
    cet_version_num = 0,
    -- params
    -- Last ground velocity for inertia calculation
    last_ground_velocity = nil,
    -- Record previous ground contact state
    was_on_ground = true,
    -- Inertia strength factor (0.0 = no inertia)
    default_inertia_factor = 0.45,
    inertia_factor = 0,
    -- Vehicle landing settings
    default_down_force = -30.0,
    down_force = 0,
    raycast_distance = 3.0,
    -- dodge
    is_dodge = false,
    is_air_dodge = false,
}

registerForEvent('onInit', function()

    if not AIR:CheckDependencies() then
        print('[AIR][Error] Air\'s Inertia Returns Mod failed to load due to missing dependencies.')
        return
    end

    AIR:ResetInertiaFactor()
    AIR:ResetDownForce()
    AIR.last_ground_velocity = Vector4.new(0.0, 0.0, 0.0, 0.0)
    local AIR = AIR -- Save self for closure
    ObserveAfter("LocomotionEventsTransition", "OnUpdate",
    ---@param this LocomotionEventsTransition
    ---@param timeDelta Float
    ---@param stateContext StateContext
    ---@param scriptInterface StateGameScriptInterface
    function(this, timeDelta, stateContext, scriptInterface)

        -- Get player object
        local player = Game.GetPlayer()

        -- Determine if player is on the ground
        local is_on_ground = this:IsTouchingGround(scriptInterface)

        local locomotion_velocity = this.GetLinearVelocity(scriptInterface)

        if is_on_ground then
            -- Apply velocity correction if enabled and on vehicle
            if not AIR.was_on_ground then
                -- Update down force based on ground material before applying
                if AIR:IsSlidingGround(player) then
                    this:AddImpulse(stateContext, Vector4.new(
                        0.0,
                        0.0,
                        AIR.down_force,
                        1.0
                    ))
                end
            end

            -- Record current velocity when on the ground
            AIR.last_ground_velocity = player:GetVelocity()
            AIR.was_on_ground = true
        else
            if AIR.is_dodge or AIR.is_air_dodge then
                -- Do not apply inertia during dodge
                return
            end
            -- Apply inertia only at the moment of leaving the ground
            if AIR.was_on_ground then
                -- Apply inertia once when leaving the ground
                this:AddImpulse(stateContext, Vector4.new(
                    (AIR.last_ground_velocity.x - locomotion_velocity.x) * AIR.inertia_factor,
                    (AIR.last_ground_velocity.y - locomotion_velocity.y) * AIR.inertia_factor,
                    0.0, -- Leave Z axis (vertical) to gravity
                    1.0
                ))
                AIR.was_on_ground = false
            end
            -- After that, leave it to the game's physics engine (do nothing)
        end
    end)

    Observe("DodgeEvents", "OnEnter",
    ---@param this DodgeEvents
    ---@param stateContext StateContext
    ---@param scriptInterface StateGameScriptInterface
    function(this, stateContext, scriptInterface)   
        AIR.is_dodge = true
    end)

    ObserveAfter("DodgeEvents", "OnExit",
    ---@param this DodgeEvents
    ---@param stateContext StateContext
    ---@param scriptInterface StateGameScriptInterface
    function(this, stateContext, scriptInterface)
        AIR.is_dodge = false
    end)


    Observe("DodgeAirEvents", "OnEnter",
    ---@param this DodgeAirEvents
    ---@param stateContext StateContext
    ---@param scriptInterface StateGameScriptInterface
    function(this, stateContext, scriptInterface)   
        AIR.is_air_dodge = true
    end)

    ObserveAfter("DodgeAirEvents", "OnExit",
    ---@param this DodgeAirEvents
    ---@param stateContext StateContext
    ---@param scriptInterface StateGameScriptInterface
    function(this, stateContext, scriptInterface)
        AIR.is_air_dodge = false
    end)

    print('[AIR][Info] Air\'s Inertia Returns Mod loaded successfully.')

end)

function AIR:CheckDependencies()
    -- Check Cyber Engine Tweaks Version
    local cet_version_str = GetVersion()
    local cet_version_major, cet_version_minor = cet_version_str:match("1.(%d+)%.*(%d*)")
    AIR.cet_version_num = tonumber(cet_version_major .. "." .. cet_version_minor)

    if AIR.cet_version_num < AIR.cet_required_version then
        print("[AIR][Error] Air\'s Inertia Returns Mod requires Cyber Engine Tweaks version 1." .. AIR.cet_required_version .. " or higher.")
        return false
    end
    return true
end

function AIR:SetInertiaFactor(factor)
    if factor < 0.0 then
        factor = 0.0
    end
    AIR.inertia_factor = factor
end

function AIR:ResetInertiaFactor()
    AIR.inertia_factor = AIR.default_inertia_factor
end

function AIR:SetDownForce(force)
    AIR.down_force = force
end

function AIR:ResetDownForce()
    AIR.down_force = AIR.default_down_force
end

function AIR:IsSlidingGround(player)
    local player_position = player:GetWorldPosition()
    local start_position = Vector4.new(
        player_position.x,
        player_position.y,
        player_position.z + 0.5,
        1.0
    )
    local end_position = Vector4.new(
        player_position.x,
        player_position.y,
        player_position.z - AIR.raycast_distance,
        1.0
    )
    local is_static_colliding, _ = Game.GetSpatialQueriesSystem():SyncRaycastByCollisionGroup(start_position,end_position,"Static",false,true)
    if is_static_colliding then
        return true
    end
    local is_dynamic_colliding, _ = Game.GetSpatialQueriesSystem():SyncRaycastByCollisionGroup(start_position,end_position,"Dynamic",false,true)
    if is_dynamic_colliding then
        return true
    end
    local is_vehicle_colliding, _ = Game.GetSpatialQueriesSystem():SyncRaycastByCollisionGroup(start_position,end_position,"Vehicle",false,false)
    if is_vehicle_colliding then
        return true
    end
    return false
end

return AIR