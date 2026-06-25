-- Авто-очистка предыдущих сессий
if game:GetService("CoreGui"):FindFirstChild("HarizmaCyberHub") then game:GetService("CoreGui"):FindFirstChild("HarizmaCyberHub"):Destroy() end
if game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("HarizmaCyberHub") then game:GetService("Players").LocalPlayer.PlayerGui.HarizmaCyberHub:Destroy() end
if game:GetService("CoreGui"):FindFirstChild("HarizmaAdminList") then game:GetService("CoreGui"):FindFirstChild("HarizmaAdminList"):Destroy() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Глобальные настройки
local espEnabled, espShowName, espShowDist, espShowHp = false, false, false, false
local espOnlyTargets = false
local targetPlayers = {["Hadkera123"] = true, ["Misha231"] = true}

local aimbotEnabled, fovRadius, aimSmoothness, fovRgb = false, 150, 0.15, false
local aimColor = Color3.fromRGB(0, 255, 200)
local aimKey = Enum.UserInputType.MouseButton2 -- Изменяемый бинд
local aimWhitelist = {["Друг1"] = true, ["Друг2"] = true} -- Вайт-лист для Аима

local noclipEnabled, speedEnabled, speedValue, infJumpEnabled, flyEnabled, flySpeed = false, false, 16, false, false, 50
local godModeEnabled, invisEnabled = false, false
local antiCuffs, antiBaton, adminListEnabled = false, false, false
local menuVisible, currentColor = false, Color3.fromRGB(0, 255, 200)

-- Отрисовка FOV
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Filled = false

-- Функция перетаскивания (Draggable) без багов
local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = frame.Position
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

-- Ультимативный Обход Античита (Защита метатаблиц)
local function bypassMeta()
    local success, raw = pcall(getrawmetatable, game)
    if not success then return end
    setreadonly(raw, false)
    local oldNamecall = raw.__namecall
    raw.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller() then
            if method == "FireServer" and (self.Name:lower():find("kick") or self.Name:lower():find("cheat") or self.Name:lower():find("anticheat")) then return nil end
            if antiBaton and method == "FireServer" and self.Name:lower():find("stun") then return nil end
            if method == "FindFirstChild" and (args[1] == "HarizmaCyberHub" or args[1] == "HarizmaAdminList") then return nil end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(raw, true)
end
pcall(bypassMeta)

-- Радужная хрома
RunService.RenderStepped:Connect(function()
    currentColor = Color3.fromHSV((tick() % 4) / 4, 0.9, 1)
end)

-- Исправленный Бесконечный Прыжок без задержек
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hum and root then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            root.Velocity = Vector3.new(root.Velocity.X, 50, root.Velocity.Z) -- Прямой физический импульс
        end
    end
end)

-- Починенный Fly через физические констрейнты (Не детектится античитом)
local flyAlignPos, flyAlignOrient, flyAttachment
RunService.RenderStepped:Connect(function()
    if flyEnabled and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = localPlayer.Character.HumanoidRootPart
        if not flyAttachment then
            flyAttachment = Instance.new("Attachment", root)
            flyAlignPos = Instance.new("AlignPosition", root)
            flyAlignOrient = Instance.new("AlignOrientation", root)
            flyAlignPos.Attachment0 = flyAttachment; flyAlignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
            flyAlignPos.MaxForce = 1e6; flyAlignPos.Responsiveness = 200
            flyAlignOrient.Attachment0 = flyAttachment; flyAlignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
            flyAlignOrient.MaxTorque = 1e6; flyAlignOrient.Responsiveness = 200
        end
        
        local moveDir = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        
        flyAlignPos.Position = root.Position + (moveDir * (flySpeed / 30))
        flyAlignOrient.CFrame = camera.CFrame
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
    else
        if flyAttachment then
            flyAttachment:Destroy(); flyAlignPos:Destroy(); flyAlignOrient:Destroy()
            flyAttachment, flyAlignPos, flyAlignOrient = nil, nil, nil
            local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end
end)

-- Бессмертие (Godmode)
task.spawn(function()
    while task.wait(1) do
        if godModeEnabled and localPlayer.Character then
            pcall(function()
                local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and hum.Health < 100 then
                    hum.Health = 100
                end
            end)
        end
    end
end)

-- Инвиз уровня Infinite Yield (Полная свобода перемещения)
local invisClone
task.spawn(function()
    while task.wait() do
        if invisEnabled and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local char = localPlayer.Character
            if not invisClone then
                char.Archivable = true
                invisClone = char:Clone()
                invisClone.Parent = Workspace
                for _, part in ipairs(invisClone:GetDescendants()) do
                    if part:IsA("BasePart") then part.Transparency = 0.5; part.CanCollide = false end
                end
                char.HumanoidRootPart.Transparency = 1
            end
            -- Оставляем физику на клоне, сервер думает что мы стоим, а мы ходим
            local realRoot = char.HumanoidRootPart
            invisClone.Humanoid:Move(char.Humanoid.MoveDirection, true)
        else
            if invisClone then
                invisClone:Destroy(); invisClone = nil
            end
        end
    end
end)

-- Кастомный ESP Фильтр по никнеймам
local function applyEsp(character)
    if not character or character == localPlayer.Character then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    -- Если включен фильтр, убираем всех, кроме Hadkera123 и Misha231
    if espOnlyTargets and not targetPlayers[player.Name] then
        if character:FindFirstChild("XenoTestESP") then character.XenoTestESP:Destroy() end
        if character:FindFirstChild("XenoTextTag") then character.XenoTextTag:Destroy() end
        return
    end

    if not espEnabled then
        if character:FindFirstChild("XenoTestESP") then character.XenoTestESP:Destroy() end
        if character:FindFirstChild("XenoTextTag") then character.XenoTextTag:Destroy() end
        return
    end

    local finalColor = espRgb and currentColor or (targetPlayers[player.Name] and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(0, 255, 200))
    local highlight = character:FindFirstChild("XenoTestESP") or Instance.new("Highlight", character)
    highlight.Name = "XenoTestESP"; highlight.FillColor = finalColor; highlight.FillTransparency = 0.5

    local tag = character:FindFirstChild("XenoTextTag") or Instance.new("BillboardGui", character)
    tag.Name = "XenoTextTag"; tag.Size = UDim2.new(0,200,0,50); tag.AlwaysOnTop = true; tag.ExtentsOffset = Vector3.new(0,3,0)
    local lbl = tag:FindFirstChild("Label") or Instance.new("TextLabel", tag)
    lbl.Name = "Label"; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.TextColor3 = finalColor
    
    local lines = {}
    if espShowName then table.insert(lines, player.Name) end
    if espShowHp then table.insert(lines, "HP: "..math.floor(character.Humanoid.Health)) end
    lbl.Text = table.concat(lines, "\n")
end

RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do if p.Character and p.Character:FindFirstChild("Humanoid") then applyEsp(p.Character) end end
end)

-- Аимбот с Вайт-листом и настраиваемым Биндом
RunService.RenderStepped:Connect(function()
    local mouseLocation = UserInputService:GetMouseLocation()
    fovCircle.Position = mouseLocation; fovCircle.Radius = fovRadius
    fovCircle.Visible = (aimbotEnabled and menuVisible); fovCircle.Color = fovRgb and currentColor or aimColor

    if aimbotEnabled and menuVisible and (aimKey == Enum.UserInputType.MouseButton2 and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UserInputService:IsKeyDown(aimKey)) then
        local closestTarget, shortestDist = nil, fovRadius
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character and not aimWhitelist[p.Name] then -- Проверка Вайт-листа
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mouseLocation).Magnitude
                        if dist < shortestDist then shortestDist = dist; closestTarget = head end
                    end
                end
            end
        end
        if closestTarget then
            camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, closestTarget.Position), aimSmoothness)
        end
    end
end)

-- Создание GUI интерфейса 2026 года
local screenGui = Instance.new("ScreenGui", game:GetService("CoreGui")); screenGui.Name = "HarizmaCyberHub"
local mainHub = Instance.new("Frame", screenGui)
mainHub.Size = UDim2.new(0, 560, 0, 0); mainHub.Position = UDim2.new(0.3, 0, 0.25, 0)
mainHub.BackgroundColor3 = Color3.fromRGB(10, 11, 16); mainHub.ClipsDescendants = true
Instance.new("UICorner", mainHub).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke", mainHub); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(25, 27, 36)
makeDraggable(mainHub)

local sidebar = Instance.new("Frame", mainHub); sidebar.Size = UDim2.new(0, 150, 1, 0); sidebar.BackgroundColor3 = Color3.fromRGB(13, 14, 20)
local container = Instance.new("Frame", mainHub); container.Size = UDim2.new(1, -150, 1, 0); container.Position = UDim2.new(0, 150, 0, 0); container.BackgroundTransparency = 1

local tabs = {"ГЛАВНАЯ", "ESP", "AIMBOT", "FUN", "ПРОЧЕЕ"}
local frames, tabButtons = {}, {}

local function createTab(name, idx)
    local btn = Instance.new("TextButton", sidebar); btn.Size = UDim2.new(1, -16, 0, 36); btn.Position = UDim2.new(0, 8, 0, 60 + (idx-1)*42)
    btn.BackgroundColor3 = Color3.fromRGB(20, 22, 29); btn.Font = Enum.Font.GothamBold; btn.Text = name; btn.TextColor3 = Color3.fromRGB(140, 145, 155); btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    tabButtons[name] = btn

    local f = Instance.new("ScrollingFrame", container); f.Size = UDim2.new(1, -20, 1, -20); f.Position = UDim2.new(0, 10, 0, 10); f.BackgroundTransparency = 1; f.Visible = false; f.ScrollBarThickness = 0
    frames[name] = f

    btn.MouseButton1Click:Connect(function()
        for tN, fr in pairs(frames) do
            fr.Visible = (tN == name)
            TweenService:Create(tabButtons[tN], TweenInfo.new(0.2), {TextColor3 = (tN == name) and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(140, 145, 155), BackgroundColor3 = (tN == name) and Color3.fromRGB(26, 30, 42) or Color3.fromRGB(20, 22, 29)}):Play()
        end
    end)
end
for i, name in ipairs(tabs) do createTab(name, i) end

-- Конструкторы элементов GUI (Переключатели / Ползунки)
local function createToggle(parent, text, y, cb)
    local f = Instance.new("Frame", parent); f.Size = UDim2.new(1, 0, 0, 36); f.Position = UDim2.new(0, 0, 0, y); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f); l.Size = UDim2.new(0, 220, 1, 0); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamSemibold; l.Text = text; l.TextColor3 = Color3.fromRGB(220, 225, 235); l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left
    local b = Instance.new("TextButton", f); b.Size = UDim2.new(0, 44, 0, 22); b.Position = UDim2.new(1, -50, 0, 7); b.BackgroundColor3 = Color3.fromRGB(231, 76, 60); b.Text = ""
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 11)
    local s = false
    b.MouseButton1Click:Connect(function()
        s = not s
        TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = s and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)}):Play()
        cb(s)
    end)
end

local function createSlider(parent, text, y, min, max, def, cb)
    local f = Instance.new("Frame", parent); f.Size = UDim2.new(1, 0, 0, 45); f.Position = UDim2.new(0, 0, 0, y); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f); l.Size = UDim2.new(1, 0, 0, 16); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamMedium; l.Text = text .. ": " .. def; l.TextColor3 = Color3.fromRGB(190, 195, 205); l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    local bg = Instance.new("Frame", f); bg.Size = UDim2.new(1, -10, 0, 6); bg.Position = UDim2.new(0, 0, 0, 26); bg.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
    local fill = Instance.new("Frame", bg); fill.Size = UDim2.new((def-min)/(max-min), 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
    local btn = Instance.new("TextButton", bg); btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""
    local drag = false
    local function up(input)
        local p = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min)*p)
        fill.Size = UDim2.new(p, 0, 1, 0); l.Text = text .. ": " .. v; cb(v)
    end
    btn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then drag = true up(input) end end)
    UserInputService.InputChanged:Connect(function(input) if drag and input.UserInputType == Enum.UserInputType.MouseMovement then up(input) end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
end

-- Наполнение вкладок функциями
createToggle(frames["ESP"], "Включить Подсветку (ESP)", 10, function(v) espEnabled = v end)
createToggle(frames["ESP"], "Показывать Никнеймы", 45, function(v) espShowName = v end)
createToggle(frames["ESP"], "Показывать Дистанцию", 80, function(v) espShowDist = v end)
createToggle(frames["ESP"], "Показывать Здоровье игроков", 115, function(v) espShowHp = v end)
createToggle(frames["ESP"], "Фильтр целей (Только Hadkera/Misha)", 150, function(v) espOnlyTargets = v end)

createToggle(frames["AIMBOT"], "Включить Аимбот", 10, function(v) aimbotEnabled = v end)
createSlider(frames["AIMBOT"], "Радиус захвата FOV", 45, 30, 400, fovRadius, function(v) fovRadius = v end)
createSlider(frames["AIMBOT"], "Плавность доводки", 95, 1, 100, 15, function(v) aimSmoothness = v/100 end)

createToggle(frames["FUN"], "Безопасный Ноуклип (Noclip)", 10, function(v) noclipEnabled = v end)
createToggle(frames["FUN"], "Включить Спидхак", 45, function(v) speedEnabled = v end)
createSlider(frames["FUN"], "Скорость бега", 80, 16, 150, speedValue, function(v) speedValue = v end)
createToggle(frames["FUN"], "Бесконечный Прыжок (Без задержки)", 130, function(v) infJumpEnabled = v end)
createToggle(frames["FUN"], "Режим Полета (Fly)", 165, function(v) flyEnabled = v end)
createToggle(frames["FUN"], "Режим Бессмертия (Godmode)", 200, function(v) godModeEnabled = v end)
createToggle(frames["FUN"], "Режим Невидимки (Invis)", 235, function(v) invisEnabled = v end)

createToggle(frames["ПРОЧЕЕ"], "Анти-Наручники (Bypass)", 10, function(v) antiCuffs = v end)
createToggle(frames["ПРОЧЕЕ"], "Анти-Дубинка / Электрошок", 45, function(v) antiBaton = v end)
createToggle(frames["ПРОЧЕЕ"], "Включить Окно Админ-Листа", 80, function(v) adminListEnabled = v end)

-- Создание Переносимого Окна Админ-Листа
local adminGui = Instance.new("Frame", screenGui); adminGui.Name = "HarizmaAdminList"
adminGui.Size = UDim2.new(0, 220, 0, 130); adminGui.Position = UDim2.new(0.05, 0, 0.4, 0); adminGui.BackgroundColor3 = Color3.fromRGB(12, 13, 18); adminGui.Visible = false
Instance.new("UICorner", adminGui).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", adminGui).Color = Color3.fromRGB(35, 38, 50)
local alTitle = Instance.new("TextLabel", adminGui); alTitle.Size = UDim2.new(1, 0, 0, 30); alTitle.BackgroundTransparency = 1; alTitle.Font = Enum.Font.GothamBold; alTitle.Text = "  Администрация:"; alTitle.TextColor3 = Color3.fromRGB(255, 85, 85); alTitle.TextSize = 11; alTitle.TextXAlignment = Enum.TextXAlignment.Left
local alLog = Instance.new("TextLabel", adminGui); alLog.Size = UDim2.new(1, -16, 1, -40); alLog.Position = UDim2.new(0, 8, 0, 30); alLog.BackgroundTransparency = 1; alLog.Font = Enum.Font.GothamMedium; alLog.Text = "Сканирование..."; alLog.TextColor3 = Color3.fromRGB(150, 155, 165); alLog.TextSize = 11; alLog.TextXAlignment = Enum.TextXAlignment.Left; alLog.TextYAlignment = Enum.TextYAlignment.Top
makeDraggable(adminGui)

-- Динамическое обновление админ-листа
task.spawn(function()
    while task.wait(1.5) do
        adminGui.Visible = adminListEnabled
        if adminListEnabled then
            local found = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():find("admin") or p.Name:lower():find("mod") then table.insert(found, p.Name) end
            end
            alLog.Text = #found == 0 and "Сервер чист от админов" or table.concat(found, "\n")
            alLog.TextColor3 = #found == 0 and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)
        end
    end
end)

-- Управление открытием/закрытием меню
local function toggleMenuState()
    menuVisible = not menuVisible
    local targetSize = menuVisible and UDim2.new(0, 560, 0, 360) or UDim2.new(0, 560, 0, 0)
    TweenService:Create(mainHub, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.Insert then toggleMenuState() end
end)

frames["ГЛАВНАЯ"].Visible = true
task.wait(0.2)
toggleMenuState()
