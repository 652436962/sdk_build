/*
 * 翻斗式脉冲雨量计 - 分钟雨量统计程序
 * 读取 gpio-keys 脉冲事件，每 60 秒输出一次分钟雨量
 * 编译: aarch64-linux-gnu-gcc -o rain_gauge rain_gauge.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <poll.h>
#include <errno.h>
#include <linux/input.h>

#define INPUT_DEV      "/dev/input/event3"
#define TIP_MM         0.25          // 每斗雨量(mm)，按实际规格修改
#define REPORT_SEC     60            // 统计周期(秒)

static volatile int running = 1;

void sig_handler(int sig) { running = 0; }

int main(int argc, char **argv) {
    struct input_event ev;
    struct pollfd pfd;
    struct timespec t_start, t_now;
    int fd;
    unsigned long count = 0, total = 0;

    // 可通过命令行参数指定每斗雨量
    double tip_mm = TIP_MM;
    if (argc > 1) tip_mm = atof(argv[1]);
    if (tip_mm <= 0) tip_mm = TIP_MM;

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    fd = open(INPUT_DEV, O_RDONLY);
    if (fd < 0) {
        perror("open " INPUT_DEV);
        return 1;
    }

    pfd.fd = fd;
    pfd.events = POLLIN;

    clock_gettime(CLOCK_MONOTONIC, &t_start);
    printf("[雨量计] 每斗=%.2fmm  统计周期=%ds  设备=%s\n",
           tip_mm, REPORT_SEC, INPUT_DEV);
    fflush(stdout);

    while (running) {
        int ret = poll(&pfd, 1, 1000);  // 1秒超时

        if (ret < 0) {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }

        // 有事件可读
        if (ret > 0 && (pfd.revents & POLLIN)) {
            if (read(fd, &ev, sizeof(ev)) == sizeof(ev)) {
                if (ev.type == EV_KEY && ev.code == KEY_PROG1 && ev.value == 1) {
                    count++;
                    total++;
                }
            }
        }

        // 检查是否达到统计周期（无论有无脉冲都输出）
        clock_gettime(CLOCK_MONOTONIC, &t_now);
        long elapsed = t_now.tv_sec - t_start.tv_sec;

        if (elapsed >= REPORT_SEC) {
            double rain = count * tip_mm;
            time_t now = time(NULL);
            char ts[32];
            strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", localtime(&now));

            printf("[%s] 本分钟脉冲=%lu  分钟雨量=%.1fmm  累计脉冲=%lu  累计雨量=%.1fmm\n",
                   ts, count, rain, total, total * tip_mm);
            fflush(stdout);

            count = 0;
            t_start = t_now;
        }
    }

    close(fd);
    printf("\n[雨量计] 停止。累计: %lu 脉冲, %.1f mm\n", total, total * tip_mm);
    return 0;
}
