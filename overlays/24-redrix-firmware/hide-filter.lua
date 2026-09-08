-- Hide implementation nodes from desktop volume controllers, not playback
-- clients. PipeWire requires playback clients to be able to see their linked
-- nodes, even when WirePlumber transparently inserts a smart filter.
local clients = ObjectManager { Interest { type = "client" } }
local nodes = ObjectManager { Interest { type = "node" } }

local function is_controller(client)
  local p = client.properties
  return p["client.api"] == "pipewire-pulse" and (
    p["application.id"] == "org.kde.plasma-pa" or
    p["application.id"] == "org.kde.kded6" or
    p["application.id"] == "org.kde.systemsettings" or
    p["media.category"] == "Manager" or
    p["application.name"] == "pactl" or
    p["application.name"] == "pavucontrol")
end

local function hide(client, node)
  local name = node.properties["node.name"]
  if is_controller(client) and
      (name == "redrix_chromeos_sink" or name == "redrix_chromeos_output") then
    client:update_permissions { [node["bound-id"]] = "-" }
  end
end

clients:connect("object-added", function (_, client)
  for node in nodes:iterate() do hide(client, node) end
end)
nodes:connect("object-added", function (_, node)
  for client in clients:iterate() do hide(client, node) end
end)

nodes:activate()
clients:activate()
