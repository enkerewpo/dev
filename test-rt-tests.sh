#!/usr/bin/env bash

set -e

echo "Building and checking rt-tests for all architectures..."

architectures=("aarch64" "armv7l" "riscv64" "x86_64" "loongarch64")
compilers=("gcc")

mkdir -p test-results

for arch in "${architectures[@]}"; do
    for compiler in "${compilers[@]}"; do
        echo "Testing $arch with $compiler..."
        
    
        result=$(nix-build rt-tests.nix -A binary-checks.$arch.$compiler)
        
    
        cat "$result" > "test-results/${arch}-${compiler}.txt"
        
        echo "Result for $arch-$compiler:"
        cat "test-results/${arch}-${compiler}.txt"
        echo "----------------------------------------"
    done
done

echo "All tests completed. Results are in the test-results directory." 