import 'package:composition_delegate/composition_delegate.dart';
import 'package:test/test.dart';

void main() {
  CompositionDelegate setupCompositionDelegate() {
    CompositionDelegate compDelegate = CompositionDelegate(
        layoutContext:
            LayoutContext(size: Size(1280, 800), minSurfaceWidth: 320))
      ..setLayoutStrategy(layoutStrategy: layoutStrategyType.copresentStrategy);
    return compDelegate;
  }

  group(
    'Test copresent layout determination',
    () {
      test('For no Surfaces is empty', () {
        CompositionDelegate compDelegate = setupCompositionDelegate();
        expect(compDelegate.getLayout(), isEmpty);
      });

      test('For one Surface is full screen', () {
        // expect a List, with one Layer, with one SurfaceLayout
        CompositionDelegate compDelegate = setupCompositionDelegate();

        List<Layer> expectedLayout = <Layer>[
          Layer(
              element: SurfaceLayout(
                  x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'first'))
        ];
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first');
        expect(compDelegate.getLayout(), equals(expectedLayout));
      });

      test('For two Surfaces with sequential is two layers', () {
        CompositionDelegate compDelegate = setupCompositionDelegate();

        Layer expectedUpper = Layer(
            element: SurfaceLayout(
                x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'second'));
        Layer expectedLower = Layer(
            element: SurfaceLayout(
                x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'first'));
        // expect a List of two Layers, with one SurfaceLayout in each
        List<Layer> expectedLayout = [expectedLower, expectedUpper];
        // This test relies on the surface being focused in the correct order as the focus list is
        // maintained separaretly from what has been added to the tree.
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first')
          ..addSurface(
              surface: Surface(surfaceId: 'second'),
              relation:
                  SurfaceRelation(arrangement: SurfaceArrangement.sequential))
          ..focusSurface(surfaceId: 'second');
        expect(compDelegate.getLayout(), equals(expectedLayout));
      });

      test('For two Surfaces with co-present is split-screen', () {
        CompositionDelegate compDelegate = setupCompositionDelegate();

        Layer expectedUpper = Layer.fromList(
          elements: [
            SurfaceLayout(
                x: 0.0, y: 0.0, w: 640.0, h: 800.0, surfaceId: 'first'),
            SurfaceLayout(
                x: 640.0, y: 0.0, w: 640.0, h: 800.0, surfaceId: 'second'),
          ],
        );
        // expect a List of two Layers, with one SurfaceLayout in each
        List<Layer> expectedLayout = [expectedUpper];
        // This test relies on the surface being focused in the correct order as the focus list is
        // maintained separaretly from what has been added to the tree.
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first')
          ..addSurface(
            surface: Surface(surfaceId: 'second'),
            parentId: 'first',
            relation:
                SurfaceRelation(arrangement: SurfaceArrangement.copresent),
          )
          ..focusSurface(surfaceId: 'second');
        expect(compDelegate.getLayout(), equals(expectedLayout));
      });

      test('Leftmost surfaces are pushed off when space runs out', () {
        CompositionDelegate compDelegate = setupCompositionDelegate()
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first')
          ..addSurface(
              surface: Surface(surfaceId: 'second'),
              relation:
                  SurfaceRelation(arrangement: SurfaceArrangement.copresent),
              parentId: 'first')
          ..focusSurface(surfaceId: 'second')
          ..addSurface(
              surface: Surface(surfaceId: 'third'),
              relation:
                  SurfaceRelation(arrangement: SurfaceArrangement.copresent),
              parentId: 'second')
          ..focusSurface(surfaceId: 'third')
          ..addSurface(
              surface: Surface(surfaceId: 'fourth'),
              relation:
                  SurfaceRelation(arrangement: SurfaceArrangement.copresent),
              parentId: 'third')
          ..focusSurface(surfaceId: 'fourth')
          ..addSurface(
              surface: Surface(surfaceId: 'fifth'),
              relation:
                  SurfaceRelation(arrangement: SurfaceArrangement.copresent),
              parentId: 'fourth')
          ..focusSurface(surfaceId: 'fifth');

        Layer expectedUpper = Layer.fromList(
          elements: [
            SurfaceLayout(
                x: 0.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'second'),
            SurfaceLayout(
                x: 320.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'third'),
            SurfaceLayout(
                x: 640.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'fourth'),
            SurfaceLayout(
                x: 960.0, y: 0.0, w: 320.0, h: 800.0, surfaceId: 'fifth'),
          ],
        );
        Layer expectedLower = Layer.fromList(elements: [
          SurfaceLayout(x: 0.0, y: 0.0, w: 1280.0, h: 800.0, surfaceId: 'first')
        ]);
        // expect a List of two Layers, with one SurfaceLayout in each
        List<Layer> expectedLayout = [expectedUpper, expectedLower];
        // This test relies on the surface being focused in the correct order as the focus list is
        // maintained separaretly from what has been added to the tree.
        compDelegate
          ..addSurface(surface: Surface(surfaceId: 'first'))
          ..focusSurface(surfaceId: 'first')
          ..addSurface(
            surface: Surface(surfaceId: 'second'),
            parentId: 'first',
            relation:
                SurfaceRelation(arrangement: SurfaceArrangement.copresent),
          )
          ..focusSurface(surfaceId: 'second');
        expect(compDelegate.getLayout(), equals(expectedLayout));
      });
    },
  );
}
