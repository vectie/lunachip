# PRX100 descriptor publication pipeline

Revision1.2 remains the qualified historical baseline. The later
[byte-memory port isolation](PRX100_BYTE_MEMORY.md) retains its publication
rules and adds a separate collection port and result lookahead; its fresh
board A/B measurement is1.12747→1.12710ms, only0.033% lower.

Target revision 1.2 retains the exact portable core, four-entry ring, two
internal slots, workload and 50/100 MHz clocks. This is a target implementation
contract. The [physical qualification](evidence/prx100-publication-20261017.md)
passes20 jobs at median1.12750ms,18.01% below the1.37524ms baseline.

The target joins successful operand prefetch with consumer advancement past
all four current packets before updating the next tile's twelve changing
descriptor words. It publishes all four next commands while the current tile
is still being retired or collected. Consumer advancement, rather than
completion, releases descriptor storage. No partially fetched or held packet
may be overwritten. The publication cursor stays at most one tile ahead of
the collection cursor.

Operand banks alternate at A256/2304 and B512/2560. Result banks now alternate
at C1024/3072. A bank is recycled only after its old tile's four ordered
completions and eight acknowledged partial-result writes. Next-tile work can
overlap current result collection. Separate C addresses preserve ownership
for any admitted younger StoreC; actual store admission remains constrained
by the unchanged core's retirement capacity. Ordered completion ACK pauses after each group of four until that
group's collection finishes; held younger completions retain core ownership.

One synchronous BRAM read port serves both clients. A host result read blocks
new core acceptance and waits for any held tagged response to retire before
changing the read address. The latch uses the following edge. Host writes
continue to exclude core writes; core reads may overlap descriptor/prefetch
writes. Legal core writes cover only the two eight-word C regions.

START and physical reset clear publication state together with existing
ownership. Health loss, response/completion faults and watchdog fail closed.
Version is 0x00010002. Register layout and logical traffic counts are unchanged.
Core-wait counts publication, completion/join and collection-entry states;
staging counts descriptor initialization, operand request/wait and ahead
descriptor writes. These overlap DDR wait and each other and are not a
disjoint latency partition. START-to-DONE remains the comparable whole-job
measurement. No new performance claim is made before board verification.
