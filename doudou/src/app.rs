#![allow(non_snake_case)]

use dioxus::prelude::*;
use crate::screens::{Home, Login, Settings};
use crate::tauri;

#[component]
pub fn App() -> Element {
    let mut server = use_signal(|| None::<serde_json::Value>);
    let mut loading = use_signal(|| true);
    let mut refresh = use_signal(|| 0_u32);
    let mut page = use_signal(|| "home");

    use_effect(move || {
        let _ = *refresh.read();
        loading.set(true);
        spawn(async move {
            let result: Result<Option<serde_json::Value>, _> =
                tauri::invoke_tauri("get_server", &()).await;
            loading.set(false);
            if let Ok(s) = result {
                server.set(s);
            }
        });
    });

    rsx! {
        link { rel: "stylesheet", href: "styles.css" }
        main { class: "app-root",
            if *loading.read() && server.read().is_none() {
                div { class: "app-loading",
                    div { class: "spinner" }
                    p { "Loading..." }
                }
            } else if server.read().is_some() {
                div { class: "app-layout",
                    aside { class: "sidebar",
                        div { class: "sidebar-brand", "Doudou" }
                        nav { class: "sidebar-nav",
                            a {
                                class: if *page.read() == "home" { "sidebar-link active" } else { "sidebar-link" },
                                href: "#",
                                onclick: move |_| page.set("home"),
                                "Home"
                            }
                            a {
                                class: if *page.read() == "settings" { "sidebar-link active" } else { "sidebar-link" },
                                href: "#",
                                onclick: move |_| page.set("settings"),
                                "Settings"
                            }
                        }
                    }
                    div { class: "app-content",
                        if *page.read() == "settings" {
                            Settings {}
                        } else {
                            Home {}
                        }
                    }
                    footer { class: "mini-player",
                        crate::components::MiniPlayer {}
                    }
                }
            } else {
                Login {
                    on_success: move |_| {
                        let r = refresh.read().saturating_add(1);
                        refresh.set(r);
                    }
                }
            }
        }
    }
}
