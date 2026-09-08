-- WirePlumber 0.5's smart-filter substitution also affects sink-monitor
-- capture. Keep recording/level meters on the real sink, after its volume,
-- rather than redirecting them to the hidden Redrix playback-only filter.
local linking = require("linking-utils")

SimpleEventHook {
  name = "redrix/save-monitor-target",
  after = { "linking/find-defined-target", "linking/find-filter-target",
            "linking/find-media-role-target", "linking/find-default-target",
            "linking/find-best-target" },
  before = "linking/get-filter-from-target",
  interests = { EventInterest { Constraint { "event.type", "=", "select-target" } } },
  execute = function(event)
    local _, _, si, _, _, target = linking:unwrap_select_target_event(event)
    local node = si:get_associated_proxy("node")
    if target and node.properties["stream.capture.sink"] == "true" then
      event:set_data("redrix.monitor-target", target)
    end
  end,
}:register()

SimpleEventHook {
  name = "redrix/restore-monitor-target",
  after = "linking/get-filter-from-target",
  before = "linking/prepare-link",
  interests = { EventInterest { Constraint { "event.type", "=", "select-target" } } },
  execute = function(event)
    local original = event:get_data("redrix.monitor-target")
    local current = event:get_data("target")
    if original and current and current.properties["node.name"] == "redrix_chromeos_sink" then
      event:set_data("target", original)
    end
  end,
}:register()
