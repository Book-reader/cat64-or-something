module emulator;
import std::io;

// 16 Mib of memory
const MEM_SIZE = 0x01000000;

// 8 General registers
const NUM_REGISTERS = 8;

// 64 bit
def USize = ulong;

struct Cpu
{
    // The address of the current instruction in memory
    USize inst_ptr;
    USize[NUM_REGISTERS] registers;
}

def InstSize = ushort;

bitstruct Instruction : InstSize
{
    // There can be a max of 63 instructions, 64 including 0
    InstructionType type : 0..5;
    BitWidth width : 6..7;
    OpType src_type : 8..9;
    OpType dst_type : 10..11;
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
    PRINT,
    MOV,
    RET,
    // Temp instruction that exits the emulator
    EXIT,
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


char[MEM_SIZE] mem;

fn int main(String[] args)
{

    
    Instruction test = {.type = MOV, .width = W8, .src_type = NUM, .dst_type = REG};

    io::printfn("test: %.4x 00b6: \u00b6", (InstSize)test); 


    // Theoretically moves 'a' (61) to register 0, 0e06 = Instruction {.type = MOV, .width = W8, .src_type = NUM, .dst_type = REG}, 61 = 'a', 00 = eax / r0
    // Then prints it with 0005
    //char[] prog = args[1].to_int(16)!!;
    char[*] prog = x"090648000005090649000005094600b600000509060A000005";

    io::print("Executing: ");
    foreach (c : prog)
    {
        io::printf("%.2x", c);
    }
    io::printn();

    bool running = true;

    Cpu cpu;
    while (running && cpu.inst_ptr < prog.len)
    {
        // Fetch, Decode, Execute
        // https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
        
        // running = false;

        // Fetch & Decode the current instruction
        Instruction curr_inst = (Instruction)(InstSize)((prog[cpu.inst_ptr] << 8) + prog[cpu.inst_ptr + 1]);

        io::printfn("%.4x", (InstSize)curr_inst);

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
                        src = prog[cpu.inst_ptr:curr_inst.width.size];
                        cpu.inst_ptr += curr_inst.width.size;
                    case REG:
                        src = prog[cpu.inst_ptr:1];
                        cpu.inst_ptr += 1;
                    default:
                        error("found %s", curr_inst.src_type);
                }

                switch (curr_inst.dst_type)
                {
                    case NUM:
                        error("DST of MOV cannot be a number");
                    case REG:
                        dst = prog[cpu.inst_ptr:1];
                        cpu.inst_ptr += 1;
                    default:
                        error("found %s", curr_inst.dst_type);
                }
                
                switch (curr_inst.dst_type)
                {
                    case REG:
                        cpu.registers[dst[0]] = to_usize(curr_inst.width, src);
                    default:
                        error("found %s", curr_inst.dst_type);
                }
                //cpu.registers[reg_id] = src[0];
                // cpu.inst_ptr += 1 + (USize)curr_inst.width.size;
            case PRINT:
                io::printf("%c", cpu.registers[0]);
            case EXIT:
                running = false;
            default:
                error("Instruction %s not implemented yet", curr_inst.type);
        }
    }

    return 0;
}

fn USize to_usize(BitWidth width, char[] src)
{
    switch (width)
    {
        case W8:
            return src[0];
        case W16:
            return ((USize)src[0] << 8) + src[1];
        default:
            error("%s not implimented", width);
    }
}

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
