module common;

import std::io;
import std::thread;
import std::time;
import std::collections::list;

// 16 Mib of memory
const MEM_SIZE = 0x02000000_0;

// 8 General registers
const NUM_REGISTERS = 12;
const String[NUM_REGISTERS] REG_NAMES = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "rsp", "esp", "scl", "scr"};
const REG_SIZE = 1; // Char
const PTR_SIZE = 8; // Long
const OFF_SIZE = 2; // Short

$assert(ulong.sizeof == 8 && "Must be on a 64 bit system");

def InstSize = ushort;

// https://projectf.io/posts/riscv-cheat-sheet/
enum InstructionType : char (String name, InstructionArgs args)
{ // ARG1 ARG2 (SRC, DST)
  NOP = { "NOP", args() },

  ADD = { "ADD", args(REG, REG) },
  IADD = { "IADD", args(REG, REG) },
  ADDI = { "ADDi", args(REG, IMM) },
  IADDI = { "IADDi", args(REG, IMM) },

  SUB = { "SUB", args(REG, REG) },
  ISUB = { "ISUB", args(REG, REG) },
  SUBI = { "SUBi", args(REG, IMM) },
  ISUBI = { "ISUBi", args(REG, IMM) },

  MUL = { "MUL", args(REG, REG) },
  IMUL = { "IMUL", args(REG, REG) },
  MULI = { "MULi", args(REG, IMM) },
  IMULI = { "IMULi", args(REG, IMM) },

  DIV = { "DIV", args(REG, REG) },
  IDIV = { "IDIV", args(REG, REG) },
  DIVI = { "DIVi", args(REG, IMM) },
  IDIVI = { "IDIVi", args(REG, IMM) },

  JMP = { "JMP", args(IMM) },
  JMPI = { "JMPi", args(REG) },
  AJMP = { "AJMP", args(IMM) },
  AJMPI = { "AJMPi", args(REG) },

  JEQ = { "JEQ", args(IMM) },
  JNE = { "JNE", args(IMM) },
  JGT = { "JGT", args(IMM) },
  JGE = { "JGE", args(IMM) },
  JLT = { "JLT", args(IMM) },
  JLE = { "JLE", args(IMM) },
  

  CMP = { "CMP", args(REG, REG) },
  ICMP = { "ICMP", args(REG, REG) },
  CMPI = { "CMPi", args(REG, IMM) },
  ICMPI = { "ICMPi", args(REG, IMM) },

  XOR = { "XOR", args(REG, REG) },
  XORI = { "XORi", args(IMM, REG) },

  AND = { "AND", args(REG, REG) },
  ANDI = { "ANDi", args(REG, IMM) },

  OR = { "OR", args(REG, REG) },
  ORI = { "ORi", args(IMM, REG) },

  NOT = { "NOT", args(REG, REG) },
  NOTI = { "NOTi", args(IMM, REG) },

  SLL = { "SLL", args(REG, REG) },
  SLLI = { "SLLi", args(REG, IMM) },

  SRL = { "SRL", args(REG, REG) },
  SRLI = { "SRLi", args(REG, IMM) },

  SRA = { "SRA", args(REG, REG) },
  SRAI = { "SRAi", args(REG, IMM) },

  PUSH = { "PUSH", args(REG) },
  PUSHI = { "PUSHi", args(IMM) },

  POP = { "POP", args(REG, REG) },
  POPI = { "POPi", args(REG, IMM) },

  CALL = { "CALL", args(IMM) },

  LD = { "LD", args(REG, REG) },
  LDI = { "LDi", args(REG, IMM) },

  SD = { "SD", args(REG, REG) },
  SDI = { "SDi", args(REG, IMM) },

  RET = { "RET", args() },

  SYSCALL = { "SYSCALL", args() },

  EXIT = { "EXIT", args() },

  DBG = { "DBG", args() },

  PRINT = { "PRINT", args(REG) },
  PRINTI = { "PRINTi", args(IMM) },
}

enum BitWidth : char (String suffix, ulong size, typeid type)
{
//  NONE = { "", 0, void.typeid },
  W8 = { ".8", 1, char.typeid },
  W16 = { ".16", 2, ushort.typeid },
  W32 = { ".32" 4, uint.typeid },
  W64 = { ".64", 8, ulong.typeid },
}

enum ArgType : char
{
//  NONE,
  REG,
//  REGPTR,
  IMM,
  LABEL,
  REGOFF
}

fn bool ArgType.valid_arg(self, Expr arg)
{
  switch (self)
  {
    case REG:
      return arg.len() == 1 && arg[0].type == REGISTER;
    case IMM:
      return arg.len() == 1 && (arg[0].type == NUMBER || arg[0].type == CHAR);
    case LABEL:
      return arg.len() == 1 && arg[0].type == LABEL;
    case REGOFF:
      return arg.len() == 2 && (arg[0].type == NUMBER || arg[0].type == CHAR) && arg[1].type == REGISTER;
  }
}

const MAX_INST_ARGS = 3;

struct InstructionArgs
{
  usz count;
  ArgType[MAX_INST_ARGS] arg;
}

def Expr = List<[Token]>;
def Tokens = List<[Expr]>;

struct Token(Printable)
{
  String lexme;
  TokenType type;
}

fn usz! Token.to_format(&self, Formatter* formatter) @dynamic
{
  return formatter.printf("'%s':%s", self.lexme, self.type);
}

enum TokenType : char
{
  STRING,
  CHAR,
  NUMBER,
  INSTRUCTION,
  REGISTER,
  LABEL,
  ARG_SEP,
  LABEL_DECL,
}

// If only...
/*macro InstructionArgs args(...)
{
  InstructionArgs $new;
  $for (var $i = 0; $i < $vacount; $i ++)
    String $arg = to_string($i + 1);;
    $new.$eval("has_arg" +++ $arg) = true;
    $new.$eval("arg" +++ $arg) = $vaarg[i];
  $endfor
  return $new;
}*/

macro InstructionArgs args(...)
{
  ArgType[MAX_INST_ARGS] $args;

  $for (var $i = 0; $i < $vacount; $i ++)
    $args[$i] = $vaconst[$i];
  $endfor

  return {$vacount, $args};
/*  $switch ($vacount)
    $case 0:
      return {};
    $case 1:
      return {1, {$vaconst[0], {}, {}}};
    $case 2:
      return {2, {$vaconst[0], $vaconst[1], {}}};
    $case 3:
      return {3, {$vaconst[0], $vaconst[1], $vaconst[2]}};
    $default:
      $error ("Unsupported arg count: " +++ to_string($vacount));
  $endswitch*/
}

macro to_string($num) {
  char[] $res;
  $for (;$num != 0; $num = $num / 10)
    $res = { (char) ('0' + $num % 10) } +++ $res;
  $endfor
  return (String) $res;
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

//macro char[].get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof)();
macro void char[].set(self, BitWidth $width, val) => self.$eval("set_" +++ $width.nameof)(val);

module common @if(/*!*/env::X86_64);

macro char[].get(self, BitWidth $width)
{
  $switch ($width)
    $case W8:
      return self[0];
    $default:
      return *@as($typefrom($width.type)*, @as(char*, self[0:$width.size]));
//    $case W32:
//      return 
  $endswitch
}

/*// TODO: replace all these methods with `$switch` in `char[].as($width)`
fn char char[].as_W8(self) => self[0];

fn ushort char[].as_W16(self) => *@as(ushort*, @as(char*, self[0:2]));

fn uint char[].as_W32(self) => *@as(uint*, @as(char*, self[0:4]));

fn ulong char[].as_W64(self) => *@as(ulong*, @as(char*, self[0:8]));
*/
fn void char[].set_W8(self, char val) => self[0] = val;

fn void char[].set_W16(self, ushort val)
{
  self[0] = @as(char, val);
  self[1] = @as(char, val >> 8);
}
fn void char[].set_W32(self, uint val)
{
  self[0] = @as(char, val);
  self[1] = @as(char, val >> 8);
  self[2] = @as(char, val >> 16);
  self[3] = @as(char, val >> 24);
}
fn void char[].set_W64(self, ulong val)
{
  self[0] = @as(char, val);
  self[1] = @as(char, val >> 8);
  self[2] = @as(char, val >> 16);
  self[3] = @as(char, val >> 24);
  self[4] = @as(char, val >> 32);
  self[5] = @as(char, val >> 40);
  self[6] = @as(char, val >> 48);
  self[7] = @as(char, val >> 56);
}


/*module common @if(env::X86_64);

fn char char[].get
