local hash = {}

local function makeSalt()
  return tostring(math.random(100000, 999999)) .. tostring(os.clock()):gsub("%.", "")
end

function hash.hashPassword(password)
  local salt = makeSalt()
  local digest = textutils.sha256(salt .. ":" .. password)
  return "sha256:" .. salt .. ":" .. digest
end

function hash.verifyPassword(password, stored)
  if type(stored) ~= "string" then
    return false
  end
  local algo, salt, digest = stored:match("^(.-):(.-):(.*)$")
  if algo ~= "sha256" or not salt or not digest then
    return false
  end
  local check = textutils.sha256(salt .. ":" .. password)
  return check == digest
end

return hash
