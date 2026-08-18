#!/usr/bin/env python3
"""Emit strict JSON spectrum frames for the cliamp-player QML plugin."""

import json
import math
import os
import select
import shutil
import signal
import subprocess
import sys
import threading
import time

WIDTH = 16
HEIGHT = 64
FPS = 20
FRAME_INTERVAL = 1.0 / FPS
FRAME_BYTES = WIDTH * HEIGHT
READ_TIMEOUT = 2.0
MAX_STDERR_BYTES = 8192
MAX_JSON_LINE_BYTES = 65536

running = True
child = None
warning_counts = {}


def warn(key, message, limit=3):
    count = warning_counts.get(key, 0)
    warning_counts[key] = count + 1
    if count < limit:
        print(f"cliamp-player: {message}", file=sys.stderr, flush=True)
    elif count == limit:
        print(f"cliamp-player: suppressing further {key} warnings", file=sys.stderr, flush=True)


def stop(_signum=None, _frame=None):
    global running
    running = False
    process = child
    if process is not None and process.poll() is None:
        try:
            process.terminate()
        except OSError:
            pass


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


def terminate_child(process):
    if process is None or process.poll() is not None:
        return
    try:
        process.terminate()
        process.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    except OSError:
        pass


class StderrTail:
    def __init__(self, limit=MAX_STDERR_BYTES):
        self.limit = limit
        self.data = bytearray()

    def append(self, chunk):
        self.data.extend(chunk)
        overflow = len(self.data) - self.limit
        if overflow > 0:
            del self.data[:overflow]

    def text(self):
        return bytes(self.data).decode("utf-8", errors="replace").strip()


def drain_stderr(stream, tail):
    try:
        while True:
            chunk = os.read(stream.fileno(), 4096)
            if not chunk:
                break
            tail.append(chunk)
    except (OSError, ValueError):
        pass
    finally:
        try:
            stream.close()
        except (OSError, ValueError):
            pass


def start_process(command, **kwargs):
    tail = StderrTail()
    process = subprocess.Popen(command, stderr=subprocess.PIPE, **kwargs)
    stderr_thread = threading.Thread(
        target=drain_stderr,
        args=(process.stderr, tail),
        name="cliamp-player-stderr",
        daemon=True,
    )
    try:
        stderr_thread.start()
    except RuntimeError:
        terminate_child(process)
        raise
    return process, tail, stderr_thread


def child_stderr(tail, stderr_thread):
    stderr_thread.join(timeout=0.5)
    return tail.text()


class BoundedLineReader:
    def __init__(self, stream, limit=MAX_JSON_LINE_BYTES):
        self.stream = stream
        self.limit = limit
        self.buffer = bytearray()

    def read(self, timeout):
        deadline = time.monotonic() + timeout
        while running:
            newline = self.buffer.find(b"\n")
            if newline >= 0:
                if newline > self.limit:
                    return "oversized", None
                line = bytes(self.buffer[:newline])
                del self.buffer[:newline + 1]
                return "line", line
            if len(self.buffer) > self.limit:
                return "oversized", None

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return "timeout", None
            try:
                ready, _, _ = select.select([self.stream], [], [], remaining)
            except (OSError, ValueError):
                return "error", None
            if not ready:
                return "timeout", None

            try:
                chunk = os.read(self.stream.fileno(), 4096)
            except OSError:
                return "error", None
            if not chunk:
                if not self.buffer:
                    return "eof", None
                if len(self.buffer) > self.limit:
                    return "oversized", None
                line = bytes(self.buffer)
                self.buffer.clear()
                return "line", line
            self.buffer.extend(chunk)

        return "stopped", None


def default_monitor():
    if shutil.which("pactl"):
        try:
            sink = subprocess.check_output(
                ["pactl", "get-default-sink"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2,
            ).strip()
            if sink:
                return sink + ".monitor"
        except (OSError, subprocess.SubprocessError):
            pass
    return "@DEFAULT_MONITOR@"


def read_exact(stream, size, timeout):
    data = bytearray()
    deadline = time.monotonic() + timeout
    descriptor = stream.fileno()
    while len(data) < size:
        if not running:
            return "stopped", None
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return "timeout", None
        try:
            ready, _, _ = select.select([descriptor], [], [], remaining)
        except (OSError, ValueError):
            return "read-error", None
        if not ready:
            return "timeout", None
        try:
            chunk = os.read(descriptor, size - len(data))
        except OSError:
            return "read-error", None
        if not chunk:
            return "eof", None
        data.extend(chunk)
    return "frame", bytes(data)


def finite_values(values):
    if not isinstance(values, list) or not values:
        return None
    result = []
    for value in values:
        try:
            number = float(value)
        except (TypeError, ValueError, OverflowError):
            return None
        if not math.isfinite(number):
            return None
        result.append(number)
    return result


def resample(values):
    if len(values) == 1:
        return [values[0]] * WIDTH
    result = []
    for index in range(WIDTH):
        position = index * (len(values) - 1) / (WIDTH - 1)
        left = int(position)
        right = min(len(values) - 1, left + 1)
        fraction = position - left
        result.append(values[left] * (1 - fraction) + values[right] * fraction)
    return result


def normalize_bands(values):
    clean = finite_values(values)
    if clean is None:
        return None
    return [max(0.0, min(1.0, value)) for value in resample(clean)]


def emit(bands, source):
    payload = {
        "bands": [round(value, 3) for value in bands],
        "energy": round(sum(bands) / len(bands), 4),
        "source": source,
    }
    try:
        line = json.dumps(payload, separators=(",", ":"), allow_nan=False)
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
        return True
    except (BrokenPipeError, ValueError):
        return False


def spectrum_from_frame(frame, previous):
    bands = []
    for index in range(WIDTH):
        value = sum(frame[index::WIDTH]) / (HEIGHT * 255.0)
        response = 0.72 if value > previous[index] else 0.28
        smoothed = previous[index] + (value - previous[index]) * response
        previous[index] = smoothed
        bands.append(max(0.0, min(1.0, smoothed)))
    return bands


def stream_ffmpeg():
    global child
    source = default_monitor()
    graph = (
        "showfreqs="
        f"s={WIDTH}x{HEIGHT}:mode=bar:fscale=log:ascale=log:colors=white:r={FPS}"
    )
    command = [
        "ffmpeg",
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "pulse",
        "-i",
        source,
        "-filter_complex",
        graph,
        "-f",
        "rawvideo",
        "-pix_fmt",
        "gray",
        "pipe:1",
    ]

    try:
        process, error_tail, error_thread = start_process(
            command,
            stdout=subprocess.PIPE,
            bufsize=0,
        )
    except (OSError, RuntimeError) as error:
        warn("ffmpeg-start", f"cannot start ffmpeg: {error}")
        return "failed"

    child = process
    previous = [0.0] * WIDTH
    next_source_check = time.monotonic() + 5
    outcome = "failed"
    failure = "stream ended unexpectedly"

    try:
        while running:
            frame_status, frame = read_exact(process.stdout, FRAME_BYTES, READ_TIMEOUT)
            if frame_status == "stopped" or not running:
                outcome = "stopped"
                break
            if frame_status != "frame":
                if default_monitor() != source:
                    outcome = "source-changed"
                else:
                    failure = f"{frame_status} while reading a spectrum frame"
                break
            if not emit(spectrum_from_frame(frame, previous), "ffmpeg"):
                outcome = "pipe-closed"
                break
            if time.monotonic() >= next_source_check:
                next_source_check = time.monotonic() + 5
                if default_monitor() != source:
                    outcome = "source-changed"
                    break
    finally:
        if not running and outcome == "failed":
            outcome = "stopped"
        terminate_child(process)
        error_text = child_stderr(error_tail, error_thread)
        child = None

    if outcome == "failed":
        detail = error_text or failure
        warn("ffmpeg-stream", f"ffmpeg capture failed: {detail}")
    return outcome


def stream_cliamp():
    global child
    if not shutil.which("cliamp"):
        warn("cliamp-missing", "cliamp is not available on PATH")
        return "failed"

    try:
        process, error_tail, error_thread = start_process(
            ["cliamp", "visstream", "--fps", str(FPS)],
            stdout=subprocess.PIPE,
            bufsize=0,
        )
    except (OSError, RuntimeError) as error:
        warn("cliamp-start", f"cannot start cliamp visstream: {error}")
        return "failed"

    child = process
    reader = BoundedLineReader(process.stdout)
    valid_frames = 0
    consecutive_timeouts = 0
    consecutive_invalid = 0
    next_emit = 0.0
    outcome = "failed"
    failure = "stream ended unexpectedly"

    try:
        while running:
            frame_status, line = reader.read(READ_TIMEOUT)
            if frame_status == "stopped" or not running:
                outcome = "stopped"
                break
            if frame_status == "timeout":
                consecutive_timeouts += 1
                if process.poll() is not None:
                    failure = "process exited"
                    break
                if consecutive_timeouts >= 2:
                    failure = "no frames received for four seconds"
                    break
                continue
            if frame_status != "line":
                if frame_status == "oversized":
                    failure = f"frame exceeds {MAX_JSON_LINE_BYTES}-byte limit"
                elif frame_status == "eof":
                    failure = "end of stream"
                else:
                    failure = "read error"
                break
            consecutive_timeouts = 0

            try:
                response = json.loads(line)
            except (TypeError, ValueError, RecursionError):
                response = None

            values = response.get("bands") if isinstance(response, dict) and response.get("ok") is True else None
            bands = normalize_bands(values)
            if bands is None:
                consecutive_invalid += 1
                warn("invalid-frame", "ignoring malformed cliamp visstream frame")
                if consecutive_invalid >= FPS * 2:
                    failure = "too many malformed frames"
                    break
                continue

            consecutive_invalid = 0
            now = time.monotonic()
            if next_emit > now:
                time.sleep(next_emit - now)
            if not running:
                outcome = "stopped"
                break
            valid_frames += 1
            if not emit(bands, "cliamp"):
                outcome = "pipe-closed"
                break
            next_emit = time.monotonic() + FRAME_INTERVAL
    finally:
        if not running:
            outcome = "stopped"
        terminate_child(process)
        error_text = child_stderr(error_tail, error_thread)
        child = None

    if outcome == "failed":
        detail = error_text or failure
        if valid_frames == 0:
            detail = "no valid frames; " + detail
        warn("cliamp-stream", f"cliamp visstream failed: {detail}")
    return outcome


def main():
    if shutil.which("ffmpeg"):
        while running:
            outcome = stream_ffmpeg()
            if outcome == "source-changed":
                continue
            if outcome in ("stopped", "pipe-closed"):
                return 0
            break
    else:
        warn("ffmpeg-missing", "ffmpeg is unavailable; using cliamp visstream")

    if not running:
        return 0

    warn("fallback", "using cliamp visstream fallback")
    outcome = stream_cliamp()
    return 0 if outcome in ("stopped", "pipe-closed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
