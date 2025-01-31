module emulator @test;
import common;

// 8012 is 'dbg' (big-endian)
// 800b is 'exit' (big-endian)

// NUM to REG
fn void mov_64_num_to_reg()
{
  main({"test", x"88e9 48031785f3ad783f 02 800b"});
  usz expected = 0x48031785f3ad783f;
  assert(cpu.regs[2] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[2]);
}

fn void mov_32_num_to_reg()
{
  main({"test", x"88c9 010ff030 02 800b"});
  usz expected = 0x010ff030;
  assert(cpu.regs[2] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[2]);
}

fn void mov_16_num_to_reg()
{
  main({"test", x"88a9 010f 02 800b"});
  usz expected = 0x010f;
  assert(cpu.regs[2] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[2]);
}

fn void mov_8_num_to_reg()
{
  main({"test", x"8889 f1 02 800b"});
  usz expected = 0xf1;
  assert(cpu.regs[2] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[2]);
}

// REG to REG
fn void mov_64_reg_to_reg()
{
  main({"test", x"88e9 48031785f3ad783f 02 8969 02 00 800b"});
  usz expected = 0x48031785f3ad783f;
  assert(cpu.regs[0] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[0]);
}

fn void mov_32_reg_to_reg()
{
  main({"test", x"88c9 010ff030 02 8949 02 00 800b"});
  usz expected = 0x010ff030;
  assert(cpu.regs[0] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[0]);
}

fn void mov_16_reg_to_reg()
{
  main({"test", x"88a9 010f 02 8929 02 00 800b"});
  usz expected = 0x010f;
  assert(cpu.regs[0] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[0]);
}

fn void mov_8_reg_to_reg()
{
  main({"test", x"8889 f1 02 8909 02 00 800b"});
  usz expected = 0xf1;
  assert(cpu.regs[0] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[0]);
}

// PTR TO REG
fn void mov_64_ptr_to_reg()
{
  main({"test", x"8869 000000000000000d 04 800b 2498f105e12a0423"});
  usz expected = 0x2498f105e12a0423;
  assert(cpu.regs[4] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[4]);
}

fn void mov_32_ptr_to_reg()
{
  main({"test", x"8849 000000000000000d 04 800b 2498f105"});
  usz expected = 0x2498f105;
  assert(cpu.regs[4] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[4]);
}

fn void mov_16_ptr_to_reg()
{
  main({"test", x"8829 000000000000000d 04 800b 2498"});
  usz expected = 0x2498;
  assert(cpu.regs[4] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[4]);
}

fn void mov_8_ptr_to_reg()
{
  main({"test", x"8809 000000000000000d 04 800b 24"});
  usz expected = 0x24;
  assert(cpu.regs[4] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[4]);
}

// REGPTR TO REG
fn void mov_64_regptr_to_reg()
{
  main({"test", x"88e9 0000000000000011 02 89e9 02 05 800b f38bc34d3521f562"});
  usz expected = 0xf38bc34d3521f562;
  assert(cpu.regs[5] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[5]);
}

fn void mov_32_regptr_to_reg()
{
  main({"test", x"88e9 0000000000000011 02 89c9 02 05 800b f38bc34d"});
  usz expected = 0xf38bc34d;
  assert(cpu.regs[5] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[5]);
}

fn void mov_16_regptr_to_reg()
{
  main({"test", x"88e9 0000000000000011 02 89a9 02 05 800b f38b"});
  usz expected = 0xf38b;
  assert(cpu.regs[5] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[5]);
}

fn void mov_8_regptr_to_reg()
{
  main({"test", x"88e9 0000000000000011 02 8989 02 05 800b f3"});
  usz expected = 0xf3;
  assert(cpu.regs[5] == expected, "Expected 0x%x, got 0x%x", expected, cpu.regs[5]);
}


