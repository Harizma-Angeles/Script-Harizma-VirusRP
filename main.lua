-- Защита от повторного запуска (удаление старой версии)
if game:GetService("CoreGui"):FindFirstChild("HarizmaCyberHub") then
    game:GetService("CoreGui"):FindFirstChild("HarizmaCyberHub"):Destroy()
end
if game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("HarizmaCyberHub") then
    game:GetService("Players").LocalPlayer.PlayerGui.HarizmaCyberHub:Destroy()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Состояние функций
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
local fovColor = Color3.fromRGB(0, 255, 200)
local aimButton = Enum.UserInputType.MouseButton2

local noclipEnabled = false
local speedEnabled = false
local speedValue = 16
local infJumpEnabled = false
local flyEnabled = false
local flySpeed = 50
local invisibilityEnabled = false

local antiCuffs = false
local antiBaton = false

local menuVisible = false
local currentColor = Color3.fromRGB(0, 255, 200)

-- Фильтры и списки
local ADMIN_KEYWORDS = {"admin", "mod", "owner", "creator", "dev", "spectator", "moderator", "helper"}
local TARGET_BLACKLIST = {["Hadkera123"] = true, ["Misha231"] = true}

-- Очистка FOV при удалении
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = fovColor
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Radius = fovRadius
fovCircle.Filled = false
fovCircle.Transparency = 0.6

-- Мета-обход античита и блокировка воздействий
local function ultimateBypass()
    local success, raw = pcall(getrawmetatable, game)
    if not success then return end
    setreadonly(raw, false)
    local oldNamecall = raw.__namecall
    
    raw.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if not checkcaller() then
            -- Скрытие объектов скрипта от проверок игры
            if (method == "FindFirstChild" or method == "IsA" or method == "GetChildren") then
                if args[1] == "XenoTestESP" or args[1] == "XenoTextTag" or args[1] == "HarizmaCyberHub" then
                    return nil
                end
            end
            
            -- Анти-батник / Анти-тейзер (Блокировка входящих Remote-эффектов оглушения)
            if antiBaton and method == "FireServer" and self.Name:lower():find("stun") then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(raw, true)
end
pcall(ultimateBypass)

-- Радужный цикл синхронизации
RunService.RenderStepped:Connect(function()
    local hue = (tick() % 4) / 4
    currentColor = Color3.fromHSV(hue, 0.9, 1)
end)

local function isAdmin(player)
    if player == localPlayer then return false end
    local nameLower = player.Name:lower()
    local dispLower = player.DisplayName:lower()
    for _, keyword in ipairs(ADMIN_KEYWORDS) do
        if nameLower:find(keyword) or dispLower:find(keyword) then return true end
    end
    return false
end

-- Жесткий поток защиты персонажа (Анти-наручники / Фиксация)
task.spawn(function()
    while task.wait() do
        pcall(function()
            if antiCuffs and localPlayer.Character then
                for _, obj in ipairs(localPlayer.Character:GetDescendants()) do
                    if obj:IsA("Weld") or obj:IsA("MoverConstraint") or obj:IsA("Seat") then
                        if obj.Name:lower():find("cuff") or obj.Name:lower():find("tie") or obj.Parent.Name:lower():find("cuff") then
                            obj:Destroy()
                        end
                    end
                end
                local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and (hum.PlatformStand or hum.Sit) then
                    hum.PlatformStand = false
                    hum.Sit = false
                end
            end
        end)
    end
end)

-- Логика Невидимки (Invisibility)
task.spawn(function()
    while task.wait() do
        pcall(function()
            if invisibilityEnabled and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local root = localPlayer.Character.HumanoidRootPart
                local clone = root:Clone()
                clone.Parent = localPlayer.Character
                root.CFrame = CFrame.new(0, -9999, 0) -- Прячем настоящий Root под карту
                task.wait(0.1)
                if not invisibilityEnabled then
                    root.CFrame = clone.CFrame
                    clone:Destroy()
                end
            end
        end)
    end
end)

-- Драг-система для GUI
local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Система ESP рендеринга с фильтрами по никнеймам
local function applyEsp(character)
    if not character or character == localPlayer.Character then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    if espFilterAdmins and not isAdmin(player) and not TARGET_BLACKLIST[player.Name] then
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

    local finalColor = espRgb and currentColor or Color3.fromRGB(0, 255, 200)
    if TARGET_BLACKLIST[player.Name] then
        finalColor = Color3.fromRGB(238, 130, 238) -- Фиолетовый маркер для черного списка
    elseif isAdmin(player) then
        finalColor = Color3.fromRGB(255, 50, 50)
    end

    local highlight = oldEsp or Instance.new("Highlight")
    highlight.Name = "XenoTestESP"
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.2
    highlight.FillColor = finalColor
    highlight.Parent = character

    local textLines = {}
    if TARGET_BLACKLIST[player.Name] then table.insert(textLines, "[ЦЕЛЬ ИЗ СПИСКА]") end
    if espShowRole and isAdmin(player) then table.insert(textLines, "[АДМИНИСТРАТОР]") end
    if espShowName then table.insert(textLines, player.Name) end
    if espShowHp then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then table.insert(textLines, "ХП: " .. math.floor(hum.Health)) end
    end
    if espShowDist then
        local root = character:FindFirstChild("HumanoidRootPart")
        local lroot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and lroot then
            table.insert(textLines, "Дистанция: " .. math.floor((root.Position - lroot.Position).Magnitude) .. "м")
        end
    end

    if #textLines > 0 then
        local textTag = oldTag or Instance.new("BillboardGui")
        textTag.Name = "XenoTextTag"
        textTag.Size = UDim2.new(0, 220, 0, 90)
        textTag.AlwaysOnTop = true
        textTag.ExtentsOffset = Vector3.new(0, 3.5, 0)
        
        local lbl = textTag:FindFirstChild("Label") or Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextStrokeTransparency = 0.2
        lbl.TextColor3 = finalColor
        lbl.Text = table.concat(textLines, "\n")
        lbl.Parent = textTag
        textTag.Parent = character
    elseif oldTag then
        oldTag:Destroy()
    end
end

RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then applyEsp(p.Character) end
    end
end)

-- Aimbot FOV & Логика наведения
RunService.RenderStepped:Connect(function()
    local mouseLocation = UserInputService:GetMouseLocation()
    fovCircle.Position = mouseLocation
    fovCircle.Radius = fovRadius
    fovCircle.Visible = (aimbotEnabled and menuVisible) -- Линия исчезает мгновенно при закрытии меню!
    fovCircle.Color = fovRgb and currentColor or fovColor

    if aimbotEnabled and menuVisible and UserInputService:IsMouseButtonPressed(aimButton) then
        local closestPlayer = nil
        local shortestDistance = fovRadius
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character then
                local root = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mouseLocation).Magnitude
                        if dist < shortestDistance then
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

-- Движение персонажа (Noclip, Speed, Fly)
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

-- Сборка интерфейса современного Fluent-приложения
local targetCore = game:GetService("CoreGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HarizmaCyberHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = targetCore

local mainHub = Instance.new("Frame")
mainHub.Size = UDim2.new(0, 560, 0, 0)
mainHub.Position = UDim2.new(0.3, 0, 0.25, 0)
mainHub.BackgroundColor3 = Color3.fromRGB(11, 12, 16)
mainHub.BorderSizePixel = 0
mainHub.Active = true
mainHub.ClipsDescendants = true
mainHub.Parent = screenGui
Instance.new("UICorner", mainHub).CornerRadius = UDim.new(0, 14)
makeDraggable(mainHub)

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.8
stroke.Color = Color3.fromRGB(28, 30, 38)
stroke.Parent = mainHub

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainHub

local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(1, 0, 0, 45)
menuTitle.Position = UDim2.new(0, 14, 0, 8)
menuTitle.BackgroundTransparency = 1
menuTitle.Font = Enum.Font.GothamBold
menuTitle.Text = "HARIZMA-SCRIPT"
menuTitle.TextColor3 = Color3.fromRGB(0, 255, 200)
menuTitle.TextSize = 13
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Parent = sidebar

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -150, 1, 0)
container.Position = UDim2.new(0, 150, 0, 0)
container.BackgroundTransparency = 1
container.Parent = mainHub

local tabs = {"ГЛАВНАЯ", "ESP", "AIMBOT", "FUN", "ПРОЧЕЕ"}
local frames = {}
local tabButtons = {}

local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -18, 0, 36)
    btn.Position = UDim2.new(0, 9, 0, 55 + (index - 1) * 42)
    btn.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
    btn.Font = Enum.Font.GothamBold
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(140, 145, 155)
    btn.TextSize = 11
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    tabButtons[name] = btn

    local f = Instance.new("ScrollingFrame")
    f.Size = UDim2.new(1, -20, 1, -20)
    f.Position = UDim2.new(0, 10, 0, 10)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.ScrollBarThickness = 0
    f.CanvasSize = UDim2.new(0, 0, 0, 500)
    f.Parent = container
    frames[name] = f

    btn.MouseButton1Click:Connect(function()
        for tName, frame in pairs(frames) do
            if tName == name then
                frame.Visible = true
                TweenService:Create(tabButtons[tName], TweenInfo.new(0.25, Enum.EasingStyle.Quart), {TextColor3 = Color3.fromRGB(0, 255, 200), BackgroundColor3 = Color3.fromRGB(28, 33, 45)}):Play()
            else
                frame.Visible = false
                TweenService:Create(tabButtons[tName], TweenInfo.new(0.25, Enum.EasingStyle.Quart), {TextColor3 = Color3.fromRGB(140, 145, 155), BackgroundColor3 = Color3.fromRGB(22, 24, 31)}):Play()
            end
        end
    end)
end

for i, t in ipairs(tabs) do createTabButton(t, i) end

-- Контент вкладки «ГЛАВНАЯ»
local home = frames["ГЛАВНАЯ"]
local hTitle = Instance.new("TextLabel")
hTitle.Size = UDim2.new(1, 0, 0, 30)
hTitle.Position = UDim2.new(0, 0, 0, 10)
hTitle.BackgroundTransparency = 1
hTitle.Font = Enum.Font.GothamBold
hTitle.Text = "ГЛАВНОЕ МЕНЮ"
hTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
hTitle.TextSize = 18
hTitle.TextXAlignment = Enum.TextXAlignment.Left
hTitle.Parent = home

local hCredits = Instance.new("TextLabel")
hCredits.Size = UDim2.new(1, 0, 0, 40)
hCredits.Position = UDim2.new(0, 0, 0, 45)
hCredits.BackgroundTransparency = 1
hCredits.Font = Enum.Font.GothamSemibold
hCredits.Text = "Credits:\ndiscord: harizmaang"
hCredits.TextColor3 = Color3.fromRGB(0, 255, 200)
hCredits.TextSize = 12
hCredits.TextXAlignment = Enum.TextXAlignment.Left
hCredits.Parent = home

local hNotice = Instance.new("TextLabel")
hNotice.Size = UDim2.new(1, -10, 0, 150)
hNotice.Position = UDim2.new(0, 0, 0, 105)
hNotice.BackgroundTransparency = 1
hNotice.Font = Enum.Font.GothamMedium
hNotice.Text = "Скрипт находится в разработке и функции будут пополняться.\n\nМы не несем ответственность за вас и ваш аккаунт. Скрипт сделан в развлекательных целях!"
hNotice.TextColor3 = Color3.fromRGB(150, 155, 165)
hNotice.TextSize = 11
hNotice.TextWrapped = true
hNotice.TextXAlignment = Enum.TextXAlignment.Left
hNotice.TextYAlignment = Enum.TextYAlignment.Top
hNotice.Parent = home

-- Конструктор переключателей нового поколения (Toggle)
local function createToggle(parent, text, yPos, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 240, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamSemibold
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(225, 230, 240)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -52, 0, 7)
    btn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    btn.Text = ""
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 11)

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)}):Play()
        callback(state)
    end)
end

-- Конструктор ползунков (Slider)
local function createSlider(parent, text, yPos, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.Text = text .. ": " .. default
    lbl.TextColor3 = Color3.fromRGB(195, 200, 210)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -12, 0, 6)
    bg.Position = UDim2.new(0, 0, 0, 28)
    bg.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
    bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
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

-- Наполнение вкладок
createToggle(frames["ESP"], "Включить Подсветку (ESP)", 10, function(v) espEnabled = v end)
createToggle(frames["ESP"], "Показывать Никнеймы", 45, function(v) espShowName = v end)
createToggle(frames["ESP"], "Показывать Дистанцию", 80, function(v) espShowDist = v end)
createToggle(frames["ESP"], "Показывать Роли", 115, function(v) espShowRole = v end)
createToggle(frames["ESP"], "Показывать Здоровье (HP)", 150, function(v) espShowHp = v end)
createToggle(frames["ESP"], "Показывать Предмет в Руках", 185, function(v) espShowItem = v end)
createToggle(frames["ESP"], "Радужный Хрома ESP", 220, function(v) espRgb = v end)
createToggle(frames["ESP"], "Фильтр: Только Админы и ЧС", 255, function(v) espFilterAdmins = v end)

createToggle(frames["AIMBOT"], "Включить Аимассист (FOV)", 10, function(v) aimbotEnabled = v end)
createSlider(frames["AIMBOT"], "Радиус FOV", 45, 30, 400, fovRadius, function(v) fovRadius = v end)
createSlider(frames["AIMBOT"], "Плавность Наведения", 95, 1, 100, 15, function(v) aimSmoothness = v / 100 end)
createToggle(frames["AIMBOT"], "Радужный Круг FOV", 145, function(v) fovRgb = v end)

createToggle(frames["FUN"], "Безопасный Ноуклип (Noclip)", 10, function(v) noclipEnabled = v end)
createToggle(frames["FUN"], "Включить Спидхак", 45, function(v) speedEnabled = v end)
createSlider(frames["FUN"], "Скорость бега", 80, 16, 150, speedValue, function(v) speedValue = v end)
createToggle(frames["FUN"], "Бесконечный Прыжок", 130, function(v) infJumpEnabled = v end)
createToggle(frames["FUN"], "Включить Полет (Fly)", 165, function(v) flyEnabled = v end)
createSlider(frames["FUN"], "Скорость полета", 200, 20, 200, flySpeed, function(v) flySpeed = v end)
createToggle(frames["FUN"], "Режим Невидимки (Invis)", 250, function(v) invisibilityEnabled = v end)

-- Вкладка ПРОЧЕЕ (Новый функционал)
local misc = frames["ПРОЧЕЕ"]
createToggle(misc, "Анти-Наручники (Жесткий Обход)", 10, function(v) antiCuffs = v end)
createToggle(misc, "Анти-Дубинка / Электрошокер", 45, function(v) antiBaton = v end)

-- Блок Админ-Листа (Интерфейс вывода)
local adminBox = Instance.new("Frame")
adminBox.Size = UDim2.new(1, -12, 0, 80)
adminBox.Position = UDim2.new(0, 0, 0, 90)
adminBox.BackgroundColor3 = Color3.fromRGB(18, 19, 26)
adminBox.Parent = misc
Instance.new("UICorner", adminBox).CornerRadius = UDim.new(0, 8)

local adminTitle = Instance.new("TextLabel")
adminTitle.Size = UDim2.new(1, 0, 0, 25)
adminTitle.Position = UDim2.new(0, 10, 0, 5)
adminTitle.BackgroundTransparency = 1
adminTitle.Font = Enum.Font.GothamBold
adminTitle.Text = "АКТИВНЫЕ АДМИНИСТРАТОРЫ НА СЕРВЕРЕ:"
adminTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
adminTitle.TextSize = 10
adminTitle.TextXAlignment = Enum.TextXAlignment.Left
adminTitle.Parent = adminBox

local adminLog = Instance.new("TextLabel")
adminLog.Size = UDim2.new(1, -20, 1, -30)
adminLog.Position = UDim2.new(0, 10, 0, 25)
adminLog.BackgroundTransparency = 1
adminLog.Font = Enum.Font.GothamMedium
adminLog.Text = "Сканирование сессии..."
adminLog.TextColor3 = Color3.fromRGB(160, 165, 175)
adminLog.TextSize = 11
adminLog.TextXAlignment = Enum.TextXAlignment.Left
adminLog.TextYAlignment = Enum.TextYAlignment.Top
adminLog.Parent = adminBox

task.spawn(function()
    while task.wait(3) do
        local found = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if isAdmin(p) then table.insert(found, p.Name) end
        end
        if #found == 0 then
            adminLog.Text = "Администраторы не найдены. Чистый сервер."
            adminLog.TextColor3 = Color3.fromRGB(46, 204, 113)
        else
            adminLog.Text = table.concat(found, ", ")
            adminLog.TextColor3 = Color3.fromRGB(231, 76, 60)
        end
    end
end)

-- Конфигурации (Кнопки сохранения параметров сессии)
local btnSave = Instance.new("TextButton")
btnSave.Size = UDim2.new(0, 180, 0, 32)
btnSave.Position = UDim2.new(0, 0, 0, 185)
btnSave.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
btnSave.Font = Enum.Font.GothamBold
btnSave.Text = "Сохранить Конфиг"
btnSave.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSave.TextSize = 11
btnSave.Parent = misc
Instance.new("UICorner", btnSave).CornerRadius = UDim.new(0, 6)

local btnLoad = Instance.new("TextButton")
btnLoad.Size = UDim2.new(0, 180, 0, 32)
btnLoad.Position = UDim2.new(0, 195, 0, 185)
btnLoad.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
btnLoad.Font = Enum.Font.GothamBold
btnLoad.Text = "Загрузить Конфиг"
btnLoad.TextColor3 = Color3.fromRGB(11, 12, 16)
btnLoad.TextSize = 11
btnLoad.Parent = misc
Instance.new("UICorner", btnLoad).CornerRadius = UDim.new(0, 6)

frames["ГЛАВНАЯ"].Visible = true
TweenService:Create(tabButtons["ГЛАВНАЯ"], TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(0, 255, 200), BackgroundColor3 = Color3.fromRGB(28, 33, 45)}):Play()

-- Переключение состояния меню (Плавный выезд)
local function toggleMenuState()
    menuVisible = not menuVisible
    local targetSize = menuVisible and UDim2.new(0, 560, 0, 360) or UDim2.new(0, 560, 0, 0)
    TweenService:Create(mainHub, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    
    if menuVisible then
        for tName, frame in pairs(frames) do 
            frame.Visible = (tName == "ГЛАВНАЯ") 
            if tName == "ГЛАВНАЯ" then
                TweenService:Create(tabButtons[tName], TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(0, 255, 200), BackgroundColor3 = Color3.fromRGB(28, 33, 45)}):Play()
            else
                TweenService:Create(tabButtons[tName], TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(140, 145, 155), BackgroundColor3 = Color3.fromRGB(22, 24, 31)}):Play()
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.Insert then toggleMenuState() end
end)

task.wait(0.3)
toggleMenuState()
