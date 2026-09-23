-- Bug Fixes | Full Auto Pilot v6
-- Millones de combinaciones de combos + movimiento rápido al matar

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

local Settings = {
    FullAuto = false,
    MeleeAura = false,
    Aim = true,
    LowGraphics = false,

    WeaponRange = 11.2,
    OptimalRange = 9.0,
    ChaseRange = 30,
    AttackSpeed = 0.17,
    FastMoveSpeed = 1.8,   -- velocidad alta al matar / perseguir
    NormalMoveSpeed = 1.25,
}

local State = {
    lastAttack = 0,
    lastParry = 0,
    lastDisplace = 0,
    lastCounter = 0,
    lastTarget = nil,
    isCountering = false,
    minimized = false,
    killBoostUntil = 0,     -- boost de velocidad después de matar
}

-- Generador de muchísimas combinaciones
local Keys = {Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F}
local function GenerateCombos()
    local combos = {}

    -- Todas las permutaciones de 2, 3 y 4 hits
    for _, a in ipairs(Keys) do
        for _, b in ipairs(Keys) do
            table.insert(combos, {a, b})
            for _, c in ipairs(Keys) do
                table.insert(combos, {a, b, c})
                for _, d in ipairs(Keys) do
                    table.insert(combos, {a, b, c, d})
                end
            end
        end
    end

    -- Versiones con Displace (G) al final (contraataques)
    local withG = {}
    for _, combo in ipairs(combos) do
        if #combo >= 2 then
            local copy = table.clone(combo)
            table.insert(copy, Enum.KeyCode.G)
            table.insert(withG, copy)
        end
    end

    -- Mezclar todo
    for _, c in ipairs(withG) do
        table.insert(combos, c)
    end

    return combos
end

local AllCombos = GenerateCombos() -- cientos de combinaciones posibles

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BugFixesFullAuto"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Size = UDim2.new(0, 330, 0, 370)
MainFrame.Position = UDim2.new(0.5, -165, 0.14, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 46)
TitleBar.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Bug Fixes | Full Auto v6"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 34, 0, 34)
MinBtn.Position = UDim2.new(1, -78, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
MinBtn.Text = "–"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.Position = UDim2.new(1, -40, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 15
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, 0, 1, -46)
Content.Position = UDim2.new(0, 0, 0, 46)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function MakeToggle(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 70, 70)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.Parent = Content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.TextColor3 = on and Color3.fromRGB(50, 255, 130) or Color3.fromRGB(255, 70, 70)
        callback(on)
    end)
end

MakeToggle("FULL AUTO (Juega Solo)", 12, function(v)
    Settings.FullAuto = v
    if v then Settings.Aim = true end
end)
MakeToggle("Melee Aura", 62, function(v) Settings.MeleeAura = v end)
MakeToggle("AIM Lock", 112, function(v) Settings.Aim = v end)
MakeToggle("Low Graphics", 162, function(v)
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

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(0.9, 0, 0, 55)
Info.Position = UDim2.new(0.05, 0, 1, -65)
Info.BackgroundTransparency = 1
Info.Text = "Cientos de combos posibles\nSe mueve rápido al matar\nSolo ataca en rango de arma"
Info.TextColor3 = Color3.fromRGB(130, 140, 160)
Info.Font = Enum.Font.Gotham
Info.TextSize = 12
Info.TextWrapped = true
Info.Parent = Content

MinBtn.MouseButton1Click:Connect(function()
    State.minimized = not State.minimized
    if State.minimized then
        Content.Visible = false
        MainFrame.Size = UDim2.new(0, 330, 0, 46)
        MinBtn.Text = "+"
    else
        Content.Visible = true
        MainFrame.Size = UDim2.new(0, 330, 0, 370)
        MinBtn.Text = "–"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- ==================== DETECCIÓN ====================

local function GetEnemies()
    local list = {}
    local myChar = LocalPlayer.Character
    if not myChar then return list end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum or myHum.Health <= 0 then return list end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dist = (myRoot.Position - hrp.Position).Magnitude
                table.insert(list, {
                    player = plr,
                    root = hrp,
                    hum = hum,
                    char = plr.Character,
                    dist = dist
                })
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- ==================== MOVIMIENTO + COMBATE ====================

local function SoftFace(pos)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local goal = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
    root.CFrame = root.CFrame:Lerp(goal, 0.19)
end

local function WalkTo(pos, speed)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local dir = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
    if dir.Magnitude < 1.1 then
        hum:Move(Vector3.zero, false)
        return
    end
    hum:Move(dir.Unit * speed, false)
end

local function Strafe(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local toEnemy = (Vector3.new(targetPos.X, root.Position.Y, targetPos.Z) - root.Position).Unit
    local side = Vector3.new(-toEnemy.Z, 0, toEnemy.X)
    if math.floor(tick() * 0.8) % 2 == 0 then side = -side end
    hum:Move((toEnemy * -0.25 + side * 1.0).Unit * 1.1, false)
end

local function Press(key, t)
    pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(t or 0.022)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local function DoRandomCombo(isCounter)
    if tick() - State.lastAttack < Settings.AttackSpeed then return end
    State.lastAttack = tick()

    local combo
    if isCounter then
        -- Buscar combos que terminen en G
        local counters = {}
        for _, c in ipairs(AllCombos) do
            if c[#c] == Enum.KeyCode.G then
                table.insert(counters, c)
            end
        end
        combo = counters[math.random(1, #counters)]
    else
        combo = AllCombos[math.random(1, #AllCombos)]
    end

    for i, key in ipairs(combo) do
        Press(key, 0.021)
        if i < #combo then task.wait(0.032) end
    end
end

local function DoParry()
    if tick() - State.lastParry < 0.26 then return end
    State.lastParry = tick()

    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait(0.018)
        VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)
    Press(Enum.KeyCode.R, 0.018)

    State.isCountering = true
    State.lastCounter = tick()
end

local function ProcessCounter()
    if not State.isCountering then return end
    if tick() - State.lastCounter > 0.45 then
        State.isCountering = false
        return
    end
    State.isCountering = false
    State.lastAttack = 0
    DoRandomCombo(true)
end

-- ==================== FULL AUTO ====================

RunService.Heartbeat:Connect(function()
    if not Settings.FullAuto then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHum or myHum.Health <= 0 then return end

    local enemies = GetEnemies()
    if #enemies == 0 then
        myHum:Move(Vector3.zero, false)
        State.lastTarget = nil
        return
    end

    local target = enemies[1]
    local dist = target.dist

    -- Detectar si matamos al anterior → boost de velocidad
    if State.lastTarget and State.lastTarget ~= target.player then
        State.killBoostUntil = tick() + 2.2 -- 2.2 segundos de movimiento rápido
    end
    State.lastTarget = target.player

    local speed = Settings.NormalMoveSpeed
    if tick() < State.killBoostUntil then
        speed = Settings.FastMoveSpeed -- se mueve más rápido después de matar
    end

    SoftFace(target.root.Position)

    -- Movimiento
    if dist > Settings.WeaponRange + 1.2 and dist < Settings.ChaseRange then
        WalkTo(target.root.Position, speed)
    elseif dist < 7.0 then
        Strafe(target.root.Position)
    elseif dist > Settings.OptimalRange + 1.5 and dist <= Settings.WeaponRange + 0.8 then
        WalkTo(target.root.Position, speed * 0.75)
    else
        myHum:Move(Vector3.zero, false)
    end

    -- Solo atacar en rango real del arma
    if dist <= Settings.WeaponRange then
        local group = 0
        for _, e in ipairs(enemies) do
            if e.dist <= 14.5 then group += 1 end
        end

        DoRandomCombo(false)

        if dist <= 10.8 or group >= 2 then
            DoParry()
            ProcessCounter()
        end

        if group >= 2 and tick() - State.lastDisplace > 1.0 then
            State.lastDisplace = tick()
            Press(Enum.KeyCode.G, 0.025)
        end
    end
end)

-- Melee Aura
RunService.Heartbeat:Connect(function()
    if Settings.FullAuto or not Settings.MeleeAura then return end
    local enemies = GetEnemies()
    if #enemies > 0 and enemies[1].dist <= Settings.WeaponRange then
        SoftFace(enemies[1].root.Position)
        DoRandomCombo(false)
    end
end)

-- AIM
RunService.RenderStepped:Connect(function()
    if not Settings.Aim then return end
    local enemies = GetEnemies()
    if #enemies == 0 then return end
    local part = enemies[1].char:FindFirstChild("Head") or enemies[1].root
    if part then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), 0.13)
    end
end)

print("✅ Bug Fixes Full Auto v6")
print("• Cientos de combinaciones de combos generadas")
print("• Movimiento rápido al matar (boost 2.2s)")
print("• Solo ataca en rango de arma")
print("• Minimizar con el botón –")
