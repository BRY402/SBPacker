-- @scriptdef: module
local error = error
local f = string.format
local next = next
local table_concat = table.concat
local tostring = tostring
local type = type

local SBPack = {
    sources = {
        init = "",
        beforeBuild = ""
    },
    sourcecontainers = {
        module = {},
        script = {}
    }
}


function SBPack:setInit(code)
    if type(code) ~= "string" then
        error("Invalid initialization source, expected string", 2)
    end
    
    SBPack.sources.init = code
end

function SBPack:beforeBuild(code)
    if type(code) ~= "string" then
        error("Invalid source for start of build, expected string", 2)
    end
    
    SBPack.sources.beforeBuild = code
end


function SBPack:clear(containerName)
    if not containerName then
        for i, _ in next, self.sourcecontainers do
            self.sourcecontainers[i] = {}
        end
        
        return
    end
    
    if self.sourcecontainers[tostring(containerName)] then
        self.sourcecontainers[tostring(containerName)] = {}
    end
end

function SBPack:generate()
    local src = {
        [[
local coroutine = coroutine
local sb_package = {preload = {}}
local print = print

local require = (function(_ENV)
    local unpack = unpack or table.unpack
    local loaded = {}
    sb_package.loaded = setmetatable({}, {__index = loaded})

    return function(modname, args)
        local res = loaded[modname]
        if res then
            return res
        end

        local mod = sb_package.preload[modname]
        if mod then
            local args = type(args) == "table" and args or {args}
            loaded[modname] = mod(setmetatable({}, {__index = _ENV}), modname, unpack(args))
        else
            loaded[modname] = require(modname) --!
        end

        return loaded[modname]
    end
end)(_ENV or getfenv())
]],
        SBPack.sources.beforeBuild
    }
    
    for _, container in next, SBPack.sourcecontainers do
        for _, source in next, container do
            src[#src + 1] = source
        end
    end
    
    src[#src + 1] = SBPack.sources.init
    
    return table_concat(src, "\n")
end

function SBPack:createContainer(Name)
    local Name = tostring(Name)
    local container = self.sourcecontainers[Name] or {}
    self.sourcecontainers[Name] = container
    
    return container
end
function SBPack:addSourceContainer(Type, Name, Source)
    if type(Source) ~= "string" then
        error("Invalid module source, expected string", 2)
    end
    
    self.sourcecontainers[tostring(Type)][tostring(Name)] = f([[
sb_package.preload[%q] = function(_ENV, ...)
    %s
end
]], tostring(Name), Source)
end

function SBPack:addMod(modname, Source)
    SBPack:addSourceContainer("module", modname, f([[
    local function mod(_ENV, ...)
%s
    end
    if setfenv then
        setfenv(mod, _ENV)
    end

    return mod(_ENV, ...)
]], Source))
end

function SBPack:addScript(scriptname, Source)
    SBPack:addSourceContainer("script", scriptname, f([[
    local function mod(_ENV, ...)
%s
    end
    if setfenv then
        setfenv(mod, _ENV)
    end
        
    local thread = coroutine.create(mod)
    local success, result = coroutine.resume(thread, _ENV, ...)

    if not success then
        print(result)
        return
    end

    return result
]], Source))
end

function SBPack:removeMod(modname)
    self.sourcecontainers.module[tostring(modname)] = nil
end

function SBPack:removeScript(scriptname)
    self.sourcecontainers.script[tostring(scriptname)] = nil
end

function SBPack:hasSourceContainer(name)
    for _, container in next, self.sourcecontainers do
        if container[tostring(name)] ~= nil then
            return true
        end
    end
end


return SBPack