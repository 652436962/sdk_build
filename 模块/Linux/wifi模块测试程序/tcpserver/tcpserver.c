/* tcpserver.c - TCP 服务端：按来源 IP 分文件记录收到的消息
 * 用法: tcpserver [-p 端口] [-b 绑定IP] [-d 日志目录]
 * 默认: 0.0.0.0:1500, 日志目录 /var/log/tcpserver
 * 功能:
 *   - 每个客户端连接 fork 一个子进程处理；
 *   - 收到的数据同时打印到 stdout 与 /dev/console(串口)；
 *   - 按来源 IP 写入独立文件: <日志目录>/<IP>.log，每条消息带时间戳；
 *   - 原样回显给客户端。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

#define DEFAULT_PORT 1500
#define DEFAULT_LOGDIR "/lechi/logs"
#define BUFSZ 4096

static FILE *gcon = NULL;          /* 串口控制台 */
static char g_logdir[256] = DEFAULT_LOGDIR;

static void say(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    fflush(stdout);

    if (gcon) {
        va_start(ap, fmt);
        vfprintf(gcon, fmt, ap);
        va_end(ap);
        fflush(gcon);
    }
}

static void ts(char *out, size_t n)
{
    time_t t = time(NULL);
    struct tm tm;
    localtime_r(&t, &tm);
    strftime(out, n, "%Y-%m-%d %H:%M:%S", &tm);
}

static void dump(const unsigned char *buf, int len)
{
    int i, q = 0;
    char txt[BUFSZ + 8];

    for (i = 0; i < len; i++)
        txt[q++] = (buf[i] >= 32 && buf[i] < 127) ? buf[i] : '.';
    txt[q] = '\0';
    say("  TXT: %s\n", txt);
}

/* 每个连接的来源 IP 一个日志文件: <logdir>/<ip>.log */
static FILE *open_ip_log(const char *ip)
{
    char path[320];
    FILE *f;

    mkdir(g_logdir, 0755);                     /* 已存在则忽略 */
    snprintf(path, sizeof path, "%s/%s.log", g_logdir, ip);
    f = fopen(path, "a");
    if (!f)
        say("WARN: cannot open %s: %s\n", path, strerror(errno));
    return f;
}

static void handle(int fd, struct sockaddr_in *peer)
{
    char t[32], ip[INET_ADDRSTRLEN];
    unsigned char buf[BUFSZ];
    ssize_t n;
    FILE *lf;

    inet_ntop(AF_INET, &peer->sin_addr, ip, sizeof ip);
    ts(t, sizeof t);
    say("[%s] CONNECT from %s:%d\n", t, ip, ntohs(peer->sin_port));

    lf = open_ip_log(ip);

    while ((n = read(fd, buf, sizeof buf)) > 0) {
        ts(t, sizeof t);
        say("[%s] RECV %zd bytes from %s:%d\n",
            t, n, ip, ntohs(peer->sin_port));
        dump(buf, (int)n);

        /* 写入该 IP 专属文件，带时间戳 */
        if (lf) {
            fprintf(lf, "[%s] %s:%d %zd bytes  ", t, ip,
                    ntohs(peer->sin_port), n);
            fwrite(buf, 1, (size_t)n, lf);
            if (n > 0 && buf[n - 1] != '\n')
                fputc('\n', lf);
            fflush(lf);
        }

        if (write(fd, buf, n) != n)
            break;
    }

    if (lf)
        fclose(lf);

    ts(t, sizeof t);
    say("[%s] CLOSE %s:%d\n", t, ip, ntohs(peer->sin_port));
    close(fd);
    _exit(0);
}

int main(int argc, char **argv)
{
    int port = DEFAULT_PORT, lfd, cfd, opt = 1, i;
    struct sockaddr_in addr, peer;
    socklen_t plen = sizeof peer;
    const char *bindip = "0.0.0.0";

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-p") && i + 1 < argc)
            port = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-b") && i + 1 < argc)
            bindip = argv[++i];
        else if (!strcmp(argv[i], "-d") && i + 1 < argc)
            snprintf(g_logdir, sizeof g_logdir, "%s", argv[++i]);
    }

    gcon = fopen("/dev/console", "w");

    signal(SIGCHLD, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);

    lfd = socket(AF_INET, SOCK_STREAM, 0);
    if (lfd < 0) { perror("socket"); return 1; }
    setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof opt);

    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    addr.sin_addr.s_addr = inet_addr(bindip);
    if (bind(lfd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        perror("bind");
        return 1;
    }
    if (listen(lfd, 16) < 0) { perror("listen"); return 1; }

    mkdir(g_logdir, 0755);
    say("TCP server listening on %s:%d, per-IP logs -> %s/<ip>.log\n",
        bindip, port, g_logdir);

    for (;;) {
        cfd = accept(lfd, (struct sockaddr *)&peer, &plen);
        if (cfd < 0) {
            if (errno == EINTR)
                continue;
            perror("accept");
            continue;
        }
        if (fork() == 0) {
            close(lfd);
            handle(cfd, &peer);
        }
        close(cfd);
    }
    return 0;
}
