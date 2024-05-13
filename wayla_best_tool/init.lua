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

        if node_def == nil then
            return
        end

        local groups = node_def.groups

        local item_name = context.player:get_wielded_item():get_name()
        local wielded_item = minetest.registered_items[item_name]

        if wielded_item == nil then
            return
        end

        local best_tool_lut = {
            -- Mineclone
            pickaxey = "Pickaxe",
            axey = "Axe",
            shovely = "Shovel",
            shearsy = "No Tool",
            shearsy_wool = "Shears",
            swordy = "Sword",
            swordy_cobweb = "Sword",

            -- Minetest
            -- dig_immediate = "No Tool",
            -- crumbly = "Shovel",
            -- cracky = "Pickaxe",
            -- snappy = "No Tool",
            -- choppy = "Axe",
            -- fleshy = "Sword",
            -- explody = "No Tool",
        }

        local best_tool = "No Tool"
        local wield_level = 0
        local break_level = 0

        for group, level in pairs(groups) do
            if best_tool_lut[group] then
                best_tool = best_tool_lut[group]

                local diggroups = wielded_item._mcl_diggroups

                if diggroups and diggroups[group] then
                    break_level = level
                    wield_level = minetest
                        .registered_items[item_name]
                        ._mcl_diggroups[group]
                        .level
                end

                break
            end
        end

        local is_correct =
            groups.handy
            or best_tool == "No Tool"
            or harvestable
            or minetest.get_item_group(
                item_name,
                string.lower(best_tool)
            ) > 0
            and wield_level >= break_level

        if not is_correct and wield_level < break_level then
            best_tool = best_tool .. " (level " .. break_level .. ")"
        end

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
