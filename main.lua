-- HARIZMA CYBER HUB [ESP & FOV FIXED VERSION]

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer

local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
if not success or not coreGui then 
    coreGui = localPlayer:WaitForChild("PlayerGui") 
end

if coreGui:FindFirstChild("HarizmaCyberHub") then 
    coreGui.HarizmaCyberHub:Destroy() 
end

local RunService = game:GetService("RunService") 
local UserInputService = game:GetService("UserInputService") 
local TweenService = game:GetService("TweenService") 
local Workspace = game:GetService("Workspace") 
local camera = Workspace.CurrentCamera 

-- Состояния хаба
local espEnabled, espShowName, espShowDist, espShowRole, espShowHp = false, false, false, false, false
local aimbotEnabled, fovRadius, aimSmoothness = false, 150, 0.15
local chatEspEnabled = false
local aimButton = Enum.UserInputType.MouseButton2
local noclipEnabled, speedEnabled, speedValue, infJumpEnabled = false, false, 16, false
local flyEnabled, flySpeed = false, 50
local flyDirections = {Forward = 0, Backward = 0, Left = 0, Right = 0, Up = 0, Down = 0}
local menuVisible = false 

-- Кастомизация темы
local themeColor = Color3.fromRGB(0, 255, 200) 
local menuTransparency, buttonTransparency = 0, 0
local currentColor = themeColor 

local savedBinds = { ["esp"] = Enum.KeyCode.X, ["aimbot"] = Enum.KeyCode.V, ["noclip"] = Enum.KeyCode.C, ["fly"] = Enum.KeyCode.F, ["chat"] = nil }
local registryUiToggles, currentlyBinding = {}, nil
local ADMIN_KEYWORDS = {"admin", "mod", "owner", "creator", "dev", "moderator"} 

-- Chat ESP Function
local function showChatBubble(player, message)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = player.Character.Head
    billboard.AlwaysOnTop = true
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 20
    label.Text = message
    label.Parent = billboard
    billboard.Parent = player.Character.Head
    task.delay(4, function() billboard:Destroy() end)
end

Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(msg) if chatEspEnabled then showChatBubble(p, msg) end end) end)
for _, p in pairs(Players:GetPlayers()) do p.Chatted:Connect(function(msg) if chatEspEnabled then showChatBubble(p, msg) end end) end

-- Отрисовка FOV круга
local fovCircle = nil
pcall(function()
    if Drawing and Drawing.new then
        fovCircle = Drawing.new("Circle") 
        fovCircle.Visible = false 
        fovCircle.Thickness = 1.5 
        fovCircle.NumSides = 64 
        fovCircle.Radius = fovRadius 
        fovCircle.Filled = false 
        fovCircle.Transparency = 0.6 
    end
end)

local function isAdmin(player) 
    if player == localPlayer then return false end 
    local n, d = player.Name:lower(), player.DisplayName:lower() 
    for _, k in ipairs(ADMIN_KEYWORDS) do if n:find(k) or d:find(k) then return true end end 
    return false 
end 

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Система Драга UI
local function makeDraggable(frame) 
    local dragging, dragInput, dragStart, startPos 
    frame.InputBegan:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            dragging = true dragStart = input.Position startPos = frame.Position 
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) 
        end 
    end) 
    frame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end) 
    UserInputService.InputChanged:Connect(function(input) 
        if input == dragInput and dragging then 
            local delta = input.Position - dragStart 
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
        end 
    end) 
end 

-- ESP
local function createEspElements(character)
    if not character or character == localPlayer.Character then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    local highlight = character:FindFirstChild("XenoHighlight") or Instance.new("Highlight")
    highlight.Name = "XenoHighlight"
    highlight.FillColor = themeColor
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = character
    highlight.Enabled = false
    highlight.Parent = character
    local textTag = character:FindFirstChild("XenoTextTag") or Instance.new("BillboardGui")
    textTag.Name = "XenoTextTag" 
    textTag.Size = UDim2.new(0, 200, 0, 80) 
    textTag.AlwaysOnTop = true 
    textTag.ExtentsOffset = Vector3.new(0, 3.5, 0)
    textTag.Enabled = false
    local lbl = textTag:FindFirstChild("Label") or Instance.new("TextLabel")
    lbl.Name = "Label" 
    lbl.Size = UDim2.new(1, 0, 1, 0) 
    lbl.BackgroundTransparency = 1 
    lbl.Font = Enum.Font.SourceSansBold 
    lbl.TextSize = 13 
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Parent = textTag
    textTag.Parent = character
end

local function applyEspToAll()
    for _, p in ipairs(Players:GetPlayers()) do 
        if p.Character then createEspElements(p.Character) end 
        p.CharacterAdded:Connect(createEspElements) 
    end
end
applyEspToAll()
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(createEspElements) end)

-- ЕДИНЫЙ ЦИКЛ ОБНОВЛЕНИЯ
RunService.RenderStepped:Connect(function(dt)
    currentColor = Color3.fromHSV((os.clock() % 4) / 4, 0.9, 1) 
    for _, player in ipairs(Players:GetPlayers()) do 
        local character = player.Character
        if character and player ~= localPlayer then
            local highlight = character:FindFirstChild("XenoHighlight")
            local textTag = character:FindFirstChild("XenoTextTag")
            local lbl = textTag and textTag:FindFirstChild("Label")
            if not espEnabled then 
                if highlight then highlight.Enabled = false end
                if textTag then textTag.Enabled = false end 
            else
                local finalColor = themeColor 
                if isAdmin(player) then finalColor = Color3.fromRGB(255, 50, 50) end 
                if highlight then highlight.Enabled = true highlight.FillColor = finalColor end
                if textTag then textTag.Enabled = true end
                if lbl then
                    local textLines = {} 
                    if espShowRole then
                        if isAdmin(player) then table.insert(textLines, "[ADMIN]") 
                        elseif player.Team then table.insert(textLines, "[" .. player.Team.Name .. "]") 
                        else table.insert(textLines, "[No Team]") end
                    end 
                    if espShowName then table.insert(textLines, player.Name) end 
                    if espShowHp then local hum = character:FindFirstChildOfClass("Humanoid") if hum then table.insert(textLines, "HP: " .. math.floor(hum.Health)) end end 
                    if espShowDist then 
                        local root = character:FindFirstChild("HumanoidRootPart") 
                        local lroot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") 
                        if root and lroot then table.insert(textLines, "[" .. math.floor((root.Position - lroot.Position).Magnitude) .. "m]") end 
                    end 
                    lbl.TextColor3 = finalColor 
                    lbl.Text = table.concat(textLines, "\n")
                end
            end
        end
    end 
    if fovCircle then
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = fovRadius
        fovCircle.Visible = aimbotEnabled
        fovCircle.Color = themeColor
    end
    if aimbotEnabled and UserInputService:IsMouseButtonPressed(aimButton) then 
        local closestPlayer, shortestDistance = nil, fovRadius 
        for _, p in ipairs(Players:GetPlayers()) do 
            if p ~= localPlayer and p.Character then 
                local head = p.Character:FindFirstChild("Head")
                if head then 
                    local pos, onScreen = camera:WorldToViewportPoint(head.Position) 
                    if onScreen then 
                        local dist = (Vector2.new(pos.X, pos.Y) - UserInputService:GetMouseLocation()).Magnitude 
                        if dist < shortestDistance then shortestDistance = dist closestPlayer = p.Character end 
                    end 
                end 
            end 
        end 
        if closestPlayer then camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, closestPlayer.Head.Position), aimSmoothness) end 
    end 
    if flyEnabled and localPlayer.Character then
        local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            local moveVector = (camera.CFrame.LookVector * (flyDirections.Forward - flyDirections.Backward)) + (camera.CFrame.RightVector * (flyDirections.Right - flyDirections.Left)) + (Vector3.new(0, 1, 0) * (flyDirections.Up - flyDirections.Down))
            if moveVector.Magnitude > 0 then root.CFrame = root.CFrame + (moveVector.Unit * (flySpeed * dt)) end
        end
    end
    if speedEnabled and localPlayer.Character then 
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid") 
        if hum then hum.WalkSpeed = speedValue end 
    end
end)

RunService.Stepped:Connect(function() 
    if localPlayer.Character and noclipEnabled then 
        for _, part in ipairs(localPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end 
    end 
end) 

UserInputService.InputBegan:Connect(function(i, gp)
    if currentlyBinding then
        if i.KeyCode == Enum.KeyCode.Backspace then savedBinds[currentlyBinding] = nil
        elseif i.KeyCode ~= Enum.KeyCode.Escape then savedBinds[currentlyBinding] = i.KeyCode end
        currentlyBinding = nil return
    end
    if gp or not flyEnabled then return end
    if i.KeyCode == Enum.KeyCode.W then flyDirections.Forward = 1 elseif i.KeyCode == Enum.KeyCode.S then flyDirections.Backward = 1 elseif i.KeyCode == Enum.KeyCode.A then flyDirections.Left = 1 elseif i.KeyCode == Enum.KeyCode.D then flyDirections.Right = 1 elseif i.KeyCode == Enum.KeyCode.Space then flyDirections.Up = 1 elseif i.KeyCode == Enum.KeyCode.LeftShift then flyDirections.Down = 1 end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.W then flyDirections.Forward = 0 elseif i.KeyCode == Enum.KeyCode.S then flyDirections.Backward = 0 elseif i.KeyCode == Enum.KeyCode.A then flyDirections.Left = 0 elseif i.KeyCode == Enum.KeyCode.D then flyDirections.Right = 0 elseif i.KeyCode == Enum.KeyCode.Space then flyDirections.Up = 0 elseif i.KeyCode == Enum.KeyCode.LeftShift then flyDirections.Down = 0 end
end)

-- UI
local screenGui = Instance.new("ScreenGui", coreGui) screenGui.Name = "HarizmaCyberHub"
local mainHub = Instance.new("Frame", screenGui) mainHub.Size = UDim2.new(0, 560, 0, 360) mainHub.Position = UDim2.new(0.3, 0, 0.25, 0) mainHub.BackgroundColor3 = Color3.fromRGB(11, 12, 16) makeDraggable(mainHub)
local sidebar = Instance.new("Frame", mainHub) sidebar.Size = UDim2.new(0, 150, 1, 0) sidebar.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
local container = Instance.new("Frame", mainHub) container.Size = UDim2.new(1, -150, 1, 0) container.Position = UDim2.new(0, 150, 0, 0) container.BackgroundTransparency = 1

local tabs = {"ГЛАВНАЯ", "ESP", "AIMBOT", "ЧАТ", "FUN", "НАСТРОЙКИ"} 
local frames = {}
for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton", sidebar) btn.Size = UDim2.new(1, -10, 0, 35) btn.Position = UDim2.new(0, 5, 0, 50 + (i-1)*40) btn.Text = name btn.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
    local f = Instance.new("ScrollingFrame", container) f.Size = UDim2.new(1, 0, 1, 0) f.Visible = (name == "ГЛАВНАЯ") f.BackgroundTransparency = 1
    frames[name] = f
    btn.MouseButton1Click:Connect(function() for _, frame in pairs(frames) do frame.Visible = false end f.Visible = true end)
end

local function createToggle(parent, text, y, featureId, callback)
    local frame = Instance.new("Frame", parent) frame.Size = UDim2.new(1, 0, 0, 36) frame.Position = UDim2.new(0, 0, 0, y) frame.BackgroundTransparency = 1
    local btn = Instance.new("TextButton", frame) btn.Size = UDim2.new(0, 44, 0, 22) btn.Position = UDim2.new(1, -52, 0, 7) btn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) btn.Text = ""
    local state = false btn.MouseButton1Click:Connect(function() state = not state callback(state) btn.BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60) end)
    Instance.new("TextLabel", frame).Text = text Instance.new("TextLabel", frame).Position = UDim2.new(0, 10, 0, 0) Instance.new("TextLabel", frame).Size = UDim2.new(0, 200, 1, 0)
    if featureId then
        local b = Instance.new("TextButton", frame) b.Size = UDim2.new(0, 50, 0, 22) b.Position = UDim2.new(1, -112, 0, 7) b.Text = "..."
        b.MouseButton1Click:Connect(function() currentlyBinding = featureId b.Text = "Press key" end)
        task.spawn(function() while task.wait(0.3) do if currentlyBinding ~= featureId then b.Text = savedBinds[featureId] and savedBinds[featureId].Name or "None" end end end)
    end
end

createToggle(frames["ESP"], "ESP", 10, "esp", function(v) espEnabled = v end)
createToggle(frames["ESP"], "Имена", 45, nil, function(v) espShowName = v end)
createToggle(frames["ESP"], "Дистанция", 80, nil, function(v) espShowDist = v end)
createToggle(frames["ESP"], "Роли", 115, nil, function(v) espShowRole = v end)
createToggle(frames["ESP"], "HP", 150, nil, function(v) espShowHp = v end)
createToggle(frames["AIMBOT"], "Аимбот", 10, "aimbot", function(v) aimbotEnabled = v end)
createToggle(frames["ЧАТ"], "Показ сообщений", 10, "chat", function(v) chatEspEnabled = v end)
createToggle(frames["FUN"], "Ноуклип", 10, "noclip", function(v) noclipEnabled = v end)
createToggle(frames["FUN"], "Спидхак", 45, nil, function(v) speedEnabled = v end)
createToggle(frames["FUN"], "Полет", 80, "fly", function(v) flyEnabled = v end)

UserInputService.InputBegan:Connect(function(i, gp) if not gp and i.KeyCode == Enum.KeyCode.Insert then mainHub.Visible = not mainHub.Visible end end)

toggleMenuState()
