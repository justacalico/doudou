#![allow(non_snake_case)]

use dioxus::prelude::*;
use crate::tauri;

#[derive(serde::Serialize)]
struct LoginArgs {
    server_url: String,
    username: String,
    password: String,
}

#[component]
pub fn Login(on_success: EventHandler<()>) -> Element {
    let mut server_url = use_signal(|| String::new());
    let mut username = use_signal(|| String::new());
    let mut password = use_signal(|| String::new());
    let mut error = use_signal(|| None::<String>);
    let mut loading = use_signal(|| false);

    let submit = move |_: FormEvent| {
        let server_url = server_url.read().clone();
        let username = username.read().clone();
        let password = password.read().clone();
        if server_url.is_empty() || username.is_empty() || password.is_empty() {
            error.set(Some("Please fill all fields".to_string()));
            return;
        }
        loading.set(true);
        error.set(None);
        spawn(async move {
            let args = LoginArgs {
                server_url: server_url.clone(),
                username: username.clone(),
                password: password.clone(),
            };
            let result: Result<serde_json::Value, _> = tauri::invoke_tauri("login", &args).await;
            loading.set(false);
            match result {
                Ok(_) => on_success.call(()),
                Err(e) => error.set(Some(e)),
            }
        });
    };

    rsx! {
        div { class: "login-container",
            div { class: "login-card",
                h1 { class: "login-title", "{crate::l10n::t(\"en\", \"signIn\")}" }
                p { class: "login-subtitle", "{crate::l10n::t(\"en\", \"connectJellyfin\")}" }
                form { onsubmit: submit, class: "login-form",
                    if let Some(msg) = error.read().as_ref() {
                        div { class: "login-error", "{msg}" }
                    }
                    input {
                        class: "login-input",
                        r#type: "text",
                        placeholder: "Server URL (e.g. https://jellyfin.example.com)",
                        value: "{server_url}",
                        oninput: move |e| server_url.set(e.value())
                    }
                    input {
                        class: "login-input",
                        r#type: "text",
                        placeholder: "Username",
                        value: "{username}",
                        oninput: move |e| username.set(e.value())
                    }
                    input {
                        class: "login-input",
                        r#type: "password",
                        placeholder: "Password",
                        value: "{password}",
                        oninput: move |e| password.set(e.value())
                    }
                    button {
                        class: "login-button",
                        r#type: "submit",
                        disabled: *loading.read(),
                        if *loading.read() { "Signing in..." } else { "Sign in" }
                    }
                }
            }
        }
    }
}
