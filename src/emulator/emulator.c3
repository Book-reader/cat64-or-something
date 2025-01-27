module emulator;
import common;
import logger;

import std::io;
import std::thread;

struct Memory
{
  char[] ram;
}

fn void Memory.new_init(&self, usz size)
{
  self.ram = mem::alloc_array(char, size);
}

fn void Memory.free(&self)
{
  mem::free(self.ram);
}

fn char[] Memory.get(&self, usz start, usz len)
{
  return self.ram[start:len];
}

fn void Memory.set(&self, usz start, usz len, char[] new)
{
  self.ram[start:len] = new;
}

def Register = ulong;

fn void Register.write_W8(&self, char data)
{
  *self = self.read_W8() | @as(usz, data);
}

fn void Register.write_W16(&self, ushort data)
{
  *self = self.read_W16() | @as(usz, data);
}

fn void Register.write_W32(&self, uint data)
{
  *self = self.read_W32() | @as(usz, data);
}

fn void Register.write_W64(&self, ulong data)
{
  *self = ((Register) data).read_W64();
}

fn char Register.read_W8(self)
{
  return @as(char, self & 0x00000000000000ff);
}

fn ushort Register.read_W16(self)
{
  return @as(ushort, self & 0x000000000000ffff);
}

fn uint Register.read_W32(self)
{
  return @as(uint, self & 0x00000000ffffffff);
}

fn ulong Register.read_W64(self)
{
  return self;
}

struct Cpu
{
  // The address of the current instruction in memory
  Register* inst_ptr; // a pointer to regs[9];
  Register* stack_ptr; // A pointer to regs[8];
  Register[common::NUM_REGISTERS] regs;
  bool f_zero;
  // if gt
  bool f_carry;
}

fn void Cpu.init(&self)
{
  self.inst_ptr = &self.regs[9];
  self.stack_ptr = &self.regs[8];
}

Memory mem;
Cpu cpu;

fn int main(String[] args)
{
  cpu.init();
  mem.new_init(common::MEM_SIZE);
  defer mem.free();
  Instruction test = {.real = true, .type = MOV, .width = W64, .src_type = NUM, .dst_type = REG};
  //{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .src_type = PTR,.dst_type = PTR}; // {.type = CMP, .width = W8, .src_type = REGPTR, .dst_type = NUM, .offset_kind = NONE, .real = true };
//  char[2] a;
//  set_W16(&a, (InstSize)test);
  logger::debug("test: %.4x %h 00b6: \u00b6", @as(InstSize, test), /*a*/);

  char[] prog;

  if (args.len > 1)
  {
    prog = file::load_new(args[1])!!;
  }
  else
  {
    prog = x"88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800b";
//         x"88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8c82 00 00 9483 ffffffffffffffe9 800b";
  }
  defer if (args.len > 1) free(prog);


  mem.set(0, prog.len, prog);

  if (args.len > 2)
  {
    mem.set(0xff, args[2].len, args[2]);
  }
  else
  {
    String msg = "Hello, World!\n\0";
    mem.set(0xff, msg.len, msg);
  }


  logger::debug("Executing (%s b): %h", prog.len, prog);

  bool running = true;

  // io::printfn("%.4x %.4x %.4x", @common::to_usize(W16, prog[0:2]), @common::to_usize2(W16, prog[0:2]), @common::to_usize3(W16, prog[0:2]));

  while (running)
  {
    // Fetch, Decode, Execute
    // https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
    
    // running = false;

    // Fetch & Decode the current instruction
    $echo("FIXME: " +++ $$FILE +++ ", " +++ $$FUNC);
    Instruction curr_inst = (Instruction)(mem.get(*cpu.inst_ptr, 2).as_W16());
    //logger::debug("%.8x", get_W32(mem[*cpu.inst_ptr:4]));
    logger::debug("%s: %.4x -> %s %s %s %s", *cpu.inst_ptr, @as(InstSize, curr_inst), curr_inst.type, curr_inst.width, curr_inst.type == JIF ? curr_inst.jif_cond.nameof : curr_inst.dst_type.nameof, curr_inst.src_type);

    // Big brain error checking
    if (!curr_inst.real)
    {
      logger::error("Invalid instruction: %.4x", @as(InstSize, curr_inst));
//      running = false;
//      continue;
    }


    // Point at the next byte
    *cpu.inst_ptr += 2;

    // Execute the current instruction
    switch (curr_inst.type) @jump
    {
      case MOV:
        switch (curr_inst.width) @jump
        {
          case W8:
            vm_mov(curr_inst, W8);
          case W16:
            vm_mov(curr_inst, W16);
          case W32:
            vm_mov(curr_inst, W32);
          case W64:
            vm_mov(curr_inst, W64);
        }
/*        char[] src = @read(curr_inst, src_type);
        char[] dst = @read(curr_inst, dst_type);

        dst[:src.len] = src[..];*/
        /*switch (curr_inst.dst_type)
        {
          case REG:
            switch (curr_inst.src_type)
            {
              case NUM:
                // io::printfn("setting register %d containing %x to %x", dst[0], @common::to_usize(W64, &cpu.regs[dst[0]]), @common::to_usize(curr_inst.width, src[0:curr_inst.width.size]));
                cpu.regs[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = to_numeric(curr_inst.width, src)[0:curr_inst.width.size];
              case REG:
                cpu.regs[dst] = cpu.regs[src];
              case REGPTR:
                cpu.regs[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = mem[src:curr_inst.width.size];
              default:
                logger::error("found %s", curr_inst.src_type);
            }
          case NUM:
            logger::error("Destination of MOV cannot be NUM");
          default:
            logger::error("found %s", curr_inst.dst_type);
        }*/
      case JMP:
        logger::error("JMP not implemented yet");
/*        ulong old = *cpu.inst_ptr;
        char[] new = @read({.width = W64, .src_type = curr_inst.src_type, .offset_kind = SRC, .dst_type = NUM }, dst_type);
        *cpu.inst_ptr = common::to_usize(new.len, new);
        logger::debug("JMPing from %s to %s", old, *cpu.inst_ptr);*/
        /*if (!curr_inst.jif_rel)
        {
          *cpu.inst_ptr = common::to_usize(W64, mem[*cpu.inst_ptr:BitWidth.W64.size]);
        }
        else
        {
          *cpu.inst_ptr += (isz)common::to_usize(W64, mem[*cpu.inst_ptr:BitWidth.W64.size]);
        }*/
      case PRINTC:
        logger::debug("Printing %d %c", cpu.regs[0], cpu.regs[0]);
        io::printf("%c", cpu.regs[0]);
      case PRINTINT:
        io::printfn("%d", cpu.regs[0]);
      case PRINT:
        io::printf("%s", @as(ZString, cpu.regs[0]));
      case ADD:
        logger::error("ADD not implemented yet");
        // TODO: make these return char[] that points to the correct place in memory so I can just do dst[:curr_inst.width.size] = src[:curr_inst.width.size];
/*        ulong src = @read(curr_inst, src_type);
        ulong dst = @read(curr_inst, dst_type);

        dst[:src.len] = common::to_bytes(common::to_usize(src.len, dst[:src.len]) + common::to_usize(src.len, src[..]));
*/
/*        switch (curr_inst.dst_type)
        {
          case REG:
            switch (curr_inst.src_type)
            {
              case NUM:
                //cpu.regs[]
                // TODO: this probably doesn't work
                cpu.regs[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = common::to_bytes(curr_inst.width, common::to_usize(curr_inst.width, &cpu.regs[dst]) + src)[0:curr_inst.width.size];
              case REG:
                cpu.regs[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = common::to_bytes(curr_inst.width, common::to_usize(curr_inst.width, cpu.regs[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size]) + common::to_usize(curr_inst.width, cpu.regs[src][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size]));
              default:
                logger::error("found %s", curr_inst.dst_type);
            }
          default:
            logger::error("found %s", curr_inst.dst_type);
        }*/
      case CMP:
        logger::error("CMP not implemented yet");
/*        ulong src = @read(curr_inst, src_type);
        ulong dst = @read(curr_inst, dst_type);

        logger::debug("Comparing %s and %s", src, dst);

        cpu.f_zero = src == dst;
        cpu.f_carry = src > dst;

        logger::debug("Equal: %s, src > dst: %s", cpu.f_zero, cpu.f_carry);*/

      case JIF:
        bool jmp = false;

        logger::debug("Jumping with condition %s", curr_inst.jif_cond);

        switch (curr_inst.jif_cond) @jump
        {
          case NE:
            logger::debug("NE: %s", !cpu.f_zero);
            jmp = !cpu.f_zero;
          case EQ:
            jmp = cpu.f_zero;
          case GT:
            jmp = cpu.f_carry;
          case GE:
            jmp = cpu.f_carry || cpu.f_zero;
          case LT:
            jmp = !cpu.f_carry && !cpu.f_zero;
          case LE:
            jmp = !cpu.f_carry || cpu.f_zero;
          default:
            logger::error("Condition %s not implemented", curr_inst.jif_cond);
        }
        if (jmp)
        {
          logger::debug("Condition was true");
/*          // TODO: use the actual instruction and set the width to 64 in the assembler
          ulong old = *cpu.inst_ptr;
          logger::debug("JIF: offset_kind %s", curr_inst.offset_kind);
          char[] new = @read({.width = W64, .src_type = curr_inst.src_type, .offset_kind = SRC, .dst_type = NUM }, dst_type);
          *cpu.inst_ptr = common::to_usize(new.len, new);
          logger::debug("Jumping from %s to %s", old, *cpu.inst_ptr);*/
        }
        else
        {
          logger::debug("Condition was false");
          *cpu.inst_ptr += ulong.sizeof;
        }
      case DBG:
        foreach (i, &reg : cpu.regs)
        {
          logger::info("r%s: %s", i, reg);
        }
      case EXIT:
        running = false;
      case NOP:
        break;
      default:
        logger::error("Instruction %s not implemented yet", curr_inst.type);
    }
    // TODO: set a clock speed
    thread::sleep(100);
  }



  return 0;
}

macro vm_mov(Instruction inst, BitWidth $width)
{
  @write(inst, $width, @read(inst, src_type, $width));
}

macro @write(Instruction inst, BitWidth $width, value)
{
  switch (inst.dst_type) @jump
  {
    case NUM:
      logger::error("Cannot MOV to NUM");
    case REG:
      defer *cpu.inst_ptr += 1;
      cpu.regs[mem.get(*cpu.inst_ptr, 1)[0]].$eval("write_" +++ $width.nameof)(value);
//    case REGPTR:   
    default:
      logger::error("Unimplemented: %s", inst.dst_type);
  }
}

macro @read(Instruction inst, #arg_type, BitWidth $width)
{
  switch (inst.#arg_type) @jump
  {
    case NUM:
      defer *cpu.inst_ptr += $width.size;
      return mem.get(*cpu.inst_ptr, $width.size).$eval("as_" +++ $width.nameof)();
    case REG:
      defer *cpu.inst_ptr += 1;
      return cpu.regs[mem.get(*cpu.inst_ptr, 1)[0]].$eval("read_" +++ $width.nameof)();
    case REGPTR:
      defer *cpu.inst_ptr += 1;
      return mem.get(cpu.regs[mem.get(*cpu.inst_ptr, 1)[0]], $width.size).$eval("as_" +++ $width.nameof)();
    case PTR:
      defer *cpu.inst_ptr += BitWidth.W64.size;
      return mem.get(mem.get(*cpu.inst_ptr, BitWidth.W64.size).as_W64(), $width.size).$eval("as_" +++ $width.nameof)();
//    default:
//      logger::error("Not Implemented: %s", inst.dst_type);
  }
}

/*macro ulong @read(Instruction inst, #type)
{
  ulong ptr = *cpu.inst_ptr;
  ulong out;
  switch (inst.#type)
  {
    case NUM:
      out = common::to_usize(inst.width, mem[ptr:inst.width.size]);
      *cpu.inst_ptr += inst.width.size;
    case REG:
      out = mem[ptr];
      *cpu.inst_ptr += 1;
    case REGPTR:
      out = common::to_usize(W64, &cpu.regs[mem[ptr]]);
      *cpu.inst_ptr += 1;
    default:
      logger::error("found %s", inst.#type);
  }


  $assert($stringify(#type)[3..] == "_type" && "That probably isn't good");
  OffsetKind $of;
  $switch
    $case $stringify(#type) == "src_type":
      $of = SRC;
    $case $stringify(#type) == "dst_type":
      $of = DST;
    $default:
      $error("Whoopsy: " +++ $stringify(#type));
  $endswitch
//  logger::debug("maybe Jumping relativly by %s to %s or to %s", @as(isz, out), @as(isz, ptr) + @as(isz, out), out);
//  logger::debug("Offset Kind: %s, type: %s", inst.offset_kind, $stringify(#type));
  if (inst.offset_kind.includes($of))
  {
//    logger::debug("was relative");
    return @as(ulong, @as(isz, ptr) + @as(isz, out));
  }
//  logger::debug("was not relative");

  return out;
}*/
/*
macro void @write(Instruction inst, #type, ulong val)
{
  ulong prt = *cpu.inst_ptr;
}*/
