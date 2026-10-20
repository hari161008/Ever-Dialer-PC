use egui::{vec2, Align, FontId, Layout, RichText, Rounding, Stroke, Ui};
use std::time::Duration;

use crate::bluetooth::{BluetoothCommand, BluetoothController, BluetoothState};
use crate::theme::MaterialYouPalette;
use crate::widgets::m3_card::{m3_chip, m3_pill_button, M3Card};
use crate::widgets::m3_switch::M3Switch;

pub struct EverDialerApp {
    palette: MaterialYouPalette,
    bluetooth: BluetoothController,
    toggle_bluetooth_connection: bool,
    last_toggle_state: bool,
}

impl EverDialerApp {
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        let palette = MaterialYouPalette::from_system();
        palette.apply_to_egui(&cc.egui_ctx);

        let bluetooth = BluetoothController::new();

        Self {
            palette,
            bluetooth,
            toggle_bluetooth_connection: false, // Default: OFF as requested
            last_toggle_state: false,
        }
    }
}

impl eframe::App for EverDialerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Request repaint periodically for real-time bluetooth and audio changes
        ctx.request_repaint_after(Duration::from_millis(500));

        let state = self.bluetooth.get_state();

        // Detect if user toggled the switch
        if self.toggle_bluetooth_connection != self.last_toggle_state {
            self.bluetooth.send(BluetoothCommand::ToggleSpeakerMode(
                self.toggle_bluetooth_connection,
            ));
            self.last_toggle_state = self.toggle_bluetooth_connection;
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(12.0);

            // Top Bar
            self.render_top_bar(ui);

            ui.add_space(20.0);

            // Primary Container: "Bluetooth Connection"
            self.render_bluetooth_container(ui, &state);

            ui.add_space(20.0);

            // Audio & Speaker Status Card
            self.render_audio_status_card(ui, &state);
        });
    }
}

impl EverDialerApp {
    fn render_top_bar(&mut self, ui: &mut Ui) {
        ui.horizontal(|ui| {
            // App Title with Material You branding
            ui.heading(
                RichText::new("Ever Dialer PC")
                    .size(24.0)
                    .strong()
                    .color(self.palette.on_surface),
            );

            ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                // System Accent Indicator
                m3_chip(
                    ui,
                    RichText::new("Material You Active").size(12.0),
                    self.palette.primary_container,
                    self.palette.on_primary_container,
                    Some(self.palette.primary),
                );
            });
        });
    }

    fn render_bluetooth_container(&mut self, ui: &mut Ui, state: &BluetoothState) {
        let palette = self.palette.clone();
        M3Card::new(&palette)
            .corner_radius(28.0)
            .show(ui, |ui| {
                // Header row of the container
                ui.horizontal(|ui| {
                    // Bluetooth Icon in a tonal squircle
                    let icon_size = vec2(46.0, 46.0);
                    let (rect, _) = ui.allocate_exact_size(icon_size, egui::Sense::hover());
                    if ui.is_rect_visible(rect) {
                        let bg = if self.toggle_bluetooth_connection {
                            self.palette.primary_container
                        } else {
                            self.palette.surface_container_highest
                        };
                        let fg = if self.toggle_bluetooth_connection {
                            self.palette.on_primary_container
                        } else {
                            self.palette.outline
                        };

                        ui.painter().rect(
                            rect,
                            Rounding::same(14.0),
                            bg,
                            Stroke::NONE,
                        );

                        // Draw Bluetooth glyph symbol
                        let center = rect.center();
                        let p_top = center + vec2(0.0, -12.0);
                        let p_bot = center + vec2(0.0, 12.0);
                        let p_tr = center + vec2(8.0, -6.0);
                        let p_br = center + vec2(8.0, 6.0);
                        let p_tl = center + vec2(-7.0, -6.0);
                        let p_bl = center + vec2(-7.0, 6.0);

                        let stroke = Stroke::new(2.4_f32, fg);
                        ui.painter().line_segment([p_top, p_bot], stroke);
                        ui.painter().line_segment([p_tl, p_br], stroke);
                        ui.painter().line_segment([p_br, center], stroke);
                        ui.painter().line_segment([center, p_tr], stroke);
                        ui.painter().line_segment([p_tr, p_bl], stroke);
                    }

                    ui.add_space(8.0);

                    // Title & Description
                    ui.vertical(|ui| {
                        ui.label(
                            RichText::new("Bluetooth Connection")
                                .font(FontId::proportional(20.0))
                                .strong()
                                .color(self.palette.on_surface),
                        );
                        ui.label(
                            RichText::new("Use this PC as a wireless media speaker for your phone")
                                .font(FontId::proportional(13.0))
                                .color(self.palette.on_surface_variant),
                        );
                    });

                    // Right-aligned Material 3 Switch toggle
                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        ui.add(M3Switch::new(
                            &mut self.toggle_bluetooth_connection,
                            &self.palette,
                        ));
                    });
                });

                ui.add_space(14.0);
                ui.separator();
                ui.add_space(14.0);

                // Container Details depending on toggle state
                if self.toggle_bluetooth_connection {
                    self.render_active_container_content(ui, state);
                } else {
                    self.render_inactive_container_content(ui);
                }
            });
    }

    fn render_active_container_content(&mut self, ui: &mut Ui, state: &BluetoothState) {
        ui.horizontal(|ui| {
            if let Some(device) = &state.connected_device {
                m3_chip(
                    ui,
                    RichText::new(format!("Connected: {}", device.name)).strong(),
                    self.palette.success_container,
                    self.palette.on_success,
                    Some(self.palette.success),
                );
            } else {
                m3_chip(
                    ui,
                    "Discoverable — Ready for Phone",
                    self.palette.primary_container,
                    self.palette.on_primary_container,
                    Some(self.palette.primary),
                );
            }

            ui.add_space(10.0);
            ui.label(
                RichText::new(format!("Broadcast Name: {}", state.alias))
                    .color(self.palette.on_surface_variant)
                    .size(13.0),
            );
        });

        ui.add_space(12.0);

        if let Some(device) = &state.connected_device {
            // Connected Phone Card
            M3Card::new(&self.palette)
                .elevated(true)
                .corner_radius(18.0)
                .show(ui, |ui| {
                    ui.horizontal(|ui| {
                        ui.vertical(|ui| {
                            ui.label(
                                RichText::new(format!("📱 {}", device.name))
                                    .size(16.0)
                                    .strong()
                                    .color(self.palette.on_surface),
                            );
                            ui.label(
                                RichText::new(format!("MAC: {}", device.mac))
                                    .size(12.0)
                                    .color(self.palette.on_surface_variant),
                            );
                            ui.label(
                                RichText::new("Streaming audio to PC speakers via PipeWire A2DP")
                                    .size(12.0)
                                    .color(self.palette.primary),
                            );
                        });

                        ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                            if m3_pill_button(ui, "Disconnect", &self.palette, false).clicked() {
                                self.bluetooth.send(BluetoothCommand::DisconnectDevice(
                                    device.mac.clone(),
                                ));
                            }
                        });
                    });
                });
        } else {
            // Pairing Instructions Card
            M3Card::new(&self.palette)
                .elevated(true)
                .corner_radius(18.0)
                .show(ui, |ui| {
                    ui.vertical(|ui| {
                        ui.label(
                            RichText::new("How to connect your phone:")
                                .size(14.0)
                                .strong()
                                .color(self.palette.on_surface),
                        );
                        ui.add_space(6.0);
                        ui.label(
                            RichText::new("1. On your phone, go to Settings > Bluetooth.")
                                .size(13.0)
                                .color(self.palette.on_surface_variant),
                        );
                        ui.label(
                            RichText::new(format!(
                                "2. Select \"{}\" in the list of available devices.",
                                state.alias
                            ))
                            .size(13.0)
                            .color(self.palette.on_surface_variant),
                        );
                        ui.label(
                            RichText::new(
                                "3. Confirm the pairing prompt on your phone if requested.",
                            )
                            .size(13.0)
                            .color(self.palette.on_surface_variant),
                        );
                        ui.label(
                            RichText::new(
                                "4. Play any media (music, YouTube, videos) — sound will stream here!",
                            )
                            .size(13.0)
                            .color(self.palette.primary),
                        );
                    });
                });
        }
    }

    fn render_inactive_container_content(&mut self, ui: &mut Ui) {
        ui.horizontal(|ui| {
            m3_chip(
                ui,
                "Media Speaker Mode Disabled",
                self.palette.surface_container_highest,
                self.palette.outline,
                None,
            );
        });

        ui.add_space(8.0);
        ui.label(
            RichText::new(
                "Turn ON the toggle above to make this PC discoverable and accept wireless audio streaming from your mobile device.",
            )
            .size(13.0)
            .color(self.palette.on_surface_variant),
        );
    }

    fn render_audio_status_card(&mut self, ui: &mut Ui, state: &BluetoothState) {
        let palette = self.palette.clone();
        M3Card::new(&palette)
            .corner_radius(20.0)
            .show(ui, |ui| {
                ui.horizontal(|ui| {
                    ui.label(
                        RichText::new("🔊 PC Output Audio")
                            .size(15.0)
                            .strong()
                            .color(palette.on_surface),
                    );

                    ui.with_layout(Layout::right_to_left(Align::Center), |ui| {
                        if state.speaker_muted {
                            if m3_pill_button(ui, "Unmute Speakers", &palette, true).clicked()
                            {
                                self.bluetooth.send(BluetoothCommand::UnmuteSpeaker);
                            }
                            m3_chip(
                                ui,
                                "MUTED",
                                self.palette.error_container,
                                self.palette.on_error,
                                Some(self.palette.error),
                            );
                        } else {
                            m3_chip(
                                ui,
                                format!("Volume: {:.0}%", state.speaker_volume * 100.0),
                                self.palette.surface_container_highest,
                                self.palette.on_surface,
                                None,
                            );
                        }
                    });
                });

                if state.speaker_muted {
                    ui.add_space(8.0);
                    ui.label(
                        RichText::new(
                            "⚠️ Your laptop speaker is currently muted in PipeWire. Click 'Unmute Speakers' so sounds from your phone will be audible.",
                        )
                        .size(12.0)
                        .color(self.palette.error),
                    );
                }
            });
    }
}
