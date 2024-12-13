module emulator;
import std::io;

// 16 Mib of memory
const MEM_SIZE = 0x02000000;

// 8 General registers
const NUM_REGISTERS = 8;

// 64 bit
def USize = ulong;

struct Cpu
{
    // The address of the current instruction in memory
    USize inst_ptr;
    char[NUM_REGISTERS][USize.sizeof] registers;
}

def InstSize = ushort;

bitstruct Instruction : InstSize
{
    // There can be a max of 63 instructions, 64 including 0
    InstructionType type : 0..5;
    BitWidth width : 6..7;
    OpType src_type : 8..9;
    OpType dst_type : 10..11;
    Condition cond : 12..14;
}

enum InstructionType : char
{
    // Do nothing
    NOP,
    // move PC memory address
    JMP,
    JZ,
    INC,
    DEC,
    // Both of these will cease to exist once I create a stdout device
    PRINTC,
    PRINT,
    //
    MOV,
    RET,
    // Temp instruction that exits the emulator
    EXIT,
}

enum BitWidth : char (char size, String type)
{
    W8 = { 1, "char" },
    W16 = { 2, "ushort" },
    W32 = { 4, "uint" },
    W64 = { 8, "USize" },
}

enum OpType : char
{
   PTR,
   NUM,
   REG,
   REGPTR,
}

enum Condition
{
   NONE,
   IFEQ,
   IFNEQ,
   IFGT,
   IFGTEQ,
   IFLT,
   IFLTEQ,
}

struct Value
{
    ValueType type;
    ValueAs as;
//    char[] data;
}

union ValueAs
{
    char w8;
    ushort w16;
    uint w32;
    USize w64;
    char reg;
    void* ptr;
}

enum ValueType : char
{
    W8,
    W16,
    W32,
    W64,
    REG,
    PTR,
}

macro @over_types(; @body())
{
    
}

fn void* Value.get(&self)
{
    $foreach ($i, $type: ValueType.values)
        if (self.type == $type)
        {
            return &self.as.$eval(ValueAs.membersof[$i].nameof);
        }
    $endforeach
    error("Unreachable");
}

fn void Value.set(&self, Value val)
{
    switch (self.type)
    {
        case REG:
            //cpu.registers[self.as.reg] = *val.get();
        default:
    }
}

char[MEM_SIZE] mem_real; //@align(4);
char* mem = &mem_real;
Cpu cpu;

fn int main(String[] args)
{

    
    Instruction test = {.type = JMP, .width = W8, .src_type = REG, .dst_type = REG};

    io::printfn("test: %.4x 00b6: \u00b6", (InstSize)test); 


    // Theoretically moves 'a' (61) to register 0, 0906 = Instruction {.type = MOV, .width = W8, .src_type = NUM, .dst_type = REG}, 61 = 'a', 00 = eax / r0
    // Then prints it with 0005
    char[*] prog = x"0907 48 00 0005 0907 49 00 0005 0947 00b6 01 0a47 01 00 0005 0907 0A 01 0a07 01 02 0a07 02 00 0005 0a01 0000000000000000 0009";
    mem[0:prog.len] = prog;

    mem[0xff:5] = "hello\x00";

    // io::printfn("%.4x == %.4x == %.2x%.2x: %s", to_usize(W16, mem[0..1]), @to_size(W16, mem[0..1]), mem[0], mem[1], to_usize(W16, mem[0..1]) == @to_size(W16, mem[0..1]));

    io::print("Executing: ");
    foreach (c : prog)
    {
        io::printf("%.2x", c);
    }
    io::printn();

    bool running = true;

    DString inst_buf;
    inst_buf.new_init();
    defer inst_buf.free();

    io::printn("Output: ");

    while (running)
    {
        // Fetch, Decode, Execute
        // https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
        
        // running = false;

        // Fetch & Decode the current instruction
        Instruction curr_inst = (Instruction)(InstSize)((mem[cpu.inst_ptr] << 8) + mem[cpu.inst_ptr + 1]);

        inst_buf.appendf("%.4x -> %s %s %s %s\n", (InstSize)curr_inst, curr_inst.type, curr_inst.width, curr_inst.dst_type, curr_inst.src_type);
        $if ($feature(DEBUG)):
            if (curr_inst.type != NOP)
            {
                io::printfn("%.4x %s %s %s %s", (InstSize)curr_inst, curr_inst.type, curr_inst.width, curr_inst.dst_type, curr_inst.src_type);
            }
        $endif

        // Point at the next byte
        cpu.inst_ptr += 2;


        // Execute the current instruction
        switch (curr_inst.type)
        {
            case MOV:
                char[] src;
                char[] dst;
                switch (curr_inst.src_type)
                {
                    case NUM:
                        src = mem[cpu.inst_ptr:curr_inst.width.size];
                        cpu.inst_ptr += curr_inst.width.size;
                    case REG:
                        src = mem[cpu.inst_ptr:1];
                        //src = (char*)
                        cpu.inst_ptr += 1;
                    default:
                        error("found %s", curr_inst.src_type);
                }

                switch (curr_inst.dst_type)
                {
                    case NUM:
                        error("DST of MOV cannot be a number");
                    case REG:
                        dst = mem[cpu.inst_ptr:1];
                        cpu.inst_ptr += 1;
                    default:
                        error("found %s", curr_inst.dst_type);
                }
                
                switch (curr_inst.dst_type)
                {
                    case REG:
                        switch (curr_inst.src_type)
                        {
                            case NUM:
                                // io::printfn("setting register %s containing %s to %s", dst[0], @to_size(W64, &cpu.registers[dst[0]]), @to_size(curr_inst.width, src[0:curr_inst.width.size]));
                                cpu.registers[dst[0]][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = src[0:curr_inst.width.size];
                            case REG:
                                cpu.registers[dst[0]] = cpu.registers[src[0]];
                            default:
                                error("found %s", curr_inst.src_type);
                        }
                    default:
                        error("found %s", curr_inst.dst_type);
                }
            case JMP:
                cpu.inst_ptr = @to_size(W64, mem[cpu.inst_ptr:BitWidth.W64.size]);
            case PRINTC:
                io::printf("%c", @to_size(W64, &cpu.registers[0]));
            case PRINT:
                io::printf("%s", (ZString)(char*)@to_size(W64, &cpu.registers[0]));
            case EXIT:
                running = false;
            case NOP:
                break;
            default:
                error("Instruction %s not implemented yet", curr_inst.type);
        }
    }

    io::printn("Produced by instructions:");
    io::printf(inst_buf.str_view());

    return 0;
}

/*fn USize to_usize(BitWidth width, char[] src)
{
    switch (width)
    {
        case W8:
            return src[0];
        case W16:
            return ((USize)src[0] << 8) + src[1];
        case W32:
            return ((USize)src[0] << 24) + ((USize)src[1] << 16) + ((USize)src[2] << 8) + src[3];
        case W64:
            return ((USize)src[0] << 56) + ((USize)src[1] << 48) + ((USize)src[2] << 40) + ((USize)src[3] << 32) + ((USize)src[4] << 24) + ((USize)src[5] << 16) + ((USize)src[6] << 8) + src[7];
        default:
            error("%s not implimented", width);
    }
}*/

macro void error(String format, ...)
{
    $if (env::COMPILER_SAFE_MODE):
        unreachable(format, $vasplat);
    $else
        io::eprintf("ERROR: %s:%s ", $$FILE, $$LINE);
        io::eprintfn(format, $vasplat);
        unreachable();
    $endif
}

macro @to_size(BitWidth width, char[] src)
{
    $foreach ($width : BitWidth.values)
        if (width == $width)
        {
            var $Type = $evaltype($width.type);
            $Type val = src[$width.size - 1];
            $for (var $i = 0; $i < $width.size - 1; $i++)
                val += (($Type)src[$i] << (($width.size - $i - 1) * 8));
            $endfor

            return val;
        }
    $endforeach
    error("Unreachable");
}
