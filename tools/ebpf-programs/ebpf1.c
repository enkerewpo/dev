#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>

static volatile bool exiting = false;

static void sig_handler(int sig)
{
	exiting = true;
}

int main(int argc, char **argv)
{
	struct bpf_object *obj;
	struct bpf_link *link = NULL;
	int err;

	/* Cleaner handling of Ctrl-C */
	signal(SIGINT, sig_handler);
	signal(SIGTERM, sig_handler);

	/* Load and verify BPF application */
	obj = bpf_object__open_file("ebpf1.bpf.o", NULL);
	if (libbpf_get_error(obj)) {
		fprintf(stderr, "ERROR: opening BPF object file failed\n");
		return 1;
	}

	/* Load BPF program */
	err = bpf_object__load(obj);
	if (err) {
		fprintf(stderr, "ERROR: loading BPF object file failed\n");
		goto cleanup;
	}

	/* Attach tracepoint */
	link = bpf_program__attach(bpf_object__find_program_by_name(obj, "handle_tp"));
	if (libbpf_get_error(link)) {
		fprintf(stderr, "ERROR: bpf_program__attach failed\n");
		link = NULL;
		goto cleanup;
	}

	printf("Successfully started! Please run `sudo cat /sys/kernel/debug/tracing/trace_pipe` "
	       "to see output of the BPF programs.\n");
	printf("Press Ctrl+C to stop.\n");

	/* Main loop - just wait for signals */
	while (!exiting) {
		sleep(1);
	}

	printf("Stopping...\n");

cleanup:
	bpf_link__destroy(link);
	bpf_object__close(obj);
	return err != 0;
}