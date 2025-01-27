#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "无法检测操作系统类型"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            print_info "检测到 $OS $VER 系统"
            print_info "开始安装依赖..."
            
            # 更新包列表
            apt-get update
            
            # 安装Python3和pip3
            apt-get install -y python3 python3-pip
            
            # 安装依赖包
            apt-get install -y python3-requests python3-bs4 ca-certificates
            
            # 使用pip安装可能缺少的包
            pip3 install --break-system-packages requests beautifulsoup4
            ;;
            
        "CentOS Linux"|"Red Hat Enterprise Linux")
            print_info "检测到 $OS $VER 系统"
            print_info "开始安装依赖..."
            
            # 安装EPEL源
            yum install -y epel-release
            
            # 安装Python3和pip3
            yum install -y python3 python3-pip
            
            # 安装依赖包
            yum install -y python3-requests python3-beautifulsoup4 ca-certificates
            
            # 使用pip安装可能缺少的包
            pip3 install requests beautifulsoup4
            ;;
            
        *)
            print_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    
    local missing_deps=()
    
    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    # 检查pip3
    if ! command -v pip3 &> /dev/null; then
        missing_deps+=("python3-pip")
    fi
    
    # 检查Python模块
    if ! python3 -c "import requests" 2>/dev/null; then
        missing_deps+=("python3-requests")
    fi
    
    if ! python3 -c "import bs4" 2>/dev/null; then
        missing_deps+=("python3-bs4")
    fi
    
    # 检查证书
    if [ ! -d "/etc/ssl/certs" ]; then
        missing_deps+=("ca-certificates")
    fi
    
    # 如果有缺失的依赖，显示提示
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warn "以下依赖缺失:"
        for dep in "${missing_deps[@]}"; do
            print_warn "  - $dep"
        done
        
        print_info "是否自动安装缺失的依赖? (y/N)"
        read -r choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            install_deps
        else
            print_error "请手动安装缺失的依赖后再运行"
            exit 1
        fi
    else
        print_info "所有依赖已满足"
    fi
}

# 创建Python脚本
create_python_script() {
    cat > iptv.py << 'EOL'
#!/usr/bin/python3
# -*- coding: utf-8 -*-

import re
import requests
from bs4 import BeautifulSoup
import os
import socket
import time
from urllib.parse import urlparse, parse_qs
from collections import Counter

def is_valid_url(url):
    """检查是否是有效的URL"""
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except:
        return False

def load_m3u_content(source):
    """加载m3u内容,支持URL和本地文件"""
    try:
        if is_valid_url(source):
            print(f"正在从URL下载m3u文件: {source}")
            response = requests.get(source, timeout=10)
            response.raise_for_status()
            return response.text
        else:
            if not os.path.exists(source):
                raise FileNotFoundError(f"找不到文件: {source}")
            print(f"正在读取本地文件: {source}")
            with open(source, 'r', encoding='utf-8') as f:
                return f.read()
    except requests.exceptions.RequestException as e:
        print(f"下载m3u文件失败: {e}")
        return None
    except Exception as e:
        print(f"读取m3u文件失败: {e}")
        return None

def get_m3u_source():
    """获取m3u源"""
    while True:
        print("\n请选择m3u源类型:")
        print("1. 输入m3u文件URL")
        print("2. 输入本地m3u文件路径")
        print("3. 使用默认本地文件(./iptv.m3u)")
        
        choice = input("\n请选择 (1-3): ").strip()
        
        if choice == '1':
            url = input("请输入m3u文件URL: ").strip()
            if is_valid_url(url):
                return url
            print("无效的URL,请重新输入")
        
        elif choice == '2':
            path = input("请输入本地m3u文件路径: ").strip()
            if os.path.exists(path):
                return path
            print("文件不存在,请重新输入")
        
        elif choice == '3':
            default_path = './iptv.m3u'
            if os.path.exists(default_path):
                return default_path
            print("默认文件不存在,请选择其他选项")
        
        else:
            print("无效的选择,请重新输入")

def check_network_capabilities():
    """检查当前网络环境的能力"""
    capabilities = {
        'ipv4': {'available': False, 'speed': 0},
        'ipv6': {'available': False, 'speed': 0}
    }
    
    # 检查IPv4连接和速度
    try:
        start_time = time.time()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect(('8.8.8.8', 53))
        capabilities['ipv4']['available'] = True
        capabilities['ipv4']['speed'] = 1 / (time.time() - start_time)
    except:
        pass
    finally:
        sock.close()
    
    # 检查IPv6连接和速度
    try:
        start_time = time.time()
        sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect(('2001:4860:4860::8888', 53))
        capabilities['ipv6']['available'] = True
        capabilities['ipv6']['speed'] = 1 / (time.time() - start_time)
    except:
        pass
    finally:
        sock.close()
    
    # 自动决定IP偏好
    if capabilities['ipv4']['available'] and capabilities['ipv6']['available']:
        if capabilities['ipv4']['speed'] > capabilities['ipv6']['speed']:
            capabilities['preference'] = 'ipv4'
        else:
            capabilities['preference'] = 'ipv6'
    elif capabilities['ipv4']['available']:
        capabilities['preference'] = 'ipv4'
    elif capabilities['ipv6']['available']:
        capabilities['preference'] = 'ipv6'
    else:
        capabilities['preference'] = None
        
    return capabilities

def get_epg_data():
    """从EPG网站获取频道信息"""
    try:
        print("\n请选择EPG数据源:")
        print("1. 使用默认EPG源")
        print("2. 使用自定义EPG源")
        print("3. 不使用EPG数据")
        
        while True:
            choice = input("\n请选择 (1-3): ").strip()
            
            if choice == '3':
                print("将不使用EPG数据")
                return {}
                
            if choice == '1':
                # 使用稳定的EPG数据源
                urls = [
                    'http://epg.51zmt.top:8000/e.xml'  # 全部频道数据源
                ]
                
                for url in urls:
                    try:
                        print(f"\n正在尝试获取EPG数据 ({url})...")
                        response = requests.get(url, timeout=5)
                        response.raise_for_status()
                        response.encoding = 'utf-8'
                        content = response.text
                        
                        channels = {}
                        # 根据不同格式解析数据
                        if url.endswith('.txt') or url.endswith('/diyp/'):
                            # 解析txt格式
                            for line in content.splitlines():
                                if ',' in line:
                                    parts = line.split(',')
                                    if len(parts) >= 2:
                                        channel_id = parts[0].strip()
                                        name = parts[1].strip()
                                        channels[name] = {
                                            'id': channel_id,
                                            'name': name,
                                            'logo': f"https://epg.112114.xyz/logo/{name}.png"
                                        }
                        elif url.endswith('.xml'):
                            # 解析xml格式
                            import xml.etree.ElementTree as ET
                            from io import StringIO
                            try:
                                tree = ET.parse(StringIO(content))
                                root = tree.getroot()
                                for channel in root.findall('.//channel'):
                                    channel_id = channel.get('id', '')
                                    name_elem = channel.find('display-name')
                                    if name_elem is not None and channel_id:
                                        name = name_elem.text.strip()
                                        channels[name] = {
                                            'id': channel_id,
                                            'name': name,
                                            'logo': f"https://epg.112114.xyz/logo/{name}.png"
                                        }
                            except ET.ParseError:
                                continue
                        
                        if channels:
                            print(f"成功获取 {len(channels)} 个频道的EPG信息")
                            return channels
                            
                    except Exception as e:
                        print(f"尝试获取EPG数据失败: {e}")
                        continue
                
                print("所有EPG源都无法访问")
                return {}
                    
            elif choice == '2':
                while True:
                    url = input("\n请输入EPG数据文件的URL: ").strip()
                    if url.startswith(('http://', 'https://')):
                        break
                    print("请输入有效的URL地址")
                    
                try:
                    response = requests.get(url, timeout=10)
                    response.raise_for_status()
                    response.encoding = 'utf-8'
                    content = response.text
                    
                    channels = {}
                    # 解析自定义格式的数据
                    for line in content.splitlines():
                        if ',' in line:
                            parts = line.split(',')
                            if len(parts) >= 2:
                                channel_id = parts[0].strip()
                                name = parts[1].strip()
                                channels[name] = {
                                    'id': channel_id,
                                    'name': name,
                                    'logo': f"https://epg.112114.xyz/logo/{name}.png"
                                }
                    
                    if channels:
                        print(f"成功获取 {len(channels)} 个频道的EPG信息")
                        return channels
                    else:
                        print("未能从EPG源获取到频道信息")
                        return {}
                        
                except Exception as e:
                    print(f"获取EPG数据失败: {e}")
                    return {}
            else:
                print("无效的选择，请重新输入")
                
    except Exception as e:
        print(f"警告: 无法获取EPG数据: {str(e)}")
        print("将使用本地匹配")
        return {}

def get_source_preference():
    """获取用户对源的偏好设置"""
    print("\n请选择源的优先级:")
    print("1. 优先高清源 (1080P)")
    print("   - 优先选择1080P的源")
    print("   - 适合大多数家庭宽带用户")
    print("   - 画质清晰，带宽占用适中")
    
    print("\n2. 优先超清源 (4K)")
    print("   - 优先选择4K/2160P的源")
    print("   - 需要较大带宽（建议100M以上）")
    print("   - 适合网络条件较好的用户")
    
    print("\n3. 优先低码率源")
    print("   - 选择码率较低的源")
    print("   - 适合网络不稳定或带宽较小的用户")
    print("   - 更流畅，但画质可能略差")
    
    print("\n4. 优先高码率源")
    print("   - 选择码率最高的源")
    print("   - 需要较大带宽")
    print("   - 画质最好，但可能不够流畅")
    
    print("\n5. 按推荐设置自动选择")
    print("   - 平衡考虑分辨率、码率和响应时间")
    print("   - 自动选择最适合的源")
    print("   - 适合不确定选什么的用户")
    
    while True:
        choice = input("\n请选择 (1-5): ").strip()
        if choice in ['1', '2', '3', '4', '5']:
            preferences = {
                '1': {'target_resolution': 1080, 'rate_weight': 0, 'resolution_weight': 2},
                '2': {'target_resolution': 2160, 'rate_weight': 1, 'resolution_weight': 2},
                '3': {'rate_weight': -2, 'resolution_weight': 0},
                '4': {'rate_weight': 2, 'resolution_weight': 0},
                '5': {'rate_weight': 1, 'resolution_weight': 1}
            }
            return preferences[choice]
        print("无效的选择,请重新输入")

def parse_m3u_content(content, keyword, network_info):
    """解析m3u内容"""
    channels = {}
    current_channel = None
    
    for line in content.splitlines():
        line = line.strip()
        if line.startswith('#EXTINF'):
            print(f"检查行: {line}")  # 调试信息
            
            # 获取频道名称
            name_match = re.search(r'tvg-name="([^"]*)"', line) or \
                        re.search(r'group-title="[^"]*",\s*([^,]+)$', line) or \
                        re.search(r',([^,]+)$', line)
            
            if name_match:
                channel_name = name_match.group(1).strip()
                # 在频道名称和整行中查找关键词
                keyword_upper = keyword.upper()
                name_upper = channel_name.upper()
                line_upper = line.upper()
                
                # 特殊处理卫视关键词
                is_match = False
                if keyword_upper == '卫视':
                    is_match = ('卫视' in line or '卫视频道' in line)
                elif keyword_upper == 'CCTV':
                    # 对CCTV进行特殊处理
                    is_match = ('CCTV' in name_upper or 'CCTV' in line_upper or
                              'group-title="央视"' in line or 
                              'group-title="CCTV"' in line)
                else:
                    is_match = (keyword_upper in name_upper or
                              keyword_upper in line_upper or
                              keyword_upper in name_upper.replace(' ', '') or
                              keyword_upper in line_upper.replace(' ', ''))
                
                if is_match:
                    print(f"匹配到关键词: {keyword}")
                    channel_info = {
                        'name': channel_name,
                        'extinf': line,
                        'display_name': line.split(',')[-1].strip()
                    }
                    
                    # 从EXTINF行解析分辨率
                    resolution = 0
                    if '4K' in line or '2160P' in line.upper():
                        resolution = 2160
                    elif '1080P' in line.upper() or 'FHD' in line.upper():
                        resolution = 1080
                    elif '720P' in line.upper() or 'HD' in line.upper():
                        resolution = 720
                    elif '576P' in line.upper() or 'SD' in line.upper():
                        resolution = 576
                    elif '480P' in line.upper():
                        resolution = 480
                    channel_info['resolution'] = resolution
                    
                    current_channel = channel_info
                else:
                    print(f"未匹配到关键词: {keyword}")
                    current_channel = None
            else:
                current_channel = None

        elif line.startswith('http') and current_channel:
            # 不再过滤URL
            current_channel['url'] = line
            
            # 从URL中提取信息
            url_parts = urlparse(line)
            path_parts = url_parts.path.split('/')
            query_parts = parse_qs(url_parts.query)
            
            # 提取频道ID和提供商信息
            provider = ''
            source_id = ''
            
            # 从URL中提取频道ID
            if 'id=' in line:
                source_id = query_parts.get('id', [''])[0]
            elif '?id=' in line:
                source_id = line.split('?id=')[1].split('&')[0]
            
            # 从URL中提取提供商信息
            if 'live.php' in line:
                provider = 'PHP直播'
            elif 'iptv' in line.lower():
                provider = 'IPTV'
            elif 'live' in line.lower():
                provider = '直播源'
            
            current_channel['id'] = source_id
            current_channel['provider'] = provider
            
            # 添加到频道列表
            channel_name = current_channel['name']
            if channel_name not in channels:
                channels[channel_name] = []
            channels[channel_name].append(current_channel.copy())
            current_channel = None
            
    return channels

def analyze_sources(channels):
    """分析所有源的统计信息"""
    stats = {
        'channel_duplicates': {},  # 频道重复数统计
        'rate_counts': {},        # 码率分布统计
        'resolution_counts': {},   # 分辨率分布统计
        'common_resolution': 0     # 最常见分辨率
    }
    
    # 初始化分辨率计数器
    for res in [480, 576, 720, 1080, 2160]:
        stats['resolution_counts'][res] = 0
    
    # 统计频道重复数
    stats['channel_duplicates'] = {name: len(sources) for name, sources in channels.items()}
    
    # 统计码率和分辨率分布
    all_sources = []
    for sources in channels.values():
        all_sources.extend(sources)
    
    # 统计码率
    rates = []
    for source in all_sources:
        # 安全获取码率值，如果不存在则跳过
        if 'rate' in source:
            rate = float(source['rate'])
            rates.append(rate)
            stats['rate_counts'][rate] = stats['rate_counts'].get(rate, 0) + 1
    
    # 统计分辨率
    resolutions = []
    for source in all_sources:
        if 'resolution' in source and source['resolution'] > 0:
            resolution = source['resolution']
            resolutions.append(resolution)
            stats['resolution_counts'][resolution] = stats['resolution_counts'].get(resolution, 0) + 1
    
    # 计算最常见分辨率
    if resolutions:
        stats['common_resolution'] = max(set(resolutions), key=resolutions.count)
    
    return stats

def process_channels(channels, network_info):
    """处理频道选择"""
    if not channels:
        return []
    
    # 分析源的特征
    source_stats = analyze_sources(channels)
    
    # 获取用户偏好
    source_preference = get_source_preference()
    
    # 选择最佳源
    selected_channels = []
    for channel_name, sources in channels.items():
        if sources:  # 确保有可用源
            selected = get_recommended_source(sources, source_stats, source_preference)
            selected_channels.append(selected)
    
    return selected_channels

def get_recommended_source(sources, source_stats, source_preference):
    """根据用户偏好获取推荐的源"""
    def score_source(source):
        score = 0
        
        # 分辨率评分
        if source_preference.get('target_resolution') and 'resolution' in source:
            resolution_diff = abs(source.get('resolution', 0) - source_preference['target_resolution'])
            score -= resolution_diff * source_preference.get('resolution_weight', 1)
        
        # 码率评分 - 如果没有码率信息，则跳过这部分评分
        rate_weight = source_preference.get('rate_weight', 0)
        if 'rate' in source and source['rate']:
            if rate_weight < 0:  # 优先低码率
                score -= float(source['rate']) * abs(rate_weight)
            elif rate_weight > 0:  # 优先高码率
                score += float(source['rate']) * rate_weight
        
        # 响应时间评分
        if 'response_time' in source:
            try:
                response_time = float(source['response_time'])
                score -= response_time * 2
            except (ValueError, TypeError):
                pass
        
        return score
    
    # 如果只有一个源，直接返回
    if len(sources) == 1:
        return sources[0]
        
    # 返回评分最高的源
    return max(sources, key=score_source)

def get_output_path(keyword):
    """获取输出文件路径"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_filename = f'{keyword}.m3u'
    output_path = os.path.join(script_dir, base_filename)
    
    # 如果文件已存在，在文件名后添加数字
    counter = 1
    while os.path.exists(output_path):
        filename = f'{keyword}_{counter}.m3u'
        output_path = os.path.join(script_dir, filename)
        counter += 1
    
    print(f"\n文件将保存到: {output_path}")
    return output_path

def write_m3u(channels, output_path, epg_data=None):
    """写入新的m3u文件"""
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        def channel_sort_key(channel):
            name = channel['name']
            if 'CCTV' in name.upper():
                match = re.search(r'CCTV(\d+)', name, re.IGNORECASE)
                if match:
                    return (0, int(match.group(1)))
                return (0, float('inf'))
            return (1, name)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('#EXTM3U\n')
            for channel in sorted(channels, key=channel_sort_key):
                # 如果有EPG信息，更新channel信息
                if epg_data and channel['name'] in epg_data:
                    epg_info = epg_data[channel['name']]
                    # 更新EXTINF行，添加tvg-id和logo信息
                    extinf = channel['extinf']
                    if 'tvg-id="' not in extinf:
                        extinf = extinf.replace('#EXTINF:-1', f'#EXTINF:-1 tvg-id="{epg_info["id"]}"')
                    if 'tvg-logo="' not in extinf and epg_info.get('logo'):
                        extinf = extinf.replace('#EXTINF:-1', f'#EXTINF:-1 tvg-logo="{epg_info["logo"]}"')
                    f.write(f"{extinf}\n")
                else:
                    f.write(f"{channel['extinf']}\n")
                f.write(f"{channel['url']}\n")
        
        print(f"\n文件已保存到: {output_path}")
        
        if os.name == 'nt':
            if input("\n是否打开文件所在位置? (y/N): ").lower() == 'y':
                os.system(f'explorer /select,"{output_path}"')
                
    except Exception as e:
        print(f"保存文件失败: {e}")
        return False
    
    return True

def main():
    # 检查网络环境
    print("正在检查网络环境...")
    network_info = check_network_capabilities()
    
    if network_info['ipv4']['available']:
        print(f"√ IPv4 网络可用 (速度评分: {network_info['ipv4']['speed']:.2f})")
    if network_info['ipv6']['available']:
        print(f"√ IPv6 网络可用 (速度评分: {network_info['ipv6']['speed']:.2f})")
    
    print(f"\n将优先使用 {network_info['preference'].upper()} 网络")
    
    # 获取EPG数据
    epg_data = get_epg_data()
    
    # 获取m3u源
    m3u_source = get_m3u_source()
    if not m3u_source:
        print("未能获取m3u源,程序退出")
        return
        
    # 加载m3u内容
    content = load_m3u_content(m3u_source)
    if not content:
        print("未能加载m3u内容,程序退出")
        return
    
    # 获取关键词
    keyword = input("\n请输入要筛选的频道关键词(例如: CCTV、卫视、4K等): ")
    
    print(f"\n开始筛选包含 '{keyword}' 的频道...")
    channels = parse_m3u_content(content, keyword, network_info)
    
    if not channels:
        print(f"未找到包含 '{keyword}' 的频道!")
        return
    
    # 显示频道信息
    if epg_data:
        print("\n频道信息:")
        for channel_name in channels.keys():
            if channel_name in epg_data:
                epg_info = epg_data[channel_name]
                print(f"{channel_name}:")
                print(f"  频道ID: {epg_info['id']}")
                if epg_info.get('logo'):
                    print(f"  台标: {epg_info['logo']}")
    
    # 处理频道选择
    selected_channels = process_channels(channels, network_info)
    
    if selected_channels:
        # 获取输出路径
        output_path = get_output_path(keyword)
        
        # 写入文件时使用EPG信息
        if write_m3u(selected_channels, output_path, epg_data):
            print(f"\n处理完成! 共处理 {len(selected_channels)} 个频道")
            
            # 显示文件信息
            file_size = os.path.getsize(output_path) / 1024
            print(f"文件大小: {file_size:.1f} KB")
            
            # 显示处理结果统计
            print("\n频道统计:")
            providers = {}
            for channel in selected_channels:
                provider = channel.get('provider', '未知')
                providers[provider] = providers.get(provider, 0) + 1
            
            for provider, count in providers.items():
                print(f"{provider}: {count}个频道")
    else:
        print("未能生成频道列表")

if __name__ == '__main__':
    main()
EOL

    # 添加执行权限
    chmod +x iptv.py
}

# 验证安装
verify_install() {
    print_info "验证安装..."
    
    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 安装失败"
        exit 1
    fi
    
    # 检查pip3
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 安装失败"
        exit 1
    fi
    
    # 验证Python包
    python3 -c "import requests" 2>/dev/null || {
        print_error "requests 模块安装失败"
        exit 1
    }
    
    python3 -c "import bs4" 2>/dev/null || {
        print_error "beautifulsoup4 模块安装失败"
        exit 1
    }
    
    print_info "所有依赖安装成功！"
}

# 卸载依赖
uninstall_deps() {
    case $OS in
        "Ubuntu"|"Debian GNU/Linux")
            print_info "开始卸载依赖..."
            
            # 卸载Python包
            pip3 uninstall -y --break-system-packages requests beautifulsoup4
            
            # 卸载系统包
            apt-get remove -y python3-requests python3-bs4 python3-pip
            
            # 清理不需要的包
            apt-get autoremove -y
            ;;
            
        "CentOS Linux"|"Red Hat Enterprise Linux")
            print_info "开始卸载依赖..."
            
            # 卸载Python包
            pip3 uninstall -y requests beautifulsoup4
            
            # 卸载系统包
            yum remove -y python3-requests python3-beautifulsoup4 python3-pip
            
            # 清理不需要的包
            yum autoremove -y
            ;;
            
        *)
            print_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    print_info "依赖卸载完成"
}

# 显示菜单
show_menu() {
    echo -e "\n${GREEN}IPTV工具 - 主菜单${NC}"
    echo "1. 运行IPTV工具"
    echo "2. 安装依赖"
    echo "3. 卸载依赖"
    echo "4. 退出"
    echo
    read -p "请选择操作 (1-4): " choice
    
    case $choice in
        1)
            if [ ! -f "iptv.py" ]; then
                print_info "创建Python脚本..."
                create_python_script
            fi
            print_info "启动IPTV工具..."
            python3 iptv.py
            ;;
        2)
            check_dependencies
            print_info "依赖安装完成"
            ;;
        3)
            print_warn "警告: 这将卸载所有相关依赖"
            read -p "确定要继续吗? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                uninstall_deps
            fi
            ;;
        4)
            print_info "退出程序"
            exit 0
            ;;
        *)
            print_error "无效的选择"
            ;;
    esac
}

# 主函数
main() {
    print_info "IPTV工具 - 安装和运行"
    check_root
    detect_os
    while true; do
        show_menu
    done
}

# 运行主函数
main 
