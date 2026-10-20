use egui::{vec2, Color32, Pos2, Response, Rounding, Sense, Stroke, Ui, Widget};
use crate::theme::MaterialYouPalette;

/// Android Material You (Material 3) Toggle Switch.
/// Spec:
/// - Track: 52 x 32 dp, 16 dp corner radius.
/// - Thumb: animated between 16 dp (unselected) and 24 dp (selected).
/// - Dynamic tonal colors based on Material You system palette.
pub struct M3Switch<'a> {
    pub selected: &'a mut bool,
    pub palette: &'a MaterialYouPalette,
}

impl<'a> M3Switch<'a> {
    pub fn new(selected: &'a mut bool, palette: &'a MaterialYouPalette) -> Self {
        Self { selected, palette }
    }
}

impl<'a> Widget for M3Switch<'a> {
    fn ui(self, ui: &mut Ui) -> Response {
        let desired_size = vec2(52.0, 32.0);
        let (rect, mut response) = ui.allocate_exact_size(desired_size, Sense::click());

        if response.clicked() {
            *self.selected = !*self.selected;
            response.mark_changed();
        }

        if ui.is_rect_visible(rect) {
            let t = ui.ctx().animate_bool(response.id, *self.selected);

            // Interpolate Track Color
            let track_off_color = self.palette.surface_container_highest;
            let track_on_color = self.palette.primary;
            let track_color = lerp_color(track_off_color, track_on_color, t);

            // Interpolate Track Stroke
            let stroke_off_color = self.palette.outline;
            let stroke_width = (1.0 - t) * 2.0;
            let track_stroke = if stroke_width > 0.05 {
                Stroke::new(stroke_width, stroke_off_color)
            } else {
                Stroke::NONE
            };

            // Draw track (Pill shape)
            ui.painter().rect(
                rect,
                Rounding::same(16.0),
                track_color,
                track_stroke,
            );

            // Thumb calculation:
            // Off: center x = min.x + 14.0, radius = 8.0 (diameter 16.0)
            // On: center x = max.x - 16.0, radius = 12.0 (diameter 24.0)
            let off_x = rect.min.x + 14.0;
            let on_x = rect.max.x - 16.0;
            let thumb_x = egui::lerp(off_x..=on_x, t);
            let thumb_center = Pos2::new(thumb_x, rect.center().y);

            let thumb_radius = egui::lerp(8.0..=12.0, t);

            let thumb_off_color = self.palette.outline;
            let thumb_on_color = self.palette.on_primary;
            let thumb_color = lerp_color(thumb_off_color, thumb_on_color, t);

            // State layer (hover ripple circle)
            if response.hovered() {
                let hover_color = if *self.selected {
                    Color32::from_rgba_premultiplied(
                        self.palette.primary.r(),
                        self.palette.primary.g(),
                        self.palette.primary.b(),
                        30,
                    )
                } else {
                    Color32::from_rgba_premultiplied(
                        self.palette.outline.r(),
                        self.palette.outline.g(),
                        self.palette.outline.b(),
                        30,
                    )
                };
                ui.painter().circle_filled(thumb_center, 18.0, hover_color);
            }

            // Draw thumb
            ui.painter().circle_filled(thumb_center, thumb_radius, thumb_color);

            // Subtle checkmark when active
            if t > 0.75 {
                let icon_alpha = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
                let icon_color = Color32::from_rgba_premultiplied(
                    self.palette.primary.r(),
                    self.palette.primary.g(),
                    self.palette.primary.b(),
                    (255.0 * icon_alpha) as u8,
                );
                // Draw a mini checkmark inside thumb
                let p1 = thumb_center + vec2(-4.0, 0.0);
                let p2 = thumb_center + vec2(-1.5, 3.0);
                let p3 = thumb_center + vec2(4.0, -3.0);
                ui.painter().line_segment([p1, p2], Stroke::new(1.8_f32, icon_color));
                ui.painter().line_segment([p2, p3], Stroke::new(1.8_f32, icon_color));
            }
        }

        response
    }
}

fn lerp_color(c1: Color32, c2: Color32, t: f32) -> Color32 {
    let t = t.clamp(0.0, 1.0);
    let r = egui::lerp(c1.r() as f32..=c2.r() as f32, t) as u8;
    let g = egui::lerp(c1.g() as f32..=c2.g() as f32, t) as u8;
    let b = egui::lerp(c1.b() as f32..=c2.b() as f32, t) as u8;
    let a = egui::lerp(c1.a() as f32..=c2.a() as f32, t) as u8;
    Color32::from_rgba_premultiplied(r, g, b, a)
}
