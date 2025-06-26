#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

typedef unsigned int u32;
typedef int pid_t;

struct syscalls_enter_write_args {
  unsigned short common_type;
  unsigned char common_flags;
  unsigned char common_preempt_count;
  int common_pid;
  int __syscall_nr;
  unsigned int fd;
  const char *buf;
  size_t count;
};

SEC("tp/syscalls/sys_enter_write")
int handle_write(struct syscalls_enter_write_args *ctx) {
  pid_t pid = bpf_get_current_pid_tgid() >> 32;
  struct task_struct *task = (struct task_struct *)bpf_get_current_task_btf();
  // if (bpf_strncmp(task->comm, TASK_COMM_LEN, "bpftool") == 0) {
  //   return 0;
  // }
  bpf_printk("BPF triggered sys_enter_write from PID %d\n", pid);
  return 0;
}

char LICENSE[] SEC("license") = "GPL";