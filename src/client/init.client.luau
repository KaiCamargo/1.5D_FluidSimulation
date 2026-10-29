local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.react)
local ReactRoblox = require(Packages:FindFirstChild("react-roblox"))
local handle = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)
local root = ReactRoblox.createRoot(handle)

-- Water Simulation Constants CURRENTLY TUNED FOR WATER
local demoScreenSize = UDim2.new(1, 0, 1, 0)    -- Size of the demonstration fream
local nColumns = 500                            -- Number of simulated columns
local s = demoScreenSize.X.Scale / nColumns     -- Width of each column
local tPerStep = 1 / 100                   		-- Time step amount per heartbeat
local stepsBetweenFrames = 10                   -- Calculation steps between heartbeats (1 is normal simulation speed, 10 is 10x simulation speed with no loss)
local c = 1 / 700                          		-- Wave speed
local damp = 0.9945 							-- Damping of velocity
local k = math.pow(c, 2) / math.pow(s, 2)       -- Discrecitization of wave equation
local _columnObject = {                         -- Column object scaffold
    h = 0,
    v = 0,
}
local rng = Random.new()                        -- Random Number Generator for decimal numbers
local columnDict = {}                           -- Dictionary of columns each column holds the column object
local waterLevelLeft = 0.5                      -- Resting water level of left side of screen outside of bounds
local waterLevelRight = 0.5                     -- Resting water level of right side of screen outside of bounds
local minimumStartingWaterLevel = 0				-- The level all the columns will start at before any rng
local rngLowerLimit = 0							-- Minimum random value
local rngUpperLimit = 0							-- Set rng to 0.5 for interesting waves
local applyLeftWaterLevel = false				-- Whether or not the left side will behave like there's a column to the left with waterLevelLeft height when out of bounds
local applyRightWaterLevel = false				-- Whether or not the right side will behave like there's a column to the right with waterLevelRight height when out of bounds
for i = 1, nColumns do							-- Set all initial heights, experiment with adding equations
    columnDict[i] = {
        -- h = minimumWaterLevel + rng:NextNumber(rngLowerLimit, rngUpperLimit),	-- Equation to set all the initial heights of the columns
		h = ((25 * math.sin( ( math.pi * i ) / 10) ) + 25) / 50,                            -- Sinosudial equation to set initial heights
        v = 0                                                                       -- Sets initial velocity to zero set equation to a concave up parabola to simulate a splash in the middle at the start
    }
end

local minDomainX = 1
local maxDomainX = nColumns

local function calculate_a_i(k, i, columnDict, minDomainX, maxDomainX) -- Calculates the acceleration that will be added to the velocity of the columns
    if i - 1 < minDomainX then
		if not applyLeftWaterLevel then
			return k * (columnDict[i + 1].h - columnDict[i].h)								-- Contribution if only right neighbor exists and only the right neighbor is considered
		end
        return k * (waterLevelLeft + columnDict[i + 1].h - (2 * columnDict[i].h) )          -- Contribution if only right neighbor exists and constant water level assumed to the left
    elseif i + 1 > maxDomainX then
		if not applyRightWaterLevel then
			return k * (columnDict[i - 1].h - columnDict[i].h)								-- Contribution if only left neighbor exists and only the left neighbor is considered
		end
        return k * (waterLevelRight + columnDict[i - 1].h - (2 * columnDict[i].h) )         -- Contribution if only left neighbor exists and constant water level assumed to the right
    else 
        return k * ( columnDict[i - 1].h + columnDict[i + 1].h - (2 * columnDict[i].h) )    -- Contribution if both neighbors exists
    end
end

local function Bar(props) -- The class of the columns of water
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
		local timer = game:GetService("RunService").Heartbeat:Connect(function()
			props.OnHeartbeat()	-- Runs OnHeartbeat every physics simulation step
		end)
		return function()
			print("disconnecting from heartbeat signal")
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
                    o.v = o.v + (tPerStep * calculate_a_i(k, i, columnDict, minDomainX, maxDomainX)) -- Add acceleration to velocity of bars
                    o.v = o.v * damp -- Damping of velocity
                    o.h = o.h + o.v -- Add velocity to height of bars
                end
            end
        end
    end
}))