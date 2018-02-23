// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

//! Main process for Fuchsia builds - uses fidl rather than stdin / stdout

extern crate xi_core_lib;
extern crate xi_rpc;

extern crate fuchsia_zircon as zircon;
extern crate mxruntime;
#[macro_use]
extern crate fidl;
extern crate byteorder;

extern crate application_services_service_provider;
extern crate apps_xi_services;
extern crate apps_ledger_services_public;
use self::application_services_service_provider::{ServiceProvider, ServiceProvider_Stub};
use self::apps_ledger_services_public::{Ledger_Client, Ledger_Proxy, Ledger_Metadata, Ledger_new_Proxy};
use self::apps_xi_services::{Json, Json_Stub};

use std::thread;
use std::io::{self, Write, Cursor};
use std::sync::Arc;

use self::zircon::{Channel, HandleBase, Socket, Status, cprng_draw};
use self::zircon::{ZX_SOCKET_READABLE, ZX_SOCKET_PEER_CLOSED, ZX_TIME_INFINITE};
use self::mxruntime::{HandleType, get_startup_handle};

use f1dl::Server;

use xi_rpc::RpcLoop;

use xi_core_lib::MainState;

use byteorder::{NativeEndian, ReadBytesExt};

pub struct MySocket(Arc<Socket>);

fn status_to_io_err(_status: Status) -> io::Error {
    // TODO: better error mapping
    io::Error::new(io::ErrorKind::Other, "OS error")
}

impl io::Read for MySocket {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let wait_sigs = ZX_SOCKET_READABLE | ZX_SOCKET_PEER_CLOSED;
        match self.0.wait(wait_sigs, ZX_TIME_INFINITE) {
            Ok(signals) => {
                if signals.contains(ZX_SOCKET_PEER_CLOSED) {
                    return Ok(0)
                }
            }
            Err(status) => return Err(status_to_io_err(status))
        }
        self.0.read(Default::default(), buf).or_else(|status|
            if status == Status::ErrPeerClosed {
                Ok(0)
            } else {
                Err(status_to_io_err(status))
            }
        )
    }
}

impl io::Write for MySocket {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.0.write(Default::default(), buf).map_err(|status|
            // TODO: handle case where socket is full (wait and retry)
            status_to_io_err(status)
        )
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

fn gen_session_id() -> (u64,u32) {
    let mut buf = vec![0; 12];
    let actual = cprng_draw(&mut buf[..]).unwrap();
    assert_eq!(12, actual);
    let mut buf = Cursor::new(buf);
    let first = buf.read_u64::<NativeEndian>().unwrap();
    let second = buf.read_u32::<NativeEndian>().unwrap();
    (first, second)
}

fn editor_main(sock: Socket, ledger: Ledger_Proxy) {
    let mut state = MainState::new();
    state.set_ledger(ledger, gen_session_id());
    let arc_sock = Arc::new(sock);
    let my_in = io::BufReader::new(MySocket(arc_sock.clone()));
    let my_out = MySocket(arc_sock);
    let mut rpc_looper = RpcLoop::new(my_out);

    rpc_looper.mainloop(|| my_in, &mut state);
}

struct JsonServer;

impl Json for JsonServer {
    fn connect_socket(&mut self, sock: Socket, sync_ledger: f1dl::InterfacePtr<Ledger_Client>) {
        let f1dl::InterfacePtr { version, inner } = sync_ledger;
        assert_eq!(Ledger_Metadata::VERSION, version);
        let ledger = Ledger_new_Proxy(inner);
        let _ = thread::spawn(move || editor_main(sock, ledger));
    }
}

impl Json_Stub for JsonServer {
    // Use default dispatching, but we could override it here.
}
impl_fidl_stub!(JsonServer : Json_Stub);

struct ServiceProviderServer;

impl ServiceProvider for ServiceProviderServer {
    fn connect_to_service(&mut self, service_name: String, channel: Channel) {
        // TODO: should probably get service name from hello service metadata
        if service_name == "xi.Json" {
            let json_server = JsonServer;
            let _ = Server::new(json_server, channel).spawn();
        } else {
            if let Err(e) = write!(io::stderr(), "unknown service name {}\n", service_name) {
                panic!("Error writing error to stdout: {}", e);
            }
        }
    }
}

impl ServiceProvider_Stub for ServiceProviderServer {
    // Use default dispatching, but we could override it here.
}
impl_fidl_stub!(ServiceProviderServer : ServiceProvider_Stub);

pub fn main() {
    let startup_handle = get_startup_handle(HandleType::OutgoingServices)
        .expect("couldn't get outgoing services handle");
    let chan = Channel::from_handle(startup_handle);
    let my_server = ServiceProviderServer;
    let server_thread = Server::new(my_server, chan).spawn();
    let _ = server_thread.join();
}
