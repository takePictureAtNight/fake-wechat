/// 应用环境配置：修改此处即可切换后端地址，无需改动业务代码。
///
/// 说明：
/// - [apiBaseUrl] 为 Spring Boot 根地址，**不要**末尾斜杠。
/// - 模拟器连本机可用 `http://10.0.2.2:8080`（Android）或 `http://127.0.0.1:8080`（iOS）。
/// - 真机请使用电脑局域网 IP，且与后端 `server.port` 一致。
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = 'http://192.168.1.6:8080';
}
