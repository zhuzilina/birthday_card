import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math; // 导入数学库用于计算月亮轨迹
import 'fireworks_page.dart'; // 假设这个文件存在且内容正确

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

class _DynamicSkyBackgroundState extends State<DynamicSkyBackground> {
  Timer? _timer;
  SkyTheme _currentTheme = skyThemes[12.0]!; // 初始值设为正午
  bool _isNight = false; // 控制是否显示月光（逻辑判断）
  Offset _moonPosition = Offset.zero; // 月亮位置

  // 用于月亮淡入淡出动画
  double _moonOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateSkyTheme(); // 立即计算一次当前颜色
        // 设置一个定时器，每2分钟更新一次天空颜色和月亮位置
        _timer = Timer.periodic(const Duration(minutes: 2), (timer) {
          _updateSkyTheme();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 组件销毁时取消定时器，防止内存泄漏
    super.dispose();
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
      // 使用固定的卡片尺寸(300x300)来计算月亮位置
      final double cardWidth = 300.0;
      final double cardHeight = 300.0;

      // 基于当前日期生成伪随机起始位置
      final now = DateTime.now();
      final dateSeed = now.year * 10000 + now.month * 100 + now.day;
      final random = math.Random(dateSeed);

      // 月亮从左边随机位置出现
      final startMoonX = -100.0; // 固定从左边外部开始
      final startMoonY = random.nextDouble() * cardHeight * 0.8; // Y轴随机位置（0-80%高度）

      // 基于起始位置计算对应的终点，形成对角线轨迹
      final endMoonX = cardWidth + 50.0; // 固定从右边离开
      final endMoonY = startMoonY + (random.nextDouble() * 100 + 50); // 基于起始Y计算结束Y

      // 控制点，创建弧形轨迹
      final controlMoonX = cardWidth * 0.5; // 中心点X
      final controlMoonY = math.min(startMoonY, endMoonY) - 50; // 控制点在起始点和终点上方

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
            left: _moonPosition.dx - 100, // 根据月亮实际尺寸进行偏移，使其中心在_moonPosition
            top: _moonPosition.dy - 100,
            child: AnimatedOpacity(
              opacity: _moonOpacity, // 控制月光透明度
              duration: const Duration(seconds: 2), // 淡入淡出动画持续时间
              curve: Curves.easeInOut,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFFFFFFF).withOpacity(0.7),
                      Color(0xFFFFFACD).withOpacity(0.5),
                      Color(0xFFFFFFE0).withOpacity(0.3),
                      Color(0xFFFFFFE0).withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.2, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '生日贺卡'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _openFireworks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FireworksPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicSkyBackground( // 将 DynamicSkyBackground 直接作为 Scaffold 的 body
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                constraints: BoxConstraints(
                  minWidth: 300,
                  minHeight: 400,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 这个 Stack 内部的 DynamicSkyBackground 已经被移动到 Scaffold 的 body
                    // 这里只需要显示卡片内容
                    Container(
                      width: 300,
                      height: 300,
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
                            left: 22,
                            bottom: 135,
                            child: Text(
                              'to:WYQ',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 38,
                            bottom: 50,
                            child: Text(
                              '春风十里\n贺卿良辰',
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 6,
                            child: Center(
                              child: Text(
                                '一岁一礼    一寸欢喜',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 7,
                            bottom: 20,
                            child: Transform.rotate(
                              angle: 45 * -math.pi / 180, // 使用 math.pi
                              child: Text(
                                'from:zzl',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _openFireworks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '看烟花 🎆',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.celebration, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}