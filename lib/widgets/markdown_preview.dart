import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/constants.dart';

/// 主编辑器和外部文件编辑器共用的 Markdown 渲染内容。
///
/// 该组件只负责正文渲染，不包裹阅读纸张或边框，调用方可按编辑、预览、
/// 分屏等场景安排滚动和留白，避免两套预览样式逐步偏离。
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.data,
    this.imageDirectory,
  });

  final String data;

  /// 外部文件预览可传入文档所在目录，使相对图片地址按原文件位置加载。
  final String? imageDirectory;

  @override
  Widget build(BuildContext context) {
    const h1Style = TextStyle(
      fontSize: AppFontSize.title,
      fontWeight: FontWeight.w600,
      height: 1.28,
      color: AppColors.textPrimary,
      fontFamily: 'serif',
    );
    const h2Style = TextStyle(
      fontSize: AppFontSize.xxl,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: AppColors.textPrimary,
      fontFamily: 'serif',
    );
    const h3Style = TextStyle(
      fontSize: AppFontSize.xl,
      fontWeight: FontWeight.w600,
      height: 1.45,
      color: AppColors.textPrimary,
    );
    const bodyStyle = TextStyle(
      fontSize: AppFontSize.base,
      height: 1.85,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w400,
    );

    return Markdown(
      data: data,
      selectable: true,
      padding: EdgeInsets.zero,
      imageDirectory: imageDirectory,
      builders: {
        'h1': _HeadingBackgroundBuilder(
          textStyle: h1Style,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.72),
          accentWidth: 4,
        ),
        'h2': _HeadingBackgroundBuilder(
          textStyle: h2Style,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.48),
          accentWidth: 3,
        ),
        'h3': _HeadingBackgroundBuilder(
          textStyle: h3Style,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.28),
          accentWidth: 3,
        ),
      },
      styleSheet: MarkdownStyleSheet(
        h1: h1Style,
        h1Padding: const EdgeInsets.only(bottom: AppSpacing.md),
        h2: h2Style,
        h2Padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        h3: h3Style,
        h3Padding: const EdgeInsets.only(top: AppSpacing.xs),
        p: bodyStyle,
        pPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        blockSpacing: AppSpacing.lg,
        listIndent: AppSpacing.xl,
        listBullet: const TextStyle(
          fontSize: AppFontSize.base,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        listBulletPadding: const EdgeInsets.only(right: AppSpacing.sm),
        code: const TextStyle(
          fontSize: AppFontSize.sm,
          backgroundColor: AppColors.primaryLight,
          color: AppColors.primaryDark,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.borderColor,
            width: 1,
          ),
        ),
        codeblockPadding: const EdgeInsets.all(AppSpacing.lg),
        blockquote: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        blockquoteDecoration: BoxDecoration(
          border: const Border(
            left: BorderSide(
              color: AppColors.primary,
              width: 3,
            ),
          ),
          color: AppColors.primaryLight.withValues(alpha: 0.28),
        ),
        tableHead: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        tableBody: bodyStyle,
        tableBorder: TableBorder.all(
          color: AppColors.borderColor,
          width: 0.7,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        a: const TextStyle(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.borderColor,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 标题整行背景与左侧强调线。
/// Markdown 默认的 TextStyle.backgroundColor 只覆盖文字，不能形成阅读器中的标题块。
class _HeadingBackgroundBuilder extends MarkdownElementBuilder {
  _HeadingBackgroundBuilder({
    required this.textStyle,
    required this.backgroundColor,
    this.accentWidth = 4,
  });

  final TextStyle textStyle;
  final Color backgroundColor;
  final double accentWidth;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(color: AppColors.primary, width: accentWidth),
        ),
      ),
      child: Text(element.textContent, style: preferredStyle ?? textStyle),
    );
  }
}
