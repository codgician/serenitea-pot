"""Exercise device-owned graphs on ALSA file/null PCMs; never open hardware."""

import array
import json
import math
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import threading
import time


PIPEWIRE, LADSPA, GRAPHS = sys.argv[1:]
GRAPHS = json.loads(Path(GRAPHS).read_text())
RATE = 48000
INPUT = 6553 / 32768
# Use the unchanged speaker gain stage for exact adapter lifecycle assertions;
# the production APM graph is exercised separately with voiced input below.
VOLUME_GRAPH = dict(GRAPHS["speaker"])
VOLUME_GRAPH.update(nodes=[VOLUME_GRAPH["nodes"][-1]], links=[],
                    inputs=["gain:Input Left", "gain:Input Right"])
SAVED_GAIN = 10 ** (-13.5 / 20)


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


with tempfile.TemporaryDirectory(prefix="redrix-graphs-") as directory:
    root = Path(directory)
    # A null PCM may skip/read faster than the delivered graph rate. A finite
    # infile can hit EOF and leave unrelated silence/garbage in this fixture.
    # Feed a bounded FIFO continuously instead; no physical device is opened.
    os.mkfifo(root / "input.raw")
    feeder_fd = os.open(root / "input.raw", os.O_RDWR | os.O_NONBLOCK)
    finish_feeding = threading.Event()
    chunk = (array.array("i", [6553 << 16]) * 1024).tobytes()

    def feed():
        data = memoryview(chunk)
        previous = chunk
        offset = 0
        while not finish_feeding.is_set():
            if select.select([], [feeder_fd], [], 0.1)[1]:
                try:
                    if chunk is not previous:
                        previous = chunk
                        data = memoryview(chunk)
                        offset = 0
                    written = os.write(feeder_fd, data[offset:offset + 4096])
                    offset = (offset + written) % len(data)
                except BlockingIOError:
                    pass

    feeder = threading.Thread(target=feed, daemon=True)
    feeder.start()
    (root / "alsa.conf").write_text(
        'pcm.null { type null }\n'
        'pcm.test_capture { type file slave.pcm "null" '
        f'file "/dev/null" infile "{root}/input.raw" format "raw" }}\n'
    )
    env = dict(os.environ, XDG_RUNTIME_DIR=directory,
               PIPEWIRE_RUNTIME_DIR=directory, PIPEWIRE_REMOTE="redrix-check",
               ALSA_CONFIG_PATH=str(root / "alsa.conf"), LADSPA_PATH=LADSPA,
               PIPEWIRE_DEBUG="2")
    config = {
        "context.properties": {
            "core.daemon": True, "core.name": "redrix-check",
            "default.clock.rate": RATE, "default.clock.quantum": 256,
            "default.clock.min-quantum": 256, "default.clock.max-quantum": 256,
        },
        "context.spa-libs": {
            "audio.convert.*": "audioconvert/libspa-audioconvert",
            "support.*": "support/libspa-support", "api.alsa.*": "alsa/libspa-alsa",
        },
        "context.modules": [
            {"name": "libpipewire-module-" + name}
            for name in ("protocol-native", "spa-node-factory", "client-node",
                         "adapter", "link-factory", "metadata", "access")
        ],
        "context.objects": [{
            "factory": "spa-node-factory", "args": {
                "factory.name": "support.node.driver", "node.name": "Check-Driver",
                "node.group": "check", "priority.driver": 20000,
            },
        }],
    }
    (root / "pipewire.conf").write_text("\n".join(
        key + " = " + json.dumps(value, indent=2) for key, value in config.items()
    ))
    server_log = (root / "server.log").open("w+")
    server = subprocess.Popen([PIPEWIRE + "/bin/pipewire", "-c", str(root / "pipewire.conf")],
                              env=env, stdout=server_log, stderr=server_log)

    def command(program, *args):
        result = subprocess.run([PIPEWIRE + "/bin/" + program, *map(str, args)],
                                env=env, capture_output=True, text=True, timeout=10)
        if result.returncode:
            raise AssertionError(f"{program} {args}: {result.stderr}")
        return result.stdout

    def nodes():
        return [o for o in json.loads(command("pw-dump"))
                if o["type"] == "PipeWire:Interface:Node"]

    def find_node(name):
        return next((o for o in nodes() if o["info"]["props"].get("node.name") == name), None)

    def port_config(node, direction, channels):
        positions = ["MONO"] if channels == 1 else ["FL", "FR"]
        command("pw-cli", "set-param", node, "PortConfig", json.dumps({
            "direction": direction, "mode": "dsp", "format": {
                "mediaType": "audio", "mediaSubtype": "raw", "format": "F32P",
                "rate": RATE, "channels": channels, "position": positions,
            },
        }))

    def props(node, value):
        command("pw-cli", "set-param", node, "Props", json.dumps(value))

    def create(name, channels=2, graph=None):
        args = {
            "factory.name": "api.alsa.pcm.source", "node.name": name,
            "media.class": "Audio/Source", "api.alsa.path": "test_capture",
            "api.alsa.open.ucm": False, "audio.channels": channels,
            "audio.rate": RATE, "audio.format": "S32LE",
            "audio.position": ["MONO"] if channels == 1 else ["FL", "FR"],
            "node.group": "check", "object.linger": True,
            # The null PCM has no physical clock. Test graph gain/reset rather
            # than sinc ringing from restarting its artificial clock at DC.
            "resample.disable": True,
            "channelmix.lock-volumes": True,
            "audioconvert.filter-graph.0": json.dumps(graph or VOLUME_GRAPH),
            "audioconvert.filter-graph.disable": True,
        }
        command("pw-cli", "create-node", "adapter", json.dumps(args, indent=2))
        node = find_node(name)
        assert node is not None, f"node {name} was not created"
        return node["id"]

    def capture(name, channels=2, frames=RATE // 2, during=None):
        output = root / "output.raw"
        with (root / "capture.log").open("w+") as log:
            recorder = subprocess.Popen([
                PIPEWIRE + "/bin/pw-cat", "--record", "--raw", "--format", "f32",
                "--channels", str(channels), "--rate", str(RATE),
                "--properties", "{ resample.disable = true }",
                "--sample-count", str(frames), "--target", "0", str(output),
            ], env=env, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 5
                node = None
                while time.monotonic() < deadline:
                    node = find_node("pw-cat")
                    if node:
                        break
                    time.sleep(0.01)
                assert node, "recorder node did not appear"
                port_config(node["id"], "Input", channels)
                source = find_node(name)
                assert source is not None, "capture source disappeared"
                # Queue all channel links from one client. Separate pw-link
                # processes let recording start with only one channel linked.
                command("pw-cli", "create-link", source["id"], "*",
                        node["id"], "*", '{ "object.linger": true }')
                if during:
                    during()
                # pw-cat 1.6.6 returns 1 upon reaching --sample-count; verify PCM,
                # not that incidental exit code.
                recorder.wait(timeout=15)
                data = array.array("f")
                data.frombytes(output.read_bytes())
                assert len(data) == frames * channels, f"short capture: {len(data)}"
                assert all(math.isfinite(x) for x in data), "nonfinite audio"
                return data
            finally:
                stop(recorder)

    def check_gain(data, gain, channel=0, channels=2, settle=RATE // 5):
        expected = INPUT * gain
        values = data[settle * channels + channel::channels]
        assert values, "no measured samples"
        max_error = max(abs(x - expected) for x in values)
        tolerance = max(1e-5, expected * 1e-3)
        if max_error >= tolerance:
            bad = [i + settle for i, x in enumerate(values) if abs(x - expected) >= tolerance]
            raise AssertionError(("steady gain mismatch", max_error, expected,
                                  "bad frame range", bad[0], bad[-1], "count", len(bad)))

    try:
        deadline = time.monotonic() + 5
        while not (root / "redrix-check").exists():
            assert server.poll() is None, "server failed to start"
            assert time.monotonic() < deadline, "server startup timed out"
            time.sleep(0.01)
        # Explicit device DSP must not silently disappear when a required
        # plugin is unavailable. The following normal-volume scenario also
        # proves rejection did not just kill the server or break node creation.
        missing_graph = json.loads(json.dumps(VOLUME_GRAPH))
        missing_graph["nodes"][0]["plugin"] = "redrix-deliberately-missing-plugin"
        try:
            create("missing-plugin-probe", graph=missing_graph)
        except AssertionError:
            pass
        else:
            raise AssertionError("missing required plugin published a usable audio node")
        assert server.poll() is None, "missing plugin crashed the audio server"
        assert find_node("missing-plugin-probe") is None, "failed graph exposed an unprocessed node"


        # ACP may not emit a changed-volume event when its requested value is
        # already the default unity. The graph must initialize without one.
        node = create("default-volume-probe")
        port_config(node, "Output", 2)
        check_gain(capture("default-volume-probe"), 1)
        command("pw-cli", "destroy", node)
        print("PASS default device volume initializes without a change event", flush=True)
        print("PASS missing required plugin rejects the node without disabling valid audio", flush=True)

        node = create("saved-volume-probe")
        props(node, {"channelVolumes": [0.125, 0.125], "mute": False})
        port_config(node, "Output", 2)
        check_gain(capture("saved-volume-probe"), SAVED_GAIN)
        props(node, {"mute": True})
        # This exact-gain probe uses the speaker's intentional 100 ms mute ramp.
        muted = capture("saved-volume-probe")
        assert max(map(abs, muted[RATE // 5 * 2:])) == 0
        props(node, {"mute": False})
        check_gain(capture("saved-volume-probe", frames=RATE), SAVED_GAIN, settle=RATE * 3 // 5)
        props(node, {"params": ["channelmix.max-volume", 10.0]})
        check_gain(capture("saved-volume-probe"), SAVED_GAIN)
        print("PASS pre-format saved volume and mute preserve single gain ownership", flush=True)

        def cycle():
            for _ in range(30):
                command("pw-cli", "send-command", node, "Suspend", "{}")
                command("pw-cli", "send-command", node, "Start", "{}")

        data = capture("saved-volume-probe", frames=RATE * 5, during=cycle)
        assert max(map(abs, data)) <= INPUT * SAVED_GAIN * 1.001, ("corrupt lifecycle samples", min(data), max(data))
        assert min(data) >= -1e-5, "corrupt negative samples"
        check_gain(data, SAVED_GAIN, settle=RATE * 4)
        check_gain(capture("saved-volume-probe"), SAVED_GAIN)

        def flush():
            for _ in range(20):
                command("pw-cli", "send-command", node, "Flush", "{}")

        data = capture("saved-volume-probe", frames=RATE * 3, during=flush)
        check_gain(data, SAVED_GAIN, settle=RATE * 2)
        assert all(-1e-5 <= x <= INPUT * SAVED_GAIN * 1.001 for x in data), "corrupt/dry flush frames"
        command("pw-cli", "destroy", node)
        print("PASS active ALSA suspend/start, flush and reopen retain clean audio", flush=True)

        node = create("muted-volume-probe")
        props(node, {"mute": True})
        port_config(node, "Output", 2)
        assert max(map(abs, capture("muted-volume-probe"))) == 0
        command("pw-cli", "destroy", node)
        print("PASS pre-format mute never starts at the default gain", flush=True)

        node = create("balanced-volume-probe")
        props(node, {"channelVolumes": [0.125, 0.008], "mute": False})
        port_config(node, "Output", 2)
        data = capture("balanced-volume-probe")
        check_gain(data, SAVED_GAIN, 0)
        check_gain(data, 10 ** (-27 / 20), 1)
        command("pw-cli", "send-command", node, "Suspend", "{}")
        command("pw-cli", "send-command", node, "Start", "{}")
        data = capture("balanced-volume-probe")
        check_gain(data, SAVED_GAIN, 0)
        check_gain(data, 10 ** (-27 / 20), 1)
        command("pw-cli", "destroy", node)
        print("PASS stereo volume and balance survive reactivation", flush=True)

        # APM rejects DC. Feed deterministic voiced harmonics, identically to
        # both channels, and measure post-AGC balance without pinning AGC levels.
        samples = array.array("i")
        for frame in range(RATE):
            phase = 2 * math.pi * frame / RATE
            value = 0.012 * (1 + math.sin(4 * phase)) * (
                math.sin(170 * phase) + 0.3 * math.sin(510 * phase))
            samples.extend([int(value * (1 << 31))] * 2)
        chunk = samples.tobytes()
        node = create("speech-apm", 2, GRAPHS["microphone"])
        props(node, {"channelVolumes": [0.125, 1.0], "mute": False})
        port_config(node, "Output", 2)
        for _ in range(2):
            data = capture("speech-apm", frames=RATE * 3)
            assert all(math.isfinite(x) and abs(x) <= 1.0 for x in data)
            left, right = data[::2], data[1::2]
            assert sum(x * x for x in right) / len(right) > 1e-6, "lost speech signal"
            assert max(abs(l - r * 0.1) for l, r in zip(left, right)) < 1e-5, "AGC defeated UI balance"
            command("pw-cli", "send-command", node, "Suspend", "{}")
            command("pw-cli", "send-command", node, "Start", "{}")
        props(node, {"mute": True})
        assert max(map(abs, capture("speech-apm"))) == 0
        props(node, {"mute": False})
        data = capture("speech-apm", frames=RATE * 3, during=flush)
        assert all(math.isfinite(x) and abs(x) <= 1.0 for x in data)
        assert sum(x * x for x in data[1::2]) / (len(data) // 2) > 1e-6
        command("pw-cli", "destroy", node)
        print("PASS system speech APM preserves post-AGC volume, mute and lifecycle", flush=True)

        assert server.poll() is None, "audio host crashed"
    except BaseException:
        server_log.flush()
        print((root / "server.log").read_text()[-12000:], file=sys.stderr)
        raise
    finally:
        stop(server)
        finish_feeding.set()
        feeder.join(timeout=2)
        os.close(feeder_fd)
        server_log.close()
