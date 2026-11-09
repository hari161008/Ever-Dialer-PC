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

conn_counter = 0
active_conn_id = 0

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

def handle_socket_connection(client_sock, client_addr, mac_addr=""):
    global active_client_sock, running, conn_counter, active_conn_id
    with sock_lock:
        conn_counter += 1
        my_conn_id = conn_counter
        active_conn_id = my_conn_id
        if active_client_sock is not None:
            log("New connection incoming; closing previous socket")
            try:
                active_client_sock.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
            try:
                active_client_sock.close()
            except Exception:
                pass
            active_client_sock = None
        active_client_sock = client_sock

    dev_name = str(client_addr[0]) if client_addr else "Mobile Device"
    log(f"Bluetooth connection established with {dev_name} (MAC: {mac_addr}) [conn #{my_conn_id}]")
    emit_event("status", connected=True, device=dev_name, mac=mac_addr)

    # Immediately request telemetry data from the newly connected phone; sync is triggered by Flutter with timestamp
    try:
        client_sock.sendall(b'{"cmd": "request_telemetry"}\n')
        log(f"Sent immediate request_telemetry to {dev_name}")
    except Exception as e:
        log(f"Error sending initial request_telemetry: {e}")

    buffer = ""
    try:
        client_sock.settimeout(2.5)
        while running:
            with sock_lock:
                if active_conn_id != my_conn_id:
                    log(f"Connection #{my_conn_id} superseded by newer connection #{active_conn_id}")
                    break
            try:
                data = client_sock.recv(65536)
                if not data:
                    log(f"Socket #{my_conn_id} closed by remote device")
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
                        log(f"Received {event_name} packet from phone #{my_conn_id}")
                        emit_event(event_name, payload=parsed.get("payload", parsed))
                    except Exception as json_err:
                        log(f"JSON parse error on incoming packet: {json_err}")
            except socket.timeout:
                continue
            except Exception as e:
                log(f"Socket #{my_conn_id} read exception: {e}")
                break
    finally:
        with sock_lock:
            is_active = (active_conn_id == my_conn_id)
            if is_active:
                active_client_sock = None
        try:
            client_sock.close()
        except Exception:
            pass
        if is_active:
            emit_event("status", connected=False)
            log(f"Client #{my_conn_id} disconnected")
        else:
            log(f"Superseded client #{my_conn_id} cleaned up without emitting disconnect")

def try_connect_rfcomm(mac, channel=RFCOMM_CHANNEL):
    global active_client_sock
    with sock_lock:
        if active_client_sock is not None:
            return
    try:
        log(f"Attempting outgoing RFCOMM connect to {mac} on channel {channel}...")
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        sock.settimeout(3.5)
        sock.connect((mac, channel))
        log(f"Outgoing RFCOMM connected to {mac} on channel {channel}")
        threading.Thread(target=handle_socket_connection, args=(sock, (mac, channel), mac), daemon=True).start()
    except Exception as e:
        log(f"Outgoing RFCOMM connect to {mac} channel {channel} failed: {e}")

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
                dev_name = "Mobile Device"
                mac_addr = ""
                try:
                    dev_obj = bus.get_object('org.bluez', path)
                    dev_props = dbus.Interface(dev_obj, 'org.freedesktop.DBus.Properties')
                    dev_name = str(dev_props.Get('org.bluez.Device1', 'Alias'))
                    mac_addr = str(dev_props.Get('org.bluez.Device1', 'Address'))
                except Exception as e:
                    try:
                        parts = path.split('/')[-1].replace('dev_', '').split('_')
                        if len(parts) == 6:
                            mac_addr = ':'.join(parts)
                    except Exception:
                        pass
                    log(f"Note querying DBus device properties for {path}: {e}")
                threading.Thread(target=handle_socket_connection, args=(sock, (dev_name, RFCOMM_CHANNEL), mac_addr), daemon=True).start()

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

            try:
                cmd_obj = json.loads(line)
                cmd_name = cmd_obj.get("cmd")
                if cmd_name == "connect" and "mac" in cmd_obj:
                    target_mac = cmd_obj["mac"].strip()
                    if target_mac:
                        threading.Thread(target=try_connect_rfcomm, args=(target_mac,), daemon=True).start()
                        continue
                elif cmd_name == "disconnect":
                    with sock_lock:
                        if active_client_sock is not None:
                            try:
                                active_client_sock.shutdown(socket.SHUT_RDWR)
                            except Exception:
                                pass
                            try:
                                active_client_sock.close()
                            except Exception:
                                pass
                            active_client_sock = None
                    continue
            except Exception:
                pass

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
