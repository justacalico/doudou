#[derive(Debug, Clone)]
pub struct CrossfadeConfig {
    pub enabled: bool,
    pub duration_seconds: u32,
}

impl Default for CrossfadeConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            duration_seconds: 0,
        }
    }
}
