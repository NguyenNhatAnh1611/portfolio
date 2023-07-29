--||Services||--
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Debris = game:GetService("Debris")

--|| Directories ||--
local Remotes = ReplicatedStorage.Remotes

--|| Imports ||--
local RaycastHitbox = require(script.RaycastHitboxV4)

local COMBAT = ReplicatedStorage.Remotes.COMBAT
local MODULES = ReplicatedStorage.MODULES
local STATE = require(MODULES.Shared.STATE)
local DATA = require(ServerScriptService.COMBAT.Preset.DATA)
local PLAYERDATA = require(ServerScriptService.COMBAT.Preset.PLAYER)
local AnimationManager = require(MODULES.Utility.AnimationManager)

local HitboxService = {}
function HitboxService:RaycastHitbox(Character: any, Object: any, HitPoints: any, Duration: number, HitOnce: boolean, Blacklist: any, ParryEnabled, CallbackFunction)
	if not (Character) then
		return;
	end

	if not (Object) then
		Object = Character:FindFirstChild("HumanoidRootPart");
	end

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Blacklist

	if not (HitPoints) then
		warn("Invaild HitPoints: Not defined!");
		return;
	end

	local NewHitbox = RaycastHitbox.new(Object)
	NewHitbox.RaycastParams = Params
	NewHitbox.Visualizer = true
	NewHitbox:SetPoints(Object, HitPoints)

	local HitEnded = false
	local Connection; Connection = NewHitbox.OnHit:Connect(function(Hit, Humanoid, RayResult)
		if (HitOnce == true) then
			if (HitEnded == true) then
				return;
			end
			Connection:Disconnect();
			NewHitbox:HitStop();
			HitEnded = true;
		end
		
		if (Character:FindFirstChild("Forcefield")) then return end
		if (Humanoid.Parent:FindFirstChild("Knocked")) then return end
		if (Humanoid.Parent.Parent ~= workspace.World.Live) then return end
		if not STATE:LOADPRESET(Character, "Damagable") then return end
		if ParryEnabled and Humanoid.Parent:FindFirstChild("Parry") and Character:FindFirstChild("Parry") then
			Character.Parry:Fire(Humanoid.Parent)
		else
			pcall(function()
				CallbackFunction(Hit, Humanoid, RayResult);
			end)
		end
	end)

	NewHitbox:HitStart();
	task.wait(Duration)
	if (HitEnded == true) then
		return;
	end
	Connection:Disconnect();
	NewHitbox:HitStop();
	HitEnded = true;
end
function HitboxService:MagnitudeHitbox(Character, Data)
	local Hits = {}
	local EnemyHumanoids = {}

	local Humanoid, HumanoidRootPart = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart")

	local SecondType = Data.SecondType or ""

	for _,Characters in ipairs(workspace.World.Live:GetChildren()) do
		if Characters:FindFirstChild("HumanoidRootPart") and Characters:FindFirstChild("Humanoid")  then
			local Calculation = (HumanoidRootPart.Position - Characters.HumanoidRootPart.Position).Magnitude
			if Calculation <= Data.Range then
				if Characters ~= Character then
					if (Character:FindFirstChild("Forcefield")) then return end
					if (Humanoid.Parent:FindFirstChild("Knocked")) then return end
					if (Humanoid.Parent.Parent ~= workspace.World.Live) then return end
					if not STATE:LOADPRESET(Character, "Damagable") then return end
					
					Hits[#Hits + 1] = Characters
					Data.Range = Calculation
				end
			end
		end
	end

	for _,EnemyCharacter in ipairs(Hits) do
		local EnemyHumanoid,EnemyRoot = EnemyCharacter:FindFirstChild("Humanoid"), EnemyCharacter:FindFirstChild("HumanoidRootPart")
		EnemyHumanoids[#EnemyHumanoids + 1] = EnemyCharacter:FindFirstChild("Humanoid")
	end

	for _, Humanoids in ipairs(EnemyHumanoids) do
		return true, EnemyHumanoids
	end
	return false
end
function HitboxService:FindNearestKnocked(Character)
	local Humanoid, HumanoidRootPart = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not HumanoidRootPart then return end
	
	local Whitelist = {}
	for _, v in pairs(workspace.World.Live:GetChildren()) do
		if v ~= Character and v:FindFirstChild("Knocked") and not v:FindFirstChild("Gripping") and not v:FindFirstChild("Carrying") then
			if (v.PrimaryPart.Position - HumanoidRootPart.Position).magnitude <= 7 then
				table.insert(Whitelist, v)
			end
		end
	end
	
	local Nearest = Whitelist[1]
	for _, v in pairs(Whitelist) do
		local sc, er = pcall(function()
			if (v.PrimaryPart.Position - HumanoidRootPart.Position).magnitude < (Nearest.PrimaryPart.Position - HumanoidRootPart.Position).magnitude then
				Nearest = v
				return "break"
			end
		end)
		
		if sc == "break" then
			break
		end
	end
	
	return Nearest
end
function HitboxService:BlockHitbox(Root, Blacklist, HitboxSettings, ParryEnabled, Callback)
	if not Root then return end
	if not Blacklist then return end
	if not HitboxSettings then return end
	
	local Whitelist = {}
	for _, v in pairs(workspace.World.Live:GetChildren()) do
		for _, v1 in pairs(v:GetChildren()) do
			if v1:IsA("BasePart") then
				table.insert(Whitelist, v1)
			end
		end
	end
	
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Whitelist
	Params.RespectCanCollide = true
	Params.MaxParts = 5
	
	local Hits = {}
	
	local StartTime = tick()
	spawn(function()
		while tick() - StartTime <= HitboxSettings.Duration do
			local cf = Root.CFrame * (HitboxSettings.CFrame or HitboxSettings.PositionCFrame or CFrame.new(0, 0, 0))
			
			if HitboxSettings.ExceptionalPosition then
				cf = CFrame.new(HitboxSettings.ExceptionalPosition)
			elseif HitboxSettings.ExceptionalCFrame then
				cf = HitboxSettings.ExceptionalCFrame
			end
			
			local parts = workspace:GetPartBoundsInBox(cf, HitboxSettings.Size, Params)
			if HitboxSettings.Forced then
				for _, v in pairs(HitboxSettings.Forced) do
					table.insert(parts, v)
				end
			end
			
			local CanContinue = true
			for _, v in pairs(parts) do
				local p = v.Parent
				if not table.find(Hits, p) and not table.find(Blacklist, p) then
					if not (Root.Parent:FindFirstChild("Forcefield")) and not (p:FindFirstChild("Knocked")) and (p.Parent == workspace.World.Live) and STATE:LOADPRESET(Root.Parent, "Damagable") then
						if ParryEnabled and p:FindFirstChild("Parry") and Root.Parent:FindFirstChild("Parry") then
							CanContinue = false
							pcall(function()
								Root.Parent.Parry:Fire(p)
							end)
							break
						else
							table.insert(Hits, p)

							pcall(function()
								spawn(function()
									Callback(p);
								end)
							end)
							
							if HitboxSettings.HitOnce then
								CanContinue = false
								break
							end
						end
					end
				end
			end
			
			if not CanContinue then break end
			wait(HitboxSettings.Interval)
		end
	end)
end
function HitboxService:TouchedHitbox(Root, Blacklist, HitboxSettings, ParryEnabled, Callback)
	if not Root then return end
	if not Blacklist then return end
	if not HitboxSettings then return end
	
	HitboxSettings.CFrame = HitboxSettings.CFrame or CFrame.new(0, 0, 0)
	
	local Whitelist = {}
	for _, v in pairs(workspace.World.Live:GetChildren()) do
		for _, v1 in pairs(v:GetChildren()) do
			if v1:IsA("BasePart") then
				table.insert(Whitelist, v1)
			end
		end
	end
	
	local Part = Instance.new("Part")
	Part.Name = "Hitbox"
	Part.Transparency = 1
	Part.CanCollide = false
	Part.Size = HitboxSettings.Size
	Part.CFrame = Root.CFrame * HitboxSettings.CFrame
	if HitboxSettings.Visualize then
		Part.Color = Color3.fromRGB(255, 0, 0)
		Part.Transparency = 0.4
	end
	Part.Parent = workspace.World.Visuals
	
	local Motor6D = Instance.new("Motor6D")
	Motor6D.Part1 = Root
	Motor6D.Part0 = Part
	Motor6D.C1 = HitboxSettings.CFrame
	Motor6D.Parent = Part
	Debris:AddItem(Part, HitboxSettings.Duration)
	
	local Hits = {}
	local CanContinue = true
	
	local TouchingParts = Part:GetTouchingParts()
	for _, Hit in pairs(TouchingParts) do
		if not CanContinue then return end
		pcall(function()
			if not Hit.Parent:IsA("Model") then return end
			local Character = Hit.Parent
			if Character.Parent ~= workspace.World.Live then return end
			if table.find(Hits, Character) then return end
			if table.find(Blacklist, Character) then return end

			if (Character:FindFirstChild("Forcefield")) then return end
			if (Character:FindFirstChild("Knocked")) then return end
			if not STATE:LOADPRESET(Character, "Damagable") then return end

			if ParryEnabled and Character:FindFirstChild("Parry") and Root.Parent:FindFirstChild("Parry") then
				CanContinue = false
				pcall(function()
					Root.Parent.Parry:Fire(Character)
				end)
			else
				table.insert(Hits, Character)

				pcall(function()
					Callback(Character);
				end)

				if HitboxSettings.HitOnce then
					CanContinue = false
				end
			end
		end)
	end
	
	Part.Touched:Connect(function(Hit)
		if not CanContinue then return end
		pcall(function()
			if not Hit.Parent:IsA("Model") then return end
			local Character = Hit.Parent
			if Character.Parent ~= workspace.World.Live then return end
			if table.find(Hits, Character) then return end
			if table.find(Blacklist, Character) then return end
			
			if (Character:FindFirstChild("Forcefield")) then return end
			if (Character:FindFirstChild("Knocked")) then return end
			if not STATE:LOADPRESET(Character, "Damagable") then return end
			
			if ParryEnabled and Character:FindFirstChild("Parry") and Root.Parent:FindFirstChild("Parry") then
				CanContinue = false
				pcall(function()
					Root.Parent.Parry:Fire(Character)
				end)
			else
				table.insert(Hits, Character)

				pcall(function()
					Callback(Character);
				end)

				if HitboxSettings.HitOnce then
					CanContinue = false
				end
			end
		end)
	end)
end
return HitboxService
