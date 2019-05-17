// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

const EdgeInsets _kPadding = EdgeInsets.only(top: 32.0, bottom: 12.0);

const ListEquality<RawImage> _kImageListEquality =
    ListEquality<RawImage>();

// Shows a grid of horizontally scrolling images. Their scroll behavior is
// driven automatically using a ScrollController (see ImageGridModel).
class ImageGrid extends StatelessWidget {
  /// Image data used for rendering this grid.
  final List<RawImage> images;
  // If false, just use empty Containers instead of painting the RawImages.
  final bool drawImages;

  /// If not null, this is used to scroll the grid.
  final ScrollController scrollController;

  /// Constructor.
  const ImageGrid({
    @required this.images,
    @required this.drawImages,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        color: Colors.black,
        fontSize: 8.0,
        height: 1.2,
      ),
      child: Container(
        padding: _kPadding,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Text('Image Grid Test (Flutter)'),
            Container(
              height: 8.0,
            ),
            Expanded(
              child: CustomScrollView(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.only(left: 32.0),
                    sliver: SliverGrid(
                      gridDelegate: _ImageGridDelegate(
                        images: images,
                        rowCount: 3,
                      ),
                      delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) =>
                              _buildItem(images[index]),
                          childCount: images.length),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(RawImage image) {
    return Container(
      padding: EdgeInsets.only(
        right: 16.0,
        bottom: 16.0,
      ),
      child: PhysicalModel(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4.0),
        elevation: 2.0,
        child: drawImages
            ? image
            : Container(
                width: 500.0,
                height: 500.0,
              ),
      ),
    );
  }
}

class _ImageGridDelegate extends SliverGridDelegate {
  final List<RawImage> images;
  final int rowCount;
  SliverConstraints _lastConstraints;
  _ImageGridLayout _lastLayout;

  _ImageGridDelegate({
    this.images,
    this.rowCount,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (_newConstraints(constraints)) {
      _lastConstraints = constraints;
      _lastLayout = _ImageGridLayout(
        sliverGridGeometryList: _getSliverGeometryList(
          constraints.crossAxisExtent,
        ),
        rowCount: rowCount,
      );
    }
    return _lastLayout;
  }

  bool _newConstraints(SliverConstraints constraints) {
    return _lastConstraints == null ||
        _lastConstraints.crossAxisExtent != constraints.crossAxisExtent;
  }

  @override
  bool shouldRelayout(_ImageGridDelegate oldDelegate) {
    return oldDelegate.rowCount != rowCount ||
        !_kImageListEquality.equals(oldDelegate.images, images);
  }

  /// Generates the individual SliverGridGeometry elements that correspond to
  /// each image.
  List<SliverGridGeometry> _getSliverGeometryList(
    double crossAxisExtent,
  ) {
    List<SliverGridGeometry> sliverGridGeometryList = <SliverGridGeometry>[];
    List<SliverGridGeometry> lastElementInRow = <SliverGridGeometry>[];
    double rowHeight = crossAxisExtent / rowCount;

    int getShortestRow() {
      double smallestOffest = double.infinity;
      int smallestOffestIndex = 0;
      for (int i = 0; i < rowCount; i++) {
        if (lastElementInRow.length < i + 1) {
          smallestOffestIndex = i;
          lastElementInRow.add(const SliverGridGeometry(
            scrollOffset: 0.0,
            crossAxisOffset: 0.0,
            mainAxisExtent: 0.0,
            crossAxisExtent: 0.0,
          ));
          break;
        }
        double offset = lastElementInRow[i].scrollOffset +
            lastElementInRow[i].mainAxisExtent;
        if (offset < smallestOffest) {
          smallestOffestIndex = i;
          smallestOffest = offset;
        }
      }
      return smallestOffestIndex;
    }

    for (RawImage image in images) {
      int rowIndex = getShortestRow();
      double scrollOffset = lastElementInRow[rowIndex].scrollOffset +
          lastElementInRow[rowIndex].mainAxisExtent;
      double crossAxisOffset = rowHeight * rowIndex;
      double mainAxisExtent = _getScaledImageWidth(image, rowHeight);
      double crossAxisExtent = rowHeight;
      SliverGridGeometry gridGeometry = SliverGridGeometry(
        scrollOffset: scrollOffset,
        crossAxisOffset: crossAxisOffset,
        mainAxisExtent: mainAxisExtent,
        crossAxisExtent: crossAxisExtent,
      );
      lastElementInRow[rowIndex] = gridGeometry;
      sliverGridGeometryList.add(gridGeometry);
    }
    return sliverGridGeometryList;
  }

  /// Gets the scaled width of the image given the height.
  /// This will maintain the aspect-ratio of the image as well.
  double _getScaledImageWidth(RawImage image, double height) =>
      image.width * height / image.height;
}

class _ImageGridLayout extends SliverGridLayout {
  final List<SliverGridGeometry> sliverGridGeometryList;
  final int rowCount;

  const _ImageGridLayout({
    this.sliverGridGeometryList,
    this.rowCount,
  });

  /// The minimum child index that is visible at (or after) this scroll offset.
  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    int index = 0;
    for (int i = 0; i < sliverGridGeometryList.length; i++) {
      if (sliverGridGeometryList[i].scrollOffset +
              sliverGridGeometryList[i].mainAxisExtent >=
          scrollOffset) {
        index = i;
        break;
      }
    }
    return index;
  }

  /// The maximum child index that is visible at (or before) this scroll offset.
  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    int index = sliverGridGeometryList.length - 1;
    for (int i = 0; i < sliverGridGeometryList.length; i++) {
      if (sliverGridGeometryList[i].scrollOffset > scrollOffset) {
        index = math.max(0, i - 1);
        break;
      }
    }
    return index;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    return sliverGridGeometryList[index];
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    double maxScrollOffset = double.negativeInfinity;

    /// Get the max of the last few elements based on rowCount
    for (int i = childCount - 1; i >= 0 && i > i - rowCount; i--) {
      double offset = sliverGridGeometryList[i].scrollOffset +
          sliverGridGeometryList[i].mainAxisExtent;
      if (offset > maxScrollOffset) {
        maxScrollOffset = offset;
      }
    }

    return maxScrollOffset;
  }
}
