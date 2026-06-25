local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local espEnabled = false
local espShowName = false
local espShowDist = false
local espShowRole = false
local espShowHp = false
local espShowItem = false
local espRgb = false
local espFilterAdmins = false

local aimbotEnabled = false
local fovRadius = 150
local aimSmoothness = 0.15
local fovRgb = false
local fovColor = Color3.fromRGB(255, 255, 255)
local aimButton = Enum.UserInputType.MouseButton2

local noclipEnabled = false
local speedEnabled = false
local speedValue = 16
local infJumpEnabled = false
local flyEnabled = false
local flySpeed = 50

local currentTab = "HOME"
local menuVisible = false
local currentColor = Color3.fromRGB(255, 255, 255)
local ADMIN_KEYWORDS = {"admin", "mod", "owner", "creator", "dev", "spectator", "moderator"}

local function getRandomName()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    local name = ""
    for i = 1, math.random(15, 25) do
        local r = math.random(1, #chars)
        name = name .. string.sub(chars, r, r)
    end
    return name
end

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Radius = fovRadius
fovCircle.Filled = false
fovCircle.Transparency = 0.6

local function getProtectedTarget()
    local target = nil
    local success = pcall(function()
        target = game:GetService("CoreGui")
    end)
    if not success or not target then
        target = localPlayer:WaitForChild("PlayerGui")
    end
    return target
end

local function hardBypass()
    local success, raw = pcall(getrawmetatable, game)
    if not success then return end
    setreadonly(raw, false)
    local oldNamecall = raw.__namecall
    raw.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and (method == "FindFirstChild" or method == "FindPartOnRay" or method == "IsA") then
            local args = {...}
            if args[1] == "XenoTestESP" or args[1] == "XenoTextTag" or args[1] == "HarizmaHub" or args[1] == "HarizmaWatermark" then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(raw, true)
end
pcall(hardBypass)

RunService.RenderStepped:Connect(function()
    local hue = (tick() % 5) / 5
    currentColor = Color3.fromHSV(hue, 1, 1)
end)

local function isAdmin(player)
    if player == localPlayer then return false end
    local nameLower = player.Name:lower()
    local dispLower = player.DisplayName:lower()
    for _, keyword in ipairs(ADMIN_KEYWORDS) do
        if nameLower:find(keyword) or dispLower:find(keyword) then
            return true
        end
    end
    return false
end

local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function applyEsp(character)
    if not character or character == localPlayer.Character then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    if espFilterAdmins and not isAdmin(player) then
        local oldEsp = character:FindFirstChild("XenoTestESP")
        local oldTag = character:FindFirstChild("XenoTextTag")
        if oldEsp then oldEsp:Destroy() end
        if oldTag then oldTag:Destroy() end
        return
    end

    local oldEsp = character:FindFirstChild("XenoTestESP")
    local oldTag = character:FindFirstChild("XenoTextTag")

    if not espEnabled then 
        if oldEsp then oldEsp:Destroy() end
        if oldTag then oldTag:Destroy() end
        return 
    end

    local finalColor = espRgb and currentColor or (isAdmin(player) and Color3.fromRGB(241, 196, 15) or Color3.fromRGB(255, 60, 60))

    local highlight = oldEsp
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "XenoTestESP"
        highlight.FillTransparency = 0.5
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = character
    end
    highlight.FillColor = finalColor

    local textLines = {}
    if espShowRole and isAdmin(player) then table.insert(textLines, "[ADMIN]") end
    if espShowName then table.insert(textLines, player.Name) end
    if espShowHp then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then table.insert(textLines, "HP: " .. math.floor(hum.Health)) end
    end
    if espShowDist then
        local root = character:FindFirstChild("HumanoidRootPart")
        local lroot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and lroot then
            table.insert(textLines, math.floor((root.Position - lroot.Position).Magnitude) .. "m")
        end
    end
    if espShowItem then
        local tool = character:FindFirstChildOfClass("Tool")
        table.insert(textLines, "Item: " .. (tool and tool.Name or "Hands"))
    end

    if #textLines > 0 then
        local textTag = oldTag
        if not textTag then
            textTag = Instance.new("BillboardGui")
            textTag.Name = "XenoTextTag"
            textTag.Size = UDim2.new(0, 200, 0, 80)
            textTag.AlwaysOnTop = true
            textTag.ExtentsOffset = Vector3.new(0, 3, 0)
            local lbl = Instance.new("TextLabel")
            lbl.Name = "Label"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 11
            lbl.TextStrokeTransparency = 0.3
            lbl.Parent = textTag
            textTag.Parent = character
        end
        textTag.Label.Text = table.concat(textLines, "\n")
        textTag.Label.TextColor3 = finalColor
    elseif oldTag then
        oldTag:Destroy()
    end
end

RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then applyEsp(p.Character) end
    end
end)

local function isPlayerVisible(targetCharacter)
    local head = targetCharacter:FindFirstChild("Head") or targetCharacter:FindFirstChild("HumanoidRootPart")
    if not head then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {localPlayer.Character, targetCharacter}
    local result = Workspace:Raycast(camera.CFrame.Position, head.Position - camera.CFrame.Position, params)
    return result == nil
end

RunService.RenderStepped:Connect(function()
    local mouseLocation = UserInputService:GetMouseLocation()
    fovCircle.Position = mouseLocation
    fovCircle.Radius = fovRadius
    fovCircle.Visible = (aimbotEnabled and menuVisible)
    fovCircle.Color = fovRgb and currentColor or fovColor

    if aimbotEnabled and UserInputService:IsMouseButtonPressed(aimButton) then
        local closestPlayer = nil
        local shortestDistance = fovRadius
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character then
                local root = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mouseLocation).Magnitude
                        if dist < shortestDistance and isPlayerVisible(p.Character) then
                            shortestDistance = dist
                            closestPlayer = p.Character
                        end
                    end
                end
            end
        end
        if closestPlayer then
            local root = closestPlayer:FindFirstChild("Head") or closestPlayer:FindFirstChild("HumanoidRootPart")
            camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, root.Position), aimSmoothness)
        end
    end
end)

local savedCollisions = {}
RunService.Stepped:Connect(function()
    if localPlayer.Character then
        for _, part in ipairs(localPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipEnabled then
                    if savedCollisions[part] == nil then savedCollisions[part] = part.CanCollide end
                    part.CanCollide = false
                else
                    if savedCollisions[part] ~= nil then
                        part.CanCollide = savedCollisions[part]
                        savedCollisions[part] = nil
                    end
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if speedEnabled and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speedValue end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if infJumpEnabled and not gp and input.KeyCode == Enum.KeyCode.Space then
        local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local flyBodyValue = nil
RunService.RenderStepped:Connect(function()
    if flyEnabled and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = localPlayer.Character.HumanoidRootPart
        if not flyBodyValue then
            flyBodyValue = Instance.new("BodyVelocity")
            flyBodyValue.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBodyValue.Parent = root
        end
        local moveDir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        flyBodyValue.Velocity = moveDir * flySpeed
    else
        if flyBodyValue then
            flyBodyValue:Destroy()
            flyBodyValue = nil
        end
    end
end)

local function advancedWeaponSpawner(weaponName)
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("RemoteEvent") and (obj.Name:lower():find("give") or obj.Name:lower():find("spawn") or obj.Name:lower():find("weapon")) then
                obj:FireServer(weaponName)
            elseif obj:IsA("ClickDetector") and obj.Parent and obj.Parent.Name == weaponName then
                fireclickdetector(obj)
            elseif obj:IsA("ProximityPrompt") and obj.Parent and obj.Parent.Name == weaponName then
                fireproximityprompt(obj)
            end
        end
        local targets = {ReplicatedStorage, Workspace, Lighting}
        for _, t in ipairs(targets) do
            local w = t:FindFirstChild(weaponName, true)
            if w and w:IsA("Tool") then
                local c = w:Clone()
                c.Parent = localPlayer.Backpack
                local h = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then h:EquipTool(c) end
                break
            end
        end
    end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HarizmaHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = getProtectedTarget()

local watermark = Instance.new("Frame")
watermark.Name = "HarizmaWatermark"
watermark.Size = UDim2.new(0, 200, 0, 30)
watermark.Position = UDim2.new(0, 15, 0, 15)
watermark.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
watermark.BorderSizePixel = 0
watermark.Parent = screenGui
Instance.new("UICorner", watermark).CornerRadius = UDim.new(0, 6)

local wmText = Instance.new("TextLabel")
wmText.Size = UDim2.new(1, 0, 1, 0)
wmText.BackgroundTransparency = 1
wmText.Font = Enum.Font.GothamBold
wmText.Text = "HARIZMA-SCRIPT v1.2"
wmText.TextColor3 = Color3.fromRGB(255, 255, 255)
wmText.TextSize = 11
wmText.Parent = watermark

local mainHub = Instance.new("Frame")
mainHub.Size = UDim2.new(0, 520, 0, 0)
mainHub.Position = UDim2.new(0.3, 0, 0.25, 0)
mainHub.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
mainHub.BorderSizePixel = 0
mainHub.Active = true
mainHub.ClipsDescendants = true
mainHub.Parent = screenGui
Instance.new("UICorner", mainHub).CornerRadius = UDim.new(0, 8)
makeDraggable(mainHub)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainHub

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -130, 1, 0)
container.Position = UDim2.new(0, 130, 0, 0)
container.BackgroundTransparency = 1
container.Parent = mainHub

local tabs = {"HOME", "ESP", "AIMBOT", "WEAPONS", "FUN"}
local frames = {}

local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.Position = UDim2.new(0, 5, 0, 15 + (index - 1) * 42)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    btn.Font = Enum.Font.GothamBold
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 11
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local f = Instance.new("ScrollingFrame")
    f.Size = UDim2.new(1, -16, 1, -20)
    f.Position = UDim2.new(0, 8, 0, 10)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.ScrollBarThickness = 2
    f.CanvasSize = UDim2.new(0, 0, 0, 450)
    f.Parent = container
    frames[name] = f

    btn.MouseButton1Click:Connect(function()
        for tName, frame in pairs(frames) do frame.Visible = (tName == name) end
    end)
end

for i, t in ipairs(tabs) do createTabButton(t, i) end

local home = frames["HOME"]
local hTitle = Instance.new("TextLabel")
hTitle.Size = UDim2.new(1, 0, 0, 35)
hTitle.Position = UDim2.new(0, 0, 0, 10)
hTitle.BackgroundTransparency = 1
hTitle.Font = Enum.Font.GothamBold
hTitle.Text = "HARIZMA-SCRIPT"
hTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
hTitle.TextSize = 20
hTitle.TextXAlignment = Enum.TextXAlignment.Left
hTitle.Parent = home

local hCredits = Instance.new("TextLabel")
hCredits.Size = UDim2.new(1, 0, 0, 35)
hCredits.Position = UDim2.new(0, 0, 0, 45)
hCredits.BackgroundTransparency = 1
hCredits.Font = Enum.Font.GothamSemibold
hCredits.Text = "Credits:\ndiscord: harizmaang"
hCredits.TextColor3 = Color3.fromRGB(52, 152, 219)
hCredits.TextSize = 13
hCredits.TextXAlignment = Enum.TextXAlignment.Left
hCredits.Parent = home

local hNotice = Instance.new("TextLabel")
hNotice.Size = UDim2.new(1, -10, 0, 140)
hNotice.Position = UDim2.new(0, 0, 0, 95)
hNotice.BackgroundTransparency = 1
hNotice.Font = Enum.Font.GothamMedium
hNotice.Text = "Скрипт находится в активной разработке, новые функции будут стабильно пополняться.\n\n[ ВНИМАНИЕ ]:\nМы не несем ответственность за вас и сохранность вашего аккаунта. Скрипт создан исключительно в ознакомительных и развлекательных целях!"
hNotice.TextColor3 = Color3.fromRGB(180, 180, 185)
hNotice.TextSize = 11
hNotice.TextWrapped = true
hNotice.TextXAlignment = Enum.TextXAlignment.Left
hNotice.TextYAlignment = Enum.TextYAlignment.Top
hNotice.Parent = home

local function createToggle(parent, text, yPos, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 180, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 45, 0, 22)
    btn.Position = UDim2.new(1, -50, 0, 4)
    btn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    btn.Text = ""
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)
        callback(state)
    end)
end

local function createSlider(parent, text, yPos, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 15)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.Text = text .. ": " .. default
    lbl.TextColor3 = Color3.fromRGB(200, 200, 205)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -10, 0, 6)
    bg.Position = UDim2.new(0, 0, 0, 22)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    fill.Parent = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = bg

    local function updateValue(input)
        local pos = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        lbl.Text = text .. ": " .. val
        callback(val)
    end

    local dragging = false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true updateValue(input) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateValue(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

createToggle(frames["ESP"], "Enable Highlight ESP", 10, function(v) espEnabled = v end)
createToggle(frames["ESP"], "Show Player Names", 45, function(v) espShowName = v end)
createToggle(frames["ESP"], "Show Distance (m)", 80, function(v) espShowDist = v end)
createToggle(frames["ESP"], "Show Player Roles", 115, function(v) espShowRole = v end)
createToggle(frames["ESP"], "Show Health Points", 150, function(v) espShowHp = v end)
createToggle(frames["ESP"], "Show Held Items", 185, function(v) espShowItem = v end)
createToggle(frames["ESP"], "Chroma Rainbow ESP", 220, function(v) espRgb = v end)
createToggle(frames["ESP"], "Filter (Admins Only)", 255, function(v) espFilterAdmins = v end)

createToggle(frames["AIMBOT"], "Enable FOV Aimbot", 10, function(v) aimbotEnabled = v end)
createSlider(frames["AIMBOT"], "Aimbot FOV Radius", 45, 30, 400, fovRadius, function(v) fovRadius = v end)
createSlider(frames["AIMBOT"], "Aimbot Smoothness", 90, 1, 100, 15, function(v) aimSmoothness = v / 100 end)
createToggle(frames["AIMBOT"], "Chroma Rainbow FOV", 135, function(v) fovRgb = v end)

local weaponList = {"M4A1", "Glock", "AK47", "Remington", "Knife", "Pistol", "Rifle", "Shotgun", "Crowbar", "Katana"}
for idx, wName in ipairs(weaponList) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.Position = UDim2.new(0, 0, 0, (idx - 1) * 38)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "Spawn: " .. wName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Parent = frames["WEAPONS"]
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    btn.MouseButton1Click:Connect(function() advancedWeaponSpawner(wName) end)
end

createToggle(frames["FUN"], "Enable Safe Noclip", 10, function(v) noclipEnabled = v end)
createToggle(frames["FUN"], "Enable Speed Hack", 45, function(v) speedEnabled = v end)
createSlider(frames["FUN"], "Speed Hack Value", 80, 16, 150, speedValue, function(v) speedValue = v end)
createToggle(frames["FUN"], "Enable Infinite Jump", 125, function(v) infJumpEnabled = v end)
createToggle(frames["FUN"], "Enable Fly Exploit", 160, function(v) flyEnabled = v end)
createSlider(frames["FUN"], "Fly Speed Value", 195, 20, 200, flySpeed, function(v) flySpeed = v end)

frames["HOME"].Visible = true

local function toggleMenuState()
    menuVisible = not menuVisible
    local targetSize = menuVisible and UDim2.new(0, 520, 0, 360) or UDim2.new(0, 520, 0, 0)
    TweenService:Create(mainHub, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    
    if menuVisible then
        for tName, frame in pairs(frames) do frame.Visible = (tName == "HOME") end
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.Insert then toggleMenuState() end
end)

task.wait(0.5)
toggleMenuState()
