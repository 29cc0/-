local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

local avEnabled = false
local avHbConn, avHcConn, avCharConn

local gui = Instance.new("ScreenGui")
gui.Name = "MoonPixel"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then pcall(function() gui.Parent = player:WaitForChild("PlayerGui") end) end

local ball = Instance.new("TextButton")
ball.Size = UDim2.new(0, 48, 0, 48)
ball.Position = UDim2.new(0, 10, 0.5, -24)
ball.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
ball.Text = "+"
ball.TextColor3 = Color3.fromRGB(220, 220, 220)
ball.Font = Enum.Font.GothamBold
ball.TextSize = 26
ball.AutoButtonColor = false
ball.Parent = gui
Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ball).Color = Color3.fromRGB(74, 158, 255)

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 200, 0, 160)
panel.Visible = false
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", panel).Color = Color3.fromRGB(60, 60, 70)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "防虚空"
titleText.TextColor3 = Color3.fromRGB(235, 235, 235)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -32, 0, 3)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
minBtn.Text = "_"
minBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.AutoButtonColor = false
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local togBtn = Instance.new("TextButton")
togBtn.Size = UDim2.new(0, 44, 0, 22)
togBtn.Position = UDim2.new(0, 16, 0, 52)
togBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
togBtn.Text = ""
togBtn.AutoButtonColor = false
togBtn.Parent = panel
Instance.new("UICorner", togBtn).CornerRadius = UDim.new(1, 0)

local knob = Instance.new("Frame")
knob.Size = UDim2.new(0, 18, 0, 18)
knob.Position = UDim2.new(0, 24, 0, 2)
knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knob.BorderSizePixel = 0
knob.Parent = togBtn
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

local togLabel = Instance.new("TextLabel")
togLabel.Size = UDim2.new(0, 120, 0, 22)
togLabel.Position = UDim2.new(0, 70, 0, 52)
togLabel.BackgroundTransparency = 1
togLabel.Text = "防死亡 ON"
togLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
togLabel.Font = Enum.Font.Gotham
togLabel.TextSize = 13
togLabel.TextXAlignment = Enum.TextXAlignment.Left
togLabel.Parent = panel

local healBtn = Instance.new("TextButton")
healBtn.Size = UDim2.new(0, 168, 0, 30)
healBtn.Position = UDim2.new(0, 16, 0, 90)
healBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
healBtn.Text = "立即回满血量"
healBtn.TextColor3 = Color3.fromRGB(210, 210, 210)
healBtn.Font = Enum.Font.Gotham
healBtn.TextSize = 13
healBtn.AutoButtonColor = false
healBtn.Parent = panel
Instance.new("UICorner", healBtn).CornerRadius = UDim.new(0, 8)

local tipLabel = Instance.new("TextLabel")
tipLabel.Size = UDim2.new(1, -32, 0, 20)
tipLabel.Position = UDim2.new(0, 16, 0, 132)
tipLabel.BackgroundTransparency = 1
tipLabel.Text = "拖拽悬浮球移动"
tipLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
tipLabel.Font = Enum.Font.Gotham
tipLabel.TextSize = 11
tipLabel.TextXAlignment = Enum.TextXAlignment.Center
tipLabel.Parent = panel

local function updatePanelPos()
    local bx = ball.AbsolutePosition.X
    local by = ball.AbsolutePosition.Y
    local bs = ball.AbsoluteSize
    if bx > 300 then
        panel.Position = UDim2.new(0, bx - 210, 0, by)
    else
        panel.Position = UDim2.new(0, bx + bs.X + 10, 0, by)
    end
end

local function protectChar(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    avHcConn = hum.HealthChanged:Connect(function()
        if not avEnabled or not hum.Parent then return end
        pcall(function()
            if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        end)
    end)
    avHbConn = RunService.Heartbeat:Connect(function()
        if not avEnabled or not hum.Parent then return end
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.BreakJointsOnDeath = false
            if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
            if hum.Health <= 1 then
                hum.Health = hum.MaxHealth
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end)
end

local function startProtection()
    if avEnabled then return end
    avEnabled = true
    local char = player.Character or player.CharacterAdded:Wait()
    protectChar(char)
    avCharConn = player.CharacterAdded:Connect(function(c)
        if avHbConn then avHbConn:Disconnect() end
        if avHcConn then avHcConn:Disconnect() end
        protectChar(c)
    end)
    togBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    knob.Position = UDim2.new(0, 24, 0, 2)
    togLabel.Text = "防死亡 ON"
    togLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
end

local function stopProtection()
    if not avEnabled then return end
    avEnabled = false
    if avHbConn then avHbConn:Disconnect() avHbConn = nil end
    if avHcConn then avHcConn:Disconnect() avHcConn = nil end
    if avCharConn then avCharConn:Disconnect() avCharConn = nil end
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end) end
    end
    togBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
    knob.Position = UDim2.new(0, 2, 0, 2)
    togLabel.Text = "防死亡 OFF"
    togLabel.TextColor3 = Color3.fromRGB(200, 80, 80)
end

togBtn.MouseButton1Click:Connect(function()
    if avEnabled then stopProtection() else startProtection() end
end)

healBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.Health = hum.MaxHealth end) end
    end
end)

local panelOpen = false
local function togglePanel()
    panelOpen = not panelOpen
    if panelOpen then
        updatePanelPos()
        ball.Text = "x"
        panel.Visible = true
    else
        ball.Text = "+"
        panel.Visible = false
    end
end

minBtn.MouseButton1Click:Connect(function()
    panelOpen = false
    ball.Text = "+"
    panel.Visible = false
end)

local dragging, dragStart, startPos, didDrag
ball.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        didDrag = false
        dragStart = input.Position
        startPos = ball.Position
    end
end)
ball.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        if not didDrag then togglePanel() end
    end
end)
UserInput.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        if math.abs(d.X) > 3 or math.abs(d.Y) > 3 then didDrag = true end
        ball.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        if panelOpen then updatePanelPos() end
    end
end)

startProtection()