/*
 * Copyright 2025 遇见晴天
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart'; // flutter UI组件库
import 'package:flutter/services.dart'; // 一些系统服务需要用到
import 'package:shared_preferences/shared_preferences.dart'; // 用于app状态持久化存储
import 'dart:math' as math; // 导入数学库用于计算月亮轨迹
import 'dart:io' as io; // 用于平台检测
import 'package:flutter/foundation.dart' show kIsWeb; // 用于Web平台检测
import 'package:desktop_window/desktop_window.dart'; // 用于桌面窗口设置
import 'fireworks_page.dart'; // 导入烟花定制页面
import 'app_intro_page.dart'; // 导入app关于页面
import 'welcome_page.dart'; // 导入app欢迎页面

// 定义一个数据结构，用于存储每个关键时间点的天空颜色
class SkyTheme {
  final List<Color> colors; // 渐变颜色列表，固定为3个颜色
  final Alignment begin;     // 渐变起始位置
  final Alignment end;       // 渐变结束位置

  const SkyTheme({
    required this.colors,
    this.begin = Alignment.bottomCenter,
    this.end = Alignment.topCenter,
  }) : assert(colors.length == 3, 'SkyTheme must have exactly 3 colors for consistent interpolation.');
}

// 定义一天中不同时间点的"天空调色板"
// 所有主题的颜色列表都固定为3个，不足的用最后一个颜色填充
final Map<double, SkyTheme> skyThemes = {
  // 午夜 - 深邃的星空
  0.0: SkyTheme(colors: [Color(0xFF060922), Color(0xFF00020c), Color(0xFF00020c)]), // 补齐到3个颜色
  // 黎明前 - 天空开始出现微光
  5.0: SkyTheme(colors: [Color(0xFF1a2a6c), Color(0xFF0b0d2b), Color(0xFF0b0d2b)]), // 补齐到3个颜色
  // 日出 - 暖色调出现
  6.5: SkyTheme(colors: [Color(0xFF8AB8E6), Color(0xFFCDE8F4), Color(0xFFFFD8A8)]),
  // 上午 - 清澈的蓝天
  8.0: SkyTheme(colors: [Color(0xFF377ccf), Color(0xFF81c6f8), Color(0xFF81c6f8)]), // 补齐到3个颜色
  // 正午 - 天空最亮
  12.0: SkyTheme(colors: [Color(0xFF0089ff), Color(0xFF59d2fe), Color(0xFF59d2fe)]), // 补齐到3个颜色
  // 下午 - 蓝色开始加深
  16.0: SkyTheme(colors: [Color(0xFF0262c2), Color(0xFF6caaf5), Color(0xFF6caaf5)]), // 补齐到3个颜色
  // 日落 - 壮丽的晚霞
  18.5: SkyTheme(colors: [Color(0xFFf0cb62), Color(0xFFf58754), Color(0xFFa64d79)]),
  // 黄昏 - 天空变为深蓝和紫色
  20.0: SkyTheme(colors: [Color(0xFF1f253d), Color(0xFF535a8c), Color(0xFF535a8c)]), // 补齐到3个颜色
  // 深夜 - 回归静谧
  22.0: SkyTheme(colors: [Color(0xFF0a1033), Color(0xFF02041a), Color(0xFF02041a)]), // 补齐到3个颜色
};

class DynamicSkyBackground extends StatefulWidget {
  final Widget? child;

  const DynamicSkyBackground({Key? key, this.child}) : super(key: key);

  @override
  _DynamicSkyBackgroundState createState() => _DynamicSkyBackgroundState();
}

// 封装一个获取全屏状态的InheritedWidget
class FullscreenState extends InheritedWidget {
  final bool isFullscreen;

  const FullscreenState({
    super.key,
    required this.isFullscreen,
    required super.child,
  });

  static FullscreenState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FullscreenState>();
  }

  @override
  bool updateShouldNotify(FullscreenState oldWidget) {
    return isFullscreen != oldWidget.isFullscreen;
  }
}

class _DynamicSkyBackgroundState extends State<DynamicSkyBackground> {
  Timer? _timer;
  SkyTheme _currentTheme = skyThemes[12.0]!; // 初始值设为正午
  bool _isNight = false; // 控制是否显示月光（逻辑判断）
  Offset _moonPosition = Offset.zero; // 月亮位置

  // 用于月亮淡入淡出动画
  double _moonOpacity = 0.0;

  // 星星相关属性
  List<Widget> _stars = [];
  double _starsOpacity = 0.0;
  Size? _screenSize;
  bool _isFullscreen = false; // 全屏状态检测

  // 流星相关属性
  List<Widget> _meteors = [];
  Timer? _meteorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateScreenState(); // 更新屏幕状态
        _generateStars(); // 生成星星
        _updateSkyTheme(); // 立即计算一次当前颜色
        // 设置一个定时器，每2分钟更新一次天空颜色和月亮位置
        _timer = Timer.periodic(const Duration(minutes: 2), (timer) {
          _updateSkyTheme();
        });
        _startMeteorShower(); // 启动流星效果

        // Windows平台或Web平台监听窗口变化
        if (kIsWeb || io.Platform.isWindows) {
          _setupWindowListener();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 组件销毁时取消定时器，防止内存泄漏
    _meteorTimer?.cancel(); // 取消流星定时器
    super.dispose();
  }

  // 更新屏幕状态
  void _updateScreenState() {
    _screenSize = MediaQuery.of(context).size;

    // 检测是否全屏状态（简单判断：屏幕宽度大于1200或高度大于800时认为是类全屏状态）
    if (kIsWeb || io.Platform.isWindows) {
      _isFullscreen = _screenSize!.width > 1200 || _screenSize!.height > 800;
    } else {
      _isFullscreen = false;
    }
  }

  // 设置窗口变化监听
  void _setupWindowListener() {
    // 监听窗口变化（这里使用定时器定期检查）
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final newSize = MediaQuery.of(context).size;
      if (newSize != _screenSize) {
        final wasFullscreen = _isFullscreen;
        _updateScreenState();

        // 如果全屏状态发生变化，重新生成元素
        if (wasFullscreen != _isFullscreen) {
          setState(() {
            _generateStars();
          });
        }
      }
    });
  }

  // 生成随机星星
  void _generateStars() {
    if (_screenSize == null) return;

    final now = DateTime.now();
    final dateSeed = now.year * 10000 + now.month * 100 + now.day;
    final random = math.Random(dateSeed);

    final screenWidth = _screenSize!.width;
    final screenHeight = _screenSize!.height;

    // 计算屏幕面积比例，用于调整星星数量
    final screenArea = screenWidth * screenHeight;
    final baseArea = 375.0 * 667.0; // 基准屏幕面积
    var scaleFactor = (screenArea / baseArea).clamp(0.5, 3.0);

    // 全屏状态下增强星星效果
    if (_isFullscreen) {
      scaleFactor *= 1.5; // 全屏状态下增加50%的星星密度
    }

    // 生成更多星星，包括底部区域，根据屏幕尺寸调整数量
    final starCount = ((25 + random.nextInt(15)) * scaleFactor).round();
    final bottomStarCount = ((8 + random.nextInt(7)) * scaleFactor).round();

    _stars.clear();

    // 生成全屏星星
    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * screenWidth;
      final y = random.nextDouble() * screenHeight;
      final size = (1.0 + random.nextDouble() * 2.0) * scaleFactor.clamp(0.8, 1.5); // 根据屏幕调整大小
      final opacity = 0.3 + random.nextDouble() * 0.7; // 0.3-1.0透明度

      _stars.add(_createStar(x, y, size, opacity, random));
    }

    // 专门生成底部区域的星星
    for (int i = 0; i < bottomStarCount; i++) {
      final x = random.nextDouble() * screenWidth;
      final y = screenHeight * 0.7 + random.nextDouble() * screenHeight * 0.3; // 70%-100%高度区域
      final size = (0.8 + random.nextDouble() * 1.5) * scaleFactor.clamp(0.8, 1.2); // 底部星星稍小一点
      final opacity = 0.4 + random.nextDouble() * 0.6; // 0.4-1.0透明度

      _stars.add(_createStar(x, y, size, opacity, random));
    }
  }

  // 创建单个星星的辅助方法
  Widget _createStar(double x, double y, double size, double opacity, math.Random random) {
    return Positioned(
      left: x,
      top: y,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 1500 + random.nextInt(1000)),
        tween: Tween(begin: opacity * 0.5, end: opacity),
        builder: (context, value, child) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: value * 0.5),
                  blurRadius: size * 2,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 启动流星效果
  void _startMeteorShower() {
    _meteorTimer?.cancel(); // 先取消之前的定时器
    _scheduleNextMeteor();
  }

  // 安排下一个流星
  void _scheduleNextMeteor() {
    if (!mounted) return;

    final random = math.Random();
    final nextMeteorDelay = Duration(seconds: 3 + random.nextInt(12)); // 3-15秒随机间隔

    _meteorTimer = Timer(nextMeteorDelay, () {
      if (mounted && _isNight && _starsOpacity > 0.5) {
        _createMeteor();
        _scheduleNextMeteor(); // 安排下一个流星
      } else {
        // 如果不是夜晚，稍后再试
        _meteorTimer = Timer(const Duration(seconds: 30), _scheduleNextMeteor);
      }
    });
  }

  // 创建流星
  void _createMeteor() {
    if (_screenSize == null) return;

    final random = math.Random();
    final screenWidth = _screenSize!.width;
    final screenHeight = _screenSize!.height;

    // 计算屏幕缩放因子
    final baseArea = 375.0 * 667.0;
    final screenArea = screenWidth * screenHeight;
    var scaleFactor = (screenArea / baseArea).clamp(0.5, 3.0);

    // 全屏状态下增强流星效果
    if (_isFullscreen) {
      scaleFactor *= 1.3; // 全屏状态下增加流星轨迹长度
    }

    // 流星起始位置（从右上角区域）
    final startX = screenWidth * 0.6 + random.nextDouble() * screenWidth * 0.4;
    final startY = random.nextDouble() * screenHeight * 0.4;

    // 流星结束位置（向左下角移动）
    final endX = startX - (100 + random.nextDouble() * 100) * scaleFactor.clamp(0.8, 1.5);
    final endY = startY + (50 + random.nextDouble() * 150) * scaleFactor.clamp(0.8, 1.5);

    // 流星长度和速度
    final meteorLength = (30 + random.nextDouble() * 50) * scaleFactor.clamp(0.8, 1.5);
    final duration = 800 + random.nextInt(1200); // 0.8-2.0秒

    // 计算旋转角度
    final rotation = math.atan2(endY - startY, endX - startX);

    // 创建流星
    final meteorKey = GlobalKey();
    final meteor = TweenAnimationBuilder<double>(
      key: meteorKey,
      duration: Duration(milliseconds: duration),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, progress, child) {
        final currentX = startX + (endX - startX) * progress;
        final currentY = startY + (endY - startY) * progress;
        final currentOpacity = 1.0 - progress; // 逐渐消失

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: meteorLength,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: currentOpacity * 0.8),
                    Colors.white.withValues(alpha: currentOpacity),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );

    setState(() {
      _meteors.add(meteor);
    });

    // 流星动画结束后移除
    Timer(Duration(milliseconds: duration + 100), () {
      if (mounted) {
        setState(() {
          _meteors.removeWhere((element) => element.key == meteorKey);
        });
      }
    });
  }

  void _updateSkyTheme() {
    if (!mounted) return; // 添加安全检查

    final now = DateTime.now();
    final currentTime = now.hour + now.minute / 60.0;

    // 获取排序后的关键时间点列表
    final sortedTimes = skyThemes.keys.toList()..sort();

    // 找到当前时间前后的两个关键时间点
    // 处理跨午夜的情况，例如 23:00 -> 01:00
    double prevTime = sortedTimes.lastWhere((t) => t <= currentTime, orElse: () => sortedTimes.last);
    double nextTime = sortedTimes.firstWhere((t) => t > currentTime, orElse: () => sortedTimes.first);

    // 如果下一个时间点小于当前时间点（说明已经跨越午夜），则将下一个时间点加上24小时进行计算
    if (nextTime < currentTime) {
      nextTime += 24.0;
    }
    // 同样，如果当前时间比上一个时间点小（例如 01:00，而上一个时间点是 22:00），则上一个时间点减去24小时
    if (prevTime > currentTime && currentTime < sortedTimes.first) {
        prevTime -= 24.0; // 例如，0.0 (midnight) 应该从 22.0 (last evening) 过渡
    }


    final prevTheme = skyThemes[prevTime % 24.0]!; // 使用 % 24.0 确保取到正确的主题
    final nextTheme = skyThemes[nextTime % 24.0]!;


    // 计算当前时间在两个关键点之间的进度 (0.0 到 1.0)
    final timeRange = nextTime - prevTime;
    final progressInRange = currentTime - prevTime;
    final t = (progressInRange / timeRange).clamp(0.0, 1.0);

    // 对渐变的每个颜色进行线性插值，现在所有主题都有3个颜色，确保平滑过渡
    List<Color> interpolatedColors = [];
    for (int i = 0; i < 3; i++) {
      interpolatedColors.add(
        Color.lerp(prevTheme.colors[i], nextTheme.colors[i], t)!,
      );
    }

    // 计算月亮透明度（在黄昏和黎明时渐变）
    double newMoonOpacity = 0.0;

    // 黄昏渐变时间：19:30-20:30 (0.5小时过渡)
    if (currentTime >= 19.5 && currentTime < 20.5) {
      // 黄昏时月亮逐渐出现
      final fadeProgress = (currentTime - 19.5) / 1.0; // 0.0 到 1.0
      newMoonOpacity = fadeProgress.clamp(0.0, 1.0);
    }
    // 黎明渐变时间：5:30-6:30 (0.5小时过渡)
    else if (currentTime >= 5.5 && currentTime < 6.5) {
      // 黎明时月亮逐渐消失
      final fadeProgress = 1.0 - (currentTime - 5.5) / 1.0; // 1.0 到 0.0
      newMoonOpacity = fadeProgress.clamp(0.0, 1.0);
    }
    // 完整夜晚时间
    else if (currentTime >= 20.5 || currentTime < 5.5) {
      newMoonOpacity = 1.0; // 完全夜晚显示月亮
    }

    final isNightTime = newMoonOpacity > 0.0; // 根据透明度判断是否显示月亮

    // 计算星星透明度（从傍晚开始出现，黎明消失）
    double newStarsOpacity = 0.0;
    // 星星出现时间：19:00-20:00
    if (currentTime >= 19.0 && currentTime < 20.0) {
      final fadeProgress = (currentTime - 19.0) / 1.0;
      newStarsOpacity = fadeProgress.clamp(0.0, 0.8);
    }
    // 星星完全可见时间：20:00-05:00
    else if (currentTime >= 20.0 || currentTime < 5.0) {
      newStarsOpacity = 0.8;
    }
    // 星星消失时间：05:00-06:00
    else if (currentTime >= 5.0 && currentTime < 6.0) {
      final fadeProgress = 1.0 - (currentTime - 5.0) / 1.0;
      newStarsOpacity = fadeProgress.clamp(0.0, 0.8);
    }

    // 计算月亮位置
    Offset newMoonPosition = Offset.zero;

    if (isNightTime) {

      // 计算月亮在夜晚时间内的进度，从0.0到1.0
      // 夜晚总时长：从19:30到6:30，共11小时
      double moonCycleProgress;
      if (currentTime >= 19.5) { // 晚上7:30到午夜
        moonCycleProgress = (currentTime - 19.5) / 11.0;
      } else { // 午夜到早上6:30
        moonCycleProgress = (currentTime + 4.5) / 11.0;
      }
      moonCycleProgress = moonCycleProgress.clamp(0.0, 1.0); // 确保在0-1之间

      // 定义月亮路径：基于日期计算随机左边起始位置
      // 使用屏幕尺寸来计算月亮位置
      final double cardWidth = _screenSize?.width ?? 300.0;
      final double cardHeight = _screenSize?.height ?? 300.0;

      // 基于当前日期生成伪随机起始位置
      final now = DateTime.now();
      final dateSeed = now.year * 10000 + now.month * 100 + now.day;
      final random = math.Random(dateSeed);

      // 计算缩放因子
      final baseArea = 375.0 * 667.0;
      final screenArea = cardWidth * cardHeight;
      var scaleFactor = (screenArea / baseArea).clamp(0.5, 3.0);

      // 全屏状态下调整月亮轨迹
      if (_isFullscreen) {
        scaleFactor *= 1.2; // 全屏状态下增加月亮轨迹范围
      }

      // 月亮从左边随机位置出现
      final startMoonX = -100.0 * scaleFactor.clamp(0.8, 1.5); // 固定从左边外部开始
      final startMoonY = random.nextDouble() * cardHeight * 0.8; // Y轴随机位置（0-80%高度）

      // 基于起始位置计算对应的终点，形成对角线轨迹
      final endMoonX = cardWidth + 50.0 * scaleFactor.clamp(0.8, 1.5); // 固定从右边离开
      final endMoonY = startMoonY + (random.nextDouble() * 100 + 50) * scaleFactor.clamp(0.8, 1.5); // 基于起始Y计算结束Y

      // 控制点，创建弧形轨迹
      final controlMoonX = cardWidth * 0.5; // 中心点X
      final controlMoonY = math.min(startMoonY, endMoonY) - 50 * scaleFactor.clamp(0.8, 1.5); // 控制点在起始点和终点上方

      // 使用二次贝塞尔曲线公式进行插值
      final moonX = (1 - moonCycleProgress) * (1 - moonCycleProgress) * startMoonX +
                   2 * (1 - moonCycleProgress) * moonCycleProgress * controlMoonX +
                   moonCycleProgress * moonCycleProgress * endMoonX;
      final moonY = (1 - moonCycleProgress) * (1 - moonCycleProgress) * startMoonY +
                   2 * (1 - moonCycleProgress) * moonCycleProgress * controlMoonY +
                   moonCycleProgress * moonCycleProgress * endMoonY;

      newMoonPosition = Offset(moonX, moonY);
    }

    // 更新状态，触发界面刷新
    setState(() {
      _currentTheme = SkyTheme(
        colors: interpolatedColors,
        begin: prevTheme.begin,
        end: prevTheme.end,
      );
      _isNight = isNightTime;
      _moonPosition = newMoonPosition;
      _moonOpacity = newMoonOpacity; // 更新月亮透明度
      _starsOpacity = newStarsOpacity; // 更新星星透明度
    });
  }

  @override
  Widget build(BuildContext context) {
    return FullscreenState(
      isFullscreen: _isFullscreen,
      child: Stack(
        children: [
        // 使用 AnimatedContainer，当颜色变化时会自动产生平滑的动画过渡
        AnimatedContainer(
          duration: const Duration(seconds: 2), // 渐变动画的持续时间
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _currentTheme.colors,
              begin: _currentTheme.begin,
              end: _currentTheme.end,
            ),
            // 移除这里的 borderRadius，让外部控制容器的圆角
            // borderRadius: BorderRadius.circular(15),
          ),
          child: widget.child,
        ),
        // 月光效果，使用 Positioned 和 Opacity 实现淡入淡出
        if (_isNight)
          Positioned(
            left: _moonPosition.dx - (_screenSize?.width != null ? (100 * ((_screenSize!.width * _screenSize!.height) / (375.0 * 667.0)).clamp(0.8, 1.5)) : 100), // 根据屏幕尺寸调整月亮大小
            top: _moonPosition.dy - (_screenSize?.height != null ? (100 * ((_screenSize!.width * _screenSize!.height) / (375.0 * 667.0)).clamp(0.8, 1.5)) : 100),
            child: AnimatedOpacity(
              opacity: _moonOpacity, // 控制月光透明度
              duration: const Duration(seconds: 2), // 淡入淡出动画持续时间
              curve: Curves.easeInOut,
              child: Container(
                width: _screenSize?.width != null ? (200 * ((_screenSize!.width * _screenSize!.height) / (375.0 * 667.0)).clamp(0.8, 1.5)) : 200,
                height: _screenSize?.height != null ? (200 * ((_screenSize!.width * _screenSize!.height) / (375.0 * 667.0)).clamp(0.8, 1.5)) : 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFFFFFFF).withValues(alpha: 0.7),
                      Color(0xFFFFFACD).withValues(alpha: 0.5),
                      Color(0xFFFFFFE0).withValues(alpha: 0.3),
                      Color(0xFFFFFFE0).withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.2, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
        // 星星效果
        AnimatedOpacity(
          opacity: _starsOpacity,
          duration: const Duration(seconds: 3),
          curve: Curves.easeInOut,
          child: Stack(
            children: _stars,
          ),
        ),
        // 流星效果
        Stack(
          children: _meteors,
        ),
      ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置桌面版本默认窗口大小
  if (!kIsWeb && (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
    try {
      // 设置桌面应用窗口最小尺寸
      await DesktopWindow.setMinWindowSize(const Size(800, 1000));
      await DesktopWindow.setMaxWindowSize(const Size(1200, 1600));
      // 设置窗口初始大小
      await DesktopWindow.setWindowSize(const Size(900, 1100));
    } catch (e) {
      print('设置窗口大小失败: $e');
    }
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // 垂直向上
    DeviceOrientation.portraitDown, // 垂直向下（可选，如果允许180度旋转）
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小礼物',
      theme: ThemeData(
        fontFamily: 'FZSJ-TSYTJW',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const MainApp(),
        '/welcome': (context) => const WelcomePage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    bool isFirstLaunch = true; // 强制默认为首次启动
    bool hasLaunchedBefore = false;

    developer.log('🚀 开始检查首次启动状态（强制显示逻辑）...');

    // 在桌面环境中，使用文件系统检查是否是首次启动
    if (io.Platform.isWindows || io.Platform.isLinux) {
      try {
        final appDir = io.Directory.current;
        final markerFile = io.File('${appDir.path}/.launched_before');

        hasLaunchedBefore = await markerFile.exists();
        developer.log('📁 桌面环境 - 检查启动标记文件: $hasLaunchedBefore');

        if (!hasLaunchedBefore) {
          // 创建标记文件表示已启动过
          await markerFile.writeAsString('launched');
          developer.log('✅ 创建启动标记文件');
        }
      } catch (e) {
        developer.log('❌ 创建标记文件失败: $e');
      }
    } else {
      // 移动设备和Web使用SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        hasLaunchedBefore = prefs.getBool('hasLaunchedBefore') ?? false;
        developer.log('📱 移动环境 - SharedPreferences状态: $hasLaunchedBefore');

        if (!hasLaunchedBefore) {
          await prefs.setBool('hasLaunchedBefore', true);
          developer.log('✅ 设置SharedPreferences标志');
        }
      } catch (e) {
        developer.log('❌ SharedPreferences访问出错: $e');
      }
    }

    // 等待一秒钟，让用户看到启动画面
    await Future.delayed(const Duration(milliseconds: 1000));

    // 桌面端总是显示欢迎页面（测试）
    if (io.Platform.isWindows || io.Platform.isLinux) {
      isFirstLaunch = true;
      developer.log('🖥️ 桌面端 - 强制显示欢迎页面');
    } else {
      isFirstLaunch = !hasLaunchedBefore;
      developer.log('📱 移动端 - 首次启动=$isFirstLaunch');
    }

    developer.log('🎯 最终决定 - isFirstLaunch=$isFirstLaunch, mounted=$mounted');

    if (mounted) {
      if (isFirstLaunch) {
        developer.log('🎉 导航到欢迎页面');
        Navigator.pushReplacementNamed(context, '/welcome');
      } else {
        developer.log('🏠 导航到主页');
        Navigator.pushReplacementNamed(context, '/');
      }
    } else {
      developer.log('❌ 组件已销毁，无法导航');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/lunch_icon.jpg',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '小礼物',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
                fontFamily: 'FZSJ-TSYTJW',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '一份很小的生日贺卡',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'FZSJ-TSYTJW',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyHomePage(title: '生日贺卡');
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _buttonOpacity = 1.0;
  Timer? _hideButtonTimer;

  @override
  void initState() {
    super.initState();
    _scheduleButtonHide();
  }

  @override
  void dispose() {
    _hideButtonTimer?.cancel();
    super.dispose();
  }

  void _scheduleButtonHide() {
    _hideButtonTimer?.cancel();
    _hideButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _buttonOpacity = 0.0;
        });
      }
    });
  }

  void _showButtonTemporarily() {
    setState(() {
      _buttonOpacity = 1.0;
    });
    _scheduleButtonHide();
  }

  bool _isDaytime() {
    final now = DateTime.now();
    final currentTime = now.hour + now.minute / 60.0;
    // 白天时间：6:00 - 18:00
    return currentTime >= 6.0 && currentTime < 18.0;
  }

  void _openFireworks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FireworksPage()),
    );
  }

  Future<String> _loadLetterText() async {
    final String response = await rootBundle.loadString('assets/txt/letter.txt');
    return response;
  }

  void _showNoteCard() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<String>(
          future: _loadLetterText(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text('加载失败'),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 300,
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Text(
                                  snapshot.data ?? '',
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                '关闭',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 38,
                      bottom: 33,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AppIntroPage(),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AnimatedOpacity(
        opacity: _buttonOpacity,
        duration: const Duration(milliseconds: 500),
        child: FloatingActionButton(
          onPressed: () {
            _showButtonTemporarily();
            if (_isDaytime()) {
              _showNoteCard();
            } else {
              _openFireworks();
            }
          },
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          tooltip: _isDaytime() ? '查看贺卡' : '看烟花',
          mini: true,
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              _isDaytime() ? 'assets/images/little_note.png' : 'assets/images/fireworks.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _showButtonTemporarily,
        child: DynamicSkyBackground(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                Container(
                  constraints: BoxConstraints(
                    minWidth: 300,
                    minHeight: 600,
                    maxWidth: 600, // 限制最大宽度，避免在大屏幕上过大
                    maxHeight: 1000, // 限制最大高度
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // 根据可用空间动态调整卡片大小
                        double cardSize = [constraints.maxWidth * 0.9, constraints.maxHeight * 0.7].reduce(math.min);

                        // 全屏状态下允许更大的卡片尺寸
                        final isFullscreen = FullscreenState.of(context)?.isFullscreen ?? false;
                        if (isFullscreen) {
                          cardSize = math.min(cardSize, math.min(MediaQuery.of(context).size.width * 0.5, 800)); // 全屏时最大50%宽度，800px
                          cardSize = math.min(cardSize, math.min(MediaQuery.of(context).size.height * 0.7, 800)); // 全屏时最大70%高度，800px
                          cardSize = cardSize.clamp(400.0, 800.0); // 全屏时最小400px，最大800px
                        } else {
                          cardSize = math.min(cardSize, math.min(MediaQuery.of(context).size.width * 0.6, 600)); // 普通屏幕最大60%宽度，600px
                          cardSize = math.min(cardSize, math.min(MediaQuery.of(context).size.height * 0.6, 600)); // 普通屏幕最大60%高度，600px
                          cardSize = cardSize.clamp(300.0, 600.0); // 普通屏幕最小300px，最大600px
                        }

                        return Container(
                          width: cardSize,
                          height: cardSize,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            image: DecorationImage(
                              image: AssetImage('assets/images/card.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: cardSize * 0.07, // 22/300 的比例
                            bottom: cardSize * 0.45, // 135/300 的比例
                            child: Text(
                              'to:WYQ',
                              style: TextStyle(
                                fontFamily: 'FZSJ-TSYTJW',
                                fontSize: cardSize * 0.073, // 22/300 的比例
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            left: cardSize * 0.1, // 30/300 的比例
                            bottom: cardSize * 0.15, // 46/300 的比例
                            child: Text(
                              '春风十里\n贺卿良辰',
                              style: TextStyle(
                                fontFamily: 'FZSJ-TSYTJW',
                                fontSize: cardSize * 0.107, // 32/300 的比例
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: cardSize * 0.02, // 7/300 的比例
                            child: Center(
                              child: Text(
                                '一岁一礼    一寸欢喜',
                                style: TextStyle(
                                  fontFamily: 'FZSJ-TSYTJW',
                                  fontSize: cardSize * 0.073, // 22/300 的比例
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: cardSize * 0.02, // 7/300 的比例
                            bottom: cardSize * 0.07, // 20/300 的比例
                            child: Transform.rotate(
                              angle: 45 * -math.pi / 180, // 使用 math.pi
                              child: Text(
                                'from:zzl',
                                style: TextStyle(
                                  fontFamily: 'FZSJ-TSYTJW',
                                  fontSize: cardSize * 0.04, // 12/300 的比例
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    },
                  ),
                    ],
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}