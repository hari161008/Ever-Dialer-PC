use egui::{vec2, Color32, Frame, Margin, Response, Rounding, Sense, Stroke, Ui, WidgetText};
use crate::theme::MaterialYouPalette;

/// Material You Card Container
pub struct M3Card<'a> {
    pub palette: &'a MaterialYouPalette,
    pub elevated: bool,
    pub corner_radius: f32,
}

impl<'a> M3Card<'a> {
    pub fn new(palette: &'a MaterialYouPalette) -> Self {
        Self {
            palette,
            elevated: false,
            corner_radius: 24.0,
        }
    }

    pub fn elevated(mut self, elevated: bool) -> Self {
        self.elevated = elevated;
        self
    }

    pub fn corner_radius(mut self, radius: f32) -> Self {
        self.corner_radius = radius;
        self
    }

    pub fn show<R>(self, ui: &mut Ui, add_contents: impl FnOnce(&mut Ui) -> R) -> R {
        let fill = if self.elevated {
            self.palette.surface_container_high
        } else {
            self.palette.surface_container
        };

        let stroke = Stroke::new(1.0_f32, self.palette.outline_variant);

        Frame::none()
            .fill(fill)
            .rounding(Rounding::same(self.corner_radius))
            .stroke(stroke)
            .inner_margin(Margin::same(20.0))
            .show(ui, add_contents)
            .inner
    }
}

/// Helper to render a Material You Pill Chip (e.g. status badge)
pub fn m3_chip(
    ui: &mut Ui,
    text: impl Into<WidgetText>,
    bg_color: Color32,
    fg_color: Color32,
    dot_color: Option<Color32>,
) -> Response {
    let padding = vec2(12.0, 6.0);
    let label = text.into();

    let font_id = egui::TextStyle::Body.resolve(ui.style());
    let galley = label.into_galley(
        ui,
        Some(egui::TextWrapMode::Extend),
        f32::INFINITY,
        font_id,
    );

    let mut width = galley.size().x + padding.x * 2.0;
    if dot_color.is_some() {
        width += 14.0;
    }
    let height = galley.size().y.max(18.0) + padding.y * 2.0;
    let desired_size = vec2(width, height);

    let (rect, response) = ui.allocate_exact_size(desired_size, Sense::hover());

    if ui.is_rect_visible(rect) {
        ui.painter().rect(
            rect,
            Rounding::same(999.0),
            bg_color,
            Stroke::NONE,
        );

        let mut text_x = rect.min.x + padding.x;

        if let Some(dot) = dot_color {
            let dot_center = egui::pos2(rect.min.x + padding.x + 4.0, rect.center().y);
            ui.painter().circle_filled(dot_center, 4.0, dot);
            text_x += 14.0;
        }

        let text_pos = egui::pos2(text_x, rect.center().y - galley.size().y / 2.0);
        ui.painter().galley(text_pos, galley, fg_color);
    }

    response
}

/// Helper for Material 3 Pill Button
pub fn m3_pill_button(
    ui: &mut Ui,
    text: impl Into<WidgetText>,
    palette: &MaterialYouPalette,
    primary: bool,
) -> Response {
    let label = text.into();
    let font_id = egui::TextStyle::Button.resolve(ui.style());
    let galley = label.into_galley(
        ui,
        Some(egui::TextWrapMode::Extend),
        f32::INFINITY,
        font_id,
    );

    let padding = vec2(20.0, 10.0);
    let desired_size = vec2(
        galley.size().x + padding.x * 2.0,
        galley.size().y + padding.y * 2.0,
    );

    let (rect, response) = ui.allocate_exact_size(desired_size, Sense::click());

    if ui.is_rect_visible(rect) {
        let (bg, fg, stroke) = if primary {
            (palette.primary, palette.on_primary, Stroke::NONE)
        } else if response.hovered() {
            (
                palette.surface_container_highest,
                palette.on_surface,
                Stroke::new(1.0_f32, palette.outline),
            )
        } else {
            (
                palette.surface_container_high,
                palette.on_surface,
                Stroke::new(1.0_f32, palette.outline_variant),
            )
        };

        ui.painter().rect(
            rect,
            Rounding::same(999.0),
            bg,
            stroke,
        );

        let text_pos = egui::pos2(
            rect.center().x - galley.size().x / 2.0,
            rect.center().y - galley.size().y / 2.0,
        );
        ui.painter().galley(text_pos, galley, fg);
    }

    response
}
