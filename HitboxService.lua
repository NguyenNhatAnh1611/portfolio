-- [[Credits]] --
-- Made by OriChanRBLX, serves applying for LUA role in HiddenDevs.

-- [[Overview]] --

-- 2 types of hitbox: BlockHitbox and RaycastHitbox
-- They serve the same function, detecting and returning characters, but have different ways of working.
-- BoxHitbox doesn't require mobilities, such as swinging or whatever. It detects characters in a range of motion, and can easily be changed.
-- RaycastHitbox is more precise and detects every frame of motion. But in exchange, it requires mobility. For example, if the Player can't load the Animations (because of lag, high ping,...), the Hitbox mostly won't work because there are no motions, however, moving around is a way to get around it..
-- TouchedHitbox is Raycast Hitbox, but with .Touched event. However, TouchedHitbox is not good for handling stuff, since it can cause unwanted parts to fire the event. Which can result in bad performance.
-- FindNearestKnocked is a game script, with MagnitudeHitbox built-in, but uses to find Knocked Player (workaround with Gripping, Carrying)
-- MagnitudeHitbox is to loop through all valid instances, and then detect whether they are in valid range to be hit by the hitbox.

-- [[Functionality]]--

-- The first lines are used to create variables for future uses, they are seperated for a better looking module.
-- function HitboxService:(FunctionName) is used to create global functions, and put them inside the module table, and then return the table at the end of the script. When it gets required, the table will be returned and you can use the functions inside it as well as use the variables.
-- RaycastHitbox, uses RaycastHitboxV4: https://devforum.roblox.com/t/raycast-hitbox-401-for-all-your-melee-needs/374482, but with proper uses into the main game runline. First lines are the checks if the variables are valid, we can use pcall if we don't want to check, since pcall won't error any, so the block of script won't work, same when the variables are nil.
-- Next is to create RaycastParams which is needed when perform workspace:Raycast, we will use the HitPoints to determine where we raycast, and the object will determines whether the hit points will be putted on. They functions the same as attachment, but without preset, without memory leaks.
-- When they hit an object (Must be a Character in this situation), they will perform an Live Enemy Check. If the check is valid, call the CallbackFunction() while returning the entity.

-- [[Parry Check]] - If parry is enabled, there will be an event named "Parry" in the player. If they are found, it will fires the event and cancel the hitbox.
-- [[Live Enemy Check]] - The game have an module script named STATE, which is a table module manager, which ensures each player to have their own State Table attached upon called. STATE:LOADPRESET(Character, Preset) will loop through all the state we need to be checked (are in the preset), and return whether the STATE are valid with the current preset values. Next is to check if they are in a valid folder (workspace.World.Live), and check whether they have a ForceField, and check if they are not knocked.
-- [[Knocked Enemy Check]] - Just check for Knocked Event inside the Character.

-- BlockHitbox uses OverlapParams: https://create.roblox.com/docs/reference/engine/datatypes/OverlapParams, so it can detect parts in range. Variables (Root, Blacklist, HitboxSettings, ParryEnabled, Callback), first thing, we will create OverlapParams with Whitelist (Include). We will loop through all lives, check if them are valid, and then put the parts in the whitelist table.
-- HitboxSettings is an table, there are required variables (position and size, duration, interval) 
-- Optional are Max (Max Parts can be detected), CFrame (aka Hitbox offset from the Root Object), ExceptionalPosition (ignores the Root Object, cast hitbox at the exceptional position), ExceptionalCFrame (Same as Position, but have rotations)
-- Duration and Interval, the script will get parts in OverlapParams every Interval in given duration, this can be done by using tick(), while loop or os.clock() and while loop.
-- TouchedHitbox works the same as Raycast, but uses .Touched event instead.
-- FindNearestKnocked is a game script, with MagnitudeHitbox built-in, but uses to find Knocked Player (workaround with Gripping, Carrying)
-- MagnitudeHitbox is to loop through all valid instances, and then detect whether they are in valid range to be hit by the hitbox.

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
