local _M = { _VERSION = 0.1 }

local gsub = string.gsub
local match = string.match
local gmatch = string.gmatch
local format = string.format
local insert = table.insert
local concat = table.concat
local loaded = package.loaded
local loadlib = package.loadlib
local preload = package.preload
local loadfile = loadfile

local load_from_path = function(name, path, loader)
    local err, pkg

    name = gsub(name, '%.', '/')
    path = gsub(path, '%?', name)

    for path in gmatch(path, '[^;]+') do
        pkg = loader(path)

        if pkg then break end

        err = err or {}
        insert(err, format("no file '%s'\n", path))
    end

    return pkg, pkg == nil and concat(err)
end

local package_loader_c = function(name, basename)
    init = 'luaopen_' .. gsub(gsub(name, '^.*%-', 1), '%.','_')
    name = basename and match(name, '^[^.]+') or name

    return load_from_path(name, package.cpath, function(path)
        return loadlib(path, init)
    end)
end

_M.loaders = {
    function(name)
        return preload[name], preload[name] == nil
            and format("no field package.preload['%s']\n", name)
    end,
    function(name)
        return load_from_path(name, package.path, loadfile)
    end,
    package_loader_c,
    function(name)
        return package_loader_c(name, true)
    end
}

local require = function(self, name)
    local errors
    for i, loader in ipairs(self.loaders) do
        local pkg, err = loader(name)

        if pkg then
            loaded[name] = pkg(name)
            return loaded[name]
        end

        errors = errors or {}
        errors[i+1] = err
    end

    errors[1] = format("module '%s' not found\n", name)

    return error(concat(errors), 2)
end

return setmetatable(_M, {
    __call = function(self, name)
        return name ~= nil and (loaded[name] or require(self, name))
    end
})

-- vim: ts=4 sw=4 et ai
