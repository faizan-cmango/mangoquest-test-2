# System Architecture Document — sync_fifo · SAD v0.4

> Machine index: `sad.yaml`. Requirements live in `rtm.yaml`, ports in `idd/`, scenarios in
> `vps.yaml`, risk in `riskmap.yaml`, clocks in `clocks.yaml`.

## 1 Scope and context
A synchronous FIFO of 16 words of 32 bits between a producer (IDD-S_IN) and a consumer
(IDD-M_OUT), both valid-ready, on one clock and one synchronous active-low reset (`clocks.yaml`).
Out of scope: registers, interrupts, programmable thresholds, error flags, power, DFT insertion,
board design.

The brief contradicts itself: in_ready must follow out_ready combinationally when full, and no
input-to-output path may exist. The person chose to allow that one arc and no other (ADR-01).

Assumptions (defaults, none asked):
1. The producer and the consumer are synchronous to core_clk and may change valid or ready at any cycle.
2. The consumer never drives out_ready combinationally from in_ready (IDD-S_IN R4).
3. in_ready is 0 during reset and out_data is 0 when out_valid is 0 (ADR-03).
4. A word accepted into an empty FIFO is visible one cycle later; there is no write-through (ADR-02).
5. No area, power or pin target is given, so none is set; the only target is 200 MHz.

## 2 Block decomposition
One block, `sync_fifo`, decomposed internally (ADR-05, ADR-06) into an output stage of one word, a pre-read stage of one word and a body
store of up to 14 words, so the capacity stays 16. The output stage loads from the pre-read stage (a register), which loads from the body store, so the 16:1 read mux no longer feeds the output stage; words fill the front stages first. out_valid and out_data are driven straight from
the output stage's flip-flops, not from a read mux; the stage is loaded at a clock edge from the
body store, or from in_data when the body is empty (one-cycle latency, no write-through to the
ports), and loaded with 0 when it empties. A split into separate blocks would add interfaces
without gain. Guidance, not a requirement (ADR-04): the body is a flop array. The oldest word is
read from state alone, so out_valid and out_data depend on no input (REQ-3.3.1);
in_ready is "not full" OR out_ready, which gives the one arc (REQ-3.1.7, REQ-3.3.2).

ADR-07 (proposed, for AC-1) refines the front end: the output stage becomes two words used alternately (a head toggle picks the word shown on out_valid and out_data, so a dequeue moves no data), each with its own load enable derived from stage state only, never from out_ready. out_ready then reaches only the head toggle, the valid bits, the held-word count and in_ready, which cuts its fanout. The stages are the 2 output words, the 1-word pre-read stage and a 14-word body; in_ready is limited by a count of 16 held words, and the stages may hold a 17th word physically so that the accept-and-release cycle at 16 needs no data move steered by out_ready. This is not visible at the ports: capacity stays 16 and the single out_ready to in_ready arc is unchanged.

## 3.1 Dataflow — REQ-3.1.1 … REQ-3.1.8
A transfer is valid and ready both 1 at a rising edge (REQ-3.1.2). Order is kept and nothing is
lost or duplicated (REQ-3.1.3). Cycle sketch at full, in_valid 1, out_ready 1:

```
cycle        n        n+1      n+2
in_ready     1(=rdy)  1        1
out_valid    1        1        1      no bubble (REQ-3.1.6)
action       W(new)+R(oldest) each edge, occupancy stays 16
```
While fewer than 16 words are held in_ready is 1 (REQ-3.1.5); at 16 it equals out_ready within the
cycle (REQ-3.1.7). Simultaneous enqueue and dequeue below full leave the content count unchanged
(REQ-3.1.4). From empty, the first word shows after one cycle (REQ-3.1.8).

## 3.2 Output stability and reset — REQ-3.2.1 … REQ-3.2.4
A stalled output is stable (REQ-3.2.1). Reset empties the FIFO and sets the outputs (REQ-3.2.2,
REQ-3.2.3, REQ-3.2.4); a reset applied while words are held discards them.

## 3.3 Combinational independence — REQ-3.3.1, REQ-3.3.2
The only input-to-output path is out_ready to in_ready, only while full. No other input reaches
any output within a cycle; out_valid and out_data change only at a clock edge. Both are formal.

## 6.1 Performance — REQ-6.1.1
One clock, 200 MHz. The critical path is out_ready to in_ready through the input and output delay
budgets. Feasibility results: see the table below.

Feasibility (proxy of the architecture with the output stage of ADR-05, opensta_liberty, confidence 0.5, pre-layout, tt): the 200 MHz target is still MISSED. Fmax estimate 149.1 MHz; worst setup slack -1.707 ns on the path _1197_ -> _1162_ (register to register); area 21221.6 um2. The first proxy (read mux on out_data) gave 196 MHz and -2.764 ns on an output path. The output stage removed the output-path miss but the load logic (body read mux and in_data select into the stage, gated by out_ready) is now the longest path. The target is not relaxed. AC-1 stays open. Update (ADR-06, pre-read second stage, proxy with 14-word body): Fmax estimate 180.2 MHz; worst setup slack -1.426 ns on out_ready -> a stage-control flop (input delay budget plus out_ready fanout); register-to-register slack -0.550 ns; area 20317.0 um2. Still MISSED; AC-1 stays open and the target is not relaxed. Options for the person: (a) errata_major to lower the target; (b) a decomposition that cuts the out_ready fanout, for example a 2-word output stage with decoupled load enables so out_ready gates fewer flops (ADR); (c) a pipelined body read one cycle ahead (ADR). Results are of a proxy, not of Kemi's RTL.

Update (ADR-07, 2-word ping-pong output stage with decoupled load enables, proxy at docs/feasibility/sync_fifo/sync_fifo.sv, opensta_liberty, confidence 0.5, pre-layout, tt): Fmax estimate 158.0 MHz; worst setup slack -1.3275 ns on _2060_ -> _1979_ (register to register); area 22079.9 um2. The 200 MHz target is still MISSED, so slack is not non-negative and Fmax is below 200 MHz; AC-1 stays open and the target is not relaxed. Fmax history: 196.0 (read mux), 149.1 (ADR-05), 180.2 (ADR-06), 158.0 MHz (ADR-07). ADR-07 did not improve on ADR-06: the count and pointer update logic and the head and tail selects now set the path. Further options for the person: (a) errata_major to lower the target; (b) a pipelined body read one cycle ahead with registered one-hot stage state (ADR); (c) re-measure on Kemi's RTL, which can be hand-optimised beyond the proxy.

## 7 Risk register
See `riskmap.yaml`.

## 8 Open items
Open ArchChallenges: AC-1 (target_conflict, blocker): the proxy with the 2-word output stage (ADR-07) still misses 200 MHz at 158.0 MHz, slack -1.3275 ns (180.2 MHz with ADR-06, 149.1 MHz with ADR-05; see 6.1); the person decides on a further decomposition or a target change. The brief's contradiction is resolved by the person's answer
(ADR-01, status proposed, for sign-off).

Unresolved architectural decisions, for the approver:
1. ADR-01 to ADR-07 await acceptance.
2. Should a depth-status output (level, almost-full) be added? Not asked for, so not added.
3. Whether the neighbouring blocks tolerate the out_ready to in_ready arc in their timing budget (R-01).
4. Behaviour when rst_n changes asynchronously to core_clk: unspecified and illegal.
