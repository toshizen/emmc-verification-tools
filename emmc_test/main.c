/*******************************************************************************
 * @file main.c
 * @brief eMMC write test for validation
 * @description Test to compare write amount before/after ring_info optimization
 *******************************************************************************/

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <stdint.h>
#include <signal.h>

#define NUM_FILES 5000
#define DATA_DIR "/opt/emmc_test/data"
#define INFO_FILE "/opt/emmc_test/data/ring_info"
#define INFO_SIZE (440 * 1024)  // 440KB (5000 IO × 88 bytes)
#define DAT_SIZE 64             // Each dat file size
#define FLUSH_INTERVAL_SEC 30   // Flush interval in seconds

typedef struct {
    int start_id;
    int end_id;
    int mode;  // 0: before fix (write info every time), 1: after fix (write info per 30sec)
} thread_arg_t;

static volatile int g_running = 1;
static volatile int g_files_updated = 0;
static pthread_mutex_t g_mtx = PTHREAD_MUTEX_INITIALIZER;
static uint64_t g_write_count = 0;
static uint64_t g_info_write_count = 0;

// Signal handler for graceful shutdown
void signal_handler(int signo) {
    (void)signo;
    g_running = 0;
}

// Write ring_info file
int write_info_file(void) {
    char *buf = malloc(INFO_SIZE);
    if (!buf) {
        fprintf(stderr, "Failed to allocate memory for info file\n");
        return -1;
    }

    // Fill with dummy data
    memset(buf, 0xAB, INFO_SIZE);

    // Write with fsync (same as save_ctrl)
    FILE *fp = fopen(INFO_FILE, "w");
    if (!fp) {
        fprintf(stderr, "Failed to open %s: %s\n", INFO_FILE, strerror(errno));
        free(buf);
        return -1;
    }

    if (fwrite(buf, 1, INFO_SIZE, fp) != INFO_SIZE) {
        fprintf(stderr, "Failed to write info file\n");
        fclose(fp);
        free(buf);
        return -1;
    }

    fflush(fp);
    fsync(fileno(fp));
    fclose(fp);
    free(buf);

    pthread_mutex_lock(&g_mtx);
    g_info_write_count++;
    pthread_mutex_unlock(&g_mtx);

    return 0;
}

// Write thread for multiple dat files
void *write_thread(void *arg) {
    thread_arg_t *targ = (thread_arg_t *)arg;
    char filepath[256];
    char buf[DAT_SIZE];
    int counter = 0;

    while (g_running) {
        // Process all files assigned to this thread
        for (int id = targ->start_id; id <= targ->end_id && g_running; id++) {
            snprintf(filepath, sizeof(filepath), "%s/%05d.dat", DATA_DIR, id);

            FILE *fp = fopen(filepath, "r+");
            if (!fp) {
                fprintf(stderr, "Failed to open %s: %s\n", filepath, strerror(errno));
                continue;
            }

            // Write dummy data with timestamp
            struct timespec ts;
            clock_gettime(CLOCK_REALTIME, &ts);
            snprintf(buf, sizeof(buf), "%ld.%09ld:%d", ts.tv_sec, ts.tv_nsec, counter++);

            fseek(fp, 0, SEEK_SET);
            if (fwrite(buf, 1, DAT_SIZE, fp) != DAT_SIZE) {
                fprintf(stderr, "Failed to write to %s\n", filepath);
                fclose(fp);
                continue;
            }

            fflush(fp);
            fclose(fp);

            pthread_mutex_lock(&g_mtx);
            g_write_count++;
            g_files_updated++;
            pthread_mutex_unlock(&g_mtx);

            // Mode 0 (before fix): Write info file every time
            if (targ->mode == 0) {
                write_info_file();
            }
        }

        // Small delay before next round
        usleep(1000);
    }

    free(targ);
    return NULL;
}

// Monitor thread: flush every 30 seconds (mode 1 only)
void *monitor_thread(void *arg) {
    int mode = *(int *)arg;
    time_t start_time = time(NULL);

    while (g_running) {
        sleep(1);

        time_t elapsed = time(NULL) - start_time;
        if (elapsed >= FLUSH_INTERVAL_SEC) {
            pthread_mutex_lock(&g_mtx);
            int updated = g_files_updated;
            g_files_updated = 0;
            pthread_mutex_unlock(&g_mtx);

            if (mode == 1 && updated > 0) {
                write_info_file();
                printf("[%ld sec] Flushed: %d files updated, info written\n", elapsed, updated);
            }

            start_time = time(NULL);
        }
    }

    return NULL;
}

// Statistics thread
void *stats_thread(void *arg) {
    (void)arg;
    uint64_t prev_write = 0;
    uint64_t prev_info = 0;
    time_t start_time = time(NULL);

    while (g_running) {
        sleep(10);

        pthread_mutex_lock(&g_mtx);
        uint64_t cur_write = g_write_count;
        uint64_t cur_info = g_info_write_count;
        pthread_mutex_unlock(&g_mtx);

        time_t elapsed = time(NULL) - start_time;
        uint64_t dat_writes = cur_write - prev_write;
        uint64_t info_writes = cur_info - prev_info;

        // Calculate write amount
        uint64_t dat_bytes = dat_writes * DAT_SIZE;
        uint64_t info_bytes = info_writes * INFO_SIZE;
        uint64_t total_bytes = dat_bytes + info_bytes;

        printf("[%ld sec] DAT: %lu writes (%lu KB), INFO: %lu writes (%lu KB), Total: %lu KB\n",
               elapsed, dat_writes, dat_bytes / 1024,
               info_writes, info_bytes / 1024,
               total_bytes / 1024);

        prev_write = cur_write;
        prev_info = cur_info;
    }

    return NULL;
}

int main(int argc, char *argv[]) {
    int mode = 1;  // Default: after fix (mode 1)
    int duration = 300;  // Default: 5 minutes
    int num_threads = 100;  // Default: 100 threads

    // Parse arguments
    if (argc > 1) {
        mode = atoi(argv[1]);
        if (mode != 0 && mode != 1) {
            fprintf(stderr, "Usage: %s [mode] [duration] [num_threads]\n", argv[0]);
            fprintf(stderr, "  mode: 0 (before fix), 1 (after fix, default)\n");
            fprintf(stderr, "  duration: test duration in seconds (default: 300)\n");
            fprintf(stderr, "  num_threads: number of write threads (default: 100)\n");
            return 1;
        }
    }
    if (argc > 2) {
        duration = atoi(argv[2]);
    }
    if (argc > 3) {
        num_threads = atoi(argv[3]);
        if (num_threads < 1 || num_threads > NUM_FILES) {
            fprintf(stderr, "Error: num_threads must be between 1 and %d\n", NUM_FILES);
            return 1;
        }
    }

    printf("=== eMMC Write Test ===\n");
    printf("Mode: %d (%s)\n", mode, mode == 0 ? "BEFORE FIX" : "AFTER FIX");
    printf("Files: %d\n", NUM_FILES);
    printf("Threads: %d (each handles ~%d files)\n", num_threads, NUM_FILES / num_threads);
    printf("Data dir: %s\n", DATA_DIR);
    printf("Info size: %d KB\n", INFO_SIZE / 1024);
    printf("Test duration: %d seconds\n", duration);
    printf("==================================\n\n");

    // Setup signal handler
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Create data directory
    if (mkdir(DATA_DIR, 0755) < 0 && errno != EEXIST) {
        fprintf(stderr, "Failed to create %s: %s\n", DATA_DIR, strerror(errno));
        return 1;
    }

    // Create dat files
    printf("Creating %d dat files...\n", NUM_FILES);
    for (int i = 0; i < NUM_FILES; i++) {
        char filepath[256];
        snprintf(filepath, sizeof(filepath), "%s/%05d.dat", DATA_DIR, i);

        FILE *fp = fopen(filepath, "w");
        if (!fp) {
            fprintf(stderr, "Failed to create %s: %s\n", filepath, strerror(errno));
            return 1;
        }

        char buf[DAT_SIZE] = {0};
        fwrite(buf, 1, DAT_SIZE, fp);
        fclose(fp);

        if ((i + 1) % 1000 == 0) {
            printf("  Created %d files...\n", i + 1);
        }
    }
    printf("Done.\n\n");

    // Create initial info file
    write_info_file();

    // Start threads
    pthread_t *threads = malloc(sizeof(pthread_t) * num_threads);
    if (!threads) {
        fprintf(stderr, "Failed to allocate thread array\n");
        return 1;
    }

    printf("Starting write threads...\n");
    int files_per_thread = NUM_FILES / num_threads;
    int remainder = NUM_FILES % num_threads;

    for (int i = 0; i < num_threads; i++) {
        thread_arg_t *arg = malloc(sizeof(thread_arg_t));

        // Calculate file range for this thread
        arg->start_id = i * files_per_thread;
        arg->end_id = (i + 1) * files_per_thread - 1;

        // Distribute remainder files to first threads
        if (i < remainder) {
            arg->start_id += i;
            arg->end_id += i + 1;
        } else {
            arg->start_id += remainder;
            arg->end_id += remainder;
        }

        arg->mode = mode;

        if (pthread_create(&threads[i], NULL, write_thread, arg) != 0) {
            fprintf(stderr, "Failed to create thread %d: %s\n", i, strerror(errno));
            free(arg);
            return 1;
        }

        if ((i + 1) % 100 == 0 || i == num_threads - 1) {
            printf("  Started %d threads...\n", i + 1);
        }
    }
    printf("Done.\n\n");

    // Start monitor thread
    pthread_t mon_thread;
    pthread_create(&mon_thread, NULL, monitor_thread, &mode);

    // Start stats thread
    pthread_t stat_thread;
    pthread_create(&stat_thread, NULL, stats_thread, NULL);

    printf("Test running... Press Ctrl+C to stop, or wait %d seconds.\n\n", duration);

    // Wait for duration or signal
    for (int i = 0; i < duration && g_running; i++) {
        sleep(1);
    }

    // Stop all threads
    printf("\nStopping test...\n");
    g_running = 0;

    // Wait for all threads
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    pthread_join(mon_thread, NULL);
    pthread_join(stat_thread, NULL);

    free(threads);

    // Print final statistics
    printf("\n=== Test Results ===\n");
    printf("Total DAT writes: %lu (%.2f MB)\n",
           g_write_count, (double)(g_write_count * DAT_SIZE) / (1024 * 1024));
    printf("Total INFO writes: %lu (%.2f MB)\n",
           g_info_write_count, (double)(g_info_write_count * INFO_SIZE) / (1024 * 1024));
    printf("Total write amount: %.2f MB\n",
           (double)(g_write_count * DAT_SIZE + g_info_write_count * INFO_SIZE) / (1024 * 1024));
    printf("====================\n");

    return 0;
}
