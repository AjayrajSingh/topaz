// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_ui_gfx/fidl.dart' as ui_gfx;
import 'package:zircon/zircon.dart';

import 'session.dart';

// ignore_for_file: public_member_api_docs

class Resource {
  final int id;
  final Session session;

  Resource._create(this.session, ui_gfx.ResourceArgs resource)
      : id = session.nextResourceId() {
    session.enqueue(new ui_gfx.Command.withCreateResource(
        new ui_gfx.CreateResourceCommand(id: id, resource: resource)));
  }

  Resource._import(this.session, Handle token, ui_gfx.ImportSpec spec)
      : id = session.nextResourceId() {
    session.enqueue(new ui_gfx.Command.withImportResource(
        new ui_gfx.ImportResourceCommand(id: id, token: token, spec: spec)));
  }
}

ui_gfx.Value vector1(double val) => new ui_gfx.Value.withVector1(val);

class Node extends Resource {
  Node._create(Session session, ui_gfx.ResourceArgs resource)
      : super._create(session, resource);

  Node._import(Session session, Handle token, ui_gfx.ImportSpec spec)
      : super._import(session, token, spec);

  void setRotation(double x, double y, double z, double w) {
    final ui_gfx.Quaternion quaternion =
        new ui_gfx.Quaternion(x: x, y: y, z: z, w: w);
    setRotationValue(
        new ui_gfx.QuaternionValue(value: quaternion, variableId: 0));
  }

  void setRotationValue(ui_gfx.QuaternionValue rotation) {
    session.enqueue(new ui_gfx.Command.withSetRotation(
        new ui_gfx.SetRotationCommand(id: id, value: rotation)));
  }

  void setTranslation(double x, double y, double z) {
    final ui_gfx.Vec3 vec3 = new ui_gfx.Vec3(x: x, y: y, z: z);
    setTranslationValue(new ui_gfx.Vector3Value(value: vec3, variableId: 0));
  }

  void setTranslationValue(ui_gfx.Vector3Value vec3) {
    session.enqueue(new ui_gfx.Command.withSetTranslation(
        new ui_gfx.SetTranslationCommand(id: id, value: vec3)));
  }
}

class ContainerNode extends Node {
  ContainerNode._create(Session session, ui_gfx.ResourceArgs resource)
      : super._create(session, resource);

  ContainerNode._import(Session session, Handle token, ui_gfx.ImportSpec spec)
      : super._import(session, token, spec);

  void addChild(Node child) {
    session.enqueue(new ui_gfx.Command.withAddChild(
        new ui_gfx.AddChildCommand(nodeId: id, childId: child.id)));
  }

  void addPart(Node part) {
    session.enqueue(new ui_gfx.Command.withAddPart(
        new ui_gfx.AddPartCommand(nodeId: id, partId: part.id)));
  }
}

class ImportNode extends ContainerNode {
  ImportNode(Session session, Handle token)
      : super._import(session, token, ui_gfx.ImportSpec.node);
}

class ShapeNode extends Node {
  ShapeNode(Session session)
      : super._create(session,
            const ui_gfx.ResourceArgs.withShapeNode(const ui_gfx.ShapeNodeArgs()));

  void setMaterial(Material material) {
    session.enqueue(new ui_gfx.Command.withSetMaterial(
        new ui_gfx.SetMaterialCommand(nodeId: id, materialId: material.id)));
  }

  void setShape(Shape shape) {
    session.enqueue(new ui_gfx.Command.withSetShape(
        new ui_gfx.SetShapeCommand(nodeId: id, shapeId: shape.id)));
  }
}

class Material extends Resource {
  Material(Session session)
      : super._create(session,
            const ui_gfx.ResourceArgs.withMaterial(const ui_gfx.MaterialArgs()));

  void setColor(double red, double green, double blue, double alpha) {
    final ui_gfx.ColorRgba color = new ui_gfx.ColorRgba(
        red: (red * 255).round(),
        green: (green * 255).round(),
        blue: (blue * 255).round(),
        alpha: (alpha * 255).round());
    setColorValue(new ui_gfx.ColorRgbaValue(value: color, variableId: 0));
  }

  void setColorValue(ui_gfx.ColorRgbaValue color) {
    session.enqueue(new ui_gfx.Command.withSetColor(
        new ui_gfx.SetColorCommand(materialId: id, color: color)));
  }
}

class Shape extends Resource {
  Shape._create(Session session, ui_gfx.ResourceArgs resource)
      : super._create(session, resource);
}

class RoundedRectangle extends Shape {
  factory RoundedRectangle(
          Session session,
          double width,
          double height,
          double topLeftRadius,
          double topRightRadius,
          double bottomLeftRadius,
          double bottomRightRadius) =>
      new RoundedRectangle.fromValues(
          session,
          vector1(width),
          vector1(height),
          vector1(topLeftRadius),
          vector1(topRightRadius),
          vector1(bottomLeftRadius),
          vector1(bottomRightRadius));

  factory RoundedRectangle.fromValues(
      Session session,
      ui_gfx.Value width,
      ui_gfx.Value height,
      ui_gfx.Value topLeftRadius,
      ui_gfx.Value topRightRadius,
      ui_gfx.Value bottomLeftRadius,
      ui_gfx.Value bottomRightRadius) {
    final ui_gfx.RoundedRectangleArgs rect = new ui_gfx.RoundedRectangleArgs(
        width: width,
        height: height,
        topLeftRadius: topLeftRadius,
        topRightRadius: topRightRadius,
        bottomLeftRadius: bottomLeftRadius,
        bottomRightRadius: bottomRightRadius);

    return new RoundedRectangle._create(
        session, new ui_gfx.ResourceArgs.withRoundedRectangle(rect));
  }

  RoundedRectangle._create(Session session, ui_gfx.ResourceArgs resource)
      : super._create(session, resource);
}
