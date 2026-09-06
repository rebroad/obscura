// Android's ARM64 dynamic loader requires PT_TLS alignment of at least 64 bytes.
// Keep this input section alive so every Cargo-linked executable, including test
// harnesses, inherits that alignment.
    .section .tdata.obscura_android_tls_alignment,"awT",@progbits
    .p2align 6
    .globl obscura_android_tls_alignment
    .hidden obscura_android_tls_alignment
    .type obscura_android_tls_alignment, %object
    .size obscura_android_tls_alignment, 64
obscura_android_tls_alignment:
    .zero 64

    .section .note.GNU-stack,"",@progbits
