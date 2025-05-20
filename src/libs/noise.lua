-- Perlin Noise in Lua
-- Adapted from various public domain sources

local Noise = {}

local PERMUTATION_TABLE_SIZE = 256
local perm = {}
local gradX = {}
local gradY = {}
local gradZ = {}

-- Linear interpolation
local function lerp(a, b, t)
    return a + t * (b - a)
end

-- Fade function (Ken Perlin's improved version: 6t^5 - 15t^4 + 10t^3)
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function randomVector(seedRandom)
    local theta = seedRandom() * 2 * math.pi
    local phi = seedRandom() * math.pi
    local x = math.cos(theta) * math.sin(phi)
    local y = math.sin(theta) * math.sin(phi)
    local z = math.cos(phi)
    return { x, y, z }
end

function Noise.init(seed)
    local seedRandom
    if seed then
        -- Create a seeded pseudo-random number generator
        -- This is a very basic LCG, replace with something better if needed.
        local current_seed = seed
        local a = 1664525
        local c = 1013904223
        local m = 2 ^ 32
        seedRandom = function()
            current_seed = (a * current_seed + c) % m
            return current_seed / m
        end
    else
        seedRandom = math.random -- Use Lua's default math.random if no seed
    end

    -- Initialize permutation table with values 0..255
    for i = 0, PERMUTATION_TABLE_SIZE - 1 do
        perm[i + 1] = i
    end

    -- Shuffle permutation table using the seeded random
    for i = PERMUTATION_TABLE_SIZE, 2, -1 do
        local j = math.floor(seedRandom() * i) + 1
        perm[i], perm[j] = perm[j], perm[i]
    end

    -- Double the permutation table to avoid buffer overflow later
    -- (actually, extending to 512 by copying is more common for 256 table)
    for i = 1, PERMUTATION_TABLE_SIZE do
        perm[PERMUTATION_TABLE_SIZE + i] = perm[i]
    end

    -- Generate gradient vectors
    for i = 1, PERMUTATION_TABLE_SIZE do
        local v = randomVector(seedRandom)
        gradX[i] = v[1]
        gradY[i] = v[2]
        gradZ[i] = v[3]
    end
end

-- Dot product of gradient and distance vector
local function grad(hash, x, y, z)
    -- Convert hash to 1-based index for Lua tables
    local h = (hash % PERMUTATION_TABLE_SIZE) + 1
    return gradX[h] * x + gradY[h] * y + gradZ[h] * z
end

--- Generates 3D Perlin noise.
--- Output ranges roughly from -1 to 1.
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate (can be a seed or time for 2D animation)
--- @return number Noise value
function Noise.get(x, y, z)
    if not x or not y then
        error("Noise.get requires at least x and y arguments.")
    end
    z = z or 0 -- Default z to 0 if not provided (for 2D noise)

    -- Find unit cube that contains point
    local X = math.floor(x) % PERMUTATION_TABLE_SIZE
    local Y = math.floor(y) % PERMUTATION_TABLE_SIZE
    local Z = math.floor(z) % PERMUTATION_TABLE_SIZE
    if X < 0 then X = X + PERMUTATION_TABLE_SIZE end
    if Y < 0 then Y = Y + PERMUTATION_TABLE_SIZE end
    if Z < 0 then Z = Z + PERMUTATION_TABLE_SIZE end

    -- Find relative x,y,z of point in cube
    x = x - math.floor(x)
    y = y - math.floor(y)
    z = z - math.floor(z)

    -- Compute fade curves for each of x,y,z
    local u = fade(x)
    local v = fade(y)
    local w = fade(z)

    -- Hash coordinates of the 8 cube corners
    -- Lua tables are 1-based, so add 1 to indices
    X = X + 1
    Y = Y + 1
    Z = Z + 1

    local p = perm
    local A = p[X] + Y
    local AA = p[A] + Z
    local AB = p[A + 1] + Z
    local B = p[X + 1] + Y
    local BA = p[B] + Z
    local BB = p[B + 1] + Z

    -- Add blended results from 8 corners of cube
    local val = lerp(w,
        lerp(v,
            lerp(u, grad(p[AA], x, y, z), grad(p[BA], x - 1, y, z)),
            lerp(u, grad(p[AB], x, y - 1, z), grad(p[BB], x - 1, y - 1, z))),
        lerp(v,
            lerp(u, grad(p[AA + 1], x, y, z - 1), grad(p[BA + 1], x - 1, y, z - 1)),
            lerp(u, grad(p[AB + 1], x, y - 1, z - 1), grad(p[BB + 1], x - 1, y - 1, z - 1))))
    return val
end

-- Initialize with a default seed (e.g., os.time()) if not called manually
-- Noise.init(os.time())
-- print("Default Perlin Noise initialized.")

-- Example usage:
-- Noise.init(12345) -- Initialize with a seed
-- local value = Noise.get(0.1, 0.2, 0.3)
-- print(value)
-- local value2D = Noise.get(0.5, 0.6) -- z defaults to 0
-- print(value2D)

return Noise
