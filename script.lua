-- Vicious Bee Stinger Detector - ONLY detects "Thorn" parts

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local request = request or http_request or syn.request
local player = Players.LocalPlayer

local config = {
    webhookUrl = "",
    isRunning = false,
    _descendantConnection = nil,
    _detectedStingers = {},
    currentField = "None"
}

-- Load saved webhook
if isfile and readfile and isfile("vicious_bee_webhook.txt") then
    local saved = readfile("vicious_bee_webhook.txt")
    if saved and saved ~= "" then
        config.webhookUrl = saved
        print("✅ Loaded saved webhook")
    end
end

-- Fields
local fields = {
    ["Sunflower Field"] = Vector3.new(183, 4, 165),
    ["Mushroom Field"] = Vector3.new(-253, 4, 299),
    ["Dandelion Field"] = Vector3.new(-30, 4, 225),
    ["Blue Flower Field"] = Vector3.new(113, 4, 88),
    ["Clover Field"] = Vector3.new(174, 34, 189),
    ["Strawberry Field"] = Vector3.new(-169, 20, 165),
    ["Spider Field"] = Vector3.new(-57, 20, 4),
    ["Bamboo Field"] = Vector3.new(93, 20, -25),
    ["Pineapple Patch"] = Vector3.new(262, 68, -201),
    ["Pumpkin Patch"] = Vector3.new(-194, 68, -182),
    ["Cactus Field"] = Vector3.new(-194, 68, -107),
    ["Rose Field"] = Vector3.new(-322, 20, 124),
    ["Pine Tree Forest"] = Vector3.new(-318, 68, -150),
    ["Stump Field"] = Vector3.new(439, 96, -179),
    ["Coconut Field"] = Vector3.new(-255, 72, 459),
    ["Pepper Patch"] = Vector3.new(-486, 124, 517),
    ["Mountain Top Field"] = Vector3.new(76, 176, -191)
}

-- Helper: find closest field
local function getClosestField(pos)
    local closestField = "Unknown"
    local closestDistance = math.huge
    for name, fPos in pairs(fields) do
        local dist = (pos - fPos).Magnitude
        if dist < closestDistance then
            closestDistance = dist
            closestField = name
        end
    end
    return closestField, closestDistance
end

-- Webhook sender
local function sendWebhook(title, description, color, fieldsData)
    if config.webhookUrl == "" then return end
    local embed = {
        title = title,
        description = description,
        color = color,
        fields = fieldsData or {},
        timestamp = DateTime.now():ToIsoDate(),
        footer = {text = "Vicious Bee Hunter | " .. player.Name}
    }
    pcall(function()
        request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({embeds = {embed}})
        })
    end)
end

-- Detect "Thorn" parts
local function onNewObject(obj)
    if not config.isRunning then return end
    task.wait(0.05)
    if not obj or not obj.Parent then return end
    if obj.Name ~= "Thorn" then return end -- ONLY Thorn parts
    if config._detectedStingers[obj] then return end

    local pos = obj.Position
    local field, distance = getClosestField(pos)
    if field == "Unknown" or distance > 150 then return end -- must be near field

    config._detectedStingers[obj] = true
    config.currentField = field

    local playerDistance = "Unknown"
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        playerDistance = math.floor((char.HumanoidRootPart.Position - pos).Magnitude) .. " studs"
    end

    -- Send webhook alert
    sendWebhook(
        "🎯 Vicious Bee Stinger Found!",
        "A **Thorn** part matching the stinger has spawned!",
        0xFF0000,
        {
            {name = "📦 Object Name", value = obj.Name, inline = true},
            {name = "🔧 Type", value = obj.ClassName, inline = true},
            {name = "📍 Field", value = field, inline = true},
            {name = "📏 Field Distance", value = math.floor(distance).." studs", inline = true},
            {name = "👤 Player Distance", value = playerDistance, inline = true},
            {name = "📐 Size", value = string.format("%.1f, %.1f, %.1f", obj.Size.X, obj.Size.Y, obj.Size.Z), inline = false},
            {name = "🧭 Position", value = string.format("(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z), inline = false},
            {name = "🌐 Server ID", value = game.JobId, inline = false}
        }
    )

    print("🎯 Vicious Bee Stinger Detected!", "Field:", field)

    -- Remove from tracking if deleted
    obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            config._detectedStingers[obj] = nil
            config.currentField = "None"
        end
    end)
end

-- GUI
local function createGUI()
    if CoreGui:FindFirstChild("ViciousBeeHunterGUI") then
        CoreGui:FindFirstChild("ViciousBeeHunterGUI"):Destroy()
    end
    local ScreenGui = Instance.new("ScreenGui", CoreGui)
    ScreenGui.Name = "ViciousBeeHunterGUI"

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30,30,35)
    MainFrame.Size = UDim2.new(0,400,0,300)
    MainFrame.Position = UDim2.new(0.5,-200,0.5,-150)
    MainFrame.Active = true
    MainFrame.Draggable = true
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

    local Title = Instance.new("TextLabel", MainFrame)
    Title.Size = UDim2.new(1,0,0,50)
    Title.BackgroundColor3 = Color3.fromRGB(255,200,50)
    Title.Text = "🐝 Vicious Bee Stinger Detector"
    Title.Font = Enum.Font.GothamBold
    Title.TextColor3 = Color3.fromRGB(20,20,20)
    Title.TextSize = 17
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0,12)

    local WebhookBox = Instance.new("TextBox", MainFrame)
    WebhookBox.Size = UDim2.new(1,-40,0,40)
    WebhookBox.Position = UDim2.new(0,20,0,70)
    WebhookBox.BackgroundColor3 = Color3.fromRGB(45,45,50)
    WebhookBox.PlaceholderText = "Enter Discord Webhook URL..."
    WebhookBox.Text = config.webhookUrl
    WebhookBox.TextColor3 = Color3.fromRGB(255,255,255)
    WebhookBox.TextSize = 14
    Instance.new("UICorner", WebhookBox).CornerRadius = UDim.new(0,8)

    local StartButton = Instance.new("TextButton", MainFrame)
    StartButton.Size = UDim2.new(1,-40,0,45)
    StartButton.Position = UDim2.new(0,20,0,125)
    StartButton.BackgroundColor3 = Color3.fromRGB(50,200,50)
    StartButton.Text = "START DETECTING"
    StartButton.Font = Enum.Font.GothamBold
    StartButton.TextColor3 = Color3.fromRGB(255,255,255)
    StartButton.TextSize = 16
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0,8)

    local StatusLabel = Instance.new("TextLabel", MainFrame)
    StatusLabel.Size = UDim2.new(1,-40,0,25)
    StatusLabel.Position = UDim2.new(0,20,0,185)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200,200,200)

    local PositionLabel = Instance.new("TextLabel", MainFrame)
    PositionLabel.Name = "PositionLabel"
    PositionLabel.Size = UDim2.new(1,-40,0,25)
    PositionLabel.Position = UDim2.new(0,20,0,240)
    PositionLabel.BackgroundTransparency = 1
    PositionLabel.Font = Enum.Font.Gotham
    PositionLabel.TextSize = 13
    PositionLabel.TextXAlignment = Enum.TextXAlignment.Left
    PositionLabel.TextColor3 = Color3.fromRGB(180,180,180)
    PositionLabel.Text = "Position: (X, Y, Z)"

    -- Start Button
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            local webhook = WebhookBox.Text
            if webhook == "" or not webhook:match("^https://discord%.com/api/webhooks/") then
                StatusLabel.Text = "Status: ❌ Invalid Webhook URL"
                StatusLabel.TextColor3 = Color3.fromRGB(255,100,100)
                return
            end
            config.webhookUrl = webhook
            if writefile then writefile("vicious_bee_webhook.txt", webhook) end
            config.isRunning = true
            if not config._descendantConnection then
                config._descendantConnection = game.DescendantAdded:Connect(onNewObject)
            end
            StartButton.Text = "STOP DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
            StatusLabel.Text = "Status: 👀 Watching for stingers..."
            StatusLabel.TextColor3 = Color3.fromRGB(100,255,100)
        else
            config.isRunning = false
            if config._descendantConnection then
                config._descendantConnection:Disconnect()
                config._descendantConnection = nil
            end
            StartButton.Text = "START DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(50,200,50)
            StatusLabel.Text = "Status: Stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(200,200,200)
        end
    end)
end

createGUI()

-- Update player position in GUI
RunService.RenderStepped:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
        if gui then
            local label = gui.MainFrame:FindFirstChild("PositionLabel")
            if label then
                label.Text = string.format("Position: (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
            end
        end
    end
end)

print("🐝 Vicious Bee Stinger Detector Loaded! Waiting for Thorn...")
