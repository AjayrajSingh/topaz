// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#![feature(async_await, await_macro, futures_api)]

use failure::{format_err, Error, ResultExt};
use fidl_fuchsia_developer_tiles::ControllerMarker;
use fuchsia_app::client::connect_to_service_at;
use fuchsia_async as fasync;
use itertools::izip;
use std::path::{Path, PathBuf};
use structopt::StructOpt;

#[derive(StructOpt, Debug)]
#[structopt(
    name = "ermine_ctl",
    bin_name = "ermine_ctl",
    about = "Send commands to ermine."
)]
enum Options {
    #[structopt(name = "remove")]
    /// Remove a mod from Ermine
    Remove {
        /// Key identifying the mod to remove
        key: usize,
    },
    #[structopt(name = "list")]
    /// List the mods running in Ermine
    List,
}

fn first_entry_at_path(path: &Path) -> Result<PathBuf, Error> {
    let target = PathBuf::from(path);
    let user = target.read_dir().context("Can't read target.")?.next();
    Ok(user
        .ok_or_else(|| format_err!("Can't get first entry of {}", target.display()))??
        .path())
}

fn find_r_directory() -> Result<PathBuf, Error> {
    let sys = PathBuf::from("/hub/r/sys");
    if sys.exists() {
        Ok(first_entry_at_path(&sys).context("No entry in /hub/r/sys")?.join("r"))
    } else {
        Ok(PathBuf::from("/hub/r"))
    }
}

fn main() -> Result<(), Error> {
    let options = Options::from_args();

    let hub = find_r_directory().context("Can't find hub directory")?;
    let user = first_entry_at_path(&hub)
        .context("Can't find user entry at path '/hub/r'. Did you not yet log in?")?;
    let proc =
        first_entry_at_path(&user).context("Can't find process entry in hub user directory.")?;
    let ermine_c = proc.join("c").join("ermine.cmx");
    let ermine = first_entry_at_path(&ermine_c).context(
        "Can't find ermine component directory in the hub, perhaps ermine isn't running?",
    )?;
    let ermine_out = ermine.join("out");

    let mut executor = fasync::Executor::new().context("error creating event loop")?;
    let ermine_svc = connect_to_service_at::<ControllerMarker>(&ermine_out.to_str().unwrap())
        .context("failed to connect to ermine control interface")?;

    let fut = async {
        match options {
            Options::Remove { key } => {
                ermine_svc
                    .remove_tile(key as u32)
                    .expect("Remove mod failed.");
            }
            Options::List => {
                let (keys, urls, sizes, focusabilties) =
                    await!(ermine_svc.list_tiles()).expect("List mods failed.");
                for (key, url, size, focusable) in
                    izip!(keys.iter(), urls.iter(), sizes.iter(), focusabilties.iter())
                {
                    let focus_label = if *focusable { "" } else { " (unfocusable)" };
                    println!(
                        "Mod key={} url={} size={},{} {}",
                        key, url, size.width, size.height, focus_label
                    );
                }
            }
        }
    };

    executor.run_singlethreaded(fut);

    Ok(())
}
