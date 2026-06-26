-- Безопасный поиск контейнера для UI
local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
if not success or not coreGui then coreGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

-- Удаление старой копии
if coreGui:FindFirstChild("HarizmaCyberHub") then coreGui.HarizmaCyberHub:Destroy() end

local Players = game:GetService("Players") 
local RunService = game:GetService("RunService") 
local UserInputService = game:GetService("UserInputService") 
local TweenService = game:GetService("TweenService") 
local Workspace = game:GetService("Workspace") 
local camera = Workspace.CurrentCamera 
local lp = Players.LocalPlayer

-- Состояния хаба
local espEnabled, espShowName, espShowDist, espShowRole, espShowHp = false, false, false, false, false
local aimbotEnabled, fovRadius, aimSmoothness, fovRgb = false, 150, 0.15, false
local fovColor = Color3.fromRGB(0, 255, 200)
local aimButton = Enum.UserInputType.MouseButton2
local noclipEnabled, speedEnabled, speedValue, infJumpEnabled = false, false, 16, false

local flyEnabled, flySpeed = false, 50
local flyDirections = {Forward = 0, Backward = 0, Left = 0, Right = 0, Up = 0, Down = 0}
local flyConnection = nil

local invisibilityEnabled, antiCuffs, antiBaton = false, false, false
local menuVisible = false 

-- Кастомизация темы
local themeColor = Color3.fromRGB(0, 255, 200) 
local menuTransparency, buttonTransparency = 0, 0
local currentColor = themeColor 

local savedBinds = { ["esp"] = Enum.KeyCode.X, ["aimbot"] = Enum.KeyCode.V, ["noclip"] = Enum.KeyCode.C, ["fly"] = Enum.KeyCode.F }
local registryUiToggles, currentlyBinding = {}, nil
local ADMIN_KEYWORDS = {"admin", "mod", "owner", "creator", "dev", "moderator"} 

-- Отрисовка FOV круга (Обернуто в pcall для Xeno)
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

RunService.RenderStepped:Connect(function() 
    currentColor = Color3.fromHSV((tick() % 4) / 4, 0.9, 1) 
end) 

local function isAdmin(player) 
    if player == lp then return false end 
    local n, d = player.Name:lower(), player.DisplayName:lower() 
    for _, k in ipairs(ADMIN_KEYWORDS) do if n:find(k) or d:find(k) then return true end end 
    return false 
end 

-- Безопасный Анти-Баттон и Анти-Куфф без метатаблиц
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if antiCuffs and lp.Character then
                local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                if hum and (hum.PlatformStand or hum.Sit) then 
                    hum.PlatformStand = false 
                    hum.Sit = false 
                end
                for _, v in ipairs(lp.Character:GetDescendants()) do
                    if v:IsA("Weld") and (v.Name:lower():find("cuff") or v.Parent.Name:lower():find("cuff")) then
                        v:Destroy()
                    end
                end
            end
        end)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and lp.Character then
        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Легкий CFrame Полет
local function updateFlyState(state)
    flyEnabled = state
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if not state then return end

    flyConnection = RunService.RenderStepped:Connect(function()
        local char = lp.Character local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        root.AssemblyLinearVelocity = Vector3.zero
        local camLook = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector
        local moveVector = Vector3.zero
        
        moveVector = moveVector + (camLook * (flyDirections.Forward - flyDirections.Backward))
        moveVector = moveVector + (camRight * (flyDirections.Right - flyDirections.Left))
        moveVector = moveVector + (Vector3.new(0, 1, 0) * (flyDirections.Up - flyDirections.Down))
        
        if moveVector.Magnitude > 0 then
            root.CFrame = root.CFrame + (moveVector.Unit * (flySpeed * RunService.RenderStepped:Wait()))
        end
    end)
end

UserInputService.InputBegan:Connect(function(i, gp)
    if gp or not flyEnabled then return end
    if i.KeyCode == Enum.KeyCode.W then flyDirections.Forward = 1
    elseif i.KeyCode == Enum.KeyCode.S then flyDirections.Backward = 1
    elseif i.KeyCode == Enum.KeyCode.A then flyDirections.Left = 1
    elseif i.KeyCode == Enum.KeyCode.D then flyDirections.Right = 1
    elseif i.KeyCode == Enum.KeyCode.Space then flyDirections.Up = 1
    elseif i.KeyCode == Enum.KeyCode.LeftShift then flyDirections.Down = 1 end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.W then flyDirections.Forward = 0
    elseif i.KeyCode == Enum.KeyCode.S then flyDirections.Backward = 0
    elseif i.KeyCode == Enum.KeyCode.A then flyDirections.Left = 0
    elseif i.KeyCode == Enum.KeyCode.D then flyDirections.Right = 0
    elseif i.KeyCode == Enum.KeyCode.Space then flyDirections.Up = 0
    elseif i.KeyCode == Enum.KeyCode.LeftShift then flyDirections.Down = 0 end
end)

-- Невидимка (Визуальное скрытие)
local function updateInvisState(state)
    invisibilityEnabled = state
    local char = lp.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Transparency = state and 1 or 0
        end
    end
end

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

-- Стабильное 2D ESP без использования крашащих Highlight элементов
local function createEspElements(character)
    if not character or character == lp.Character then return end
    
    local textTag = character:FindFirstChild("XenoTextTag") or Instance.new("BillboardGui")
    textTag.Name = "XenoTextTag" 
    textTag.Size = UDim2.new(0, 200, 0, 60) 
    textTag.AlwaysOnTop = true 
    textTag.ExtentsOffset = Vector3.new(0, 3, 0)
    
    local lbl = textTag:FindFirstChild("Label") or Instance.new("TextLabel")
    lbl.Name = "Label" 
    lbl.Size = UDim2.new(1, 0, 1, 0) 
    lbl.BackgroundTransparency = 1 
    lbl.Font = Enum.Font.SourceSansBold 
    lbl.TextSize = 13 
    lbl.TextStrokeTransparency = 0.3 
    lbl.Parent = textTag
    textTag.Parent = character
end

for _, p in ipairs(Players:GetPlayers()) do if p.Character then createEspElements(p.Character) end p.CharacterAdded:Connect(createEspElements) end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(createEspElements) end)

RunService.RenderStepped:Connect(function() 
    for _, player in ipairs(Players:GetPlayers()) do 
        local character = player.Character
        if not character or player == lp then continue end
        local textTag = character:FindFirstChild("XenoTextTag")
        local lbl = textTag and textTag:FindFirstChild("Label")

        if not espEnabled then 
            if textTag then textTag.Enabled = false end 
            continue 
        end 

        if textTag then textTag.Enabled = true end
        local finalColor = themeColor 
        if isAdmin(player) then finalColor = Color3.fromRGB(255, 50, 50) end 

        if lbl then
            local textLines = {} 
            if espShowRole and isAdmin(player) then table.insert(textLines, "[ADMIN]") end 
            if espShowName then table.insert(textLines, player.Name) end 
            if espShowHp then local hum = character:FindFirstChildOfClass("Humanoid") if hum then table.insert(textLines, "HP: " .. math.floor(hum.Health)) end end 
            if espShowDist then 
                local root = character:FindFirstChild("HumanoidRootPart") local lroot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") 
                if root and lroot then table.insert(textLines, "[" .. math.floor((root.Position - lroot.Position).Magnitude) .. "m]") end 
            end 
            lbl.TextColor3 = finalColor 
            lbl.Text = table.concat(textLines, " ")
        end
    end 
end) 

-- Легкий Аимбот
RunService.RenderStepped:Connect(function() 
    local mouseLocation = UserInputService:GetMouseLocation() 
    
    if fovCircle then
        fovCircle.Position = mouseLocation 
        fovCircle.Radius = fovRadius 
        fovCircle.Visible = (aimbotEnabled and menuVisible) 
        fovCircle.Color = themeColor 
    end

    if aimbotEnabled and UserInputService:IsMouseButtonPressed(aimButton) then 
        local closestPlayer, shortestDistance = nil, fovRadius 
        for _, p in ipairs(Players:GetPlayers()) do 
            if p ~= lp and p.Character then 
                local root = p.Character:FindFirstChild("Head")
                if root then 
                    local pos, onScreen = camera:WorldToViewportPoint(root.Position) 
                    if onScreen then 
                        local dist = (Vector2.new(pos.X, pos.Y) - mouseLocation).Magnitude 
                        if dist < shortestDistance then shortestDistance = dist closestPlayer = p.Character end 
                    end 
                end 
            end 
        end 
        if closestPlayer then 
            local root = closestPlayer:FindFirstChild("Head")
            if root then
                camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, root.Position), aimSmoothness) 
            end
        end 
    end 
end) 

-- Ноуклип и Спидхак
RunService.Stepped:Connect(function() 
    if lp.Character and noclipEnabled then 
        for _, part in ipairs(lp.Character:GetDescendants()) do 
            if part:IsA("BasePart") then part.CanCollide = false end 
        end 
    end 
end) 

RunService.RenderStepped:Connect(function() 
    if speedEnabled and lp.Character then 
        local hum = lp.Character:FindFirstChildOfClass("Humanoid") 
        if hum then hum.WalkSpeed = speedValue end 
    end 
end) 

-- Конструктор UI (Полная совместимость)
local screenGui = Instance.new("ScreenGui") screenGui.Name = "HarizmaCyberHub" screenGui.ResetOnSpawn = false screenGui.Parent = coreGui 
local mainHub = Instance.new("Frame") mainHub.Size = UDim2.new(0, 560, 0, 360) mainHub.Position = UDim2.new(0.3, 0, 0.25, 0) mainHub.BackgroundColor3 = Color3.fromRGB(11, 12, 16) mainHub.BorderSizePixel = 0 mainHub.Active = true mainHub.ClipsDescendants = true mainHub.Parent = screenGui 
Instance.new("UICorner", mainHub).CornerRadius = UDim.new(0, 14) makeDraggable(mainHub) 

local sidebar = Instance.new("Frame") sidebar.Size = UDim2.new(0, 150, 1, 0) sidebar.BackgroundColor3 = Color3.fromRGB(15, 16, 22) sidebar.BorderSizePixel = 0 sidebar.Parent = mainHub 
local menuTitle = Instance.new("TextLabel") menuTitle.Size = UDim2.new(1, 0, 0, 45) menuTitle.Position = UDim2.new(0, 14, 0, 8) menuTitle.BackgroundTransparency = 1 menuTitle.Font = Enum.Font.GothamBold menuTitle.Text = "HARIZMA HACK" menuTitle.TextColor3 = themeColor menuTitle.TextSize = 13 menuTitle.TextXAlignment = Enum.TextXAlignment.Left menuTitle.Parent = sidebar 
local container = Instance.new("Frame") container.Size = UDim2.new(1, -150, 1, 0) container.Position = UDim2.new(0, 150, 0, 0) container.BackgroundTransparency = 1 container.Parent = mainHub 

local tabs = {"ГЛАВНАЯ", "ESP", "AIMBOT", "FUN", "ПРОЧЕЕ", "НАСТРОЙКИ"} 
local frames, tabButtons = {}, {} 

local function createTabButton(name, index) 
    local btn = Instance.new("TextButton") 
    if name == "НАСТРОЙКИ" then btn.Size = UDim2.new(1, -18, 0, 32) btn.Position = UDim2.new(0, 9, 1, -42) btn.Text = "⚙ НАСТРОЙКИ" else btn.Size = UDim2.new(1, -18, 0, 36) btn.Position = UDim2.new(0, 9, 0, 55 + (index - 1) * 42) btn.Text = name end
    btn.BackgroundColor3 = Color3.fromRGB(22, 24, 31) btn.Font = Enum.Font.GothamBold btn.TextColor3 = Color3.fromRGB(140, 145, 155) btn.TextSize = 11 btn.Parent = sidebar Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8) tabButtons[name] = btn 

    local f = Instance.new("ScrollingFrame") f.Size = UDim2.new(1, -20, 1, -20) f.Position = UDim2.new(0, 10, 0, 10) f.BackgroundTransparency = 1 f.Visible = false f.ScrollBarThickness = 0 f.CanvasSize = UDim2.new(0, 0, 0, 400) f.Parent = container frames[name] = f 

    btn.MouseButton1Click:Connect(function() 
        for tName, frame in pairs(frames) do 
            if tName == name then frame.Visible = true TweenService:Create(tabButtons[tName], TweenInfo.new(0.2, Enum.EasingStyle.Quart), {TextColor3 = themeColor, BackgroundColor3 = Color3.fromRGB(28, 33, 45)}):Play() else frame.Visible = false TweenService:Create(tabButtons[tName], TweenInfo.new(0.2, Enum.EasingStyle.Quart), {TextColor3 = Color3.fromRGB(140, 145, 155), BackgroundColor3 = Color3.fromRGB(22, 24, 31)}):Play() end
        end 
    end) 
end 
for i, t in ipairs(tabs) do createTabButton(t, i) end 

task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            menuTitle.TextColor3 = themeColor mainHub.BackgroundTransparency = menuTransparency sidebar.BackgroundTransparency = menuTransparency
            for tName, btn in pairs(tabButtons) do btn.BackgroundTransparency = buttonTransparency if btn.TextColor3 ~= Color3.fromRGB(140, 145, 155) then btn.TextColor3 = themeColor end end
        end)
    end
end)

local function createToggle(parent, text, yPos, featureId, callback) 
    local frame = Instance.new("Frame") frame.Size = UDim2.new(1, 0, 0, 36) frame.Position = UDim2.new(0, 0, 0, yPos) frame.BackgroundTransparency = 1 frame.Parent = parent 
    local lbl = Instance.new("TextLabel") lbl.Size = UDim2.new(0, 200, 1, 0) lbl.BackgroundTransparency = 1 lbl.Font = Enum.Font.GothamSemibold lbl.Text = text lbl.TextColor3 = Color3.fromRGB(225, 230, 240) lbl.TextSize = 12 lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Parent = frame 
    local btn = Instance.new("TextButton") btn.Size = UDim2.new(0, 44, 0, 22) btn.Position = UDim2.new(1, -52, 0, 7) btn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) btn.Text = "" btn.Parent = frame Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 11) 

    local state = false 
    local function setVisualState(targetState) state = targetState pcall(function() TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)}):Play() end) end
    btn.MouseButton1Click:Connect(function() state = not state setVisualState(state) callback(state) end)

    if featureId then
        registryUiToggles[featureId] = { GetState = function() return state end, SetState = function(s) setVisualState(s) callback(s) end }
        local bindBtn = Instance.new("TextButton") bindBtn.Size = UDim2.new(0, 50, 0, 22) bindBtn.Position = UDim2.new(1, -112, 0, 7) bindBtn.BackgroundColor3 = Color3.fromRGB(25, 27, 36) bindBtn.Font = Enum.Font.GothamBold bindBtn.TextSize = 10 bindBtn.TextColor3 = Color3.fromRGB(180, 185, 195) bindBtn.Text = savedBinds[featureId] and savedBinds[featureId].Name or "None" bindBtn.Parent = frame Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0, 5)
        bindBtn.MouseButton1Click:Connect(function() if currentlyBinding then return end currentlyBinding = featureId bindBtn.Text = "..." end)
        task.spawn(function() while task.wait(0.3) do if currentlyBinding ~= featureId then bindBtn.Text = savedBinds[featureId] and savedBinds[featureId].Name or "None" end end end)
    end
end 

local function createSlider(parent, text, yPos, min, max, default, callback) 
    local frame = Instance.new("Frame") frame.Size = UDim2.new(1, 0, 0, 48) frame.Position = UDim2.new(0, 0, 0, yPos) frame.BackgroundTransparency = 1 frame.Parent = parent 
    local lbl = Instance.new("TextLabel") lbl.Size = UDim2.new(1, 0, 0, 16) lbl.BackgroundTransparency = 1 lbl.Font = Enum.Font.GothamMedium lbl.Text = text .. ": " .. default lbl.TextColor3 = Color3.fromRGB(195, 200, 210) lbl.TextSize = 11 lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Parent = frame 
    local bg = Instance.new("Frame") bg.Size = UDim2.new(1, -12, 0, 6) bg.Position = UDim2.new(0, 0, 0, 28) bg.BackgroundColor3 = Color3.fromRGB(32, 34, 44) bg.Parent = frame Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 3) 
    local fill = Instance.new("Frame") fill.Size = UDim2.new(math.clamp((default - min) / math.max(1, max - min), 0, 1), 0, 1, 0) fill.BackgroundColor3 = themeColor fill.Parent = bg Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3) 
    local btn = Instance.new("TextButton") btn.Size = UDim2.new(1, 0, 1, 0) btn.BackgroundTransparency = 1 btn.Text = "" btn.Parent = bg 

    local function updateValue(input) 
        local pos = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1) 
        local val = math.floor(min + (max - min) * pos) fill.Size = UDim2.new(pos, 0, 1, 0) lbl.Text = text .. ": " .. val callback(val) 
    end 
    local dragging = false 
    btn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true updateValue(input) end end) 
    UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateValue(input) end end) 
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end) 
    task.spawn(function() while task.wait(0.2) do fill.BackgroundColor3 = themeColor end end)
end 

-- Главный экран
local home = frames["ГЛАВНАЯ"] 
local hTitle = Instance.new("TextLabel") hTitle.Size = UDim2.new(1, 0, 0, 30) hTitle.Position = UDim2.new(0, 0, 0, 10) hTitle.BackgroundTransparency = 1 hTitle.Font = Enum.Font.GothamBold hTitle.Text = "ГЛАВНОЕ МЕНЮ [XENO]" hTitle.TextColor3 = Color3.fromRGB(255, 255, 255) hTitle.TextSize = 18 hTitle.TextXAlignment = Enum.TextXAlignment.Left hTitle.Parent = home 
local hCredits = Instance.new("TextLabel") hCredits.Size = UDim2.new(1, 0, 0, 40) hCredits.Position = UDim2.new(0, 0, 0, 45) hCredits.BackgroundTransparency = 1 hCredits.Font = Enum.Font.GothamSemibold hCredits.Text = "Credits:\ndiscord: harizmaang" hCredits.TextColor3 = themeColor hCredits.TextSize = 12 hCredits.TextXAlignment = Enum.TextXAlignment.Left hCredits.Parent = home 

createToggle(frames["ESP"], "Включить Подсветку (ESP)", 10, "esp", function(v) espEnabled = v end) 
createToggle(frames["ESP"], "Показывать Никнеймы", 45, nil, function(v) espShowName = v end) 
createToggle(frames["ESP"], "Показывать Дистанцию", 80, nil, function(v) espShowDist = v end) 
createToggle(frames["ESP"], "Показывать Роли", 115, nil, function(v) espShowRole = v end) 
createToggle(frames["ESP"], "Показывать Здоровье (HP)", 150, nil, function(v) espShowHp = v end) 

createToggle(frames["AIMBOT"], "Включить Аимассист (FOV)", 10, "aimbot", function(v) aimbotEnabled = v end) 
createSlider(frames["AIMBOT"], "Радиус FOV", 45, 30, 400, fovRadius, function(v) fovRadius = v end) 
createSlider(frames["AIMBOT"], "Плавность Наведения", 95, 1, 100, 15, function(v) aimSmoothness = v / 100 end) 

createToggle(frames["FUN"], "Безопасный Ноуклип (Noclip)", 10, "noclip", function(v) noclipEnabled = v end) 
createToggle(frames["FUN"], "Включить Спидхак", 45, nil, function(v) speedEnabled = v end) 
createSlider(frames["FUN"], "Скорость бега", 80, 16, 150, speedValue, function(v) speedValue = v end) 
createToggle(frames["FUN"], "Бесконечный Прыжок", 130, nil, function(v) infJumpEnabled = v end) 
createToggle(frames["FUN"], "Включить Полет (Fly)", 165, "fly", function(v) updateFlyState(v) end) 
createSlider(frames["FUN"], "Скорость полета", 200, 20, 200, flySpeed, function(v) flySpeed = v end) 
createToggle(frames["FUN"], "Режим Невидимки (Invis)", 250, nil, function(v) updateInvisState(v) end) 

local misc = frames["ПРОЧЕЕ"] 
createToggle(misc, "Анти-Наручники", 10, nil, function(v) antiCuffs = v end) 

local settingsFrame = frames["НАСТРОЙКИ"]
createSlider(settingsFrame, "Прозрачность Меню (%)", 10, 0, 90, 0, function(v) menuTransparency = v / 100 end)
createSlider(settingsFrame, "Прозрачность Кнопок (%)", 60, 0, 90, 0, function(v) buttonTransparency = v / 100 end)
local rVal, gVal, bVal = 0, 255, 200
createSlider(settingsFrame, "Цвет: Красный (R)", 110, 0, 255, 0, function(v) rVal = v themeColor = Color3.fromRGB(rVal, gVal, bVal) end)
createSlider(settingsFrame, "Цвет: Зеленый (G)", 160, 0, 255, 255, function(v) gVal = v themeColor = Color3.fromRGB(rVal, gVal, bVal) end)
createSlider(settingsFrame, "Цвет: Синий (B)", 210, 0, 255, 200, function(v) bVal = v themeColor = Color3.fromRGB(rVal, gVal, bVal) end)

frames["ГЛАВНАЯ"].Visible = true 
pcall(function() TweenService:Create(tabButtons["ГЛАВНАЯ"], TweenInfo.new(0.1), {TextColor3 = themeColor, BackgroundColor3 = Color3.fromRGB(28, 33, 45)}):Play() end)

local function toggleMenuState() 
    menuVisible = not menuVisible 
    local targetSize = menuVisible and UDim2.new(0, 560, 0, 360) or UDim2.new(0, 560, 0, 0) 
    pcall(function() TweenService:Create(mainHub, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play() end)
end 

UserInputService.InputBegan:Connect(function(input, gp) 
    if currentlyBinding then
        if input.KeyCode == Enum.KeyCode.Escape then savedBinds[currentlyBinding] = nil else savedBinds[currentlyBinding] = input.KeyCode end
        currentlyBinding = nil return
    end
    if gp then return end 
    if input.KeyCode == Enum.KeyCode.Insert then toggleMenuState() 
    else
        for id, keyCode in pairs(savedBinds) do
            if keyCode and input.KeyCode == keyCode and registryUiToggles[id] then
                local state = registryUiToggles[id].GetState() registryUiToggles[id].SetState(not state)
            end
        end
    end
end) 

toggleMenuState()
