///|
#borrow(path)
extern "c" fn open_fd(path : Bytes, mode : Int32) -> Int32 = "pblaze_open"

///|
extern "c" fn close_fd(fd : Int32) -> Unit = "pblaze_close"

///|
#borrow(buf)
extern "c" fn positional(
  fd : Int32,
  buf : FixedArray[Byte],
  n : Int32,
  address : Int64,
  writing : Bool,
  kind : Int32,
) -> Int32 = "pblaze_positional_io"

///|
#borrow(buf)
extern "c" fn stream(
  fd : Int32,
  buf : FixedArray[Byte],
  n : Int32,
  writing : Bool,
) -> Int32 = "pblaze_stream_io"

///|
extern "c" fn lock_card(fd : Int32) -> Int32 = "pblaze_lock"

///|
extern "c" fn aperture_size(fd : Int32) -> Int64 = "pblaze_aperture_size"

///|
extern "c" fn file_size(fd : Int32) -> Int64 = "pblaze_file_size"

///|
#borrow(path)
extern "c" fn temporary(path : FixedArray[Byte]) -> Int32 = "pblaze_temporary"

///|
#borrow(path)
extern "c" fn discard(path : FixedArray[Byte]) -> Unit = "pblaze_discard"

///|
#borrow(temp, path)
extern "c" fn publish(temp : FixedArray[Byte], path : Bytes) -> Int32 = "pblaze_publish"

///|
fn open_path(path : String, mode : Int32) -> Int32 raise {
  guard !path.contains("\u0000") else { fail("NUL in path") }
  let fd = open_fd(@utf8.encode(path + "\u0000"), mode)
  guard fd >= 0 else { fail("open \{path} returned \{fd}") }
  fd
}

///|
fn exact(io : Int32, count : Int32) -> Unit raise {
  guard io == count else { fail("I/O returned \{io}, expected \{count}") }
}

///|
fn u32(buf : FixedArray[Byte], pos : Int32) -> UInt32 {
  buf[pos].to_uint() |
  (buf[pos + 1].to_uint() << 8) |
  (buf[pos + 2].to_uint() << 16) |
  (buf[pos + 3].to_uint() << 24)
}

///|
/// A private binary pipe between the local inference bridge and this process.
/// Frames carry opcode (1 read, 2 write), absolute byte address and byte count,
/// all little-endian u32. A successful reply starts with the exact byte count.
fn serve(prefix : String) -> Unit raise {
  let h2c = open_path(prefix + "_h2c_0", 1)
  defer close_fd(h2c)
  let c2h = open_path(prefix + "_c2h_0", 0)
  defer close_fd(c2h)
  let bar = open_path(prefix + "_user", 2)
  defer close_fd(bar)
  exact(lock_card(bar), 0)
  let header = FixedArray::make(12, b'\x00')
  let ack = FixedArray::make(4, b'\x00')
  let buf = FixedArray::make(1048576, b'\x00')
  while true {
    let got = stream(0, header, 12, false)
    if got == 0 {
      return
    }
    exact(got, 12)
    let op = u32(header, 0)
    let address = u32(header, 4).to_int64()
    let count = u32(header, 8).to_int64()
    guard (op == 1U || op == 2U) &&
      count >= 4L &&
      count <= 1048576L &&
      count % 4L == 0L &&
      address % 4L == 0L else {
      fail("invalid XDMA frame")
    }
    let n = count.to_int()
    let write = op == 2U
    let (fd, offset, kind) = if address + count <= 0x80000000L {
      (if write { h2c } else { c2h }, address, 1)
    } else if !write && address == 0x80000000L && count == 4L {
      (bar, 0x80000L, 2)
    } else if address >= 0x80100000L && address + count <= 0x80160000L {
      (bar, address - 0x80100000L, 2)
    } else if op == 1 &&
      address >= 0x80190000L &&
      address + count <= 0x80190400L {
      (bar, address - 0x80100000L, 2)
    } else {
      fail("outside PCIe DDR or control aperture")
    }
    if write {
      exact(stream(0, buf, n, false), n)
    }
    exact(positional(fd, buf, n, offset, write, kind), n)
    for i in 0..<4 {
      ack[i] = header[8 + i]
    }
    exact(stream(1, ack, 4, true), 4)
    if !write {
      exact(stream(1, buf, n, true), n)
    }
  }
}

///|
fn copy(
  direction : String,
  prefix : String,
  address : Int64,
  file : String,
  offset : Int64,
  count : Int64,
) -> Unit raise {
  guard count > 0L &&
    count <= 0x80000000L &&
    address >= 0L &&
    address <= 0x80000000L - count &&
    offset >= 0L &&
    offset <= 0x7fffffffffffffffL - count else {
    fail("invalid transfer range")
  }
  guard !file.contains("\u0000") else { fail("NUL in file path") }
  let upload = direction == "upload"
  let bar = open_path(prefix + "_user", 2)
  defer close_fd(bar)
  exact(lock_card(bar), 0)
  let dma = open_path(
    prefix + (if upload { "_h2c_0" } else { "_c2h_0" }),
    if upload {
      1
    } else {
      0
    },
  )
  defer close_fd(dma)
  let temp = @utf8.encode(file + ".pblaze3-XXXXXX\u0000").to_fixedarray()
  let disk = if upload { open_path(file, 0) } else { temporary(temp) }
  guard disk >= 0 else { fail("cannot create output temporary file: \{disk}") }
  defer close_fd(disk)
  defer (if !upload { discard(temp) })
  if upload {
    guard file_size(disk) >= offset + count else {
      fail("source range exceeds file size")
    }
    let span = aperture_size(bar)
    guard span >= 0L else { fail("cannot identify PCIe user BAR: \{span}") }
    guard span == 1048576L else { fail("unrecognized user BAR size") }
    let word = FixedArray::make(4, b'\x00')
    exact(positional(bar, word, 4, 0L, false, 2), 4)
    if u32(word, 0) == 0x50423330U {
      // The diagnostic image has GPIO at offset zero and no resident identity.
      exact(positional(bar, word, 4, 0x260L, false, 2), 4)
      guard u32(word, 0) == 0x53465531U else {
        fail("missing residency register")
      }
      for i in 0..<4 {
        word[i] = b'\x00'
      }
      exact(positional(bar, word, 4, 0x29cL, true, 2), 4)
      exact(positional(bar, word, 4, 0x29cL, false, 2), 4)
      guard u32(word, 0) == 0U else { fail("residency invalidation failed") }
    }
  }
  let buf = FixedArray::make(1048576, b'\x00')
  for done = 0L; done < count; {
    let n = (count - done).min(1048576L).to_int()
    if upload {
      exact(positional(disk, buf, n, offset + done, false, 0), n)
      exact(positional(dma, buf, n, address + done, true, 1), n)
    } else {
      exact(positional(dma, buf, n, address + done, false, 1), n)
      exact(positional(disk, buf, n, offset + done, true, 0), n)
    }
    continue done + n.to_int64()
  }
  if !upload {
    exact(publish(temp, @utf8.encode(file + "\u0000")), 0)
  }
}

///|
fn main raise {
  match @env.args()[1:] {
    ["serve", prefix] => serve(prefix)
    ["upload" | "download" as direction, prefix, address, file, offset, count] =>
      copy(
        direction,
        prefix,
        @string.parse_int64(address),
        file,
        @string.parse_int64(offset),
        @string.parse_int64(count),
      )
    _ =>
      fail(
        "serve DEVICE_PREFIX | upload|download DEVICE_PREFIX DDR_ADDRESS FILE FILE_OFFSET BYTE_COUNT",
      )
  }
}
