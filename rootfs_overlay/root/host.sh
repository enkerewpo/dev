clang -target bpf \
    -nostdinc \
    -I../../../linux-git/include \
    -Iinclude \
    -g \
    -c \
    test1.bpf.c \
    -o test1.o
echo "built all ebpf objects"