#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <linux/bpf.h>
#include <linux/perf_event.h>
#include <linux/ptrace.h>
#include <sys/resource.h>

static int libbpf_print_fn(enum libbpf_print_level level, const char *format, va_list args)
{
    return vfprintf(stderr, format, args);
}

int main(int argc, char **argv)
{
    struct bpf_object *obj;
    int err;

    /* Set up libbpf errors and debug info callback */
    libbpf_set_print(libbpf_print_fn);

    /* Open BPF object */
    obj = bpf_object__open_file("test1.o", NULL);
    if (libbpf_get_error(obj)) {
        fprintf(stderr, "Failed to open BPF object\n");
        return 1;
    }

    /* Load BPF object into kernel */
    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "Failed to load BPF object\n");
        bpf_object__close(obj);
        return 1;
    }

    /* Attach tracepoint */
    struct bpf_program *prog = bpf_object__find_program_by_name(obj, "trace_execve_enter");
    if (!prog) {
        fprintf(stderr, "Failed to find BPF program\n");
        bpf_object__close(obj);
        return 1;
    }

    struct bpf_link *link = bpf_program__attach(prog);
    if (libbpf_get_error(link)) {
        fprintf(stderr, "Failed to attach BPF program\n");
        bpf_object__close(obj);
        return 1;
    }

    printf("Successfully loaded and attached BPF program. Press Ctrl+C to exit.\n");

    /* Keep the program running to maintain the BPF program attachment */
    while (1) {
        sleep(1);
    }

    /* Cleanup */
    bpf_link__destroy(link);
    bpf_object__close(obj);

    return 0;
}
