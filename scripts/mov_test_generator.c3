module mov_test_generator;
import std::io;
import std::math::random;
import c3tools::codegen;
import common;

const InstSize EXIT = @as(InstSize, Instruction{.real = true, .type = EXIT});

fn InstSize inst(Instruction inst) => (InstSize)inst;
fn InstSize inst2(InstructionType type, OpType src_type, OpType dst_type, BitWidth width) =>
   (InstSize)Instruction{.real = true, .type = type, .dst_type = dst_type, .src_type = src_type, .width = width};

fn void main()
{
  CodeGen c;
  c.new_init();
  defer c.free();

//  c.@module("emulator @test");
  $foreach ($width : BitWidth.values)
  {
    double rnd = random::rnd();
    if (rnd < 0.5) rnd += 0.5;
    
    var $Type = $typefrom($width.type);
    $Type expected = @as($Type, rnd * $Type.max);

    usz reg = rand_in_range(0, common::REG_NAMES.len - 4);
    c.@fn("void mov_%s_num_to_reg()",  $width.nameof)
    {
      c.wn("main({\"test\", x\"%.4x %x %.2x %.4x\"})", inst2(type: MOV, src_type: NUM, dst_type: REG, width: $width), expected, reg, EXIT);
      c.wn("usz expected = 0x%x", expected);
      c.wn("assert(cpu.regs[%s] == expected, \"Expected 0x%%x, got 0x%%x\", expected, cpu.regs[%s])", reg, reg);
    };

    c.@fn("void mov_%s_reg_to_reg()", $width.nameof)
    {
      c.wn("main({\"test\", x\"%.4x %x 02 %.4x 02 00 %.4x\"})", inst({.real = true, .type = MOV, .dst_type = REG, .src_type = NUM, .width = $width}), expected, inst2(type: MOV, src_type: REG, dst_type: REG, width: $width), EXIT);
      c.wn("usz expected = 0x%x", expected);
      c.wn("assert(cpu.regs[0] == expected, \"Expected 0x%%x, got 0x%%x\", expected, cpu.regs[0])");
    };

  }
  $endforeach

  io::printn(c.buf.str_view());

}
