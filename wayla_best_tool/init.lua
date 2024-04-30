---@diagnostic disable:undefined-global

local last_tool

wayla.register_element("best_tool", {
    single_provider = true,
    make_content = function(providers, context)
        local provider = providers[1]

        if not provider then
            return
        end

        local data = provider.get_data(context)
        local texture = "wbt_incorrect.png"

        if data.is_correct then
            texture = "wbt_correct.png"
        end

        local content = {
            {
                type = "image",
                x = 0,
                y = 0,
                w = "0.25c",
                h = "0.25c",
                texture_name = texture,
            },
            {
                type = "label",
                x = "0.35c",
                y = 0,
                label = data.best_tool,
            },
        }

        return content, "0.25c"
    end,
})

wayla.register_provider("best_tool", {
    element = "best_tool",

    get_data = function(context)
        local node_def = minetest.registered_items[context.node.name]
        local groups = node_def.groups

        local wielded_item = context.player:get_wielded_item()
        local item_name = wielded_item:get_name()

        local best_tool_lut = {
            -- Mineclone
            pickaxey = "Pickaxe",
            axey = "Axe",
            shovely = "Shovel",
            swordy = "Sword",
            swordy_cobweb = "Sword",

            -- Minetest
            -- dig_immediate,
            crumbly = "Shovel",
            cracky = "Pickaxe",
            -- snappy,
            choppy = "Axe",
            fleshy = "Sword",
            -- explody,
        }

        local best_tool = "No Tool"
        for group, _ in pairs(groups) do
            if best_tool_lut[group] then
                best_tool = best_tool_lut[group]
                break
            end
        end

        -- TODO: this should correctly account for tool levels
        local is_correct =
            groups.handy
            or best_tool == "No Tool"
            or harvestable
            or minetest.get_item_group(
                item_name,
                string.lower(best_tool)
            ) > 0

        best_tool = is_correct
            and minetest.colorize("lightgreen", best_tool)
            or minetest.colorize("yellow", best_tool)

        return {
            is_correct = is_correct,
            best_tool = best_tool,
        }
    end,

    should_update = function(context)
        local tool = context.player:get_wielded_item():get_name()
        local should_update = tool ~= last_tool
        last_tool = tool
        return should_update
    end,
})
