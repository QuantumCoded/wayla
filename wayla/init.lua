---@diagnostic disable:undefined-global
---@diagnostic disable:lowercase-global

wayla = {
    players = {},
    elements = {},
    providers = {},
    order = {},
    needs_update = {},
}

local function ordered_elements()
    -- TODO make this work
end

local tx = RuntimeTranslator(96)

local function split_measure(measure)
    if measure then
        return string.match(measure, "^(-?[0-9.]+)([icpdbs]?)$")
    end
end

function wayla.draw(player, context)
    local name = player:get_player_name()

    wayla.players[name].show = true

    for element_name, element in pairs(wayla.elements) do
        local providers = {}

        for _, provider in ipairs(element.providers) do
            table.insert(providers, wayla.providers[provider])
        end

        -- can make this a gate if
        if wayla.needs_update[element_name] then
            wayla.needs_update[element_name] = false

            element.content, element.height =
                element.make_content(providers, context)
        end
    end

    local height = 0.5
    local y_offset = 0.25
    local content = {}

    for _, element_name in ipairs(wayla.order) do
        local element = wayla.elements[element_name]
        local element_content = element.content

        if not element_content then
            break
        end

        local element_height = tx.units.get_y(split_measure(element.height))

        local container = {
            type = "container",
            x = "0.25c",
            y = y_offset .. "c",
        }

        for _, node in ipairs(element_content) do
            table.insert(container, node)
        end

        height = height + element_height
        y_offset = y_offset + element_height + 0.1

        table.insert(content, container)
    end

    height = height + (#wayla.order - 1) * 0.1

    local tree = {
        { type = "size", w = "8.5c", h = height .. "c" },
        { type = "anchor", x = 0.5, y = 0 },
        { type = "position", x = 0.5, y = 0.01 },
        { type = "padding", x = 0, y = 0 },
        {
            type = "box",
            x = 0,
            y = 0,
            w = "8.5c",
            h = height .. "c",
            color = "#000C",
        },
    }

    for _, node in ipairs(content) do
        table.insert(tree, node)
    end

    local formspec = formspec_ast.unparse(tree)
    formspec = string.gsub(formspec, "container%[", "margin[")
    formspec = string.gsub(formspec, "container_end%[", "margin_end[")
    formspec = scarlet.translate_96dpi(formspec)

    hud_fs.show_hud(player, "wayla", formspec)
end

function wayla.get_pointed_pos(player)
    local eye_height = player:get_properties().eye_height

    local start_pos =
        player:get_pos()
        + vector.new(0, eye_height, 0)
        + player:get_eye_offset()

    local node_name = minetest.get_node(start_pos).name
    local in_liquid = minetest.registered_nodes[node_name].drawtype == "liquid"

    local tool_range =
        player:get_wielded_item():get_definition().range
        or minetest.registered_items[""].range
        or 5

    local end_pos = start_pos + player:get_look_dir() * tool_range

    local ray = minetest.raycast(
        start_pos,
        end_pos,
        false,
        not in_liquid
    ):next()

    if not ray then
        return
    end

    return ray.under
end



-- Registers a Wayla HUD element with a unique name.
-- make_element is a function that returns a Flow element to add to the HUD.
--  {
--      make_content,
--      single_provider,
--      order, TODO
--  }
function wayla.register_element(name, element)
    if wayla.elements[name] then
        minetest.log(
            "error",
            "[wayla:register_element] Attempted to register multiple elements "
            .. "with the same name '"
            .. name
            .. "'."
        )
        return
    end

    if not element.make_content then
        minetest.log(
            "warning",
            "[wayla:register_provider] Skipping element '"
            .. name
            .. "' because the make_content function was not specified."
        )
        return
    end

    -- order should be generated here on element register
    table.insert(wayla.order, name)

    element.providers = {}
    wayla.elements[name] = element
    wayla.needs_update[name] = true
end
--  {
--      element,
--      get_data,
--      title,
--      function should_update(pos, node),
--  }

--- @class Provider 

---Register a function that given a node can provide data for an element.
---If two or more providers are registered to the same element, the element is
---expected to handle this, unless it uses `single_provider`.
---This will fail if no element by the specified `element_name` exists.
---@param name string The name of the provider
---@param provider { element: string, get_data: function, title: string?, show_title: boolean?, should_update: function? } The provider table
---If `should_update` exists and returns `true` then `get_data` will be
---called, and the data it returns will be rendered in a way specified by the
---element. Therefore the parameters and return type of `get_data` also depend
---on the target element. 
function wayla.register_provider(name, provider)
    --- Element
    local element = provider.element

    if wayla.providers[name] then
        minetest.log(
            "error",
            "[wayla:register_provider] Attempted to register multiple providers "
            .. "with the same name '"
            .. name
            .. "'."
        )
        return
    end

    if not wayla.elements[element] then
        minetest.log(
            "warning",
            "[wayla:register_provider] Skipping provider '"
            .. name
            .. "' because element '"
            .. element
            .. "' has not been registered."
        )
        return
    end

    if not provider.get_data then
        minetest.log(
            "warning",
            "[wayla:register_provider] Skipping provider '"
            .. name
            .. "' because the get_data function was not specified."
        )
        return
    end

    if
        wayla.elements[element].single_provider
        and #wayla.elements[element].providers == 1
    then
        minetest.log(
            "error",
            "[wayla:register_provider] Attempt to register multiple providers "
            .. "for single_provider element. Provider '"
            .. name
            .. "' cannot be registered because provider '"
            .. wayla.elements[element].providers[1]
            .. "' has already been registered."
        )
        return
    end

    wayla.providers[name] = provider

    -- this should also allow order
    table.insert(wayla.elements[element].providers, name)
end

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    if not wayla.players[name] then
        wayla.players[name] = {
            enable = true,
            show = false,
            player = player,
        }
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()

    if wayla.players[name] ~= nil then
        wayla.players[name] = nil
    end
end)

minetest.register_chatcommand("wayla", {
    func = function(name)
        local player = wayla.players[name]
        player.enable = not player.enable

        if
            not player.enable
            and player.show
        then
            hud_fs.close_hud(minetest.get_player_by_name(name), "wayla")
            player.show = false
        end
    end
})

minetest.register_globalstep(function()
    for name, wayla_player in pairs(wayla.players) do
        if not wayla_player.enable then
            break
        end

        local player = wayla_player.player
        local meta = player:get_meta()
        local pointed_pos = wayla.get_pointed_pos(player)

        if not pointed_pos then
            if wayla.players[name].show then
                hud_fs.close_hud(player, "wayla")
                wayla.players[name].show = false
            end

            meta:set_string("wayla:pointed_node", "ignore")
            meta:set_int("wayla:pointed_x", 0)
            meta:set_int("wayla:pointed_y", 0)
            meta:set_int("wayla:pointed_z", 0)
            return
        end

        local pointed_node = minetest.get_node(pointed_pos)
        local node_name = pointed_node.name
        local needs_update = false

        local context = {
            pos = pointed_pos,
            node = pointed_node,
            player = player,
        }

        -- check if a provider has updates for an element
        for _, provider in pairs(wayla.providers) do
            if
                provider.should_update
                and provider.should_update(context)
            then
                needs_update = true
                wayla.needs_update[provider.element] = true
            end
        end

        -- if the player looks somewhere/at something else update all elements
        if
            meta:get_string("wayla:pointed_node") ~= node_name
            or meta:get_int("wayla:pointed_x") ~= pointed_pos.x
            or meta:get_int("wayla:pointed_y") ~= pointed_pos.y
            or meta:get_int("wayla:pointed_z") ~= pointed_pos.z
        then
            needs_update = true
            for element_name, _ in pairs(wayla.elements) do
                wayla.needs_update[element_name] = true
            end
        end

        -- don't update if not needed
        if
            not needs_update
            and wayla.players[name].show
        then
            return
        end

        -- update metadata to store last updated node's info
        meta:set_string("wayla:pointed_node", node_name)
        meta:set_int("wayla:pointed_x", pointed_pos.x)
        meta:set_int("wayla:pointed_y", pointed_pos.y)
        meta:set_int("wayla:pointed_z", pointed_pos.z)

        wayla.draw(player, context)
    end
end)
