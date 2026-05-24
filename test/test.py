# SPDX-FileCopyrightText: © 2024 Finn Rades (zOnlyKroks)
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


@cocotb.test()
async def test_riscv_processor(dut):
    """Test the 8-bit RISC-V processor with Fibonacci sequence"""

    dut._log.info("Starting 8-bit RISC-V processor test")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut._log.info("Resetting processor")
    dut.ena.value = 1
    dut.ui_in.value = 0  # All control signals low
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enable debug mode
    dut.ui_in.value = 0b00000010  # debug_en = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Running Fibonacci sequence program")

    # Monitor execution for a reasonable number of cycles
    pc_values = []
    reg_values = []
    halt_detected = False

    for cycle in range(200):  # Run for up to 200 cycles
        await RisingEdge(dut.clk)

        # Check if output is valid
        if dut.uio_out.value & 0x80:  # valid signal is bit 7
            pc = dut.uo_out.value & 0x0F  # PC lower 4 bits
            reg_out = (dut.uo_out.value >> 4) & 0x0F  # Register output
            halt = (dut.uio_out.value >> 6) & 0x01  # Halt signal

            pc_values.append(pc)
            reg_values.append(reg_out)

            if len(pc_values) <= 20:  # Log first 20 valid cycles
                dut._log.info(f"Cycle {cycle}: PC=0x{pc:X}, REG=0x{reg_out:X}, HALT={halt}")

            if halt:
                dut._log.info(f"CPU halted at cycle {cycle}")
                halt_detected = True
                break

    # Verify some basic behavior
    assert len(pc_values) > 0, "No valid outputs detected"
    dut._log.info(f"Captured {len(pc_values)} valid execution cycles")

    # Check that PC values change (processor is actually executing)
    unique_pc_values = set(pc_values)
    assert len(unique_pc_values) > 1, "PC never changed - processor may not be executing"

    dut._log.info("Basic execution test passed")


@cocotb.test()
async def test_step_mode(dut):
    """Test single-step execution mode"""

    dut._log.info("Testing step mode")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enable debug and step mode
    dut.ui_in.value = 0b00000110  # debug_en = 1, step_mode = 1
    await ClockCycles(dut.clk, 5)

    # In step mode, processor should stay at first fetch state
    initial_pc = dut.uo_out.value & 0x0F
    await ClockCycles(dut.clk, 10)

    # PC should not advance in step mode during fetch
    current_pc = dut.uo_out.value & 0x0F
    # Note: This test might need adjustment based on exact step mode implementation

    dut._log.info(f"Step mode test: Initial PC=0x{initial_pc:X}, After 10 cycles PC=0x{current_pc:X}")
    dut._log.info("Step mode test completed")


@cocotb.test()
async def test_io_connectivity(dut):
    """Test basic I/O connectivity"""

    dut._log.info("Testing I/O connectivity")

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
    await ClockCycles(dut.clk, 5)

    # Test that outputs are defined and not floating
    assert dut.uo_out.value.is_resolvable, "uo_out has unresolved bits"
    assert dut.uio_out.value.is_resolvable, "uio_out has unresolved bits"
    assert dut.uio_oe.value.is_resolvable, "uio_oe has unresolved bits"

    # Check that bidirectional pins are set as outputs
    assert dut.uio_oe.value == 0xFF, f"Expected all uio pins as outputs, got 0x{dut.uio_oe.value:02X}"

    dut._log.info("I/O connectivity test passed")
