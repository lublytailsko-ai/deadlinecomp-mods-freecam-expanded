-- dlcomp health broadcaster (SERVER)
-- Sends every player's current health to clients so the client ESP can draw health bars.
-- Run in the Server Luau console (this session) or put it in Server Autorun.
-- Safe to run again: it replaces the previous copy instead of stacking.

local MESSAGE = "dlcomp-health"  -- must match plr_health_message in the client file
local INTERVAL = 0.25            -- seconds between health checks
local REFRESH = 2                -- resend this often even if nothing changed (late joiners, respawns)
local RECIPIENTS = nil           -- nil = send to everyone; or a list, e.g. {"Caster1", "Caster2"}

if shared.dlcomp_health_task then
	pcall(task.cancel, shared.dlcomp_health_task)
	shared.dlcomp_health_task = nil
end

local last_payload = nil
local last_sent = -1000

local function build_payload()
	local parts = {}
	for _, player in players.get_all() do
		local alive_ok, alive = pcall(player.is_alive)
		local hp_ok, health = pcall(player.get_health)
		if alive_ok and alive and hp_ok and type(health) == "number" then
			parts[#parts + 1] = player.name .. ":" .. math.floor(health + 0.5)
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

local function send(payload)
	for _, player in players.get_all() do
		if RECIPIENTS == nil or table.find(RECIPIENTS, player.name) then
			pcall(player.fire_client, MESSAGE, payload)
		end
	end
end

shared.dlcomp_health_task = task.spawn(function()
	while true do
		local ok, err = pcall(function()
			local payload = build_payload()
			if payload ~= last_payload or (tick() - last_sent) >= REFRESH then
				last_payload = payload
				last_sent = tick()
				send(payload)
			end
		end)
		if not ok then
			warn("dlcomp-health:", err)
		end
		task.wait(INTERVAL)
	end
end)

print("dlcomp-health broadcaster running")
