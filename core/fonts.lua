local M = {}

M.MIN_SIZE = 9
M.MAX_SIZE = 28

M.families = {
    { key = "regular", label = "Regular", sizes = {
        [9] = 78,
        [10] = 70,
        [11] = 206,
        [12] = 207,
        [13] = 208,
        [14] = 209,
        [15] = 210,
        [16] = 211,
        [17] = 212,
        [18] = 213,
        [19] = 214,
        [20] = 215,
        [21] = 216,
        [22] = 217,
        [23] = 218,
        [24] = 219,
        [25] = 220,
        [26] = 221,
        [27] = 222,
        [28] = 223,
    } },
    { key = "semibold", label = "Semibold", sizes = {
        [10] = 270,
        [11] = 271,
        [12] = 17,
        [13] = 41,
        [14] = 272,
        [15] = 65,
        [16] = 273,
        [17] = 274,
        [18] = 275,
        [19] = 276,
        [20] = 277,
        [21] = 278,
        [22] = 279,
        [23] = 280,
        [24] = 281,
        [25] = 282,
        [26] = 283,
        [27] = 284,
        [28] = 285,
    } },
    { key = "bold", label = "Bold", sizes = {
        [10] = 77,
        [11] = 166,
        [12] = 167,
        [13] = 168,
        [14] = 169,
        [15] = 170,
        [16] = 171,
        [17] = 172,
        [18] = 173,
        [19] = 174,
        [20] = 175,
        [21] = 176,
        [22] = 177,
        [23] = 178,
        [24] = 179,
        [25] = 180,
        [26] = 181,
        [27] = 182,
        [28] = 183,
    } },
}

function M.indexOf(key)
    for index, family in ipairs(M.families) do
        if family.key == key then
            return index
        end
    end

    return 1
end

function M.keyAt(index)
    local family = M.families[index]

    if family == nil then
        return M.families[1].key
    end

    return family.key
end

function M.byKey(key)
    for _, family in ipairs(M.families) do
        if family.key == key then
            return family
        end
    end

    return M.families[1]
end

function M.resolve(key, size)
    local family = M.byKey(key)
    local wanted = math.max(M.MIN_SIZE, math.min(M.MAX_SIZE, math.floor(size)))

    for step = 0, M.MAX_SIZE - M.MIN_SIZE do
        local below = wanted - step
        local above = wanted + step

        if family.sizes[below] ~= nil then
            return family.sizes[below]
        end

        if family.sizes[above] ~= nil then
            return family.sizes[above]
        end
    end

    return id.Font.NOTOSANS_BOLD_12
end

return M
