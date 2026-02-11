# Chromatix (幻色龙)

**Version:** 1.0.0  
**Author:** David W Zhang  
**Interface:** 120000

## 简介 (Introduction)
Chromatix 是一个魔兽世界插件，旨在根据你当前的专精（Specialization）自动切换装备方案（Equipment Set）。

## 功能 (Features)
- **自动切换**: 切换专精时自动装备关联的套装。
- **一键创建**: 在装备管理界面增加“新的天赋方案”按钮，快速创建以当前专精命名的套装。
- **智能命名**: 支持英文（如 "Retribution"）或本地化（如 "惩戒"）命名方式。
- **战斗保护**: 战斗中触发的切换操作会自动延迟到战斗结束后执行。

## 命令 (Commands)
- `/chromatix config` - 打开设置面板
- `/chromatix status` - 查看当前状态
- `/chromatix swap` - 手动触发切换
- `/chromatix debug` - 调试模式

## 安装 (Installation)
将 `Chromatix` 文件夹放置于 `_retail_\Interface\AddOns\` 目录下。

## License
MIT