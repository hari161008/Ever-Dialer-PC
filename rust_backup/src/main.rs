mod app;
mod bluetooth;
mod theme;
mod widgets;

use app::EverDialerApp;

fn main() -> eframe::Result<()> {
    let native_options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("Ever Dialer PC")
            .with_inner_size([560.0, 520.0])
            .with_min_inner_size([460.0, 420.0])
            .with_resizable(true),
        ..Default::default()
    };

    eframe::run_native(
        "Ever Dialer PC",
        native_options,
        Box::new(|cc| Ok(Box::new(EverDialerApp::new(cc)))),
    )
}
