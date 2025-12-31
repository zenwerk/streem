package streem

import "base:intrinsics"

// Atomic operations module
// Reference: src/atomic.h
//
// In C version, GCC built-in atomics are used:
// - __sync_bool_compare_and_swap
// - __sync_fetch_and_add
// - __sync_fetch_and_sub
// - __sync_fetch_and_or
// - __sync_fetch_and_and
//
// Odin provides intrinsics for atomic operations

// Compare-and-swap: atomically compare *a with b, if equal set to c
// Returns true if exchange happened
atomic_cas :: proc "contextless" (a: ^$T, old_val: T, new_val: T) -> bool {
	_, ok := intrinsics.atomic_compare_exchange_strong(a, old_val, new_val)
	return ok
}

// Atomic add: atomically add b to *a, return old value
atomic_add :: proc "contextless" (a: ^$T, b: T) -> T {
	return intrinsics.atomic_add(a, b)
}

// Atomic subtract: atomically subtract b from *a, return old value
atomic_sub :: proc "contextless" (a: ^$T, b: T) -> T {
	return intrinsics.atomic_sub(a, b)
}

// Atomic increment: atomically increment *a by 1, return old value
atomic_inc :: proc "contextless" (a: ^$T) -> T where intrinsics.type_is_integer(T) {
	return intrinsics.atomic_add(a, T(1))
}

// Atomic decrement: atomically decrement *a by 1, return old value
atomic_dec :: proc "contextless" (a: ^$T) -> T where intrinsics.type_is_integer(T) {
	return intrinsics.atomic_sub(a, T(1))
}

// Atomic OR: atomically OR b to *a, return old value
atomic_or :: proc "contextless" (a: ^$T, b: T) -> T {
	return intrinsics.atomic_or(a, b)
}

// Atomic AND: atomically AND b to *a, return old value
atomic_and :: proc "contextless" (a: ^$T, b: T) -> T {
	return intrinsics.atomic_and(a, b)
}

// Atomic load: atomically load value from *a
atomic_load :: proc "contextless" (a: ^$T) -> T {
	return intrinsics.atomic_load(a)
}

// Atomic store: atomically store value to *a
atomic_store :: proc "contextless" (a: ^$T, val: T) {
	intrinsics.atomic_store(a, val)
}
