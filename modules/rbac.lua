local fs_utils = require("modules.fs_utils")
local audit = require("modules.audit")

local rbac = {}

rbac.DB_ROOT = "/hdd/db/"
rbac.USERS_DIR = rbac.DB_ROOT .. "users/"
rbac.ROLES_DIR = rbac.DB_ROOT .. "roles/"

local function loadRole(role_id)
  local path = rbac.ROLES_DIR .. role_id .. ".json"
  return fs_utils.readJSON(path)
end

local function isPrefixPermission(permObj, obj)
  if permObj == "*" then
    return true
  end
  if permObj == obj then
    return true
  end
  return obj:sub(1, #permObj) == permObj
end

local function topoSort(roles)
  local order = {}
  local state = {}
  local function visit(role_id)
    if state[role_id] == "grey" then
      return false, "cycle"
    end
    if state[role_id] == "black" then
      return true
    end
    state[role_id] = "grey"
    local role = roles[role_id]
    local inherits = role and role.inherits or {}
    for _, parent in ipairs(inherits) do
      if roles[parent] then
        local ok, err = visit(parent)
        if not ok then
          return false, err
        end
      end
    end
    state[role_id] = "black"
    table.insert(order, role_id)
    return true
  end
  for role_id, _ in pairs(roles) do
    local ok, err = visit(role_id)
    if not ok then
      return nil, err
    end
  end
  return order
end

function rbac.resolveEffectivePermissions(roles_list)
  local roles = {}
  for _, role_id in ipairs(roles_list or {}) do
    local roleData = loadRole(role_id)
    if roleData then
      roles[role_id] = roleData
    end
  end
  local order, err = topoSort(roles)
  if not order then
    return nil, err
  end
  local seen = {}
  local permissions = {}
  for _, role_id in ipairs(order) do
    local role = roles[role_id]
    local perms = role.permissions or {}
    for _, perm in ipairs(perms) do
      local key = (perm.effect or "allow") .. ":" .. (perm.obj or "") .. ":" .. (perm.op or "") .. ":" .. (perm.scope or "")
      if not seen[key] then
        seen[key] = true
        table.insert(permissions, perm)
      end
    end
  end
  return permissions
end

local function loadUser(user_id)
  local path = rbac.USERS_DIR .. user_id .. ".json"
  return fs_utils.readJSON(path)
end

local function loadResourceMeta(obj, resource_id)
  if obj == "user" then
    return loadUser(resource_id)
  end
  local path = rbac.DB_ROOT .. obj .. "/" .. resource_id .. ".json"
  if fs.exists(path) then
    return fs_utils.readJSON(path)
  end
  local generic = rbac.DB_ROOT .. "resources/" .. obj .. "/" .. resource_id .. ".json"
  if fs.exists(generic) then
    return fs_utils.readJSON(generic)
  end
  return nil
end

function rbac.denyAccess(user_id, operacion, objeto, recurso_id_opt, session_opt)
  local user = loadUser(user_id)
  if not user then
    return true, "user not found"
  end
  local roles = user.roles or {}
  local perms, err = rbac.resolveEffectivePermissions(roles)
  if not perms then
    return true, err
  end
  local allowed = false
  local denyReason = "no matching permissions"
  for _, perm in ipairs(perms) do
    local objMatch = perm.obj and isPrefixPermission(perm.obj, objeto)
    local opMatch = perm.op == operacion or perm.op == "*"
    if objMatch and opMatch then
      local scope = perm.scope or "global"
      if scope == "global" then
        if perm.effect == "deny" then
          audit.auditLog("access_denied", { user = user_id, obj = objeto, op = operacion })
          return true, "deny rule"
        end
        allowed = true
      elseif scope == "propio" then
        if not recurso_id_opt then
          denyReason = "missing resource"
        else
          local resource = loadResourceMeta(objeto, recurso_id_opt)
          if resource and resource.owner == user_id then
            if perm.effect == "deny" then
              audit.auditLog("access_denied", { user = user_id, obj = objeto, op = operacion })
              return true, "deny rule"
            end
            allowed = true
          else
            denyReason = "resource not owned"
          end
        end
      end
    end
  end
  if allowed then
    return false, nil
  end
  audit.auditLog("access_denied", { user = user_id, obj = objeto, op = operacion, reason = denyReason })
  return true, denyReason
end

function rbac.hasPermission(user_id, operacion, objeto, recurso_id_opt, session_opt)
  local denied = rbac.denyAccess(user_id, operacion, objeto, recurso_id_opt, session_opt)
  return not denied
end

return rbac
