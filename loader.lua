package.preload['nl_ent'] = function()

    ---@class NLEntity
    local NLEntity = {}

    NLEntity.__index = function(t, k)
        -- Methods take priority
        local method = rawget(NLEntity, k)
        if method then return method end

        -- Scalar netprop read: ent.m_iHealth (no () needed)
        local val = entity.get_prop(t.__idx, k)
        if val ~= nil then return val end

        -- Nil result = likely array netprop, return index proxy
        -- ent.m_flPoseParameter[11]
        return setmetatable({}, {
            __index = function(_, idx)
                return entity.get_prop(t.__idx, k, idx)
            end,
            __newindex = function(_, idx, v)
                entity.set_prop(t.__idx, k, v, idx)
            end,
        })
    end

    NLEntity.__newindex = function(t, k, v)
        -- Netprop write: ent.m_iHealth = 100
        if k:sub(1, 2) == 'm_' or k:sub(1, 3) == 'pl.' then
            entity.set_prop(t.__idx, k, v)
        else
            rawset(t, k, v)
        end
    end

    local function wrap(entindex)
        if not entindex then return nil end
        return setmetatable({ __idx = entindex }, NLEntity)
    end

    --------------------------------------------------------------------
    -- entity.* namespace
    --------------------------------------------------------------------

    local M = {}

    function M.get_local_player()
        return wrap(entity.get_local_player())
    end

    function M.get(idx, by_userid)
        if by_userid then
            for _, ent in ipairs(entity.get_all('CCSPlayer')) do
                if entity.get_prop(ent, 'm_iUserId') == idx then
                    return wrap(ent)
                end
            end
            return nil
        end
        return wrap(idx)
    end

    function M.get_players(enemies_only, include_dormant, callback)
        local raw = {}
        if include_dormant then
            for _, idx in ipairs(entity.get_all('CCSPlayer')) do
                if not enemies_only or entity.is_enemy(idx) then
                    table.insert(raw, idx)
                end
            end
        else
            raw = entity.get_players(enemies_only or false)
        end

        if callback then
            for _, idx in ipairs(raw) do callback(wrap(idx)) end
            return nil
        end

        local result = {}
        for _, idx in ipairs(raw) do table.insert(result, wrap(idx)) end
        return result
    end

    function M.get_entities(class, include_dormant, callback)
        local raw    = entity.get_all(class)
        local result = {}
        for _, idx in ipairs(raw) do
            if include_dormant or not entity.is_dormant(idx) then
                if callback then
                    callback(wrap(idx))
                else
                    table.insert(result, wrap(idx))
                end
            end
        end
        if not callback then return result end
    end

    function M.get_game_rules()    return wrap(entity.get_game_rules())      end
    function M.get_player_resource() return wrap(entity.get_player_resource()) end
    function M.get_threat()        return nil end  -- no GS equivalent

    --------------------------------------------------------------------
    -- Common methods
    --------------------------------------------------------------------

    function NLEntity:get_index()     return self.__idx end
    function NLEntity:is_player()     return entity.get_classname(self.__idx) == 'CCSPlayer' end
    function NLEntity:is_dormant()    return entity.is_dormant(self.__idx) end
    function NLEntity:is_alive()      return entity.is_alive(self.__idx) end
    function NLEntity:is_enemy()      return entity.is_enemy(self.__idx) end
    function NLEntity:get_classname() return entity.get_classname(self.__idx) end
    function NLEntity:get_classid()   return nil end  -- no GS equivalent
    function NLEntity:get_name()      return entity.get_player_name(self.__idx) end
    function NLEntity:get_materials() return {} end   -- no GS equivalent
    function NLEntity:get_model_name()
        return entity.get_prop(self.__idx, 'm_nModelIndex')
    end

    function NLEntity:is_weapon()
        local cn = entity.get_classname(self.__idx) or ''
        return cn:find('Weapon') ~= nil or cn:find('Knife') ~= nil
    end

    function NLEntity:is_bot()
        local sid = entity.get_steam64(self.__idx)
        return sid == nil or sid == ''
    end

    function NLEntity:is_visible()
        local esp = entity.get_esp_data(self.__idx)
        return esp ~= nil and esp.alpha > 0
    end

    function NLEntity:is_occluded()
        return not self:is_visible()
    end

    function NLEntity:get_origin()
        local x, y, z = entity.get_origin(self.__idx)
        if not x then return nil end
        return { x = x, y = y, z = z }
    end

    function NLEntity:get_angles()
        local p = entity.get_prop(self.__idx, 'm_angEyeAngles[0]') or 0
        local y = entity.get_prop(self.__idx, 'm_angEyeAngles[1]') or 0
        local r = entity.get_prop(self.__idx, 'm_angAbsRotation')  or 0
        return { x = p, y = y, z = r }
    end

    function NLEntity:get_simulation_time()
        return {
            current = entity.get_prop(self.__idx, 'm_flSimulationTime'),
            old     = entity.get_prop(self.__idx, 'm_flOldSimulationTime'),
        }
    end

    --------------------------------------------------------------------
    -- Player methods
    --------------------------------------------------------------------

    function NLEntity:get_network_state()
        return entity.is_dormant(self.__idx) and 4 or 0
    end

    function NLEntity:get_bbox()
        local x1, y1, x2, y2, alpha = entity.get_bounding_box(self.__idx)
        return { pos1 = { x = x1, y = y1 }, pos2 = { x = x2, y = y2 }, alpha = alpha }
    end

    function NLEntity:get_player_info()
        local sid = entity.get_steam64(self.__idx)
        return { steamid64 = sid, steamid = sid, is_fake_player = self:is_bot(), is_hltv = false }
    end

    function NLEntity:get_player_weapon(all_weapons)
        local wpn = entity.get_player_weapon(self.__idx)
        if all_weapons then return wpn and { wrap(wpn) } or {} end
        return wrap(wpn)
    end

    function NLEntity:get_eye_position()
        local x, y, z = entity.get_origin(self.__idx)
        if not x then return nil end
        local ofs = entity.get_prop(self.__idx, 'm_vecViewOffset[2]') or 64
        return { x = x, y = y, z = z + ofs }
    end

    function NLEntity:get_hitbox_position(idx)
        local x, y, z = entity.hitbox_position(self.__idx, idx)
        if not x then return nil end
        return { x = x, y = y, z = z }
    end

    function NLEntity:get_bone_position(idx)
        -- GS exposes no raw bones; hitbox is the closest proxy
        return self:get_hitbox_position(idx)
    end

    function NLEntity:get_xuid()        return entity.get_steam64(self.__idx) end
    function NLEntity:get_resource()    return wrap(entity.get_player_resource()) end
    function NLEntity:get_anim_state()  return {} end    -- no GS equivalent
    function NLEntity:get_anim_overlay() return {} end   -- no GS equivalent
    function NLEntity:simulate_movement() return nil end -- no GS equivalent

    --------------------------------------------------------------------
    -- Steam avatar via panorama JS
    -- Uses SteamAPI.GetMediumFriendAvatar(xuid) to get a panorama image
    -- path, then loads it through renderer.load_jpg into a texture ID.
    -- The result is cached per xuid so the JS roundtrip only happens once.
    --------------------------------------------------------------------

    local _avatar_cache   = {}  -- xuid -> texture id
    local _avatar_pending = {}  -- xuid -> true (waiting for JS callback)

    -- One-time panorama bridge: registers a global JS function
    -- __nl_ent_avatar_cb(xuid, dataurl) that Lua polls via a shared db key.
    local _avatar_bridge_init = false
    local function _init_avatar_bridge()
        if _avatar_bridge_init then return end
        _avatar_bridge_init = true
        panorama.loadstring([[
            // nl_ent avatar bridge
            if (!window.__nl_ent_avatar_fetch) {
                window.__nl_ent_avatar_fetch = function(xuid) {
                    // GetMediumFriendAvatar returns a panorama image path like
                    // 'avatar://steamid/<xuid>' which SetImage understands.
                    // We resolve it to a real URL via a hidden Image panel.
                    let img = $.CreatePanel('Image', $.GetContextPanel(), '__nl_ent_av_' + xuid)
                    img.style.visibility = 'collapse'
                    // SteamAPI.GetMediumFriendAvatar returns the avatar URL string
                    let url = SteamAPI.GetMediumFriendAvatar(xuid)
                    img.SetImage(url)
                    // After one frame the src attribute is populated with the real URL
                    $.Schedule(0.05, function() {
                        let src = img.src || url
                        img.DeleteAsync(0.0)
                        // Store result in panorama's persistent storage so Lua can read it
                        // via plist (GS exposes plist as a shared key-value store)
                        GameInterfaceAPI.SetSettingString('__nl_av_' + xuid, src)
                    })
                }
            }
        ]], 'CSGOHud')
    end

    function NLEntity:get_steam_avatar()
        local xuid = entity.get_steam64(self.__idx)
        if not xuid or xuid == '' then return nil end

        -- Return cached texture immediately if we have it
        if _avatar_cache[xuid] then return _avatar_cache[xuid] end

        _init_avatar_bridge()

        -- Kick off the JS fetch if not already pending
        if not _avatar_pending[xuid] then
            _avatar_pending[xuid] = true
            panorama.loadstring(
                'if(window.__nl_ent_avatar_fetch) window.__nl_ent_avatar_fetch("" + xuid + "")',
                'CSGOHud'
            )
        end

        -- Poll plist for the result (populated by JS after ~50ms)
        local url = plist.get('__nl_av_' .. xuid)
        if not url or url == '' then return nil end

        -- We have a URL — fetch the raw bytes and load as texture
        -- GS doesn't have http.get, so we use the panorama img src path directly.
        -- The path is either a file:// steam cache path or a https:// URL.
        -- Try io.open for local steam cache files (most common case).
        local tex_id = nil
        local local_path = url:match('^file://(.+)$')
        if local_path then
            local f = io.open(local_path, 'rb')
            if f then
                local data = f:read('*a')
                f:close()
                -- Steam avatars are JPG
                tex_id = renderer.load_jpg(data, 0, 0)
            end
        end

        if tex_id then
            _avatar_cache[xuid] = tex_id
            _avatar_pending[xuid] = nil
            -- Clean up plist key
            plist.set('__nl_av_' .. xuid, '')
        end

        return tex_id
    end

    --------------------------------------------------------------------
    -- set_icon via the scoreboard panorama JS bridge (from your script).
    -- Initialised lazily on first call, same lifecycle as the proximity lib.
    -- icon arg: panorama image path or URL string, nil to clear.
    --------------------------------------------------------------------

    local _icon_js = nil

    local function _init_icon_bridge()
        if _icon_js then return end
        _icon_js = panorama.loadstring([[
            let entity_panels = {}
            let entity_data = {}
            let event_callbacks = {}
            let SLOT_LAYOUT = `
                <root>
                    <Panel style='min-width: 3px; padding-top: 2px; padding-left: 0px;' scaling='stretch-to-fit-y-preserve-aspect'>
                        <Image id='smaller' textureheight='15' style='horizontal-align: center; opacity: 0.01; transition: opacity 0.1s ease-in-out 0.0s, img-shadow 0.12s ease-in-out 0.0s; overflow: noclip; padding: 3px 5px; margin: -3px -5px;' />
                        <Image id='small'   textureheight='17' style='horizontal-align: center; opacity: 0.01; transition: opacity 0.1s ease-in-out 0.0s, img-shadow 0.12s ease-in-out 0.0s; overflow: noclip; padding: 3px 5px; margin: -3px -5px;' />
                        <Image id='image'   textureheight='21' style='opacity: 0.01; transition: opacity 0.1s ease-in-out 0.0s, img-shadow 0.12s ease-in-out 0.0s; padding: 3px 5px; margin: -3px -5px; margin-top: -5px;' />
                    </Panel>
                </root>
            `
            let _DestroyEntityPanel = function(key) {
                let panel = entity_panels[key]
                if (panel != null && panel.IsValid()) {
                    let parent = panel.GetParent()
                    let musor = parent.GetChild(0)
                    musor.visible = true
                    if (parent.FindChildTraverse('id-sb-skillgroup-image') != null)
                        parent.FindChildTraverse('id-sb-skillgroup-image').style.margin = '0px 0px 0px 0px'
                    panel.DeleteAsync(0.0)
                }
                delete entity_panels[key]
            }
            let _DestroyEntityPanels = function() {
                for (let key in entity_panels) _DestroyEntityPanel(key)
            }
            let _GetOrCreateCustomPanel = function(xuid) {
                if (entity_panels[xuid] == null || !entity_panels[xuid].IsValid()) {
                    entity_panels[xuid] = null
                    let sb = $.GetContextPanel().FindChildTraverse('ScoreboardContainer')?.FindChildTraverse('Scoreboard')
                           || $.GetContextPanel().FindChildTraverse('id-eom-scoreboard-container')?.FindChildTraverse('Scoreboard')
                    if (sb == null) { _DestroyEntityPanels(); return }
                    sb.FindChildrenWithClassTraverse('sb-row').forEach(function(el) {
                        if (el.m_xuid != xuid) return
                        el.Children().forEach(function(child_frame) {
                            if (child_frame.GetAttributeString('data-stat', '') != 'rank') return
                            let scoreboard_el = child_frame.GetChild(0)
                            let parent = scoreboard_el.GetParent()
                            let custom_icons = $.CreatePanel('Panel', parent, 'revealer-icon')
                            if (parent.FindChildTraverse('id-sb-skillgroup-image') != null)
                                parent.FindChildTraverse('id-sb-skillgroup-image').style.margin = '0px 0px 0px 0px'
                            parent.MoveChildAfter(custom_icons, parent.GetChild(1))
                            parent.GetChild(0).visible = false
                            let slot_parent = $.CreatePanel('Panel', custom_icons, 'icon')
                            slot_parent.visible = false
                            slot_parent.BLoadLayoutFromString(SLOT_LAYOUT, false, false)
                            entity_panels[xuid] = custom_icons
                        })
                    })
                }
                return entity_panels[xuid]
            }
            let _UpdatePlayer = function(entindex, path_to_image) {
                if (entindex == null || entindex == 0) return
                entity_data[entindex] = { applied: false, image_path: path_to_image }
            }
            let _ClearPlayer = function(entindex) {
                if (entindex == null) return
                let xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex(entindex)
                _DestroyEntityPanel(xuid)
                delete entity_data[entindex]
            }
            let _ApplyPlayer = function(entindex) {
                let xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex(entindex)
                let panel = _GetOrCreateCustomPanel(xuid)
                if (panel == null) return
                let slot_parent = panel.FindChild('icon')
                slot_parent.visible = true
                let slot = slot_parent.FindChild('image')
                slot.visible = true
                slot.style.opacity = '1'
                slot.SetImage(entity_data[entindex].image_path)
                return true
            }
            let _ApplyData = function() {
                for (let entindex in entity_data) {
                    entindex = parseInt(entindex)
                    let xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex(entindex)
                    if (!entity_data[entindex].applied || entity_panels[xuid] == null || !entity_panels[xuid].IsValid()) {
                        if (_ApplyPlayer(entindex)) entity_data[entindex].applied = true
                    }
                }
            }
            let _Create = function() {
                event_callbacks['OnOpenScoreboard'] = $.RegisterForUnhandledEvent('OnOpenScoreboard', _ApplyData)
                event_callbacks['Scoreboard_UpdateEverything'] = $.RegisterForUnhandledEvent('Scoreboard_UpdateEverything', _ApplyData)
                event_callbacks['Scoreboard_UpdateJob'] = $.RegisterForUnhandledEvent('Scoreboard_UpdateJob', _ApplyData)
            }
            let _Clear = function() { entity_data = {} }
            let _Destroy = function() {
                _Clear()
                _DestroyEntityPanels()
                for (let event in event_callbacks) {
                    $.UnregisterForUnhandledEvent(event, event_callbacks[event])
                    delete event_callbacks[event]
                }
            }
            return {
                create:        _Create,
                destroy:       _Destroy,
                clear:         _Clear,
                update:        _UpdatePlayer,
                clear_player:  _ClearPlayer,
                destroy_panel: _DestroyEntityPanels
            }
        ]], 'CSGOHud')()
        _icon_js.create()
    end

    function NLEntity:set_icon(icon)
        _init_icon_bridge()
        if icon then
            _icon_js.update(self.__idx, icon)
        else
            _icon_js.clear_player(self.__idx)
        end
    end

    function NLEntity:get_spectators()
        local specs = {}
        for _, idx in ipairs(entity.get_all('CCSPlayer')) do
            local mode   = entity.get_prop(idx, 'm_iObserverMode')
            local target = entity.get_prop(idx, 'm_hObserverTarget')
            if mode and mode > 0 and target == self.__idx then
                table.insert(specs, wrap(idx))
            end
        end
        return specs
    end

    --------------------------------------------------------------------
    -- CCSWeaponInfo via FFI
    -- GetWpnData() is vtable index 446 on CBaseCombatWeapon in CS:GO.
    -- Returns a pointer to CCSWeaponInfo (weapon_info_t).
    --------------------------------------------------------------------

    local ffi = require('ffi')

    ffi.cdef[[
        typedef struct {
            char pad[0x014];            float max_player_speed;
            char pad2[0x004];           float max_player_speed_alt;
            char pad3[0x008];           float attack_move_speed_factor;
            char pad4[0x060];           float spread;
            float spread_alt;
            float inaccuracy_crouch;    float inaccuracy_crouch_alt;
            float inaccuracy_stand;     float inaccuracy_stand_alt;
            float inaccuracy_jump_initial;
            float inaccuracy_jump_apex;
            float inaccuracy_jump;      float inaccuracy_jump_alt;
            float inaccuracy_land;      float inaccuracy_land_alt;
            float inaccuracy_ladder;    float inaccuracy_ladder_alt;
            float inaccuracy_fire;      float inaccuracy_fire_alt;
            float inaccuracy_move;      float inaccuracy_move_alt;
            float inaccuracy_reload;
            int   recoil_seed;
            float recoil_angle;         float recoil_angle_alt;
            float recoil_angle_variance; float recoil_angle_variance_alt;
            float recoil_magnitude;     float recoil_magnitude_alt;
            float recoil_magnitude_variance; float recoil_magnitude_variance_alt;
            int   spread_seed;
            char pad5[0x04C];
            float recovery_time_crouch; float recovery_time_stand;
            float recovery_time_crouch_final; float recovery_time_stand_final;
            int   recovery_transition_start_bullet;
            int   recovery_transition_end_bullet;
            char pad6[0x01C];
            bool  full_auto;
            char pad7[0x003];
            int   damage;
            float headshot_multiplier;
            float armor_ratio;
            int   bullets;
            float penetration;
            char pad8[0x008];
            float range;
            float range_modifier;
            char pad9[0x010];
            bool  has_silencer;
            char pad10[0x00F];
            int   weapon_type;
            char pad11[0x024];
            float cycle_time;
            float cycle_time_alt;
            char pad12[0x00C];
            int   max_clip1;
            int   max_clip2;
            char pad13[0x038];
            int   weapon_price;
            int   kill_award;
            char pad14[0x004];
            float throw_velocity;
            char pad15[0x00C];
            bool  has_burst_mode;
        } CCSWeaponInfo;

        typedef CCSWeaponInfo* (__thiscall* GetWpnData_t)(void*);
    ]]

    -- Cache GetWpnData per weapon entindex to avoid re-casting every frame
    local _wpndata_cache = {}

    local function get_weapon_data_ptr(wpn_idx)
        if _wpndata_cache[wpn_idx] then return _wpndata_cache[wpn_idx] end

        -- vtable_bind pattern: cast entindex ptr, grab vtable[446]
        local ok, ptr = pcall(function()
            local ent_ptr = ffi.cast('void***', client.get_entity_from_handle and
                client.get_entity_from_handle(wpn_idx) or
                -- fallback: read m_pEntity from entindex via GS internal
                ffi.cast('uintptr_t*',
                    ffi.cast('uintptr_t',
                        client.create_interface('client_panorama.dll', 'VClientEntityList003')
                    )
                )[0]
            )
            local vtable  = ent_ptr[0]
            local fn      = ffi.cast('GetWpnData_t', vtable[446])
            return fn(ent_ptr)
        end)

        if ok and ptr ~= nil then
            _wpndata_cache[wpn_idx] = ptr
        end
        return ok and ptr or nil
    end

    -- Map CCSWeaponInfo struct fields → NL key names
    local function wpndata_to_table(p)
        if not p then return {} end
        return {
            max_player_speed              = p.max_player_speed,
            max_player_speed_alt          = p.max_player_speed_alt,
            attack_move_speed_factor      = p.attack_move_speed_factor,
            spread                        = p.spread,
            spread_alt                    = p.spread_alt,
            inaccuracy_crouch             = p.inaccuracy_crouch,
            inaccuracy_crouch_alt         = p.inaccuracy_crouch_alt,
            inaccuracy_stand              = p.inaccuracy_stand,
            inaccuracy_stand_alt          = p.inaccuracy_stand_alt,
            inaccuracy_jump_initial       = p.inaccuracy_jump_initial,
            inaccuracy_jump_apex          = p.inaccuracy_jump_apex,
            inaccuracy_jump               = p.inaccuracy_jump,
            inaccuracy_jump_alt           = p.inaccuracy_jump_alt,
            inaccuracy_land               = p.inaccuracy_land,
            inaccuracy_land_alt           = p.inaccuracy_land_alt,
            inaccuracy_ladder             = p.inaccuracy_ladder,
            inaccuracy_ladder_alt         = p.inaccuracy_ladder_alt,
            inaccuracy_fire               = p.inaccuracy_fire,
            inaccuracy_fire_alt           = p.inaccuracy_fire_alt,
            inaccuracy_move               = p.inaccuracy_move,
            inaccuracy_move_alt           = p.inaccuracy_move_alt,
            inaccuracy_reload             = p.inaccuracy_reload,
            recoil_seed                   = p.recoil_seed,
            recoil_angle                  = p.recoil_angle,
            recoil_angle_alt              = p.recoil_angle_alt,
            recoil_angle_variance         = p.recoil_angle_variance,
            recoil_angle_variance_alt     = p.recoil_angle_variance_alt,
            recoil_magnitude              = p.recoil_magnitude,
            recoil_magnitude_alt          = p.recoil_magnitude_alt,
            recoil_magnitude_variance     = p.recoil_magnitude_variance,
            recoil_magnitude_variance_alt = p.recoil_magnitude_variance_alt,
            spread_seed                   = p.spread_seed,
            recovery_time_crouch          = p.recovery_time_crouch,
            recovery_time_stand           = p.recovery_time_stand,
            recovery_time_crouch_final    = p.recovery_time_crouch_final,
            recovery_time_stand_final     = p.recovery_time_stand_final,
            recovery_transition_start_bullet = p.recovery_transition_start_bullet,
            recovery_transition_end_bullet   = p.recovery_transition_end_bullet,
            full_auto                     = p.full_auto,
            damage                        = p.damage,
            headshot_multiplier           = p.headshot_multiplier,
            armor_ratio                   = p.armor_ratio,
            bullets                       = p.bullets,
            penetration                   = p.penetration,
            range                         = p.range,
            range_modifier                = p.range_modifier,
            has_silencer                  = p.has_silencer,
            weapon_type                   = p.weapon_type,
            cycle_time                    = p.cycle_time,
            cycle_time_alt                = p.cycle_time_alt,
            max_clip1                     = p.max_clip1,
            max_clip2                     = p.max_clip2,
            weapon_price                  = p.weapon_price,
            kill_award                    = p.kill_award,
            throw_velocity                = p.throw_velocity,
            has_burst_mode                = p.has_burst_mode,
        }
    end

    --------------------------------------------------------------------
    -- Weapon icon via panorama/images path + renderer.load_png
    -- CS:GO stores weapon icons at:
    --   csgo/panorama/images/icons/equipment/<weapon_name>.png
    -- We derive the name from the classname (e.g. CWeaponAK47 -> weapon_ak47)
    --------------------------------------------------------------------

    -- classname -> icon filename mapping for edge cases
    local _icon_name_overrides = {
        CKnife            = 'weapon_knife',
        CKnifeGG          = 'weapon_knife',
        CDEagle           = 'weapon_deagle',
        CAK47             = 'weapon_ak47',
        CC4               = 'weapon_c4',
        CBaseCSGrenade    = 'weapon_flashbang',
        CDecoyGrenade     = 'weapon_decoy',
        CFlashbang        = 'weapon_flashbang',
        CHEGrenade        = 'weapon_hegrenade',
        CIncendiaryGrenade= 'weapon_incgrenade',
        CMolotovGrenade   = 'weapon_molotov',
        CSmokeGrenade     = 'weapon_smokegrenade',
    }

    local _icon_texture_cache = {}

    local function weapon_classname_to_iconname(classname)
        if not classname then return nil end
        if _icon_name_overrides[classname] then
            return _icon_name_overrides[classname]
        end
        -- CWeaponAK47 -> weapon_ak47 etc.
        local name = classname:match('^CWeapon(.+)$')
        if name then
            return 'weapon_' .. name:lower()
        end
        return nil
    end

    --------------------------------------------------------------------
    -- Weapon methods
    --------------------------------------------------------------------

    function NLEntity:get_weapon_index()
        return entity.get_prop(self.__idx, 'm_iItemDefinitionIndex')
    end

    function NLEntity:get_weapon_owner()
        return wrap(entity.get_prop(self.__idx, 'm_hOwnerEntity'))
    end

    function NLEntity:get_weapon_reload()
        local activity = entity.get_prop(self.__idx, 'm_iActivity')
        if activity == 967 then  -- ACT_VM_RELOAD
            return entity.get_prop(self.__idx, 'm_flReloadTime') or -1
        end
        return -1
    end

    function NLEntity:get_max_speed()
        local ptr = get_weapon_data_ptr(self.__idx)
        if ptr then return ptr.max_player_speed end
        return entity.get_prop(self.__idx, 'm_flMaxspeed')
    end

    function NLEntity:get_spread()
        local ptr = get_weapon_data_ptr(self.__idx)
        if ptr then return ptr.spread end
        return entity.get_prop(self.__idx, 'm_fAccuracyPenalty') or 0
    end

    function NLEntity:get_inaccuracy()
        return entity.get_prop(self.__idx, 'm_fAccuracyPenalty') or 0
    end

    function NLEntity:get_weapon_info()
        return wpndata_to_table(get_weapon_data_ptr(self.__idx))
    end

    -- Returns a renderer texture ID (number) loaded from the weapon's PNG icon,
    -- or nil on failure. Cache is keyed by classname so it only reads the file once.
    function NLEntity:get_weapon_icon()
        local cn = entity.get_classname(self.__idx)
        if not cn then return nil end

        if _icon_texture_cache[cn] then
            return _icon_texture_cache[cn]
        end

        local icon_name = weapon_classname_to_iconname(cn)
        if not icon_name then return nil end

        -- CS:GO panorama icon path (relative to game root)
        local path = 'csgo/panorama/images/icons/equipment/' .. icon_name .. '.png'

        local ok, contents = pcall(function()
            -- GS exposes file reads via the filesystem interface.
            -- Use the gamesense/files built-in if available, else io.open fallback.
            if files and files.read then
                return files.read(path)
            end
            -- io.open fallback (works when script runs with file access)
            local f = io.open(path, 'rb')
            if not f then return nil end
            local data = f:read('*a')
            f:close()
            return data
        end)

        if not ok or not contents or contents == '' then return nil end

        -- We don't know the dimensions ahead of time; pass 0,0 and let GS decode
        local tex_id = renderer.load_png(contents, 0, 0)
        if tex_id then
            _icon_texture_cache[cn] = tex_id
        end
        return tex_id
    end

    return M
end

local ffi,
      network,
      pui,
      vector,
      base64,
      clipboard,
      json,
      bit32,
      entity = require 'ffi',
            require 'gamesense/http',
            require 'gamesense/pui',
            require 'vector',
            require 'gamesense/base64',
            require 'gamesense/clipboard',
            require 'json',
            require 'bit',
            require 'nl_ent'


local events = setmetatable({ }, {
    __index = function(event)
        return {
            set = function(callback)
                client.set_event_callback(tostring(event), function(...) callback(...) end)
            end,
            unset = function()
                client.unset_event_callback(tostring(event))
            end,
            fire = function(data)
                client.fire_event(tostring(event), data)
            end
        }
    end
})

local color_mt, color, colors = { }, { }, { }; do
    
    function color_mt:init(r, g, b, a)
        self.r = math.floor(r or 255)
        self.g = math.floor(g or 255)
        self.b = math.floor(b or 255)
        self.a = math.floor(a or 255)
        self.r = math.max(0, math.min(255, self.r))
        self.g = math.max(0, math.min(255, self.g))
        self.b = math.max(0, math.min(255, self.b))
        self.a = math.max(0, math.min(255, self.a))
        return self
    end
    function color_mt:as_fraction(r, g, b, a)
        self.r = math.floor((r or 1) * 255)
        self.g = math.floor((g or 1) * 255)
        self.b = math.floor((b or 1) * 255)
        self.a = math.floor((a or 1) * 255)
        self.r = math.max(0, math.min(255, self.r))
        self.g = math.max(0, math.min(255, self.g))
        self.b = math.max(0, math.min(255, self.b))
        self.a = math.max(0, math.min(255, self.a))
        return self
    end
    function color_mt:to_hex()
        return string.format('%02X%02X%02X%02X', self.r, self.g, self.b, self.a)
    end
    function color_mt:unpack()
        return self.r, self.g, self.b, self.a
    end
    function color_mt:get_fraction()
        return self.r / 255, self.g / 255, self.b / 255, self.a / 255
    end
    function color_mt:__tostring()
        return string.format('color(%d, %d, %d, %d)', self.r, self.g, self.b, self.a)
    end
    function color_mt:__eq(other)
        return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a
    end

    color = setmetatable({ }, {
        __call = function(cls, ...)
            local self = setmetatable({}, color_mt)
            local args = { ... }

            if #args == 0 then
                self.r, self.g, self.b, self.a = 255, 255, 255, 255
            elseif #args == 1 and type(args[1]) == 'string' then
                local hex = args[1]:gsub('#', '')

                if #hex == 3 then
                    -- RGB shorthand (e.g., 'F00')
                    self.r = tonumber(hex:sub(1,1) .. hex:sub(1,1), 16) or 255
                    self.g = tonumber(hex:sub(2,2) .. hex:sub(2,2), 16) or 255
                    self.b = tonumber(hex:sub(3,3) .. hex:sub(3,3), 16) or 255
                    self.a = 255
                elseif #hex == 6 then
                    -- RRGGBB format
                    self.r = tonumber(hex:sub(1,2), 16) or 255
                    self.g = tonumber(hex:sub(3,4), 16) or 255
                    self.b = tonumber(hex:sub(5,6), 16) or 255
                    self.a = 255
                elseif #hex == 8 then
                    -- RRGGBBAA format
                    self.r = tonumber(hex:sub(1,2), 16) or 255
                    self.g = tonumber(hex:sub(3,4), 16) or 255
                    self.b = tonumber(hex:sub(5,6), 16) or 255
                    self.a = tonumber(hex:sub(7,8), 16) or 255
                else
                    self.r, self.g, self.b, self.a = 255, 255, 255, 255
                end
            elseif #args == 1 and type(args[1]) == 'number' then
                -- color(233) => 233, 233, 233, 233
                local val = math.floor(args[1])
                self.r, self.g, self.b, self.a = val, val, val, val
            elseif #args == 2 then
                -- color(242, 255) => 242, 242, 242, 255
                local val, alpha = math.floor(args[1]), math.floor(args[2])
                self.r, self.g, self.b, self.a = val, val, val, alpha
            elseif #args == 3 then
                -- color(133, 25, 92) => 133, 25, 92, 255
                self.r, self.g, self.b, self.a = math.floor(args[1]), math.floor(args[2]), math.floor(args[3]), 255
            elseif #args == 4 then
                self.r, self.g, self.b, self.a = math.floor(args[1]), math.floor(args[2]), math.floor(args[3]), math.floor(args[4])
            elseif #args >= 4 then
                debug(nil, 'Too many arguments!')
            end
        end
    })

    colors = {
        format = function(str, clr)
            if not clr then
                clr = pui.accent()
            else
                if type(clr) == 'string' then
                    clr = clr
                elseif type(clr) == 'table' then
                    clr = clr.to_hex and clr:to_hex() or string.format('%02X%02X%02X%02X', clr[1], clr[2], clr[3], clr[4] and clr[4] or 255)
                end
            end
            
            return (str:gsub('${%w+}', function(key)
                return string.format('\a%s%s\aFFFFFFFF', clr, key)
            end))
        end
    }

    string.upper_first = function(str)
        return (str:gsub('^%l', string.upper))
    end
end

local software = { }; do
    software.name = 'nocturnal.club'
    software.username = _USER_NAME or 'author'
    software.build = 'beta'
    software.states = {
        'Global',
        'Standing',
        'Moving',
        'Slow walking',
        'Air',
        'Air crouch',
        'Crouch',
        'Crouch move',
        'Freestanding',
        'Manual yaw',
        'Safe head'
    }

    local me = entity.get_local_player()
end

local menu, group, reference, utils = { }, { }, { }, { }; do
    group = {
        aa = pui.group('aa', 'anti-aimbot angles'),
        fl = pui.group('aa', 'fake lag'),
        ot = pui.group('aa', 'other')
    }

    utils = {        
        rgb_to_hex = function (color)
            return string.format('%02X%02X%02X%02X', color[1], color[2], color[3], color[4] or 255)
        end,

        hex_to_rgb = function (hex)
            hex = hex:gsub('^#', '')
            return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16) or 255
        end,
        
        gradient_text = function (text, colors, precision)
            local symbols, length = {}, #string.gsub(text, '.[\128-\191]*', 'a')
            local s = 1 / (#colors - 1)
            precision = precision or 1
    
            local i = 0
            for letter in string.gmatch(text, '.[\128-\191]*') do
                i = i + 1
    
                local weight = i / length
                local cw = weight / s
                local j = math.ceil(cw)
                local w = (cw / j)
                local L, R = colors[j], colors[j+1]
    
                local r = L[1] + (R[1] - L[1]) * w
                local g = L[2] + (R[2] - L[2]) * w
                local b = L[3] + (R[3] - L[3]) * w
                local a = L[4] + (R[4] - L[4]) * w
    
                symbols[#symbols+1] = ((i-1) % precision == 0) and ('\a%02x%02x%02x%02x%s'):format(r, g, b, a, letter) or letter
            end
    
            symbols[#symbols+1] = '\aCDCDCDFF'
    
            return table.concat(symbols)
        end
    }

    reference = {
        aimbot = {
            enabled = {pui.reference('rage', 'aimbot', 'enabled')},
            hitbox = pui.reference('rage', 'aimbot', 'target hitbox'),
            multi_point = pui.reference('rage', 'aimbot', 'multi-point scale'),
            hit_chance = pui.reference('rage', 'aimbot', 'minimum hit chance'),
            stop = {pui.reference('rage', 'aimbot', 'quick stop')},
            double_tap = {pui.reference('rage', 'aimbot', 'double tap')},
            accuracy = pui.reference('rage', 'other', 'accuracy boost'),
            delay_shot = pui.reference('rage', 'other', 'delay shot'),
            fake_duck = pui.reference('rage', 'other', 'duck peek assist')
        },
        antiaim = {
            angles = {
                enabled = pui.reference('aa', 'anti-aimbot angles', 'enabled'),
                pitch = {pui.reference('aa', 'anti-aimbot angles', 'pitch')},
                yaw_base = pui.reference('aa', 'anti-aimbot angles', 'yaw base'),
                yaw = {pui.reference('aa', 'anti-aimbot angles', 'yaw')},
                yaw_jitter = {pui.reference('aa', 'anti-aimbot angles', 'yaw jitter')},
                body_yaw = {pui.reference('aa', 'anti-aimbot angles', 'body yaw')},
                edge_yaw = pui.reference('aa', 'anti-aimbot angles', 'edge yaw'),
                freestand_body = pui.reference('aa', 'anti-aimbot angles', 'freestanding body yaw'),
                freestanding = {pui.reference('aa', 'anti-aimbot angles', 'freestanding')},
                roll = pui.reference('aa', 'anti-aimbot angles', 'roll'),
                edge = pui.reference('aa', 'anti-aimbot angles', 'edge yaw')
            },
    
            fakelag = {
                enabled = {pui.reference('aa', 'fake lag', 'enabled')},
                amount = pui.reference('aa', 'fake lag', 'amount'),
                variance = pui.reference('aa', 'fake lag', 'variance'),
                limit = pui.reference('aa', 'fake lag', 'limit')
            },
            
            other = {
                slow_motion = {pui.reference('aa', 'other', 'slow motion')},
                legs = pui.reference('aa', 'other', 'leg movement'),
                hide_shots = {pui.reference('aa', 'other', 'on shot anti-aim')},
                fakepeek = {pui.reference('aa', 'other', 'fake peek')}
            }
        },
        visuals = {
            indicators = pui.reference('visuals', 'other esp', 'feature indicators'),
            props = pui.reference('visuals', 'effects', 'transparent props'),
            overlay = pui.reference('visuals', 'effects', 'remove scope overlay')
        },
        misc = {
            zoom_fov = pui.reference('misc', 'miscellaneous', 'override zoom fov'),
            clantag = pui.reference('misc', 'miscellaneous', 'clan tag spammer'),
            ping = {pui.reference('misc', 'miscellaneous', 'ping spike')},
            console = pui.reference('misc', 'miscellaneous', 'draw console output'),
            color = pui.reference('misc', 'settings', 'menu color')
        }
    }

    pui.macros.child = '\v⌁\r'

    menu = {
        home = {
            main = group.fl:combobox(
                '\f<child> nocturnal.\v' .. (software.build:lower() == 'beta' and 'lc' or 'club'), {
                    'Main',
                    'Anti-aimbot',
                    'Other'
                }
            )
        },
        antiaim = {
            main = group.fl:combobox(
                '\n>.<', {
                    'Builder',
                    'Defensive',
                    'Other'
                }
            ),
            other = {
                freestanding = {
                    switch = group.aa:checkbox(
                        'Freestanding on Auto Peek'
                    ),
                    disablers = group.aa:multiselect(
                        '\f<child> Disablers', software.states
                    )
                },
                manual = {
                    switch = group.aa:checkbox(
                        'Manual yaw'
                    ),
                    left = group.aa:hotkey(
                        '\f<child> Left'
                    ),
                    right = group.aa:hotkey(
                        '\f<child> Right'
                    ),
                    forward = group.aa:hotkey(
                        '\f<child> Forward'
                    )
                },
                edge = {
                    switch
                }
            }
        }
    }
end

local main_visibility, menu_visibility, is_home_tab, is_antiaim_tab, is_other_tab, is_builder_tab, is_defensive_tab; do
    main_visibility = (function(tabs, visibility)
        local aa, fl, ot = reference.antiaim.angles, reference.antiaim.fakelag, reference.antiaim.other

        if tabs:find('antiaim') then
            aa.enabled:set_visible(visibility)
            aa.pitch[1]:set_visible(visibility)
            aa.pitch[2]:set_visible(visibility)
            aa.yaw_base:set_visible(visibility)
            aa.yaw[1]:set_visible(visibility)
            aa.yaw[2]:set_visible(visibility)
            aa.yaw_jitter[1]:set_visible(visibility)
            aa.yaw_jitter[2]:set_visible(visibility)
            aa.body_yaw[1]:set_visible(visibility)
            aa.body_yaw[2]:set_visible(visibility)
            aa.freestand_body:set_visible(visibility)
            aa.freestanding[1]:set_visible(visibility)
            aa.freestanding[1].hotkey:set_visible(visibility)
            aa.roll:set_visible(visibility)
            aa.edge:set_visible(visibility)
        end
        if tabs:find('fakelag') then
            fl.enabled[1]:set_visible(visibility)
            fl.enabled[1].hotkey:set_visible(visibility)
            fl.amount:set_visible(visibility)
            fl.variance:set_visible(visibility)
            fl.limit:set_visible(visibility)
        end
        if tabs:find('other') then
            ot.slow_motion[1]:set_visible(visibility)
            ot.slow_motion[1].hotkey:set_visible(visibility)
            ot.legs:set_visible(visibility)
            ot.hide_shots[1]:set_visible(visibility)
            ot.hide_shots[1].hotkey:set_visible(visibility)
            ot.fakepeek[1]:set_visible(visibility)
            ot.fakepeek[1].hotkey:set_visible(visibility)
        end
    end)('antiaim, fakelag', false)

    events.shutdown:set(function()
        main_visibility('antiaim, fakelag, other', true)
    end)

    is_home_tab      = {menu.home.main, 'Main'}
    is_antiaim_tab   = {menu.home.main, 'Anti-aimbot'}
    is_other_tab     = {menu.home.main, 'Other'}

    is_other_tab     = {menu.antiaim.main, 'Other'}
    is_builder_tab   = {menu.antiaim.main, 'Builder'}
    is_defensive_tab = {menu.antiaim.main, 'Defensive'}

    menu_visibility = function()
        local aa = menu.antiaim

        aa.main:depend({menu.home.main, 'Anti-aimbot'})

        aa.other.freestanding.switch:depend(is_antiaim_tab, is_other_tab)
        aa.other.freestanding.disablers:depend(is_antiaim_tab, is_other_tab, {aa.other.freestanding.switch, true})
        
        aa.other.manual.switch:depend(is_antiaim_tab, is_other_tab)
        aa.other.manual.left:depend(is_antiaim_tab, is_other_tab, {aa.other.manual.switch, true})
        aa.other.manual.right:depend(is_antiaim_tab, is_other_tab, {aa.other.manual.switch, true})
        aa.other.manual.forward:depend(is_antiaim_tab, is_other_tab, {aa.other.manual.switch, true})
    end
end

local antiaim, builder = { }, { }; do

    local function normalize(min, max, val)
        if val <= min then
            return min
        elseif val >= max then
            return max
        end
        return val
    end

    antiaim.states = software.states

    builder.selector = group.aa:combobox(
        '\v{ ~ }\r Condition', antiaim.states
    ):depend(is_antiaim_tab, is_builder_tab)

    for _, state in ipairs(antiaim.states) do
        builder[state] = {
            switch = state ~= 'Global' and group.aa:checkbox('Enable \v' .. state) or nil,
            yaw_type = group.aa:combobox('Yaw · \vType', {
                'L&R',
                'L&R Delayed'
            }),
            yaw_left = group.aa:slider('Yaw · \vLeft', 
                -180, 180, 0, true, '°'
            ),
            yaw_right = group.aa:slider('Yaw · \vRight',
                -180, 180, 0, true, '°'    
            ),
            yaw_randomization = group.aa:slider('Yaw · \vRandomize', 
                0, 100, 0, true, '%'
            ),
            delay = { }, -- soon
            jitter = group.aa:combobox('Jitter · \vType', {
                'Off',
                'Center',
                'Offset',
                'Random',
                'Skitter'
            }),
            jitter_offset = group.aa:slider('Jitter · \vOffset',
                -180, 180, 0, true, '°'
            ),
            jitter_randomization = group.aa:slider('Jitter · \vRandomize',
                -180, 180, 0, true, '°'
            ),
            body_yaw = group.aa:checkbox('Body · \vYaw'),
            body_yaw_options = group.aa:multiselect('Options', {
                'Jitter',
                'Randomize Jitter'
            }),
            body_yaw_mode = group.aa:combobox('Desync · \vMode', {
                'Static',
                'L&R'
            }),
            body_yaw_value = group.aa:slider('Desync · \vAmount',
                0, 58, 0, true, '°'
            )
        }

        is_current_state = {builder.selector, state}

        if builder[state].switch then
            builder[state].switch:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        end

        builder[state].yaw_type:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].yaw_left:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].yaw_right:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].yaw_randomization:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].jitter:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].jitter_offset:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].jitter_randomization:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].body_yaw:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].body_yaw_options:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].body_yaw_mode:depend(is_antiaim_tab, is_builder_tab, is_current_state)
        builder[state].body_yaw_value:depend(is_antiaim_tab, is_builder_tab, is_current_state)
    end

    antiaim.__state = function()
        if not entity.is_alive(me) then
            return 'Global'
        end

        local last_tick = globals.tickcount()

        local velocity = vector(entity.get_prop(me, 'm_vecVelocity')):length2d()
        local duck = entity.get_prop(me, 'm_flDuckAmount') > 0
        local in_air = bit32.band(entity.get_prop(me, 'm_iFlags'), 1) == 0

        local state, was_in_air = (velocity > 1.5 and 'Moving' or 'Standing'), false;

        if globals.tickcount() ~= last_tick then
            was_in_air = in_air
            last_tick = globals.tickcount()
        end

        if in_air or was_in_air then
            state = duck and 'Air crouch' or 'Air'
        elseif velocity > 1.5 and duck then
            state = 'Crouch'
        elseif reference.antiaim.other.slow_motion[1]:get() and reference.antiaim.other.slow_motion[1].hotkey:get() then
            state = 'Slow walking'
        elseif duck then
            return 'Crouch'
        end
    end

    antiaim.get_state = function()
        local __state = self:__state()
        local tab = menu.antiaim.other
        local manual = (function()
            return false --soon
        end)()

        if tab.freestanding.switch:get() and not manual then
            if not tab.freestanding.disablers[__state] and builder['Freestanding'].switch:get() then
                reference.antiaim.angles.freestanding[1]:override(true)
                reference.antiaim.angles.freestanding[1].hotkey:override('Always on')

                return 'Freestanding'
            else
                reference.antiaim.angles.freestanding[1]:override(false)
                reference.antiaim.angles.freestanding[1].hotkey:override()
            end
        elseif manual then
            return 'Manual yaw'
        else
            local switch = builder[__state].switch
            if switch ~= nil and switch:get() then
                return __state
            else
                return 'Global'
            end
        end
    end

    builder.listen = function(cmd)
        local state = antiaim.get_state()
    end

    builder.handle = function(cmd)

    end

    events.setup_command:set(function(cmd)
        builder.handle(cmd)
    end)
end
