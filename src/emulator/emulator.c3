module emulator;
import common;
import logger;

import std::io;
import std::thread;


struct ReadResult
{
  ulong diff;
  union
  {
    char as_W8;
    ushort as_W16;
    uint as_W32;
    ulong as_W64;
  }
}

macro ReadResult ReadResult.new(BitWidth $width, usz diff, val) @operator(construct)
{
  ReadResult new = {.diff = diff};
  new.$eval("as_" +++ $width.nameof) = val;
  return new;
}

macro ReadResult.get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof);

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

fn char[] Memory.get(&self, usz start, usz len) @inline => self.ram[start:len];

fn void Memory.set(&self, usz start, usz len, char[] new)
{
  self.ram[start:len] = new;
}

def Register = ulong;

macro Register.write(&self, $width, data)
{
  logger::debug("Writing %s (0x%x) as %s", data, data, $width);
  self.$eval("write_" +++ $width.nameof)(data);
  logger::debug("Self is now %s (0x%x)", *self, *self);
}

fn void Register.write_W8(&self, char data)
{
  @profile("Register.write_W8")
  {
    *self = (*self & ~0x00000000000000ff) | @as(usz, data);
  };
}

fn void Register.write_W16(&self, ushort data)
{
  @profile("Register.write_W16")
  {
    *self = (*self & ~0x000000000000ffff) | @as(usz, data);
  };
}

fn void Register.write_W32(&self, uint data)
{
  @profile("Register.write_W32")
  {
    *self = (*self & ~0x00000000ffffffff) | @as(usz, data);
  };
}

// Whoops, looks like this is a feature now
// I should probably remove this at some point
fn void Register.write_W64(&self, ulong data)
{
  @profile("Register.write_W64")
  {
    *self = ((Register) data).read_W64();
  };
}

macro Register.read(&self, BitWidth $width) => self.$eval("read_" +++ $width.nameof)();

fn char Register.read_W8(self)
{
@profile("Register.read_W8")
{
  return @as(char, self & 0x00000000000000ff);
};
}

fn ushort Register.read_W16(self)
{
@profile("Register.read_W16")
{
  return @as(ushort, self & 0x000000000000ffff);
};
}

fn uint Register.read_W32(self)
{
@profile("Register.read_W32")
{
  return @as(uint, self & 0x00000000ffffffff);
};
}

fn ulong Register.read_W64(self)
{@profile("Register.read_W64")
{
  return self;
};
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
  Instruction test = {.real = true, .type = DBG};
//{.real = true, .type = JIF, .jif_cond = NE, .width = W8, .dst_type = NUM};//{.real = true, .type = JIF, .width = W8, .src_type = NUM, .dst_type = REG};
//{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .dst_type = NUM};//{.real = true, .type = MOV, .width = W64, .src_type = NUM, .dst_type = REG};
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
    prog = x"e988 ff00000000000000 01 8989 01 00 0680 e488 0100000000000000 01 8288 00 00 8384 0b00000000000000 1580 0b80";
        // x"83a4 00 0000000000000000";//" 88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800b";
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

  $if $feature(PERF):
    usz iteration = 0;
    Clock clock = clock::now();
  $endif

  while (running) @profile("main loop")
  {
    $if $feature(PERF):
      if (iteration == 1000000000 - 1) running = false; if (iteration % 5000000 == 0)io::printfn("CPU Cycle: %s", iteration);
    $endif
    // Fetch, Decode, Execute
    // https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
    Instruction inst; 
    @profile("load inst")
    {
      inst = @as(Instruction, mem.get(*cpu.inst_ptr, 2).get(W16));
    };

    logger::debug("%s: %.4x -> %s.%s %s, %s", *cpu.inst_ptr, @as(InstSize, inst), inst.type, inst.width, inst.type == JIF ? inst.jif_cond.nameof : inst.dst_type.nameof, inst.src_type);


    // Big brain error checking
    if (!inst.real)
    {
      logger::error("Invalid instruction: %.4x", @as(InstSize, inst));
//      running = false;
//      continue;
    }

    $if $feature(PERF):
      iteration += 1;
    $endif

    // Point at the next byte
    *cpu.inst_ptr += 2;
    // Execute the current instruction
    @profile("switch")
    {
      switch (inst.type) @jump
      {
       case MOV:
         switch (inst.width) @jump
         {
           case W8:
             vm_mov(inst, W8);
           case W16:
             vm_mov(inst, W16);
           case W32:
             vm_mov(inst, W32);
           case W64:
             vm_mov(inst, W64);
         }
       case JMP:
         ulong old = *cpu.inst_ptr;
         ulong new = @read(inst, 0, dst_type, W64).get(W64);
         logger::debug("JMPing from %s to %s", old, new);
         *cpu.inst_ptr = new;
       case PRINTC:
         logger::debug("Printing %d %c", cpu.regs[0], cpu.regs[0]);
         logger::debug("mem at reg 1: %d %c", mem.get(cpu.regs[1], 1)[0], mem.get(cpu.regs[1], 1)[0]);
         io::printf("%c", cpu.regs[0]);
       case PRINTINT:
         io::printfn("%d", cpu.regs[0]);
       case PRINT:
         io::printf("%s", @as(ZString, cpu.regs[0]));
       case ADD:
         switch (inst.width) @jump
         {
           case W8:
             vm_add(inst, W8);
            case W16:
              vm_add(inst, W16);
            case W32:
              vm_add(inst, W32);
            case W64:
              vm_add(inst, W64);
          }

        case CMP:
          switch (inst.width) @jump
          {
            case W8:
              vm_cmp(inst, W8);
            case W16:
              vm_cmp(inst, W16);
            case W32:
              vm_cmp(inst, W32);
            case W64:
              vm_cmp(inst, W64);
          }

        case JIF:
          bool jmp = false;

          logger::debug("Jumping with condition %s", inst.jif_cond);

          switch (inst.jif_cond) @jump
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
//            default:
//              logger::error("Condition %s not implemented", inst.jif_cond);
          }
          if (jmp)
          {
            logger::debug("Condition was true");
            // TODO: use the actual instruction and set the width to 64 in the assembler
            ulong old = *cpu.inst_ptr;
            logger::debug("JIF: offset_kind %s", inst.offset_kind);
            ulong new = @read(inst, 0, dst_type, W64).get(W64);
            logger::debug("Jumping from %s to %s", old, new);
            *cpu.inst_ptr = new;
          }
          else
          {
            logger::debug("Condition was false");
            *cpu.inst_ptr += ulong.sizeof;
          }
        case DBG:
          foreach (i, reg : cpu.regs)
          {
            logger::info("%s: %.16x", common::REG_NAMES[i], reg);
          }
        case EXIT:
          running = false;
        case NOP:
          break;
        default:
          logger::error("Instruction %s not implemented yet", inst.type);
      }
    };
    // TODO: set a clock speed
    $if $feature(DELAY):
      thread::sleep(1000000);
    $endif
  };
  $if $feature(PERF):
    NanoDuration nano_seconds = clock.mark(); 
    io::printfn("Took %s or %s ns to do %s iterations, hz/ns", nano_seconds, ((long)nano_seconds/(double)1000000000), iteration);
  $endif

  return 0;
}

macro vm_mov(Instruction inst, BitWidth $width)
{
  ReadResult out = @read(inst, 0, src_type, $width);
  *cpu.inst_ptr += out.diff;
  logger::debug("MOVing %s (0x%x)", out.get($width), out.get($width));
  *cpu.inst_ptr += @write(inst, $width, out.get($width));
}

macro vm_add(Instruction inst, BitWidth $width)
{
  ReadResult src = @read(inst, 0, src_type, $width);
  ReadResult dst = @read(inst, src.diff, dst_type, $width);
  logger::debug("adding %s to %s", src.get($width), dst.get($width));

  (void)@write(inst, $width, @as($typefrom($width.type), dst.get($width) + src.get($width)));
  *cpu.inst_ptr += src.diff + dst.diff;

  logger::debug("inst_ptr after write %s", *cpu.inst_ptr);

  logger::debug("src: %x, dst: %x", src.get($width), dst.get($width));
  
}

macro vm_cmp(Instruction inst, BitWidth $width)
{
  ReadResult src = @read(inst, 0, src_type, $width);
  ReadResult dst = @read(inst, src.diff, dst_type, $width);
  *cpu.inst_ptr += src.diff + dst.diff;


  logger::debug("Comparing %s and %s", src.get($width), dst.get($width));

  cpu.f_zero = src.get($width) == dst.get($width);
  cpu.f_carry = src.get($width) > dst.get($width);

  logger::debug("Equal: %s, src > dst: %s", cpu.f_zero, cpu.f_carry);

}

macro usz @write(Instruction inst, BitWidth $width, value) @nodiscard
{
  logger::debug("Writing %s (0x%x)", value, value);
  switch (inst.dst_type) @jump
  {
    case NUM:
      logger::error("Cannot MOV to NUM");
    case REG:
      logger::debug("to REG %s (%s) ", common::REG_NAMES[mem.get(*cpu.inst_ptr, 1).get(W8)], mem.get(*cpu.inst_ptr, 1).get(W8));
      cpu.regs[mem.get(*cpu.inst_ptr, 1).get(W8)].write($width, value);
      return 1;
//    case REGPTR:
    default:
      logger::error("Unimplemented: %s", inst.dst_type);
  }
}

macro ReadResult @read(Instruction inst, ulong offset, #arg_type, BitWidth $width)
{
  logger::debug("@read: %s", inst.#arg_type);
  logger::debug("mem at inst_ptr: %h %s", mem.get(*cpu.inst_ptr, 10), mem.get(*cpu.inst_ptr, 10));
  ulong addr =  *cpu.inst_ptr + offset;
  switch (inst.#arg_type) @jump
  {
    case NUM:
//      logger::debug("NUM: nearby memory: %s, number: %x", mem.get(addr, 10), mem.get(addr, $width.size).get($width));
      return ReadResult.new($width, $width.size, mem.get(addr, $width.size).get($width));
    case REG:
      logger::debug("REG contains %.16x", cpu.regs[mem.get(addr, 1).as_W8()]);
      return ReadResult.new($width, 1, cpu.regs[mem.get(addr, 1).as_W8()].read($width));
    case REGPTR:
      return ReadResult.new($width, 1, mem.get(cpu.regs[mem.get(addr, 1).as_W8()], $width.size).get($width));
    case PTR:
      return ReadResult.new($width, BitWidth.W64.size, mem.get(mem.get(addr, BitWidth.W64.size).as_W64(), $width.size).get($width));
//    default:
//      logger::error("Not Implemented: %s", inst.dst_type);
  }
}
