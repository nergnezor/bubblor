import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Draggable;
import 'package:flame/game.dart';
import 'package:flame_rive/flame_rive.dart';
import 'package:flutter/services.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:rive/rive.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/services.dart';
// import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(GameWidget(
    game: MyGame(),
  ));
  if (!kIsWeb && Platform.isAndroid) {
    try {
      FlutterDisplayMode.setHighRefreshRate();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      print(e);
    }
  }
}

class MyGame extends FlameGame with HasTappables, HasDraggables {
  static double frameRate = 60;
  double y = 0;
  double x = 0;

  @override
  Color backgroundColor() => const Color(0xff471717);

  @override
  Future<void> onLoad() async {
    BubbleComponent.screenSize = size;
    await super.onLoad();
  }

  Future<void> createBubble(double xPosition, double yPosition) async {
    Artboard artboard =
        await loadArtboard(RiveFile.asset('assets/bubble_still.riv'));
    BubbleComponent component = BubbleComponent(artboard: artboard);
    component.position = Vector2(xPosition, yPosition) - component.size / 2;
    add(component);
  }

  @override
  void onDragStart(int i, DragStartInfo info) {
    super.onDragStart(i, info);
    print('handled 2?' + info.toString());
    if (info.handled) {
      return;
    }
    createBubble(info.eventPosition.game.x, info.eventPosition.game.y);
  }

  @override
  void onDragUpdate(int i, DragUpdateInfo info) {
    super.onDragUpdate(i, info);

    x += info.delta.game.x; // != 0 || info.delta.game.y != 0) {
    y += info.delta.game.y;
    info.handled = true;
  }

  @override
  void update(double dt) {
    // y += 1;
    // if (y > size.y) {
    //   y = 0;
    // }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    _drawVerticalLines(canvas);
    super.render(canvas);
  }

  void _drawVerticalLines(Canvas c) {
    Offset start = Offset(x, y);
    Offset end = Offset(x + 200, y + 200);
    final int cellSize = 50;
    final paint = Paint()
      ..color = Colors.green
      // ..strokeWidth = 4
      ..style = PaintingStyle.fill;
    for (double x = start.dx; x <= end.dx; x += cellSize) {
      c.drawLine(Offset(x, start.dy), Offset(x, end.dy), paint);
    }
    Rect rect = Rect.fromPoints(start, end);
    c.drawPath(Path()..addRect(rect), Paint()..color = Colors.red);
    c.drawPath(
        Path()
          ..addPolygon(
              [Offset(0, 0), rect.topLeft, rect.topRight, Offset(size.x, 0)],
              true),
        Paint()..color = Colors.blue);
    c.drawPath(
        Path()
          ..addPolygon([
            Offset(0, size.y),
            rect.bottomLeft,
            rect.bottomRight,
            size.toOffset(),
          ], true),
        Paint()..color = Colors.yellow);

    c.drawPath(
        Path()
          ..addPolygon(
              [Offset(0, 0), rect.topLeft, rect.bottomLeft, Offset(0, size.y)],
              true),
        Paint()..color = Colors.orangeAccent);
    c.drawPath(
        Path()
          ..addPolygon([
            Offset(size.x, 0),
            rect.topRight,
            rect.bottomRight,
            size.toOffset(),
          ], true),
        Paint()..color = Colors.teal);

    paint.color = Color.fromARGB(30, 0, 0, 0);
    c.drawCircle(start, 100, paint);
  }
}

class BubbleComponent extends RiveComponent
    with HasGameRef, Tappable, Draggable {
  final Artboard artboard;
  BubbleComponent({required this.artboard})
      : super(artboard: artboard, size: Vector2.all(50));

  late OneShotAnimation controller;
  late Fill fill;
  Vector3 velocity = Vector3.zero();
  static late Vector2 screenSize;
  double lifeTime = 0;
  double maxVelocity = 0;
  bool growing = true;
  // AccelerometerEvent? acc;
  // GyroscopeEvent? gyro;
  Vector3 acc = Vector3.zero();
  Vector3 gyro = Vector3.zero();
  @override
  Future<void>? onLoad() {
    controller = OneShotAnimation('Idle', autoplay: true);
    artboard.addController(controller);
    artboard.forEachComponent((child) {
      if (child.name == 'fyllning') {
        fill = child as Fill;
      }
    });
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      motionSensors.accelerometerUpdateInterval = 5000;
      motionSensors.accelerometer.listen((AccelerometerEvent event) {
        acc.setValues(event.x, event.y, event.z);
      });
      motionSensors.gyroscopeUpdateInterval = 5000;
      motionSensors.gyroscope.listen((GyroscopeEvent event) {
        gyro.setValues(event.x, event.y, event.z);
      });
    }
    return super.onLoad();
  }

  @override
  void update(double dt) {
    //if (size.x < 10) size.x = 10;
    if (gyro.x > 0) velocity.z += gyro.x;
    
    position.y -= velocity.z;
    final dy = (position.y - screenSize.y / 2);
    size.x = 100 + (dy * dy) / 1000;
    size.y = size.x;
    final sizeFactor = size.x / 100;
    var lean = Vector2(-acc.x, acc.y) / 9.8;
    lean.x *= screenSize.x / sizeFactor;
    lean.y *= screenSize.y / 20;
    var pos = lean + screenSize / 2 - size / 2;
    //pos.x += -acc.x;//(lean.x + 7 * position.x) / 8;
    position.x = (pos.x + 7 * position.x) / 8;
    position.y = (pos.y + 9 * position.y) / 10;

    velocity.x += gyro.y / sizeFactor;
    position.x += velocity.x;

    lifeTime += dt;
    if (lifeTime > 10.0) {
      gameRef.remove(this);
    }
    //float(dt);
    super.update(dt);

    velocity *= 0.95;
    //position.y += dt * 10;

    if (growing) {
      size.x += 2;
      size.y += 2;
      //position.x -= 1;
      //position.y -= 1;
      if (size.x > 150) {
        growing = false;
        //gameRef.remove(this);
      }
    }
    //edgeBounce();
    //position.clamp(Vector2.zero(), screenSize - size);
    x += velocity.x;
    y += velocity.y;
  }

  void edgeBounce() {
//  bounce
    if (position.x < 0 || position.x > screenSize.x - size.x) {
      velocity.x = 0;
      // -velocity.x;
      // print(position.x);
      position.x = max(0, min(screenSize.x - size.x, position.x));
      // position.x.clamp(100, screenSize.x - size.x);
      // scale.x -= velocity.x.abs() * 2;
    }
    if (position.y < 0 || position.y > screenSize.y - size.y) {
      velocity.y = -velocity.y;
      position.y = max(0, min(screenSize.y - size.y, position.y));
      // position.y.clamp(0, screenSize.y - size.y);
      // scale.y -= velocity.y.abs() * 2;
    }
    // position.clamp(Vector2.zero(), screenSize - size);
    // scale.x += (1 - scale.x) * 0.1;
    // scale.y += (1 - scale.y) * 0.1;
    // scale.clamp(Vector2.all(0.5), Vector2.all(1));
  }

  @override
  bool onDragStart(DragStartInfo info) {
    info.handled = true;
    return false;
  }

  @override
  bool onDragEnd(DragEndInfo info) {
    growing = false;
    return false;
  }

  @override
  bool onDragUpdate(DragUpdateInfo info) {
    position = info.eventPosition.game - size / 2;
    velocity.xy = (info.delta.game / 60);

    return true;
  }

  void float(double dt) {
    position += Vector2.all(sin(lifeTime * 3) * dt * 10);
  }
}
