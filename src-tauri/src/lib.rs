use std::{
    fs,
    path::PathBuf,
    process::Command,
    sync::{Arc, Mutex},
};

use tauri::image::Image;
use tauri::menu::CheckMenuItem;
use tauri::menu::Menu;
use tauri::menu::MenuItem;
use tauri::menu::PredefinedMenuItem;
use tauri::tray::TrayIconBuilder;
use tauri::{ActivationPolicy, Emitter, Manager};

const LAB_URL: &str = "https://hazakuralab.pages.dev";

#[derive(Clone, serde::Deserialize, serde::Serialize)]
struct AppSettings {
    night: bool,
    mode: String,
    focus: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            night: false,
            mode: "sakura".to_string(),
            focus: "normal".to_string(),
        }
    }
}

impl AppSettings {
    fn sanitized(mut self) -> Self {
        if !matches!(
            self.mode.as_str(),
            "sakura" | "magic" | "spark" | "hazakura"
        ) {
            self.mode = "sakura".to_string();
        }
        if !matches!(self.focus.as_str(), "quiet" | "normal" | "play") {
            self.focus = "normal".to_string();
        }
        self
    }
}

fn settings_path(app: &tauri::App) -> Option<PathBuf> {
    app.path()
        .app_config_dir()
        .ok()
        .map(|dir| dir.join("settings.json"))
}

fn load_settings(app: &tauri::App) -> AppSettings {
    let Some(path) = settings_path(app) else {
        return AppSettings::default();
    };

    fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str::<AppSettings>(&text).ok())
        .unwrap_or_default()
        .sanitized()
}

fn save_settings(path: Option<&PathBuf>, settings: &AppSettings) {
    let Some(path) = path else {
        return;
    };

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).ok();
    }
    if let Ok(text) = serde_json::to_string_pretty(settings) {
        fs::write(path, text).ok();
    }
}

fn emit_settings(window: &tauri::WebviewWindow, settings: &AppSettings) {
    window.emit("sakura-night-changed", settings.night).ok();
    window
        .emit("sakura-mode-changed", settings.mode.as_str())
        .ok();
    window
        .emit("sakura-focus-changed", settings.focus.as_str())
        .ok();
}

fn open_lab_site() {
    Command::new("open").arg(LAB_URL).spawn().ok();
}

fn show_about_dialog() {
    let message = "display dialog \"Sakura Sky\\n\\n葉桜ラボ - とことんAIで遊ぶ研究所\\nAIで遊ぶ、小さなデスクトップ演出アプリです。\\n\\n未署名配布版のため、環境によって起動に追加操作が必要な場合があります。\" buttons {\"OK\"} default button \"OK\" with title \"Sakura Sky\"";
    Command::new("osascript").args(["-e", message]).spawn().ok();
}

fn create_tray(app: &mut tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    let menu = Menu::new(app)?;
    let app_handle = app.app_handle().clone();
    let settings = load_settings(app);
    let settings_file = settings_path(app);

    let brand_item = MenuItem::with_id(
        app,
        "brand",
        "葉桜ラボ - とことんAIで遊ぶ研究所",
        false,
        None::<String>,
    )?;
    let controls_label = MenuItem::with_id(app, "controls_label", "操作", false, None::<String>)?;
    let pause_item = MenuItem::with_id(app, "pause", "停止", true, None::<String>)?;
    let night_item = MenuItem::with_id(
        app,
        "night",
        if settings.night {
            "夜桜背景を隠す"
        } else {
            "夜桜背景を表示"
        },
        true,
        None::<String>,
    )?;
    let mode_label = MenuItem::with_id(app, "mode_label", "モードを選択", false, None::<String>)?;
    let sakura_item = CheckMenuItem::with_id(
        app,
        "mode_sakura",
        "SAKURA",
        true,
        settings.mode == "sakura",
        None::<String>,
    )?;
    let magic_item = CheckMenuItem::with_id(
        app,
        "mode_magic",
        "Magic",
        true,
        settings.mode == "magic",
        None::<String>,
    )?;
    let spark_item = CheckMenuItem::with_id(
        app,
        "mode_spark",
        "Spark",
        true,
        settings.mode == "spark",
        None::<String>,
    )?;
    let hazakura_item = CheckMenuItem::with_id(
        app,
        "mode_hazakura",
        "Hazakura",
        true,
        settings.mode == "hazakura",
        None::<String>,
    )?;
    let focus_label = MenuItem::with_id(app, "focus_label", "演出の強さ", false, None::<String>)?;
    let focus_quiet_item = CheckMenuItem::with_id(
        app,
        "focus_quiet",
        "控えめ",
        true,
        settings.focus == "quiet",
        None::<String>,
    )?;
    let focus_normal_item = CheckMenuItem::with_id(
        app,
        "focus_normal",
        "標準",
        true,
        settings.focus == "normal",
        None::<String>,
    )?;
    let focus_play_item = CheckMenuItem::with_id(
        app,
        "focus_play",
        "遊びすぎ",
        true,
        settings.focus == "play",
        None::<String>,
    )?;
    let reset_item = MenuItem::with_id(app, "reset", "設定を初期化", true, None::<String>)?;
    let site_item = MenuItem::with_id(app, "site", "葉桜ラボを開く", true, None::<String>)?;
    let about_item = MenuItem::with_id(app, "about", "このアプリについて", true, None::<String>)?;
    let quit_item = MenuItem::with_id(app, "quit", "終了", true, None::<String>)?;
    let section_after_brand = PredefinedMenuItem::separator(app)?;
    let section_after_controls = PredefinedMenuItem::separator(app)?;
    let section_after_modes = PredefinedMenuItem::separator(app)?;
    let section_after_focus = PredefinedMenuItem::separator(app)?;
    let section_before_quit = PredefinedMenuItem::separator(app)?;

    menu.append(&brand_item)?;
    menu.append(&section_after_brand)?;
    menu.append(&controls_label)?;
    menu.append(&pause_item)?;
    menu.append(&night_item)?;
    menu.append(&section_after_controls)?;
    menu.append(&mode_label)?;
    menu.append(&sakura_item)?;
    menu.append(&magic_item)?;
    menu.append(&spark_item)?;
    menu.append(&hazakura_item)?;
    menu.append(&section_after_modes)?;
    menu.append(&focus_label)?;
    menu.append(&focus_quiet_item)?;
    menu.append(&focus_normal_item)?;
    menu.append(&focus_play_item)?;
    menu.append(&section_after_focus)?;
    menu.append(&reset_item)?;
    menu.append(&site_item)?;
    menu.append(&about_item)?;
    menu.append(&section_before_quit)?;
    menu.append(&quit_item)?;

    // Resolve icon path from resource directory (inside .app bundle)
    let resource_dir = app.path().resource_dir()?;
    let icon_path = PathBuf::from(&resource_dir).join("icons").join("icon.png");

    let exe_dir = std::env::current_exe()?.parent().unwrap().to_path_buf();
    let dev_icon_path = exe_dir
        .join("..")
        .join("..")
        .join("icons")
        .join("icon.png")
        .canonicalize();

    let icon_path = if icon_path.exists() {
        icon_path
    } else if let Ok(p) = dev_icon_path {
        p
    } else {
        PathBuf::from("icons/icon.png")
    };

    let image = Image::from_path(&icon_path)?;

    let _tray = TrayIconBuilder::new()
        .menu(&menu)
        .icon(image)
        .tooltip("Sakura Sky by 葉桜ラボ - とことんAIで遊ぶ研究所")
        .build(app)?;

    let app_handle2 = app_handle.clone();
    if let Some(win) = app_handle.get_webview_window("main") {
        let initial_settings = settings.clone();
        std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_millis(180));
            emit_settings(&win, &initial_settings);
        });
    }

    let state = Arc::new(Mutex::new((false, settings)));
    app.on_menu_event(move |_app, item| {
        let id = item.id.as_ref();
        if id == "pause" {
            if let Ok(mut state) = state.lock() {
                state.0 = !state.0;
                pause_item
                    .set_text(if state.0 { "再開" } else { "停止" })
                    .ok();
                if let Some(win) = app_handle2.get_webview_window("main") {
                    win.emit("sakura-paused-changed", state.0).ok();
                }
            }
        } else if id == "night" {
            if let Ok(mut state) = state.lock() {
                state.1.night = !state.1.night;
                night_item
                    .set_text(if state.1.night {
                        "夜桜背景を隠す"
                    } else {
                        "夜桜背景を表示"
                    })
                    .ok();
                save_settings(settings_file.as_ref(), &state.1);
                if let Some(win) = app_handle2.get_webview_window("main") {
                    win.emit("sakura-night-changed", state.1.night).ok();
                }
            }
        } else if matches!(
            id,
            "mode_sakura" | "mode_magic" | "mode_spark" | "mode_hazakura"
        ) {
            if let Ok(mut state) = state.lock() {
                let mode = match id {
                    "mode_magic" => "magic",
                    "mode_spark" => "spark",
                    "mode_hazakura" => "hazakura",
                    _ => "sakura",
                };
                state.1.mode = mode.to_string();
                sakura_item.set_checked(mode == "sakura").ok();
                magic_item.set_checked(mode == "magic").ok();
                spark_item.set_checked(mode == "spark").ok();
                hazakura_item.set_checked(mode == "hazakura").ok();
                save_settings(settings_file.as_ref(), &state.1);
                if let Some(win) = app_handle2.get_webview_window("main") {
                    win.emit("sakura-mode-changed", mode).ok();
                }
            }
        } else if matches!(id, "focus_quiet" | "focus_normal" | "focus_play") {
            if let Ok(mut state) = state.lock() {
                let focus = match id {
                    "focus_quiet" => "quiet",
                    "focus_play" => "play",
                    _ => "normal",
                };
                state.1.focus = focus.to_string();
                focus_quiet_item.set_checked(focus == "quiet").ok();
                focus_normal_item.set_checked(focus == "normal").ok();
                focus_play_item.set_checked(focus == "play").ok();
                save_settings(settings_file.as_ref(), &state.1);
                if let Some(win) = app_handle2.get_webview_window("main") {
                    win.emit("sakura-focus-changed", focus).ok();
                }
            }
        } else if id == "reset" {
            if let Ok(mut state) = state.lock() {
                state.0 = false;
                state.1 = AppSettings::default();
                pause_item.set_text("停止").ok();
                night_item.set_text("夜桜背景を表示").ok();
                sakura_item.set_checked(true).ok();
                magic_item.set_checked(false).ok();
                spark_item.set_checked(false).ok();
                hazakura_item.set_checked(false).ok();
                focus_quiet_item.set_checked(false).ok();
                focus_normal_item.set_checked(true).ok();
                focus_play_item.set_checked(false).ok();
                save_settings(settings_file.as_ref(), &state.1);
                if let Some(win) = app_handle2.get_webview_window("main") {
                    win.emit("sakura-paused-changed", false).ok();
                    emit_settings(&win, &state.1);
                }
            }
        } else if id == "site" {
            open_lab_site();
        } else if id == "about" {
            show_about_dialog();
        } else if id == "quit" {
            std::process::exit(0);
        }
    });

    Ok(())
}

fn start_cursor_tracking(window: tauri::WebviewWindow) {
    std::thread::spawn(move || loop {
        if let (Ok(cursor), Ok(position), Ok(scale_factor)) = (
            window.cursor_position(),
            window.outer_position(),
            window.scale_factor(),
        ) {
            let x = (cursor.x - position.x as f64) / scale_factor;
            let y = (cursor.y - position.y as f64) / scale_factor;
            window.emit("sakura-cursor-moved", (x, y)).ok();
        }

        std::thread::sleep(std::time::Duration::from_millis(24));
    });
}

pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            app.set_activation_policy(ActivationPolicy::Accessory);

            let window = app.get_webview_window("main").unwrap();
            window.set_ignore_cursor_events(true).ok();
            window.set_shadow(false).ok();
            window.set_visible_on_all_workspaces(true).ok();
            if let Ok(Some(monitor)) = window.current_monitor() {
                window.set_position(*monitor.position()).ok();
                window.set_size(*monitor.size()).ok();
            }
            start_cursor_tracking(window);

            create_tray(app)?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
