# Simple test to debug I/O issues

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_simple_io(dut):
    """Simple I/O test to see exact values"""

    dut._log.info("=== Simple I/O Debug Test ===")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Print all signal values
    dut._log.info(f"uo_out = 0x{int(dut.uo_out.value):02X}")
    dut._log.info(f"uio_out = 0x{int(dut.uio_out.value):02X}")
    dut._log.info(f"uio_oe = 0x{int(dut.uio_oe.value):02X}")

    # Check each bit of uio_oe
    uio_oe_val = int(dut.uio_oe.value)
    for i in range(8):
        bit_val = (uio_oe_val >> i) & 1
        dut._log.info(f"uio_oe[{i}] = {bit_val}")

    # The test should pass if we can read the values
    dut._log.info("Simple I/O test completed successfully")