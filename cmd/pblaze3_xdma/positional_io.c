#define _DARWIN_C_SOURCE
#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#define _FILE_OFFSET_BITS 64
#include <moonbit.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/file.h>
#include <sys/stat.h>
#ifdef __linux__
#include <sys/sysmacros.h>
#endif

MOONBIT_FFI_EXPORT int32_t pblaze_open(const uint8_t *path, int32_t mode) {
  int flags = mode == 0 ? O_RDONLY : mode == 1 ? O_WRONLY :
              O_RDWR;
  int fd = open((const char *)path, flags | O_CLOEXEC, 0600);
  return fd < 0 ? -errno : fd;
}

MOONBIT_FFI_EXPORT void pblaze_close(int32_t fd) { close(fd); }

/* Use scalar syscalls. The pinned XDMA AIO implementation expects an
 * asynchronous completion callback for its iterator entry points. */
MOONBIT_FFI_EXPORT int32_t pblaze_positional_io(int32_t fd, uint8_t *data,
    int32_t length, int64_t address, int32_t writing, int32_t kind) {
  if (length <= 0 || length > 1024 * 1024 || address < 0 ||
      (kind == 2 && ((address | length) & 3)))
    return -EINVAL;
  uint8_t *io = data;
  void *allocation = NULL;
  /* XDMA incrementing AXI-MM compares the low host and endpoint address bits. */
  if (kind == 1 && (((uintptr_t)data ^ (uint64_t)address) & 4095)) {
    int err = posix_memalign(&allocation, 4096, (size_t)length + 4095);
    if (err) return -err;
    io = (uint8_t *)allocation + (address & 4095);
    if (writing) memcpy(io, data, length);
  }
  int result = 0;
  while (result < length) {
    size_t n = kind == 2 ? 4u : (size_t)(length - result);
    ssize_t done = writing ? pwrite(fd, io + result, n, address + result)
                           : pread(fd, io + result, n, address + result);
    if (done < 0 && errno == EINTR) continue;
    if (done < 0) { result = -errno; break; }
    if (!done || (kind != 0 && (size_t)done != n)) { result = -EIO; break; }
    result += (int)done;
  }
  if (allocation && !writing && result == length) memcpy(data, io, length);
  free(allocation);
  return result;
}

/* Pipes may return short counts. EOF is valid only between frames. */
MOONBIT_FFI_EXPORT int32_t pblaze_stream_io(int32_t fd, uint8_t *data,
    int32_t length, int32_t writing) {
  int offset = 0;
  while (offset < length) {
    ssize_t n = writing ? write(fd, data + offset, length - offset)
                        : read(fd, data + offset, length - offset);
    if (n < 0 && errno == EINTR) continue;
    if (n < 0) return -errno;
    if (!n) return offset == 0 ? 0 : -EIO;
    offset += (int)n;
  }
  return offset;
}


MOONBIT_FFI_EXPORT int32_t pblaze_lock(int32_t fd) {
  return flock(fd, LOCK_EX | LOCK_NB) == 0 ? 0 : -errno;
}

MOONBIT_FFI_EXPORT int64_t pblaze_file_size(int32_t fd) {
  struct stat st;
  return fstat(fd, &st) == 0 ? st.st_size : -errno;
}

MOONBIT_FFI_EXPORT int64_t pblaze_aperture_size(int32_t fd) {
  struct stat st;
  if (fstat(fd, &st)) return -errno;
  if (S_ISREG(st.st_mode)) return st.st_size;
#ifdef __linux__
  char path[128];
  snprintf(path, sizeof(path), "/sys/dev/char/%u:%u/device/resource0",
           major(st.st_rdev), minor(st.st_rdev));
  return stat(path, &st) == 0 ? st.st_size : -errno;
#else
  return -ENOTSUP;
#endif
}

MOONBIT_FFI_EXPORT int32_t pblaze_temporary(uint8_t *path) {
  int fd = mkstemp((char *)path);
  return fd < 0 ? -errno : fd;
}

MOONBIT_FFI_EXPORT void pblaze_discard(const uint8_t *path) {
  unlink((const char *)path);
}

MOONBIT_FFI_EXPORT int32_t pblaze_publish(const uint8_t *temp, const uint8_t *path) {
  return link((const char *)temp, (const char *)path) == 0 ? 0 : -errno;
}
