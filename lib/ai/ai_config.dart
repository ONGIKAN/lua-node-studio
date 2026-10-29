import '../storage/project_store.dart';

/// 自定义 AI API 配置（OpenAI 兼容接口）。
///
/// 只保存在本机的工程设置文件 `__settings.json` 里，不会上传到任何地方；
/// 请求只会发往用户填写的 [baseUrl]。
class AiConfig {
  const AiConfig({
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  static const AiConfig empty = AiConfig();

  /// 至少要有地址和模型才能对话（本地部署的模型允许不填 API Key）。
  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  /// 补全成可直接 POST 的 `/chat/completions` 地址。
  ///
  /// - 已以 `/chat/completions` 结尾：原样使用
  /// - 以 `/v1` 结尾：追加 `/chat/completions`
  /// - 其它：追加 `/v1/chat/completions`
  String get endpoint {
    var base = baseUrl.trim();
    if (base.isEmpty) return '';
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) return base;
    if (base.endsWith('/v1')) return '$base/chat/completions';
    return '$base/v1/chat/completions';
  }

  AiConfig copyWith({String? baseUrl, String? apiKey, String? model}) => AiConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  static AiConfig fromJson(Map<String, dynamic> j) => AiConfig(
        baseUrl: (j['baseUrl'] as String?) ?? empty.baseUrl,
        apiKey: (j['apiKey'] as String?) ?? '',
        model: (j['model'] as String?) ?? empty.model,
      );
}

/// 读写 [AiConfig]（落盘在工程目录的 `__settings.json` 里）。
class AiConfigStore {
  AiConfigStore(this.store);

  final ProjectStore store;

  static const String _keyBaseUrl = 'ai.baseUrl';
  static const String _keyApiKey = 'ai.apiKey';
  static const String _keyModel = 'ai.model';

  /// 用户是否真正完成过“保存并测试连接”。
  ///
  /// 仅凭默认地址/模型不算已配置——首次打开 AI 功能时仍然要提示先设置。
  static const String _keyConfigured = 'ai.configured';

  Future<AiConfig> load() async {
    final baseUrl = await store.loadSetting(_keyBaseUrl);
    final apiKey = await store.loadSetting(_keyApiKey);
    final model = await store.loadSetting(_keyModel);
    return AiConfig(
      baseUrl: (baseUrl ?? '').trim().isEmpty ? AiConfig.empty.baseUrl : baseUrl!,
      apiKey: apiKey ?? '',
      model: (model ?? '').trim().isEmpty ? AiConfig.empty.model : model!,
    );
  }

  /// 用户是否已经成功保存并测试过连接。
  Future<bool> loadConfigured() async {
    final value = await store.loadSetting(_keyConfigured);
    return value == 'true';
  }

  Future<void> save(AiConfig config) async {
    await store.saveSetting(_keyBaseUrl, config.baseUrl.trim());
    await store.saveSetting(_keyApiKey, config.apiKey.trim());
    await store.saveSetting(_keyModel, config.model.trim());
  }

  /// 连接测试通过后标记为已配置。
  Future<void> markConfigured() async {
    await store.saveSetting(_keyConfigured, 'true');
  }
}
