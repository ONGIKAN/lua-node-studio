import '../models/graph.dart';
import 'sample_algorithms.dart';
import 'sample_graph.dart';

/// 一条内置示例：标题、说明、预期输出，以及构建示例图的函数。
class SampleEntry {
  const SampleEntry({
    required this.title,
    required this.description,
    required this.expectOutput,
    required this.build,
  });

  final String title;
  final String description;

  /// 直接执行示例生成的 Lua 时，控制台应出现的输出（末尾去空白后比较）。
  final String expectOutput;

  final NodeGraph Function() build;
}

/// 内置示例清单。第一条就是默认打开的「1 到 10 求和」，保持与原版一致。
final List<SampleEntry> kSamples = [
  SampleEntry(
    title: '1 到 10 求和',
    description: 'for 循环 + 变量累加，最基础的执行流',
    expectOutput: 'sum =\t55',
    build: buildSampleGraph,
  ),
  SampleEntry(
    title: '阶乘 factorial',
    description: '带参数与返回值的函数：计算 5!',
    expectOutput: '5! = 120',
    build: buildFactorialSample,
  ),
  SampleEntry(
    title: '斐波那契数列',
    description: '带参数的函数 + 循环维护两个变量：求 fib(10)',
    expectOutput: 'fib(10) = 55',
    build: buildFibonacciSample,
  ),
  SampleEntry(
    title: '最大公约数 gcd',
    description: '两个参数 + while 循环 + 取模：gcd(48, 36)',
    expectOutput: 'gcd(48, 36) = 12',
    build: buildGcdSample,
  ),
  SampleEntry(
    title: '素数判断',
    description: 'if/else 提前返回 + while 试除：判断 97 是否为素数',
    expectOutput: 'true',
    build: buildPrimeSample,
  ),
];
