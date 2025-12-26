local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

pcall(function()
    player.PlayerGui:FindFirstChild("NeutralUI"):Destroy()
end)

local library = {}

function library:Window(title)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NeutralUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = game.CoreGui

    local Main = Instance.new("Frame")
    Main.Parent = ScreenGui
    Main.Size = UDim2.fromOffset(280, 360)
    Main.Position = UDim2.fromScale(0.5, 0.5)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true

    local MainCorner = Instance.new("UICorner", Main)
    MainCorner.CornerRadius = UDim.new(0, 8)

    local Title = Instance.new("TextLabel")
    Title.Parent = Main
    Title.Size = UDim2.new(1, -12, 0, 28)
    Title.Position = UDim2.fromOffset(6, 6)
    Title.BackgroundTransparency = 1
    Title.Text = title or "Window"
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local Divider = Instance.new("Frame")
    Divider.Parent = Main
    Divider.Position = UDim2.fromOffset(6, 38)
    Divider.Size = UDim2.new(1, -12, 0, 1)
    Divider.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    Divider.BorderSizePixel = 0

    local TabContainer = Instance.new("Frame")
    TabContainer.Parent = Main
    TabContainer.Position = UDim2.fromOffset(6, 44)
    TabContainer.Size = UDim2.new(1, -12, 1, -50)
    TabContainer.BackgroundTransparency = 1

    local ScrollingFrame = Instance.new("ScrollingFrame")
    ScrollingFrame.Parent = TabContainer
    ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    ScrollingFrame.BackgroundTransparency = 1
    ScrollingFrame.BorderSizePixel = 0
    ScrollingFrame.ScrollBarThickness = 3
    ScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 105)
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

    function library:Tab(name)
        local TabFrame = Instance.new("Frame")
        TabFrame.Parent = ScrollingFrame
        TabFrame.Size = UDim2.new(1, -3, 0, 0)
        TabFrame.AutomaticSize = Enum.AutomaticSize.Y
        TabFrame.BackgroundTransparency = 1

        local Layout = Instance.new("UIListLayout")
        Layout.Parent = TabFrame
        Layout.Padding = UDim.new(0, 5)
        Layout.SortOrder = Enum.SortOrder.LayoutOrder

        function library:Section(title)
            local Section = Instance.new("Frame")
            Section.Parent = TabFrame
            Section.Size = UDim2.new(1, 0, 0, 30)
            Section.AutomaticSize = Enum.AutomaticSize.Y
            Section.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
            Section.BorderSizePixel = 0

            local Corner = Instance.new("UICorner", Section)
            Corner.CornerRadius = UDim.new(0, 6)

            local Padding = Instance.new("UIPadding", Section)
            Padding.PaddingTop = UDim.new(0, 5)
            Padding.PaddingBottom = UDim.new(0, 5)
            Padding.PaddingLeft = UDim.new(0, 5)
            Padding.PaddingRight = UDim.new(0, 5)

            local Label = Instance.new("TextLabel")
            Label.Parent = Section
            Label.Size = UDim2.new(1, 0, 0, 18)
            Label.BackgroundTransparency = 1
            Label.Text = title
            Label.Font = Enum.Font.GothamSemibold
            Label.TextSize = 14
            Label.TextColor3 = Color3.fromRGB(220, 220, 225)
            Label.TextXAlignment = Enum.TextXAlignment.Left

            local SectionLayout = Instance.new("UIListLayout")
            SectionLayout.Parent = Section
            SectionLayout.Padding = UDim.new(0, 3)
            SectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

            function library:Button(text, callback)
                local Button = Instance.new("TextButton")
                Button.Parent = Section
                Button.Size = UDim2.new(1, 0, 0, 28)
                Button.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
                Button.Text = text
                Button.Font = Enum.Font.GothamMedium
                Button.TextSize = 14
                Button.TextColor3 = Color3.fromRGB(240, 240, 245)
                Button.AutoButtonColor = false

                local Corner = Instance.new("UICorner", Button)
                Corner.CornerRadius = UDim.new(0, 5)

                Button.MouseButton1Click:Connect(function()
                    Button.BackgroundColor3 = Color3.fromRGB(75, 75, 82)
                    task.delay(0.1, function()
                        Button.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
                    end)
                    callback()
                end)
            end

            function library:Label(text)
                local Label = Instance.new("TextLabel")
                Label.Parent = Section
                Label.Size = UDim2.new(1, 0, 0, 16)
                Label.BackgroundTransparency = 1
                Label.Text = text
                Label.Font = Enum.Font.GothamMedium
                Label.TextSize = 12
                Label.TextColor3 = Color3.fromRGB(180, 180, 185)
                Label.TextXAlignment = Enum.TextXAlignment.Center
            end

            function library:UnloadButton()
                local UnloadBtn = Instance.new("TextButton")
                UnloadBtn.Parent = Section
                UnloadBtn.Size = UDim2.new(1, 0, 0, 28)
                UnloadBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
                UnloadBtn.Text = "Unload UI"
                UnloadBtn.Font = Enum.Font.GothamBold
                UnloadBtn.TextSize = 14
                UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                UnloadBtn.AutoButtonColor = false

                local Corner = Instance.new("UICorner", UnloadBtn)
                Corner.CornerRadius = UDim.new(0, 5)

                UnloadBtn.MouseButton1Click:Connect(function()
                    UnloadBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                    task.wait(0.1)
                    ScreenGui:Destroy()
                end)
            end

            return library
        end

        return library
    end

    return library
end

local function pressE()
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local ui = library:Window("Quest Force Complete")
local tab = ui:Tab("Bears")
local section = tab:Section("Force Complete Bears")

local bears = {
    "Black Bear",
    "Mother Bear",
    "Brown Bear",
    "Panda Bear",
    "Science Bear",
    "Polar Bear",
    "Spirit Bear",
    "Dapper Bear"
}

for _, bear in ipairs(bears) do
    section:Button(bear, pressE)
end

section:Label("Use on Alt")
section:UnloadButton()
