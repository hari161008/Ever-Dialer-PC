use egui::{Color32, Margin, Rounding, Stroke, Visuals};
use std::fs;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct MaterialYouPalette {
    pub primary: Color32,
    pub on_primary: Color32,
    pub primary_container: Color32,
    pub on_primary_container: Color32,

    pub surface: Color32,
    pub surface_dim: Color32,
    pub surface_container_low: Color32,
    pub surface_container: Color32,
    pub surface_container_high: Color32,
    pub surface_container_highest: Color32,

    pub on_surface: Color32,
    pub on_surface_variant: Color32,

    pub outline: Color32,
    pub outline_variant: Color32,

    pub error: Color32,
    pub on_error: Color32,
    pub error_container: Color32,

    pub success: Color32,
    pub on_success: Color32,
    pub success_container: Color32,

    pub is_dark: bool,
}

impl MaterialYouPalette {
    /// Detect system colors from KDE Plasma config or desktop portals, falling back to Material 3 defaults.
    pub fn from_system() -> Self {
        let (accent_rgb, is_dark) = Self::detect_system_theme();
        Self::generate_from_accent(accent_rgb, is_dark)
    }

    fn detect_system_theme() -> ((u8, u8, u8), bool) {
        // 1. Try reading KDE config ~/.config/kdeglobals
        if let Some(home) = std::env::var_os("HOME") {
            let kdeglobals = PathBuf::from(home).join(".config/kdeglobals");
            if let Ok(content) = fs::read_to_string(kdeglobals) {
                let mut accent = None;
                let mut is_dark = true;

                for line in content.lines() {
                    let line = line.trim();
                    if line.starts_with("AccentColor=") || line.starts_with("LastUsedCustomAccentColor=") {
                        if let Some(val) = line.split('=').nth(1) {
                            let parts: Vec<u8> = val
                                .split(',')
                                .filter_map(|s| s.trim().parse::<u8>().ok())
                                .collect();
                            if parts.len() == 3 {
                                accent = Some((parts[0], parts[1], parts[2]));
                            }
                        }
                    }
                    if line.starts_with("ColorScheme=") {
                        let lower = line.to_lowercase();
                        if lower.contains("light") && !lower.contains("dark") {
                            is_dark = false;
                        }
                    }
                }

                if let Some(acc) = accent {
                    return (acc, is_dark);
                }
            }
        }

        // Default Material 3 vibrant seed color: Android Teal/Blue or Gold
        ((72, 137, 243), true)
    }

    pub fn generate_from_accent(accent: (u8, u8, u8), is_dark: bool) -> Self {
        let (r, g, b) = accent;

        // Calculate perceived luminance to choose appropriate high contrast on_primary text
        let lum = 0.299 * (r as f32) + 0.587 * (g as f32) + 0.114 * (b as f32);
        let on_primary = if lum > 140.0 {
            Color32::from_rgb(18, 18, 20)
        } else {
            Color32::from_rgb(255, 255, 255)
        };

        if is_dark {
            // Material You Dark Tonal Mapping
            let primary = Color32::from_rgb(r, g, b);
            let primary_container = Color32::from_rgba_premultiplied(
                (r as f32 * 0.35) as u8,
                (g as f32 * 0.35) as u8,
                (b as f32 * 0.35) as u8,
                255,
            );
            let on_primary_container = Color32::from_rgb(
                r.saturating_add(40),
                g.saturating_add(40),
                b.saturating_add(40),
            );

            let surface = Color32::from_rgb(18, 19, 22);
            let surface_dim = Color32::from_rgb(14, 15, 17);
            let surface_container_low = Color32::from_rgb(26, 27, 31);
            let surface_container = Color32::from_rgb(32, 33, 38);
            let surface_container_high = Color32::from_rgb(42, 44, 50);
            let surface_container_highest = Color32::from_rgb(52, 54, 61);

            let on_surface = Color32::from_rgb(226, 226, 230);
            let on_surface_variant = Color32::from_rgb(196, 198, 208);

            let outline = Color32::from_rgb(142, 144, 153);
            let outline_variant = Color32::from_rgb(68, 71, 79);

            let error = Color32::from_rgb(255, 180, 171);
            let on_error = Color32::from_rgb(105, 0, 5);
            let error_container = Color32::from_rgb(147, 0, 10);

            let success = Color32::from_rgb(123, 220, 162);
            let on_success = Color32::from_rgb(0, 57, 28);
            let success_container = Color32::from_rgb(0, 82, 42);

            Self {
                primary,
                on_primary,
                primary_container,
                on_primary_container,
                surface,
                surface_dim,
                surface_container_low,
                surface_container,
                surface_container_high,
                surface_container_highest,
                on_surface,
                on_surface_variant,
                outline,
                outline_variant,
                error,
                on_error,
                error_container,
                success,
                on_success,
                success_container,
                is_dark: true,
            }
        } else {
            // Material You Light Tonal Mapping
            let primary = Color32::from_rgb(r, g, b);
            let primary_container = Color32::from_rgb(
                r.saturating_add(60),
                g.saturating_add(60),
                b.saturating_add(60),
            );
            let on_primary_container = Color32::from_rgb(
                (r as f32 * 0.4) as u8,
                (g as f32 * 0.4) as u8,
                (b as f32 * 0.4) as u8,
            );

            let surface = Color32::from_rgb(251, 248, 253);
            let surface_dim = Color32::from_rgb(220, 218, 223);
            let surface_container_low = Color32::from_rgb(245, 242, 247);
            let surface_container = Color32::from_rgb(238, 235, 241);
            let surface_container_high = Color32::from_rgb(232, 229, 235);
            let surface_container_highest = Color32::from_rgb(226, 223, 229);

            let on_surface = Color32::from_rgb(26, 27, 31);
            let on_surface_variant = Color32::from_rgb(70, 72, 79);

            let outline = Color32::from_rgb(120, 122, 130);
            let outline_variant = Color32::from_rgb(198, 200, 208);

            let error = Color32::from_rgb(186, 26, 26);
            let on_error = Color32::from_rgb(255, 255, 255);
            let error_container = Color32::from_rgb(255, 218, 214);

            let success = Color32::from_rgb(24, 134, 75);
            let on_success = Color32::from_rgb(255, 255, 255);
            let success_container = Color32::from_rgb(175, 242, 199);

            Self {
                primary,
                on_primary,
                primary_container,
                on_primary_container,
                surface,
                surface_dim,
                surface_container_low,
                surface_container,
                surface_container_high,
                surface_container_highest,
                on_surface,
                on_surface_variant,
                outline,
                outline_variant,
                error,
                on_error,
                error_container,
                success,
                on_success,
                success_container,
                is_dark: false,
            }
        }
    }

    /// Apply this palette to the global egui style and visuals
    pub fn apply_to_egui(&self, ctx: &egui::Context) {
        let mut style = (*ctx.style()).clone();

        let mut visuals = if self.is_dark {
            Visuals::dark()
        } else {
            Visuals::light()
        };

        visuals.override_text_color = Some(self.on_surface);
        visuals.panel_fill = self.surface;
        visuals.window_fill = self.surface_container;
        visuals.faint_bg_color = self.surface_container_low;
        visuals.extreme_bg_color = self.surface_dim;

        // Material 3 rounded widgets
        visuals.widgets.noninteractive.rounding = Rounding::same(16.0);
        visuals.widgets.noninteractive.bg_fill = self.surface_container;
        visuals.widgets.noninteractive.bg_stroke = Stroke::new(1.0_f32, self.outline_variant);

        visuals.widgets.inactive.rounding = Rounding::same(20.0);
        visuals.widgets.inactive.bg_fill = self.surface_container_high;
        visuals.widgets.inactive.bg_stroke = Stroke::NONE;

        visuals.widgets.hovered.rounding = Rounding::same(20.0);
        visuals.widgets.hovered.bg_fill = self.surface_container_highest;
        visuals.widgets.hovered.bg_stroke = Stroke::new(1.5_f32, self.primary);

        visuals.widgets.active.rounding = Rounding::same(20.0);
        visuals.widgets.active.bg_fill = self.primary;
        visuals.widgets.active.fg_stroke = Stroke::new(1.5_f32, self.on_primary);

        visuals.selection.bg_fill = self.primary_container;
        visuals.selection.stroke = Stroke::new(1.0_f32, self.primary);

        style.visuals = visuals;
        style.spacing.item_spacing = egui::vec2(12.0, 12.0);
        style.spacing.window_margin = Margin::same(18.0);

        ctx.set_style(style);
    }
}
