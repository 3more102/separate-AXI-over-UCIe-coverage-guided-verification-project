# Verification Plan

## 1. Scope

This milestone verifies a single-beat AXI request/response path transported over a project-local 128-bit flit abstraction. The abstraction is useful for end-to-end verification work but is not a complete UCIe protocol model.

## 2. DUT assumptions

- 32-bit address and 32-bit data.
- 4-bit AXI ID.
- One outstanding read and one outstanding write.
- Single-beat transfers only: LEN=0, SIZE=2, INCR burst.
- Write address and write data may arrive in either order.
- Error response is injected for addresses in region 0xF000_0000-0xFFFF_FFFF.
- Read data returned by the responder is address XOR 0xA5A55A5A.

## 3. Checks

### AXI protocol-facing checks

- AW, W, and AR payloads remain stable while VALID is asserted and READY is low.
- B and R payloads remain stable under response backpressure.
- Returned BID/RID match the request ID.

### Transport checks

- UCIe request flit remains stable while stalled.
- Write packet fields match AW/W fields.
- Read packet fields match AR fields.
- Single-beat AXI metadata is encoded correctly.
- AXI response status matches the responder's address-region rule.
- Read data reconstructed on AXI matches the deterministic responder function.

## 4. Functional coverage

Current coverpoints:

- read vs write
- OKAY vs SLVERR vs other response
- normal vs error address region
- AW-before-W vs W-before-AW
- operation x response cross
- operation x address-region cross

SVA cover properties also observe:

- UCIe TX backpressure
- AXI read-response backpressure
- AXI write-response backpressure

## 5. Coverage-guided feedback

The helper script accepts coverage counts in JSON:

    {
      "bins": {
        "read": 30,
        "write": 31,
        "aw_before_w": 8,
        "w_before_aw": 2,
        "link_backpressure": 1,
        "read_backpressure": 0,
        "write_resp_error": 0,
        "read_resp_error": 1
      }
    }

It applies inverse-frequency weighting and emits both JSON knobs and optional simulator plusargs. Zero-hit bins therefore receive the largest next-run bias.

## 6. Planned extensions

1. Full AXI4 bursts with WLAST checking and beat-by-beat scoreboarding.
2. Multiple outstanding IDs and response reordering.
3. Separate request/data packet classes on the transport side.
4. Link reset, retry/replay, corruption, and recovery abstraction.
5. UCIS/Questa coverage database extraction and merge.
6. Coverage closure reporting per regression seed and per feature.
7. Formal properties for bounded request-to-response liveness.
