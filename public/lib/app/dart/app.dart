// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

// ignore_for_file: public_member_api_docs

import 'package:fidl/fidl.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:fuchsia.fidl.component/component.dart';
import 'package:zircon/zircon.dart';

class ApplicationContext {
  static ApplicationContext _context;

  ApplicationContext();

  final ApplicationEnvironmentProxy environment =
      new ApplicationEnvironmentProxy();
  final ApplicationLauncherProxy launcher = new ApplicationLauncherProxy();
  final ServiceProviderProxy environmentServices = new ServiceProviderProxy();
  final ServiceProviderImpl outgoingServices = new ServiceProviderImpl();

  factory ApplicationContext.fromStartupInfo() {
    if (_context != null) {
      return _context;
    }

    final ApplicationContext context = new ApplicationContext();

    final Handle environmentHandle = MxStartupInfo.takeEnvironment();
    if (environmentHandle != null) {
      context.environment
        ..ctrl.bind(new InterfaceHandle<ApplicationEnvironment>(
            new Channel(environmentHandle)))
        ..getApplicationLauncher(context.launcher.ctrl.request())
        ..getServices(context.environmentServices.ctrl.request());
    }

    final Handle outgoingServicesHandle = MxStartupInfo.takeOutgoingServices();
    if (outgoingServicesHandle != null) {
      context.outgoingServices.bind(new InterfaceRequest<ServiceProvider>(
          new Channel(outgoingServicesHandle)));
    }

    _context = context;

    return context;
  }

  void close() {
    environment.ctrl.close();
    launcher.ctrl.close();
    environmentServices.ctrl.close();
    outgoingServices.close();
  }
}

void connectToService<T>(
    ServiceProvider serviceProvider, ProxyController<T> controller) {
  final String serviceName = controller.$serviceName;
  assert(serviceName != null,
      'controller.\$serviceName must not be null. Check the FIDL file for a missing [Discoverable]');
  serviceProvider.connectToService(
      serviceName, controller.request().passChannel());
}

InterfaceHandle<T> connectToServiceByName<T>(
    ServiceProvider serviceProvider, String serviceName) {
  final ChannelPair pair = new ChannelPair();
  serviceProvider.connectToService(serviceName, pair.first);
  return new InterfaceHandle<T>(pair.second);
}

typedef void ServiceConnector<T>(InterfaceRequest<T> request);
typedef void DefaultServiceConnector<T>(
    String serviceName, InterfaceRequest<T> request);

typedef void _ServiceConnectorThunk(Channel channel);

class ServiceProviderImpl extends ServiceProvider {
  final ServiceProviderBinding _binding = new ServiceProviderBinding();

  void bind(InterfaceRequest<ServiceProvider> interfaceRequest) {
    _binding.bind(this, interfaceRequest);
  }

  void close() {
    _binding.close();
  }

  DefaultServiceConnector<dynamic> defaultConnector;

  final Map<String, _ServiceConnectorThunk> _connectorThunks =
      <String, _ServiceConnectorThunk>{};

  void addServiceForName<T>(ServiceConnector<T> connector, String serviceName) {
    _connectorThunks[serviceName] = (Channel channel) {
      connector(new InterfaceRequest<T>(channel));
    };
  }

  @override
  void connectToService(String serviceName, Channel channel) {
    final _ServiceConnectorThunk connectorThunk = _connectorThunks[serviceName];
    if (connectorThunk != null) {
      connectorThunk(channel);
    } else if (defaultConnector != null) {
      defaultConnector(serviceName, new InterfaceRequest<dynamic>(channel));
    } else {
      channel.close();
    }
  }
}

void _connectToService(Channel directory, Channel request, String servicePath) {
  final ByteData byteData = new ByteData(56 + servicePath.length);

  // struct zxrio_msg {
  //   zx_txid_t txid;
  //   uint32_t reserved0;
  //   uint32_t flags;
  //   uint32_t op;
  //   uint32_t datalen;
  //   int32_t arg;
  //   union {
  //     int64_t off;
  //     uint32_t mode;
  //     uint32_t protocol;
  //     uint32_t op;
  //   } arg2;
  //   int32_t reserved1;
  //   uint32_t hcount;
  //   zx_handle_t handle[4];
  //   uint8_t data[8192];
  // };

  final List<Handle> handles = <Handle>[];
  int offset = 0;

  // txid -> 0
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // reserved0 -> 0
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // flags -> 0
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // op -> ZXRIO_OPEN
  byteData.setUint32(offset, 0x103, Endian.little);
  offset += 4;

  // datalen -> length of servicePath
  byteData.setUint32(offset, servicePath.length, Endian.little);
  offset += 4;

  // arg -> ZX_FS_RIGHT_READABLE | ZX_FS_RIGHT_WRITABLE | ZX_FS_FLAG_PIPELINE
  byteData.setInt32(offset, 0x80000003, Endian.little);
  offset += 4;

  // arg2 -> 493 (inside a 64 bit union)
  byteData.setUint32(offset, 493, Endian.little);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // reserved1 -> 0
  byteData.setInt32(offset, 0, Endian.little);
  offset += 4;

  // hcount -> 1
  byteData.setUint32(offset, 1, Endian.little);
  offset += 4;

  // handle[4]. The actual handle values don't matter.
  byteData.setUint32(offset, 0xFFFFFFFFF, Endian.little);
  handles.add(request.handle);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // data.
  for (int i = 0; i < servicePath.length; i++) {
    // TODO(ZX-1358) This would not work for non-ASCII. This will be
    // fixed when we move to FIDL.
    byteData.setUint8(offset, servicePath.codeUnitAt(i));
    offset += 1;
  }

  assert(directory.write(byteData, handles) == ZX.OK);
}

class Services {
  Channel _directory;

  Services();

  Channel request() {
    ChannelPair pair = new ChannelPair();
    assert(pair.status == ZX.OK);
    _directory = pair.second;
    return pair.first;
  }

  void connectToService<T>(ProxyController<T> controller) {
    final String serviceName = controller.$serviceName;
    assert(serviceName != null,
        'controller.\$serviceName must not be null. Check the FIDL file for a missing [Discoverable]');
    _connectToService(
        _directory, controller.request().passChannel(), serviceName);
  }

  InterfaceHandle<T> connectToServiceByName<T>(String serviceName) {
    final ChannelPair pair = new ChannelPair();
    _connectToService(_directory, pair.first, serviceName);
    return new InterfaceHandle<T>(pair.second);
  }

  void close() {
    _directory.close();
  }
}
