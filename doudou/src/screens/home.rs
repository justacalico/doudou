#![allow(non_snake_case)]

use dioxus::prelude::*;
use crate::tauri;

#[component]
pub fn Home() -> Element {
    let mut library = use_signal(|| None::<crate::state::LibraryData>);
    let mut loading = use_signal(|| true);
    let mut error = use_signal(|| None::<String>);

    use_effect(move || {
        spawn(async move {
            let result: Result<crate::state::LibraryData, _> =
                tauri::invoke_tauri("get_library", &()).await;
            loading.set(false);
            match result {
                Ok(data) => library.set(Some(data)),
                Err(e) => error.set(Some(e)),
            }
        });
    });

    let content = match (*loading.read(), error.read().as_ref(), library.read().as_ref()) {
        (true, _, _) => rsx! { div { class: "home-loading", "Loading library..." } },
        (_, Some(msg), _) => rsx! { div { class: "home-error", "Error: {msg}" } },
        (_, _, Some(data)) => {
            let albums: Vec<_> = data.albums.iter().take(12).collect();
            rsx! {
                div { class: "home-content",
                    h2 { class: "section-title", "{crate::l10n::t(\"en\", \"recentlyAdded\")}" }
                    div { class: "card-grid",
                        for album in albums {
                            div { key: "{album.id}", class: "music-card",
                                div { class: "music-card-art",
                                    div { class: "music-card-placeholder", "♪" }
                                }
                                div { class: "music-card-title", "{album.name}" }
                                div { class: "music-card-subtitle",
                                    "{album.artist_name.as_deref().unwrap_or_default()}"
                                }
                            }
                        }
                    }
                }
            }
        }
        _ => rsx! {},
    };

    rsx! {
        div { class: "home-container",
            {content}
        }
    }
}
