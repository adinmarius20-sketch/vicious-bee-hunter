-- Vicious Bee/Object Hunter Script v3.1
-- Detects objects that appear near fields, looks for stinger-like parts

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
    _detectedObjects = {},
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

-- Field centers
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
    local success, err = pcall(function()
        request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({embeds = {embed}})
        })
    end)
    if not success then
        warn("Webhook failed:", err)
    end
end

-- Find closest field to a position
local function getClosestField(position)
    local closestField = "Unknown"
    local closestDistance = math.huge
    for fieldName, fieldPos in pairs(fields) do
        local dist = (position - fieldPos).Magnitude
        if dist < closestDistance then
            closestDistance = dist
            closestField = fieldName
        end
    end
    return closestField, closestDistance
end

-- Check if part looks like a stinger/object of interest
local function isInterestingObject(obj)
    if not obj or not obj:IsA("BasePart") then return false end
    if obj.Size.Magnitude < 1 then return false end -- ignore tiny parts

    local nameWhitelist = {"C", "Stem", "CorePart"} -- common stinger parts
    for _, n in ipairs(nameWhitelist) do
        if obj.Name == n then
            return true
        end
    end

    -- Optional: any thin, elongated part
    local size = obj.Size
    if size.Y >= 2 and size.X < 2 and size.Z < 2 then
        return true
    end

    return false
end

-- Detect new objects near fields
local function onNewObject(obj)
    if not config.isRunning then return end
    task.wait(0.05)
    if not obj or not obj.Parent then return end
    if not obj:IsA("BasePart") then return end
    if config._detectedObjects[obj] then return end

    local field, distance = getClosestField(obj.Position)
    if field == "Unknown" or distance > 150 then return end

    if not isInterestingObject(obj) then return end

    config._detectedObjects[obj] = true
    config.currentField = field

    local playerDistance = "Unknown"
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        playerDistance = math.floor((char.HumanoidRootPart.Position - obj.Position).Magnitude) .. " studs"
    end

    sendWebhook(
        "🟡 Object Detected in Field!",
        "A new object has spawned near a field.",
        0xFFFF00,
        {
            {name = "📦 Object Name", value = obj.Name, inline = true},
            {name = "🔧 Type", value = obj.ClassName, inline = true},
            {name = "📍 Field", value = config.currentField, inline = true},
            {name = "📏 Field Distance", value = math.floor(distance) .. " studs", inline = true},
            {name = "👤 Player Distance", value = playerDistance, inline = true},
            {name = "📐 Size", value = string.format("%.1f, %.1f, %.1f", obj.Size.X, obj.Size.Y, obj.Size.Z), inline = false},
            {name = "🧭 Position", value = string.format("(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z), inline = false},
            {name = "🌐 Server ID", value = game.JobId, inline = false}
        }
    )

    print("🟡 Object Detected Near Field:", obj.Name, "Field:", field)

    obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            config._detectedObjects[obj] = nil
            config.currentField = "None"
        end
    end)
end

-- GUI Creation
local function createGUI()
    if CoreGui:FindFirstChild("ViciousBeeHunterGUI") then
        CoreGui:FindFirstChild("ViciousBeeHunterGUI"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui", CoreGui)
    ScreenGui.Name = "ViciousBeeHunterGUI"

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    MainFrame.Size = UDim2.new(0, 400, 0, 330)
    MainFrame.Active = true
    MainFrame.Draggable = true
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

    local Title = Instance.new("TextLabel", MainFrame)
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee/Object Detector"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 17
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

    local WebhookBox = Instance.new("TextBox", MainFrame)
    WebhookBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    WebhookBox.Position = UDim2.new(0, 20, 0, 70)
    WebhookBox.Size = UDim2.new(1, -40, 0, 40)
    WebhookBox.Font = Enum.Font.Gotham
    WebhookBox.PlaceholderText = "Enter Discord Webhook URL..."
    WebhookBox.Text = config.webhookUrl
    WebhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookBox.TextSize = 14
    WebhookBox.ClearTextOnFocus = false
    Instance.new("UICorner", WebhookBox).CornerRadius = UDim.new(0, 8)

    local StartButton = Instance.new("TextButton", MainFrame)
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.Position = UDim2.new(0, 20, 0, 125)
    StartButton.Size = UDim2.new(1, -40, 0, 45)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START DETECTING"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 16
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 8)

    local StatusLabel = Instance.new("TextLabel", MainFrame)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 185)
    StatusLabel.Size = UDim2.new(1, -40, 0, 25)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

    local InfoLabel = Instance.new("TextLabel", MainFrame)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Position = UDim2.new(0, 20, 0, 240)
    InfoLabel.Size = UDim2.new(1, -40, 0, 45)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "💡 Monitors ENTIRE GAME for stinger-like objects near fields"
    InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    InfoLabel.TextSize = 11
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Position Label
    local PositionLabel = Instance.new("TextLabel", MainFrame)
    PositionLabel.Name = "PositionLabel"
    PositionLabel.BackgroundTransparency = 1
    PositionLabel.Position = UDim2.new(0, 20, 0, 285)
    PositionLabel.Size = UDim2.new(1, -40, 0, 25)
    PositionLabel.Font = Enum.Font.Gotham
    PositionLabel.Text = "Position: (X, Y, Z)"
    PositionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    PositionLabel.TextSize = 13
    PositionLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Start Button Logic
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            local webhook = WebhookBox.Text
            if webhook == "" or not webhook:match("^https://discord%.com/api/webhooks/") then
                StatusLabel.Text = "Status: ❌ Invalid Webhook URL"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end

            config.webhookUrl = webhook
            if writefile then writefile("vicious_bee_webhook.txt", webhook) end
            config.isRunning = true

            if not config._descendantConnection then
                config._descendantConnection = game.DescendantAdded:Connect(onNewObject)
                print("✅ Monitoring ENTIRE GAME for new objects...")
            end

            StartButton.Text = "STOP DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 👀 Watching for objects..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

            sendWebhook(
                "🚀 Detection Started", 
                "Now monitoring for stinger-like objects in this server!", 
                0x00AAFF, 
                {{name = "🌐 Server ID", value = game.JobId, inline = false}}
            )
        else
            config.isRunning = false
            if config._descendantConnection then
                config._descendantConnection:Disconnect()
                config._descendantConnection = nil
            end
            StartButton.Text = "START DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            StatusLabel.Text = "Status: Stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)
end

-- Create GUI
createGUI()

-- Update position in real time
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

print("🐝 Vicious Bee/Object Detector v3.1 Loaded!")
