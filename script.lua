-- Vicious Bee Stinger Hunter Script v3.0 - STAY IN SERVER
-- Detects stinger when it spawns - NO SERVER HOPPING

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local request = request or http_request or syn.request
local player = Players.LocalPlayer

local config = {
    webhookUrl = "",
    isRunning = false,
    stingerDetected = false,
    currentField = "None",
    _descendantConnection = nil,
    _detectedStingers = {}
}

-- Load saved webhook
if isfile and readfile and isfile("vicious_bee_webhook.txt") then
    local saved = readfile("vicious_bee_webhook.txt")
    if saved and saved ~= "" then
        config.webhookUrl = saved
        print("✅ Loaded saved webhook")
    end
end

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

local function sendWebhook(title, description, color, webhookFields)
    if config.webhookUrl == "" then return end
    
    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["fields"] = webhookFields or {},
        ["timestamp"] = DateTime.now():ToIsoDate(),
        ["footer"] = {["text"] = "Vicious Bee Hunter | " .. player.Name}
    }
    
    local success, err = pcall(function()
        request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["embeds"] = {embed}})
        })
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
end

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

-- MAIN DETECTION: Check if object could be a stinger (STRICT)
local function couldBeStinger(obj)
    if not obj or not obj:IsA("BasePart") then return false end

    -- 1️⃣ CorePart is the main stinger
    if obj.Name == "CorePart" then
        print("✅ DETECTED REAL STINGER (CorePart)")
        return true
    end

    -- 2️⃣ Check for spikes/poking parts near CorePart
    local spikeNames = {"Stem", "C"} -- add more if you notice others
    for _, name in ipairs(spikeNames) do
        if obj.Name == name then
            -- Look for nearby CorePart (within 5 studs)
            for _, part in ipairs(workspace:GetDescendants()) do
                if part.Name == "CorePart" and part:IsA("BasePart") then
                    if (part.Position - obj.Position).Magnitude <= 5 then
                        print("⚠️ Detected spike near CorePart:", obj.Name)
                        return true
                    end
                end
            end
        end
    end

    -- 3️⃣ Mesh fallback: in case future stingers use MeshParts
    if obj:IsA("MeshPart") or obj:FindFirstChildOfClass("SpecialMesh") then
        print("⚠️ POSSIBLE STINGER (mesh-based):", obj.Name)
        return true
    end

    -- Otherwise, ignore unrelated parts
    return false
end

-- IMPROVED: Detect new objects spawning ANYWHERE in the game
local function onNewObject(obj)
    if not config.isRunning then return end
    
    -- Small delay to let object fully load
    task.wait(0.05)
    
    if not obj or not obj.Parent then return end
    
    -- Only check BaseParts (physical objects)
    if not obj:IsA("BasePart") then return end
    
    print("🔍 NEW OBJECT SPAWNED:", obj:GetFullName())
    print("   Type:", obj.ClassName)
    print("   Name:", obj.Name)
    print("   Parent:", obj.Parent:GetFullName())
    print("   Size:", obj.Size)
    print("   Position:", obj.Position)
    print("   Transparency:", obj.Transparency)
    
    -- Check if it could be a stinger
    if not couldBeStinger(obj) then 
        -- Don't spam console for every object
        return 
    end
    
    -- Avoid duplicate alerts
    if config._detectedStingers[obj] then 
        print("   ⚠️ Already detected")
        return 
    end
    
    print("   ⭐ POSSIBLE STINGER DETECTED!")
    
    config._detectedStingers[obj] = true
    
    -- Get field location
    local closestField, distance = getClosestField(obj.Position)
    
    config.stingerDetected = true
    config.currentField = closestField
    
    -- Get player distance
    local playerDistance = "Unknown"
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            playerDistance = math.floor((hrp.Position - obj.Position).Magnitude) .. " studs"
        end
    end
    
    -- Send webhook
    sendWebhook(
        "🎯 POSSIBLE VICIOUS BEE STINGER!",
        "A suspicious object has spawned that could be the Vicious Bee stinger!",
        0xFF0000,
        {
            { name = "📦 Object Name", value = obj.Name, inline = true },
            { name = "🔧 Type", value = obj.ClassName, inline = true },
            { name = "📍 Field", value = closestField, inline = true },
            { name = "📏 Field Distance", value = math.floor(distance) .. " studs", inline = true },
            { name = "👤 Player Distance", value = playerDistance, inline = true },
            { name = "📐 Size", value = string.format("%.1f, %.1f, %.1f", obj.Size.X, obj.Size.Y, obj.Size.Z), inline = false },
            { name = "🧭 Position", value = string.format("(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z), inline = false },
            { name = "🌐 Server ID", value = game.JobId, inline = false }
        }
    )
    
    -- Update GUI
    local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
    if gui and gui:FindFirstChild("MainFrame") then
        local statusLabel = gui.MainFrame:FindFirstChild("StatusLabel")
        if statusLabel then
            statusLabel.Text = "Status: 🎯 STINGER DETECTED!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        end
        
        local fieldLabel = gui.MainFrame:FindFirstChild("FieldLabel")
        if fieldLabel then
            fieldLabel.Text = "Field: 🐝 " .. closestField
            fieldLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
        end
    end
    
    print("🎯 STINGER ALERT SENT!")
    print("📍 Field:", closestField)
    print("📏 Distance:", distance, "studs")
    
    -- Clean up when removed
    obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            print("⚠️ Stinger removed from workspace")
            config._detectedStingers[obj] = nil
            config.stingerDetected = false
            config.currentField = "None"
        end
    end)
end

local function createGUI()
    if CoreGui:FindFirstChild("ViciousBeeHunterGUI") then
        CoreGui:FindFirstChild("ViciousBeeHunterGUI"):Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    local MainFrame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local WebhookBox = Instance.new("TextBox")
    local StartButton = Instance.new("TextButton")
    local StatusLabel = Instance.new("TextLabel")
    local FieldLabel = Instance.new("TextLabel")
    local InfoLabel = Instance.new("TextLabel")
    local CloseButton = Instance.new("TextButton")
    
    ScreenGui.Name = "ViciousBeeHunterGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    MainFrame.Size = UDim2.new(0, 400, 0, 300)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
    
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee Stinger Detector"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 17
    
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)
    
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseButton.Position = UDim2.new(1, -35, 0, 10)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    
    Instance.new("UICorner", CloseButton)
    
    WebhookBox.Parent = MainFrame
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
    
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.Position = UDim2.new(0, 20, 0, 125)
    StartButton.Size = UDim2.new(1, -40, 0, 45)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START DETECTING"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 16
    
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 8)
    
    StatusLabel.Parent = MainFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 185)
    StatusLabel.Size = UDim2.new(1, -40, 0, 25)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Parent = MainFrame
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 20, 0, 210)
    FieldLabel.Size = UDim2.new(1, -40, 0, 25)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Field: Waiting..."
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 13
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    InfoLabel.Parent = MainFrame
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Position = UDim2.new(0, 20, 0, 240)
    InfoLabel.Size = UDim2.new(1, -40, 0, 45)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "💡 Monitors ENTIRE GAME for stinger spawns anywhere"
    InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    InfoLabel.TextSize = 11
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            local webhook = WebhookBox.Text
            if webhook == "" or not webhook:match("^https://discord%.com/api/webhooks/") then
                StatusLabel.Text = "Status: ❌ Invalid Webhook URL"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                return
            end
            
            config.webhookUrl = webhook
            
            if writefile then
                writefile("vicious_bee_webhook.txt", webhook)
                print("✅ Webhook saved")
            end
            
            config.isRunning = true
            
            -- Connect the listener for new objects EVERYWHERE in the game
            if not config._descendantConnection then
                config._descendantConnection = game.DescendantAdded:Connect(onNewObject)
                print("✅ Monitoring ENTIRE GAME for new objects...")
            end
            
            StartButton.Text = "STOP DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            StatusLabel.Text = "Status: 👀 Watching for stingers..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            sendWebhook(
                "🚀 Detection Started", 
                "Now monitoring for Vicious Bee stinger spawns in this server!", 
                0x00AAFF, 
                {{name = "🌐 Server ID", value = game.JobId, inline = false}}
            )
            
            print("🎯 DETECTION ACTIVE - Watching for new objects...")
        else
            config.isRunning = false
            
            if config._descendantConnection then
                config._descendantConnection:Disconnect()
                config._descendantConnection = nil
                print("✅ Stopped monitoring")
            end
            
            StartButton.Text = "START DETECTING"
            StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            StatusLabel.Text = "Status: Stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            FieldLabel.Text = "Field: Waiting..."
            FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        config.isRunning = false
        if config._descendantConnection then
            config._descendantConnection:Disconnect()
        end
        ScreenGui:Destroy()
    end)
end

print("🐝 Vicious Bee Stinger Detector v3.0 Loaded!")
print("📱 Opening GUI...")
print("🎯 This script stays in ONE server and watches for stinger spawns!")
createGUI()
