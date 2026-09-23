-- Bug Fixes | Mobile Optimized
-- Melee Aura + Smart Auto Parry (Sword Position) + AIM + Low Graphics
-- Compatible with Delta Mobile

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

local Settings = {
    MeleeAura = false,
    MeleeRange = 11,
    AutoParry = false,
    Aim = false,
    AimSmooth = 0.18,
    LowGraphics = false,
    FaceEnemy = true -- Gira el personaje hacia el enemigo para bloquear mejor
}

-- Detectar si es mobile
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- GUI Mobile Friendly
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BugFixesDelta"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = isMobile and UDim2.new(0, 300, 0, 340) or UDim2.new(0, 270, 0, 310)
Frame.Position = UDim2.new(0.5, isMobile and -150 or -135, 0.25, 0)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 42)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Title.Text = "Bug Fixes | Mobile"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = isMobile and 16 or 15
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local function MakeToggle(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, isMobile and 42 or 34)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 85, 85)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = isMobile and 15 or 13
    btn.Parent = Frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.TextColor3 = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 85, 85)
        callback(on)
    end)
end

MakeToggle("Melee Aura", 55, function(v) Settings.MeleeAura = v end)
MakeToggle("Smart Auto Parry", 105, function(v) Settings.AutoParry = v end)
MakeToggle("AIM Lock", 155, function(v) Settings.Aim = v end)
MakeToggle("Low Graphics", 205, function(v)
    Settings.LowGraphics = v
    if v then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                obj.Enabled = false
            end
        end
    else
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end)
        Lighting.GlobalShadows = true
    end
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Frame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Info text for mobile
local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(0.9, 0, 0, 30)
Info.Position = UDim2.new(0.05, 0, 1, -35)
Info.BackgroundTransparency = 1
Info.Text = isMobile and "Mobile Mode • Puedes moverte libremente" or "PC Mode"
Info.TextColor3 = Color3.fromRGB(140, 140, 160)
Info.Font = Enum.Font.Gotham
Info.TextSize = 12
Info.Parent = Frame

-- Closest player
local function GetClosest(range)
    local closest, shortest = nil, range or 999
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, 999 end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (root.Position - hrp.Position).Magnitude
                if d < shortest then
                    shortest = d
                    closest = plr
                end
            end
        end
    end
    return closest, shortest
end

-- Get enemy sword / tool position for smarter parry
local function GetEnemySwordPos(target)
    if not target or not target.Character then return nil end
    local char = target.Character
    -- Buscar herramienta equipada o partes de la espada
    for _, obj in pairs(char:GetDescendants()) do
        if obj:IsA("Tool") and obj.Parent == char then
            local handle = obj:FindFirstChild("Handle")
            if handle then return handle.Position end
        end
        if obj.Name:lower():find("sword") or obj.Name:lower():find("blade") or obj.Name:lower():find("katana") then
            if obj:IsA("BasePart") then
                return obj.Position
            end
        end
    end
    -- Fallback a la mano derecha o torso
    local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if rightHand then return rightHand.Position end
    local root = char:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end

-- Face enemy smoothly without locking movement completely
local function FaceTarget(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local lookAt = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    local goal = CFrame.lookAt(root.Position, lookAt)
    -- Solo rotar un poco, no forzar completamente para no romper movimiento mobile
    root.CFrame = root.CFrame:Lerp(goal, 0.15)
end

-- Melee Aura (funciona en mobile)
local lastAttack = 0
RunService.Heartbeat:Connect(function()
    if not Settings.MeleeAura then return end
    if tick() - lastAttack < 0.35 then return end -- cooldown para no spamear

    local target, dist = GetClosest(Settings.MeleeRange)
    if target and dist <= Settings.MeleeRange then
        lastAttack = tick()
        -- En mobile intentamos varias formas de input
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
        task.wait(0.06)
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        end)
        task.wait(0.06)
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end
end)

-- Smart Auto Parry (analiza posición de la espada del enemigo)
local lastParry = 0
RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry then return end
    if tick() - lastParry < 0.28 then return end

    local target, dist = GetClosest(13)
    if not target or dist > 12 then return end

    local swordPos = GetEnemySwordPos(target)
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    -- Si hay espada cerca, girar hacia ella para bloquear
    if swordPos and (swordPos - myRoot.Position).Magnitude < 14 then
        lastParry = tick()

        -- 1. Girar el personaje hacia la espada del enemigo (esto ayuda mucho a bloquear)
        if Settings.FaceEnemy then
            FaceTarget(swordPos)
        end

        -- 2. Intentar input de bloqueo (funciona mejor en PC, en mobile depende del executor)
        pcall(function()
            -- Right click / bloqueo
            VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
        end)

        -- 3. Cambiar stance (R) que en este juego ayuda a defender
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
            task.wait(0.025)
            VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        end)
    end
end)

-- AIM (suave, no bloquea movimiento)
RunService.RenderStepped:Connect(function()
    if not Settings.Aim then return end
    local target = GetClosest(50)
    if target and target.Character then
        local part = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
        if part then
            local goal = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, Settings.AimSmooth)
        end
    end
end)

print("✅ Bug Fixes Mobile Script loaded")
print("• Melee Aura + Smart Auto Parry (analiza espada)")
print("• Puedes moverte libremente en mobile")
