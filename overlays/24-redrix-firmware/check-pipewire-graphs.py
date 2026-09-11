"""Exercise native filter-chain and WirePlumber policy; never open audio hardware."""
import array
import errno
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

PIPEWIRE, WIREPLUMBER, LADSPA, POLICY = sys.argv[1:]
POLICY = json.loads(Path(POLICY).read_text())
RATE = 48000


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


with tempfile.TemporaryDirectory(prefix="redrix-filter-chain-") as directory:
    root = Path(directory)
    env = dict(os.environ, XDG_RUNTIME_DIR=directory,
               PIPEWIRE_RUNTIME_DIR=directory, PIPEWIRE_REMOTE="redrix-check",
               XDG_CONFIG_HOME=str(root / "config"), XDG_STATE_HOME=str(root / "state"),
               WIREPLUMBER_CONFIG_DIR=str(root / "wireplumber"), LADSPA_PATH=LADSPA,
               DBUS_SYSTEM_BUS_ADDRESS=os.environ["DBUS_SESSION_BUS_ADDRESS"])
    for name in ("PIPEWIRE_PROPS", "PIPEWIRE_CONFIG_DIR", "PIPEWIRE_CONFIG_NAME",
                 "PIPEWIRE_CONFIG_PREFIX", "PIPEWIRE_QUANTUM", "PIPEWIRE_RATE"):
        env.pop(name, None)
    # Trusted diagnostics can see parents which native software-dsp hides from
    # ordinary clients. These are synthetic devices, not a security boundary.
    admin_dir = root / "admin"
    admin_dir.mkdir()
    (admin_dir / "client.conf").write_text(
        Path(PIPEWIRE + "/share/pipewire/client.conf").read_text())
    fragments = admin_dir / "client.conf.d"
    fragments.mkdir()
    (fragments / "test.conf").write_text(
        "context.properties = { wireplumber.daemon = true }\n")
    admin_env = dict(env, PIPEWIRE_CONFIG_DIR=str(admin_dir))
    logs = []
    processes = []

    def spawn(args, name, admin=False):
        log = (root / (name + ".log")).open("w+")
        logs.append(log)
        process = subprocess.Popen(args, env=admin_env if admin else env,
                                   stdout=log, stderr=log)
        processes.append(process)
        return process

    def command(program, *args, admin=False):
        result = subprocess.run([PIPEWIRE + "/bin/" + program, *map(str, args)],
                                env=admin_env if admin else env,
                                capture_output=True, text=True, timeout=10)
        if result.returncode:
            raise AssertionError(f"{program} {args}: {result.stderr}")
        return result.stdout

    def objects(admin=False):
        return json.loads(command("pw-dump", admin=admin))

    def nodes(admin=False):
        return [o for o in objects(admin) if o["type"] == "PipeWire:Interface:Node"]

    def find_node(name, admin=False):
        return next((o for o in nodes(admin)
                     if o["info"]["props"].get("node.name") == name), None)

    def wait_for(predicate, message, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            result = predicate()
            if result:
                return result
            assert server.poll() is None, "PipeWire exited"
            if manager is not None:
                assert manager.poll() is None, "WirePlumber exited"
            time.sleep(0.05)
        raise AssertionError(message)

    def set_props(name, props, admin=False):
        node = find_node(name, admin)
        assert node is not None, name
        command("pw-cli", "set-param", node["id"], "Props", json.dumps(props), admin=admin)

    def volume(name, left, right=None, mute=False):
        if right is None:
            right = left
        set_props(name, {"channelVolumes": [(left / 100) ** 3, (right / 100) ** 3],
                         "mute": mute})

    def endpoint_props(name):
        return next(p for p in find_node(name)["info"]["params"]["Props"]
                    if "channelVolumes" in p)

    def capture(target, seconds=1, admin=False, monitor=False, during=None):
        path = root / "capture.raw"
        path.unlink(missing_ok=True)
        props = {"node.name": "check.recorder", "node.dont-fallback": True,
                 "node.linger": True, "state.restore-props": False,
                 "state.restore-target": False}
        if monitor:
            props["stream.capture.sink"] = True
        args = [PIPEWIRE + "/bin/pw-cat", "--record", "--raw", "--format", "f32",
                "--rate", str(RATE), "--channels", "2", "--sample-count", str(RATE * seconds),
                "--properties", json.dumps(props)]
        if target is not None:
            args += ["--target", target]
        recorder = spawn([*args, str(path)], "capture", admin)
        try:
            wait_for(lambda: find_node("check.recorder", admin), "recorder did not appear")
            if during:
                during()
            returncode = recorder.wait(timeout=seconds + 10)
            # pw-cat 1.6.x exits 1 at --sample-count without marking the stream
            # drained. Accept that only with no diagnostics and all fresh samples.
            log = (root / "capture.log").read_text()
            assert returncode in (0, 1) and not log.strip(), ("recorder failed", returncode, log)
            data = array.array("f")
            data.frombytes(path.read_bytes())
            assert len(data) == RATE * seconds * 2, ("short capture", len(data))
            assert all(math.isfinite(x) for x in data), "nonfinite audio"
            return data
        finally:
            stop(recorder)

    def rms(data):
        assert data
        return math.sqrt(sum(x * x for x in data) / len(data))

    def check_microphone_balance():
        data = capture(POLICY["micNode"], seconds=2)
        left, right = data[RATE::2], data[RATE + 1::2]
        assert rms(right) > 1e-4, "lost microphone signal"
        assert all(abs(x) <= 1.0 for x in data), "APM output exceeded full scale"
        assert max(abs(l - 0.1 * r) for l, r in zip(left, right)) < 1e-5, "double or misplaced microphone gain"

    backend_microphone = {
        "factory.name": "audiotestsrc", "node.name": POLICY["micBackend"],
        "media.class": "Audio/Source", "audio.channels": 2,
        "audio.position": ["FL", "FR"], "audio.rate": RATE,
        "node.group": "check", "priority.session": 1,
        "channelmix.lock-volumes": True, "object.linger": True,
    }
    backend_speaker = {
        "factory.name": "support.null-audio-sink", "node.name": POLICY["speakerBackend"],
        "media.class": "Audio/Sink", "audio.position": ["FL", "FR"],
        "audio.rate": RATE, "priority.session": 1, "channelmix.lock-volumes": True,
    }
    config = {
        "context.properties": {
            "core.daemon": True, "core.name": "redrix-check",
            "default.clock.rate": RATE, "default.clock.quantum": 256,
        },
        "context.spa-libs": {
            "audio.convert.*": "audioconvert/libspa-audioconvert",
            "support.*": "support/libspa-support",
            "audiotestsrc": "audiotestsrc/libspa-audiotestsrc",
        },
        "context.modules": [{"name": "libpipewire-module-" + name} for name in (
            "protocol-native", "spa-node-factory", "client-node", "adapter",
            "link-factory", "metadata", "access")],
        "context.objects": [
            {"factory": "spa-node-factory", "args": {
                "factory.name": "support.node.driver", "node.name": "Check-Driver",
                "node.group": "check", "priority.driver": 20000}},
            {"factory": "adapter", "args": backend_speaker},
            {"factory": "adapter", "args": backend_microphone},
        ],
    }
    (root / "pipewire.conf").write_text("\n".join(
        key + " = " + json.dumps(value, indent=2) for key, value in config.items()))
    wp_dir = root / "wireplumber"
    (wp_dir / "wireplumber.conf.d").mkdir(parents=True)
    (wp_dir / "wireplumber.conf").write_text(
        Path(WIREPLUMBER + "/share/wireplumber/wireplumber.conf").read_text())

    def write_policy(rules):
        (wp_dir / "wireplumber.conf.d" / "test.conf").write_text(json.dumps({
            "wireplumber.profiles": {"policy": {
                "pw.node-factory.adapter": "required", "node.software-dsp": "required"}},
            "node.software-dsp.rules": rules,
        }, indent=2))

    def start_manager():
        return spawn([WIREPLUMBER + "/bin/wireplumber", "--profile", "policy"], "wireplumber")

    def ready_endpoints():
        names = {o["info"]["props"].get("node.name") for o in nodes()}
        return (POLICY["speakerNode"] in names and POLICY["micNode"] in names
                and POLICY["speakerBackend"] not in names and POLICY["micBackend"] not in names)

    def assert_rejected(process, node_name):
        try:
            returncode = process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            # Policy may keep a default-target request pending. A timeout alone
            # is not proof: require a live, registered, non-running stream.
            node = find_node(node_name)
            assert server.poll() is None and manager.poll() is None, "audio service exited"
            assert process.poll() is None and node is not None, "stream failed to register"
            assert node["info"]["state"] in ("idle", "suspended"), node["info"]["state"]
            log = (root / "rejected.log").read_text()
            assert not log.strip(), log
        else:
            # Require the server's missing-target error, not a local file/CLI failure.
            log = (root / "rejected.log").read_text()
            assert returncode != 0, "stream unexpectedly completed"
            assert re.search(rf"remote error: id=\d+ seq:-?\d+ res:{-errno.ENOENT} ", log), log

    def reject_capture(target):
        path = root / "rejected.raw"
        path.unlink(missing_ok=True)
        args = [PIPEWIRE + "/bin/pw-cat", "--record", "--raw", "--format", "f32",
                "--rate", str(RATE), "--channels", "2", "--sample-count", str(RATE),
                "--properties", '{ "node.name": "check.rejected", "node.dont-fallback": true }']
        if target:
            args += ["--target", target]
        recorder = spawn([*args, str(path)], "rejected")
        try:
            assert_rejected(recorder, "check.rejected")
            assert not path.exists() or path.stat().st_size == 0, "recording bypassed missing processing"
        finally:
            stop(recorder)

    manager = None
    server = spawn([PIPEWIRE + "/bin/pipewire", "-c", str(root / "pipewire.conf")], "pipewire")
    try:
        wait_for(lambda: (root / "redrix-check").exists(), "PipeWire socket missing")
        write_policy(POLICY["rules"])
        manager = start_manager()
        wait_for(ready_endpoints, "processed endpoints did not replace hidden parents")
        assert find_node(POLICY["micBackend"], admin=True), "diagnostic client cannot see backend"
        assert max(map(abs, capture(POLICY["micNode"]))) == 0, "first cutover was not safely silent"
        print("PASS native filters replace raw devices and start safely silent", flush=True)

        volume(POLICY["micNode"], 50, 100)
        check_microphone_balance()
        set_props(POLICY["micBackend"], {"channelVolumes": [0.008, 0.008], "mute": True}, admin=True)
        check_microphone_balance()
        print("PASS microphone volume is applied once after APM; backend gain is locked", flush=True)
        volume(POLICY["micNode"], 50, 100, mute=True)
        assert max(map(abs, capture(POLICY["micNode"]))) == 0
        volume(POLICY["micNode"], 50, 100)
        check_microphone_balance()
        print("PASS native microphone mute and unmute preserve balance", flush=True)

        # Monitor the hidden null sink as a trusted diagnostic client: this is
        # after the full speaker DSP, not the public virtual sink's dry monitor.
        tone = array.array("f")
        for i in range(RATE * 4):
            sample = 0.03 * math.sin(2 * math.pi * 440 * i / RATE)
            tone.extend([sample, sample])
        (root / "tone.raw").write_bytes(tone.tobytes())

        def speaker_capture(level, mute_during=False):
            if level is not None:
                volume(POLICY["speakerNode"], level)
            players = []
            def play():
                players.append(spawn([PIPEWIRE + "/bin/pw-cat", "--playback", "--raw", "--format", "f32",
                    "--rate", str(RATE), "--channels", "2", "--target", POLICY["speakerNode"],
                    "--properties", '{ "node.name": "check.player", "node.dont-fallback": true, "node.linger": true, "state.restore-props": false }',
                    str(root / "tone.raw")], "playback"))
                if mute_during:
                    wait_for(lambda: (find_node("check.player") or {}).get("info", {}).get("state") == "running",
                             "speaker player did not start")
                    time.sleep(0.7)
                    volume(POLICY["speakerNode"], level, mute=True)
            try:
                data = capture(POLICY["speakerBackend"], seconds=3, admin=True, monitor=True, during=play)
                return data
            finally:
                for player in players:
                    stop(player)
        loud_data = speaker_capture(100)
        loud = rms(loud_data[RATE * 2:RATE * 4:2])
        loud_right = rms(loud_data[RATE * 2 + 1:RATE * 4:2])
        quiet = rms(speaker_capture(50)[RATE * 2:RATE * 4:2])
        speaker_props = endpoint_props(POLICY["speakerNode"])
        assert all(abs(v - 0.125) < 1e-6 for v in speaker_props["channelVolumes"]), (
            "speaker readback disagrees with the 50% DSP gain", speaker_props)
        assert loud > 1e-4
        assert abs(quiet / loud - 10 ** (-13.5 / 20)) < 0.005, (quiet, loud)
        print("PASS full speaker filter-chain preserves the board volume curve", flush=True)
        # Change volume while idle, then resume without another volume command.
        # Custom plugin-control metadata may still show the previous activation;
        # verify the public value and rendered audio rather than that snapshot.
        speaker_capture(5)
        volume(POLICY["speakerNode"], 50)
        assert all(abs(v - 0.125) < 1e-6
                   for v in endpoint_props(POLICY["speakerNode"])["channelVolumes"])
        resumed = speaker_capture(None)
        assert abs(rms(resumed[RATE * 2:RATE * 4:2]) / loud - 10 ** (-13.5 / 20)) < 0.005
        print("PASS idle speaker volume agrees with readback and resumed audio", flush=True)
        muted_speaker = speaker_capture(100, mute_during=True)
        assert rms(muted_speaker[RATE // 2:RATE:2]) > loud * 0.5, "speaker started muted"
        assert max(map(abs, muted_speaker[RATE * 4:])) == 0, "speaker did not mute"
        print("PASS native speaker mute silences an active processed stream", flush=True)
        volume(POLICY["speakerNode"], 50, 20, mute=True)

        volume(POLICY["micNode"], 50, 100, mute=True)
        raw = find_node(POLICY["micBackend"], admin=True)
        command("pw-cli", "destroy", raw["id"], admin=True)
        wait_for(lambda: find_node(POLICY["micNode"]) is None, "filter survived removed hardware")
        external = dict(backend_microphone, **{"node.name": "test.external"})
        command("pw-cli", "create-node", "adapter", json.dumps(external), admin=True)
        wait_for(lambda: find_node("test.external"), "unrelated source was hidden")
        assert rms(capture("test.external")) > 1e-4, "unrelated microphone was affected"
        reject_capture(POLICY["micNode"])
        command("pw-cli", "destroy", find_node("test.external")["id"], admin=True)
        command("pw-cli", "create-node", "adapter", json.dumps(backend_microphone), admin=True)
        wait_for(ready_endpoints, "filter did not return after hardware recreation")
        assert max(map(abs, capture(POLICY["micNode"]))) == 0, "recreated device lost saved mute"
        volume(POLICY["micNode"], 50, 100)
        check_microphone_balance()
        print("PASS backend removal/recreation keeps mute and reconnects only to its device", flush=True)

        # Let upstream State finish its deferred write, then recreate the real
        # session manager and its LocalModules (not merely one graph handle).
        state_file = root / "state/wireplumber/stream-properties"
        wait_for(lambda: state_file.exists() and "org.codgician.redrix.microphone" in state_file.read_text(),
                 "virtual endpoint state was not saved")
        stop(manager)
        manager = None
        wait_for(lambda: find_node(POLICY["micNode"]) is None, "old manager retained its filter")
        manager = start_manager()
        wait_for(ready_endpoints, "filters did not recover with WirePlumber")
        check_microphone_balance()
        restored = endpoint_props(POLICY["speakerNode"])
        assert restored["mute"] is True, "speaker lost saved mute"
        assert all(abs(v - want) < 1e-6 for v, want in
                   zip(restored["channelVolumes"], [0.125, 0.008])), restored
        assert max(map(abs, speaker_capture(None))) == 0
        set_props(POLICY["speakerNode"], {"mute": False})
        restored_audio = speaker_capture(None)
        assert abs(rms(restored_audio[RATE * 2:RATE * 4:2]) / loud - 10 ** (-13.5 / 20)) < 0.005
        assert abs(rms(restored_audio[RATE * 2 + 1:RATE * 4:2]) / loud_right - 10 ** (-27 / 20)) < 0.005
        print("PASS native volume state survives WirePlumber restart", flush=True)

        stop(manager)
        manager = None
        broken = json.loads(json.dumps(POLICY["rules"]))
        args = json.loads(broken[1]["actions"]["create-filter"]["filter-graph"])
        args["filter.graph"]["nodes"][0]["plugin"] = "redrix-deliberately-missing-plugin"
        broken[1]["actions"]["create-filter"]["filter-graph"] = json.dumps(args)
        write_policy(broken)
        manager = start_manager()
        wait_for(lambda: find_node(POLICY["speakerNode"]) is not None
                 and find_node(POLICY["micBackend"]) is None, "failure policy did not hide raw input")
        assert find_node(POLICY["micNode"]) is None
        reject_capture(POLICY["micNode"])
        reject_capture(None)
        assert manager.poll() is None and server.poll() is None
        print("PASS missing APM rejects explicit/default capture without exposing raw input", flush=True)

        stop(manager)
        manager = None
        broken = json.loads(json.dumps(POLICY["rules"]))
        args = json.loads(broken[0]["actions"]["create-filter"]["filter-graph"])
        args["filter.graph"]["nodes"][0]["plugin"] = "redrix-deliberately-missing-plugin"
        broken[0]["actions"]["create-filter"]["filter-graph"] = json.dumps(args)
        write_policy(broken)
        manager = start_manager()
        wait_for(lambda: find_node(POLICY["micNode"]) is not None
                 and find_node(POLICY["speakerBackend"]) is None,
                 "failure policy did not hide raw output")
        assert find_node(POLICY["speakerNode"]) is None
        check_microphone_balance()
        for target in (POLICY["speakerNode"], None):
            players = []
            def rejected_playback():
                args = [PIPEWIRE + "/bin/pw-cat", "--playback", "--raw", "--format", "f32",
                        "--rate", str(RATE), "--channels", "2",
                        "--properties", '{ "node.name": "check.rejected-player", "node.dont-fallback": true }']
                if target:
                    args += ["--target", target]
                players.append(spawn([*args, str(root / "tone.raw")], "rejected"))
            try:
                data = capture(POLICY["speakerBackend"], seconds=2, admin=True,
                               monitor=True, during=rejected_playback)
                for player in players:
                    assert_rejected(player, "check.rejected-player")
                assert max(map(abs, data)) == 0, "playback bypassed missing speaker processing"
            finally:
                for player in players:
                    stop(player)
        print("PASS missing speaker DSP rejects explicit/default playback without raw output", flush=True)
    except BaseException:
        for name in ("pipewire", "wireplumber", "capture", "playback", "rejected"):
            path = root / (name + ".log")
            if path.exists():
                print(name + ":\n" + path.read_text()[-12000:], file=sys.stderr)
        raise
    finally:
        for process in reversed(processes):
            stop(process)
        for log in logs:
            log.close()
