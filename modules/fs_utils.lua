local fs_utils = {}

local function ensureDir(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

function fs_utils.ensureDir(path)
  ensureDir(path)
end

function fs_utils.readAll(path)
  local file = fs.open(path, "r")
  if not file then
    return nil, "open failed"
  end
  local content = file.readAll()
  file.close()
  return content
end

function fs_utils.readJSON(path)
  local content, err = fs_utils.readAll(path)
  if not content then
    return nil, err
  end
  local ok, data = pcall(textutils.unserializeJSON, content)
  if not ok then
    return nil, "invalid json"
  end
  return data
end

function fs_utils.writeJSONAtomic(path, tbl, opts)
  local options = opts or {}
  local serialized = textutils.serializeJSON(tbl, options.pretty or false)
  local tmpPath = path .. ".tmp"
  local file = fs.open(tmpPath, "w")
  if not file then
    return false, "open failed"
  end
  file.write(serialized)
  if file.flush then
    file.flush()
  end
  file.close()
  local ok, moveErr = pcall(fs.move, tmpPath, path)
  if not ok then
    if fs.exists(tmpPath) then
      fs.delete(tmpPath)
    end
    return false, moveErr or "move failed"
  end
  if options.verify then
    local check = fs_utils.readJSON(path)
    if not check then
      return false, "verification failed"
    end
  end
  return true
end

function fs_utils.safeWriteLines(path, lines)
  local tmpPath = path .. ".tmp"
  local file = fs.open(tmpPath, "w")
  if not file then
    return false, "open failed"
  end
  for _, line in ipairs(lines) do
    file.write(line)
    file.write("\n")
  end
  if file.flush then
    file.flush()
  end
  file.close()
  local ok, moveErr = pcall(fs.move, tmpPath, path)
  if not ok then
    if fs.exists(tmpPath) then
      fs.delete(tmpPath)
    end
    return false, moveErr or "move failed"
  end
  return true
end

function fs_utils.readLines(path)
  if not fs.exists(path) then
    return {}
  end
  local file = fs.open(path, "r")
  if not file then
    return {}
  end
  local lines = {}
  while true do
    local line = file.readLine()
    if not line then
      break
    end
    table.insert(lines, line)
  end
  file.close()
  return lines
end

function fs_utils.ensureTree(paths)
  for _, path in ipairs(paths) do
    ensureDir(path)
  end
end

return fs_utils
