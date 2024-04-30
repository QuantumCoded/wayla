---@diagnostic disable:undefined-global

wayla.register_element("attributes", {
	make_content = function(providers, context)
		local content = {}
		local count = 0

		for _, provider in ipairs(providers) do
			local lines, color = provider.get_data(context)
			local title = provider.title or provider.name

			if type(lines) ~= "table" then
				lines = { title .. ": " .. lines }
			end

			for _, text in ipairs(lines) do
				if color then
					text = minetest.colorize(color, text)
				end

				table.insert(content, {
					type = "label",
					x = 0,
					y = count * 0.25 .. "c",
					label = text,
				})

				count = count + select(2, string.gsub(text, "\n", "")) + 1
			end
		end

		return content, count * 0.25 .. "c"
	end,
})
