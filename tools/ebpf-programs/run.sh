sudo bpftool prog load trace_write.bpf.o /sys/fs/bpf/trace_write autoattach;

sudo bpftool prog trace log;