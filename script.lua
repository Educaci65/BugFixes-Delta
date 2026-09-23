-- Bug Fixes | Full Auto Pilot v4
-- Detecta perfecto + juega solo + lógica de combos avanzada (casi nunca pierde)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

local Settings = {
    FullAuto = false,          -- Juega completamente solo
    MeleeAura = false,
    AutoParry = true,          -- Siempre activo en Full Auto
    Aim = true,
    LowGraphics = false,

    OptimalRange = 9.5,        -- Distancia ideal de pelea
    ChaseRange = 28,
    AttackSpeed = 0.19,
}

-- Estado interno del cerebro de combate
local State = {
    lastAttack = 0,
    lastParry = 0,
    lastDisplace = 0,
    lastCounter = 0,
    comboStep = 1,
    currentCombo = 1,
    isCountering = false,
    target = nil,
    mode = "idle" -- idle, chase, fight, group, counter
}

-- Combos avanzados según situación
local Combos = {
    -- Combo normal (presión)
    normal = {
        {Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F},
        {Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.Q},
        {Enum.KeyCode.Q, Enum.KeyCode.F, Enum.KeyCode.E},
    },
    -- Combo agresivo (cuando el enemigo está cerca o hay varios)
    aggressive = {
        {Enum.KeyCode.F, Enum.KeyCode.F, Enum.KeyCode.E},
        {Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.Q},
        {Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.F},
    },
    -- Contraataque después de parry
    counter = {
        {Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.G},
        {Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.G},
        {Enum.KeyCode.Q, Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.G},
    },
    -- Combo de grupo (máxima presión)
    group = {
        {Enum.KeyCode.F, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F},
        {Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F, Enum.KeyCode.E},
    }
}

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BugFixesFullAuto"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 330, 0, 360)
Frame.Position = UDim2.new(0.5, -165, 0.15, 0)
Frame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 46)
Title.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
Title.Text = "Bug Fixes | Full Auto Pilot"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 14)

local function MakeToggle(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 42)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 70, 70)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.Parent = Frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.TextColor3 = on and Color3.fromRGB(50, 255, 130) or Color3.fromRGB(255, 70, 70)
        callback(on)
    end)
end

MakeToggle("FULL AUTO (Juega Solo)", 55, function(v)
    Settings.FullAuto = v
    if v then
        Settings.AutoParry = true
        Settings.Aim = true
    end
end)

MakeToggle("Melee Aura", 108, function(v) Settings.MeleeAura = v end)
MakeToggle("AIM Lock", 161, function(v) Settings.Aim = v end)
MakeToggle("Low Graphics", 214, function(v)
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
Close.Size = UDim2.new(0, 36, 0, 36)
Close.Position = UDim2.new(1, -42, 0, 5)
Close.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255,255,255)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 16
Close.Parent = Frame
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 9)
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(0.9, 0, 0, 50)
Status.Position = UDim2.new(0.05, 0, 1, -58)
Status.BackgroundTransparency = 1
Status.Text = "FULL AUTO = Detecta + se mueve + pelea solo\nLógica de combos avanzada activada"
Status.TextColor3 = Color3.fromRGB(130, 140, 160)
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.TextWrapped = true
Status.Parent = Frame

-- ==================== DETECCIÓN SÓLIDA ====================

local function GetValidEnemies()
    local list = {}
    local myChar = LocalPlayer.Character
    if not myChar then return list end

    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum or myHum.Health <= 0 then return list end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    -- Evitar jugadores que estén en estado raro
                    local state = hum:GetState()
                    if state ~= Enum.HumanoidStateType.Dead and state ~= Enum.HumanoidStateType.Physics then
                        local dist = (myRoot.Position - hrp.Position).Magnitude
                        table.insert(list, {
                            player = plr,
                            root = hrp,
                            hum = hum,
                            char = char,
                            dist = dist
                        })
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- ==================== UTILIDADES DE COMBATE ====================

local function Press(key, hold)
    pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(hold or 0.028)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local function SoftFace(pos)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local goal = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
    root.CFrame = root.CFrame:Lerp(goal, 0.20)
end

local function MoveToward(pos, intensity)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local dir = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
    if dir.Magnitude < 0.8 then
        hum:Move(Vector3.zero, false)
        return
    end
    hum:Move(dir.Unit * (intensity or 1.3), false)
end

local function Strafe(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local toEnemy = (Vector3.new(targetPos.X, root.Position.Y, targetPos.Z) - root.Position).Unit
    local side = Vector3.new(-toEnemy.Z, 0, toEnemy.X)
    -- Alterna lado para no ser predecible
    if tick() % 2 < 1 then side = -side end
    local move = (toEnemy * -0.35 + side * 0.9).Unit
    hum:Move(move, false)
end

-- ==================== LÓGICA DE COMBOS ====================

local function ExecuteCombo(comboType)
    if tick() - State.lastAttack < Settings.AttackSpeed then return end
    State.lastAttack = tick()

    local pool = Combos[comboType] or Combos.normal
    local combo = pool[State.currentCombo]
    State.currentCombo = State.currentCombo % #pool + 1

    for i, key in ipairs(combo) do
        Press(key, 0.026)
        if i < #combo then task.wait(0.038) end
    end
end

local function DoParryAndCounter()
    if tick() - State.lastParry < 0.27 then return end
    State.lastParry = tick()

    -- Bloqueo
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait(0.022)
        VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)
    Press(Enum.KeyCode.R, 0.022)

    -- Activar contraataque
    State.isCountering = true
    State.lastCounter = tick()
end

local function ProcessCounter()
    if not State.isCountering then return end
    if tick() - State.lastCounter > 0.50 then
        State.isCountering = false
        return
    end

    State.isCountering = false
    State.lastAttack = 0
    ExecuteCombo("counter")
end

-- ==================== CEREBRO FULL AUTO ====================

RunService.Heartbeat:Connect(function()
    if not Settings.FullAuto then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum or myHum.Health <= 0 then return end

    local enemies = GetValidEnemies()
    if #enemies == 0 then
        myHum:Move(Vector3.zero, false)
        State.mode = "idle"
        return
    end

    local nearest = enemies[1]
    local dist = nearest.dist
    local nearbyCount = 0
    for _, e in ipairs(enemies) do
        if e.dist <= 16 then nearbyCount += 1 end
    end

    -- Decidir modo
    if nearbyCount >= 2 then
        State.mode = "group"
    elseif dist > Settings.OptimalRange + 3 then
        State.mode = "chase"
    elseif dist < 7.5 then
        State.mode = "too_close"
    else
        State.mode = "fight"
    end

    -- Siempre mirar al objetivo principal
    SoftFace(nearest.root.Position)

    -- === COMPORTAMIENTO SEGÚN MODO ===

    if State.mode == "chase" then
        MoveToward(nearest.root.Position, 1.45)
        if dist <= Settings.MeleeRange + 2 then
            ExecuteCombo("normal")
        end

    elseif State.mode == "fight" then
        -- Rango ideal → presionar con combos y strafear ligeramente
        if dist > Settings.OptimalRange + 1.2 then
            MoveToward(nearest.root.Position, 0.9)
        elseif dist < Settings.OptimalRange - 1.5 then
            Strafe(nearest.root.Position)
        else
            myHum:Move(Vector3.zero, false)
        end
        ExecuteCombo("normal")
        if dist <= 11 then
            DoParryAndCounter()
            ProcessCounter()
        end

    elseif State.mode == "too_close" then
        -- Demasiado pegado → salir + contra
        Strafe(nearest.root.Position)
        DoParryAndCounter()
        ProcessCounter()
        ExecuteCombo("aggressive")

    elseif State.mode == "group" then
        -- Varios enemigos → máxima agresividad
        SoftFace(nearest.root.Position)
        if dist > 10 then
            MoveToward(nearest.root.Position, 1.3)
        else
            Strafe(nearest.root.Position)
        end
        ExecuteCombo("group")
        DoParryAndCounter()
        ProcessCounter()
        -- Displace más frecuente en grupo
        if tick() - State.lastDisplace > 1.1 then
            State.lastDisplace = tick()
            Press(Enum.KeyCode.G, 0.03)
        end
    end
end)

-- Melee Aura simple (si no está en Full Auto)
RunService.Heartbeat:Connect(function()
    if Settings.FullAuto or not Settings.MeleeAura then return end
    local enemies = GetValidEnemies()
    if #enemies > 0 and enemies[1].dist <= 12.5 then
        SoftFace(enemies[1].root.Position)
        ExecuteCombo("normal")
    end
end)

-- AIM
RunService.RenderStepped:Connect(function()
    if not Settings.Aim then return end
    local enemies = GetValidEnemies()
    if #enemies == 0 then return end
    local part = enemies[1].char:FindFirstChild("Head") or enemies[1].root
    if part then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), 0.14)
    end
end)

print("✅ Bug Fixes Full Auto Pilot v4 cargado")
print("• Detección mejorada")
print("• Juega prácticamente solo")
print("• Lógica de combos avanzada (normal / agresivo / contra / grupo)")
