//! Call Tauri commands from Dioxus (WASM).

use serde::Serialize;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = ["window", "__TAURI__", "core"])]
    async fn invoke(cmd: &str, args: JsValue) -> JsValue;
}

pub async fn invoke_tauri<T, R>(cmd: &str, args: &T) -> Result<R, String>
where
    T: Serialize + ?Sized,
    R: serde::de::DeserializeOwned,
{
    let args_js = serde_wasm_bindgen::to_value(args).map_err(|e| e.to_string())?;
    let result_js = invoke(cmd, args_js).await;
    if result_js.is_null() || result_js.is_undefined() {
        return Err("No response".to_string());
    }
    serde_wasm_bindgen::from_value(result_js).map_err(|e| e.to_string())
}

pub async fn invoke_tauri_unit<T>(cmd: &str, args: &T) -> Result<(), String>
where
    T: Serialize + ?Sized,
{
    let _: Option<()> = invoke_tauri(cmd, args).await?;
    Ok(())
}
