# System Architecture Document — sync_fifo · SAD v0.1

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
One block, `sync_fifo`: a storage of 16 words, a write position, a read position and an occupancy
measure. A split would add interfaces without gain. Guidance, not a requirement (ADR-04): the
oldest word is read from state alone, so out_valid and out_data depend on no input (REQ-3.3.1);
in_ready is "not full" OR out_ready, which gives the one arc (REQ-3.1.7, REQ-3.3.2).

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

Feasibility (proxy of the architecture, opensta_liberty, confidence 0.5, pre-layout, tt): the 200 MHz target is MISSED. Fmax estimate 196 MHz (register-to-register slack -0.103 ns); worst setup slack -2.764 ns on the path from the read-position state through the 16:1 read mux to out_data, against the 30 % output delay; area 20211.9 um2. This raised challenge AC-1 (target_conflict). The target is not relaxed here. Options for the person: errata_major to change the frequency target, or an ADR that changes the decomposition so out_data comes straight from a dedicated output stage instead of the read mux (this keeps the ports and the combinational-arc rule). The result is of a proxy, not of Kemi's RTL.

## 7 Risk register
See `riskmap.yaml`.

## 8 Open items
Open ArchChallenges: AC-1 (target_conflict, blocker): the proxy misses 200 MHz (see 6.1); the person decides between a target change and a decomposition change. The brief's contradiction is resolved by the person's answer
(ADR-01, status proposed, for sign-off).

Unresolved architectural decisions, for the approver:
1. ADR-01 to ADR-04 await acceptance.
2. Should a depth-status output (level, almost-full) be added? Not asked for, so not added.
3. Whether the neighbouring blocks tolerate the out_ready to in_ready arc in their timing budget (R-01).
4. Behaviour when rst_n changes asynchronously to core_clk: unspecified and illegal.
