-- Bug Fixes | Mobile OP Auto Combat
-- No bloquea movimiento + Auto Combate para grupos

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

local Settings = {
    MeleeAura = false,
    AutoCombat = false,      -- NUEVO: modo auto combate completo
    AutoParry = false,
    Aim = false,
    LowGraphics = false,

    MeleeRange = 13,
    CombatRange = 18,        -- rango para perseguir
    AttackCooldown = 0.28,
    FaceSpeed = 0.12,        -- muy suave para no romper movimiento
}

local isMobile = UserInputService.TouchEnabled
local lastAttack = 0
local lastParry = 0
local currentTarget = nil

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BugFixesOP"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 310, 0, 380)
Frame.Position = UDim2.new(0.5, -155, 0.2, 0)
Frame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 44)
Title.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Title.Text = "Bug Fixes | OP Mobile"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local function MakeToggle(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 80, 80)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.Parent = Frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.TextColor3 = on and Color3.fromRGB(70, 255, 120) or Color3.fromRGB(255, 80, 80)
        callback(on)
    end)
end

MakeToggle("Melee Aura", 55, function(v) Settings.MeleeAura = v end)
MakeToggle("AUTO COMBATE (OP)", 105, function(v) Settings.AutoCombat = v end)
MakeToggle("Smart Auto Parry", 155, function(v) Settings.AutoParry = v end)
MakeToggle("AIM Lock", 205, function(v) Settings.Aim = v end)
MakeToggle("Low Graphics", 255, function(v)
    Settings.LowGraphics = v
    if v then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, e in pairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then e.Enabled = false end
        end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                obj.Enabled = false
            end
        end
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        Lighting.GlobalShadows = true
    end
end)

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 34, 0, 34)
Close.Position = UDim2.new(1, -40, 0, 5)
Close.BackgroundColor3 = Color3.fromRGB(180, 35, 35)
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255,255,255)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 15
Close.Parent = Frame
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 8)
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(0.9, 0, 0, 40)
Info.Position = UDim2.new(0.05, 0, 1, -45)
Info.BackgroundTransparency = 1
Info.Text = "Auto Combate = se mueve solo + ataca grupos\nNo bloquea tu joystick"
Info.TextColor3 = Color3.fromRGB(130, 130, 150)
Info.Font = Enum.Font.Gotham
Info.TextSize = 12
Info.TextWrapped = true
Info.Parent = Frame

-- ==================== FUNCIONES ====================

local function GetAlivePlayers()
    local list = {}
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return list end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dist = (myRoot.Position - hrp.Position).Magnitude
                table.insert(list, {player = plr, root = hrp, hum = hum, dist = dist})
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local function SoftFace(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local flat = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    local goal = CFrame.lookAt(root.Position, flat)
    -- Muy suave → no rompe el movimiento del joystick
    root.CFrame = root.CFrame:Lerp(goal, Settings.FaceSpeed)
end

local function DoAttack()
    if tick() - lastAttack < Settings.AttackCooldown then return end
    lastAttack = tick()

    -- Ciclo de cortes (E Q F)
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.025)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    task.wait(0.05)
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.025)
        VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
    end)
    task.wait(0.05)
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.025)
        VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
end

local function DoParry()
    if tick() - lastParry < 0.32 then return end
    lastParry = tick()

    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
    end)
end

-- ==================== LOOPS ====================

-- Melee Aura simple (solo ataca si están cerca, no mueve)
RunService.Heartbeat:Connect(function()
    if not Settings.MeleeAura or Settings.AutoCombat then return end

    local list = GetAlivePlayers()
    if #list == 0 then return end

    local nearest = list[1]
    if nearest.dist <= Settings.MeleeRange then
        SoftFace(nearest.root.Position)
        DoAttack()
    end
end)

-- AUTO COMBATE OP (se mueve + ataca + parry + multi target)
RunService.Heartbeat:Connect(function()
    if not Settings.AutoCombat then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local list = GetAlivePlayers()
    if #list == 0 then return end

    -- Prioriza el más cercano
    local target = list[1]
    currentTarget = target.player

    -- 1. Mirar al enemigo (suave)
    SoftFace(target.root.Position)

    -- 2. Moverse hacia él si está lejos (usando Humanoid para no romper controles)
    if target.dist > 9 and target.dist < Settings.CombatRange then
        -- Camina hacia el objetivo sin cancelar el joystick del usuario
        local direction = (target.root.Position - root.Position).Unit
        hum:Move(Vector3.new(direction.X, 0, direction.Z), false)
    elseif target.dist <= 9 then
        -- Si está muy cerca, deja de empujar y solo ataca
        hum:Move(Vector3.zero, false)
    end

    -- 3. Atacar siempre que esté en rango
    if target.dist <= Settings.MeleeRange + 2 then
        DoAttack()
    end

    -- 4. Auto Parry si hay alguien muy cerca (grupo)
    if Settings.AutoParry or target.dist <= 11 then
        DoParry()
    end

    -- 5. Si hay varios enemigos cerca, atacar más agresivo
    local nearbyCount = 0
    for _, t in ipairs(list) do
        if t.dist <= 14 then
            nearbyCount += 1
        end
    end
    if nearbyCount >= 2 then
        -- Modo grupo: ataca más rápido
        Settings.AttackCooldown = 0.18
        DoAttack()
        DoParry()
    else
        Settings.AttackCooldown = 0.28
    end
end)

-- Auto Parry standalone
RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry or Settings.AutoCombat then return end

    local list = GetAlivePlayers()
    if #list == 0 then return end
    if list[1].dist <= 12 then
        SoftFace(list[1].root.Position)
        DoParry()
    end
end)

-- AIM
RunService.RenderStepped:Connect(function()
    if not Settings.Aim then return end
    local list = GetAlivePlayers()
    if #list == 0 then return end
    local part = list[1].player.Character:FindFirstChild("Head") or list[1].root
    if part then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), 0.16)
    end
end)

print("✅ Bug Fixes OP Mobile cargado")
print("• Auto Combate = se mueve solo + ataca grupos")
print("• Ya no debería bloquear tu movimiento")
