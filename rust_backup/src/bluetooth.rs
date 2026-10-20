use std::process::Command;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

#[derive(Clone, Debug, Default)]
#[allow(dead_code)]
pub struct BluetoothDevice {
    pub mac: String,
    pub name: String,
    pub connected: bool,
    pub paired: bool,
}

#[derive(Clone, Debug)]
pub struct BluetoothState {
    pub powered: bool,
    pub discoverable: bool,
    pub pairable: bool,
    pub alias: String,
    pub connected_device: Option<BluetoothDevice>,
    pub speaker_mode_enabled: bool,
    pub speaker_muted: bool,
    pub speaker_volume: f32,
    pub status_message: String,
}

impl Default for BluetoothState {
    fn default() -> Self {
        Self {
            powered: false,
            discoverable: false,
            pairable: false,
            alias: "Ever Dialer PC".to_string(),
            connected_device: None,
            speaker_mode_enabled: false,
            speaker_muted: false,
            speaker_volume: 0.5,
            status_message: "Ready".to_string(),
        }
    }
}

#[allow(dead_code)]
pub enum BluetoothCommand {
    ToggleSpeakerMode(bool),
    UnmuteSpeaker,
    SetVolume(f32),
    DisconnectDevice(String),
    Refresh,
}

pub struct BluetoothController {
    state: Arc<Mutex<BluetoothState>>,
    cmd_sender: Sender<BluetoothCommand>,
}

impl BluetoothController {
    pub fn new() -> Self {
        let state = Arc::new(Mutex::new(BluetoothState::default()));
        let (cmd_sender, cmd_receiver) = channel::<BluetoothCommand>();

        let state_clone = Arc::clone(&state);
        thread::spawn(move || {
            worker_loop(state_clone, cmd_receiver);
        });

        Self { state, cmd_sender }
    }

    pub fn get_state(&self) -> BluetoothState {
        self.state.lock().unwrap().clone()
    }

    pub fn send(&self, cmd: BluetoothCommand) {
        let _ = self.cmd_sender.send(cmd);
    }
}

fn worker_loop(state: Arc<Mutex<BluetoothState>>, rx: Receiver<BluetoothCommand>) {
    // Initial query
    update_hardware_state(&state);

    loop {
        // Handle any pending commands
        while let Ok(cmd) = rx.try_recv() {
            match cmd {
                BluetoothCommand::ToggleSpeakerMode(enable) => {
                    handle_toggle_speaker_mode(&state, enable);
                }
                BluetoothCommand::UnmuteSpeaker => {
                    let _ = Command::new("wpctl")
                        .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "0"])
                        .status();
                    update_audio_state(&state);
                }
                BluetoothCommand::SetVolume(vol) => {
                    let vol_str = format!("{:.2}", vol.clamp(0.0, 1.5));
                    let _ = Command::new("wpctl")
                        .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &vol_str])
                        .status();
                    update_audio_state(&state);
                }
                BluetoothCommand::DisconnectDevice(mac) => {
                    let _ = Command::new("bluetoothctl")
                        .args(["disconnect", &mac])
                        .status();
                }
                BluetoothCommand::Refresh => {
                    update_hardware_state(&state);
                }
            }
        }

        // Periodic hardware state refresh
        update_hardware_state(&state);

        thread::sleep(Duration::from_millis(1500));
    }
}

fn handle_toggle_speaker_mode(state: &Arc<Mutex<BluetoothState>>, enable: bool) {
    if enable {
        // 1. Unblock rfkill if blocked
        let _ = Command::new("rfkill").args(["unblock", "bluetooth"]).status();

        // 2. Power on bluetooth
        let _ = Command::new("bluetoothctl").args(["power", "on"]).status();

        // 3. Set alias to "Ever Dialer PC"
        let _ = Command::new("bluetoothctl")
            .args(["system-alias", "Ever Dialer PC"])
            .status();

        // 4. Make pairable & discoverable without timeout
        let _ = Command::new("bluetoothctl")
            .args(["discoverable-timeout", "0"])
            .status();
        let _ = Command::new("bluetoothctl")
            .args(["discoverable", "on"])
            .status();
        let _ = Command::new("bluetoothctl")
            .args(["pairable", "on"])
            .status();

        // 5. Ensure audio is unmuted so phone sound can play
        let _ = Command::new("wpctl")
            .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "0"])
            .status();

        if let Ok(mut s) = state.lock() {
            s.speaker_mode_enabled = true;
            s.discoverable = true;
            s.powered = true;
            s.status_message = "Discoverable: Phone can connect to Ever Dialer PC".to_string();
        }
    } else {
        // Turn off discoverable mode
        let _ = Command::new("bluetoothctl")
            .args(["discoverable", "off"])
            .status();

        if let Ok(mut s) = state.lock() {
            s.speaker_mode_enabled = false;
            s.discoverable = false;
            s.status_message = "Bluetooth Speaker Mode Off".to_string();
        }
    }
}

fn update_hardware_state(state: &Arc<Mutex<BluetoothState>>) {
    update_bluetooth_state(state);
    update_audio_state(state);
}

fn update_bluetooth_state(state: &Arc<Mutex<BluetoothState>>) {
    // bluetoothctl show
    if let Ok(output) = Command::new("bluetoothctl").args(["show"]).output() {
        let text = String::from_utf8_lossy(&output.stdout);
        let mut powered = false;
        let mut discoverable = false;
        let mut pairable = false;
        let mut alias = "Ever Dialer PC".to_string();

        for line in text.lines() {
            let line = line.trim();
            if line.starts_with("Powered:") {
                powered = line.ends_with("yes");
            } else if line.starts_with("Discoverable:") {
                discoverable = line.ends_with("yes");
            } else if line.starts_with("Pairable:") {
                pairable = line.ends_with("yes");
            } else if line.starts_with("Alias:") {
                if let Some(val) = line.strip_prefix("Alias:") {
                    alias = val.trim().to_string();
                }
            }
        }

        // Query connected devices
        let mut connected_device = None;
        if let Ok(dev_out) = Command::new("bluetoothctl")
            .args(["devices", "Connected"])
            .output()
        {
            let dev_text = String::from_utf8_lossy(&dev_out.stdout);
            for dline in dev_text.lines() {
                let parts: Vec<&str> = dline.split_whitespace().collect();
                if parts.len() >= 3 && parts[0] == "Device" {
                    let mac = parts[1].to_string();
                    let name = parts[2..].join(" ");
                    connected_device = Some(BluetoothDevice {
                        mac,
                        name,
                        connected: true,
                        paired: true,
                    });
                    break;
                }
            }
        }

        if let Ok(mut s) = state.lock() {
            s.powered = powered;
            s.discoverable = discoverable;
            s.pairable = pairable;
            s.alias = alias;
            s.connected_device = connected_device;
        }
    }
}

fn update_audio_state(state: &Arc<Mutex<BluetoothState>>) {
    // wpctl get-volume @DEFAULT_AUDIO_SINK@
    if let Ok(output) = Command::new("wpctl")
        .args(["get-volume", "@DEFAULT_AUDIO_SINK@"])
        .output()
    {
        let text = String::from_utf8_lossy(&output.stdout);
        // Output format: "Volume: 0.40 [MUTED]" or "Volume: 0.75"
        let is_muted = text.contains("[MUTED]");
        let mut volume = 0.5;

        for part in text.split_whitespace() {
            if let Ok(v) = part.parse::<f32>() {
                volume = v;
                break;
            }
        }

        if let Ok(mut s) = state.lock() {
            s.speaker_muted = is_muted;
            s.speaker_volume = volume;
        }
    }
}
