import '../l10n/l10n.dart';
import '../models/graph.dart';
import 'sample_algorithms.dart';
import 'sample_graph.dart';
import 'sample_modules.dart';

/// 一条内置示例：标题、说明、预期输出，以及构建示例图的函数。
class SampleEntry {
  const SampleEntry({
    required this.title,
    required this.titleEn,
    required this.description,
    required this.descriptionEn,
    required this.expectOutput,
    required this.build,
  });

  final String title;
  final String titleEn;
  final String description;
  final String descriptionEn;

  /// 直接执行示例生成的 Lua 时，控制台应出现的输出（末尾去空白后比较）。
  final String expectOutput;

  final NodeGraph Function() build;

  /// 当前语言下展示的标题 / 说明。
  String get displayTitle => L10n.isEnglish ? titleEn : title;
  String get displayDescription => L10n.isEnglish ? descriptionEn : description;
}

/// 内置示例清单。第一条就是默认打开的「1 到 10 求和」，保持与原版一致。
final List<SampleEntry> kSamples = [
  SampleEntry(
    title: '1 到 10 求和',
    titleEn: 'Sum 1 to 10',
    description: 'for 循环 + 变量累加，最基础的执行流',
    descriptionEn: 'A for loop with a running sum — the most basic exec flow',
    expectOutput: 'sum =\t55',
    build: buildSampleGraph,
  ),
  SampleEntry(
    title: '阶乘 factorial',
    titleEn: 'Factorial',
    description: '带参数与返回值的函数：计算 5!',
    descriptionEn: 'A function with a parameter and a return value: 5!',
    expectOutput: '5! = 120',
    build: buildFactorialSample,
  ),
  SampleEntry(
    title: '斐波那契数列',
    titleEn: 'Fibonacci',
    description: '带参数的函数 + 循环维护两个变量：求 fib(10)',
    descriptionEn: 'A function with a parameter; a loop keeps two variables: fib(10)',
    expectOutput: 'fib(10) = 55',
    build: buildFibonacciSample,
  ),
  SampleEntry(
    title: '最大公约数 gcd',
    titleEn: 'GCD',
    description: '两个参数 + while 循环 + 取模：gcd(48, 36)',
    descriptionEn: 'Two parameters, a while loop and modulo: gcd(48, 36)',
    expectOutput: 'gcd(48, 36) = 12',
    build: buildGcdSample,
  ),
  SampleEntry(
    title: '素数判断',
    titleEn: 'Prime check',
    description: 'if/else 提前返回 + while 试除：判断 97 是否为素数',
    descriptionEn:
        'Early return with if/else plus trial division: is 97 prime?',
    expectOutput: 'true',
    build: buildPrimeSample,
  ),
  SampleEntry(
    title: '模块化求和',
    titleEn: 'Module sum',
    description: '用「求和模块」一个节点算 1 到 100 的和，不再手搭循环',
    descriptionEn:
        'One "Sum module" node totals 1..100 — no manual loop needed',
    expectOutput: 'sum(1..100) = 5050',
    build: buildModuleSumSample,
  ),
  SampleEntry(
    title: '表达式计算',
    titleEn: 'Expression',
    description: '一个「表达式」节点里写完 (a + b) * (a - b)',
    descriptionEn: 'Write (a + b) * (a - b) inside a single expression node',
    expectOutput: 'expr = 20',
    build: buildExpressionSample,
  ),
  SampleEntry(
    title: '加减乘除',
    titleEn: 'Arithmetic',
    description: '12 和 4 分别做加减乘除，四种专用运算节点',
    descriptionEn: 'Add, subtract, multiply and divide 12 by 4 with dedicated nodes',
    expectOutput: '12 + 4 = 16\n12 - 4 = 8\n12 * 4 = 48\n12 / 4 = 3.0',
    build: buildArithmeticSample,
  ),
];
