// https://eunomia.dev/en/tutorials/2-kprobe-unlink/

#include "vmlinux.h"
#include <bpf/bpf_core_read.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

char LICENSE[] SEC("license") = "Dual BSD/GPL";


SEC("kprobe/do_sys_open")
int raw_kprobe_offset_sys_open(struct pt_regs *ctx) {
    pid_t pid = bpf_get_current_pid_tgid() >> 32;
    const char *filename;
    struct filename *name = (struct filename *)PT_REGS_PARM2(ctx);
    filename = BPF_CORE_READ(name, name);
    bpf_printk("offset hook pid=%d filename=%s\n", pid, filename);
    return 0;
}

SEC("kprobe/do_unlinkat")
int BPF_KPROBE(do_unlinkat, int dfd, struct filename *name) {
  pid_t pid;
  const char *filename;

  pid = bpf_get_current_pid_tgid() >> 32;
  filename = BPF_CORE_READ(name, name);
  bpf_printk("KPROBE ENTRY pid = %d, filename = %s\n", pid, filename);
  return 0;
}

SEC("kretprobe/do_unlinkat")
int BPF_KRETPROBE(do_unlinkat_exit, long ret) {
  pid_t pid;

  pid = bpf_get_current_pid_tgid() >> 32;
  bpf_printk("KPROBE EXIT: pid = %d, ret = %ld\n", pid, ret);
  return 0;
}
