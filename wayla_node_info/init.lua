---@diagnostic disable:undefined-global

local function inventorycube(img1, img2, img3)
	if not img1 then
		return ""
	end

	local images = { img1, img2, img3 }
	for i = 1, 3 do
		images[i] = images[i] .. "^[resize:16x16"
		images[i] = images[i]:gsub("%^", "&")
	end

	return "[inventorycube{" .. table.concat(images, "{")
end

local function get_node_image(node_name)
    local node = minetest.registered_nodes[node_name]

	if not node or (not node.tiles and not node.inventory_image) then
        return
	end

    if node.groups["not_in_creative_inventory"] then
        local drop = node.drop
        if drop and type(drop) == "string" then
            node_name = drop
            node =
                minetest.registered_nodes[drop]
                or minetest.registered_craftitems[drop]
        end
    end

    if not node then
        return
    end

    local tiles = node.tiles or {}

    if tiles.animation then
        -- TODO: support animated images
    elseif node.palette then
        return {
            item_image = node_name,
        }
    elseif node.inventory_image:sub(1, 14) == "[inventorycube" then
        return {
            image = node.inventory_image .. "^[resize:146x146", "node", node,
        }
    elseif node.inventory_image ~= "" then
        return {
            image = node.inventory_image .. "^[resize:16x16", "craft_item", node,
        }
    else
        tiles[3] = tiles[3] or tiles[1]
        tiles[6] = tiles[6] or tiles[3]

        if type(tiles[1]) == "table" then
            tiles[1] = tiles[1].name
        end
        if type(tiles[3]) == "table" then
            tiles[3] = tiles[3].name
        end
        if type(tiles[6]) == "table" then
            tiles[6] = tiles[6].name
        end

        return {
            image = inventorycube(tiles[1], tiles[6], tiles[3]),
        }
    end
end

wayla.register_element("node_info", {
    single_provider = true,
    make_content = function(providers, context)
        local provider = providers[1]

        if not provider then
            return
        end

        local data = provider.get_data(context)

        local content = {}
        local x_offset = "0c"
        local height = "0.75c"

        if data.image and data.image.image then
            x_offset = "0.85c"
            table.insert(content, {
                type = "image",
                x = 0,
                y = 0,
                w = "0.75i",
                h = "0.75i",
                texture_name = data.image.image,
            })
        end

        if data.image and data.image.item_image then
            x_offset = "0.85c"
            table.insert(content, {
                type = "item_image",
                x = 0,
                y = 0,
                w = "0.75i",
                h = "0.75i",
                item_name = data.image.item_image,
            })
        end

        table.insert(content, { type = "label", x = x_offset, y = "0.1c", label = data.name })

        if data.name ~= data.node_name then
            table.insert(content, { type = "label", x = x_offset, y = "0.4c", label = data.node_name })
        end

        if not data.image and data.name == data.node_name then
            height = "0.5c"
        end

        return content, height
    end,
})

wayla.register_provider("node_info", {
    element = "node_info",
    get_data = function(context)
        local node_name = context.node.name
        local node = minetest.registered_nodes[node_name]

        local description =
            node.short_description
            or node.description
            or node_name

        return {
            node_name = node_name,
            ---@diagnostic disable-next-line:undefined-field
            name = string.split(description, "\n")[1] or node_name,
            image = get_node_image(node_name),
        }
    end,
})
