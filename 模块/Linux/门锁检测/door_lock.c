/*
 * 门锁检测程序
 * 监听 gpio-keys 事件，实时输出门锁开/关状态变化
 * 编译: aarch64-linux-gnu-gcc -o door_lock door_lock.c -static -s
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <linux/input.h>

#define INPUT_DEV      "/dev/input/event3"

static volatile int running = 1;
void sig_handler(int sig) { running = 0; }

int main(void) {
    struct input_event ev;
    int fd;
    int state = -1;  // -1 未知, 0 关闭, 1 打开

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    fd = open(INPUT_DEV, O_RDONLY);
    if (fd < 0) {
        perror("open " INPUT_DEV);
        return 1;
    }

    printf("[门锁检测] 设备=%s  等待状态变化...\n", INPUT_DEV);
    fflush(stdout);

    while (running) {
        if (read(fd, &ev, sizeof(ev)) != sizeof(ev)) {
            if (running) perror("read");
            break;
        }

        if (ev.type == EV_KEY && ev.code == KEY_PROG1) {
            time_t now = time(NULL);
            char ts[32];
            strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", localtime(&now));

            int new_state = ev.value;  // 0=释放 1=按下
            if (new_state != state) {
                printf("[%s] 门锁状态: %s\n",
                       ts, new_state ? "锁定" : "解锁");
                fflush(stdout);
                state = new_state;
            }
        }
    }

    close(fd);
    printf("\n[门锁检测] 已停止。\n");
    return 0;
}
