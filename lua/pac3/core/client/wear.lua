CreateClientConVar("pac_server_player_size", 0, true, true)

local function decimal_hack_mul(tbl)
	--[[for key, val in pairs(tbl) do
		local t = type(val)
		if t == "Vector" then
			tbl[key].x = tbl[key].x * 100
			tbl[key].y = tbl[key].y * 100
			tbl[key].z = tbl[key].z * 100
		elseif t == "number" then
			tbl[key] = val * 100
		elseif t == "table" then
			decimal_hack_mul(val)
		end
	end]]
end

local function decimal_hack_div(tbl)
	--[[for key, val in pairs(tbl) do
		local t = type(val)
		if t == "Vector" then
			tbl[key].x = tbl[key].x / 100
			tbl[key].y = tbl[key].y / 100
			tbl[key].z = tbl[key].z / 100
		elseif t == "number" then
			tbl[key] = val / 100
		elseif t == "table" then
			decimal_hack_div(val)
		end
	end]]
end


do -- to server
	function pac.SendPartToServer(part)
		local data = {part = part:ToTable()}
		data.owner = part:GetOwner()
			
		pac.HandleServerModifiers(data)
		
		net.Start("pac_submit")
			decimal_hack_mul(data)
			net.WriteTable(data)
		net.SendToServer()
	end

	function pac.RemovePartOnServer(name, server_only, filter)
		net.Start("pac_submit")
			local data = {part = name, server_only = server_only}
			decimal_hack_mul(data)
			net.WriteTable(data)
		net.SendToServer()
	end
end

do -- from server
	function pac.WearPartFromServer(owner, part_data)
		pac.dprint("received outfit %q from %s with %i number of children to set on %s", part_data.self.Name or "", tostring(owner), table.Count(part_data.children), part_data.self.OwnerName or "")

		for key, part in pairs(pac.GetParts()) do
			if 
				not part:HasParent() and 
				part:GetPlayerOwner() == owner and 
				part:GetName() == pac.HandlePartName(owner, part_data.self.Name) and 
				part.ClassName == part_data.self.ClassName 
			then
				pac.dprint("removing part %q to be replaced with the part previously received", part.Name)
				part:Remove()
			end
		end
	
		local part = pac.CreatePart(part_data.self.ClassName, owner)
		part:SetTable(part_data)
		part:CheckOwner()
		
		pac.HandleServerModifiers(part_data)
		
		pac.CallHook("OnWoreOutfit", part, owner == LocalPlayer())
	end

	function pac.RemovePartFromServer(owner, part_name)
		pac.dprint("%s removed %q", tostring(owner), part_name)

		if part_name == "__ALL__" then		
			for key, part in pairs(pac.GetParts()) do
				if not part:HasParent() and part:GetPlayerOwner() == owner then
					part:Remove()
				end
			end 
			
			pac.HandleServerModifiers(owner, true)
		else
			for key, part in pairs(pac.GetParts()) do
				if 
					not part:HasParent() and 
					part:GetPlayerOwner() == owner and 
					part:GetName() == pac.HandlePartName(owner, part_name)
				then
					part:Remove()
					return
				end
			end 
		end
	end
end

local function handle_data(data)
	if data.owner:IsValid() then
		local T = type(data.part)
		if T == "table" then
			pac.WearPartFromServer(data.owner, data.part)
		elseif T ==  "string" then
			pac.RemovePartFromServer(data.owner, data.part)
		end
	end
end

net.Receive("pac_submit", function()
	local data = net.ReadTable()
	decimal_hack_div(data)
	handle_data(data)
end)

function pac.Notify(allowed, reason)
	 if allowed then
		chat.AddText(Color(255,255,0), "[PAC3] ", Color(0,255,0), "Your config has been applied.")
	else
		chat.AddText(Color(255,255,0), "[PAC3] ", Color(255,0,0), reason)
	end
end

usermessage.Hook("pac_submit_acknowledged", function(umr)
	local allowed = umr:ReadBool()
	local reason = umr:ReadString()

	pac.Notify(allowed, reason)
end)