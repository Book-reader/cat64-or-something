module common;

import std::io;
import std::thread;
import std::time;
import std::collections::list;
import logger;

// 16 Mib of memory
const RAM_SIZE = 0x04000000; //  64 MiB
const ROM_SIZE = 0x00080000; // 512 KiB
const ROM_START = 0xF0000000;

// const MEM_TOTAL = RAM_SIZE + ROM_SIZE;

const DEFAULT_INST_PTR = ROM_START;
const DEFAULT_STACK_PTR = 0;

// 8 General registers
const NUM_REGISTERS = 36;
const String[NUM_REGISTERS] REG_NAMES = {
	"R0 ", "R1 ", "R2 ", "R3 ", "R4 ", "R5 ", "R6 ", "R7 ",
	"R8 ", "R9 ", "R10", "R11", "R12", "R13", "R14", "R15",
	"R16", "R17", "R18", "R19", "R20", "R21", "R22", "R23",
	"R24", "R25", "R26", "R27", "R28", "R29", "R30", "R31",
	"RSP", "ESP", "RFP", "RIP"};
//const REG_SIZE = 1; // Char

const PTR_SIZE = 4; // Int
$assert usz.sizeof >= PTR_SIZE : "Must be on at least a 32 bit system";

// alias InstSize = ushort;

bitstruct Instruction (Printable) : ushort @littleendian
{
	ArgType src : 0..1;
	ArgType dst : 2..3;
	Condition cond : 4..6;
	bool has_offset : 7;
	InstructionType type : 8..13;
	BitWidth width : 14..15;
/*	BitWidth width : 0..1;
	InstructionType type : 2..7;
	bool has_offset : 8;
	Condition cond : 9..11;
	ArgType src : 12..13;
	ArgType dst : 14..15;*/
}

const INST_SIZE = 2;
$assert Instruction.sizeof == INST_SIZE;

fn usz? Instruction.to_format(&self, Formatter* formatter) @dynamic
{
	usz? n;
	String name = self.type.get_name();
	if (self.cond.ordinal >= Condition.values.len || self.src.ordinal >= ArgType.values.len || self.dst.ordinal >= ArgType.values.len || self.width.ordinal >= BitWidth.values.len || name == "INVALID")
	{
		n += formatter.printf("<INVALID>");
	}
	else
	{
		if (self.cond != ALWAYS) n += formatter.printf("%s ", self.cond);
		n += formatter.printf("%s.%s {%s->%s:%s}", self.type.get_name(), self.width, self.src, self.dst, self.has_offset);
	}
	return n;
}

// typedef Condition = char;

enum Condition : char
{
	ALWAYS,
	IFZ,
	IFNZ,
	IFC, // same as: IFLT
	IFNC, // same as: IFGTEQ
	IFGT,
	IFLTEQ,
}

enum ArgType : char
{
	REG,
	REG_PTR,
	IMM,
	IMM_PTR,
}

typedef InstructionType = char;

enum BitWidth : char (String suffix, inline ulong size, typeid type, typeid itype)
{
//  NONE = { "", 0, void.typeid },
  W8 = { ".8", 1, char.typeid, ichar.typeid },
  W16 = { ".16", 2, ushort.typeid, short.typeid },
  W32 = { ".32", 4, uint.typeid, int.typeid },
}

alias Bytes = List {char};


// enum ParseArgType ()

struct Token(Printable)
{
  TokenType type;
  String lexme;
  usz line;
  usz position;
}

fn usz? Token.to_format(&self, Formatter* formatter) @dynamic
{
  return formatter.printf("(%s:%s ('%s':%s))%s", self.line, self.position, self.lexme == "\n" ? "\\n" : self.lexme, self.type, self.type == EOEXPR ? "\n" : "");
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
  EOEXPR,
}

macro to_string($num) {
  char[] $res;
  $for ;$num != 0; $num = $num / 10:
    $res = { (char) ('0' + $num % 10) } +++ $res;
  $endfor
  return (String) $res;
}

fn bool String[].contains(&self, String pointer)
{
	return @ok(self.index_of(pointer));
}

fn usz? String[].index_of(&self, String pointer)
{
	foreach (i, val : self)
	{
		if (val == pointer) return i;
	}
	return NOT_FOUND?;
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
  $foreach $value : $values:
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


//macro char[].get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof)();
<*
 @require values::@is_int(val) && !$defined(*val)
 @require $typeof(val).typeid == $width.type ||| $typeof(val).typeid == $width.itype
*>
macro void char[].set(self, BitWidth $width, val) => self[:$width] = @as(char*, &val)[:$width];
//self.$eval("set_" +++ $width.nameof)(val);

macro char[].get(self, BitWidth $width)
{
  $switch $width:
    $case W8:
      return self[0];
	$case W16:
		return bitorder::read(self, UShortLE);
	$case W32:
		return bitorder::read(self, UIntLE);
/*    $default:
      
      char[] data = {0, 0, 0, 0, 0, 0, 0, 0};
      //$for (var $i = 0; $i < $width; $i++)
      // data[$i] = self[$i];
      //$endfor
      data[:$width] = self[:$width];
      logger::debug("reading value %s from %s", @as($typefrom($width.itype), *@as($typefrom($width.type)*, @as(char*, data))), data);
      return *@as($typefrom($width.type)*, @as(char*, data));// *(@as($typefrom($width.type)*, @as(char*, self[:$width]));
//    $case W32:
//      return
*/
  $endswitch
}

/*// TODO: replace all these methods with `$switch` in `char[].as($width)`
fn char char[].as_W8(self) => self[0];

fn ushort char[].as_W16(self) => *@as(ushort*, @as(char*, self[0:2]));

fn uint char[].as_W32(self) => *@as(uint*, @as(char*, self[0:4]));

fn ulong char[].as_W64(self) => *@as(ulong*, @as(char*, self[0:8]));
*/

module common;// @if(!env::X86_64);

/*
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

/*fn void char[].set_W64(self, ulong val)
{
  self[0] = @as(char, val);
  self[1] = @as(char, val >> 8);
  self[2] = @as(char, val >> 16);
  self[3] = @as(char, val >> 24);
  self[4] = @as(char, val >> 32);
  self[5] = @as(char, val >> 40);
  self[6] = @as(char, val >> 48);
  self[7] = @as(char, val >> 56);
}*/
fn void char[].set_W64(self, ulong val)
{
	self[:BitWidth.W64] = @as(char*, &val)[:BitWidth.W64];
}*/

module common @if(false);// @if(env::X86_64);


/*
fn char char[].get

// TODO: Test which is faster:
fn ulong char[].get_W64(char[] self) @naked @noinline
{
	char* s = self;
	asm
	{
		movq $rax, [s];
		ret;
	}
	unreachable();
}

fn ulong char[].get_W64(char[] self) @naked @inline
{
	char* s = self;
	ulong ret;
	asm
	{
		movq ret, [s];
		ret;
	}
	return ret;
}*/

fn void char[].set_W64(self, ulong val)
{
	char* s = self;
	asm
	{
		movq [s], val;
	}
}

// module common::cond;

// const ALWAYS = 0b000;
// const IFZ = 

module common::inst;
import logger;

const InstructionType NOP   = 0x00;
const InstructionType ADD   = 0x01;
const InstructionType MUL   = 0x02;
const InstructionType AND   = 0x03;
const InstructionType SLA   = 0x04;
const InstructionType SRA   = 0x05;
const InstructionType BSE   = 0x06;
const InstructionType CMP   = 0x07;
const InstructionType JMP   = 0x08;
const InstructionType RJMP  = 0x09;
const InstructionType PUSH  = 0x0A;
const InstructionType IN    = 0x0B;
const InstructionType ISE   = 0x0C;
const InstructionType MSE   = 0x0D;
const InstructionType HALT  = 0x10;
const InstructionType INC   = 0x11;
const InstructionType OR    = 0x13;
const InstructionType IMUL  = 0x14;
const InstructionType SRL   = 0x15;
const InstructionType BCL   = 0x16;
const InstructionType MOV   = 0x17;
const InstructionType CALL  = 0x18;
const InstructionType RCALL = 0x19;
const InstructionType POP   = 0x1A;
const InstructionType OUT   = 0x1B;
const InstructionType ICL   = 0x1C;
const InstructionType MCL   = 0x1D;
const InstructionType BRK   = 0x20;
const InstructionType SUB   = 0x21;
const InstructionType DIV   = 0x22;
const InstructionType XOR   = 0x23;
const InstructionType ROL   = 0x24;
const InstructionType ROR   = 0x25;
const InstructionType BTS   = 0x26;
const InstructionType MOVZ  = 0x27;
const InstructionType LOOP  = 0x28;
const InstructionType RLOOP = 0x29;
const InstructionType RET   = 0x2A;
const InstructionType INT   = 0x2C;
const InstructionType TLB   = 0x2D;
const InstructionType DEC   = 0x31;
const InstructionType REM   = 0x32;
const InstructionType NOT   = 0x33;
const InstructionType IDIV  = 0x34;
const InstructionType IREM  = 0x35;
const InstructionType ICMP  = 0x37;
const InstructionType RTA   = 0x39;
const InstructionType RETI  = 0x3A;
const InstructionType FLP   = 0x3D;

// it is impossible for these to be valid instructions as the instruction only has 6 bits to be stored in the instruction
const InstructionType GET  = 0xFF;
const InstructionType GET_ = 0xFE;
const InstructionType BREAK = 0xFD;

macro InstructionType.arg_count($self) @const
{
	$switch $self:
		$case NOP:
		$case ISE:
		$case MSE:
		$case HALT:
		$case ICL:
		$case MCL:
		$case BRK:
		$case RET:
		$case RETI:
			return 0;
		$case ADD:
		$case MUL:
		$case AND:
		$case SLA:
		$case SRA:
		$case BSE:
		$case CMP:
		$case IN:
		$case OR:
		$case IMUL:
		$case SRL:
		$case BCL:
		$case MOV:
		$case OUT:
		$case SUB:
		$case DIV:
		$case XOR:
		$case ROL:
		$case ROR:
		$case BTS:
		$case MOVZ:
		$case REM:
		$case IDIV:
		$case IREM:
		$case ICMP:
		$case RTA:
			return 2;
		$case JMP:
		$case RJMP:
		$case PUSH:
		$case INC:
		$case CALL:
		$case RCALL:
		$case POP:
		$case LOOP:
		$case RLOOP:
		$case INT:
		$case TLB:
		$case DEC:
		$case NOT:
		$case FLP:
			return 1;
		$default:
			$error("Unknown instruction");
	$endswitch
}

// bit ops like bsl always have W8 sources because you don't need to shift the max of 32 bits by more than the 255 of W8 so allowing W16/32 would be pointless&wasteful
macro bool InstructionType.is_bit_op($self) @const
{
	$switch $self:
		$case SLA:
		$case SRA:
		$case SRL:
		$case ROR:
		$case ROL:
		$case BCL:
		$case BSE:
		$case BTS:
			return true;
		$default:
			return false;
	$endswitch
}

macro bool is_valid_instruction(InstructionType $val)
{
	$switch $val:
		$case NOP:
		$case ISE:
		$case MSE:
		$case HALT:
		$case ICL:
		$case MCL:
		$case BRK:
		$case RET:
		$case RETI:
		$case ADD:
		$case MUL:
		$case AND:
		$case SLA:
		$case SRA:
		$case BSE:
		$case CMP:
		$case IN:
		$case OR:
		$case IMUL:
		$case SRL:
		$case BCL:
		$case MOV:
		$case OUT:
		$case SUB:
		$case DIV:
		$case XOR:
		$case ROL:
		$case ROR:
		$case BTS:
		$case MOVZ:
		$case REM:
		$case IDIV:
		$case IREM:
		$case ICMP:
		$case RTA:
		$case JMP:
		$case RJMP:
		$case PUSH:
		$case INC:
		$case CALL:
		$case RCALL:
		$case POP:
		$case LOOP:
		$case RLOOP:
		$case INT:
		$case TLB:
		$case DEC:
		$case NOT:
		$case FLP:
			return true;
		$default:
			return false;
	$endswitch
}

fn usz InstructionType.arg_count_rt(self) @deprecated("pls don't use it has runtime cost :(")
{
	switch (self)
	{
		case NOP:
		case ISE:
		case MSE:
		case HALT:
		case ICL:
		case MCL:
		case BRK:
		case RET:
		case RETI:
			return 0;
		case ADD:
		case MUL:
		case AND:
		case SLA:
		case SRA:
		case BSE:
		case CMP:
		case IN:
		case OR:
		case IMUL:
		case SRL:
		case BCL:
		case MOV:
		case OUT:
		case SUB:
		case DIV:
		case XOR:
		case ROL:
		case ROR:
		case BTS:
		case MOVZ:
		case REM:
		case IDIV:
		case IREM:
		case ICMP:
		case RTA:
			return 2;
		case JMP:
		case RJMP:
		case PUSH:
		case INC:
		case CALL:
		case RCALL:
		case POP:
		case LOOP:
		case RLOOP:
		case INT:
		case TLB:
		case DEC:
		case NOT:
		case FLP:
			return 1;
		default:
			abort("Unknown instruction: 0x%.4x", self);
	}
}

fn String InstructionType.get_name(self)
{
	switch (self)
	{
		case NOP:
			return "NOP";
		case ADD:
			return "ADD";
		case MUL:
			return "MUL";
		case AND:
			return "AND";
		case SLA:
			return "SLA";
		case SRA:
			return "SRA";
		case BSE:
			return "BSE";
		case CMP:
			return "CMP";
		case JMP:
			return "JMP";
		case RJMP:
			return "RJMP";
		case PUSH:
			return "PUSH";
		case IN:
			return "IN";
		case ISE:
			return "ISE";
		case MSE:
			return "MSE";
		case HALT:
			return "HALT";
		case INC:
			return "INC";
		case OR:
			return "OR";
		case IMUL:
			return "IMUL";
		case SRL:
			return "SRL";
		case BCL:
			return "BCL";
		case MOV:
			return "MOV";
		case CALL:
			return "CALL";
		case RCALL:
			return "RCALL";
		case POP:
			return "POP";
		case OUT:
			return "OUT";
		case ICL:
			return "ICL";
		case MCL:
			return "MCL";
		case BRK:
			return "BRK";
		case SUB:
			return "SUB";
		case DIV:
			return "DIV";
		case XOR:
			return "XOR";
		case ROL:
			return "ROL";
		case ROR:
			return "ROR";
		case BTS:
			return "BTS";
		case MOVZ:
			return "MOVZ";
		case LOOP:
			return "LOOP";
		case RLOOP:
			return "RLOOP";
		case RET:
			return "RET";
		case INT:
			return "INT";
		case TLB:
			return "TLB";
		case DEC:
			return "DEC";
		case REM:
			return "REM";
		case NOT:
			return "NOT";
		case IDIV:
			return "IDIV";
		case IREM:
			return "IREM";
		case ICMP:
			return "ICMP";
		case RTA:
			return "RTA";
		case RETI:
			return "RETI";
		case FLP:
			return "FLP";
		default:
			// logger::warn("unknown or unsupported InstructionType %s", self);
			return "INVALID";
	}
}
