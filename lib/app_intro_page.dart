import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppIntroPage extends StatelessWidget {
  const AppIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        title: const Text(
          '关于',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 应用图标和名称
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cake,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '小礼物',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 开发信息
            const Text(
              '开发信息',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('开发者', '遇见晴天'),
                  _buildInfoRow('开发框架', 'Flutter'),
                  _buildInfoRow('更新时间', '2025年10月9日'),
                  _buildInfoRow('说明', '本app是赠予一位朋友的生日礼物'),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 版权信息
            const Text(
              '许可证',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Apache License 2.0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本应用采用 Apache 许可证 2.0 版本开源。'
                    '\n\n您可以自由地使用、修改和分发本软件，但需要遵守以下条件：',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7F8C8D),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLicenseItem('• 保留版权声明'),
                  _buildLicenseItem('• 修改文件时需标注变更'),
                  _buildLicenseItem('• 包含许可证副本'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final Uri url = Uri.parse('https://github.com/zhuzilina/birthday_card/blame/main/LICENSE');
                      try {
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('无法打开链接'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('打开链接时出错: $e'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      '完整许可证文本请点击查看',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A90E2),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF4A90E2),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 第三方开源代码
            const Text(
              '第三方开放源代码许可',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '烟花模拟器',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本项目使用的烟花效果基于开源的烟花模拟器实现，'
                    '该项目采用 Apache License 2.0 许可证开源。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7F8C8D),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final Uri url = Uri.parse('https://github.com/zhuzilina/birthday_card/blob/main/assets/web/LICENSE');
                      try {
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('无法打开链接'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('打开链接时出错: $e'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      '查看烟花模拟器许可证',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A90E2),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7F8C8D),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF7F8C8D),
          height: 1.4,
        ),
      ),
    );
  }
}