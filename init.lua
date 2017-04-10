-- Parameters
cmg = {}
cmg.path = minetest.get_modpath("carpathian_mapgen")
local YWATER = 1 -- y of water level
local YSURF = 4 -- y of surface centre and top of beach
local TERSCA = 64 -- Terrain vertical scale in nodes
local TSTONE = 0.04 -- Stone density threshold, depth of sand or biome nodes
local DEBUG = false

-- Noise parameters

-- Base terrain noise, low and mostly flat  2D
local np_base = {offset = 1, scale = 1, spread = {x = 8192, y = 8192, z = 8192}, seed = 211, octaves = 6, persist = 0.8, lacunarity = 0.5}
-- Terrain feature noise  2D
local np_terrain1 = {offset = 0, scale = 1, spread = {x = 2048, y = 2048, z = 2048}, seed = 666, octaves = 3, persist = 0.5, lacunarity = 2}
local np_terrain2 = {offset = 0, scale = 1, spread = {x = 2048, y = 2048, z = 2048}, seed = 555, octaves = 3, persist = 0.5, lacunarity = 2}
local np_terrain3 = {offset = 0, scale = 1, spread = {x = 2048, y = 2048, z = 2048}, seed = 444, octaves = 3, persist = 0.5, lacunarity = 2}

-- Terrain height noises  2D
local np_theight1 = {offset = 0, scale = 1, spread = {x = 128, y = 128, z = 128}, seed = 123, octaves = 5, persist = 0.5, lacunarity = 2}
local np_theight2 = {offset = 0, scale = 1, spread = {x = 256, y = 256, z = 256}, seed = 234, octaves = 5, persist = 0.5, lacunarity = 3}
local np_theight3 = {offset = 0, scale = 1, spread = {x = 512, y = 512, z = 512}, seed = 345, octaves = 5, persist = 0.5, lacunarity = 2}
local np_theight4 = {offset = 0, scale = 1, spread = {x = 768, y = 768, z = 768}, seed = 456, octaves = 5, persist = 0.5, lacunarity = 2}

-- Hill and mountain noise, large  2D
local np_mnt1 = {offset = 0, scale = 1, spread = {x = 817, y = 817, z = 817}, seed = 762, octaves = 6, persist = 0.7, lacunarity = 2}
local np_mnt2 = {offset = 0, scale = 1, spread = {x = 257, y = 257, z = 257}, seed = 267, octaves = 6, persist = 0.7, lacunarity = 2}
local np_mnt3 = {offset = 0, scale = 1, spread = {x = 643, y = 643, z = 643}, seed = 672, octaves = 6, persist = 0.7, lacunarity = 2}
-- Hill/mountain noise modifier, influences mountains for overhangs 3D
local np_mod = {offset = 0, scale = 1, spread = {x = 512, y = 512, z = 512}, seed = 429, octaves = 6, persist = 0.6, lacunarity = 2}

-- Set mapgen parameters
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})


-- Constants
local c_air       = minetest.CONTENT_AIR
local c_ignore    = minetest.CONTENT_IGNORE
-- Nodes
local c_grass     = minetest.get_content_id("default:dirt_with_grass")
local c_dirt      = minetest.get_content_id("default:dirt")
local c_stone     = minetest.get_content_id("default:stone")
local c_sand      = minetest.get_content_id("default:sand")
local c_water     = minetest.get_content_id("default:water_source")

-- Initialize noise objects to nil
local nobj_base  = nil
local nobj_terrain1 = nil
local nobj_terrain2 = nil
local nobj_terrain3 = nil
local nobj_theight1 = nil
local nobj_theight2 = nil
local nobj_theight3 = nil
local nobj_theight4 = nil
local nobj_mnt1 = nil
local nobj_mnt2 = nil
local nobj_mnt3 = nil
local nobj_mod = nil

-- Localise noise buffers
local nbuf_base
local nbuf_terrain1
local nbuf_terrain2
local nbuf_terrain3
local nbuf_theight1
local nbuf_theight2
local nbuf_theight3
local nbuf_theight4
local nbuf_mnt1
local nbuf_mnt2
local nbuf_mnt3
local nbuf_mod

-- Localise data buffer
local dbuf

-- On generated function
minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()

	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	local sidelen = x1 - x0 + 1
	local ystridevm = sidelen + 32 -- strides for voxelmanip
	local zstridevm = ystridevm ^ 2
	local ystridepm = sidelen + 2 -- strides for perlinmaps, densitymap, stability map
	local zstridepm = ystridepm ^ 2

	local chulens3d = {x = sidelen + 2, y = sidelen + 2, z = sidelen + 2}
	local chulens2d = {x = sidelen + 2, y = sidelen + 2, z = 1}
	local minpos3d = {x = x0 - 1, y = y0 - 1, z = z0 - 1}
	local minpos2d = {x = x0 - 1, y = z0 - 1}
	
	nobj_base     = nobj_base     or minetest.get_perlin_map(np_base, chulens2d)
	nobj_terrain1 = nobj_terrain1 or minetest.get_perlin_map(np_terrain1, chulens2d)
	nobj_terrain2 = nobj_terrain2 or minetest.get_perlin_map(np_terrain2, chulens2d)
	nobj_terrain3 = nobj_terrain3 or minetest.get_perlin_map(np_terrain3, chulens2d)
	nobj_theight1 = nobj_theight1 or minetest.get_perlin_map(np_theight1, chulens2d)
	nobj_theight2 = nobj_theight2 or minetest.get_perlin_map(np_theight2, chulens2d)
	nobj_theight3 = nobj_theight3 or minetest.get_perlin_map(np_theight3, chulens2d)
	nobj_theight4 = nobj_theight4 or minetest.get_perlin_map(np_theight4, chulens2d)
	nobj_mnt1     = nobj_mnt1     or minetest.get_perlin_map(np_mnt1, chulens2d)
	nobj_mnt2     = nobj_mnt2     or minetest.get_perlin_map(np_mnt2, chulens2d)
	nobj_mnt3     = nobj_mnt3     or minetest.get_perlin_map(np_mnt3, chulens2d)
	nobj_mod      = nobj_mod      or minetest.get_perlin_map(np_mod, chulens3d)
	
	local nvals_base     = nobj_base     :get2dMap_flat(minpos2d, nbuf_base)
	local nvals_terrain1 = nobj_terrain1 :get2dMap_flat(minpos2d, nbuf_terrain1)
	local nvals_terrain2 = nobj_terrain2 :get2dMap_flat(minpos2d, nbuf_terrain2)
	local nvals_terrain3 = nobj_terrain3 :get2dMap_flat(minpos2d, nbuf_terrain3)
	local nvals_theight1 = nobj_theight1 :get2dMap_flat(minpos2d, nbuf_theight1)
	local nvals_theight2 = nobj_theight2 :get2dMap_flat(minpos2d, nbuf_theight2)
	local nvals_theight3 = nobj_theight3 :get2dMap_flat(minpos2d, nbuf_theight3)
	local nvals_theight4 = nobj_theight4 :get2dMap_flat(minpos2d, nbuf_theight4)
	local nvals_mnt1     = nobj_mnt1     :get2dMap_flat(minpos2d, nbuf_mnt1)
	local nvals_mnt2     = nobj_mnt2     :get2dMap_flat(minpos2d, nbuf_mnt2)
	local nvals_mnt3     = nobj_mnt3     :get2dMap_flat(minpos2d, nbuf_mnt3)
	local nvals_mod      = nobj_mod      :get3dMap_flat(minpos3d, nbuf_mod)

	local dvals = {} -- 3D densitymap

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = vm:get_data(dbuf)

	-- Place stone
	local ni3d = 1
	local ni2d = 1
	for z = z0 - 1, z1 + 1 do
		for y = y0 - 1, y1 + 1 do
			local vi = area:index(x0 - 1, y, z)
			for x = x0 - 1, x1 + 1 do
				local n_base     = nvals_base[ni2d]
				local n_terrain1    = math.abs(nvals_terrain1[ni2d])
				local n_terrain2    = math.abs(nvals_terrain2[ni2d])
				local n_terrain3    = math.abs(nvals_terrain3[ni2d])
				local n_theight1 = math.abs(nvals_theight1[ni2d])
				local n_theight2 = math.abs(nvals_theight2[ni2d])
				local n_theight3 = math.abs(nvals_theight3[ni2d])
				local n_theight4 = math.abs(nvals_theight4[ni2d])
				local n_mnt1      = nvals_mnt1[ni2d]
				local n_mnt2      = nvals_mnt2[ni2d]
				local n_mnt3      = nvals_mnt3[ni2d]
				local n_mod      = math.abs(nvals_mod[ni3d])

				local function lerp(noise_a, noise_b, n_mod)
					return noise_a * (1 - n_mod) + noise_b * n_mod
				end

				local com1, com2, com3, com4
				com1 = lerp(n_theight1, n_theight2, n_mod)
				com2 = lerp(n_theight3, n_theight4, n_mod)
				com3 = lerp(n_theight3, n_theight2, n_mod)
				com4 = lerp(n_theight1, n_theight4, n_mod)
				local hilliness = math.max(math.min(com1,com2),math.min(com3,com4))
				local grad = (YSURF - y) / TERSCA
				local tstone = TSTONE

				local function steps(h)
					local w = math.abs(n_base)
					local k = math.floor(h / w)
					local f = (h - k * w) / w
					local s = math.min(2 * f, 1.0)
					return (k + s) * w
				end

				local function bias(noise, bias)
					return (noise / ((((1.0 / bias) - 2.0) * (1.0 - noise)) + 1.0))
				end

				local function gain(noise, gain)
					if noise < 0.5 then
						return bias(noise * 2.0, gain) / 2.0
					else
						return bias(noise * 2.0 - 1.0, 1.0 - gain) / 2.0 + 0.5
					end
				end

				local ridge_mount = hilliness * (1 - math.abs(n_mnt1))
				local step_mount = hilliness * steps(n_mnt2)
				local gain_mount = hilliness * gain(n_mnt3, 0.2)

				local density = n_base + ((n_terrain1 ^ 3) * ridge_mount) +
				((n_terrain2 ^ 3) * step_mount) + ((n_terrain3 ^ 3) * gain_mount) + grad


				dvals[ni3d] = density

				if density >= tstone then
					data[vi] = c_stone
				elseif y == y1 + 1 and x >= x0 and x <= x1 and z >= z0 and z <= z1 then
					data[vi] = c_air
				end
				ni3d = ni3d + 1
				ni2d = ni2d + 1
				vi = vi + 1
			end
			ni2d = ni2d - ystridepm
		end
		ni2d = ni2d + ystridepm
	end
	
	-- Place sub-surface biome nodes
	local stable = {} -- stability map
	for y = y0, y1 + 1 do
		local tstone = TSTONE
		if y < YSURF then
			tstone = TSTONE * 4
		end
		for z = z0, z1 do
			local vi = area:index(x0, y, z)
			local di = (z - z0 + 1) * zstridepm + -- densitymap index
					(y - y0 + 1) * ystridepm + 2 -- +2 because starting at x = x0
			local ni2d = (z - z0 + 1) * ystridepm + 2 -- biome noise and stability maps

			for x = x0, x1 do
				local density = dvals[di]

				if density >= tstone then -- existing stone
					stable[ni2d] = true
				elseif density >= 0 and (stable[ni2d] or y == y0) then -- biome layer
					local nodu  = data[(vi - ystridevm)]
					local node  = data[(vi - ystridevm + 1)]
					local nodw  = data[(vi - ystridevm - 1)]
					local nodn  = data[(vi - ystridevm + zstridevm)]
					local nods  = data[(vi - ystridevm - zstridevm)]
					local nodne = data[(vi - ystridevm + zstridevm + 1)]
					local nodnw = data[(vi - ystridevm + zstridevm - 1)]
					local nodse = data[(vi - ystridevm - zstridevm + 1)]
					local nodsw = data[(vi - ystridevm - zstridevm - 1)]

					if y == y0 then -- also check for ignore
						if nodu == c_air or nodu == c_ignore
								or node == c_air or node == c_ignore
								or nodw == c_air or nodw == c_ignore
								or nodn == c_air or nodn == c_ignore
								or nods == c_air or nods == c_ignore
								or nodne == c_air or nodne == c_ignore
								or nodnw == c_air or nodnw == c_ignore
								or nodse == c_air or nodse == c_ignore
								or nodsw == c_air or nodsw == c_ignore then
							stable[ni2d] = false
						else
							stable[ni2d] = true
						end
					else
						if node == c_air
								or nodw == c_air
								or nodn == c_air
								or nods == c_air
								or nodne == c_air
								or nodnw == c_air
								or nodse == c_air
								or nodsw == c_air then
							stable[ni2d] = false
						end
					end

					if stable[ni2d] then
						if y <= YSURF then
							data[vi] = c_sand
						else
							data[vi] = c_dirt
						end
					end
				else
					stable[ni2d] = false
				end

				vi = vi + 1
				di = di + 1
				ni2d = ni2d + 1
			end
		end
	end

	if y1 > YSURF then
		-- Place surface biome nodes
		for z = z0, z1 do
			local ni2d = (z - z0 + 1) * ystridepm + 2
			for x = x0, x1 do
				local aircount = 0
				local vi = area:index(x, y1 + 2, z)
				for y = y1 + 2, y0, -1 do
					if y <= YSURF then
						break
					end

					local nodid = data[vi]
					if nodid == c_air then
						aircount = aircount + 1
					elseif aircount >= 1 then -- surface found
						if nodid == c_dirt then
							data[vi] = c_grass
						end
						aircount = 0
					end
					vi = vi - ystridevm
				end
				ni2d = ni2d + 1
			end
		end
	end

	if y0 <= YWATER then
		-- Place water
		for z = z0, z1 do
			for y = y0, y1 do
				local vi = area:index(x0, y, z)
				for x = x0, x1 do
					if data[vi] == c_air and y <= YWATER then
						data[vi] = c_water
					end
					vi = vi + 1
				end
			end
		end
	end

	vm:set_data(data)
	vm:calc_lighting({x = x0, y = y0 - 1, z = z0}, {x = x1, y = y1 + 1, z = z1})
	vm:write_to_map(data)
	vm:update_liquids()

	if DEBUG then
		local chugent = math.ceil((os.clock() - t0) * 1000)
		print ("[carpathian] "..chugent.." ms")
	end
end)
