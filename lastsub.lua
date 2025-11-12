local cache = (os.getenv("HOME") or ".") .. "/.cache/mpv/last_sub"
os.execute("mkdir -p " .. cache:match("(.+)/[^/]+$"))
local ready = false

local function save_sub()
	if not ready then return end
	local sid = mp.get_property_number("sid")
	local f = io.open(cache, "w")
	if not f then return end

	if not sid or sid == 0 then
		f:write("none")
	else
		for _, t in ipairs(mp.get_property_native("track-list")) do
			if t.type == "sub" and t.id == sid then
				f:write(t.title or t.lang or tostring(t.id))
				break
			end
		end
	end
	f:close()
end

local function analyze_tracks(saved)
	if saved then
		saved = saved:lower()
		if saved == "" or saved == "none" then saved = nil end
	end

	local english_sub_id = nil

	for _, t in ipairs(mp.get_property_native("track-list")) do
		if t.type == "sub" then
			if saved then
				local name = (t.title or t.lang or tostring(t.id)):lower()
				if name:find(saved, 1, true) then return t.id end -- Cached sub found
			end

			if not english_sub_id and t.lang then
				local lang = t.lang:lower()
				if lang:find("en") then english_sub_id = t.id end
			end
		elseif t.type == "audio" and t.selected then
			local lang = t.lang and t.lang:lower() or "en"
			if not saved and lang:find("en") then return nil end -- English audio and no cached sub → no need to scan further
		end
	end

	return english_sub_id
end

local function restore_sub()
	local f = io.open(cache, "r")
	local saved = f and f:read("*l")
	if f then f:close() end

	local sid = analyze_tracks(saved)
	if sid then mp.set_property("sid", sid) end
end

mp.register_event("file-loaded", function()
	ready = true
	restore_sub()
end)

mp.observe_property("sid", "number", function()
	save_sub()
end)
