-- Bug Fixes | Melee Aura + Auto Parry + AIM + Low Graphics
-- Hecho para Delta

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

local Settings = {
    MeleeAura = false,
    MeleeRange = 12,
    AutoParry = false,
    Aim = false,
    AimSmooth = 0.22,
    LowGraphics = false
}

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BugFixesDelta"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 270, 0, 310)
Frame.Position = UDim2.new(0.5, -135, 0.35, 0)
Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 38)
Title.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
Title.Text = "Bug Fixes | Delta"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local function MakeToggle(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 34)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 90, 90)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = Frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.TextColor3 = on and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 90, 90)
        callback(on)
    end)
end

MakeToggle("Melee Aura", 50, function(v) Settings.MeleeAura = v end)
MakeToggle("Auto Parry", 95, function(v) Settings.AutoParry = v end)
MakeToggle("AIM Lock", 140, function(v) Settings.Aim = v end)
MakeToggle("Low Graphics", 185, function(v)
    Settings.LowGraphics = v
    if v then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
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
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        Lighting.GlobalShadows = true
    end
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -33, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = Frame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Closest player
local function GetClosest(range)
    local closest, shortest = nil, range or 999
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

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

-- Melee Aura
RunService.Heartbeat:Connect(function()
    if not Settings.MeleeAura then return end
    local target, dist = GetClosest(Settings.MeleeRange)
    if target and dist <= Settings.MeleeRange then
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.04)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        task.wait(0.07)
        VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.04)
        VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        task.wait(0.07)
        VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.04)
        VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end)

-- Auto Parry
RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry then return end
    local target, dist = GetClosest(14)
    if target and dist <= 11 then
        VIM:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait(0.025)
        VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
        VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
    end
end)

-- AIM
RunService.RenderStepped:Connect(function()
    if not Settings.Aim then return end
    local target = GetClosest(55)
    if target and target.Character then
        local part = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
        if part then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, part.Position), Settings.AimSmooth)
        end
    end
end)

print("✅ Bug Fixes script loaded | Melee Aura + Auto Parry + AIM + Low Graphics")
