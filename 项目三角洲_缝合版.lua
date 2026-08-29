local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

if not hookfunction then
    return LocalPlayer:Kick("[缝合版] 注入器不支持hookfunction, 请换Solara/Wave")
end

local BulletLoaded, BulletModule = pcall(require, ReplicatedStorage.Modules.FPS.Bullet)
if not BulletLoaded then
    return LocalPlayer:Kick("[缝合版] 游戏未加载完成, 请进入对局后再注入")
end

local HasDrawing = pcall(function() return Drawing.new("Square") end)

-- ============================================================
-- 配置
-- ============================================================
local Config = {
    SilentAim = {
        Enabled = true,
        WallCheck = true,
        HitPart = "Head",
        Prediction = true,
        TargetAI = true,
        TargetPlayer = true,
        HitChance = 100,
        FovRadius = 600,
        ShowFov = false,
    },
    ESP = {
        Enabled = false,
        ShowBox = true,
        ShowName = true,
        ShowHealth = true,
        ShowDistance = true,
        ShowSkeleton = false,
        ShowWeapon = false,
        MaxDistance = 5000,
    },
}

-- ============================================================
-- 工具函数
-- ============================================================
local function IsAlive(plr)
    return plr and plr.Character
        and plr.Character:FindFirstChild("HumanoidRootPart")
        and plr.Character:FindFirstChild("Humanoid")
        and plr.Character.Humanoid.Health > 0
end

local function WallCheck(origin, target, ignore)
    local list = {Camera}
    if IsAlive(LocalPlayer) then table.insert(list, LocalPlayer.Character) end
    if ignore then for _, v in ipairs(ignore) do table.insert(list, v) end end
    local result = workspace:FindPartOnRayWithIgnoreList(
        Ray.new(origin, target.Position - origin), list, false, true
    )
    return result and result:IsDescendantOf(target.Parent)
end

local function SolveQuad(a, b, c)
    local d = b^2 - 4*a*c
    if d < 0 then return nil, nil end
    local s = math.sqrt(d)
    return (-b - s)/(2*a), (-b + s)/(2*a)
end

local function TravelTime(dir, grav, speed)
    local r1, r2 = SolveQuad(grav:Dot(grav)/4, grav:Dot(dir) - speed^2, dir:Dot(dir))
    if r1 and r2 then
        if r1 > 0 and r1 < r2 then return math.sqrt(r1) end
        if r2 > 0 and r2 < r1 then return math.sqrt(r2) end
    end
    return 0
end

local function BulletDrop(origin, target, speed, gravity)
    local g = Vector3.yAxis * (gravity * 2)
    local t = TravelTime(target - origin, g, speed)
    return 0.5 * g * t^2
end

local function PredictPos(target, origin, speed, gravity)
    local g = Vector3.yAxis * (gravity * 2)
    local t = TravelTime(target.Position - origin, g, speed)
    return target.Position + (target.Velocity * t)
end

-- ============================================================
-- 静默自瞄
-- ============================================================
local function GetAIBodies()
    local bodies = {}
    local aiZones = workspace:FindFirstChild("AiZones")
    if aiZones then
        for _, zone in ipairs(aiZones:GetChildren()) do
            for _, body in ipairs(zone:GetChildren()) do
                table.insert(bodies, body)
            end
        end
    end
    return bodies
end

local function GetClosestTarget(...)
    local closest, closestDist = nil, Config.SilentAim.FovRadius
    local origin = Camera.CFrame.Position
    local center = Camera.ViewportSize / 2

    if Config.SilentAim.TargetAI then
        for _, body in ipairs(GetAIBodies()) do
            if not body:FindFirstChild("HumanoidRootPart") then goto ai_next end
            local hp = body:FindFirstChild(Config.SilentAim.HitPart)
            if not hp then goto ai_next end
            if Config.SilentAim.WallCheck and not WallCheck(origin, hp, ...) then goto ai_next end
            local pos, onScreen = Camera:WorldToViewportPoint(hp.Position)
            if not onScreen then goto ai_next end
            local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
            if dist < closestDist then closestDist = dist; closest = hp end
            ::ai_next::
        end
    end

    if Config.SilentAim.TargetPlayer then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then goto plr_next end
            if not IsAlive(plr) then goto plr_next end
            local hp = plr.Character:FindFirstChild(Config.SilentAim.HitPart)
            if not hp then goto plr_next end
            if Config.SilentAim.WallCheck and not WallCheck(origin, hp, ...) then goto plr_next end
            local pos, onScreen = Camera:WorldToViewportPoint(hp.Position)
            if not onScreen then goto plr_next end
            local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
            if dist < closestDist then closestDist = dist; closest = hp end
            ::plr_next::
        end
    end

    return closest
end

local OriginalCreateBullet
OriginalCreateBullet = hookfunction(BulletModule.CreateBullet, function(a, b, c, d, aim, e, ammo, tickVal, recoil)
    if not Config.SilentAim.Enabled then
        return OriginalCreateBullet(a, b, c, d, aim, e, ammo, tickVal, recoil)
    end
    if Config.SilentAim.HitChance < 100 and math.random(1, 100) > Config.SilentAim.HitChance then
        return OriginalCreateBullet(a, b, c, d, aim, e, ammo, tickVal, recoil)
    end

    local target = GetClosestTarget(b, c, d)
    if target then
        local ammoData = ReplicatedStorage.AmmoTypes:FindFirstChild(ammo)
        if ammoData then
            local drop = ammoData:GetAttribute("ProjectileDrop") or 0
            local speed = ammoData:GetAttribute("MuzzleVelocity") or 900
            ammoData:SetAttribute("Drag", 0)

            local predicted = target.Position
            if Config.SilentAim.Prediction then
                predicted = PredictPos(target, aim.Position, speed, drop)
            end
            local dropOffset = BulletDrop(aim.Position, predicted, speed, drop)

            return OriginalCreateBullet(a, b, c, d, {
                ["CFrame"] = CFrame.new(aim.Position, predicted + dropOffset)
            }, e, ammo, tickVal, recoil)
        end
    end

    return OriginalCreateBullet(a, b, c, d, aim, e, ammo, tickVal, recoil)
end)

-- ============================================================
-- ESP 系统
-- ============================================================
local ESPData = {}
local ESPBones = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"}, {"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"}, {"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"}, {"RightLowerLeg","RightFoot"},
}

local function NewDrawing(class, props)
    if not HasDrawing then return nil end
    local ok, d = pcall(function()
        local dr = Drawing.new(class)
        for k, v in pairs(props) do dr[k] = v end
        return dr
    end)
    return ok and d or nil
end

local function CreateESP(plr)
    if not HasDrawing then return end
    ESPData[plr] = {
        Box = NewDrawing("Square", {Color=Color3.new(1,1,1), Thickness=1, Filled=false}),
        BoxOutline = NewDrawing("Square", {Color=Color3.new(0,0,0), Thickness=3, Filled=false}),
        Name = NewDrawing("Text", {Color=Color3.new(1,1,1), Outline=true, Center=true, Size=13}),
        HealthOutline = NewDrawing("Line", {Thickness=3, Color=Color3.new(0,0,0)}),
        Health = NewDrawing("Line", {Thickness=1}),
        Distance = NewDrawing("Text", {Color=Color3.new(1,1,1), Size=12, Outline=true, Center=true}),
        Weapon = NewDrawing("Text", {Color=Color3.fromRGB(10,15,30), Size=12, Outline=true, Center=true}),
        SkeletonLines = {},
        Data = {OnScreen=false},
    }
end

local function UpdateESPData()
    if not HasDrawing then return end
    for plr, esp in pairs(ESPData) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos, vis = Camera:WorldToViewportPoint(hrp.Position)
                if vis then
                    local top = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0)).Y
                    local bot = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0,2.6,0)).Y
                    local h = (top - bot)/2
                    local sz = Vector2.new(math.floor(h*1.8), math.floor(h*1.9))
                    local bp = Vector2.new(math.floor(pos.X - sz.X/2), math.floor(pos.Y - h*1.6/2))

                    local hum = char:FindFirstChild("Humanoid")
                    local hp = hum and (hum.Health/hum.MaxHealth) or 0
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    local distText = math.floor(dist) .. "m"

                    local weaponName = "None"
                    pcall(function()
                        local pf = ReplicatedStorage:FindFirstChild("Players")
                        if pf then
                            local pd = pf:FindFirstChild(plr.Name)
                            if pd and pd:FindFirstChild("Status") then
                                local gv = pd.Status:FindFirstChild("GameplayVariables")
                                if gv then
                                    weaponName = gv:GetAttribute("EquippedTool") or gv.EquippedTool.Value or "None"
                                end
                            end
                        end
                    end)

                    esp.Data = {
                        OnScreen = dist <= Config.ESP.MaxDistance,
                        BoxSize = sz, BoxPos = bp,
                        Health = hp, Distance = distText, Weapon = weaponName,
                    }

                    -- 骨骼
                    if Config.ESP.ShowSkeleton and #esp.SkeletonLines == 0 then
                        for _, bone in ipairs(ESPBones) do
                            if char:FindFirstChild(bone[1]) and char:FindFirstChild(bone[2]) then
                                table.insert(esp.SkeletonLines, {
                                    NewDrawing("Line", {Thickness=2, Color=Color3.new(1,1,1), Transparency=1}),
                                    bone[1], bone[2]
                                })
                            end
                        end
                    end
                    for i = #esp.SkeletonLines, 1, -1 do
                        local sk = esp.SkeletonLines[i]
                        local b1 = char:FindFirstChild(sk[2])
                        local b2 = char:FindFirstChild(sk[3])
                        if b1 and b2 then
                            local p1 = Camera:WorldToViewportPoint(b1.Position)
                            local p2 = Camera:WorldToViewportPoint(b2.Position)
                            sk[1].From = Vector2.new(p1.X, p1.Y)
                            sk[1].To = Vector2.new(p2.X, p2.Y)
                            sk[1].Visible = Config.ESP.ShowSkeleton
                        else
                            if sk[1] and sk[1].Remove then sk[1]:Remove() end
                            table.remove(esp.SkeletonLines, i)
                        end
                    end
                else
                    esp.Data = {OnScreen=false}
                end
            else
                esp.Data = {OnScreen=false}
            end
        else
            esp.Data = {OnScreen=false}
        end
    end
end

local function RenderESP()
    if not HasDrawing then return end
    for plr, esp in pairs(ESPData) do
        local d = esp.Data
        if d and d.OnScreen and Config.ESP.Enabled then
            if Config.ESP.ShowBox then
                esp.Box.Size = d.BoxSize; esp.Box.Position = d.BoxPos
                esp.Box.Color = Color3.new(1,1,1); esp.Box.Visible = true
                esp.BoxOutline.Size = d.BoxSize; esp.BoxOutline.Position = d.BoxPos
                esp.BoxOutline.Visible = true
            else
                esp.Box.Visible = false; esp.BoxOutline.Visible = false
            end
            if Config.ESP.ShowHealth then
                local hp = d.Health
                esp.HealthOutline.From = Vector2.new(d.BoxPos.X-6, d.BoxPos.Y+d.BoxSize.Y)
                esp.HealthOutline.To = Vector2.new(esp.HealthOutline.From.X, esp.HealthOutline.From.Y - d.BoxSize.Y)
                esp.Health.From = Vector2.new(d.BoxPos.X-5, d.BoxPos.Y+d.BoxSize.Y)
                esp.Health.To = Vector2.new(esp.Health.From.X, esp.Health.From.Y - hp*d.BoxSize.Y)
                esp.Health.Color = Color3.new(1,0,0):Lerp(Color3.new(0,1,0), hp)
                esp.HealthOutline.Visible = true; esp.Health.Visible = true
            else
                esp.HealthOutline.Visible = false; esp.Health.Visible = false
            end
            if Config.ESP.ShowName then
                esp.Name.Text = plr.Name
                esp.Name.Position = Vector2.new(d.BoxPos.X+d.BoxSize.X/2, d.BoxPos.Y-16)
                esp.Name.Visible = true
            else
                esp.Name.Visible = false
            end
            if Config.ESP.ShowDistance then
                esp.Distance.Text = d.Distance
                esp.Distance.Position = Vector2.new(d.BoxPos.X+d.BoxSize.X/2, d.BoxPos.Y+d.BoxSize.Y+2)
                esp.Distance.Visible = true
            else
                esp.Distance.Visible = false
            end
            if Config.ESP.ShowWeapon then
                esp.Weapon.Text = d.Weapon
                esp.Weapon.Position = Vector2.new(d.BoxPos.X+d.BoxSize.X/2, d.BoxPos.Y+d.BoxSize.Y+16)
                esp.Weapon.Visible = true
            else
                esp.Weapon.Visible = false
            end
        else
            for _, k in ipairs{"Box","BoxOutline","Name","Health","HealthOutline","Distance","Weapon"} do
                if esp[k] then esp[k].Visible = false end
            end
            for _, sk in ipairs(esp.SkeletonLines) do
                if sk[1] then sk[1].Visible = false end
            end
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    if HasDrawing then CreateESP(plr) end
end)
Players.PlayerRemoving:Connect(function(plr)
    if ESPData[plr] then
        for _, v in pairs(ESPData[plr]) do
            if type(v) == "table" and v.Remove then pcall(v.Remove, v) end
        end
        ESPData[plr] = nil
    end
end)
if HasDrawing then
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then CreateESP(plr) end
    end
end

-- ============================================================
-- FOV 圆圈
-- ============================================================
local FovCircle = HasDrawing and NewDrawing("Circle", {
    Thickness=2, NumSides=100, Radius=Config.SilentAim.FovRadius,
    Color=Color3.new(1,1,1), Filled=false, Visible=false, Transparency=1
}) or nil

local function UpdateFovCircle()
    if not FovCircle then return end
    if Config.SilentAim.ShowFov then
        FovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        FovCircle.Radius = Config.SilentAim.FovRadius
        FovCircle.Visible = true
    else
        FovCircle.Visible = false
    end
end

-- ============================================================
-- UI 系统
-- ============================================================
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DeltaCheat"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = game.CoreGui or LocalPlayer:WaitForChild("PlayerGui")

    -- 主容器
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 480, 0, 420)
    Main.Position = UDim2.new(0.5, -240, 0.5, -210)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui

    -- 圆角效果
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Main

    -- 顶部栏
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 50)
    TopBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = Main

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 8)
    TopCorner.Parent = TopBar

    -- 底部填充防止圆角泄露
    local BottomFill = Instance.new("Frame")
    BottomFill.Size = UDim2.new(1, 0, 0, 8)
    BottomFill.Position = UDim2.new(0, 0, 1, -8)
    BottomFill.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    BottomFill.BorderSizePixel = 0
    BottomFill.Parent = TopBar

    -- Logo
    local Logo = Instance.new("TextLabel")
    Logo.Size = UDim2.new(0, 200, 1, 0)
    Logo.Position = UDim2.new(0, 16, 0, 0)
    Logo.BackgroundTransparency = 1
    Logo.Text = "PROJECT DELTA"
    Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    Logo.Font = Enum.Font.GothamBold
    Logo.TextSize = 16
    Logo.TextXAlignment = Enum.TextXAlignment.Left
    Logo.Parent = TopBar

    -- 状态指示灯
    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 8, 0, 8)
    StatusDot.Position = UDim2.new(0, 210, 0.5, -4)
    StatusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = TopBar
    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = StatusDot

    local StatusText = Instance.new("TextLabel")
    StatusText.Size = UDim2.new(0, 60, 1, 0)
    StatusText.Position = UDim2.new(0, 224, 0, 0)
    StatusText.BackgroundTransparency = 1
    StatusText.Text = "ACTIVE"
    StatusText.TextColor3 = Color3.fromRGB(0, 255, 100)
    StatusText.Font = Enum.Font.GothamSemibold
    StatusText.TextSize = 11
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.Parent = TopBar

    -- 关闭按钮
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 32, 0, 32)
    CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.Parent = TopBar
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Tab 按钮区域
    local TabBar = Instance.new("Frame")
    TabBar.Name = "TabBar"
    TabBar.Size = UDim2.new(1, 0, 0, 40)
    TabBar.Position = UDim2.new(0, 0, 0, 50)
    TabBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    TabBar.BorderSizePixel = 0
    TabBar.Parent = Main

    -- 内容区域
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -24, 1, -106)
    Content.Position = UDim2.new(0, 12, 0, 102)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    -- 滚动框架
    local Scrolling = Instance.new("ScrollingFrame")
    Scrolling.Size = UDim2.new(1, 0, 1, 0)
    Scrolling.BackgroundTransparency = 1
    Scrolling.BorderSizePixel = 0
    Scrolling.ScrollBarThickness = 3
    Scrolling.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
    Scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scrolling.Parent = Content

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.Parent = Scrolling

    local UIPadding = Instance.new("UIPadding")
    UIPadding.PaddingRight = UDim.new(0, 4)
    UIPadding.Parent = Scrolling

    -- 当前激活的Tab
    local ActiveTab = "Aimbot"
    local TabButtons = {}
    local ContentCache = {}

    -- 创建Tab按钮
    local function CreateTab(name, text, icon)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = icon .. "  " .. text
        btn.TextColor3 = Color3.fromRGB(140, 140, 150)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.Parent = TabBar

        -- 底部指示线
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(1, -40, 0, 2)
        indicator.Position = UDim2.new(0, 20, 1, -2)
        indicator.BackgroundColor3 = Color3.fromRGB(140, 60, 255)
        indicator.BorderSizePixel = 0
        indicator.Visible = false
        indicator.Parent = btn
        local indCorner = Instance.new("UICorner")
        indCorner.CornerRadius = UDim.new(1, 0)
        indCorner.Parent = indicator

        btn.MouseButton1Click:Connect(function()
            ActiveTab = name
            for _, b in pairs(TabButtons) do
                b.TextColor3 = Color3.fromRGB(140, 140, 150)
                b:FindFirstChildOfClass("Frame").Visible = false
            end
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            indicator.Visible = true

            -- 切换内容
            for n, frame in pairs(ContentCache) do
                frame.Visible = (n == name)
            end
        end)

        TabButtons[name] = btn
        if name == "Aimbot" then
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            indicator.Visible = true
        end
        btn.Parent = TabBar
        return btn
    end

    -- 布局Tab按钮
    local function LayoutTabs()
        local x = 8
        for _, btn in pairs(TabButtons) do
            btn.Position = UDim2.new(0, x, 0, 0)
            x = x + btn.Size.X.Offset + 4
        end
    end

    -- 创建分区
    local function CreateSection(parent, title)
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, 0, 0, 30)
        section.BackgroundTransparency = 1
        section.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundTransparency = 1
        label.Text = title
        label.TextColor3 = Color3.fromRGB(140, 60, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = section

        -- 分隔线
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 0, 26)
        line.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        line.BorderSizePixel = 0
        line.Parent = section

        section.Size = UDim2.new(1, 0, 0, 30)
        return section
    end

    -- 创建开关
    local function CreateToggle(parent, name, get, set)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 36)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(200, 200, 210)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local toggle = Instance.new("Frame")
        toggle.Size = UDim2.new(0, 40, 0, 22)
        toggle.Position = UDim2.new(1, -44, 0.5, -11)
        toggle.BackgroundColor3 = get() and Color3.fromRGB(140, 60, 255) or Color3.fromRGB(50, 50, 60)
        toggle.BorderSizePixel = 0
        toggle.Parent = frame
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggle

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = get() and UDim2.new(0, 20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = toggle
        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local newVal = not get()
                set(newVal)
                local targetBg = newVal and Color3.fromRGB(140, 60, 255) or Color3.fromRGB(50, 50, 60)
                local targetX = newVal and UDim2.new(0, 20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)

                TweenService:Create(toggle, TweenInfo.new(0.2), {BackgroundColor3 = targetBg}):Play()
                TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetX}):Play()
            end
        end)

        return frame
    end

    -- 创建滑块
    local function CreateSlider(parent, name, min, max, get, set, suffix)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 56)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 20)
        header.BackgroundTransparency = 1
        header.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(200, 200, 210)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = header

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.4, 0, 1, 0)
        valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(get()) .. (suffix or "")
        valueLabel.TextColor3 = Color3.fromRGB(140, 60, 255)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = header

        -- 滑块轨道
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, 4)
        track.Position = UDim2.new(0, 0, 0, 30)
        track.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        track.BorderSizePixel = 0
        track.Parent = frame
        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(0, 2)
        trackCorner.Parent = track

        -- 填充条
        local fill = Instance.new("Frame")
        local ratio = (get() - min) / (max - min)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(140, 60, 255)
        fill.BorderSizePixel = 0
        fill.Parent = track
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 2)
        fillCorner.Parent = fill

        -- 拖动球
        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.new(0, 14, 0, 14)
        thumb.Position = UDim2.new(ratio, -7, 0.5, -7)
        thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        thumb.BorderSizePixel = 0
        thumb.Parent = track
        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = thumb

        local dragging = false

        local function updateFromPos(x)
            local relX = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + relX * (max - min))
            set(val)
            valueLabel.Text = tostring(val) .. (suffix or "")
            fill.Size = UDim2.new(relX, 0, 1, 0)
            thumb.Position = UDim2.new(relX, -7, 0.5, -7)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateFromPos(input.Position.X)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromPos(input.Position.X)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        return frame
    end

    -- 创建下拉选择
    local function CreateDropdown(parent, name, options, get, set)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 36)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.4, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(200, 200, 210)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local dropdown = Instance.new("TextButton")
        dropdown.Size = UDim2.new(0, 160, 0, 28)
        dropdown.Position = UDim2.new(1, -164, 0.5, -14)
        dropdown.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        dropdown.Text = get()
        dropdown.TextColor3 = Color3.fromRGB(200, 200, 210)
        dropdown.Font = Enum.Font.GothamMedium
        dropdown.TextSize = 12
        dropdown.TextXAlignment = Enum.TextXAlignment.Left
        dropdown.Parent = frame
        local ddCorner = Instance.new("UICorner")
        ddCorner.CornerRadius = UDim.new(0, 5)
        ddCorner.Parent = dropdown

        local ddPadding = Instance.new("UIPadding")
        ddPadding.PaddingLeft = UDim.new(0, 10)
        ddPadding.Parent = dropdown

        -- 箭头
        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 20, 1, 0)
        arrow.Position = UDim2.new(1, -24, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "▾"
        arrow.TextColor3 = Color3.fromRGB(140, 140, 150)
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 10
        arrow.Parent = dropdown

        local menuOpen = false
        local menuFrame = nil

        dropdown.MouseButton1Click:Connect(function()
            if menuOpen then
                if menuFrame then menuFrame:Destroy(); menuFrame = nil end
                menuOpen = false
                return
            end
            menuOpen = true

            menuFrame = Instance.new("Frame")
            menuFrame.Size = UDim2.new(0, 160, 0, #options * 28 + 4)
            menuFrame.Position = UDim2.new(0, 0, 1, 4)
            menuFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            menuFrame.BorderSizePixel = 0
            menuFrame.ZIndex = 10
            menuFrame.Parent = dropdown
            local menuCorner = Instance.new("UICorner")
            menuCorner.CornerRadius = UDim.new(0, 5)
            menuCorner.Parent = menuFrame

            for i, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 28)
                optBtn.Position = UDim2.new(0, 0, 0, (i-1)*28 + 2)
                optBtn.BackgroundColor3 = (opt == get()) and Color3.fromRGB(140, 60, 255) or Color3.fromRGB(30, 30, 38)
                optBtn.Text = opt
                optBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
                optBtn.Font = Enum.Font.GothamMedium
                optBtn.TextSize = 12
                optBtn.TextXAlignment = Enum.TextXAlignment.Left
                optBtn.ZIndex = 11
                optBtn.Parent = menuFrame
                local optPadding = Instance.new("UIPadding")
                optPadding.PaddingLeft = UDim.new(0, 10)
                optPadding.Parent = optBtn

                optBtn.MouseButton1Click:Connect(function()
                    set(opt)
                    dropdown.Text = opt
                    menuFrame:Destroy()
                    menuFrame = nil
                    menuOpen = false
                end)
            end
        end)

        return frame
    end

    -- ============================================================
    -- 构建 Tab 内容
    -- ============================================================

    -- Aimbot Tab
    local aimbotContent = Instance.new("Frame")
    aimbotContent.Size = UDim2.new(1, 0, 1, 0)
    aimbotContent.BackgroundTransparency = 1
    aimbotContent.Visible = true
    aimbotContent.Parent = Scrolling
    ContentCache["Aimbot"] = aimbotContent

    -- ESP Tab
    local espContent = Instance.new("Frame")
    espContent.Size = UDim2.new(1, 0, 1, 0)
    espContent.BackgroundTransparency = 1
    espContent.Visible = false
    espContent.Parent = Scrolling
    ContentCache["ESP"] = espContent

    -- 创建Tab
    CreateTab("Aimbot", "静默自瞄", "🎯")
    CreateTab("ESP", "玩家ESP", "👁")
    LayoutTabs()

    -- Aimbot 内容
    CreateSection(aimbotContent, "主要设置")
    CreateToggle(aimbotContent, "静默自瞄", function() return Config.SilentAim.Enabled end, function(v) Config.SilentAim.Enabled = v end)
    CreateDropdown(aimbotContent, "瞄准部位", {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}, function() return Config.SilentAim.HitPart end, function(v) Config.SilentAim.HitPart = v end)

    CreateSection(aimbotContent, "辅助设置")
    CreateToggle(aimbotContent, "穿墙检测", function() return Config.SilentAim.WallCheck end, function(v) Config.SilentAim.WallCheck = v end)
    CreateToggle(aimbotContent, "子弹预测", function() return Config.SilentAim.Prediction end, function(v) Config.SilentAim.Prediction = v end)
    CreateToggle(aimbotContent, "攻击AI", function() return Config.SilentAim.TargetAI end, function(v) Config.SilentAim.TargetAI = v end)
    CreateToggle(aimbotContent, "攻击玩家", function() return Config.SilentAim.TargetPlayer end, function(v) Config.SilentAim.TargetPlayer = v end)

    CreateSection(aimbotContent, "FOV设置")
    CreateSlider(aimbotContent, "FOV范围", 60, 1200, function() return Config.SilentAim.FovRadius end, function(v) Config.SilentAim.FovRadius = v end, "")
    CreateSlider(aimbotContent, "命中率", 1, 100, function() return Config.SilentAim.HitChance end, function(v) Config.SilentAim.HitChance = v end, "%")
    CreateToggle(aimbotContent, "显示FOV圈", function() return Config.SilentAim.ShowFov end, function(v) Config.SilentAim.ShowFov = v end)

    -- ESP 内容
    if HasDrawing then
        CreateSection(espContent, "主要设置")
        CreateToggle(espContent, "玩家ESP", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)

        CreateSection(espContent, "显示选项")
        CreateToggle(espContent, "显示方框", function() return Config.ESP.ShowBox end, function(v) Config.ESP.ShowBox = v end)
        CreateToggle(espContent, "显示名字", function() return Config.ESP.ShowName end, function(v) Config.ESP.ShowName = v end)
        CreateToggle(espContent, "显示血量", function() return Config.ESP.ShowHealth end, function(v) Config.ESP.ShowHealth = v end)
        CreateToggle(espContent, "显示距离", function() return Config.ESP.ShowDistance end, function(v) Config.ESP.ShowDistance = v end)
        CreateToggle(espContent, "显示骨骼", function() return Config.ESP.ShowSkeleton end, function(v) Config.ESP.ShowSkeleton = v end)
        CreateToggle(espContent, "显示武器", function() return Config.ESP.ShowWeapon end, function(v) Config.ESP.ShowWeapon = v end)

        CreateSection(espContent, "距离限制")
        CreateSlider(espContent, "最大距离", 100, 10000, function() return Config.ESP.MaxDistance end, function(v) Config.ESP.MaxDistance = v end, " studs")
    else
        CreateSection(espContent, "⚠ 不可用")
        local warn = Instance.new("TextLabel")
        warn.Size = UDim2.new(1, 0, 0, 40)
        warn.BackgroundTransparency = 1
        warn.Text = "你的注入器不支持 Drawing 库\nESP 功能无法使用\n请换用 Solara / Wave 等注入器"
        warn.TextColor3 = Color3.fromRGB(255, 100, 100)
        warn.Font = Enum.Font.GothamMedium
        warn.TextSize = 12
        warn.TextWrapped = true
        warn.Parent = espContent
    end

    -- 更新滚动区域
    local totalHeight = 0
    for _, child in ipairs(Scrolling:GetChildren()) do
        if child:IsA("Frame") then
            totalHeight = totalHeight + child.Size.Y.Offset + 8
        end
    end
    Scrolling.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 8)

    -- 最小化按钮
    local minimized = false
    local originalSize = Main.Size
    local originalPos = Main.Position

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 32, 0, 32)
    MinBtn.Position = UDim2.new(1, -76, 0.5, -16)
    MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    MinBtn.Text = "─"
    MinBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 14
    MinBtn.Parent = TopBar
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            originalSize = Main.Size
            Main.Size = UDim2.new(0, 480, 0, 50)
            Content.Visible = false
            TabBar.Visible = false
        else
            Main.Size = originalSize
            Content.Visible = true
            TabBar.Visible = true
        end
    end)
end

-- ============================================================
-- 主循环
-- ============================================================
RunService.RenderStepped:Connect(function()
    UpdateESPData()
    RenderESP()
    UpdateFovCircle()
end)

-- ============================================================
-- 初始化
-- ============================================================
CreateUI()

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Project Delta",
        Text = "已加载! 自瞄默认开启 | 左侧面板切换功能",
        Duration = 5,
    })
end)

print("========================================")
print("[Project Delta] 静默自瞄 + ESP 已加载")
print("[自瞄] " .. (Config.SilentAim.Enabled and "✅ 已开启" or "❌ 已关闭"))
print("[ESP]  " .. (HasDrawing and "✅ Drawing可用" or "❌ 需切换注入器"))
print("========================================")