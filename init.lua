local load_time_start = os.clock()
dofile(minetest.get_modpath("grass").."/mapgen_stuff.lua")

local nds = {
	"air",
	"default:dirt_with_grass",
	"default:dry_shrub",
	"default:junglegrass",
	"default:stone"
}
for i = 1,5 do
	table.insert(nds, "default:grass_"..i)
end

local flowers = {"tulip", "rose", "dandelion_yellow", "dandelion_white", "geranium", "viola"}
for n,i in pairs(flowers) do
	local flower = "flowers:"..i
	table.insert(nds, flower)
	flowers[n] = flower
end

grass_add_cs(nds)

grass_add_biome({
	description = "grass biome",
	ground = {grass_cs["default:dirt_with_grass"]},
	miny = 0,
	maxy = 50,
	settings = {
		always_generate = false,
		smooth = true,
		plants_enabled = false,
		mapgen_rarity = 10,
		mapgen_size = 30,
		smooth_trans_size = 20,
		seeddif = 21
	},
	generate_ground = function(pos, area, data)
		local p_pos = area:index(pos.x, pos.y+1, pos.z)
		if data[p_pos] == grass_cs["air"] then
			--data[area:indexp(pos)] = grass_cs["default:stone"]
			if pr:next(1,500) == 1 then
				data[p_pos] = grass_cs[flowers[pr:next(1,6)]]
			elseif pr:next(1,250) == 1 then
				data[p_pos] = grass_cs["default:junglegrass"]
			elseif pr:next(1,100) == 1 then
				data[p_pos] = grass_cs["default:dry_shrub"]
			elseif pr:next(1,4) == 1 then
				data[p_pos] = grass_cs["default:grass_"..pr:next(1,5)]
			end
		end
		return data
	end,
	structures = false,
})

minetest.log("info", string.format("[grass] loaded after ca. %.2fs", os.clock() - load_time_start))
