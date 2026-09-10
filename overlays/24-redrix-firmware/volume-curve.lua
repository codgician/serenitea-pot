-- ChromeOS scales Speaker playback in software, after the CRAS DSP, through
-- the explicit [Speaker] curve in /etc/cras/redrix/sof-rt5682.card_settings.
-- PipeWire's Speaker sink has no mixer element either, but its slider is the
-- plain cubic pipewire-pulse mapping: 20% is -42 dB where ChromeOS is -27 dB.
-- Map the slider through the ChromeOS curve by overriding the sink's soft
-- volumes; the requested channelVolumes stay untouched, so desktop controls
-- keep showing the slider position. The sink applies volume after the Redrix
-- filter, matching the CRAS order. Above 100% the curve is undefined and
-- PipeWire's own gain continues from 0 dB.
local args = ...
local node_name = args:parse(1)["node.name"]

-- dB * 100 at slider positions 0..100, generated from card_settings.
local curve = @speakerCurve@

local function curve_gain(linear)
  if linear <= 0 then
    return 0
  end
  local position = 100 * linear ^ (1 / 3)
  if position >= 100 then
    return linear
  end
  local step = math.floor(position)
  local frac = position - step
  local db = (curve[step] * (1 - frac) + curve[step + 1] * frac) / 100
  return 10 ^ (db / 20)
end

local function apply(node)
  for param in node:iterate_params("Props") do
    local parsed = param:parse()
    if parsed.pod_type == "Object" and parsed.object_id == "Props" then
      local volumes = parsed.properties.channelVolumes
      if not volumes then
        return
      end
      local soft = parsed.properties.softVolumes or {}
      local target = { "Spa:Float" }
      local changed = false
      for i, v in ipairs(volumes) do
        local gain = curve_gain(v)
        target[i + 1] = gain
        if soft[i] == nil or math.abs(soft[i] - gain) > 1e-6 then
          changed = true
        end
      end
      if changed then
        node:set_param("Props", Pod.Object {
          "Spa:Pod:Object:Param:Props", "Props",
          softVolumes = Pod.Array(target),
        })
      end
      return
    end
  end
end

SimpleEventHook {
  name = "redrix/speaker-volume-curve",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-params-changed" },
      Constraint { "event.subject.param-id", "=", "Props" },
      Constraint { "node.name", "=", node_name },
    },
    EventInterest {
      Constraint { "event.type", "=", "node-added" },
      Constraint { "node.name", "=", node_name },
    },
  },
  execute = function(event)
    apply(event:get_subject())
  end,
}:register()
