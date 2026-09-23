-- Bug Fixes | OP Mobile Auto Combat v3
-- Movimiento real + ataques variados + contraataque después de bloquear

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

local Settings = {
    MeleeAura = false,
    AutoCombat = false,
    AutoParry = false,
    Aim = false,
    LowGraphics = false,

    MeleeRange = 12.5,
    ChaseRange = 22,
    AttackSpeed = 0.22,
    FaceSpeed = 0.18,
}

local lastAttack = 0
local lastParry = 0
local lastCounter = 0
local attackIndex = 1
local isCountering = false

-- Combinaciones de ataque variadas (para que no sea predecible)
local AttackCombos = {
    {Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F},
    {Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.Q},
    {Enum.KeyCode.Q, Enum.KeyCode.F, Enum.KeyCode.E},
    {Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.Q},
    {Enum.KeyCode.F, Enum.KeyCode.Q, Enum.KeyCode.E},
}

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BugFixesOP"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 320, 0, 390)
Frame.Position = UDim2.new(0.5, -160, 0.18, 0)
Frame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 44)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Title.Text = "Bug Fixes | OP Combat v3"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local function MakeToggle(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 75, 75)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.Parent = Frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.TextColor3 = on and Color3.fromRGB(60, 255, 120) or Color3.fromRGB(255, 75, 75)
        callback(on)
    end)
end

MakeToggle("Melee Aura", 55, function(v) Settings.MeleeAura = v end)
MakeToggle("AUTO COMBATE OP", 105, function(v) Settings.AutoCombat = v end)
MakeToggle("Smart Auto Parry + Contra", 155, function(v) Settings.AutoParry = v end)
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
Close.BackgroundColor3 = Color3.fromRGB(170, 30, 30)
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255,255,255)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 15
Close.Parent = Frame
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 8)
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(0.9, 0, 0, 50)
Info.Position = UDim2.new(0.05, 0, 1, -55)
Info.BackgroundTransparency = 1
Info.Text = "Auto Combate ahora se mueve de verdad\nAtques variados + Contraataque al bloquear"
Info.TextColor3 = Color3.fromRGB(140, 140, 160)
Info.Font = Enum.Font.Gotham
Info.TextSize = 12
Info.TextWrapped = true
Info.Parent = Frame

-- ==================== DETECCIÓN MEJORADA ====================

local function GetEnemies()
    local enemies = {}
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return enemies end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                local dist = (myRoot.Position - hrp.Position).Magnitude
                table.insert(enemies, {
                    player = plr,
                    root = hrp,
                    hum = hum,
                    dist = dist,
                    char = plr.Character
                })
            end
        end
    end

    table.sort(enemies, function(a, b) return a.dist < b.dist end)
    return enemies
end

-- ==================== MOVIMIENTO REAL ====================

local function MoveTo(targetPos, speed)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local direction = (Vector3.new(targetPos.X, root.Position.Y, targetPos.Z) - root.Position)
    if direction.Magnitude < 1 then
        hum:Move(Vector3.zero, false)
        return
    end

    direction = direction.Unit
    -- Movimiento más fuerte y constante
    hum:Move(direction * (speed or 1), false)
end

local function SoftFace(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    local goal = CFrame.lookAt(root.Position, lookPos)
    root.CFrame = root.CFrame:Lerp(goal, Settings.FaceSpeed)
end

-- ==================== COMBATE ====================

local function PressKey(key, time)
    pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(time or 0.03)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local function DoVariedAttack()
    if tick() - lastAttack < Settings.AttackSpeed then return end
    lastAttack = tick()

    local combo = AttackCombos[attackIndex]
    attackIndex = attackIndex % #AttackCombos + 1

    for i, key in ipairs(combo) do
        PressKey(key, 0.028)
        if i < #combo then task.wait(0.045) end
    end
end

local function DoParry()
    if tick() - lastParry < 0.30 then return end
    lastParry = tick()

    -- Bloqueo
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait(0.025)
        VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)

    -- Stance change
    PressKey(Enum.KeyCode.R, 0.025)

    -- Marcar para contraataque
    isCountering = true
    lastCounter = tick()
end

local function DoCounterAttack()
    if not isCountering then return end
    if tick() - lastCounter > 0.55 then
        isCountering = false
        return
    end

    -- Contraataque rápido y fuerte justo después del bloqueo
    isCountering = false
    lastAttack = 0 -- forzar ataque inmediato

    -- Combinación de contra fuerte
    PressKey(Enum.KeyCode.F, 0.03)
    task.wait(0.04)
    PressKey(Enum.KeyCode.E, 0.03)
    task.wait(0.04)
    PressKey(Enum.KeyCode.Q, 0.03)

    -- Displace (G) para romper guardia o reposicionar
    task.wait(0.05)
    PressKey(Enum.KeyCode.G, 0.03)
end

-- ==================== LOOPS PRINCIPALES ====================

-- AUTO COMBATE OP
RunService.Heartbeat:Connect(function()
    if not Settings.AutoCombat then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local enemies = GetEnemies()
    if #enemies == 0 then
        hum:Move(Vector3.zero, false)
        return
    end

    local target = enemies[1]
    local dist = target.dist

    -- Siempre mirar al más cercano
    SoftFace(target.root.Position)

    -- Movimiento inteligente
    if dist > 10 and dist < Settings.ChaseRange then
        -- Perseguir
        MoveTo(target.root.Position, 1.4)
    elseif dist <= 8.5 then
        -- Demasiado cerca → dar un pequeño paso atrás + lateral para no quedar pegado
        local back = (root.Position - target.root.Position).Unit
        local side = Vector3.new(-back.Z, 0, back.X) -- perpendicular
        local moveDir = (back * 0.6 + side * 0.7).Unit
        hum:Move(moveDir, false)
    else
        -- Rango ideal → mantenerse y atacar
        hum:Move(Vector3.zero, false)
    end

    -- Atacar
    if dist <= Settings.MeleeRange + 1.5 then
        DoVariedAttack()
    end

    -- Parry + Contra si hay amenaza cerca
    if dist <= 11.5 or #enemies >= 2 then
        DoParry()
        task.spawn(DoCounterAttack)
    end

    -- Si hay grupo (2+), ser más agresivo
    if #enemies >= 2 and enemies[2].dist <= 15 then
        Settings.AttackSpeed = 0.16
        DoVariedAttack()
        DoParry()
    else
        Settings.AttackSpeed = 0.22
    end
end)

-- Melee Aura simple
RunService.Heartbeat:Connect(function()
    if not Settings.MeleeAura or Settings.AutoCombat then return end

    local enemies = GetEnemies()
    if #enemies == 0 then return end

    if enemies[1].dist <= Settings.MeleeRange then
        SoftFace(enemies[1].root.Position)
        DoVariedAttack()
    end
end)

-- Auto Parry standalone + Contra
RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry or Settings.AutoCombat then return end

    local enemies = GetEnemies()
    if #enemies == 0 then return end

    if enemies[1].dist <= 12 then
        SoftFace(enemies[1].root.Position)
        DoParry()
        task.spawn(DoCounterAttack)
    end
end)

-- AIM
RunService.RenderStepped:Connect(function()
    if not Settings.Aim then return end
    local enemies = GetEnemies()
    if #enemies == 0 then return end

    local part = enemies[1].char:FindFirstChild("Head") or enemies[1].root
    if part then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), 0.15)
    end
end)

print("✅ Bug Fixes OP Combat v3 cargado")
print("• Movimiento real mejorado")
print("• Ataques variados (ya no siempre la misma combo)")
print("• Contraataque automático después de bloquear")
