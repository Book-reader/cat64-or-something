module common;

import std::io;
import std::thread;
import std::time;

// 16 Mib of memory
const MEM_SIZE = 0x02000000_0;

// 8 General registers
const NUM_REGISTERS = 12;
const String[NUM_REGISTERS] REG_NAMES = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "rsp", "esp", "scl", "scr"};


$assert(usz.sizeof == 8 && "Must be 64 bit");

def InstSize = ushort;

// const PTR_SIZE = 6; // 6 bytes = 281474976710655 or 256TiB of addresable memory

const OFFSET_SIZE = 6; // allows an address offset of 281474976710655. may be less with negatives

bitstruct Instruction : InstSize @overlap
{
  // There can be a max of 31 instructions, 32 including 0
  InstructionType type : 0..4;
  BitWidth width : 5..6;
  // 
  Condition jif_cond : 7..8;
  OpType src_type : 7..9;
  OpType dst_type : 10..12;

  bool src_type_rel : 13;
  bool dst_type_rel : 14;
  
  bool real : 15;
}

enum InstructionType : char (String name, bool sized, char args)
{
  // Do nothing
  NOP = { "nop", false, 0 },
  // move PC memory address
  JMP = { "jmp", false, 1 },
  CMP = { "cmp", true, 2 }, // TODO: ICMP for signed comparison, possibly using flag so IADD/ISUB/IMUL/IDIV can also be added. this would likely require reducing the bits available to `type`
  JIF = { "jif", false, 2 }, // Only takes 1 agument in the vm, as the first argument is embedded in the instruction
  ADD = { "add", true, 2 },
  SUB = { "sub", true, 2 },
  CALL = { "call", false, 0 },
  RET = { "ret", false, 0 }, // this might be a pseudo instruction

  EXIT = { "exit", false, 0 },

  // Both of these will cease to exist once I create a stdout device
  PRINT = { "print", false, 1 },
  PRINTC = { "printc", true, 0 },
  PRINTINT = { "printint", true, 0},

  MOV = { "mov", true, 2 },
  // Temp instruction that exits the emulator

  AND = { "and", true, 2 },
  NOT = { "not", true, 1 },
  OR = { "or", true, 2 },
  XOR = { "xor", true, 2 },
  PUSH = { "push", true, 1 },
  POP = { "pop", true, 1 },
  DBG = { "dbg", false, 0},
  SYSCALL = { "syscall", false, 1 },

  ICMP = { "icmp", true, 2 },
  IADD = { "iadd", true, 2 },
  ISUB = { "isub", true, 2 },
  MUL = { "mul", true, 2 },
  DIV = { "div", true, 2 },
  IMUL = { "imul", true, 2 },
  IDIV = { "idiv", true, 2 },
}

enum BitWidth : char (char size, usz bit_size, String name, typeid type)
{
  W8 = { 1, 8, "8", char.typeid },
  W16 = { 2, 16, "16", ushort.typeid },
  W32 = { 4, 32, "32", uint.typeid },
  W64 = { 8, 64, "64", ulong.typeid },
}

enum OpType : char
{
  PTR,
  NUM,
  REG,
  REGPTR,
}


enum Condition : char
{
  EQ,
  NE,
  GT,
  GE,
  LT,
  LE,
}

/*fn ulong char[].as_W64(self)
{
  char* data = self;
  ulong new;
  asm
  {
    movq [data], new;
  };
  return new;
}*/

macro char[].get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof)();

// TODO: replace all these methods with `$switch` in `char[].as($width)`
fn char char[].as_W8(self) => self[0];

fn ushort char[].as_W16(self) => *@as(ushort*, @as(char*, char[]{self[1], self[0]}));

fn uint char[].as_W32(self) => *@as(uint*, @as(char*, char[]{self[3], self[2], self[1], self[0]}));

fn ulong char[].as_W64(self) => *@as(ulong*, @as(char*, char[]{self[7], self[6], 
                                 self[5], self[4], self[3], self[2], self[1], self[0]}));

macro void char[].set(self, BitWidth $width, val) => self.$eval("set_" +++ $width.nameof)(val);

fn void char[].set_W8(self, char val) => self[0] = val;

fn void char[].set_W16(self, ushort val)
{
  self[1] = @as(char, val);
  self[0] = @as(char, val >> 8);
}
fn void char[].set_W32(self, uint val)
{
  self[3] = @as(char, val);
  self[2] = @as(char, val >> 8);
  self[1] = @as(char, val >> 16);
  self[0] = @as(char, val >> 24);
}
fn void char[].set_W64(self, ulong val)
{
  self[7] = @as(char, val);
  self[6] = @as(char, val >> 8);
  self[5] = @as(char, val >> 16);
  self[4] = @as(char, val >> 24);
  self[3] = @as(char, val >> 32);
  self[2] = @as(char, val >> 40);
  self[1] = @as(char, val >> 48);
  self[0] = @as(char, val >> 56);
}

// We have zig at home:
macro @as($Type, #expr) @builtin => ($Type)(#expr);

macro @eachif(value, $Enum = void, #attribute = null; @body($matching_value)) @builtin
{
  $if $Enum.typeid == void.typeid:
    $Enum = $typeof(value);
  $endif

  return @eachif_arr(value, $Enum.values, #attribute, false; $match)
  {
    @body($match);
  };

}

macro @eachif_arr(value, $values, #attribute = null, $failable = true; @body($matching_value)) @builtin
{
  $foreach ($value : $values)
    var $val_at;
    $if $stringify(#attribute) == "null":
      $val_at = $value;
    $else
      $val_at = $value.#attribute;
    $endif
//    logger::debug("comparing c:%s to r:%s", $val_at, value);
    if ($val_at == value)
    {
//      logger::debug("c:%s and r:%s match", $val_at, value);
      @body($value);
      return;
    }
  $endforeach


  $if $stringify(#attribute) == "null" ||| $failable:
    unreachable();
  $else
    return SearchResult.MISSING?;
  $endif
}

/*usz current_bench_depth = 0;
macro @profile(String name; @body()) @builtin
{
  $if $feature(BENCH):
    current_bench_depth += 1;
    Clock clock = clock::now();
    defer
    {
      NanoDuration nano_seconds = clock.mark();
      io::eprint("[BENCH] ");
      for (usz i = 0; i < current_bench_depth - 1; i++) io::eprint("-");
      io::eprintfn("> %s took %s", name, nano_seconds);
      current_bench_depth -= 1;
   }
    $endif
  @body();
}
*/

