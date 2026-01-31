-- rewritte the code to be better (some day)
local options = {}
local long_options = {}

local module = {
    options = options,
    long_options = long_options
}

local function handle_opt(opts, Arg)
    local optL = #opts
    for i = 1, optL do
        local optN = opts:sub(i, i)
        options[optN](i == optL and Arg)
    end
end

function module.doOptions(arg)
    for optI, optN in ipairs(arg) do
        if optN:sub(1, 1) == "-" then
            local Arg = arg[optI + 1]
            local carg = (Arg and Arg or "-"):sub(1, 1) ~= "-" and Arg
            if carg then
                table.remove(arg, optI + 1)
            end
            
            if optN:sub(2, 2) == "-" then
                long_options[optN](carg)
            else
                handle_opt(optN:sub(2, -1), carg)
            end
        end
    end
end

return module