"""Compile and exercise the pinned client's actual configuration getters.

The surrounding state uses std locks and synthetic profiles; no GUI, private
input, identity, or real RustDesk configuration is accessed.
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path


def function(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


source = Path(sys.argv[1]).read_text()
with tempfile.TemporaryDirectory() as scratch:
    directory = Path(scratch)
    settings = directory / "server-options"
    getters = "\n".join(
        function(source, f"    pub fn {name}(")
        for name in (
            "get_options",
            "get_option",
            "get_rendezvous_server",
            "get_rendezvous_servers",
        )
    )
    helper = (
        function(source, "fn managed_server_options(")
        if "fn managed_server_options(" in source
        else ""
    )
    helper = helper.replace('"/run/rustdesk/server-options"', json.dumps(str(settings)))
    harness = r"""
use std::collections::HashMap;
use std::fs;
use std::sync::{LazyLock, RwLock};

#[derive(Default)]
struct Config2 {
    options: HashMap<String, String>,
    rendezvous_server: String,
    serial: i32,
}
static CONFIG2: LazyLock<RwLock<Config2>> = LazyLock::new(Default::default);
static DEFAULT_SETTINGS: LazyLock<RwLock<HashMap<String, String>>> =
    LazyLock::new(Default::default);
static OVERWRITE_SETTINGS: LazyLock<RwLock<HashMap<String, String>>> =
    LazyLock::new(Default::default);
static EXE_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new(String::new());
static PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new(String::new());
const RENDEZVOUS_PORT: i32 = 21116;
const SERIAL: i32 = 3;
const RENDEZVOUS_SERVERS: [&str; 1] = ["public.example.invalid"];
struct Config;
impl Config {
GETTERS
}
HELPER
GET_OR

fn main() {
    let path = std::env::args().nth(1).unwrap();
    let stale = HashMap::from([
        ("custom-rendezvous-server".into(), "old.example.invalid".into()),
        ("relay-server".into(), "old-relay.example.invalid".into()),
        ("key".into(), "old-key".into()),
        ("direct-server".into(), "N".into()),
        ("direct-access-port".into(), "21118".into()),
        ("unrelated-setting".into(), "keep-me".into()),
    ]);
    fs::write(&path, "blizzard.example.invalid\nfirst-key\n").unwrap();
    for context in ["fresh-root", "fresh-sddm", "desktop-with-stale-cache"] {
        CONFIG2.write().unwrap().options = if context.starts_with("fresh") {
            HashMap::new()
        } else {
            stale.clone()
        };
        assert_eq!(Config::get_option("key"), "first-key", "{context}");
        assert_eq!(Config::get_option("relay-server"), "blizzard.example.invalid");
        assert_eq!(Config::get_option("direct-server"), "Y", "{context}");
        assert_eq!(Config::get_option("direct-access-port"), "21120", "{context}");
        assert_eq!(Config::get_rendezvous_server(), "blizzard.example.invalid:21116");
        assert_eq!(Config::get_rendezvous_servers(), vec!["blizzard.example.invalid"]);
        let options = Config::get_options();
        assert_eq!(options.get("key").unwrap(), "first-key");
        assert_eq!(options.get("custom-rendezvous-server").unwrap(), "blizzard.example.invalid");
        assert_eq!(options.get("relay-server").unwrap(), "blizzard.example.invalid");
        assert_eq!(options.get("direct-server").unwrap(), "Y");
        assert_eq!(options.get("direct-access-port").unwrap(), "21120");
    }
    assert_eq!(Config::get_option("unrelated-setting"), "keep-me");
    assert_eq!(CONFIG2.read().unwrap().options, stale);

    // A root generator's atomic rotation reaches an already-running GUI too.
    let replacement = format!("{path}.new");
    fs::write(&replacement, "replacement.example.invalid\nreplacement-key\n").unwrap();
    fs::rename(&replacement, &path).unwrap();
    // Model a delayed whole-map save from a GUI that cached the prior profile.
    CONFIG2.write().unwrap().options = stale.clone();
    assert_eq!(Config::get_option("key"), "replacement-key");
    assert_eq!(Config::get_rendezvous_server(), "replacement.example.invalid:21116");
    assert_eq!(Config::get_options().get("key").unwrap(), "replacement-key");
    assert_eq!(Config::get_options().get("unrelated-setting").unwrap(), "keep-me");
    assert_eq!(Config::get_option("direct-server"), "Y");
    assert_eq!(Config::get_option("direct-access-port"), "21120");

    fs::remove_file(&path).unwrap();
    assert_eq!(Config::get_option("key"), "old-key");
    assert_eq!(Config::get_rendezvous_server(), "old.example.invalid:21116");
    assert_eq!(Config::get_option("direct-server"), "Y");
    assert_eq!(Config::get_option("direct-access-port"), "21120");
    assert_eq!(CONFIG2.read().unwrap().options, stale);
    for invalid in ["", "only-a-server\n", "\nkey\n", "server\n\n", "server\nkey\nextra\n"] {
        fs::write(&path, invalid).unwrap();
        assert_eq!(Config::get_option("key"), "old-key");
        assert_eq!(Config::get_option("direct-server"), "Y");
        assert_eq!(Config::get_option("direct-access-port"), "21120");
    }
    println!("Passed fresh root/SDDM, stale desktop save, rotation, fallback and unrelated settings");
}
"""
    harness = (
        harness.replace("GETTERS", getters)
        .replace("HELPER", helper)
        .replace("GET_OR", function(source, "fn get_or("))
    )
    program = directory / "consumer.rs"
    program.write_text(harness)
    executable = directory / "consumer"
    subprocess.run(
        ["rustc", "--edition=2021", str(program), "-o", str(executable)],
        check=True,
    )
    subprocess.run([str(executable), str(settings)], check=True)
