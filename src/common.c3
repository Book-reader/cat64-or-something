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

enum InstructionType : char (String name, bool sized, usz args_len)
{
    // Do nothing
    NOP = { "nop", false, 0 },
    // move PC memory address
    JMP = { "jmp", false, 1 },
    CMP = { "cmp", true, 2 },
    JIF = { "jif", false, 1 },
    ADD = { "add", true, 2 },
    SUB = { "sub", true, 2 },
    // Both of these will cease to exist once I create a stdout device
    PRINTC = { "printc", true, 1 },
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

fn USize to_usize(BitWidth src_width, char[] src)
{
    switch (src_width)
    {
        case W8:
            return src[0];
        case W16:
            return *(USize*)(char*)char[]{src[1], src[0], 0, 0, 0, 0, 0, 0};
        case W32:
            return *(USize*)(char*)char[]{src[3], src[2], src[1], src[0], 0, 0, 0, 0};
        case W64:
            return *(USize*)(char*)char[]{src[7], src[6], src[5], src[4], src[3], src[2], src[1], src[0]};

    }
}

fn char[] to_bytes(BitWidth dst_width, USize data)
{
    char* src = (char*)&data;
    switch (dst_width)
    {
        case W8:
            return {src[0]};
        case W16:
           return {src[1], src[0]};
        case W32:
           return {src[3], src[2], src[1], src[0]};
        case W64:
            return {src[7], src[6], src[5], src[4], src[3], src[2], src[1], src[0]};
    }
}

macro void error(String format, ...)
{
    $if (env::COMPILER_SAFE_MODE):
        unreachable(format, $vasplat);
    $else
        io::eprintf("ERROR: %s:%s ", $$FILE, $$LINE);
        io::eprintfn(format, $vasplat);
        libc::exit(1);
        unreachable();
    $endif
}
