
## 使用方法

1. 首次运行时，选择"2"安装依赖：
   - 自动检测系统类型
   - 安装必要的Python包和依赖

2. 选择"1"运行IPTV工具：
   - 选择M3U源（在线URL或本地文件）
   - 输入要筛选的频道关键词（如：CCTV、卫视、4K等）
   - 选择源质量偏好
   - 等待处理完成

3. 如需卸载依赖，选择"3"

## 源质量选项说明

1. 优先高清源 (1080P)
   - 适合大多数家庭宽带用户
2. 优先超清源 (4K)
   - 需要较大带宽（建议100M以上）
3. 优先低码率源
   - 适合网络不稳定用户
4. 优先高码率源
   - 画质最好，需要大带宽
5. 按推荐设置自动选择
   - 自动平衡各项参数

## 注意事项

- 需要root权限运行
- 支持Ubuntu/Debian和CentOS系统
- 需要网络连接以获取EPG数据
- 生成的文件保存在当前目录

## 运行方法
```
# 国内用户（推荐）
bash <(curl -s https://www.ghproxy.cn/raw.githubusercontent.com/yl948/iptvtool/refs/heads/main/iptvtool.sh)

# 或者使用sudo运行（如果需要root权限）
sudo bash <(curl -s https://www.ghproxy.cn/raw.githubusercontent.com/yl948/iptvtool/refs/heads/main/iptvtool.sh)
```

```
# 直接运行
bash <(curl -s https://raw.githubusercontent.com/yl948/iptvtool/refs/heads/main/iptvtool.sh)

# 或者使用sudo运行
sudo bash <(curl -s https://raw.githubusercontent.com/yl948/iptvtool/refs/heads/main/iptvtool.sh)
```
## 项目地址

https://github.com/yl948/iptvtool
