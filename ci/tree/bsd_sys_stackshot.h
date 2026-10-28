/*
 * bsd/sys/stackshot.h - restored for the ARMv7 HD2/J1 tree.
 *
 * The published source export is missing this header, but osfmk/kdp/kdp.c
 * dereferences struct mem_and_io_snapshot and uses the STACKSHOT_* action and
 * magic constants, so the kernel component fails to compile without it.  The
 * field list is exactly what kdp.c reads (active_pages, busy_buffer_count,
 * free_pages, inactive_pages, pages_reclaimed, pages_wanted,
 * pages_wanted_reclaimed_valid, purgeable_pages, snapshot_magic,
 * speculative_pages, throttled_pages, wired_pages); the magic values follow
 * Apple's public stackshot.h.  Nothing on land consumes this over the debug
 * port yet, so the layout only has to be self-consistent inside the kernel.
 */
#ifndef _SYS_STACKSHOT_H
#define _SYS_STACKSHOT_H

#include <stdint.h>
#include <sys/types.h>

/* stackshot actions, as used by kdp.c and kern_stackshot.c */
#define STACKSHOT_GET_GLOBAL_MEM_STATS  1
#define STACKSHOT_SAVE_LOADINFO         2
#define STACKSHOT_ACTIVATE_AFTER_SNAPSHOT 3
#define STACKSHOT_GET_DQ                4

#define STACKSHOT_THREAD_SNAPSHOT_MAGIC 0x18535441
#define STACKSHOT_TASK_SNAPSHOT_MAGIC   0x19535441
#define STACKSHOT_MEM_AND_IO_SNAPSHOT_MAGIC 0x20535441

/* window over which vm pressure is averaged, milliseconds */
#define VM_PRESSURE_TIME_WINDOW         (1000 * 15)

struct mem_and_io_snapshot {
	uint32_t snapshot_magic;
	uint32_t snapshot_length;
	uint64_t snapshot_timestamp;

	uint32_t free_pages;
	uint32_t speculative_pages;
	uint32_t active_pages;
	uint32_t wired_pages;
	uint32_t purgeable_pages;
	uint32_t filebacked_pages;
	uint32_t anonymous_pages;
	uint32_t throttled_pages;
	uint32_t inactive_pages;

	uint32_t pages_wanted;
	uint32_t pages_reclaimed;
	uint8_t  pages_wanted_reclaimed_valid;

	uint32_t busy_buffer_count;
	uint32_t total_protection_faults;
	uint32_t total_translator_faults;
};

#endif /* _SYS_STACKSHOT_H */
