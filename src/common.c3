module common;

// 16 Mib of memory
const MEM_SIZE = 0x02000000_0;

// 8 General registers
const NUM_REGISTERS = 8;

// 64 bit
def USize = ulong;

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
    OpType src_type : 7..8;
    OpType dst_type : 9..10;
//    Condition cond : 11..13;
    OffsetKind offset_kind : 11..12;
    
    bool real : 15;
}

enum InstructionType : char
{
    // Do nothing
    NOP,
    // move PC memory address
    JMP,
    CMP,
    JIF,
    ADD,
    SUB,
    // Both of these will cease to exist once I create a stdout device
    PRINTC,
    PRINT,
    //
    MOV,
    RET,
    // Temp instruction that exits the emulator
    EXIT,

    AND,
    NAND,
    NOT,
    OR,
    XOR,
    NOR,
    XNOR,
}

enum BitWidth : char (char size)
{
    W8 = 1,
    W16 = 2,
    W32 = 4,
    W64 = 8,
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
    NEQ,
    GT,
    GTEQ,
    LT,
    LTEQ,
}

enum OffsetKind : char
{
    NONE,
    SRC,
    DST,
    BOTH
}


