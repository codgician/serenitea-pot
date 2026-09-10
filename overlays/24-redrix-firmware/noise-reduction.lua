-- RTNR is a firmware control, not a capture-volume control. Keep its lifetime
-- tied to the physical Mic1 node, and let WirePlumber's persistent Settings
-- store be the only source of the desired value.
local args = ...
local config = args:parse(1)
local node_name = assert(config["node.name"], "missing node.name")
local card_name = assert(config["alsa.card"], "missing alsa.card")
local setting_name = "redrix.noise-reduction"
local control_name = "RTNR10.0 rtnr_enable_10"
local control_property = "api.alsa.bind-ctl." .. control_name
local card_path_prefix = "alsa:acp:" .. card_name .. ":"
local card_path_suffix = ":capture"
local log = Log.open_topic("s-redrix-noise-reduction")

local mic_nodes = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "=", node_name },
  },
}

local generation = 0
local queued = false
local syncing = false

local function is_target_node(node)
  local path = node.properties["object.path"]
  return type(path) == "string" and
      path:sub(1, #card_path_prefix) == card_path_prefix and
      path:sub(-#card_path_suffix) == card_path_suffix
end

local function get_bound_control(iterator, state)
  for param in iterator, state do
    local parsed = param:parse()
    if parsed and parsed.pod_type == "Object" and parsed.object_id == "Props" and parsed.properties then
      local params = parsed.properties.params
      if params and params.pod_type == "Struct" then
        for index = 1, #params - 1, 2 do
          if params[index] == control_property then
            return params[index + 1], true
          end
        end
      end
    end
  end
  return nil, false
end

local function log_missing_control(node)
  log:warning(node, "RTNR control is not bound on Mic1; check api.alsa.bind-ctls")
end

local apply_current

local function queue_apply()
  if queued or syncing then
    return
  end
  queued = true
  Core.idle_add(function()
    queued = false
    apply_current()
    return false
  end)
end

local function request_apply()
  generation = generation + 1
  queue_apply()
end

local function verify_current(enabled, applied_generation)
  for node in mic_nodes:iterate() do
    if is_target_node(node) then
      -- Core.sync acknowledges the write, not the later ALSA event/cache update.
      -- Query fresh server parameters instead of comparing the stale WP cache.
      node:enum_params("Props", function(params, error)
        if generation ~= applied_generation then return end
        if error then
          log:warning(node, "Cannot verify RTNR control: " .. tostring(error))
          return
        end
        local current, bound = get_bound_control(params:iterate())
        if not bound then
          log_missing_control(node)
        elseif current ~= enabled then
          log:warning(node, "RTNR control did not reach the requested setting")
        end
      end)
    end
  end
end

apply_current = function()
  if syncing then
    return
  end

  local applied_generation = generation
  local enabled = Settings.get_boolean(setting_name)
  local wrote = false

  for node in mic_nodes:iterate() do
    if not is_target_node(node) then
      log:warning(node, "Mic1 node does not belong to ALSA card " .. card_name)
    else
      local _, bound = get_bound_control(node:iterate_params("Props"))
      if not bound then
        log_missing_control(node)
      else
        node:set_param("Props", Pod.Object {
          "Spa:Pod:Object:Param:Props", "Props",
          params = Pod.Struct { control_property, enabled },
        })
        wrote = true
      end
    end
  end

  if not wrote then
    return
  end

  syncing = true
  Core.sync(function(error)
    syncing = false
    if error then
      log:warning("RTNR update failed: " .. tostring(error))
    elseif generation == applied_generation then
      verify_current(enabled, applied_generation)
    end
    if generation ~= applied_generation then
      queue_apply()
    end
  end)
end

mic_nodes:connect("object-added", function()
  request_apply()
end)
mic_nodes:activate()

Settings.subscribe(setting_name, request_apply)
request_apply()
