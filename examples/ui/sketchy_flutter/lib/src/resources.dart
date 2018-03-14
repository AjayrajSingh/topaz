// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.ui.gfx.fidl/nodes.fidl.dart' as scenic;
import 'package:lib.ui.gfx.fidl/ops.fidl.dart' as scenic;
import 'package:lib.ui.gfx.fidl/resources.fidl.dart' as scenic;
import 'package:lib.ui.gfx.fidl/shapes.fidl.dart' as scenic;
import 'package:lib.ui.gfx.fidl/types.fidl.dart' as scenic;
import 'package:zircon/zircon.dart';

import 'session.dart';

// ignore_for_file: public_member_api_docs

class Resource {
  final int id;
  final Session session;

  Resource._create(this.session, scenic.Resource resource)
      : id = session.nextResourceId() {
    session.enqueue(new scenic.Op.withCreateResource(
        new scenic.CreateResourceOp(id: id, resource: resource)));
  }

  Resource._import(this.session, Handle token, scenic.ImportSpec spec)
      : id = session.nextResourceId() {
    session.enqueue(new scenic.Op.withImportResource(
        new scenic.ImportResourceOp(id: id, token: token, spec: spec)));
  }
}

scenic.Value vector1(double val) => new scenic.Value.withVector1(val);

class Node extends Resource {
  Node._create(Session session, scenic.Resource resource)
      : super._create(session, resource);

  Node._import(Session session, Handle token, scenic.ImportSpec spec)
      : super._import(session, token, spec);

  void setRotation(double x, double y, double z, double w) {
    final scenic.Quaternion quaternion =
        new scenic.Quaternion(x: x, y: y, z: z, w: w);
    setRotationValue(
        new scenic.QuaternionValue(value: quaternion, variableId: 0));
  }

  void setRotationValue(scenic.QuaternionValue rotation) {
    session.enqueue(new scenic.Op.withSetRotation(
        new scenic.SetRotationOp(id: id, value: rotation)));
  }

  void setTranslation(double x, double y, double z) {
    final scenic.Vec3 vec3 = new scenic.Vec3(x: x, y: y, z: z);
    setTranslationValue(new scenic.Vector3Value(value: vec3, variableId: 0));
  }

  void setTranslationValue(scenic.Vector3Value vec3) {
    session.enqueue(new scenic.Op.withSetTranslation(
        new scenic.SetTranslationOp(id: id, value: vec3)));
  }
}

class ContainerNode extends Node {
  ContainerNode._create(Session session, scenic.Resource resource)
      : super._create(session, resource);

  ContainerNode._import(Session session, Handle token, scenic.ImportSpec spec)
      : super._import(session, token, spec);

  void addChild(Node child) {
    session.enqueue(new scenic.Op.withAddChild(
        new scenic.AddChildOp(nodeId: id, childId: child.id)));
  }

  void addPart(Node part) {
    session.enqueue(new scenic.Op.withAddPart(
        new scenic.AddPartOp(nodeId: id, partId: part.id)));
  }
}

class ImportNode extends ContainerNode {
  ImportNode(Session session, Handle token)
      : super._import(session, token, scenic.ImportSpec.node);
}

class ShapeNode extends Node {
  ShapeNode(Session session)
      : super._create(session,
            const scenic.Resource.withShapeNode(const scenic.ShapeNode()));

  void setMaterial(Material material) {
    session.enqueue(new scenic.Op.withSetMaterial(
        new scenic.SetMaterialOp(nodeId: id, materialId: material.id)));
  }

  void setShape(Shape shape) {
    session.enqueue(new scenic.Op.withSetShape(
        new scenic.SetShapeOp(nodeId: id, shapeId: shape.id)));
  }
}

class Material extends Resource {
  Material(Session session)
      : super._create(session,
            const scenic.Resource.withMaterial(const scenic.Material()));

  void setColor(double red, double green, double blue, double alpha) {
    final scenic.ColorRgba color = new scenic.ColorRgba(
        red: (red * 255).round(),
        green: (green * 255).round(),
        blue: (blue * 255).round(),
        alpha: (alpha * 255).round());
    setColorValue(new scenic.ColorRgbaValue(value: color, variableId: 0));
  }

  void setColorValue(scenic.ColorRgbaValue color) {
    session.enqueue(new scenic.Op.withSetColor(
        new scenic.SetColorOp(materialId: id, color: color)));
  }
}

class Shape extends Resource {
  Shape._create(Session session, scenic.Resource resource)
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
      scenic.Value width,
      scenic.Value height,
      scenic.Value topLeftRadius,
      scenic.Value topRightRadius,
      scenic.Value bottomLeftRadius,
      scenic.Value bottomRightRadius) {
    final scenic.RoundedRectangle rect = new scenic.RoundedRectangle(
        width: width,
        height: height,
        topLeftRadius: topLeftRadius,
        topRightRadius: topRightRadius,
        bottomLeftRadius: bottomLeftRadius,
        bottomRightRadius: bottomRightRadius);

    return new RoundedRectangle._create(
        session, new scenic.Resource.withRoundedRectangle(rect));
  }

  RoundedRectangle._create(Session session, scenic.Resource resource)
      : super._create(session, resource);
}
