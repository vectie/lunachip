///|
test "CLI ring demo fetches encoded commands and executes through one real byte memory port" {
  inspect(run_command(["ring-demo"]), content=(
    #|LunaWave FluxTile ring demo: fetched LoadA -> LoadB -> MatMul -> StoreC -> Fence
    #|host C=[-44, 12, 66; -2005, 2328, 715] oracle=match
    #|5 ordered successful completions; producer=5 consumer=5; descriptors fetched from host bytes
    #|requests=181 read_bytes=175 write_bytes=24; descriptor/input/output padding preserved
    #|modeled compute cycles=7 active=6 capture=6; shared transport backpressure and delayed responses exercised
    #|Simulation only; provisional fetched ring and draft device ABI.
  ))
}
