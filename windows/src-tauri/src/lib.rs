pub mod cli;
pub mod hooks;
pub mod server;
pub mod statemap;

use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{Manager, WebviewUrl, WebviewWindowBuilder};

#[tauri::command]
fn list_agents() -> Vec<hooks::AgentInfo> {
    hooks::catalog()
}

#[tauri::command]
fn is_installed(kind: String) -> bool {
    hooks::is_installed(&kind)
}

#[tauri::command]
fn toggle_install(kind: String) -> Result<bool, String> {
    hooks::toggle(&kind)
}

#[tauri::command]
fn open_settings(app: tauri::AppHandle) {
    if let Some(w) = app.get_webview_window("settings") {
        let _ = w.set_focus();
        return;
    }
    let _ = WebviewWindowBuilder::new(&app, "settings", WebviewUrl::App("settings.html".into()))
        .title("AgentPet , Settings")
        .inner_size(440.0, 560.0)
        .resizable(true)
        .build();
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            list_agents,
            is_installed,
            toggle_install,
            open_settings
        ])
        .setup(|app| {
            server::start(app.handle().clone());

            // Tray menu , the pet window is frameless, so this is how you reach
            // Settings or quit the app.
            let settings_i = MenuItem::with_id(app, "settings", "Settings", true, None::<&str>)?;
            let quit_i = MenuItem::with_id(app, "quit", "Quit AgentPet", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&settings_i, &quit_i])?;
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("AgentPet")
                .menu(&menu)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "settings" => open_settings(app.clone()),
                    "quit" => app.exit(0),
                    _ => {}
                })
                .build(app)?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running AgentPet");
}
