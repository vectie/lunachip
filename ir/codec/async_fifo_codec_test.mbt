///|
const ASYNC_FIFO_CODEC_GOLDEN : String =
  #|LUNACHIP-IR 4
  #|DESIGN 6173796e632d6669666f
  #|TOP 436865636b65644173796e634669666f
  #|MODULES 1
  #|MODULE 436865636b65644173796e634669666f
  #|DOMAINS 2
  #|DOMAIN 0 0 rising
  #|DOMAIN 1 1 rising
  #|PARAMETERS 0
  #|NODES 47
  #|NODE 0 clock input 736f757263655f636c6f636b
  #|NODE 1 clock input 64657374696e6174696f6e5f636c6f636b
  #|NODE 2 reset input 736f757263655f7265736574
  #|NODE 3 reset input 64657374696e6174696f6e5f7265736574
  #|NODE 4 bits:1 input 736f757263655f76616c6964
  #|NODE 5 uint:8 input 736f757263655f776f7264
  #|NODE 6 bits:3 input 736f757263655f746167
  #|NODE 7 bits:1 input 64657374696e6174696f6e5f7265616479
  #|NODE 8 uint:4 reg 0 19 2 0 synchronous active_high - -
  #|NODE 9 uint:4 reg 0 21 2 0 synchronous active_high - -
  #|NODE 10 bits:1 reg 0 34 2 0 synchronous active_high - -
  #|NODE 11 uint:4 reg 1 23 3 0 synchronous active_high - -
  #|NODE 12 uint:4 reg 1 25 3 0 synchronous active_high - -
  #|NODE 13 bits:1 reg 1 36 3 0 synchronous active_high - -
  #|NODE 14 bits:1 not 10
  #|NODE 15 bits:1 and 4 14
  #|NODE 16 bits:1 and 13 7
  #|NODE 17 uint:4 const 1
  #|NODE 18 uint:4 add 8 17
  #|NODE 19 uint:4 mux 15 18 8
  #|NODE 20 uint:4 lshr 19 17
  #|NODE 21 uint:4 xor 19 20
  #|NODE 22 uint:4 add 11 17
  #|NODE 23 uint:4 mux 16 22 11
  #|NODE 24 uint:4 lshr 23 17
  #|NODE 25 uint:4 xor 23 24
  #|NODE 26 uint:4 reg 0 12 2 0 synchronous active_high - -
  #|NODE 27 uint:4 reg 0 26 2 0 synchronous active_high - -
  #|NODE 28 uint:4 reg 0 27 2 0 synchronous active_high - -
  #|NODE 29 uint:4 reg 1 9 3 0 synchronous active_high - -
  #|NODE 30 uint:4 reg 1 29 3 0 synchronous active_high - -
  #|NODE 31 uint:4 reg 1 30 3 0 synchronous active_high - -
  #|NODE 32 uint:4 const 12
  #|NODE 33 uint:4 xor 28 32
  #|NODE 34 bits:1 eq 21 33
  #|NODE 35 bits:1 eq 25 31
  #|NODE 36 bits:1 not 35
  #|NODE 37 bits:3 slice 8 2 0
  #|NODE 38 uint:3 reinterpret 37
  #|NODE 39 bits:3 slice 11 2 0
  #|NODE 40 uint:3 reinterpret 39
  #|NODE 41 uint:8 async_fifo_read 0 0
  #|NODE 42 uint:8 const 0
  #|NODE 43 uint:8 mux 13 41 42
  #|NODE 44 bits:3 async_fifo_read 0 1
  #|NODE 45 bits:3 const 0
  #|NODE 46 bits:3 mux 13 44 45
  #|MEMORIES 0
  #|OUTPUTS 4
  #|OUTPUT 64657374696e6174696f6e5f746167 bits:3 46
  #|OUTPUT 64657374696e6174696f6e5f76616c6964 bits:1 13
  #|OUTPUT 64657374696e6174696f6e5f776f7264 uint:8 43
  #|OUTPUT 736f757263655f7265616479 bits:1 14
  #|INPUT_TIMINGS 6
  #|INPUT_TIMING 2 sampled_in 0
  #|INPUT_TIMING 3 sampled_in 1
  #|INPUT_TIMING 4 sampled_in 0
  #|INPUT_TIMING 5 sampled_in 0
  #|INPUT_TIMING 6 sampled_in 0
  #|INPUT_TIMING 7 sampled_in 1
  #|OUTPUT_TIMINGS 4
  #|OUTPUT_TIMING 64657374696e6174696f6e5f746167 produced_in 1
  #|OUTPUT_TIMING 64657374696e6174696f6e5f76616c6964 produced_in 1
  #|OUTPUT_TIMING 64657374696e6174696f6e5f776f7264 produced_in 1
  #|OUTPUT_TIMING 736f757263655f7265616479 produced_in 0
  #|AGGREGATES 0
  #|PRIMITIVES 1
  #|PRIMITIVE 0 async_fifo 7175657565f09f94a5
  #|SOURCE_DOMAIN 0
  #|DESTINATION_DOMAIN 1
  #|DEPTH 8
  #|POINTER_WIDTH 4
  #|SYNCHRONIZER_STAGES 3
  #|RESET_POLICY coordinated_idle
  #|SOURCE_RESET synchronous active_high 2 0
  #|DESTINATION_RESET synchronous active_high 3 0
  #|SHAPE record 2
  #|FIELD 776f7264
  #|SHAPE leaf uint:8
  #|FIELD 746167
  #|SHAPE leaf bits:3
  #|SOURCE_VALID 4
  #|SOURCE_READY 14
  #|SOURCE_TRANSFER 15
  #|SOURCE_PAYLOADS 2
  #|SOURCE_PAYLOAD 0 5
  #|SOURCE_PAYLOAD 1 6
  #|DESTINATION_READY 7
  #|DESTINATION_VALID 13
  #|DESTINATION_TRANSFER 16
  #|DESTINATION_PAYLOADS 2
  #|DESTINATION_PAYLOAD 0 41 43
  #|DESTINATION_PAYLOAD 1 44 46
  #|WRITE_BINARY 8
  #|WRITE_BINARY_NEXT 19
  #|READ_BINARY 11
  #|READ_BINARY_NEXT 23
  #|WRITE_GRAY 9
  #|WRITE_GRAY_NEXT 21
  #|READ_GRAY 12
  #|READ_GRAY_NEXT 25
  #|READ_GRAY_STAGES 3
  #|READ_GRAY_STAGE 0 26
  #|READ_GRAY_STAGE 1 27
  #|READ_GRAY_STAGE 2 28
  #|WRITE_GRAY_STAGES 3
  #|WRITE_GRAY_STAGE 0 29
  #|WRITE_GRAY_STAGE 1 30
  #|WRITE_GRAY_STAGE 2 31
  #|FULL 10
  #|FULL_NEXT 34
  #|NONEMPTY 13
  #|NONEMPTY_NEXT 36
  #|WRITE_ADDRESS 38
  #|READ_ADDRESS 40
  #|ENDPRIMITIVE
  #|ENDMODULE
  #|END
  #|

///|
test "schema four async FIFO has exact canonical bytes" {
  let decoded = @codec.parse(ASYNC_FIFO_CODEC_GOLDEN)
  assert_eq(@codec.serialize(decoded), ASYNC_FIFO_CODEC_GOLDEN)
  guard decoded.top_module().unwrap().cdc_primitives()[0] is AsyncFifo(spec) else {
    fail("expected asynchronous FIFO primitive")
  }
  assert_eq(spec.depth(), 8)
  assert_eq(spec.synchronizer_stages(), 3)
  assert_eq(spec.raw_reads().length(), 2)
}

///|
test "schema four async FIFO fails closed on lists fields and truncation" {
  let malformed = [
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="RESET_POLICY coordinated_idle",
      new="RESET_POLICY independent",
    ),
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="SOURCE_PAYLOADS 2",
      new="SOURCE_PAYLOADS 1",
    ),
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="SOURCE_PAYLOAD 1 6",
      new="SOURCE_PAYLOAD 2 6",
    ),
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="READ_GRAY_STAGE 1 27",
      new="READ_GRAY_STAGE 2 27",
    ),
    ASYNC_FIFO_CODEC_GOLDEN.replace(old="FIELD 746167", new="FIELD 776f7264"),
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="ENDPRIMITIVE\nENDMODULE",
      new="ENDMODULE",
    ),
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="ENDPRIMITIVE",
      new="UNKNOWN_FIELD 1\nENDPRIMITIVE",
    ),
    ASYNC_FIFO_CODEC_GOLDEN.replace(
      old="NODE 42 uint:8 const 0",
      new="NODE 42 uint:8 async_fifo_read 0 0",
    ),
  ]
  for document in malformed {
    try @codec.parse(document) catch {
      _ => ()
    } noraise {
      _ => fail("expected malformed asynchronous FIFO rejection")
    }
  }
}
