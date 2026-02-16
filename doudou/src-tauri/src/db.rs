//! SQLite cache init (for future use: offline cache, downloads metadata).

use rusqlite::Connection;
use std::path::Path;

pub fn init(db_path: &Path) -> Result<Connection, String> {
    std::fs::create_dir_all(db_path.parent().unwrap_or(Path::new(".")))
        .map_err(|e| e.to_string())?;
    let conn = Connection::open(db_path).map_err(|e| e.to_string())?;
    conn.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS cache (
            key TEXT PRIMARY KEY,
            value BLOB,
            updated INTEGER
        );
        ",
    )
    .map_err(|e| e.to_string())?;
    Ok(conn)
}
