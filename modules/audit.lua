local fs_utils = require("modules.fs_utils")

local audit = {}

audit.DB_ROOT = "/hdd/db/"
audit.LOGS_DIR = audit.DB_ROOT .. "logs/"
audit.AUDIT_LOG = audit.LOGS_DIR .. "audit.log"
audit.MAX_LOG_ENTRIES = 1000

local function nowISO()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

audit.nowISO = nowISO

audit.currentSession = nil

audit.setSession = function(session)
  audit.currentSession = session
end

local function trimToLimit(lines)
  local count = #lines
  if count < audit.MAX_LOG_ENTRIES then
    return lines
  end
  local keep = audit.MAX_LOG_ENTRIES - 1
  local startIndex = count - keep + 1
  local trimmed = {}
  for i = startIndex, count do
    table.insert(trimmed, lines[i])
  end
  return trimmed
end

function audit.auditLog(event_type, details)
  fs_utils.ensureDir(audit.LOGS_DIR)
  local entry = {
    ts = nowISO(),
    event_type = event_type,
    session_id = audit.currentSession and audit.currentSession.id or nil,
    user_id = audit.currentSession and audit.currentSession.user_id or nil,
    details = details or {},
  }
  local serialized = textutils.serializeJSON(entry)
  local lines = fs_utils.readLines(audit.AUDIT_LOG)
  lines = trimToLimit(lines)
  table.insert(lines, serialized)
  local ok, err = fs_utils.safeWriteLines(audit.AUDIT_LOG, lines)
  if not ok then
    return false, err
  end
  return true
end

function audit.tail(lines)
  local all = fs_utils.readLines(audit.AUDIT_LOG)
  local limit = math.max(0, lines or 10)
  local startIndex = math.max(1, #all - limit + 1)
  local out = {}
  for i = startIndex, #all do
    table.insert(out, all[i])
  end
  return out
end

function audit.clear()
  return fs_utils.safeWriteLines(audit.AUDIT_LOG, {})
end

return audit
