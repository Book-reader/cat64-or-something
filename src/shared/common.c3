module common;

import std::io;
import std::thread;

// 16 Mib of memory
const MEM_SIZE = 0x02000000_0;

// 8 General registers
const NUM_REGISTERS = 10;

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

//  Condition cond : 11..13;
  OffsetKind offset_kind : 12..13;
  
  bool real : 15;
}

enum InstructionType : char (String name, bool sized, char args)
{
  // Do nothing
  NOP = { "nop", false, 0 },
  // move PC memory address
  JMP = { "jmp", false, 1 },
  CMP = { "cmp", true, 2 },
  JIF = { "jif", false, 2 }, // Only takes 1 agument in the vm, as the first argument is embedded in the instruction
  ADD = { "add", true, 2 },
  SUB = { "sub", true, 2 },
  // Both of these will cease to exist once I create a stdout device
  PRINTC = { "printc", true, 0 },
  PRINTINT = {"printint", true, 0},
  PRINT = { "print", false, 1 },
  //
  MOV = { "mov", true, 2 },
  RET = { "ret", false, 0 }, // this might be a pseudo instruction
  // Temp instruction that exits the emulator
  EXIT = { "exit", false, 0 },

  AND = { "and", true, 2 },
  NAND = { "and", true, 2 },
  NOT = { "not", true, 2 },
  OR = { "or", true, 2 },
  XOR = { "xor", true, 2 },
  NOR = { "nor", true, 2 },
  XNOR = { "xnor", true, 2 },
  PUSH = { "push", true, 1 },
  POP = { "pop", true, 1 },
  DBG = { "dbg", false, 0},
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

enum OffsetKind : char
{
  NONE,
  SRC,
  DST,
  BOTH
}

fn bool OffsetKind.includes(self, OffsetKind other)
{
  if (self == NONE) return false;
  if (self == other) return true;
  if (self == BOTH) return true;
  return false;
}

/*fn USize to_usize(BitWidth src_width, char[] src) @builtin
{
  switch (src_width)
  {
    case W8:
      return src[0];
    case W16:
      return *@as(USize*, @as(char*, char[]{src[1], src[0], 0, 0, 0, 0, 0, 0}));
    case W32:
      return *@as(USize*, @as(char*, char[]{src[3], src[2], src[1], src[0], 0, 0, 0, 0}));
    case W64:
      return *@as(USize*, @as(char*, char[]{src[7], src[6], src[5], src[4], src[3], src[2], src[1], src[0]}));

  }
}*/

/*macro char[] to_bytes(BitWidth dst_width, USize data, bool $alloc = false) @builtin
{
  char* src = @as(char*, &data);
  
  $if $alloc:
    char[] dst = mem::alloc_array(char, dst_width.size);
  $else
    char[] dst;
  $endif
  switch (dst_width)
  {
    case W8:
      dst = char[]{src[0]};
    case W16:
      dst = char[]{src[1], src[0]};
    case W32:
      dst = char[]{src[3], src[2], src[1], src[0]};
    case W64:
      dst = char[]{src[7], src[6], src[5], src[4], src[3], src[2], src[1], src[0]};
  }
  return dst;
}*/

fn char char[].as_W8(self) => self[0];

fn ushort char[].as_W16(self) => @as(ushort, self[1])
                              | (@as(ushort, self[0]) << 8);

fn uint char[].as_W32(self) => @as(uint, self[3])
                            | (@as(uint, self[2]) << 8)
                            | (@as(uint, self[1]) << 16)
                            | (@as(uint, self[0]) << 24);

fn ulong char[].as_W64(self) => @as(ulong, self[7])
                             | (@as(ulong, self[6]) << 8)
                             | (@as(ulong, self[5]) << 16)
                             | (@as(ulong, self[4]) << 24)
                             | (@as(ulong, self[3]) << 32)
                             | (@as(ulong, self[2]) << 40)
                             | (@as(ulong, self[1]) << 48)
                             | (@as(ulong, self[0]) << 56);


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

macro to_numeric(BitWidth $src_width, char[] src) @builtin
{
  $switch ($src_width)
//    $case W8:
//      return 1;
    $default:
      $error("to_numeric: " +++ $src_width.nameof);
  $endswitch
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

