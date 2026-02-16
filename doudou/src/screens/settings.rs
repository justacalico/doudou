#![allow(non_snake_case)]

use dioxus::prelude::*;
use crate::tauri;

#[derive(Clone, serde::Serialize, serde::Deserialize)]
struct AppSettings {
    theme_mode: Option<String>,
    accent_color: Option<String>,
    locale: Option<String>,
}

#[component]
pub fn Settings() -> Element {
    let mut settings = use_signal(|| None::<AppSettings>);
    let mut loading = use_signal(|| true);

    use_effect(move || {
        spawn(async move {
            let result: Result<AppSettings, _> =
                tauri::invoke_tauri("get_settings", &()).await;
            loading.set(false);
            settings.set(result.ok());
        });
    });

    let save = move |theme: Option<String>, locale: Option<String>| {
        let mut s = settings.read().clone().unwrap_or(AppSettings {
            theme_mode: None,
            accent_color: None,
            locale: None,
        });
        s.theme_mode = theme;
        s.locale = locale;
        let s_clone = s.clone();
        spawn(async move {
            let _: Result<(), _> = tauri::invoke_tauri("set_settings", &s_clone).await;
        });
    };

    rsx! {
        div { class: "settings-container",
            if *loading.read() {
                p { "Loading settings..." }
            } else {
                h2 { "Settings" }
                p { class: "settings-note", "Theme and locale are saved automatically when changed." }
                div { class: "settings-actions",
                    button {
                        class: "login-button",
                        onclick: move |_| save(Some("dark".into()), None),
                        "Set dark theme"
                    }
                    button {
                        class: "login-button",
                        onclick: move |_| save(Some("light".into()), None),
                        "Set light theme"
                    }
                    button {
                        class: "login-button",
                        onclick: move |_| save(None, Some("en".into())),
                        "Set locale: English"
                    }
                }
            }
        }
    }
}
