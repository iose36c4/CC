local fs_utils = require("modules.fs_utils")
local hash = require("modules.hash")
local audit = require("modules.audit")

local auth = {}

auth.DB_ROOT = "/hdd/db/"
auth.USERS_DIR = auth.DB_ROOT .. "users/"
auth.SESSIONS_DIR = auth.DB_ROOT .. "sessions/"
auth.CURRENT_SESSION = auth.SESSIONS_DIR .. "current.json"

local function nowISO()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function auth.captureCredentials(prompt_user, prompt_pass)
  write(prompt_user or "Usuario: ")
  local user = read()
  write(prompt_pass or "Password: ")
  local pass = read("*")
  return user, pass
end

local function loadUser(user_id)
  local path = auth.USERS_DIR .. user_id .. ".json"
  return fs_utils.readJSON(path)
end

function auth.loginFlow(max_attempts, lockout_seconds)
  local attempts = 0
  local maxA = max_attempts or 3
  local lockout = lockout_seconds or 5
  while attempts < maxA do
    local user, pass = auth.captureCredentials("Usuario: ", "Password: ")
    local userData = loadUser(user)
    if userData and hash.verifyPassword(pass, userData.password_hash or "") then
      local session = {
        id = tostring(os.epoch("utc")) .. "-" .. tostring(math.random(1000, 9999)),
        user_id = user,
        created_at = nowISO(),
        active_role = userData.roles and userData.roles[1] or nil,
      }
      fs_utils.ensureDir(auth.SESSIONS_DIR)
      local ok, err = fs_utils.writeJSONAtomic(auth.CURRENT_SESSION, session, { verify = true })
      if not ok then
        return nil, err
      end
      audit.setSession(session)
      audit.auditLog("login", { user = user })
      return session.id
    end
    attempts = attempts + 1
    audit.auditLog("login_failed", { user = user })
    if attempts < maxA then
      sleep(lockout)
    end
  end
  return nil, "max_attempts"
end

function auth.logoutFlow()
  if fs.exists(auth.CURRENT_SESSION) then
    local session = fs_utils.readJSON(auth.CURRENT_SESSION)
    fs.delete(auth.CURRENT_SESSION)
    audit.setSession(nil)
    audit.auditLog("logout", { user = session and session.user_id or nil })
  end
  return true
end

function auth.loadCurrentSession()
  if fs.exists(auth.CURRENT_SESSION) then
    return fs_utils.readJSON(auth.CURRENT_SESSION)
  end
  return nil
end

return auth
