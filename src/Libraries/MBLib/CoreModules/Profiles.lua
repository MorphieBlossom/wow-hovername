local _, addon = ...

-- ===== MBLib.Profiles =====
-- Per-character profile system. The consumer's account-wide SavedVariables
-- file (e.g. MeowerData) is partitioned into three top-level buckets:
--
--   _db.Settings         -- account-wide settings (existing; untouched here)
--   _db.Account          -- account-wide consumer data (e.g. account watchers
--                            + the movers that pin them). Consumer reads /
--                            writes its own sub-tables under this freely.
--   _db.Profiles[name]   -- per-profile consumer data buckets. Same shape;
--                            consumer owns the sub-table layout.
--   _db.CharacterProfile[char] = profileName
--                          -- maps a character's "Name-Realm" key to the
--                            name of the profile it's currently bound to.
--
-- Profiles are addon-internal: a single SavedVariables file holds everything
-- and the profile dimension is layered on top. WoW's per-character SV slot
-- isn't used — it would tie a character to a profile by file location and
-- prevent sharing one profile between several characters, which is the
-- whole point of named profiles.
--
-- The consumer (Meower, etc.) declares what data lives where: it reads
-- account-only data via Profiles:GetAccount(), and active-profile data via
-- Profiles:GetActive(). Profile contents are opaque to MBLib — the only
-- shape MBLib knows is { [name] = { ...arbitrary subtables... } }.
--
-- Default profile naming: each character starts on a profile named after
-- itself (e.g. "XXX-YYY"). The consumer can request a different
-- default by registering a fallback name before the first login.

local Profiles = {}

-- Opt-in flag. Consumers that want profiles call ``MBLib.Profiles:Enable()``
-- BEFORE ``MBLib:Init`` runs (typically right after creating the addon
-- table in their loader). Consumers that don't say anything see no
-- behavior change at all — Init is a no-op, the SavedVariables shape
-- stays exactly as it was, and the public API methods bail cleanly.
-- This keeps HoverName / StatInfo / etc. from suddenly growing a
-- Profiles + CharacterProfile + Account section in their SV file.
local enabled = false

local DEFAULT_PROFILE_FALLBACK = "Default"

function Profiles:Enable()
  enabled = true
end

function Profiles:IsEnabled()
  return enabled
end

-- ===== Export compaction =====
-- Opt-in: drops schema-agnostic empties from the exported payload to
-- shrink the wire string. Specifically, string-keyed entries whose
-- value is "" or {} are pruned. Numeric-keyed entries (array slots)
-- are NEVER dropped because removing a slot would shift the indexes
-- of every later entry. Booleans and numbers are also kept verbatim
-- because MBLib has no schema knowledge — "false" or "0" may or may
-- not equal a consumer's default, and we can't tell.
--
-- Safe for any consumer that fills missing fields from defaults when
-- the data is loaded (which Meower already does in normalizeWatcher).
-- Off by default so legacy consumers see no behavior change.
local compactExport = false

function Profiles:SetExportCompact(on)
  compactExport = on and true or false
end

function Profiles:IsExportCompact()
  return compactExport
end

local function prune(v)
  if type(v) ~= "table" then return v end
  local out = {}
  local n = #v
  -- Numeric (array) run: preserve every slot, recurse into each.
  for i = 1, n do
    out[i] = prune(v[i])
  end
  -- String + sparse-numeric keys: drop entries whose pruned value
  -- collapses to "" or an empty table.
  for k, val in pairs(v) do
    local skip = (type(k) == "number" and k >= 1 and k <= n)
    if not skip then
      local pv = prune(val)
      local emptyTable = type(pv) == "table" and next(pv) == nil
      if pv ~= nil and pv ~= "" and not emptyTable then
        out[k] = pv
      end
    end
  end
  return out
end

-- ===== Transient keys =====
-- Consumers can mark sub-table keys in a profile as "transient" — those
-- keys are stripped from the payload at Export time and stripped again
-- on Import (so a payload from an older client that still has the key
-- doesn't smuggle it in). Typical use: Stats counters that are
-- character-state, not configuration, and shouldn't follow a profile
-- when it's shared with another player.
local transientKeys = {}

function Profiles:RegisterTransientKey(key)
  if type(key) == "string" and key ~= "" then
    transientKeys[key] = true
  end
end

function Profiles:IsTransientKey(key)
  return transientKeys[key] == true
end

-- Returns a shallow-cloned profile table with every registered transient
-- key dropped. Used internally by Export / Import — callers shouldn't
-- need to invoke this directly, but it's exposed for tests / debugging.
function Profiles:Sanitized(profile)
  if type(profile) ~= "table" then return profile end
  if next(transientKeys) == nil then return profile end
  local out = {}
  for k, v in pairs(profile) do
    if not transientKeys[k] then out[k] = v end
  end
  return out
end

-- ===== Storage helpers =====
local function db()
  return addon.MBLib and addon.MBLib._db or nil
end

-- Stable key for the local character. Used as both the default profile
-- name and the lookup key in CharacterProfile. ALWAYS includes the
-- realm — returning a bare name when GetNormalizedRealmName is briefly
-- empty (which it can be during the ADDON_LOADED window before realm
-- info is fully resolved) leads to the same character being bound
-- under two different keys ("Foo" and "Foo-Realm") and appearing in
-- the profiles list twice. Refusing to issue a key without the realm
-- forces callers to defer until PLAYER_LOGIN, where both fields are
-- guaranteed populated.
local function characterKey()
  local name = UnitName and UnitName("player") or ""
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
  if name == "" or realm == "" then return nil end
  return name .. "-" .. realm
end

local function ensureSchema()
  if not enabled then return nil end
  local d = db()
  if not d then return nil end
  if type(d.Profiles) ~= "table" then d.Profiles = {} end
  if type(d.CharacterProfile) ~= "table" then d.CharacterProfile = {} end
  if type(d.Account) ~= "table" then d.Account = {} end
  return d
end

-- ===== Listener lists =====
-- Consumers subscribe to OnActivated (active profile flipped on THIS
-- character) and OnProfileChanged (anything about a specific named profile
-- changed — created, renamed, imported, deleted, copied into). Callbacks
-- are pcall-wrapped so one throwing can't tank the chain.
local activatedListeners      = {}
local profileChangedListeners = {}

local function fireActivated(newName, oldName)
  for _, fn in ipairs(activatedListeners) do
    pcall(fn, newName, oldName)
  end
end

local function fireProfileChanged(name)
  for _, fn in ipairs(profileChangedListeners) do
    pcall(fn, name)
  end
end

function Profiles:OnActivated(fn)
  if type(fn) == "function" then activatedListeners[#activatedListeners + 1] = fn end
end

function Profiles:OnProfileChanged(fn)
  if type(fn) == "function" then profileChangedListeners[#profileChangedListeners + 1] = fn end
end

-- ===== Default profile fallback =====
-- Consumer can opt to override the per-character default name (the name
-- the first-time profile gets) before Init runs. Useful for addons that
-- want to ship a single "Default" profile shared by every character
-- instead of one-per-character.
function Profiles:SetDefaultName(name)
  if type(name) == "string" and name ~= "" then
    DEFAULT_PROFILE_FALLBACK = name
  end
end

-- ===== Active profile =====
function Profiles:GetActiveName()
  local d = ensureSchema()
  if not d then return nil end
  local charKey = characterKey()
  if not charKey then return nil end
  return d.CharacterProfile[charKey]
end

function Profiles:GetActive()
  local name = self:GetActiveName()
  if not name then return nil end
  local d = ensureSchema()
  if not d or not d.Profiles[name] then return nil end
  return d.Profiles[name]
end

-- Bind THIS character to the named profile. Creates an empty profile
-- by that name if it doesn't already exist (so renames / typed values
-- via the UI are forgiving). Fires OnActivated when the value actually
-- changed; bouncing to the same profile is a no-op.
function Profiles:Activate(name)
  if type(name) ~= "string" or name == "" then return false end
  local d = ensureSchema()
  if not d then return false end
  local charKey = characterKey()
  if not charKey then return false end
  local prev = d.CharacterProfile[charKey]
  if prev == name and d.Profiles[name] then return true end
  if type(d.Profiles[name]) ~= "table" then d.Profiles[name] = {} end
  d.CharacterProfile[charKey] = name
  fireActivated(name, prev)
  fireProfileChanged(name)
  return true
end

-- ===== Account bucket =====
-- Sibling to Profiles. Anything stored here is shared across every
-- character on the account and ignores the active-profile setting.
function Profiles:GetAccount()
  local d = ensureSchema()
  if not d then return nil end
  return d.Account
end

-- ===== Listing =====
function Profiles:All()
  local d = ensureSchema()
  return d and d.Profiles or {}
end

function Profiles:Names()
  local list = {}
  for n in pairs(self:All()) do list[#list + 1] = n end
  table.sort(list, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  return list
end

function Profiles:Exists(name)
  local d = ensureSchema()
  return d and d.Profiles[name] ~= nil or false
end

-- List of "Name-Realm" character keys currently bound to the named
-- profile. Sorted for stable display. The active local character will
-- be in this list if it's currently on `name`.
function Profiles:CharactersFor(name)
  local list = {}
  local d = ensureSchema()
  if not d then return list end
  for charKey, profileName in pairs(d.CharacterProfile) do
    if profileName == name then list[#list + 1] = charKey end
  end
  table.sort(list, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  return list
end

-- ===== CRUD =====

-- Deep copy that's safe for the table-only data we keep in profiles.
-- We don't need to handle cycles or metatables — profile data is plain
-- saved-variables.
local function deepCopy(src)
  if type(src) ~= "table" then return src end
  local out = {}
  for k, v in pairs(src) do out[k] = deepCopy(v) end
  return out
end

-- Create a new (empty) profile. Returns false if the name already exists
-- so the caller can surface a "name in use" error. Use Copy to seed from
-- an existing profile.
function Profiles:Create(name)
  if type(name) ~= "string" or name == "" then return false, "invalid name" end
  local d = ensureSchema()
  if not d then return false, "no db" end
  if d.Profiles[name] then return false, "exists" end
  d.Profiles[name] = {}
  fireProfileChanged(name)
  return true
end

-- Copy `srcName` into `dstName`. Returns false if dst already exists or
-- src doesn't, so the caller can show the right error message.
function Profiles:Copy(srcName, dstName)
  if type(srcName) ~= "string" or srcName == "" then return false, "invalid src" end
  if type(dstName) ~= "string" or dstName == "" then return false, "invalid dst" end
  local d = ensureSchema()
  if not d then return false, "no db" end
  if not d.Profiles[srcName] then return false, "src missing" end
  if d.Profiles[dstName] then return false, "dst exists" end
  d.Profiles[dstName] = deepCopy(d.Profiles[srcName])
  fireProfileChanged(dstName)
  return true
end

-- Delete a profile. Allowed in all states — including when it's the
-- only profile in the account AND when one or more characters are
-- still bound to it. Those characters become "profile-less" (their
-- CharacterProfile binding is cleared) and stay that way until the
-- user either activates an existing profile or creates a new one
-- from the Profiles page. Consumer code is expected to treat a nil
-- result from GetActive() as "the user has nothing selected here"
-- and gate its mutating UI accordingly.
function Profiles:Delete(name)
  local d = ensureSchema()
  if not d or not d.Profiles[name] then return false, "missing" end
  -- Snapshot the bound characters so we can fire one OnActivated event
  -- per orphaned character — listeners (Stats refresh, Watchers event
  -- subscriptions, etc.) need to know their backing store just changed.
  local orphaned = {}
  for charKey, bound in pairs(d.CharacterProfile) do
    if bound == name then table.insert(orphaned, charKey) end
  end
  d.Profiles[name] = nil
  for _, charKey in ipairs(orphaned) do
    d.CharacterProfile[charKey] = nil
  end
  -- Fire OnActivated for the local character if it was the one
  -- orphaned. Other characters won't be online to notice; their
  -- listeners will see the nil binding on next login.
  local myKey = characterKey()
  for _, charKey in ipairs(orphaned) do
    if charKey == myKey then
      fireActivated(nil, name)
      break
    end
  end
  fireProfileChanged(name)
  return true
end

-- Rename a profile in place. Updates every character binding that points
-- at the old name. No-op when newName equals oldName; fails if newName is
-- already in use by a different profile.
function Profiles:Rename(oldName, newName)
  if oldName == newName then return true end
  if type(newName) ~= "string" or newName == "" then return false, "invalid name" end
  local d = ensureSchema()
  if not d or not d.Profiles[oldName] then return false, "missing" end
  if d.Profiles[newName] then return false, "exists" end
  d.Profiles[newName] = d.Profiles[oldName]
  d.Profiles[oldName] = nil
  for charKey, bound in pairs(d.CharacterProfile) do
    if bound == oldName then d.CharacterProfile[charKey] = newName end
  end
  fireProfileChanged(newName)
  fireProfileChanged(oldName)
  return true
end

-- ===== Serialization =====
-- Profiles export to a base64-wrapped Lua table literal. We can't rely on
-- any third-party serializer being vendored (consumers may or may not ship
-- LibSerialize / AceSerializer), so MBLib writes a tiny self-contained
-- serializer and decoder. Format covers exactly what shows up in profile
-- data: nested tables with string / number keys, string / number / boolean
-- leaves. No functions, no userdata, no cycles.

local function serializeValue(v, out, indent)
  local t = type(v)
  if t == "nil" then
    out[#out + 1] = "nil"
  elseif t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "number" then
    if v ~= v then -- NaN
      out[#out + 1] = "0/0"
    elseif v == math.huge then
      out[#out + 1] = "math.huge"
    elseif v == -math.huge then
      out[#out + 1] = "-math.huge"
    else
      out[#out + 1] = tostring(v)
    end
  elseif t == "string" then
    -- %q produces a Lua-readable quoted form that handles every escape
    -- (newlines, embedded quotes, backslashes) cleanly.
    out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    local n = #v
    -- Numeric run first (ipairs-style), then sparse + string keys. Lua
    -- tables don't preserve insertion order on hash slots; we sort string
    -- keys for stable output (makes round-tripping tests reproducible).
    for i = 1, n do
      serializeValue(v[i], out, indent + 1)
      out[#out + 1] = ","
    end
    local stringKeys = {}
    for k in pairs(v) do
      if type(k) == "string" then
        stringKeys[#stringKeys + 1] = k
      elseif type(k) == "number" and (k < 1 or k > n or k ~= math.floor(k)) then
        stringKeys[#stringKeys + 1] = k
      end
    end
    table.sort(stringKeys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(stringKeys) do
      if type(k) == "string" then
        out[#out + 1] = "["
        out[#out + 1] = string.format("%q", k)
        out[#out + 1] = "]="
      else
        out[#out + 1] = "["
        out[#out + 1] = tostring(k)
        out[#out + 1] = "]="
      end
      serializeValue(v[k], out, indent + 1)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    -- Unsupported (function, userdata, thread) collapses to nil so the
    -- decoder doesn't choke. Profiles shouldn't contain these.
    out[#out + 1] = "nil"
  end
end

local function serialize(t)
  local buf = {}
  serializeValue(t, buf, 0)
  return table.concat(buf)
end

-- Decoder: load() with an empty env keeps the chunk from touching any
-- global; mode "t" rejects bytecode injection. The chunk is restricted to
-- `return <table-literal>`. On failure (parse error / wrong type) we
-- return nil and the error string so the UI can show "not a valid
-- profile" instead of throwing.
local function deserialize(s)
  if type(s) ~= "string" or s == "" then return nil, "empty payload" end
  local chunk, err
  -- WoW retail's Lua 5.2 ships `load` with the modern signature, which is
  -- what we want for the empty-env / "t" (text-only) sandbox. Some IDE
  -- emmylua stubs only know about 5.1's `loadstring`; fall back to it on
  -- clients that genuinely lack `load`.
  if type(load) == "function" then
    chunk, err = load("return " .. s, "MBLibProfile", "t", {})
  elseif type(loadstring) == "function" then
    chunk, err = loadstring("return " .. s, "MBLibProfile")
    if chunk then setfenv(chunk, {}) end
  else
    return nil, "no loader available"
  end
  if not chunk then return nil, err end
  local ok, result = pcall(chunk)
  if not ok then return nil, tostring(result) end
  if type(result) ~= "table" then return nil, "payload is not a table" end
  return result
end

-- ===== Base64 =====
-- Plain RFC 4648 alphabet. Pure Lua so MBLib stays free of native deps.
-- We pad with "=" so the decoded length is unambiguous on round-trip.
local B64_ALPHABET =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_DECODE = {}
for i = 1, #B64_ALPHABET do
  B64_DECODE[B64_ALPHABET:sub(i, i)] = i - 1
end

local function base64Encode(s)
  local buf = {}
  local len = #s
  local i = 1
  while i <= len do
    local a = s:byte(i)
    local b = i + 1 <= len and s:byte(i + 1) or nil
    local c = i + 2 <= len and s:byte(i + 2) or nil
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    buf[#buf + 1] = B64_ALPHABET:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
    buf[#buf + 1] = B64_ALPHABET:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
    if b then
      buf[#buf + 1] = B64_ALPHABET:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
    else
      buf[#buf + 1] = "="
    end
    if c then
      buf[#buf + 1] = B64_ALPHABET:sub(n % 64 + 1, n % 64 + 1)
    else
      buf[#buf + 1] = "="
    end
    i = i + 3
  end
  return table.concat(buf)
end

local function base64Decode(s)
  if type(s) ~= "string" then return nil, "not a string" end
  -- Strip all whitespace (newlines from copy-paste are common).
  s = s:gsub("%s+", "")
  if s == "" then return nil, "empty" end
  if #s % 4 ~= 0 then return nil, "bad length" end
  local buf = {}
  local i = 1
  while i <= #s do
    local c1 = s:sub(i, i)
    local c2 = s:sub(i + 1, i + 1)
    local c3 = s:sub(i + 2, i + 2)
    local c4 = s:sub(i + 3, i + 3)
    local v1 = B64_DECODE[c1]
    local v2 = B64_DECODE[c2]
    local v3 = c3 == "=" and 0 or B64_DECODE[c3]
    local v4 = c4 == "=" and 0 or B64_DECODE[c4]
    if not v1 or not v2 or v3 == nil or v4 == nil then
      return nil, "invalid base64 character"
    end
    local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
    buf[#buf + 1] = string.char(math.floor(n / 65536) % 256)
    if c3 ~= "=" then buf[#buf + 1] = string.char(math.floor(n / 256) % 256) end
    if c4 ~= "=" then buf[#buf + 1] = string.char(n % 256) end
    i = i + 4
  end
  return table.concat(buf)
end

-- Sanity check the result of a base64 decode against the expected
-- profile envelope shape. Returns true if it looks like a profile or a
-- single watcher (the consumer surface for this is also "import a thing
-- that came out of a sibling Export call").
local function looksLikeEnvelope(t)
  if type(t) ~= "table" then return false end
  return type(t.kind) == "string" and (t.payload ~= nil)
end

-- Envelope wraps the actual payload with a small header so we can tell
-- "this is a profile" vs "this is a single watcher" on import without
-- the caller having to pre-classify. `version` lets us evolve the
-- payload shape later and reject older / newer dumps cleanly.
local ENVELOPE_VERSION = 1

function Profiles:Export(name)
  local d = ensureSchema()
  if not d or not d.Profiles[name] then return nil, "missing profile" end
  -- Strip any consumer-registered transient keys (e.g. Stats) before
  -- encoding — those represent character state, not configuration,
  -- and shouldn't follow the profile to another character / player.
  local payload = self:Sanitized(d.Profiles[name])
  -- Optional schema-agnostic prune: drop "" / {} sub-fields so the
  -- wire string isn't bloated with default-shaped empties. Consumer
  -- must opt in via SetExportCompact (Meower does so in its Init).
  if compactExport then payload = prune(payload) end
  local envelope = {
    kind    = "MBLibProfile",
    version = ENVELOPE_VERSION,
    name    = name,
    payload = payload,
  }
  return base64Encode(serialize(envelope))
end

-- Wrap an arbitrary payload in the same envelope shape, so consumers
-- that want to export sub-units (e.g. a single watcher) can ride the
-- same import path. `kind` is consumer-defined; MBLib only enforces
-- that it's a non-empty string.
function Profiles:WrapForExport(kind, payload, extra)
  if type(kind) ~= "string" or kind == "" then return nil end
  if compactExport then payload = prune(payload) end
  local envelope = {
    kind    = kind,
    version = ENVELOPE_VERSION,
    payload = payload,
  }
  if type(extra) == "table" then
    for k, v in pairs(extra) do
      if envelope[k] == nil then envelope[k] = v end
    end
  end
  return base64Encode(serialize(envelope))
end

-- Decode + validate an envelope WITHOUT touching SavedVariables. Returns
-- the envelope table on success; nil + error message on failure. Use
-- this from the Import dialog to surface "not a valid profile" before
-- offering a save button.
function Profiles:UnwrapImport(base64)
  local raw, decodeErr = base64Decode(base64)
  if not raw then return nil, decodeErr end
  local envelope, parseErr = deserialize(raw)
  if not envelope then return nil, parseErr end
  if not looksLikeEnvelope(envelope) then return nil, "not a profile envelope" end
  if envelope.version ~= ENVELOPE_VERSION then
    return nil, "unsupported version " .. tostring(envelope.version)
  end
  return envelope
end

-- Decode a profile envelope and add it under `assignName` (overriding
-- the embedded name). Fails on duplicate name unless `overwrite` is true.
-- Doesn't activate the profile — the caller decides whether to flip the
-- character over after import.
function Profiles:Import(base64, assignName, overwrite)
  local envelope, err = self:UnwrapImport(base64)
  if not envelope then return false, err end
  if envelope.kind ~= "MBLibProfile" then
    return false, "envelope is not a profile (kind=" .. tostring(envelope.kind) .. ")"
  end
  local d = ensureSchema()
  if not d then return false, "no db" end
  local name = assignName or envelope.name
  if type(name) ~= "string" or name == "" then return false, "no target name" end
  if d.Profiles[name] and not overwrite then return false, "exists" end
  -- Strip transient keys on import too, so a payload from an older
  -- client (or a hand-edited one) can't smuggle Stats / other
  -- character-state into the receiving account.
  d.Profiles[name] = self:Sanitized(deepCopy(envelope.payload) or {}) or {}
  fireProfileChanged(name)
  return true, name
end

-- ===== Init =====
-- Repairs any "bare name" CharacterProfile bindings written by a build
-- that resolved characterKey() too early (when GetNormalizedRealmName
-- briefly returned ""). If a bare-name entry exists AND the new
-- realm-suffixed key for the same character isn't already bound, copy
-- the binding over and drop the bare-name slot. If both exist, the
-- realm-suffixed one wins and the bare-name slot is dropped without
-- overwriting. Run every Init pass — cheap, idempotent.
local function repairBareNameBindings(d, charKey)
  if not d or not charKey then return end
  local namePart = charKey:match("^([^-]+)") or charKey
  local bareBound = d.CharacterProfile[namePart]
  if not bareBound or namePart == charKey then return end
  if d.CharacterProfile[charKey] == nil then
    d.CharacterProfile[charKey] = bareBound
  end
  d.CharacterProfile[namePart] = nil
end

local function tryInit()
  if not enabled then return false end
  local d = ensureSchema()
  if not d then return false end
  local charKey = characterKey()
  if not charKey then return false end

  repairBareNameBindings(d, charKey)

  -- Default profile name: always the character key ("XXX-YYY"). One
  -- profile per character by default; if the consumer overrode with
  -- SetDefaultName before Init, honor that for the FIRST profile only
  -- (subsequent characters still seed under their own character key so
  -- the per-character-default UX is consistent).
  local activeName = d.CharacterProfile[charKey]
  if not activeName then
    activeName = charKey
    if next(d.Profiles) == nil and DEFAULT_PROFILE_FALLBACK ~= "Default" then
      activeName = DEFAULT_PROFILE_FALLBACK
    end
  end
  if type(d.Profiles[activeName]) ~= "table" then
    d.Profiles[activeName] = {}
  end
  d.CharacterProfile[charKey] = activeName
  return true
end

function Profiles:Init()
  -- Opt-in. Consumers that don't enable profiles get the historical
  -- behavior — no Profiles / CharacterProfile / Account keys added to
  -- their SavedVariables file, no API side effects.
  if not enabled then return end
  if tryInit() then return end

  -- characterKey() returned nil — realm info isn't resolved yet
  -- (ADDON_LOADED can fire before GetNormalizedRealmName is ready).
  -- Retry on PLAYER_LOGIN, by which point both name and realm are
  -- guaranteed populated.
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    tryInit()
    -- Notify listeners (Watchers, Stats panels, etc.) that their
    -- backing store is now resolvable. Without this they keep
    -- pointing at the empty fallback list from the early-init
    -- window.
    fireActivated(Profiles:GetActiveName(), nil)
    self:UnregisterEvent("PLAYER_LOGIN")
    self:SetScript("OnEvent", nil)
  end)
end

addon.MBLib.Profiles = Profiles
