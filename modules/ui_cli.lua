local ui_cli = {}

function ui_cli.renderTable(rows, columns)
  local widths = {}
  for _, col in ipairs(columns) do
    widths[col.key] = #col.label
  end
  for _, row in ipairs(rows) do
    for _, col in ipairs(columns) do
      local val = tostring(row[col.key] or "")
      if #val > widths[col.key] then
        widths[col.key] = #val
      end
    end
  end
  local function formatValue(value, width)
    local str = tostring(value)
    if #str > width then
      return str:sub(1, width - 3) .. "..."
    end
    return str .. string.rep(" ", width - #str)
  end
  local header = {}
  for _, col in ipairs(columns) do
    table.insert(header, formatValue(col.label, widths[col.key]))
  end
  print(table.concat(header, "  "))
  for _, row in ipairs(rows) do
    local line = {}
    for _, col in ipairs(columns) do
      table.insert(line, formatValue(row[col.key] or "", widths[col.key]))
    end
    print(table.concat(line, "  "))
  end
end

function ui_cli.cliHelp(subject)
  if not subject then
    print("Uso: usuario <sujeto> <verbo> [args] [flags]")
    print("Sujetos: user, role, session, audit, system")
    print("Ejemplos:")
    print("  user add <id> [--role R] [--meta '{\"name\":\"Ana\"}']")
    print("  user list [--json] [--limit N]")
    print("  role create <id> --permissions '<json>'")
    return
  end
  if subject == "user" then
    print("user add|list|show|delete|edit")
  elseif subject == "role" then
    print("role create|list|assign|revoke")
  elseif subject == "session" then
    print("session status|login|logout")
  elseif subject == "audit" then
    print("audit tail|clear")
  elseif subject == "system" then
    print("system shutdown|help")
  else
    print("Sujeto desconocido")
  end
end

function ui_cli.parseArgs(argv)
  local args = { unpack(argv) }
  local flags = {}
  local positionals = {}
  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--help" or arg == "-h" then
      flags.help = true
    elseif arg == "--json" then
      flags.json = true
    elseif arg == "--pretty" then
      flags.pretty = true
    elseif arg == "--force" or arg == "-f" then
      flags.force = true
    elseif arg == "--version" or arg == "-v" then
      flags.version = true
    elseif arg == "--limit" then
      i = i + 1
      flags.limit = tonumber(args[i])
    elseif arg == "--page" then
      i = i + 1
      flags.page = tonumber(args[i])
    else
      table.insert(positionals, arg)
    end
    i = i + 1
  end
  return positionals, flags
end

function ui_cli.jsonResult(ok, payload, code)
  local out = {
    ok = ok,
    code = code or (ok and 0 or 1),
  }
  if ok then
    out.result = payload
  else
    out.error = payload
  end
  return textutils.serializeJSON(out)
end

return ui_cli
