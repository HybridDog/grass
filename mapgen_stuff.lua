local give_info = true
local inform_all = false
local max_spam = 2

local inform
if give_info then
	function inform(msg, spam, t)
		if spam <= max_spam then
			local info
			if t then
				info = string.format("[grass] "..msg.." after ca. %.2fs", os.clock() - t)
			else
				info = "[grass] "..msg
			end
			print(info)
			if inform_all then
				minetest.chat_send_all(info)
			end
		end
	end
else
	function inform()
	end
end

if not rawget(_G, "grass_cs") then
	grass_cs = {}
end
function grass_add_cs(names)
	for _,name in ipairs(names) do
		if not grass_cs[name] then
			grass_cs[name] = minetest.get_content_id(name)
		end
	end
end

local function fix_light(minp, maxp)
	local manip = minetest.get_voxel_manip()
	local emerged_pos1, emerged_pos2 = manip:read_from_map(minp, maxp)
	area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	nodes = manip:get_data()

	manip:set_data(nodes)
	manip:write_to_map()
	manip:update_map()
end

local function table_contains(v, t)
	for _,i in ipairs(t) do
		if v == i then
			return true
		end
	end
	return false
end

local function pstost(minp, maxp)
	return "x=["..minp.x.."; "..maxp.x.."]; y=["..minp.y.."; "..maxp.y.."]; z=["..minp.z.."; "..maxp.z.."]"
end

--[[
param = {
	description = string,
	unwanted_nodes = datatab,
	usual_stuff = datatab,
	ground = datatab,
	miny = int,
	maxy = int,
	settings = {
		always_generate = bool,
		smooth = bool,
		plants_enabled = bool,
		mapgen_rarity = float,
		mapgen_size = int,
		smooth_trans_size = float,
		seeddif = int,
	},
	generate_ground = function(pos, area, data) --data,
	generate_plants = function(pos, area, data) --data, (structp),
	make_structures = function(tab),
	structures = bool,
}
]]

function grass_add_biome(param)

local config = param.settings

local smooth = config.smooth
local plants_enabled = config.enable_plants

local rarity = config.mapgen_rarity
local size = config.mapgen_size
local smooth_trans_size = config.smooth_trans_size

local nosmooth_rarity = 1-rarity/50
local perlin_scale = size*100/rarity
local smooth_rarity_max = nosmooth_rarity+smooth_trans_size*2/perlin_scale
local smooth_rarity_min = nosmooth_rarity-smooth_trans_size/perlin_scale
local smooth_rarity_dif = smooth_rarity_max-smooth_rarity_min

minetest.register_on_generated(function(minp, maxp, seed)

	--avoid calculating perlin noises for unneeded places
	if maxp.y <= param.miny
	or minp.y >= param.maxy then
		return
	end

	local x0,z0,x1,z1 = minp.x,minp.z,maxp.x,maxp.z	-- Assume X and Z lengths are equal
	local perlin1 = minetest.get_perlin(config.seeddif, 3, 0.5, perlin_scale)	--Get map specific perlin

	--[[if not (perlin1:get2d({x=x0, y=z0}) > 0.53) and not (perlin1:get2d({x=x1, y=z1}) > 0.53)
	and not (perlin1:get2d({x=x0, y=z1}) > 0.53) and not (perlin1:get2d({x=x1, y=z0}) > 0.53)
	and not (perlin1:get2d({x=(x1-x0)/2, y=(z1-z0)/2}) > 0.53) then]]

	if not config.always_generate
	and not (perlin1:get2d({x=x0, y=z0} ) > nosmooth_rarity ) 					--top left
	and not (perlin1:get2d({ x = x0 + ( (x1-x0)/2), y=z0 } ) > nosmooth_rarity )--top middle
	and not (perlin1:get2d({x=x1, y=z1}) > nosmooth_rarity) 						--bottom right
	and not (perlin1:get2d({x=x1, y=z0+((z1-z0)/2)}) > nosmooth_rarity) 			--right middle
	and not (perlin1:get2d({x=x0, y=z1}) > nosmooth_rarity)  						--bottom left
	and not (perlin1:get2d({x=x1, y=z0}) > nosmooth_rarity)						--top right
	and not (perlin1:get2d({x=x0+((x1-x0)/2), y=z1}) > nosmooth_rarity) 			--left middle
	and not (perlin1:get2d({x=(x1-x0)/2, y=(z1-z0)/2}) > nosmooth_rarity) 			--middle
	and not (perlin1:get2d({x=x0, y=z1+((z1-z0)/2)}) > nosmooth_rarity) then		--bottom middle
		return
	end

	local t1 = os.clock()

	local divs = maxp.x-minp.x
	pr = PseudoRandom(seed+68)

		--Information:
	inform("tries to generate "..param.description.." at: "..pstost(minp, maxp), 2)

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

	local unwanted_nodes = param.unwanted_nodes
	if unwanted_nodes then
		for p_pos in area:iterp(minp, maxp) do
			local d_p_pos = data[p_pos]
			for _,nam in ipairs(unwanted_nodes) do			
				if d_p_pos == nam then
					data[p_pos] = c.air
					break
				end
			end
		end
	end

	local num = 1
	local tab = {}

	local usual_stuff = param.usual_stuff

	for j=0,divs do
		for i=0,divs do
			local x,z = x0+i,z0+j

			local in_biome = false
			local test = perlin1:get2d({x=x, y=z})
			--smooth mapgen
			if config.always_generate then
				in_biome = true
			elseif smooth then
				if test >= smooth_rarity_max
				or (
					test > smooth_rarity_min
					and pr:next(1, 1000) <= ((test-smooth_rarity_min)/smooth_rarity_dif)*1000
				) then
					in_biome = true
				end
			elseif (not smooth)
			and test > nosmooth_rarity then
				in_biome = true
			end

			if in_biome then

				if usual_stuff then
					for b = minp.y,maxp.y,1 do	--remove usual stuff
						local p_pos = area:index(x, b, z)
						local d_p_pos = data[p_pos]
						for _,nam in ipairs(usual_stuff) do			
							if d_p_pos == nam then
								data[p_pos] = c.air
								break
							end
						end
					end
				end

				local ground_y = nil --get ground_y:
--				for y=maxp.y,0,-1 do
				for y=maxp.y,-5,-1 do	--because of the caves
					if table_contains(data[area:index(x, y, z)], param.ground) then
						ground_y = y
						break
					end
				end

				if ground_y then
					local pos = {x=x, y=ground_y, z=z}
					data = param.generate_ground(pos, area, data)
					if plants_enabled then
						local structp = nil
						data, structp = param.generate_plants(pos, area, data)
						if structp then
							tab[num] = structp
							num = num+1
						end
					end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map()
	inform("ground finished", 2, t1)

	if param.structures then
		local t2 = os.clock()
		param.make_structures(tab)
		inform("structures added", 2, t2)

		local t2 = os.clock()
		fix_light(minp, maxp)
		inform("shadows added", 2, t2)
	end

	inform("done", 1, t1)
end)
end
