# 海康威视 RTSP 协议获取视频流

> 来源：https://bbs.huaweicloud.com/blogs/421827  
> 作者：Damon小智 | 2024/02/08  
> 摄像头：海康威视 POE 供电 臻全彩款  
> 方案：通过海康 RTSP 协议推流，不需要接入萤石云

---

## 两种推流方式对比

| 方式 | 流畅度 | 配置要求 | 稳定性 | 集成功能 |
|------|--------|----------|--------|----------|
| **海康 RTSP 协议取流** | 高 | 需现场配置路由 | 一般 | 需自行开发 |
| **萤石云 RTMP 协议推流** | 一般 | 无需配置路由，开箱即用 | 更好 | 萤石云轻应用 SDK，前端一键生成 |

> 本文介绍的是**海康 RTSP 协议取流**方式。

---

## 一、海康 RTSP 取流格式

海康威视官方最新 RTSP 取流格式（2023.9）：

```
rtsp://用户名:密码@IP:554/Streaming/Channels/101
```

### URL 参数说明

| URL 末尾 | 含义 | 示例 |
|----------|------|------|
| `101` | 第 1 通道，主码流 | 默认使用 |
| `201` | 第 2 通道，主码流 | 多通道摄像头 |
| `102` | 第 1 通道，子码流 | 低分辨率预览 |
| `103` | 第 1 通道，第三码流 | 更低分辨率 |

格式：`Channels/X0Y`

- `X`：通道号（1=第一通道，2=第二通道...）
- `Y`：码流类型（1=主码流，2=子码流，3=第三码流）

> 注意：网上流传的 `rtsp://用户名:密码@IP:554/h264/ch1/main/av_stream` 是 2012 年之前的旧格式，现已更新。车载录像机不支持 RTSP 取流。

---

## 二、设备端配置

### a) 关闭萤石云接入

在海康录像机/NVR 的配置界面中，**关闭萤石云服务**，避免与 RTSP 取流冲突。

### b) 调整视频编码为 H.264

将视频编码格式设置为 **H.264**，确保兼容性（H.265 可能导致部分播放器无法解码）。

---

## 三、测试 RTSP 推流（VLC 播放器）

### 1. 下载安装 VLC Media Player

官网：https://www.videolan.org/vlc/

### 2. 打开网络串流

菜单：`媒体` → `打开网络串流`

输入 RTSP 地址，例如：

```
rtsp://admin:12345@192.168.1.64:554/Streaming/Channels/101
```

### 3. 验证成功

- 看到监控画面 → RTSP 地址正确，取流成功
- 报错 → 在 `工具` → `消息` 中查看错误日志

---

## 四、常见 RTSP 取流示例

```bash
# VLC 命令行播放
vlc rtsp://admin:12345@192.168.1.64:554/Streaming/Channels/101

# ffplay 播放
ffplay rtsp://admin:12345@192.168.1.64:554/Streaming/Channels/101

# FFmpeg 转码推流
ffmpeg -i rtsp://admin:12345@192.168.1.64:554/Streaming/Channels/101 \
       -c copy -f flv rtmp://服务器地址/live/stream

# OpenCV 读取
python -c "
import cv2
cap = cv2.VideoCapture('rtsp://admin:12345@192.168.1.64:554/Streaming/Channels/101')
while True:
    ret, frame = cap.read()
    if ret:
        cv2.imshow('Hikvision', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
cap.release()
"
```
