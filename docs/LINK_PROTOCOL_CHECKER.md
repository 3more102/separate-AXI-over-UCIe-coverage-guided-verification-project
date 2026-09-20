# Abstract UCIe Link Protocol Checker

`tb/checkers/link_protocol_checker.sv` is a passive checker for the current
single-outstanding request/response transport used by the packetized
AXI-over-UCIe milestone.

It checks four invariants independently of the AXI scoreboard:

1. A request whose `VALID` is high while `READY` is low must keep `VALID`
   asserted and keep operation, ID, address, length, size, data and strobe stable.
2. A stalled response must keep `VALID` and its payload stable.
3. A response cannot appear without an accepted outstanding request.
4. Response direction and response ID must match the accepted request.

The checker also flags a second accepted request while another request is still
outstanding. That rule matches the current RTL milestone; it must be replaced by
tag/credit bookkeeping when multiple outstanding transactions are implemented.

## Open-source self-test

```bash
cd sim
iverilog -g2012 -Wall -s link_protocol_checker_tb \
  -o ../build/link_checker.vvp -f link_checker.f
vvp ../build/link_checker.vvp
```

The unit test includes one legal backpressured transaction and deliberate
negative cases for response-ID mismatch and request-payload instability. CI
passes only when the checker accepts the legal case and detects both violations.

This checker validates the repository's abstract digital transport contract. It
does not assert UCIe PHY, electrical, training, CRC, retry, or standards
compliance.
