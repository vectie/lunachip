#define _DARWIN_C_SOURCE

#include <dlfcn.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static _Atomic uint64_t allocation_calls = 0;
static _Atomic uint64_t allocation_bytes = 0;
static _Atomic uint64_t malloc_calls = 0;
static _Atomic uint64_t calloc_calls = 0;
static _Atomic uint64_t realloc_calls = 0;
static _Atomic int counter_enabled = 0;

enum { maximum_allocation_sites = 128 };

struct allocation_site {
  const void *address;
  uint64_t calls;
  uint64_t bytes;
};

static struct allocation_site allocation_sites[maximum_allocation_sites];
static size_t allocation_site_count = 0;

static void record_site(const void *address, uint64_t size) {
  for (size_t index = 0; index < allocation_site_count; index += 1) {
    if (allocation_sites[index].address == address) {
      allocation_sites[index].calls += 1;
      allocation_sites[index].bytes += size;
      return;
    }
  }
  if (allocation_site_count < maximum_allocation_sites) {
    allocation_sites[allocation_site_count] = (struct allocation_site){
        .address = address,
        .calls = 1,
        .bytes = size,
    };
    allocation_site_count += 1;
  }
}

static void record_allocation(uint64_t size, _Atomic uint64_t *kind,
                              const void *caller) {
  if (atomic_load_explicit(&counter_enabled, memory_order_relaxed)) {
    atomic_fetch_add_explicit(&allocation_calls, 1, memory_order_relaxed);
    atomic_fetch_add_explicit(&allocation_bytes, size, memory_order_relaxed);
    atomic_fetch_add_explicit(kind, 1, memory_order_relaxed);
    record_site(caller, size);
  }
}

static void *counting_malloc(size_t size) {
  record_allocation((uint64_t)size, &malloc_calls,
                    __builtin_return_address(0));
  return malloc(size);
}

static void *counting_calloc(size_t count, size_t size) {
  record_allocation((uint64_t)count * (uint64_t)size, &calloc_calls,
                    __builtin_return_address(0));
  return calloc(count, size);
}

static void *counting_realloc(void *pointer, size_t size) {
  record_allocation((uint64_t)size, &realloc_calls,
                    __builtin_return_address(0));
  return realloc(pointer, size);
}

#define LUNACHIP_INTERPOSE(replacement, replacee)                            \
  __attribute__((used)) static struct {                                      \
    const void *replacement;                                                 \
    const void *replacee;                                                    \
  } interpose_##replacee __attribute__((section("__DATA,__interpose"))) = { \
    (const void *)(uintptr_t)&replacement,                                   \
    (const void *)(uintptr_t)&replacee,                                      \
  }

LUNACHIP_INTERPOSE(counting_malloc, malloc);
LUNACHIP_INTERPOSE(counting_calloc, calloc);
LUNACHIP_INTERPOSE(counting_realloc, realloc);

__attribute__((visibility("default")))
void lunachip_interposer_counter_start(void) {
  atomic_store_explicit(&allocation_calls, 0, memory_order_relaxed);
  atomic_store_explicit(&allocation_bytes, 0, memory_order_relaxed);
  atomic_store_explicit(&malloc_calls, 0, memory_order_relaxed);
  atomic_store_explicit(&calloc_calls, 0, memory_order_relaxed);
  atomic_store_explicit(&realloc_calls, 0, memory_order_relaxed);
  allocation_site_count = 0;
  atomic_store_explicit(&counter_enabled, 1, memory_order_relaxed);
}

__attribute__((visibility("default")))
void lunachip_interposer_counter_stop(void) {
  atomic_store_explicit(&counter_enabled, 0, memory_order_relaxed);
  for (size_t index = 0; index < allocation_site_count; index += 1) {
    Dl_info information = {0};
    const char *symbol = "<unknown>";
    uintptr_t offset = 0;
    if (dladdr(allocation_sites[index].address, &information) != 0 &&
        information.dli_sname != NULL) {
      symbol = information.dli_sname;
      offset = (uintptr_t)allocation_sites[index].address -
               (uintptr_t)information.dli_saddr;
    }
    fprintf(stderr,
            "allocation_site=%s+0x%llx calls=%llu bytes_requested=%llu\n",
            symbol, (unsigned long long)offset,
            (unsigned long long)allocation_sites[index].calls,
            (unsigned long long)allocation_sites[index].bytes);
  }
}

__attribute__((visibility("default")))
uint64_t lunachip_interposer_allocation_calls(void) {
  return atomic_load_explicit(&allocation_calls, memory_order_relaxed);
}

__attribute__((visibility("default")))
uint64_t lunachip_interposer_allocation_bytes(void) {
  return atomic_load_explicit(&allocation_bytes, memory_order_relaxed);
}

__attribute__((visibility("default")))
uint64_t lunachip_interposer_malloc_calls(void) {
  return atomic_load_explicit(&malloc_calls, memory_order_relaxed);
}

__attribute__((visibility("default")))
uint64_t lunachip_interposer_calloc_calls(void) {
  return atomic_load_explicit(&calloc_calls, memory_order_relaxed);
}

__attribute__((visibility("default")))
uint64_t lunachip_interposer_realloc_calls(void) {
  return atomic_load_explicit(&realloc_calls, memory_order_relaxed);
}
