local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.react)
local ReactRoblox = require(Packages:FindFirstChild("react-roblox"))
local handle = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)
local root = ReactRoblox.createRoot(handle)

-- Water Simulation Constants
local demoScreenSize = UDim2.new(1, 0, 1, 0)    -- Size of the demonstration fream
local nColumns = 500                            -- Number of simulated columns
local s = demoScreenSize.X.Scale / nColumns     -- Width of each column
local tPerStep = 5 / nColumns                   -- Time step amount
local stepsBetweenFrames = 10                   -- Time steps between heartbeats
local c = tPerStep / 10                         -- Wave speed
local k = math.pow(c, 2) / math.pow(s, 2)       -- Discrecitization of wave equation
local _columnObject = {                         -- Column object scaffold
    h = 0,
    v = 0,
}
local rng = Random.new()                        -- Random Number Generator for decimal numbers
local columnDict = {}                           -- Dictionary of columns each column holds the column object
local waterLevelLeft = 0.5                      -- Resting water level of left side of screen
local waterLevelRight = 0.5                     -- Resting water level of right side of screen
local rngLowerLimit = 0
local rngUpperLimit = 0.25
for i = 1, nColumns do
    columnDict[i] = {
        h = 0 + rng:NextNumber(rngLowerLimit, rngUpperLimit),
        v = 0
    }
end

local minDomainX = 1
local maxDomainX = nColumns

local function calculate_a_i(k, i, columnDict, minDomainX, maxDomainX)
    if i - 1 < minDomainX then
        return k * (waterLevelLeft + columnDict[i + 1].h - (2 * columnDict[i].h) )          -- Contribution if only right neighbor exists
    elseif i + 1 > maxDomainX then
        return k * (waterLevelRight + columnDict[i - 1].h - (2 * columnDict[i].h) )         -- Contribution if only left neighbor exists
    else 
        return k * ( columnDict[i - 1].h + columnDict[i + 1].h - (2 * columnDict[i].h) )    -- Contribution if both neighbors exists
    end
end

local function Bar(props)
    local id = props.id
    local index = props.index
    
    local height, setHeight = React.useState(columnDict[id].h)
    local colorMod = index % 2 == 0 and 200 or 150

    React.useEffect(function()
        local timer = game:GetService("RunService").Heartbeat:Connect(function()
            if columnDict[id] then
                setHeight(columnDict[id].h)     -- Sets visible column height every heartbeat
            end
        end)
        return function()
            timer:Disconnect()
        end
    end, {}) -- {} Prevents running inner code more than once

    return React.createElement("Frame", {
        Size = UDim2.fromScale(s, height), 
        BackgroundColor3 = Color3.fromRGB(colorMod, 100, 255), -- Changes color every even or odd number
        BorderSizePixel = 0,
        LayoutOrder = index,
    })
end

local function DemonstrationScreen(props)
    local children = {}
    local items = {}

    for i = 1, nColumns do
        table.insert(items, i)
    end

    -- Arrange bars side to side with no gaps horizontally
    children.UIListLayout = React.createElement("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0), -- 0 padding ensures seamless 1/nTh alignment
    })

    for index, id in ipairs(items) do
        children["Bar_" .. id] = React.createElement(Bar, {
            id = id,
            index = index
        }) -- Populate children list for main bar holder
    end

	React.useEffect(function() -- Runs ONCE when created
		print("connecting to keyboard signal")
		local UserInputService = game:GetService("UserInputService")
		local timer = game:GetService("RunService").Heartbeat:Connect(function()
			props.OnHeartbeat()
		end)
		return function()
			print("disconnecting from keyboard signal")
			timer:Disconnect()
		end
	end, {}) -- empty dependency array means this effect only runs once
	return React.createElement("Frame", {
		Size = demoScreenSize,
        BorderMode = Enum.BorderMode.Outline,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
	}, children)
end

root:render(React.createElement(DemonstrationScreen, {
    OnHeartbeat = function()
        for step = 1, stepsBetweenFrames do 
            for i = 1, nColumns do
                local o = columnDict[i]
                if o then
                    o.v = o.v + (tPerStep * calculate_a_i(k, i, columnDict, minDomainX, maxDomainX))
                    o.v = o.v * 0.995
                    o.h = o.h + o.v
                end
            end
        end
    end
}))