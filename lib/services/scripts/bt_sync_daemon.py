#!/usr/bin/env python3
"""
Ever Dialer PC Bluetooth Sync Daemon
Connects with Ever Dialer Android Mobile App over RFCOMM / Bluetooth SPP.
Streams sync payloads (Contacts, Call Logs, SMS, Notes, Favourites) to Ever Dialer PC via stdout.
Receives commands from Ever Dialer PC via stdin.
"""

import sys
import os
import json
import socket
import select
import signal
import time
import threading
import fcntl

EVER_DIALER_UUID = "fa87c0d0-afac-11de-8a39-0800200c9a66"
SPP_UUID = "00001101-0000-1000-8000-00805f9b34fb"
RFCOMM_CHANNEL = 4

LOCK_FILE = "/tmp/everdialer_bt_sync.lock"
lock_fd = None

def acquire_process_lock():
    global lock_fd
    try:
        lock_fd = open(LOCK_FILE, 'w')
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.write(str(os.getpid()))
        lock_fd.flush()
        return True
    except (IOError, BlockingIOError):
        return False

running = True
active_client_sock = None
sock_lock = threading.Lock()

def log(msg):
    sys.stderr.write(f"[EverDialerBT] {msg}\n")
    sys.stderr.flush()

def emit_event(event_type, **kwargs):
    try:
        payload = {"event": event_type, **kwargs}
        sys.stdout.write(json.dumps(payload) + "\n")
        sys.stdout.flush()
    except (BrokenPipeError, IOError):
        pass

def signal_handler(signum, frame):
    global running
    log(f"Received signal {signum}, shutting down...")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def handle_socket_connection(client_sock, client_addr):
    global active_client_sock, running
    with sock_lock:
        if active_client_sock is not None:
            log("New connection incoming; closing previous socket")
            try:
                active_client_sock.close()
            except Exception:
                pass
            active_client_sock = None
        active_client_sock = client_sock

    dev_name = str(client_addr[0]) if client_addr else "Mobile Device"
    log(f"Bluetooth connection established with {dev_name}")
    emit_event("status", connected=True, device=dev_name)

    buffer = ""
    try:
        client_sock.settimeout(4.0)
        while running:
            try:
                data = client_sock.recv(16384)
                if not data:
                    log("Socket closed by remote device")
                    break
                buffer += data.decode('utf-8', errors='replace')
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        parsed = json.loads(line)
                        event_name = parsed.get("type", "sync_data")
                        log(f"Received {event_name} packet from phone")
                        emit_event(event_name, payload=parsed.get("payload", parsed))
                    except Exception as json_err:
                        log(f"JSON parse error on incoming packet: {json_err}")
            except socket.timeout:
                continue
            except Exception as e:
                log(f"Socket read exception: {e}")
                break
    finally:
        with sock_lock:
            active_client_sock = None
        try:
            client_sock.close()
        except Exception:
            pass
        emit_event("status", connected=False)
        log("Client disconnected")

def start_bluez_profile():
    try:
        import dbus
        import dbus.service
        import dbus.mainloop.glib
        from gi.repository import GLib

        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus = dbus.SystemBus()

        class Profile(dbus.service.Object):
            @dbus.service.method('org.bluez.Profile1', in_signature='oha{sv}', out_signature='')
            def NewConnection(self, path, fd, properties):
                log(f"BlueZ NewConnection callback on {path}")
                raw_fd = fd.take()
                sock = socket.fromfd(raw_fd, socket.AF_BLUETOOTH, socket.SOCK_STREAM)
                threading.Thread(target=handle_socket_connection, args=(sock, ("Mobile Device", RFCOMM_CHANNEL)), daemon=True).start()

            @dbus.service.method('org.bluez.Profile1', in_signature='o', out_signature='')
            def RequestDisconnection(self, path):
                log(f"BlueZ RequestDisconnection: {path}")

            @dbus.service.method('org.bluez.Profile1', in_signature='', out_signature='')
            def Release(self):
                log("BlueZ Profile Release")

        profile_obj = Profile(bus, '/everdialer/sync_profile')
        manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.ProfileManager1')

        opts = {
            'Channel': dbus.UInt16(RFCOMM_CHANNEL),
            'Name': 'EverDialerPcSync',
            'Role': 'server',
            'RequireAuthentication': dbus.Boolean(False),
            'RequireAuthorization': dbus.Boolean(False),
            'AutoConnect': dbus.Boolean(True)
        }
        manager.RegisterProfile('/everdialer/sync_profile', EVER_DIALER_UUID, opts)
        log(f"Registered BlueZ Profile1 object for UUID {EVER_DIALER_UUID}")

        glib_loop = GLib.MainLoop()
        t = threading.Thread(target=glib_loop.run, daemon=True)
        t.start()
        return manager
    except Exception as e:
        log(f"Warning: could not register BlueZ DBus profile: {e}")
        return None

def rfcomm_server_thread():
    server_sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server_sock.bind(('00:00:00:00:00:00', RFCOMM_CHANNEL))
        server_sock.listen(2)
        server_sock.settimeout(1.0)
        log(f"Raw RFCOMM server listening on channel {RFCOMM_CHANNEL}")
    except Exception as e:
        log(f"Raw RFCOMM bind note: {e}")
        return

    while running:
        if active_client_sock is not None:
            time.sleep(1)
            continue
        try:
            client_sock, client_info = server_sock.accept()
            handle_socket_connection(client_sock, client_info)
        except socket.timeout:
            continue
        except Exception as e:
            if running:
                log(f"RFCOMM accept error: {e}")
            time.sleep(1)

    try:
        server_sock.close()
    except Exception:
        pass

def stdin_listener():
    global running, active_client_sock
    while running:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            log(f"PC command received: {line}")
            with sock_lock:
                if active_client_sock is not None:
                    try:
                        active_client_sock.sendall((line + "\n").encode('utf-8'))
                        log(f"Successfully transmitted command to phone over Bluetooth")
                    except Exception as e:
                        log(f"Failed to forward stdin command to mobile: {e}")
                else:
                    log(f"Cannot forward command: phone is not connected via Bluetooth")
        except Exception as e:
            log(f"Error in stdin_listener: {e}")
            break

def main():
    global running
    if not acquire_process_lock():
        log("Another daemon instance is already active. Exiting cleanly.")
        return 0

    emit_event("status", connected=False, state="starting")

    profile_manager = start_bluez_profile()

    # If BlueZ profile registered, BlueZ handles channel 4. Only fallback to raw socket if BlueZ unavailable.
    if profile_manager is None:
        log("BlueZ profile unavailable, using raw RFCOMM socket on channel 4")
        server_t = threading.Thread(target=rfcomm_server_thread, daemon=True)
        server_t.start()

    stdin_t = threading.Thread(target=stdin_listener, daemon=True)
    stdin_t.start()

    emit_event("status", connected=False, state="listening", channel=RFCOMM_CHANNEL)
    log("Sync daemon running and listening.")

    while running:
        time.sleep(0.5)

    if profile_manager:
        try:
            profile_manager.UnregisterProfile('/everdialer/sync_profile')
        except Exception:
            pass

    emit_event("status", connected=False, state="stopped")
    return 0

if __name__ == "__main__":
    sys.exit(main())
