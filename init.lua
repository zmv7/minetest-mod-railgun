local range = minetest.settings:get("railgun.range") or 100
local density = minetest.settings:get("railgun.density") or 3
local destroy_nodes = minetest.settings:get_bool("railgun.destroy_nodes", true)

minetest.register_tool("railgun:railgun",{
	description = "Railgun",
	inventory_image = "railgun_railgun.png",
	on_use = function(itemstack, user, pointed_thing)
		local name = user:get_player_name()
		local meta = itemstack:get_meta()
		local railgun_color = meta:get("color")
		if not railgun_color then
			railgun_color = "cyan"
			meta:set_string("color", railgun_color)
		end
		if not minetest.is_creative_enabled(name) then
			local inv = user:get_inventory()
			if inv:contains_item("main","railgun:railgun_rod") then
				inv:remove_item("main", "railgun:railgun_rod")
				itemstack:add_wear(655.35)
			else
				minetest.sound_play("unavailable", {to_player=name})
				return itemstack
			end
		end
		local pos = user:get_pos()
		local props = user:get_properties()
		local dir = user:get_look_dir()
		local yaw = user:get_look_horizontal()
		pos.y = pos.y + props.eye_height*0.9
		pos.x = pos.x + math.cos(yaw)/4
		pos.z = pos.z + math.sin(yaw)/4
		for i=1, range*density do
			minetest.add_particle({
				pos = {x = pos.x + dir.x * i/density, y = pos.y + dir.y * i/density, z = pos.z + dir.z * i/density},
				expirationtime = 0.2+i/5000,
				size = 0.8,
				vertical = false,
				texture = "railgun_particle.png^[colorize:"..railgun_color..":255",
				glow = 14
			})
		end
		minetest.sound_play("nexfire", {pos=pos, gain = 0.3})
		local rayend = vector.add(pos, vector.multiply(dir, range))
		local ray = core.raycast(pos, rayend, true, false)
		for pointed_thing in ray do
			if pointed_thing.type == "object" then
			local obj = pointed_thing.ref
			local props = obj:get_properties()
			if obj ~= user and props.pointable then
				obj:punch(user, 1.0, {
					full_punch_interval = 1.0,
					damage_groups = {fleshy = 100},
				}, dir)
			end
			end
			if destroy_nodes and pointed_thing.type == "node" then
				if not minetest.is_protected(pointed_thing.under, name) then
					local node = minetest.get_node(pointed_thing.under)
					local rnode = minetest.registered_nodes[node.name]
					local can_break = true
					if rnode then
						local groups = rnode.groups
						if groups and groups.unbreakable then
							can_break = false
						end
						if rnode.can_dig and not rnode.can_dig(pointed_thing.under, user) then
							can_break = false
						end
					end
					if can_break then
						minetest.remove_node(pointed_thing.under)
						minetest.check_for_falling(pointed_thing.under)
					end
				end
			end
		end
		return itemstack
	end,
})

minetest.register_craftitem("railgun:railgun_rod",{
	description = "Rod for railgun",
	inventory_image = "railgun_railgun_rod.png",
})
if minetest.settings:get_bool("railgun.enable_crafts", true) then
	local d, o, m, s = "default:diamondblock", "default:obsidian", "default:mese", "default:steel_ingot"
	minetest.register_craft({
		output = "railgun:railgun_rod 3",
		recipe = {
			{d, o, m},
			{o, d, o},
			{m, o, d},
		}
	})
	minetest.register_craft({
		output = "railgun:railgun",
		recipe = {
			{m, s, ""},
			{s, m, s},
			{"", s, m},
		}
	})
end
minetest.register_craft({
	type = "shapeless",
	output = "railgun:railgun",
	recipe = {"railgun:railgun","group:dye"},
})

minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
	if not (itemstack and old_craft_grid) then return end
	local railgun_found, dye
	for _, stack in ipairs(old_craft_grid) do
		local name = stack:get_name()
		if name == "railgun:railgun" then
			railgun_found = true
		end
		if name and name:match("^dye:") then
			dye = name:match("dye:(%S+)")
		end
	end
	if railgun_found and dye then
		local meta = itemstack:get_meta()
		meta:set_string("color", dye)
		return itemstack
	end
end)

minetest.register_chatcommand("railgun_color",{
  description = "Apply color to wielded railgun",
  privs = {creative=true},
  params = "[colorstring]",
  func = function (name, param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return false, "No player"
	end
	local witem = player:get_wielded_item()
	if not witem or witem:get_name() ~= "railgun:railgun" then
		return false, "You need to hold railgun in the hand!"
	end
	local meta = witem:get_meta()
	if not meta then
		return false, "Something gone wrong :("
	end
	if param and param ~= "" then
		local check = minetest.colorspec_to_colorstring(param)
		if not check then
			return false, "Invalid colorstring"
		end
		meta:set_string("color", param)
	else
		meta:set_string("color","#fd0")
	end
	player:set_wielded_item(witem)
	return true, "Railgun color has been updated"
end})
