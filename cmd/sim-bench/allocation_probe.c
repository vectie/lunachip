#include <dlfcn.h>
#include <stdint.h>
#include <time.h>

#include <moonbit.h>

typedef void (*counter_action)(void);
typedef uint64_t (*counter_value)(void);

static counter_action start_counter = NULL;
static counter_action stop_counter = NULL;
static counter_value read_allocation_calls = NULL;
static counter_value read_allocation_bytes = NULL;
static counter_value read_malloc_calls = NULL;
static counter_value read_calloc_calls = NULL;
static counter_value read_realloc_calls = NULL;
static int counter_resolution_attempted = 0;

static void resolve_counter(void) {
  if (counter_resolution_attempted) {
    return;
  }
  counter_resolution_attempted = 1;
  *(void **)(&start_counter) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_counter_start");
  *(void **)(&stop_counter) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_counter_stop");
  *(void **)(&read_allocation_calls) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_allocation_calls");
  *(void **)(&read_allocation_bytes) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_allocation_bytes");
  *(void **)(&read_malloc_calls) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_malloc_calls");
  *(void **)(&read_calloc_calls) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_calloc_calls");
  *(void **)(&read_realloc_calls) =
      dlsym(RTLD_DEFAULT, "lunachip_interposer_realloc_calls");
}

static int counter_available(void) {
  resolve_counter();
  return start_counter != NULL && stop_counter != NULL &&
         read_allocation_calls != NULL && read_allocation_bytes != NULL &&
         read_malloc_calls != NULL && read_calloc_calls != NULL &&
         read_realloc_calls != NULL;
}

MOONBIT_FFI_EXPORT
int32_t lunachip_allocation_counter_available(void) {
  return counter_available();
}

MOONBIT_FFI_EXPORT
void lunachip_allocation_counter_start(void) {
  if (counter_available()) {
    start_counter();
  }
}

MOONBIT_FFI_EXPORT
void lunachip_allocation_counter_stop(void) {
  if (counter_available()) {
    stop_counter();
  }
}

MOONBIT_FFI_EXPORT
uint64_t lunachip_allocation_calls(void) {
  return counter_available() ? read_allocation_calls() : 0;
}

MOONBIT_FFI_EXPORT
uint64_t lunachip_allocation_bytes(void) {
  return counter_available() ? read_allocation_bytes() : 0;
}

MOONBIT_FFI_EXPORT
uint64_t lunachip_malloc_calls(void) {
  return counter_available() ? read_malloc_calls() : 0;
}

MOONBIT_FFI_EXPORT
uint64_t lunachip_calloc_calls(void) {
  return counter_available() ? read_calloc_calls() : 0;
}

MOONBIT_FFI_EXPORT
uint64_t lunachip_realloc_calls(void) {
  return counter_available() ? read_realloc_calls() : 0;
}

MOONBIT_FFI_EXPORT
uint64_t lunachip_monotonic_nanoseconds(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC_RAW, &now) != 0) {
    return 0;
  }
  return (uint64_t)now.tv_sec * 1000000000ULL + (uint64_t)now.tv_nsec;
}
